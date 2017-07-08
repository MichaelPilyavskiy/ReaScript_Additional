

  local preset = 'last'  
  
  --[[ 
    - pattern editor
    - improved performance
    - import .mid as groove
    - startup actions
    - support for tempo changes
    - support for time signature changes
    - support for snap offset
    - quantize shift
    - PIG engine
    - store pattern per project
  ]]
  
  --[[
    * Changelog:
    * v2.0alpha2 (2016-08-30)
      + Presets
      + Presets: load last config by default
      + Presets: load defaults if config file not exists
    * v2.0alpha1 (2016-05-29) 
      + New GUI
      + Store window position 
    * v1.0 (2015-08-28)
      + Public release     
    * v0.01 (2015-06-23)
      + 'swing items' idea
  --]]
  
  ------------------------------------------------------------------
  
  vrs = "2.0pre1"
  local debug0 = 1
  
  -----------------------------------------------------------------------   
   
    function f_Get_SSV(s)
      if not s then return end
      local t = {}
      for i in s:gmatch("[%d%.]+") do 
        t[#t+1] = tonumber(i) / 255
      end
      gfx.r, gfx.g, gfx.b = t[1], t[2], t[3]
    end
    
  ------------------------------------------------------------------
      
  function msg(s)    
    if debug0 == 1 then 
      reaper.ShowConsoleMsg(s) 
      reaper.ShowConsoleMsg('\n') end
  end
  
  ------------------------------------------------------------------
  function f_GetListItems_xywh(list)
    local item_h = 20
    local x_ind = 4
    local cnt 
    local x,y,w,h = list.x, list.y, list.w, list.h
    if not list.names then cnt = 0 else cnt = #list.names end
    local items = {}
    local y_offs = (h - item_h * cnt)/2
    for i = 1, cnt do
      items[i] = {x = x + x_ind,
                  y = y_offs+y+(i-1)*item_h,
                  w= w - x_ind*2,
                  h = item_h - 1}
    end
    return items
  end
  ------------------------------------------------------------------  
  function DEFINE_Objects()
      local obj = { tab = {},
                    list = {}
                  }    
      obj.main_w = 480
      obj.main_h = 200
      obj.y_offs = 5
      obj.x_offs = 5
      
      -- tabs
        obj.tab.names = { 'General',
                          'Pattern',
                          'PIG',
                          'Options', 
                          'About'}
        local tab_h = 20   
        local tab_w = math.ceil((obj.main_w-obj.x_offs)/#obj.tab.names)    
        for i = 1, #obj.tab.names do          
          obj.tab[i] = { ['x']=obj.x_offs/2 + (i-1)*tab_w,
           ['y']=obj.y_offs,
           ['w']=tab_w,
           ['h']=tab_h}
        end
      
      -- general window lists
        local list_indent_y = 0+ tab_h + obj.y_offs*2
      --  1.0 / 2.0 / 3.0
        local list_w = 80
        obj.list.actionlist = {x = obj.x_offs*2,     y = list_indent_y,
         w = list_w,    h = obj.main_h -list_indent_y- obj.y_offs*2,
         names = {'Quantize', 'Match', 'Create'},       
         active_id = data.action}
        obj.list.actionlist.items_xywh = f_GetListItems_xywh(obj.list.actionlist)
      -- 1.1   quantize objects
        local list_indent_y = 0+ tab_h + obj.y_offs*2
        local list_w = 120
        obj.list.QuantizeObjList = {x = obj.x_offs*3  + obj.list.actionlist.w,     y = list_indent_y,
         w = list_w,    h = obj.main_h -list_indent_y- obj.y_offs*2,
         names = {'Items', 'Str.Markers', 'Env.Points'},       
         active_id = data_int}
        obj.list.QuantizeObjList.items_xywh = f_GetListItems_xywh(obj.list.QuantizeObjList)        
        
        
        
        
        
        
      --[[ knob
        obj.knob = {}
        obj.knob.count = 0
        obj.knob.xywh = {}
        obj.knob.h = 70
        for i = 1, obj.knob.count do
          local w = math.ceil((obj.main_w-obj.x_offs*2)/obj.knob.count)
          obj.knob.xywh[i] = { ['x']=obj.x_offs + (i-1)*w+1,
           ['y']=obj.main_h - obj.knob.h,
           ['w']=w-2,
           ['h']=obj.knob.h-obj.y_offs}
        end]]
                
      
    return obj
  end
  
  -----------------------------------------------------------------------   
  
  function GUI_button(obj, gui, xywh, name, issel, font) local w1_sl_a
    gfx.y,gfx.x = 0,0         
    -- frame
      gfx.a = 1
      F_Get_SSV(gui.color.white, true)
      --gfx.rect(xywh[1],xywh[2],xywh[3], xywh[4]+1, 0 , gui.aa)
      
    -- back
      if issel then gfx.a = 0.8 else gfx.a = 0.2 end
      gfx.blit(3, 1, 0, --backgr
        0,0,objects.main_w, objects.main_h,
        xywh[1],xywh[2],xywh[3],xywh[4], 0,0) 
      
    -- txt              
      
      gfx.setfont(1, gui.fontname, font)
      if issel then
        gfx.a = gui.b_sel_text_alpha
        F_Get_SSV(gui.color.black, true)
       else
        gfx.a = gui.b_sel_text_alpha_unset
        F_Get_SSV(gui.color.white, true)
      end
      local measurestrname = gfx.measurestr(name)
      local x0 = xywh[1] + (xywh[3] - measurestrname)/2
      local y0 = xywh[2] + (xywh[4] - gui.b_sel_fontsize)/2
      gfx.x, gfx.y = x0,y0 
      gfx.drawstr(name)  
  end
  
  -----------------------------------------------------------------------     
  
  function DEFINE_GUI_vars()
    gfx.mode = -1
    
    local gui = {}
      gui.aa = 1
      gui.fontname = 'Calibri'
      gui.fontsize_tab = 18    
      gui.fontsz_knob = 15
      if OS == "OSX32" or OS == "OSX64" then gui.fontsize_tab = gui.fontsize_tab - 5 end
      if OS == "OSX32" or OS == "OSX64" then gui.fontsz_knob = gui.fontsz_knob - 5 end
      
      gui.color = {['back'] = '71 71 71 ',
                      ['back2'] = '51 63 56',
                      ['black'] = '0 0 0',
                      ['green'] = '102 255 102',
                      ['blue'] = '127 204 255',
                      ['white'] = '255 255 255',
                      ['red'] = '255 70 50',
                      ['green_dark'] = '102 153 102',
                      ['yellow'] = '200 200 0',
                      ['pink'] = '200 150 200',
                    }
    return gui
  end
  
  -----------------------------------------------------------------------   
  
  function GUI_knob(obj, gui, knob, tab, id)
    local x,y,w,h, text_len
    if knob[tab] == nil or knob[tab][id] == nil then return end
    
    local text = knob[tab][id].name
    local val_txt = knob[tab][id].value_txt
    local color = knob[tab][id].color
    local is_active = knob[tab][id].is_active
    local val = knob[tab][id].value
    local type = knob[tab][id].type
      -- 1 norm
      -- 2 polar
      -- 3 mirror

    if text == nil then text = '' end    
    if val_txt == nil then val_txt = '' end
    if color == nil then color = 'back' end
    if is_active == nil then is_active = false end
    if val == nil then val = 0 end
    if type == nil then type = 1 end
    
       x,y,w,h = obj.knob.xywh[id].x,
       obj.knob.xywh[id].y,
       obj.knob.xywh[id].w,
       obj.knob.xywh[id].h
    
    -- back
      if is_active then gfx.a = 0.1 else gfx.a = 0.01 end
      gfx.blit(1, 1, math.rad(0), -- backgr
               0,20,obj.main_w, obj.main_h/2,x,y,w,h, 0,0) 
               
    -- arc
      local arc_r = w / 2 * 0.6 
      local ang_gr = 110
      
    -- arc back
      for i = 0, 3, 0.4 do
        if is_active then gfx.a = 0.03 else gfx.a = 0.005  end
        f_Get_SSV(gui.color.white)
        
        -- why THE HELL original gfx.arc() looks like SHIT? -- 
        
        gfx.arc(x+w/2-1,y+h/2+1,arc_r-i,    math.rad(-ang_gr),math.rad(-90),    gui.aa)
        gfx.arc(x+w/2-1,y+h/2-1,arc_r-i,    math.rad(-90),math.rad(0),    gui.aa)
        gfx.arc(x+w/2,y+h/2-1,arc_r-i,    math.rad(0),math.rad(90),    gui.aa)
        gfx.arc(x+w/2,y+h/2+1,arc_r-i,    math.rad(90),math.rad(ang_gr),    gui.aa)
      end
    
      
    -- arc val
    
      if is_active then gfx.a = 0.3 else gfx.a = 0.03 end
      
      if type == 1 then 
        local ang_val = math.rad(-ang_gr+ang_gr*2*val)
        for i = 0, 3, 0.4 do
          f_Get_SSV(gui.color[color])
          if ang_val < math.rad(-90) then 
            gfx.arc(x+w/2-1,y+h/2+1,arc_r-i,    math.rad(-ang_gr),ang_val, gui.aa)
           else
            if ang_val < math.rad(0) then 
              gfx.arc(x+w/2-1,y+h/2+1,arc_r-i,    math.rad(-ang_gr),math.rad(-90), gui.aa)
              gfx.arc(x+w/2-1,y+h/2-1,arc_r-i,    math.rad(-90),ang_val,    gui.aa)
             else
              if ang_val < math.rad(90) then 
                gfx.arc(x+w/2-1,y+h/2+1,arc_r-i,    math.rad(-ang_gr),math.rad(-90), gui.aa)
                gfx.arc(x+w/2-1,y+h/2-1,arc_r-i,    math.rad(-90),math.rad(0),    gui.aa)
                gfx.arc(x+w/2,y+h/2-1,arc_r-i,    math.rad(0),ang_val,    gui.aa)
               else
                if ang_val < math.rad(ang_gr) then 
                  gfx.arc(x+w/2-1,y+h/2+1,arc_r-i,    math.rad(-ang_gr),math.rad(-90), gui.aa)
                  gfx.arc(x+w/2-1,y+h/2-1,arc_r-i,    math.rad(-90),math.rad(0),    gui.aa)
                  gfx.arc(x+w/2,y+h/2-1,arc_r-i,    math.rad(0),math.rad(90),    gui.aa)
                  gfx.arc(x+w/2,y+h/2+1,arc_r-i,    math.rad(90),ang_val,    gui.aa)
                 else
                  gfx.arc(x+w/2-1,y+h/2+1,arc_r-i,    math.rad(-ang_gr),math.rad(-90),    gui.aa)
                  gfx.arc(x+w/2-1,y+h/2-1,arc_r-i,    math.rad(-90),math.rad(0),    gui.aa)
                  gfx.arc(x+w/2,y+h/2-1,arc_r-i,    math.rad(0),math.rad(90),    gui.aa)
                  gfx.arc(x+w/2,y+h/2+1,arc_r-i,    math.rad(90),math.rad(ang_gr),    gui.aa)                  
                end
              end
            end                
          end
        end
      end -- end type1  
        
      if type == 2 then -- polar
        for i = 0, 3, 0.4 do
          f_Get_SSV(gui.color[gui.color[color] ])
          if val >= 0 then   
            local ang_val = math.rad(ang_gr*val)
            if ang_val < math.rad(90) then
              gfx.arc(x+w/2,y+h/2-1,arc_r-i,    math.rad(0),ang_val,    gui.aa)
             else
              gfx.arc(x+w/2,y+h/2-1,arc_r-i,    math.rad(0),math.rad(90),    gui.aa)
              gfx.arc(x+w/2,y+h/2+1,arc_r-i,    math.rad(90),ang_val,    gui.aa)
            end
           else
            local ang_val = math.rad(ang_gr*val)
            if ang_val > math.rad(-90) then
              gfx.arc(x+w/2-1,y+h/2-1,arc_r-i,    math.rad(0),ang_val,    gui.aa)
             else
              gfx.arc(x+w/2-1,y+h/2-1,arc_r-i,    math.rad(-90),math.rad(0),    gui.aa)
              gfx.arc(x+w/2-1,y+h/2+1,arc_r-i,    ang_val,math.rad(-90),    gui.aa)
            end
          end
        end
      end -- end type 2
      
      if type == 3 then -- mirror
        for i = 0, 3, 0.4 do
          f_Get_SSV(gui.color[gui.color[color] ])
          local ang_val = math.rad(ang_gr*val)
          if ang_val < math.rad(90) then
            gfx.arc(x+w/2,y+h/2-1,arc_r-i,    math.rad(0),ang_val,    gui.aa)
            gfx.arc(x+w/2-1,y+h/2-1,arc_r-i,    -ang_val,math.rad(0),    gui.aa)
           else
            gfx.arc(x+w/2,y+h/2-1,arc_r-i,    math.rad(0),math.rad(90),    gui.aa)
            gfx.arc(x+w/2,y+h/2+1,arc_r-i,    math.rad(90),ang_val,    gui.aa)
            gfx.arc(x+w/2-1,y+h/2+1,arc_r-i,    -ang_val,math.rad(-90),    gui.aa)
            gfx.arc(x+w/2-1,y+h/2-1,arc_r-i,    math.rad(-90),math.rad(0),    gui.aa)
          end
        end
      end -- end type 3      
               
      f_Get_SSV(gui.color[color])
      
    -- text
      if is_active then gfx.a = 0.8 else gfx.a = 0.1 end
      gfx.setfont(1, gui.fontname, gui.fontsz_knob)
      text_len = gfx.measurestr(text)
      gfx.x, gfx.y = x+(w-text_len)/2,y+h-gfx.texth-2
      gfx.drawstr(text)
  
    -- text
      gfx.setfont(1, gui.fontname, gui.fontsz_knob)
      text_len = gfx.measurestr(val_txt)
      gfx.x, gfx.y = x+(w-text_len)/2,y+(h-gfx.texth)/2
      gfx.drawstr(val_txt)     
  end
    
  -----------------------------------------------------------------------  
  function GUI_tab(obj, gui, id) 
    local a, offs, offs2, r ,x,y,w,h, w_tab
    local x,y,w,h = 
      obj.tab[id].x,
      obj.tab[id].y, 
      obj.tab[id].w, 
      obj.tab[id].h
    offs = 2
    offs2 = 5 -- tab indent
    r = 3
    f_Get_SSV(gui.color.back)
    -- back
      if data.active_tab == id then 
        w_tab = obj.main_w / #obj.tab.names
        gfx.a = 1
        gfx.muladdrect(0,0,obj.main_w,obj.main_h,1,1,1,0.7,0,0.01,0,0 )
        
        gfx.a = 0.0
        gfx.blit(1, 1, math.rad(180), 
          0,  0,  obj.main_w,   obj.main_h/2,
          obj.x_offs,   y+h,   obj.main_w-obj.x_offs*2 ,  (obj.main_h -h-obj.x_offs*2),   0,0) 
        gfx.blit(1, 1, math.rad(0),
          0,0,obj.main_w, obj.main_h/2,
          x+offs2,    y,    w-offs2*2,    h,    0,0)
      -- frame  
        gfx.a = 0.15
        gfx.x,gfx.y = x+offs2,y
        gfx.lineto(x+w-offs2,y)
        gfx.lineto(x+w-offs2,y+h)
        gfx.lineto(obj.main_w-obj.x_offs ,y+h)
        gfx.lineto(obj.main_w-obj.x_offs ,obj.main_h -obj.y_offs)
        gfx.lineto(obj.x_offs ,obj.main_h -obj.y_offs)
        gfx.lineto(obj.x_offs ,y+h)
        gfx.lineto(x+offs2 ,y+h)
        gfx.lineto(x+offs2 ,y)
       else
        gfx.a = 0.1
        gfx.rect(x+offs2,y,w-offs2*2,h,1)
      end
    -- text
    f_Get_SSV(gui.color.white)
    if data.active_tab == id then gfx.a = 0.8 else gfx.a = 0.1 end
    
    gfx.setfont(1, gui.fontname, gui.fontsize_tab, 1)
    gfx.x = x + (w-gfx.measurestr(obj.tab.names[id]))/2
    gfx.y = y + (h-gfx.texth)/2
    gfx.drawstr(obj.tab.names[id])   
           
  end
  -----------------------------------------------------------------------    
  function GUI_List(gui, obj, list)
    -- frame
      local x,y,w,h = list.x, list.y, list.w, list.h
      --gfx.a = 0.02
      --gfx.rect(x,y,w,h,0)
    -- items 
      gfx.setfont(1, gui.fontname, gui.fontsize_tab, 1)  
      if list.names then
        for i = 1, #list.names do
          local ix,iy,iw,ih = list.items_xywh[i].x,
                        list.items_xywh[i].y,
                        list.items_xywh[i].w,
                        list.items_xywh[i].h
          
          gfx.a = 0.01
          --gfx.rect(ix,iy,iw,ih,0,1)
          local text_alpha = 0.1
          if list.active_id == i-1 then
            gfx.a = 0.10
            gfx.blit(1, 1, math.rad(0), 
                    0,10, obj.main_w, obj.main_h/2,
                    ix, iy, iw,ih/2, 0,0) 
            gfx.blit(1, 1, math.rad(180), 
                    0,10, obj.main_w, obj.main_h/2,
                    ix, iy+ ih/2, iw + 2, ih/2, -10,0)  
            text_alpha = 0.7  
          end                   
            
          
          gfx.x = x + (w-gfx.measurestr(list.names[i]))/2
          gfx.y = iy
          gfx.a = text_alpha
          gfx.drawstr(list.names[i])
        end
      end    
  end
  -----------------------------------------------------------------------      
  function GUI_draw(gui, obj, data, knob)
    
    
    -- smooth change
      if update_gfx  then 
        if not alpha_change_dir then alpha_change_dir = 1 end
        alpha_change_dir = math.abs(alpha_change_dir - 1)
      end                  
      if update_gfx then run_change0 = clock  end    
      if run_change0 then
        local time_flow = 0.3--sec
        if clock - run_change0 < time_flow then 
          alpha_change = f_limit((clock - run_change0)/time_flow  + 0.1, 0,1)
        end
      end
    
    
    -- buffers
      -- 1 gradient
      -- 10-11 common/smooth
      -- 12 main back
      
      
    --------------------------------------  
    -- 1 GRADIENT
      if update_gfx then    
        --msg('=============\nDEFINE_GUI_buffers_1-buttons back')  
        gfx.dest = 1
        gfx.setimgdim(1, -1, -1)  
        gfx.setimgdim(1, obj.main_w, obj.main_h)  
        gfx.gradrect(0,0, obj.main_w, obj.main_h, 1,1,1,0.7, 0,0.001,0,0.0001, 0,0,0,-0.005)
      end 
         
    --------------------------------------
    -- 10 main window
      if update_gfx then   
        local buf_dest
        if alpha_change_dir == 0 then buf_dest = 10 else buf_dest = 11 end -- if 0 #10 is next
        gfx.dest = buf_dest
        gfx.a = 1
        gfx.setimgdim(buf_dest, -1, -1)  
        gfx.setimgdim(buf_dest, obj.main_w, obj.main_h)  
        -- back
          gfx.a = 0.4
          f_Get_SSV(gui.color.back)
          gfx.rect(0,0, obj.main_w, obj.main_h,1)
          
        -- tabs
          for id = 1, #obj.tab.names do GUI_tab(obj, gui, id) end
        
        -- knobs
          --for id = 1, obj.knob.count do GUI_knob(obj, gui, knob, data.active_tab, id) end
        
        if data.active_tab == 1 then
          -- list
            GUI_List(gui, obj, obj.list.actionlist)
              if data.action == 0 then GUI_List(gui, obj, obj.list.QuantizeObjList) end
        end
      end    
      
    --------------------------------------
    -- DRAW COMMON BUFFER
    
      gfx.dest = -1
      gfx.x,gfx.y = 0,0
                  
      -- smooth com
        local buf1, buf2
        if alpha_change_dir == 0 then buf1 = 10 buf2 = 11 else buf1 = 11 buf2 = 10  end
        local a1 = alpha_change
        local a2 = math.abs(alpha_change - 1)
        gfx.a = a1
        gfx.blit(buf1, 1, 0,
            0,0, obj.main_w, obj.main_h,
            0,0, obj.main_w, obj.main_h, 0,0)
        gfx.a = a2
        gfx.blit(buf2, 1, 0, 
            0,0, obj.main_w, obj.main_h,
            0,0, obj.main_w, obj.main_h, 0,0)
          
    gfx.update()
    update_gfx = false
  end      

  ------------------------------------------------------------------
  
  function CONF_GetDefaults()    
    local  default_data = {       main_x = 0,
                           main_y = 0,
                              
                           active_tab = 1,
                            
                           action = 0, -- 0 - quantize, 1 - match, 2 - create
                           
                           GetObjOnStart = 0 -- 0 nothing,
                           -- main --
                           --random = 0,
                           --shift = 0,
                           --gravity = 0,
                           --swing = 0,
                           --strength = 0,
                           
                           
                           
                          }
                          
    return default_data
  end 
 ----------------------------------------------------------------------- 
  function f_limit(val,min,max)
      if val == nil or min == nil or max == nil then return end
      local val_out = val
      if val < min then val_out = min end
      if val > max then val_out = max end
      return val_out
    end 
----------------------------------------------------------------------- 
  function MOUSE_match(b)
    if mouse.mx > b.x and mouse.mx < b.x+b.w and mouse.my > b.y and mouse.my < b.y+b.h then return true end 
  end 
-----------------------------------------------------------------------  
  function MOUSE_Click(mouse, xywh_table)
    if MOUSE_match(xywh_table) and mouse.LMB_state and not mouse.last_LMB_state then return true end
  end
  -----------------------------------------------------------------------     
  function MOUSE_button (xywh)
    if MOUSE_match(xywh) and mouse.LMB_state and not mouse.last_LMB_state then return true end
  end
  -----------------------------------------------------------------------  
  function MOUSE_list(list)
    for i = 1, #list.names do
      if MOUSE_button (list.items_xywh[i]) then 
        update_gfx = true
        return true, i-1
      end        
    end
    if MOUSE_match (list) and mouse.wheel_trig > 0 then  
      update_gfx = true
      return true, f_limit(list.active_id-1, 0, #list.names-1)
    end  
    if MOUSE_match (list) and mouse.wheel_trig < 0 then  
      update_gfx = true
      return true, f_limit(list.active_id+1, 0, #list.names-1)
    end
  end
  -----------------------------------------------------------------------         
  function MOUSE_get(obj, knob)
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
    
    
    --[[mouse.wheel_res = 4800    
    mouse.d_res = 100
    if mouse.Ctrl_state then mouse.d_res = 1000 end    
    if mouse.last_wheel ~= nil then 
      mouse.wheel_diff = -mouse.last_wheel +mouse.wheel
     else
      mouse.wheel_diff = 0
    end    
    if mouse.LMB_state and not mouse.last_LMB_state then    
      mouse.last_mx_onclick = mouse.mx
      mouse.last_my_onclick = mouse.my
    end           
    if mouse.last_mx_onclick ~= nil and mouse.last_my_onclick ~= nil then
      mouse.dx = mouse.mx - mouse.last_mx_onclick
      mouse.dy = mouse.my - mouse.last_my_onclick
     else
      mouse.dx, mouse.dy = 0,0
    end          
    if not mouse.LMB_state  then mouse.context = nil end    
    if mouse.last_LMB_state and not mouse.LMB_state then mouse.last_touched = nil end    
    mouse.last_mx = 0
    mouse.last_my = 0
    ]]
    
    -- tabs
      for i = 1, #obj.tab.names do
        if MOUSE_button(obj.tab[i]) then
          update_gfx = true
          data.active_tab = i
          CONF_Write_INI(file_path)
          break
        end
      end
      
    -- General tab
      -- actions list
        local ret, id = MOUSE_list(obj.list.actionlist)
        if ret then 
          data.action = id 
          CONF_Write_INI(file_path) 
        end
      
      
          
    mouse.last_LMB_state = mouse.LMB_state  
    mouse.last_RMB_state = mouse.RMB_state
    mouse.last_MMB_state = mouse.MMB_state 
    mouse.last_Ctrl_LMB_state = mouse.Ctrl_LMB_state
    mouse.last_Ctrl_state = mouse.Ctrl_state
    mouse.last_wheel = mouse.wheel 
  end
  ------------------------------------------------------------------    
  function CONF_SaveScreenPos()
    _, data.main_x, data.main_y = gfx.dock(-1, data.main_x, data.main_y)
    if not last_main_x or not last_main_y 
        or last_main_x ~= data.main_x or last_main_y ~= data.main_y then 
        CONF_Write_INI(file_path)
    end
    last_main_x,last_main_y = data.main_x,data.main_y
  end
  ------------------------------------------------------------------    
  function Run()
    clock = os.clock()
    CONF_SaveScreenPos()
        
    local obj = DEFINE_Objects()
    local gui = DEFINE_GUI_vars()
    --local knob = DEFINE_Knobs()
    GUI_draw(gui, obj, data, knob)
    MOUSE_get(obj, knob)
    
    local char = gfx.getchar() 
    if char == 32 then reaper.Main_OnCommandEx(40044, 0,0) end
    if char == 27 then gfx.quit() end     
    if char ~= -1 then reaper.defer(Run) else gfx.quit() end
    
  end
  
  ---------------------------------------------------------------------------------------------------------
  function CONF_ParseINI(file)    
    -- http://github.com/Dynodzzo/Lua_INI_Parser/blob/master/LIP.lua
    if not file then return end
    local data = {}
          local section;
          for line in file:lines() do
            tempSection = line:match('^%[([^%[%]]+)%]$');
            if(tempSection)then
              section = tonumber(tempSection) and tonumber(tempSection) or tempSection;
              data[section] = data[section] or {};
            end
            local param, value = line:match('^([%w|_]+)%s-=%s-(.+)$');
            if(param and value ~= nil)then
              if(tonumber(value))then
                value = tonumber(value);
              elseif(value == 'true')then
                value = true;
              elseif(value == 'false')then
                value = false;
              end
              if(tonumber(param))then
                param = tonumber(param);
              end
              data[section][param] = value;
            end
          end
          
          file:close();
    return data
  end
  ---------------------------------------------------------------------------------------------------------
  function CONF_Load_INI(fileName, preset)
    -- load defaults to data
      data = CONF_GetDefaults()
    -- check file/get content
      local file = io.open(fileName, 'r')
      if file then 
        local ini_t = CONF_ParseINI(file)
        if ini_t and ini_t[preset] then
          for key in pairs(data) do
            if ini_t[preset][key] then data[key] = ini_t[preset][key] end
          end
        end
      end
  end
  ------------------------------------------------------------------
  function CONF_Write_INI(file_path, preset)
    reaper.BR_Win32_WritePrivateProfileString( 'debug', 'LastSave', os.date(), file_path)
    reaper.BR_Win32_WritePrivateProfileString( 'debug', 'vrs', vrs, file_path)
    if not preset then preset = 'last' end
    for key in pairs(data) do
      reaper.BR_Win32_WritePrivateProfileString( preset, key, data[key], file_path)
    end
  end
  ------------------------------------------------------------------  
  function CONF_GetConfPath()
    -- check if congig exists/load CONFig
      local t = debug.getinfo(1)
      file_path = t.source:sub(2,-t.source:reverse():find('%.')-1)..'_config.ini'
      if file_path then 
        local file = io.open(file_path, 'r')
        if file then file:close() return file_path end
      end    
    -- create file
      local file = io.open(file_path, 'w')
      file:close()      
    return file_path
  end
  ------------------------------------------------------------------  
  
  OS = reaper.GetOS()
  mouse = {}
  Q_obj = {}
  update_gfx = true
  file_path = CONF_GetConfPath()
  CONF_Load_INI(file_path, preset)
  CONF_Write_INI(file_path, preset)
  local obj = DEFINE_Objects(data)
  gfx.init("mpl QuantizeTool "..vrs, obj.main_w, obj.main_h,0, 
    data.main_x, 
    data.main_y)    
  Run()
  
  ------------------------------------------------------------------
  ------------------------------------------------------------------
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  --[[----------------------------------------------------------------
  
  fu nction DEFINE_Knobs()
    --[[knob = {}
    
    knob[1] = {} -- main tab    
    knob[1][1] = {['name'] = 'Randomize',
                  ['is_active'] = true,                  
                  ['color'] = 'green',
                  ['type'] = 1,
                  ['value'] = data.random,
                  ['value_txt'] = math.floor(data.random*100)..' %' ,
                  ['value_raw'] = "random"
                  }
                  
    knob[1][2] = {['name'] = 'Shift',
                  ['is_active'] = true,                  
                  ['color'] = 'green',
                  ['type'] = 2,
                  ['value'] = data.shift,
                  ['value_txt'] = math.floor(data.shift*100)..' %' ,
                  ['value_raw'] = "shift"
                  }
                  
                  
    knob[1][3] = {['name'] = 'Gravity',
                  ['is_active'] = true,                  
                  ['color'] = 'green',
                  ['type'] = 3,
                  ['value'] = data.gravity,
                  ['value_txt'] = math.floor(data.gravity*100)..' %' ,
                  ['value_raw'] = "gravity"
                  }
                  
    knob[1][4] = {['name'] = 'Swing',
                  ['is_active'] = true,                  
                  ['color'] = 'green',
                  ['type'] = 1,
                  ['value'] = data.swing,
                  ['value_txt'] = math.floor(data.swing*100)..' %' ,
                  ['value_raw'] = "swing"
                  }
                  
    knob[1][5] = {['name'] = 'Strength',
                  ['is_active'] = true,                  
                  ['color'] = 'red',
                  ['type'] = 1,
                  ['value'] = data.strength,
                  ['value_txt'] = math.floor(data.strength*100)..' %' ,
                  ['value_raw'] = "strength"
                  }
                  
                  
    return knob
  end
  ]]
  
  --[[ knob / mousewheel
    for i = 1, obj.knob.count do
      if MOUSE_match(obj.knob.xywh[i]) and mouse.wheel_diff ~= 0 then
        if knob[active_tab] 
            and knob[active_tab][i] 
            and data['preset_-1'][ knob[active_tab][i].value_raw ]
         then
          if knob[active_tab][i].type == 1 or  knob[active_tab][i].type == 3 then
            data['preset_-1'][ knob[active_tab][i].value_raw ] = 
              F_limit( data['preset_-1'][ knob[active_tab][i].value_raw ]  
                  + mouse.wheel_diff/mouse.wheel_res,
                  0,1)
           else 
            data['preset_-1'][ knob[active_tab][i].value_raw ] = 
             F_limit( data['preset_-1'][ knob[active_tab][i].value_raw ]  
                + mouse.wheel_diff/mouse.wheel_res,
                -1,1)
          end
        end
        update_gfx = true
        SetData(file_path, data)
      end
    end
    
  -- knob / lefthold        
    for i = 1, obj.knob.count do
      -- store context
      if MOUSE_match(obj.knob.xywh[i]) 
        and mouse.LMB_state 
        and not mouse.last_LMB_state 
       then
        mouse.context = 'knob_'..i
        mouse.val_on_click = data['preset_-1'][ knob[active_tab][i].value_raw ]
      end
      -- match context
      if mouse.LMB_state  and mouse.context == 'knob_'..i then
        if knob[active_tab][i].type == 1 or  knob[active_tab][i].type == 3 then
          data['preset_-1'][ knob[active_tab][i].value_raw ] = 
            F_limit( mouse.val_on_click- mouse.dy/mouse.d_res, 0,1)
         else
          data['preset_-1'][ knob[active_tab][i].value_raw ] = 
            F_limit( mouse.val_on_click- mouse.dy/mouse.d_res, -1,1)
        end              
        if mouse.Alt_state then -- set by defauilt on alt hold
          data['preset_-1'][ knob[active_tab][i].value_raw ] = 
            data['preset_0'][ knob[active_tab][i].value_raw ]
        end
        update_gfx = true
        SetData(file_path, data)
      end
    end]]
    
    
  
