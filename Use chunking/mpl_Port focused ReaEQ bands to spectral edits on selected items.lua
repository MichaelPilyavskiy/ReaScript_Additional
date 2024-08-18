-- @description Port focused ReaEQ bands to spectral edits on selected items
-- @version 1.11
-- @author MPL
-- @website http://forum.cockos.com/showthread.php?t=188335
-- @changelog
--    # reindex out of metapackage by lot of requests


  -------------------------------------------------------
  function AddSE(data, tk_id, SR, item_pos, item_len, loopS, loopE, F_base, F_Area, gain_dB, take_offs, take_prate)
    if not data[tk_id+1] then return end
    if not data[tk_id+1].edits then data[tk_id+1].edits = {} end
      
    -- obey time selection
    local pos, len = 0, item_len
    if loopE - loopS > 0.001 then 
      pos = math.max(loopS - item_pos, 0)
      len = loopE - pos - item_pos
     else
      pos = 0
      len = item_len
    end
    pos = pos* take_prate + take_offs 
    len = len * take_prate
    if len <= 0 then return end
    local freq_L = math.max(0, F_base-F_Area)
    local freq_H = math.min(SR, F_base+F_Area)
    data[tk_id+1].edits [ #data[tk_id+1].edits + 1] = 
      {pos = pos,
       len = len,
       gain = 10^(gain_dB/20),
       fadeinout_horiz = 0,
       fadeinout_vert = 0,
       freq_low = freq_L,
       freq_high = freq_H,
       chan = -1, -- -1 all 0 L 1 R
       bypass = 0, -- bypass&1 solo&2
       gate_threshold = 0,
       gate_floor = 0,
       compress_threshold = 1,
       compress_ratio = 1,
       unknown1 = 0,
       unknown2 = 0,
       fadeinout_horiz2 = 0, 
       fadeinout_vert2 = 0}
  end
  ----------------------------------------------------------------------
  function main() 
    local  retval, tracknumber, itemnumber, fx = GetFocusedFX()
    if not (retval &1==1 and fx >= 0) then return end
    local tr = CSurf_TrackFromID( tracknumber, false )
    if not ValidatePtr2(0,tr,'MediaTrack*') then return end
    local isReaEQ = TrackFX_GetEQParam( tr, fx, 0 )
    if not isReaEQ then return end
    
    -- loop bands
    bands = {}
    for band = 0, 50 do
      local retval_type, b_type = reaper.TrackFX_GetNamedConfigParm(tr, fx, 'BANDTYPE'..band)
      if not retval_type then break end
      
      local retval, freq =      TrackFX_GetFormattedParamValue( tr, fx, band*3 + 0,'')
      local retval, db_gain  =  TrackFX_GetFormattedParamValue( tr, fx, band*3 + 1,'')
      local retval, N =         TrackFX_GetFormattedParamValue( tr, fx, band*3 + 2,'')
      local retval, b_enabled = TrackFX_GetNamedConfigParm( tr, fx, 'BANDENABLED'..band )      
      
      freq = math.floor(tonumber(freq) )
      db_gain = tonumber(db_gain) if not db_gain then db_gain = -150 end
      N = tonumber(N)
      b_type = tonumber(b_type)
      b_enabled = tonumber(b_enabled) and tonumber(b_enabled) ==1
      
      if (b_type == 8 or b_type == 9 or b_type == 2)and b_enabled then
          local Q = math.sqrt(2^N) / (2^N - 1 )
          bands[#bands+1]  = {  F = freq,
                                G = db_gain,
                                Q = math.floor(freq/Q)}
      end 
    end
    
    local loopS, loopE = GetSet_LoopTimeRange2( 0, false, 0, -1, -1, false )
    for i = 1, CountSelectedMediaItems(0) do 
      local item = GetSelectedMediaItem(0,i-1)
      local item_pos = GetMediaItemInfo_Value( item, 'D_POSITION' )
      local item_len = GetMediaItemInfo_Value( item, 'D_LENGTH' )
      local tk = GetActiveTake( item )
      local src =  GetMediaItemTake_Source( tk )
      local SR = GetMediaSourceSampleRate( src )
      local tk_id = GetMediaItemTakeInfo_Value( tk, 'IP_TAKENUMBER' )
      local take_offs = GetMediaItemTakeInfo_Value( tk , 'D_STARTOFFS' )
      local take_prate = GetMediaItemTakeInfo_Value( tk , 'D_PLAYRATE' )
      
      local ret, data = GetSpectralData(item) 
      for i = 1, #bands do  
        local f_area = 200
        if bands[i].F < 1000 then 
          f_area = 200
         elseif bands[i].F >= 1000 and bands[i].F < 5000 then 
          f_area = 200
         elseif bands[i].F >= 5000 and bands[i].F < 10000 then 
          f_area = 500
         elseif bands[i].F >= 10000 then 
          f_area = 1000
        end
        AddSE(data, tk_id, SR, item_pos, item_len, loopS, loopE, 
              bands[i].F, 
              f_area,--bands[i].Q, 
              bands[i].G, 
              take_offs, take_prate)
      end
      if ret then SetSpectralData(item, data) end
    end
  end
  function GetSpectralData(item)
    --[[
    {table}
      {takeID}
        {edits}
          {editID = 
            param = value}
    ]]
    if not item then return end
    local chunk = ({GetItemStateChunk( item, '', false )})[2]
    -- parse chunk
    local tk_cnt = 0
    local SE ={}
    for line in chunk:gmatch('[^\r\n]+') do 
    
      if line:match('<SOURCE') then 
        tk_cnt =  tk_cnt +1 
        SE[tk_cnt]= {}
      end 
        
      if line:match('SPECTRAL_CONFIG') then
        local sz = line:match('SPECTRAL_CONFIG ([%d]+)')
        if sz then sz = tonumber(sz) end
        SE[tk_cnt].FFT_sz = sz
      end
            
      if line:match('SPECTRAL_EDIT%s') then  
        if not SE[tk_cnt].edits then SE[tk_cnt].edits = {} end
        local tnum = {} 
        for num in line:gmatch('[^%s]+') do if tonumber(num) then tnum[#tnum+1] = tonumber(num) end end
        
        local take = GetMediaItemTake( item, tk_cnt-1 )
        local s_offs = GetMediaItemTakeInfo_Value( take, 'D_STARTOFFS'  )
        local rate = GetMediaItemTakeInfo_Value( take, 'D_PLAYRATE'  ) 
        
  
            
        SE[tk_cnt].edits [#SE[tk_cnt].edits+1] =       {pos = (tnum[1] - s_offs)/rate,
                       len = tnum[2]/rate,
                       gain = tnum[3],
                       fadeinout_horiz = tnum[4], -- knobleft/2 + knobright/2
                       fadeinout_vert = tnum[5], -- knoblower/2 + knobupper/2
                       freq_low = tnum[6],
                       freq_high = tnum[7],
                       chan = tnum[8], -- -1 all 0 L 1 R
                       bypass = tnum[9], -- bypass&1 solo&2
                       gate_threshold = tnum[10],
                       gate_floor = tnum[11],
                       compress_threshold = tnum[12],
                       compress_ratio = tnum[13],
                       unknown1 = tnum[14],
                       unknown2 = tnum[15],
                       fadeinout_horiz2 = tnum[16],  -- knobright - knobleft
                       fadeinout_vert2 = tnum[17],
                       chunk_str = line} -- knobupper - knoblower
      end
  
  
      local pat = '[%d%.]+ [%d%.]+'
      if line:match('SPECTRAL_EDIT_B') then  
        if not SE[tk_cnt].edits [#SE[tk_cnt].edits].points_bot then SE[tk_cnt].edits [#SE[tk_cnt].edits].points_bot = {} end
        for pair in line:gmatch('[^%+]+') do 
          SE[tk_cnt].edits [#SE[tk_cnt].edits].points_bot [#SE[tk_cnt].edits [#SE[tk_cnt].edits].points_bot + 1] = pair:match(pat)
        end
      end
  
      if line:match('SPECTRAL_EDIT_T') then  
        if not SE[tk_cnt].edits [#SE[tk_cnt].edits].points_top then SE[tk_cnt].edits [#SE[tk_cnt].edits].points_top = {} end
        for pair in line:gmatch('[^%+]+') do 
          SE[tk_cnt].edits [#SE[tk_cnt].edits].points_top [#SE[tk_cnt].edits [#SE[tk_cnt].edits].points_top + 1] = pair:match(pat)
        end
      end
                                   
    end
    return true, SE
  end
  ------------------------------------------------------------------------------------------------------
  function SetSpectralData(item, data, apply_chunk)
    --[[
    {table}
      {takeID}
        {edits}
          {editID = 
            param = value}
    ]]  
    if not item then return end
    local chunk = ({GetItemStateChunk( item, '', false )})[2]
    chunk = chunk:gsub('SPECTRAL_CONFIG.-\n', '')
    chunk = chunk:gsub('SPECTRAL_EDIT.-\n', '')
    local open
    local t = {} 
    for line in chunk:gmatch('[^\r\n]+') do t[#t+1] = line end
    local tk_cnt = 0 
    for i = 1, #t do
      if t[i]:match('<SOURCE') then 
        tk_cnt = tk_cnt + 1 
        open = true 
      end
      if open and t[i]:match('>') then
      
        local add_str = ''
        local take  =GetTake( item, tk_cnt-1 )
        if data[tk_cnt] 
          and data[tk_cnt].edits 
          and take
          and not TakeIsMIDI(take)
          then
          for edit_id in pairs(data[tk_cnt].edits) do
            if not data[tk_cnt].FFT_sz then data[tk_cnt].FFT_sz = 1024 end
            local s_offs = GetMediaItemTakeInfo_Value( take, 'D_STARTOFFS'  )
            local rate = GetMediaItemTakeInfo_Value( take, 'D_PLAYRATE'  ) 
            if not apply_chunk then
              add_str = add_str..'SPECTRAL_EDIT '
                ..data[tk_cnt].edits[edit_id].pos*rate + s_offs..' '
                ..data[tk_cnt].edits[edit_id].len*rate..' '
                ..data[tk_cnt].edits[edit_id].gain..' '
                ..data[tk_cnt].edits[edit_id].fadeinout_horiz..' '
                ..data[tk_cnt].edits[edit_id].fadeinout_vert..' '
                ..data[tk_cnt].edits[edit_id].freq_low..' '
                ..data[tk_cnt].edits[edit_id].freq_high..' '
                ..data[tk_cnt].edits[edit_id].chan..' '
                ..data[tk_cnt].edits[edit_id].bypass..' '
                ..data[tk_cnt].edits[edit_id].gate_threshold..' '
                ..data[tk_cnt].edits[edit_id].gate_floor..' '
                ..data[tk_cnt].edits[edit_id].compress_threshold..' '
                ..data[tk_cnt].edits[edit_id].compress_ratio..' '
                ..data[tk_cnt].edits[edit_id].unknown1..' '
                ..data[tk_cnt].edits[edit_id].unknown2..' '
                ..data[tk_cnt].edits[edit_id].fadeinout_horiz2..' '
                ..data[tk_cnt].edits[edit_id].fadeinout_vert2..' '
                ..'\n'
              
              if data[tk_cnt].edits[edit_id].points_bot then
                for pt = 1, #data[tk_cnt].edits[edit_id].points_bot, 10 do
                  add_str = add_str..'SPECTRAL_EDIT_B '..table.concat(data[tk_cnt].edits[edit_id].points_bot, ' + ', pt, math.min(#data[tk_cnt].edits[edit_id].points_bot, pt + 10))
                end
                add_str = add_str..'\n'
              end
  
              if data[tk_cnt].edits[edit_id].points_top then
                for pt = 1, #data[tk_cnt].edits[edit_id].points_top, 10 do
                  add_str = add_str..'SPECTRAL_EDIT_T '..table.concat(data[tk_cnt].edits[edit_id].points_top, ' + ', pt,  math.min(#data[tk_cnt].edits[edit_id].points_top, pt + 10))
                end
                add_str = add_str..'\n'
              end
                            
              add_str = add_str..'SPECTRAL_CONFIG '..data[tk_cnt].FFT_sz ..'\n'
              --msg(add_str)
             else
              add_str = apply_chunk..'\nSPECTRAL_CONFIG '..data[tk_cnt].FFT_sz ..'\n'
              
            end
          end        
        end
        
        t[i] = t[i]..'\n'..add_str
        open = false
      end
    end   
    
    local out_chunk = table.concat(t, '\n')
    --ClearConsole()
    --msg(out_chunk)
    SetItemStateChunk( item, out_chunk, false )
    UpdateItemInProject( item )
  end
  ----------------------------------------------------------------------
  function VF_CheckFunctions(vrs)  local SEfunc_path = reaper.GetResourcePath()..'/Scripts/MPL Scripts/Functions/mpl_Various_functions.lua'  if  reaper.file_exists( SEfunc_path ) then dofile(SEfunc_path)  if not VF_version or VF_version < vrs then  reaper.MB('Update '..SEfunc_path:gsub('%\\', '/')..' to version '..vrs..' or newer', '', 0) else return true end   else  reaper.MB(SEfunc_path:gsub('%\\', '/')..' not found. You should have ReaPack installed. Right click on ReaPack package and click Install, then click Apply', '', 0) if reaper.APIExists('ReaPack_BrowsePackages') then reaper.ReaPack_BrowsePackages( 'Various functions' ) else reaper.MB('ReaPack extension not found', '', 0) end end end
  --------------------------------------------------------------------  
  local ret = VF_CheckFunctions(3.42) if ret then local ret2 = VF_CheckReaperVrs(6.68,true) if ret2 then 
    Undo_BeginBlock()
    main() 
    Undo_EndBlock( 'Port focused ReaEQ bands to spectral edits', 4 )
  end end