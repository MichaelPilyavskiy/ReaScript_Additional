  --test find take BPM
  
  for key in pairs(reaper) do _G[key]=reaper[key]  end
  
  
----------------------------------------------------------------
  function GetRMS_t(take, wind)
    if not take or TakeIsMIDI(take) then return end
    local src = GetMediaItemTake_Source( take )
    local src_len = ({ GetMediaSourceLength( src )})[1]
    local accessor = CreateTakeAudioAccessor(take)
    --numch = GetMediaSourceNumChannels(src)
    local rate = GetMediaSourceSampleRate(src) 
    local buf_size = math.floor(wind*rate)    
    --buf_size =2^ math.floor(math.log(buf_size, 2)+1)
    local step = buf_size/rate
    local sum_t = {}
    local fft_t = {}
    -- read whole file samples
    for read_pos = 0, src_len, step do 
      local buffer = new_array(buf_size)
      GetAudioAccessorSamples(
        accessor , --AudioAccessor
        rate, -- samplerate
        1,--aa.numch, -- numchannels
        read_pos, -- starttime_sec
        buf_size, -- numsamplesperchannel
        buffer) --samplebuffer
       
      -- Get RMS sum in defined range
        local buffer_com_t = buffer.table(1, buf_size, true)
        local sum_com = 0
        for i = 1, buf_size do sum_com = sum_com + math.abs(buffer_com_t[i]) end    
        table.insert(sum_t, sum_com)   
        buffer.clear()                  
    end          
    DestroyAudioAccessor(accessor) 
    return sum_t
  end
----------------------------------------------------------------  
  function drawt(t) 
    for i = 1, #t do gfx.lineto( i*gfx.w/#t, gfx.h-gfx.h *t[i]) end
  end  
----------------------------------------------------------------  
  function GetDerivative(t, order)
    local cnt = 0
    local out_t = t
    repeat
      local der_t = {0}
      for i = 2, #out_t do der_t[i] = math.abs(out_t[i]-out_t[i-1]) end
      out_t = der_t
      cnt = cnt + 1
    until cnt >= order
    return out_t
  end
  ----------------------------------------------------------------  
  function SmoothTable(t, fact)
    for i = 2, #t do t[i]= t[i] - (t[i] - t[i-1])*fact   end
    return t 
  end
  ----------------------------------------------------------------  
  function NormalizeTable(t)
      local max_com = 0
      for i =1, #t do max_com = math.max(max_com, t[i]) end
      local com_mult = 1/max_com      
      for i =1, #t do t[i]= t[i]*com_mult  end    
      return t,max_com
  end
----------------------------------------------------------------  
  function GetPoints(dt,threshold, filter_window)
    local points = {0}
    for i = 2, #dt do 
      if dt[i]-dt[i-1] > threshold then 
        points[i] = 1
        if last_point_id and i - last_point_id < filter_window then  points[i] = 0 end
        last_point_id = i 
       else 
        points[i] = 0 
      end 
    end
    return points
  end
  ----------------------------------------------------------------  
  function ScaleTable(t, pow)
    for i = 1, #t do t[i] = t[i]^pow end
    return t
  end
  ----------------------------------------------------------------  
  function GetPointsDiff(points_t)
    local diff_t = {}
    local peak_id_diff = 0
    for i = 1, #points_t do
      diff_t[i] = peak_id_diff
      if points_t[i] == 1 then
        if last_peak_id then 
          peak_id_diff = i - last_peak_id
        end
        last_peak_id = i
      end
    end      
    return diff_t
  end
  ----------------------------------------------------------------
  function GetTimeDiffAverage(points_diff_t)
    local rms_time_sum = 0
    for i = 1, #points_diff_t do rms_time_sum = rms_time_sum + points_diff_t[i] end
    rms_time_sum = rms_time_sum / #points_diff_t
    local rms_time_sum2,cnt = 0,0
    for i = 1, #points_diff_t do 
      if math.abs(points_diff_t[i] - rms_time_sum) < rms_time_sum/2 then rms_time_sum2 = rms_time_sum2 + points_diff_t[i] cnt = cnt +1 end
    end
    rms_time_sum2 = rms_time_sum2 / cnt
    return rms_time_sum2
  end
----------------------------------------------------------------  
  local item = GetSelectedMediaItem(0,0)
  local take = GetActiveTake(item)
  
  wind = 0.01
  smooth_rms = 0.5
  points_threshold = 0.2
  deriative_order = 1
  rms_scaling = 2
  filter_window = 10-- filter closer points
  
  local rms = GetRMS_t(take, wind)
  rms = ScaleTable(rms, rms_scaling)
  rms = NormalizeTable(rms)
  rms = SmoothTable(rms, smooth_rms)    
  local der_t = GetDerivative(rms,deriative_order)
  der_t = NormalizeTable(der_t)
  der_t = ScaleTable(der_t, 1)
  local points_t = GetPoints(der_t, points_threshold, filter_window)
  local points_dif_t = GetPointsDiff(points_t)
  TimeDiffAv = GetTimeDiffAverage(points_dif_t)
  BPM = 60 / (TimeDiffAv * wind)
  points_dif_t, max_val = NormalizeTable(points_dif_t)
  BPM_graph = TimeDiffAv * (1/max_val)
----------------------------------------------------------------   
 
  gfx.init('',570,100,0,500,10)
  gfx.set(1,1,1,0.3) 
  drawt(rms) 
  gfx.set(0.2,1,0.2,0.2)
  drawt(der_t)
  gfx.set(1,0.2,0.2,0.3)
  drawt(points_t)
  gfx.set(0.2,0.2,1,1)
  drawt(points_dif_t)
  gfx.x,gfx.y = 10,10
  gfx.drawstr(BPM)
  gfx.set(0.2,0.9,1,1)
  gfx.line(0, gfx.h-BPM_graph*gfx.h, gfx.w, gfx.h-BPM_graph*gfx.h)
