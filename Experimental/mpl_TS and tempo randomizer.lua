-- @description test_TS and tempo randomizer
-- @version 1.0
-- @author MPL
-- @website http://forum.cockos.com/member.php?u=70694
-- @changelog
--    + test

-- MPL TS and tempo randomizer

  local TS_array = {"4/4", "6/8", "12/8", "4/4", "2/4", "3/8", "7/8"}
  tempo_min, tempo_max = 60, 180
  -------------------------------  
  local b,m={},{}
  function B_perform(b)
    gfx.rect(b.x,b.y,b.w,b.h,0)
    gfx.setfont(1, "Arial", 17)
    gfx.x, gfx.y = b.x+(b.w-gfx.measurestr(b.txt))/2, b.y+(b.h-gfx.texth)/2
    gfx.drawstr(b.txt)
  end
  -------------------------------  
  function AddChangeMarker(val_timesig, val_denom, tempo)
    local cur_pos = reaper.GetCursorPositionEx( 0 )
    ptidx = reaper.FindTempoTimeSigMarker( 0, cur_pos )
    if ptidx < 0 then 
                                    reaper.SetTempoTimeSigMarker( 0, -1,    cur_pos, -1, -1, tempo,  val_timesig, val_denom, false )
     else
      local pos = ({reaper.GetTempoTimeSigMarker( 0, ptidx )})[3]
      if cur_pos - pos > 0.001 then reaper.SetTempoTimeSigMarker( 0, -1,    cur_pos, -1, -1, tempo,  val_timesig, val_denom, false )
       else                    local is_lin = ({reaper.GetTempoTimeSigMarker( 0, ptidx )})[8]
                                    reaper.SetTempoTimeSigMarker( 0, ptidx, cur_pos, -1, -1, tempo,  val_timesig, val_denom, is_lin )
      end
    end
    reaper.UpdateTimeline()
    reaper.UpdateArrange()
  end
  -------------------------------
  function Define_Buttons()    
    local offs = 10
    local w_b, h_b = gfx.w-2*offs, 40
    b.sign = {x=offs,y=10,w=w_b,h=h_b, txt='TimeSignature',
              func =  function() local val_timesig,val_denom
                        local val = TS_array[ math.random(1,#TS_array) ]
                        local t = {} for num in val:gmatch('[%d]+') do t[#t+1] = tonumber(num) end val_timesig = t[1] val_denom = t[2]
                        b.sign.txt = 'TimeSignature: '..val
                        AddChangeMarker(val_timesig,val_denom,-1)
                      end}
    b.temp = {x=offs,y=offs*2+h_b,w=w_b,h=h_b, txt='Tempo',
              func =  function() local val_timesig,val_denom
                        local val = math.random(tempo_min, tempo_max)
                        b.temp.txt = 'Tempo: '..val
                        AddChangeMarker(-1,-1,val)
                      end}
  end
  -------------------------------
  function mouse()
    m.x = gfx.mouse_x
    m.y = gfx.mouse_y
    m.st = gfx.mouse_cap==1    
    for key in pairs(b) do 
      if m.x > b[key].x and m.x < b[key].x+ b[key].w 
        and m.y > b[key].y and m.y < b[key].y+ b[key].h 
        and m.st and not m.Lst then
        b[key].func()
      end
    end    
    m.Lst =  m.st
  end
  -------------------------------  
  function Main()
    for key in pairs(b) do B_perform(b[key]) end
    local char = gfx.getchar()
    gfx.update()  
    mouse()
    if char ~= 27 and char ~= -1 then reaper.defer(Main) end      
  end
  -------------------------------  
  gfx.init("Randomizer", 200, 120, 0, 10, 10)
  reaper.atexit(gfx.quit)
  Define_Buttons()
  Main()
