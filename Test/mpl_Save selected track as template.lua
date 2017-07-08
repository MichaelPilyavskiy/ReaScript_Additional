
  
  function msg(s) reaper.ShowConsoleMsg(s..'\n') end
  
  -- create database if not exists
    res_path = reaper.GetResourcePath()
    database_file = res_path..'/mpl ResourceManager database.ini'
    file = io.open(database_file,"r")
    if file == nil then file = io.open(database_file,"w") file:write('') end
    file:close() 
  
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
                     
