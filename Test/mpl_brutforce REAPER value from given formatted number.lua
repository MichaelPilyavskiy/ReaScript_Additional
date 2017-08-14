-- test brutforce REAPER value from given formatted number

  local scr_nm = 'test MPL brutforce reaper val'
  for key in pairs(reaper) do _G[key]=reaper[key]  end 
  -------------------------------------------------------  
  function GetFormattedParamInternal(tr, fx, param, val)
    local param_n
    if val then TrackFX_SetParamNormalized( tr, fx, param, val ) end
    local _, buf = TrackFX_GetFormattedParamValue( tr , fx, param, '' )
    local param_str = buf:match('%-[%d%.]+') or buf:match('[%d%.]+')
    if param_str then param_n = tonumber(param_str) end
    return param_n
  end
  ------------------------------------------------------- 
  function BF(find , pow, tr, fx, param) 
    if not tonumber(find) then return end
    local find =  tonumber(find)
    local BF_s, BF_e,closer_out_val = 0, 1
    for step_pow = -1, pow, -1 do
      local last_param_n
      for val = BF_s, BF_e, 10^step_pow do  
        local param_n = GetFormattedParamInternal(tr , fx, param, val)
        if not last_param_n and find <= param_n  then return val end
        if last_param_n and find > last_param_n and find <= param_n then 
          BF_s = val - 10^step_pow
          BF_e = val
          closer_out_val = val
          break
        end
        last_param_n = param_n
      end
      if not closer_out_val then return 1 end
    end
    return closer_out_val
  end
  -------------------------------------------------------
  function GetStringTable(tr, fx, param, steps)
    local t = {}
    local last_str
    for val = 0, 1, 1/steps do
      TrackFX_SetParamNormalized( tr, fx, param, val )
      local str = ({TrackFX_GetFormattedParamValue( tr , fx, param, '' )})[2]
      if not last_str or last_str ~= str then t[#t+1] = {str = str, val=val} end
      last_str = str
    end
    return t
  end
  -------------------------------------------------------
  function main() local ReaperVal
    local retval, tracknum, fx, param = GetLastTouchedFX()
    if not retval then return end
    local tr = CSurf_TrackFromID( tracknum, false )    
    local param_rpr_val = TrackFX_GetParamNormalized( tr, fx, param )
    local cur_param = GetFormattedParamInternal(tr , fx, param)
    if cur_param then
    
      -- digits
      local retval, find = reaper.GetUserInputs( scr_nm, 1, 'value', cur_param )
      if retval then 
        ReaperVal = BF(find, -14, tr, fx, param)
        if not ReaperVal then ReaperVal = param_rpr_val end
        TrackFX_SetParamNormalized( tr, fx, param, ReaperVal )
      end
      
     else
     
      -- txt
      local retval, find = reaper.GetUserInputs( scr_nm, 1, 'value', ({TrackFX_GetFormattedParamValue( tr , fx, param, '' )})[2] )
      if retval then 
        local t_val = GetStringTable(tr, fx, param, 127 )
        for i = 1, #t_val do if t_val[i].str:lower():find(find:lower()) then ReaperVal = t_val[i].val break end end
        if not ReaperVal then ReaperVal = param_rpr_val end
        TrackFX_SetParamNormalized( tr, fx, param, ReaperVal )      
      end
      
    end
  end
  ---------------------------------------------------------
  
  main()
