

-- changelog
--  	* v0.02 (2016-05-07)
--  	* v0.01 (2016-04-02)  
-- 	 + Tag input box

  ---------------------------------------------------------------------------------------
  
  function msg(s) reaper.ShowConsoleMsg(s..'\n') end
   
  ---------------------------------------------------------------------------------------
  
  function MOUSE_trig(mouse, t)
    if MOUSE_match(mouse, t) 
      and mouse.trigger
      then  
      return true else return false  end
  end    
  
  ---------------------------------------------------------------------------------------
  
  function MOUSE_match(mouse, b)
    if b ~= nil then
      if mouse.mx > b[1] and mouse.mx < b[1]+b[3]
        and mouse.my > b[2] and mouse.my < b[2]+b[4] then
       return true 
      end 
    end
  end 
  
  ---------------------------------------------------------------------------------------
  
  function MOUSE_get(objects)
    mouse.mx = gfx.mouse_x
    mouse.my = gfx.mouse_y
    mouse.LMB_state = gfx.mouse_cap&1 == 1
    mouse.char = gfx.getchar() 
    
    if mouse.last_mx == nil or mouse.last_my == nil or
      mouse.last_mx ~= mouse.mx or mouse.last_my ~= mouse.my then
      mouse.move = true else mouse.move = false 
    end
    
    if mouse.LMB_state and not mouse.last_LMB_state then    
      mouse.last_mx_onclick = mouse.mx
      mouse.last_my_onclick = mouse.my
      mouse.trigger = true 
     else 
      mouse.trigger = false
    end    
    
    -- exit mouse states
      mouse.last_mx = mouse.mx
      mouse.last_my = mouse.my   
      mouse.last_LMB_state = mouse.LMB_state
      mouse.last_RMB_state = mouse.RMB_state
      mouse.last_MMB_state = mouse.MMB_state
      mouse.last_Ctrl_LMB_state = mouse.Ctrl_LMB_state
      mouse.last_Ctrl_state = mouse.Ctrl_state
      mouse.last_wheel = mouse.wheel    
    
    return mouse
  end

  ---------------------------------------------------------------------------------------
    
  function MOUSE_TextBox(textbox_t, mouse, text_field, app_field)
    if textbox_t == nil then textbox_t = {} end
    if textbox_t.active_char == nil then textbox_t.active_char = 0 end
    if textbox_t.text == nil then textbox_t.text = '' end
    if MOUSE_trig(mouse,text_field ) then textbox_t.active = true  end
    if mouse.char == 13  then   -- enter for apply
      textbox_t.active = false 
      if textbox_t.current_tags == nil then 
        textbox_t.current_tags = textbox_t.text
       else
        textbox_t.current_tags = textbox_t.current_tags..', '..textbox_t.text 
      end
      textbox_t.text = ''
      update_gfx = true
    end
     
    
    if textbox_t.active then
      if  -- regular input
        (
            (mouse.char >= 65 -- a
            and mouse.char <= 90) --z
            or (mouse.char >= 97 -- a
            and mouse.char <= 122) --z
            or ( mouse.char >= 212 -- A
            and mouse.char <= 223) --Z
            or ( mouse.char >= 48 -- 0
            and mouse.char <= 57) --Z
            or mouse.char == 95 -- _
            or mouse.char == 44 -- ,
            or mouse.char == 32 -- (space)
            or mouse.char == 45 -- (-)
        )
        then        
          textbox_t.text = textbox_t.text..string.char(mouse.char)
          textbox_t.active_char = textbox_t.active_char + 1
      end
      
      if mouse.char == 8 then -- backspace
        textbox_t.text = textbox_t.text:sub(0,textbox_t.active_char-1)..textbox_t.text:sub(textbox_t.active_char+1)
        textbox_t.active_char = textbox_t.active_char - 1
      end
      
      if mouse.char == 1818584692 then -- left arrow
        textbox_t.active_char = textbox_t.active_char - 1
      end
      
      if mouse.char == 1919379572 then -- right arrow
        textbox_t.active_char = textbox_t.active_char + 1
      end
      
    end
    
    if textbox_t.active_char < 0 then textbox_t.active_char = 0 end
    if textbox_t.active_char > textbox_t.text:len()  then textbox_t.active_char = textbox_t.text:len() end
    
    return textbox_t
  end
  
  ---------------------------------------------------------------------------------------
    
    function DEFINE_Objects()
      local x_offset = 10
      local y_offset = 10
      local iBox_h = 22
      
      local mouse_x, mouse_y = reaper.GetMousePosition()
      local objects = {}
      
      objects.main_w = 400
      objects.main_h = 300
      objects.x_pos = mouse_x-objects.main_w/2     
      if objects.x_pos < 0 then objects.x_pos = 10 end
      objects.y_pos =  mouse_y-objects.main_h/2
      if objects.y_pos < 0 then objects.y_pos = 10 end
      
      
      -- tags
      objects.tag = {x_offset, y_offset, objects.main_w - x_offset*2, 60} -- frame
      objects.x_offset_text = 10
      objects.iBox = {x_offset*2, y_offset*1.5 ,objects.main_w - x_offset*4, iBox_h}
      objects.current_tags = {x_offset*2, y_offset*2 + iBox_h}
      
      -- selector
      objects.selector = {x_offset, y_offset + objects.tag[2]+objects.tag[4],objects.main_w - x_offset*2, 30 }
      
      return objects
    end
    
  ---------------------------------------------------------------------------------------      
  
  function F_split_SST(str, is_col)
    if str ~= nil then
      local str_t = {}
      for word in str:gmatch('[^%s]+') do 
        if tonumber(word) ~= nil then word = tonumber(word) end
        str_t[#str_t+1] = word 
      end
      
      function unpack (t, i)
        i = i or 1
        if t[i] ~= nil then
          if is_col then
            return t[i]/255, unpack(t, i + 1)
           else
            return t[i], unpack(t, i + 1)
          end
        end
      end
      
      return unpack (str_t, 1)
    end      
  end
  
  ---------------------------------------------------------------------------------------  
  
    function GUI_textbox(gui, objects, textbox_t, xywh_t, xywh_t_app)
      if textbox_t == nil then return end
      -- back
        gfx.r, gfx.g, gfx.b = F_split_SST(gui.color['white'], true)
        gfx.a = 0.2
        gfx.rect(xywh_t[1],xywh_t[2],xywh_t[3],xywh_t[4]) -- back main
        
      -- active frame
        if textbox_t.active then
          gfx.r, gfx.r, gfx.b = F_split_SST(gui.color['white'], true)
          gfx.a = 0.3          
          gfx.rect(xywh_t[1],xywh_t[2],xywh_t[3],xywh_t[4], 0) -- back main
        end    
      
      -- draw text
        gfx.r, gfx.r, gfx.b = F_split_SST(gui.color['green'], true)
        gfx.a = 0.9       
        gfx.setfont(1, gui.fontname, gui.fontsize)
        gfx.x = xywh_t[1] + objects.x_offset_text
        gfx.y = xywh_t[2] + xywh_t[4]/2 - gfx.texth/2
        gfx.drawstr(textbox_t.text)
        
      -- active_char line
        if textbox_t.active_char ~= nil and textbox_t.active then
          gfx.r, gfx.r, gfx.b = F_split_SST(gui.color['white'], true)
          gfx.a = 0.4
          gfx.x = xywh_t[1]+gfx.measurestr(textbox_t.text:sub(0,textbox_t.active_char)) + objects.x_offset_text - 
            gfx.measurestr('|')/2
          gfx.y = xywh_t[2] + xywh_t[4]/2 - gfx.texth/2
          gfx.drawstr('|')
        end
    end
    
  ---------------------------------------------------------------------------------------  
    
    function DEFINE_GUI_vars()
      local gui = {}
      gui.OS = reaper.GetOS()
      gui.aa = 1
      gfx.mode = 0
      gui.fontname = 'Calibri'
      gui.fontsize = 23      
      if gui.OS == "OSX32" or gui.OS == "OSX64" then gui.fontsize = gui.fontsize - 7 end
      gui.fontsize_b = gui.fontsize - 5
      gui.fontsize_selector = gui.fontsize - 5
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
                    ['grey'] = '120 120 120',
                  }  
      
      return gui
  end   

  ---------------------------------------------------------------------------------------  
  
  function GUI_selector(gui,xywh, t, t_id)
    if t == nil or t_id == nil then return end
    
    -- frame
      gfx.r, gfx.g, gfx.b = F_split_SST(gui.color['white'], true)
      gfx.a = 0.4
      gfx.rect(xywh[1],xywh[2],xywh[3],xywh[4],0)

    -- buttons    
    gfx.setfont(1, gui.fontname, gui.fontsize_selector)
    local com_l = 0
    for i = 1, #t do com_l = com_l + gfx.measurestr(t[i]) end
    local com_l_for_offsets = xywh[3] - com_l
    local offset = com_l_for_offsets/8
    local com_offset = 0
    
      for i = 1, #t do
        gfx.r, gfx.g, gfx.b = F_split_SST(gui.color['white'], true)
        if i == t_id then gfx.a = 0.4 else gfx.a = 0.2 end
        gfx.rect( xywh[1] + com_offset,
                  xywh[2],
                  gfx.measurestr(t[i])+offset*2,
                  xywh[4],1)
        gfx.x = xywh[1] + com_offset + offset
        gfx.y = xywh[2] + (xywh[4] - gfx.texth)/2
        gfx.drawstr(t[i])
        com_offset = com_offset + gfx.measurestr(t[i]) + offset*2
      end
    --
    
    
--[[               F_Get_SSV(col, true)
               gfx.a = 0.3
               gfx.rect(xywh[1],
                         xywh[2],
                         xywh[3],
                         xywh[4],0,1)
               
               gfx.a = 0.4
               gfx.rect(xywh[1] + 2,
                        xywh[2]+2+
                        (xywh[4]/2-2)*val,
                        xywh[3]-4,
                        (xywh[4]-4)/2,1,1)
               
               gfx.a = 1
               gfx.x = xywh[1] + (xywh[3]- gfx.measurestr(b1)) /2
               gfx.y = xywh[2]   +2 
               gfx.drawstr(b1)
               
               gfx.a = 1
               gfx.x = xywh[1] + (xywh[3]- gfx.measurestr(b2)) /2
               gfx.y = xywh[2] + 1+ xywh[4] /2
               gfx.drawstr(b2)]]              
  end
                          
  ---------------------------------------------------------------------------------------  
      
    function GUI_draw(gui, objects, int_data)
      -- 1 static
      -- 2 dyn1 - tags, selector
      if update_gfx then      
      -- static -------------------
        gfx.dest = 1
        gfx.setimgdim(1, -1, -1)  
        gfx.setimgdim(1, objects.main_w, objects.main_h)
                
        -- back
          gfx.r, gfx.g, gfx.b = F_split_SST(gui.color['back'], true)
          gfx.a = 1
          gfx.rect(0,0,objects.main_w, objects.main_w,1) -- back main
  
        -- tags frame
          gfx.r, gfx.g, gfx.b = F_split_SST(gui.color['white'], true)
          gfx.a = 0.15
          gfx.rect(objects.tag[1],objects.tag[2],objects.tag[3],objects.tag[4],0) -- tags frame   
      end
           
        -- dyn ----------------------
        
        gfx.dest = 2
        gfx.setimgdim(2, -1, -1)  
        gfx.setimgdim(2, objects.main_w, objects.main_h)
        -- draw selector
          GUI_selector(gui,objects.selector, int_data.selector,int_data.selector_act)
        
        -- draw current active tags
          if textbox1 ~= nil and textbox1.current_tags ~= nil then
            gfx.x, gfx.y =objects.current_tags[1],objects.current_tags[2]
            gfx.r, gfx.g, gfx.b = F_split_SST(gui.color['green'], true)
            gfx.a = 1
            gfx.setfont(1, gui.fontname, gui.fontsize)
            gfx.drawstr(textbox1.current_tags)
          end
          
              
                
      
      
      -- common buffer
        gfx.dest = -1   
        gfx.a = 1
        gfx.x,gfx.y = 0,0
        gfx.blit(1, 1, 0, 
          0,0, objects.main_w, objects.main_h,
          0,0, objects.main_w, objects.main_h, 0,0)
        gfx.blit(2, 1, 0, 
          0,0, objects.main_w, objects.main_h,
          0,0, objects.main_w, objects.main_h, 0,0)
            
      GUI_textbox(gui,  objects, textbox1, objects.iBox, objects.iBox_app)
      
      update_gfx = false
    end

  ---------------------------------------------------------------------------------------
    
  function ENGINE_Form_data_table(res_path)
    local data = {}
    
    local paths = {'TrackTemplates',
                   'FXChains',
                   --'presets',
                   'ProjectTemplates'}
    for k = 1, #paths do
      local path = paths[k]
      data[path] = {}
      local i = 0
      repeat
        ret_file = reaper.EnumerateFiles(res_path..'/'..path, i)
        i = i + 1
        if ret_file ~= nil then 
          ret_file = ret_file:sub(0,-1-ret_file:reverse():find('[%.]'))
          data[path][#data[path]+1] = {['name'] = ret_file}
        end
      until ret_file == nil
    end
    
    return data
  end

  ---------------------------------------------------------------------------------------
    
  function ENGINE_Check_data_table(data) 
    local temp_t
    if data == nil then data = {} end
    local str = 'data={}'
    for i in pairs(data) do
      temp_t = data[i]
      str = str..'\n'..'data.'..i..'={}'
      for k in pairs(temp_t) do
        temp_t2 = data[i][k]
        for m in pairs(temp_t2) do
          str = str..'\n'..'data.'..i..'['..k..']'..'={}'
          str = str..'\n'..'data.'..i..'['..k..'].'..m..'="'..data[i][k][m]..'"'
        end
      end
    end
    str = str..'\n'..'return data'
    return data, str
  end
  
  ---------------------------------------------------------------------------------------
  function DEFINE_Vars()
    local int_data = {}
    int_data.selector = {
                        'All',
                        'FX Chains',
                        'TrackTemplates',
                        'ProjectTemplates'}
    int_data.selector_act = 1                    
    
    
    return int_data
  end
  
  ---------------------------------------------------------------------------------------
  
  function DEFINE_Database() local data
    local res_path = reaper.GetResourcePath()
    local database_file = res_path..'/mpl_ResourceManager.ini'    
    
    local str = 
[[
-- Configuration for mpl_Resource Manager.lua
-- It contains some script variables and database.
-- If you wanna share your database with others, you need to copy this file and all relative paths (chains, templates and presets))
-- Please do not modify this file if you don`t understand completely what is going on here

]]
    
    
    local file = io.open(database_file,"r")
    if file == nil then 
      data = ENGINE_Form_data_table(res_path)
      file = io.open(database_file,"w")
      if outstr == nil then outstr = '' end
      msg(str..outstr)
      file:write(str..outstr)
     else      
      local content = file:read("*all")
      data = ENGINE_Form_data_table(res_path) 
      data, outstr = ENGINE_Check_data_table(data)
      --[[local f = assert(load(content))
      data = f()      
      data, outstr = ENGINE_Check_data_table(data)]]
      msg(str..outstr)
      file:write(str..outstr)
    end
    file:close() 
    return database_file, data
    
  end    
  
  ---------------------------------------------------------------------------------------    
  
    function MAIN_defer()
      local objects = DEFINE_Objects()
      local gui = DEFINE_GUI_vars()
      local int_data = DEFINE_Vars()
      GUI_draw(gui, objects, int_data)      
      
      local mouse = MOUSE_get(objects)
      textbox1 = MOUSE_TextBox(textbox1, mouse, objects.iBox, objects.iBox_app)
      
      gfx.update()
      if mouse.char ~= 27 then  reaper.defer(MAIN_defer) end -- escape to close
    end 
    
  ---------------------------------------------------------------------------------------
  
  -- init file
    local config_file, data = DEFINE_Database()
    
  -- init gfx vars
    mouse = {}
    textbox1 = {}
    local objects = DEFINE_Objects()
    
  -- init gfx
    gfx.init('mpl Resource Manager',objects.main_w,objects.main_h, 0)--, mouse_x, mouse_y)
    reaper.atexit(gfx.quit)
    update_gfx = true
    MAIN_defer()
    
  
  
  
  
  --[[
  function GetTrackTemplate(track)
    local _, chunk = reaper.GetTrackStateChunk(track, '')
    local chunk_t = {}
    for line in chunk:gmatch('[^\n]+') do chunk_t[#chunk_t+1] = line end
    local count = 0
    for i = 1, #chunk_t do
      if chunk_t[i]:find('<ITEM') ~= nil then count = 1 end
      if count > 0 and chunk_t[i]:find('<') ~= nil then count = count+1 end
      if chunk_t[i]:find('>') ~= nil then count = count-1 end      
      if count > 0 then chunk_t[i] = '' end
    end    
    local chunk_out = ''
    for i = 1, #chunk_t do
      if chunk_t[i] ~= '' then chunk_out = chunk_out..'\n'..chunk_t[i] end
    end
    return chunk_out
  end
  track = reaper.GetSelectedTrack(0, 0)
  if track ~= nil then 
    _, track_name = reaper.GetSetMediaTrackInfo_String(track, 'P_NAME', '', false)
    chunk_out = GetTrackTemplate(track)
    ret = reaper.MB('Do you want to save selected track as template', 'mpl ResourceManager', 4)
    if ret == 6 then
      _, file_name = reaper.GetUserInputs('Save track template', 1, 'FileName', track_name)
      if file_name ~= nil and file_name ~= '' then
      
        -- write file
          file = io.open(res_path..'/TrackTemplates/'..file_name..'.RTrackTemplate',"w")
          file:write(chunk_out)
          file:close()
          
        -- write database
          reaper.BR_Win32_WritePrivateProfileString('TrackTemplates', file_name, 'tags', database_file)
          reaper.BR_Win32_WritePrivateProfileString('Tags', 'TrackTemplates', 'Bass, Lead', database_file)
        
      end
    end
  end
         
                     
                     key = ''
    ----
    ---------------------------------------------------------------------------------------
     
    function GetTagsFromIni(database_file)
      local key_t = {}
      local tags = ''
      for word in key:gmatch('[^%,]+') do key_t[#key_t+1] = word end
      for i = 1, #key_t do
        local _, tags_k = reaper.BR_Win32_GetPrivateProfileString('Tags', key_t[i], '', database_file)
        tags = tags..tags_k..','
      end
      local out_tags_t = {}
      for word in tags:gmatch('[^%,]+') do out_tags_t [#out_tags_t+1] = word end
      return out_tags_t
    end
    
    file = Check_Database()
    tags = GetTagsFromIni(file)
  
  
    
    ]]      
