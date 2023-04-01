-- @description RS5k_manager_control_functions
-- @author MPL
-- @website http://forum.cockos.com/member.php?u=70694
-- @version 1.05
-- @changelog
--    + current RS5k manager note note

  -----------------------------------------------------------------------   
  function SetGlobalParam(val, param, incr)
    local ret1, mode = reaper.GetProjExtState( 0, 'MPLRS5KMANAGEFUNC', 'MODE' )
    if ret1 == 1 then
      if tonumber(mode) == 0 then -- rs5k manager
        SetGlobalParam_RS5k(val, param, incr)
       elseif  tonumber(mode)== 1 then 
         local retval, tracknumber, fxnumber, paramnumber = reaper.GetLastTouchedFX()
         local tr =  CSurf_TrackFromID( tracknumber, false )
        SetGlobalParam_sub(tr, param, val, incr, fxnumber)  
       elseif  tonumber(mode)== 2 then -- selected track
        local tr = GetSelectedTrack( 0, 0 )
        SetGlobalParam_sub(tr, param, val, incr) 
       elseif  tonumber(mode)== 3 then -- focused fx
        local retval, tracknumber, itemnumber, fxnumber = reaper.GetFocusedFX()
         local tr =  CSurf_TrackFromID( tracknumber, false )
        SetGlobalParam_sub(tr, param, val, incr, fxnumber)  
       elseif  tonumber(mode)== 4 then -- current rs5k man
        local ret, note = GetProjExtState( 0, 'MPLRS5KMANAGEFUNC', 'LASTNOTERS5KMAN')
        if ret then
          note = tonumber(note)
          if note >= 0 and note <= 127 then
            SetGlobalParam_RS5k(val, param, incr, note)   
          end
        end      
      end
     else
      SetGlobalParam_RS5k(val, param, incr)
    end
    
    
  end
  --------------------------------------------------------
  function SetGlobalParam_RS5k(val, param, incr, note)
    local tr 
    local haspintrack = reaper.GetExtState('MPL_RS5K manager', 'pintrack')
    if not haspintrack or not tonumber(haspintrack) then return end
    if  tonumber(haspintrack) == 1 then 
      local ret, trGUID = reaper.GetProjExtState( 0, 'MPLRS5KMANAGE', 'PINNEDTR' )
      tr = reaper.BR_GetMediaTrackByGUID( 0, trGUID )
      if not tr  then return end
     else
      tr = reaper.GetSelectedTrack(0,0)
    end
      
    if not tr then return end
    SetGlobalParam_sub(tr, param, val, incr, _, note) 
      
    for sid = 1,  reaper.GetTrackNumSends( tr, 0 ) do
      local srcchan = reaper.GetTrackSendInfo_Value( tr, 0, sid-1, 'I_SRCCHAN' )
      local dstchan = reaper.GetTrackSendInfo_Value( tr, 0, sid-1, 'I_DSTCHAN' )
      local midiflags = reaper.GetTrackSendInfo_Value( tr, 0, sid-1, 'I_MIDIFLAGS' )
      if srcchan == -1 and dstchan ==0 and midiflags == 0 then
        local desttr = reaper.BR_GetMediaTrackSendInfo_Track( tr, 0, sid-1, 1 )
        SetGlobalParam_sub(desttr, param, val, incr, _, note)
      end
    end 
  end  
  --------------------------------------------------------
  function SetGlobalParam_sub(tr, param, val, incr, fxnumber, note)  
    if not tr then return end 
    for fxid = 1,  reaper.TrackFX_GetCount( tr ) do
      if (fxnumber and fxid-1 == fxnumber) or not fxnumber then
        -- validate RS5k by param names
          local retval, p3 = reaper.TrackFX_GetParamName( tr, fxid-1, 3, '' )
          local retval, p4 = reaper.TrackFX_GetParamName( tr, fxid-1, 4, '' )
          local isRS5k = retval and p3:match('range')~= nil and p4:match('range')~= nil
          if not isRS5k then goto skipFX end
        
        local MIDIpitch = math.floor(reaper.TrackFX_GetParamNormalized( tr, fxid-1, 3)*128)
        if not note or (note and note == MIDIpitch) then
        
          if val then 
            reaper.TrackFX_SetParamNormalized( tr, fxid-1, param, val)
           elseif incr then
            local val = reaper.TrackFX_GetParamNormalized( tr, fxid-1, param) 
            --reaper.ShowConsoleMsg((val )..'\n')
            if param == 9 or param == 10 then
              reaper.TrackFX_SetParamNormalized( tr, fxid-1, param, math.max(0,math.min(1,val + incr/2000)) )
             elseif param == 1 then
              reaper.TrackFX_SetParamNormalized( tr, fxid-1, param, math.max(0,math.min(1,val + incr)) )
             elseif param == 15 then
              reaper.TrackFX_SetParamNormalized( tr, fxid-1, param, math.max(0,math.min(1,val + incr/160)) )
             elseif param == 22 then
              reaper.TrackFX_SetParamNormalized( tr, fxid-1, param, math.max(0,math.min(1,val + incr/1000)) )
             elseif param == 13 then
              local end_val = reaper.TrackFX_GetParamNormalized( tr, fxid-1, 14 ) -0.001
              reaper.TrackFX_SetParamNormalized( tr, fxid-1, param, math.max(0,math.min(end_val,val + incr)) )
             elseif param == 14 then
              local st_val = reaper.TrackFX_GetParamNormalized( tr, fxid-1, 13 ) +0.001
              reaper.TrackFX_SetParamNormalized( tr, fxid-1, param, math.max(st_val,math.min(1,val + incr)) ) 
             elseif param == 17 or param == 18 then -- velocity max
              local val = reaper.TrackFX_GetParamNormalized( tr, fxid-1, param ) 
              reaper.TrackFX_SetParamNormalized( tr, fxid-1, param, math.max(0,math.min(1,val + incr/127)) )  
             elseif param == 23 then -- loop offs
              reaper.TrackFX_SetParamNormalized( tr, fxid-1, param, math.max(0,math.min(1,val + incr/30000)) )                   
             elseif param == 24 then
              reaper.TrackFX_SetParamNormalized( tr, fxid-1, param, math.max(0,math.min(1,val + incr/14990)) )                   
             elseif param == 25 then -- sustain
              reaper.TrackFX_SetParamNormalized( tr, fxid-1, param, math.max(0,math.min(1,val + incr)) )                 
              
             elseif param == 26 then
              reaper.TrackFX_SetParamNormalized( tr, fxid-1, param, math.max(0,math.min(1,val + incr/4000)) )                   
              
            end
          end
        end
          
        ::skipFX::
      end
    end 
  end
