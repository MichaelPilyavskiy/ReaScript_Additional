

--[[  full changelog
--    0.1 // 05.10.2016
--      + init alpha
]]
  
  
  
  
  local vrs = 1.0
  local name = 'MPL Track Inspector'
  ------------------------------------------------------------------  
  function GetExtState(default, key)
    val = reaper.GetExtState( name, key )
    if val == '' or not tonumber(val )then 
      reaper.SetExtState( name, key, default, true )
      return default
     else 
      return tonumber(val)
    end
  end  
  ------------------------------------------------------------------   
  function SetExtState(val, key)
    if val and key then 
      reaper.SetExtState( name, key, val, true )
    end
  end    
  ------------------------------------------------------------------  
  function math_q(val, pow)
    if val then return  math.floor(val * 10^pow)/ 10^pow end
  end
  ------------------------------------------------------------------      
  function msg(s) if s then reaper.ShowConsoleMsg(s..'\n') end end
  -------------------------------------------------------------------   
  function DEFINE_GUI_vars()
      local gui = {
                  aa = 1,
                  mode = 3,
                  fontname = 'Calibri',
                  fontsize = 18}
     
        if OS == "OSX32" or OS == "OSX64" then gui.fontsize = gui.fontsize - 7 end
        gui.fontsize_textb = gui.fontsize - 1
      
      gui.color = {['back'] = '51 51 51',
                    ['back2'] = '51 63 56',
                    ['black'] = '0 0 0',
                    ['green'] = '102 255 102',
                    ['blue'] = '127 204 255',
                    ['white'] = '255 255 255',
                    ['red'] = '204 76 51',
                    ['green_dark'] = '102 153 102',
                    ['yellow'] = '200 200 0',
                    ['pink'] = '200 150 200',
                  }    
    return gui    
  end  
  --------------------------------------------------------------------
  function DEFINE_Objects(Tr_data)
    
    local obj = {}
      obj.main_w = gfx.w
      obj.main_h = gfx.h
      obj.offs = 5
      obj.panel_h = 20
      
      if Tr_data then
        obj.trackid = {x = obj.offs,
                       y = obj.offs,
                      w = 30,
                      h =  obj.panel_h,
                      name = Tr_data.id,
                      col = Tr_data.col}        
        obj.trackname = {x = obj.offs + obj.trackid.w + obj.offs,
                       y = obj.offs,
                      w = gfx.w - 3*obj.offs - obj.trackid.w,
                      h =  obj.panel_h,
                      name =Tr_data.tr_name,
                      col = Tr_data.col }
      end
                                                             
                                    
    return obj
  end
-----------------------------------------------------------------------    
  function F_Get_SSV(s)
    local t = {}
    for i in s:gmatch("[%d%.]+") do 
      t[#t+1] = tonumber(i) / 255
    end
    gfx.r, gfx.g, gfx.b = t[1], t[2], t[3]
    return t[1], t[2], t[3]
  end
  ------------------------------------------------------------------   
  function GUI_slider(obj, obj_t, gui, val_t)
    gfx.mode = 0
    local val1, val2 =val_t.L^2 , val_t.R^2
    if val1 == nil then val1 = 0 end
    if val2 == nil then val2 = 0 end
    local alpha_mult = 1.8
    -- define xywh
      local x,y,w,h = obj_t.x, obj_t.y, obj_t.w, obj_t.h
    -- frame
      gfx.a = 0.05
      F_Get_SSV(gui.color.white, true)
      F_gfx_rect(x,y,w,h)     
    -- center line
      gfx.a = 1
      gfx.blit(5, 1, 0, --backgr
               0,0,w, obj.slider.line_h,
               x+w/2,y+h/2 - 1,w/2, obj.slider.line_h, 0,0   )   
      gfx.blit(5, 1, math.rad(180), --backgr
               0,0,w, obj.slider.line_h,
               x,y+h/2 - 1,w/2, obj.slider.line_h, 0,0   )                       
      gfx.a = 3
      gfx.blit(4, 1, 0, --backgr
               0,0,obj.slider.manualw, obj.slider.h,
               x + w/2 - val1 * w/2,y, x + w/2 - (x + w/2 - val1 * w/2) + 1, obj.slider.h, 0,0)
      gfx.blit(4, 1, 0, --backgr
               0,0,obj.slider.manualw, obj.slider.h,
               x + w/2, y, val2*w/2, obj.slider.h, 0,0   )            
    -- grid
      local steps = 20
      local cust_h_dif = 4
      F_Get_SSV(gui.color.white, true)
      for i = x, x+w, w/steps  do
        cust_h = (i-x) * steps / w
        if cust_h > steps/2 then cust_h = steps - cust_h end
        gfx.a = cust_h / steps
        if (cust_h / steps) ~= 0.5 then -- ignore center
          if cust_h % 2 == 1 then  cust_h = cust_h - cust_h_dif end
            gfx.line(i, y + h/2 + cust_h,
                   i, y + h/2 - cust_h)
                   --gfx.drawstr(math.floor(cust_h)..' ')
        end
      end      
    -- draw sm
      F_Get_SSV(gui.color.blue, true)
      gfx.a = 0.6
      gfx.line(x+w/2, y+1,x+w/2, y+h-1)
      local pol_side = 5
      gfx.triangle(x+w/2 - pol_side,y + h/2,
                    x+w/2,y + h/2- pol_side,
                    x+w/2 + pol_side,y + h/2,
                    x+w/2,y + h/2 + pol_side)
                    
    --text
      gfx.setfont(1, gui.fontname, font)
      gfx.a = 1
      F_Get_SSV(gui.color.blue, true)
      local txt_offs = 5
      if not offs1_max then offs1_max = 0 end
      if not offs2_max then offs2_max = 0 end
      
    -- text val1
      local val1_txt = math.floor(offs1_max*1000)
      if val1_txt < 10 then
        val1_txt = math.floor(offs1_max*1000000)..'μs'
       else
        val1_txt = val1_txt..'ms'
      end
      local measurestrname = gfx.measurestr(val1_txt)
      local x0 = x + txt_offs
      local y0 = y
      gfx.x, gfx.y = x0,y0 
      gfx.drawstr(val1_txt)      
    -- text val2  
      local val2_txt = math.floor(offs2_max*1000)
      if val2_txt < 10 then
        val2_txt = math.floor(offs2_max*1000000)..'μs'
       else
        val2_txt = val2_txt..'ms'
      end      
      local measurestrname = gfx.measurestr(val2_txt)
      local x0 = x + w - measurestrname - txt_offs
      local y0 = y
      gfx.x, gfx.y = x0,y0 
      gfx.drawstr(val2_txt) 
      
    --[[ txt count    
      if SM_t and #SM_t > 0 then
        gfx.a = 1
        local x0 = 10 --x
        local y0 = 20 --y + h/2 - gfx.h
        gfx.x, gfx.y = x0,y0 
        gfx.drawstr(' stretch markers') 
      end]]
          
  end
  -----------------------------------------------------------------------    
  function F_gfx_rect(x,y,w,h)
    gfx.x, gfx.y = x,y
    gfx.line(x, y, x+w, y)
    gfx.line(x+w, y+1, x+w, y+h - 1)
    gfx.line(x+w, y+h,x, y+h)
    gfx.line(x, y+h-1,x, y+1)
  end
  -----------------------------------------------------------------------  
  function F_SetColor(col)
     r,g,b = reaper.ColorFromNative( col )
    gfx.r = r/255
    gfx.g = g/255
    gfx.b = b/255
  end
  -----------------------------------------------------------------------         
  function GUI_textbut(obj, gui, obj_t)
    local x,y,w,h = obj_t.x, obj_t.y, obj_t.w, obj_t.h
    -- frame
      gfx.a = 0.05
      F_Get_SSV(gui.color.white, true)
      F_gfx_rect(x,y,w,h) 
    -- back
      gfx.a = 0.9 
      gfx.blit(3, 1, 0, --backgr
        0,0,obj.main_w,obj.main_h/2,
        x,y,w,h, 0,0)
    -- text
      local text = obj_t.name
      if obj_t.is_checkbox then
        if obj_t.val == 1 then text = '☑ '..text else text = '☐ '..text end
      end
      gfx.setfont(1, gui.fontname, gui.fontsize_textb)
      gfx.a = 0.9
      if  obj_t.max_val and obj_t.val >  obj_t.max_val  then 
        F_Get_SSV(gui.color.red, true)
        text = text..' (whooa that`s too much)'
       else
        F_Get_SSV(gui.color.blue, true)
      end
      if obj_t.col then F_SetColor(obj_t.col) else F_SetColor(0) end
      local measurestrname = gfx.measurestr(text)
      local x0 = x + (w - measurestrname)/2
      local y0 = y + (h - gfx.texth)/2 +1
      gfx.x, gfx.y = x0,y0 
      gfx.drawstr(text) 
      
  end  
  -----------------------------------------------------------------------         
  function GUI_button(obj, gui, obj_t, cust_alpha)
    local x,y,w,h = obj_t.x, obj_t.y, obj_t.w, obj_t.h
    -- frame
      gfx.a = 0.1
      F_Get_SSV(gui.color.white, true)
      F_gfx_rect(x,y,w,h)
      
    -- back
      if cust_alpha then gfx.a = cust_alpha else gfx.a = 0.5 end
        gfx.blit(3, 1, math.rad(180), --backgr
        0,0,obj.main_w,obj.main_h/2,
        x,y,w,h+1, 0,0)
        
    -- text
      gfx.setfont(1, gui.fontname, gui.fontsize)
      local measurestrname = gfx.measurestr(obj_t.name)
      local x0 = x + (w - measurestrname)/2 + 1
      local y0 = y + (h - gfx.texth)/2 
      
      gfx.a = 0.9
      F_Get_SSV(gui.color.black, true)
      gfx.x, gfx.y = x0+1,y0 +2
      gfx.drawstr(obj_t.name)
      gfx.a = 1
      F_Get_SSV(gui.color.green, true)
      gfx.x, gfx.y = x0,y0 
      gfx.drawstr(obj_t.name)
      
 
  end   
------------------------------------------------------------------  
  function GUI_draw(obj, gui)         local buf_dest
    gfx.mode = 1 -- additive mode
    local time_flow =0.6--sec
    gfx.rect(0,0,gfx.w,gfx.h, 0)
    -- DRAW static buffers
    if update_gfx_onstart then  
      -- buf3 -- buttons back gradient      
      -- buf4 -- slider  
      -- buf5 -- cent line scale
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
                 
      update_gfx_onstart = nil
    end
    
      
    -- Store Com Buffer
      if  update_gfx then  
        if not alpha_change_dir then alpha_change_dir = 1 end
        alpha_change_dir = math.abs(alpha_change_dir - 1)  
        run_change0 = clock       
        if alpha_change_dir == 0 then buf_dest = 10 else buf_dest = 11 end -- if 0 #10 is next
        gfx.dest = buf_dest
        gfx.a = 1
        gfx.setimgdim(buf_dest, -1, -1)  
        gfx.setimgdim(buf_dest, obj.main_w,obj.main_h*3) 
          --===========================================
          GUI_textbut(obj, gui, obj.trackid)
          GUI_textbut(obj, gui, obj.trackname)
          --===========================================      
        update_gfx = false
      end
      
    --  Define smooth changes 
      if run_change0 then
        T = clock - run_change0
        if clock - run_change0 < time_flow then 
          alpha_change = F_limit((clock - run_change0)/time_flow  + 0.2, 0,1)
        end
      end
      
      
    -- Draw Common buffer
      gfx.dest = -1
      gfx.x,gfx.y = 0,0
      F_Get_SSV(gui.color.back, true)
      gfx.a = 1
      gfx.rect(0,0,gfx.w,gfx.h, 1)
      gfx.mode = 1
      -- smooth com
        local buf1, buf2
        if alpha_change_dir == 0 then buf1 = 10 buf2 = 11 else buf1 = 11 buf2 = 10  end
        local a1 = alpha_change
        local a2 = math.abs(alpha_change - 1)
        gfx.a = a1
        gfx.blit(buf1, 1, 0,
            0,0,  obj.main_w,obj.main_h*3,
            0,0,  obj.main_w,obj.main_h*3, 0,0)
        gfx.a = a2
        gfx.blit(buf2, 1, 0, 
            0,0,  obj.main_w,obj.main_h*3,
            0,0,  obj.main_w,obj.main_h*3, 0,0)           
    
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
----------------------------------------------------------------------- 
  function MOUSE_match(b, offs)
    local mouse_y_match = b.y
    local mouse_h_match = b.y+b.h
    if offs then 
      mouse_y_match = mouse_y_match - offs 
      mouse_h_match = mouse_y_match+b.h
    end
    if mouse.mx > b.x and mouse.mx < b.x+b.w and mouse.my > mouse_y_match and mouse.my < mouse_h_match then return true end 
  end 
-----------------------------------------------------------------------  
  function MOUSE_Click(mouse, xywh_table)
    if MOUSE_match(xywh_table) and mouse.LMB_state and not mouse.last_LMB_state then return true end
  end
  -----------------------------------------------------------------------     
  function MOUSE_button (xywh, offs)
    if MOUSE_match(xywh, offs) and mouse.LMB_state and not mouse.last_LMB_state then return true end
  end  
  -----------------------------------------------------------------------           
  function MOUSE_slider (obj)
    local val
    ret_pow = 1.5
    if MOUSE_match(obj) and (mouse.LMB_state or mouse.RMB_state) then 
      if mouse.mx < obj.x + obj.w/2 then
        if mouse.Alt_state then return true , 1, 0 
         else mouse.last_obj = obj.name end
       else
        if mouse.Alt_state then return true , 2, 0 
         else mouse.last_obj = obj.name..'2' end
      end
    end
    
    if not mouse.Alt_state then 
      if (mouse.last_obj == obj.name or mouse.last_obj == obj.name..'2') and mouse.RMB_state then     
        val = math.abs(F_limit((mouse.mx - obj.x)/obj.w, 0,1) * 2 - 1 )^ret_pow
        return true , 3, math_q(val, 5)
      end
      
      if mouse.last_obj == obj.name then 
        val = math.abs(F_limit((mouse.mx - obj.x)/obj.w, 0,1) * 2 - 1 )^ret_pow
        return true , 1, math_q(val, 5)
       elseif mouse.last_obj == obj.name..'2' then
        val = ((F_limit((mouse.mx - obj.x)/obj.w, 0,1) - 0.5) * 2)^ret_pow
        return true , 2, math_q(val, 5)
      end
    end
    
  end
  
  -----------------------------------------------------------------------         
  function MOUSE_get(obj)
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
    
    -- reset mouse context/doundo
      if not mouse.last_LMB_state and not mouse.last_RMB_state then app = false mouse.last_obj = 0 end
    
    -- proceed undo state
      if not app and last_app then reaper.Undo_OnStateChange(name )end
      last_app = app
      
    -- mouse release
      mouse.last_LMB_state = mouse.LMB_state  
      mouse.last_RMB_state = mouse.RMB_state
      mouse.last_MMB_state = mouse.MMB_state 
      mouse.last_Ctrl_LMB_state = mouse.Ctrl_LMB_state
      mouse.last_Ctrl_state = mouse.Ctrl_state
      mouse.last_Alt_state = mouse.Alt_state
      mouse.last_wheel = mouse.wheel 
  end   
  ------------------------------------------------------------------  
  function F_open_URL(url)  
     if OS=="OSX32" or OS=="OSX64" then
       os.execute("open ".. url)
      else
       os.execute("start ".. url)
     end
   end   
  ------------------------------------------------------------------     
   function DEFINE_TrackData()
    PSCC = reaper.GetProjectStateChangeCount( 0 )
    if not last_PSCC or last_PSCC ~= PSCC then 
      local track =  reaper.GetLastTouchedTrack()
      local _, tr_name = reaper.GetSetMediaTrackInfo_String( track, 'P_NAME', '', false )
      local Tr_data = {
              id = reaper.CSurf_TrackToID( track, false ),
              tr_name = tr_name ,
              col = reaper.GetTrackColor( track )}
      
      if not last_track or last_track ~= track then update_gfx = true end
      last_track = track
      return Tr_data
    end
    last_PSCC = PSCC
   end
  ------------------------------------------------------------------    
  function Run()    
    clock = os.clock()
    Tr_data = DEFINE_TrackData()
    local obj = DEFINE_Objects(Tr_data)
    local gui = DEFINE_GUI_vars()
    GUI_draw(obj, gui)
    MOUSE_get(obj)
    local char = gfx.getchar() 
    if char ~= -1 then reaper.defer(Run) else gfx.quit() end    
  end  
  
    
  OS = reaper.GetOS()
  mouse = {}
  data = {str_val = {L = 0, R = 0}}
  update_gfx = true
  update_gfx_onstart = true
  local obj = DEFINE_Objects()
  gfx.init(name..' // '..vrs, w, h, 1) 
  obj = nil   
  Run()
