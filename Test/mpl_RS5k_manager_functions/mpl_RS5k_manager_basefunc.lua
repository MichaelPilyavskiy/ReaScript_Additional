-- @description RS5k_manager_basefunc 
-- @author MPL
-- @website http://forum.cockos.com/member.php?u=70694
-- @noindex

  ---------------------------------------------------
  function ExtState_Load(conf)
    local def = ExtState_Def()
    for key in pairs(def) do 
      local es_str = GetExtState(def.ES_key, key)
      if es_str == '' then conf[key] = def[key] else conf[key] = tonumber(es_str) or es_str end
    end    
  end  
  ---------------------------------------------------
  function ExtState_Save(conf)
    local ret 
    ret, conf.wind_x, conf.wind_y, conf.wind_w, conf.wind_h = gfx.dock(-1, 0,0,0,0)
    for k,v in spairs(conf, function(t,a,b) return b:lower() > a:lower() end) do SetExtState(conf.ES_key, k, conf[k], true) end   
  end
  ---------------------------------------------------
  function lim(val, min,max) --local min,max 
    if not min or not max then min, max = 0,1 end 
    return math.max(min,  math.min(val, max) ) 
  end
  ---------------------------------------------------
  function spairs(t, order) --http://stackoverflow.com/questions/15706270/sort-a-table-in-lua
    local keys = {}
    for k in pairs(t) do keys[#keys+1] = k end
    if order then table.sort(keys, function(a,b) return order(t, a, b) end)  else  table.sort(keys) end
    local i = 0
    return function()
              i = i + 1
              if keys[i] then return keys[i], t[keys[i]] end
           end
  end
  ---------------------------------------------------
  function msg(s) 
    if not s then return end 
    --ShowConsoleMsg('==================\n'..os.date()..'\n'..s..'\n')
    ShowConsoleMsg(s..'\n')  
  end
  ---------------------------------------------------
  function math_q(num)  if math.abs(num - math.floor(num)) < math.abs(num - math.ceil(num)) then return math.floor(num) else return math.ceil(num) end end
  ---------------------------------------------------
  function math_q_dec(num, pow) return math.floor(num * 10^pow) / 10^pow end
  ---------------------------------------------------
  function dBFromVal(val) if val < 0.5 then return 20*math.log(val*2, 10) else return (val*12-6) end end
  ---------------------------------------------------------------------------------------------------------------------
  function Normalize(t, scale)
    local m = 0 for i = 1, #t do m = math.max(math.abs(t[i]),m) end
    for i = 1, #t do t[i] = scale*t[i]/m end
  end 
  ---------------------------------------------------
  function CopyTable(orig)--http://lua-users.org/wiki/CopyTable
      local orig_type = type(orig)
      local copy
      if orig_type == 'table' then
          copy = {}
          for orig_key, orig_value in next, orig, nil do
              copy[CopyTable(orig_key)] = CopyTable(orig_value)
          end
          setmetatable(copy, CopyTable(getmetatable(orig)))
      else -- number, string, boolean, etc
          copy = orig
      end
      return copy
  end
  ---------------------------------------------------
  function GetParentFolder(dir) return dir:match('(.*)[%\\/]') end
  ---------------------------------------------------
  function IsSupportedExtension(fn)
    --reaper.IsMediaExtension( ext, wantOthers )
    if fn 
      and (fn:lower():match('%.wav')
      or fn:lower():match('%.flac')
      or fn:lower():match('%.mp3')
      or fn:lower():match('%.ogg')
      or fn:lower():match('%.aif')
          ) then 
        return true 
    end
  end
  ---------------------------------------------------
  function GetDirList(dir, offset)
    local t = {}
    local subdirindex, fileindex = 0,0
    local i = 1
    repeat
      path = EnumerateSubdirectories( dir, subdirindex )
      if path then 
        i = i + 1
        if not offset or (offset and i >=offset) then t[#t+1] = {path,0} end
      end
      subdirindex = subdirindex+1
    until not path
    repeat
      fn = EnumerateFiles( dir, fileindex )
      if IsSupportedExtension(fn) then 
        i = i + 1
        if not offset or (offset and i >=offset) then t[#t+1] = {fn,1} end 
      end
      fileindex = fileindex+1
    until not fn
    return t
  end
  ---------------------------------------------------
  function GetShortSmplName(path)
    local fn = path
    fn = fn:gsub('%\\','/')
    if fn then fn = fn:reverse():match('(.-)/') end
    if fn then fn = fn:reverse() end
    if fn then fn = fn:match('(.*).wav') end
    return fn
  end
  -----------------------------------------------------------------------    
    function GetNoteStr(conf, val, mode) 
      local oct_shift = -1--conf.oct_shift-7
      local int_mode
      if mode then int_mode = mode else int_mode = conf.key_names end
      if int_mode == 0 then
        if not val then return end
        local val = math.floor(val)
        local oct = math.floor(val / 12)
        local note = math.fmod(val,  12)
        local key_names = {'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B',}
        if note and oct and key_names[note+1] then return key_names[note+1]..oct+oct_shift end
       elseif int_mode == 1 then
        if not val then return end
        local val = math.floor(val)
        local oct = math.floor(val / 12)
        local note = math.fmod(val,  12)
        local key_names = {'C', 'D♭', 'D', 'E♭', 'E', 'F', 'G♭', 'G', 'A♭', 'A', 'B♭', 'B',}
        if note and oct and key_names[note+1] then return key_names[note+1]..oct+oct_shift end  
       elseif int_mode == 2 then
        if not val then return end
        local val = math.floor(val)
        local oct = math.floor(val / 12)
        local note = math.fmod(val,  12)
        local key_names = {'Do', 'Do#', 'Re', 'Re#', 'Mi', 'Fa', 'Fa#', 'Sol', 'Sol#', 'La', 'La#', 'Si',}
        if note and oct and key_names[note+1] then return key_names[note+1]..oct+oct_shift end      
       elseif int_mode == 3 then
        if not val then return end
        local val = math.floor(val)
        local oct = math.floor(val / 12)
        local note = math.fmod(val,  12)
        local key_names = {'Do', 'Re♭', 'Re', 'Mi♭', 'Mi', 'Fa', 'Sol♭', 'Sol', 'La♭', 'La', 'Si♭', 'Si',}
        if note and oct and key_names[note+1] then return key_names[note+1]..oct+oct_shift end       
       elseif int_mode == 4 -- midi pitch
        then return val
       elseif int_mode == 5 -- freq
        then return math.floor(440 * 2 ^ ( (val - 69) / 12))..'Hz'
       elseif int_mode == 6 -- empty
        then return ''
       elseif int_mode == 7 then -- ru
        if not val then return end
        local val = math.floor(val)
        local oct = math.floor(val / 12)
        local note = math.fmod(val,  12)
        local key_names = {'До', 'До#', 'Ре', 'Ре#', 'Ми', 'Фа', 'Фа#', 'Соль', 'Соль#', 'Ля', 'Ля#', 'Си'}
        if note and oct and key_names[note+1] then return key_names[note+1]..oct+oct_shift..'\n'..val,
                                                          'keys (RU) + octave + MIDI note' end  
       elseif int_mode == 8 then
        if not val then return end
        local val = math.floor(val)
        local oct = math.floor(val / 12)
        local note = math.fmod(val,  12)
        local key_names = {'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B',}
        if note and oct and key_names[note+1] then 
          return key_names[note+1]..oct+oct_shift..'\n'..val,
                  'keys + octave + MIDI note'
        end              
      end
    end
    ----------------------------------------------------------------------- 
    function GetInput( conf, captions_csv, retvals_csv,floor)
      local ret, str =  GetUserInputs( conf.mb_title, 1, captions_csv, retvals_csv )
      if not ret then return end
      if not tonumber(str) then return end
      local num = tonumber(str)
      if floor then num = math.floor(num) end
      return num
    end
