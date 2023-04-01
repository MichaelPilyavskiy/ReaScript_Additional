-- @description test_touchscr GUI for sel item
-- @version 1.0
-- @author MPL
-- @website http://forum.cockos.com/member.php?u=70694
-- @changelog
--    + test

-- http://forum.cockos.com/showthread.php?t=188039
-- touchscr GUI for sel item
-- 1.04 27.02.2017

actions = {
  {name = 'Dyn split', 
   func = function() 
            Action(40760)           
          end},
          
  {name = 'B', 
   func = function() 
            Action(40760) 
          end},
          
  {name = 'C', 
   func = function() 
            Action() 
          end},

  {name = 'D', 
   func = function() 
            Action(40760) 
          end},
          
  {name = 'E', 
   func = function() 
            Action() 
          end},
          
  {name = 'F', 
   func = function() 
            Action() 
          end}
          
                                                  
          }
                    
function Action(act)
  if type(act) == 'number' then
    reaper.Main_OnCommand(act,0)
   else
    reaper.Main_OnCommand(reaper.ReverseNamedCommandLookup( act ),0)
  end
end

function Run()
    item = reaper.GetSelectedMediaItem(0,0)
    DEFINE_obj()
    GUI_draw() 
    MOUSE_get()
    gfx.update()
    local char = gfx.getchar() 
    if char == 32 then reaper.Main_OnCommandEx(40044, 0,0) end
    if char == 27 then gfx.quit() end     
    if char ~= -1 then reaper.defer(Run) else gfx.quit() end   
  end
  ---------------------------------------  
  function GUI_slider(obj_t, noval, oppos, relative) local w1
    if not obj_t then return end
    local x,y,w,h, val = obj_t.x,obj_t.y,obj_t.w,obj_t.h,obj_t.val
    gfx.set(1,1,1,1)
    gfx.rect(x,y,w,h,0)
    gfx.a = 0.2
    if val then 
      if relative then val = val / item_len end
      if oppos  then w1 = w*(1-val) else w1 = w*val end
      if not noval then gfx.rect(x,y,w1,h,1) end
    end
    gfx.a = 1
    local txt_offs = 5
    if val then 
      local val = math.floor(val*100)/100
      if relative then val = math.floor((val * 100))..'%' end
      txt = obj_t.name..': '..val
     else 
      txt = obj_t.name
    end
    gfx.x = x+(w - gfx.measurestr(txt)) /2
    gfx.y = y+(h - gfx.texth) / 2
    gfx.a = 1
    gfx.drawstr(txt)
  end
  ---------------------------------------
  function GUI_draw()
    gfx.set(1,1,1,0.15)
    gfx.rect(0,0,gfx.w, gfx.h)
    
    if item then 
      tk = reaper.GetActiveTake(item)
      _, tk_name = reaper.GetSetMediaItemTakeInfo_String( tk, 'P_NAME', '', 0 )
      gfx.a = 1
      m_str = gfx.measurestr(tk_name)
      gfx.x, gfx.y = (gfx.w - m_str) /2,5 gfx.drawstr(tk_name)
      GUI_slider(obj.fader_vol)
      GUI_slider(obj.fader_f_in, nil, nil, true)
      GUI_slider(obj.fader_f_out, nil, true, true)
      GUI_slider(obj.fader_point_st, true)
      GUI_slider(obj.fader_point_end, true)
      for i = 1, #actions do
        GUI_slider(obj.act_but[i], true)
      end
    end
    
    gfx.update()
  end
  ------------------------------------------------------------------ 
  function MOUSE_match(b)
    if b and b.x then
      local mouse_y_match = b.y
      local mouse_h_match = b.y+b.h
      if mouse.mx > b.x 
          and mouse.mx < b.x+b.w 
          and mouse.my > mouse_y_match 
          and mouse.my < mouse_h_match 
          then return true 
      end 
    end
  end 
  ---------------------------------------  
  function MOUSE_slider(obj_t, lim1, lim2, oppos)
    local out
    if mouse.LMB_state 
      and not mouse.last_LMB_state 
      and MOUSE_match(obj_t) then
          mouse.last_obj_val =obj_t.val
          if obj_t.val2 then mouse.last_obj_val2 =obj_t.val2 end
          mouse.last_obj = obj_t.name
          out = true
        end
        if mouse.LMB_state and mouse.last_obj == obj_t.name and mouse.last_obj_val then
          coeff = 1
          if lim1 and lim2 then 
            if oppos then coeff = -1 else coeff = 1 end
            new_val = F_limit(mouse.last_obj_val + (mouse.dx*0.005)*coeff,lim1,lim2)
           else           
            new_val =         mouse.last_obj_val + (mouse.dx*0.005)*coeff
          end          
          obj_t.func(new_val, mouse.last_obj_val2)
        end   
    return out 
  end
  -----------------------------------------------------------------------     
  function MOUSE_button(xywh, offs, is_right)    
    if is_right then
      if MOUSE_match(xywh, offs) and mouse.RMB_state and not mouse.last_RMB_state then return true end
     else
      if MOUSE_match(xywh, offs) and mouse.LMB_state and not mouse.last_LMB_state then return true end
    end
  end
  ---------------------------------------
  function MOUSE_get()
    mouse.abs_x, mouse.abs_y = reaper.GetMousePosition()
    mouse.mx = gfx.mouse_x
    mouse.my = gfx.mouse_y
    mouse.LMB_state = gfx.mouse_cap&1 == 1 
    
    -- dx/dy
      if not mouse.last_LMB_state and mouse.LMB_state then 
        mouse.LMB_stamp_x = mouse.mx
        mouse.LMB_stamp_y = mouse.my
      end    
      if mouse.LMB_state then 
        mouse.dx = mouse.mx - mouse.LMB_stamp_x
        mouse.dy = mouse.my - mouse.LMB_stamp_y
      end
    
    if item then 
      MOUSE_slider(obj.fader_vol, 0, 1)
      MOUSE_slider(obj.fader_f_in, 0, item_len)
      MOUSE_slider(obj.fader_f_out, 0, item_len, true)
      MOUSE_slider(obj.fader_point_st)
      MOUSE_slider(obj.fader_point_end)
      
      for i = 1, #actions do
        if MOUSE_button(obj.act_but[i]) then  assert(load(actions[i].func)) end
       end
             
    end
    
    -- reset mouse context/doundo
      if mouse.last_LMB_state and not mouse.LMB_state then 
        mouse.last_obj = nil
        mouse.last_obj_val = nil
        mouse.dx = 0
        mouse.dy = 0
      end
  
    -- mouse release
      mouse.last_LMB_state = mouse.LMB_state  
      mouse.last_mx = mouse.mx
      mouse.last_my = mouse.my
  end
  --------------------------------------------
  function F_limit(val,min,max)
      if val == nil then return end
      local val_out = val
      if min and val < min then val_out = min end
      if max and val > max then val_out = max end
      return val_out
    end
  --------------------------------------------
  function DEFINE_obj()
    obj = {}
    if item then 
      item_len = reaper.GetMediaItemInfo_Value( item, 'D_LENGTH' )
      item_pos = reaper.GetMediaItemInfo_Value( item, 'D_POSITION' )
      local offs = 10
      local name_offs = 20
      local h_sl = 40
      
      local but_cnt = #actions
      obj.act_but = {}
      local custbut_w = (gfx.w - offs*2)/but_cnt
      for i = 1, but_cnt do
        obj.act_but[i] = {x = offs + custbut_w * (i-1) + 2,
                          y = offs+name_offs,
                          w = custbut_w-4,
                          h = h_sl,
                          name = actions[i].name,
                          }
      end
      obj.fader_vol = {x = offs,
                       y = offs*2+name_offs+h_sl,
                       w =  gfx.w - offs *2,
                       h = h_sl,
                       name = 'Gain',
                       val = reaper.GetMediaItemInfo_Value( item, 'D_VOL' ),
                       func = function(v) 
                                reaper.SetMediaItemInfo_Value( item, 'D_VOL', v ) 
                                reaper.UpdateItemInProject(item)
                              end 
                       }
      obj.fader_f_in = {x = offs,
                       y = offs*3+h_sl*2+name_offs,
                       w =  gfx.w/2 - offs *2,
                       h = h_sl,
                       name = 'FadeIn',
                       val = reaper.GetMediaItemInfo_Value( item, 'D_FADEINLEN' ),
                       func = function(v) 
                                reaper.SetMediaItemInfo_Value( item, 'D_FADEINLEN', v ) 
                                reaper.UpdateItemInProject(item)
                              end 
                       }  
      obj.fader_f_out = {x = offs*3 + obj.fader_f_in.w,
                       y = offs*3+h_sl*2+name_offs,
                       w =  obj.fader_f_in.w,
                       h = h_sl,
                       name = 'FadeOut',
                       dir = -1,
                       val = reaper.GetMediaItemInfo_Value( item, 'D_FADEOUTLEN' ),
                       func = function(v) 
                                reaper.SetMediaItemInfo_Value( item, 'D_FADEOUTLEN', v ) 
                                reaper.UpdateItemInProject(item)
                              end 
                       }  
      --local take = reaper.GetActiveTake(item)
      --st_offs =  reaper.GetMediaItemTakeInfo_Value( take, 'D_STARTOFFS' )
      obj.fader_point_st = {x = offs,
                       y = offs*4+h_sl*3+name_offs,
                       w =  obj.fader_f_in.w,
                       h = h_sl,
                       name = 'StartPoint',
                       
                       val = item_pos,  
                       val2 = item_len,
                       func = function(v) 
                                local cur_pos = reaper.GetMediaItemInfo_Value( item, 'D_POSITION') 
                                reaper.SetMediaItemInfo_Value( item, 'D_POSITION', v ) 
                                local take = reaper.GetActiveTake(item)
                                reaper.SetMediaItemTakeInfo_Value( take, 'D_STARTOFFS', reaper.GetMediaItemTakeInfo_Value( take, 'D_STARTOFFS') - (cur_pos-v) )
                                reaper.SetMediaItemInfo_Value( item, 'D_LENGTH', reaper.GetMediaItemInfo_Value( item, 'D_LENGTH') + (cur_pos-v) )
                                reaper.UpdateItemInProject(item)
                              end,                  
                       }       
      obj.fader_point_end = {x =  offs*3 + obj.fader_f_in.w,
                       y = offs*4+h_sl*3+name_offs,
                       w =  obj.fader_f_in.w,
                       h = h_sl,
                       name = 'EndPoint',
                       val = reaper.GetMediaItemInfo_Value( item, 'D_LENGTH' ),         
                       func = function(v) 
                                reaper.SetMediaItemInfo_Value( item, 'D_LENGTH', v ) 
                                reaper.UpdateItemInProject(item)
                              end 
                       }                                                                                    
    end
  end
  --------------------------------------------
  function Lokasenna_Window_At_Center (w, h)
    -- thanks to Lokasenna 
    -- http://forum.cockos.com/showpost.php?p=1689028&postcount=15    
    local l, t, r, b = 0, 0, w, h    
    local __, __, screen_w, screen_h = reaper.my_getViewport(l, t, r, b, l, t, r, b, 1)    
    local x, y = (screen_w - w) / 2, (screen_h - h) / 2    
    gfx.init("mpl Randomize stretch markers", w, h, 0, x, y) 
  end
  
  mouse = {}
  MOUSE_get()
  local w,h = 500, 230
  local __, __, screen_w, screen_h = reaper.my_getViewport(0,0,w,h,0,0,w,h, 1)  
  gfx.init('',w, h,0, (screen_w-w)/2, screen_h-h-100)
  
  gfx.setfont(1, 'Arial', 15)
  Run()
