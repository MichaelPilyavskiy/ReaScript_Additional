  shift_bank = 0
  shift_program = 0
  
  function GetDeviceID(dev_name)
    for i = 0, 64 do
      local retval, nameout = reaper.GetMIDIInputName( i, '' )
      if nameout:lower():match(dev_name:lower()) then  return i end
    end
  end
  -----------------------------------------
  function MPL_StuffPC(devid, bank, program, shift_bank, shift_program)
    if bank + shift_bank < 0 or bank + shift_bank > 64 then return end
    if program + shift_program < 0 or program + shift_program > 64 then return end
    for chan = 0, 15 do
      reaper.StuffMIDIMessage( devid, 0xB0+chan, 0, 0 )  -- CC0
      reaper.StuffMIDIMessage( devid, 0xB0+chan, 0x20, bank+shift_bank ) -- CC32
      reaper.StuffMIDIMessage( devid, 0xC0+chan, program + shift_program, 0 ) -- CC32
    end     
    reaper.SetExtState( 'mpl_StuffPC', 'last_bank', bank+shift_bank, true )
    reaper.SetExtState( 'mpl_StuffPC', 'last_program', program+shift_program, true )    
  end
  -----------------------------------------
  local devid = GetDeviceID('launchkey')
  if devid and devid ~= 0 then 
    last_bank,last_program = reaper.GetExtState(  'mpl_StuffPC', 'last_bank' ) --local 
    if last_bank then 
      last_bank = tonumber(last_bank)
      last_program = tonumber(reaper.GetExtState(  'mpl_StuffPC', 'last_program' ))
    end
    if not last_bank or last_bank == '' then
      last_bank = 0
      last_program = 0
      reaper.SetExtState( 'mpl_StuffPC', 'last_bank', last_bank, true )
      reaper.SetExtState( 'mpl_StuffPC', 'last_program', last_program, true )
    end
    MPL_StuffPC(devid, last_bank, last_program, shift_bank, shift_program)  
  end
