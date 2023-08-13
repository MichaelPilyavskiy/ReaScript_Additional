-- @description Project specific action mapping
-- @version 0.1alpha
-- @author MPL
-- @website http://forum.cockos.com/showthread.php?t=188335
-- @metapackage
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
  --------------------------------------------------------------------------------------
  function GetIdFromActionName(section, search) --https://forum.cockos.com/showpost.php?p=2383057&postcount=3
    -- / section (Main=0, see reascript help for more)
    local name, cnt, ret = '', 0, 1
    while ret > 0 do
      ret, name = reaper.kbd_enumerateActions(section, cnt, '')
      if name:match(search) then return ret end
      cnt=cnt+1 
    end 
  end 
  --------------------------------------------------------------------------------------
  function PSAM_SetMap(sectionID,cmdID)
    
    -- get target
    local ret, trGUID, trparam = PSAM_SetMap_GetParam() 
    if not ret then return end
    
    -- map control
    local destcmdID = GetIdFromActionName(sectionID, 'mpl_Project specific action mapping - control script')
    if not destcmdID then return end -- control script not found
    local dialog_ok = reaper.DoActionShortcutDialog(  reaper.GetMainHwnd(), sectionID, destcmdID, -1 ) -- assign command with control
    if not dialog_ok then return end
    
    -- assign in the control script
    local retval, desc = reaper.GetActionShortcutDesc( sectionID, destcmdID,  reaper.CountActionShortcuts( sectionID, destcmdID )-1 )
    if retval and desc then
      if control then SetProjExtState( 0, 'MPL_PSAM', desc, trGUID..'_'..trparam ) end
    end 
  end
  --------------------------------------------------------------------------------------
  function PSAM_ControlScript(contextstr)
    local desc
    if contextstr:match('osc%:(.-)%:') then desc = contextstr:match('osc%:(.-)%:') end
    if not desc then return end
    
    local ret, val = GetProjExtState( 0, 'MPL_PSAM', desc )
    if ret then reaper.ShowConsoleMsg(val) end
  end
  --------------------------------------------------------------------------------------
  function PSAM_main()
    local is_new_value,filename,sectionID,cmdID,mode,resolution,val,contextstr = reaper.get_action_context()
    if filename then 
      if filename:match('set mapping') then PSAM_SetMap(sectionID,cmdID) end
      if filename:match('control script') then PSAM_ControlScript(contextstr) end
    end
    PSAM_SetMap() -- test
  end
  
  PSAM_main()