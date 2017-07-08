
-- convert hh:mm:ss:ms timecode to project markers  

  function main()    
    local retval, path = reaper.GetUserFileNameForRead('', 'TimeCode file', '.txt' )
    if not retval then return end
    file = io.open(path)
    if file then context = file:read('a') file:close() else return end 
    
    local t = {} for line in context:gmatch('[^\r\n]+') do t[#t+1] = line end
    for i = 1, #t do
      local str = t[i]
      if str:match('%d%d%:%d%d%:%d%d%:%d%d') then 
        local h,m,s,ms = str:match("(%d+):(%d+):(%d+):(%d+)")
        if ms and h and m and s then 
          timepos = tonumber(ms/100+s+m*60+h*3600)
          if timepos then reaper.AddProjectMarker( 0, false, timepos, 0, '', -1 )  end
        end
      end  
    end
    
  end
  main()
