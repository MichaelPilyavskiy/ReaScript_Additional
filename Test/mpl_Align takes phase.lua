

  --check: show all takes
  -- move content
  --//disable for loop source takerate != 1
        
  ------------------------------------------------------------------
  
  local vrs = "0.1"
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
  
  function GetObjects()
      local  obj = {}    
      obj.main_w = 300
      obj.main_h = 300
      obj.y_offs = 5
      obj.x_offs = 5
      
      -- tabs
        obj.tab = {}
        obj.tab.names = {'General','About'}
        obj.tab.xywh = {}
        obj.tab.h = 20        
        for i = 1, #obj.tab.names do
          local w = math.ceil((obj.main_w-obj.x_offs)/#obj.tab.names)
          obj.tab.xywh[i] = { ['x']=obj.x_offs/2 + (i-1)*w,
           ['y']=obj.y_offs,
           ['w']=w,
           ['h']=obj.tab.h}
        end

      -- knob
        obj.knob = {}
        obj.knob.count =3
        obj.knob.xywh = {}
        obj.knob.h = 80
        for i = 1, obj.knob.count do
          local w = math.floor((obj.main_w - obj.x_offs*2) /obj.knob.count)
          obj.knob.xywh[i] = { ['x']=obj.x_offs + (i-1)*w+1,
           ['y']=obj.main_h - obj.knob.h,
           ['w']=w,
           ['h']=obj.knob.h-obj.y_offs}
        end
      
      -- takes_disp
        obj.takes_disp = {}
        obj.takes_disp.xywh = {
          ['x']=obj.x_offs*2,
          ['y']=obj.y_offs*2 + obj.tab.h,
          ['w']=obj.main_w-obj.x_offs*4}
        obj.takes_disp.xywh.h = obj.main_h - obj.knob.h-obj.tab.h*3-obj.y_offs*6
      
      -- buttons
        obj.buttons = {['xywh']={}}
        obj.buttons.xywh[1] = {
                  ['x']=obj.x_offs*2,
                  ['y']=obj.y_offs*3 + obj.tab.h + obj.takes_disp.xywh.h,
                  ['w']=obj.main_w-obj.x_offs*4,
                  ['h']=obj.tab.h} 
               
        obj.buttons.xywh[2] = {['x']=obj.x_offs*2,
                           ['y']=obj.buttons.xywh[1].y + obj.buttons.xywh[1].h + obj.y_offs,
                           ['w']=obj.main_w-obj.x_offs*4,
                           ['h']=obj.tab.h}
                         
        obj.buttons.xywh[3] = obj.knob.xywh[2]
        
                  
    return obj
  end
  
  
  -----------------------------------------------------------------------     
  
  function GetGUI_vars()
    gfx.mode = 0
    
    local gui = {}
      gui.aa = 1
      gui.fontname = 'Calibri'
      gui.fontsize_tab = 20    
      gui.fontsz_knob = 18
      if OS == "OSX32" or OS == "OSX64" then gui.fontsize_tab = gui.fontsize_tab - 5 end
      if OS == "OSX32" or OS == "OSX64" then gui.fontsz_knob = gui.fontsz_knob - 5 end
      if OS == "OSX32" or OS == "OSX64" then gui.fontsz_get = gui.fontsz_get - 5 end
      
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
      if is_active then gfx.a = 0.1 else gfx.a = 0.1 end
      gfx.blit(1, 1, math.rad(0), -- backgr
               0,20,obj.main_w, obj.main_h/2,x,y,w,h, 0,0) 
               
    -- arc
      local arc_r = w / 2 * 0.7 
      local ang_gr = 110      
      local arc_w = 7
      
      local x_fix = 0
    -- arc back
      if type > 0 then
        for i = 0, arc_w, 0.4 do
          if is_active then gfx.a = 0.02 else gfx.a = 0.009  end
          f_Get_SSV(gui.color.white)
          
          -- why THE HELL original gfx.arc() looks like SHIT? -- 
          
          gfx.arc(x+w/2-1,y+h/2+1,arc_r-i,    math.rad(-ang_gr),math.rad(-90),    gui.aa)
          gfx.arc(x+w/2-1,y+h/2-1,arc_r-i,    math.rad(-90),math.rad(0),    gui.aa)
          gfx.arc(x+w/2+x_fix,y+h/2-1,arc_r-i,    math.rad(0),math.rad(90),    gui.aa)
          gfx.arc(x+w/2+x_fix,y+h/2+1,arc_r-i,    math.rad(90),math.rad(ang_gr),    gui.aa)
        end
    end
      
    -- arc val
    
      if is_active then gfx.a = 0.5 else gfx.a = 0.09 end
      
      if type == 1 then 
        local ang_val = math.rad(-ang_gr+ang_gr*2*val)
        for i = 0, arc_w, 0.4 do
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
                gfx.arc(x+w/2+x_fix,y+h/2-1,arc_r-i,    math.rad(0),ang_val,    gui.aa)
               else
                if ang_val < math.rad(ang_gr) then 
                  gfx.arc(x+w/2-1,y+h/2+1,arc_r-i,    math.rad(-ang_gr),math.rad(-90), gui.aa)
                  gfx.arc(x+w/2-1,y+h/2-1,arc_r-i,    math.rad(-90),math.rad(0),    gui.aa)
                  gfx.arc(x+w/2+x_fix,y+h/2-1,arc_r-i,    math.rad(0),math.rad(90),    gui.aa)
                  gfx.arc(x+w/2+x_fix,y+h/2+1,arc_r-i,    math.rad(90),ang_val,    gui.aa)
                 else
                  gfx.arc(x+w/2-1,y+h/2+1,arc_r-i,    math.rad(-ang_gr),math.rad(-90),    gui.aa)
                  gfx.arc(x+w/2-1,y+h/2-1,arc_r-i,    math.rad(-90),math.rad(0),    gui.aa)
                  gfx.arc(x+w/2+x_fix,y+h/2-1,arc_r-i,    math.rad(0),math.rad(90),    gui.aa)
                  gfx.arc(x+w/2+x_fix,y+h/2+1,arc_r-i,    math.rad(90),math.rad(ang_gr),    gui.aa)                  
                end
              end
            end                
          end
        end
      end -- end type1  
        
      if type == 2 then -- polar
        for i = 0, arc_w, 0.4 do
          f_Get_SSV(gui.color[gui.color[color] ])
          if val >= 0 then   
            local ang_val = math.rad(ang_gr*val)
            if ang_val < math.rad(90) then
              gfx.arc(x+w/2+x_fix,y+h/2-1,arc_r-i,    math.rad(0),ang_val,    gui.aa)
             else
              gfx.arc(x+w/2+x_fix,y+h/2-1,arc_r-i,    math.rad(0),math.rad(90),    gui.aa)
              gfx.arc(x+w/2+x_fix,y+h/2+1,arc_r-i,    math.rad(90),ang_val,    gui.aa)
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
        for i = 0, arc_w, 0.4 do
          f_Get_SSV(gui.color[gui.color[color] ])
          local ang_val = math.rad(ang_gr*val)
          if ang_val < math.rad(90) then
            gfx.arc(x+w/2+x_fix,y+h/2-1,arc_r-i,    math.rad(0),ang_val,    gui.aa)
            gfx.arc(x+w/2-1,y+h/2-1,arc_r-i,    -ang_val,math.rad(0),    gui.aa)
           else
            gfx.arc(x+w/2+x_fix,y+h/2-1,arc_r-i,    math.rad(0),math.rad(90),    gui.aa)
            gfx.arc(x+w/2+x_fix,y+h/2+1,arc_r-i,    math.rad(90),ang_val,    gui.aa)
            gfx.arc(x+w/2-1,y+h/2+1,arc_r-i,    -ang_val,math.rad(-90),    gui.aa)
            gfx.arc(x+w/2-1,y+h/2-1,arc_r-i,    math.rad(-90),math.rad(0),    gui.aa)
          end
        end
      end -- end type 3      
               
      f_Get_SSV(gui.color[color])
      
    -- text
      if is_active then gfx.a = 0.9 else gfx.a = 0.2 end
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
    
  function GUI_button(obj, gui, button, tab, id)
    
    local x,y,w,h = obj.buttons.xywh[id].x, 
      obj.buttons.xywh[id].y,
      obj.buttons.xywh[id].w, 
      obj.buttons.xywh[id].h  
          
      -- back frame
          if button[tab][id].value == 1 then gfx.a = 0.2 else gfx.a = 0.01 end
          gfx.blit(1, 1, math.rad(0), -- backgr
                   0,50,obj.main_w, obj.main_h/6,x,y,w+1,h, 0,0)
       
      -- text
        local text = button[tab][id].name
        f_Get_SSV(gui.color[ button[tab][id].color])   
        if button[tab][id].value == 1 then gfx.a = 0.8 else gfx.a = 0.08 end
        gfx.setfont(1, gui.fontname, gui.fontsz_knob)
        local text_len = gfx.measurestr(text)
        gfx.x, gfx.y = x+(w-text_len)/2,y+(h-gfx.texth)/2 + 1
        gfx.drawstr(text)
    
  end  
  
  -----------------------------------------------------------------------   
  
  function f_gfx_rect(x,y,w,h)
    gfx.x, gfx.y = x,y
    gfx.line(x,y, x+w-1, y)
    gfx.line(x+w,y, x+w, y+h-2)
    gfx.line(x+w,y+h-1, x-1, y+h-1)
    gfx.line(x-1,y+h-2, x-1, y)
  end  
  
  -----------------------------------------------------------------------   
  
    function GUI_tab(obj, gui, id) local a, offs, offs2, r ,x,y,w,h, w_tab, lev
    local x,y,w,h = 
      obj.tab.xywh[id].x,
      obj.tab.xywh[id].y, 
      obj.tab.xywh[id].w, 
      obj.tab.xywh[id].h
      
    offs = 2
    offs2 = 5 -- tab indent
    r = 3
    
    f_Get_SSV(gui.color.back)
    
    -- back + frame
      if data['preset_-1'].active_tab == id then 
        w_tab = obj.main_w / #obj.tab.names
        gfx.a = 1
        gfx.muladdrect(0,0,obj.main_w,obj.main_h,1,1,1,0.8,0,0.01,0,0 )
        gfx.a = 0.07
        gfx.blit(1, 1, math.rad(0),
          0,0,obj.main_w, obj.main_h/2,
          x+offs2,y,w-offs2*2,h, 0,0)
        if id ==1 then lev = obj.main_h -obj.knob.h-obj.y_offs
        else lev = obj.main_h-obj.y_offs end
        gfx.a = 1
        gfx.x,gfx.y = x+offs2,y
        gfx.lineto(x+w-offs2,y)
        gfx.lineto(x+w-offs2,y+h)
        gfx.lineto(obj.main_w-obj.x_offs ,y+h)
        gfx.lineto(obj.main_w-obj.x_offs ,lev)
        gfx.lineto(obj.x_offs , lev           )
        gfx.lineto(obj.x_offs ,y+h)
        gfx.lineto(x+offs2 ,y+h)
        gfx.lineto(x+offs2 ,y)
       else
        gfx.a = 0.1
        gfx.rect(x+offs2,y,w-offs2*2,h,1)
      end
    
      
    
 -- text
    f_Get_SSV(gui.color.white)
    if data['preset_-1'].active_tab == id then gfx.a = 0.8 else gfx.a = 0.1 end
    
    gfx.setfont(1, gui.fontname, gui.fontsize_tab, 1)
    gfx.x = x + (w-gfx.measurestr(obj.tab.names[id]))/2
    gfx.y = y + (h-gfx.texth)/2
    gfx.drawstr(obj.tab.names[id])   
           
  end
  
  -----------------------------------------------------------------------   
    
  function GUI_array(obj, gui, id) local val
    local sc = 100
    if takes and takes[id] and takes[id].sample_array then
      gfx.x = 0
      gfx.y = obj.main_h/2 + takes[id].sample_array[1]*sc
      local sample_count = takes[1].sample_array.get_alloc()
      for i = 1, sample_count, 20 do
        if i < takes[id].sample_array.get_alloc() then
          val = takes[id].sample_array[i]
          gfx.lineto( (obj.main_w / sample_count) * i,
                      obj.main_h/2 + val*sc)
                    end
      end
    end
    return sample_count
  end
  
  -----------------------------------------------------------------------   
  
  function GUI_draw(gui, obj, data, knob, button)
    ---if update_gfx then   msg('upd gui') end
    -- buffers
      -- 1 gradient
      -- 2 wait screen
      -- 3 back,tabs
      -- 4 takes window
      
      --11-27 draw_blit_arrays
      
    --------------------------------------  
    -- 1 GRADIENT
      if update_gfx then    
        --msg('=============\nDEFINE_GUI_buffers_1-buttons back')  
        gfx.dest = 1
        gfx.setimgdim(1, -1, -1)  
        gfx.setimgdim(1, obj.main_w, obj.main_h)  
        gfx.gradrect(0,0, obj.main_w, obj.main_h, 1,1,1,0.9, 0,0.001,0,0.0001, 0,0,0,-0.005)
      end 
         
    -- 2 wait screen
      if update_gfx then 
        --if trig_process ~= nil and trig_process == 1 then
          gfx.dest = 2
          gfx.setimgdim(2, -1, -1)  
          gfx.setimgdim(2, obj.main_w, obj.main_h) 
          gfx.a = 0.93
          f_Get_SSV(gui.color.back)
          gfx.rect(0,0, obj.main_w, obj.main_h,1)  
          f_Get_SSV(gui.color.white)    
          local str = 'Analyzing takes. Please wait...'
          gfx.setfont(1, gui.fontname, gui.fontsize_tab)
          gfx.x = (obj.main_w - gfx.measurestr(str))/2
          gfx.y = (obj.main_h-gfx.texth)/2
          gfx.drawstr(str)
        end
        
    --------------------------------------
    -- 3 main window
      if update_gfx then
        --msg('DEFINE_GUI_buffers_10-mainback')
        gfx.dest = 3
        gfx.a = 1
        gfx.setimgdim(3, -1, -1)  
        gfx.setimgdim(3, obj.main_w, obj.main_h)  
        
        -- back
          gfx.a = 0.9
          f_Get_SSV(gui.color.back)
          gfx.rect(0,0, obj.main_w, obj.main_h,1)
          
        -- tabs
          for id = 1, #obj.tab.names do GUI_tab(obj, gui, id) end
        
        -- knobs
          for id = 1, obj.knob.count do GUI_knob(obj, gui, knob, data['preset_-1'].active_tab, id) end
          
        -- button
          if data['preset_-1'].active_tab == 1 then 
            for id = 1, #button[1] do GUI_button(obj, gui, button, data['preset_-1'].active_tab, id) end
          end
          
        -- takes back
          if data['preset_-1'].active_tab == 1 then  
            -- frame
            gfx.a = 0.1
            f_Get_SSV(gui.color.white)
            local x,y,w,h = obj.takes_disp.xywh.x, obj.takes_disp.xywh.y,obj.takes_disp.xywh.w, obj.takes_disp.xywh.h
            gfx.x, gfx. y = x, y 
            gfx.line(x+1,y,x+w,y)
            gfx.line(x+w+1,y,x+w+1,y+h-1 )
            gfx.line(x+w+1,y+h, x, y+h )
            gfx.line(x, y+h-1, x, y )
            
            gfx.a = 0.06
            gfx.blit(1, 1, math.rad(180), 
              0,0,obj.main_w, obj.main_h/4,
              obj.takes_disp.xywh.x, 
              obj.takes_disp.xywh.y-1, 
              obj.takes_disp.xywh.w+1 ,
              obj.takes_disp.xywh.h+1, 0,0)
          end
      end    
    
    
    
    -- draw arrays
      if draw_blit_arrays and takes then 
        gfx.mode = 3
        -- draw
          --msg('store takes')
          for i = 1, #takes do
            if i == 1 then -- reference take
              gfx.a = 1
              f_Get_SSV(gui.color.white)
             else -- dub tales
              gfx.a = 0.9
              gfx.r = 0.3 + math.random()*0.7
              gfx.g = 0.3 + math.random()*0.7
              gfx.b = 0.3 + math.random()*0.7
            end
            gfx.dest = 10+i
            gfx.setimgdim(10+i, -1, -1)  
            gfx.setimgdim(10+i, obj.main_w, obj.main_h)
            GUI_array(obj, gui, i)
          end
          
        -- blit to com buffer
          gfx.dest = 5
          gfx.a =1
          gfx.setimgdim(5, -1, -1)  
          gfx.setimgdim(5, obj.main_w, obj.main_h)  
                  
      --gfx.muladdrect(x,y,w,h,mul_r,mul_g,mul_b[,mul_a,add_r,add_g,add_b,add_a] )
                   
        draw_blit_arrays = false
      end       
        
        
        
        
      
    --------------------------------------
    -- DRAW COMMON BUFFER
      gfx.dest = -1   
      --gfx.setimgdim(-1, -1, -1)  
      gfx.a = 1
      gfx.x,gfx.y = 0,0
      
      -- main
      gfx.blit(3, 1, 0, 
          0,0, obj.main_w, obj.main_h,
          0,0, obj.main_w, obj.main_h, 0,0)
      --[[gfx.blit(4, 1, 0, 
          0,0, obj.main_w, obj.main_h,
          0,0, obj.main_w, obj.main_h, 0,0) ]]
          
      if takes ~= nil and data['preset_-1'].active_tab == 1  then
        gfx.a = 1
        for i = 1, #takes do
          if i ==1 then gfx_offset = 0 else
            gfx_offset = 
              (obj.takes_disp.xywh.w / takes[1].sample_array_sz)  
               * takes[i].offset_smpls * data['preset_-1'].strength
          end
          gfx.blit(10+i, 1, 0, 
            0,0, obj.main_w, obj.main_h,
            obj.takes_disp.xywh.x + gfx_offset,
            obj.takes_disp.xywh.y, 
            obj.takes_disp.xywh.w, 
            obj.takes_disp.xywh.h,
            0,0)
        end
        
        --[[gfx.blit(5, 1, 0, 
            0,0, obj.main_w, obj.main_h,
            0,0, obj.main_w, obj.main_h, 0,0) ]]
      end    
         
      if trig_process ~= nil and trig_process == 0 then 
        gfx.blit(2, 1, 0, 
          0,0, obj.main_w, obj.main_h,
          0,0, obj.main_w, obj.main_h, 0,0)
        trig_process = 1
      end       
      
      
      
      
    gfx.update()
    update_gfx = false
  end      
  
  ------------------------------------------------------------------
  
  function Define_Defaults(apply_to_current)
    
    local default_data = { ['preset_0'] = 
                            { -- screen position --
                              ['main_x'] = 0,
                              ['main_y'] = 0,
                              
                              ['active_tab'] = 1,
                              
                              -- main --
                              ['search'] = 0.2,
                              ['strength'] = 0,
                              ['move_behavior'] = 0, -- 0 move position / 1 - move content
                              ['view_showall'] = 1
                            }
                          }
                          
    if apply_to_current then default_data['preset_-1'] =  default_data.preset_0 end
    return default_data
  end
  
  ------------------------------------------------------------------
  
  function GetData_LIP(fileName, preset)
  
    -- http://github.com/Dynodzzo/Lua_INI_Parser/blob/master/LIP.lua
    
    local file = io.open(fileName, 'r')
    local def_data = Define_Defaults(true)
    
    if file == nil then 
      data = def_data
      SetData(file_path, data)
      update_gfx = true
      return data
    
     else
      data = {}
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
    end
    
    if preset ~= nil then
      if data['preset_'..preset] ~= nil then
        data['preset_-1'] = data['preset_'..preset]
      end
    end
    
    -- check for nil defaults
      for i in pairs(def_data['preset_-1']) do
        if data['preset_-1'][i] == nil then data['preset_-1'][i] = def_data['preset_-1'][i] end
      end
      
    data['preset_-1'].active_tab =1
    
    return data;
  end  
  
  ------------------------------------------------------------------
      
  function SetData(fileName, data)    
    reaper.BR_Win32_WritePrivateProfileString('debug','LastSave',os.date(), file_path )
    for section in pairs(data) do
      for key in pairs(data[section]) do
        if key ~= 'strength' then
          reaper.BR_Win32_WritePrivateProfileString(section,key,data[section][key] , file_path )
        end
      end
    end    
    update_gfx = true
  end  

-----------------------------------------------------------------------     
 
  function MOUSE_match(b)
    if mouse.mx > b.x and mouse.mx < b.x+b.w
      and mouse.my > b.y and mouse.my < b.y+b.h then
     return true 
    end 
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
     
  function ENGINE_GetOffset(takes, i, ref_arr)
    local id_min_diff, diff_sum
     diff = {}
    
    search_sample_cnt = takes[i].sample_array.get_alloc()
    arr = reaper.new_array(takes[i].sample_array)
    t = arr.table()
    for ref_search_pos = 1, search_sample_cnt*2 do
      diff_sum = 0
      max_val = 0
      for smpl = 1, search_sample_cnt do
        max_val = math.max(arr[smpl],  ref_arr [smpl + ref_search_pos]  )
        diff_sum = 
          math.abs( arr     [smpl]   
                  - ref_arr [smpl + ref_search_pos]    ) 
          + diff_sum
          
      end
      diff [ #diff +1 ] = diff_sum * max_val
    end
    
    min_diff = math.huge
    for i = 2, #diff do
      if diff[i] < min_diff then 
       min_diff = diff[i]
       id_min_diff = i
      end
    end
    return id_min_diff / takes[i].SR, id_min_diff
  end
  
-----------------------------------------------------------------------     
      
  function ENGINE_GetTakes(trig_process)
    local c_sel_items,   item,   take, takes, SR, SR0
    
    local edit_cur  = reaper.GetCursorPositionEx( 0 )
    -- store guids
     local  takes = {}
      c_sel_items =  reaper.CountSelectedMediaItems( 0 )
      for i = 1, c_sel_items do 
        item =  reaper.GetSelectedMediaItem( 0, i-1 )
        if item then 
          take =  reaper.GetActiveTake( item )
          if not reaper.TakeIsMIDI( take )then 
            takes[#takes+1] = {['guid']  =reaper.BR_GetMediaItemTakeGUID( take ),
                            ['item_pos'] =  reaper.GetMediaItemInfo_Value( item, 'D_POSITION' ),
                            ['SR'] = reaper.GetMediaSourceSampleRate(reaper.GetMediaItemTake_Source(take))}
          end
        end
      end
    
    local err_msg_head = 'mpl Align takes phase: error'
    local err_msg = 
[[
So you get this error. Now check:
1. Selected AUDIO takes count is from 2 to 16.
2. Takerates of all selected takes are equal 1.0x.
3. Takes have same sample rate.
4. Takes are mono (otherwise first channel will be analyzed).
5. Edit cursor cross all selected takes.
6. Edit cursor is placed far from item edges (at least by "Search area" time)
7. Takes are non loopsourced.
]]

    -- check is more/equal than 2 takes
      if takes == nil or #takes < 2 or #takes > 16  then 
        reaper.MB(err_msg,err_msg_head, 0)
        return 
      end 
    
    -- check for params
      for i = 1, #takes do 
        take = reaper.GetMediaItemTakeByGUID( 0, takes[i].guid )
        local take_src = reaper.GetMediaItemTake_Source(take)
        if i == 1 then SR0 = reaper.GetMediaSourceSampleRate(take_src)
         else
          SR = reaper.GetMediaSourceSampleRate(take_src)
          if SR ~= SR0 then 
            reaper.MB(err_msg, err_msg_head, 0)
            return
          end
        end
        --[[ playrate
          if reaper.GetMediaItemTakeInfo_Value( take, 'D_PLAYRATE' ) ~= 1 
           then
            reaper.MB(err_msg, err_msg_head, 0)
            return trig_process , nil
          end]]
        
        
        
        -- is cursor out of take
          local tk_item =  reaper.GetMediaItemTake_Item( take )
          local item_pos =  reaper.GetMediaItemInfo_Value( tk_item, 'D_POSITION' )
          local item_len = reaper.GetMediaItemInfo_Value( tk_item, 'D_LENGTH' )        
          if (item_pos > edit_cur) 
            or item_pos + item_len < edit_cur 
            or item_pos + item_len - edit_cur < data['preset_-1'].search
            then
            reaper.MB(err_msg, err_msg_head, 0)
            return 
          end
          
      end 
    
    -- get sample arrays from takes
      for i = 1, #takes do 
        takes[i].sample_array,takes[i].sample_array_sz = ENGINE_GetSampleArray(takes, i, edit_cur - takes[i].item_pos )
      end
      
    -- calculate offset
      local ref_array = takes[1].sample_array
      takes[1].offset = 0
      for i = 2, #takes do 
        takes[i].offset, takes[i].offset_smpls = ENGINE_GetOffset(takes, i, ref_array)
      end
       
    -- return offsets for further knob control
      
    draw_blit_arrays = true
    return takes
  end

-----------------------------------------------------------------------     

  function ENGINE_GetSampleArray(takes, id, offs)
    local search_area = data['preset_-1'].search -- ms
    
    local take =  reaper.GetMediaItemTakeByGUID( 0, takes[id].guid )
      local tk = {}
      
      tk.src = reaper.GetMediaItemTake_Source(take)
      tk.numch = 2--reaper.GetMediaSourceNumChannels(tk.src)
      tk.SR = reaper.GetMediaSourceSampleRate(tk.src)
      
      
      local arr_size = math.floor(search_area * tk.SR)
      if id ~= 1 then arr_size = math.floor(arr_size /3 )end
      tk.buffer = reaper.new_array(arr_size*2)
      tk.buffer_com = reaper.new_array(arr_size)
      
      tk.aa = reaper.CreateTakeAudioAccessor(take)
        reaper.GetAudioAccessorSamples(
          tk.aa , --AudioAccessor
          tk.SR, -- samplerate
          2,--aa.numch, -- numchannels
          offs, -- starttime_sec
          arr_size, -- numsamplesperchannel
          tk.buffer) --samplebuffer
          
        -- merge buffers dy duplicating sum/2
          for i = 2, arr_size * 2, 2  do
            tk.buffer_com[i/2] = -(tk.buffer[i] + tk.buffer[i-1])/2
          end
          
        tk.buffer.clear()
      reaper.DestroyAudioAccessor(tk.aa)
      
    -- normalize
      local max = 0
      for i = 1, tk.buffer_com.get_alloc() do max = math.max(max, tk.buffer_com[i]) end
      for i = 1, tk.buffer_com.get_alloc() do tk.buffer_com[i] = tk.buffer_com[i] / max end
    return tk.buffer_com, arr_size
  end  
   
-----------------------------------------------------------------------     
      
function MOUSE_get(obj, knob, button)
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
    mouse.wheel_res = 19200
    mouse.d_res = 100
    
    if mouse.Ctrl_state then mouse.d_res = 1000 end
    
    if mouse.last_wheel and mouse.last_wheel ~= mouse.wheel then 
      mouse.wheel_diff = mouse.wheel - mouse.last_wheel
      update_gfx = true 
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
    
    if mouse.last_LMB_state and not mouse.LMB_state then 
      update_gfx = true 
      mouse.context  = nil 
    end
    
    mouse.last_mx = 0
    mouse.last_my = 0
    
    ---------------------
      -- tabs
        for i = 1, #obj.tab.names do
          if MOUSE_match(obj.tab.xywh[i]) 
            and mouse.LMB_state 
            and not mouse.last_LMB_state 
            then          
            update_gfx = true
            data['preset_-1'].active_tab = i
            SetData(file_path, data)
          end
        end
      
      local active_tab = data['preset_-1'].active_tab
      
      -- button
        for i = 1, #obj.buttons.xywh do
            if  MOUSE_match(obj.buttons.xywh[i]) 
              and mouse.LMB_state 
              and not mouse.last_LMB_state 
              then          
              mouse.context = 'button_'..i
              if i ~= 3 then 
                data['preset_-1'][ button[active_tab][i].value_raw ] = math.abs(data['preset_-1'][ button[active_tab][i].value_raw ]  -1 )
                SetData(file_path, data)
              end
            end
        end
        
        
      ---------------------          
      -- knob / mousewheel
        for i = 1, obj.knob.count do
          if i == 3 and not takes then break end
          if MOUSE_match(obj.knob.xywh[i]) and mouse.wheel_diff ~= 0 then
            
            if knob[active_tab] 
                and knob[active_tab][i] 
                and data['preset_-1'][ knob[active_tab][i].value_raw ]
             then
              if i == 1 then lim = 0.05 end -- search area
              if i == 3 then lim = 0 end -- search area
              data['preset_-1'][ knob[active_tab][i].value_raw ] = 
                  F_limit( data['preset_-1'][ knob[active_tab][i].value_raw ]  
                      + mouse.wheel_diff/mouse.wheel_res,
                      lim,1)
            end
            SetData(file_path, data)
            
            if i ==3 and data['preset_-1'].strength ~= 0 then
              ENGINE_AlignTakes(data['preset_-1'].strength)
            end
            
          end
        end
      
      -- get takes
        if MOUSE_match(obj.knob.xywh[2]) 
          and mouse.LMB_state 
          and not mouse.last_LMB_state 
         then
          trig_process = 0
          update_gfx = true 
        end
        
        if trig_process ~= nil and trig_process == 1 then
          takes = ENGINE_GetTakes()
          data['preset_-1'].strength = 0
          trig_process = nil
        end
      
      -- knob / lefthold        
        for i = 1, obj.knob.count do
          if i == 3 and not takes then break end
          if i ~= 2 -- for get takes button
            and obj.knob.xywh[i] ~= nil 
            and knob[active_tab] ~= nil 
            and knob[active_tab][i] ~= nil then 
          
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
              if i == 1 then lim = 0.05 end -- search area
              if i == 3 then lim = 0 end -- search area
                data['preset_-1'][ knob[active_tab][i].value_raw ] = 
                  F_limit( mouse.val_on_click- mouse.dy/mouse.d_res, lim,1)
              if mouse.Alt_state then -- set by defauilt on alt hold
                data['preset_-1'][ knob[active_tab][i].value_raw ] = 
                  data['preset_0'][ knob[active_tab][i].value_raw ]
              end
              SetData(file_path, data)
              
              if i ==3 and data['preset_-1'].strength ~= 0 then
                ENGINE_AlignTakes(data['preset_-1'].strength)
              end
              
            end
          end
        end
        
    mouse.last_LMB_state = mouse.LMB_state  
    mouse.last_RMB_state = mouse.RMB_state
    mouse.last_MMB_state = mouse.MMB_state 
    mouse.last_Ctrl_LMB_state = mouse.Ctrl_LMB_state
    mouse.last_Ctrl_state = mouse.Ctrl_state
    mouse.last_wheel = mouse.wheel 
    
    knob = Define_knobs()
    return knob, button
  end
  
  ------------------------------------------------------------------
  
  function Define_buttons(obj, takes)
      local button = {}
      button[1] = {} -- main tab
        button[1][1] = 
         {['name']= 'Move contents',
          ['value'] = data['preset_-1'].move_behavior,
          ['color'] = 'white',
          ['value_raw'] = 'move_behavior'}
          
        button[1][2] = 
         {['name']= 'Show all takes',
          ['value'] = data['preset_-1'].view_showall,
          ['color'] = 'white',
          ['value_raw'] = 'view_showall'}
        
        --[[button[1][3] = 
           {['name']= 'Get takes',
            ['value'] = 1,
            ['color'] = 'green'}]]
                    
    return button
  end
  
  
  ------------------------------------------------------------------
    
  function Define_knobs()
    local knob = {}
    
    knob[1] = {} -- main tab    
    knob[1][1] = {['name'] = 'Search area',
                  ['is_active'] = true,                  
                  ['color'] = 'green',
                  ['type'] = 1,
                  ['value'] = data['preset_-1'].search,
                  ['value_txt'] = math.floor(data['preset_-1'].search*100)..' ms' ,
                  ['value_raw'] = "search"
                  }
                  
    knob[1][2] = {['name'] = '',
                  ['is_active'] = true,                  
                  ['color'] = 'green',
                  ['type'] = 0,
                  ['value_txt'] = 'Get takes' 
                  }
                                 
    knob[1][3] = {['name'] = 'Align',
                  ['is_active'] = takes~=nil,                  
                  ['color'] = 'red',
                  ['type'] = 1,
                  ['value'] = data['preset_-1'].strength,
                  ['value_txt'] = math.floor(data['preset_-1'].strength*100)..' %' ,
                  ['value_raw'] = "strength"
                  }
                  
                  
    return knob
  end
  
  ------------------------------------------------------------------
    
  function ENGINE_AlignTakes(val)
    for i = 2, #takes do
      local take = reaper.GetMediaItemTakeByGUID( 0, takes[i].guid )
      if take ~= nil then
        local tk_item =  reaper.GetMediaItemTake_Item( take )
        pos = takes[i].item_pos + (takes[i].offset * val)
        reaper.SetMediaItemInfo_Value( tk_item, 'D_POSITION',pos )
        reaper.UpdateItemInProject( tk_item )
      end
    end
  end
  
  ------------------------------------------------------------------
    
  function Run()
    -- store position on screen
        _, data['preset_-1'].main_x, data['preset_-1'].main_y = gfx.dock(-1, data['preset_-1'].main_x, data['preset_-1'].main_y)
        if gfx_main_x == nil or gfx_main_x ~= data['preset_-1'].main_x or gfx_main_y ~= data['preset_-1'].main_y then SetData(file_path, data) end
        gfx_main_x,gfx_main_y = data['preset_-1'].main_x,data['preset_-1'].main_y
     
        
    local obj = GetObjects()
    local knob = Define_knobs()
    local gui = GetGUI_vars()
    local but = Define_buttons(obj)
    local knob, but = MOUSE_get(obj, knob, but)
    GUI_draw(gui, obj, data, knob, but)
    
    
    local char = gfx.getchar() 
    if char == 32 then reaper.Main_OnCommandEx(40044, 0,0) end
    if char == 27 then gfx.quit() end     
    if char ~= -1 then reaper.defer(Run) else gfx.quit() end
    
  end
  
  ------------------------------------------------------------------
  
  local preset = -1 -- last config
  OS = reaper.GetOS()
  mouse = {}
  update_gfx = true
  local t = debug.getinfo(1)
  file_path = t.source:sub(2,-t.source:reverse():find('%.')-1)..'_config.ini'
  data = GetData_LIP(file_path, preset)
  local obj = GetObjects(data)
  gfx.init("mpl Align takes phase "..vrs, obj.main_w, obj.main_h, 0, 
    data['preset_-1'].main_x, 
    data['preset_-1'].main_y)
    
  Run()
