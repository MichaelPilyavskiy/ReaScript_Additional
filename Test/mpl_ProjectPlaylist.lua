-- @version 0.01
-- @author MPL
-- @changelog
--   + init
-- @description ProjectPlaylist
-- @website http://forum.cockos.com/member.php?u=70694
  
  --[[ changelog
    01.07.2017  0.01 init alpha
      basic GUI
      load current opened project on start
      save/load playlist
      selecting tabs
  ]]
  
  
  
  
  
  
  
  --  INIT -------------------------------------------------  
  debug = 1
  for key in pairs(reaper) do _G[key]=reaper[key]  end  
  local playlists_path = GetResourcePath()..'/MPL ProjectPlaylists/'
  local mouse = {}
  local gui -- see GUI_define()
   obj = {}
  local conf = {}
  local cycle = 0
  local redraw = 1
  local SCC, lastSCC, SCC_trig
  local ProjState
  playlist = {}
  ---------------------------------------------------
  local function lim(val, min,max) --local min,max 
    if not min or not max then min, max = 0,1 end 
    return math.max(min,  math.min(val, max) ) 
  end
  ---------------------------------------------------
  local function ExtState_Save()
    _, conf.wind_x, conf.wind_y, conf.wind_w, conf.wind_h = gfx.dock(-1, 0,0,0,0)
    for key in pairs(conf) do SetExtState(conf.ES_key, key, conf[key], true)  end
  end
  ---------------------------------------------------
  local function msg(s) ShowConsoleMsg(s..'\n') end
  if debug == 1 then function deb(s) ShowConsoleMsg(s..'\n') end end
  ---------------------------------------------------
  local function col(col_s, a) gfx.set( table.unpack(gui.col[col_s])) if a then gfx.a = a end  end
  ---------------------------------------------------
  local function GUI_DrawObj(o) 
    local x,y,w,h, txt = o.x, o.y, o.w, o.h, o.txt
    gfx.a = o.a or 0.3
    gfx.blit( 2, 1, math.rad(o.grad_blit_rot), -- grad back
              0,0,  obj.grad_sz,math.ceil(obj.grad_sz*o.grad_blit_h_coeff),
              x,y,w,h, 0,0)
    if o.active and o.active == 1 then     col('green', 0.43) gfx.rect(x,y,w,h,1) end
    col('white', 0.8)
    gfx.setfont(1, gui.fontname, gui.fontsz)
    gfx.x = x+ (w-gfx.measurestr(txt))/2
    gfx.y = y+ (h-gfx.texth)/2
    gfx.drawstr(o.txt)
  end
  ---------------------------------------------------
  local function GUI_Playlist()
    gfx.dest = 4
    gfx.setimgdim(4, -1, -1)  
    gfx.setimgdim(4, gfx.w,gfx.h - obj.menu_b_h)  
    for key in pairs(obj) do if type(obj[key]) == 'table' and key:find('PLitem') then GUI_DrawObj(obj[key]) end end          
  end
  ---------------------------------------------------
  local function GUI_draw()
    gfx.mode = 0
    -- redraw: -1 init, 1 maj changes, 2 minor changes
    -- 1 back
    -- 2 gradient
    --// 3 dynamic stuff
    -- 4 playlist
      if redraw == 0 then -- dynamic
        
      end
      
    --  init
      if redraw == -1 then
        gfx.dest = 2
        gfx.setimgdim(2, -1, -1)  
        gfx.setimgdim(2, obj.grad_sz,obj.grad_sz)  
        local r,g,b,a = 0.9,0.9,1,0.65
        gfx.x, gfx.y = 0,0
        local c = 0.5
        local drdx = c*0.00001
        local drdy = c*0.00001
        local dgdx = c*0.00008
        local dgdy = c*0.0001    
        local dbdx = c*0.00008
        local dbdy = c*0.00001
        local dadx = c*0.00003
        local dady = c*0.0004       
        gfx.gradrect(0,0, obj.grad_sz,obj.grad_sz, 
                        r,g,b,a, 
                        drdx, dgdx, dbdx, dadx, 
                        drdy, dgdy, dbdy, dady) 
        redraw = 1 -- force com redraw after init 
      end
      
    -- refresh
      if redraw == 1 then 
        -- refresh backgroung
          gfx.dest = 1
          gfx.setimgdim(1, -1, -1)  
          gfx.setimgdim(1, gfx.w, gfx.h) 
          gfx.blit( 2, 1, 0, -- grad back
                    0,0,  obj.grad_sz,obj.grad_sz,
                    0,0,  gfx.w,gfx.h, 0,0)
          gfx.a = 0.1
        -- refresh all buttons
          for key in pairs(obj) do if type(obj[key]) == 'table' and not key:find('PLitem') then GUI_DrawObj(obj[key]) end end          
        -- refresh playlist
          GUI_Playlist()
      end
            
    --  render    
      gfx.dest = -1   
      gfx.a = 1
      gfx.x,gfx.y = 0,0
    --  back
      gfx.blit(1, 1, 0, -- backgr
          0,0,gfx.w, gfx.h,
          0,0,gfx.w, gfx.h, 0,0)  
    --  PL
      gfx.blit(4, 1, 0, -- backgr
          0,0,gfx.w, gfx.h - obj.menu_b_h,
          0,obj.menu_b_h,gfx.w, gfx.h - obj.menu_b_h, 0,0)            
    
    redraw = 0
    gfx.update()
  end
  ---------------------------------------------------
  function HasWindXYWHChanged()
    local  _, wx,wy,ww,wh = gfx.dock(-1, 0,0,0,0)
    local retval=0
    if wx ~= obj.last_gfxx or wy ~= obj.last_gfxy then retval= 2 end --- minor
    if ww ~= obj.last_gfxw or wh ~= obj.last_gfxh then retval= 1 end --- major
    if not obj.last_gfxx then retval = -1 end
    obj.last_gfxx, obj.last_gfxy, obj.last_gfxw, obj.last_gfxh = wx,wy,ww,wh
    return retval
  end
  ---------------------------------------------------
  local function ExtState_Def()
    return {ES_key = 'MPL_ProjectPlaylist',
            wind_x =  50,
            wind_y =  50,
            wind_w =  200,
            wind_h =  500,
            dock =    0}
  end
  ---------------------------------------------------
  local function ExtState_Load()
    local def = ExtState_Def()
    for key in pairs(def) do 
      local es_str = GetExtState(def.ES_key, key)
      if es_str == '' then conf[key] = def[key] else conf[key] = tonumber(es_str) or es_str end
    end
  end
  ---------------------------------------------------
  local function OBJ_Update()
    obj.menu.w = gfx.w
    for i = 1, #playlist do
      obj['PLitem_'..i] = {x = 0,
                       y = obj.it_h*(i-1),
                       w = gfx.w,
                       h = obj.it_h,
                       txt = GetProjectName( playlist[i].ptr, '' ):sub(0,-5),
                       a = 1,
                       grad_blit_h_coeff = 0.3,
                       grad_blit_rot = 180,
                       mouse_offs_y = obj.menu_b_h,
                       func = function()                                 
                                for i = 1, #playlist do obj['PLitem_'..i].active = 0 end
                                obj['PLitem_'..i].active = 1
                                redraw = 1
                                SelectProjectInstance( playlist[i].ptr )
                              end}
    end
  end
  ---------------------------------------------------
  local function Actions_AddOpenedProjectsToPlaylist()
    for i = 1, 100 do
      local retval, projfn=  EnumProjects( i-1, '' )
      if projfn == '' then break end
      playlist[#playlist+1] = {ptr = retval, path = projfn }
    end  
  end
  ---------------------------------------------------  
  function Menu()
    gfx.x, gfx.y = mouse.mx, mouse.my  
    local is_dirty = '#' if playlist.fn then is_dirty = '' end
    local str_t = {
             {  txt = 'Add current project to playlist',
                func =  function() 
                          local retval, projfn=  EnumProjects( -1, '' )
                          playlist[#playlist+1] = {ptr = retval, path = projfn }
                        end
              },
              {  txt = '|Add all opened project to playlist (ignore projects without saved RPP)',
                 func = function() Actions_AddOpenedProjectsToPlaylist() end
               },
              { txt = '||Load projects from playlist',
                func =  function()  
                          local ret =  MB( 'Are you sure you want to close ALL project tabs?', 'MPL ProjectPlaylist', 4 )
                          if ret == 6 then 
                            local r, fn = GetUserFileNameForRead('', 'Open ProjectPlaylist', 'txt' )
                            if not r then return end 
                            local f = io.open(fn, 'r')
                            if not f then return end
                            local context = f:read('a')
                            f:close()
                            local t = {}
                            Main_OnCommand(40886,0) -- File: Close all projects
                            playlist = {fn = fn}
                            for line in context:gmatch('[^\r\n]+') do 
                              Main_OnCommand(41929, 0 ) -- New project tab (ignore default template)
                              Main_openProject( line )
                              local retval=  EnumProjects( -1, '' )
                              playlist[#playlist+1] = {path = line,
                                                        ptr = retval} 
                            end
                            SelectProjectInstance( EnumProjects( 0, '') )
                            Main_OnCommand(40860,0) -- Close current project tab
                          end
                        end   
                },   
              { txt = '|'..is_dirty..'Save playlist',
                func =  function()  
                          for i = 1, #playlist do out_str = out_str..playlist[i].path..'\n' end                          
                          local f = io.open(playlist.fn, 'w')                          
                          f:write(out_str)
                          f:close()
                        end       
                },                                            
              { txt = '|Save playlist to /REAPER/MPL ProjectPlaylist/(timestamp)',
                func =  function()  
                          local out_str = ''
                          RecursiveCreateDirectory( playlists_path, 0 )
                          local fp = playlists_path..'playlist'..os.date():gsub('%:', '-')..'.txt'
                          for i = 1, #playlist do out_str = out_str..playlist[i].path..'\n' end                          
                          local f = io.open(fp, 'w')                          
                          f:write(out_str)
                          f:close()
                        end
              }
            }
    local str = ""
    for i = 1, #str_t do str = str..str_t[i].txt end
    local ret = gfx.showmenu(str)
    if ret > 0 then str_t[ret].func() end
  end
  ---------------------------------------------------
  local function OBJ_define()  
    obj.offs = 2
    obj.menu_b_h = 40
    obj.it_h = 35
    obj.grad_sz = 500 -- gradient rect
    
    obj.menu = {x = 0,
                y = 0,
                w= gfx.w,
                h = obj.menu_b_h,
                a = 0.5,
                grad_blit_h_coeff = 1,
                grad_blit_rot = 0,
                txt = 'Menu',
                mouse_offs_y = 0,
                func = function() Menu() end}
  end
 ---------------------------------------------------
  local function MOUSE_Match(b)return mouse.mx > b.x and mouse.mx < b.x+b.w and mouse.my > b.y + b.mouse_offs_y and mouse.my < b.y+b.mouse_offs_y+b.h end 
 --------------------------------------------------- 
  local function MOUSE_Click(b) return MOUSE_Match(b) and mouse.LMB_state and not mouse.last_LMB_state end
  ---------------------------------------------------
  local function MOUSE()
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
    if mouse.last_wheel then mouse.wheel_trig = (mouse.wheel - mouse.last_wheel) end 
    if mouse.LMB_state and not mouse.last_LMB_state then  mouse.last_mx_onclick = mouse.mx     mouse.last_my_onclick = mouse.my end    
    if mouse.last_mx_onclick and mouse.last_my_onclick then mouse.dx = mouse.mx - mouse.last_mx_onclick  mouse.dy = mouse.my - mouse.last_my_onclick else mouse.dx, mouse.dy = 0,0 end

    -- butts    
      for key in pairs(obj) do if type(obj[key]) == 'table'then if MOUSE_Click(obj[key]) then if obj[key].func then obj[key].func()end break end end end
        
    -- mouse release    
      if mouse.last_LMB_state and not mouse.LMB_state   then  mouse.context_latch = '' end
      mouse.last_LMB_state = mouse.LMB_state  
      mouse.last_RMB_state = mouse.RMB_state
      mouse.last_MMB_state = mouse.MMB_state 
      mouse.last_Ctrl_LMB_state = mouse.Ctrl_LMB_state
      mouse.last_Ctrl_state = mouse.Ctrl_state
      mouse.last_Alt_state = mouse.Alt_state
      mouse.last_wheel = mouse.wheel      
  end
  ---------------------------------------------------
  local function run()
    SCC =  GetProjectStateChangeCount( 0 ) if not lastSCC or lastSCC ~= SCC then SCC_trig = true else SCC_trig = false end lastSCC = SCC
    clock = os.clock()
    cycle = cycle+1
    local st_wind = HasWindXYWHChanged()
    if st_wind >= -1 then ExtState_Save() if math.abs(st_wind) == 1 then redraw = st_wind OBJ_Update() end end
    if SCC_trig then OBJ_Update() end
    MOUSE()
    GUI_draw()
    if gfx.getchar() >= 0 then defer(run) else atexit(gfx.quit) end
  end
  ---------------------------------------------------
  local function GUI_define()
    gui = {
                aa = 1,
                mode = 3,
                fontname = 'Calibri',
                fontsz = 20,
                col = { grey =    {0.5, 0.5,  0.5 },
                        white =   {1,   1,    1   },
                        red =     {1,   0,    0   },
                        green =   {0,   1,    0.3   }
                      }
                
                }
    
      if OS == "OSX32" or OS == "OSX64" then gui.fontsz = gui.fontsz - 3 end
  end
  ---------------------------------------------------
  ExtState_Load()  
  gfx.init('MPL ProjectPlaylist',conf.wind_w, conf.wind_h, conf.dock, conf.wind_x, conf.wind_y)
  OBJ_define()
  OBJ_Update()
  GUI_define()
  Actions_AddOpenedProjectsToPlaylist() -- debug
  run()
  
  
