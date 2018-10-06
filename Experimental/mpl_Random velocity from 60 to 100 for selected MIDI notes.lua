-- @description test_Random velocity from 60 to 100 for selected MIDI notes
-- @version 1.0
-- @author MPL
-- @website http://forum.cockos.com/member.php?u=70694
-- @changelog
--    + test

  scr_title = 'MPL test random velocity from 60 to 100 for selected MIDI notes'
  
  vel_min = 10
  vel_max = 70
  
  for key in pairs(reaper) do _G[key]=reaper[key]  end 
  -------------------------------------------------------------------------
  function AppMIDIData(take)
    local tableEvents = {}
    local t = 0 
    local gotAllOK, MIDIstring = MIDI_GetAllEvts(take, "")
    local MIDIlen = MIDIstring:len()
    local stringPos = 1 
    local offset, flags, msg                
    while stringPos < MIDIlen-12 do
      offset, flags, msg, stringPos = string.unpack("i4Bs4", MIDIstring, stringPos)
      if msg:len() > 1 then
        if msg:byte(1)>>4 == 0x9 and flags&1 == 1 then
          local val = math.floor(math.random() * (vel_max-vel_min) + vel_min)
          local vel_bin = string.char(val)
          msg = msg:sub(0,2)..vel_bin..msg:sub(4)
        end
      end
      t = t + 1
      tableEvents[t] = string.pack("i4Bs4", offset, flags, msg)
    end                
    MIDI_SetAllEvts(take, table.concat(tableEvents) .. MIDIstring:sub(-12))
    MIDI_Sort(take)    
  end  
  -------------------------------------------------------------------------  
  function main()
    local midieditor = MIDIEditor_GetActive()
    if not midieditor then return end
    local take =  MIDIEditor_GetTake( midieditor )
    if not take then return end
    Undo_BeginBlock()  
    AppMIDIData(take)
    Undo_EndBlock(scr_title, 1)  
  end  
  
  main()
  
