-- @description test_Swap source of selected take and take under mouse
-- @version 1.0
-- @author MPL
-- @website http://forum.cockos.com/member.php?u=70694
-- @changelog
--    + test

  reaper.BR_GetMouseCursorContext()
  take1 = reaper.BR_GetMouseCursorContext_Take()
  
  sel_item = reaper.GetSelectedMediaItem(0,0)
  if sel_item ~= nil then take2 = reaper.GetActiveTake(sel_item) end
  
  if take1 ~= nil and take2 ~= nil then
    src1 = reaper.GetMediaItemTake_Source(take1)
    src2 = reaper.GetMediaItemTake_Source(take2)
    
    reaper.SetMediaItemTake_Source(take1, src2)
    reaper.SetMediaItemTake_Source(take2, src1)
    
    reaper.Main_OnCommand(40048, 0)
    reaper.UpdateArrange()
  end
