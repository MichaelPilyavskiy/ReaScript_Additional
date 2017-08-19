  --MPL Test convert stereo pan envelope to dual pan envelope for selected tracks
  
  local buf = 2^12 -- samples
  for key in pairs(reaper) do _G[key]=reaper[key]  end 
    
 ---------------------------------------------------------------   
  function MakeVisible(env)
    retval, strNeedBig = GetEnvelopeStateChunk( env, '', false )
    strNeedBig = strNeedBig:gsub('VIS 0 ', 'VIS 1 ')
    strNeedBig = strNeedBig:gsub('ACT 0', 'ACT 1')
    strNeedBig = strNeedBig:gsub('ARM 0', 'ARM 1')
    reaper.SetEnvelopeStateChunk( env, strNeedBig, false )
  end
  ---------------------------------------------------------------
  function main()
    pr_len =  GetProjectLength( 0 )
    local tr = GetSelectedTrack(0,0)
    if not tr then return end
    local panmode = GetMediaTrackInfo_Value( tr, 'I_PANMODE' )
    if panmode ~= 5 then return end -- check if stereo pan  
    -- get timing data
      local SR = 1 / reaper.parse_timestr_len( 1, 0, 4 )
      local step = buf / SR  
    -- get env pointers
      local env_pan  = GetTrackEnvelopeByChunkName( tr, '<PANENV2' ) -- get pan env
      local env_w  = GetTrackEnvelopeByChunkName( tr, '<WIDTHENV2' ) -- width    
      local env_l  = GetTrackEnvelopeByChunkName( tr, '<DUALPANENVL2' )
      local env_r  = GetTrackEnvelopeByChunkName( tr, '<DUALPANENV2' )
    -- clear dest envelopes    
      DeleteEnvelopePointRange( env_l, 0, pr_len )
      DeleteEnvelopePointRange( env_r, 0, pr_len )
    -- convert points
      for p_time = 0, pr_len, step  do
         _, p_value= Envelope_Evaluate( env_pan, p_time, SR, buf )
         _, w_val= Envelope_Evaluate( env_w, p_time, SR, buf )
        InsertEnvelopePoint( env_l, p_time, p_value*w_val, 0, 0, 0, true )
        InsertEnvelopePoint( env_r, p_time, p_value*w_val, 0, 0, 0, true )
      end
    -- sort stuff
      Envelope_SortPoints( env_l )
      Envelope_SortPoints( env_r )
      MakeVisible(env_l)
      MakeVisible(env_r)
      SetMediaTrackInfo_Value( tr, 'I_PANMODE', 6 )
      UpdateArrange()
  end
  
  ClearConsole()
  Undo_BeginBlock2( 0 )
  main()
  Undo_EndBlock2( 0, 'Test convert stereo pan envelope to dual pan', '0' )
