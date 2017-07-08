  name = 'DatronGUI'
  vrs = '2.13'
  --local data = {}
  local obj = {}
  local mouse = {}
  --skip_check = true
  
    --[[  
      - 2.13  08.07.2017
        Action_RenderFromOperation
      - 2.12  23.06.2017
        parse Clear ID
      - 2.11  29.05.2017
        parse 6symb IDs
      - 2.10  25.05.2017
        change rename parser to csv [stock][ts][model]
      - 2.06  24.05.2017
        increased max singleparts in one ID up to 100 
      - 2.05  04.05.2017
        Convert_DateToTimestamp check for proper values
      - 2.04  26.04.2017
        comtime coeff = 1.1
      - 2.03  25.04.2017
        Convert date to timestamp fix
      - 2.02  19.04.2017
        auto generate header
      - 2.01  18.04.2017
        support 6digits ID for search unchecked
        store last ID when search unchecked for set stat
        content check when rename
        content check: cat3,5,7,8, 
        content check: screwchannel order
        content check: match cat number to interface count
        fix timing bugs
      - 2.0   17.04.2017
        + GUI improvements
        + SetStat: check count < 30
        + SetStat: check if not canceled after ID
      - 1.71 13.03.2017
        divisions for parse stat
      - 1.70 26.12.2016
        clear logs Action
      - 1.69 23.12.2016
        prevent coping from NIC paths
      - 1.68 22.12.2016
        fix ID/compressed into Get_ID() function
      - 1.67
        fix some stat ID
      - 1.66
        fix IDs
      - 1.65
        improvements in admin stat-format: proper IDs, queue
      - 1.62
        fix non exist model name for rename MCR
      - 1.61
        formatted month/day on AddFromMCR
      - 1.6
        move MCR
      - 1.5 10.2016
        add browse unchecked function
        additional functions moved to context menu      
    ]]
  
  
  --  MSK
  data = {
          
          machines = {
                      {path= [=[V:\]=],       name='D1',         offset_sec=700,   bypass = false },  
                      {path= [=[Y:\]=],       name='D2',         offset_sec=550,   bypass = false},
                      {path= [=[X:\]=],       name='D3',         offset_sec=600,   bypass = false}
                      },
          count_machines = 4,
          log_path = [=[Z:\DATRON\Datron MSK.txt]=],
          stat_path = [=[Z:\DATRON\Files_STL_Checked\Stat.txt]=]  ,
          stat_path0 = [=[Z:\DATRON\Files_STL_Checked]=]  ,
          MCR_path = [=[C:\Users\Public\Documents\hyperDENT\NC Output\]=],
          unchecked_path = [=[Z:\files_for_check\Unchecked]=],
          run_update = true,  
          trig_time = 60,-- sec
          coefficient_time = 1.1}
  
  -- SPB        
  --[[data = {
          
          machines = {
                      {path= [=[V:\]=],       name='D1',         offset_sec=700,   bypass = false },  
                      {path= [=[Y:\]=],       name='D2',         offset_sec=450,   bypass = false},
                      {path= [=[X:\]=],       name='D3',         offset_sec=500,   bypass = false}
                      },
          count_machines = 2,                                                           -- count for proper division/mod when counting milled parts with Menu/Get(MM/YYYY)
          log_path = [=[Z:\DATRON\Datron MSK.txt]=],                                    -- real time state of milling
          stat_path = [=[Z:\DATRON\Files_STL_Checked\Stat.txt]=]  ,                     -- txt file for checked statistics stored with "set" button
          stat_path0 = [=[Z:\DATRON\Files_STL_Checked]=]  ,                             -- path for saving files searched with "Search Unchecked"
          MCR_path = [=[C:\Users\Public\Documents\hyperDENT\NC Output\]=],              -- output of HyperDent MCR/NC files
          unchecked_path = [=[Z:\files_for_check\Unchecked]=],                          -- unchecked path
          run_update = true,  
          trig_time = 60,-- sec
          coefficient_time = 1.1}        ]]  
  ----------------------------------------------------------------------          
  function Action_RenderFromOperation()    
    local retval, fp = reaper.GetUserFileNameForRead('', 'Open MCR', '.mcr' )
    if not retval then return end
    local retval2, rend_from = reaper.GetUserInputs( 'Render from...', 1, 'operation #', '' )
    if not retval2 or not tonumber(rend_from) then return end 
    
    -- read MCR context
      fp_new = fp:sub(0,-5)..'-OP_'..rend_from..'.mcr'
      f = io.open(fp, 'r')
      if not f then return end
      cont = f:read('a')
      f:close()
    
    -- get output stuff
      MCR_header = cont:match('.-;OPERATION'):sub(0,-11)
      MCR_follow = cont:match(';OPERATION '..rend_from..'.*')
    
    -- write output stuff
      if MCR_header and MCR_follow then 
        f = io.open(fp_new, 'w')
        if not f then return end
        f:write(MCR_header..MCR_follow)
        f:close()
      end
  end
  
      
  ----------------------------------------------------------------------
  function Objects_Init()  -- static variables
    --if debug_mode then msg('define obj') end
    if gfx.w < 100 then gfx.w = 100 end
    if gfx.h < 100 then gfx.h = 100 end
    local OS_switch = reaper.GetOS():find('Win') or reaper.GetOS():find('Unknown')    
    obj = {
                    main_w = 320,
                    main_h = 240,
                    offs = 1,
                    
                    w1 = 120,                      -- button               
                    
                    h1  = 50,                     -- button
                    h2 = 3,                     -- progress bar
                    min_w1 = 500,                 -- layers gain
                    
                    fontname = 'Calibri',
                    fontsize1 = 18, -- tabs     
                    
                    txt_alpha1 = 0.7,
                    
                    glass_side = 200,
                    
                    blit_alpha1 = 0.4,
                    blit_alpha2 = 0.7,          -- machines alpha progress
                    
                    gui_color = {['back'] = '20 20 20',
                                  ['back2'] = '51 63 56',
                                  ['black'] = '0 0 0',
                                  ['green'] = '130 255 120',
                                  ['blue2'] = '100 150 255',
                                  ['blue'] = '127 204 255',
                                  ['white'] = '255 255 255',
                                  ['red'] = '255 130 70',
                                  ['green_dark'] = '102 153 102',
                                  ['yellow'] = '200 200 0',
                                  ['pink'] = '200 150 200',
                                },
                    but = {}
                  }
                  
    obj.but.rename = {x = gfx.w - obj.w1,
                      y = 0, 
                      w = obj.w1,
                      h = obj.h1,
                      txt = 'Rename MCR/NC',
                      a_frame = obj.blit_alpha1,
                      a_txt = obj.txt_alpha1,
                      fontname = obj.fontname,
                      fontsize = obj.fontsize1,
                      func = function() Action_RenameMCR() end}
                      
               
    obj.but.search_unchecked = {x = gfx.w - obj.w1,
                      y = obj.h1, 
                      w = obj.w1,
                      h = obj.h1,
                      txt = 'Search\nUnchecked',
                      a_frame = obj.blit_alpha1,
                      a_txt = obj.txt_alpha1,
                      fontname = obj.fontname,
                      fontsize = obj.fontsize1,
                      func = function() Action_SearchUnchecked() end}                      
                      
    obj.but.setTable = {x = gfx.w - obj.w1,
                      y = obj.h1*2, 
                      w = obj.w1,
                      h = obj.h1,
                      txt = 'Set',
                      a_frame = obj.blit_alpha1,
                      a_txt = obj.txt_alpha1,
                      fontname = obj.fontname,
                      fontsize = obj.fontsize1,
                      func = function() Action_SetSingleStat() end}
                      
    obj.but.menu = {x = gfx.w - obj.w1,
                      y = obj.h1*3, 
                      w = obj.w1,
                      h = obj.h1,
                      txt = 'Menu >',
                      a_frame = obj.blit_alpha1,
                      a_txt = obj.txt_alpha1,
                      fontname = obj.fontname,
                      fontsize = obj.fontsize1,
                      func = function() Menu() end}  
    obj.but.trig_line = {x=0,
                     y = 0,
                     w = gfx.w,
                     h = obj.h2,
                     a_frame = 0.8,
                     col_frame = 'green',
                     refresh_always = true}
                     
    for i = 1, #data.machines do
      obj.but['machine'..i] = 
                      {x = 0,
                      y = (i-1)*math.floor(gfx.h/#data.machines)+obj.h2, 
                      w = gfx.w-obj.w1-obj.offs,
                      h = math.floor(gfx.h/#data.machines),
                      txt = 'D'..i,
                      a_frame = obj.blit_alpha2,
                      a_txt = obj.txt_alpha1,
                      fontname = obj.fontname,
                      fontsize = obj.fontsize1,
                      col_frame = 'blue',
                      func = function() msg('m'..i) end}  
    end    
    return obj
  end
  -------------------------------------------------------------------- 
  function F_GetComTime(file_path) local comtime
    if not file_path then return end
    local file = io.open(file_path, 'r')
    comtime = 1
    if file then
      local content = file:read(2000)
      if not content then return comtime end
      for line in content:gmatch('[^\n]+') do        
        if line:find('Tooltime') then 
          local t_time = line:reverse():match('[%d]+'):reverse()
          if tonumber(t_time) then comtime = comtime + tonumber(t_time) end
        end
      end
      file:close()
    end
    return comtime * data.coefficient_time
  end
  -------------------------------------------------------------------- 
  function Menu()
    gfx.x, gfx.y = mouse.mx, mouse.my
    local actions = {
              {name = 'Statistics: get (MM/YYYY)',       func = function () str = Action_ParseStat(nil,nil,true) msg(str) end},
              {name = 'Statistics: Open stat file|', func = function () local cmd = 'start "" "'..data.stat_path..'"'  os.execute(cmd) end},
              {name = 'Log: Search by ID', func = function () Action_SearchLogsByID()  end},
              {name = 'Log: Clear all|', func = function () for i = 1, #data.machines do Action_Clear_Logs(data.machines[i].path..'Protokoll.txt') end end},
              {name = 'Render MCR from custom operation number|', func = function () Action_RenderFromOperation()  end},
              
              {name = 'Open current administrator file', func = function () local cmd = 'start "" "'..data.log_path..'"'  os.execute(cmd)  end}
              
              }
    -- form str
        str = ''
        for i = 1,#actions do str = str..'|'..actions[i].name end        
        ret = gfx.showmenu(str:sub(2))
        if ret > 0 then load(actions[ret].func) end
  end
  ---------------------------------------------------------------------------     
    function msg(s) if s then reaper.ShowConsoleMsg(s..'\n') end end
    --------------------------------------------------------------------------- 
      function Action_Clear_Logs(filePath)
        local file = io.open(filePath, 'r')
        if not file then return end
        local content = file:read("*all")    
        local t = {}
        for line in content:gmatch('[^\n]+') do t[#t+1] = line  end
        
        for i = 1, #t do
          if t[i]:find('job start') then  open = true end           
          if open then
            if not (t[i]:find('Start') or t[i]:find('Ende') or t[i]:find('Dauer')) then t[i] = '' end
          end
          if t[i]:find('job end') then  open = false end 
        end    
        local out_str = table.concat(t, '\n')
        out_str = out_str:gsub('[\n]+', '\n')
        file:close()    
        local file = io.open(filePath, 'w')
        file:write(out_str)
        file:close()
      end
  -------------------------------------------------------------------- 
  function Action_SearchLogsByID()
    local retval, retvals_csv = reaper.GetUserInputs( 'Search by ID', 1, '', '' )
    if tonumber(retvals_csv) then
      local ID = tonumber(retvals_csv)
      local str = ''
      for i = 1, #data.machines do
        local file_path = data.machines[i].path..'Protokoll.txt'
        local file = io.open(file_path, 'r')
        if file then
          local content = file:read('a')
          for line in content:gmatch('[^\n]+') do
            if line:find(ID) and (line:find('Start') or line:find('Ende'))   then
              str = str..'\n'..i..' '..line
            end
          end
          file:close()
        end
      end
      msg(str)
    end
  end
  -------------------------------------------------------------------- 
  function Action_ParseStat(month, year,get_for_table)
    local filePath = data.stat_path
    
    if not month or not year then
      local retval, retvals_csv = reaper.GetUserInputs( 'GetStat', 2, 'month,year', '' )
      local t = {}
      for number in retvals_csv:gmatch('[%d]+') do
        t[#t+1] = number
      end
      month, year = tonumber(t[1]), tonumber(t[2])
      reaper.ClearConsole()
    end
    
    if month and year then        
      local file = io.open(filePath, 'r')
      if not file then return end
      local content = file:read("*all")
      local t = {}
      for line in content:gmatch('[^\n]+') do  t[#t+1] = line end
      local t2 = {}
      for i = 1, #t do        
        day_s, month_s, year_s = t[i]:match('([%d]+).([%d]+).([%d]+)')
        day_s, month_s, year_s = tonumber(day_s), tonumber(month_s), tonumber(year_s)
        if month_s == month and year_s == year then
          local cur_cnt = t[i]:match('single=([%d]+)')          
          if not t2[day_s] then t2[day_s] = 0 end
          t2[day_s] = t2[day_s] + cur_cnt
        end
      end    
      local com = 0
      local cnt_mach = data.count_machines
      local str  = 'Выпилено/рассчитано за '..month..'.'..year..'\n'
      for day = 1, 31 do
        if t2[day] then 
          local num = math.floor(t2[day])
          num_div = num % data.count_machines
          num_div0 = math.floor(num / data.count_machines )
          str = str..'\n'..day..'.'..month..' - '..num
          if get_for_table then str = str..'     (table:'..num_div0..' '..num_div..')' end
          com = com + t2[day] 
        end
      end
      str = str..'\n\nВсего: '..math.floor(com)
      file:close() 
      
      return str   
    end
  end
  -------------------------------------------------------------------- 
  function Action_SetSingleStat()
    local type_str = 'single'
    local file = io.open(data.stat_path, 'r+')
    if not file then file = io.open(data.stat_path, 'w') end
    local content = file:read("*all")      
    local retval, retvals_csv = reaper.GetUserInputs( 'Datron Count Parts: '..type_str, 1, '', '' )
    if retval and tonumber(retvals_csv) and tonumber(retvals_csv) < 100  then
      local def_ID
      if data.last_search_unchecked then def_ID = data.last_search_unchecked else def_ID = '' end
      local ret, ID = reaper.GetUserInputs( 'Datron Count Parts: '..type_str, 1, 'ID', def_ID )
      if ret then 
        local line = os.date()..' '..type_str..'='..tonumber(retvals_csv)..' ID='..ID..'\n'
        file:write(line)
        obj.but.setTable.txt = 'Set\n'..ID
        update_gfx = true
      end
    end    
    file:close()    
  end  
  --------------------------------------------------------------------
  function GUI_backgr(w,h)
    if not w then w = gfx.w end
    if not h then h = gfx.h+20 end
    F_Get_SSV(obj.gui_color.black)
    gfx.a = 1
    gfx.rect(0,0,w, h, 1)
    F_Get_SSV(obj.gui_color.white)
    gfx.a = 0.2
    gfx.rect(0,0,w, h, 1)
  end    
  -----------------------------------------------------------------------
  function F_Get_SSV(s)
    if not s then return end
    local t = {}
    for i in s:gmatch("[%d%.]+") do t[#t+1] = tonumber(i) / 255 end
    gfx.r, gfx.g, gfx.b = t[1], t[2], t[3]
  end  
  --------------------------------------------------------------------
  function F_conv_int_to_logic(num, inp1, inp2)
    if (num and type(num) == 'number' and num == 1) 
      or (num and type(num) == 'boolean' and num == true) 
      or (num and type(num) == 'table') then
      if inp2 then return inp2 end
      return true
     else
      if inp1 then return inp1 end
      return false
    end
  end   
  --------------------------------------------------------------------
  function Action_SearchUnchecked()
    local retval, retvals_csv = reaper.GetUserInputs( 'Add from Unchecked by ID', 1, '', '' )
    if retvals_csv:len() ~= 5 and retvals_csv:len() ~= 6 then return end
    if not tonumber(retvals_csv) then return end
    local ID = tonumber(retvals_csv)
    data.last_search_unchecked = ID
    files = {}
    -- search unchecked for path
      for i = 1, 50000 do 
         
        local file_name0 = reaper.EnumerateFiles( data.unchecked_path, i-1 ) 
        if file_name0 and file_name0:find(ID) ~= nil then 
          if file_name0:find('stl') 
            --or file_name0:find('pts') 
            --or file_name0:find('constructionInfo')
            then
            files[#files+1] = {file_name =file_name0,  path = data.unchecked_path} 
          end
        end
        
        local path = reaper.EnumerateSubdirectories( data.unchecked_path, i-1 )
        if path and path:find(ID) ~= nil then 
          out_path = data.unchecked_path..'\\'..path
          for j = 0, 50 do
            file_name = reaper.EnumerateFiles( out_path, j-1 )
            --if not file_name then break end
            if file_name and file_name:find('stl') then 
              files[#files+1] = {file_name =file_name,  
                                 path = out_path}
            end
          end 
          
          --goto skip_to_files
          --break 
        end    
      end
      
      for i = 1, #files do
        if check_NIC(files[i].file_name) or check_NIC(files[i].path) then return end
      end
      
      if #files == 0 then return end
    
    -- create dir if not exist
      local temp = os.date("*t", os_time)
      local dir_path = 
        data.stat_path0..'\\'..
        temp.year..'\\'..
        string.format("%02d", temp.month)..'\\'..
        string.format("%02d", temp.day)..'\\'..
        ID
      os.execute('md '..dir_path)
      
    -- copy found files to folder
      local new_nameco
      for i = 1, #files do
        if files[i].file_name:find(ID) == nil then 
          new_name = files[i].file_name:gsub('.stl', '-'..ID..'.stl')
         else
          new_name = files[i].file_name
        end
        local command = 'copy "'..files[i].path..'\\'..files[i].file_name..'" "'..dir_path..'\\'..files[i].file_name..'"'
        local command2 = 'rename "'..dir_path..'\\'..files[i].file_name..'" "'..new_name..'"'
        --msg(command)
        --msg(command2)
        os.execute(command)
        os.execute(command2)
      end
      local files_str = ''
      for i = 1, #files do files_str = files_str..'\n'..files[i].file_name end
      reaper.MB(#files..' STL copied: \n'..files_str, 'Add from unchecked', 0)
  end
  ---------------------------------------------------------------------------      
    function check_NIC(str)
      local t = {}
      for i = 1, 100 do t[#t+1] = string.byte(str,i) end  
      for i = 1, #t do 
        if t[i] == 209 or t[i] == 208  then return true end
      end  
    end
  --------------------------------------------------------------------------------  
  function GUI_draw()
    gfx.mode = 0
    -- update buf on start
      if update_gfx_onstart then
          -- back
          gfx.dest = 3
          gfx.setimgdim(3, -1, -1)
          gfx.setimgdim(3, obj.glass_side, obj.glass_side)
          gfx.a = 1
          local r,g,b,a = 0.9,0.9,1,0.4
          gfx.x, gfx.y = 0,0
          local drdx = 0.00001
          local drdy = 0
          local dgdx = 0.0001
          local dgdy = 0.0003
          local dbdx = 0.0002
          local dbdy = 0
          local dadx = 0.0001
          local dady = 0.0009
          gfx.gradrect(0,0,obj.glass_side, obj.glass_side,
                          r,g,b,a,
                          drdx, dgdx, dbdx, dadx,
                          drdy, dgdy, dbdy, dady)
          update_gfx_on_start = nil
      end

    -- update static buffers
    if update_gfx then
        gfx.a = 1
        gfx.dest = 10
        gfx.setimgdim(10, -1, -1)
        gfx.setimgdim(10, gfx.w, gfx.h)
        GUI_backgr()        
        for key in pairs(obj.but) do if not obj.but[key].refresh_always then GUI_obj(obj.but[key]) end end
    end
    
    
    gfx.dest = -1
    gfx.a = 1    
    gfx.blit(10, 1, 0,
            0,0,  gfx.w, gfx.h,
            0,0,  gfx.w, gfx.h, 0,0)
    gfx.a =1
    
    for key in pairs(obj.but) do if obj.but[key].refresh_always then GUI_obj(obj.but[key]) end end
    
    update_gfx = false
    gfx.update()
  end  
  --------------------------------------------------------------------
  function msg(s)
    if not s then return end
    reaper.ShowConsoleMsg(s)
    reaper.ShowConsoleMsg('\n')
  end
  --------------------------------------------------------------------
  function GUI_obj(t)
    if not t then return end
    local  x,y,w,h = t.x, t.y, t.w, t.h
    if w < obj.offs then return end
    if t.a_frame then gfx.a = t.a_frame end
    local y1 = y
    local h1 = h
    if debug_mode then 
      gfx.a = 0.1
      gfx.line(x,y,x+w,y+h)
      gfx.line(x,y+h,x+w,y)
      gfx.rect(x,y,w,h,0)
    end
    
    if not t.frame_type or t.frame_type == 1 then -- 5=rect frame
      gfx.blit(3, 1, math.rad(0),
                0,
                0,
                obj.glass_side,
                obj.glass_side,
                x,y1,w,h1/2,
                0, 0)
      gfx.blit(3, 1, math.rad(180),
                0,
                0,
                obj.glass_side,
                obj.glass_side,
                x-1,y1+math.floor(h1/2),w+1,math.floor(h1/2) ,
                0, 0)       
      
      if t.col_frame then
        local w_pr
        if t.progress and t.progress > 0 then 
          F_Get_SSV(obj.gui_color.green)
          w_pr = w * t.progress
         else
          F_Get_SSV(obj.gui_color.blue)
          w_pr = w
        end
        
        if t.a_frame then gfx.a = t.a_frame end
        gfx.rect(x,y,w_pr,h-1,1)
        gfx.a = 0.01
        gfx.rect(x,y,w,h,1)
      end  
      
      if t.context then
        gfx.a = 0.5
        F_Get_SSV(obj.gui_color.white)
        gfx.rect(x,y,w,h,0)
      end
      if t.txt_col then F_Get_SSV(obj.gui_color[t.txt_col]) else gfx.set(1,1,1) end
      if t.txt then
        gfx.setfont(1, t.fontname, t.fontsize)
        local cnt = 0 for word in t.txt:gmatch('[^\n]+') do cnt = cnt + 1 end
        if cnt == 1 then 
          local measurestrname = gfx.measurestr(t.txt)
                    gfx.x = x + (w-measurestrname)/2
                    gfx.y = y + (h-gfx.texth)/2
                    if t.a_txt then gfx.a = t.a_txt end
                    gfx.drawstr(t.txt)
         else
          y = y + h/2 - (gfx.texth*(cnt+2))/2
          cnt = 1
          for word in t.txt:gmatch('[^\n]+') do            
            local measurestrname = gfx.measurestr(word)
            gfx.x = x + (w-measurestrname)/2
            gfx.y = y + cnt*gfx.texth
            if t.a_txt then gfx.a = t.a_txt end
            gfx.drawstr(word)
            cnt = cnt + 1
          end
        end
      end              
    end
    
  end
  --------------------------------------------------------------------
  function Objects_Update()
    obj.but.rename.x = gfx.w-obj.w1
    local h_but = gfx.h/4
    obj.but.rename.h=h_but
    
    obj.but.search_unchecked.x = gfx.w-obj.w1
    obj.but.search_unchecked.y=h_but
    obj.but.search_unchecked.h=h_but
    
    obj.but.setTable.x = gfx.w-obj.w1
    obj.but.setTable.y=h_but*2
    obj.but.setTable.h=h_but
    
    obj.but.menu   .x = gfx.w-obj.w1
    obj.but.menu.y=h_but*3
    obj.but.menu.h=h_but
    
    for i = 1, #data.machines do
      obj.but['machine'..i].y = (i-1)*math.floor(gfx.h/#data.machines)+obj.h2
      obj.but['machine'..i].h =  math.floor(gfx.h/#data.machines)
      obj.but['machine'..i].w = gfx.w-obj.w1-obj.offs
    end
    
    if progress_trig_upd then obj.but.trig_line.w = progress_trig_upd * gfx.w end
  end
  -----------------------------------------------------------------------
  function MOUSE_button(xywh)
    if MOUSE_match(xywh) then 
      xywh.context = true
      if mouse.LMB_state and not mouse.last_LMB_state then xywh.func() end
     else 
      xywh.context = false
    end
  end
  ------------------------------------------------------------------
  function MOUSE_match(b) if mouse.mx > b.x and mouse.mx < b.x+b.w and mouse.my > b.y and mouse.my < b.y+b.h then return true end end
  -----------------------------------------------------------------------
  function MOUSE_get()
    mouse.abs_x, mouse.abs_y = reaper.GetMousePosition()
    mouse.mx = gfx.mouse_x
    mouse.my = gfx.mouse_y
    mouse.LMB_state = gfx.mouse_cap&1 == 1
    mouse.RMB_state = gfx.mouse_cap&2 == 2
    mouse.Ctrl_state = gfx.mouse_cap&4 == 4
    mouse.Alt_state = gfx.mouse_cap&17 == 17
    mouse.Shift_state = gfx.mouse_cap&8 == 8
    mouse.wheel = gfx.mouse_wheel

    for key in pairs(obj.but) do MOUSE_button(obj.but[key]) end
    --if MOUSE_match({x=0,y=0,w=gfx.w,h=gfx.h}) and mouse.last_mx and (mouse.last_mx ~= mouse.mx or mouse.last_my ~= mouse.my ) then update_gfx = true   end
    
    -- mouse release
      mouse.last_mx = mouse.mx
      mouse.last_my = mouse.my
      mouse.last_LMB_state = mouse.LMB_state
      mouse.last_RMB_state = mouse.RMB_state
      mouse.last_MMB_state = mouse.MMB_state
      mouse.last_Ctrl_LMB_state = mouse.Ctrl_LMB_state
      mouse.last_Ctrl_state = mouse.Ctrl_state
      mouse.last_Alt_state = mouse.Alt_state
      mouse.last_wheel = mouse.wheel
      mouse.last_mx = mouse.mx
      mouse.last_my = mouse.my
  end  
  --------------------------------------------------------------------
  function Data_Update() local com_time_TS, com_time
    if skip_check then return end
    if not trigger_update then return end
    local str = ""
    
    for i = 1, #data.machines do   
      local f = io.open(data.machines[i].path..'/Protokoll.txt', "r")
      if f then 
        f:seek("end", -200)
        local text = f:read("*a")
        if not text then f:close() end
        local srch_line
        for line in text:gmatch('[^\r\n]+') do if line:find('Start') or line:find('Ende') then srch_line = line end end        
        if srch_line then
          local is_st = srch_line:find('Start')
          local work_ID = Get_ID(srch_line)
          local program_name
          if is_st then program_name = srch_line:match('Start.*'):sub(7) else program_name = srch_line:match('Ende.*'):sub(7) end
          local disk_ID = program_name:match('[%d]+[^%d]+') 
          local com_time = F_GetComTime(data.machines[i].path..'/'..program_name)
          if com_time then 
            com_time_TS = math.floor(com_time * data.coefficient_time)
            com_time = os.date("!%X", com_time_TS)
           else 
            com_time = ''
          end  
          local ts_last_line = Convert_DateToTimestamp(srch_line:sub(0,20))        
          local elapsed = math.floor(os.time() - ts_last_line + data.machines[i].offset_sec)
          if elapsed < 0 then elapsed = 0 end
          if com_time and com_time_TS then obj.but['machine'..i].progress = elapsed/com_time_TS end
          if  obj.but['machine'..i].progress and  obj.but['machine'..i].progress > 1 then  obj.but['machine'..i].progress = 1 end
          obj.but['machine'..i].txt = 'D'..i..' | '..disk_ID:sub(0,-2)..'\n'..work_ID
          if not is_st then obj.but['machine'..i].progress = nil else obj.but['machine'..i].txt = obj.but['machine'..i].txt..'\n'..os.date("!%X", elapsed )..' / '..com_time  end
          str = str..'\n'..'D'..i
          if not com_time_TS then com_time_TS = 1 end
          if not obj.but['machine'..i].progress then str = str..'\n'..'Готово: '..work_ID else str = str..'\n'..'Будет готово через '..math.floor( (com_time_TS-elapsed)/60)..' минут: '..work_ID end
          str = str..'\n'
        end
        f:close()
      end
    end 
    
    --msg(str)
    local file = io.open(data.log_path, 'w')
    if file then
      file:write(str)
      file:close()
    end 
    update_gfx = true
    trigger_update = nil
  end
  --------------------------------------------------------------------  
  function Convert_DateToTimestamp(s)
    local p="(%d+).(%d+).(%d+)  (%d+):(%d+):(%d+)"
    s_day,s_month,s_year,s_hour,s_min,s_sec=s:match(p)    
    if not (s_day and s_month and s_year and s_hour and s_min and s_sec) then return 100 end
    if tonumber(s_year) < 2017 or tonumber(s_month) > 12 or tonumber(s_hour) > 24 or tonumber(s_day) > 31 or tonumber(s_min) > 60 or tonumber(s_sec ) > 60 then return 100 end
    return os.time({day=s_day,month=s_month,year=s_year,hour=s_hour,min=s_min,sec=s_sec})
  end
  --------------------------------------------------------------------
  function Get_ID(str)
    if not str then return '' end
    local ID = str:reverse():match('[^%d]%d%d%d%d%d[^%d]') 
    if not ID then ID = str:reverse():match('[^%d]%d%d%d%d%d%d[^%d]')  end
    if ID then ID = ID:reverse():sub(2,-2) end
    if not ID then ID = str:reverse():match('%d%d%d%d%d') if ID then ID = ID:reverse() end end
    --[[
    local ID = str:reverse():match('%d%d%d%d%d[^%d]')    
    local ID = str:reverse():match('%d%d_%d%d%d%d%d[^%d]')
    if not ID then  ID = str:reverse():match('%d_%d%d%d%d%d[^%d]') end
    if not ID then  ID = str:reverse():match('[^%d]%d%d%d%d%d[^%d]') end
    if not ID then  ID = str:reverse():match('[^%d]%d%d%d%d[^%d]') end
    if ID then 
      ID = ID:reverse() 
      if ID:find('[%p]') == 1 then ID = ID:sub(2) end
      if ID:reverse():find('[%p]') == 1 then ID = ID:sub(0,-2) end
    end]]
    if not ID then  ID = '' end
    --if ID then ID = ID:reverse():match('[%d]+')
    return ID
  end
  --------------------------------------------------------------------
  function Run()   
    
    com_w, com_h = gfx.w, gfx.h
    if not last_com_w or last_com_w ~= com_w or last_com_h ~= com_h  then Objects_Update() update_gfx = true end
    last_com_w,last_com_h = com_w, com_h
    
    local os_time = os.time()
    clock = os_time % data.trig_time
    progress_trig_upd = clock/data.trig_time
    if last_clock and last_clock ~= 0 and clock == 0 then trigger_update = true end
    last_clock = clock
    
    Data_Update()
    Objects_Update()
    GUI_draw()
    MOUSE_get()
    
    if char == 27 then gfx.quit() end      -- escape
    if char ~= -1 then reaper.defer(Run) else gfx.quit() end    -- check is ReaScript GUI opened
    
  end
  ---------------------------------------------------------------------------  
  function GetNCname(fp)
    local out
    local t = {}
    for str in fp:gmatch('[^%,]+') do t[#t+1] = str end
    if #t ~= 3 then return end
    
    local T_disk = t[1]:sub(1-t[1]:reverse():find('\\'))
    local T_time = t[2]:sub(7,8)..t[2]:sub(5,6)..t[2]:sub(10,13)
    local T_mod = Get_ID(t[3])
    local ext
    local sp = '_'
    local out = T_disk..sp..T_time..sp..T_mod
    if fp:lower():find('.mcr') then ext = '.mcr'
      elseif fp:lower():find('.nc') then ext = '.nc' end
    if ext then out = out..ext end
    return out
  end
  ---------------------------------------------------------------------------  
  function Action_RenameMCR() 
      reaper.ClearConsole()
      local i = 0
      repeat
        file_name = reaper.EnumerateFiles( data.MCR_path, i )        
        if file_name then 
          local filename_full = data.MCR_path..file_name
          local file = io.open(filename_full, 'r')
          if file then   
            file:close()
            
            local new_name = GetNCname(filename_full)
            if new_name and file_name ~= new_name then
              local command = 'rename "'..filename_full..'"  "'..new_name..'"'
              os.execute(command)            
            end
            
          end
          
        end
        i  = i + 1
      until file_name == nil
    end
  --------------------------------------------------------------------   
  function Fill_Header(filename)
    do return  end
    if not filename then return end
    local file = io.open(filename, 'r')
    if not file then return end
    if not filename:match('[%d]+[^%d]+') then return end
    local disk = '(auto)'..filename:match('[%d]+[^%d]+')
    
    local disk_diam = disk:match('%d%d')
    if disk_diam and disk_diam == '13' then disk_diam = 13.5 end
    
    local material
    if filename:lower():find('ti') then material = 'Ti' else material = 'CoCr' end
    
    if not (disk and disk_diam and material) then return end 
    local str_add = 
[[
!Makro Datei ; Erzeugt am 18.04.2017 - 12:43 Uhr by hyperDENT!
!34893
_sprache 0;
Dimension 1;
; !Blankname = "]]..disk..[["!
; !Material = "]]..material..[["!
; !Thickness = ]]..disk_diam..[[!

; !Tooltype_1 = "Co Cr Datron Ballnose 3 x 12_Raise"!
; !Tooltype_10 = "Co Cr Datron Ballmill 1.5 x 12_Raise"!
; !Tooltype_12 = "Co Cr Datron Ballmill 2 x 12(2)"!
; !Tooltype_409 = "Titanium Ballmill 1 x 13_Raise"!
; !Tooltype_51 = "Co Cr Datron endmil 1.8 Yena Long"!
; !Tooltype_418 = "Co Chr Datron Bullnose 1,5X 8 r 0,1_G"!
; !Tooltype_436 = "Co Chr Datron Endmill 1,5x3"!
; !Tooltype_447 = "Co Chr Datron Endmill _015_L"!
; !Tooltype_473 = "Drill 1,5"!
; !Tooltype_477 = "Drill 2"!

; !Tooltime_1 = 10!
; !Tooltime_409 = 10!
; !Tooltime_10 = 10!
; !Tooltime_12 = 10!
; !Tooltime_51 = 10!
; !Tooltime_418 = 10!
; !Tooltime_436 = 10!
; !Tooltime_447 = 10!
; !Tooltime_473 = 10!
; !Tooltime_477 = 10!

; !Toolpath_1 = 10!
; !Toolpath_10 = 10!
; !Toolpath_12 = 10!
; !Toolpath_409 = 10!
; !Toolpath_51 = 10!
; !Toolpath_418 = 10!
; !Toolpath_436 = 10!
; !Toolpath_447 = 10!
; !Toolpath_473 = 10!
; !Toolpath_477 = 10!

; !Toolminlen_1 = 64!
; !Toolminlen_10 = 64!
; !Toolminlen_12 = 64!
; !Toolminlen_409 = 64!
; !Toolminlen_51 = 62!
; !Toolminlen_418 = 64!
; !Toolminlen_436 = 64!
; !Toolminlen_447 = 64!
; !Toolminlen_473 = 64!
; !Toolminlen_477 = 64!
;

]]

    -- check/cnange content
      local out_content = ''
      local content = file:read('*all')--(200)
      if not content:find('Tooltype') then
        local content_findcut = content:find('Wzpruefen')
        out_content = str_add..content:sub(content_findcut)
      end
      file:close()
      
    -- write new content
      if out_content ~= '' then 
        file = io.open(filename, 'w')
        file:write(out_content)
        file:close()
        else return false
      end
    return true
  end    
  --------------------------------------------------------------------     
  function ContentCheck(content)
    local content = content:lower()
    local str = ''
    local cnt_screwch = 0
    local cnt_interf3 = 0
    local cnt_interf5 = 0
    local cnt_interf7 = 0
    local cnt_interf8 = 0
    local deep_scrCh = ''
    for line in content:gmatch('[^\n\r]+') do       
      if line:find('plane finishing inside abutment bases') then cnt_screwch = cnt_screwch + 1 end
      if line:find('cat3') then cnt_interf3 = cnt_interf3 + 1  str = str..'    cat3\n' end
      if line:find('cat5')  then cnt_interf5 = cnt_interf5 + 1  str = str..'    cat5\n' end
      if line:find('cat7') then cnt_interf7 = cnt_interf7 + 1  str = str..'    cat7\n' end
      if line:find('cat8') then cnt_interf8 = cnt_interf8 + 1  str = str..'    cat8\n' end
      --[[if line:find('screwchannel') and line:find('occ') then 
        if line:find('1st') then str = str..'   '..deep_scrCh..'screwchannel - 1st'..'\n' end
        if line:find('3rd') then str = str..'   screwchannel - 3rd'..'\n' deep_scrCh = '!!! ' end
      end]]
      if line:find('screwchannel machining') then  str = str..'   '..line..'\n' end
    end
    
    local cnt_parts = math.floor(cnt_screwch/2)    
    if cnt_parts ~= 0 and cnt_interf5 % cnt_parts ~= 0 then str = str:gsub('cat5','!!! cat5') end -- check count
    
    return cnt_parts, str
  end
  --------------------------------------------------------------------                              
  
  Objects_Init()
  gfx.init(name..' '..vrs,obj.main_w, obj.main_h, 0)--({reaper.GetMousePosition()})[1],({reaper.GetMousePosition()})[2] )
  Objects_Init()
  update_gfx = true
  update_gfx_onstart = true
  trigger_update = true
  Run()
