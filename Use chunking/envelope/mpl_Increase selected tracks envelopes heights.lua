-- @description Increase selected tracks envelopes heights
-- @version 1.01
-- @author MPL
-- @website http://forum.cockos.com/member.php?u=70694
-- @changelog
--    # independent from SWS

  difference = -10

  function main()
    for sel_tr = 1, reaper.CountSelectedTracks(0) do
      local track = reaper.GetSelectedTrack(0,sel_tr-1)
      if track then 
        for i = 1,  reaper.CountTrackEnvelopes( track ) do
          local env = reaper.GetTrackEnvelope( track, i-1 )
          local I_TCPH = GetEnvelopeInfo_Value( env, 'I_TCPH' )
          local retval, str = reaper.GetEnvelopeStateChunk( env, '', false )
          str=str:gsub('LANEHEIGHT %d+', 'LANEHEIGHT '..math.floor(VF_lim(I_TCPH - difference,1,1000)))
          SetEnvelopeStateChunk( env, str, false )
        end
      end
    end
    TrackList_AdjustWindows( true )
    UpdateArrange()
  end
    
  ----------------------------------------------------------------------
  function VF_CheckFunctions(vrs)  local SEfunc_path = reaper.GetResourcePath()..'/Scripts/MPL Scripts/Functions/mpl_Various_functions.lua'  if  reaper.file_exists( SEfunc_path ) then dofile(SEfunc_path)  if not VF_version or VF_version < vrs then  reaper.MB('Update '..SEfunc_path:gsub('%\\', '/')..' to version '..vrs..' or newer', '', 0) else return true end   else  reaper.MB(SEfunc_path:gsub('%\\', '/')..' not found. You should have ReaPack installed. Right click on ReaPack package and click Install, then click Apply', '', 0) if reaper.APIExists('ReaPack_BrowsePackages') then reaper.ReaPack_BrowsePackages( 'Various functions' ) else reaper.MB('ReaPack extension not found', '', 0) end end end
  --------------------------------------------------------------------  
  local ret = VF_CheckFunctions(3.41) if ret then local ret2 = VF_CheckReaperVrs(6,true) if ret2 then 
    Undo_BeginBlock2( 0 )
    main() 
    Undo_EndBlock2( 0, 'Increase selected tracks envelopes heights', 0xFFFFFFFF )
  end end