
local changelog =[[
    2.0alpha1 23.03.2017     
      + GUI: separate parameters blocks
      + GUI: update envelopes on changing parameters related with builing envelope
      + GUI: improved scalable UI
      + envelope_builder: use fft_real (twice faster FFT performance, 5.25+)
      + envelope_builder: glue takes independently before analyze if takerate != 1 or offset != 0 or there are existed stretch markers
      + envelope_builder: additional mode to collect sum of prenormalized RMS and FFT envelopes based on FFT size window
      + point_detector: mode switch beetween transients (very short envelope rising) and syllables (long envelope rising)
      + point_detector: dynamically show minimal distance
      
      todo
        prepare: always use loop source due to REAPER bug when accessing empty audio source (random huge peaks)      
        perform time selection
        solo takes tracks
        check for SWS version
        auto search area   
        show points detect params dynamically     
        
    1.0   11.02.2016
      + Public release
  ]]
-----------------------------------------------------------------------  
  name = 'MPL AlignTakes'
  vrs = '2.0alpha1'
  reavrs = 5.25
  --------------------------------------------------------------------
  function msg(s)
    if not s then return end
    reaper.ShowConsoleMsg(s)
    reaper.ShowConsoleMsg('\n')
  end
  --------------------------------------------------------------------    
  --debug_mode = true
  local r = reaper
  local gfx = gfx
  data = {}
  mouse = {}
  local blocks = {}
  local obj = {}
  local scaling = {}
  takes = {}
  local run_l
  -- trig_process == 1 GUI trigger 
  --              ==2 gettakes 
  --              ==3 update takes   
-----------------------------------------------------------------------    
  function Data_LoadConfig()
    local def_data = Data_defaults()
    -- get config path
      local config_path = debug.getinfo(2, "S").source:sub(2):sub(0,-5)..'_config.ini'
    -- check default file
      local file = io.open(config_path, 'r')
      if not file then
        file = io.open(config_path, 'w')
        local def_content =
[[// Configuration data for ]]..name..[[

[Info]
[Global_variables]
]]
        file:write(def_content)
        file.close()
      end
      file:close()
    -- Load data section
      local ext_name = 'Global_variables'
      for key in pairs(def_data) do
        if type(def_data[key]) == 'number' or type(def_data[key]) == 'string' then
          local _, stringOut = reaper.BR_Win32_GetPrivateProfileString( ext_name, key, def_data[key], config_path )
          if stringOut ~= ''  then
            if tonumber(stringOut) then stringOut = tonumber(stringOut) end
            data[key] = stringOut
            --data[key] = def_data[key] -- FOR RESET DEBUG
            r.BR_Win32_WritePrivateProfileString( ext_name, key, data[key], config_path )
           else
            r.BR_Win32_WritePrivateProfileString( ext_name, key, def_data[key], config_path )
          end
        end
      end
  end
  --------------------------------------------------------------------  
  function Data_defaults()
    local data_default = {
      wind_w = 480,                     --  default GUI width
      wind_h = 360,                     --  default GUI height
      
      glue_before_analyze = 0,          -- glue independently

      mode = 0,                         --  0-RMS 1-FFT      
      scaling = 1,
      custom_window = 0.35,                --  RMS window
      fft_size = 0,                     --  FFT size
      fft_HP = 0,
      fft_LP = 1,
      smooth_env = 0,
      
      mode_points = 0,
      min_distance = 0,
      sens = .5
      
      }
    return data_default
  end       
      --[[{ 
        name = 'Default',
        knob_coeff = 0.01, -- knob sensivity
        xpos = 100,
        ypos = 100,
        compact_view = 0, -- default mode
        mode = 0, -- 0 - RMS / 1 - FFT
        alg = 0,
        custom_window_norm = 0, -- rms window    
        fft_size_norm = 0.5,
        fft_HP_norm = 0,
        fft_LP_norm = 1,
        smooth_norm = 0,
        filter_area_norm =  0.1, -- filter closer points
        rise_area_norm =    0.2, -- detect rise on this area
        risefall_norm =     0.125, -- how much envelope rise/fall in rise area - for scaled env
        risefall2_norm =    0.3, -- how much envelope rise/fall in rise area - for original env
        threshold_norm =    0.1, -- noise floor for scaled env
        scaling_pow_norm =  0.9, -- normalised RMS values scaled via power of this value (after convertion))
        search_area_norm =  0.1
        
        -- green / detection point  
             data2.scaling_pow = F_convert(math.abs(1-data.current.scaling_pow_norm), 0.1, 0.75)
             data2.threshold = F_convert(data.current.threshold_norm, 0.1,0.4)     
             data2.rise_area = F_convert(data.current.rise_area_norm, 0.1,0.5)
             data2.risefall = F_convert(data.current.risefall_norm, 0.1,0.8)
             data2.risefall2 = F_convert(data.current.risefall2_norm, 0.05,0.8)    
             data2.filter_area = F_convert(data.current.filter_area_norm, 0.1,2)
                 
           -- blue / envelope
             data2.custom_window = F_convert(data.current.custom_window_norm, 0.005, 0.2)
             data2.fft_size = math.floor(2^math.floor(F_convert(data.current.fft_size_norm,7,10)))
             if data2.fft_LP == nil then data2.fft_LP = data2.fft_size end
             data2.fft_HP = F_limit(math.floor(F_convert(data.current.fft_HP_norm, 1, data2.fft_size)), 1, data2.fft_LP-1)
             data2.fft_LP =  1+F_limit(math.floor(F_convert(data.current.fft_LP_norm, 1, data2.fft_size)), data2.fft_HP+1, data2.fft_size)
             data2.smooth = data.current.smooth_norm
           
           -- red / algo
             data2.search_area = F_convert(data.current.search_area_norm, 0.05, 2) 
             
           --othert
             data2.play_pos = reaper.GetPlayPosition(0)
             
             
      }]]
      
  
  -----------------------------------------------------------------------
   function F_limit(val,min,max,quant_digits)
       if val == nil then return end
       local val_out = val
       if min and val < min then val_out = min end
       if max and val > max then val_out = max end
       local int, dec = math.modf(val_out)
       if dec == 0 then return int end
       if quant_digits then
         return math.floor(val_out*10^quant_digits)/10^quant_digits
       end
       return val_out
     end
  --------------------------------------------------------------------     
  function F_q(val, digits) return math.floor(10^digits* val)/(10^digits) end  
  -----------------------------------------------------------------------
  function F_convert(val, min, max) return (max-min) *val + min end
  --------------------------------------------------------------------
  function Data_init_scaling()  --   tp==1 return string
    scaling = {
        scaling_env   = function(val, tp) --  tp1 string  tp2 value
                          local min, max, out_v = 0.05, 1
                          if not tp then
                            if mouse.dy and mouse.dy ~= 0 then out_v = F_limit(F_q(val - (mouse.dy / 300 ),2),0,1) end
                            return out_v
                          end
                          local out_v = F_convert(val, min, max)
                          if tp == 1 then return math.floor(out_v*100)..'%' end
                          if tp == 2 then return out_v end
                        end,
        smooth_env   = function(val, tp) --  tp1 string  tp2 value
                          local min, max, out_v = 0.01, 0.95
                          if not tp then
                            if mouse.dy and mouse.dy ~= 0 then out_v = F_limit(F_q(val - (mouse.dy / 300 ),2),0,1) end
                            return out_v
                          end
                          local out_v = F_convert(val, min, max)
                          if tp == 1 then return math.floor(out_v*100)..'%' end
                          if tp == 2 then return out_v end
                        end,                        
                        
        rms   = function(val, tp) --  tp1 string  tp2 value
                          local min, max, out_v = 0.005, 0.02
                          if not tp then
                            if mouse.dy and mouse.dy ~= 0 then out_v = F_limit(F_q(val - (mouse.dy / 300 ),2),0,1) end
                            return out_v
                          end
                          local out_v = F_convert(val, min, max)
                          if tp == 1 then return math.floor(out_v*1000)..'ms' end
                          if tp == 2 then return out_v end
                        end,
                        
        fft   = function(val, tp) --  tp1 string  tp2 value
                          if not val or not tonumber(val) then val = 0 end
                          local min, max, out_v = 7, 10
                          if not tp then
                            if mouse.dy and mouse.dy ~= 0 then out_v = F_limit(F_q(val - (mouse.dy / 200 ),2),0,1) end                            
                            return out_v
                          end                          
                          if tp == 1 then return math.floor(2^math.floor(F_convert(val, min, max))) end
                          if tp == 2 then return math.floor(2^math.floor(F_convert(val, min, max))) end
                        end,   
                                             
        fft_filt   = function(val, tp) --  tp1 string  tp2 value
                          if not val or not tonumber(val) then val = 0 end
                          if not tp then  if mouse.dy and mouse.dy ~= 0 then out_v = F_limit(F_q(val - (mouse.dy / 200 ),2),0.001,1) end    return out_v  end
                          if tp == 1 then 
                            local out_n = math.floor(val * 22050)
                            local out_s = 'Hz'
                            if out_n > 1000 then out_n = F_q(out_n/1000,1) out_s = 'kHz' end
                            return   out_n..out_s
                          end
                        end, 
        min_distance  = function(val, tp) --  tp1 string  tp2 value
                          local min, max, out_v = 0.02, 1.5
                          if not tp then
                            if mouse.dy and mouse.dy ~= 0 then out_v = F_limit(F_q(val - (mouse.dy / 300 ),2),0,1) end
                            return out_v
                          end
                          local out_v = F_convert(val, min, max)
                          if tp == 1 then return math.floor(out_v*1000)..'ms' end
                          if tp == 2 then return out_v end
                        end,
}                                                
  end  
  ------------------------------------------------------------------
  function Data_Update()
    local def_data = Data_defaults()
    local config_path = debug.getinfo(2, "S").source:sub(2):sub(0,-5)..'_config.ini'
    for key in pairs(def_data) do  if type(data[key])~= 'table'   then  reaper.BR_Win32_WritePrivateProfileString( 'Global_variables', key, data[key], config_path ) end  end
    reaper.BR_Win32_WritePrivateProfileString( 'Info', 'vrs', vrs, config_path )
    data.CALC_fft_size = scaling.fft(data.fft_size, 2)
  end
  --------------------------------------------------------------------
  function GUI_init_gfx()
    local obj = Objects_Init()
    local mouse_x, mouse_y = reaper.GetMousePosition()
    local x_pos = reaper.GetExtState( name, 'x_pos' )
    local y_pos = reaper.GetExtState( name, 'y_pos' )
    local w = reaper.GetExtState( name, 'wind_w' )
    local h = reaper.GetExtState( name, 'wind_h' )
    if tonumber(w) then data.wind_w = tonumber(w) data.wind_h = tonumber(h) end
    gfx.quit()
    if x_pos and x_pos ~= '' then
      local txt_name = name..' '..vrs
              gfx.init('', data.wind_w, data.wind_h, 0, x_pos, y_pos)
     else     gfx.init('', data.wind_w, data.wind_h, 0)--mouse_x, mouse_y)
    end
    Objects_Init()    
  end
  --------------------------------------------------------------------
  function F_conv_int_to_logic(num, inp1, inp2)
    if (num and type(num) == 'number' and num == 1) 
      or (num and type(num) == 'boolean' and num == true) 
      or (num and type(num) == 'table') then
      if inp2 then return inp2 end
      return true
     else
      if inp1 then return inp1 end
      return false
    end
  end
  
  --------------------------------------------------------------------  
  function Objects_Init()  -- static variables
    --if debug_mode then msg('define obj') end
    if gfx.w < 100 then gfx.w = 100 end
    if gfx.h < 100 then gfx.h = 100 end
    local OS_switch = reaper.GetOS():find('Win') or reaper.GetOS():find('Unknown')    
    obj = {
                    main_w = gfx.w,
                    main_h = gfx.h,
                    offs = 1,
  
                    tab_h = 30,
                    but_h = 20,                    
                    row_h = 40,                   
                    
                    w1 = 55,                      --  knob w
                    w2 = 110,                      -- label
                    w3 = 30,                      -- get
                    w4 = 70,                      -- selector w
                    
                    h1 = 100,                      -- peaks display
                    h2 = 30,                      -- knob h
                    
                    knob_ind_y= 10,               -- space beetween knobs
                    
                    info_but_h = 20,
                    info_but_w = 150,
                                        
                    min_w1 = 500,                 -- layers gain
                    
                    fontname = 'Calibri',
                    fontsize = F_conv_int_to_logic(OS_switch, 13, 18), 
                    fontsize2 = F_conv_int_to_logic(OS_switch, 11, 15), 
                    fontsize3 = F_conv_int_to_logic(OS_switch, 9, 14),    -- normalize coeff
                    fontsize4 = F_conv_int_to_logic(OS_switch, 8, 12), 
                    fontsize5 = F_conv_int_to_logic(OS_switch, 8, 12),                   
                    txt_alpha0 = 0.1,
                    txt_alpha1 = 0.7,
                    txt_alpha2 = 0.3,             -- switch on
                    txt_alpha3 = 0.6,              -- switch off
                    
                    glass_side = 200,
                    blit_alpha0 = 0.1,
                    blit_alpha1 = 0.4,
                    blit_alpha2 = 0.2,            -- peaks grad
                    
                    gui_color = {['back'] = '20 20 20',
                                  ['back2'] = '51 63 56',
                                  ['black'] = '0 0 0',
                                  ['green'] = '130 255 120',
                                  ['blue2'] = '100 150 255',
                                  ['blue'] = '127 204 255',
                                  ['white'] = '255 255 255',
                                  ['red'] = '255 130 70',
                                  ['green_dark'] = '102 153 102',
                                  ['yellow'] = '200 200 0',
                                  ['pink'] = '200 150 200',
                                }
                  }
      -- version / menu button
        obj.info = {x = gfx.w - obj.info_but_w,
                  y = 0,
                  w = obj.info_but_w,
                  h = obj.info_but_h,
                  a_frame = 0,
                  a_txt = obj.txt_alpha1,
                  fontname = obj.fontname,
                  fontsize = obj.fontsize2,
                  txt = '? '..name..' '..vrs
                  } 
      -- lc check
        obj.lc_txt = {x = 0,
                      y = obj.info_but_h+5,
                      w = gfx.w,
                      h = obj.row_h,
                      frame_type = 5,
                      fontname = obj.fontname,
                      fontsize = obj.fontsize,
                      a_txt = obj.txt_alpha1,
                      a_frame = obj.blit_alpha0,
                      txt = 'Purchase MPL scripts for $10'}
      -- lc check
        obj.lc_txt2 = {x = 0,
                      y = obj.info_but_h+10+obj.row_h,
                      w = gfx.w,
                      h = obj.row_h,
                      frame_type = 5,
                      fontname = obj.fontname,
                      fontsize = obj.fontsize,
                      a_txt = obj.txt_alpha1,
                      a_frame = obj.blit_alpha0,
                      txt = 'Already purchased'}     
                      
      -- lc check
        obj.lc_txt3 = {x = 0,
                      y = obj.info_but_h+15+obj.row_h*2,
                      w = gfx.w,
                      h = obj.row_h,
                      frame_type = 5,
                      fontname = obj.fontname,
                      fontsize = obj.fontsize,
                      a_txt = obj.txt_alpha1,
                      a_frame = obj.blit_alpha0,
                      txt = 'Continue'}    
      obj.knobs_y_offs = obj.info_but_h + obj.offs
    -- prepare knobs
      obj.lab1 =      {x = 0,
                     y = obj.knobs_y_offs+obj.knob_ind_y,
                     w = obj.w2,
                     h = obj.h2,
                     a_frame = obj.blit_alpha0,
                     txt= 'Build Envelope',
                     a_txt = obj.txt_alpha1,
                     man_col = 'white',
                     fontname = obj.fontname,
                     fontsize = obj.fontsize,
                     } 
      obj.mode_sw = {x = F_follow_button(obj.lab1),
                     x_shift = 0,
                     y = obj.lab1.y,
                     w = obj.w4,
                     h = obj.h2,
                     frame_type = 7,
                     a_frame = obj.blit_alpha0,
                     a_txt = obj.txt_alpha1,
                     mouse_id = 'enc_mode',
                     txt1 = 'RMS',
                     txt2 = 'FFT',
                     statecnt = 3
                     }                          
      obj.kn_scaling = {x = F_follow_button(obj.mode_sw),
                     y = obj.lab1.y,
                     w = obj.w1,
                     h = obj.h2,
                     frame_type = 4,
                     a_frame = obj.blit_alpha0,
                     knob_val = data.scaling,
                     knob_val_alias = scaling.scaling_env(data.scaling, 1),
                     knob_alias = 'scaling',
                     a_txt = obj.txt_alpha1,
                     mouse_id = 'kn_scaling',
                     man_col = 'white'
                     } 
      obj.kn_rms_fft = {x = F_follow_button(obj.kn_scaling),
                     y = obj.lab1.y,
                     w = obj.w1,
                     h = obj.h2,
                     frame_type = 4,
                     a_frame = obj.blit_alpha0,
                     knob_val = F_conv_int_to_logic(data.mode == 0, data.fft_size, data.custom_window),
                     knob_alias = F_conv_int_to_logic(data.mode == 0, 'FFT size', 'window'),
                     a_txt = obj.txt_alpha1,
                     mouse_id = 'kn_rms_fft',
                     man_col = 'white'
                     }    
      obj.smooth_env = {x = F_follow_button(obj.kn_rms_fft),
                     y = obj.lab1.y,
                     w = obj.w1,
                     h = obj.h2,
                     frame_type = 4,
                     a_frame = obj.blit_alpha0,
                     knob_val = scaling.smooth_env(data.smooth_env, 1),
                     knob_alias = 'Smooth',
                     a_txt = obj.txt_alpha1,
                     mouse_id = 'smooth_env',
                     man_col = 'white'
                     }                      
      obj.fft_HP = {x = F_follow_button(obj.smooth_env),
                     y = obj.lab1.y,
                     w = obj.w1,
                     h = obj.h2,
                     frame_type = 4,
                     a_frame = obj.blit_alpha0,
                     knob_val = data.fft_HP,
                     knob_alias = 'FFT HP',
                     a_txt = obj.txt_alpha1,
                     mouse_id = 'fft_HP',
                     man_col = 'white'
                     }    
      obj.fft_LP = {x = F_follow_button(obj.fft_HP),
                    y = obj.lab1.y,
                     w = obj.w1,
                     h = obj.h2,
                     frame_type = 4,
                     a_frame = obj.blit_alpha0,
                     knob_val = data.fft_LP,
                     knob_alias = 'FFT LP',
                     a_txt = obj.txt_alpha1,
                     mouse_id = 'fft_LP',
                     man_col = 'white'
                     }            
                      
                                                                    
    -- points detect
    obj.lab2 =      {x = 0,
                   y = obj.knobs_y_offs + obj.offs + obj.h2+obj.knob_ind_y*2,
                   w = obj.w2,
                   h = obj.h2,
                   a_frame = obj.blit_alpha0,
                   txt= 'Points Detector',
                   a_txt = obj.txt_alpha1,
                   txt_col = 'green',
                   fontname = obj.fontname,
                   fontsize = obj.fontsize,
                   } 
    obj.mode_sw_points = {x = F_follow_button(obj.lab2),
                     x_shift = 0,
                     y = obj.lab2.y,
                     w = obj.w4,
                     h = obj.h2,
                     frame_type = 7,
                     a_frame = obj.blit_alpha0,
                     a_txt = obj.txt_alpha1,
                     txt_col = 'green',
                     mouse_id = 'points_mode',
                     txt1 = 'Transient',
                     txt2 = 'Syllable',
                     statecnt = 2
                     }             
      obj.min_distance = {x = F_follow_button(obj.mode_sw_points),
                     y = obj.lab2.y,
                     w = obj.w1,
                     h = obj.h2,
                     frame_type = 4,
                     a_frame = obj.blit_alpha0,
                     knob_val = data.min_distance,
                     knob_alias = 'distance',
                     a_txt = obj.txt_alpha1,
                     mouse_id = 'min_distance',
                     txt_col = 'green'
                     }                      
                     
                     
                              
    ------------- search
    obj.lab3 =      {x = 0,
                   y = obj.knobs_y_offs + obj.offs + obj.h2*2+obj.knob_ind_y*3,
                   w = obj.w2,
                   h = obj.h2,
                   a_frame = obj.blit_alpha0,
                   txt= 'Search Best Fit',
                   a_txt = obj.txt_alpha1,
                   man_col = 'white',
                   fontname = obj.fontname,
                   fontsize = obj.fontsize,
                   }  
    obj.peak_disp_y = obj.knobs_y_offs + obj.offs + obj.h2*3+obj.knob_ind_y*4
    ------------- search
    obj.get_b =      {x = 0,
                   y = obj.peak_disp_y,
                   w = obj.w2,
                   h = gfx.h - obj.peak_disp_y,
                   a_frame = obj.blit_alpha0,
                   txt= 'Get Takes',
                   a_txt = obj.txt_alpha1,
                   txt_col = 'white',
                   fontname = obj.fontname,
                   fontsize = obj.fontsize,
                   }     
    
    obj.peaks_disp1 =      {x = obj.w2,
                   y = obj.get_b.y + obj.get_b.h,
                   w = gfx.w-obj.w2,
                   h = 1,
                   a_frame = obj.blit_alpha2,
                   src_frame = 7
                   }          
    obj.peaks_disp2 =      {x = obj.w2,
                   y = obj.get_b.y + obj.get_b.h,
                   w = gfx.w-obj.w2,
                   h = 1,
                   a_frame = obj.blit_alpha2,
                   src_frame = 7,
                   inverted_blit = true
                   }                                                                
    return obj
  end
  --------------------------------------------------------------------
  function Objects_Update() local last_h
    if mouse.context_match == 'info vrs' then obj.info.a_frame = obj.blit_alpha1 else obj.info.a_frame = 0 end  
    if mouse.context_match == 'get_b' then obj.get_b.a_frame = obj.blit_alpha1 else obj.get_b.a_frame = 0 end  
    
    if not update_gfx then return end
    obj.peaks_disp1.y = obj.peak_disp_y
    obj.peaks_disp1.h = (gfx.h - obj.peak_disp_y) /2 
    
    obj.peaks_disp2.y = obj.peak_disp_y + obj.peaks_disp1.h
    obj.peaks_disp2.h = (gfx.h - obj.peak_disp_y) /2 
        ---------------------------- ENV ctrl
    obj.mode_sw.state = data.mode    
    obj.kn_scaling.knob_val = data.scaling    
    obj.kn_scaling.knob_val_alias = scaling.scaling_env(data.scaling, 1)     
    obj.kn_rms_fft.knob_val_alias = F_conv_int_to_logic(data.mode == 0, scaling.fft(data.fft_size, 1), scaling.rms(data.custom_window, 1))  
    obj.kn_rms_fft.knob_alias = F_conv_int_to_logic(data.mode == 0, 'fft size', 'window')
    obj.kn_rms_fft.knob_val = F_conv_int_to_logic(data.mode == 0, data.fft_size, data.custom_window)
    obj.fft_HP.knob_val = data.fft_HP
    obj.fft_HP.knob_val_alias = scaling.fft_filt(data.fft_HP, 1)
    obj.fft_HP.a_txt = F_conv_int_to_logic(data.mode == 0, obj.txt_alpha1,obj.txt_alpha0)
    obj.fft_LP.knob_val = data.fft_LP
    obj.fft_LP.knob_val_alias = scaling.fft_filt(data.fft_LP, 1)
    obj.fft_LP.a_txt = F_conv_int_to_logic(data.mode == 0, obj.txt_alpha1,obj.txt_alpha0)     
    obj.smooth_env.knob_val = data.smooth_env   
    obj.smooth_env.knob_val_alias = scaling.smooth_env(data.smooth_env, 1) 
        ---------------------------- POINTS ctrl    
    obj.mode_sw_points.state = data.mode_points
    obj.min_distance.knob_val = data.min_distance
    obj.min_distance.knob_val_alias = scaling.min_distance(data.min_distance, 1)
    
  end  
  ----------------------------------------------------------------------- 
  function F_follow_button(obj) return obj.w + obj.x end
  -----------------------------------------------------------------------    
   function F_xywh_gfx()
     -- save xy state
       local _, wind_x,wind_y = gfx.dock(-1,0,0,0,0)
       local wind_w, wind_h = gfx.w, gfx.h
       if
         not last_wind_x
         or not last_wind_y
         or not last_wind_w
         or not last_wind_h
         or last_wind_w~=wind_w
         or last_wind_h~=wind_h then
         --if debug_mode then msg(string.rep('_',30)..'\n') msg('SAVE WH '..os.date())  end
  
         reaper.SetExtState( name, 'wind_w', math.floor(wind_w), true )
         reaper.SetExtState( name, 'wind_h', math.floor(wind_h), true )
         update_gfx = true
         Objects_Init()
       end
  
       if  last_wind_x~=wind_x or last_wind_y~=wind_y then
         --if debug_mode then msg(string.rep('_',30)..'\n') msg('SAVE XY '..os.date())  end
         reaper.SetExtState( name, 'x_pos', math.floor(wind_x), true )
         reaper.SetExtState( name, 'y_pos', math.floor(wind_y), true )
       end
  
       last_wind_x = wind_x
       last_wind_y = wind_y
       last_wind_w = wind_w
       last_wind_h = wind_h
   end
  --------------------------------------------------------------------
  function GUI_backgr(w,h, a)
    if not w then w = gfx.w end
    if not h then h = gfx.h+20 end
    F_Get_SSV(obj.gui_color.black)
    gfx.a = 1
    if a then gfx.a = a end
    gfx.rect(0,0,w, h, 1)
    F_Get_SSV(obj.gui_color.white)
    gfx.a = 0.2
    gfx.rect(0,0,w, h, 1)
  end   
  -----------------------------------------------------------------------
  function F_Get_SSV(s)
    if not s then return end
    local t = {}
    for i in s:gmatch("[%d%.]+") do t[#t+1] = tonumber(i) / 255 end
    gfx.r, gfx.g, gfx.b = t[1], t[2], t[3]
  end
  --------------------------------------------------------------------
  function F_frame(t)
    if not t then return end
    local  x,y,w,h = t.x, t.y, t.w, t.h
    if w < obj.offs then return end
    if t.a_frame then gfx.a = t.a_frame end
    local y1 = y
    local h1 = h
    local ang_rot if t.inverted_blit then ang_rot = math.rad(180) else ang_rot = math.rad(0) end
    if debug_mode then 
      gfx.a = 0.1
      gfx.line(x,y,x+w,y+h)
      gfx.line(x,y+h,x+w,y)
      gfx.rect(x,y,w,h,0)
    end
    
    -- REGULAR ----------------------
    if not t.frame_type or t.frame_type == 1 or t.frame_type == 5 then -- 5=rect frame
      local src_frame
      if t.src_frame then src_frame = t.src_frame else src_frame = 3 end
      gfx.blit(src_frame, 1, ang_rot,
                0,
                0,
                obj.glass_side,
                obj.glass_side,
                x,y1,w,h1,
                0, 0)
      if t.frame_type == 5  then gfx.rect(x,y,w,h) end
      
      if t.col_frame then
        F_Get_SSV(obj.gui_color[t.col_frame])
        gfx.rect(x,y,w,h,1)
      end  
      if t.txt_col then F_Get_SSV(obj.gui_color[t.txt_col]) else gfx.set(1,1,1) end
      if t.txt then
        gfx.setfont(1, t.fontname, t.fontsize)
        local measurestrname = gfx.measurestr(t.txt)
        if not t.txt_pos then
          gfx.x = x + (w-measurestrname)/2
         elseif t.txt_pos == 1 then -- right aligned
          gfx.x = x + w-measurestrname- 2
         elseif t.txt_pos == 2 then -- left aligned
          gfx.x = x+2
        end
        gfx.y = y + (h-gfx.texth)/2
        if t.a_txt then gfx.a = t.a_txt end
        gfx.drawstr(t.txt)
      end              
    end
    
   
    --  KNOB  -----------------------------------------
    if t.frame_type == 4 then
      gfx.blit(3, 1, math.rad(0),
              0,
              0,
              obj.glass_side,
              obj.glass_side,
              x,y1,w,h1,
              0, 0)
      
      if t.knob_val then
        GUI_knob(t, t.knob_val)
        if t.txt_col then F_Get_SSV(obj.gui_color[t.txt_col]) else F_Get_SSV(obj.gui_color.white) end  
        gfx.setfont(1, obj.fontname, obj.fontsize2)
        local measurestrname = gfx.measurestr(t.knob_val_alias)
        gfx.x = math.floor(x + (w-measurestrname)/2)   
        if t.knob_alias and t.knob_alias ~= '' then 
          gfx.y = y + h/2-gfx.texth + 2
         else
          gfx.y = y + h-gfx.texth
        end
        if t.a_txt then gfx.a = t.a_txt end
        gfx.drawstr(t.knob_val_alias)        
      end
      if t.knob_alias then
        if t.txt_col then F_Get_SSV(obj.gui_color[t.txt_col]) else F_Get_SSV(obj.gui_color.white) end  
        gfx.setfont(1, obj.fontname, obj.fontsize3)
        local measurestrname = gfx.measurestr(t.knob_alias)
        gfx.x = math.floor(x + (w-measurestrname)/2)
        gfx.y = math.floor(y + h - gfx.texth)
        if t.a_txt then gfx.a = t.a_txt end
        gfx.drawstr(t.knob_alias)        
      end      
    end
    
    -- SWITCH
      if t.frame_type == 7 then
        gfx.blit(3, 1, ang_rot,
                0,
                0,
                obj.glass_side,
                obj.glass_side,
                x,y1,w,h1,
                0, 0)
        -- switch_frame
          x = x + t.x_shift
          local r_sw = 6
          local x_offs = x + r_sw
          gfx.a  = 0.2
          gfx.arc(x_offs+2, y+r_sw, r_sw, math.rad(90), math.rad(0), 1)
          gfx.arc(x_offs, y+r_sw, r_sw, math.rad(-90), math.rad(0), 1)
          gfx.arc(x_offs, y+h-r_sw, r_sw, math.rad(180), math.rad(270), 1)
          gfx.arc(x_offs+2, y+h-r_sw, r_sw, math.rad(90), math.rad(180), 1)
          gfx.line(x, y+r_sw+1, x, y+h-r_sw-1)
          gfx.line(x+obj.offs+r_sw*2+1, y+r_sw+1, x+obj.offs+r_sw*2+1, y+h-r_sw-1)
          gfx.x = x + r_sw + 1 gfx.y = y
          gfx.setpixel(gfx.r,gfx.g,gfx.b )
          gfx.y = y+h
          gfx.setpixel(gfx.r,gfx.g,gfx.b )
        -- switch man
          local crcl_r = math.floor(r_sw*0.7)
          gfx.a = 0.4
          local y_crcl
          if t.state == 0  then 
            y_crcl =  y+r_sw+1
           elseif (t.state == 2 and t.statecnt == 3) then 
            y_crcl =  y+h/2
           elseif (t.state == 1 and t.statecnt == 3) or (t.state==1 and t.statecnt == 2) then 
            y_crcl = y+h-r_sw-1
          end
          gfx.circle(x+r_sw+1, y_crcl,  crcl_r, 1,1 )
        -- txt
          gfx.setfont(1, obj.fontname, obj.fontsize3)
          if t.txt1 and t.txt2 then 
            gfx.a = F_conv_int_to_logic(  ((t.state==0 or t.state==2) and t.statecnt == 3) or  (t.state==0 and t.statecnt == 2)      , obj.txt_alpha0,obj.txt_alpha1)
            gfx.x = x+r_sw*2 + 6
            gfx.y = y
            gfx.drawstr(t.txt1) 
            gfx.a = F_conv_int_to_logic(  ((t.state==1 or t.state==2) and t.statecnt == 3) or (t.state==1 and t.statecnt == 2)      , obj.txt_alpha0,obj.txt_alpha1)
            gfx.x = x+r_sw*2 + 6
            gfx.y = y + gfx.texth
            gfx.drawstr(t.txt2) 
          end 
      end
  end
  -----------------------------------------------------------------------   
  function LC_check()
     local modstr = r.GetExtState( 'MPL_LC', 'lickey' )
     if modstr == '' then return end
     local b='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/' local modstr = string.gsub(modstr, '[^'..b..'=]', '') modstr = (modstr:gsub('.', function(x)  if (x == '=') then return '' end local r,f='',(b:find(x)-1) for i=6,1,-1 do r=r..(f%2^i-f%2^(i-1)>0 and '1' or '0') end return r; end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x) if (#x ~= 8) then return '' end local c=0  for i=1,8 do c=c+(x:sub(i,i)=='1' and 2^(8-i) or 0) end return string.char(c) end)) local outstr = '' for i = 1, modstr:len(), 4 do outstr = outstr..string.char(tonumber(modstr:sub(i,i+3))) end if modstr:find('46') and modstr:find('64')  then return true end return false end if LC_check() then run_l = 2 else run_l = 0 
  end
  --------------------------------------------------------------------     
  function GUI_knob(t, val)
    local  x,y,w,h = t.x, t.y, t.w, t.h
    if not val or not tonumber(val )then val = 0 end
    local ang_lim = -30 -- grad
    local x0 = math.floor(x+w/2 )-1
    local r0 = math.floor(1.0*  w/2)
    local y0 = math.floor(y+ h/2-(r0*math.sin(math.rad(ang_lim)))/2) - 5
    
    -- arc
      gfx.a = 0.01
      for i = 1 , 3, 0.2  do 
        gfx.arc(x0,y0,      r0-i, math.rad(-90 + ang_lim ), math.rad(-90), 1)
        gfx.arc(x0,y0-1,  r0-i, math.rad(-90 ), math.rad(0), 1) 
        gfx.arc(x0+1,y0-1,    r0-i, math.rad(0), math.rad(90), 1) 
        gfx.arc(x0+1,y0,      r0-i, math.rad(90), math.rad(90- ang_lim), 1) 
      end
    
    -- value
      if t.man_col then F_Get_SSV(obj.gui_color[t.man_col]) end
      gfx.a = 0.2
      if t.a_txt then gfx.a = t.a_txt * 0.25 end
      local com_gr = 180-ang_lim*2
      if t.is_centered then
        local ang_val = val*com_gr/2
        for i = 1 , 3, 0.2  do 
          if ang_val > 0 and ang_val <= 90 then 
            gfx.arc(x0+1,y0-1,r0-i, math.rad(0), math.rad(ang_val), 1) 
           elseif ang_val > 0 and ang_val <= 180 then
            gfx.arc(x0+1,y0-1,r0-i, math.rad(0), math.rad(90), 1)  
            gfx.arc(x0+1,y0,r0-i, math.rad(90), math.rad(ang_val), 1)  
           elseif ang_val > -90 and ang_val <= 0 then 
            gfx.arc(x0,y0-1,r0-i, math.rad(0), math.rad(ang_val), 1)
           elseif ang_val <= -90 then
            gfx.arc(x0,y0-1,r0-i, math.rad(-90), math.rad(0), 1) 
            gfx.arc(x0,y0,r0-i, math.rad(-90), math.rad(ang_val), 1)                      
          end
        end        
       else
        local ang_val = -90+ang_lim+ com_gr * val
        for i = 1 , 3, 0.2  do 
          if ang_val <= -90 then gfx.arc(x0,y0,r0-i, math.rad(-90+ang_lim ), math.rad(ang_val), 1)
            elseif ang_val <= 0 then 
              gfx.arc(x0,y0,r0-i, math.rad(-90+ang_lim ), math.rad(-90), 1)
              gfx.arc(x0,y0-1,r0-i, math.rad(-90), math.rad(ang_val), 1)
            elseif ang_val <= 90 then 
              gfx.arc(x0,y0,r0-i, math.rad(-90+ang_lim ), math.rad(-90), 1)
              gfx.arc(x0,y0-1,r0-i, math.rad(-90), math.rad(0), 1) 
              gfx.arc(x0+1,y0-1,r0-i, math.rad(0), math.rad(ang_val), 1)   
            elseif ang_val <= 180 then 
              gfx.arc(x0,y0,r0-i, math.rad(-90+ang_lim ), math.rad(-90), 1)
              gfx.arc(x0,y0-1,r0-i, math.rad(-90), math.rad(0), 1) 
              gfx.arc(x0+1,y0-1,r0-i, math.rad(0), math.rad(90), 1)  
              gfx.arc(x0+1,y0,r0-i, math.rad(90), math.rad(ang_val), 1)                         
          end
        end
      end
  end 
  --------------------------------------------------------------------
  function GUI_draw()
    gfx.mode = 0
    --[[
    3 gradient glass
    7 peaks grad
    8 peaks
    9 - points
    10 common static buf
    ]]
    -- update buf on start
      if update_gfx_onstart then
          -- back
          gfx.dest = 3
          gfx.setimgdim(3, -1, -1)
          gfx.setimgdim(3, obj.glass_side, obj.glass_side)
          gfx.a = 1
          local r,g,b,a = 0.9,0.9,1,0.6
          gfx.x, gfx.y = 0,0
          local drdx = 0.00001
          local drdy = 0
          local dgdx = 0.0001
          local dgdy = 0.0003
          local dbdx = 0.00002
          local dbdy = 0
          local dadx = 0.00013
          local dady = 0.00104
          gfx.gradrect(0,0,obj.glass_side, obj.glass_side,
                          r,g,b,a,
                          drdx, dgdx, dbdx, dadx,
                          drdy, dgdy, dbdy, dady)
          
          -- buf 7 -- item envelope gradient
            if update_gfx then 
                gfx.dest = 7  
                gfx.setimgdim(7, -1, -1)
                gfx.setimgdim(7, obj.glass_side, obj.glass_side)
                gfx.gradrect(0,0, obj.glass_side, obj.glass_side, 1,1,1,0.9, 0,0,0,0.00001, 0,0,0,-0.005)
            end
            
        update_gfx_on_start = nil
      end
  
    -- update static buffers
    if update_gfx then
        gfx.a = 1
        gfx.dest = 10
        gfx.setimgdim(10, -1, -1)
        gfx.setimgdim(10, gfx.w, gfx.h)
        GUI_backgr()
        
        F_frame(obj.lab1)
        F_frame(obj.mode_sw)
        F_frame(obj.kn_scaling)
        F_frame(obj.kn_rms_fft)
        F_frame(obj.fft_HP)
        F_frame(obj.fft_LP)
        F_frame(obj.smooth_env)
        
        F_frame(obj.lab2)
        F_frame(obj.mode_sw_points)
        F_frame(obj.min_distance)
        
        F_frame(obj.lab3)
        
        F_frame(obj.peaks_disp1)
        F_frame(obj.peaks_disp2)
        
        
    end
    
  
    GUI_Peaks()
    GUI_Points()
    
    gfx.dest = -1
    -- main
      gfx.a = 1    
      gfx.blit(10, 1, 0,
              0,0,  obj.main_w,obj.main_h,
              0,0,  obj.main_w,obj.main_h, 0,0)
    -- peaks blit
      gfx.a = 0.6
      gfx.blit(8, 1, 0,
                0,0,  takes.env_buf_sz,obj.glass_side,
                obj.peaks_disp1.x,obj.peaks_disp1.y,  obj.peaks_disp1.w, obj.peaks_disp1.h * 2, 0,0)    
    -- points blit
      gfx.a = 1
      gfx.blit(9, 1, 0,
                0,0, takes.env_buf_sz,obj.glass_side,
                obj.peaks_disp1.x,obj.peaks_disp1.y,  obj.peaks_disp1.w, obj.peaks_disp1.h * 2, 0,0)     
                    
              
    -- peaks
      if takes and takes[1] and takes.env_buf_sz then
        if mouse.context_match and mouse.context_match == 'peaks display' then
          -- draw norm values
            gfx.set(1,1,1)
            gfx.a = obj.txt_alpha1        
            gfx.x = obj.peaks_disp1.x+2          
            gfx.setfont(1, obj.fontname, obj.fontsize3)
            gfx.y = obj.peaks_disp1.y+obj.peaks_disp1.h-gfx.texth
            gfx.drawstr('Normalize: x'..F_q(takes[1].norm_scaling, 1))
            gfx.x = obj.peaks_disp1.x+2
            gfx.y = obj.peaks_disp1.y + obj.peaks_disp1.h
            gfx.setfont(1, obj.fontname, obj.fontsize3)
            gfx.drawstr('Normalize: x'..F_q(takes[takes.active_dub].norm_scaling, 1))
        end             
      end
      
      
    :: skip_main_blit::
    F_frame(obj.info)
    F_frame(obj.get_b) 
    if trig_process and trig_process == 1 then GUI_Analize() trig_process = 2 end
    update_gfx_onstart = false
    update_gfx = false
    gfx.update()
  end
  --------------------------------------------------------------------   
  function GUI_Points()
    if not update_points then return end
    update_points = nil
    --if debug_mode then gfx.x = 0 gfx.y = 0 gfx.drawstr('points '..os.date()) end
    
    if not takes or not takes[2] then return end    
    
    -- blit points    
      gfx.dest = 9 
      gfx.setimgdim(9, -1, -1)
      gfx.setimgdim(9, F_limit(takes.env_buf_sz, obj.glass_side), obj.glass_side)
      if takes[2] and takes.active_dub and takes[takes.active_dub] and takes[takes.active_dub].points then F_buildpoints(takes[takes.active_dub], true) end  
  end
  --------------------------------------------------------------------    
  function F_buildpeaks(take_env, is_inv)
    gfx.set(1,1,1)
    local env = take_env.env_normalized
      local x,y,h = 0, 0, obj.glass_side/2
      local coeff = 1
      --if takes.env_buf_sz < obj.glass_side then coeff = obj.glass_side / takes.env_buf_sz end
      local buf_sz = env.get_alloc()
      local last_x, last_y
      gfx.a = 1
      local y_offs = 1
      for i = 0, buf_sz do
        local val if i == 0 then val = 0 else val = env[i] end
        local x0 = math.floor(i*coeff)
        local y0 = math.floor(y+h+(h*val)*F_conv_int_to_logic(is_inv, -1,1))
        if not last_x then last_x = x0 end
        if not last_y then last_y = y0 end
        
        if x0 - last_x > 1 then 
          gfx.triangle( last_x,  last_y   + F_conv_int_to_logic(is_inv, 0,y_offs ),
                        last_x, y+h + F_conv_int_to_logic(is_inv, 0,y_offs ),
                        x0-1, y+h + F_conv_int_to_logic(is_inv, 0,y_offs ), 
                        x0-1,  y0 + F_conv_int_to_logic(is_inv, 0,y_offs ))  
          last_x = x0
        end
        last_y = y0
      end  
  end
  --------------------------------------------------------------------    
  function F_buildpoints(take_t, is_inv)
    local points_buf = take_t.points
    local x,y,h = 0, 0, obj.glass_side/2
    local buf_sz = #points_buf
    gfx.a = 1
    local y_offs = 1
    F_Get_SSV(obj.gui_color.green)
    local tri_side = 20
    local min_dist_smpls = F_limit(math.floor(scaling.min_distance(data.min_distance, 2) / takes.sec_per_bufvalue), 1)
    local val
    for i = 1, buf_sz do
      val = points_buf[i]
      if val == 1 then 
        gfx.a = 1
        gfx.line(i, y+h, i, y+h*2)
        if i ~= 1 and i ~= buf_sz then gfx.a = 0.5 gfx.rect(i, y+h, math.floor(min_dist_smpls), h) end 
      end
    end
  end
  --------------------------------------------------------------------  
  function GUI_Peaks()
    if not update_peaks then return end
    update_peaks = nil
    if debug_mode then gfx.x = 0 gfx.y = 0 gfx.drawstr('peaks '..os.date()) end
    
    if not takes or not takes[1] then return end    
    
    -- blit peaks    
      gfx.dest = 8  
      gfx.setimgdim(8, -1, -1)
      gfx.setimgdim(8, F_limit(takes.env_buf_sz, obj.glass_side), obj.glass_side)
      if takes[1] and takes[1].env_normalized then F_buildpeaks(takes[1]) end
      if takes[2] and takes.active_dub and takes[takes.active_dub] and takes[takes.active_dub].env_normalized then F_buildpeaks(takes[takes.active_dub], true) end
  end
  ------------------------------------------------------------------
  function MOUSE_match(b, offs, x_only)
    if b and b.x and b.y and b.w and b.h then
      local mouse_y_match = b.y
      local mouse_h_match = b.y+b.h
      if offs then
        mouse_y_match = mouse_y_match - offs
        mouse_h_match = mouse_y_match+b.h
      end
      if not x_only then
        if mouse.mx > b.x
          and mouse.mx < b.x+b.w
          and mouse.my > mouse_y_match
          and mouse.my < mouse_h_match
          then return true
        end
       else
        if mouse.mx > b.x
          and mouse.mx < b.x+b.w
          then return true
        end
      end
    end
  end
  -----------------------------------------------------------------------
  function MOUSE_button(xywh, offs, is_right)
    if is_right then
      if MOUSE_match(xywh, offs)
        and mouse.RMB_state
        and not mouse.last_RMB_state
        then
          mouse.context = xywh.mouse_id
          return true
       end
     else
      if MOUSE_match(xywh, offs)
        and mouse.LMB_state
        and not mouse.last_LMB_state
        then
          mouse.context = xywh.mouse_id
          return true
      end
    end
  end  
  -----------------------------------------------------------------------
  function MOUSE_DC(xywh,blit_offs)
    if MOUSE_match(xywh,blit_offs)
      and not mouse.last_LMB_state
      and mouse.LMB_state
      and mouse.last_click_ts
      and clock - mouse.last_click_ts > 0
      and clock - mouse.last_click_ts < 0.2 then
        return true
    end
    if MOUSE_match(xywh,blit_offs) and not mouse.last_LMB_state and mouse.LMB_state then  mouse.last_click_ts = clock end
  end  
  -----------------------------------------------------------------------
  function MOUSE_knob(obj_t, val, scale_func, default_val,blit_offs)
    if not blit_offs then blit_offs = 0 end
    if not obj_t then return end
    if (not mouse.last_LMB_state 
            and mouse.LMB_state
            and MOUSE_match(obj_t, blit_offs)
            and mouse.Alt_state)
        or MOUSE_DC(obj_t,blit_offs) 
        then
        return default_val
    end
    -- store context
      if not mouse.last_LMB_state 
        and mouse.LMB_state
        and MOUSE_match(obj_t, blit_offs) 
        and not mouse.Alt_state then
          mouse.context = obj_t.mouse_id
          mouse.context_val = val
      end
    -- app context 
      if mouse.context and mouse.context == obj_t.mouse_id 
        and mouse.last_LMB_state
        and mouse.LMB_state 
        and math.abs(mouse.dy) > 1 then
        return scale_func(mouse.context_val)
      end
    -- wheel
      if MOUSE_match(obj_t, blit_offs) and mouse.wheel_trig ~= 0 then
        return scale_func(val) 
      end
  end
  -----------------------------------------------------------------------
  function MOUSE_get()
    mouse.abs_x, mouse.abs_y = reaper.GetMousePosition()
    mouse.mx = gfx.mouse_x
    mouse.my = gfx.mouse_y
    mouse.LMB_state = gfx.mouse_cap&1 == 1
    mouse.RMB_state = gfx.mouse_cap&2 == 2
    --mouse.MMB_state = gfx.mouse_cap&64 == 64
    --mouse.Ctrl_LMB_state = gfx.mouse_cap&5 == 5
    mouse.Ctrl_state = gfx.mouse_cap&4 == 4
    mouse.Alt_state = gfx.mouse_cap&17 == 17 -- alt + LB
    mouse.Shift_state = gfx.mouse_cap&8 == 8
    mouse.wheel = gfx.mouse_wheel
    if not mouse.last_obj then mouse.last_obj = 0 end
    if not mouse.last_obj2 then mouse.last_obj2 = 0 end
    -- move state/tooltip state clear
      if not mouse.last_mx or not mouse.last_my or (mouse.last_mx ~= mouse.mx and mouse.last_my ~= mouse.my) then
        mouse.move = true
        mouse.show_tooltip = false
       else
        mouse.move = false
      end

    -- wheel
      if mouse.last_wheel then mouse.wheel_trig = (mouse.wheel - mouse.last_wheel) end
      if not mouse.wheel_trig then mouse.wheel_trig = 0 end

    -- dx/dy
      if (not mouse.last_LMB_state and mouse.LMB_state) then
        mouse.LMB_stamp_x = mouse.mx
        mouse.LMB_stamp_y = mouse.my
      end
      if mouse.LMB_state then
        mouse.dx = mouse.mx - mouse.LMB_stamp_x
        mouse.dy = mouse.my - mouse.LMB_stamp_y
      end
    if run_l < 2 then goto skip_mouse_mod end
  --------------------------------------------------------------    
    -- main controls
    if run_l == 2 then 
    
      -- display info peaks
        if MOUSE_match(obj.peaks_disp1) or MOUSE_match(obj.peaks_disp2) and not mouse.LMB_state then 
          mouse.context_match = 'peaks display' 
         elseif MOUSE_match(obj.info)  and not mouse.LMB_state then 
          mouse.context_match = 'info vrs' 
         elseif MOUSE_match(obj.get_b)  and not mouse.LMB_state then 
          mouse.context_match = 'get_b'   
         else
          mouse.context_match = ''
        end
        
      -------------------------------
      -- mode sw
        if MOUSE_button(obj.mode_sw) then 
          update_gfx = true
          trig_process = 1
          update_takes_data_env = true
          data.mode = data.mode + 1 if data.mode > 2 then data.mode = 0 end
          Data_Update()
        end
      -- envscaling
        local ret = MOUSE_knob(obj.kn_scaling, data.scaling, scaling.scaling_env, Data_defaults().scaling)
        if ret then 
          update_gfx = true
          data.scaling = ret
          Data_Update()
        end
      -- smooth
        local ret = MOUSE_knob(obj.smooth_env, data.smooth_env, scaling.smooth_env, Data_defaults().smooth_env)
        if ret then 
          update_gfx = true
          data.smooth_env = ret
          Data_Update()
        end        
      -- rms/fft
        local ret = MOUSE_knob(obj.kn_rms_fft, 
          F_conv_int_to_logic(data.mode == 0, data.fft_size, data.custom_window), 
          F_conv_int_to_logic(data.mode == 0, scaling.fft, scaling.rms), 
          F_conv_int_to_logic(data.mode == 0, Data_defaults().fft_size, Data_defaults().custom_window)  )
        if ret then 
          update_gfx = true
          if data.mode == 0 then data.custom_window = ret else data.fft_size = ret end
          Data_Update()
        end    
      -- fft hp
        local ret = MOUSE_knob(obj.fft_HP, data.fft_HP, scaling.fft_filt, Data_defaults().fft_HP)
        if ret then 
          update_gfx = true
          data.fft_HP = ret
          if data.fft_HP > data.fft_LP then data.fft_LP = data.fft_HP end
          Data_Update()
        end    
      -- fft lp
        local ret = MOUSE_knob(obj.fft_LP, data.fft_LP, scaling.fft_filt, Data_defaults().fft_LP)
        if ret then 
          update_gfx = true
          data.fft_LP = ret
          if data.fft_HP > data.fft_LP then data.fft_HP = data.fft_LP end
          Data_Update()
        end     
      ------------------------------------- 
      -- mode sw points
        if MOUSE_button(obj.mode_sw_points) then 
          update_gfx = true
          trig_process = 1
          trig_process_minor = true
          data.mode_points = data.mode_points + 1 
          if data.mode_points > 1 then data.mode_points = 0 end
          Data_Update()
          
          update_takes_data_points = true
        end
      -- rms/fft
        local ret = MOUSE_knob(obj.min_distance, data.min_distance, scaling.min_distance, Data_defaults().min_distance)
        if ret then 
          update_gfx = true
          data.min_distance = ret
          Data_Update()
          update_takes_data_points = true
        end         
        
      ----------------------------------                   
      -- get
        if MOUSE_button(obj.get_b) then trig_process = 1 update_takes_data_main = true end
      
    end
  --------------------------------------------------------------
  -- release stuff
    if mouse.last_LMB_state and not mouse.LMB_state  then
      -- upd envelopes
        if mouse.context_last and (
            mouse.context_last == obj.kn_scaling.mouse_id 
            or mouse.context_last == obj.kn_rms_fft.mouse_id
            or mouse.context_last == obj.smooth_env.mouse_id
            or (mouse.context_last == obj.fft_HP.mouse_id and (data.mode == 1 or data.mode == 2))
            or (mouse.context_last == obj.fft_LP.mouse_id and (data.mode == 1 or data.mode == 2))
          )
          then
          update_gfx = true
          trig_process = 1
          update_takes_data_env = true
          mouse.context_last = ''
        end
      -- upd points
        if mouse.context_last and (  
        mouse.context_last == obj.min_distance.mouse_id
        )
        then    
          update_gfx = true
          trig_process = 1
          update_takes_data_points = true
          mouse.context_last = ''
        end           
    end
  --------------------------------------------------------------  
    ::skip_mouse_mod::
    
    if run_l == 0 or run_l == 1 then
      if MOUSE_button(obj.lc_txt) then 
        local ret = reaper.MB(
[[

All MPL stuff with GUI will get a protection like this in near future. 
Once purchased you don`t need to puchase other scripts.
And your license info stored in you REAPER configuration (will not lost after import/export).

After purchasing there will be more privileges for you, if you will need some advanced features or you want me to fix some bugs/behaviour.
By giving some money you support my efforts to do existing or hidden REAPER features better and usable.

Procedure of puchasing MPL`s stuff looks like this:
1) after click "Yes" paypal page will be opened in your default browser, this link used also for donations;
2) send $10;
3) send email to m.pilyavskiy@gmail.com (so I`ll know where to send activation code);
4) wait for email response with activation code. If you didn`t get one, check your spam folder or PM me at any resource mentioned (click on version in top right corner of script GUI);
5) click "Already purchased" and paste activation code;
6) enjoy.

If you have problems with PayPal, you can PM me at Cockos forum or m.pilyavskiy@gmail.com.

Purchase MPL scripts?

]], name..': purchasing',3)
        if ret == 6 then F_open_URL('https://www.paypal.me/donate2mpl') end
      end
      if MOUSE_button(obj.lc_txt2) then  
        local retval, retvals_csv = reaper.GetUserInputs( name, 1, 'License code,extrawidth=400','' )
        if retval then 
          r.SetExtState( 'MPL_LC', 'lickey', retvals_csv, true )
          force_upd = true
        end
      end
      
    end
    if run_l == 1 and MOUSE_button(obj.lc_txt3) then run_l = 2 end
    -- info button
      if MOUSE_button(obj.info) then MENU_main() end
    --------------------------------------------------------------  
    -- reset mouse context/doundo
      if mouse.context ~= '' then mouse.context_last = mouse.context end
      if (mouse.last_LMB_state and not mouse.LMB_state)
        or (mouse.last_RMB_state and not mouse.RMB_state) then
        mouse.last_obj = 0
        mouse.context = ''
        mouse.context_val = ''
        mouse.last_obj_val = nil
        mouse.dx = 0
        mouse.dy = 0
      end
--------------------------------------------------------------
    -- mouse release
      mouse.last_LMB_state = mouse.LMB_state
      mouse.last_RMB_state = mouse.RMB_state
      mouse.last_MMB_state = mouse.MMB_state
      mouse.last_Ctrl_LMB_state = mouse.Ctrl_LMB_state
      mouse.last_Ctrl_state = mouse.Ctrl_state
      mouse.last_Alt_state = mouse.Alt_state
      mouse.last_wheel = mouse.wheel
      mouse.last_mx = mouse.mx
      mouse.last_my = mouse.my
  end  
-----------------------------------------------------------------------     
  function ENGINE_prepare_takes() local item, take
    local count_items = r.CountSelectedMediaItems()
    if not count_items or count_items < 2 then return end
    
    -- store GUIDs
      local GUIDs = {}
      local min_pos =  reaper.GetProjectLength( 0 )
      local max_pos = 0
      local last_item_len, item_len
      glue = false
      for tr_id = 1, r.CountTracks(0) do
        local tr= r.GetTrack(0,tr_id-1)   
        for it_id = 1, reaper.CountTrackMediaItems( tr ) do
          local item =  reaper.GetTrackMediaItem( tr, it_id-1 )
          item_len = r.GetMediaItemInfo_Value(item, 'D_POSITION')
          if last_item_len and item_len ~= last_item_len then glue = true end
          last_item_len = item_len
          min_pos = math.min(min_pos, r.GetMediaItemInfo_Value(item, 'D_POSITION'))
          max_pos = math.max(max_pos, r.GetMediaItemInfo_Value(item, 'D_POSITION') + r.GetMediaItemInfo_Value(item, 'D_LENGTH'))
          if  reaper.IsMediaItemSelected( item ) and not reaper.TakeIsMIDI(reaper.GetActiveTake(item)) then 
            if not GUIDs[reaper.GetTrackGUID( tr )] then GUIDs[reaper.GetTrackGUID( tr )] = {} end
            GUIDs[reaper.GetTrackGUID( tr )][r.BR_GetMediaItemGUID( item )] = {}
          end
        end    
      end  
          
    -- check  time selection
      local st_TS, end_TS = reaper.GetSet_LoopTimeRange2( 0, false, false, 0, 0, false )
      if st_TS ~= min_pos or end_TS ~= max_pos then glue = true end
      
    -- set time selection 
      reaper.GetSet_LoopTimeRange2( 0, true, false, min_pos, max_pos, false )
      
     
      if not glue then return true end
      
    -- glue items inside time selection
      local new_GUIDs = {}
      for tr_GUID in pairs(GUIDs) do
        reaper.Main_OnCommand(40289, 0) -- unselect all items
        for it_GUID in pairs(GUIDs[tr_GUID]) do
          local item =  reaper.BR_GetMediaItemByGUID( 0, it_GUID )
          reaper.SetMediaItemSelected(item, true)
        end
        reaper.Main_OnCommand(41588, 0) -- glue include time selection
        local cur_item =  reaper.GetSelectedMediaItem( 0, 0)
        if cur_item then new_GUIDs[#new_GUIDs+1] = reaper.BR_GetMediaItemGUID( cur_item ) end
      end
    
    -- restore item selection
      for i = 1, #new_GUIDs do reaper.SetMediaItemInfo_Value(reaper.BR_GetMediaItemByGUID( 0, new_GUIDs[i] ), 'B_UISEL', 1) end
      
    reaper.UpdateArrange()
    return true
  end      
    
    --[[-----------------------------------------------------------------------------   
    function ENGINE_GlueSelectedItemsIndependently()
        
      
      reaper.Main_OnCommand(40289, 0) -- unselect all items
      -- add new items to selection
        for i = 1, #new_GUIDs do
          local item = reaper.BR_GetMediaItemByGUID( 0, new_GUIDs[i] )
          if item then reaper.SetMediaItemSelected(item, true) end
        end
      reaper.UpdateArrange() 
    end  
    
    ENGINE_GlueSelectedItemsIndependently() ]]
    
    --[[r.Main_OnCommand(41844,0) -- clear stretch markers
    r.Main_OnCommand(40652,0) -- set item rate to 1
    r.Main_OnCommand(40047,0) -- Peaks: Build any missing peaks
    
    
    -- check for unglued reference item/take, is MIDI
      local realcnt = 0
      local ref_item = r.GetSelectedMediaItem(0, 0)
      local ref_track = r.GetMediaItemTrack(ref_item)
      local ref_pos = r.GetMediaItemInfo_Value(ref_item, 'D_POSITION')
      local ref_len = r.GetMediaItemInfo_Value(ref_item, 'D_LENGTH')
      reaper.SetMediaItemInfo_Value( ref_item, 'B_LOOPSRC', 1 )
      if not r.TakeIsMIDI(r.GetActiveTake(ref_item)) then realcnt = 1 end
      for i = 2, count_items do
        local item = r.GetSelectedMediaItem(0, i-1)
        --reaper.SetMediaItemInfo_Value( item, 'B_LOOPSRC', 0 )        
        local track = r.GetMediaItemTrack(item)
        local take = r.GetActiveTake(item)
        if not r.TakeIsMIDI(take) then realcnt = realcnt + 1 end
        if track == ref_track then  r.MB('Only one reference take allowed. Glue takes before aligning',name, 0) return  end  
      end
     
    -- enough audio takes
      if realcnt < 2 then return end
      
]]
      
  --------------------------------------------------------------------
  function MENU_main()
    local actions = {  
      --{name='#[About]'},
      {name=  name..' thread on Cockos forum',
        func = function() F_open_URL('http://forum.cockos.com/showthread.php?t=179544' ) end},
      {name='Show changelog',
        func = function() r.ClearConsole() msg(changelog) end},     
      {name='MPL @ SondCloud',
        func = function() F_open_URL('http://soundcloud.com/mp57') end},
      {name='MPL @ VK',
        func = function() F_open_URL('http://vk.com/michael_pilyavskiy') end},
      {name='MPL @ PDJ',
        func = function() F_open_URL('http://promodj.com/MichaelPilyavskiy') end}, 
      
      {name='|#Preferences'},
      {name='Glue takes independently before analyze',
        func = function() data.glue_before_analyze = math.abs(1-data.glue_before_analyze) Data_Update() end,         
        val = data.glue_before_analyze}
    }  
    gfx.x, gfx.y = mouse.mx,mouse.my
    local str = ''
    for i = 1, #actions  do
      local check
      if actions[i].val and actions[i].val == 1 then check = '!' else check = '' end
      str = str..check..actions[i].name..'|'
    end
    local ret = gfx.showmenu(str)
    if ret > 0 and ret <= #actions then assert(load(actions[ret].func)) end
  end
  --------------------------------------------------------------------  
  function ENGINE_Update()
    local ret
    if trig_process ~= 2 then return end
    
    if update_takes_data_main then
      ret = ENGINE_prepare_takes()
      if ret then
        ENGINE_GetTakes()
        update_takes_data_env = true
        update_takes_data_points = true
      end
    end
            
    if update_takes_data_env then 
      ENGINE_UpdateTakeEnvelopes() 
      update_takes_data_points = true 
      update_peaks = true
    end
            
    if update_takes_data_points then 
      ENGINE_UpdateTakePoints() 
      update_points = true 
    end
            
    trig_process = nil
    update_takes_data_main = nil
    update_takes_data_env = nil
    update_takes_data_points = nil  
  end    
  --------------------------------------------------------------------
  function Run()
    F_xywh_gfx()
    if run_l == 0 or run_l == 1 then
      if run_l == 0 then cnt = math.floor(os.clock() - ts) end      
      GUI_backgr(gfx.w,gfx.h)
      F_frame(obj.info)
      F_frame(obj.lc_txt)
      F_frame(obj.lc_txt2)
      obj.lc_txt3.txt = 'Continue after '..5-cnt..' seconds'
      if cnt >= 5 then obj.lc_txt3.txt = 'Continue' end
      F_frame(obj.lc_txt3)
      gfx.update()
      MOUSE_get()
      if cnt > 5 and run_l ~= 2 then run_l = 1 end
      if char ~= -1 then r.defer(Run) else gfx.quit() end
     elseif run_l == 2 then
  
      clock = os.clock ()
      
      -- upd gfx
        check_cnt = r.GetProjectStateChangeCount(0)
        if not last_check_cnt or last_check_cnt ~= check_cnt then  update_gfx = true end
        last_check_cnt = check_cnt
           
      -- perform updates
        if trig_process then ENGINE_Update() end
        
        Objects_Update()
        GUI_draw()
        MOUSE_get()
        
      -- shortcuts
        char = gfx.getchar()
        if char == 32 then r.Main_OnCommandEx(40044, 0,0) end   -- space: play/pause
        if char == 27 then gfx.quit() end                       -- escape
        if char ~= -1 then r.defer(Run) else gfx.quit() end     -- check is ReaScript GUI opened
      
   end
  end
  -----------------------------------------------------------------------    
  function ENGINE_GetTakePoints(take_t)
    -- ValidPtr
      local take =   reaper.GetMediaItemTakeByGUID( 0, take_t.tk_GUID)    
      if not take then return end     
       
    -- init points buf 
      local buf_sz = takes.env_buf_sz
      local buf = reaper.new_array(buf_sz)
      buf[1], buf[buf_sz] = 1,1 -- edge points
      local min_dist_smpls = F_limit(math.floor(scaling.min_distance(data.min_distance, 2) / takes.sec_per_bufvalue), 1)
      
      sens = 0.1
      --msg('min_dist_smpls'..min_dist_smpls)
      --msg('buf_sz'..buf_sz)
    -- transient mode
      if data.mode_points == 0 then
        local i = 1
        repeat
          i = i + 1          
          if i < take_t.env_normalized.get_alloc() then 
            if take_t.env_normalized[i] - take_t.env_normalized[i-1] > sens then 
              buf[i] = 1
              i = i + min_dist_smpls
              --msg(i)
            end 
          end
        until i > buf_sz
      end
    
    take_t.points = buf.table()
    buf.clear()
  end
  -----------------------------------------------------------------------     
  function ENGINE_UpdateTakeEnvelopes()
    if not takes then return end
    for i = 1, #takes do ENGINE_GetTakeData(takes[i]) end
    if takes[1] then takes.env_buf_sz = takes[1].env_normalized.get_alloc() end
    if takes[1] then takes.sec_per_bufvalue = takes[1].item_len / takes.env_buf_sz end
    update_peaks = true
  end
  -----------------------------------------------------------------------     
  function ENGINE_UpdateTakePoints()
    if not takes then return end
    for i = 2, #takes do ENGINE_GetTakePoints(takes[i]) end
    update_points = true
  end  
  -----------------------------------------------------------------------
  function GUI_Analize()
    GUI_backgr(_,_,0.92)
    local str = 'Analyzing takes. Please wait...'
    gfx.setfont(1, obj.fontname, obj.fontsize)
    gfx.x = (obj.main_w - gfx.measurestr(str))/2
    gfx.y = (obj.main_h-gfx.texth)/2
    gfx.a = 0.8
    gfx.drawstr(str)
  end
  -----------------------------------------------------------------------
  function F_open_URL(url) local OS = r.GetOS() if OS=="OSX32" or OS=="OSX64" then  os.execute("open ".. url) else  os.execute("start ".. url)  end  end
  --------------------------------------------------------------------
  function F_vrs_check()
    appvrs = r.GetAppVersion()
    appvrs = appvrs:match('[%d%p]+')
    if not appvrs then return end
    appvrs =  tonumber(appvrs)
    if not appvrs or appvrs < reavrs then return end
    return true
  end
  ----------------------------------------------------------------------- 
    function ENGINE_GetTakes() 
      takes = {}
      for i =1, reaper.CountSelectedMediaItems() do 
        local item = reaper.GetSelectedMediaItem(0, i-1)
        local take = reaper.GetActiveTake(item)
        if not reaper.TakeIsMIDI(take) then 
          takes[#takes+1] = { len = reaper.GetMediaItemInfo_Value( item, 'D_LENGTH'),
                              pos  = reaper.GetMediaItemInfo_Value( item, 'D_POSITION'),
                              tk_GUID = reaper.BR_GetMediaItemTakeGUID(take),
                              name = ({reaper.GetSetMediaItemTakeInfo_String(take, 'P_NAME', '', false)})[2],
                              offset =  reaper.GetMediaItemTakeInfo_Value(take, 'D_STARTOFFS'),
                              rate = reaper.GetMediaSourceSampleRate(reaper.GetMediaItemTake_Source(take)),
                              vol  = reaper.GetMediaItemTakeInfo_Value(take, 'D_VOL') ,
                              item = item,
                              item_len = reaper.GetMediaItemInfo_Value(item, 'D_LENGTH'),
                              SR = reaper.GetMediaSourceSampleRate(reaper.GetMediaItemTake_Source(take)),
                              numch = reaper.GetMediaSourceNumChannels(reaper.GetMediaItemTake_Source(take))
                              }
        end
      end
      takes.active_dub = 2
    end  
-----------------------------------------------------------------------   
  function ENGINE_GetTakeData(take_t) 
    -- ValidPtr
      local take =   reaper.GetMediaItemTakeByGUID( 0, take_t.tk_GUID)    
      if not take then return end     
      
    -- mode
      local window_sec ,window_smpls
      if data.mode == 0 then 
        window_sec = scaling.rms(data.custom_window,2) 
        window_smpls = math.ceil(window_sec*take_t.SR)      
       else 
        window_sec = data.CALC_fft_size/take_t.SR  
        window_smpls = data.CALC_fft_size
      end
    
    -- seek accessor
      local sum_t = {}
      local aa_accessor = reaper.CreateTakeAudioAccessor(take)
      for read_pos = 0, take_t.item_len, window_sec do 
        local buffer = reaper.new_array(window_smpls*take_t.numch)
        local buffer_com = reaper.new_array(window_smpls*take_t.numch)                 
        reaper.GetAudioAccessorSamples(aa_accessor, take_t.SR, take_t.numch, read_pos, window_smpls, buffer)            
    
        -- merge interleaved smpls
          for i = 1, window_smpls*take_t.numch - 1, take_t.numch do
            buffer_com[i] = buffer[i]
            for ch = 1, take_t.numch-1 do buffer_com[i] = buffer_com[i] + buffer[i+ch]  end
            buffer_com[i] = buffer_com[i] / take_t.numch
            buffer_com[i+1] = 0
          end
          
        local sum_com = 0
        
        -- Get FFT sum of bins in defined range
          if data.mode == 1 or data.mode == 2 then  
            buffer_com.fft_real(data.CALC_fft_size, true, 1)
            local buffer_com_t = buffer_com.table(1,data.CALC_fft_size, true)
            for i = math.floor(data.fft_HP*data.CALC_fft_size), math.floor(data.fft_LP*data.CALC_fft_size) do 
              if buffer_com_t[i] then sum_com = sum_com + math.abs(buffer_com_t[i]) end  
            end  
          end
          
        -- Get RMS sum in defined range
          if data.mode == 0 or data.mode == 2 then  
            local buffer_com_t = buffer_com.table(1,window_smpls, true)
            for i = 1, window_smpls do sum_com = sum_com + math.abs(buffer_com_t[i]) end  
          end        
          
          table.insert(sum_t, sum_com)
          
        buffer.clear()
        buffer_com.clear()  
      end
    
    -- destroy aa form out buffer 
      reaper.DestroyAudioAccessor(aa_accessor)
      local out_buf = reaper.new_array(#sum_t)
      out_buf.copy(sum_t, 0, #sum_t, 1 )
      
    -- normalize table
      local max_com = 0
      for i =1, out_buf.get_alloc() do max_com = math.max(max_com, out_buf[i]) end
      local com_mult = 1/max_com      
      for i =1, out_buf.get_alloc() do out_buf[i]= out_buf[i]*com_mult  end          
    -- scal table
      for i =1, out_buf.get_alloc() do out_buf[i]= out_buf[i]^scaling.scaling_env(data.scaling,2)  end
    -- smooth table
      for i =2, out_buf.get_alloc() do out_buf[i]= out_buf[i] - (out_buf[i] - out_buf[i-1])*scaling.smooth_env(data.smooth_env, 2)  end    
    
    take_t.env_normalized = out_buf
    take_t.norm_scaling = max_com
  end                    
  
  ------------------------------------------------------------------  
  if not F_vrs_check() then reaper.MB('Install latest REAPER and SWS extension releases.\nScript supports REAPER '..reavrs..' and later, SWS 2.7.2 and later ', name, 0) goto skip end
  ts = os.clock()
  r.atexit()
  r.ClearConsole() 
  Data_init_scaling()
  Data_LoadConfig()
  Data_Update() 
  GUI_init_gfx()
  update_gfx = true
  update_gfx_onstart = true
  Run()
  ::skip::
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
--[[--------------------------------------------------------------------- 
----------------------------------------------------------------------- 
-----------------------------------------------------------------------   
 
 local load_preset_on_start = 'current'
 
   -- 'current' - load last config
   -- 'default' - load default config
   -- 3 - load preset #3
-----------------------------------------------------------------------   
  f unction A2_DEFINE_dynamic_variables()
    if not data2.current_take then data2.current_take = 2 end

    -- green / detection point  
      data2.scaling_pow = F_convert(math.abs(1-data.current.scaling_pow_norm), 0.1, 0.75)
      data2.threshold = F_convert(data.current.threshold_norm, 0.1,0.4)     
      data2.rise_area = F_convert(data.current.rise_area_norm, 0.1,0.5)
      data2.risefall = F_convert(data.current.risefall_norm, 0.1,0.8)
      data2.risefall2 = F_convert(data.current.risefall2_norm, 0.05,0.8)    
      data2.filter_area = F_convert(data.current.filter_area_norm, 0.1,2)
          
    -- blue / envelope
      data2.custom_window = F_convert(data.current.custom_window_norm, 0.005, 0.2)
      data2.fft_size = math.floor(2^math.floor(F_convert(data.current.fft_size_norm,7,10)))
      if data2.fft_LP == nil then data2.fft_LP = data2.fft_size end
      data2.fft_HP = F_limit(math.floor(F_convert(data.current.fft_HP_norm, 1, data2.fft_size)), 1, data2.fft_LP-1)
      data2.fft_LP =  1+F_limit(math.floor(F_convert(data.current.fft_LP_norm, 1, data2.fft_size)), data2.fft_HP+1, data2.fft_size)
      data2.smooth = data.current.smooth_norm
    
    -- red / algo
      data2.search_area = F_convert(data.current.search_area_norm, 0.05, 2) 
      
    --othert
      data2.play_pos = reaper.GetPlayPosition(0)
  end
  
-----------------------------------------------------------------------  
  f nction F_convert(val, min, max)
    return (max-min) *val + min
  end
  

  
        
-----------------------------------------------------------------------  
  f unction ENGINE_get_take_data_points2(inputarray, window_sec) -- micro mode
    --local arr_size,points
    
    if inputarray == nil then return end
    
    
    arr_size = inputarray.get_alloc()    
    if arr_size <=1 then return end
    
    inputarray_scaled = reaper.new_array(arr_size)
    for i = 1, arr_size do inputarray_scaled[i] = inputarray[i]^data2.scaling_pow end
    
    points = reaper.new_array(arr_size)
    
    --  clear arr val
      for i = 1, arr_size do points[i] = 0 end  
    
    -- parameters
      filter_area_wind = math.floor(data2.filter_area / window_sec)
      risearea_wind = math.floor(data2.rise_area / window_sec)
      
      -------------
      -------------
      
    -- check for rise
      for i = 1, arr_size - risearea_wind do 
        arr_val_i = inputarray_scaled[i]
        max_val = 0
        for k = i, i + risearea_wind do
          arr_val_k = inputarray_scaled[k]
          max_val = math.max(max_val,arr_val_k)
          if last_max_val == nil or last_max_val ~= max_val then max_val_id = k end
          last_max_val = max_val
        end
        if max_val - arr_val_i > data2.risefall then
          
          arr_val_i2 = inputarray[i]
          max_val2 = 0
          for k = i, i + risearea_wind do
            arr_val_k2 = inputarray[k]
            max_val2 = math.max(max_val2,arr_val_k2)
            if last_max_val2 == nil or last_max_val2 ~= max_val2 then 
              max_val_id2 = k end
            last_max_val2 = max_val2
          end
          if max_val2 - arr_val_i2 > data2.risefall2 then          
          
            points[max_val_id] = 1
          end
        end
      end
    
    -- check for fall
      for i = 1, arr_size - risearea_wind do 
        arr_val_i = inputarray_scaled[i]
        min_val = 1
        for k = i, i + risearea_wind do
          arr_val_k = inputarray_scaled[k]
          min_val = math.min(min_val,arr_val_k)
          if last_min_val == nil or last_min_val ~= min_val then min_val_id = k end
          last_min_val = max_val
        end
        if arr_val_i - min_val > data2.risefall then
          arr_val_i2 = inputarray[i]
          min_val2 = 1
          for k = i, i + risearea_wind do
            arr_val_k2 = inputarray[k]
            min_val2 = math.min(min_val2,arr_val_k2)
            if last_min_val2 == nil or last_min_val2 ~= min_val2 then 
              min_val_id2 = k end
            last_min_val2 = max_val2
          end
          if arr_val_i2 - min_val2 > data2.risefall2 then        
            points[min_val_id] = 1
          end
        end
      end 
            
      -------------
      -------------
      
    -- filter points threshhld
      for i = 1, arr_size do
        if inputarray_scaled[i] < data2.threshold 
          then 
          points[i] = 0 end
      end 
            
    -- filter points area
      for i = 1, arr_size-1 do 
        if points[i] == 1 then
          point_i_val = inputarray_scaled[i]
          max_sa = i + 1 + filter_area_wind
          if max_sa > arr_size then max_sa = arr_size end
          for k = i + 1, max_sa do
            if points[k] == 1 then points[k] = 0 end
          end       
        end
      end 

      -------------
      -------------
                        
    -- prepare for output
      for i = 2, filter_area_wind do  points[i] = 0 end
      points[1] = 1
      points[arr_size] = 1
      
    return points    
  end
 
-----------------------------------------------------------------------    
  f unction F_find_arrays_com_diff(ref_array, ref_array_offset, dub_array, get_ref_block_rms)
    local dub_array_size = dub_array.get_alloc()
    local ref_array_size = ref_array.get_alloc()
    local endpoint,ref_rms
    local com_difference = 0
    if ref_array_offset + dub_array_size > ref_array_size then endpoint = ref_array_size - ref_array_offset
      else endpoint = dub_array_size end
      
    for i = 1, endpoint do
      com_difference = com_difference + math.abs(ref_array[i + ref_array_offset - 1 ]-dub_array[i])
    end
    
    if get_ref_block_rms ~= nil and get_ref_block_rms then
      ref_rms = 0
      for i = 1, endpoint do
        ref_rms = ref_rms + math.abs(ref_array[i + ref_array_offset - 1 ])
      end
      ref_rms = ref_rms / endpoint
    end
    
    return com_difference, ref_rms
  end   
   
-----------------------------------------------------------------------   
  f unction F_find_min_value(t)
    local min_val_id, min_val, min_val0
    min_val0 = math.huge
    for i = 1, #t do
      min_val = math.min(min_val0, t[i])
      if min_val ~= min_val0 then 
        min_val0 = min_val
        min_val_id = i
      end
    end
    return min_val_id
  end

-----------------------------------------------------------------------   
  f unction F_find_max_value(t)
    local max_val_id, max_val, max_val0
    max_val0 =0
    for i = 1, #t do
      max_val = math.max(max_val0, t[i])
      if max_val ~= max_val0 then 
        max_val0 = max_val
        max_val_id = i
      end
    end
    return max_val_id
  end
      
-----------------------------------------------------------------------   
    f unction F_stretch_array(src_array, new_size)
      local src_array_size = src_array.get_alloc()
      local coeff = (src_array_size - 1) / (new_size  - 1)
      if new_size <= 1 then return src_array end
      local out_array = reaper.new_array(new_size)
      if new_size < src_array_size or new_size > src_array_size then
        for i = 0, new_size - 1 do 
          src_idx = math.floor(i * coeff) + 1
          src_idx = math.floor(F_limit(src_idx, 1, src_array_size))
          out_array[i+1] = src_array[src_idx]
        end
        return out_array
       elseif new_size == src_array_size then 
        out_array = src_array 
        return out_array
      end    
      return out_array    
    end
    
-----------------------------------------------------------------------       
  f unction F_stretch_array2(src_array, src_mid_point, stretched_point)
    if src_array == nil or src_mid_point == nil or stretched_point == nil 
      then return end      
    local src_array_size = src_array.get_alloc()
    local out_arr = reaper.new_array(src_array_size)    
    local src_arr_pt1_size = src_mid_point - 1
    local src_arr_pt2_size = src_array_size-src_mid_point + 1    
    local out_arr_pt1_size = stretched_point - 1
    local out_arr_pt2_size = src_array_size-stretched_point + 1 
    --msg(src_arr_pt1_size) 
    if   src_arr_pt1_size <= 0 then src_arr_pt1_size = 1 end
    if   src_arr_pt2_size <= 0 then src_arr_pt2_size = 1 end
    local src_arr_pt1 = reaper.new_array(src_arr_pt1_size)
    local src_arr_pt2 = reaper.new_array(src_arr_pt2_size)    
    src_arr_pt1.copy(src_array,--src, 
                            1,--srcoffs, 
                            src_arr_pt1_size,--size, 
                            1)--destoffs])  
    src_arr_pt2.copy(src_array,--src, 
                            src_mid_point,--srcoffs, 
                            src_arr_pt2_size,--size, 
                            1)--destoffs])            
    local out_arr_pt1 = F_stretch_array(src_arr_pt1, out_arr_pt1_size)
    local out_arr_pt2 = F_stretch_array(src_arr_pt2, out_arr_pt2_size)    
    out_arr.copy(out_arr_pt1,--src, 
                 1,--srcoffs, 
                 out_arr_pt1_size,--size, 
                 1)--destoffs]) 
    out_arr.copy(out_arr_pt2,--src, 
                 1,--srcoffs, 
                 out_arr_pt2_size,--size, 
                 out_arr_pt1_size + 1)--destoffs]) 
                 
    return   out_arr               
  end  


-----------------------------------------------------------------------          
  f unction ENGINE_compare_data2_alg1(ref_arr_orig, dub_arr_orig, points, window_sec) 
      local st_search, end_search
      
      if ref_arr_orig == nil then return end
      if dub_arr_orig == nil then return end
      if points == nil then return end
      
      local ref_arr_size = ref_arr_orig.get_alloc()  
      local dub_arr_size = dub_arr_orig.get_alloc() 
      
      ref_arr = reaper.new_array(ref_arr_size)
      for i = 1, ref_arr_size do ref_arr[i] = ref_arr_orig[i]^data2.scaling_pow end
      
      dub_arr = reaper.new_array(dub_arr_size)
      for i = 1, dub_arr_size do dub_arr[i] = dub_arr_orig[i]^data2.scaling_pow end
      
      
      local sm_table = {}    
          
      search_area = math.floor(data2.search_area / window_sec)
              
      -- get blocks
        local block_ids = {}
        for i = 1, dub_arr_size do
          if points[i] == 1 then 
            block_ids[#block_ids+1] = {['orig']=i} end
        end    
        
      -- loop blocks
        for i = 1, #block_ids - 2 do
          -- create fixed block
            
            point1 = block_ids[i].orig
            point2 = block_ids[i+1].orig
            point3 = block_ids[i+2].orig
            
              if i >= 1 then
                P1_diff = 0
                P2_fant = point2-point1+1
                P3_fant = point3 - point1 + 1 -- arr size
                fantom_arr = reaper.new_array(P3_fant)            
                fantom_arr.copy(dub_arr,--src, 
                                point1,--srcoffs, 
                                P3_fant,--size, 
                                1)--destoffs])
              end
         
            
          -- loop possible positions
            local min_block_len = 3
            search_pos_start = P2_fant - search_area
            if search_pos_start < min_block_len then search_pos_start = min_block_len end
            search_pos_end = P2_fant + search_area
            if search_pos_end > P3_fant - min_block_len then search_pos_end = P3_fant - min_block_len end    
            if (search_pos_end-search_pos_start+1) > min_block_len then
              
              diff = reaper.new_array(search_pos_end-search_pos_start+1)
              for k = search_pos_start, search_pos_end do
                fantom_arr_stretched = F_stretch_array2(fantom_arr, P2_fant, k)
                diff[k - search_pos_start+1] = F_find_arrays_com_diff(ref_arr, point1, fantom_arr_stretched)
              end
              block_ids[i+1].stretched = F_find_min_value(diff) + search_pos_start 
                - 1 - P1_diff + point1
              sm_table[#sm_table+1] =  
                    {block_ids[i+1].stretched *  window_sec,
                     (-1+block_ids[i+1].orig) * window_sec}
            end
            fantom_arr.clear()
        end -- end loop blocks
        
      return sm_table
  end   

              
----------------------------------------------------------------------- 
  f unction ENGINE_compare_data2_alg2(ref_arr_orig, dub_arr_orig, points, window_sec) 
      local st_search, end_search
      
      if ref_arr_orig == nil then return end
      if dub_arr_orig == nil then return end
      if points == nil then return end
      
      local ref_arr_size = ref_arr_orig.get_alloc()  
      local dub_arr_size = dub_arr_orig.get_alloc()       
      ref_arr = reaper.new_array(ref_arr_size)
      for i = 1, ref_arr_size do ref_arr[i] = ref_arr_orig[i]^data2.scaling_pow end      
      dub_arr = reaper.new_array(dub_arr_size)
      for i = 1, dub_arr_size do dub_arr[i] = dub_arr_orig[i]^data2.scaling_pow end
            
      local sm_table = {}    
      search_area = math.floor(data2.search_area / window_sec)
              
      -- get blocks
         block_ids = {}
        for i = 1, dub_arr_size do
          if points[i] == 1 then 
            block_ids[#block_ids+1] = {['orig']=i} end
        end    
        
      -- loop blocks
        block_ids[1].str = 1
        for i = 2, #block_ids - 1 do
        -- create fixed block            
          point1 = block_ids[i-1].str
          point1_orig = block_ids[i-1].orig
          point2 = block_ids[i].orig
          point3 = block_ids[i+1].orig
          
          search_point = point2 - point1
          
        -- form fantom array
          fantom_arr_sz = point3 - point1          
          fantom_arr = reaper.new_array(fantom_arr_sz)          
          fantom_arr_pt1 = reaper.new_array(point2 - point1_orig)          
          fantom_arr_pt1.copy(dub_arr,--src,
                              point1_orig,--srcoffs,
                              point2 - point1_orig,--size,
                              1)--destoffs]) 
          fantom_arr_pt1_str = F_stretch_array(fantom_arr_pt1, point2-point1)                        
          fantom_arr.copy(fantom_arr_pt1_str,--src,
                          1,--srcoffs,
                          point2-point1,--size,
                          1)--destoffs])            
          fantom_arr.copy(dub_arr,--src,
                          point2,--srcoffs,
                          point3-point2,--size,
                          point2-point1+1)--destoffs])
          
        -- loop possible positions
          filter_area_wind = math.floor(data2.filter_area / window_sec)
          min_block_len = 20
          if min_block_len > filter_area_wind then min_block_len = filter_area_wind - 3 end
          search_start = search_point - search_area
            if search_start < min_block_len then search_start = min_block_len end
          search_end = search_point + search_area
            if search_end > fantom_arr_sz - min_block_len then search_end = fantom_arr_sz - min_block_len end         
        
          diff_t = {}
          for k = search_start, search_end do
            fantom_arr_stretched = F_stretch_array2(fantom_arr, search_point, k)
            diff_t[#diff_t+1] = F_find_arrays_com_diff(ref_arr, point1, fantom_arr_stretched)
          end 
          id_diff = F_find_min_value(diff_t)
          if not id_diff then id_diff = 0 end -- unknown bug > 1.120
          block_ids[i].str = id_diff + search_start + point1
          sm_table[#sm_table+1] =  {
            block_ids[i].str * window_sec,
            (-1+block_ids[i].orig) * window_sec }
        end -- loop blocks
      return sm_table       
      
  end          
  
                                        
-----------------------------------------------------------------------   
  f unction ENGINE_set_stretch_markers2(take_id, str_mark_table, val)
    if str_mark_table == nil then return nil end
    if takes_t ~= nil and takes_t[take_id] ~= nil then
      local take = reaper.SNM_GetMediaItemTakeByGUID(0, takes_t[take_id].guid)
      if take ~= nil then       
        
        reaper.DeleteTakeStretchMarkers(take, 0, #str_mark_table + 1)
       
        reaper.SetTakeStretchMarker(take, -1, 0, takes_t[take_id].offset)
        for i = 1, #str_mark_table do
          
          set_pos = str_mark_table[i][1]-(takes_t[take_id].pos-takes_t[1].pos)
          src_pos = str_mark_table[i][2]-(takes_t[take_id].pos-takes_t[1].pos) + takes_t[take_id].offset
          set_pos = src_pos - takes_t[take_id].offset - ((src_pos - takes_t[take_id].offset) - set_pos)*val
          
          
          if last_src_pos ~= nil and last_set_pos ~= nil then
            -- check for negative stretch markers
            if (src_pos - last_src_pos) / (set_pos - last_set_pos ) > 0 then
              reaper.SetTakeStretchMarker(take, -1, set_pos,src_pos)             
              last_src_pos = src_pos
              last_set_pos = set_pos
            end
           else
            reaper.SetTakeStretchMarker(take, -1, set_pos,src_pos)             
            last_src_pos = src_pos
            last_set_pos = set_pos
          end
          
        end
        reaper.SetTakeStretchMarker(take, -1, takes_t[take_id].len)
        
      end
    end
    reaper.UpdateArrange()
    return true
  end        
                  
                
-----------------------------------------------------------------------    
    -- proceed undo state
      if not app and last_app then reaper.Undo_OnStateChange('mpl Align takes' )end
      last_app = app
      
          
-----------------------------------------------------------------------
  f unction DEFINE_defaults()    
    local default = 
                  { 
                    name = 'Default',
                    knob_coeff = 0.01, -- knob sensivity
                    xpos = 100,
                    ypos = 100,
                    compact_view = 0, -- default mode
                    mode = 0, -- 0 - RMS / 1 - FFT
                    alg = 0,
                    custom_window_norm = 0, -- rms window    
                    fft_size_norm = 0.5,
                    fft_HP_norm = 0,
                    fft_LP_norm = 1,
                    smooth_norm = 0,
                    filter_area_norm =  0.1, -- filter closer points
                    rise_area_norm =    0.2, -- detect rise on this area
                    risefall_norm =     0.125, -- how much envelope rise/fall in rise area - for scaled env
                    risefall2_norm =    0.3, -- how much envelope rise/fall in rise area - for original env
                    threshold_norm =    0.1, -- noise floor for scaled env
                    scaling_pow_norm =  0.9, -- normalised RMS values scaled via power of this value (after convertion))
                    search_area_norm =  0.1
                  }
    
    local top_t = {    
      count_presets = 8}
      
    return default, top_t
  end   ]]
  
