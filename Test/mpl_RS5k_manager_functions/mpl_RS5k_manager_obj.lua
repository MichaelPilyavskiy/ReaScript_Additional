-- @description RS5k_manager_GUI
-- @author MPL
-- @website http://forum.cockos.com/member.php?u=70694
-- @noindex
  
  
  ---------------------------------------------------
  function OBJ_init(obj)  
    -- size
    obj.reapervrs = tonumber(GetAppVersion():match('[%d%.]+')) 
    obj.offs = 5 
    obj.grad_sz = 200 
    obj.tab_h = 30    
    obj.splbrowse_up = 20 -- pat controls, smaple name
    obj.splbrowse_curfold = 20 -- current pat
    obj.splbrowse_listit = 15 -- also pattern item
    
    obj.item_h = 20   -- splbrowsp    
    obj.item_h2 = 20  -- list header
    obj.item_h3 = 15  -- list items
    obj.item_h4 = 40  -- steseq
    obj.item_w1 = 120 -- steseq name
    obj.scroll_w = 15
    obj.comm_w = 80 -- commit button
    obj.comm_h = 30
    obj.key_h = 250-- keys y/h  
    obj.WF_h=50    
    obj.kn_w =42
    obj.kn_h =56     
    
    -- alpha
    obj.it_alpha = 0.45 -- under tab
    obj.it_alpha2 = 0.28 -- navigation
    obj.it_alpha3 = 0.1 -- option tabs
    obj.it_alpha4 = 0.05 -- option items
    obj.it_alpha5 = 0.05-- oct lowhigh
    obj.GUI_a1 = 0.2 -- pat not sel
    obj.GUI_a2 = 0.45 -- pat sel
       
    
    -- font
    obj.GUI_font = 'Calibri'
    obj.GUI_fontsz = 20  -- tab
    obj.GUI_fontsz2 = 15 -- WF back spl name
    obj.GUI_fontsz3 = 13-- spl ctrl
    if GetOS():find("OSX") then 
      obj.GUI_fontsz = obj.GUI_fontsz - 6 
      obj.GUI_fontsz2 = obj.GUI_fontsz2 - 5 
      obj.GUI_fontsz3 = obj.GUI_fontsz3 - 4
    end 
    
    -- colors    
    obj.GUIcol = { grey =    {0.5, 0.5,  0.5 },
                   white =   {1,   1,    1   },
                   red =     {1,   0,    0   },
                   green =   {0.3,   0.9,    0.3   },
                   black =   {0,0,0 }
                   }    
    
    -- other
    obj.layout = {'Chromatic Keys',
                  'Chromatic Keys (2 oct)',
                  'Korg NanoPad',
                  'Ableton Live Drum Rack',
                  'Studio One Impact',
                  'Ableton Push'} 
    obj.action_export = {} -- drop file from splbrows to pads
  end
  ---------------------------------------------------
  function HasWindXYWHChanged(obj)
    local  _, wx,wy,ww,wh = gfx.dock(-1, 0,0,0,0)
    local retval=0
    if wx ~= obj.last_gfxx or wy ~= obj.last_gfxy then retval= 2 end --- minor
    if ww ~= obj.last_gfxw or wh ~= obj.last_gfxh then retval= 1 end --- major
    if not obj.last_gfxx then retval = -1 end
    obj.last_gfxx, obj.last_gfxy, obj.last_gfxw, obj.last_gfxh = wx,wy,ww,wh
    return retval
  end
  ---------------------------------------------------
  function OBJ_GenKeys_splCtrl(conf, obj, data, refresh, mouse, pat)
    local env_x_shift = 20
    local knob_back = 0
    local knob_y = 0
    local wheel_ratio = 12000
    local wheel_ratio_log = 12000
    local cur_note = obj.current_WFkey
    
    local file_name
    if not (cur_note and data[cur_note] and data[cur_note][1]) then 
      file_name = '< Drag`n`drop samples to pads >' 
     else
      file_name = data[cur_note][1].fn
    end
       
      obj.spl_WF_filename = { clear = true,
              x = obj.tab_div,
              y = obj.kn_h,--gfx.h - obj.WF_h-obj.key_h,
              w = gfx.w - obj.tab_div,
              h = obj.splbrowse_up,
              col = 'white',
              state = 0,
              txt= file_name,
              aligh_txt = 0,
              show = true,
              is_but = true,
              fontsz = obj.GUI_fontsz2,
              alpha_back =0}  
    --end
    if not (cur_note and data[cur_note] and data[cur_note][1]) or conf.global_mode == 2 then return end            
            
             
      -- knobs
      --if not (gfx.h - obj.WF_h-obj.key_h > obj.kn_h + obj.offs * 2) then return end
        ---------- gain ----------
        local gain_val = data[cur_note][1].gain / 2
        local gain_txt
        if mouse.context_latch and mouse.context_latch == 'splctrl_gain' then 
          gain_txt  = data[cur_note][1].gain_dB..'dB'   
         else   
          gain_txt = 'Gain'    
        end
        obj.splctrl_gain = { clear = true,
              x = obj.tab_div + obj.offs,
              y = knob_y,
              w = obj.kn_w,
              h = obj.kn_h,
              col = 'white',
              state = 0,
              txt= gain_txt,
              aligh_txt = 16,
              show = true,
              is_but = true,
              is_knob = true,
              val = gain_val,
              fontsz = obj.GUI_fontsz3,
              alpha_back =knob_back,
              func =  function() 
                        mouse.context_latch_val = data[cur_note][1].gain 
                      end,
              func_LD2 = function ()
                          if not mouse.context_latch_val then return end
                          local out_val = lim(mouse.context_latch_val - mouse.dy/200, 0, 2)
                          if not out_val then return end
                          SetRS5KParam(data, conf, 0, out_val, cur_note)
                          refresh.GUI = true 
                          refresh.data = true 
                        end,
              func_wheel = function()
                          local out_val = lim(data[cur_note][1].gain  + mouse.wheel_trig/wheel_ratio, 0, 2)
                          if not out_val then return end
                          SetRS5KParam(data, conf, 0, out_val, cur_note)
                          refresh.GUI = true 
                          refresh.data = true 
                        end,
                        
              func_DC = function ()
                          SetRS5KParam(data, conf, 0, 0.5, cur_note)
                          refresh.GUI = true 
                          refresh.data = true 
                        end
              }
        ---------- pan ----------                          
        local pan_val = data[cur_note][1].pan 
        local pan_txt
        if mouse.context_latch and mouse.context_latch == 'splctrl_pan' then 
          pan_txt  = math.floor((-0.5+data[cur_note][1].pan)*200)
          if pan_txt < 0 then pan_txt = math.abs(pan_txt)..'%L' elseif pan_txt > 0 then pan_txt = math.abs(pan_txt)..'%R' else pan_txt = 'center' end
         else   pan_txt = 'Pan'    
        end                          
        obj.splctrl_pan = { clear = true,
              x = obj.tab_div + obj.offs + obj.kn_w,
              y = knob_y,
              w = obj.kn_w,
              h = obj.kn_h,
              col = 'white',
              state = 0,
              txt= pan_txt,
              aligh_txt = 16,
              show = true,
              is_but = true,
              is_knob = true,
              is_centered_knob = true,
              val = pan_val,
              fontsz = obj.GUI_fontsz3,
              alpha_back =knob_back,
              func =  function() 
                        mouse.context_latch_val = data[cur_note][1].pan 
                      end,
              func_LD2 = function ()
                          if not mouse.context_latch_val then return end
                          local out_val = lim(mouse.context_latch_val - mouse.dy/200, 0, 1)
                          if not out_val then return end
                          SetRS5KParam(data, conf, 1, out_val, cur_note)
                          refresh.GUI = true 
                          refresh.data = true 
                        end,
              func_wheel = function()
                          local out_val = lim(data[cur_note][1].pan  + mouse.wheel_trig/wheel_ratio, 0, 2)
                          if not out_val then return end
                          SetRS5KParam(data, conf, 1, out_val, cur_note)
                          refresh.GUI = true 
                          refresh.data = true 
                        end,                          
              func_DC = function () 
                          SetRS5KParam(data, conf, 1, 0.5, cur_note)
                          refresh.GUI = true 
                          refresh.data = true 
                        end}        
        ---------- ptch ----------                          
        local pitch_val = data[cur_note][1].pitch_offset 
        local pitch_txt
        if mouse.context_latch and (mouse.context_latch == 'splctrl_pitch1' or mouse.context_latch == 'splctrl_pitch2') then 
          pitch_txt  = data[cur_note][1].pitch_semitones else   pitch_txt = 'Pitch'    
        end                          
        obj.splctrl_pitch1 = { clear = true,
              x = obj.tab_div + obj.offs + obj.kn_w*2,
              y = knob_y,
              w = obj.kn_w,
              h = obj.kn_h,
              col = 'white',
              state = 0,
              txt= pitch_txt,
              aligh_txt = 16,
              show = true,
              is_but = true,
              is_knob = true,
              is_centered_knob = true,
              val = pitch_val,
              fontsz = obj.GUI_fontsz3,
              alpha_back =knob_back,
              func =  function() 
                        mouse.context_latch_val = data[cur_note][1].pitch_offset 
                      end,
              func_LD2 = function ()
                          if not mouse.context_latch_val then return end
                          local out_val = lim(mouse.context_latch_val - mouse.dy/400, 0, 1)*160
                          local int, fract = math.modf(mouse.context_latch_val*160 )
                          local out_val = lim(mouse.context_latch_val - mouse.dy/400, 0, 1)
                          if not out_val then return end
                          out_val = (math_q(out_val*160)+fract)/160
                          SetRS5KParam(data, conf, 15, out_val, cur_note)
                          refresh.GUI = true 
                          refresh.data = true 
                        end,
              func_wheel = function()
                          local out_val = lim(data[cur_note][1].pitch_offset  + mouse.wheel_trig/wheel_ratio, 0, 2)
                          if not out_val then return end
                          SetRS5KParam(data, conf, 15, out_val, cur_note)
                          refresh.GUI = true 
                          refresh.data = true 
                        end,                           
              func_DC = function () 
                          SetRS5KParam(data, conf, 15, 0.5, cur_note)
                          refresh.GUI = true 
                          refresh.data = true 
                        end}  
      local int,fract =  math.modf(pitch_val*160-80 ) if not fract then fract = 0 end
      local pitch_val = fract
      obj.splctrl_pitch2 = { clear = true,
              x = obj.tab_div + obj.offs + obj.kn_w*2.25,
              y = knob_y+obj.kn_w/2,
              w = obj.kn_w/2,
              h = obj.kn_h/2,
              col = 'white',
              state = 0,
              txt= '',
              aligh_txt = 16,
              show = true,
              is_but = true,
              is_knob = true,
              --is_centered_knob = true,
              knob_a = 0,
              knob_as_point = true,
              val = pitch_val,
              fontsz = obj.GUI_fontsz3,
              alpha_back =knob_back,
              func =  function() 
                        mouse.context_latch_val = data[cur_note][1].pitch_offset 
                      end,
                       
              func_LD2 = function ()
                          if not mouse.context_latch_val then return end
                          local out_val = lim(mouse.context_latch_val - mouse.dy/100000, 0, 1)
                          if not out_val then return end
                          SetRS5KParam(data, conf, 15, out_val, cur_note)
                          refresh.GUI = true 
                          refresh.data = true 
                        end}   
        ---------- attack ----------  
        local att_txt
        if mouse.context_latch and mouse.context_latch == 'splctrl_att' then 
          att_txt  = data[cur_note][1].attack_ms..'ms'   
         else   
          att_txt = 'A'    
        end
        obj.splctrl_att = { clear = true,
              x = obj.tab_div + obj.offs+ obj.kn_w*3 + env_x_shift,
              y = knob_y,
              w = obj.kn_w,
              h = obj.kn_h,
              col = 'white',
              state = 0,
              txt= att_txt,
              aligh_txt = 16,
              show = true,
              is_but = true,
              is_knob = true,
              val = data[cur_note][1].attack^0.1666,
              fontsz = obj.GUI_fontsz3,
              alpha_back =knob_back,
              func =  function() 
                        mouse.context_latch_val = data[cur_note][1].attack 
                      end,
              func_LD2 = function ()
                          if not mouse.context_latch_val then return end
                          local out_val = lim(mouse.context_latch_val^0.1666 - mouse.dy/300, 0, 1)
                          if not out_val then return end
                          out_val = out_val^6
                          SetRS5KParam(data, conf, 9, out_val, cur_note)
                          refresh.GUI = true 
                          refresh.data = true 
                        end,
              func_wheel = function()
                          local out_val = lim(data[cur_note][1].attack^0.1666  + mouse.wheel_trig/wheel_ratio_log, 0, 2)
                          if not out_val then return end
                          SetRS5KParam(data, conf, 9, out_val^6, cur_note)
                          refresh.GUI = true 
                          refresh.data = true 
                        end,  
              func_DC = function ()
                          SetRS5KParam(data, conf, 9, 0, cur_note)
                          refresh.GUI = true 
                          refresh.data = true 
                        end
              }     
        ---------- decay ----------  
        local dec_txt
        if mouse.context_latch and mouse.context_latch == 'splctrl_dec' then 
          dec_txt  = data[cur_note][1].decay_ms..'ms'   
         else   
          dec_txt = 'D'    
        end
        obj.splctrl_dec = { clear = true,
              x = obj.tab_div + obj.offs+ obj.kn_w*4 + env_x_shift,
              y = knob_y,
              w = obj.kn_w,
              h = obj.kn_h,
              col = 'white',
              state = 0,
              txt= dec_txt,
              aligh_txt = 16,
              show = true,
              is_but = true,
              is_knob = true,
              val = data[cur_note][1].decay^0.1666,
              fontsz = obj.GUI_fontsz3,
              alpha_back =knob_back,
              func =  function() 
                        mouse.context_latch_val = data[cur_note][1].decay 
                      end,
              func_LD2 = function ()
                          if not mouse.context_latch_val then return end
                          local out_val = lim(mouse.context_latch_val^0.1666 - mouse.dy/1000, 0, 1)
                          if not out_val then return end
                          out_val = out_val^6
                          SetRS5KParam(data, conf, 24, out_val, cur_note)
                          refresh.GUI = true
                          refresh.data = true
                        end,
              func_wheel = function()
                          local out_val = lim(data[cur_note][1].decay^0.1666  + mouse.wheel_trig/wheel_ratio_log, 0, 2)
                          if not out_val then return end
                          SetRS5KParam(data, conf, 24, out_val^6, cur_note)
                          refresh.GUI = true 
                          refresh.data = true 
                        end,  
              func_DC = function ()
                          SetRS5KParam(data, conf, 24, 0.016, cur_note)
                          refresh.GUI = true 
                          refresh.data = true 
                        end
              }         
        ---------- sust ----------
        local sust_txt
        if mouse.context_latch and mouse.context_latch == 'splctrl_sust' then 
          sust_txt  = data[cur_note][1].sust_dB..'dB'   
         else   
          sust_txt = 'S'    
        end
        obj.splctrl_sust = { clear = true,
              x = obj.tab_div + obj.offs+ obj.kn_w*5 + env_x_shift,
              y = knob_y,
              w = obj.kn_w,
              h = obj.kn_h,
              col = 'white',
              state = 0,
              txt= sust_txt,
              aligh_txt = 16,
              show = true,
              is_but = true,
              is_knob = true,
              val = data[cur_note][1].sust/2,
              fontsz = obj.GUI_fontsz3,
              alpha_back =knob_back,
              func =  function() 
                        mouse.context_latch_val = data[cur_note][1].sust 
                      end,
              func_LD2 = function ()
                          if not mouse.context_latch_val then return end
                          local out_val = lim(mouse.context_latch_val - mouse.dy/200, 0, 2)
                          if not out_val then return end
                          SetRS5KParam(data, conf, 25, out_val, cur_note)
                          refresh.GUI = true 
                          refresh.data = true 
                        end,
              func_wheel = function()
                          local out_val = lim(data[cur_note][1].sust  + mouse.wheel_trig/wheel_ratio, 0, 2)
                          if not out_val then return end
                          SetRS5KParam(data, conf, 25, out_val, cur_note)
                          refresh.GUI = true 
                          refresh.data = true 
                        end,  
              func_DC = function ()
                          SetRS5KParam(data, conf, 25, 0.5, cur_note)
                          refresh.GUI = true 
                          refresh.data = true 
                        end
              }              
        ---------- release ----------  
        local rel_txt
        if mouse.context_latch and mouse.context_latch == 'splctrl_rel' then 
          rel_txt  = data[cur_note][1].rel_ms..'ms'   
         else   
          rel_txt = 'R'    
        end
        obj.splctrl_rel = { clear = true,
              x = obj.tab_div + obj.offs+ obj.kn_w*6 + env_x_shift,
              y = knob_y,
              w = obj.kn_w,
              h = obj.kn_h,
              col = 'white',
              state = 0,
              txt= rel_txt,
              aligh_txt = 16,
              show = true,
              is_but = true,
              is_knob = true,
              val = data[cur_note][1].rel^0.1666,
              fontsz = obj.GUI_fontsz3,
              alpha_back =knob_back,
              func =  function() 
                        mouse.context_latch_val = data[cur_note][1].rel 
                      end,
              func_LD2 = function ()
                          if not mouse.context_latch_val then return end
                          local out_val = lim(mouse.context_latch_val^0.1666 - mouse.dy/300, 0, 1)
                          if not out_val then return end
                          out_val = out_val^6
                          SetRS5KParam(data, conf, 10, out_val, cur_note)
                          refresh.GUI = true 
                          refresh.data = true 
                        end,
              func_wheel = function()
                          local out_val = lim(data[cur_note][1].rel^0.1666  + mouse.wheel_trig/wheel_ratio_log, 0, 2)
                          if not out_val then return end
                          SetRS5KParam(data, conf, 10, out_val^6, cur_note)
                          refresh.GUI = true 
                          refresh.data = true 
                        end, 
              func_DC = function ()
                          SetRS5KParam(data, conf, 10, 0.0004, cur_note)
                          refresh.GUI = true 
                          refresh.data = true 
                        end
              }                                                                                                                                  
  end
  -----------------------------------------------------------------------   
    function OBJ_GenPatternBrowser(conf, obj, data, refresh, mouse, pat)
      local up_w = 40
      obj.pat_new = { clear = true,
                    x = obj.browser.x,
                  y = obj.browser.y,
                  w = up_w,
                  h = obj.splbrowse_up,
                  col = 'white',
                  state = 0,
                  txt= 'New',
                  show = true,
                  is_but = true,
                  fontsz = obj.GUI_fontsz2,
                  alpha_back = obj.it_alpha2,
                  func =  function() 
                            local insert_at_index = #pat+1
                            table.insert(pat,insert_at_index,{NAME='pat'..insert_at_index,
                                                              GUID=genGuid('')})
                            pat.SEL = insert_at_index
                            refresh.projExtData = true
                            refresh.GUI = true
                            refresh.data = true
                          end} 
      obj.pat_dupl = { clear = true,
                    x = obj.browser.x+up_w+1,
                  y = obj.browser.y,
                  w = up_w,
                  h = obj.splbrowse_up,
                  col = 'white',
                  state = 0,
                  txt= 'Dupl',
                  show = true,
                  is_but = true,
                  fontsz = obj.GUI_fontsz2,
                  alpha_back = obj.it_alpha2,
                  func =  function() 
                            if not pat.SEL or not pat[ pat.SEL ] then return end
                            local insert_at_index = pat.SEL+1
                            table.insert(pat,insert_at_index,{NAME='pat'..insert_at_index})
                                                              --GUID=genGuid('')})                          
                            pat[insert_at_index] = CopyTable(pat[ pat.SEL ])
                            pat[insert_at_index].GUID=genGuid('')
                            pat[insert_at_index].NAME = IncrementPatternName(pat[insert_at_index].NAME)
                            pat.SEL = insert_at_index
                            refresh.projExtData = true 
                            refresh.GUI = true
                            refresh.data = true                         
                          end}    
      obj.pat_rem = { clear = true,
                    x = obj.browser.x+(up_w+1)*2,
                  y = obj.browser.y,
                  w = up_w,
                  h = obj.splbrowse_up,
                  col = 'white',
                  state = 0,
                  txt= 'Del',
                  show = true,
                  is_but = true,
                  fontsz = obj.GUI_fontsz2,
                  alpha_back = obj.it_alpha2,
                  func =  function() 
                            if pat.SEL and pat[pat.SEL] then 
                              table.remove(pat, pat.SEL)
                              if not pat[pat.SEL] then for i = pat.SEL, 1, -1 do if pat[i] then pat.SEL = i break end end                           end
                              refresh.projExtData = true
                              refresh.GUI = true
                              refresh.data = true
                            end
                          end}   
      obj.pat_ins = { clear = true,
                    x = obj.browser.x+(up_w+1)*3,
                  y = obj.browser.y,
                  w = up_w,
                  h = obj.splbrowse_up,
                  col = 'white',
                  state = 0,
                  txt= 'Insert',
                  show = true,
                  is_but = true,
                  fontsz = obj.GUI_fontsz2,
                  alpha_back = obj.it_alpha2,
                  func =  function() 
                            if pat.SEL and pat[pat.SEL] and 
                              ((conf.global_mode ~= 1 and data.parent_track) or (conf.global_mode == 1 and data.parent_trackMIDI))then 
                              --AddMediaItemToTrack( data.parent_track )
                              local curpos = GetCursorPosition()
                              local _, _, _, fullbeats=TimeMap2_timeToBeats( 0, curpos )
                              local endtime = TimeMap2_beatsToTime( 0, fullbeats+4 )
                              local it
                              if conf.global_mode ~= 1 then
                                it = CreateNewMIDIItemInProj( data.parent_track, curpos, endtime )
                               else
                                it = CreateNewMIDIItemInProj( data.parent_trackMIDI, curpos, endtime )
                              end
                              SelectAllMediaItems( 0, false )
                              SetMediaItemSelected( it, true )
                              CommitPattern(data, conf, pat)
                              refresh.GUI = true
                              refresh.data = true
                            end
                          end}                           
        if conf.commit_mode == 1 or conf.commit_mode == 2 then 
          obj.stepseq_commit = { clear = true,
                      x = obj.browser.x+(up_w+1)*3,-- gfx.w-obj.comm_w- obj.scroll_w - 1,
                      y = obj.browser.y+obj.item_h2,--gfx.h -obj.comm_h ,
                      w = obj.tab_div - (obj.browser.x+(up_w+1)*3),--obj.comm_w,
                      h = obj.item_h2-1,--obj.comm_h,
                      col = 'white',
                      state = 0,
                      txt= 'Commit',
                      show = true,
                      is_but = true,
                      fontsz = gui.fontsz2,
                      alpha_back = obj.it_alpha2,
                      func =  function() CommitPattern(data, conf, pat, 0) end} 
        end                        
      local cur_pat_name = '(not selected)'
      if pat.SEL and pat[pat.SEL] then cur_pat_name = pat[pat.SEL].NAME end
      obj.pat_current = { clear = true,
                    x = obj.browser.x,--+(up_w+1)*3,
                  y = obj.browser.y + obj.splbrowse_up,--+obj.item_h2,
                  w = obj.tab_div,--lim(obj.browser.w-(up_w+1)*3,up_w, math.huge),
                  h = obj.splbrowse_curfold,
                  col = 'green',
                  state = 0,
                  txt= cur_pat_name ,
                  show = true,
                  is_but = true,
                  fontsz = obj.GUI_fontsz2,
                  alpha_back = obj.it_alpha2,
                  func =  function() 
                            Menu2(mouse, {
                                    {str='Rename pattern',
                                    func =  function() 
                                              local r, str = GetUserInputs(scr_title, 1, 'Pattern name', pat[pat.SEL].NAME)
                                              if r then 
                                                local old_name = pat[pat.SEL].NAME
                                                pat[pat.SEL].NAME = str
                                                refresh.projExtData = true
                                                refresh.GUI = true
                                                refresh.data = true
                                              end
                                            end},                          
                                    {str='Rename pattern and propagate it to items with same name',
                                    func =  function() 
                                              local r, str = GetUserInputs(scr_title, 1, 'Pattern name', pat[pat.SEL].NAME)
                                              if r then 
                                                local old_name = pat[pat.SEL].NAME
                                                pat[pat.SEL].NAME = str
                                                CommitPattern(data, conf, pat, 1, old_name, new_name)
                                                refresh.projExtData = true
                                                refresh.GUI = true
                                                refresh.data = true
                                              end
                                            end},
                                    {str='Select linked patterns',
                                    func =  function() 
                                              SelectLinkedPatterns(conf, data,pat[pat.SEL].NAME)
                                            end}  ,
                                    {str='|Set pattern length to 2 beats (default)',
                                    func =  function() 
                                              pat[pat.SEL].PATLEN = 1
                                              refresh.projExtData = true
                                              refresh.GUI = true
                                              refresh.data = true
                                            end}, 
                                    {str='Set pattern length to 4 beats',
                                    func =  function() 
                                              pat[pat.SEL].PATLEN = 2
                                              refresh.projExtData = true 
                                              refresh.GUI = true
                                              refresh.data = true
                                            end},     
                                    {str='Set pattern length to 8 beats',
                                    func =  function() 
                                              pat[pat.SEL].PATLEN = 4
                                              refresh.projExtData = true
                                              refresh.GUI = true
                                              refresh.data = true
                                            end},                                                                                                                           
                                    
                                  })
                          end}      
      local p_cnt = #pat          
      for i = 1, #pat do 
        local a = 0.2
        local txt = pat[i].NAME
        if pat.SEL and i == pat.SEL then 
          txt = '> '..txt
          a = obj.GUI_a2 
        end
        obj['patlist'..i] = 
                  { clear = true,
                   
                  x = obj.browser.x,
                  y = (i-1)*obj.splbrowse_listit + obj.browser.y+obj.splbrowse_up+obj.splbrowse_curfold,
                  w = obj.tab_div,
                  h = obj.item_h3,
                  col = 'white',
                  state = 0,
                  txt= txt,
                  aligh_txt = 1,
                  --blit = 3,
                  show = true,
                  is_but = true,
                  fontsz = obj.GUI_fontsz2,
                  alpha_back = 0.2,
                  a_line = 0.1,
                    --a_line = 0,
                    --mouse_offs_y = obj.blit_y_src - obj.item_h2*2-obj.item_h,
                    func =  function() 
                              pat.SEL = i
                              if conf.autoselect_patterns == 1 then SelectLinkedPatterns(conf, data,pat[i].NAME) end
                              refresh.projExtData = true
                              refresh.GUI = true
                              refresh.data = true
                            end}    
      end
    end
    
    ----------------------------------------------------------------------- 
    function OBJ_GenOptionsList_RS5Kctrl(conf, obj, data, refresh, mouse, pat)
      if data.global_pitch_offset then
        obj.opt_rsk5ctrl_pitch = { clear = true,
                  x = obj.tab_div+2,
                  y = 1,
                  w = gfx.w - obj.tab_div-4,
                  h = obj.item_h2,
                    col = 'white',
                    state = 1,
                    txt= 'Global pitch offset: '..math_q((-0.5+data.global_pitch_offset)*160),
                    --aligh_txt = 1,
                    --blit = 4,
                    show = true,
                    is_slider = true,
                    fontsz = obj.GUI_fontsz2,
                    alpha_back = 0.1,
                    alpha_back2 = 0.3,
                    axis ='x_cent',
                    val = data.global_pitch_offset,
                    func =  function()
                              mouse.context_latch = 'opt_rsk5ctrl_pitch'
                              mouse.context_latch_val = data.global_pitch_offset
                            end,                  
                    func_LD = function()
                                if mouse.context_latch =='opt_rsk5ctrl_pitch'
                                  and mouse.context_latch_val 
                                  and mouse.is_moving then
                                    local val = mouse.context_latch_val + mouse.dx/1000
                                    local val = lim(val, 0,1)--math.floor(160*(lim(val, 0,1) -0.5))
                                    val = 0.5+math.floor(160*(lim(val, 0,1) -0.5))/160
                                    SetRS5KParam(data, conf, 15, val)
                                    refresh.GUI = true
                                    refresh.data = true
                                end
                              end
                }
      end
    end
    ---------------------------------------------------
    function OBJ_GenKeys(conf, obj, data, refresh, mouse, pat)
      --obj.item_h +  1 + obj.item_h2 + 1
      local shifts,w_div ,h_div
      local start_note_shift =0
      if conf.keymode ==0 then 
        w_div = 7
        h_div = 2
        shifts  = {{0,1},
                  {0.5,0},
                  {1,1},
                  {1.5,0},
                  {2,1},
                  {3,1},
                  {3.5,0},
                  {4,1},
                  {4.5,0},
                  {5,1},
                  {5.5,0},
                  {6,1},
                }
      elseif conf.keymode ==1 then 
        w_div = 14
        h_div = 2
        shifts  = {{0,1},
                  {0.5,0},
                  {1,1},
                  {1.5,0},
                  {2,1},
                  {3,1},
                  {3.5,0},
                  {4,1},
                  {4.5,0},
                  {5,1},
                  {5.5,0},
                  {6,1},
                  {7,1},
                  {7.5,0},
                  {8,1},
                  {8.5,0},
                  {9,1},
                  {10,1},
                  {10.5,0},
                  {11,1},
                  {11.5,0},
                  {12,1},
                  {12.5,0},
                  {13,1}                 
                }                
       elseif conf.keymode == 2 then -- korg nano
        w_div = 8
        h_div = 2     
        shifts  = {{0,1},
                  {0,0},
                  {1,1},
                  {1,0},
                  {2,1},
                  {2,0},
                  {3,1},
                  {3,0},
                  {4,1},
                  {4,0},
                  {5,1},
                  {5,0},
                  {6,1},
                  {6,0},      
                  {7,1},
                  {7,0},                              
                }   
       elseif conf.keymode == 3 then -- live dr rack
        w_div = 4
        h_div = 4     
        shifts  = { {0,3},    
                    {1,3}, 
                    {2,3}, 
                    {3,3},
                    {0,2},    
                    {1,2}, 
                    {2,2}, 
                    {3,2},
                    {0,1},    
                    {1,1}, 
                    {2,1}, 
                    {3,1},
                    {0,0},    
                    {1,0}, 
                    {2,0}, 
                    {3,0}                                                               
                }      
       elseif conf.keymode == 4 then -- s1 impact
        w_div = 4
        h_div = 4 
        start_note_shift = -1    
        shifts  = { {0,3},    
                    {1,3}, 
                    {2,3}, 
                    {3,3},
                    {0,2},    
                    {1,2}, 
                    {2,2}, 
                    {3,2},
                    {0,1},    
                    {1,1}, 
                    {2,1}, 
                    {3,1},
                    {0,0},    
                    {1,0}, 
                    {2,0}, 
                    {3,0}                                                               
                }  
       elseif conf.keymode == 5 then -- ableton push
        w_div = 8
        h_div = 8 
        start_note_shift = 0    
        shifts  = { 
                    {0,7},    
                    {1,7}, 
                    {2,7}, 
                    {3,7},
                    {4,7},
                    {5,7},
                    {6,7},
                    {7,7},
                            
                    {0,6},    
                    {1,6}, 
                    {2,6}, 
                    {3,6},
                    {4,6},
                    {5,6},
                    {6,6},
                    {7,6},
                            
                    {0,5},    
                    {1,5}, 
                    {2,5}, 
                    {3,5},
                    {4,5},
                    {5,5},
                    {6,5},
                    {7,5},
                                               
                    {0,4},    
                    {1,4}, 
                    {2,4}, 
                    {3,4},
                    {4,4},
                    {5,4},
                    {6,4},
                    {7,4},
                    
                    {0,3},    
                    {1,3}, 
                    {2,3}, 
                    {3,3},
                    {4,3},
                    {5,3},
                    {6,3},
                    {7,3},
                    
                    {0,2},    
                    {1,2}, 
                    {2,2}, 
                    {3,2},
                    {4,2},    
                    {5,2}, 
                    {6,2}, 
                    {7,2},                    
                    
                    {0,1},    
                    {1,1}, 
                    {2,1}, 
                    {3,1},
                    {4,1},    
                    {5,1}, 
                    {6,1}, 
                    {7,1},                    
                    
                    {0,0},    
                    {1,0}, 
                    {2,0}, 
                    {3,0},
                    {4,0},    
                    {5,0}, 
                    {6,0}, 
                    {7,0},                                                                              
                }                                               
      end
      

      local key_area_h = gfx.h -obj.kn_h-obj.splbrowse_up
      local key_w = math.ceil((obj.workarea.w-3*obj.offs)/w_div)
      local key_h = math.ceil((1/h_div)*(key_area_h)) 
      obj.h_div = h_div
      for i = 1, #shifts do
        local id = i-1+conf.oct_shift*12
        local note = (i-1)+12*conf.oct_shift+start_note_shift
        local fn, ret = GetSampleNameByNote(data, note)
        local col = 'white'
        local colint, colint0
        local alpha_back
        if ret then 
          alpha_back = 0.49        
          col = 'green'           
          if conf.global_mode == 1 or conf.global_mode == 2 then
            if data[id] and data[id][1] and data[id][1].trackGUID then
              local tr =  BR_GetMediaTrackByGUID( 0, data[id][1].trackGUID )
              if tr then
                colint0 =  GetTrackColor( tr )
                if colint0 ~= 0 then colint = colint0 end
              end
            end
          end
         else
          alpha_back = 0.15 
        end
        local note_str = GetNoteStr(conf, note)
        if note_str then
          local txt = note_str..'\n\r'--..fn
          if key_h < 28 then txt = note end
          local fx_rect_side = 15
          if note > 0 and note <= 127 then
            if key_h > fx_rect_side then 
              obj['keys_pFX'..i] = { clear = true,
                    x = obj.workarea.x+shifts[i][1]*key_w + key_w - fx_rect_side,-- - obj.offs,
                    y = gfx.h-key_area_h + shifts[i][2]*key_h,--+obj.offs,
                    w = fx_rect_side,
                    h = fx_rect_side,
                    col = 'white',
                    state = 0,
                    txt= 'FX',
                    --aligh_txt = 16,
                    show = true,
                    is_but = true,
                    fontsz = obj.GUI_fontsz3-2,
                    alpha_back =0.2,
                    func =  function() 
                                local tr = GetDestTrackByNote(data, conf,data.parent_track, note)
                                if not tr then return end
                                TrackFX_Show( tr,0, 1 )
                              end}
            end
            obj['keys_p'..i] = 
                      { clear = true,
                        x = obj.workarea.x+shifts[i][1]*key_w + obj.offs,
                        y = gfx.h-key_area_h+ shifts[i][2]*key_h,
                        w = key_w-1,
                        h = key_h,
                        col = col,
                        colint = colint,
                        state = 0,
                        txt= txt,
                        is_step = true,
                        vertical_txt = fn,
                        linked_note = note,
                        show = true,
                        is_but = true,
                        alpha_back = alpha_back,
                        a_frame = 0.05,
                        aligh_txt = 5,
                        fontsz = obj.GUI_fontsz2,
                        func =  function() 
                                  if obj[ mouse.context ] and obj[ mouse.context ].linked_note then
                                    if conf.keypreview == 1 then StuffMIDIMessage( 0, '0x9'..string.format("%x", 0), obj[ mouse.context ].linked_note,100)  end
                                    obj.current_WFkey = obj[ mouse.context ].linked_note
                                    refresh.GUI_WF = true                                  
                                   else
                                    refresh.GUI_WF = true
                                  end
                                end--[[,
                        func_R = function ()
                                    
                                    Menu2(mouse, {
                                          { str = 'Erase pad/linked track',
                                            func = function() 
                                                    if conf.global_mode == 1 or conf.global_mode == 2 then
                                                      if data[id] and data[id][1] and data[id][1].trackGUID then
                                                        local tr =  BR_GetMediaTrackByGUID( 0, data[id][1].trackGUID )
                                                        if tr then
                                                          DeleteTrack( tr )
                                                        end
                                                      end
                                                    end
                                                  end
                                          }
                                        
                                         })
                                
                                
                                  end]]
                                } 
            if    note%12 == 1 
              or  note%12 == 3 
              or  note%12 == 6 
              or  note%12 == 8 
              or  note%12 == 10 
              then obj['keys_p'..i].txt_col = 'black' end
          end
        end
      end
    
      
    end
  ----------------------------------------------------------------------- 
  function OBJ_GenOptionsList(conf, obj, data, refresh, mouse, pat)
    obj.opt_global = { clear = true,
                x = obj.browser.x+1,
                y = obj.browser.y,--+(obj.item_h2+1),
                w = obj.tab_div-2,
                h = obj.item_h2,
                col = 'white',
                state = conf.options_tab == 0,
                txt= 'Global preferences',
                show = true,
                is_but = true,
                fontsz = obj.GUI_fontsz2,
                alpha_back = obj.it_alpha3,
                alpha_back2 = obj.it_alpha2,
                func =  function() 
                          conf.options_tab = 0 
                          refresh.conf = true 
                          refresh.GUI = true
                          refresh.data = true
                        end}   
    obj.opt_sample = { clear = true,
                x = obj.browser.x+1,
                y = obj.browser.y+(obj.item_h2+1),
                w = obj.tab_div-2,
                h = obj.item_h2,
                col = 'white',
                state = conf.options_tab == 1,
                txt= 'Browser / Pads',
                show = true,
                is_but = true,
                fontsz = obj.GUI_fontsz2,
                alpha_back = obj.it_alpha3,
                alpha_back2 = obj.it_alpha2,
                func =  function() 
                          conf.options_tab = 1 
                          refresh.conf = true
                          refresh.GUI = true
                          refresh.data = true
                        end}  

    obj.opt_stepseq = { clear = true,
                x = obj.browser.x+1,
                y = obj.browser.y+(obj.item_h2+1)*2,
                w = obj.tab_div-2,
                h = obj.item_h2,
                col = 'white',
                state = conf.options_tab == 2,
                txt= 'StepSequencer / Patterns',
                show = true,
                is_but = true,
                fontsz = obj.GUI_fontsz2,
                alpha_back = obj.it_alpha3,
                alpha_back2 = obj.it_alpha2,
                func =  function() 
                          conf.options_tab = 2
                          refresh.conf = true
                          refresh.GUI = true
                          refresh.data = true
                        end} 
    obj.opt_rs5k_ctrl = { clear = true,
                x = obj.browser.x+1,
                y = obj.browser.y+(obj.item_h2+1)*3,
                w = obj.tab_div-2,
                h = obj.item_h2,
                col = 'white',
                state = conf.options_tab == 3,
                txt= 'Common RS5K controls',
                show = true,
                is_but = true,
                fontsz = obj.GUI_fontsz2,
                alpha_back = obj.it_alpha3,
                alpha_back2 = obj.it_alpha2,
                func =  function() 
                          conf.options_tab = 3
                          refresh.conf = true
                          refresh.GUI = true
                          refresh.data = true
                        end}                                                                        
  end
  ----------------------------------------------------------------------- 
  function OBJ_GenOptionsList_Browser(conf, obj, data, refresh, mouse, pat)
    
    obj.opt_sample_favpathcount = { clear = true,
                x = obj.tab_div+2,
                y = 1,
                w = gfx.w - obj.tab_div-4,
                h = obj.item_h2,
                col = 'white',
                state = conf.options_tab == 0,
                txt= 'Favourite paths: '..conf.fav_path_cnt,
                show = true,
                is_but = true,
                fontsz = obj.GUI_fontsz2,
                alpha_back = obj.it_alpha4,
                func =  function() 
                          ret = GetInput( conf, 'Set favourite paths count', conf.fav_path_cnt,true)
                          if ret then 
                            conf.fav_path_cnt = ret 
                            refresh.conf = true
                          refresh.GUI = true
                          refresh.data = true 
                          end                          
                        end}     
    obj.opt_sample_use_0notepreview = { clear = true,
                x = obj.tab_div+2,
                y = 1+(obj.item_h2+2),
                w = gfx.w - obj.tab_div-4,
                h = obj.item_h2,
                col = 'white',
                check = conf.use_preview,
                txt= 'Use RS5k instance at note 0 as browser preview',
                show = true,
                is_but = true,
                fontsz = obj.GUI_fontsz2,
                alpha_back = obj.it_alpha4,
                func =  function() 
                          conf.use_preview = math.abs(1-conf.use_preview) 
                          refresh.conf = true
                          refresh.GUI = true
                          refresh.data = true                
                        end}     
    obj.opt_pad_keynames = { clear = true,
                x = obj.tab_div+2,
                y = 1+(obj.item_h2+2)*2,
                w = gfx.w - obj.tab_div-4,
                h = obj.item_h2,
                col = 'white',
                txt= 'Key names: '..({GetNoteStr(conf, 0, conf.key_names)})[2],
                show = true,
                is_but = true,
                fontsz = obj.GUI_fontsz2,
                alpha_back = obj.it_alpha4,
                func =  function() 
                          Menu2(mouse, {  {str = ({GetNoteStr(conf, 1, 8)})[2],
                                    func = function() 
                                              conf.key_names = 8 
                                              refresh.conf = true                          
                                              refresh.GUI = true
                                              refresh.data = true 
                                            end ,
                                    state = conf.key_names == 8},
                                  {str = ({GetNoteStr(conf, 1, 7)})[2],
                                    func = function() 
                                              conf.key_names = 7 
                                              refresh.conf = true 
                                              refresh.GUI = true
                                              refresh.data = true
                                            end ,
                                    state = conf.key_names == 7}
                                })
                        end} 
    obj.opt_pad_layout = { clear = true,
                x = obj.tab_div+2,
                y = 1+(obj.item_h2+2)*3,
                w = gfx.w - obj.tab_div-4,
                h = obj.item_h2,
                col = 'white',
                txt= 'Layout: '..obj.layout[conf.keymode+1],
                show = true,
                is_but = true,
                fontsz = obj.GUI_fontsz2,
                alpha_back = obj.it_alpha4,
                func =  function() 
                          Menu2(mouse, {  {str = obj.layout[1],
                                    func = function() 
                                              conf.keymode = 0 
                                              refresh.conf = true 
                                              refresh.GUI = true
                                              refresh.data = true
                                            end ,
                                    state = conf.keymode == 0},
                                  {str = obj.layout[2],
                                    func = function() 
                                              conf.keymode = 1 
                                              refresh.conf = true 
                                              refresh.GUI = true
                                              refresh.data = true
                                            end ,
                                    state = conf.keymode == 1},
                                  {str = obj.layout[3],
                                    func = function() 
                                            conf.keymode = 2 
                                            refresh.conf = true
                                            refresh.GUI = true
                          refresh.data = true end ,
                                    state = conf.keymode == 2}  ,   
                                  {str = obj.layout[4],
                                    func = function() 
                                    conf.keymode = 3 
                                    refresh.conf = true
                                     refresh.GUI = true
                          refresh.data = true end ,
                                    state = conf.keymode == 3},
                                  {str = obj.layout[5],
                                    func = function() 
                                    conf.keymode = 4 
                                    refresh.conf = true 
                                    refresh.GUI = true
                          refresh.data = true end ,
                                    state = conf.keymode == 4}    ,
                                  {str = obj.layout[6],
                                    func = function() 
                                    conf.keymode = 5 
                                    refresh.conf = true 
                                    refresh.GUI = true
                          refresh.data = true end ,
                                    state = conf.keymode == 5}                                                                                                                                            
                                })
                        end}    
    obj.opt_sample_keypreview = { clear = true,
                x = obj.tab_div+2,
                y = 1+(obj.item_h2+2)*4,
                w = gfx.w - obj.tab_div-4,
                h = obj.item_h2,
                col = 'white',
                check = conf.keypreview,
                txt= 'Send MIDI by clicking on keys',
                show = true,
                is_but = true,
                fontsz = obj.GUI_fontsz2,
                alpha_back = obj.it_alpha4,
                func =  function() 
                          conf.keypreview = math.abs(1-conf.keypreview) 
                          refresh.conf = true 
                          refresh.GUI = true
                          refresh.data = true                
                        end}                                                                                            
  end

  ----------------------------------------------------------------------- 
  function OBJ_GenOptionsList_Global(conf, obj, data, refresh, mouse, pat)
    local global_modes = {'RS5K instances are on single track',
                          'RS5K instances are on child tracks (MIDI send)',
                          'Dump sources to child tracks as audio items'}
    obj.opt_global_mode = { clear = true,
                x = obj.tab_div+2,
                y = 1,
                w = gfx.w - obj.tab_div-4,
                h = obj.item_h2,
                col = 'red',
                state = conf.global_mode == 0,
                txt= 'Parent track mode: '..global_modes[conf.global_mode+1],
                show = true,
                is_but = true,
                fontsz = obj.GUI_fontsz2,
                alpha_back = obj.it_alpha4,
                func =  function() 
                          Menu2(mouse, {  {str = global_modes[1],
                                    func = function() 
                                              conf.global_mode = 0 
                                              refresh.conf = true 
                                              refresh.GUI = true
                                              refresh.data = true
                                              data.parent_track = nil 
                                              refresh.projExtData = true
                                              obj.set_par_tr.ignore_mouse = false
                                            end ,
                                    state = conf.global_mode == 0},
                                  {str = global_modes[2],
                                    func = function() 
                                            conf.global_mode = 1 
                                            refresh.conf = true  
                                            refresh.GUI = true
                                            refresh.data = true 
                                            data.parent_track = nil 
                                            obj.set_par_tr.ignore_mouse = false
                                          end ,
                                    state = conf.global_mode == 1},
                                  {str = global_modes[3],
                                    func = function() 
                                              conf.global_mode = 2 
                                              refresh.conf = true 
                                              refresh.GUI = true
                                              refresh.data = true 
                                              data.parent_track = nil 
                                              obj.set_par_tr.ignore_mouse = false
                                            end ,
                                    state = conf.global_mode == 2}                                                                        
                                })
                                
                                
                                
                        end}    
    obj.opt_global_autoprepare = { clear = true,
                x = obj.tab_div+2,
                y = obj.item_h2+2,
                w = gfx.w - obj.tab_div-4,
                h = obj.item_h2,
                col = 'white',
                check = conf.prepareMIDI,
                txt= 'Auto prepare MIDI input',
                show = true,
                is_but = true,
                fontsz = obj.GUI_fontsz2,
                alpha_back = obj.it_alpha4,
                func =  function() 
                          conf.prepareMIDI = math.abs(1-conf.prepareMIDI) 
                          refresh.conf = true
                          refresh.GUI = true
                          refresh.data = true                
                        end}   
    obj.opt_global_redefine_parent = { clear = true,
                x = obj.tab_div+2,
                y = (obj.item_h2+2)*2,
                w = gfx.w - obj.tab_div-4,
                h = obj.item_h2,
                col = 'red',
                txt= 'Redefine parent track (make sure you know what you do)',
                show = true,
                is_but = true,
                fontsz = obj.GUI_fontsz2,
                alpha_back = obj.it_alpha4,
                func =  function() DefineParentTrack(conf, data, refresh) end}    
    obj.opt_global_select_parent = { clear = true,
                x = obj.tab_div+2,
                y = (obj.item_h2+2)*3,
                w = gfx.w - obj.tab_div-4,
                h = obj.item_h2,
                col = 'white',
                txt= 'Select parent track',
                show = true,
                is_but = true,
                fontsz = obj.GUI_fontsz2,
                alpha_back = obj.it_alpha4,
                func =  function() 
                          if not data.parent_track or not ValidatePtr2( 0, data.parent_track, 'MediaTrack*' ) then return end 
                          SetOnlyTrackSelected( data.parent_track )
                        end}                                          
                        
    --[[obj.opt_global_exploders5k = { clear = true,
                x = obj.tab_div+2,
                y = (obj.item_h2+2)*2,
                w = gfx.w - obj.tab_div-4,
                h = obj.item_h2,
                col = 'white',
                txt= 'Action: Explode RS5k instances from selected track',
                show = true,
                is_but = true,
                fontsz = obj.GUI_fontsz2,
                alpha_back = obj.it_alpha4,
                func =  function() 
                          local tr = GetSelectedTrack(0,0)
                          ExplodeRS5K_main(tr)     
                        end}      ]]                                          
  
  end  
  
-----------------------------------------------------------------------  
  function OBJ_GenStepSequencer(conf, obj, data, refresh, mouse, pat) 
    local s_cnt = 0
    for i = 1, 127 do if CheckPatCond(data, pat, i) then s_cnt = s_cnt + 1 end end
    local cnt = 0          
    for i = 1, 127 do
      if CheckPatCond(data, pat, i) then 
        cnt = cnt + 1 
        local a = 0.2
        local note = i--(i-1)+12*conf.oct_shift
        local fn, ret = GetSampleNameByNote(data, note)
        local col = 'white'
        local colint, colint0
        if ret then 
          col = 'green' 
                   
          if conf.global_mode == 1 or conf.global_mode == 2 then
            if data[i] and data[i][1] and data[i][1].trackGUID then
              local tr =  BR_GetMediaTrackByGUID( 0, data[i][1].trackGUID )
              if tr then
                colint0 =  GetTrackColor( tr )
                if colint0 ~= 0 then colint = colint0 end
              end
            end
          end        
        end
        local txt = GetNoteStr(conf, note,0)..' / '..note..'\n\r'
        if fn then txt=txt..fn end
        obj['stseq'..i] = {  clear = true,
                  x = obj.tab.w+ obj.offs,
                  y = (cnt-1)*obj.item_h4,
                  w = obj.item_w1,
                  h = obj.item_h4-1,
                  col = col,
                  colint = colint,
                  state = 1,
                  txt= txt,
                  aligh_txt = 4,
                  --blit = 4,
                  show = true,
                  is_but = true,
                  fontsz = obj.GUI_fontsz2,
                  alpha_back = 0.5,
                  --a_line = 0,
                  --mouse_offs_x = obj.workarea.x,
                  --mouse_offs_y = obj.blit_y_src2-obj.workarea.y,
                  func =    function() 
                              StuffMIDIMessage( 0, '0x9'..string.format("%x", 0), note,100)
                            end,
                  func_R = function()
                              local t = { { str='Copy steps',
                                            func = function() 
                                                      if pat[pat.SEL]['NOTE'..i] and pat[pat.SEL]['NOTE'..i].seq then 
                                                        Buf_t = pat[pat.SEL]['NOTE'..i].seq
                                                      end 
                                                    end},
                                          { str = 'Paste steps',
                                            func = function() 
                                              if Buf_t then 
                                                if pat[pat.SEL]['NOTE'..i] then 
                                                  pat[pat.SEL]['NOTE'..i].seq = CopyTable(Buf_t)
                                                  refresh.projExtData = true
                                                  refresh.GUI = true
                                                  refresh.data = true
                                                end
                                              end
                                            end},
                                          { str = 'Paste steps and link until close',
                                            func = function() 
                                              if Buf_t then 
                                                pat[pat.SEL]['NOTE'..i].seq = Buf_t
                                                refresh.projExtData = true
                                                refresh.GUI = true
                                                refresh.data = true
                                              end
                                            end}                                            
                                        }
                              
                              Menu2(mouse, t)
                              
                            end
                  }
        if obj.gui_cond then  obj['stseq'..i].w = obj.item_h4 
                              obj['stseq'..i].txt = GetNoteStr(conf, note,0)..'\n\r'..note
        end
        if obj.gui_cond2 then obj['stseq'..i].w = 0 end
        local steps = conf.default_steps
        if pat[pat.SEL] and pat[pat.SEL]['NOTE'..i] and pat[pat.SEL]['NOTE'..i].STEPS then steps = pat[pat.SEL]['NOTE'..i].STEPS end
        obj['stseq_steps'..i] = {  clear = true,
                  x = obj['stseq'..i].x+obj['stseq'..i].w + 1,
                  y = (cnt-1)*obj.item_h4,
                  w = obj.item_h4,
                  h = obj.item_h4-1,
                  col = col,
                  colint = colint,
                  state = 0,
                  txt= steps,
                  --aligh_txt = 1,
                  --blit = 4,
                  show = true,
                  fontsz = obj.GUI_fontsz2,
                  alpha_back = 0.5,
                  --a_line = 0,
                  --mouse_offs_x = obj.workarea.x,
                  --mouse_offs_y = obj.blit_y_src2-obj.workarea.y,
                  func_wheel = function(wheel)
                                if not pat.SEL or not pat[pat.SEL] or not pat[pat.SEL]['NOTE'..i] then return end
                                local val = pat[pat.SEL]['NOTE'..i].STEPS
                                if wheel > 0 then c = 1 else c = -1 end
                                if pat[pat.SEL]['NOTE'..i] then
                                  pat[pat.SEL]['NOTE'..i].STEPS = val + c
                                  refresh.projExtData = true
                                  refresh.GUI = true
                                  refresh.data = true
                                end
                              end,
                  func =  function()
                            if not pat[pat.SEL] then return end
                            mouse.context_latch = 'stseq_steps'..i
                            mouse.context_latch_val = steps
                          end,                  
                  func_trigCtrl =  function()
                            if not pat[pat.SEL] then return end
                            mouse.context_latch = 'stseq_steps'..i
                            mouse.context_latch_val = steps
                          end,                  
                  func_LD = function()
                              if mouse.context_latch =='stseq_steps'..i
                                and mouse.context_latch_val 
                                and mouse.is_moving 
                                and pat[pat.SEL] then
                                  local val = mouse.context_latch_val - mouse.dy/20
                                  local val = math.floor(lim(val, 1,conf.max_step_count) )
                                  if not pat[pat.SEL]['NOTE'..i] then pat[pat.SEL]['NOTE'..i] = {} end
                                  pat[pat.SEL]['NOTE'..i].STEPS = val
                                  refresh.projExtData = true 
                                  refresh.GUI = true
                                  refresh.data = true
                              end
                          end,
                  func_ctrlLD = function()
                              if mouse.context_latch =='stseq_steps'..i
                                and mouse.context_latch_val 
                                and mouse.is_moving 
                                and pat[pat.SEL] then
                                  local val = mouse.context_latch_val - mouse.dy/10
                                  local val = math.floor(lim(val, 1,conf.max_step_count) )
                                  local q_val = 2^(lim(math.floor(math.sqrt(val)),1,6))
                                  if not pat[pat.SEL]['NOTE'..i] then pat[pat.SEL]['NOTE'..i] = {} end
                                  pat[pat.SEL]['NOTE'..i].STEPS = math.floor(q_val)
                                  refresh.projExtData = true
                                  refresh.GUI = true
                                  refresh.data = true
                              end
                          end,                          
                        
                  func_DC = function()
                              if pat[pat.SEL] then
                                  if not pat[pat.SEL]['NOTE'..i] then pat[pat.SEL]['NOTE'..i] = {} end
                                  pat[pat.SEL]['NOTE'..i].STEPS = conf.default_steps
                                  refresh.projExtData = true
                                  refresh.GUI = true
                                  refresh.data = true 
                              end
                          end,
                          }  
        if obj.gui_cond2 then obj['stseq_steps'..i].w = 0 end
        -- steps
        local step_w = (obj.workarea.w - obj['stseq_steps'..i].w - obj['stseq'..i].w - 3-obj.scroll_w) / steps
        for step = 1, steps do
          local val = 0
          if pat[pat.SEL] and pat[pat.SEL]['NOTE'..i] and pat[pat.SEL]['NOTE'..i].seq and pat[pat.SEL]['NOTE'..i].seq[step] then val = pat[pat.SEL]['NOTE'..i].seq[step] end
          obj['stseq_stepseq'..i..'_'..step] = {  clear = true,
                  x = obj['stseq_steps'..i].x + obj['stseq_steps'..i].w + 2 + (step-1)*step_w,
                  y = (cnt-1)*obj.item_h4,
                  w = step_w-1,
                  h = obj.item_h4-1,
                  col = col,
                  colint = colint,
                  state = 1,
                  txt= '',
                  --aligh_txt = 1,
                  --blit = 4,
                  show = true,
                  is_step = true,
                  fontsz = obj.GUI_fontsz2,
                  alpha_back = 0.23,
                  val = val,
                  --a_line = 0,
                  --mouse_offs_x = obj.workarea.x,
                  --mouse_offs_y = obj.blit_y_src2-obj.workarea.y,
                  func =  function() 
                            mouse.context_latch = 'stseq_stepseq'..i..'_'..step
                            if not pat[pat.SEL] then return end
                            if not pat[pat.SEL]['NOTE'..i] then pat[pat.SEL]['NOTE'..i] = {} end
                            if not pat[pat.SEL]['NOTE'..i].STEPS then pat[pat.SEL]['NOTE'..i].STEPS = conf.default_steps end
                            if not pat[pat.SEL]['NOTE'..i].seq then pat[pat.SEL]['NOTE'..i].seq = {} end
                            if not pat[pat.SEL]['NOTE'..i].seq[step] then pat[pat.SEL]['NOTE'..i].seq[step] = 0 end                            
                            if pat[pat.SEL]['NOTE'..i].seq[step] > 0 then 
                              pat[pat.SEL]['NOTE'..i].seq[step] = 0
                              mouse.context_latch_val = pat[pat.SEL]['NOTE'..i].seq[step]
                             else
                              pat[pat.SEL]['NOTE'..i].seq[step] = conf.default_value
                              mouse.context_latch_val = conf.default_value
                            end
                            pat[pat.SEL]['NOTE'..i].SEQHASH = FormSeqHash(steps, pat[pat.SEL]['NOTE'..i].seq)
                            refresh.projExtData = true
                            if conf.global_mode == 1 or conf.global_mode == 2 then BuildTrackTemplate_MIDISendMode(conf, data, refresh) end
                            refresh.GUI = true
                            refresh.data = true 
                          end,
                  func_LD =  function() 
                                if not pat[pat.SEL] or not mouse.is_moving  then return end
                                if not pat[pat.SEL]['NOTE'..i] then pat[pat.SEL]['NOTE'..i] = {} end
                                if not pat[pat.SEL]['NOTE'..i].STEPS then pat[pat.SEL]['NOTE'..i].STEPS = conf.default_steps end
                                if not pat[pat.SEL]['NOTE'..i].seq then pat[pat.SEL]['NOTE'..i].seq = {} end
                                if pat[pat.SEL]['NOTE'..i].seq[step] then
                                  if mouse.context_latch_val then pat[pat.SEL]['NOTE'..i].seq[step] = mouse.context_latch_val end
                                 else
                                  pat[pat.SEL]['NOTE'..i].seq[step] = 0
                                end
                                pat[pat.SEL]['NOTE'..i].SEQHASH = FormSeqHash(steps, pat[pat.SEL]['NOTE'..i].seq)
                                refresh.projExtData = true
                                refresh.GUI = true
                                refresh.data = true
                          end,
                  func_ctrlLD = function()
                              if mouse.context_latch =='stseq_stepseq'..i..'_'..step
                                and mouse.context_latch_val 
                                and mouse.is_moving 
                                and pat[pat.SEL] then
                                  local val = mouse.context_latch_val - mouse.dy/conf.mouse_ctrldrag_res
                                  local val = math.floor(lim(val, 0,127) )
                                  if not pat[pat.SEL]['NOTE'..i] then pat[pat.SEL]['NOTE'..i] = {} end
                                  pat[pat.SEL]['NOTE'..i].seq[step] = val
                                  pat[pat.SEL]['NOTE'..i].SEQHASH = FormSeqHash(steps, pat[pat.SEL]['NOTE'..i].seq)
                                  refresh.projExtData = true
                                  refresh.GUI = true
                                  refresh.data = true
                              end
                          end,  
                  func_wheel = function(wheel)
                              if mouse.context =='stseq_stepseq'..i..'_'..step  and pat[pat.SEL] then
                                  if not pat[pat.SEL]['NOTE'..i] then pat[pat.SEL]['NOTE'..i] = {} end
                                  if pat[pat.SEL]['NOTE'..i].seq and pat[pat.SEL]['NOTE'..i].seq[step] then
                                    pat[pat.SEL]['NOTE'..i].seq[step] = math_q(pat[pat.SEL]['NOTE'..i].seq[step] + wheel/conf.mouse_stepseq_wheel_res)
                                    pat[pat.SEL]['NOTE'..i].SEQHASH = FormSeqHash(steps, pat[pat.SEL]['NOTE'..i].seq)
                                    refresh.projExtData = true
                                    refresh.GUI = true
                                    refresh.data = true
                                  end
                              end
                          end,                                                     
                  func_RD =  function() 
                            if not pat[pat.SEL] then return end
                            if not pat[pat.SEL]['NOTE'..i] then pat[pat.SEL]['NOTE'..i] = {} end
                            if not pat[pat.SEL]['NOTE'..i].STEPS then pat[pat.SEL]['NOTE'..i].STEPS = conf.default_steps end
                            if not pat[pat.SEL]['NOTE'..i].seq then pat[pat.SEL]['NOTE'..i].seq = {} end
                            pat[pat.SEL]['NOTE'..i].seq[step] = 0
                            pat[pat.SEL]['NOTE'..i].SEQHASH = FormSeqHash(steps, pat[pat.SEL]['NOTE'..i].seq)
                            refresh.projExtData = true
                            refresh.GUI = true
                            refresh.data = true
                          end 
                }                              
        end
      end    
    end
  end  
----------------------------------------------------------------------------
  function OBJ_GenSampleBrowser(conf, obj, data, refresh, mouse, pat)
    local up_w = 25
    if obj.tab_div == 0 then up_w = 0 end
    
    obj.browser_up = { clear = true,
                  x = obj.browser.x,
                y = obj.browser.y,
                w = up_w,
                h = obj.splbrowse_up,
                col = 'white',
                state = 0,
                txt= '<',
                show = true,
                is_but = true,
                fontsz = obj.GUI_fontsz2,
                alpha_back = obj.it_alpha2,
                func =  function() 
                          local path = GetParentFolder(conf.cur_smpl_browser_dir) 
                          if path then 
                            conf.cur_smpl_browser_dir = path 
                            refresh.conf = true
                            refresh.GUI = true
                            refresh.data = true
                          end
                        end} 
    ------ browser menu form --------------- 
    obj.browser_curfold = { clear = true,
                x = obj.browser.x + up_w,
                y = obj.browser.y,--+obj.item_h2,
                w = obj.tab_div - up_w,
                h = obj.splbrowse_curfold,
                col = 'white',
                state = 0,
                txt= conf.cur_smpl_browser_dir,
                show = true,
                is_but = true,
                fontsz = obj.GUI_fontsz2,
                alpha_back = obj.it_alpha,
                func =  function() Menu2(mouse, Menu_FormBrowser(conf,refresh)) end}
    local cur_dir_list = GetDirList(conf.cur_smpl_browser_dir, 0)
    for i = 1, #cur_dir_list do
      local txt = cur_dir_list[i][1]
      local txt2 if  cur_dir_list[i][2] == 0 then txt2 = '>' end
      obj['browser_dirlist'..i] = 
                { clear = true,
                  x = obj.browser.x,
                  y = (i-1)*obj.splbrowse_listit + obj.browser.y+obj.splbrowse_up,--+obj.splbrowse_curfold,
                  w = obj.tab_div,
                  h = obj.item_h3,
                  col = 'white',
                  state = 0,
                  txt= txt,
                  txt2=txt2,
                  aligh_txt = 1,
                  --blit = 3,
                  show = true,
                  is_but = true,
                  fontsz = obj.GUI_fontsz2,
                  alpha_back = 0.2,
                  a_line = 0.1,
                  --mouse_offs_y = obj.blit_y_src - obj.item_h2*2-obj.item_h,
                  func =  function() 
                            local p = conf.cur_smpl_browser_dir..'/'..cur_dir_list[i][1] 
                            p = p:gsub('\\','/')
                            if not IsSupportedExtension(p) then 
                              conf.cur_smpl_browser_dir = p
                              refresh.conf = true 
                              refresh.GUI = true
                              refresh.data = true
                             else
                              -- preview
                              if conf.use_preview == 1 then 
                                Preview_Key(data,conf,refresh, p)
                              end
                            end
                          end,
                    func_LD = function()
                                local path = conf.cur_smpl_browser_dir..'/'..cur_dir_list[i][1] 
                                obj.action_export.state = true
                                obj.action_export.fn = path
                              end}    
    end
  end
  ----------------------------------------------------------------------- 
  function OBJ_GenOptionsList_StepSeq(conf, obj, data, refresh, mouse, pat)
    local commit_modes = {'set/update selected items by clicking step sequencer' ,
                          'ignore selected items, update items by name-based propagating'  ,
                          'manual commiting to selected items'}
    obj.opt_steseq_commit_mode = { clear = true,
                x = obj.tab_div+2,
                y = 1,
                w = gfx.w - obj.tab_div-4,
                h = obj.item_h2,
                col = 'white',
                state = conf.commit_mode == 0,
                txt= 'Commit mode: '..commit_modes[conf.commit_mode+1],
                show = true,
                is_but = true,
                fontsz = obj.GUI_fontsz2,
                alpha_back = obj.it_alpha4,
                func =  function() 
                          Menu2(mouse, {  {str = commit_modes[1],
                                    func = function() 
                                              conf.commit_mode = 0 
                                              refresh.conf = true  
                                              refresh.GUI = true
                                              refresh.data = true
                                             end ,
                                    state = conf.commit_mode == 0},
                                  {str = commit_modes[2],
                                    func = function() 
                                    conf.commit_mode = 1 
                                    refresh.conf = true
                                     refresh.GUI = true
                                              refresh.data = true end ,
                                    state = conf.commit_mode == 1},
                                  {str = commit_modes[3],
                                    func = function() 
                                    conf.commit_mode = 2 
                                    refresh.conf = true  
                                    refresh.GUI = true
                                              refresh.data = true end ,
                                    state = conf.commit_mode == 2}                                    
                                })
                        end}  
    obj.opt_steseq_mouseres_ctrlleftdrag = { clear = true,
                x = obj.tab_div+2,
                y = 1 + obj.item_h2+2,
                w = gfx.w - obj.tab_div-4,
                h = obj.item_h2,
                col = 'white',
                state = conf.options_tab == 0,
                txt= 'Mouse dy ratio (Ctrl+LeftDrag, default=0.5): '..conf.mouse_ctrldrag_res,
                show = true,
                is_but = true,
                fontsz = obj.GUI_fontsz2,
                alpha_back = obj.it_alpha4,
                func =  function() 
                          ret = GetInput(conf, 'Set dy ratio for ctrl+left drag', conf.mouse_ctrldrag_res)
                          if ret then 
                            conf.mouse_ctrldrag_res = ret 
                            refresh.conf = true
                            refresh.GUI = true
                                                                          refresh.data = true 
                          end                          
                        end} 
    obj.opt_steseq_mousewheel_ratio = { clear = true,
                x = obj.tab_div+2,
                y = 1+(obj.item_h2+2)*2,
                w = gfx.w - obj.tab_div-4,
                h = obj.item_h2,
                col = 'white',
                state = conf.options_tab == 0,
                txt= 'Mouse wheel ratio (default=40): '..conf.mouse_stepseq_wheel_res,
                show = true,
                is_but = true,
                fontsz = obj.GUI_fontsz2,
                alpha_back = obj.it_alpha4,
                func =  function() 
                          ret = GetInput(conf, 'Set mousewheel ratio', conf.mouse_stepseq_wheel_res)
                          if ret then 
                            conf.mouse_stepseq_wheel_res = ret 
                            refresh.conf = true 
                            refresh.GUI = true
                                                                          refresh.data = true 
                          end                          
                        end}                              
    obj.opt_steseq_autoselect = { clear = true,
                x = obj.tab_div+2,
                y = 1+(obj.item_h2+2)*3,
                w = gfx.w - obj.tab_div-4,
                h = obj.item_h2,
                col = 'white',
                check = conf.autoselect_patterns,
                txt= 'Select linked items by click on pattern name',
                show = true,
                is_but = true,
                fontsz = obj.GUI_fontsz2,
                alpha_back = obj.it_alpha4,
                func =  function() 
                          conf.autoselect_patterns = math.abs(1-conf.autoselect_patterns) 
                          refresh.conf = true 
                          refresh.GUI = true
                                                                        refresh.data = true                  
                        end}                          
                        
                                                 
  end
  ---------------------------------------------------  
  function OBJ_initButtons(conf, obj, data, refresh, mouse, pat)
    local set_par_tr_w = 300
    obj.set_par_tr =  {x =(gfx.w-set_par_tr_w)/2,
                y = (gfx.h-obj.kn_h)/2 ,
                w = set_par_tr_w,
                h = obj.kn_h,
                col = 'white',
                show = true,
                state = 0,
                txt = 'Set selected track as parent for script data',
                fontsz = obj.GUI_fontsz2,
                alpha_back = 0.05,
                mouse_scale = 100,
                axis = 'y',
                is_slider = true,
                func =  function() 
                          DefineParentTrack(conf, data, refresh) 
                        end}
    
    
    obj.tab = { x = 0,
                y = 0,
                h = obj.tab_h,
                col = 'white',
                state = 0,
                show = true,
                alpha_back = 0.2,
                func =  function()
                          local _, val = MOUSE_Match(mouse, obj.tab)
                          conf.tab = math.floor(lim(val*3, 0,2.99) )
                          refresh.GUI = true
                          refresh.data = true
                          refresh.conf = true
                        end
                }

    obj.browser =      { x = 0,
                y = obj.tab_h + 1 ,
                h = gfx.h-obj.item_h,
                col = 'white',
                state = 0,
                alpha_back = 0.45,
                ignore_mouse = true}
    obj.stepseq_area =      { x = obj.tab_w,
                y = obj.tab_h + 1 ,
                h = gfx.h-obj.item_h,
                col = 'white',
                state = 0,
                alpha_back = 0.45,
                ignore_mouse = true}                
    obj.workarea = { 
                y = 1,--obj.item_h+obj.item_h2+2,
                h = gfx.h,
                col = 'white',
                --show = true,
                state = 0,
                ignore_mouse = true}                

  end
  ---------------------------------------------------
  function OBJ_Update(conf, obj, data, refresh, mouse, pat) 
    obj.tab_div = math.floor(gfx.w*conf.tab_div)
    if obj.tab_div < 160 then obj.tab_div = 0 end
    --if not obj.tab then return end
    --
    obj.tab.is_tab = conf.tab + (3<<7)
    obj.tab.w = obj.tab_div
    obj.tab.show = obj.tab_div~=0
    if conf.tab == 0 then 
      obj.tab.txt = 'Samples & Pads'
      --obj.tab.col = 'green'
     elseif conf.tab == 1 then 
      obj.tab.txt = 'Patterns & StepSeq'
      --obj.tab.col = 'blue'
     elseif conf.tab == 2 then 
      obj.tab.txt = 'Options'  
      --obj.tab.col = 'white'    
    end
    obj.tab.val = conf.tab
    obj.tab.steps = 3
    --
    obj.browser.w = obj.tab_div
    --
    obj.workarea.x = obj.tab_div+1
    obj.workarea.w = gfx.w - obj.tab_div - 2
    --
    obj.gui_cond = obj.workarea.w < 400
    obj.gui_cond2 = obj.workarea.w < 300
    for key in pairs(obj) do if type(obj[key]) == 'table' and obj[key].clear then obj[key] = nil end end
    ---------------------------------------------macro windows
    if conf.tab == 0 then 
      local cnt_it = OBJ_GenSampleBrowser(conf, obj, data, refresh, mouse, pat)
      if not obj.keys_hide_knobs then
        obj.keys_octaveshiftL = { clear = true,
                    x = gfx.w-obj.comm_w,
                    y = 0,--gfx.h -obj.comm_h ,
                    w = obj.comm_w/2,
                    h = obj.comm_h,
                    col = 'white',
                    state = fale,
                    txt= '<',
                    show = true,
                    is_but = true,
                    mouse_overlay = true,
                    fontsz = obj.GUI_fontsz,
                    alpha_back = obj.it_alpha5,
                    a_frame = 0.05,
                    func =  function() 
                              conf.oct_shift = lim(conf.oct_shift - 1,0,10)
                              refresh.conf = true 
                              refresh.GUI = true
                              refresh.data = true
                            end} 
        obj.keys_octaveshiftR = { clear = true,
                    x = gfx.w-obj.comm_w/2,
                    y = 0,--gfx.h -obj.comm_h ,
                    w = obj.comm_w/2,
                    h = obj.comm_h,
                    col = 'white',
                    state = fale,
                    txt= '>',
                    show = true,
                    is_but = true,
                    mouse_overlay = true,
                    fontsz = obj.GUI_fontsz,
                    alpha_back = obj.it_alpha5,
                    a_frame = 0.05,
                    func =  function() 
                              conf.oct_shift = lim(conf.oct_shift + 1,1,10)
                              refresh.conf = true 
                              refresh.GUI = true
                              refresh.data = true                           
                            end}  
      end                        
  
      OBJ_GenKeys(conf, obj, data, refresh, mouse, pat)
      OBJ_GenKeys_splCtrl(conf, obj, data, refresh, mouse, pat)
      -----------------------
     elseif conf.tab == 1 then 
      local cnt_it
      if obj.tab_div ~= 0 then cnt_it = OBJ_GenPatternBrowser(conf, obj, data, refresh, mouse, pat) end
      local cnt_it2 = OBJ_GenStepSequencer(conf, obj, data, refresh, mouse, pat)
      -----------------------
     elseif conf.tab == 2 then 
      OBJ_GenOptionsList(conf, obj, data, refresh, mouse, pat)
      if conf.options_tab == 1 then OBJ_GenOptionsList_Browser(conf, obj, data, refresh, mouse, pat) 
       elseif conf.options_tab == 2 then OBJ_GenOptionsList_StepSeq(conf, obj, data, refresh, mouse, pat)
       elseif conf.options_tab == 0 then OBJ_GenOptionsList_Global(conf, obj, data, refresh, mouse, pat)
       elseif conf.options_tab == 3 then OBJ_GenOptionsList_RS5Kctrl(conf, obj, data, refresh, mouse, pat)
      end      
      -----------------------
    end
    for key in pairs(obj) do if type(obj[key]) == 'table' then obj[key].context = key end end    
  end
