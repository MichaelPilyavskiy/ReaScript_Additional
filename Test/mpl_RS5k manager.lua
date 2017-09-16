-- @description RS5k manager
-- @version alpha
-- @author MPL
-- @website http://forum.cockos.com/member.php?u=70694
-- @changelog
--   init alpha
  
--[[ 
  08.2017           Early beta as reimplementing Pattern Rack
  15.09.2017  0.1   basic gui
                    tabs
                    basic browser content
  16.09.2017  0.11  SampleBrowser: browse for file
                    SampleBrowser: favourites Save/Load
                    SampleBrowser: scroll by wheel
  
  ]]
  
  
  local scr_title = 'RS5k manager'
  --  INIT -------------------------------------------------
  for key in pairs(reaper) do _G[key]=reaper[key]  end  
  local mouse = {}
  local obj = {}
  conf = {}
  redraw = -1
  blit_h,slider_val = 0,0
  local gui = {
                aa = 1,
                mode = 0,
                font = 'Calibri',
                fontsz = 20,
                fontsz2 = 14,
                col = { grey =    {0.5, 0.5,  0.5 },
                        white =   {1,   1,    1   },
                        red =     {1,   0,    0   },
                        green =   {0.3,   0.9,    0.3   }
                      }
                
                }
    
  if GetOS():find("OSX") then 
    gui.fontsz = gui.fontsz - 7 
    gui.fontsz2 = gui.fontsz2 - 7 
  end
  ---------------------------------------------------
  local function lim(val, min,max) --local min,max 
    if not min or not max then min, max = 0,1 end 
    return math.max(min,  math.min(val, max) ) 
  end
  ---------------------------------------------------
  function ExtState_Save()
    _, conf.wind_x, conf.wind_y, conf.wind_w, conf.wind_h = gfx.dock(-1, 0,0,0,0)
    --for key in pairs(conf) do SetExtState(conf.ES_key, key, conf[key], true)  end
    for k,v in spairs(conf, function(t,a,b) return b:lower() > a:lower() end) do SetExtState(conf.ES_key, k, conf[k], true) end   
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
  local function msg(s)  ShowConsoleMsg(os.date()..' '..s..'\n') end
  ---------------------------------------------------
  local function col(col_s, a) gfx.set( table.unpack(gui.col[col_s])) if a then gfx.a = a end  end
  ---------------------------------------------------
  local function GUI_DrawObj(o) 
    if not o then return end
    local x,y,w,h, txt = o.x, o.y, o.w, o.h, o.txt
    if not x or not y or not w or not h then return end
    gfx.a = o.alpha_back or 0.3
    gfx.blit( 2, 1, 0, -- grad back
              0,0,  obj.grad_sz,obj.grad_sz,
              x,y,w,h, 0,0)
    
    -- fill back
    local x_sl = x      
    local w_sl = w 
    local y_sl = y      
    local h_sl = h 
    if o.is_slider and o.steps and (not o.axis or o.axis == 'x') then 
      x_sl = x + w/o.steps*o.val
      w_sl = w/o.steps
     elseif o.is_slider  and o.steps and o.axis == 'y' then 
      y_sl = y + h/o.steps*o.val
      h_sl = h - h/o.steps
    end  
    col(o.col, o.alpha_back or 0.2)
    gfx.rect(x_sl,y_sl,w_sl,h_sl,1)
    
    -- txt
    if o.txt then 
      col('white', o.alpha_txt or 0.8)
      local f_sz = gui.fontsz
      gfx.setfont(1, gui.font,o.fontsz or gui.fontsz )
      if gfx.measurestr(o.txt) > w then 
        repeat o.txt = o.txt:sub(2) until gfx.measurestr(o.txt..'> ...')< w -2
        o.txt = '...'..o.txt
      end
      if o.txt2 then o.txt = o.txt2..' '..o.txt end
      gfx.x = x+ (w-gfx.measurestr(o.txt))/2
      if o.aligh_txt and o.aligh_txt == 1 then gfx.x = x + 1 end -- align left
      gfx.y = y+ (h-gfx.texth)/2
      if o.bot_al_txt then 
        gfx.y = y+ h-gfx.texth-3
      end
      gfx.drawstr(o.txt)
    end
    
    -- frame
    if o.a_frame then  -- low frame
      col(o.col, o.a_frame or 0.2)
      --gfx.rect(x,y,w,h,0)
      --gfx.x,gfx.y = x,y
      --gfx.lineto(x,y+h)
      gfx.x,gfx.y = x+1,y+h
      gfx.lineto(x+w,y+h)
      --gfx.x,gfx.y = x+w,y+h-1
      --gfx.lineto(x+w,y)
      --gfx.x,gfx.y = x+w-1,y
      --gfx.lineto(x+1,y)
    end
  end
  ---------------------------------------------------
  local function GUI_draw()
    gfx.mode = 0
    -- redraw: -1 init, 1 maj changes, 2 minor changes
    -- 1 back
    -- 2 gradient
    -- 3 smpl browser blit
      
    --  init
      if redraw == -1 then
        OBJ_Update()
        gfx.dest = 2
        gfx.setimgdim(2, -1, -1)  
        gfx.setimgdim(2, obj.grad_sz,obj.grad_sz)  
        local r,g,b,a = 1,1,1,0.55
        gfx.x, gfx.y = 0,0
        local c = 0.7
        local drdx = c*0.00001
        local drdy = c*0.00001
        local dgdx = c*0.00008
        local dgdy = c*0.0001    
        local dbdx = c*0.00008
        local dbdy = c*0.00001
        local dadx = c*0.0008
        local dady = c*0.001       
        gfx.gradrect(0,0, obj.grad_sz,obj.grad_sz, 
                        r,g,b,a, 
                        drdx, dgdx, dbdx, dadx, 
                        drdy, dgdy, dbdy, dady) 
        redraw = 1 -- force com redraw after init 
      end
      
    -- refresh
      if redraw == 1 then 
        OBJ_Update()
        -- refresh backgroung
          gfx.dest = 1
          gfx.setimgdim(1, -1, -1)  
          gfx.setimgdim(1, gfx.w, gfx.h) 
          gfx.blit( 2, 1, 0, -- grad back
                    0,0,  obj.grad_sz,obj.grad_sz/2,
                    0,0,  gfx.w,gfx.h, 0,0)
          gfx.a = 0.1
          --gfx.line(gfx.w-obj.menu_w, 0,gfx.w-obj.menu_w, gfx.h )
        -- tab div
          col('white', 0.2)
          local div = gfx.line(obj.tab_div, 0, obj.tab_div, gfx.h)
        -- refresh all buttons
          for key in pairs(obj) do 
            if type(obj[key]) == 'table' and obj[key].show and not obj[key].blit then 
              GUI_DrawObj(obj[key]) 
            end  
          end  
        -- refresh blit list 
          if blit_h then
            gfx.dest = 3
            gfx.setimgdim(3, -1, -1)  
            gfx.setimgdim(3, obj.tab_div, blit_h) 
            for key in pairs(obj) do 
              if type(obj[key]) == 'table' and obj[key].show and obj[key].blit then 
                GUI_DrawObj(obj[key]) 
              end  
            end    
          end
      end
      
      
    --  render    
      gfx.dest = -1   
      gfx.a = 1
      gfx.x,gfx.y = 0,0
    --  back
      gfx.blit(1, 1, 0, -- backgr
          0,0,gfx.w, gfx.h,
          0,0,gfx.w, gfx.h, 0,0)  
    --  blit browser
      if blit_h and obj.blit_y_src then
        gfx.blit(3, 1, 0, -- backgr
          0,  obj.blit_y_src+obj.browser.y+obj.item_h2, obj.tab_div, blit_h,
          0,  obj.browser.y+obj.item_h2,              obj.tab_div, blit_h, 0,0) 
      end    
    
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
    local t= {ES_key = 'MPL_'..scr_title,
            wind_x =  50,
            wind_y =  50,
            wind_w =  600,
            wind_h =  200,
            dock =    0,
            tab = 0,
            tab_div = 0.3,
            cur_smpl_browser_dir =  GetResourcePath():gsub('\\','/'),
            fav_path_cnt = 4,
            mouse_wheel_res = 960}
    for i = 1, t.fav_path_cnt do t['smpl_browser_fav_path'..i] = '' end
    return t
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
  local function OBJ_define()  
    obj.offs = 2
    obj.grad_sz = 200
    obj.item_h = 30   
    obj.item_h2 = 15
    obj.scroll_w = 25
    
    obj.slider = { x = 0,
                y = 0,
                h = obj.item_h,
                col = 'white',
                state = 0,
                show = true,
                is_slider = true,
                mouse_scale = 100,
                axis = 'x',
                allow_click_to_set = true,
                alpha_back = 0.4,
                func =  function(val) 
                          local v = lim(val, 0,1) 
                          conf.tab = math.max(0,math.ceil(v*3)-1) 
                          ExtState_Save() 
                          redraw = 1 
                        end}

    obj.browser =      { x = 0,
                y = obj.item_h+1,
                h = gfx.h-obj.item_h,
                col = 'white',
                state = 0,
                alpha_back = 0.4,
                ignore_mouse = true}
    obj.scroll =  {
                y = obj.item_h+2+obj.item_h2,
                w = obj.scroll_w,
                h = gfx.h-obj.item_h-obj.item_h2-3,
                col = 'white',
                show = true,
                state = 0,
                alpha_back = 0.4,
                mouse_scale = 100,
                axis = 'y',
                is_slider = true,
                func =  function(val) 
                          slider_val = lim(val, 0,1) 
                          redraw = 1
                        end}                     
    
                      
  end
  ---------------------------------------------------
  function OBJ_Update()
    obj.tab_div = math.floor(gfx.w*conf.tab_div)
    --
    obj.slider.w = obj.tab_div
    if conf.tab == 0 then 
      obj.slider.txt = 'Samples & Pads'
     elseif conf.tab == 1 then 
      obj.slider.txt = 'Patterns & StepSeq'
     elseif conf.tab == 2 then 
      obj.slider.txt = 'Controls & Options'      
    end
    obj.slider.val = conf.tab
    obj.slider.steps = 3
    --
    obj.browser.w = obj.tab_div
    --
    obj.scroll.x =  obj.tab_div-obj.scroll_w
    obj.scroll.val = slider_val
    obj.scroll.h = gfx.h-obj.item_h-obj.item_h2-3
    --
    for key in pairs(obj) do if type(obj[key]) == 'table' and obj[key].clear then obj[key] = nil end end
    if conf.tab == 0 then 
      local cnt_it = OBJ_GenSampleBrowser() 
      obj.scroll.steps = cnt_it
    end
    for key in pairs(obj) do if type(obj[key]) == 'table' then obj[key].context = key end end    
  end
  ---------------------------------------------------
  function GetParentFolder(dir) return dir:match('(.*)[%\\/]') end
  ---------------------------------------------------
  function Menu_FormBrowser()                   
    local browser_t =
                                  {
                                    {str = 'Browse for file/path',
                                    func = function()
                                              local ret, fn = GetUserFileNameForRead('', 'Browse for file/path', '.wav' )
                                              if ret then
                                                local par_fold = GetParentFolder(fn)
                                                if par_fold then 
                                                  conf.cur_smpl_browser_dir = par_fold 
                                                  ExtState_Save()
                                                  redraw = 1                                             
                                                end
                                              end
                                            end
                                    },                                
                                    {str = '|>Save as favourite|1 - '..conf.smpl_browser_fav_path1,
                                    func = function()
                                              conf.smpl_browser_fav_path1 = conf.cur_smpl_browser_dir
                                              ExtState_Save()
                                              redraw = 1 
                                            end
                                    }
                                  }
    -- save favourite 
    for i = 2, conf.fav_path_cnt  do
      if conf['smpl_browser_fav_path'..i] then 
        if i == conf.fav_path_cnt or not conf['smpl_browser_fav_path'..i+1] then close = '<' else close = '' end
        browser_t[#browser_t+1] = { str = close..i..' - '..conf['smpl_browser_fav_path'..i],
                                  func = function()
                                    conf['smpl_browser_fav_path'..i] = conf.cur_smpl_browser_dir
                                    ExtState_Save()
                                    redraw = 1 
                                  end
                                }
      end
    end 
    -- load favourite
    for i = 1, conf.fav_path_cnt  do
      if conf['smpl_browser_fav_path'..i] then
        browser_t[#browser_t+1] = { str = 'Fav'..i..' - '..conf['smpl_browser_fav_path'..i],
                                  func = function()
                                    conf.cur_smpl_browser_dir = conf['smpl_browser_fav_path'..i]
                                    ExtState_Save()
                                    redraw = 1 
                                  end
                                }    
      end
    end
    return  browser_t
  end
  ---------------------------------------------------
  function OBJ_GenSampleBrowser()
    local it_alpha = 0.3
    local up_w = 20
    obj.browser_up = { clear = true,
                  x = obj.browser.x,
                y = obj.browser.y,
                w = up_w,
                h = obj.item_h2,
                col = 'white',
                state = 0,
                txt= '<',
                show = true,
                is_but = true,
                fontsz = gui.fontsz2,
                alpha_back = it_alpha,
                func =  function() 
                          local path = GetParentFolder(conf.cur_smpl_browser_dir) 
                          if path then 
                            conf.cur_smpl_browser_dir = path 
                            ExtState_Save()
                            redraw = 1
                          end
                        end} 
    ------ browser menu form --------------- 
    obj.browser_cur = { clear = true,
                x = up_w+1+obj.browser.x,
                y = obj.browser.y,
                w = obj.tab_div-up_w-1,
                h = obj.item_h2,
                col = 'white',
                state = 0,
                txt= conf.cur_smpl_browser_dir,
                show = true,
                is_but = true,
                fontsz = gui.fontsz2,
                alpha_back = it_alpha,
                func =  function() Menu(Menu_FormBrowser()) end}
    local cur_dir_list = GetDirList(conf.cur_smpl_browser_dir)
    blit_h = #cur_dir_list*obj.item_h2 + obj.browser.y
    obj.blit_y_src = math.floor(slider_val*(blit_h-obj.item_h2*2-obj.item_h))
    for i = 1, #cur_dir_list do
      local txt = cur_dir_list[i][1]
      local txt2 if  cur_dir_list[i][2] == 0 then txt2 = '>' end
      obj['browser_dirlist'..i] = 
                { clear = true,
                  x = obj.browser.x,
                  y = obj.browser.y + 1  + obj.item_h2+(i-1)*obj.item_h2,
                  w = obj.tab_div-obj.scroll_w,
                  h = obj.item_h2,
                  col = 'white',
                  state = 0,
                  txt= txt,
                  txt2=txt2,
                  aligh_txt = 1,
                  blit = true,
                  show = true,
                  is_but = true,
                  fontsz = gui.fontsz2,
                  alpha_back = 0.2,
                  a_frame = 0.1,
                  --mouse_offs_y = blit_y,
                  func =  function() 
                            local p = conf.cur_smpl_browser_dir..'/'..cur_dir_list[i][1] 
                            p = p:gsub('\\','/')
                            if not IsSupportedExtension(p) then 
                              conf.cur_smpl_browser_dir = p
                              ExtState_Save()
                              redraw = 1
                            end
                          end}    
    end
    local cnt = lim((gfx.h-obj.browser.h)/#cur_dir_list, 2, math.huge)
    return cnt
  end
  ---------------------------------------------------
  function IsSupportedExtension(fn)
    if fn 
      and fn:lower():match('%.wav') then 
        return true 
    end
  end
  ---------------------------------------------------
  function GetDirList(dir)
    local t = {}
    local subdirindex, fileindex = 0,0
    repeat
      path = EnumerateSubdirectories( dir, subdirindex )
      if path then t[#t+1] = {path,0} end
      subdirindex = subdirindex+1
    until not path
    repeat
      fn = EnumerateFiles( dir, fileindex )
      if IsSupportedExtension(fn) then t[#t+1] = {fn,1} end
      fileindex = fileindex+1
    until not fn
    return t
  end
  ---------------------------------------------------
  function Menu(t)
    local str, check = '', ''
    for i = 1, #t do
      if t[i].state then check = '!' else check ='' end
      str = str..check..t[i].str..'|'
    end
    gfx.x = mouse.mx
    gfx.y = mouse.my
    local ret = gfx.showmenu(str)
    if ret > 0 then if t[ret].func then t[ret].func() end end
    --local id_match = {}
    --local id = 0
    --[[if not t[i].str:find('>') then id = id + 1 end
    id_match[#id_match+1] = id ]]
      --[[msg(ret) 
      msg(id_match[ret])
      if t[id_match[ret] ].func then 
        t[id_match[ret] ].func() 
      end ]]    
  end
 ---------------------------------------------------
  function MOUSE_Match(b) 
    if not b.mouse_offs_y then b.mouse_offs_y = 0 end
    if b.x and b.y and b.w and b.h then 
      return mouse.mx > b.x 
        and mouse.mx < b.x+b.w 
        and mouse.my > b.y + b.mouse_offs_y
        and mouse.my < b.y+b.h + b.mouse_offs_y
      end  
  end
 ------------- -------------------------------------- 
  function MOUSE_Click(b,flag) 
    if b.ignore_mouse then return end
    if not flag then flag = 'L' end 
    if MOUSE_Match(b) and mouse[flag..'MB_state'] and not mouse['last_'..flag..'MB_state'] then 
      mouse.context_latch = b.context 
      return true
    end
  end
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
    if mouse.last_mx and mouse.last_my and (mouse.last_mx ~= mouse.mx or mouse.last_my ~= mouse.my) then mouse.is_moving = true else mouse.is_moving = false end
    if mouse.last_wheel then mouse.wheel_trig = (mouse.wheel - mouse.last_wheel) end 
    if mouse.LMB_state and not mouse.last_LMB_state then  mouse.last_mx_onclick = mouse.mx     mouse.last_my_onclick = mouse.my end    
    if mouse.last_mx_onclick and mouse.last_my_onclick then mouse.dx = mouse.mx - mouse.last_mx_onclick  mouse.dy = mouse.my - mouse.last_my_onclick else mouse.dx, mouse.dy = 0,0 end
    -- butts    
    for key in pairs(obj) do
      if not key:match('knob') and type(obj[key]) == 'table' then
        if obj[key].is_but then  if MOUSE_Click(obj[key]) then if obj[key].func then  obj[key].func() end end end
        if obj[key].is_slider then  
          if MOUSE_Click(obj[key]) then 
            if obj[key].allow_click_to_set then
              local v = (mouse.mx-obj[key].x) / obj[key].w
              obj[key].val = v              
              obj[key].func(v)
            end            
            mouse.context_latch = obj[key].context
            mouse.context_latch_val = obj[key].val
          end
        end
        if mouse.is_moving 
          and mouse.LMB_state 
          and mouse.context_latch 
          and mouse.context_latch == obj[key].context
          and mouse.context_latch_val 
          and obj[key].axis 
          and obj[key].mouse_scale then 
          obj[key].val = mouse.context_latch_val + mouse['d'..obj[key].axis]/obj[key].mouse_scale
          obj[key].func(obj[key].val)
        end
      end
    end
    
    -- scroll
      if MOUSE_Match(obj.browser) and mouse.wheel_trig ~= 0 then
        slider_val = lim(slider_val - mouse.wheel_trig/conf.mouse_wheel_res,0,1)
        redraw = 1
      end
    
    -- mouse release    
      if mouse.last_LMB_state and not mouse.LMB_state   then  
        mouse.context_latch = ''
        mouse.context_latch_val = 0
      end
      mouse.last_mx = mouse.mx
      mouse.last_my = mouse.my
      mouse.last_LMB_state = mouse.LMB_state  
      mouse.last_RMB_state = mouse.RMB_state
      mouse.last_MMB_state = mouse.MMB_state 
      mouse.last_Ctrl_LMB_state = mouse.Ctrl_LMB_state
      mouse.last_Ctrl_state = mouse.Ctrl_state
      mouse.last_Alt_state = mouse.Alt_state
      mouse.last_wheel = mouse.wheel      
  end
  ---------------------------------------------------
  local SCC, lastSCC
  function CheckUpdates()
    local retval = 0
    -- force by proj change state
      SCC =  GetProjectStateChangeCount( 0 ) 
      if not lastSCC then retval = -1  end 
      if lastSCC and lastSCC ~= SCC then retval =  1  end 
      lastSCC = SCC
      
    -- window size
      local ret = HasWindXYWHChanged()
      if ret == 1 then 
        ExtState_Save()
        retval =  -1 
       elseif ret == 2 then 
        ExtState_Save()
        retval =  1 
      end
    return retval
  end
  ---------------------------------------------------
  function run()
    redraw = CheckUpdates()
    MOUSE()
    GUI_draw()
    if gfx.getchar() >= 0 then defer(run) else atexit(gfx.quit) end
  end
  ---------------------------------------------------
  ExtState_Load()  
  gfx.init('MPL '..scr_title,
            conf.wind_w, 
            conf.wind_h, 
            conf.dock, conf.wind_x, conf.wind_y)
  OBJ_define()
  OBJ_Update()
  run()
  
  
