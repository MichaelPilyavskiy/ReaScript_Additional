-- @description test_Swap source of selected takes
-- @version 1.0
-- @author MPL
-- @website http://forum.cockos.com/member.php?u=70694
-- @changelog
--    + test

  sel_item = reaper.GetSelectedMediaItem(0,0)
  if sel_item ~= nil then take1 = reaper.GetActiveTake(sel_item) end  
  sel_item1 = reaper.GetSelectedMediaItem(0,1)
  if sel_item1 ~= nil then take2 = reaper.GetActiveTake(sel_item1) end
  
  if take1 ~= nil and take2 ~= nil then
    src1 = reaper.GetMediaItemTake_Source(take1)
    src2 = reaper.GetMediaItemTake_Source(take2)
    
    reaper.SetMediaItemTake_Source(take1, src2)
    reaper.SetMediaItemTake_Source(take2, src1)
    
    reaper.Main_OnCommand(40048, 0)
    reaper.UpdateArrange()
  end
