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
  16.09.2017  0.13  SampleBrowser
                    SampleBrowser: browse for file
                    SampleBrowser: favourites Save/Load
                    SampleBrowser: scroll by wheel   
                    SampleBrowser: drag n drop to keys (export to rs5k)
                    Keys: show/preview MIDI note
                    Keys: show linked samples
                    Keys: MIDI prepare track if at least one RS5K instance found
                    Data: sort data table by MIDI note (for potential support layer), currently replacing sample
  19.09.2017  0.14  Patterns: GUI prepare   
  23.09.2017  0.16  PatternBrowser
                    StepSequencer sketch
                    
  ]]
  local vrs = 'v0.16alpha'
  --NOT gfx NOT reaper
  local scr_title = 'RS5K manager'
  --  INIT -------------------------------------------------
  for key in pairs(reaper) do _G[key]=reaper[key]  end  
  local mouse = {}
  local obj = {}
  conf = {}
  pat = {}
  data = {}
  local action_export = {}
  local redraw = -1
  local blit_h,slider_val,blit_h2,slider_val2 = 0,0,0,0
  local gui = {
                aa = 1,
                mode = 0,
                font = 'Calibri',
                fontsz = 20,
                fontsz2 = 14,
                a1 = 0.2, -- pat not sel
                a2 = 0.45, -- pat sel
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
  function ExtState_Def()
    local t= {
            -- globals
            ES_key = 'MPL_'..scr_title,
            wind_x =  50,
            wind_y =  50,
            wind_w =  600,
            wind_h =  200,
            dock =    0,
            -- GUI
            tab = 0,
            tab_div = 0.3,
            -- GUI control
            mouse_wheel_res = 960,
            -- Samples
            cur_smpl_browser_dir = GetResourcePath():gsub('\\','/'),
            fav_path_cnt = 4,
            -- Pads
            keymode = 0,
            oct_shift = 5,
            key_names = 8,
            -- Patterns
            default_steps = 16
            }
    for i = 1, t.fav_path_cnt do t['smpl_browser_fav_path'..i] = '' end
    return t
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
  local function msg(s) if not s then return end ShowConsoleMsg('==================\n'..os.date()..'\n'..s..'\n') end
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
      local txt = tostring(o.txt)
      col('white', o.alpha_txt or 0.8)
      local f_sz = gui.fontsz
      gfx.setfont(1, gui.font,o.fontsz or gui.fontsz )
      local y_shift = 0
      for line in txt:gmatch('[^\r\n]+') do
        if gfx.measurestr(line:sub(2)) > w -2 and w > 20 then 
          repeat line = line:sub(2) until gfx.measurestr(line..'...')< w -2
          line = '...'..line
        end
        if o.txt2 then line = o.txt2..' '..line end
        gfx.x = x+ (w-gfx.measurestr(line))/2
        gfx.y = y+ (h-gfx.texth)/2 + y_shift 
        if o.aligh_txt then
          if o.aligh_txt&1 then gfx.x = x + 1 end -- align left
          if o.aligh_txt>>2&1 then gfx.y = y + y_shift end -- align top
        end
        if o.bot_al_txt then 
          gfx.y = y+ h-gfx.texth-3 +y_shift
        end
        gfx.drawstr(line)
        y_shift = y_shift + gfx.texth
      end
    end
    
    -- frame
    if o.a_line then  -- low frame
      col(o.col, o.a_frame or 0.2)
      gfx.x,gfx.y = x+1,y+h
      gfx.lineto(x+w,y+h)
    end
    -- frame
    if o.a_frame then  -- low frame
      col(o.col, o.a_frame or 0.2)
      gfx.rect(x,y,w,h,0)
      gfx.x,gfx.y = x,y
      gfx.lineto(x,y+h)
      gfx.x,gfx.y = x+1,y+h
      --gfx.lineto(x+w,y+h)
      gfx.x,gfx.y = x+w,y+h-1
      --gfx.lineto(x+w,y)
      gfx.x,gfx.y = x+w-1,y
      gfx.lineto(x+1,y)
    end    
    return true
  end
  ---------------------------------------------------
  function math_q(num)  if math.abs(num - math.floor(num)) < math.abs(num - math.ceil(num)) then return math.floor(num) else return math.ceil(num) end end
  ---------------------------------------------------
  function MIDI_prepare(tr)
    local bits_set=tonumber('111111'..'00000',2)
    SetMediaTrackInfo_Value( tr, 'I_RECINPUT', 4096+bits_set ) -- set input to all MIDI
    SetMediaTrackInfo_Value( tr, 'I_RECMON', 1) -- monitor input
    SetMediaTrackInfo_Value( tr, 'I_RECARM', 1) -- arm track
    SetMediaTrackInfo_Value( tr, 'I_RECMODE',0) -- record MIDI out
  end
  ---------------------------------------------------
  function Data_Update()
    data = {}
    local temp = {}
    local tr = GetSelectedTrack(0,0)
    if not tr then return end
    data.tr_pointer = tr
    local ex = false
    for fxid = 1,  TrackFX_GetCount( tr ) do
      local retval, buf =TrackFX_GetFXName( tr, fxid-1, '' )
      if buf:lower():match('rs5k') or buf:lower():match('reasamplomatic5000') then
        ex = true
        local retval, fn = TrackFX_GetNamedConfigParm( tr, fxid-1, 'FILE' )
        local pitch = math_q(TrackFX_GetParamNormalized( tr, fxid-1, 3)*127)
        temp[#temp+1] = {idx = fxid-1,
                        name = buf,
                        fn = fn,
                        pitch=pitch }
      end
    end
    if ex then MIDI_prepare(tr) end
    for i =1, #temp do 
      if not data[ temp[i].pitch]  then data[ temp[i].pitch] = {} end
      data[ temp[i].pitch][#data[ temp[i].pitch]+1] = temp[i] 
    end
  end
  ---------------------------------------------------
  local function GUI_draw()
    gfx.mode = 0
    -- redraw: -1 init, 1 maj changes, 2 minor changes
    -- 1 back
    -- 2 gradient
    -- 3 smpl browser blit
    -- 4 stepseq 
    --  init
      if redraw == -1 then
        Data_Update()
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
        Data_Update()
        OBJ_Update()
        -- refresh backgroung
          gfx.dest = 1
          gfx.setimgdim(1, -1, -1)  
          gfx.setimgdim(1, gfx.w, gfx.h) 
          gfx.blit( 2, 1, 0, -- grad back
                    0,0,  obj.grad_sz,obj.grad_sz/2,
                    0,0,  gfx.w,gfx.h, 0,0)
        -- refresh all buttons
          for key in pairs(obj) do 
            if type(obj[key]) == 'table' and obj[key].show and not obj[key].blit then 
              GUI_DrawObj(obj[key]) 
            end  
          end  
        -- refresh blit list 1
          if blit_h then
            gfx.dest = 3
            gfx.setimgdim(3, -1, -1)  
            gfx.setimgdim(3, obj.tab_div, blit_h) 
            for key in spairs(obj) do 
              if type(obj[key]) == 'table' and obj[key].show and obj[key].blit and obj[key].blit== 3 then 
                local ret = GUI_DrawObj(obj[key])
              end  
            end    
          end
        -- refresh blit list 2
          if blit_h2 then
            gfx.dest = 4
            gfx.setimgdim(4, -1, -1)  
            gfx.setimgdim(4, obj.workarea.w-obj.scroll_w-1, blit_h2) 
            for key in spairs(obj) do 
              if type(obj[key]) == 'table' and obj[key].show and obj[key].blit and obj[key].blit== 4 then 
                local ret = GUI_DrawObj(obj[key])
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
          0,  
          obj.blit_y_src+obj.browser.y+obj.item_h2, 
          obj.tab_div, 
          blit_h,
          0,  
          obj.browser.y+obj.item_h2,              
          obj.tab_div, 
          blit_h, 
          0,0) 
      end    
    --  blit stepseq
      if blit_h2 and obj.blit_y_src2 then
        gfx.blit(4, 1, 0, -- backgr
          0,  
          obj.blit_y_src2, 
          obj.workarea.w, 
          blit_h2,
          
          obj.workarea.x,  
          obj.workarea.y+obj.item_h+obj.item_h2 +2,              
          obj.workarea.w, 
          blit_h2, 
          0,0) 
      end 
          
    -- drag&drop item to keys
      if action_export.state then
        local name = GetShortSmplName(action_export.fn)
        gfx.setfont(1, gui.font,gui.fontsz2 )
        GUI_DrawObj({ x = mouse.mx + 10,
                        y = mouse.my,
                        w = gfx.measurestr(name),
                        h = gfx.texth,
                        col = 'white',
                        state = 0,
                        txt = name,
                        show = true,
                        fontsz = gui.fontsz2,
                        alpha_back = 0.1})
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
  local function ExtState_Load()
    local def = ExtState_Def()
    for key in pairs(def) do 
      local es_str = GetExtState(def.ES_key, key)
      if es_str == '' then conf[key] = def[key] else conf[key] = tonumber(es_str) or es_str end
    end    
  end
  ---------------------------------------------------
  function ExtState_Load_Patterns()
    pat = {}
    local ret, str = GetProjExtState( 0, conf.ES_key, 'PAT' )
    if not ret then return end
    -- parse patterns
      for line in str:gmatch('<PAT[\n\r](.-)>') do   
        pat[#pat+1] = {}     
        for l2 in line:gmatch('[^\r\n]+') do          
          local key = l2:match('[%a]+')
          local val = l2:match('[%a][%s](.*)')
          if tonumber(val) then val = tonumber(val) end
          pat[#pat][key] = val
        end
      end
    -- parse params
      for line in str:gmatch('[^\r\n]+') do 
        if line:find('[%a]+ [%d]+') and line:find('[%a]+ [%d]+') == 1 then 
          local key = line:match('[%a]+')
          local val = line:match('[%d]+') if val then val = tonumber(val) end
          pat[key] = val
        end 
      end
  end
  ---------------------------------------------------
  function ExtState_Save_Patterns()
    local str = '//MPL_RS5K_PATLIST'
    local ind = '   '
    for k,v in spairs(pat, function(t,a,b) return tostring(b):lower() > tostring(a):lower() end) do 
    --for k in pairs(pat) do 
      if tonumber(k) then
        local pat_t = pat[k]
        str = str..'\n<PAT'
        for key in pairs(pat_t) do
          str = str..'\n'..ind..key..' '..pat_t[key]
        end
        str = str..'\n>'
       else
        str = str..'\n'..k..' '..pat[k]
      end
    end  
    msg('\nSAVE\n'..str)
    SetProjExtState( 0, conf.ES_key, 'PAT', str )
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
  local function OBJ_define()  
    obj.offs = 2
    obj.grad_sz = 200
    obj.item_h = 30  -- tabs
    obj.item_h2 = 20 -- list header
    obj.item_h3 = 15 -- list items
    obj.item_h4 = 40 -- steseq
    obj.scroll_w = 15
    obj.it_alpha = 0.35 -- under tab
    obj.it_alpha2 = 0.24 -- navigation
    
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
    obj.workarea =      { 
                y = 0,
                h = gfx.h,
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
    obj.workarea.x = obj.tab_div+1
    obj.workarea.w = gfx.w - obj.tab_div - 2
    --
    obj.scroll.x =  obj.tab_div-obj.scroll_w
    obj.scroll.val = slider_val
    obj.scroll.h = gfx.h-obj.item_h-obj.item_h2-3
    --
    for key in pairs(obj) do if type(obj[key]) == 'table' and obj[key].clear then obj[key] = nil end end
    if conf.tab == 0 then 
      local cnt_it = OBJ_GenSampleBrowser()
      if conf.keymode == 0 then OBJ_GenKeys() end
      obj.scroll.steps = cnt_it
     elseif conf.tab == 1 then 
      local cnt_it = OBJ_GenPatternBrowser()
      obj.scroll.steps = cnt_it   
      local cnt_it2 = OBJ_GenStepSequencer() 
      obj.scroll2 =  {clear = true,
                  x = gfx.w - obj.scroll_w,
                  y = obj.item_h+2+obj.item_h2,
                  w = obj.scroll_w,
                  h = gfx.h-obj.item_h-obj.item_h2-3,
                  col = 'white',
                  show = true,
                  state = 0,
                  alpha_back = 0.4,
                  mouse_scale = 100,
                  axis = 'y',
                  val = slider_val2 ,
                  is_slider = true,
                  func =  function(val) 
                            slider_val2 = lim(val, 0,1) 
                            redraw = 1
                          end}  
    end
    for key in pairs(obj) do if type(obj[key]) == 'table' then obj[key].context = key end end    
  end
-----------------------------------------------------------------------  
  function OBJ_GenStepSequencer()
    local s_cnt = 0
    for i = 1, 127 do
      if data[i] then 
        s_cnt = s_cnt + 1
      end
    end
    blit_h2 = s_cnt*obj.item_h4 + obj.workarea.y + obj.item_h2
    obj.blit_y_src2 = math.floor(slider_val2*(blit_h2-obj.item_h2*2-obj.item_h))  
    local cnt = 0          
    for i = 1, 127 do
      if data[i] then 
        cnt = cnt + 1 
        local a = 0.2
        obj['stseq'..i] = {  clear = true,
                  x = 0,
                  y = (cnt-1)*obj.item_h4,
                  w =  obj.workarea.w-obj.scroll_w,
                  h = obj.item_h4,
                  col = 'white',
                  state = 1,
                  txt= i,
                  aligh_txt = 1,
                  blit = 4,
                  show = true,
                  is_but = true,
                  fontsz = gui.fontsz2,
                  alpha_back = 0.4,
                  --a_line = 0,
                  mouse_offs_y = obj.blit_y_src2,
                  func =  function() 
                            
                          end}
      end    
    end
    --local cnt = lim((gfx.h-obj.browser.h)/s_cnt, 2, math.huge)
    return cnt
  end  
-----------------------------------------------------------------------   
  function OBJ_GenPatternBrowser()
    local up_w = 40
    obj.pat_new = { clear = true,
                  x = obj.browser.x,
                y = obj.browser.y,
                w = up_w,
                h = obj.item_h2,
                col = 'white',
                state = 0,
                txt= 'New',
                show = true,
                is_but = true,
                fontsz = gui.fontsz2,
                alpha_back = obj.it_alpha2,
                func =  function() 
                          local insert_at_index = #pat+1
                          table.insert(pat,insert_at_index,{NAME='pat'..insert_at_index,
                                                            GUID=genGuid('')})
                          pat.SEL = insert_at_index
                          ExtState_Save_Patterns()
                          redraw = 1
                        end} 
    obj.pat_dupl = { clear = true,
                  x = obj.browser.x+up_w+1,
                y = obj.browser.y,
                w = up_w,
                h = obj.item_h2,
                col = 'white',
                state = 0,
                txt= 'Dupl',
                show = true,
                is_but = true,
                fontsz = gui.fontsz2,
                alpha_back = obj.it_alpha2,
                func =  function() 
                          if not pat.SEL or not pat[ pat.SEL ] then return end
                          local insert_at_index = pat.SEL+1
                          table.insert(pat,insert_at_index,{NAME='pat'..insert_at_index})
                                                            --GUID=genGuid('')})                          
                          pat[insert_at_index] = CopyTable(pat[ pat.SEL ])
                          pat[insert_at_index].GUID=genGuid('')
                          pat.SEL = insert_at_index
                          ExtState_Save_Patterns()
                          redraw = 1                          
                        end}    
    obj.pat_rem = { clear = true,
                  x = obj.browser.x+(up_w+1)*2,
                y = obj.browser.y,
                w = up_w,
                h = obj.item_h2,
                col = 'white',
                state = 0,
                txt= 'Del',
                show = true,
                is_but = true,
                fontsz = gui.fontsz2,
                alpha_back = obj.it_alpha2,
                func =  function() 
                          if pat.SEL and pat[pat.SEL] then 
                            table.remove(pat, pat.SEL)
                            if not pat[pat.SEL] then for i = pat.SEL, 1, -1 do if pat[i] then pat.SEL = i break end end                           end
                            ExtState_Save_Patterns()
                            redraw = 1
                          end
                        end}   
    local cur_pat_name = '(not selected)'
    if pat.SEL and pat[pat.SEL] then cur_pat_name = pat[pat.SEL].NAME end
    obj.pat_current = { clear = true,
                  x = obj.browser.x+(up_w+1)*3,
                y = obj.browser.y,
                w = lim(obj.browser.w-(up_w+1)*3,up_w, math.huge),
                h = obj.item_h2,
                col = 'white',
                state = 0,
                txt= cur_pat_name ,
                show = true,
                is_but = true,
                fontsz = gui.fontsz2,
                alpha_back = obj.it_alpha,
                func =  function() 
                          
                        end}      
    local p_cnt = #pat
    --if #pat > 1 then p_cnt = #pat end
    blit_h = p_cnt*obj.item_h3 + obj.browser.y + obj.item_h2
    obj.blit_y_src = math.floor(slider_val*(blit_h-obj.item_h2*2-obj.item_h))            
    for i = 1, #pat do 
      local a = 0.2
      if pat.SEL and i == pat.SEL then a = gui.a2 end
      obj['patlist'..i] = 
                { clear = true,
                  x = obj.browser.x,
                  y = obj.browser.y + 1  + obj.item_h2+(i-1)*obj.item_h3,
                  w = obj.tab_div-obj.scroll_w- 1,
                  h = obj.item_h3,
                  col = 'white',
                  state = 1,
                  txt= pat[i].NAME,
                  --aligh_txt = 1,
                  blit = 3,
                  show = true,
                  is_but = true,
                  fontsz = gui.fontsz2,
                  alpha_back = a,
                  --a_line = 0,
                  mouse_offs_y = obj.blit_y_src,
                  func =  function() 
                            pat.SEL = i
                            ExtState_Save_Patterns()
                            redraw = 1
                          end}    
    end
    local cnt = lim((gfx.h-obj.browser.h)/p_cnt, 2, math.huge)
    return cnt
  end
  ---------------------------------------------------
  function OBJ_GenSampleBrowser()
    local up_w = 25
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
                alpha_back = obj.it_alpha2,
                func =  function() 
                          local path = GetParentFolder(conf.cur_smpl_browser_dir) 
                          if path then 
                            conf.cur_smpl_browser_dir = path 
                            ExtState_Save()
                            slider_val = 0
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
                alpha_back = obj.it_alpha,
                func =  function() Menu(Menu_FormBrowser()) end}
    local cur_dir_list = GetDirList(conf.cur_smpl_browser_dir)
    local list_cnt = #cur_dir_list
    --if #cur_dir_list > 2 then list_cnt = #cur_dir_list end
    blit_h = list_cnt*obj.item_h3 + obj.browser.y + obj.item_h
    obj.blit_y_src = math.floor(slider_val*(blit_h-obj.item_h2*2-obj.item_h))
    for i = 1, #cur_dir_list do
      local txt = cur_dir_list[i][1]
      local txt2 if  cur_dir_list[i][2] == 0 then txt2 = '>' end
      obj['browser_dirlist'..i] = 
                { clear = true,
                  x = obj.browser.x,
                  y = obj.browser.y + 1  + obj.item_h2+(i-1)*obj.item_h3,
                  w = obj.tab_div-obj.scroll_w,
                  h = obj.item_h3,
                  col = 'white',
                  state = 0,
                  txt= txt,
                  txt2=txt2,
                  aligh_txt = 1,
                  blit = 3,
                  show = true,
                  is_but = true,
                  fontsz = gui.fontsz2,
                  alpha_back = 0.2,
                  a_line = 0.1,
                  mouse_offs_y = obj.blit_y_src,
                  func =  function() 
                            local p = conf.cur_smpl_browser_dir..'/'..cur_dir_list[i][1] 
                            p = p:gsub('\\','/')
                            if not IsSupportedExtension(p) then 
                              conf.cur_smpl_browser_dir = p
                              ExtState_Save()
                              redraw = 1
                             else
                              GetSampleToExport(p)
                            end
                          end}    
    end
    local cnt = lim((gfx.h-obj.browser.h)/list_cnt, 2, math.huge)
    return cnt
  end
  -----------------------------------------------------------------------    
    function GetNoteStr(val) 
      local oct_shift = conf.oct_shift-7
      if conf.key_names == 0 then
        if not val then return end
        local val = math.floor(val)
        local oct = math.floor(val / 12)
        local note = math.fmod(val,  12)
        local key_names = {'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B',}
        if note and oct and key_names[note+1] then return key_names[note+1]..oct+oct_shift end
       elseif conf.key_names == 1 then
        if not val then return end
        local val = math.floor(val)
        local oct = math.floor(val / 12)
        local note = math.fmod(val,  12)
        local key_names = {'C', 'D♭', 'D', 'E♭', 'E', 'F', 'G♭', 'G', 'A♭', 'A', 'B♭', 'B',}
        if note and oct and key_names[note+1] then return key_names[note+1]..oct+oct_shift end  
       elseif conf.key_names == 2 then
        if not val then return end
        local val = math.floor(val)
        local oct = math.floor(val / 12)
        local note = math.fmod(val,  12)
        local key_names = {'Do', 'Do#', 'Re', 'Re#', 'Mi', 'Fa', 'Fa#', 'Sol', 'Sol#', 'La', 'La#', 'Si',}
        if note and oct and key_names[note+1] then return key_names[note+1]..oct+oct_shift end      
       elseif conf.key_names == 3 then
        if not val then return end
        local val = math.floor(val)
        local oct = math.floor(val / 12)
        local note = math.fmod(val,  12)
        local key_names = {'Do', 'Re♭', 'Re', 'Mi♭', 'Mi', 'Fa', 'Sol♭', 'Sol', 'La♭', 'La', 'Si♭', 'Si',}
        if note and oct and key_names[note+1] then return key_names[note+1]..oct+oct_shift end       
       elseif conf.key_names == 4 -- midi pitch
        then return val
       elseif 
        conf.key_names == 5 -- freq
        then return math.floor(440 * 2 ^ ( (val - 69) / 12))..'Hz'
       elseif 
        conf.key_names == 6 -- empty
        then return ''
       elseif 
        conf.key_names == 7 then -- ru
        if not val then return end
        local val = math.floor(val)
        local oct = math.floor(val / 12)
        local note = math.fmod(val,  12)
        local key_names = {'До', 'До#', 'Ре', 'Ре#', 'Ми', 'Фа', 'Фа#', 'Соль', 'Соль#', 'Ля', 'Ля#', 'Си'}
        if note and oct and key_names[note+1] then return key_names[note+1]..oct+oct_shift end  
       elseif conf.key_names == 8 then
        if not val then return end
        local val = math.floor(val)
        local oct = math.floor(val / 12)
        local note = math.fmod(val,  12)
        local key_names = {'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B',}
        if note and oct and key_names[note+1] then return key_names[note+1]..oct+oct_shift..'\n'..val end              
      end
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
    ---------------------------------------------------
    function GetSampleNameByNote(note)
      local str = ''
      for key in pairs(data) do
        if key == note then 
          local fn = ''
          for i = 1, #data[key] do
            fn = fn..GetShortSmplName(data[key][i].fn)          
          end
          return fn, true
        end
      end
      return str
    end
    ---------------------------------------------------
    function OBJ_GenKeys()
      local opt_h = obj.item_h +  1 + obj.item_h2 + 1
      local key_w = math.ceil(obj.workarea.w/7)
      local key_h = math.ceil(0.5*(gfx.h - opt_h))
      local shifts  = {{0,1},
                  {0.5,0},
                  {1,1},
                  {1.5,0},
                  {2,1},
                  {3,1},
                  {3.5,0},
                  {4,1},
                  {4.5,0},
                  {5,1},
                  {5.5,0},
                  {6,1},
                }
                
      for i = 1, 12 do
        local note = (i-1)+12*conf.oct_shift
        local fn, ret = GetSampleNameByNote(note)
        local col = 'white'
        if ret then col = 'green' end
        obj['keys_'..i] = 
                  { clear = true,
                    x = obj.workarea.x+shifts[i][1]*key_w,
                    y = opt_h+ shifts[i][2]*key_h,
                    w = key_w,
                    h = key_h,
                    col = col,
                    state = 0,
                    txt= GetNoteStr(note)..'\n\r'..fn,
                    linked_note = note,
                    show = true,
                    is_but = true,
                    alpha_back = 0.2+ 0.2*shifts[i][2],
                    a_frame = 0.1,
                    aligh_txt = 5,
                    fontsz = gui.fontsz2,
                    func =  function() 
                              if obj[ mouse.context ] and obj[ mouse.context ].linked_note then
                                StuffMIDIMessage( 0, '0x9'..string.format("%x", 0), obj[ mouse.context ].linked_note,100) 
                              end
                            end}       
      end
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
  function GetSampleToExport(fn)
    action_export = {state = true,
                     fn = fn}
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
      local state= mouse.mx > b.x 
              and mouse.mx < b.x+b.w 
              and mouse.my > b.y - b.mouse_offs_y
              and mouse.my < b.y+b.h - b.mouse_offs_y
      if state and not b.ignore_mouse then mouse.context = b.context return true end
    end  
  end
 ------------- -------------------------------------- 
  function MOUSE_Click(b,flag) 
    if b.ignore_mouse then return end
    if not flag then flag = 'L' end 
    if MOUSE_Match(b) and mouse[flag..'MB_state'] and not mouse['last_'..flag..'MB_state'] then 
      mouse.context_latch = mouse.context
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
      if mouse.mx < obj.browser.x + obj.browser.w  and mouse.wheel_trig and mouse.wheel_trig ~= 0 then
        slider_val = lim(slider_val - mouse.wheel_trig/conf.mouse_wheel_res,0,1)
        redraw = 1
      end

    -- scroll stepseq
      if mouse.mx < obj.workarea.x + obj.workarea.w  and mouse.wheel_trig and mouse.wheel_trig ~= 0 then
        slider_val2 = lim(slider_val2 - mouse.wheel_trig/conf.mouse_wheel_res,0,1)
        redraw = 1
      end
          
    -- mouse release    
      if mouse.last_LMB_state and not mouse.LMB_state   then  
        -- clear context
          mouse.context_latch = ''
          mouse.context_latch_val = 0
        -- clear export state
          if action_export.state 
            and obj[ mouse.context ] 
            and obj[ mouse.context ].linked_note then
              local note = obj[ mouse.context ].linked_note
              ExportItemToRS5K(action_export.fn, note)
          end
          action_export = {}
        -- clear note
          for i = 1, 127 do StuffMIDIMessage( 0, '0x8'..string.format("%x", 0), i, 100) end
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
  function ExportItemToRS5K(fn, note)
    local ex = false
    for key in pairs(data) do
      if key == note then
        TrackFX_SetNamedConfigParm(  data.tr_pointer, data[key][1].idx, 'FILE0', fn)
        TrackFX_SetNamedConfigParm(  data.tr_pointer, data[key][1].idx, 'DONE', '') 
        redraw = 1
        ex = true
        break
      end
    end
    if not ex and data.tr_pointer then 
      local rs5k_pos = TrackFX_AddByName( data.tr_pointer, 'ReaSamplomatic5000', false, -1 )
      TrackFX_SetNamedConfigParm(  data.tr_pointer, rs5k_pos, 'FILE0', fn)
      TrackFX_SetNamedConfigParm(  data.tr_pointer, rs5k_pos, 'DONE', '')      
      reaper.TrackFX_SetParamNormalized( data.tr_pointer, rs5k_pos, 2, 0) -- gain for min vel
      reaper.TrackFX_SetParamNormalized( data.tr_pointer, rs5k_pos, 3, note/127 ) -- note range start
      reaper.TrackFX_SetParamNormalized( data.tr_pointer, rs5k_pos, 4, note/127 ) -- note range end
      reaper.TrackFX_SetParamNormalized( data.tr_pointer, rs5k_pos, 5, 0.5 ) -- pitch for start
      reaper.TrackFX_SetParamNormalized( data.tr_pointer, rs5k_pos, 6, 0.5 ) -- pitch for end
      reaper.TrackFX_SetParamNormalized( data.tr_pointer, rs5k_pos, 8, 0 ) -- max voices = 0
      reaper.TrackFX_SetParamNormalized( data.tr_pointer, rs5k_pos, 9, 0 ) -- attack
      reaper.TrackFX_SetParamNormalized( data.tr_pointer, rs5k_pos, 11, 0 ) -- obey note offs
      redraw = 1
    end
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
  ClearConsole()
  ExtState_Load()  
  ExtState_Load_Patterns()
  gfx.init('MPL '..scr_title..' '..vrs,
            conf.wind_w, 
            conf.wind_h, 
            conf.dock, conf.wind_x, conf.wind_y)
  OBJ_define()
  OBJ_Update()
  run()
  
  
