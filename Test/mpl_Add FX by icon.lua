
path = [[D:/test/]] -- path with saved PNGs with Christian Budde's VST-Plug-In Screenshot Tool http://www.pcjv.de/applications/tools/



w = 700
h = 700
gfx.init(0,w,h,0)
local t = {}
for i = 0, 300 do
  fp = reaper.EnumerateFiles( path, i )
  if not fp then break end
  id = gfx.loadimg(i, path..fp )
  t[#t+1] = fp
end

col_row = math.ceil(math.sqrt(#t))
gfx.dest = -1
for col = 0, col_row-1 do
  for row = 0, col_row-1 do
    gfx.x = col * (w / col_row) 
    gfx.y = row * (h / col_row)     
    gfx.blit(row*col_row+col,0.15,0 )
    
  end
end

function run()
  LMB = gfx.mouse_cap == 1
  
  x_pos = math.ceil(col_row * gfx.mouse_x / w )
  y_pos = math.ceil(col_row * gfx.mouse_y / h )
  t_pos = (y_pos-1)*col_row+x_pos
  if t[t_pos] then 
    fxname = t[t_pos]:gsub('.dll.png', '')
    if not last_LMB and LMB then 
      id = reaper.TrackFX_AddByName( reaper.GetTrack(0,0), fxname, false, -1 )
      reaper.TrackFX_Show( reaper.GetTrack(0,0), id, 3 )
    end
  end
  last_LMB = LMB
  gfx.update()
  if gfx.getchar() > -1 then reaper.defer(run) end
end

run()
