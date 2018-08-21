

  _, _, sec, cmd = reaper.get_action_context()
  state = reaper.GetToggleCommandStateEx( sec, cmd )
  
  ----------------------------------------------
  
  function SetButtonON()
    ret, take_new_name = reaper.GetUserInputs('New Take', 1, '', 'New take')        
    if not ret then return end
    
    reaper.SetProjExtState(0, 'mpl_RecTtake', 'name', take_new_name)
    
    -- take_new_name
    reaper.SetToggleCommandState( sec, cmd, 1 ) -- Set ON
    reaper.RefreshToolbar2( sec, cmd )
    reaper.Main_OnCommand(1013,0) -- transport: record
  end
  
  ----------------------------------------------
    
  function SetButtonOFF()
    
    _, take_new_name = reaper.GetProjExtState(0, 'mpl_RecTtake', 'name')
    reaper.SetProjExtState(0, 'mpl_RecTtake', 'name', '')
        
        
    reaper.SetToggleCommandState( sec, cmd, 0 ) -- Set OFF
    reaper.RefreshToolbar2( sec, cmd )
    reaper.Main_OnCommand(40667,0) -- transpo rt: stop save all rec media
    item = reaper.GetSelectedMediaItem(0,0)
    if item == nil then return end
    take = reaper.GetActiveTake(item)
    
    reaper.Main_OnCommand(reaper.NamedCommandLookup('_BR_TOGGLE_ITEM_ONLINE'),0) -- put offline
    src = reaper.GetMediaItemTake_Source(take)
    filename = reaper.GetMediaSourceFileName(src, '')
    local OS = reaper.GetOS()
    if OS:find('Win') ~= nil then slash = '\\' else slash = '/' end
    filename_ext = filename:sub(-filename:reverse():find('%.'))
    filename_new = filename:sub(0, -filename:reverse():find(slash))..take_new_name..filename_ext
    os.rename(filename, filename_new)
    reaper.BR_SetTakeSourceFromFile2(take, filename_new, true, true)
    reaper.UpdateItemInProject(item)
    reaper.GetSetMediaItemTakeInfo_String(take, 'P_NAME', take_new_name, true)
    reaper.Main_OnCommand(40439,0) -- put online
    reaper.UpdateArrange()
    
  end  
  
  ----------------------------------------------
  
  function msg(s) reaper.ShowConsoleMsg(s) end
  
  ----------------------------------------------
      
  if state <= 0 then -- start
    reaper.Undo_BeginBlock()
    SetButtonON() 
    reaper.Undo_EndBlock('Start take record', 0)   
  end
  
  if state == 1 then -- end
    reaper.Undo_BeginBlock()
    SetButtonOFF() 
    reaper.Undo_EndBlock('End take record', 0)   
  end
    
