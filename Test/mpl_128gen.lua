  
  -------------------------------------------------------------------------    
  function msg(s)  reaper.ShowConsoleMsg(s..'\n') end
-------------------------------------------------------------------------    
  function CODE128_GetCodeFromNum(num)
    --reaper.ClearConsole()
    local num = tostring(num)
    local t_digits = {"11011001100","11001101100","11001100110","10010011000","10010001100","10001001100","10011001000","10011000100","10001100100","11001001000","11001000100","11000100100","10110011100","10011011100","10011001110","10111001100","10011101100","10011100110","11001110010","11001011100","11001001110","11011100100","11001110100","11101101110","11101001100","11100101100","11100100110","11101100100","11100110100","11100110010","11011011000","11011000110","11000110110","10100011000","10001011000","10001000110","10110001000","10001101000","10001100010","11010001000","11000101000","11000100010","10110111000","10110001110","10001101110","10111011000","10111000110","10001110110","11101110110","11010001110","11000101110","11011101000","11011100010","11011101110","11101011000","11101000110","11100010110","11101101000","11101100010","11100011010","11101111010","11001000010","11110001010","10100110000","10100001100","10010110000","10010000110","10000101100","10000100110","10110010000","10110000100","10011010000","10011000010","10000110100","10000110010","11000010010","11001010000","11110111010","11000010100","10001111010","10100111100","10010111100","10010011110","10111100100","10011110100","10011110010","11110100100","11110010100","11110010010","11011011110","11011110110","11110110110","10101111000","10100011110","10001011110","10111101000","10111100010","11110101000","11110100010","10111011110",
    '10111101110','11101011110','11110101110'}
    local start_c = '11010011100'
    local code_b = '10111101110'
    local stop = '11000111010'
    local termination_bar = '11'    
    local out_code = ''
    local chk_sum = 105
    local chk_sum_cnt = 0
    local t_id
    for dig in num:gmatch('%d%d')do     
      t_id =  tonumber(dig)+1
      out_code = out_code..t_digits[t_id]
      chk_sum_cnt = chk_sum_cnt + 1
      chk_sum = chk_sum + dig * chk_sum_cnt
    end
    if (num:len() % 2) == 1 then 
      out_code = out_code..code_b
      chk_sum_cnt = chk_sum_cnt + 1
      chk_sum = chk_sum + 100 * chk_sum_cnt
      
      t_id = tonumber(num:sub(-1))+17
      out_code = out_code..t_digits[t_id]
      chk_sum_cnt = chk_sum_cnt + 1
      chk_sum = chk_sum + (t_id-1) * chk_sum_cnt
    end
    chk_sum = tostring(math.floor(chk_sum %103))
    out_code = out_code..t_digits[tonumber(chk_sum)+1]
    out_code = start_c..out_code..stop..termination_bar
    return out_code
  end
-------------------------------------------------------------------------    
  function CODE128_DrawCode(num, name, x, y, h)        
    local bin_digit_str = CODE128_GetCodeFromNum(num)
    local bar_width = 1    
    gfx.set(0,0,0,1)
    local cnt = 0
    local x_code = x
    for letter in bin_digit_str:gmatch('%d') do
      if letter == '1' then gfx.set(0,0,0,1) else gfx.set(1,1,1,1) end
      x_code = x_code+bar_width
      gfx.rect(x_code, y, bar_width, h)
      cnt = cnt + 1
      gfx.set(0,0,0,1)
      --if cnt % 11 == 1 then gfx.line(x,0,x,100) end
    end
    local w = x_code-x
    
    gfx.a = 0.7
    gfx.setfont(1, 'Calibri',15)
    gfx.x = x --+ (w-gfx.measurestr(num))/2
    gfx.y = y + h + 1
    gfx.drawstr(num)
    
    gfx.setfont(1, 'Calibri',21)
    gfx.x = x--+ (w-gfx.measurestr(name))/2
    gfx.y = y + h + gfx.texth - 10
    gfx.drawstr(name)
  end
-------------------------------------------------------------------------  
  function CODE128_draw() 
    gfx.mode = 1
    gfx.init('', 1000, 1000, 0)
    gfx.set(1,1,1,1)
    gfx.rect(0,0, gfx.w, gfx.h,1)
    local x = 50
    local w = 220
    local h = 80 
    local cnt = 0
    local retval, filename = reaper.GetUserFileNameForRead('', 'get str', 'txt' )
    if not retval then return end
    local file = io.open(filename, 'r')
    if not file then return end
    local content = file:read('a')
    
    for line in content:gmatch('[^\r\n]+') do
      if line:find('sep') then 
        gfx.set(0,0,0,1) gfx.line(x,h*cnt+8,x+w-30,h*cnt+8) 
        cnt = cnt+ 0.3
       elseif line:find('col') then
        x = x + w
        cnt = 0
       elseif line ~= '' then        
        local num = line:match('[%d]+')
        local name = line:match('%s.*'):sub(2) 
        CODE128_DrawCode(num, name, x, h*cnt, h - 35)
        cnt = cnt + 1
      end
      
    end  
    file:close()
    gfx.update()
  end
  
  CODE128_draw()
