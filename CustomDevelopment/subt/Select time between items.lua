matchsub = 'RUS'
  
  for key in pairs(reaper) do _G[key]=reaper[key]  end 
  ------------------------------------------------------------------------
  function collectitemedges()
    local t = {}
    for i=1, CountMediaItems(0) do
      local it = GetMediaItem(0,i-1)
      local pos=  GetMediaItemInfo_Value( it, 'D_POSITION' )
      local len = GetMediaItemInfo_Value( it, 'D_LENGTH' )
      local tr = reaper.GetMediaItem_Track( it )
      local retval, trname = reaper.GetTrackName( tr )
      if not trname:lower():match(matchsub:lower()) then 
        local retval, GUID = GetSetMediaItemInfo_String( it, 'GUID', '', false )
        t[GUID] = { p_st=pos, p_end=pos+len }
      end
    end
    return t
  end
------------------------------------------------------------------------
  function findnearestedges(t) 
    local diff
    local curpos =  GetCursorPosition()
    local tsst_diff = math.huge
    local tsend_diff = math.huge
    for GUID in pairs(t) do
    
      local pos = t[GUID].p_st
      local posend = t[GUID].p_end
      
      if pos < curpos then
        diff = curpos - pos
        if diff < tsst_diff then tsst = pos end
        tsst_diff=math.min(tsst_diff,diff)
      end
      if posend < curpos then
        diff = curpos - posend
        if diff < tsst_diff then tsst = posend end
        tsst_diff=math.min(tsst_diff,diff)
      end      
      
      if pos > curpos then
        diff = pos - curpos
        if diff < tsend_diff then tsend = pos end
        tsend_diff=math.min(tsend_diff,diff)
      end
      if posend > curpos then
        diff = posend - curpos
        if diff < tsend_diff then tsend = posend end
        tsend_diff=math.min(tsend_diff,diff)
      end   
      
    end
    
    return tsst,tsend
  end
------------------------------------------------------------------------
  function main()
    if CountSelectedMediaItems(0) == 1 then 
      local it = GetSelectedMediaItem(0,0)
      local pos=  GetMediaItemInfo_Value( it, 'D_POSITION' )
      local len = GetMediaItemInfo_Value( it, 'D_LENGTH' )
      GetSet_LoopTimeRange2( 0, true, true, pos,pos+len, false )
      return
    end
    local t = collectitemedges()
    tsst,tsend = findnearestedges(t)
    GetSet_LoopTimeRange2( 0, true, true, tsst,tsend, false )
  end
  
  main()
