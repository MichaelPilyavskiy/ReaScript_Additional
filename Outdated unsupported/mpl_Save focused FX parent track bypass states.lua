-- @description Save focused FX parent track bypass states
-- @version 1.0
-- @author MPL
-- @website https://forum.cockos.com/showthread.php?t=188335
-- @changelog
--    + init 

  function main()
    local retval, tracknumber, itemnumber, fxnumber = reaper.GetFocusedFX2()
    if not (retval&1==1) then return end
    if tracknumber == 0 then return end
    local track = GetTrack(0,tracknumber-1)
    if not track then return end
    if fxnumber&0x1000000==0x1000000 then return end -- ignore input
    local str = ''
    for fx = 0,  TrackFX_GetCount( track )-1 do
      local GUID = reaper.TrackFX_GetFXGUID( track, fx )
      local bypass_id = reaper.TrackFX_GetParamFromIdent( track, fx, ':bypass' )
      local bypass = TrackFX_GetParam( track, fx, bypass_id )
      str = str..' '..GUID..' '..math.floor(bypass)
    end 
    SetExtState( 'MPL_SaveRestoreBypassStates', 'bypass_state', str, false )
  end
  ---------------------------------------------------------------------
  function VF_CheckFunctions(vrs)  local SEfunc_path = reaper.GetResourcePath()..'/Scripts/MPL Scripts/Functions/mpl_Various_functions.lua'  if  reaper.file_exists( SEfunc_path ) then dofile(SEfunc_path)  if not VF_version or VF_version < vrs then  reaper.MB('Update '..SEfunc_path:gsub('%\\', '/')..' to version '..vrs..' or newer', '', 0) else return true end   else  reaper.MB(SEfunc_path:gsub('%\\', '/')..' not found. You should have ReaPack installed. Right click on ReaPack package and click Install, then click Apply', '', 0) if reaper.APIExists('ReaPack_BrowsePackages') then ReaPack_BrowsePackages( 'Various functions' ) else reaper.MB('ReaPack extension not found', '', 0) end end end
  --------------------------------------------------------------------  
  local ret = VF_CheckFunctions(2.84) if ret then local ret2 = VF_CheckReaperVrs(5.975,true) if ret2 then 
    Undo_BeginBlock2( 0 )
    main() 
    Undo_EndBlock2( 0, 'Save focused FX parent track bypass states', 0 )
  end end