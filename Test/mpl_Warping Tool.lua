


  local vrs = 0.5
  local changelog =                           
[===[ Warping Tool development is stopped / OLD Changelog:
23.01.2016  0.301
            + RMS alighn engine
22.01.2016  0.297
            # OSX font size
21.01.2016  0.29
            + Syllables alighn engine
            + Phase alighn engine
            + Play cursor
20.01.2016  0.272
            # Check for negative stretch markers
            - Removed Phrases internal stretch
20.01.2016  0.27
            Open for public testing
19.01.2016  0.265
            + Phrases alighn engine
            + Prepare takes for editing
            + GUI improvements
            + /Reaper/Scripts/mpl_WarpingTool.ini parser
06.01.2016  0.25 Testing New Algorithms
27.10.2015  0.23 Early alpha            
01.09.2015  0.01 Alignment / Warping / Tempomatching tool idea
 ]===]

----------------------------------------------------------------------- 
  function msg(str)
    if type(str) == 'boolean' then if str then str = 'true' else str = 'false' end end
    if type(str) == 'userdata' then str = str.get_alloc() end
    if str ~= nil then 
      reaper.ShowConsoleMsg(tostring(str)..'\n') 
      if str ==  "" then reaper.ShowConsoleMsg("") end
     else
      reaper.ShowConsoleMsg('nil')
    end    
  end
  
----------------------------------------------------------------------- 
  function fdebug(str) if debug_mode == 1 then msg(os.date()..' '..str) end end  
  
----------------------------------------------------------------------- 
  function MAIN_exit()
    reaper.atexit()
    gfx.quit()
  end  

-----------------------------------------------------------------------   
  function DEFINE_dynamic_variables()
    char = gfx.getchar()
    play_pos = reaper.GetPlayPosition(0)
    OS = reaper.GetOS()
  end

-----------------------------------------------------------------------
  function F_limit(val,min,max,retnil)
    if val == nil or min == nil or max == nil then return 0 end
    local val_out = val 
    if val == nil then val = 0 end
    if val < min then  val_out = min 
      if retnil then return nil end
    end
    if val > max then val_out = max 
      if retnil then return nil end
    end
    return val_out
  end 
    
-----------------------------------------------------------------------    
  function F_Get_SSV(s)
    local t = {}
    for i in s:gmatch("[%d%.]+") do 
      t[#t+1] = tonumber(i) / 255
    end
    gfx.r, gfx.g, gfx.b = t[1], t[2], t[3]
  end
  
----------------------------------------------------------------------- 
  function ENGINE_get_takes() 
    local take_guid
    local take_name
    local takes_t = {}
    local count_items = reaper.CountSelectedMediaItems()
    if count_items ~= nil then 
      for i =1, count_items do 
        local item = reaper.GetSelectedMediaItem(0, i-1)
        if item ~= nil then
          local item_len  = reaper.GetMediaItemInfo_Value( item, 'D_LENGTH')
          local item_pos  = reaper.GetMediaItemInfo_Value( item, 'D_POSITION')
          local take = reaper.GetActiveTake(item)
          if not reaper.TakeIsMIDI(take) then    
            take_guid = reaper.BR_GetMediaItemTakeGUID(take)
            _, take_name = reaper.GetSetMediaItemTakeInfo_String(take, 'P_NAME', '', false)      
            local t_offs = reaper.GetMediaItemTakeInfo_Value(take, 'D_STARTOFFS')            
            local src = reaper.GetMediaItemTake_Source(take)
            local rate = reaper.GetMediaSourceSampleRate(src) 
                   
            table.insert(takes_t, 
              {['guid']=take_guid,
               ['name']=take_name,
               ['len']=item_len,
               ['pos']=item_pos,
               ['offset']=t_offs,
               ['rate']=rate})
          end
        end    
      end        
    end   
    return takes_t 
  end  

-----------------------------------------------------------------------     
  function ENGINE_prepare_takes() local item, take
    local count_items = reaper.CountSelectedMediaItems()
    if count_items == nil or count_items < 1 then return end
    
    -- macro alighn
      if data.current_window == 1 
      or data.current_window == 2 
      or data.current_window == 3 then
        reaper.Main_OnCommand(41844,0) -- clear stretch markers
        reaper.Main_OnCommand(40652,0) -- set item rate to 1
        
        -- check for unglued reference item/take
          local ref_item = reaper.GetSelectedMediaItem(0, 0)
          if ref_item == nil then return end
          local ref_track = reaper.GetMediaItemTrack(ref_item)
          local ref_pos = reaper.GetMediaItemInfo_Value(ref_item, 'D_POSITION')
          local ref_len = reaper.GetMediaItemInfo_Value(ref_item, 'D_LENGTH')
          for i = 2, count_items do
            item = reaper.GetSelectedMediaItem(0, i-1)
            track = reaper.GetMediaItemTrack(item)
            if track == ref_track then
              reaper.MB('Reference item/take should be glued','Warping tool', 0)
              return
            end
          end
          
        -- check for edges
          for i = 2, count_items do
            item = reaper.GetSelectedMediaItem(0, i-1)
            local pos = reaper.GetMediaItemInfo_Value(item, 'D_POSITION')
            local len = reaper.GetMediaItemInfo_Value(item, 'D_LENGTH')
            if pos < ref_pos then 
              reaper.SetMediaItemInfo_Value(item, 'D_POSITION', ref_pos) 
              local take = reaper.GetActiveTake(item)   
              local take_offs = reaper.GetMediaItemTakeInfo_Value(take, 'D_STARTOFFS')
              reaper.SetMediaItemTakeInfo_Value(take, 'D_STARTOFFS', take_offs + ref_pos - pos)
            end
            
            if ref_pos + ref_len < pos+len then
              reaper.SetMediaItemInfo_Value(item, 'D_LENGTH', len - (pos+len - ref_pos  - ref_len)) 
            end
            
            if data.current_window == 3 then
              reaper.SetMediaItemInfo_Value(item, 'D_POSITION', ref_pos)
            end
            
          end
      end
      
    
    reaper.UpdateArrange()
    return 1 -- successful
  end
  
-----------------------------------------------------------------------   
  function ENGINE_get_take_data(take_id, scaling)
    local st_win_cnt,end_win_cnt
    
    local fft_size = 1024
    local HP = 2
    local LP = fft_size -- end spectrum
    
    
    fdebug('HP freq'..HP*22050/fft_size)
    fdebug('LP freq'..LP*22050/fft_size)
    
    local fft_sum_com
    local fft_sum = 0    
    local aa = {}
    local fft_sum_t = {}
    local rms_t = {}
    
    if takes_t ~= nil and takes_t[take_id] ~= nil then
      local take = reaper.SNM_GetMediaItemTakeByGUID(0, takes_t[take_id].guid)
      if take ~= nil then
        local item = reaper.GetMediaItemTake_Item(take)
        local item_len = reaper.GetMediaItemInfo_Value(item, 'D_LENGTH')
        aa.accessor = reaper.CreateTakeAudioAccessor(take)
        aa.src = reaper.GetMediaItemTake_Source(take)
        aa.numch = reaper.GetMediaSourceNumChannels(aa.src)
        aa.rate = reaper.GetMediaSourceSampleRate(aa.src) 
        
          aa.window_sec = fft_size/aa.rate -- ms
          data.global_window_sec = aa.window_sec
          
          -- get fft_size samples buffer
            for read_pos = 0, item_len, aa.window_sec do 
            
              aa.buffer = reaper.new_array(fft_size*2)
              aa.buffer_com = reaper.new_array(fft_size*2)
               
              reaper.GetAudioAccessorSamples(
                    aa.accessor , --AudioAccessor
                    aa.rate, -- samplerate
                    2,--aa.numch, -- numchannels
                    read_pos, -- starttime_sec
                    fft_size, -- numsamplesperchannel
                    aa.buffer) --samplebuffer
                    
              -- merge buffers dy duplicating sum/2
                for i = 1, fft_size*2 - 1, 2 do
                  aa.buffer_com[i] = (aa.buffer[i] + aa.buffer[i+1])/2
                  aa.buffer_com[i+1] = 0
                end
                
                
              -- Get FFT sum of bins in defined range
                aa.buffer_com.fft(fft_size, true, 1)
                aa.buffer_com_t = aa.buffer_com.table(1,fft_size, true)
                fft_sum_com = 0
                for i = HP, LP do
                  fft_sum_com = fft_sum_com + math.abs(aa.buffer_com_t[i])
                end    
                table.insert(fft_sum_t, fft_sum_com /(LP-HP))
                                
                                    
              --[[ rms table
                aa.buffer_t = aa.buffer.table(1,fft_size*2, true)
                rms_sum = 0
                for i = 1, fft_size/2 do rms_sum = rms_sum + math.abs(aa.buffer_t[i])--^0.8 end   
                table.insert(rms_t, rms_sum)]]
                
                aa.buffer.clear()
                aa.buffer_com.clear()              
            end
            
        reaper.DestroyAudioAccessor(aa.accessor)
       else return
      end
     else return
    end
    
    --out_t = rms_t
    local out_t = fft_sum_t
    
    -- normalize table
      local max_com = 0
      for i =1, #out_t do max_com = math.max(max_com, out_t[i]) end
      local com_mult = 1/max_com      
      for i =1, #out_t do out_t[i]= out_t[i]*com_mult  end
    
    -- return scaled table
      for i =1, #out_t do out_t[i]= out_t[i]^scaling  end
      
    --[[ normalize table
      local max_com = 0
      for i =1, #out_t do max_com = math.max(max_com, out_t[i]) end
      com_mult = 1/max_com      
      for i =1, #out_t do out_t[i]= out_t[i]*com_mult  end    ]]  
    
    -- fill null to reference item
      if take_id > 1 then
        st_win_cnt = math.floor ((takes_t[take_id].pos - takes_t[1].pos) 
        / data.global_window_sec)
        end_win_cnt = math.floor
          ((takes_t[1].pos + takes_t[1].len - takes_t[take_id].pos - takes_t[take_id].len) 
          / data.global_window_sec)
        -- fill from start
          if takes_t[take_id].pos > takes_t[1].pos then            
            for i = 1, st_win_cnt do table.insert(out_t, 1, 0) end
          end
        -- fill end
          if takes_t[take_id].pos + takes_t[take_id].len < 
              takes_t[1].pos + takes_t[1].len then
            for i = 1, end_win_cnt do out_t[#out_t+1] = 0 end
          end
      end
    
      if out_t ~= nil and #out_t > 1 then
        local out_array = reaper.new_array(out_t, #out_t)
        return out_array
      end
  end 

-----------------------------------------------------------------------  
  function ENGINE_get_take_data3(take_id, scaling)
  
    local aa = {}
    if takes_t ~= nil and takes_t[take_id] ~= nil then
      local take = reaper.SNM_GetMediaItemTakeByGUID(0, takes_t[take_id].guid)
      if take ~= nil then
        local item = reaper.GetMediaItemTake_Item(take)
        local item_len = reaper.GetMediaItemInfo_Value(item, 'D_LENGTH')
        aa.accessor = reaper.CreateTakeAudioAccessor(take)
        aa.src = reaper.GetMediaItemTake_Source(take)
        aa.numch = 2--reaper.GetMediaSourceNumChannels(aa.src)
        aa.rate = reaper.GetMediaSourceSampleRate(aa.src) 
        
        local arr_size = math.floor(data.window3 * aa.rate)
        
        aa.buffer = reaper.new_array(arr_size*2)
        aa.buffer_com = reaper.new_array(arr_size)
        reaper.GetAudioAccessorSamples(
            aa.accessor , --AudioAccessor
            aa.rate, -- samplerate
            2,--aa.numch, -- numchannels
            0, -- starttime_sec
            arr_size, -- numsamplesperchannel
            aa.buffer) --samplebuffer
                    
        -- merge buffers dy duplicating sum/2
          for i = 2, arr_size * 2, 2  do
            aa.buffer_com[i/2] = (aa.buffer[i] + aa.buffer[i-1])/2
          end
        reaper.DestroyAudioAccessor(aa.accessor)
       else return
      end
     else return
    end    
    return aa.buffer_com,aa.rate    
  end 
  
-----------------------------------------------------------------------  
  function ENGINE_get_take_data4(take_id, scaling)
    local st_win_cnt,end_win_cnt,
    rms_com_arrL,
    rms_com_arrR,
    rms_com_arrL_t,
    rms_com_arrR_t,
    rms_com_arr_t
 
    local aa = {}
    local rms_t = {}
    
    
    if takes_t ~= nil and takes_t[take_id] ~= nil then
      local take = reaper.SNM_GetMediaItemTakeByGUID(0, takes_t[take_id].guid)
      if take ~= nil then
        local item = reaper.GetMediaItemTake_Item(take)
        local item_len = reaper.GetMediaItemInfo_Value(item, 'D_LENGTH')
        aa.accessor = reaper.CreateTakeAudioAccessor(take)
        aa.src = reaper.GetMediaItemTake_Source(take)
        aa.numch = reaper.GetMediaSourceNumChannels(aa.src)
        aa.rate = reaper.GetMediaSourceSampleRate(aa.src) 
        
          aa.window_sec = data.arr_size4/aa.rate -- ms
          rms_com_id = 1
          arr_ch_size = math.ceil(item_len / aa.window_sec)
          --rms_com_arrL = reaper.new_array(arr_ch_size)
          --rms_com_arrR = reaper.new_array(arr_ch_size)
          rms_com_arr = reaper.new_array(arr_ch_size)
          
          -- get fft_size samples buffer
            for read_pos = 0, item_len, aa.window_sec do 
            
              aa.buffer = reaper.new_array(data.arr_size4*2)
              aa.buffer_l = reaper.new_array(data.arr_size4)
              aa.buffer_r  = reaper.new_array(data.arr_size4)
              reaper.GetAudioAccessorSamples(
                    aa.accessor , --AudioAccessor
                    aa.rate, -- samplerate
                    2,--aa.numch, -- numchannels
                    read_pos, -- starttime_sec
                    data.arr_size4, -- numsamplesperchannel
                    aa.buffer) --samplebuffer
                    
              -- merge buffers
                for i = 1, data.arr_size4 - 1 do
                  aa.buffer_l[i] = aa.buffer[i*2]
                  aa.buffer_r[i] = aa.buffer[i*2 + 1]
                end

              -- rms 
                --local rms_l_com = 0
                --local rms_r_com = 0
                local rms_com = 0
                for i = 1, data.arr_size4 - 1 do
                  --rms_l_com = rms_l_com + math.abs(aa.buffer_l[i])
                  --rms_r_com = rms_r_com + math.abs(aa.buffer_r[i])
                  rms_com = rms_com + ( math.abs(aa.buffer_r[i]) + math.abs(aa.buffer_r[i])) / 2
                end

                --rms_com_arrL[rms_com_id] = rms_l_com / (arr_size - 1)
                --rms_com_arrR[rms_com_id] = rms_r_com / (arr_size - 1)
                rms_com_arr[rms_com_id] = rms_com / (data.arr_size4 - 1)
                rms_com_id = rms_com_id + 1
              
                aa.buffer.clear()
                aa.buffer_r.clear()    
                aa.buffer_l.clear()             
            end
            
        reaper.DestroyAudioAccessor(aa.accessor)
       else return
      end
     else return
    end
    
    --rms_com_arrL_t = rms_com_arrL.table(1, arr_ch_size)
    --rms_com_arrR_t = rms_com_arrR.table(1, arr_ch_size)
    
    rms_com_arr_t = rms_com_arr.table(1, arr_ch_size)
    
    -- fill null to reference item
      if take_id > 1 then
        st_win_cnt = math.floor ((takes_t[take_id].pos - takes_t[1].pos) 
        / aa.window_sec)
        end_win_cnt = math.floor
          ((takes_t[1].pos + takes_t[1].len - takes_t[take_id].pos - takes_t[take_id].len) 
          / aa.window_sec)
          
        -- fill from start
          if takes_t[take_id].pos > takes_t[1].pos then            
            --for i = 1, st_win_cnt do table.insert(rms_com_arrL_t, 1, 0) end
            --for i = 1, st_win_cnt do table.insert(rms_com_arrR_t, 1, 0) end
            for i = 1, st_win_cnt do table.insert(rms_com_arr_t, 1, 0) end
          end
        -- fill end
          if takes_t[take_id].pos + takes_t[take_id].len < 
              takes_t[1].pos + takes_t[1].len then
            --for i = 1, end_win_cnt do rms_com_arrL_t[#rms_com_arrL_t+1] = 0 end
            --for i = 1, end_win_cnt do rms_com_arrR_t[#rms_com_arrR_t+1] = 0 end
            for i = 1, end_win_cnt do rms_com_arr_t[#rms_com_arr_t+1] = 0 end
          end
      end
      
      if rms_com_arr_t ~= nil and #rms_com_arr_t > 1 then
        out_array = reaper.new_array(rms_com_arr_t, #rms_com_arr_t)
        return out_array
      end
      
      --[[if rms_com_arrL_t ~= nil and #rms_com_arrL_t > 1 then
        local out_array_L = reaper.new_array(rms_com_arrL_t, #rms_com_arrL_t)
        local out_array_R = reaper.new_array(rms_com_arrR_t, #rms_com_arrR_t)
        return out_array_L,out_array_R
      end]]
  end 
    
-----------------------------------------------------------------------   
  function ENGINE_get_take_data_points1(inputarray, window_sec) -- macro mode
    local exists_in_st_area,gate_id_st,last_gate_id
    
    if inputarray == nil then return end
    local arr_size = inputarray.get_alloc()
    if arr_size <=1 then return end
    local points = reaper.new_array(arr_size)
    --  clear arr val
      for i = 1, arr_size do
        points[i] = 0
      end  
    
    local threshold_scaled = (10^(data.threshold1/20))^data.scaling_pow1
    local min_phrase_time_wind = math.floor(data.min_phrase_time1 / window_sec)
    
    local gate = false
    -- gate stuff
      for i = 1, arr_size do
        -- gate open
          if inputarray[i] > threshold_scaled and not gate then
            gate = true
            gate_id_st = i
            points[i] = 1
            last_gate_id = i
          end
        
        if inputarray[i] < threshold_scaled and gate and i - last_gate_id > min_phrase_time_wind then 
          gate = false
          points[i] = 1
          if i - gate_id_st < min_phrase_time_wind then
            points[i] = 0
            points[gate_id_st] = 0
          end
          gate_id_st = nil
        end
      end
        
      -------------------------
      
    -- check for ending
      local block_ids = {}
      for i = 1, arr_size do
        if points[i] == 1 then
          block_ids[#block_ids+1] = i
        end
      end    
      if #block_ids % 2 == 1 then points[arr_size-1] = 1 end
      
      if #block_ids < 2 then return end
    -- check if last block less than min length
      local last_block = (arr_size-1) - block_ids[#block_ids-1]
      if last_block < min_phrase_time_wind then 
        points[arr_size-1] = 0
        points[block_ids[#block_ids-1]] = 0
      end
      
    -- check for relative empty blocks
      for i = 1, #block_ids - 1, 2 do
        -- get rms of blocl
        local val_sum = 0
        for k = block_ids[i], block_ids[i+1] do
          val_sum = val_sum + inputarray[k]
        end
        val_sum = val_sum / (block_ids[i+1] - block_ids[i])
        if val_sum < threshold_scaled then
          points[block_ids[i]] = 0
          points[block_ids[i+1]] = 0
        end        
      end
      
    return points
  end
        
-----------------------------------------------------------------------  
  function ENGINE_get_take_data_points2(inputarray, window_sec) -- micro mode
    local exists_in_st_area,gate_id_st,last_gate_id
    
    if inputarray == nil then return end
    local arr_size = inputarray.get_alloc()    
    if arr_size <=1 then return end
    
    local points = reaper.new_array(arr_size)
    
    --  clear arr val
      for i = 1, arr_size do points[i] = 0 end  
      
    local threshold_scaled = (10^(data.threshold2/20))^data.scaling_pow2
    local threshold_rise_scaled = (10^((-120+data.threshold_rise2)/20))^data.scaling_pow2
    local risearea_wind = math.floor(data.rise_area2 / window_sec)
    local filter_area_wind = math.floor(data.filter_area2 / window_sec)
    
    -- gate stuff
      for i = 2, arr_size do
        -- gate open
          if inputarray[i] > threshold_scaled and 
             inputarray[i-1] < threshold_scaled then
            points[i] = 1
          end
        -- gate close
        if inputarray[i] < threshold_scaled and 
            inputarray[i-1] > threshold_scaled then 
          points[i] = 1
        end
      end
      
    -- check for rise
      for i = 1, arr_size - risearea_wind do 
        -- check for start points
        if i <= risearea_wind and inputarray[i] > threshold_scaled then 
          points[1] = 1 
         else
         
          --further points  
          if inputarray[i] > threshold_scaled then
            -- check area
            max_val = 0
            for k = i, i + risearea_wind do
              max_val = math.max(max_val, inputarray[k])
            end
            if max_val - inputarray[i] > threshold_rise_scaled then
              points[i] = 1 
            end
          end  
               
        end -- cond start area
      end
    
    local point_k_val,point_i_val,max_val
    -- filter points
      for i = 1, arr_size - filter_area_wind - 1 do 
        if points[i] == 1 then
          point_i_val = inputarray[i]
          max_val = 0
          for k = i + 1, i + 1 + filter_area_wind do
            if points[k] == 1 then 
              point_k_val = inputarray[k]
              max_val = math.max(max_val,point_k_val)
              --[[if last_max_val == nil or last_max_val ~= max_val then
                max_val_id = k
              end
              last_max_val = max_val]]
            end
          end
          
          if max_val ~= 0 then points[i] = 0 end
          --if max_val_id ~= nil then points[max_val_id] = 0 end
        end
      end
      
    points[1] = 1
    points[arr_size] = 1
    return points
  end
 
-----------------------------------------------------------------------    
  function F_find_arrays_com_diff(ref_array, ref_array_offset, dub_array)
    local dub_array_size = dub_array.get_alloc()
    local ref_array_size = ref_array.get_alloc()
    local endpoint
    local com_difference = 0
    if ref_array_offset + dub_array_size > ref_array_size then endpoint = ref_array_size - ref_array_offset
      else endpoint = dub_array_size end
      
    for i = 1, endpoint do
      com_difference = com_difference + math.abs(ref_array[i + ref_array_offset - 1 ]-dub_array[i])
    end
    return com_difference
  end
    
-----------------------------------------------------------------------   
  function F_find_min_value(reaperarray)
    reaperarray_size = reaperarray.get_alloc()
    min_dif0 = math.huge
    local min_dif, min_dif_id
    for k = 1, reaperarray_size do
      min_dif = math.min(reaperarray[k], min_dif0)
      if min_dif ~= min_dif0 then 
        min_dif0 = min_dif 
        min_dif_id = k 
      end
    end  
    return min_dif_id
  end
  
-----------------------------------------------------------------------  
  function ENGINE_compare_data1(ref_arr, dub_arr, dub_points_arr, window_sec)
    local st_search, end_search
    
    if ref_arr == nil then return end
    if dub_arr == nil then return end
    if dub_points_arr == nil then return end
    
    local dub_arr_size = dub_arr.get_alloc()
    
    local sm_table = {}
    local sm_table2 = {}
    
    local max_search_area_wind = 
      math.floor(data.max_search_area1 / window_sec)
      
    -- get blocks
       local block_ids = {}
      for i = 1, dub_arr_size do
        if dub_points_arr[i] == 1 then
          block_ids[#block_ids+1] = i
        end
      end    
      -- erase unfinished block
      if #block_ids % 2 == 1 then block_ids[#block_ids] = nil end
    
    -- loop blocks
    
      for i = 1, #block_ids - 1 , 2 do
        -- create fixed block
          local fantom_arr_size = block_ids[i+1] - block_ids[i] + 1
          local fantom_arr = reaper.new_array(fantom_arr_size)
          fantom_arr.copy(dub_arr,--src, 
                          block_ids[i],--srcoffs, 
                          fantom_arr_size,--size, 
                          1)--destoffs])
          
          -- PHRASES ALG 1 -- 
          
        -- loop whole segment pos
          if i == 1 then st_search = 1 else 
            st_search = block_ids[i-1] + 1 end
            
          if block_ids[i] - st_search > max_search_area_wind then 
            st_search = block_ids[i] - max_search_area_wind end
                        
          if i ~= #block_ids - 1 then end_search = block_ids[i+2] - fantom_arr_size - 1 else 
            end_search = dub_arr_size - fantom_arr_size - 1 end
            
          if end_search - block_ids[i] > max_search_area_wind then
            end_search = block_ids[i] + max_search_area_wind - 1 end
            
            --[[msg('------------------------'..i)
            msg('st_search'..st_search)
            msg('end_search'..end_search)
            msg(ref_arr)
            msg('max_search_area_wind'..max_search_area_wind)]]
            
        -- find best fit
          local diff_t = {}
          for k = st_search, end_search do
            local diff_com = 0
            for m = 1, fantom_arr_size do
              diff_com = diff_com + math.abs(fantom_arr[m]-ref_arr[k+m-1])
            end
            diff_t[k-st_search+1] = diff_com
          end
          
        -- check diff t
          local min_dif0 = math.huge
          local min_dif, min_dif_id,min_dif_id2
          for k = 1, #diff_t do
            min_dif = math.min(diff_t[k], min_dif0)
            if min_dif ~= min_dif0 then 
              min_dif0 = min_dif 
              min_dif_id = k 
            end
          end          
          if min_dif_id ~= nil then 
            min_dif_id = min_dif_id + st_search - 1  
              
            -- extract into str m table
              sm_table[#sm_table+1] =  
                  {min_dif_id*  window_sec,
                    block_ids[i]* window_sec}
              sm_table[#sm_table+1] =
                  {(min_dif_id+ fantom_arr_size) *  window_sec,
                    block_ids[i+1]* window_sec}
              --[[sm_table[#sm_table+1] = {min_dif_id,block_ids[i]} -- test sm
              sm_table[#sm_table+1] = {min_dif_id + fantom_arr_size,
                                        block_ids[i+1]}]]
           else
            min_dif_id = block_ids[i]
          end -- if found diff id 
      end  
    
    return sm_table, sm_table2
  end    
  
-----------------------------------------------------------------------   
  function F_stretch_array(src_array, new_size)
    --msg(src_array)
    --msg(new_size)
    local src_array_size = src_array.get_alloc()
    local coeff = (src_array_size - 1) / (new_size  - 1)
    local out_array = reaper.new_array(new_size)
    if new_size < src_array_size or new_size > src_array_size then
      for i = 0, new_size - 1 do 
        out_array[i+1] = src_array[math.floor(i * coeff) + 1]
      end
      return out_array
     elseif new_size == src_array_size then 
      out_array = src_array 
      return out_array
    end
    
    return out_array    
  end
    
-----------------------------------------------------------------------    
  function F_stretch_array2(src_array, src_mid_point, stretched_point)
    --[[msg('--------')
    msg(src_mid_point)
    msg(stretched_point)]]
    if src_array == nil or src_mid_point == nil or stretched_point == nil 
      then return end
      
    local src_array_size = src_array.get_alloc()
    local out_arr = reaper.new_array(src_array_size)
    
    local src_arr_pt1_size = src_mid_point - 1
    local src_arr_pt2_size = src_array_size-src_mid_point + 1
    
    local out_arr_pt1_size = stretched_point - 1
    local out_arr_pt2_size = src_array_size-stretched_point + 1
    
    local src_arr_pt1 = reaper.new_array(src_arr_pt1_size)
    local src_arr_pt2 = reaper.new_array(src_arr_pt2_size)
    
    src_arr_pt1.copy(src_array,--src, 
                            1,--srcoffs, 
                            src_arr_pt1_size,--size, 
                            1)--destoffs])  
    src_arr_pt2.copy(src_array,--src, 
                            src_mid_point,--srcoffs, 
                            src_arr_pt2_size,--size, 
                            1)--destoffs])
            
    local out_arr_pt1 = F_stretch_array(src_arr_pt1, out_arr_pt1_size)
    local out_arr_pt2 = F_stretch_array(src_arr_pt2, out_arr_pt2_size)
    
    out_arr.copy(out_arr_pt1,--src, 
                 1,--srcoffs, 
                 out_arr_pt1_size,--size, 
                 1)--destoffs]) 
    out_arr.copy(out_arr_pt2,--src, 
                 1,--srcoffs, 
                 out_arr_pt2_size,--size, 
                 out_arr_pt1_size + 1)--destoffs]) 
                 
    return   out_arr               
  end
  
-----------------------------------------------------------------------      
  function ENGINE_compare_data2(ref_arr, dub_arr, points, window_sec)
    local st_search, end_search
    
    if ref_arr == nil then return end
    if dub_arr == nil then return end
    if points == nil then return end

    local sm_table = {}    
    local dub_arr_size = dub_arr.get_alloc()      
    search_area = math.floor(data.max_search_area2 / window_sec)
            
    -- get blocks
      local block_ids = {}
      for i = 1, dub_arr_size do
        if points[i] == 1 then block_ids[#block_ids+1] = i end
      end    
      
    -- loop blocks
      for i = 1, #block_ids - 2 do
        -- create fixed block
          fantom_arr_size = block_ids[i+2] - block_ids[i] + 1
          
          local fantom_arr = reaper.new_array(fantom_arr_size)
          fantom_arr.copy(dub_arr,--src, 
                          block_ids[i],--srcoffs, 
                          fantom_arr_size,--size, 
                          1)--destoffs])
                          
        -- loop possible positions
          local min_block_len = 2
          search_pos_start = block_ids[i+1] - search_area
          if search_pos_start < block_ids[i] + min_block_len then
            search_pos_start = block_ids[i] + min_block_len end
          search_pos_end = block_ids[i+1] + search_area
          if search_pos_end > block_ids[i+2] - min_block_len then
            search_pos_end = block_ids[i+2] - min_block_len end    
          if (search_pos_end-search_pos_start+1) > min_block_len then
            --search_pos_start = block_ids[i] + 2
            --search_pos_end = block_ids[i+2] - 2 
            
            diff = reaper.new_array(search_pos_end-search_pos_start+1)
            
            for k = search_pos_start, search_pos_end do
              local orig_block = block_ids[i+1]-block_ids[i]+ 1
              local str_block = k - block_ids[i] +1
              --msg(orig_block)
              --msg(str_block)
              fantom_arr_stretched = 
                F_stretch_array2(fantom_arr,  orig_block, str_block)
              diff[k - search_pos_start+1] = 
                F_find_arrays_com_diff(ref_arr, block_ids[i], fantom_arr_stretched)
            end
            min_id_diff = F_find_min_value(diff) + search_pos_start - 1
            --[[msg('---------------') 
            msg(min_id_diff)     
            msg(block_ids[i+1])]]
            sm_table[#sm_table+1] =  
                {(min_id_diff) *  window_sec,
                  (block_ids[i+1]) * window_sec}
                  
            block_ids[i+1] = min_id_diff
          end
      end -- end loop blocks
    --msg('test')
    return sm_table
  end    
    
-----------------------------------------------------------------------  
  function ENGINE_compare_data3(ref_arr, dub_arr, rate) -- 3 seconds of every array
    
    ref_arr_size = ref_arr.get_alloc()
    dub_arr_size = dub_arr.get_alloc()

    dub_arr_cut = reaper.new_array(ref_arr_size / 3)
    dub_arr_cut.copy(dub_arr,--[src, 
                      ref_arr_size / 3, --srcoffs, 
                      ref_arr_size / 3, --size, 
                      1)--destoffs])
                      
    diff_com = reaper.new_array(2 * ref_arr_size / 3)
    for i = 1, 2 * ref_arr_size / 3 do
      diff_com[i] = F_find_arrays_com_diff(ref_arr, i, dub_arr_cut)
    end
    
    position_offset = - F_find_min_value(diff_com) + ref_arr_size / 3
    
    return position_offset / rate
  end
                              
-----------------------------------------------------------------------   
  function ENGINE_set_stretch_markers(take_id, str_mark_table, val)
    if str_mark_table == nil then return nil end
    if takes_t ~= nil and takes_t[take_id] ~= nil then
      local take = reaper.SNM_GetMediaItemTakeByGUID(0, takes_t[take_id].guid)
      if take ~= nil then       
        
        reaper.DeleteTakeStretchMarkers(take, 0, #str_mark_table + 1)
       
        reaper.SetTakeStretchMarker(take, -1, 0, takes_t[take_id].offset)
        for i = 1, #str_mark_table do
        
          set_pos = str_mark_table[i][1]-(takes_t[take_id].pos-takes_t[1].pos)
          src_pos = str_mark_table[i][2]-(takes_t[take_id].pos-takes_t[1].pos)+takes_t[take_id].offset
          set_pos = src_pos - takes_t[take_id].offset - ((src_pos - takes_t[take_id].offset) - set_pos) * val
                    
          if last_src_pos ~= nil and last_set_pos ~= nil then
            -- check for negative stretch markers
            if (src_pos - last_src_pos) / (set_pos - last_set_pos ) > 0 then
              reaper.SetTakeStretchMarker(take, -1, set_pos,src_pos)             
              last_src_pos = src_pos
              last_set_pos = set_pos
            end
           else
            reaper.SetTakeStretchMarker(take, -1, set_pos,src_pos)             
            last_src_pos = src_pos
            last_set_pos = set_pos
          end
          
        end
        reaper.SetTakeStretchMarker(take, -1, takes_t[take_id].len)
        
      end
    end
    reaper.UpdateArrange()
  end  

-----------------------------------------------------------------------    
  function F_check_ref_strm(pos, val)
    local diff = 0
    local min_diff = math.huge
    search_area = 0.05
    if str_markers_t == nil or str_markers_t[1] == nil then return pos end
    for i = 1, #str_markers_t[1] do
      diff = math.abs(str_markers_t[1][i][1] - pos)
      if diff < search_area then 
        min_dif_i = i
      end
    end
    
    if min_dif_i == nil then return pos end
    pos = str_markers_t[1][min_dif_i][1] - (pos - str_markers_t[1][min_dif_i][1]) * val
    return pos
  end
  
-----------------------------------------------------------------------   
  function ENGINE_set_stretch_markers2(take_id, str_mark_table, val)
    if str_mark_table == nil then return nil end
    if takes_t ~= nil and takes_t[take_id] ~= nil then
      local take = reaper.SNM_GetMediaItemTakeByGUID(0, takes_t[take_id].guid)
      if take ~= nil then       
        
        reaper.DeleteTakeStretchMarkers(take, 0, #str_mark_table + 1)
       
        reaper.SetTakeStretchMarker(take, -1, 0, takes_t[take_id].offset)
        for i = 1, #str_mark_table do
          
          set_pos = str_mark_table[i][1]-(takes_t[take_id].pos-takes_t[1].pos)
          src_pos = str_mark_table[i][2]-(takes_t[take_id].pos-takes_t[1].pos)+takes_t[take_id].offset
          set_pos = src_pos - takes_t[take_id].offset - ((src_pos - takes_t[take_id].offset) - set_pos)
          
          set_pos = F_check_ref_strm(set_pos, val)
          
          if last_src_pos ~= nil and last_set_pos ~= nil then
            -- check for negative stretch markers
            if (src_pos - last_src_pos) / (set_pos - last_set_pos ) > 0 then
              reaper.SetTakeStretchMarker(take, -1, set_pos,src_pos)             
              last_src_pos = src_pos
              last_set_pos = set_pos
            end
           else
            reaper.SetTakeStretchMarker(take, -1, set_pos,src_pos)             
            last_src_pos = src_pos
            last_set_pos = set_pos
          end
          
        end
        reaper.SetTakeStretchMarker(take, -1, takes_t[take_id].len)
        
      end
    end
    reaper.UpdateArrange()
  end  
  
-----------------------------------------------------------------------   
  function ENGINE_set_positions(take_id, pos_offs_val, val)
    if pos_offs_val == nil then return nil end
    if takes_t ~= nil and takes_t[take_id] ~= nil then
      local take = reaper.SNM_GetMediaItemTakeByGUID(0, takes_t[take_id].guid)
      if take ~= nil then  
        reaper.SetMediaItemTakeInfo_Value(take, 'D_STARTOFFS', 
          takes_t[take_id].offset  + pos_offs_val * val) 
      end
    end
    reaper.UpdateArrange()
  end    

-----------------------------------------------------------------------    
  function ENGINE_set_take_vol_envelopes(take_id, val, val2) 
    if val == nil then val = 0 end
    if val2 == nil then val2 = 0 end
    val = val * 10
    val2 = val2 * 10
    local wind = data.arr_size4 / takes_t[take_id].rate   
    threshold_scaled_min = (10^(-data.threshold4)/20)^data.scaling_pow4
    threshold_scaled_max = (10^(data.threshold4)/20)^data.scaling_pow4
    if takes_t ~= nil and takes_t[take_id] ~= nil then
      local take = reaper.SNM_GetMediaItemTakeByGUID(0, takes_t[take_id].guid)
      if take ~= nil then  
        local envelope = reaper.GetTakeEnvelopeByName(take, "Volume")
        if envelope == nil then
          reaper.MB('Toggle on selected takes volume envelopes', 'Warping Tool', 0)
          return
        end
        local scaling_mode = reaper.GetEnvelopeScalingMode(envelope)
        if envelope ~= nil then
          if takes_arrays[take_id] ~= nil then
            sz_ref = takes_arrays[1].get_alloc()
            local sz = takes_arrays[take_id].get_alloc()
            reaper.DeleteEnvelopePointRange(envelope, 0, takes_t[take_id].len)
            offset = (takes_t[take_id].pos - takes_t[1].pos )
            offset_w = math.floor( offset/ wind)
            for i = 1, sz-offset_w do
              if i+offset_w < sz_ref then
                diff = takes_arrays[take_id][i] - takes_arrays[1][i+offset_w]
                diff_scaled = reaper.ScaleToEnvelopeMode(scaling_mode, diff)
                diff_scaled = 1 - diff_scaled*val
                --F_limit(1 - diff_scaled, threshold_scaled_min,threshold_scaled_max)
                reaper.InsertEnvelopePoint(envelope, 
                  (i-1)*wind - offset,-- time, 
                  diff_scaled-val2,--number value, 
                  0,--integer shape, 0->Linear, 1->Square, 2->Slow start/end, 3->Fast start, 4->Fast end, 5->Bezier
                  0,--number tension, 
                  false,--boolean selected, 
                  true)--optional boolean noSortInOptional)
                end
            end
            reaper.Envelope_SortPoints(envelope)
          end
        end
      end
    end
    reaper.UpdateArrange()
  end  
    
----------------------------------------------------------------------- 
  function GUI_item_display(objects, gui, xywh, reaperarray, is_ref, pointsarray, col_peaks) local arr_size
    
    local x=xywh[1]
    local y=xywh[2]
    local w=xywh[3]
    local h=xywh[4]
      -- draw item back gradient from buf 7
       gfx.a = 0.4
       gfx.blit(7, 1, 0, -- backgr
                0,0,objects.main_w, objects.main_h,
                xywh[1],xywh[2],xywh[3], xywh[4], 0,0)
                
      if reaperarray ~= nil then
        arr_size = reaperarray.get_alloc()
      -- draw envelope  
          gfx.a = 0.7
          F_Get_SSV(gui.color.white, true) 
          local drawscale = 0.9
          gfx.x = x
          gfx.y = y
          for i=1, arr_size-1, 1 do
            local data_t_it = reaperarray[i]*drawscale
            local data_t_it2 = reaperarray[i+1]*drawscale
            local const = 0
            local st_x = x+i*w/arr_size
            local end_x = x+(i+1)*w/arr_size+const              
            if end_x > x+w then end_x = x+w end
            if end_x < x then end_x = x end
            if is_ref then 
              gfx.a = 0.3
              gfx.triangle(st_x,    y+h-h*data_t_it,
                         end_x,y+h-h*data_t_it2,
                         end_x,y+h,
                         st_x,    y+h )
             else
              gfx.a = 0.8
              F_Get_SSV(gui.color.white, true) 
              gfx.triangle(st_x,    y+h*data_t_it,
                           end_x,y+h*data_t_it2,
                           end_x,y,
                           st_x,    y )   
              gfx.a = 0.4
              F_Get_SSV(gui.color[col_peaks])
              gfx.lineto(x+(i+1)*w/arr_size, y-h*data_t_it2)
            end                    
          end -- envelope building
        end
          
          gfx.x,gfx.y = x,y
          gfx.blurto(x+w,y+h)
          gfx.muladdrect(x-1,y,w+2,h,
            1,--mul_r,
            1.0,--mul_g,
            1.0,--mul_b,
            1.5,--mul_a,
            0,--add_r,
            0,--add_g,
            0,--add_b,
            0)--add_a)
             
    -- draw blocks
      if data.current_window == 1 and not is_ref then 
        if pointsarray ~= nil then
          local pointsarr_size = reaperarray.get_alloc(pointsarray)
          -- get blocks
            local bl_t = {}
            for i = 1, pointsarr_size do
              if pointsarray[i] == 1 then bl_t[#bl_t+1] = i end
            end  
          
          gfx.a = 0.4
          
          if #bl_t%2 == 0 then -- ok
            F_Get_SSV(gui.color.green, true)            
            for i = 1, #bl_t, 2 do
              gfx.rect(x + w/pointsarr_size * bl_t[i],
                       y,
                       w/pointsarr_size * (bl_t[i+1]- bl_t[i]),
                       h)
            end
           else
            F_Get_SSV(gui.color.red, true)            
            for i = 1, #bl_t, 2 do
              if bl_t[i+1] == nil then bl_t[i+1] = pointsarr_size end
              gfx.rect(x + w/pointsarr_size * bl_t[i],
                       y,
                       w/pointsarr_size * (bl_t[i+1]- bl_t[i]),
                       h)
            end            
          end
        end
      end
      
      -- draw sep points
        if data.current_window == 2 then 
          if pointsarray ~= nil then
            local pointsarr_size = reaperarray.get_alloc(pointsarray)
            local tri_h = 5
            local tri_w = tri_h
            F_Get_SSV(gui.color.blue, true) 
            gfx.a = 0.4
            for i = 1, pointsarr_size - 1 do
              if pointsarray[i] == 1 then
                gfx.line(x + i*w/pointsarr_size,
                          y,
                          x + i*w/pointsarr_size,
                          y+h - tri_h - 1)
                gfx.triangle(x + i*w/pointsarr_size, y+h-tri_h,
                             x + i*w/pointsarr_size, y+h,
                             x + i*w/pointsarr_size + tri_w, y+h)
              end
            end  
          end --pointsarray ~= nil then
        end --if data.current_window == 2 then 

      -- back
        gfx.a = 0.4
        gfx.blit(3, 1, 0, --backgr
          0,0,objects.main_w, objects.main_h,
          xywh[1],xywh[2],xywh[3],xywh[4], 0,0) 
                    
        
  end
  
        ----------------------------------------------------------------------- 
        function GUI_button(objects, gui, xywh, name, issel, font) local w1_sl_a
          gfx.y,gfx.x = 0,0         
          -- frame
            gfx.a = 1
            F_Get_SSV(gui.color.white, true)
            --gfx.rect(xywh[1],xywh[2],xywh[3], xywh[4]+1, 0 , gui.aa)
            
          -- back
            if issel then gfx.a = 0.8 else gfx.a = 0.2 end
            gfx.blit(3, 1, 0, --backgr
              0,0,objects.main_w, objects.main_h,
              xywh[1],xywh[2],xywh[3],xywh[4], 0,0) 
            
          -- txt              
            
            gfx.setfont(1, gui.fontname, font)
            if issel then
              gfx.a = gui.b_sel_text_alpha
              F_Get_SSV(gui.color.black, true)
             else
              gfx.a = gui.b_sel_text_alpha_unset
              F_Get_SSV(gui.color.white, true)
            end
            local measurestrname = gfx.measurestr(name)
            local x0 = xywh[1] + (xywh[3] - measurestrname)/2
            local y0 = xywh[2] + (xywh[4] - gui.b_sel_fontsize)/2
            gfx.x, gfx.y = x0,y0 
            gfx.drawstr(name)  
        end

        -----------------------------------------------------------------------         
        function GUI_button2(objects, gui, xywh, name, issel, font, text_alpha, color_str) local w1_sl_a
          gfx.y,gfx.x = 0,0         
          -- frame
            gfx.a = 0.1
            F_Get_SSV(gui.color.white, true)
            gfx.rect(xywh[1],xywh[2],xywh[3], xywh[4], 0 , gui.aa)
            
          -- back
            if issel then gfx.a = 0.7 else gfx.a = 0.3 end
            gfx.blit(3, 1, 0, --backgr
              0,0,objects.main_w, objects.main_h,
              xywh[1],xywh[2],xywh[3],xywh[4], 0,0) 
            
          -- txt              
            
            gfx.setfont(1, gui.fontname, font)
            gfx.a = text_alpha
            F_Get_SSV(gui.color[color_str], true)
            local measurestrname = gfx.measurestr(name)
            local x0 = xywh[1] + (xywh[3] - measurestrname)/2
            local y0 = xywh[2] + (xywh[4] - gui.b_sel_fontsize)/2
            gfx.x, gfx.y = x0,y0 
            gfx.drawstr(name)  
        end        

                
        ----------------------------------------------------------------------- 
        function GUI_slider(objects, gui,  xywh, val, alpha, col, takes_t)
          if val == nil then val = 0 end
          gfx.y,gfx.x = 0,0         
          
          -- frame
            gfx.a = 0.1 * alpha
            F_Get_SSV(gui.color.white, true)
            gfx.rect(xywh[1],xywh[2],xywh[3], xywh[4], 1 , gui.aa) 
            
          -- center line
            gfx.a = 0.5 * alpha
            F_Get_SSV(gui.color[col], true)
            local sl_w = 3
            gfx.rect(xywh[1],xywh[2]+ (xywh[4]- sl_w) / 2,xywh[3], sl_w, 1 , gui.aa)  
          
          local handle_w = 20  
          if takes_t ~= nil and takes_t[2] ~= nil then
            -- blit grad   
              local x_offs = xywh[1] + (xywh[3] - handle_w) * val            
              gfx.a = 0.8 * alpha
              gfx.blit(3, 1, math.rad(180), --backgr
                0,0,objects.main_w, objects.main_h,
                x_offs,xywh[2],handle_w/2,xywh[4], 0,0)
              gfx.blit(3, 1, math.rad(0), --backgr
                0,0,objects.main_w, objects.main_h,
                x_offs+handle_w/2,xywh[2],handle_w/2,xywh[4], 0,0) 
            end
              
          -- grid
            local gr_h = 20
            for i = 0, 1, 0.1 do
              gfx.a = 0.3 * alpha
              F_Get_SSV(gui.color.white, true)
              gfx.line(handle_w/2 + xywh[1] + (xywh[3]-handle_w) * i, xywh[2] + xywh[4]/2 - gr_h*i - 1,
                       handle_w/2 + xywh[1] + (xywh[3]-handle_w) * i, xywh[2] + xywh[4]/2 + gr_h*i-1 )
            end            
        end
        
----------------------------------------------------------------------- 
        function GUI_text(xywh, gui, objects, f_name, f_size, name, has_frame)
          gfx.setfont(1, f_name, f_size) 
          local measurestrname = gfx.measurestr(name)
          local x0 = xywh[1] + (xywh[3] - measurestrname)/2
          local y0 = xywh[2]+(xywh[4]-gfx.texth)/2
          
          if has_frame then 
            -- text back
            gfx.a = 0.9
            F_Get_SSV(gui.color.back, true)
            gfx.rect(x0-objects.x_offset,y0,measurestrname+objects.x_offset*2,gfx.texth)  
          end
          
          -- text
          gfx.x, gfx.y = x0,y0 
          gfx.a = 0.9
          F_Get_SSV(gui.color.white, true)
          gfx.drawstr(name)
          
            
        end
                  
-----------------------------------------------------------------------   
  function DEFINE_GUI_buffers()
    local is_sel, b_col
    local objects = DEFINE_objects()
    update_gfx_minor = true
    
    -- GUI variables 
      local gui = {}
      gui.aa = 1
      gfx.mode = 0
      gui.fontname = 'Calibri'
      gui.fontsize = 23      
      if OS == "OSX32" or OS == "OSX64" then gui.fontsize = gui.fontsize - 7 end
      
      -- selector buttons
        gui.b_sel_fontsize = gui.fontsize - 1
        gui.b_sel_text_alpha = 1
        gui.b_sel_text_alpha_unset = 0.7
        
      -- reg buttons
        gui.b_text_alpha = 0.8
        gui.b3_text_alpha = 0.8
      -- takenames
        gui.b_takenames_fontsize = gui.fontsize - 3
      
      gui.color = {['back'] = '51 51 51',
                    ['back2'] = '51 63 56',
                    ['black'] = '0 0 0',
                    ['green'] = '102 255 102',
                    ['blue'] = '127 204 255',
                    ['white'] = '255 255 255',
                    ['red'] = '204 76 51',
                    ['green_dark'] = '102 153 102',
                    ['yellow'] = '200 200 0',
                    ['pink'] = '200 150 200',
                  }           
                       
      gui.window = {'Phrases',
                    'Syllables',
                    'Phase',
                    'RMS',
                    --'Pitch',
                    --'Spectrum',
                    --'Tempo',
                    --'Split',                    
                    'About'}
      
          if data.current_window == 1 then b_col = 'green' end
          if data.current_window == 2 then b_col = 'blue' end  
          if data.current_window == 3 then b_col = 'yellow' end 
          if data.current_window == 4 then b_col = 'pink' end     
    
      ----------------------------------------------------------------------- 
          
    -- data.current_window
      -- 1 phrases items
      -- 2 syllables
      -- 3 phase
      -- 4 volume
      -- 5 about
      
    -- buffers
      -- 1 main back
      -- 2 select windows
      -- 3 button back gradient
      -- 4 wind 1
      -- 5 wait window
      -- 6 envelopes
      -- 7 buffer back
      -- 8 about
        
    -- buf1 background   
      if update_gfx then    
        fdebug('DEFINE_GUI_buffers_1-mainback')  
        gfx.dest = 1
        gfx.setimgdim(1, -1, -1)  
        gfx.setimgdim(1, objects.main_w, objects.main_h) 
        gfx.a = 0.92
        F_Get_SSV(gui.color.back, true)
        gfx.rect(0,0, objects.main_w, objects.main_h,1)
      end
    
    -- buf3 -- buttons back gradient
      if update_gfx then    
        fdebug('DEFINE_GUI_buffers_3-buttons back')  
        gfx.dest = 3
        gfx.setimgdim(3, -1, -1)  
        gfx.setimgdim(3, objects.main_w, objects.main_h)  
           gfx.a = 1
           local r,g,b,a = 0.9,0.9,1,0.6
           gfx.x, gfx.y = 0,0
           local drdx = 0.00001
           local drdy = 0
           local dgdx = 0.0001
           local dgdy = 0.0003     
           local dbdx = 0.00002
           local dbdy = 0
           local dadx = 0.0003
           local dady = 0.0004       
           gfx.gradrect(0,0,objects.main_w, objects.main_h, 
                        r,g,b,a, 
                        drdx, dgdx, dbdx, dadx, 
                        drdy, dgdy, dbdy, dady)
      end  
    
    -- buf2 -- selector buttons
      if update_gfx then    
        fdebug('DEFINE_GUI_buffers_2-common buttons')  
        gfx.dest = 2
        gfx.setimgdim(2, -1, -1)  
        gfx.setimgdim(2, objects.main_w_nav, objects.main_h)
        -- black frame
          gfx.a = 0.9
          F_Get_SSV(gui.color.black, true)
          gfx.rect(0,0,objects.main_w_nav, objects.main_h)
        -- buttons
          for i = 1, objects.b_count do
            if data.current_window == i then is_sel = true else is_sel = false end
            GUI_button(objects, gui, {0, objects.b_h * (i-1), objects.main_w_nav, objects.b_h },
               gui.window[i],is_sel,gui.b_sel_fontsize)
          end
      end
    
    -- buf 4 -- general buttons / sliders / info
      if update_gfx_minor then
        if data.current_window == 1 
        or data.current_window == 2 
        or data.current_window == 3
        or data.current_window == 4
        then
          gfx.dest = 4
          gfx.setimgdim(4, -1, -1)  
          gfx.setimgdim(4, objects.main_w, objects.main_h)
          
          GUI_button2(objects, gui, objects.b_setup,'Settings', mouse.context == 'w1_settings_b', gui.b_sel_fontsize, 0.7, 'white') 
          GUI_button2(objects, gui, objects.b_tips,'Tips / Help', mouse.context == 'w1_tips_b', gui.b_sel_fontsize, 0.7, 'white') 
          
          GUI_button2(objects, gui, objects.b_get, 'Get & Prepare selected takes', 
            mouse.context == 'w1_get_b',    gui.b_sel_fontsize, 0.8, b_col) 
            
          GUI_slider(objects, gui, objects.b_slider, w1_slider, 1,b_col, takes_t)
          if data.current_window == 4  then
            GUI_slider(objects, gui, objects.b_slider2, w2_slider, 1,b_col, takes_t)
          end
          
          if takes_t ~= nil and takes_t[2] ~= nil then
          -- display navigation
            if mouse.context == 'w1_disp' then
              -- take names
              GUI_text(objects.disp_ref_text, gui, objects, 
                  gui.fontname, gui.b_takenames_fontsize, 'Reference: '..takes_t[1].name:sub(0,30), true)              
                local d_name = 'Dub: '
                if takes_t[3] ~= nil then d_name = 'Dubs ('..math.floor(data.current_take-1)..'/'..(#takes_t - 1)..'): ' end
                GUI_text(objects.disp_dub_text, gui, objects, 
                  gui.fontname, gui.b_takenames_fontsize, d_name..takes_t[data.current_take].name:sub(0,30), true)
              end
            -- display cursor position
              gfx.a = 0.9
              F_Get_SSV(gui.color.red, true)
              gfx.line(F_limit(objects.disp[1] + objects.disp[3] / takes_t[1].len * (play_pos - takes_t[1].pos), 
                        objects.disp[1], objects.disp[1] + objects.disp[3]),
                        objects.disp[2],
                       F_limit(objects.disp[1] + objects.disp[3] / takes_t[1].len * (play_pos - takes_t[1].pos), 
                        objects.disp[1], objects.disp[1] + objects.disp[3]),
                        objects.disp[2]+objects.disp[4])
          end
 
        end -- data.current_window  
      end

    -- item envelope gradient
      if update_gfx then 
        if data.current_window == 1 
        or data.current_window == 2 
        or data.current_window == 3
        or data.current_window == 4
        then
          gfx.dest = 7  
          gfx.setimgdim(7, -1, -1)
          gfx.setimgdim(7, objects.main_w, objects.main_h)
          gfx.gradrect(0,0, objects.main_w, objects.main_h, 1,1,1,0.9, 0,0,0,0.00001, 0,0,0,-0.005)
        end --if data.current_window == 1 
      end
      
    -- buf 6 static envelopes buttons
      if update_gfx then 
        if data.current_window == 1 
        or data.current_window == 2
        or data.current_window == 3 
        or data.current_window == 4
        then  
          fdebug('DEFINE_GUI_buffers_6-envelopes')      
          gfx.dest = 6
          gfx.setimgdim(6, -1, -1)  
          gfx.setimgdim(6, objects.main_w, objects.main_h)
          GUI_item_display
            (objects, gui, objects.disp_ref , takes_arrays[1],                 true, 
            takes_points[1], b_col ) 
          GUI_item_display
            (objects, gui, objects.disp_dub , takes_arrays[data.current_take], false ,
            takes_points[data.current_take], b_col)
 
        end --if data.current_window == 1 
      end
    
    
    -- buf 5 wait
      if trig_process ~= nil and trig_process == 1 then
        gfx.dest = 5
        gfx.setimgdim(5, -1, -1)  
        gfx.setimgdim(5, objects.main_w, objects.main_h) 
        gfx.a = 0.93
        F_Get_SSV(gui.color.back, true)
        gfx.rect(0,0, objects.main_w, objects.main_h,1)  
        F_Get_SSV(gui.color.white, true)    
        local str = 'Analyzing takes. Please wait...'
        gfx.setfont(1, gui.fontname, gui.fontsize)
        gfx.x = (objects.main_w - gfx.measurestr(str))/2
        gfx.y = (objects.main_h-gfx.texth)/2
        gfx.drawstr(str)
      end
      
    
    
    if debug_mode == 1 then 
      -- buf19 test
        if update_gfx or update_gfx_minor then    
          gfx.dest = 19
          gfx.setimgdim(19, -1, -1)
          gfx.setimgdim(19, objects.main_w, objects.main_h)
        end
      end
      
    -- about
      if update_gfx then 
        if data.current_window == 5 then
          gfx.dest = 8  
          gfx.setimgdim(8, -1, -1)
          gfx.setimgdim(8, objects.main_w, objects.main_h)

          -- main about
          gfx.a = 0.8
          gfx.setfont(1, gui.fontname, gui.fontsize)
          F_Get_SSV(gui.color.white, true) 
          gfx.x = objects.main_w_nav + objects.x_offset
          gfx.y = objects.y_offset
          gfx.drawstr('Warping Tool\n'..
                         'Lua script for Cockos REAPER\n'..
                         'Written by Michael Pilyavskiy (Russia)\n'..
                         'Version '..vrs)
          
          --[[local w_sep = (objects.main_w - objects.main_w_nav) /3
          gfx.x = objects.main_w_nav + objects.x_offset
          gfx.y = objects.about_links_offs
          gfx.drawstr('Contacts:\n\n')
          F_Get_SSV(gui.color.green, true) 
          gfx.x = objects.main_w_nav + objects.x_offset
          gfx.drawstr('Soundcloud\n'..
                      'PromoDJ\n'..
                      'GitHub\n'..
                      'VK')

          gfx.x = objects.main_w_nav + objects.x_offset + w_sep
          gfx.y = objects.about_links_offs
          F_Get_SSV(gui.color.white, true) 
          gfx.drawstr('Support:\n\n')
          F_Get_SSV(gui.color.green, true) 
          gfx.x = objects.main_w_nav + objects.x_offset + w_sep
          gfx.drawstr('Cockos thread\n'..
                      'RMM thread')
                      
          gfx.x = objects.main_w_nav + objects.x_offset + w_sep*2
          gfx.y = objects.about_links_offs
          F_Get_SSV(gui.color.white, true) 
          gfx.drawstr('Donation:\n\n')
          F_Get_SSV(gui.color.green, true) 
          gfx.x = objects.main_w_nav + objects.x_offset + w_sep*2
          gfx.drawstr('Donate via PayPal')                      
                  ]]    

        end
      end    
    ------------------
    -- common buf20 --
    ------------------
      gfx.dest = 20   
      gfx.setimgdim(20, -1,-1)
      gfx.setimgdim(20, objects.main_w, objects.main_h)
      
      -- common
        gfx.a = 1
        gfx.blit(1, 1, 0, -- backgr
          0,0,objects.main_w, objects.main_h,
          0,0,objects.main_w, objects.main_h, 0,0) 
        gfx.a = 1
        gfx.blit(2, 1, 0, -- buttons
          0,0,objects.main_w, objects.main_h,
          0,0,objects.main_w, objects.main_h, 0,0)           
          
      -- wind 1 phrase
        if data.current_window == 1 
        or data.current_window == 2 
        or data.current_window == 3
        or data.current_window == 4
        then
          gfx.blit(6, 1, 0, -- main window  static
            0,0,objects.main_w, objects.main_h,
            0,0,objects.main_w, objects.main_h, 0,0) 
          gfx.blit(4, 1, 0, -- main window dynamic
            0,0,objects.main_w, objects.main_h,
            0,0,objects.main_w, objects.main_h, 0,0)           
            
          if  trig_process ~= nil and trig_process == 1 then
            gfx.blit(5, 1, 0, --wait
            0,0,objects.main_w, objects.main_h,
            0,0,objects.main_w, objects.main_h, 0,0)   
          end
        end
        
      -- wind 9 about
        if data.current_window == 5 then
          gfx.blit(8, 1, 0, -- main window  static
            0,0,objects.main_w, objects.main_h,
            0,0,objects.main_w, objects.main_h, 0,0) 
        end        
        
        
        gfx.blit(19, 1, 0, --TEST
          0,0,objects.main_w, objects.main_h,
          0,0,objects.main_w, objects.main_h, 0,0)  
              
    update_gfx = false
  end

-----------------------------------------------------------------------    
  function GUI_DRAW()
    local objects = DEFINE_objects()
    --fdebug('GUI_DRAW')
     
    -- common buffer
      gfx.dest = -1   
      gfx.a = 1
      gfx.x,gfx.y = 0,0
      gfx.blit(20, 1, 0, 
        0,0, objects.main_w, objects.main_h,
        0,0, objects.main_w, objects.main_h, 0,0)
        
    gfx.update()
  end
  
-----------------------------------------------------------------------     
  function MOUSE_match(b)
    if mouse.mx > b[1] and mouse.mx < b[1]+b[3]
      and mouse.my > b[2] and mouse.my < b[2]+b[4] then
     return true 
    end 
  end 

----------------------------------------------------------------------- 
  function F_form_menu_item(default_data, name, val, type)
      
    if type == 'ms' then 
      function F_ret_str(x) return math.floor(x*1000)..'ms ' end 
     elseif type == 'db' then 
      function F_ret_str(x) return math.floor(x)..'db ' end 
     elseif type == 'pow' then 
      function F_ret_str(x) return 1/x..'x' end 
    end 
    
    local outstr = '|'..name..': '..
      F_ret_str(data[val])..
      '(Default = '..F_ret_str(default_data[val])..')'
    
    return outstr
  end

-----------------------------------------------------------------------   
  function F_menu_item_response(menuret, id, lim1, lim2, sectionname, keyname, type,val) 
    local retval, num, in_value, ret
      if menuret == id then
      --msg(data[val])
        if type == 'ms' then in_value = tostring(math.floor(data[val]*1000)) 
          elseif type == 'pow' then in_value = tostring(1/data[val])
         else 
          in_value = tostring(math.floor(data[val])) end
          
        ret, retval = reaper.GetUserInputs(sectionname, 1, keyname, in_value)
        if ret and tonumber(retval) ~= nil 
          and tonumber(retval) ~= tonumber(in_value) then
          if type == 'ms' then
            num = F_limit(tonumber(retval), lim1, lim2) / 1000
           elseif type == 'db' then
            num = F_limit(tonumber(retval), lim1, lim2)
           elseif type == 'pow' then
             num = 1 / F_limit(tonumber(retval), lim1, lim2) 
          end
          data[val] = num
          ENGINE_clear_takes_data()
          ENGINE_set_ini(data,config_path)
          ENGINE_get_ini(config_path)
        end
      end  
  end
   
-----------------------------------------------------------------------   
  function GUI_menu_settings1() local menuret 
    local default_data = DEFINE_global_variables()
    
    
    local menuret = gfx.showmenu(
      'Restore defaults for phrases alighment'..
      '|'..F_form_menu_item(default_data, 'Noise threshold',  'threshold1', 'db')..
      F_form_menu_item(default_data, 'Minimal phrase length', 'min_phrase_time1', 'ms')..
      '|'..F_form_menu_item(default_data, 'Search area',      'max_search_area1', 'ms')
      
      )
    
    -- BASIC
    
      if menuret == 1 then -- restore defaults
        data.max_search_area1 = default_data.max_search_area1
        data.min_phrase_time1 = default_data.min_phrase_time1
        data.threshold1 = default_data.threshold1
        ENGINE_set_ini(data, config_path)
        ENGINE_clear_takes_data() 
      end
      
      F_menu_item_response(menuret, 2, -120, -20, 'Phrases alighnment','Noise threshold', 'db', 'threshold1')  
      F_menu_item_response(menuret, 3, 300, 10000, 'Phrases alighnment','Min. phrase length', 'ms', 'min_phrase_time1')    
      F_menu_item_response(menuret, 4, 100, 2000, 'Phrases alighnment','Search area', 'ms', 'max_search_area1')
      
  end

-----------------------------------------------------------------------   
  function GUI_menu_settings2() local menuret 
    local default_data = DEFINE_global_variables()
    
    
    local menuret = gfx.showmenu(
      'Restore defaults for syllables alighment'..
      '|'..F_form_menu_item(default_data, 'Noise threshold','threshold2', 'db')
      ..F_form_menu_item(default_data, 'Rise area gain','threshold_rise2', 'db')
      ..F_form_menu_item(default_data, 'Rise area','rise_area2', 'ms')
      --..F_form_menu_item(default_data, 'Filter area','filter_area2', 'ms')
      ..F_form_menu_item(default_data, 'Scaling','scaling_pow2', 'pow')
      ..'|'..F_form_menu_item(default_data, 'Search area','max_search_area2', 'ms')
      
      )
    
    -- BASIC
    
      if menuret == 1 then -- restore defaults
        data.threshold2 = default_data.threshold2
        data.threshold_rise2 = default_data.threshold_rise2     
        data.rise_area2 = default_data.rise_area2
        data.filter_area2 = default_data.max_search_area2 / 2 --default_data.filter_area2
        data.max_search_area2 = default_data.max_search_area2
        data.scaling_pow2 = default_data.scaling_pow2
        ENGINE_clear_takes_data() 
        ENGINE_set_ini(data,config_path)
      end
      
      F_menu_item_response(menuret, 2, -120, -20, 'Syllables alighnment','Noise threshold', 'db', 'threshold2')  
      F_menu_item_response(menuret, 3, 10, 120, 'Syllables alighnment','Rise area threshold', 'db', 'threshold_rise2')
      F_menu_item_response(menuret, 4, 10, 500, 'Syllables alighnment','Rise area', 'ms', 'rise_area2')  
      --F_menu_item_response(menuret, 5, 10, 500, 'Syllables alighnment','Filter area', 'ms', 'filter_area2')
      F_menu_item_response(menuret, 5, 1, 8, 'Syllables alighnment', 'Scaling', 'pow', 'scaling_pow2')    
      F_menu_item_response(menuret, 6, 10, 500, 'Syllables alighnment','Search area', 'ms', 'max_search_area2')  
      
  end

-----------------------------------------------------------------------   
  function GUI_menu_settings3() local menuret 
    local default_data = DEFINE_global_variables()
    
    local menuret = gfx.showmenu(
      'Restore defaults for phase alighment'..
      '|'..F_form_menu_item(default_data, 'Window size','window3', 'ms')      
      )
    
      if menuret == 1 then -- restore defaults
        data.window3 = default_data.window3        
        ENGINE_clear_takes_data() 
        ENGINE_set_ini(data,config_path)
      end
      
      F_menu_item_response(menuret, 2, 10, 300, 'Phase alighnment','Window size', 'ms', 'window3')  
      
  end
    
-----------------------------------------------------------------------   
  function GUI_menu_settings4() local menuret 
    local default_data = DEFINE_global_variables()
    
    local menuret = gfx.showmenu(
      '#Restore defaults for RMS alighment'..
      ''..F_form_menu_item(default_data, '#Maximum difference','threshold4', 'db')  
      )
    
      if menuret == 1 then -- restore defaults
        data.threshold4 = default_data.threshold4        
        ENGINE_clear_takes_data() 
        ENGINE_set_ini(data,config_path)
      end
      
      F_menu_item_response(menuret, 2, 1, 20, 'RMS alighnment','Maximum difference', 'db', 'threshold4')  
      
  end
      
-----------------------------------------------------------------------    
  function GUI_menu_display(takes_t)
  
              local takesstr = ''
              for i = 1, #takes_t do
                if i == 1 then
                  takesstr = takesstr..'Reference: '..takes_t[i].name..'||'
                 else
                  takesstr = takesstr..'Dub #'..(i-1)..': '..takes_t[i].name..'|'
                end
              end
              
              local ret_menu = gfx.showmenu(takesstr)
              if ret_menu >1 then 
                data.current_take = ret_menu
                update_gfx = true
              end 
  end

-----------------------------------------------------------------------     
  function ENGINE_clear_takes_data() 
        -- clear data
          takes_t = {}
          takes_arrays = {}
          takes_points = {}
          str_markers_t = {}
  end
  
-----------------------------------------------------------------------   
  function MOUSE_get()
    local objects = DEFINE_objects()
    local ret -- ENGINE_prepare_takes response
    mouse.mx = gfx.mouse_x
    mouse.my = gfx.mouse_y
    mouse.LMB_state = gfx.mouse_cap&1 == 1 
    mouse.RMB_state = gfx.mouse_cap&2 == 2 
    mouse.MMB_state = gfx.mouse_cap&64 == 64
    mouse.LMB_state_doubleclick = false
    mouse.Ctrl_LMB_state = gfx.mouse_cap&5 == 5 
    mouse.Ctrl_state = gfx.mouse_cap&4 == 4 
    mouse.Alt_state = gfx.mouse_cap&17 == 17 -- alt + LB
    mouse.wheel = gfx.mouse_wheel
    if not mouse.LMB_state  then mouse.context = nil end
    
    if mouse.last_LMB_state and not mouse.LMB_state then mouse.last_touched = nil end
    
    -- change windows
      if mouse.LMB_state and not mouse.last_LMB_state 
       and MOUSE_match({0,0, objects.main_w_nav, objects.main_h}) then
        data.current_window = math.ceil(objects.b_count * mouse.my / objects.main_h)
        ENGINE_set_ini(data, config_path)
        update_gfx = true
        
        ENGINE_clear_takes_data()
      end
    
    -- get takes
      if data.current_window == 1 
      or data.current_window == 2 
      or data.current_window == 3 
      or data.current_window == 4 
      then
        -- display
          if MOUSE_match(objects.disp) then mouse.context = 'w1_disp' end
          if takes_t~= nil and takes_t[2] ~= nil then 
            if MOUSE_match(objects.disp) and mouse.LMB_state and not mouse.last_LMB_state then
              gfx.x = mouse.mx
              gfx.y = mouse.my
              GUI_menu_display(takes_t)
            end
          end
          
        -- settings button 
          if MOUSE_match(objects.b_setup) then mouse.context = 'w1_settings_b' end
          if MOUSE_match(objects.b_setup) 
            and mouse.LMB_state 
            and not mouse.last_LMB_state 
            then            
            gfx.x = mouse.mx
            gfx.y = mouse.my
            _G['GUI_menu_settings'..data.current_window]()
          end
          
        -- Tips button 
          if MOUSE_match(objects.b_tips) then mouse.context = 'w1_tips_b' end
          if MOUSE_match(objects.b_tips) 
            and mouse.LMB_state 
            and not mouse.last_LMB_state 
            then
            reaper.MB(tips[data.current_window].text, tips[data.current_window].title, 0)
          end          
                
        -- get button 
          if MOUSE_match(objects.b_get) then mouse.context = 'w1_get_b' end
          if MOUSE_match(objects.b_get) 
            and mouse.LMB_state 
            and not mouse.last_LMB_state 
           then
            if trig_process == nil then trig_process = 1 end
            
          end
          
          if trig_process ~= nil and trig_process == 1 and not mouse.LMB_state then 
            ret = ENGINE_prepare_takes()
            if ret == 1 then
              takes_t = ENGINE_get_takes()
              if #takes_t ~= 1 and #takes_t >= 2 then
                str_markers_t = {} 
                pos_offsets = {}  
                rates = {}        
                for i = 1, #takes_t do 
                
                  if data.current_window == 1
                  or data.current_window == 2 
                   then
                    takes_arrays[i] = ENGINE_get_take_data(i, data.scaling_pow1) 
                    --if i > 1 then
                      takes_points[i] = 
                        _G['ENGINE_get_take_data_points'..data.current_window]
                          (takes_arrays[i],data.global_window_sec)
                      str_markers_t[i] = 
                        _G['ENGINE_compare_data'..data.current_window]
                          (takes_arrays[1], takes_arrays[i], takes_points[i],
                          data.global_window_sec )
                    --end
                  end
                  
                  if data.current_window == 3 -- phase
                    then
                    takes_phase_arrays[i],rates[i] = ENGINE_get_take_data3(i, data.scaling_pow3)
                    if i > 1 then
                      pos_offsets[i] = _G['ENGINE_compare_data'..data.current_window]
                          (takes_phase_arrays[1], takes_phase_arrays[i],rates[i])
                    end
                  end 
                  if data.current_window == 4 -- phase
                    then
                    takes_arrays[i] = ENGINE_get_take_data4(i, data.scaling_pow4) 
                  end
                end
              end
            end 
            update_gfx = true 
            trig_process = nil
          end
          
          
        -- strength / apply slider 1 
          if takes_t ~= nil then 
            if MOUSE_match(objects.b_slider)
              and mouse.LMB_state 
              and not mouse.last_LMB_state then 
                mouse.context = 'w1_slider' 
            end
            if mouse.context == 'w1_slider' then
              w1_slider = F_limit((mouse.mx - objects.b_slider[1]) / objects.b_slider[3],0,1 )
              --msg(w1_slider)
              
              if data.current_window == 1
                or data.current_window == 2 
               then
                for i = 2, #takes_t do 
                  ENGINE_set_stretch_markers(i, str_markers_t[i], w1_slider)
                end
              end
              
              if data.current_window == 3 then
                for i = 2, #takes_t do 
                  ENGINE_set_positions(i, pos_offsets[i], w1_slider)
                end
              end
              
              if data.current_window == 4 then
                for i = 2, #takes_t do 
                  ENGINE_set_take_vol_envelopes(i, w1_slider,w2_slider)
                end
              end
              
            end
          end
          
        -- strength / apply slider 2 
          if takes_t ~= nil then 
            if MOUSE_match(objects.b_slider2)
              and mouse.LMB_state 
              and not mouse.last_LMB_state then 
                mouse.context = 'w2_slider' 
            end
            if mouse.context == 'w2_slider' then
              w2_slider = 
                F_limit((mouse.mx - objects.b_slider2[1]) / objects.b_slider2[3],0,1 )
              
              if data.current_window == 4 
               then
                for i = 2, #takes_t do 
                  ENGINE_set_take_vol_envelopes(i, w1_slider,w2_slider)
                end
              end
            end
          end         
             
          
      end -- window 1 macro alighn
      
                  
    
    mouse.last_LMB_state = mouse.LMB_state  
    mouse.last_RMB_state = mouse.RMB_state
    mouse.last_MMB_state = mouse.MMB_state 
    mouse.last_Ctrl_LMB_state = mouse.Ctrl_LMB_state
    mouse.last_Ctrl_state = mouse.Ctrl_state
    mouse.last_wheel = mouse.wheel      
  end
  
----------------------------------------------------------------------- 
  function MAIN_defer()
    DEFINE_dynamic_variables()
    DEFINE_GUI_buffers()
    GUI_DRAW()
    MOUSE_get()
    if char == 27 then MAIN_exit() end  --escape
    if char == 32 then reaper.Main_OnCommandEx(40044, 0,0) end -- space-> transport play   
    if char ~= -1 then reaper.defer(MAIN_defer) else MAIN_exit() end
  end 
  
  function DEFINE_objects()
    -- GUI global
      local objects = {}
      objects.x_offset = 10
      objects.y_offset = 5
      objects.b_count = 5
      objects.b_h = 70
      objects.main_w = 600
      objects.main_h = objects.b_count * objects.b_h
      objects.main_w_nav = 130 -- width navigation zone
      objects.takes_name_h = 70 -- display H
      objects.takes_name_h2 = 20 -- display names
      objects.slider_h = 40
      objects.get_b_h = 40
      objects.b_setup_h = 20
      objects.tips_w = 100
      
    -- GUI main window
      
      objects.b_setup = {objects.main_w_nav + objects.x_offset,
                         objects.y_offset,
                         objects.main_w - (objects.main_w_nav + 2.5*objects.x_offset + objects.tips_w),
                         objects.b_setup_h}
      objects.b_tips = {objects.main_w - objects.x_offset - objects.tips_w,
                         objects.y_offset,
                         objects.tips_w,
                         objects.b_setup_h}                         
                         
                         
      objects.b_get = {objects.main_w_nav + objects.x_offset, objects.y_offset*2+objects.b_setup_h,
                          objects.main_w - objects.main_w_nav - 2 * objects.x_offset, 
                          objects.get_b_h}     
      objects.disp_ref = {objects.main_w_nav + objects.x_offset, 
                          objects.get_b_h + 3*objects.y_offset+objects.b_setup_h,
                          objects.main_w - objects.main_w_nav - 2 * objects.x_offset, 
                          objects.takes_name_h}
      objects.disp_ref_text = {objects.disp_ref[1],
                                objects.disp_ref[2]+objects.disp_ref[4]-objects.takes_name_h2,
                                objects.disp_ref[3],
                                objects.takes_name_h2}
      objects.disp_dub = {objects.main_w_nav + objects.x_offset, 
                        objects.get_b_h + objects.takes_name_h + objects.y_offset*3+objects.b_setup_h,
                       objects.main_w - objects.main_w_nav - 2 * objects.x_offset, 
                       objects.takes_name_h}    
      objects.disp_dub_text = {objects.disp_dub[1],
                                objects.disp_dub[2],
                                objects.disp_dub[3],
                                objects.takes_name_h2}               
      objects.disp = {objects.main_w_nav + objects.x_offset, 
                        objects.get_b_h + objects.y_offset*3+objects.b_setup_h,
                       objects.main_w - objects.main_w_nav - 2 * objects.x_offset, 
                       objects.takes_name_h*2}
      objects.b_slider = {objects.main_w_nav + objects.x_offset, 
                        2*objects.takes_name_h + 4*objects.y_offset+objects.get_b_h + objects.b_setup_h,
                          objects.main_w - objects.main_w_nav - 2 * objects.x_offset, 
                          objects.slider_h} 
      objects.b_slider2 = {objects.main_w_nav + objects.x_offset, 
                          2*objects.takes_name_h + 5*objects.y_offset+objects.get_b_h + objects.b_setup_h + objects.slider_h,
                          objects.main_w - objects.main_w_nav - 2 * objects.x_offset, 
                          objects.slider_h}                         
    return objects
  end
    
-----------------------------------------------------------------------   
  function F_ret_ini_val2(content, ini_key, var, default_data)  
    local out_str ,str
    for line in content:gmatch("[^\r\n]+") do
      str = line:match(ini_key..'=.*')
      if str ~= nil then
        out_str = str:gsub(ini_key..'=','')
        break
      end
    end
    if out_str == nil or tonumber(out_str) == nil then out_str = default_data[var] end
    data[var] = tonumber(out_str)
  end
  
-----------------------------------------------------------------------  
  function ENGINE_set_ini(data, config_path)
    
    -------- LINK TO INI
    outstr = '[Global_variables]\n'..
      'current_window='..data.current_window..'\n'..
      
      '[wind1-phrase]\n'..
      'scaling_pow1='..data.scaling_pow1..'\n'..
      'threshold1='..data.threshold1..'\n'..
      'min_phrase_time1='..data.min_phrase_time1..'\n'..
      'max_search_area1='..data.max_search_area1..'\n'..
      
      '[wind2-syl]\n'..
      'threshold2='..data.threshold2..'\n'..
      'threshold_rise2='..data.threshold_rise2..'\n'..      
      'scaling_pow2='..data.scaling_pow2..'\n'..
      'rise_area2='..data.rise_area2..'\n'..
      'filter_area2='..(data.max_search_area2 / 2)..'\n'..-- data.filter_area2..'\n'..
      'max_search_area2='..data.max_search_area2..'\n'..
      
      '[wind3-phase]\n'..
      'scaling_pow2='..data.scaling_pow3..'\n'..
      'window3='..data.window3..'\n'..
      
      '[wind4-vol_pan]\n'..
      'scaling_pow2='..data.scaling_pow4..'\n'..
      'threshold4='..data.threshold4
      
    fdebug('ENGINE_set_ini >>>')    
    fdebug(outstr)
    
    local file = io.open(config_path,'w')
    file:write(outstr)
    file:close()
    
    update_gfx = true
  end   
       
-----------------------------------------------------------------------  
  function ENGINE_get_ini(config_path) --local ret, str
    update_gfx = true
    local file = io.open(config_path, 'r')
    content = file:read('*all')
    file:close()

    fdebug('ENGINE_get_ini <<< ') 
    fdebug(content)
        
    local default_data = DEFINE_global_variables()

    F_ret_ini_val2(content, 'current_window', 'current_window', default_data)
    
    F_ret_ini_val2(content, 'threshold1', 'threshold1', default_data)
    F_ret_ini_val2(content, 'scaling_pow1', 'scaling_pow1', default_data) 
    F_ret_ini_val2(content, 'min_phrase_time1', 'min_phrase_time1', default_data) 
    F_ret_ini_val2(content, 'max_search_area1', 'max_search_area1', default_data)    
    
    F_ret_ini_val2(content, 'threshold2', 'threshold2', default_data)
    F_ret_ini_val2(content, 'threshold_rise2', 'threshold_rise2', default_data) 
    F_ret_ini_val2(content, 'scaling_pow2', 'scaling_pow2', default_data) 
    F_ret_ini_val2(content, 'rise_area2', 'rise_area2', default_data) 
    F_ret_ini_val2(content, 'filter_area2', 'filter_area2', default_data)
    F_ret_ini_val2(content, 'max_search_area2', 'max_search_area2', default_data) 
    
    F_ret_ini_val2(content, 'scaling_pow3', 'scaling_pow3', default_data) 
    F_ret_ini_val2(content, 'window3', 'window3', default_data) 
    
    F_ret_ini_val2(content, 'scaling_pow4', 'scaling_pow4', default_data) 
    F_ret_ini_val2(content, 'threshold4', 'threshold4', default_data)
    
  end
  
-----------------------------------------------------------------------
  function DEFINE_global_variables()
    
    
    takes_arrays = {}
    takes_points = {}
    takes_phase_arrays = {}
    
    -------- DEFINE VARS
    local data = {}
    data.current_window = 1 -- align items on start
    data.current_take = 2
    
    -- phrase alighn -- wind 1 settings
      data.scaling_pow1 = 0.25 -- pow for out_t
      data.threshold1 = -50 -- rise to add block
      data.min_phrase_time1 = 0.7 -- min time for phrase
      data.max_search_area1 = 0.3 -- search area

    -- syl alighn -- wind 2 settings
      data.threshold2 = -30 -- thld to add point
      data.threshold_rise2 = 50 -- thld of rise area
      data.scaling_pow2 = 0.25 -- pow for out_t
      data.rise_area2 = 0.1 -- for rise search
      data.max_search_area2 = 0.1 -- search best fit for syllable
      data.filter_area2 = data.max_search_area2 / 2 --0.05 -- filter closer points
      
      
    -- phase
      data.scaling_pow3 = 1 -- pow for out_t
      data.window3 = 0.1
      
    -- vol
      data.scaling_pow4 = 1 -- pow for out_t
      data.arr_size4 = 1024 -- calc window block by / smplsrate
      data.threshold4 = 5 -- max difference
      
    return data
  end

-----------------------------------------------------------------------    
  function MAIN_search_ini(data)
    fdebug('MAIN_search_ini') 
    local reapath = reaper.GetResourcePath():gsub('\\','/')
    config_path = reapath..'/Scripts/mpl_Warping Tool.ini'
    local file = io.open(config_path, 'r')
    if file == nil then ENGINE_set_ini(data, config_path) else 
      ENGINE_get_ini(config_path) 
      file:close()
    end    
  end
      
-----------------------------------------------------------------------  

  debug_mode = 0
  if debug_mode == 1 then msg("") end    
  mouse = {}
  data = DEFINE_global_variables()
  MAIN_search_ini(data)
  objects = DEFINE_objects()
  gfx.init("mpl Warping tool // "..vrs..' beta', objects.main_w, objects.main_h, 0)
  objects = nil
  update_gfx = true
  MAIN_defer()
  
 ---------------------------------------------- 
 tips = {}
 tips[1] = {}
 tips[1].title = 'Phrases alignment tips'
 tips[1].text =
 [[
This mode is useful when you have recorded a lot of back vocals, which have only 2-5 words, not the whole duplicate of couplet or chorus. 
 
 Your simplified what-to-do algorythm is:
 1) Select takes (upper is reference),
 2) Click 'Get & Prepare',
 3) Go drink cofee,
 4) Move slider.
 
 You may ask "WTF <prepare takes> means?". That means:
 1) Clear all stretch markers from selected takes,
 2) Set selected takes takerate to 1.0x,
 3) Check for all takes on reference track is glued,
 4) Crop dub takes positions/lengths to reference take.
 
 OK you get unexpected results, nothing works or works bad.
 Don`t panic, impossible to make it universal for everyone!
 I recommend you to:
 1) Clear silence in takes by any noisegate plugin and do apply FX or glue it (simple putting it on FX chain does NOT affect!),
 2) Organize (glue) your dubs takes on same tracks,
 3) If it still not helps, you can try to change detection settings.
 ]]
 ----------------------------------------------
 tips[2] = {}
 tips[2].title = 'Syllables alignment tips'
 tips[2].text =  [[
This mode is useful when you have recorded whole back vocal of couplet or chorus. 
 
 Your simplified what-to-do algorythm is:
 1) Select takes (upper is reference),
 2) Click 'Get & Prepare',
 3) Go drink cofee,
 4) Move slider.
 
 You may ask "WTF <prepare takes> means?". That means:
 1) Clear all stretch markers from selected takes,
 2) Set selected takes takerate to 1.0x,
 3) Check for all takes on reference track is glued,
 4) Crop dub takes positions/lengths to reference take.
 
 OK you get unexpected results, nothing works or works bad.
 Don`t panic, impossible to make it universal for everyone!
 I recommend you to:
 1) Clear silence in takes by any noisegate plugin and do apply FX or glue it (simple putting it on FX chain does NOT affect!),
 2) Organize (glue) your dubs takes on same tracks,
 3) If it still not helps, you can try to change detection settings.
 ]]
 
 tips[3] = {}
 tips[3].title = 'Phase alignment tips'
 tips[3].text = 
 [[
 This mode is useful when you just wants to aligh takes in time really a bit. 
 It analyzes first few samples and find best fit for them.
 
  Your simplified what-to-do algorythm is:
  1) Select takes (upper is reference),
  2) Click 'Get & Prepare'
  3) Move slider.
  
  "Prepare takes" means:
  1) Clear all stretch markers from selected takes,
  2) Set selected takes takerate to 1.0x,
  3) Check for all takes on reference track is glued,
  4) Crop dub takes positions/lengths to reference take,
  5) Aligh position of items.
  ]]
  
 tips[4] = {}
 tips[4].title = 'RMS alignment tips'
 tips[4].text = 
 [[
 In this mode script calculates gain difference beetween takes RMS values (not peaks!) and apply it as point in take volume envelope.
 
 Note, samples calculated from source (before stretch markers, existed takes envelope etc).  That means, to get proper results (or you already alighned takes in time by this tool), glue takes before using before volume alighnment.
 
 I didn`t found how to enable takes volume envelopes by ReaScript so do it manually.
 
 After you glued takes and enabled takes envelopes:
  1) Select takes (upper is reference),
  2) Click 'Get & Prepare'
  3) Move slider1 - scaling
  4) Move slider2 - offset.
  
  "Prepare takes" means:
  1) Clear all stretch markers from selected takes,
  2) Set selected takes takerate to 1.0x,
  3) Check for all takes on reference track is glued,
  4) Crop dub takes positions/lengths to reference take.
  ]]  
