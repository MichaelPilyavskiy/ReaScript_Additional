-- @description test_Looper
-- @version 1.0
-- @author MPL
-- @changelog
--    # test
-- @website http://forum.cockos.com/member.php?u=70694

  vrs = '1.0alpha3'
  name = 'MPL Looper'  
  
  ------------------------------------------------------------------   
--[[ changelog:
  1.0alpha3 23.01.2017
    # GUI: Rec button behavior: rec > rec:stop/play > stop playback
    + Prepare project: Set item mix behavior to always mix
  1.0alpha2 20.01.2017
    # GUI refresh: use defer cycles count
    + GUI: track controls/indicators split into static/dynamic function
    + Record: start recording on next marker
    + Record: stop recording on next marker if Transport:Record is on
    + Record: add 2 markers match record loop len
    + Prepare project: region length use project time signature and measures from config
    + Prepare project: Set record mode to normal
    + Prepare project: set time selection
    + Prepare project: Insert as many tracks as needed to match config track count
    + Prepare project: set 0 position time signature to project TS/tempo
    - KeyCommands disabled
  1.0alpha1 18.01.2017
    + GUI: basic GUI
    + Prepare project: set region for common loop
    + KeyCommands: '1-8' set arm to tracks
  ]]
  
  ------------------------------------------------------------------   
--[[   
  key commands  
    1-8         set arm to tracks
    (space)     play/stop
    +           record + loop    
]]
  ------------------------------------------------------------------ 
  function Data_defaults()
    local data = {
      window_x = 0,
      window_y = 0,
      window_w = 300, 
      window_h = 400,
      d_state = 0,
      track_cnt = 8,
      refresh_count = 3, -- defer cycles
      loopregion_shift = 1, -- measure
      loopregion_len = 8 -- measure
      }
    return data
  end
  --------------------------------------------------------------------     
  function ENGINE_enable_preview()
    local tr = reaper.GetSelectedTrack(0,0)
    if not tr then return end    
    reaper.SetMediaTrackInfo_Value( tr, 'I_RECARM', 1 )
    local bits_set=tonumber('111110'..'00000',2)
    reaper.SetMediaTrackInfo_Value( tr, 'I_RECINPUT', 4096+bits_set )                                                        
    reaper.SetMediaTrackInfo_Value( tr, 'I_RECMON', 1 )     
  end
  --------------------------------------------------------------------   
  function F_ret_ExtState(str)
    local q_find = str:sub(2):find('"')
    local name = str:sub(2,q_find)
    local val_str = str:sub(q_find+2)
    local t = {}
    for line in val_str:gmatch('[^%s]+') do 
      if tonumber(line) and line:sub(1,1) ~= '0' then t[#t+1] =  tonumber(line) else t[#t+1] = line end
    end
    return {name = name, t}
  end
  --------------------------------------------------------------------  
  function DEFINE_Objects() 
    -- global variables
      if gfx.w < 100 then gfx.w = 100 end
      if gfx.h < 100 then gfx.h = 100 end
      obj = {
                    main_w = data.window_w,
                    main_h = data.window_h ,
                    tr_data = {},
                    _play_pos_progress = 0,
                    offs = 5,
                    gfx_fontname = 'Lucida Sans Unicode',
                    gfx_mode = 1,
                    gui_color = {['back'] = '20 20 20',
                                  ['back2'] = '51 63 56',
                                  ['black'] = '0 0 0',
                                  ['green'] = '130 255 120',
                                  ['blue'] = '127 204 255',
                                  ['white'] = '255 255 255',
                                  ['red'] = '204 76 51',
                                  ['green_dark'] = '102 153 102',
                                  ['yellow'] = '200 200 0',
                                  ['pink'] = '200 150 200',
                                } 
                  }
    
    -- fix OSX font          
      local gfx_fontsize = 18                
      if OS == "OSX32" or OS == "OSX64" then gfx_fontsize = gfx_fontsize - 5 end
      obj.gfx_fontsize = gfx_fontsize 
      obj.gfx_fontsize_2 = gfx_fontsize - 2 
      obj.gfx_fontsize_textb = gfx_fontsize - 1
    
    --  com vars
      local menu_h = 50
      local play_pos_h = 5
    -- generate track xywh table
      local tr_h = (data.window_h - menu_h -obj.offs) / data.track_cnt 
      local tr_id_offs = 5
      local w_id = 30
      local h_id = tr_h-tr_id_offs*2
      if h_id > w_id then h_id = w_id end
      local _, bpi = reaper.GetProjectTimeSignature2( 0 )
      for i = 1, data.track_cnt do
        local y = menu_h + tr_h* (i-1)
        obj.tr_data[i] = {x = obj.offs,
                          y = y,
                          w = data.window_w-obj.offs*2,
                          h = tr_h,
                          
                          id = i,
                          loop_len_beats_rec = math.floor(bpi*data.loopregion_len),
                          --loop_len_beats_play = math.floor(bpi*data.loopregion_len),
                          record_state = 0,
                          
                          tr_id = {x = obj.offs + tr_id_offs,
                                    w = w_id,
                                    h = h_id,
                                    y = y + (tr_h-h_id)/2
                                    },                                    
                          tr_rec = {x = obj.offs + w_id + tr_id_offs*2,
                                    w = w_id,  
                                    h = h_id,
                                    y = y + (tr_h-h_id)/2
                                    },
                          --[[tr_play = {x = obj.offs + w_id*2 + tr_id_offs*3,
                                    w = w_id,  
                                    h = h_id,
                                    y = y + (tr_h-h_id)/2
                                    } ]]                                   
                          }
      end
    -- settings button
      obj.b_prepare = {x = obj.offs,
                            y = obj.offs,
                            w = data.window_w-obj.offs*2,
                            h = menu_h -obj.offs*3- play_pos_h,
                            name = 'Prepare',
                            id_mouse = 'b_prepare',
                            color = 'white'
                            --val = data.notes_hex_side
                            } 
    -- position
      obj.play_pos = {x = obj.offs,
                      y = menu_h - obj.offs - play_pos_h,
                      w = data.window_w-obj.offs*2,
                      h = play_pos_h
                      }
  end
  -----------------------------------------------------------------------  
  function DEFINE_Objects2()
    -- check play position
      local loopregion_st_sec = reaper.TimeMap2_beatsToTime( 0, 0, data.loopregion_shift )
      local loopregion_en_sec = reaper.TimeMap2_beatsToTime( 0, 0, data.loopregion_shift + data.loopregion_len )      
      local play_pos = reaper.GetPlayPosition()
      if play_pos >= loopregion_st_sec and play_pos <= loopregion_en_sec then
        obj._play_pos_progress = (play_pos - loopregion_st_sec) / (loopregion_en_sec-loopregion_st_sec)
       else obj._play_pos_progress = 0
      end
    -- get states      
      obj._record_state = reaper.GetToggleCommandState( 1013 )
      obj._play_state = reaper.GetToggleCommandState( 1007 )
    -- reset states on stop       
      if obj._play_state == 0 then for i = 1, data.track_cnt do obj.tr_data[i].record_state = 0 end end
  end      
      
      
      
      
    --[[ reset recording on next marker if Record is on
      
      local reset_time = 0.5
      if play_pos > loopregion_st_sec and play_pos - loopregion_st_sec < reset_time then        
        if obj._record_state == 1 then
          msg('stop rec')
          --Action(40056) -- stop record at next marker
          for i = 1, data.track_cnt do
            if obj.tr_data[i].record_state == 1 then -- if waiting for record
              obj.tr_data[i].record_state = 2 -- record active
            end
          end
        end 
      end]]
    --[[ apply record if some track waiting for record
      local reset_time = 0.5
      if play_pos > loopregion_st_sec and play_pos - loopregion_st_sec < reset_time then   
        for i = 1, data.track_cnt do
          if obj.tr_data[i].record_state == 1 then -- if waiting for record
            obj.tr_data[i].record_state = 2 -- record active
          end
        end      
      end]]
      
  -----------------------------------------------------------------------    
    function F_Get_SSV(s)
      local t = {}
      for i in s:gmatch("[%d%.]+") do 
        t[#t+1] = tonumber(i) / 255
      end
      gfx.r, gfx.g, gfx.b = t[1], t[2], t[3]
      return t[1], t[2], t[3]
    end
  -----------------------------------------------------------------------    
  function F_gfx_rect(x,y,w,h)
    if x and y and w and h then 
      gfx.x, gfx.y = x,y
      gfx.line(x, y, x+w, y)
      gfx.line(x+w, y+1, x+w, y+h - 1)
      gfx.line(x+w, y+h,x, y+h)
      gfx.line(x, y+h-1,x, y+1)
    end
  end    
  --------------------------------------------------------------------   
  function GUI_slider(obj_t)
    -- define xywh
      local x,y,w,h,name = obj_t.x, obj_t.y, obj_t.w, obj_t.h,obj_t.name
    -- frame
      gfx.a = 0.1
      F_Get_SSV(gui.color.white, true)
      F_gfx_rect(x,y,w,h)     
      
      if not obj_t.val then val = 0 else val = obj_t.val end           
    -- blit grad   
      local handle_w = 30  
      local x_offs = x + (w - handle_w) * val
      gfx.a = 0.3
      gfx.blit(3, 1, 0, --backgr
          0,0,gfx.w,gfx.h,
          x,y,w*val,h)
    -- text
      gfx.setfont(1, gui.fontname, gui.fontsize)
      local measurestrname = gfx.measurestr(name)
      local x0 = x + (w - measurestrname)/2 + 1
      local y0 = y + (h - gfx.texth)/2 
      
      gfx.a = 0.3
      F_Get_SSV(gui.color.black, true)
      gfx.x, gfx.y = x0,y0 +2
      gfx.drawstr(name)
      gfx.a = 0.7
      F_Get_SSV(gui.color.green, true)
      gfx.x, gfx.y = x0,y0 
      gfx.drawstr(name)
    end
  -----------------------------------------------------------------------         
  function GUI_button(obj_t)
    local x,y,w,h, name = obj_t.x, obj_t.y, obj_t.w, obj_t.h, obj_t.name
      local color
    -- frame
      if not noframe then
        gfx.a = 0.1
        F_Get_SSV(obj.gui_color.white, true)
        F_gfx_rect(x,y,w,h)
      end      
    -- back
      if cust_alpha then gfx.a = cust_alpha else gfx.a = 0.2 end
      gfx.blit(3, 1, math.rad(180), 1,1,50,50, x,y+1,w,h, 0,0)                
    --  text
      if obj_t.color then color = obj_t.color else color = 'white' end
      F_text(name, x,y,w,h, obj.gfx_fontname, obj.gfx_fontsize, color)
  end 
  --------------------------------------------------------------------   
  function F_frame(x,y,w,h, color) 
    gfx.a = 0.1
    gfx.blit(3, 1, math.rad(180),
              0, 0,  obj.main_w/2,obj.main_h, 
              x,y,w,h,
              0, 0)
    gfx.mode =2
    if not color then 
      color = 'white' 
      gfx.a = 0.1 
      
     else 
      gfx.a = 0.3
      F_Get_SSV(obj.gui_color[color], true)
      gfx.rect(x,y,w,h-1,1)
      gfx.a = 0.6 
    end
    F_Get_SSV(obj.gui_color[color], true)
    F_gfx_rect(x,y,w,h-1)
    gfx.mode = obj.gfx_mode 
  end
  --------------------------------------------------------------------    
  function F_text(text, x,y,w,h, fontname,fontsize, color, alpha)
    -- calc / set variables
      gfx.setfont(1, fontname, fontsize)
      local measurestrname = gfx.measurestr(text)
      local x0 = x + (w - measurestrname)/2 + 1
      local y0 = y + (h - gfx.texth)/2 
      gfx.mode =0
    --[[ shadow
      gfx.a = 0.1
      F_Get_SSV(obj.gui_color.black, true)
      gfx.x, gfx.y = x0,y0 + 1
      gfx.drawstr(text)]]
    -- text
      if alpha then gfx.a = alpha else gfx.a = 0.7 end
      F_Get_SSV(obj.gui_color[color], true)
      gfx.x, gfx.y = x0,y0 
      gfx.drawstr(text)
    -- return default mode
      gfx.mode = obj.gfx_mode      
  end
  --------------------------------------------------------------------    
  function GUI_track(tr_data)
    if not tr_data then return end
    local x,y,w,h = tr_data.x,tr_data.y,tr_data.w,tr_data.h
    local x_id, y_id, w_id, h_id = tr_data.tr_id.x, tr_data.tr_id.y, tr_data.tr_id.w,tr_data.tr_id.h
    local x_rec, y_rec, w_rec, h_rec = tr_data.tr_rec.x,tr_data.tr_rec.y,tr_data.tr_rec.w,tr_data.tr_rec.h
    --local x_play, y_play, w_play, h_play = tr_data.tr_play.x,tr_data.tr_play.y,tr_data.tr_play.w,tr_data.tr_play.h
    -- blit back
      gfx.a = 0.2
      gfx.blit(3, 1, 0,
              0, 0,  obj.main_w,obj.main_h, 
              x, y, w, h,
              0, 0) 
    
    -- draw id
      local arm_col
      if obj.tr_data.arm_state and obj.tr_data.arm_state == tr_data.id then  arm_col = 'red' end
      F_frame(x_id, y_id, w_id, h_id, arm_col) 
      F_text(tr_data.id, x_id, y_id, w_id, h_id, obj.gfx_fontname, obj.gfx_fontsize, 'white')
    -- draw rec state
      F_frame(x_rec, y_rec, w_rec, h_rec)
      if tr_data.loop_len_beats_rec then
        --F_text(tr_data.loop_len_beats_rec, x_rec, y_rec, w_rec, h_rec, obj.gfx_fontname, obj.gfx_fontsize_2, 'red')
      end
    --[[ draw play state
      F_frame(x_play, y_play, w_play, h_play)
      if tr_data.loop_len_beats_play then
        F_text(tr_data.loop_len_beats_play, x_play, y_play, w_play, h_play, obj.gfx_fontname, obj.gfx_fontsize_2, 'green')
      end]]
    end
    
  --------------------------------------------------------------------    
  function GUI_track2(tr_data)
    if not tr_data then return end
    local x,y,w,h = tr_data.x,tr_data.y,tr_data.w,tr_data.h
    local x_id, y_id, w_id, h_id = tr_data.tr_id.x, tr_data.tr_id.y, tr_data.tr_id.w,tr_data.tr_id.h
    local x_rec, y_rec, w_rec, h_rec = tr_data.tr_rec.x,tr_data.tr_rec.y,tr_data.tr_rec.w,tr_data.tr_rec.h
    --local x_play, y_play, w_play, h_play = tr_data.tr_play.x,tr_data.tr_play.y,tr_data.tr_play.w,tr_data.tr_play.h
    
    local refresh_time = 0.8
    local var = clock % refresh_time / refresh_time
    local shift = 0.7
    local alpha = shift + math.sin(var*2*math.pi)*(1-shift)
    
    if tr_data.record_state == 1 then -- if rec
      F_text('Rec', x_rec, y_rec-1, w_rec, h_rec, obj.gfx_fontname, obj.gfx_fontsize_2, 'red',alpha)
     elseif tr_data.record_state == 2 then -- if play      
      F_text('Play', x_rec, y_rec-1, w_rec, h_rec, obj.gfx_fontname, obj.gfx_fontsize_2, 'green',alpha)      
    end
  end    
  --------------------------------------------------------------------   
  function GUI_progess()
    local x,y,w,h = obj.play_pos.x, obj.play_pos.y, obj.play_pos.w, obj.play_pos.h
    F_Get_SSV(obj.gui_color.green)
    gfx.a = 0.8
    gfx.rect(x,y,w*obj._play_pos_progress,h, 1)    
  end
  --------------------------------------------------------------------  
  function GUI_draw()  
    gfx.mode = obj.gfx_mode
    -- static buffer    
      if update_gfx then
        -- buf3 -- buttons back gradient    
          gfx.dest = 3
          gfx.setimgdim(3, -1, -1)  
          gfx.setimgdim(3, obj.main_w,obj.main_h)  
          gfx.a = 1
          local r,g,b,a = 0.9,0.9,1,0.6
          gfx.x, gfx.y = 0,0
          local drdx = 0.00001
          local drdy = 0
          local dgdx = 0.0001
          local dgdy = 0.0003     
          local dbdx = 0.00002
          local dbdy = 0
          local dadx = 0.0003
          local dady = 0.0004       
          gfx.gradrect(0,0,obj.main_w,obj.main_h, 
                          r,g,b,a, 
                          drdx, dgdx, dbdx, dadx, 
                          drdy, dgdy, dbdy, dady)  
        -- buf10 -- main buf  
          gfx.dest = 10
          gfx.setimgdim(10, -1, -1)  
          gfx.setimgdim(10, obj.main_w,obj.main_h)  
          F_Get_SSV(obj.gui_color.white)
          gfx.a = 0.6
          gfx.rect(0,0,gfx.w, gfx.h, 1)
          gfx.a = 1
          --gfx.rect(0,0,100,obj.menu_h, 1)
          
          GUI_button(obj.b_prepare)          
          for i =1, data.track_cnt do  GUI_track(obj.tr_data[i])  end
          
      end
      if update_gfx2 == true then
        --  buf11  -- main buf  
        gfx.dest = 11
        gfx.setimgdim(11, -1, -1)  
        gfx.setimgdim(11, obj.main_w,obj.main_h)  
        GUI_progess()
        gfx.a = 1
        for i =1, data.track_cnt do  GUI_track2(obj.tr_data[i])  end
      end     
      
    -- Blit buffers ------
      gfx.dest = -1
      gfx.x,gfx.y = 0,0
      gfx.a = 1
      gfx.blit(10, 1, 0,
               0, 0,  obj.main_w,obj.main_h,
               0, 0,  obj.main_w,obj.main_h, 0, 0) 
      gfx.blit(11, 1, 0,
               0, 0,  obj.main_w,obj.main_h,
               0, 0,  obj.main_w,obj.main_h, 0, 0) 
    -- reduced clock buffer 
                   
    update_gfx = false
    gfx.update()
  end    
    
 ----------------------------------------------------------------------- 
  function F_limit(val,min,max)
      if val == nil or min == nil or max == nil then return end
      local val_out = val
      if val < min then val_out = min end
      if val > max then val_out = max end
      return val_out
    end   
  ------------------------------------------------------------------ 
  function MOUSE_match(b, offs)
    if b then
      local mouse_y_match = b.y
      local mouse_h_match = b.y+b.h
      if offs then 
        mouse_y_match = mouse_y_match - offs 
        mouse_h_match = mouse_y_match+b.h
      end
      if mouse.mx > b.x and mouse.mx < b.x+b.w and mouse.my > mouse_y_match and mouse.my < mouse_h_match then return true end 
    end
  end 
  -----------------------------------------------------------------------     
  function MOUSE_button (xywh, offs)
    if MOUSE_match(xywh, offs) and mouse.LMB_state and not mouse.last_LMB_state then return true end
  end  
  -----------------------------------------------------------------------    
  function MOUSE_slider (obj, limit_1, limit2)
    --if mouse.last_obj ~= 'drag' then return end
    local val, limit_1, limit_2
    if not limit_1 then limit_1 = 0 end
    if not limit_2 then limit_2 = 1 end
    if MOUSE_match(obj) and mouse.LMB_state  then 
      if mouse.mx < obj.x + obj.w then
        mouse.last_obj = obj.id_mouse
      end
    end    
    if mouse.last_obj == obj.id_mouse and  mouse.LMB_state then       
      val = F_limit((mouse.mx - obj.x)/obj.w, limit_1, limit2)
      return val
    end    
  end
  ----------------------------------------------------------------------- 
  function F_dec2hex(num)
    local str = string.format("%x", num)
    return str
  end
  -----------------------------------------------------------------------  
  function GUI_menu(t, check, sub_name) local name
    local str = ''
    for i = 1, #t do
      if sub_name then 
        local t2 = {} for num in t[i]:gmatch('[^%s]+') do t2[#t2+1] = num end
        name = t2[1]
       else
        name = t[i]
      end
      
      if check == i-1 then
        str = str..'!'..name ..'|'
       else
        str = str..name ..'|'
      end
    end
    gfx.x, gfx.y = mouse.mx,mouse.my
    ret = gfx.showmenu(str) - 1
    if ret >= 0 then return ret end
  end
  -----------------------------------------------------------------------  
  function F_Menu_Resp(data, ext_state_key)
    local config_path = debug.getinfo(2, "S").source:sub(2):sub(0,-5)..'_config.ini' 
    local t2 = {}    
    for i = 1, 300 do
      _, stringOut = reaper.BR_Win32_GetPrivateProfileString(ext_state_key, i, '', config_path )
      if stringOut == '' then break end
      local t = F_ret_ExtState(stringOut)
      t2[#t2+1] = t.name
    end
    local ret = GUI_menu( t2, data - 1 )
    if ret then return math.floor(ret) + 1 end
  end
  -----------------------------------------------------------------------    
   function F_open_URL(url)  
    local OS = reaper.GetOS()  
      if OS=="OSX32" or OS=="OSX64" then
        os.execute("open ".. url)
       else
        os.execute("start ".. url)
      end
    end
  -----------------------------------------------------------------------      
  function Action(command)
    local command = reaper.NamedCommandLookup( command )
    reaper.Main_OnCommandEx( command, 0, 0 )
  end
  -----------------------------------------------------------------------      
  function ENGINE_PrepareProject()
    reaper.Undo_BeginBlock2( 0 )
    -- Item: Set item mix behavior to always mix
      Action(40919)
      local bpm, bpi = reaper.GetProjectTimeSignature2( 0 )
    --  set 0 position time signature
      reaper.SetTempoTimeSigMarker( 0, -1, 0, -1, -1, bpm, bpi, 4, 0 )    
    -- Record: Set record mode to normal
      Action(40252) 
    -- set loop region
      local rgnstart = reaper.TimeMap2_beatsToTime( 0, 0, data.loopregion_shift )
      local rgnend = reaper.TimeMap2_beatsToTime( 0, 0, data.loopregion_shift + data.loopregion_len )
      reaper.AddProjectMarker( 0, true, rgnstart, rgnend, 'MPL Looper', 0 )
    -- set time selection
      reaper.GetSet_LoopTimeRange2( 0, 1, 1, rgnstart, rgnend, 1 )
    -- insert tracks      
      for i = 1, data.track_cnt -  reaper.CountTracks( 0 ) do   reaper.InsertTrackAtIndex( 0, false )  end
      reaper.TrackList_AdjustWindows( false )

    reaper.Undo_EndBlock2( 0, 'Looper: prepare project', 0 )
  end
  -----------------------------------------------------------------------     
  function MOUSE_get()
    if not mouse then mouse = {} end
    mouse.abs_x, mouse.abs_y = reaper.GetMousePosition()
    mouse.mx = gfx.mouse_x
    mouse.my = gfx.mouse_y
    mouse.LMB_state = gfx.mouse_cap&1 == 1 
    mouse.RMB_state = gfx.mouse_cap&2 == 2 
    mouse.MMB_state = gfx.mouse_cap&64 == 64
    mouse.LMB_state_doubleclick = false
    mouse.Ctrl_LMB_state = gfx.mouse_cap&5 == 5 
    mouse.Ctrl_state = gfx.mouse_cap&4 == 4 
    mouse.Alt_state = gfx.mouse_cap&17 == 17 -- alt + LB
    mouse.wheel = gfx.mouse_wheel
    if mouse.last_wheel then mouse.wheel_trig = (mouse.wheel - mouse.last_wheel) end
    if not mouse.wheel_trig then mouse.wheel_trig = 0 end
    
    -- define dx/dy
      if not mouse.last_LMB_state and mouse.LMB_state then 
        mouse.LMB_stamp_x = mouse.mx
        mouse.LMB_stamp_y = mouse.my      
        offset_stamp_x = data.draw_offset_x
        offset_stamp_y = data.draw_offset_y
      end    
      if mouse.LMB_state then 
        mouse.dx = mouse.mx - mouse.LMB_stamp_x
        mouse.dy = mouse.my - mouse.LMB_stamp_y
      end

    -- menu
      if MOUSE_button(obj.b_prepare) then ENGINE_PrepareProject() end
      for i = 1, data.track_cnt do  
        -- set track arm
          if MOUSE_button(obj.tr_data[i].tr_id) then 
            ENGINE_set_arm(i)
            update_gfx = true 
          end
        -- set record to armed track
        if MOUSE_button(obj.tr_data[i].tr_rec) then 
          ENGINE_transport()
        end
      end
      
            
           --[[ if MOUSE_button(obj.info_cockos, 0) then F_open_URL('http://forum.cockos.com/showthread.php?t=185976') end
            if MOUSE_button(obj.info_rmm, 0) then F_open_URL('http://rmmedia.ru/threads/126388/') end
            if MOUSE_button(obj.info_vk, 0) then F_open_URL('http://vk.com/michael_pilyavskiy') end
            if MOUSE_button(obj.info_sc, 0) then F_open_URL('http://soundcloud.com/mp57') end
            if MOUSE_button(obj.info_donate, 0) then F_open_URL('http://www.paypal.me/donate2mpl') end
            ]]
            
    
    -- reset mouse context/doundo
      if mouse.last_LMB_state and not mouse.LMB_state and not mouse.RMB_state then mouse.last_obj = 0 end
      
    -- mouse release
      mouse.last_LMB_state = mouse.LMB_state  
      mouse.last_RMB_state = mouse.RMB_state
      mouse.last_MMB_state = mouse.MMB_state 
      mouse.last_Ctrl_LMB_state = mouse.Ctrl_LMB_state
      mouse.last_Ctrl_state = mouse.Ctrl_state
      mouse.last_Alt_state = mouse.Alt_state
      mouse.last_wheel = mouse.wheel 
      return obj
  end       
  ------------------------------------------------------------------ 
  function msg(str)
    local str1
     if type(str) == 'boolean' then 
       if str == true then str1 = 'true' else str1 = 'false' end
      else 
       str1 = str
     end
     if str1 then 
       reaper.ShowConsoleMsg(str1..'\n') 
      else
       reaper.ShowConsoleMsg('nil')
     end    
   end
  ------------------------------------------------------------------    
  function Data_LoadSection(def_data, data, ext_name, config_path)
      for key in pairs(def_data) do
        local _, stringOut = reaper.BR_Win32_GetPrivateProfileString( ext_name, key, def_data[key], config_path )
        if stringOut ~= ''  then
          if tonumber(stringOut) then stringOut = tonumber(stringOut) end
          data[key] = stringOut
          --data[key] = def_data[key] -- FOR RESET DEBUG
          reaper.BR_Win32_WritePrivateProfileString( ext_name, key, data[key], config_path )
         else 
          data[key] = def_data[key]
          reaper.BR_Win32_WritePrivateProfileString( ext_name, key, def_data[key], config_path )
        end
      end
  end   
  ------------------------------------------------------------------    
  function Data_InitContent()
    return
[[
// configuration for MPL Looper

[Info]

// Please don`t edit global variables
[Global_VAR]
]]    
  end
  ------------------------------------------------------------------   
  function Data_LoadConfig()
    if not data then data = {} end
    local def_data, def_layouts, def_colors, def_scales = Data_defaults()
    local layouts_count = 8
    
    -- get config path
      local config_path = debug.getinfo(2, "S").source:sub(2):sub(0,-5)..'_config.ini' 
      
    -- check default file
      local file = io.open(config_path, 'r')
      if not file then
        file = io.open(config_path, 'w')
        local def_content = Data_InitContent()
        file:write(def_content)
        file.close()
      end
      file:close()
      
    -- Load data section
      Data_LoadSection(def_data, data, 'Global_VAR', config_path)                        
  end
  ------------------------------------------------------------------
  function  F_Hex_to_rgb_SSS(hex)
    local col = tonumber(hex:gsub('#',''), 16)
    local r, g, b
    if OS == "OSX32" or OS == "OSX64" then 
      r, g, b =  reaper.ColorFromNative( col )
     else 
      b, g, r =  reaper.ColorFromNative( col )
    end
    return r..' '..g..' '..b
  end
  ------------------------------------------------------------------ 
  function Data_Update()
    local config_path = debug.getinfo(2, "S").source:sub(2):sub(0,-5)..'_config.ini' 
    local d_state, win_pos_x,win_pos_y = gfx.dock(-1,0,0)
    data.window_x, data.window_y, data.window_w, data.window_h, data.d_state = win_pos_x,win_pos_y, gfx.w, gfx.h, d_state
    for key in pairs(data) do 
      reaper.BR_Win32_WritePrivateProfileString( 'Global_VAR', key, data[key], config_path )  
    end
    reaper.BR_Win32_WritePrivateProfileString( 'Info', 'vrs', vrs, config_path ) 
    DEFINE_Objects() 
  end
  --------------------------------------------------------------------     
  function ENGINE_set_arm(track_id)
    local track_id = math.floor(track_id)
    obj.tr_data.arm_state = track_id
    -- track_id is 1-based
    for i = 1, data.track_cnt do
      local tr = reaper.GetTrack(0, i-1)
      if tr then
        if i == track_id and tr then
          reaper.SetMediaTrackInfo_Value( tr, 'I_RECARM' ,1 )
         else
          reaper.SetMediaTrackInfo_Value( tr, 'I_RECARM' ,0 )
        end
      end
    end
  end
  --------------------------------------------------------------------      
  function ENGINE_remove_loopmarkers()
    local _, num_markers = reaper.CountProjectMarkers( 0 )
     t_remove = {}
    for i = 1, num_markers do
      local _, isrgnOut, posOut, _, _, markrgnindex = reaper.EnumProjectMarkers2( proj, i-1 )
      local _, posOut_meas = reaper.TimeMap2_timeToBeats( 0, posOut )
      if not isrgnOut and posOut_meas >= data.loopregion_shift and posOut_meas <= data.loopregion_shift+ data.loopregion_len then
        t_remove[#t_remove+1] = markrgnindex
      end
    end
    for i = 1, #t_remove do reaper.DeleteProjectMarker( 0, t_remove[i], false ) end
    reaper.UpdateTimeline() 
  end
  --------------------------------------------------------------------     
  function ENGINE_add_loopmarkers(track_id)
    local shift_rec = 0.0001
    local cur_beats_rec = obj.tr_data[track_id].loop_len_beats_rec
    local m1_pos = reaper.TimeMap2_beatsToTime( 0, 0, data.loopregion_shift )
    local m2_pos = reaper.TimeMap2_beatsToTime( 0, cur_beats_rec, data.loopregion_shift ) - shift_rec
    reaper.AddProjectMarker( 0, false, m1_pos, 0, '>>', -1 )
    reaper.AddProjectMarker( 0, false, m2_pos, 0, '<<', -1 )
  end
  --------------------------------------------------------------------      
  function ENGINE_transport() 
    local repeat_state = reaper.GetToggleCommandState( 1068 )
    if repeat_state == 0 then Action(1068) end
    if not obj.tr_data.arm_state then return end
    local armed_tr = obj.tr_data.arm_state
    --ENGINE_remove_loopmarkers()
    --ENGINE_add_loopmarkers(obj.tr_data.arm_state)
    --Action(40056) -- Transport: Start/stop recording at next project marker
    if obj.tr_data[armed_tr].record_state == 0 then -- if stopped
      obj.tr_data[armed_tr].record_state = 1 -- record
      Action(40056) -- Transport: Start/stop recording at next beat
     elseif obj.tr_data[armed_tr].record_state == 1 then -- if record
      obj.tr_data[armed_tr].record_state = 2 -- play
      Action(40056) -- Transport: Start/stop recording at next beat
     elseif obj.tr_data[armed_tr].record_state == 2 then -- if play
      obj.tr_data[armed_tr].record_state = 0 -- stop    
    end
  end
  --------------------------------------------------------------------     
  --[[function KEY_get()
    -- 1-8 : number/numpad set track arm
      if char >= 49 and char < 49 + data.track_cnt then
        ENGINE_set_arm(char-48)
        update_gfx = true      
      end
    -- + : record loop
      if char == 43 then ENGINE_rec() end
    -- * : change length for current active channel
      
  end]]
  --------------------------------------------------------------------        
  function Run()   
    clock = os.clock() 
    -- update xywh/dock state
      local d_state, gfxx,gfxy = gfx.dock(-1,0,0)
      if not last_gfxw or not last_gfxh or not last_d_state or last_d_state ~= d_state or last_gfxw ~=  gfx.w or last_gfxh ~=  gfx.h then  Data_Update() update_gfx = true end
      if not last_gfxx or not last_gfxy or last_gfxx ~= gfxx or last_gfxy ~= gfxy then Data_Update() end    
      last_d_state, last_gfxx,last_gfxy, last_gfxw, last_gfxh = d_state, gfxx,gfxy,gfx.w,gfx.h
    -- reduced update perf trigger
      update_gfx2_count = update_gfx2_count + 1
      if update_gfx2_count > data.refresh_count then update_gfx2_count = 0 update_gfx2 = true else update_gfx2 = false end
    -- upd obj table
      if update_gfx2 == true then DEFINE_Objects2() end      
    -- perform mouse/GUI
      char = gfx.getchar() 
      --if char ~= 0 then msg(char) end
      MOUSE_get()
      --KEY_get()
      GUI_draw()
    -- defer loop stuff  
      if char == 32 then reaper.Main_OnCommandEx(40044, 0,0) end  -- space
      if char == 27 then gfx.quit() end                           -- escape
      if char ~= -1 then reaper.defer(Run) else gfx.quit() end    
  end  
  ------------------------------------------------------------------ 
  OS = reaper.GetOS() 
  Data_LoadConfig()  
  DEFINE_Objects()   
  update_gfx = true
  update_gfx2_count = 0
  ------------------------------------------------------------------ 
  gfx.init(name..' // '..vrs, data.window_w, data.window_h, data.d_state, data.window_x, data.window_y)
  Run()
