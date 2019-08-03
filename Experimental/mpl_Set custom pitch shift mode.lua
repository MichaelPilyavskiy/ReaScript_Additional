function literalize(str) return str end  

function MPL_SetTimeShiftPitchChange(item, pshift_mode0, timestr_mode0)
  if not item then return end
  local retval, str = reaper.GetItemStateChunk( item, '', false ) 
  local timestr_mode = tonumber(str:match('PLAYRATE [%d%-%.]+ [%d%-%.]+ [%d%-%.]+ [%d%-%.]+ ([%d%-%.]+)'))
  local timestr_mode_len = string.len(tonumber(timestr_mode))
  local timestr_mode_replace = str:match('(PLAYRATE [%d%-%.]+ [%d%-%.]+ [%d%-%.]+ [%d%-%.]+ [%d%-%.]+)') 
  local pshift_mode = tonumber(str:match('PLAYRATE [%d%-%.]+ [%d%-%.]+ [%d%-%.]+ ([%d%-%.]+)'))
  local pshift_mode_len = string.len(tonumber(pshift_mode))
  local pshift_mode_replace = str:match('(PLAYRATE [%d%-%.]+ [%d%-%.]+ [%d%-%.]+ [%d%-%.]+)') 
  if pshift_mode0 then pshift_mode= pshift_mode0 end
  if timestr_mode0 then timestr_mode = timestr_mode0 end 
  str =str:gsub(timestr_mode_replace:gsub("[%.%+%-]", function(c) return "%" .. c end), timestr_mode_replace:sub(0,-timestr_mode_len-1)..timestr_mode)
  str =str:gsub(pshift_mode_replace:gsub("[%.%+%-]", function(c) return "%" .. c end), pshift_mode_replace:sub(0,-pshift_mode_len-1)..pshift_mode)
  reaper.SetItemStateChunk( item, str, false )
end

------------------------------------------------------------------------------
  item = reaper.GetSelectedMediaItem(0,0)
  pshift_mode =   (6<<16) -- elastique 2.2.8 pro (val = 6 )
                  + (1<<4) -- syncronized (val = 1 )
  timestr_mode = 3 -- transient optimized (val = 3 )
  MPL_SetTimeShiftPitchChange(item, pshift_mode, timestr_mode)
  reaper.UpdateArrange()
  
