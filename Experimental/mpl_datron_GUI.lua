-- @description test_DatronGUI
-- @version 1.0
-- @author MPL
-- @website http://forum.cockos.com/member.php?u=70694
-- @changelog
--    + test




  name = 'DatronGUI'
  vrs = '2.25'
  --local data = {}
  local obj = {}
  local mouse = {}
  --skip_check = true
  
    --[[  
      - 2.25  15/08/2017
        # fix Data_Update/Get machine info  get working file without blank name
        # GetID reduce 1st symb for 6-digit IDs
      - 2.23  14/08/2017
        # fix some errors
        # Get_ID shows model also
      - 2.22  11/08/2017
        + write com time to MCR/NC when rename
        + Parse com time from "Total machininhg time"
        + Arum progress
        + Arum remaining time
        # fix Convert_DateToTimestamp (empty (#s+) as dummy variable)
        # Data_Update clear
      - 2.21  09/08/2017
        + arum IDs
        + arumlog
        + arum file shed
        + prevent clear Arum log
      - 2.17  22/07/2017
        # fix ID parser for 6digit IDs
      - 2.16  20/07/2017
        proper time string for admin
      - 2.15  17.07.2017
        # fix error 700
      - 2.14  13.07.2017
        execute HyperDent after search unchecked
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
                      { path= [=[V:\]=],       
                        name='D1',         
                        offset_sec=800,   
                        bypass = false,  
                        machine_type = 'Datron',
                        coefficient_time = 1.1 },  
                        
                      { path= [=[Y:\]=],       
                        name='D2',         
                        offset_sec=550,   
                        bypass = false,  
                        machine_type = 'Datron',
                        coefficient_time = 1.1 }, 
                        
                      { path= [=[X:\]=],       
                        name='D3',         
                        offset_sec=600,   
                        bypass = false,  
                        machine_type = 'Datron',
                        coefficient_time = 1.1 }, 
                        
                      { path= [=[W:\]=],       
                        name='Arum1',         
                        offset_sec=240,   
                        bypass = false,
                        machine_type = 'Arum',
                        coefficient_time = 1}
                      },
          count_machines = 4,
          log_path = [=[Z:\DATRON\Datron MSK.txt]=],
          stat_path = [=[Z:\DATRON\Files_STL_Checked\Stat.txt]=]  ,
          stat_path0 = [=[Z:\DATRON\Files_STL_Checked]=]  ,
          MCR_path = [=[C:\Users\Public\Documents\hyperDENT\NC Output\]=],
          unchecked_path = [=[Z:\files_for_check\Unchecked]=],
          calculation_path = [=[C:\Users\Public\Documents\hyperDENT\Calculation]=],
          run_update = true,  
          trig_time = 60,-- sec
          coefficient_time = 1.1}
  
  
  
  --[[   ARUM copy file shedule
  -------------------------------------------------------------
  time_shed = 180
  src = 'D:\\DentalCNC_5X200_DC_AIB3.0\\SYSTEM\\ARUMINFO.DAT'
  dest = 'D:\\USERDATA\\ARUMINFO.DAT'
  function run()
    clock = os.clock()
    if clock%time_shed < 1 then trig = true else trig = false end
    if last_trig and not trig then 
      last_clock_st = clock 
      os.execute('copy '..src..' '..dest)
    end
    last_trig = trig
    reaper.defer(run)
  end  
  run()
  -------------------------------------------------------------
  ]]
  
  
  
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
                      txt = data.machines[i].name,
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
  function GetComTime2(machine_table) 
    if not machine_table or not machine_table.current_working_file then return end
    local f = io.open(machine_table.path..'/'..machine_table.current_working_file, 'r')
    local comtime = 1
    if f then
      
      --[[if machine_table.machine_type == 'Datron' then
        local content = f:read(2000)
        if not content then return comtime end
        for line in content:gmatch('[^\n]+') do        
          if line:find('Tooltime') then 
            local t_time = line:reverse():match('[%d]+'):reverse()
            if tonumber(t_time) then comtime = comtime + tonumber(t_time) end
          end
        end
        
       elseif machine_table.machine_type == 'Arum' then]]
        f:seek('end', -20)
        local context = f:read('a')
        comtime = context:match('com_time.*')
        if comtime then comtime = comtime:match('[%d]+') end    
      --end
      
      f:close()
    end
    return math.floor(comtime * machine_table.coefficient_time)
  end
  -------------------------------------------------------------------- 
  function Menu()
    gfx.x, gfx.y = mouse.mx, mouse.my
    local actions = {
              {name = 'Statistics: get (MM/YYYY)',       func = function () str = Action_ParseStat(nil,nil,true) msg(str) end},
              {name = 'Statistics: Open stat file|', func = function () local cmd = 'start "" "'..data.stat_path..'"'  os.execute(cmd) end},
              {name = 'Log: Search by ID', func = function () Action_SearchLogsByID()  end},
              {name = 'Log: Clear D5 logs|', func = function () 
                                                  for i = 1, #data.machines do 
                                                    if data.machines[i].machine_type and data.machines[i].machine_type == 'Datron' then
                                                      Action_Clear_Logs(data.machines[i].path..'Protokoll.txt') 
                                                    end
                                                  end end},
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
            if line:find(ID) then --and (line:find('Start') or line:find('Ende'))   then
              str = str..'\n'..data.machines[i].name..' '..line
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
      os.execute('start "" "C:/Program Files (x86)/FOLLOW ME/hyperDENT V8.0/win/fmHyperDent.exe"')
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
        if t.state then 
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
  function GetAdminStr(machine_table)
    local str = machine_table.name..'\n'
    if not machine_table.current_work_state then 
      str = str..machine_table.current_work_ID.. ' готов'
     else 
        local r_h =  math.floor( math.floor( (machine_table.remaining)/60)/60)
        local r_h_s
        if r_h ==1 then 
          r_h_s = 'час'
         elseif 
          r_h >= 2 and r_h <= 4  then r_h_s = 'часа'
         else 
          r_h_s = 'часов'
        end
        local r0 = r_h..' '..r_h_s..' '
        if r_h == 0 then r0 = '' end
        
        local r_m = (math.floor( (machine_table.remaining)/60)%60)
        local r_m_s
        if r_m ==1 or (r_m > 20 and r_m % 10 == 1) then 
          r_m_s = 'минуту'
         elseif 
          (r_m >= 2 and r_m <= 4) or (r_m > 20 and r_m % 10 >= 2 and r_m % 10 <= 4)  then r_m_s = 'минуты'
         else r_m_s = 'минут'
        end
        local m0 = r_m..' '..r_m_s
        if r_m == 0 then m0 ='' end
        str = str..machine_table.current_work_ID.. ' будет готов через '..r0..m0
    end
    str = str..'\n\n'
    return str
  end
  --------------------------------------------------------------------
  function GetCurrentWorkingFile(machine_table)
    local str = ''
    local start_str = ''
    local state = true
    local f = io.open(machine_table.path..'/Protokoll.txt', "r")
    if not f then return end
    if machine_table.machine_type == 'Datron' then
      f:seek("end", -200)
      local text = f:read("*a") 
      for line in text:gmatch('[^\r\n]+') do if line:find('Start') or line:find('Ende') then str = line end end
      if str:match('Start') then 
        start_str = str:match('.-Start'):sub(0,-9)
        str = str:match('Start.*'):sub(7)  
        state = true       
       else 
        str = str:match('Ende.*')
        if str then str = str:sub(7) end
        state = false
      end
     elseif machine_table.machine_type == 'Arum' then
      f:seek("end", -200)
      local text = f:read("*a")
      local t = {}
      for line in text:gmatch('[^\r\n]+') do t[#t+1] = line end
      if #t > 1 then str = t[#t] end
      start_str = str:sub(0,19)
      if str then str = str:sub(21) end
    end
    if f then f:close() end
    return true, str, start_str, state
  end
  --------------------------------------------------------------------
  function Data_Update() local com_time_TS, com_time
    if skip_check then return end
    if not trigger_update then return end
    
    -- update Arum stuff
      for i = 1, #data.machines do if data.machines[i].machine_type == 'Arum' then
        local f = io.open(data.machines[i].path..'/ARUMINFO.DAT', "r")
        if f then 
           local program_name = f:read("*a"):match('USERDATA.*nc'):sub(10)
           local disk_ID = program_name:match('[%d]+[^%d]+')
           local work_ID = Get_ID(program_name)
           local log_pre_lastLine, srch_line = Arum_Writelog(data.machines[i].path, program_name) -- WRITE LOG
           Arum_RemoveLastProgram(data.machines[i].path, log_pre_lastLine)  -- REMOVE LAST NC
        end
        if f then f:close() end    
      end end
      
      
    -- get machine info
      for i = 1, #data.machines do
        local current_work_start_str, ret
        ret, data.machines[i].current_working_file,
        data.machines[i].current_work_start_str,
        data.machines[i].current_work_state = GetCurrentWorkingFile(data.machines[i]) --READ LOG
        if ret 
          and data.machines[i].current_working_file 
          and data.machines[i].current_working_file:match('[%d]+[^%d]+') -- disk id
          then
          data.machines[i].current_work_start_TS = Convert_DateToTimestamp(data.machines[i].current_work_start_str)
          data.machines[i].current_disk_ID = data.machines[i].current_working_file:match('[%d]+[^%d]+'):sub(0,-2)
          data.machines[i].current_work_ID = Get_ID(data.machines[i].current_working_file)
          data.machines[i].current_work_comtime = GetComTime2(data.machines[i]) --  READ MCR/NC
          data.machines[i].elapsed  = math.floor(os.time()-data.machines[i].current_work_start_TS + data.machines[i].offset_sec)
          data.machines[i].elapsed_str = os.date("!%X", math.max(math.floor(data.machines[i].elapsed),1) )
          data.machines[i].remaining = data.machines[i].current_work_comtime - data.machines[i].elapsed
          if data.machines[i].remaining < 0 then data.machines[i].current_work_state = false end
          data.machines[i].progress = data.machines[i].elapsed / data.machines[i].current_work_comtime
          if data.machines[i].progress > 1 then data.machines[i].progress = 1 end
          data.machines[i].admin_str = GetAdminStr(data.machines[i])
          
          -- write GUI stuff
            obj.but['machine'..i].progress = data.machines[i].progress
            obj.but['machine'..i].state = data.machines[i].current_work_state
            obj.but['machine'..i].txt = data.machines[i].name..' | '
                                        ..data.machines[i].current_disk_ID..'\n'
                                        ..data.machines[i].current_work_ID..'\n'
            if data.machines[i].current_work_state then 
              obj.but['machine'..i].txt = obj.but['machine'..i].txt
                                          ..data.machines[i].elapsed_str..' / '
                                          ..os.date("!%X", data.machines[i].current_work_comtime) 
            end
        end
      end  
        
        
    -- write admin log  
      local adm_str = ""
      for i = 1, # data.machines do  adm_str = adm_str..data.machines[i].admin_str end
      --reaper.ClearConsole()
      --msg(adm_str)
      local file = io.open(data.log_path, 'w')
      if file then
        file:write(adm_str)
        file:close()
      end 
    
    update_gfx = true
    trigger_update = nil
  end
  -------------------------------------------------------------------- 
  function Arum_RemoveLastProgram(path, log_pre_lastLine)
    if not log_pre_lastLine or log_pre_lastLine == '' then return end
    local filename = log_pre_lastLine:match('.*[^\r\n]'):sub(21)
    local src = path..filename
    local dest = path..'archive\\'..filename
    local f = io.open(src, 'r')
    --msg(src)
    --msg(f:read('a'))
    if f then 
      f:close() 
      reaper.ExecProcess('powershell -Command Move-Item '..src..' '..dest, 0)
    end
  end
  -------------------------------------------------------------------- 
  function Arum_Writelog(path, program_name)
    local f = io.open(path..'/Protokoll.txt', "r")
    if not f then 
      f = io.open(path..'/Protokoll.txt', "w") 
      f:write('') 
      f:close()
    end    
    local f = io.open(path..'/Protokoll.txt', "r")
    local context = f:read('a')
    local t = {}
    -- get t
      for line in context:gmatch('[^\r\n]+') do t[#t+1]  = line end
      if not t[#t] or (t[#t] and not t[#t]:match(program_name)) then 
        f = io.open(path..'/Protokoll.txt', "a") 
        f:write(os.date()..' '..program_name..'\n') 
        f:close() 
       else
        f:close()
      end
    if #t>1 then return t[#t-1], t[#t] end
  end
  --------------------------------------------------------------------  
  function Convert_DateToTimestamp(s)
    local p="(%d+).(%d+).(%d+)(%s+)(%d+):(%d+):(%d+)"
    local s_day,s_month,s_year,_,s_hour,s_min,s_sec=s:match(p)    
    if not (s_day and s_month and s_year and s_hour and s_min and s_sec) then return 1 end
    if tonumber(s_year) < 2017 or tonumber(s_month) > 12 or tonumber(s_hour) > 24 or tonumber(s_day) > 31 or tonumber(s_min) > 60 or tonumber(s_sec ) > 60 then return 100 end
    return os.time({day=s_day,month=s_month,year=s_year,hour=s_hour,min=s_min,sec=s_sec})
  end
  --------------------------------------------------------------------
  function Get_ID(str)
    if not str then return '' end
    local ID = str:reverse():match('%d%d%d%d%d%d')or  str:reverse():match('%d%d%d%d%d')
    --if ID then ID = ID:reverse():sub(2,-2) end
    --if not ID then ID = str:reverse():match('%d%d%d%d%d') if ID then ID = ID:reverse() end end
    if not ID then ID = '' else ID = ID:reverse() end
    mod_ID = str:reverse():match('[%.](%d)[%_]')
    if not mod_ID then mod_ID = str:reverse():match('[%.](%d%d)[%_]') end
    if mod_ID and ID ~= '' then ID = ID..'_'..mod_ID:reverse() end
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
    return out, T_disk, t[2] -- t[2] render timestamp
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
            local new_name,disk, ts = GetNCname(filename_full)
            if new_name and file_name ~= new_name then
              local command = 'rename "'..filename_full..'"  "'..new_name..'"'
              --msg(new_name)
              os.execute(command)   
              if new_name then --and new_name:match('.nc') then 
                AddTimeToNC(new_name, disk, ts)                
              end
            end
          end
          
        end
        i  = i + 1
      until file_name == nil
    end
  --------------------------------------------------------------------  
  function AddTimeToNC(filename, disk, ts)
    if not filename or not disk or not ts then return end
    local log_path = data.calculation_path..'\\'..disk..'\\'..ts..'\\'..disk..'.log'
    local f = io.open(log_path, 'r')
    if f then
      f:seek('end', -300)
      local context = f:read('a')
      local com_time = context:match('Total machining time.-[\n]')
      if not com_time then f:close() return end
      
      local h=com_time:match('[%d]+ hours'):match('[%d]+')
      local m=com_time:match('[%d]+ minutes'):match('[%d]+')
      local s=com_time:match('[%d]+ seconds'):match('[%d]+')
      ret_com_time = h*3600+m*60+s
      f:close()
      if ret_com_time then        
        local f = io.open(data.MCR_path..filename, 'a')
        f:write(';com_time='..math.floor(ret_com_time))
        f:close()
      end
    end
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
  function Action_GetQuere()
    reaper.ClearConsole()
    qt = {}
    local cur_time = os.time()
    for i = 1, #data.machines do
      local shift = 0
      for f_id = 0, 30 do
        local fp = reaper.EnumerateFiles( data.machines[i].path, f_id )
        if not fp then break end
        if fp:find('mcr') then 
          shift = shift + F_GetComTime(data.machines[i].path..fp)
          qt[#qt+1] = { fp=fp, 
                        time = shift+cur_time, 
                        time_form = os.date("%X",shift+cur_time),
                        disk = fp:match('.-%_')}
          shift = shift + 60*5
        end        
      end
    end
    
    --table.sort(qt, function(qt.time, qt.time) return (qt.time)<(qt.time) end)
    for i =1 , #qt do
      if qt[i] then
        msg(qt[i].time_form)
      end
    end
  end
  --------------------------------------------------------------------                              
  
  Objects_Init()
  gfx.init(name..' '..vrs,obj.main_w, obj.main_h, 0)--({reaper.GetMousePosition()})[1],({reaper.GetMousePosition()})[2] )
  Objects_Init()
  update_gfx = true
  update_gfx_onstart = true
  trigger_update = true
  Run()
  --*Action_GetQuere()
