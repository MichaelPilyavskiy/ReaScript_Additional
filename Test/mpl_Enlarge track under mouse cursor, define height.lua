


  function EnlargeSelTrack()
    cur_track = reaper.BR_TrackAtMouseCursor()
    if cur_track then 
      for i = 1, reaper.CountTracks(0) do
        local tr = reaper.GetTrack(0,i-1) 
        if tr ~= cur_track then
          reaper.SetMediaTrackInfo_Value(tr, "I_HEIGHTOVERRIDE", 10) 
         else
          reaper.SetMediaTrackInfo_Value(tr, "I_HEIGHTOVERRIDE", 150) 
        end
      end
      reaper.TrackList_AdjustWindows( false )
      reaper.UpdateArrange()
    end
    reaper.runloop(EnlargeSelTrack)
  end
  
  EnlargeSelTrack()
