-- @description Generate clock reset for last touched VCVRack bridge CC
-- @version 1.01
-- @author MPL
-- @website https://forum.cockos.com/showthread.php?t=188335
-- @noindex
-- @changelog
--   #header


  local vrs = 'v1.0'
  --NOT gfx NOT reaper
 --------------------------------------------------------------------
  function main()
    
    
    
      local TS_start, TS_end = GetSet_LoopTimeRange2( 0, false, false, 0, 0, false )
      if math.abs(TS_start-TS_end) < 0.2 then 
        reaper.MB('Define timeselection first', '', 0)
        return 
      end
      measurestep = 1
      local ret, str = GetUserInputs('Measure step', 1, 'Reset Every X measure (0.5-8)',measurestep)
      if ret and str and tonumber(str) then 
        measurestep = tonumber(str)
        if not (measurestep >=1 and measurestep < 8) then return end
        measurestep = math.floor(measurestep)
       else
        return 
      end
      
    -- get parameter
      local retval, tracknum, fxnum, paramnum = GetLastTouchedFX()
      if not retval then return end    
      local track =  CSurf_TrackFromID( tracknum, false )
      if not track then return end
    -- clear envelope
      local proj_len = GetProjectLength( 0 )
      local env = GetFXEnvelope( track, fxnum, paramnum, true ) 
      DeleteEnvelopePointRange( env, TS_start, TS_end )
    
    -- add points
      local retval, TS_start_measures, _, TS_start_fullbeats = TimeMap2_timeToBeats( 0, TS_start )
      local retval, TS_end_measures, _, TS_end_fullbeats = TimeMap2_timeToBeats( 0, TS_end )
      
      for meas = TS_start_measures,  TS_end_measures, measurestep do
        local point_gate = TimeMap2_beatsToTime( 0, 0,meas )
        local point_gate2 = TimeMap2_beatsToTime( 0,1/64, meas ) 
        InsertEnvelopePoint( env, 
                                    point_gate, 
                                    1,--value, 
                                    1,--shape, 
                                    0,--tension, 
                                    false,--selected, 
                                    true --noSortIn 
                                    )
        InsertEnvelopePoint( env, 
                                    point_gate2, 
                                    -0.1,--value, 
                                    1,--shape, 
                                    0,--tension, 
                                    false,--selected, 
                                    true --noSortIn 
                                    )                                  
      end
      Envelope_SortPoints(env)
      UpdateArrange()
      
      
    --[[local pat_len = TimeMap2_beatsToTime( 0, pat_len )
    pool_id = InsertAutomationItem( env, -1, curpos, pat_len )
    TrackList_AdjustWindows(false)]]
    
  end 
   
---------------------------------------------------------------------
  function CheckFunctions(str_func)
    local SEfunc_path = reaper.GetResourcePath()..'/Scripts/MPL Scripts/Functions/mpl_Various_functions.lua'
    local f = io.open(SEfunc_path, 'r')
    if f then
      f:close()
      dofile(SEfunc_path)
      
      if not _G[str_func] then 
        reaper.MB('Update '..SEfunc_path:gsub('%\\', '/')..' to newer version', '', 0)
       else
        return true
      end
      
     else
      reaper.MB(SEfunc_path:gsub('%\\', '/')..' missing', '', 0)
    end  
  end
  ---------------------------------------------------
  function CheckReaperVrs(rvrs) 
    local vrs_num =  GetAppVersion()
    vrs_num = tonumber(vrs_num:match('[%d%.]+'))
    if rvrs > vrs_num then 
      reaper.MB('Update REAPER to newer version '..'('..rvrs..' or newer)', '', 0)
      return
     else
      return true
    end
  end
--------------------------------------------------------------------  
  local ret = CheckFunctions('Action') 
  local ret2 = CheckReaperVrs(5.95)    
  if ret and ret2 then main() end