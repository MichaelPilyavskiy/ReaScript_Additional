
--[[ changelog 
	  * v0.18 (2016-03-28)  
	    # Don`t show silent wires
	  * v0.17 (2016-03-26)
	    # Manual routing wires testing
	  * v0.16 (2016-03-19)
	    # DEFINE_signal_flow() hardly optimized
	  * v0.15 (2016-03-14)
	    # Improved auto-generated gfx positions    
	    # GUI: Signal flow fixes
	    + Define IO order when new routing
	    + Route closer FX
	  * v0.11 (2016-03-13)
	    + Master track support + by default if no last touched track
	    + GUI: Signal flow colour curves
	    + GUI: Channel colors
	    # GUI: blit/performance improvements
	    # Structure improvements/clean
	  * v0.06 (2016-03-01)
	    + GUI: Pins
	    + GUI: Trackname
	    + GUI: Bypass button
	    + ExtState store/parsing 
	  * v0.01 (2015-11-04)
	    + Early alpha
]]  

  --[[
  
  todo:
  
  track controls
    solo
    mute
    save/load chain
    chain name
    chain list
    
  fx object
    bypass
    offline
    preset name/search
    
  gui
    add/search/replace/delete/dragndrop fx
    io meters per chain
    io meters per fx 
    
  need to fix from cockos team:
    GetProjectStateChangeCount react to get/set pins
  
  ]]
  
  local vrs = '0.18'


----------------------------------------------------------------------- 
  function msg(str)
    if type(str) == 'boolean' then if str then str = 'true' else str = 'false' end end
    if type(str) == 'userdata' then str = str.get_alloc() end
    if str ~= nil then 
      reaper.ShowConsoleMsg(tostring(str)..'\n') 
      if str ==  "" then reaper.ShowConsoleMsg("") end
     else
      reaper.ShowConsoleMsg('nil')
    end    
  end
  
----------------------------------------------------------------------- 
  function fdebug(str) if debug_mode == 1 then msg(os.date()..' '..str) end end  
  
----------------------------------------------------------------------- 
  function MAIN_exit()
    reaper.atexit()
    gfx.quit()
  end  

-----------------------------------------------------------------------     
  function F_split_SST(str)
    if str ~= nil then
      local str_t = {}
      for word in str:gmatch('[^%s]+') do 
        if tonumber(word) ~= nil then word = tonumber(word) end
        str_t[#str_t+1] = word 
      end
      
      function unpack (t, i)
        i = i or 1
        if t[i] ~= nil then
          return t[i], unpack(t, i + 1)
        end
      end
      
      return unpack (str_t, 1)
    end      
  end    

-----------------------------------------------------------------------   
  function DEFINE_track_data()
    local int_compare
    --local
     track = {}
    track.name = nil 
    track.pointer = reaper.GetLastTouchedTrack()    
    if track.pointer == nil then track.pointer = reaper.GetMasterTrack(0) end
      track.num_ch = reaper.GetMediaTrackInfo_Value(track.pointer, 'I_NCHAN')
      track.guid = reaper.GetTrackGUID(track.pointer)
      track.id = reaper.CSurf_TrackToID(track.pointer, false)
      if track.id == 0 then track.name = 'Master' else
        _, track.name = reaper.GetSetMediaTrackInfo_String(track.pointer, 'P_NAME', '', false) 
        if track.name == '' then track.name = '(untitled track)' end
        track.name = 'Track #'..track.id..': '..track.name 
      end
      track.FX_bypass = reaper.GetToggleCommandStateEx(0,8)
      
    if track.name == nil then track.name = 'No track selected' end
    if track.num_ch == nil then track.num_ch = 2 end
    
    track.fx_count = reaper.TrackFX_GetCount(track.pointer)
    track.fx = {}
    
    track.fx[0] = {}
    track.fx[track.fx_count+1] = {}
    track.fx[0].outputs = {}
    track.fx[track.fx_count+1].inputs = {}
    for k =0, track.num_ch-1 do      
      track.fx[0].outputs[#track.fx[0].outputs+1] = math.floor(2^k)
      track.fx[track.fx_count+1].inputs[#track.fx[track.fx_count+1].inputs+1] = math.floor(2^k)
    end
    
    for i = 1, track.fx_count do
      local plugin_type, inputPins, outputPins = reaper.TrackFX_GetIOSize(track.pointer, i-1)
      track.fx[i] = {}
      track.fx[i].guid = reaper.TrackFX_GetFXGUID(track.pointer, i-1)
      track.fx[i].plugin_type = plugin_type
      track.fx[i].inputs = {}
      track.fx[i].outputs = {}
      
      if plugin_type == 2 then
        track.fx[i].inputs_ch = {}
        track.fx[i].outputs_ch = {}
        for k =1, track.num_ch do
          track.fx[i].inputs[k] = reaper.TrackFX_GetPinMappings(track.pointer, i-1, 0, k-1)
          
          track.fx[i].inputs_ch[k] = ''
          for m =1, track.num_ch do 
            int_compare = 2^(m-1)
            if track.fx[i].inputs[k]&int_compare==int_compare then
              track.fx[i].inputs_ch[k] = track.fx[i].inputs_ch[k]..m..' '
            end
          end
          
          track.fx[i].outputs[k] = reaper.TrackFX_GetPinMappings(track.pointer, i-1, 1, k-1)
          
          track.fx[i].outputs_ch[k] = ''
          for m =1, track.num_ch do 
            int_compare = 2^(m-1)
            if track.fx[i].outputs[k]&int_compare==int_compare then
              track.fx[i].outputs_ch[k] = track.fx[i].outputs_ch[k]..m..' '
            end
          end
          
        end
       else
       track.fx[i].inputs_ch = {}
       track.fx[i].outputs_ch = {}
        for k =1, inputPins do
          track.fx[i].inputs[k] = reaper.TrackFX_GetPinMappings(track.pointer, i-1, 0, k-1)
          
          track.fx[i].inputs_ch[k] = ''
          for m =1, track.num_ch do 
            int_compare = 2^(m-1)
            if track.fx[i].inputs[k]&int_compare==int_compare then
              track.fx[i].inputs_ch[k] = track.fx[i].inputs_ch[k]..m..' '
            end
          end
          
        end
        
        for k =1, outputPins  do
          track.fx[i].outputs[k] = reaper.TrackFX_GetPinMappings(track.pointer, i-1, 1, k-1)
          
          track.fx[i].outputs_ch[k] = ''
          for m =1, track.num_ch do 
            int_compare = 2^(m-1)
            if track.fx[i].outputs[k]&int_compare==int_compare then
              track.fx[i].outputs_ch[k] = track.fx[i].outputs_ch[k]..m..' '
            end
          end
          
        end        
      end        
    end
    
    return track
  end  
  
-----------------------------------------------------------------------   
  function DEFINE_update_triggers()
    pcc = reaper.GetProjectStateChangeCount(0)
    if pcc_last == nil or pcc_last ~= pcc then
      pcc_last = pcc
      return true,pcc_last
     else 
      return false,pcc_last
    end    
    pcc_last = pcc
  end

-----------------------------------------------------------------------   
  function ENGINE_build_gfx_data(objects,gfx_data)
    local track
    local gfx_data = EXT_Get()
    
    local fx_track, fx_id,offs, offs_x
    local x_offs_fx,dx_offs_fx,y_offs_fx,dy_offs_fx
    fdebug('BUILD')
      -- check for new
        local c_tracks = reaper.CountTracks(0)
        --if c_tracks == nil or c_tracks == 0 then return end
        for i = 0, c_tracks do
          if i == 0 then 
            track = reaper.GetMasterTrack(0)
           else
            track = reaper.GetTrack(0,i-1)
          end
          if track ~= nil then
            local track_guid = reaper.GetTrackGUID(track)
            local track_num_ch = reaper.GetMediaTrackInfo_Value(track, 'I_NCHAN')
            local fx_count = reaper.TrackFX_GetCount(track)
            if fx_count > 0 then 
              for k = 1, fx_count do
                local  fx_guid = reaper.TrackFX_GetFXGUID(track, k-1)                
                if gfx_data[track_guid] == nil then gfx_data[track_guid] = {} end   
                if gfx_data[track_guid][fx_guid] == nil then 
                  if objects.y_offs_fx+objects.dy_offs_fx*k > gfx.h - objects.FX_h then 
                    offs = objects.dy_offs_fx2
                    offs_x = objects.dx_offs_fx2
                   else
                    offs = 0
                    offs_x = 0
                  end
                    gfx_data[track_guid][fx_guid] = math.floor(offs_x+objects.x_offs_fx+objects.dx_offs_fx*k)..' '..
                                        math.floor(offs+objects.y_offs_fx+objects.dy_offs_fx*k)..' '..
                                        objects.FX_w..' '..
                                        objects.FX_h
                end
              end
            end
          end
        end
        
      -- check for existing
        for track_guid in pairs(gfx_data) do
          if gfx_data[track_guid] ~= nil then
            for guid, xywh in pairs(gfx_data[track_guid]) do
              fx_track, fx_id = Get_FX_ByGUID(guid)              
              if fx_track == nil or fx_id == nil then 
                gfx_data[track_guid][guid] = nil 
              end
            end
          end
        end
        
    return gfx_data
  end  
    
-----------------------------------------------------------------------    
  function F_Get_SSV(s)
    local t = {}
    for i in s:gmatch("[%d%.]+") do 
      t[#t+1] = tonumber(i) / 255
    end
    gfx.r, gfx.g, gfx.b = t[1], t[2], t[3]
  end

-----------------------------------------------------------------------
  function Get_FX_ByGUID(guid)
    local fx_track, fx_id
    local c_tracks = reaper.CountTracks(0)
    if c_tracks == nil or c_tracks == 0 then return end
    for i = 1, c_tracks do
      local track = reaper.GetTrack(0, i-1)
      if track ~= nil then
        local fx_count = reaper.TrackFX_GetCount(track)
        if fx_count > 0 then 
          for k = 1, fx_count do
            local fx_guid = reaper.TrackFX_GetFXGUID(track, k-1)
            if guid == fx_guid then
              fx_track = track
              fx_id = k-1
              break
            end
          end
        end
      end
    end
    return fx_track, fx_id
  end
    
-----------------------------------------------------------------------  
  function ENGINE_Get_FX_name(guid)
    local fx_track, fx_id,fx_name,inputPins_t,outputPins_t,fx_type
    fx_track, fx_id = Get_FX_ByGUID(guid)
    if fx_track ~= nil and fx_id ~= nil then
      _, fx_name = reaper.TrackFX_GetFXName(fx_track, fx_id, '')
      fx_name = fx_name:sub(fx_name:find(':')+1)
      fx_name = (fx_id+1)..': '..fx_name:gsub('[%(].*[%)]','')
      local len = 20
      if fx_name:len() > len then
        fx_name = fx_name:sub(0,len)..'...'
      end
      return fx_name
    end
  end
  
-----------------------------------------------------------------------         
  function GUI_FX_obj(track, objects, gui, xywh, name, issel, fontsz, text_alpha, color_str) 
          
          local w1_sl_a
          gfx.y,gfx.x = 0,0                
          gfx.a = 0.6          
       
          
          -- frame
            if issel == nil or not issel then gfx.a = 0.4 else gfx.a = 0.6 end
            F_Get_SSV(gui.color.white, true)
            gfx.rect(xywh[1],xywh[2], xywh[3], xywh[4], 1 , gui.aa)
            gfx.a = 0.3
            gfx.rect(xywh[1],xywh[2]-objects.pin_h,xywh[3], 
              xywh[4]+objects.pin_h*2, 1 , gui.aa)
            
          -- txt           
            gfx.setfont(1, gui.fontname, fontsz)
            gfx.a = text_alpha
            F_Get_SSV(gui.color[color_str], true)
            local measurestrname = gfx.measurestr(name)
            local x0 = xywh[1] + (xywh[3] - measurestrname)/2
            local y0 = xywh[2] + (xywh[4] - fontsz)/2
            gfx.x, gfx.y = x0,y0 
            gfx.drawstr(name)                          
            
        end  
            
-----------------------------------------------------------------------         
        function GUI_button2(objects, gui, xywh, name, issel, fontsz, text_alpha, color_str) local w1_sl_a
          gfx.y,gfx.x = 0,0         
          -- frame
            gfx.a = 0.1
            F_Get_SSV(gui.color.white, true)
            gfx.rect(xywh[1],xywh[2],xywh[3], xywh[4], 0 , gui.aa)
            
          -- back
            if issel then gfx.a = 0.7 else gfx.a = 0.3 end
            gfx.blit(2, 1, 0, --backgr
              0,0,objects.main_w, objects.main_h,
              xywh[1],xywh[2],xywh[3],xywh[4], 0,0) 
            
          -- txt           
            gfx.setfont(1, gui.fontname, fontsz)
            gfx.a = text_alpha
            F_Get_SSV(gui.color[color_str], true)
            local measurestrname = gfx.measurestr(name)
            local x0 = xywh[1] + (xywh[3] - measurestrname)/2
            local y0 = xywh[2] + (xywh[4] - fontsz)/2
            gfx.x, gfx.y = x0,y0 
            gfx.drawstr(name)  
        end        

                    

-----------------------------------------------------------------------   
  function GUI_point(objects, gui, col, x, y)
    gfx.a = 0.5
    F_Get_SSV(gui.color[col], true)
    gfx.rect(x,y,objects.point_side,objects.point_side,1)
  end
  
-----------------------------------------------------------------------
  function F_draw_curve(x_table, y_table)
  
    local order = #x_table
    ----------------------------
    function fact(n) if n == 0 then return 1 else return n * fact(n-1) end end
    ----------------------------
    function bezier_eq(n, tab_xy, dt)
      local B = 0
      for i = 0, n-1 do
        B = B + 
          ( fact(n) / ( fact(i) * fact(n-i) ) ) 
          *  (1-dt)^(n-i)  
          * dt ^ i
          * tab_xy[i+1]
      end 
      return B
    end  
    for t = 0, 1, 0.001 do
      local x_point = bezier_eq(order, x_table, t)+ t^order*x_table[order]
      local y_point = bezier_eq(order, y_table, t)+ t^order*y_table[order] 
      gfx.x = x_point
      gfx.y = y_point
      gfx.a = gfx.a
      gfx.setpixel(gfx.r,gfx.g,gfx.b)
    end    
  end

-----------------------------------------------------------------------  
  function F_get(track, fx_id)     
    local fx_name
    _, fx_name = reaper.TrackFX_GetFXName(track, fx_id, '')
    fx_name = fx_name:sub(fx_name:find(':')+1)
    fx_name = (fx_id+1)..': '..fx_name:gsub('[%(].*[%)]','')
    local len = 18
    if fx_name:len() > len then fx_name = fx_name:sub(0,len)..'...' end
    return fx_name
  end

-----------------------------------------------------------------------
  function GUI_pin(pin_info, gui)
    local r,g,b
    r,g,b = F_split_SST(pin_info.ch_col)
    if pin_info.active == 1 then
      gfx.a = 0.8
      
     else
      gfx.a = 0.4
      --r,g,b = F_split_SST(gui.color.grey)
    end
    gfx.r, gfx.g, gfx.b = r/255,g/255,b/255
    gfx.rect(pin_info[1],pin_info[2],pin_info[3]-1,pin_info[4], 0)
    local frame_sz = 3
    if pin_info.cursor == 1 then
      gfx.rect(pin_info[1]-frame_sz,pin_info[2]-frame_sz,pin_info[3]+frame_sz*2,pin_info[4]+frame_sz*2, 1)
    end
    
    gfx.setfont(1, gui.fontname, gui.fontsize_pin)
    gfx.x = pin_info[1] + 2
    gfx.y = pin_info[2] -2
    _, ch = F_split_SST(pin_info.context)
    gfx.drawstr(ch)
  end

-----------------------------------------------------------------------  
  function GUI_wire(pins, wire, gui)
    local r,g,b
    if wire ~= nil and wire.send ~= nil and wire.rec ~= nil and wire.col ~= nil 
      then
      r,g,b = F_split_SST(wire.col)
      if r == nil or g == nil or b == nil then 
        gfx.r, gfx.g, gfx.b = F_split_SST(gui.color.green) else
        gfx.r, gfx.g, gfx.b = r/255,g/255,b/255 
      end
      gfx.a = 0.4
      
      local curve_y_mid = -(pins[wire.send][2]+pins[wire.send][4]/2 - 
        pins[wire.rec][2]+pins[wire.rec][4]/2)*0.75
      
      curve_y_mid = (curve_y_mid + (pins[wire.send][1]+pins[wire.send][3]/2 - 
        pins[wire.rec][1]+pins[wire.rec][3]/2) *0.4)*0.5
      if curve_y_mid < 0 then curve_y_mid = - curve_y_mid end
      F_draw_curve(
                    
                    {pins[wire.send][1]+pins[wire.send][3]/2,
                    pins[wire.send][1]+pins[wire.send][3]/2,
                    pins[wire.send][1]+pins[wire.send][3]/2,
                    pins[wire.rec][1]+pins[wire.rec][3]/2,
                    pins[wire.rec][1]+pins[wire.rec][3]/2,
                    pins[wire.rec][1]+pins[wire.rec][3]/2}, 
                   
                   {pins[wire.send][2]+pins[wire.send][4],
                    pins[wire.send][2]+pins[wire.send][4]/2 + curve_y_mid,
                    pins[wire.send][2]+pins[wire.send][4]/2 + 0.5*curve_y_mid,
                    pins[wire.rec][2]+pins[wire.rec][4]/2 - 0.5*curve_y_mid,
                    pins[wire.rec][2]+pins[wire.rec][4]/2 - curve_y_mid,
                    pins[wire.rec][2]}--+pins[wire.rec][4]/2}
                    
                    )
        
        
        
        --, r,g,b,a)
      
      --[[gfx.line(pins[wire.inp][1]+pins[wire.inp][3]/2,
              pins[wire.inp][2]+pins[wire.inp][4]/2,
              pins[wire.out][1]+pins[wire.out][3]/2,
              pins[wire.out][2]+pins[wire.out][4]/2,1)]]
    end
  end
        
-----------------------------------------------------------------------
  function GUI_DRAW(track,mouse,gfx_data, pins, gui,wires)
    local update_gfx_minor = true
    local alpha, byp_col,fx_name
    local objects = DEFINE_objects()
      
      ----------------------------------------------------------------------- 
          
    -- buffers
    -- buf1 back
    -- buf2 -- buttons back gradient
    -- buf3 top panel
    -- buf4 -- fx objects + io points
    -- buf5 -- wires
        
    -- buf1 background
      if update_gfx then
        fdebug('DEFINE_GUI_buffers_1-mainback')
        gfx.dest = 1
        gfx.setimgdim(1, -1, -1)
        gfx.setimgdim(1, objects.main_w, objects.main_h)
        gfx.a = 1
        F_Get_SSV(gui.color.back, true)
        gfx.rect(0,0, objects.main_w, objects.main_h,1)
      end
    
    -- buf2 -- buttons back gradient
      if update_gfx then
        fdebug('DEFINE_GUI_buffers_2-buttons back')
        gfx.dest = 2
        gfx.setimgdim(2, -1, -1)
        gfx.setimgdim(2, objects.main_w, objects.main_h) 
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
           gfx.gradrect(0,0,objects.main_w, objects.main_h,
                        r,g,b,a,
                        drdx, dgdx, dbdx, dadx,
                        drdy, dgdy, dbdy, dady)
      end
      
    -- buf 3 top panel
      if update_gfx_minor then
        gfx.dest = 3
        gfx.setimgdim(3, -1, -1)
        gfx.setimgdim(3, objects.main_w, objects.main_h)
          GUI_button2(objects, gui, objects.t_track_name, track.name, 1, gui.fontsize_b, 0.9, 'white')
          if track.FX_bypass == 1 then alpha = 0.9 byp_col = 'red' else alpha = 0.3 byp_col = 'white' end
          GUI_button2(objects, gui, objects.t_bypass, 'Bypass', mouse.context2 == 't_bypass', gui.fontsize_b, alpha, byp_col)
      end
      
    -- buf 4 -- fx objects
      if update_gfx_minor then
          gfx.dest = 4
          gfx.setimgdim(4, -1, -1)
          gfx.setimgdim(4, objects.main_w, objects.main_h)
          if gfx_data ~= nil and gfx_data[track.guid] ~= nil then
            for fx_guid, xywh in pairs(gfx_data[track.guid]) do
              fx_name = ENGINE_Get_FX_name(fx_guid)
              local x,y,w,h
              x,y,w,h = F_split_SST(xywh)
              GUI_FX_obj(track, objects, gui,
                          {x,y,w,h},
                          fx_name,
                          mouse.context2 == fx_guid,
                          gui.fontsize_fx,
                          0.8,
                          'green')
            end
          end
      end
      
     
    -- buf 5 -- pins
      if update_gfx or update_gfx_minor2 then
        gfx.dest = 5
        gfx.setimgdim(5, -1, -1)  
        gfx.setimgdim(5, objects.main_w, objects.main_h)
        for i = 1, #pins do
          GUI_pin(pins[i], gui)
        end
      end        
       
    -- buf 6 -- wires
      if update_gfx then
        gfx.dest = 6
        gfx.setimgdim(6, -1, -1)  
        gfx.setimgdim(6, objects.main_w, objects.main_h)
        for i = 1, #wires do
          GUI_wire(pins, wires[i], gui)
        end
      end        
    
    ------------------
    -- common buf20 --
    ------------------
      gfx.dest = 20   
      gfx.setimgdim(20, -1,-1)
      gfx.setimgdim(20, objects.main_w, objects.main_h)
      
      -- common
        gfx.a = 1
        gfx.blit(1, 1, 0, -- backgr
          0,0,objects.main_w, objects.main_h,
          0,0,objects.main_w, objects.main_h, 0,0) 
        gfx.blit(3, 1, 0, -- top panel
          0,0,objects.main_w, objects.main_h,
          0,0,objects.main_w, objects.main_h, 0,0) 
        gfx.blit(4, 1, 0, -- fx
          0,0,objects.main_w, objects.main_h,
          0,0,objects.main_w, objects.main_h, 0,0) 
        gfx.blit(5, 1, 0, -- pins
          0,0,objects.main_w, objects.main_h,
          0,0,objects.main_w, objects.main_h, 0,0)
        
        gfx.a = 0.5   
        gfx.blit(6, 1, 0, -- wires
          0,0,objects.main_w, objects.main_h,
          0,0,objects.main_w, objects.main_h, 0,0)
                        
    
    
    --fdebug('GUI_DRAW')
     
    -- common buffer
      gfx.dest = -1   
      gfx.a = 1
      gfx.x,gfx.y = 0,0
      gfx.blit(20, 1, 0, 
        0,0, objects.main_w, objects.main_h,
        0,0, objects.main_w, objects.main_h, 0,0)
        
    update_gfx = false 
    update_gfx_minor2 = false
    gfx.update()
  end

----------------------------------------------------------------------- 
    -- http://stackoverflow.com/questions/9079853/lua-print-integer-as-a-binary
  function F_toBits(num,bits)
      -- returns a table of bits, most significant first.
      bits = bits or select(2,math.frexp(num))
      local t={} -- will contain the bits        
      for b=bits,1,-1 do
          t[b]=math.floor(math.fmod(num,2))
          num=(num-t[b])/2
      end
      local t2 = {}
      for i = #t,1 , -1 do
        t2[#t2+1] = t[i]
      end
      return t2
  end 
     
-----------------------------------------------------------------------    
  function ENGINE_set_pin(track, fx_id, is_output, pin_id, channel, act)
    -- fx_id 1-based
    msg('create')
    msg(fx_id)
    msg(pin_id)
    msg(channel)
    
    if is_output == 1 then IO = 'outputs' else IO = 'inputs' end
    
    cur_integer = track.fx[fx_id][IO][pin_id]
    cur_integer_t = F_toBits(cur_integer, track.num_ch )
    cur_integer_t[channel] = act
    new_int_str = table.concat(cur_integer_t,'')
    msg(new_int_str)
    new_int = tonumber(new_int_str:reverse(),2)
    reaper.TrackFX_SetPinMappings(track.pointer, 
                                  fx_id-1, --integer fx, 
                                  is_output, -- integer isOutput, 
                                  pin_id-1,--integer pin, 
                                  new_int, 
                                  0)--integer hi32bits)                               
    
  end
  
-----------------------------------------------------------------------  
  function ENGINE_form_new_routing(track, mouse, pins)
    --local pin1, pin2, pin1_id, pin2_id,input_fx_id,output_fx_id,output_pin_context,input_pin_context
     pin1 = mouse.routing_active_input
     pin2 = mouse.routing_active_output
     pin1_fx_id = tonumber(pins[pin1].context:match('[^%s]+'))
     pin2_fx_id = tonumber(pins[pin2].context:match('[^%s]+'))
    
    -- prevent linking from itself
      if pin1_fx_id == pin2_fx_id then return end
      
    -- define pin IO order
    
    if pin1_fx_id > 0 and pin2_fx_id > 0 then
      if pin1_fx_id < pin2_fx_id then
        input_pin_context = pins[pin2].context
        output_pin_context = pins[pin1].context
       else
        input_pin_context = pins[pin1].context
        output_pin_context = pins[pin2].context
      end
     else
      if pin1_fx_id == 0 then
        input_pin_context = pins[pin2].context
        output_pin_context  = pins[pin1].context
      end
      if pin1_fx_id == track.fx_count+1 then
        input_pin_context = pins[pin1].context
        output_pin_context = pins[pin2].context
      end
      if pin2_fx_id == 0 then
        input_pin_context = pins[pin1].context
        output_pin_context  = pins[pin2].context
      end
      if pin2_id == track.fx_count+1 then
        input_pin_context = pins[pin2].context
        output_pin_context = pins[pin1].context        
      end
    end
    
    input_fx_id = tonumber(input_pin_context:match('[^%s]+'))
    output_fx_id = tonumber(output_pin_context:match('[^%s]+'))
    
    msg('output_pin_context')
    msg(output_pin_context)
    msg('input_pin_context')
    msg(input_pin_context)
    
    pin_out = {}
    for num in output_pin_context:gmatch('[^%s]+') do pin_out[#pin_out+1] = tonumber(num) end
    
    pin_in = {}
    for num in input_pin_context:gmatch('[^%s]+') do pin_in[#pin_in+1] = tonumber(num) end
    
    -- prevent i2i o2o
      if pin_out[3] == pin_in[3] then return end
    
    -- TODO check for existing wire
    --if F_get_pin_number(pins, str)
    
    --if pin_in[1] < track.fx_count+1 then
      for i = pin_out[1]+1, pin_in[1]-1 do
        for k = 1, #track.fx[i].inputs do
          ENGINE_set_pin(
                          track, 
                          i, --fx_id
                          0, --is_output
                          k,--pin_id
                          pin_out[2], --channel
                          0)
        end
        if track.fx[i].outputs ~= nil then 
          for k = 1,#track.fx[i].outputs do
            ENGINE_set_pin(
                            track, 
                            i, --fx_id
                            1, --is_output
                            k,--pin_id
                            pin_out[2], --channel
                            0)
          end  
        end
        
      end
      ENGINE_set_pin(
                                    track, 
                                    pin_in[1], --fx_id
                                    0, --is_output
                                    pin_in[2],--pin_id
                                    pin_out[2], --channel
                                    1)      
     
    
  end
  
-----------------------------------------------------------------------     
  function MOUSE_match(mouse, b)
    if b ~= nil then
      if mouse.mx > b[1] and mouse.mx < b[1]+b[3]
        and mouse.my > b[2] and mouse.my < b[2]+b[4] then
       return true 
      end 
    end
  end 

-----------------------------------------------------------------------    
 function F_open_URL(url)    
    if OS=="OSX32" or OS=="OSX64" then
      os.execute("open ".. url)
     else
      os.execute("start ".. url)
    end
  end

  
-----------------------------------------------------------------------            
  function MOUSE_trig(mouse, t)
    if MOUSE_match(mouse, t) 
      and mouse.trigger
      then  
      return true else return false  end
  end        
  
-----------------------------------------------------------------------   
  function MOUSE_get(track, gfx_data, objects, gfx_data_pins)
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
    
    if mouse.last_mx == nil or mouse.last_my == nil or
      mouse.last_mx ~= mouse.mx or mouse.last_my ~= mouse.my then
      mouse.move = true else mouse.move = false 
    end
    
    if mouse.move and MOUSE_match(mouse, {0,0,objects.main_w, objects.main_h}) then 
      update_gfx_minor2 = true -- for bigger bins under mouse cursor
    end
    
    if mouse.LMB_state and not mouse.last_LMB_state then    
      mouse.last_mx_onclick = mouse.mx
      mouse.last_my_onclick = mouse.my
      mouse.trigger = true 
     else 
      mouse.trigger = false
    end
           
    if mouse.last_mx_onclick ~= nil and mouse.last_my_onclick ~= nil then
      mouse.dx = mouse.mx - mouse.last_mx_onclick
      mouse.dy = mouse.my - mouse.last_my_onclick
     else
      mouse.dx, mouse.dy = 0,0
    end
          
    if not mouse.LMB_state then mouse.context = nil end
    if not mouse.LMB_state then mouse.context2 = nil end
    if not mouse.LMB_state then mouse.context3 = nil end

    -- On mouse release
      if mouse.last_LMB_state and not mouse.LMB_state then 
         mouse.release = true 
        else 
         mouse.release = false
      end
          
    --------------------------------------------------------------
    --------------------------------------------------------------
    
    -- update gfx/set extstate on release  
      if mouse.release then
        mouse.last_touched = nil 
        EXT_Set(gfx_data)
        update_gfx = true
      end    
    
    -- top panel  
      if MOUSE_match(mouse, objects.t_bypass) then mouse.context2 = 't_bypass' end
      if MOUSE_trig(mouse, objects.t_bypass) then reaper.Main_OnCommandEx(8, 0, 0) end
    
    -- get object context
      if gfx_data ~= nil and gfx_data[track.guid] ~= nil then
        for guid, xywh in pairs(gfx_data[track.guid]) do
          local t = {}
          for num in xywh:gmatch('[%d]+') do t[#t+1] = tonumber(num) end
          if MOUSE_match(mouse, t) then mouse.context2 = guid end
          if MOUSE_match(mouse, t) and not mouse.last_LMB_state and mouse.LMB_state then 
            mouse.context = guid
            mouse.obj_temp_xywh = gfx_data[track.guid][guid]
          end
        end 
      end       
      
    -- change xywh
      if mouse.context ~=nil and mouse.move and mouse.LMB_state then
        local t = {}
        for num in mouse.obj_temp_xywh:gmatch('[%d]+') do t[#t+1] = math.floor(tonumber(num)) end
        t[1]=t[1]+mouse.dx
        t[2]=t[2]+mouse.dy
        if t[1] < objects.x_limit1 then t[1] = objects.x_limit1 end
        if t[2] < objects.y_limit1 then t[2] = objects.y_limit1 end
        if t[1] + t[3]+ objects.x_limit2 > gfx.w then 
          t[1] = gfx.w - t[3] - objects.x_limit2 end
        if t[2] + t[4]+ objects.y_limit2 > gfx.h then 
          t[2] = gfx.h - t[4]-objects.y_limit2 end
        for i =1, #t do t[i] = math.floor(t[i]) end
        gfx_data[track.guid][mouse.context] = table.concat(t, ' ')
        EXT_Set()
      end
      
    -- get pins context
      for i = 1, #gfx_data_pins do
        if MOUSE_match(mouse, gfx_data_pins[i]) then 
          mouse.context3 = i 
          break 
        end
      end
      
    -- create new routing
      if mouse.trigger and mouse.context3 ~= nil then
        mouse.routing_active = true
        mouse.routing_active_input = mouse.context3
      end
      
      if mouse.release and mouse.routing_active == true then
        mouse.routing_active_output = mouse.context3
        if mouse.routing_active_output ~= nil and mouse.routing_active_input ~= nil then 
          ENGINE_form_new_routing(track, mouse, gfx_data_pins) 
          update_gfx = true
        end
        mouse.routing_active = false
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
      mouse.char = gfx.getchar() 
         
    return mouse
  end
  
-----------------------------------------------------------------------   
  function DEFINE_pins(track, gfx_data, objects, gui,mouse)
    
    local ch_col
    local pins = {}
    -- generate input pins
      for i = 1, track.num_ch do
        if i > #gui.ch_color then ch_col = gui.ch_color[#gui.ch_color] else ch_col = gui.ch_color[i] end
        pins[#pins+1] = {objects.x_offset+(i-1)*objects.pin_w ,
                         objects.t_h + objects.y_offset*2,
                         objects.pin_w,
                         objects.pin_h,
                         ['ch_col']= gui.color.green,
                         ['context']='0 '..i..' 1',
                         ['active']=1,
                         ['cursor']=0}
      end
      
    -- generate output pins
      for i = 1, track.num_ch do
        local ch_col
        if i > #gui.ch_color then ch_col = gui.ch_color[#gui.ch_color] else ch_col = gui.ch_color[i] end
        pins[#pins+1] = {objects.x_offset+(i-1)*objects.pin_w,
                         objects.main_h - objects.y_offset - objects.pin_h,
                         objects.pin_w,
                         objects.pin_h,
                         ['ch_col']=gui.color.blue,
                         ['context']=(track.fx_count+1)..' '..i..' 0',
                         ['active']=1,
                         ['cursor']=0}
      end      
    
    if track.fx_count == 0 or gfx_data == nil then return pins end
    
    -- generate input plugins pins
      for k = 1, track.fx_count do
        if gfx_data[track.guid][track.fx[k].guid] ~= nil then
          local xywh = gfx_data[track.guid][track.fx[k].guid]
          local x,y,w,h = F_split_SST(xywh)
          local act
          for i = 1, #track.fx[k].inputs do
            if track.fx[k].inputs[i] > 0 then
              pins[#pins+1] = {x+(i-1)*objects.pin_w,
                                               y - objects.pin_h,
                                               objects.pin_w,
                                               objects.pin_h,
                                               ['ch_col']=gui.color.green,
                                               ['context']=k..' '..i..' '..0,
                                               ['active']=1,
                                               ['cursor']=0}
             else
              pins[#pins+1] = {x+(i-1)*objects.pin_w,
                                               y - objects.pin_h,
                                               objects.pin_w,
                                               objects.pin_h,
                                               ['ch_col']=gui.color.green,
                                               ['context']=k..' '..i..' '..0,
                                               ['active']=0,
                                               ['cursor']=0}
            end  
          end 
        end
        
      end

    --[[ generate output plugins pins
      for k = 1, track.fx_count do
        if gfx_data[track.guid][track.fx[k].guid] ~= nil then
          local xywh = gfx_data[track.guid][track.fx[k].guid]
          local x,y,w,h = F_split_SST(xywh)
          local act
          
          for i = 1, track.num_ch do
            act = 0
            for m = 1, #track.fx[k].outputs_ch do
              -- check if exists
              if track.fx[k].outputs_ch[m]:find(i..' ') ~= nil then 
                act = 1 
                break
              end
            end 
            pins[#pins+1] = {x+(i-1)*objects.pin_w,
                             y +objects.FX_h,
                                             objects.pin_w,
                                             objects.pin_h,
                                             ['ch_col']=gui.color.blue,
                                             ['context']=k..' '..i..' '..1,
                                             ['active']=act,
                                             ['cursor']=0}
          end   
        end
        
      end  ]]    
    -- generate output plugins pins
      for k = 1, track.fx_count do
        for i = 1, track.num_ch do
          local ch_col
          if i > #gui.ch_color then ch_col = gui.ch_color[#gui.ch_color] else ch_col = gui.ch_color[i] end
          if gfx_data[track.guid][track.fx[k].guid] ~= nil then
            local xywh = gfx_data[track.guid][track.fx[k].guid]
            local x,y,w,h = F_split_SST(xywh)
            local act
            if track.fx[k].outputs[i] ~= nil then
              if track.fx[k].outputs[i] > 0 then 
                act = 1 else act = 0 
              end
              pins[#pins+1] = {x+(i-1)*objects.pin_w,
                             y +objects.FX_h,
                             objects.pin_w,
                             objects.pin_h,
                             ['ch_col']=gui.color.blue,
                             ['context']=k..' '..i..' '..1,
                             ['active']=act,
                             ['cursor']=0}
            end
          end
        end 
      end      
    
    if mouse ~= nil and mouse.context3 ~= nil then
      pins[mouse.context3].cursor = 1
    end
    
    return pins
  end

-----------------------------------------------------------------------   
  function DEFINE_gui_vars()
    -- GUI variables 
      local gui = {}
      gui.OS = reaper.GetOS()
      gui.aa = 1
      gfx.mode = 0
      gui.fontname = 'Calibri'
      gui.fontsize = 23      
      if gui.OS == "OSX32" or gui.OS == "OSX64" then gui.fontsize = gui.fontsize - 7 end
      gui.fontsize_b = gui.fontsize - 5
      gui.fontsize_fx = gui.fontsize_b - 1
      gui.fontsize_pin = gui.fontsize_b - 3
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
      
      gui.ch_color = {}
        gui.ch_color[1] = '128 128 0' -- Olive
        gui.ch_color[2] = '192 192 192' -- Silver
        gui.ch_color[3] = '128 128 128' -- Gray
        gui.ch_color[4] = '0 127 255' -- Azure
        gui.ch_color[5] = '0 255 255' -- Cyan
        gui.ch_color[6] = '34 139 34' -- Forest Green
        gui.ch_color[7] = '255 127 80' -- Coral
        gui.ch_color[8] = '70 130 180' -- Steelblue
      return gui
  end

-----------------------------------------------------------------------   
  function F_get_pin_number(pins, str)
    for i = 1, #pins do
      if pins[i].context == str then return i end
    end
  end

-----------------------------------------------------------------------    
  function F_find_active_output_pin(track, channel, fx_id)
    local t = {}
    for i = fx_id-1, 1, -1 do
      for k = 1,  #track.fx[i].outputs do
        local int_compare = 2^(channel-1)
        if track.fx[i].outputs[k]&int_compare==int_compare then
          
          local exists = nil
          for n = 1,  #track.fx[i].inputs do
            for m =1, track.num_ch do
              int_compare2 = 2^(m-1)
              if track.fx[i].inputs[n]&int_compare2==int_compare2 then
                exists = 1
                break
              end
            end
          end
          
          if exists ~= nil then
            t[#t+1] = i..' '..k..' 1'
          end
        end
      end
      if #t > 0 then return t end
    end
    if #t == 0 then t[#t+1] = '0 '..channel return t end
  end

-----------------------------------------------------------------------   
  function F_is_FX_bypassed(track ,fx_id, channel)  
    local int_compare, pin
    
    if track.fx[fx_id].inputs ~= nil then
      for pin = 1, #track.fx[fx_id].inputs do
        int_compare = 2^(channel-1)
        if track.fx[fx_id].inputs[pin]&int_compare==int_compare then
          return 0, pin, 0
        end
      end
    end
    
    if track.fx[fx_id].outputs ~= nil then
      for pin = 1, #track.fx[fx_id].outputs do
        int_compare = 2^(channel-1)
        if track.fx[fx_id].outputs[pin]&int_compare==int_compare then
          return 0, pin, 1
        end
      end
    end
    
    return 1, 0, 0
  end
  
-----------------------------------------------------------------------   
  function DEFINE_signal_flow(track, pins_table, gui)
    
    wires = {}
    local int_compare,str_pin_context, sz,inp_exists, out_exists
    
    for fx_id = 1, #track.fx do
    
      for pin = 1, #track.fx[fx_id].inputs do
        for channel =1, track.num_ch do
          int_compare = 2^(channel-1)
          is_input = 0
          if track.fx[fx_id].inputs[pin]&int_compare==int_compare then
            
            local is_byp,prev_id,pin_out
            for fx_id_check = fx_id-1, 0, -1 do
              is_byp, pin_out, is_input = F_is_FX_bypassed(track ,fx_id_check, channel)
              if is_byp == 0 then prev_id = fx_id_check break end
            end
            
            if track.fx[prev_id].outputs[pin_out]~= 0 then
              sz = #wires + 1
              wires[sz] = {}
              wires[sz].send = F_get_pin_number(pins_table, prev_id..' '..pin_out..' '..1)
              wires[sz].rec = F_get_pin_number(pins_table, fx_id..' '..pin..' '..0)
              wires[sz].col = gui.color.green        
            end
            
          end  
        end
      end
      
    end
    
    return wires
  end    
    
  
----------------------------------------------------------------------- 
  function MAIN_defer()
    local 
      objects 
      --,update_data 
      --,gfx_data
      ,track
      ,gui
      ,gfx_data_pins
      ,wires
         
    track = DEFINE_track_data()
    objects = DEFINE_objects(track)
    gui = DEFINE_gui_vars()
    update_gfx, pcc_last = DEFINE_update_triggers()
    if update_gfx or gfx_data == nil then 
      gfx_data = ENGINE_build_gfx_data(objects,gfx_data)
      EXT_Set(gfx_data)
    end
    
    
    gfx_data_pins = DEFINE_pins(track,gfx_data, objects,gui, mouse)
    wires = DEFINE_signal_flow(track,gfx_data_pins,gui)
    mouse = MOUSE_get(track,gfx_data,objects,gfx_data_pins)
    GUI_DRAW(track, mouse, gfx_data, gfx_data_pins, gui, wires)
    
    
    if mouse.char == 27 then MAIN_exit() end  --escape
    if mouse.char == 32 then reaper.Main_OnCommandEx(40044, 0,0) end -- space-> transport play   
    if mouse.char ~= -1 then reaper.defer(MAIN_defer) else MAIN_exit() end
  end 

-----------------------------------------------------------------------   
  function DEFINE_objects(track)
    -- GUI global
      local objects = {}
      objects.x_offset = 5
      objects.y_offset = 5
      objects.main_h = 400
      objects.main_w = 500
      
    -- top panel
      objects.t_h = 25
      objects.t_track_name = {objects.x_offset,
                              objects.y_offset,
                              (objects.main_w - objects.x_offset*2)*0.75,
                              objects.t_h}
      objects.t_bypass = {objects.x_offset*2 + objects.t_track_name[3],
                          objects.y_offset,
                          objects.main_w - objects.t_track_name[3] - objects.x_offset*3,
                          objects.t_h}    
      objects.point_side = 15 
      objects.pin_w = 15   
      
      objects.FX_w =  140
      objects.FX_h =  40          
      
      objects.pin_h = 12
      objects.pin_w = 12  
      
      objects.x_limit1 = objects.x_offset
      objects.x_limit2 = objects.x_offset
      objects.y_limit1 = objects.pin_h + objects.t_h + objects.y_offset*5 + 4
      objects.y_limit2 = objects.y_offset*2 + objects.pin_h*2 +4
      
      -- generating new FX xywh
        objects.x_offs_fx = 10
        objects.dx_offs_fx = 10
        objects.y_offs_fx = 10
        objects.dy_offs_fx = objects.FX_h+objects.pin_h*2 + objects.y_offset*2
        objects.d_offs_fx = 10
        objects.dx_offs_fx2 = objects.FX_w
        objects.dy_offs_fx2 = - gfx.h + objects.x_offs_fx + objects.dx_offs_fx + objects.d_offs_fx-- when out of y
                
    return objects
  end 

-----------------------------------------------------------------------   
  function EXT_Get()
    local extstate_s
    local gfx_data = {}
    retval, extstate_s = reaper.GetProjExtState(0, 'MPL_MODULAR_CHAIN', 'MPL_MC_DATA')
    fdebug('\nGET\n'..extstate_s) 
    for line in  extstate_s:gmatch('[^\n]+') do
      local t = {}
      for word in line:gmatch('[^%s]+') do
        t[#t+1] = word
      end
      local tr_guid = t[1]
      local fx_guid = t[2]
      if gfx_data[tr_guid] == nil then gfx_data[tr_guid] = {} end
      gfx_data[tr_guid][fx_guid] = t[3]..' '..t[4]..' '..t[5]..' '..t[6]
    end
    return gfx_data
  end

-----------------------------------------------------------------------  
  function EXT_Set(gfx_data)
    if gfx_data ~= nil then
      local extstate_s = ''
      for track_guid in pairs(gfx_data) do
        for fx_guid, xywh in pairs(gfx_data[track_guid]) do
          extstate_s = extstate_s..track_guid..' '..fx_guid..' '..xywh..'\n'
        end
      end
      fdebug('\nSET\n'..extstate_s)
      reaper.SetProjExtState(0, 'MPL_MODULAR_CHAIN', 'MPL_MC_DATA',extstate_s)
    end
  end 
  
-----------------------------------------------------------------------  
  debug_mode = 1
  if debug_mode == 1 then msg("") end   
     
  local objects = DEFINE_objects()  
  gfx.init("mpl ModularChain // "..vrs, objects.main_w, objects.main_h, 0)
  
  mouse = {}
  update_gfx = true
  MAIN_defer()
 
