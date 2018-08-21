
  names = {'kick',
            'snare',
            'hats',
            'tom',
            'oh'
          }
  
  
  function main()
    cnt = reaper.CountSelectedTracks(0)
    if cnt == 0 then return end
    t = {}
    for i = 1, cnt do
      local tr = reaper.GetSelectedTrack(0,i-1)
      local _, chunk = reaper.GetTrackStateChunk( tr, '', false )
      local _, tr_name =  reaper.GetSetMediaTrackInfo_String( tr, 'P_NAME', '', false )
      t[i] = {chunk=chunk, name = tr_name}
    end
    
    for i =1, #t do
      chk = false
      for j =1, #names do
        if t[i].name:lower():find(names[j]:lower()) then
          t[i].cnt = j
          chk = true
          break
        end
      end
     if not chk then t[i].cnt = #t end
    end
    
    table.sort  (t, function(a,b) return a.cnt<b.cnt end )
    
    for i =1, cnt do
      local tr = reaper.GetSelectedTrack(0,i-1)
      reaper.SetTrackStateChunk( tr, t[i].chunk, false )
    end
  end
  
  main()
