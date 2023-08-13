-- @description Project specific action mapping
-- @version 0.2alpha
-- @author MPL
-- @website http://forum.cockos.com/showthread.php?t=188335
-- @metapackage
-- @about Script for mapping track controls
-- @provides
--    [main] . > mpl_Project specific action mapping - set mapping.lua
--    [main] . > mpl_Project specific action mapping - control script.lua
-- @changelog
--    + init

  -- [[debug search filter: NOT function NOT reaper NOT gfx NOT VF]]
  
  
  --------------------------------------------------------------------------------------
  function PSAM_SetMap_GetParam_PrintState()
    local data = {}
    for i = 1, reaper.CountTracks(0) do
      local tr = reaper.GetTrack(0,i-1)
      local trGUID = reaper.GetTrackGUID( tr )
      data[trGUID] = {}
      
      -- track params 
      data[trGUID].vol = reaper.GetMediaTrackInfo_Value( tr, 'D_VOL' )
      
      -- send params 
      
      -- fx control
      
      
    end
    return data
  end
  --------------------------------------------------------------------------------------
  function PSAM_ControlScript_Parse(param,mode,resolution,valIn,tr,extparams)
    -- set track params
    if param =='vol' then
      if mode == 0 then
        local out =  reaper.SLIDER2DB(1000 * valIn / resolution)
        --reaper.SetMediaTrackInfo_Value( tr, 'D_VOL', WDL_DB2VAL(out))
        reaper.SetTrackUIVolume( tr, WDL_DB2VAL(out), false, false, 0 )
      end
    end
    
    
  end
  --------------------------------------------------------------------------------------
  function PSAM_SetMap_GetParam()
    -- get project data before and after change
      local data_cur = PSAM_SetMap_GetParam_PrintState()
      reaper.PreventUIRefresh( -1 )
      reaper.Undo_DoUndo2( 0 )
      local data_init = PSAM_SetMap_GetParam_PrintState()
      reaper.Undo_DoRedo2( 0 )
      reaper.PreventUIRefresh( 1 )
      
    -- compare
      for trGUID in pairs(data_cur) do
        if data_init[trGUID] then
          for trparam in pairs(data_cur[trGUID]) do
            if data_cur[trGUID][trparam] ~= data_init[trGUID][trparam] then
              return true, trGUID, trparam
            end
          end
        end
      end
      
  end
  ------------------------------------------------------------------------------------------------------
  function literalize(str) -- http://stackoverflow.com/questions/1745448/lua-plain-string-gsub
     if str then  return str:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", function(c) return "%" .. c end) end
  end  
  --------------------------------------------------------------------------------------
  function GetIdFromActionName(section, search) --https://forum.cockos.com/showpost.php?p=2383057&postcount=3
    -- / section (Main=0, see reascript help for more)
    local name, cnt, ret = '', 0, 1
    while ret > 0 do
      ret, name = reaper.kbd_enumerateActions(section, cnt, '')
      if name:match(literalize(search)) then return ret end
      cnt=cnt+1 
    end 
  end 
  --------------------------------------------------------------------------------------
  function PSAM_SetMap_GetJustAssignedShortcut(sectionID,destcmdID)
  
    --[[ store shortcuts
    local shortcuts = {}
    local shc_count = reaper.CountActionShortcuts( sectionID, destcmdID )
    for i = 1, shc_count do
      local retval, desc = reaper.GetActionShortcutDesc( sectionID, destcmdID, i-1 )
      shortcuts[#shortcuts+1] = desc
    end
    
    -- clear shortcuts
    for i = shc_count,1,-1 do reaper.DeleteActionShortcut( section, cmdID, i-1 ) end
    
    -- add shortcut / get desc 
    local dialog_ok = reaper.DoActionShortcutDialog(  reaper.GetMainHwnd(), sectionID, destcmdID, -1 ) -- assign command with control
    if not dialog_ok then return end
    local retval, desc = reaper.GetActionShortcutDesc( sectionID, destcmdID, 0 )
    
    -- restore shortcuts
    for i = 1, shc_count do reaper.[setshortcut]( section, cmdID, i-1, shortcuts[i] ) end
    return desc]]
    
    local dialog_ok = reaper.DoActionShortcutDialog(  reaper.GetMainHwnd(), sectionID, destcmdID, -1 ) -- assign command with control
    if not dialog_ok then return end
    local retval, desc = reaper.GetActionShortcutDesc( sectionID, destcmdID,  reaper.CountActionShortcuts( sectionID, destcmdID )-1 )
    return desc
  end
  --------------------------------------------------------------------------------------
  function PSAM_SetMap(sectionID,cmdID)
    
    -- get target
     ret, trGUID, trparam = PSAM_SetMap_GetParam() 
    if not ret then return end
    
    -- map control
    local destcmdID = GetIdFromActionName(sectionID, 'mpl_Project specific action mapping - control script')
    if not destcmdID then return end -- control script not found
    
    local desc = PSAM_SetMap_GetJustAssignedShortcut(sectionID,destcmdID,destcmdID)
    
    local extparams = '0'
    if desc then reaper.SetProjExtState( 0, 'MPL_PSAM', desc, trGUID..'_'..trparam..'_'..extparams ) end 
  end
  --------------------------------------------------------------------------------------
  function PSAM_ControlScript(contextstr,mode,resolution,valIn)
    local desc
    if contextstr:match('osc%:(.-)%:') then desc = contextstr:match('osc%:(.-)%:') end
    if not desc then return end 
    local ret, val = reaper.GetProjExtState( 0, 'MPL_PSAM', desc )
    if not ret then return end 
    local GUID, param, extparams = val:match('(%{.-%})_(.-)_(.*)') 
    if not (GUID and param and extparams) then return end
    local tr = track_from_guid_str(0,GUID)
    if not tr then return end
    
    PSAM_ControlScript_Parse(param,mode,resolution,valIn,tr,extparams)
  end
  --------------------------------------------------------------------------------------
  function PSAM_main()
    local is_new_value,filename,sectionID,cmdID,mode,resolution,val,contextstr = reaper.get_action_context()
    if filename then 
      if filename:match('set mapping') then PSAM_SetMap(sectionID,cmdID) end
      if filename:match('control script') and is_new_value then PSAM_ControlScript(contextstr,mode,resolution,val) end
    end
  end
  --------------------------------------------------------------------------------------
  function WDL_DB2VAL(x) return math.exp((x)*0.11512925464970228420089957273422) end  --https://github.com/majek/wdl/blob/master/WDL/db2val.h
  --------------------------------------------------------------------------------------
  local track_guid_cache = {}; --https://forum.cockos.com/showpost.php?p=2132505&postcount=1
  function track_from_guid_str(proj, g)
    local c = track_guid_cache[g];
    if c ~= nil and reaper.GetTrack(proj,c.idx) == c.ptr then
      -- cached!
      return c.ptr;
    end
    
    -- find guid in project
    local x = 0
    while true do
      local t = reaper.GetTrack(proj,x)
      if t == nil then
        -- not found in project, remove from cache and return error
        if c ~= nil then track_guid_cache[g] = nil end
        return nil
      end
      if g == reaper.GetTrackGUID(t) then
        -- found, add to cache
        track_guid_cache[g] = { idx = x, ptr = t }
        return t
      end
      x = x + 1
    end
  end
    --------------------------------------------------------------------------------------
  reaper.defer(PSAM_main())