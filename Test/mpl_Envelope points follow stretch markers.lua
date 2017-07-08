
function msg(s) reaper.ShowConsoleMsg(s..'\n') end
---------------------------------------------------------
function Str_Envelope (p1, p2_0, p2, p3)
  if p1 and p2_0 and p2 and p3 then
    --[[msg(p1)
    msg(p2_0)
    msg(p2)
    msg(p3)
    msg('\n')]]
    envelope =  reaper.GetTrackEnvelopeByName( track, 'Volume' )
    if not envelope then return end
    for i =1 , reaper.CountEnvelopePoints( envelope ) do
      _, time, value, shape, tension, selected = reaper.GetEnvelopePoint( envelope, i-1 )
      if time > p1 and time < math.max(p2, p2_0) then
       -- msg(time)
        old_diff = p2_0 - p1
        new_diff = p2 - p1
        diff = new_diff / old_diff
        new_time = p1 + (time-p1)*diff
        reaper.SetEnvelopePoint( envelope, 
          i-1 , new_time, value, shape, tension, selected, true )
       elseif time > math.min(p2, p2_0) and time < p3  then
        --msg(time)
        old_diff = p3 - p2_0
        new_diff = p3 - p2
        diff = new_diff / old_diff
        new_time = p3 - (p3-time)*diff
        reaper.SetEnvelopePoint( envelope, 
          i-1 , new_time, value, shape, tension, selected, true )        
      end
    end
    reaper.Envelope_SortPoints( envelope )
  end
  
end
---------------------------------------------------------
function run()
  -- store current values
    com_pos_sum = 0
    t = {}
    for i = 1,  reaper.GetTakeNumStretchMarkers( take ) do
      _, pos = reaper.GetTakeStretchMarker( take, i-1 )
      t[i] = pos
      com_pos_sum = com_pos_sum + pos
    end
  
  --  check for changes
    if last_com_pos_sum and last_com_pos_sum ~= com_pos_sum then
      -- do compare tables
        if last_t then
          for i = 2, #t do
            if t[i] ~= last_t[i] then
              
              if t[i] > 0 then 
                fin_point = t[i]
                fin_point0 = last_t[i]
                prev_point = t[i-1]
                next_point = t[i+1]
                --[[msg(fin_point0)
                msg(prev_point)
                msg(fin_point)
                msg('\n')]]
                
                Str_Envelope(prev_point,fin_point0,fin_point, next_point)
              end
            end
          end
        end
    end
  
  
  last_t = {} for i = 1, #t do last_t[i] = t[i] end
  last_com_pos_sum = com_pos_sum
  reaper.defer(run)
end
---------------------------------------------------------
  EP = {}
item = reaper.GetMediaItem(0,0)
track =  reaper.GetMediaItem_Track( item )
if item then 
  item_pos = reaper.GetMediaItemInfo_Value( item, 'D_POSITION' )
  take = reaper.GetActiveTake(item)
  if take then
    run()
  end
end

