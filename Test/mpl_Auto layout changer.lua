

  
  tcp_default = 'aa - Standart'
  mcp_default = 'aa - Standart'
  
  tcp_armed = 'bd --- Small Full Meter + value readouts'
  mcp_armed = 'bc --- Small Full Meter'

  tcp_folder = 'db --- Minimal'
  mcp_folder = 'ea - Strip'  
  
  tcp_midi_item = 'cc --- Large Media'
  mcp_midi_item = 'ba - Small'
  
  tcp_send = 'ag --- Standart Compact'
  -- mcp_send = 'blablabla'
  
  function run()
    
    function apply_layout(track, context, layout, actions)
      if context ~= nil and layout ~= nil then
        if context == 'tcp' then context = 'P_TCP_LAYOUT' end
        if context == 'mcp' then context = 'P_MCP_LAYOUT' end
        _,_ = reaper.GetSetMediaTrackInfo_String(track, context, layout, true)
      end    
    end
    
    function set_from_param(track, param, op_name)
      if reaper.GetMediaTrackInfo_Value(track, param) == 1 then
        apply_layout(track, 'tcp', _G['tcp_'..op_name])
        apply_layout(track, 'mcp', _G['mcp_'..op_name])               
      end    
    end
    
    --[[_, _, _ = reaper.BR_GetMouseCursorContext()
    track = reaper.BR_GetMouseCursorContext_Track()]]
    
    c_tracks = reaper.CountTracks(0)
    if c_tracks > 0 then
      for i = 1, c_tracks do
        track = reaper.GetTrack(0, i-1)
        if track ~= nil then
        --if last_track == nil or last_track ~= track then
          -- default          
            apply_layout(track, 'tcp', tcp_default)
            apply_layout(track, 'mcp', mcp_default)
          -- first item is midi  
            item = reaper.GetTrackMediaItem(track, 0)
            if item ~= nil then
              take = reaper.GetActiveTake(item)
              if take ~= nil then
                if reaper.TakeIsMIDI(take) then 
                  apply_layout(track, 'tcp', tcp_midi_item)
                  apply_layout(track, 'mcp', mcp_midi_item)
                end
              end
            end
          -- record arm
            set_from_param(track,'I_RECARM','armed')
            set_from_param(track,'I_FOLDERDEPTH','folder')   
            
            
          -- aux folder children
            fold_depth = reaper.GetMediaTrackInfo_Value(track, 'I_FOLDERDEPTH')
            if fold_depth <= 0 then
              tr_id = reaper.CSurf_TrackToID(track, false)
              for k = tr_id, 1, -1 do
                track_2 = reaper.GetTrack(0, k-1)
                if track_2 ~= nil then
                  fold_depth2 = reaper.GetMediaTrackInfo_Value(track_2, 'I_FOLDERDEPTH')
                  if fold_depth2 == 1 then
                    _, tr_name =  reaper.GetSetMediaTrackInfo_String(track_2, 'P_NAME', '', false)
                    if tr_name:lower():find('aux') ~= nil then 
                      apply_layout(track, 'tcp', tcp_send)
                      apply_layout(track, 'mcp', mcp_send)
                      break
                    end
                  end
                end
              end
            end
          end
        end
      end
      
        --[[  
      end
      last_track = track
    end
    reaper.defer(run)]]
  end
  
  --reaper.atexit()
  run()
