-- @description Save selected tracks FX chains
-- @version 1.0
-- @author MPL
-- @website http://forum.cockos.com/showthread.php?p=2137484
-- @changelog
--    # clean up for forum post
  
    for key in pairs(reaper) do _G[key]=reaper[key] end 
  ------------------------------------------------------------------------------------------------------
  function literalize(str) -- http://stackoverflow.com/questions/1745448/lua-plain-string-gsub
     if str then  return str:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", function(c) return "%" .. c end) end
  end 
  ---------------------------------------------------
  function ExtractFXChunk(track )
    if TrackFX_GetCount( track ) == 0 then return end 
    local _, chunk = GetTrackStateChunk(track, '')
    local lastfxGUID = literalize(TrackFX_GetFXGUID( track, TrackFX_GetCount( track )-1))
    local out_ch = chunk:match('<FXCHAIN(.*FXID '..lastfxGUID..'[\r\n]+WAK %d).*>')
    return out_ch
  end
  ---------------------------------------------------------------------
  function main(conf)
    -- check are tracks selected
      local cnt_seltr = CountSelectedTracks(0)
      if cnt_seltr == 0 then MB('There aren`t selected tracks', 'Error', 0) return end   
      
    -- ask for output path
      local retval, projfn = reaper.EnumProjects( -1, '' )
      local proj_path = GetProjectPath(0,'')..'/'
      local fn_template = 'FX_Chains'
      if projfn == '' then 
        proj_path = GetResourcePath()..'/FXChains/' 
        local ts = os.date():gsub('%:', '-')
        fn_template = 'UntitledProject_'..ts
      end
      local retval0,  saving_folder = JS_Dialog_BrowseForSaveFile('Save selected tracks FX Chains', proj_path, fn_template, ".RfxChain")
      if retval0 ~= 1 then return end
      
    -- extract chunks
      local t = {}
      for i = 1, cnt_seltr do
        local tr = GetSelectedTrack(0,i-1)
        local ch = ExtractFXChunk(tr)
        if ch then  t[#t+1] = {name = ({GetTrackName( tr )})[2]:gsub('[%/%\\%:%*%?%"%<%>%|]+', '_'), chunk = ch} end
      end
      
    -- write files
      if #t ==0 then return end 
      local ret1 = RecursiveCreateDirectory(saving_folder, 1)
      --if ret1 == 0 then MB('Can`t create path', 'Error', 0) return end   
      for i = 1, #t do
        local fname = t[i].name
        local f = io.open (saving_folder..'/'..fname..'.RfxChain', 'w')
        if f then
          f:write(t[i].chunk)
          f:close()
        end
      end
      
  end
  
    if JS_Dialog_BrowseForSaveFile then 
      main() 
     else 
      MB('Missed JS ReaScript API extension', 'Error', 0) 
    end
    
