for key in pairs(reaper) do _G[key]=reaper[key]  end 
  
  function main()
    for trid = 1, CountTracks(0) do
      tr = GetTrack(0,trid-1)
      retval, ra_list = reaper.GetSetMediaTrackInfo_String( tr, 'P_RAZOREDITS', '', false )
      local RA={}
      local t = {}
      for val in ra_list:gmatch('[^%s]+') do t[#t+1] = val end
      for i=1, #t,3 do if t[i+2] == '""' then RA[#RA+1]={pos_st=tonumber(t[i]),pos_end=tonumber(t[i+1])} end end
      
      for itemidx = 1,  CountTrackMediaItems( tr )  do
        local item = GetTrackMediaItem( tr, itemidx-1 )
        local itpos_st = GetMediaItemInfo_Value( item, 'D_POSITION' )
        local itpos_end = GetMediaItemInfo_Value( item, 'D_LENGTH' )
        itpos_end = itpos_end + itpos_st
        for RA_id=1,#RA do
          if itpos_st <= RA[RA_id].pos_st and itpos_end > RA[RA_id].pos_st and itpos_end < RA[RA_id].pos_end then 
            SetMediaItemInfo_Value( item, 'D_FADEOUTLEN',itpos_end- RA[RA_id].pos_st )
          end
          if itpos_st >= RA[RA_id].pos_st and itpos_st < RA[RA_id].pos_end then 
            SetMediaItemInfo_Value( item, 'D_FADEINLEN', RA[RA_id].pos_end - itpos_st )
          end
        end
      end
    end
      
  end
  
  main()
