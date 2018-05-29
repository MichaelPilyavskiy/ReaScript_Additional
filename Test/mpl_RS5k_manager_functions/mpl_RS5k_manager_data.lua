-- @description RS5k_manager_data
-- @author MPL
-- @website http://forum.cockos.com/member.php?u=70694
-- @noindex

  ---------------------------------------------------
  function ExtState_Def()
    local t= {
            -- globals
            mb_title = 'RS5K manager',
            ES_key = 'MPL_RS5K manager',
            wind_x =  50,
            wind_y =  50,
            wind_w =  600,
            wind_h =  200,
            dock =    0,
            parent_tr_name = 'RS5K Manager',
            MIDItr_name = 'RS5K MIDI Patterns',
            preview_name = 'RS5K preview',
            
            -- GUI
            tab = 0,  -- 0-sample browser
            tab_div = 0.3,
            
            -- GUI control
            mouse_wheel_res = 960,
            
            -- Samples
            cur_smpl_browser_dir = GetResourcePath():gsub('\\','/'),
            fav_path_cnt = 4,
            use_preview = 0,
            
            -- Pads
            keymode = 0,  -- 0-keys
            keypreview = 1, -- send MIDI by clicking on keys
            oct_shift = 5,
            key_names = 8, --8 return MIDInotes and keynames
            
            -- Patterns
            default_steps = 16,
            max_step_count = 64,
            default_value = 120,
            commit_mode = 0, -- 0-commit to selected items,
            mouse_ctrldrag_res = 10,
            mouse_stepseq_wheel_res = 40,
            autoselect_patterns = 0,
            
            -- Options
            options_tab = 0,
            global_mode = 0, -- rs5k / sends/ dumpitems
            prepareMIDI = 0
            }
    for i = 1, t.fav_path_cnt do t['smpl_browser_fav_path'..i] = '' end
    return t
  end  
  ---------------------------------------------------  
  function CheckUpdates(obj, conf, refresh)
  
    -- force by proj change state
      obj.SCC =  GetProjectStateChangeCount( 0 ) 
      if not obj.lastSCC then 
        refresh.GUI_onStart = true  
        refresh.data = true
       elseif obj.lastSCC and obj.lastSCC ~= obj.SCC then 
        --if conf.dev_mode == 1 then msg(obj.SCC..'2') end
        refresh.data = true
        refresh.GUI = true
      end 
      obj.lastSCC = obj.SCC
      
    -- window size
      local ret = HasWindXYWHChanged(obj)
      if ret == 1 then 
        refresh.conf = true 
        refresh.data = true
        refresh.GUI_onStart = true        
       elseif ret == 2 then 
        refresh.conf = true
        refresh.data = true
      end
  end
  ---------------------------------------------------
  function GetRS5kData(tr,temp,p_offs) 
    local ex
    for fxid = 1,  TrackFX_GetCount( tr ) do
      local retval, buf =TrackFX_GetFXName( tr, fxid-1, '' )
      if buf:lower():match('rs5k') or buf:lower():match('reasamplomatic5000') then
        ex = true
        local retval, fn = TrackFX_GetNamedConfigParm( tr, fxid-1, 'FILE' )
        local pitch_offset = TrackFX_GetParamNormalized( tr, fxid-1, 15)
        p_offs[#p_offs+1] = pitch_offset
        temp[#temp+1] = {idx = fxid-1,
                        name = buf,
                        fn = fn,
                        pitch    =math.floor(({TrackFX_GetFormattedParamValue( tr, fxid-1, 3, '' )})[2]),
                        pitch_semitones =    ({TrackFX_GetFormattedParamValue( tr, fxid-1, 15, '' )})[2],
                        pitch_offset = pitch_offset,
                        gain=                 TrackFX_GetParamNormalized( tr, fxid-1, 0),
                        gain_dB =           ({TrackFX_GetFormattedParamValue( tr, fxid-1, 0, '' )})[2],
                        trackGUID =           GetTrackGUID( tr ),
                        pan=                  TrackFX_GetParamNormalized( tr, fxid-1,1),
                        attack =              TrackFX_GetParamNormalized( tr, fxid-1,9),
                        attack_ms =         ({TrackFX_GetFormattedParamValue( tr, fxid-1, 9, '' )})[2],
                        decay =              TrackFX_GetParamNormalized( tr, fxid-1,24),
                        decay_ms =         ({TrackFX_GetFormattedParamValue( tr, fxid-1, 24, '' )})[2],  
                        sust =              TrackFX_GetParamNormalized( tr, fxid-1,25),
                        sust_dB =         ({TrackFX_GetFormattedParamValue( tr, fxid-1, 25, '' )})[2],
                        rel =              TrackFX_GetParamNormalized( tr, fxid-1,10),
                        rel_ms =         ({TrackFX_GetFormattedParamValue( tr, fxid-1, 10, '' )})[2],                                                                        
                        }
      end
    end  
  end
  ---------------------------------------------------
  function GetSampleNameByNote(data, note)
    local str = ''
    for key in pairs(data) do
      if key == note then 
        --local fn = ''
        --for i = 1, #data[key] do
          local fn = GetShortSmplName(data[key][1].fn)
          local fn_full = data[key][1].fn          
        --end
        if not fn then fn = fn_full end
        return fn, true, fn_full
      end
    end
    return str
  end
  ---------------------------------------------------
  function DefineParentTrack(conf, data, refresh)
    local tr = GetSelectedTrack(0,0)
    if not tr then return end
    
    data.parent_track = tr 
    data.parent_track_GUID = GetTrackGUID( tr )    
    GetSetMediaTrackInfo_String( data.parent_track, 'P_NAME', conf.parent_tr_name, 1 ) -- hard link to name
    
    refresh.data = true
    refresh.conf = true
    refresh.GUI_onStart = true
    refresh.projExtData = true                     
  end
  ---------------------------------------------------
  function Data_ValidateTrackConfig(conf, obj, data, refresh, mouse, pat)
    
  
    -- check parent track
    local c = data.parent_track 
              and ValidatePtr2( 0, data.parent_track, 'MediaTrack*' )
              and data.parent_track_GUID
              and BR_GetMediaTrackByGUID(0,data.parent_track_GUID)
              and ValidatePtr2( 0, BR_GetMediaTrackByGUID(0,data.parent_track_GUID), 'MediaTrack*' )
              
      obj.set_par_tr.ignore_mouse = c
      
      if c == false then 
        data.parent_track = nil
        data.parent_track_GUID = nil         
       else         
         if data.parent_track and GetSetMediaTrackInfo_String( data.parent_track, 'P_NAME', '', 0 ) == conf.parent_tr_name and conf.global_mode==1 or conf.global_mode==2 then
           BuildTrackTemplate_MIDISendMode(conf, data, refresh)
         end  
        return true
      end 
      
      
          
  end
  ---------------------------------------------------
  function Data_Update(conf, obj, data, refresh, mouse, pat)
    local ret = Data_ValidateTrackConfig(conf, obj, data, refresh, mouse, pat) 
    if not ret then return end
    if not data.upd_cnt then data.upd_cnt = 0 end
    data.upd_cnt = data.upd_cnt + 1
     do return end
    -- do stuff
    local tr = data.parent_track
    local temp = {}
    local p_offs = {}    
    ---------    
    if conf.global_mode == 0 then
      --local tr = GetSelectedTrack(0,0)
      --if not tr then return end
      --data.parent_track = tr      
      GetSetMediaTrackInfo_String( tr, 'P_NAME', parent_tr_name, 1 )
      local ex = false
      GetRS5kData(tr,temp,p_offs)
      if ex and conf.prepareMIDI == 1 then MIDI_prepare(tr)   end
      for i =1, #temp do 
        if not data[ temp[i].pitch]  then data[ temp[i].pitch] = {} end
        data[ temp[i].pitch][#data[ temp[i].pitch]+1] = temp[i] 
      end
    end
    ---------   
    if conf.global_mode==1   then
      --[[local tr = GetSelectedTrack(0,0)
      if not tr then return end
      data.parent_track = tr]]
      local ex = false
      local tr_id = CSurf_TrackToID( tr, false )
      if GetMediaTrackInfo_Value( tr, 'I_FOLDERDEPTH' ) == 1 then      
        for i = tr_id+1, CountTracks(0) do
          local child_tr =  GetTrack( 0, i-1 )
          if ({GetSetMediaTrackInfo_String(child_tr, 'P_NAME', '', false)})[2] == MIDItr_name then data.parent_trackMIDI = child_tr end
          local lev = GetMediaTrackInfo_Value( child_tr, 'I_FOLDERDEPTH' )
          GetRS5kData(child_tr,temp,p_offs)   
          if lev < 0 then break end
        end
      end
      ---------- add from stored data
      for i =1, #temp do 
        if not data[ temp[i].pitch]  then data[ temp[i].pitch] = {} end
        data[ temp[i].pitch][#data[ temp[i].pitch]+1] = temp[i] 
      end        
    end
    ----------
    if conf.global_mode==2   then
      --[[local tr = GetSelectedTrack(0,0)
      if not tr then return end
      data.parent_track = tr]]
      GetSetMediaTrackInfo_String( tr, 'P_NAME', parent_tr_name, 1 )
      local ex = false
      local tr_id = CSurf_TrackToID( tr, false )
      --if GetMediaTrackInfo_Value( tr, 'I_FOLDERDEPTH' ) == 1 then      
        for i = tr_id, CountTracks(0) do
          local child_tr =  GetTrack( 0, i-1 )
          if ({GetSetMediaTrackInfo_String(child_tr, 'P_NAME', '', false)})[2] == MIDItr_name then data.parent_trackMIDI = child_tr end
          local lev = GetMediaTrackInfo_Value( child_tr, 'I_FOLDERDEPTH' )
          if lev < 0 then break end
          GetRS5kData(child_tr,temp,p_offs)   
      
        end
      --end
      ---------- add from stored data
      for i =1, #temp do 
        if not data[ temp[i].pitch]  then data[ temp[i].pitch] = {} end
        data[ temp[i].pitch][#data[ temp[i].pitch]+1] = temp[i] 
      end        
    end
    ------------------------    
    local is_diff = false
    local last_val
    for i = 1, #p_offs do 
      if last_val and last_val ~= p_offs[i] then is_diff = true break end
      last_val = p_offs[i]
    end
    if is_diff then data.global_pitch_offset = 0.5 else data.global_pitch_offset = last_val end
  end 
  ---------------------------------------------------
  function GetDestTrackByNote(data, conf, main_track, note, insert_new)
    if not main_track then return end
    local tr_id = CSurf_TrackToID( main_track, false ) - 1
    local ex = false
    local last_id
    
    -- search track
    if GetMediaTrackInfo_Value( main_track, 'I_FOLDERDEPTH' ) == 1 then
      for i = tr_id+1, CountTracks(0) do        
        local child_tr =  GetTrack( 0, i-1 )
        local lev = GetMediaTrackInfo_Value( child_tr, 'I_FOLDERDEPTH' )
        for fxid = 1,  TrackFX_GetCount( child_tr ) do
          local retval, buf =TrackFX_GetFXName( child_tr, fxid-1, '' )
          if buf:lower():match('rs5k') or buf:lower():match(conf.preview_name) then
            local cur_pitch = TrackFX_GetParamNormalized( child_tr, fxid-1, 3 )
            if math_q_dec(cur_pitch, 5) == math_q_dec(note/127,5) then
              ex = true   
              return child_tr
            end              
          end
        end
        if lev < 0 then 
          last_id = i-1
          break 
        end
      end   
    end
      
    -- insert new if not exists
    if not ex and insert_new then  
      local insert_id
      if last_id then insert_id = last_id+1 else insert_id = tr_id+1 end
      local new_ch = InsertTrack(insert_id)  
      -- set params 
      --MIDI_prepare(new_ch, true)
      SetMediaTrackInfo_Value( GetTrack(0, CSurf_TrackToID(new_ch,false)-2), 'I_FOLDERDEPTH',0 )
      --SetMediaTrackInfo_Value( new_ch, 'I_FOLDERDEPTH',-1 )
      if conf.global_mode == 1 then CreateMIDISend(data, new_ch) end
      return new_ch
    end
  end
  
  ---------------------------------------------------------------------------------------------------------------------
  function GetPeaks(data, note)
    if note and data[note] and data[note][1] then   
      local file_name = data[note][1].fn
      local src = PCM_Source_CreateFromFileEx( file_name, true )
      local peakrate = 5000
      local src_len =  GetMediaSourceLength( src )
      local n_spls = math.floor(src_len*peakrate)
      local n_ch = 1
      local want_extra_type = 0--115  -- 's' char
      local buf = new_array(n_spls * n_ch * 3) -- min, max, spectral each chan(but now mono only)
        -------------
      local retval =  PCM_Source_GetPeaks(    src, 
                                        peakrate, 
                                        0,--starttime, 
                                        n_ch,--numchannels, 
                                        n_spls, 
                                        want_extra_type, 
                                        buf )
      local spl_cnt  = (retval & 0xfffff)        -- sample_count
      local peaks = {}
      for i=1, spl_cnt do  peaks[#peaks+1] = buf[i]  end
      buf.clear()
      PCM_Source_Destroy( src )
      Normalize(peaks, 1) 
      return peaks, spl_cnt
    end
  end 
