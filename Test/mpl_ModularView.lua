-- @description ModularView
-- @version 0.1alpha
-- @author MPL
-- @website http://forum.cockos.com/showthread.php?t=188335
-- @changelog
--    + developer preview

--[[ 
learn
modulation
links
pins

mark as obsolete
  --Script: mpl_List all MIDI OSC learn for current project.lua
  --Script: mpl_List all MIDI OSC learn from focused fx.lua
  --Script: mpl_Parameter Modulation Viewer.lua
  --Script: mpl_Copy LFO settings from last touched FX parameter.lua
  --Script: mpl_Paste LFO settings for last touched FX parameter.lua
]]


  -- NOT gfx NOT reaper
  local scr_title = 'ModularView'
  for key in pairs(reaper) do _G[key]=reaper[key]  end 
  --  INIT  -----------------------------------------
  local conf = {} 
  local obj = {}
  local wires = {}
  local data= {}
   structure = {}
  local ext_data = {}
  --local upd_data, upd_gui, clock,upd_dyn_objects
  local mouse = {}
  local item_XYshift = {}
  scroll = {}
  ---------------------------------------------------
  function msg(s) if s then  ShowConsoleMsg(s..'\n') end end
  ---------------------------------------------------
  function ExtState_Def()
      return {ES_key = 'MPL_'..scr_title,
              wind_x =  50,
              wind_y =  50,
              wind_w =  200,
              wind_h =  300,
              dock =    0}
  end  
  ---------------------------------------------------
  function ExtState_Load()
    local def = ExtState_Def()
    for key in pairs(def) do 
      local es_str = GetExtState(def.ES_key, key)
      if es_str == '' then conf[key] = def[key] else conf[key] = tonumber(es_str) or es_str end
    end
  end
  ---------------------------------------------------
  function ExtState_Save()
    _, conf.wind_x, conf.wind_y, conf.wind_w, conf.wind_h = gfx.dock(-1, 0,0,0,0)
    for key in pairs(conf) do SetExtState(conf.ES_key, key, conf[key], true)  end
  end  
  ---------------------------------------------------  
  function ExtStateProjData_Save2()
  
    local collect_t = { {item_XYshift, 'item_XYshift'},
                        {structure,'structure'},
                        {scroll,'scroll'}}
                
    local str = ''
    for i = 1, #collect_t do
      local t = collect_t[i][1]
      local t_key = collect_t[i][2]
      str = str..'\n<'..t_key
      for key in pairs(t) do 
        local add =''
        if type(t[key]) ~= 'table' then 
          add = t[key] 
         else
          for i2 = 1, #t[key]  do add = add..t[key][i2]..' ' end
        end
        str = str..'\n'..key..' '..add  end
      str = str..'\n>'
    end

          
    msg(str)
    SetProjExtState( 0, scr_title, 'extdata2', str )
  end
  ---------------------------------------------------  
  function ExtStateProjData_Load2()
    
    local collect_t = { {item_XYshift, 'item_XYshift'},
                        {structure,'structure'},
                        {scroll,'scroll'}}
                            
    -- item_XYshift
    local retval, extstr = GetProjExtState( 0, scr_title, 'extdata2' )
    for i = 1, #collect_t do
      local t = collect_t[i][1]
      local key = collect_t[i][2]
      local matchedstr = extstr:match('<'..key..'(.-)>')
      if matchedstr then 
        for line in matchedstr:gmatch('[^\r\n]+') do
          local vals = {}
          for val in line:gmatch('[^%s]+') do 
            if tonumber(val) then val = tonumber(val) end 
            vals[#vals+1] = val 
          end
          if #vals > 2 then
            local key2 = vals[1]
            if not t[key2] then t[key2] = {} end
            for i = 2, #vals do t[key2] [ #t[key2]+1 ] = vals[i] end
           elseif #vals == 2 then 
            local key2 = vals[1]
            t[key2] = vals[2]
          end
        end
      end
    end
    
  end
  ---------------------------------------------------    
  local SCC,lastSCC 
  function Update_PSCC()
    SCC =  GetProjectStateChangeCount( 0 ) 
    local ret = not lastSCC or lastSCC ~= SCC
    lastSCC = SCC
    return ret
  end
  ---------------------------------------------------
  local last_wx, last_wy, last_ww, last_wh
  function Update_XYWH()
    local  _, wx,wy,ww,wh = gfx.dock(-1, 0,0,0,0)
    local retval=0
    if wx ~= last_wx or wy ~= last_wy then retval= 2 end --- minor
    if ww ~= last_ww or wh ~= last_wh then retval= 1 end --- major
    if not last_wx then retval = -1 end
    last_wx, last_wy, last_ww, last_wh = wx,wy,ww,wh
    return retval
  end  
  ---------------------------------------------------
  function GUI_draw()
    gfx.mode = 0
    gfx.dest = -1   
    gfx.a = 1
    gfx.x,gfx.y = 0,0  
        
    --  toolbar line
      gfx.set(1,1,1,0.05)
      gfx.line(obj.toolbar_w, 0, obj.toolbar_w, gfx.h)  
    -- nav panel  
      gfx.set(1,1,1,0.05)
      gfx.line(obj.toolbar_w, obj.nav_panel_h, gfx.w, obj.nav_panel_h) 
    -- toolbar
      local gr_w, gr_h = gfx.getimgdim(1)
      gfx.a = 0.7
      gfx.blit(1, 1, math.rad(180),
                          0,0,gr_w, gr_h,
                          -5,0,obj.toolbar_w+5, gfx.h, 
                          0,0)          
    --  back
      local gr_w, gr_h = gfx.getimgdim(1)
      gfx.a = 0.7
      gfx.blit(1, 1, 0,
                        0,0,gr_w, gr_h,
                        obj.toolbar_w,0,gfx.w-obj.toolbar_w, gfx.h, 
                        0,0)   
    -- wires
      gfx.a = 0.5
      gfx.blit(11, 1, 0,
                0,0,gfx.w, gfx.h,
                obj.toolbar_w,obj.nav_panel_h,gfx.w, gfx.h, 0,0)
                
    -- dynobjects
      gfx.a = 1
      gfx.blit(10, 1, 0,
                0,0,gfx.w, gfx.h,
                obj.toolbar_w,obj.nav_panel_h,gfx.w, gfx.h, 0,0)

    -- dynobjects
      gfx.a = 1
      gfx.blit(12, 1, 0,
                0,0,gfx.w, gfx.h,
                0,0,gfx.w, gfx.h, 0,0)

    -- sliders
      gfx.a = 1
      gfx.blit(13, 1, 0,
                0,0,gfx.w, gfx.h,
                0,0,gfx.w, gfx.h, 0,0)
                                                
    -- draw wires                      
      if upd_gui == 1 then -- 
        gfx.setimgdim(11, -1, -1)  
        gfx.setimgdim(11, gfx.w, gfx.h) 
        gfx.dest = 11
        gfx.a = 1
        for i = 1, #wires do GUI_wire(wires[i]) end
      end  
                                      
    -- draw dyn objects                      
      if upd_gui == 1 then -- 
        gfx.setimgdim(10, -1, -1)  
        gfx.setimgdim(10, gfx.w, gfx.h) 
        gfx.dest = 10
        gfx.a = 1
        for key in pairs(obj) do if type(obj[key]) == 'table' and obj[key].clear and not obj[key].is_slider then GUI_But(obj[key]) end  end 
      end

    -- draw objects                      
      if upd_gui == 1 then -- 
        gfx.setimgdim(12, -1, -1)  
        gfx.setimgdim(12, gfx.w, gfx.h) 
        gfx.dest = 12
        gfx.a = 1
        for key in pairs(obj) do if type(obj[key]) == 'table' and not obj[key].clear and not obj[key].is_slider then GUI_But(obj[key]) end  end 
      end    
      
    -- draw sliders                    
      if upd_gui == 1 or upd_gui == 3 then -- 
        gfx.setimgdim(13, -1, -1)  
        gfx.setimgdim(13, gfx.w, gfx.h) 
        gfx.dest = 13
        gfx.a = 1
        for key in pairs(obj) do if type(obj[key]) == 'table' and obj[key].is_slider then GUI_Slider(obj[key]) end  end 
      end       
      
      gfx.update()
  end        
  ---------------------------------------------------           
  function GUI_Slider(t)
    --  fill frame
      if t.frame_col then SetCol(t.frame_col,t.frame_fill_ratio)  end 
      gfx.a = 1
      if t.frame_fill_a then gfx.a = t.frame_fill_a   end
      gfx.rect(t.x,t.y,t.w,t.h, true)
      gfx.a = 1
      if t.frame_rect_a then 
        if t.frame_rect_col then SetCol(t.frame_rect_col) end
        gfx.a = t.frame_rect_a 
        gfx.rect(t.x,t.y,t.w,t.h, false)
      end    
  end
  ---------------------------------------------------
  function GUI_grad()
    local grad_sz = 300
    gfx.mode = 0
    gfx.dest = 1
    gfx.setimgdim(1, -1, -1)  
    gfx.setimgdim(1, grad_sz,grad_sz)  
    local r,g,b,a = 1,1,1,0.6
    gfx.x, gfx.y = 0,0
    local c = 0.55
    local drdx = c*0.0001
    local drdy = c*0.00001
    local dgdx = c*0.0003
    local dgdy = c*0.0001    
    local dbdx = c*0.00008
    local dbdy = c*0.00001
    local dadx = c*0.0004
    local dady = c*0.0002       
    gfx.gradrect(0,0, grad_sz, grad_sz, 
                          r,g,b,a, 
                          drdx, dgdx, dbdx, dadx, 
                          drdy, dgdy, dbdy, dady)
                         
  end  
  ---------------------------------------------------  
  function OBJ_scroll()
    local offs = 5
    obj.scrollbar_y = {  
                              x = gfx.w - obj.scroll_w,
                              y = 0,
                              h = obj.nav_panel_h,
                              w = obj.scroll_w,
                              txt = 'DragView',
                              txt_a=1, 
                              txt_col=16777215,
                              frame_rect_a=0.5,
                              frame_fill_ratio=0.5,
                              frame_fill_a=0.5,
                              frame_col=0x6E6E6E,
                              fontsz=obj.fontsz1,
                              func_onLclick = function ()                        
                                                local path = structure.path_ID
                                                if not scroll[path] then scroll[path] = {0,0} end
                                                mouse.custom_val_latch = {scroll[path][1],
                                                                          scroll[path][2]}                          
                                              end,
                              func_onLDrag = function()
                                                local path = structure.path_ID
                                                if mouse.custom_val_latch then 
                                                  scroll[path][1] = mouse.custom_val_latch[1] + mouse.mx_latch - mouse.mx
                                                  scroll[path][2] = mouse.custom_val_latch[2] + mouse.my_latch - mouse.my                                                  
                                                  ExtStateProjData_Save2()
                                                  upd_data = 1
                                                end
                                              end,                        
                      }
    obj.resetscroll = {  
                              x = gfx.w - obj.scroll_w*2-offs,
                              y = 0,
                              h = obj.nav_panel_h,
                              w = obj.scroll_w,
                              txt = 'ResetView',
                              txt_a=1, 
                              txt_col=16777215,
                              frame_rect_a=0.5,
                              frame_fill_ratio=0.5,
                              frame_fill_a=0.5,
                              frame_col=0x6E6E6E,
                              fontsz=obj.fontsz1,
                              func_onLclick = function ()
                                                -- reset object shifts
                                                if structure.cur_level == 0 then 
                                                  for key in pairs(item_XYshift) do  
                                                    if        key:match('tr') 
                                                      and not key:match('FX') then  item_XYshift[key] = nil  end 
                                                  end
                                                 elseif structure.cur_level == 1 then 
                                                  local cur_tr = structure.path_IDtr
                                                    for key in pairs(item_XYshift) do  
                                                      if        key:match('tr'..cur_tr) 
                                                        and     key:match('FX') then 
                                                        item_XYshift[key] = nil 
                                                      end 
                                                    end
                                                end
                                                
                                                -- reset scroll
                                                local path = structure.path_ID
                                                scroll[path] = nil 
                                                
                                                ExtStateProjData_Save2()
                                                upd_data = true
                                              end,                        
                      }                      
  end
  ---------------------------------------------------   
  function OBJ_init()
    obj.toolbar_w = 20
    obj.nav_panel_h = 20
    obj.obj_params = ',x,y,w,h,txt,txt_a,txt_col,frame_rect_a,frame_fill_a,frame_col,fontsz'
    obj.fontsz1 = 13
    obj.pin_side = 6
    obj.pins_offset = 50--wire edges
    
    obj.item_w = 120
    obj.item_h = 18  
    obj.offs = 10 
    obj.w_sep_items = 40
    obj.w_sep_items2 = 40
    obj.x_shift_folder = 180
    
    obj.scroll_w =60
    obj.scroll_ratio = 4
  end
                    
  ---------------------------------------------------  
  function Data_Update()
    data.master_guid = GetTrackGUID(  GetMasterTrack( 0 ))
    
    local retval, projfn = EnumProjects( -1, '' )
    projfn = projfn:gsub('\\','/')
    projfn = projfn:match('.*/(.*)')
    if not projfn then projfn = '(unsaved)' end
    data.projname = projfn
    
    
    local depth_change = 0    
    for i = 1, CountTracks(0) do
      local tr = GetTrack(0,i-1)
      local depth = GetMediaTrackInfo_Value( tr, 'I_FOLDERDEPTH' )
      data[i]= { name=  ({GetTrackName( tr, '')})[2],
                                col =  GetTrackColor( tr ),
                                sends = {},
                                depth =  depth,
                                depth_change=depth_change,
                                guid = GetTrackGUID(tr),
                                is_top_level = depth_change==0,
                                fx = {},
                                nchan = GetMediaTrackInfo_Value( tr, 'I_NCHAN' )}
      depth_change = depth_change + depth
      
      
      -- regular send
        local hw_outs = GetTrackNumSends( tr, 1 )
        for sendidx = 1, GetTrackNumSends( tr,0 ) do
          local dest_tr = BR_GetMediaTrackSendInfo_Track( tr, 0, sendidx-1, 1 )
          local retval, sname = GetTrackSendName( tr,  hw_outs + sendidx-1, '' )
          data[i].sends[hw_outs+sendidx] = { dest= GetTrackGUID(dest_tr),
                                              s_type = 'regular',
                                              name =  sname,
                                              isAudio =  reaper.GetTrackSendInfo_Value( tr, 0, sendidx-1, 'I_SRCCHAN' )>-1,
                                              isMIDI =  reaper.GetTrackSendInfo_Value( tr, 0, sendidx-1, 'I_MIDIFLAGS' )~=4177951}   
        end
        
      --  parent
        if GetMediaTrackInfo_Value( tr, 'B_MAINSEND' ) and GetParentTrack( tr ) then
          data[i].sends[hw_outs+GetTrackNumSends( tr,0 )+1] = { dest= GetTrackGUID( GetParentTrack( tr )),
                                                              name =  '',
                                                              isAudio = true,
                                                              isMIDI = true,
                                                              s_type = 'parent'}
      --  master
         elseif  GetMediaTrackInfo_Value( tr, 'B_MAINSEND' ) and not GetParentTrack( tr ) then
          data[i].sends[hw_outs+GetTrackNumSends( tr,0 )+1] = { dest= data.master_guid ,
                                                              name =  '',
                                                              s_type = 'master',
                                                              isAudio = true,
                                                              isMIDI = false
                                                              }      
        end
      -- HW send
        for sendidx = 1, hw_outs do
          local retval, sname = GetTrackSendName( tr, sendidx-1, '' )
          local dst_chan = GetTrackSendInfo_Value( tr, 1, sendidx-1, 'I_DSTCHAN' )
          data[i].sends[sendidx] = { name = sname,
                                      dst_chan = dst_chan,
                                      s_type = 'HW'}
        end    
    end
    
  end
  --------------------------------------------------- 
  function Data_UpdateL1()
    local tr_id = structure.path_IDtr
    if not data[tr_id] then Data_Update() end
    if not data[tr_id] then return end
    
    local guid = data[tr_id].guid
    local tr
    if guid then tr = BR_GetMediaTrackByGUID( 0, guid ) end
    if not tr then return end
    
    local fx_cnt = TrackFX_GetCount( tr )
    --generate dummy IO
    local pins = {outpins = {}}
    for pin = 1, data[tr_id].nchan do pins.outpins[pin] = 2^(pin-1) end
    data[tr_id].fx[0] = { FXname = 'In',
                          inputPins_sz = 0,
                          outputPins_sz =data[tr_id].nchan,
                          pins=pins}
    local pins = {inpins = {}}
    for pin = 1, data[tr_id].nchan do pins.inpins[pin] = 2^(pin-1) end
    data[tr_id].fx[fx_cnt+1] = { FXname = 'Out',
                          inputPins_sz = data[tr_id].nchan,
                          outputPins_sz =0,
                          pins=pins}
                          
                                                    
                          
    for fx_id = 1, fx_cnt do
        local fx_name =  ({TrackFX_GetFXName( tr, fx_id-1, '' )})[2]
        local _, inputPins_sz, outputPins_sz = TrackFX_GetIOSize( tr, fx_id-1 )
        local pins = {inpins={},outpins={}}
        for inpin = 1, inputPins_sz do
          local mask = TrackFX_GetPinMappings( tr, fx_id-1, 0, inpin-1  )
          pins.inpins[inpin] = mask
        end
        for outpin = 1, outputPins_sz do
          local mask = TrackFX_GetPinMappings( tr, fx_id-1, 1, outpin-1  )
          pins.outpins[outpin] = mask
        end        
        data[tr_id].fx[fx_id] = { FXname = fx_name,
                              FXGUID = TrackFX_GetFXGUID( tr, fx_id-1 ),
                              inputPins_sz = inputPins_sz,
                              outputPins_sz = outputPins_sz,
                              pins=pins}
    end
  end
  
  --[[
  data.tr_name =  ({GetTrackName( tr, '' )})[2]
      -- fx names
        local fx_names = {}
        for fx =1,  TrackFX_GetCount( tr ) do
          local guid = TrackFX_GetFXGUID( tr, fx-1 ):gsub('-',''):match('{.-}')
          guid = guid:gsub('[{}]','')
          fx_names[guid] = {id = fx-1,
                            name = ({reaper.TrackFX_GetFXName( tr, fx-1, '' )})[2]}
        end
      
      -- chunk stuff
        local _, chunk = GetTrackStateChunk(  tr, '', false )
        local t= {} for line in chunk:gmatch('[^\n\r]+') do t[#t+1] = line end
        local collect_chunk = false
        local look_FXGUID = nil
        for i = 1, #t do 
          local line = t[i]
          if line:match('FXID') then look_FXGUID = line:gsub('-',''):match('{.-}') end
          if line:match('PROGRAMENV') then collect_chunk = '' end
          if collect_chunk and look_FXGUID then collect_chunk = collect_chunk..'\n'..line end
          if collect_chunk  and line:match('>') then 
            look_FXGUID = look_FXGUID:gsub('[{}]','')
            local fx_gett = GetFxNamebyGUID(look_FXGUID, fx_names)
            local fx_name =fx_gett.name
            local fx_id = fx_gett.id
            local param_num = tonumber(collect_chunk:match('[%d]+'))
            local param_name =  ({TrackFX_GetParamName( tr, fx_id, param_num, '' )})[2]
            
            local lfo_str = collect_chunk:match('LFO %d')
            if lfo_str and lfo_str:match('1') then lfo_str = 'LFO: Enabled' else lfo_str = 'LFO: Disabled' end
            
            local aud_str = collect_chunk:match('AUDIOCTL %d')
            if aud_str and aud_str:match('1') then aud_str = 'AudioControl: Enabled' else aud_str = 'AudioControl: Disabled' end
            
            local plink_str = collect_chunk:match('PLINK .-[\n]')
            local pm_offs,pm_scale,pm_par,pm_fx, pm_fx_name,pm_par_name ='','','','','',''
            if plink_str then 
              local t2 = {}
              for num in plink_str:gmatch('[%d%p]+') do t2[#t2+1]  = num end
              pm_offs = '         Link: offset '..math.floor(t2[1]*100)..'%\n'
              pm_scale = '         Link: scale '..math.floor(t2[4]*100)..'%\n'
              pm_par = tonumber(t2[3])
              pm_fx = tonumber(t2[2]:match('[%d]+'))
              pm_par_name = '         SourceParam: '..({TrackFX_GetParamName( tr, pm_fx, pm_par, '' )})[2]..'\n'
              pm_fx_name = ({reaper.TrackFX_GetFXName( tr,pm_fx, '' )})[2]
              if fx_id == pm_fx then pm_fx_name = pm_fx_name..' (self)' end
              pm_fx_name = '         SourceFX: '..pm_fx_name..'\n'
            end
            data[#data+1] = {ch = collect_chunk ,
                             slave_fx_name =fx_name,
                             slave_fx_id=fx_id,
                             slave_param_num = param_num,
                             slave_param_name=param_name,
                             lfo_str=lfo_str,
                             aud_str=aud_str,
                             plink_str=plink_str,
                             pm_offs = pm_offs,
                             pm_scale = pm_scale,
                             pm_par_name = pm_par_name,
                             pm_fx_name = pm_fx_name}
            
            ]]
  ---------------------------------------------------           
  function Data_UpdateStructureNav()
    if not structure.cur_level then structure.cur_level = 0 end
    if not structure.path_ID then structure.path_ID = 0 end
    
    
    do return end
    
    --[[
    structure.lev1_name = data.projname
    if not structure.curlev then structure.curlev = 0 end
    structure.lev2_name = ''
    
    for cur = 0, 4 do
      if not structure['lev'..cur..'_xscroll'] then structure['lev'..cur..'_xscroll'] = 0 end
      if not structure['lev'..cur..'_yscroll'] then structure['lev'..cur..'_yscroll'] = 0 end
    end
        
    if structure.lev2_guid then
      local guid = structure.lev2_guid
      if guid then
        local tr = BR_GetMediaTrackByGUID( 0, guid )
        if tr then 
          local retval, tr_name = reaper.GetTrackName( tr, '' )
          if retval then 
            structure.lev2_name = tr_name
            structure.lev2_id = CSurf_TrackToID(tr,false)..':'
            structure.lev2_id_int = CSurf_TrackToID(tr,false)
          end
        end
        if guid == data.master_guid then 
         structure.lev2_name = 'Master'
         structure.lev2_id = ''
        end
      end
    end
    
    -- ExtStateProjData_Save('structure', structure)]]
  end
  --------------------------------------------------- 
  function MOUSE_Match(b) 
    local xoffs, yoffs = 0,0
    if b.clear then 
      xoffs = obj.toolbar_w
      yoffs = obj.nav_panel_h
    end
    if b.x and b.y and b.w and b.h then 
      return 
        mouse.mx > b.x+xoffs 
        and mouse.mx < b.x+b.w+xoffs 
        and mouse.my > b.y+yoffs 
        and mouse.my < b.y+b.h+yoffs 
        --and (b.clear and mouse.mx  > obj.toolbar_w and mouse.mx  > obj.nav_panel_h  )
    end  
  end
  --------------------------------------------------- 
  function MOUSE()
    mouse.mx = gfx.mouse_x
    mouse.my = gfx.mouse_y
    mouse.dx, mouse.dy = 0,0
    mouse.LMB_state = gfx.mouse_cap&1 == 1 
    mouse.RMB_state = gfx.mouse_cap&2 == 2 
    mouse.MMB_state = gfx.mouse_cap&64 == 64
    mouse.Ctrl_LMB_state = gfx.mouse_cap&5 == 5 
    mouse.Ctrl_state = gfx.mouse_cap&4 == 4 
    mouse.Alt_state = gfx.mouse_cap&17 == 17 -- alt + LB
    mouse.wheel = gfx.mouse_wheel
    
    -- init dyn states 
      if not mouse.mx_latch then 
        mouse.mx_latch = mouse.mx
        mouse.my_latch = mouse.my
      end  
      if not mouse.onLclickTS then mouse.onLclickTS = clock end
      if not mouse.onLDclick then mouse.onLDclick = false end
    
    -- get base states
      mouse.onLclick = mouse.LMB_state and not mouse.last_LMB_state    
      mouse.onLDrag = mouse.LMB_state and mouse.last_LMB_state
      mouse.onLRelease = not mouse.LMB_state and mouse.last_LMB_state
    
    -- analyze state
      if not mouse.onLDrag then mouse.context_latch = '' end
      if mouse.onLclick then 
        mouse.onLDclick = mouse.onLclickTS and clock - mouse.onLclickTS < 0.2        
        mouse.onLclickTS = clock
        mouse.mx_latch = mouse.mx
        mouse.my_latch = mouse.my
      end
      if mouse.onLDrag then 
        mouse.dx = mouse.mx - mouse.mx_latch
        mouse.dy = mouse.my - mouse.my_latch
      end
    
    -- perform on GUI
    for key in spairs(obj) do 
      if type(obj[key]) == 'table' then
        
        if obj[key].func_onLclick and mouse.onLclick and MOUSE_Match(obj[key]) and not mouse.onLDclick then  
          obj[key].func_onLclick() 
          mouse.context_latch = key
          mouse.context_latch_xobj = obj[key].x
          mouse.context_latch_yobj = obj[key].y
          break 
        end
        if obj[key].func_onLDrag and mouse.onLDrag  and mouse.context_latch == key then 
          obj[key].func_onLDrag() 
          break 
        end
        if obj[key].func_onLDclick and mouse.onLDclick  and MOUSE_Match(obj[key])  then 
          obj[key].func_onLDclick() 
          break 
        end
        
      end
    end
    
    if mouse.onLRelease then 
      upd_data = true
      mouse.custom_val_latch = nil
    end
    mouse.onLDclick = false
    mouse.last_LMB_state = mouse.LMB_state
  end
  ---------------------------------------------------
  function spairs(t, order) --http://stackoverflow.com/questions/15706270/sort-a-table-in-lua
    local keys = {}
    for k in pairs(t) do keys[#keys+1] = k end
    if order then table.sort(keys, function(a,b) return order(t, a, b) end)  else  table.sort(keys) end
    local i = 0
    return function()
              i = i + 1
              if keys[i] then return keys[i], t[keys[i]] end
           end
  end
  --------------------------------------------------- 
  function run()
    clock = os.clock()
    upd_data = Update_PSCC()
    upd_gui = Update_XYWH() -- 1 wh 2 xy 3 upd sliders
    MOUSE()
    if upd_data then 
 
      Data_UpdateStructureNav()
      OBJ_scroll()
      
      if upd_dyn_objects then
        for key in pairs(obj) do if type(obj[key]) == 'table' and obj[key].clear then obj[key] = nil end end
        for i = #wires, 1,-1 do if wires[i].clear then table.remove(wires,i) end end
        upd_dyn_objects = false
      end
      
      if structure.cur_level == 0 then 
        Data_Update()
        OBJ_GenButtons_L0() 
        OBJ_GenWires_L0()
       elseif structure.cur_level == 1 then
        Data_UpdateL1() 
        OBJ_GenButtons_L1() 
        OBJ_GenWires_L1()  
      end
      
      OBJ_UpdateNavButtons()
      upd_gui = 1 
    end
    if upd_gui == 1 then 
      OBJ_scroll()
      GUI_grad()
    end
    if upd_gui > 0 then ExtState_Save() end 
    GUI_draw()
    
    if gfx.getchar() >= 0 then defer(run) else atexit(gfx.quit) end
  end
  ---------------------------------------------------
  function OBJ_UpdateNavButtons()
    local fr_fill = 0.4
    local offs = 5
    local nav_w = 130
    
    if not data.projname then return end
    obj.struct_proj = {
                            x = obj.toolbar_w,
                            y = 0,
                            w= nav_w,
                            h = obj.nav_panel_h,
                            txt = data.projname..' > ',
                            txt_a=1, 
                            frame_rect_a = 0.1,
                            frame_fill_a=0.4,
                            frame_col=0,
                            fontsz=obj.fontsz1,
                            func_onLclick = function ()                                                                   
                                              structure.cur_level = 0
                                              structure.path_ID = 0
                                              ExtStateProjData_Save2()
                                              upd_dyn_objects = true -- reset items and wires on global change
                                              upd_data = true
                                            end} 
      local cur_tr_id = structure.path_IDtr                      
      if not data[cur_tr_id]  then return end                              
      obj.struct_tr = {
                            x = obj.toolbar_w+nav_w+offs,
                            y = 0,
                            w= nav_w,
                            h = obj.nav_panel_h,
                            txt = cur_tr_id..': '..data[cur_tr_id].name,
                            txt_a=1, 
                            frame_rect_a = 0.1,
                            frame_fill_a=0.4,
                            frame_col=0,
                            fontsz=obj.fontsz1,
                            func_onLclick = function ()                  
                                              structure.cur_level = 1
                                              if structure.path_IDtr then 
                                                structure.path_ID = '1_'..structure.path_IDtr
                                              end
                                              ExtStateProjData_Save2()
                                              upd_dyn_objects = true
                                              upd_data = true
                                            end}                            
  end
  ---------------------------------------------------
  function ExtendClass(Child, Parent)
    setmetatable(Child,{__index = Parent}) 
  end
  ---------------------------------------------------
  function SetCol(int, coeff0)
    local coeff
    if not coeff0 then coeff = 1 else coeff = coeff0 end
    if int and int > 0 then 
      local r, g, b = ColorFromNative( int )      
      if  GetOS():match('OSX') then 
        gfx.set(coeff*b/255,coeff*g/255,coeff*r/255) 
       else 
        gfx.set(coeff*r/255,coeff*g/255,coeff*b/255) 
      end
     else
      gfx.set(1,1,1)
    end    
  end
  ---------------------------------------------------
  function DrawBezierCurve(x_table0, y_table0)
    local x_table, y_table = {}, {}
    for i = 1, #x_table0 do
      if x_table0[i] and y_table0[i] then 
        x_table[#x_table+1] = x_table0[i]
        y_table[#y_table+1] = y_table0[i]
      end
    end
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
    ----------------------------
    local last_x_point,last_y_point,x_point,y_point
    for t = 0, 1, 0.06 do
      local t0 = t--(1+math.sin((1.5+t)*math.pi))*0.5
      x_point = bezier_eq(order, x_table, t0)+ t0^order*x_table[order]
      y_point = bezier_eq(order, y_table, t0)+ t0^order*y_table[order] 
      gfx.x = math.floor(x_point)
      gfx.y = math.floor(y_point)
      --gfx.setpixel(gfx.r,gfx.g,gfx.b)
      if last_x_point then 
        gfx.line(x_point,y_point,last_x_point,last_y_point)
      end
      last_x_point = x_point
      last_y_point = y_point
    end    
  end
  ---------------------------------------------------
  function sign_cond(a,b) if a>=b then return 1 else return -1 end end
  ---------------------------------------------------    
  function GUI_wire(t)
    SetCol(t.col, t.tint)
    if not t.obj1 or not t.obj2 then return end
    local x1 = t.obj1.x+obj.pin_side/2
    local x2 = t.obj2.x+obj.pin_side/2
    local y1 = t.obj1.y+obj.pin_side/2
    local y2 = t.obj2.y+obj.pin_side/2
    --gfx.line(x1,y1,x2, y2, 1)
    
    
    --pins
      local pins_offset = obj.pins_offset
      local x1_pin,x2_pin,y1_pin,y2_pin
      local c if x2 < x1 then c = 0.3 else c = 1 end
      x1_pin = x1+pins_offset*c
      y1_pin = y1 
      x2_pin = x2-pins_offset *c
      y2_pin = y2
      if (y2 > y1 and x2 < x1) or ( y2 < y1 and x2 < x1) then 
        y1_pin = y1- pins_offset*c
        y2_pin = y2+ pins_offset*c
      end
      
      

    --cat
    local x_cat,y_cat
    local cat= 200
    if x2-x1 > cat then 
      x_cat = x1 + (x2-x1)/2
      y_cat = y1 +  (y1-y2)/2 +20* (math.abs(x2-x1)/cat)
    end
    
    if math.abs(y2-y1) <= obj.item_h*4 and x2-x1 < obj.pins_offset*2 and x2-x1 > 0 then
      gfx.line(x1,y1,x2, y2, 1)
     else
      --x1_pin = nil
      --x_cat = nil
      --x2_pin = nil
      DrawBezierCurve({x1,
                      x1_pin,
                      x_cat,
                      x2_pin,
                      x2},
                      {y1,
                      y1_pin,
                      y_cat,
                      y2_pin,
                      y2}
                      )
    end
  end
  ---------------------------------------------------
  function RotatePoint(ax, ay, bx, by, angle)
    local x = bx + (ax-bx)*math.cos(angle)-(ax-bx)*math.sin(angle)
    local y = by + (ay-by)*math.sin(angle)-(ay-by)*math.cos(angle)
    return x,y
  end
  ---------------------------------------------------
  function GUI_But(t) 
    --  fill frame
      if t.frame_col then SetCol(t.frame_col,t.frame_fill_ratio)  end 
      gfx.a = 1
      if t.frame_fill_a then gfx.a = t.frame_fill_a   end
      gfx.rect(t.x,t.y,t.w,t.h, true)
      gfx.a = 1
      if t.frame_rect_a then 
        if t.frame_rect_col then SetCol(t.frame_rect_col) end
        gfx.a = t.frame_rect_a 
        gfx.rect(t.x,t.y,t.w,t.h, false)
      end
      
    -- txt
      if t.txt then 
        if t.txt_col then SetCol(t.txt_col)  end 
        gfx.a = 1
        if t.txt_a then gfx.a = t.txt_a end
        if t.txt and t.w > 0 then 
          local txt = tostring(t.txt)
          gfx.setfont(1, obj.font,t.fontsz)
          local y_shift = -1
          for line in txt:gmatch('[^\r\n]+') do
            if gfx.measurestr(line:sub(0,-2)) > t.w -2 and t.w > 20 then 
              repeat line = line:sub(0,-2) until gfx.measurestr(line..'...')< t.w -2
              line = line..'...'
            end
            gfx.x = t.x+ math.ceil((t.w-gfx.measurestr(line))/2)
            gfx.y = t.y+ (t.h-gfx.texth)/2 + y_shift 
            if t.aligh_txt then
              if t.aligh_txt&1==1 then gfx.x = t.x  end -- align left
              if t.aligh_txt>>2&1==1 then gfx.y = t.y + y_shift end -- align top
              if t.aligh_txt>>4&1==1 then gfx.y = t.h - gfx.texth end -- align bot
            end
            gfx.drawstr(line)
            y_shift = y_shift + gfx.texth
          end
        end
      end
  end
  --------------------------------------------------- 
  function OBJ_GenButtons_L0()
    local scroll_x = 0
    local scroll_y = 0
    
    local path = structure.path_ID
    
    if  scroll[path] then 
      scroll_x =  scroll[path][1] *obj.scroll_ratio
      scroll_y =  scroll[path][2] *obj.scroll_ratio
    end
    local h_sep = 2
    local y_shift = 30
    
    -- build tracks and pins
    local row = 0
    local col = -1   
    local frame_fill_tint = 0.9
    local frame_fill_a = 0.95
    local depth_xoffs = 10 
    for i = 1, #data do
      local txt = data[i].name
      local x_shift0 = obj.x_shift_folder
      local y_shift0 = y_shift
      if data[i].is_top_level then 
        x_shift0 = obj.x_shift_folder
        col = col + 1
        row = 0
       else 
        x_shift0 = 0
      end
      if data[i].is_top_level then y_shift0 = 0 end
      local tcol if data[i].col == 0 then tcol = 0x6E6E6E else tcol = data[i].col end
      local tr_x = scroll_x+obj.toolbar_w + obj.offs + x_shift0 + col * (obj.item_w + obj.w_sep_items)+data[i].depth_change*depth_xoffs
      local tr_y = scroll_y+obj.nav_panel_h + obj.offs + (obj.item_h+h_sep)*row+y_shift0
      local guid = data[i].guid
      if item_XYshift['tr'..i] then
        tr_x = item_XYshift['tr'..i][1]+scroll_x
        tr_y = item_XYshift['tr'..i][2]+scroll_y
      end
      obj['tr'..i] = {       clear = true,
                              x=tr_x,
                              y=tr_y,
                              w=obj.item_w,
                              h=obj.item_h,
                              txt=txt,
                              txt_a=1, 
                              txt_col=16777215,
                              frame_rect_a=0,
                              frame_fill_ratio=frame_fill_tint,
                              frame_fill_a=frame_fill_a,
                              frame_col=tcol,
                              frame_fill_col = tcol,
                              fontsz=obj.fontsz1,
                              func_onLclick = function ()
                                                local tr_id = i
                                                local tr = CSurf_TrackFromID( tr_id, true )
                                                if tr then 
                                                  SetOnlyTrackSelected( tr ) 
                                                  SetMixerScroll( tr )
                                                  CSurf_OnSelectedChange( tr, 1 )
                                                end
                                                upd_data = true                                                
                                              end,
                              func_onLDrag = function()
                                                local set_x = mouse.mx+(mouse.context_latch_xobj-mouse.mx_latch)
                                                local set_y = mouse.my+(mouse.context_latch_yobj-mouse.my_latch)
                                                item_XYshift['tr'..i] = {set_x-scroll_x,set_y-scroll_y}
                                                ExtStateProjData_Save2()
                                                obj['tr'..i].x = set_x
                                                obj['tr'..i].y = set_y
                                                obj['tr'..i..'IN'].x= set_x-obj.pin_side
                                                obj['tr'..i..'IN'].y = set_y + math.floor(obj.item_h-obj.pin_side)/2
                                                obj['tr'..i..'OUT'].x= set_x+obj.item_w
                                                obj['tr'..i..'OUT'].y= set_y + math.floor(obj.item_h-obj.pin_side)/2
                                                upd_gui = 1
                                              end,
                              func_onLDclick = function ()
                                                  structure.cur_level = 1
                                                  structure.path_ID = '1_'..i
                                                  structure.path_IDtr = i
                                                  ExtStateProjData_Save2()
                                                  upd_dyn_objects = true
                                                  upd_data = true  
                                                end
                            }
      obj['tr'..i..'IN'] = {  clear = true,
                              x= tr_x-obj.pin_side,
                              y= tr_y + math.floor(obj.item_h-obj.pin_side)/2,
                              w=obj.pin_side,
                              h=obj.pin_side,
                              frame_fill_ratio=frame_fill_tint,
                              frame_col=tcol,
                            }  
      obj['tr'..i..'OUT'] = {  clear = true,
                              x= tr_x+obj.item_w,
                              y= tr_y + math.floor(obj.item_h-obj.pin_side)/2,
                              w=obj.pin_side,
                              h=obj.pin_side,
                              frame_fill_ratio=frame_fill_tint,
                              frame_col=tcol,
                            }                                               
      row = row + 1
    end
    col = col + 1
    
    -- built master
      local master_x = scroll_x+obj.toolbar_w + obj.offs + col * (obj.item_w + obj.w_sep_items)+obj.x_shift_folder
      local master_y = scroll_y+obj.nav_panel_h + obj.offs
      if item_XYshift['tr_'..'master'] then
        master_x = item_XYshift['tr_'..'master'][1]+scroll_x
        master_y = item_XYshift['tr_'..'master'][2]+scroll_y
      end
      obj['trMASTER'] = {   clear = true,
                            x=master_x,
                            y=master_y,
                            w=obj.item_w,
                            h=obj.item_h,
                            txt="Master",
                            txt_a=1, 
                            txt_col=16777215,
                            frame_fill_a=1,
                            frame_rect_a = 0.5,
                            frame_rect_col = 255,--red
                            frame_col=0x6E6E6E,                              
                            fontsz=obj.fontsz1,
                              func_onLclick = function ()
                                                local tr = CSurf_TrackFromID( 0, true )
                                                if tr then 
                                                  SetOnlyTrackSelected( tr ) 
                                                  SetMixerScroll( tr )
                                                  CSurf_OnSelectedChange( tr, 1 )
                                                end
                                                upd_data = true                                                
                                              end,
                              func_onLDrag = function()
                                                local set_x = mouse.mx+(mouse.context_latch_xobj-mouse.mx_latch)
                                                local set_y = mouse.my+(mouse.context_latch_yobj-mouse.my_latch)
                                                item_XYshift['tr_'..'master'] = {set_x-scroll_x,set_y-scroll_y}
                                                ExtStateProjData_Save2()
                                                obj['trMASTER'].x = set_x
                                                obj['trMASTER'].y = set_y
                                                obj['trMASTER_IN'].x= set_x-obj.pin_side
                                                obj['trMASTER_IN'].y = set_y + math.floor(obj.item_h-obj.pin_side)/2
                                                upd_gui = 1
                                              end,
                              func_onLDclick = function ()
                                                  structure.cur_level = 1
                                                  structure.path_ID = '1_'..i
                                                  structure.path_IDtr = i
                                                  ExtStateProjData_Save2()
                                                  upd_dyn_objects = true
                                                  upd_data = true  
                                                end}
      obj['trMASTER_IN'] = {  clear = true,
                              x= master_x-obj.pin_side,
                              y= master_y + math.floor(obj.item_h-obj.pin_side)/2,
                              w=obj.pin_side,
                              h=obj.pin_side,
                              frame_fill_a=0,
                              frame_fill_ratio=frame_fill_tint,
                              frame_col=16777215,
                            }                
    -- build HW  
      row = 2
      for i = 1,  GetNumAudioOutputs() do
        local ch_name =  GetOutputChannelName( i-1 )
        local HWx = scroll_x+obj.toolbar_w + obj.offs + col * (obj.item_w + obj.w_sep_items)+obj.x_shift_folder
        local HWy = scroll_y+obj.nav_panel_h + obj.offs + (obj.item_h+h_sep)*row
        if item_XYshift['tr_'..'HW'..i] then
          HWx = item_XYshift['tr_'..'HW'..i][1]+scroll_x
          HWy = item_XYshift['tr_'..'HW'..i][2]+scroll_y
        end
        obj['trHW'..i] = {clear = true,
                              x=HWx,
                            y=HWy,
                            w=obj.item_w,
                            h=obj.item_h,
                            txt=ch_name,
                            txt_a=1, 
                            txt_col=16777215,
                            frame_fill_a=0.5,
                            frame_rect_a = 0.5,
                            frame_rect_col = 0xFF3214,--red
                            frame_col=16777215,                               
                            fontsz=obj.fontsz1,
                            func_onLclick = function ()
                                                
                                              end,                              
                            func_onLDrag = function()
                                                local set_x = mouse.mx+(mouse.context_latch_xobj-mouse.mx_latch)
                                                local set_y = mouse.my+(mouse.context_latch_yobj-mouse.my_latch)
                                                item_XYshift['tr_'..'HW'..i] = {set_x-scroll_x,set_y-scroll_y}
                                                ExtStateProjData_Save2()
                                                obj['trHW'..i].x = set_x
                                                obj['trHW'..i].y = set_y
                                                obj['trHWOUT_IN'..i].x= set_x-obj.pin_side
                                                obj['trHWOUT_IN'..i].y= set_y + math.floor(obj.item_h-obj.pin_side)/2
                                                upd_gui =1
                                              end                          
                          }
      obj['trHWOUT_IN'..i] ={  clear = true,
                              x= HWx-obj.pin_side,
                              y= HWy + math.floor(obj.item_h-obj.pin_side)/2,
                              w=obj.pin_side,
                              h=obj.pin_side,
                              frame_fill_a=0,
                              frame_fill_ratio=frame_fill_tint,
                              frame_col=16777215,
                            }                             
        row = row + 1      
      end
  end
  ---------------------------------------------------
  function OBJ_GenWires_L0()                          
    --build routing wires
    wires = {} --reset t
    local wire_a = 1 -- default tint
    
    
    for i = 1, #data do -- through tracks
      if not data[i].sends and #data[i].sends > 0 then goto skipnexttr end      
      for send_id = 1, #data[i].sends do
        -- reg/parent
          if data[i].sends[send_id].s_type == 'regular' or data[i].sends[send_id].s_type == 'parent' then
            local destGUID = data[i].sends[send_id].dest
            local tr = BR_GetMediaTrackByGUID( 0, destGUID )
            if ValidatePtr2(0,tr, 'MediaTrack*') then
              local tr_id = CSurf_TrackToID(tr, false )
              local col = 0xFFFFFF
              if not data[i].sends[send_id].isAudio then col = 0x3264E6 end
              wires[#wires+1] = {clear = true,
                                  obj1 = obj['tr'..i..'OUT'],
                                 obj2 = obj['tr'..tr_id..'IN'],
                                 col = col,
                                 tint = wire_a}
            end   
          end
        -- master
          if data[i].sends[send_id].s_type == 'master' then
            wires[#wires+1] = {clear = true,
                                obj1 = obj['tr'..i..'OUT'],
                                 obj2 = obj['trMASTER_IN'],
                                 col = 0x00C832,  -- green
                                 tint = wire_a}
              
          end 
        --hw
          if data[i].sends[send_id].s_type == 'HW' then
            local chan = data[i].sends[send_id].dst_chan & 511              
            if obj['trHWOUT_IN'..chan+1] then 
              wires[#wires+1] = {clear = true,
                      obj1 = obj['tr'..i..'OUT'],
                       obj2 = obj['trHWOUT_IN'..chan+1],
                       col = 0xFF3214,  -- red
                       tint = wire_a}
            end   
            if (data[i].sends[send_id].dst_chan & 1024) ~=1024  then  
              if obj['trHWOUT_IN'..chan+2] then 
                wires[#wires+1] = {clear = true,
                        obj1 = obj['tr'..i..'OUT'],
                       obj2 = obj['trHWOUT_IN'..chan+2],
                       col = 0xFF3214,  -- red
                       tint = wire_a}  
              end
            end
          end
                   
      end   
      ::skipnexttr::     
    end
      
  end    
  ---------------------------------------------------
  function OBJ_GenButtons_L1()
    local path = structure.path_ID
    local tr_id = structure.path_IDtr
    if not data[tr_id] then return end
    
    
    local scroll_x = 0
    local scroll_y = 0
    if  scroll[path] then 
          scroll_x =  scroll[path][1] *obj.scroll_ratio
          scroll_y =  scroll[path][2] *obj.scroll_ratio
    end
    local h_sep = 2
    local x_shift = 30
    local y_shift = 0
    
    -- build fx
    local row = 0
    local col = 0 
    local frame_fill_tint = 1
    local frame_fill_a = 0.8
    local tcol = 0x6E6E6E    
    
    -- inputs
      for i = 1, data[tr_id].nchan do
        local fx_x = scroll_x+obj.toolbar_w + obj.offs  + col * (obj.item_w + obj.w_sep_items)-- + x_shift
        local fx_y = scroll_y+obj.nav_panel_h + obj.offs + (obj.item_h+h_sep)*(i-1)
        if item_XYshift['tr'..tr_id..'_FXin'..i] then
          fx_x = item_XYshift['tr'..tr_id..'_FXin'..i][1]+scroll_x
          fx_y = item_XYshift['tr'..tr_id..'_FXin'..i][2]+scroll_y
        end
        obj['tr'..tr_id..'FXin'..i] = {       clear = true,
                                x=fx_x,
                                y=fx_y,
                                w=obj.item_w,
                                h=obj.item_h,
                                txt='Input '..i,
                                txt_a=1, 
                                txt_col=16777215,
                                frame_rect_a=0,
                                frame_fill_ratio=frame_fill_tint,
                                frame_fill_a=frame_fill_a,
                                frame_col=tcol,
                                fontsz=obj.fontsz1,
                                func_onLclick = function ()
                                                                                         
                                                end,
                                func_onLDrag = function()
                                                  local set_x = mouse.mx+(mouse.context_latch_xobj-mouse.mx_latch)
                                                  local set_y = mouse.my+(mouse.context_latch_yobj-mouse.my_latch)
                                                  item_XYshift['tr'..tr_id..'_FXin'..i] = {set_x-scroll_x,set_y-scroll_y}
                                                  obj['tr'..tr_id..'FXin'..i].x = set_x
                                                  obj['tr'..tr_id..'FXin'..i].y = set_y
                                                  obj['tr'..tr_id..'FXin'..i..'outpin'].x= set_x + obj.item_w
                                                  obj['tr'..tr_id..'FXin'..i..'outpin'].y= set_y + math.floor(obj.item_h-obj.pin_side)/2
                                                  ExtStateProjData_Save2()
                                                  upd_gui = 1
                                                end
                              }
        obj['tr'..tr_id..'FXin'..i..'outpin'] = {  clear = true,
                                x= fx_x + obj.item_w,
                                y= fx_y + math.floor(obj.item_h-obj.pin_side)/2,
                                w=obj.pin_side,
                                h=obj.pin_side,
                                frame_fill_ratio=frame_fill_tint,
                                frame_col=tcol,
                                frame_fill_a=frame_fill_a
                              }                              
      end
      
    -- outputs
      local col_last = #data[tr_id].fx
      for i = 1, data[tr_id].nchan do
        local fx_x = scroll_x+obj.toolbar_w + obj.offs  + col_last * (obj.item_w + obj.w_sep_items)-- + x_shift
        local fx_y = scroll_y+obj.nav_panel_h + obj.offs + (obj.item_h+h_sep)*(i-1)
        if item_XYshift['tr'..tr_id..'_FXout'..i] then
          fx_x = item_XYshift['tr'..tr_id..'_FXout'..i][1]+scroll_x
          fx_y = item_XYshift['tr'..tr_id..'_FXout'..i][2]+scroll_y
        end
        obj['tr'..tr_id..'FXout'..i] = {       clear = true,
                                x=fx_x,
                                y=fx_y,
                                w=obj.item_w,
                                h=obj.item_h,
                                txt='Output '..i,
                                txt_a=1, 
                                txt_col=16777215,
                                frame_rect_a=0,
                                frame_fill_ratio=frame_fill_tint,
                                frame_fill_a=frame_fill_a,
                                frame_col=tcol,
                                fontsz=obj.fontsz1,
                                func_onLclick = function ()
                                                                                         
                                                end,
                                func_onLDrag = function()
                                                  local set_x = mouse.mx+(mouse.context_latch_xobj-mouse.mx_latch)
                                                  local set_y = mouse.my+(mouse.context_latch_yobj-mouse.my_latch)
                                                  item_XYshift['tr'..tr_id..'_FXout'..i] = {set_x-scroll_x,set_y-scroll_y}
                                                  obj['tr'..tr_id..'FXout'..i].x=set_x
                                                  obj['tr'..tr_id..'FXout'..i].y=set_y
                                                  obj['tr'..tr_id..'FXout'..i..'inppin'].x=set_x -obj.pin_side
                                                  obj['tr'..tr_id..'FXout'..i..'inppin'].y=set_y + math.floor(obj.item_h-obj.pin_side)/2
                                                  ExtStateProjData_Save2()
                                                  upd_gui = 1
                                                end
                              }
        obj['tr'..tr_id..'FXout'..i..'inppin'] = {  clear = true,
                                x= fx_x -obj.pin_side,
                                y= fx_y + math.floor(obj.item_h-obj.pin_side)/2,
                                w=obj.pin_side,
                                h=obj.pin_side,
                                frame_fill_ratio=frame_fill_tint,
                                frame_col=tcol,
                                frame_fill_a=frame_fill_a
                              }                              
      end      
      
    -- LOOP FX --                     
      for i = 1, #data[tr_id].fx-1 do
        col = col+ 1
        local txt = data[tr_id].fx[i].FXname
        if txt:match('%:(.*)') then txt = txt:match('%:(.*)') end
        if txt:match('%/(.*)') then txt = txt:match('%/(.*)') end
        txt = txt:gsub('%(.-%)','')
        txt = i..': '..txt
        local fx_x = scroll_x+obj.toolbar_w + obj.offs  + col * (obj.item_w + obj.w_sep_items)-- + x_shift
        local fx_y = scroll_y+obj.nav_panel_h + obj.offs + (obj.item_h+h_sep)*row+y_shift
        if item_XYshift['tr'..tr_id..'_FX'..i] then
          fx_x = item_XYshift['tr'..tr_id..'_FX'..i][1]+scroll_x
          fx_y = item_XYshift['tr'..tr_id..'_FX'..i][2]+scroll_y
        end      
        local mx_cnt = math.max(data[tr_id].fx[i].outputPins_sz,data[tr_id].fx[i].inputPins_sz)
        local h = obj.item_h*mx_cnt + h_sep*(mx_cnt-1)
        obj['FX'..i] = {       clear = true,
                                x=fx_x,
                                y=fx_y,
                                w=obj.item_w,
                                h=h,
                                txt=txt,
                                txt_a=1, 
                                txt_col=16777215,
                                frame_rect_a=0,
                                frame_fill_ratio=frame_fill_tint,
                                frame_fill_a=frame_fill_a,
                                frame_col=tcol,
                                fontsz=obj.fontsz1,
                                func_onLclick = function ()
                                                                                         
                                                end,
                                func_onLDrag = function()
                                                  local set_x = mouse.mx+(mouse.context_latch_xobj-mouse.mx_latch)
                                                  local set_y = mouse.my+(mouse.context_latch_yobj-mouse.my_latch)
                                                  item_XYshift['tr'..tr_id..'_FX'..i] = {set_x-scroll_x,set_y-scroll_y}
                                                  obj['FX'..i].x=set_x
                                                  obj['FX'..i].y=set_y
                                                  for inpin = 1, data[tr_id].fx[i].inputPins_sz do
                                                    obj['FX'..i..'IN'..inpin].x= set_x-obj.pin_side
                                                    obj['FX'..i..'IN'..inpin].y= set_y + math.floor(obj.item_h-obj.pin_side)/2 + (obj.item_h +h_sep) * (inpin-1)
                                                  end
                                                  for outpin = 1, data[tr_id].fx[i].outputPins_sz do
                                                    obj['FX'..i..'OUT'..outpin].x= set_x+obj.item_w
                                                    obj['FX'..i..'OUT'..outpin].y= set_y + math.floor(obj.item_h-obj.pin_side)/2 + (obj.item_h +h_sep) * (outpin-1)
                                                  end
                                                  ExtStateProjData_Save2()
                                                  upd_gui = 1
                                                end,
                                func_onLDclick = function ()
                                                    
                                                    
                                                  end
                              } 
        for inpin = 1, data[tr_id].fx[i].inputPins_sz do
          obj['FX'..i..'IN'..inpin] = {  clear = true,
                                  x= fx_x-obj.pin_side,
                                  y= fx_y + math.floor(obj.item_h-obj.pin_side)/2 + (obj.item_h +h_sep) * (inpin-1),
                                  w=obj.pin_side,
                                  h=obj.pin_side,
                                  frame_fill_ratio=frame_fill_tint,
                                  frame_col=tcol,
                                  frame_fill_a=frame_fill_a
                                } 
        end   
        for outpin = 1, data[tr_id].fx[i].outputPins_sz do
          obj['FX'..i..'OUT'..outpin] = {  clear = true,
                                  x= fx_x+obj.item_w,
                                  y= fx_y + math.floor(obj.item_h-obj.pin_side)/2 + (obj.item_h +h_sep) * (outpin-1),
                                  w=obj.pin_side,
                                  h=obj.pin_side,
                                  frame_fill_ratio=frame_fill_tint,
                                  frame_col=tcol,
                                  frame_fill_a=frame_fill_a
                                } 
        end          
      end

    
          
  end
  
  ---------------------------------------------------
  function OBJ_GenWires_L1()                          
    local tr_id = structure.path_IDtr
    if not data[tr_id] then return end
    
    wires = {} --reset t
    local wire_a = 1 -- default tint    
    local fx_cnt = #data[tr_id].fx
    
    for ch = 1, data[tr_id].nchan do -- through channels
      for fx = fx_cnt + 1, 1,  -1 do
        local dest_t
        if fx > fx_cnt then 
          dest_t =  obj['tr'..tr_id..'FXout'..ch..'inppin']
         else
           dest_t = obj['FX'..fx..'IN'..ch]
        end
        
        
        
        if fx > 1 then
          for int_pin_id = 1, data[tr_id].fx[fx-1].outputPins_sz do
            if (data[tr_id].fx[fx-1].pins.outpins[int_pin_id] & ch) == ch then
              local src_t = obj['FX'..(fx-1)..'OUT'..int_pin_id]
              wires[#wires+1] = {clear = true,
                                obj1 = src_t,
                               obj2 = dest_t,
                               col = 0xFFFFFF,
                               tint = wire_a} 
            end
          end
        end
      end
    end
      
  end     
  ---------------------------------------------------  
  ExtState_Load() 
  gfx.init('MPL '..scr_title,conf.wind_w, conf.wind_h, conf.dock, conf.wind_x, conf.wind_y)
  OBJ_init()
  ExtStateProjData_Load2()
  run()
