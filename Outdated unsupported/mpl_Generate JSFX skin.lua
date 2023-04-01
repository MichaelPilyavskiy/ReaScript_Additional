-- @description Generate JSFX skin
-- @version 0.01
-- @author MPL
-- @website http://forum.cockos.com/showthread.php?t=233358
-- @changelog
--    + init




  -- NOT gfx NOT reaper NOT VF NOT GUI NOT DATA NOT MAIN 
  
  DATA2 = {
             jsfxcode_marks = {
                                desc_uiimport = '// [MPLJSFXGEN UI_IMPORT]'
                              }
            }
  ---------------------------------------------------------------------  
  function main()
    if not DATA.extstate then DATA.extstate = {} end
    DATA.extstate.version = 0.01
    DATA.extstate.extstatesection = 'mpl_generateJSFXskin'
    DATA.extstate.mb_title = 'MPL Generate JSFX skin'
    DATA.extstate.default = 
                          {  
                          wind_x =  100,
                          wind_y =  100,
                          wind_w =  800,
                          wind_h =  600,
                          dock =    0,
                          
                          CONF_NAME = 'default',
                          
                          UI_enableshortcuts = 0,
                          UI_initatmouse = 0,
                          UI_showtooltips = 1,
                          UI_groupflags = 0, -- show/hide setting flags
                          UI_appatchange = 1, 
                          UI_appatinit = 1, 
                          
                          }
                          
    DATA:ExtStateGet()
    DATA:ExtStateGetPresets()  
    if DATA.extstate.UI_initatmouse&1==1 then
      local w = DATA.extstate.wind_w
      local h = DATA.extstate.wind_h 
      local x, y = GetMousePosition()
      DATA.extstate.wind_x = x-w/2
      DATA.extstate.wind_y = y-h/2
    end
    
    
    DATA:GUIinit()
    GUI_RESERVED_init(DATA)
    RUN()
  end
  path =reaper.GetResourcePath()
  --------------------------------------------------------------------- 
  function DATA2:JSFX_Read_ScanPath(path) --https://forum.cockos.com/showpost.php?p=1991414&postcount=2
    local t = {}
    local subdirindex, fileindex = 0,0    
    local path_child
    repeat
        path_child = reaper.EnumerateSubdirectories(path, subdirindex )
        if path_child then 
            table.insert(t,path_child)
            local tmp = DATA2:JSFX_Read_ScanPath(path .. "/" .. path_child)
            for i = 1, #tmp do
                --table.insert(t, path .. "/" .. path_child .. "/" .. tmp[i])
                table.insert(t, tmp[i])
            end
        end
        subdirindex = subdirindex+1
    until not path_child 
    repeat
        fn = reaper.EnumerateFiles( path, fileindex )
        if path and fn then 
            --t[#t+1] = path .. "/" .. fn
            t[#t+1] = path..'/'..fn
        end
        fileindex = fileindex+1
    until not fn 
    return t
  end
  --------------------------------------------------------------------- 
  function DATA2:JSFX_Saike_UI_initparams()  
    return
[[

backgr_col = 0x434343;

// knob colors
knob_font_color_r = 0.9;
knob_font_color_g = 0.9;
knob_font_color_b = 0.9;
knob_font_color_a = 1;

// toggle colors
toggle_r = .4;
toggle_g = .9;
toggle_b = .4;
toggle_a = 1.0;


KNOB_FONT = 6; // knob value
gfx_setfont(KNOB_FONT, "Arial", floor(15 * (1+fontscaling)));
KNOB_FONT2 = 7; // knob label
gfx_setfont(KNOB_FONT2, "Arial", floor(15 * (1+fontscaling)));
HINT_FONT = 8;
gfx_setfont(HINT_FONT, "Arial", floor(13 * (1+fontscaling)));
TOGGLE_FONT = 9;
gfx_setfont(TOGGLE_FONT, "Arial", floor(13 * (1+fontscaling)));
]]
  end
  --------------------------------------------------------------------- 
  function DATA2:JSFX_Saike_UI_lib()
    return
[[//--------------- BEGIN OF GFX UI BY SAIKE ---------------------------------------------------
function ui_rad(x) (x*$pi/180);
function ui_draw_arc(x y r start_ang end_ang lim_ang) 
  (
    x = floor(x);
    y = floor(y);
    y_shift = 0;
    has_1st_segm = (start_ang <= -90) | (end_ang <= -90);
    has_2nd_segm = (start_ang > -90 && start_ang <= 0) | (end_ang > -90 && end_ang <= 0) | (start_ang<=-90 && end_ang >= 0 );
    has_3rd_segm = (start_ang >= 0 && start_ang <= 90) | (end_ang > 0 && end_ang <= 90) | (start_ang<=0 && end_ang >= 90 );
    has_4th_segm = (start_ang > 90) | (end_ang > 90);
    
    has_1st_segm == 1 ? (  gfx_arc(x,y+1 +y_shift,r, ui_rad(max(start_ang,-lim_ang)), ui_rad(min(end_ang, -90)),    1));
    has_2nd_segm == 1 ? (  gfx_arc(x,y+y_shift,r, ui_rad(max(start_ang,-90)), ui_rad(min(end_ang, 0)),    1));
    has_3rd_segm == 1 ? (  gfx_arc(x+1,y+y_shift,r, ui_rad(max(start_ang,0)), ui_rad(min(end_ang, 90)),    1));
    has_4th_segm == 1 ? (  gfx_arc(x+1,y+1+y_shift,r, ui_rad(max(start_ang,90)), ui_rad(min(end_ang, lim_ang)),    1));
  );
function ui_setfromhex(hex,a) // by MPL 
  (
  !a ? (a = 1) : (a = a);
  r = (hex>>16)&0xFF;
  g = (hex>>8)&0xFF;
  b = (hex)&0xFF;
  gfx_set(r/255,g/255,b/255,a);
  );
  
  
function ui_drawHint() 
  global(scaling, gfx_x, gfx_y, gfx_w, gfx_h, mouse_x, mouse_y, HINT_FONT)
  local(w, h, globalTime)
  instance(hintTime, currentHint, lastGlobalTime, delta_time)
  (
    globalTime = time_precise();
    delta_time = globalTime - lastGlobalTime;
    lastGlobalTime = globalTime;
  
    ( hintTime > .99 ) ? (
      gfx_setfont(HINT_FONT);
      gfx_measurestr(currentHint,w,h);
      
      gfx_x = mouse_x+15;
      gfx_y = mouse_y+15;
      ( gfx_x > 0.5*gfx_w ) ? gfx_x = mouse_x - w - 8;
      ( gfx_y > 0.5*gfx_h ) ? gfx_y = mouse_y - h - 8;

      gfx_set( 0.05, 0.05, 0.1, .8 );
      gfx_rect(gfx_x-2, gfx_y-2, w+4, h+4);
      gfx_set( .7, .7, .7, 1 );      
      gfx_printf(currentHint);
    );
  );    

//------------------------------------------------------------------
function ui_mouse_clamp(value, mini, maxi) 
  local()
  global()
  ( max(min(value,maxi),mini));
  
 //------------------------------------------------------------------ 
function ui_updateHintTime(hint)
  global(gfx_x, gfx_y, mouse_x, mouse_y)
  local()
  instance(lx, ly, hintTime, currentHint, delta_time)
  (
    ( ( abs(lx - mouse_x) + abs( ly - mouse_y ) ) > 0 ) ? (
      hintTime = 0;
    ) : (      
      (hint != 0) ? (
        currentHint = hint;
        hintTime = hintTime + delta_time;
        hintTime = min(1, hintTime)
      ) : (
        0
      )
    );
    
    lx = mouse_x;
    ly = mouse_y;
  );  

//------------------------------------------------------------------
function ui_knob_draw()  
  (
    
    slider_show(slider(this.slideridx),0);
    
    // define internal variables
    x=this.x;
    y=this.y;
    w=this.w;
    h=this.h;
    this.arc_r = floor(0.5*0.8*min(w, (h-h_labels*2)));
    this.h_labels = floor(h*0.2);
    value = slider(this.slideridx);
    
    // frame
    ui_setfromhex(0xFFFFFF,0.2);
    gfx_x=x;
    gfx_y=y;
    gfx_lineto(x+w,y,1);
    gfx_lineto(x+w,y+h,1);
    gfx_lineto(x,y+h,1);
    gfx_lineto(x,y,1); 
    
    h_labels = this.h_labels;
    //full circle
    angle_lim = 130;
    arc_r = this.arc_r; 
    ui_setfromhex(0xFFFFFF,0.1);
    gfx_circle(x+w/2, y+h/2, arc_r, 1, 1);
    ui_setfromhex(backgr_col,1);
    gfx_circle(x+w/2, y+h/2, arc_r-3, 1, 1);
    y_fill = y+h/2 + arc_r*sin(ui_rad(-angle_lim-90))+3;
    gfx_rect(x+1,y_fill,w-1,h-y_fill);  
    
    // arc
    ui_setfromhex(0xFFFFFF,0.5);
    val_norm = value/127;
    ang1 = -angle_lim;
    ang2 = (-angle_lim+(angle_lim*2)*val_norm);
    r_offs = 1;
    loop(6,
      r_offs = r_offs - 0.5;
      ui_draw_arc(x+w/2,y+h/2,floor(arc_r+r_offs), ang1, ang2,angle_lim); 
    ); 
    
    
    // value
    label = this.description;
    gfx_setfont(KNOB_FONT2);  
    gfx_measurestr(label, tw, thval); 
    ui_setfromhex(0xFFFFFF,1);
    gfx_x = x+floor((w-tw)/2);
    gfx_y = y+ h_labels/2-thval/2 ;
    gfx_printf(label); 
    
    // value 
    value_format = this.value_format;
    ui_setfromhex(0xFFFFFF,1);
    gfx_setfont(KNOB_FONT);
    gfx_measurestr(value_format, tw, thlab);
    gfx_x = floor(x+(w-tw)/2);
    gfx_y = floor(y + h-h_labels);
    ui_setfromhex(0xFFFFFF,1);
    gfx_printf(value_format);
     
;
  );
  
  
  
//------------------------------------------------------------------  
function ui_obj_init(slideridx, in_active, description, hint, x, y, w, h, value_min,value_max) 
  (
  this.value_format = sprintf(1, "%g",slider(slideridx));
  this.active = in_active;
  this.description = description;
  this.hint = hint;
  this.slideridx = slideridx;
  //this.value = slideridx;
  this.value_min = value_min;
  this.value_max = value_max;
  strlist = this.strlist;
  this.value_src = slider(slideridx);
  
  this.x = x;
  this.y = y;
  this.w = w;
  this.h = h;
  
  );
  
//------------------------------------------------------------------
function ui_knob_mouseover(mx, my)
  instance(x, y, r)
  global()
  local(dx, dy)
  (
    dx = (mx-x);
    dy = (my-y);
    (dx*dx + dy*dy) < (r*r)
  );
  
//------------------------------------------------------------------
  function ui_knob_mouseprocess_method(mx, my, mousecap, default)  
    local(left, dx, dy, change, mul, over)
    instance(hint, value, x, y, r, w,h,cap, lleft, lx, ly, active, lastLeftClick, doubleClick, cTime, hoverTime)
    global(hinter.ui_updateHintTime, mouse_wheel, delta_time, comboboxOpen, activeModifier)
    (
      change = 0;
      !comboboxOpen ? (
        mul = 1; 
        dx = (mx-x);
        dy = (my-y);
        over = 
          mx >= x && mx <= x+w &&
          my >= y && my <= y+h;
        
        
        //(dx*dx + dy*dy) < (w*h); 
        (mousecap&4) ? mul = mul * 0.1666666666667; /* CTRL */
        (mousecap&8) ? mul = mul * 0.125; /* SHIFT */ 
        (over || (cap > 0)) ? (
          hoverTime = hoverTime + delta_time;
        ) : ( 
          hoverTime = 0;
        ); 
        active ? (
          left = mousecap & 1; 
          ( over == 1 ) ? (
            (mouse_wheel ~= 0) ? (
              value = value + 0.0001 * mul * mouse_wheel;
              mouse_wheel = 0;
              value = ui_mouse_clamp(value, 0, 1);
              change = 1;
            );
          ); 
          ( left == 0 ) ? (
            ( over == 1 ) ? (
              hinter.ui_updateHintTime(hint);
            ) : ( 
              hinter.ui_updateHintTime(0);
            );
          ); 
          doubleClick = 0;
          (left && !lleft) ? (
             time_precise(cTime);
             ( ( cTime - lastLeftClick ) < .25 ) ? (
                doubleClick = 1;
             ) : lastLeftClick = cTime;
          );
          
          ( left && cap == 1 ) ? (
            value = value - .01*mul*(my - ly);
            change = 1;
          ) : ( cap = 0; );
          
          ( left && !lleft ) ? 
          (
            ( over ) ?
            (
              doubleClick ? (
                lastLeftClick = -100;
                change = 1;
                value = default;
              ) : ( 
                cap = 1;
              );
            );
          ); 
          lleft = left;
          lx = mx;
          ly = my;
        );
      ); 
      change
    );
  
//------------------------------------------------------------------
function ui_knob_mouseprocess(mx, my, mousecap, default)  
  local(ret)
  instance(value)
  global()
  (
    ret = this.ui_knob_mouseprocess_method(mx, my, mousecap, default);
    value = ui_mouse_clamp(value, 0, 1);
    ret
  );


//------------------------------------------------------------------
function ui_toggle_draw()  
  (
    
    slider_show(slider(this.slideridx),0);
    
    // define internal variables
    x=this.x;
    y=this.y;
    w=this.w;
    h=this.h;
    this.arc_r = floor(0.5*0.8*min(w, (h-h_labels*2)));
    this.h_labels = floor(h*0.2);
    this.w_label_name_w = floor(w*0.35);
    this.value_format_ext = this.strlist[slider(this.slideridx)+1];
    
    // frame
    ui_setfromhex(0xFFFFFF,0.2);
    gfx_x=x+this.w_label_name_w;
    gfx_y=y;
    gfx_lineto(x+w,y,1);
    gfx_lineto(x+w,y+h,1);
    gfx_lineto(x+this.w_label_name_w,y+h,1);
    gfx_lineto(x+this.w_label_name_w,y,1); 
    
    // value
    label = this.description;
    gfx_setfont(KNOB_FONT2);  
    gfx_measurestr(label, tw, thval); 
    ui_setfromhex(0xFFFFFF,1);
    gfx_x = x+this.w_label_name_w-tw-5;
    gfx_y = y+h/2-thval/2;
    gfx_printf(label); 
    
    
    h_labels = this.h_labels;
    
    // value 
    value_format = this.value_format_ext;
    ui_setfromhex(0xFFFFFF,1);
    gfx_setfont(KNOB_FONT);
    gfx_measurestr(value_format, tw, thlab);
    gfx_x = floor(x+this.w_label_name_w+((w-this.w_label_name_w)-tw)/2);
    gfx_y = floor(y + (h-thlab)/2);
    ui_setfromhex(0xFFFFFF,1);
    gfx_printf(value_format);
;
  );
  
//------------------------------------------------------------------
function drawToggle(_x, _y, _w, _h, _on, wr, wg, wb, wa, r, g, b, a, _str)
  local(ww, hh, r)
  instance(x, y, w, h, str, on, invert, label, xHit, yHit, wHit, hHit, inactive)
  global(gfx_x, gfx_y, gfx_a, gfx_mode, 
         TOGGLE_FONT, knob_font_color_r, knob_font_color_g, knob_font_color_b, knob_font_color_a)
  (
    x = _x;
    y = _y;
    w = _w;
    h = _h;
    on = _on;
    str = _str; 
    x = floor(x);
    y = floor(y);
    w = floor(w);
    h = floor(h); 
    xHit = x;
    yHit = y;
    wHit = w;
    hHit = h;
    gfx_set(0, 0, 0, 0);
    gfx_rect(x, y, w, h); 
    inactive ? (
      b = g = r;
      wg = wb = wr;
    ); 
    gfx_set(r, g, b, a*.2);
    gfx_rect(x, y, w, h); 
    gfx_set(wr, wg, wb, wa);
    gfx_line(x, y, x+w, y);
    gfx_line(x, y, x, y+h);
    gfx_line(x+w, y, x+w, y+h);
    gfx_line(x, y+h, x+w, y+h);
    ( label ) ? (
      gfx_set(knob_font_color_r, knob_font_color_g, knob_font_color_b, knob_font_color_a);
      gfx_setfont(TOGGLE_FONT);
      gfx_measurestr(label, ww, hh);
      gfx_x = floor(x+1.5*w);
      gfx_y = floor(y-.5*hh+.5*h);
      gfx_printf(label);
      
      xHit = x;
      yHit = y;
      wHit = w + 1.5 * w + ww;
      hHit = hh;
    ); 
    !inactive ? (
      ( (on && !invert) || (!on && invert) ) ? (
        gfx_set(r, g, b, a);
        gfx_rect(x, y, w, h);
        gfx_a *= .36;
        gfx_rect(x, y, w, h);
        gfx_a *= .6;
        gfx_rect(x+1, y+1, w-2, h-2);
        r = r*w*.4;
        g = g*w*.4;
        b = b*w*.4;
        gfx_set(r, g, b, gfx_a);
        loop(10,
          gfx_a *= .7;
          r *= 1.3;
          gfx_circle(floor(x+.5*w), floor(y+.5*h), 2*r, 2*r);
        );
      );
    );
  );


  
//------------------------------------------------------------------
function processMouseToggle(mx, my, mousecap)
  instance(xHit, yHit, wHit, hHit, on, lastleft, str)
  local(left, slack, over)
  global(hinter.ui_updateHintTime, comboboxOpen)
  (
    !comboboxOpen ? (
      slack = 2;
      left = mousecap & 1; 
      over = ( (mx >= (xHit-slack)) && ( mx <= (xHit+wHit+slack) ) && ( my >= (yHit-slack) ) && ( my <= (yHit+hHit+slack) ) ); 
      over ? (
        ( (left == 1) && (lastleft == 0) ) ?  (
          on = 1 - on;
        );
        hinter.ui_updateHintTime(str);
      ); 
      lastleft = left;
    ); 
    on
  );
  
//------------------ END OF GFX UI BY SAIKE ------------------------
]]
  end
  --------------------------------------------------------------------- 
  function DATA2:JSFX_Mod_GenerateControls(sliders)
    
    local knob_str = ''
    local knob_x = DATA2.jsfxparams_offs
    local knob_y = DATA2.jsfxparams_offs
    local knob_r = math.floor((DATA2.jsfxparams_knob_w/2))
    
    local xid = 0
    local yid = 0
    if not sliders then return end
    -- generate controls
      for sliderid in spairs(sliders) do
        local sliderid_int = tonumber(sliderid)
        if sliders[sliderid].slidertype == 0 then 
          xid = xid+  1
          yid = yid+  1
          local val_diff = (sliders[sliderid].parameters_max-sliders[sliderid].parameters_min)
          local mouse_def = (sliders[sliderid].defaultvar -sliders[sliderid].parameters_min ) / val_diff
          local item_name = 'slider_entry_'..sliderid
          knob_str=knob_str..'\n'..
          
item_name..'.ui_obj_init('.. 
sliderid_int..','..  -- val_formatted
'1,'..                                          -- active
'"'..sliders[sliderid].description..'",'..         -- knob label
'"'..(sliders[sliderid].hint or '[no hint]')..'",'..
knob_x..', '..knob_y..', '..DATA2.jsfxparams_knob_w..','..DATA2.jsfxparams_knob_h..','..
sliders[sliderid].parameters_min..','..
sliders[sliderid].parameters_max..
');\n'..
item_name..'.ui_knob_draw();\n'..
item_name..'.ui_knob_mouseprocess(mouse_x, mouse_y, mouse_cap, '..mouse_def..') ? ( \n'..
'  tempval = '..item_name..'.value*'..val_diff..'+'..sliders[sliderid].parameters_min..';\n'..
'  slider_automate(slider'..sliderid_int..'); \n'..
'  slider'..sliderid_int..'=tempval; \n'..
'  update_bitrate_now = 1;\n'..
');\n'

          if xid > DATA2.jsfxparams_knobperrow-1  then
            knob_x = DATA2.jsfxparams_offs
            knob_y = knob_y + DATA2.jsfxparams_knob_h + DATA2.jsfxparams_offs
            xid = 0
           else
            knob_x = knob_x + DATA2.jsfxparams_knob_w + DATA2.jsfxparams_offs
          end 
        
        end
      end
      
    -- generate lists
      knob_x = DATA2.jsfxparams_offs
      knob_y = knob_y + DATA2.jsfxparams_knob_h + DATA2.jsfxparams_offs
      local toggle_w = (DATA2.jsfxparams_knob_w+DATA2.jsfxparams_offs)*DATA2.jsfxparams_knobperrow-DATA2.jsfxparams_offs
      for sliderid in spairs(sliders) do
        local sliderid_int = tonumber(sliderid)
        if sliders[sliderid].slidertype == 1 then 
          local mouse_def = 0 
          local val_diff = (sliders[sliderid].parameters_max-sliders[sliderid].parameters_min)
          local item_name = 'slider_entry_'..sliderid
          local list =  table.concat(sliders[sliderid].parameter_list,'|')
          
          local listname = ''
          for i = 1,#sliders[sliderid].parameter_list do
            listname=listname..item_name..'.strlist['..i..']="'..sliders[sliderid].parameter_list[i]..'";'
          end
          
          knob_str=knob_str..'\n'..
item_name..'.ui_obj_init('.. 
sliderid_int..','..  -- val_formatted
'1,'..                                          -- active
'"'..sliders[sliderid].description..'",'..         -- knob label
'"'..(sliders[sliderid].hint or '[no hint]')..'",'..
knob_x..', '..knob_y..', '..toggle_w..','..DATA2.jsfxparams_toggle_h..','..
sliders[sliderid].parameters_min..','..
(sliders[sliderid].parameters_max or -1)..
');\n'..
listname..'\n'..
item_name..'.ui_toggle_draw();\n'..
item_name..'.ui_knob_mouseprocess(mouse_x, mouse_y, mouse_cap, '..mouse_def..') ? ( \n'..
'  tempval = gfx_showmenu("'..list..'");\n'..
'  tempval != 0 ? '..
' (slider_automate(slider'..sliderid_int..'); \n'..
'  slider'..sliderid_int..'=tempval-1; \n'..
'  update_bitrate_now = 1);\n'..
');\n'

          knob_y = knob_y + DATA2.jsfxparams_toggle_h + DATA2.jsfxparams_offs
        
        end
      end      
      
      
      
      
    return knob_str
    
  end
 --------------------------------------------------------------------- 
  function DATA2:JSFX_Mod_Generate(t0)   
    DATA2.jsfxparams_offs = 5
    DATA2.jsfxparams_knob_w = 70
    DATA2.jsfxparams_knob_h = 100
    DATA2.jsfxparams_toggle_h = math.floor(DATA2.jsfxparams_knob_h*0.2)
    
    DATA2.jsfxparams_knobperrow = 5
    DATA2.jsfxparams_gfxw = DATA2.jsfxparams_knob_w*DATA2.jsfxparams_knobperrow + DATA2.jsfxparams_offs * (DATA2.jsfxparams_knobperrow+1)
    DATA2.jsfxparams_gfxh = DATA2.jsfxparams_knob_h*2
    
    local sliders = t0.sliders
    local cnt = t0.sliderscnt
    local controls = DATA2:JSFX_Mod_GenerateControls(sliders)
    if not controls then return end
local str=
'@gfx '..DATA2.jsfxparams_gfxw..' '..DATA2.jsfxparams_gfxh..'\n'..
'//[AUTOGENERATED_CODE] from MPL JFSX theme generator // based on Saike UI framework'..'\n'..
DATA2:JSFX_Saike_UI_initparams()..'\n'..
DATA2:JSFX_Saike_UI_lib()..'\n'..
[[

// background
gfx_mode = 0;
ui_setfromhex(backgr_col,1);
gfx_rect(0,0,gfx_w,gfx_h);

]]..
controls..
[[

hinter.ui_drawHint();
//[AUTOGENERATED_CODE_END]]

    return str
  end
  --------------------------------------------------------------------- 
  function DATA2:JSFX_Mod()
    for id = 1, #DATA2.JSFX do
    
      -- init gfx section
      if not DATA2.JSFX[id].hasmodded then
        local init_str = DATA2:JSFX_Mod_Generate(DATA2.JSFX[id])
        DATA2.JSFX[id].sections[#DATA2.JSFX[id].sections+1] = {
          str = init_str,
          section = 'gfx'
        }
       elseif DATA2.JSFX[id].gfxsectionid and DATA2.JSFX[id].sections[DATA2.JSFX[id].gfxsectionid] then
        local section_t = DATA2.JSFX[id].sections[DATA2.JSFX[id].gfxsectionid]
        section_t.str =DATA2:JSFX_Mod_Generate(DATA2.JSFX[id])
      end 
      
    end
  end
  --------------------------------------------------------------------- 
  function DATA2:JSFX_Write()
    for id = 1, #DATA2.JSFX do
      local output = ''
      for sectionid = 1, #DATA2.JSFX[id].sections do
        if not (DATA2.JSFX[id].sections[sectionid] and DATA2.JSFX[id].sections[sectionid].str) then goto skip_write end
        output = output..DATA2.JSFX[id].sections[sectionid].str--..'\n'
      end
      output = output:gsub('@header\n','')
      local fp= DATA2.JSFX[id].path
      local f = io.open(fp, 'wb')
      if f then 
        f:write(output)
        f:close()
      end
      ::skip_write::
    end
  end
  --------------------------------------------------------------------- 
  function DATA2:JSFX_Read_ParseContent_ParseSliders(str)
    local sliders = {}
    for line in str:gmatch('[^\r\n]+') do
      if line:match('slider(%d+)') then
        local sliderid,defaultvar,parameters,description = line:match('slider(%d+)%:(.-)%<(.-)%>(.*)')
        if sliderid then sliderid = string.format('%02d',sliderid) end
        
        -- parse list
        local parameter_list,parameters_min,parameters_max,parameters_step
        if not parameters and line:match('slider(%d+)%:(.-)%,(.*)') then 
          local sliderid,defaultvar,description = line:match('slider(%d+)%:(.-)%,(.*)')
          sliders[sliderid] = { defaultvar=defaultvar,
                              description=description,
                              slidertype=3,
                              }
        end
        
        if not parameters and line:match('slider(%d+)%:(.-):(.-):(,*)') then 
          local sliderid,path,unknown,description = line:match('slider(%d+)%:(.-):(.-):(,*)')
          sliders[sliderid] = { defaultvar=defaultvar,
                              description=description,
                              path=path,
                              unknown=unknown,
                              slidertype=4, -- path
                              }
        end
        
        
        if parameters and parameters:match('%{(.-)%}') then 
          local parameters_list_str = parameters:match('%{(.-)%}')
          parameter_list = {}
          for val in parameters_list_str:gmatch('[^%,]+') do parameter_list[#parameter_list+1] = val end
        end
        
        if parameters then
          parameters = parameters--:match('(.-)[{>]') 
          parameters_min,parameters_max,parameters_step = parameters:match('(.-)%,(.-)%,(.*)')
          parameters_min,parameters_max,parameters_step = tonumber(parameters_min),tonumber(parameters_max),tonumber(parameters_step)
        end
        
        -- regular slider
          if sliderid and (parameters_min and parameters_max and parameters_step) then 
            sliders[sliderid] = { defaultvar=defaultvar,
                                parameters=parameters,
                                description=description,
                                slidertype=0, 
                                parameters_min=parameters_min,
                                parameters_max=parameters_max,
                                parameters_step=parameters_step,
                                parameter_list=parameter_list
                                }
        end

        -- list
          if sliderid and (parameters_min and parameters_max ) and parameter_list then 
            sliders[sliderid] = { defaultvar=defaultvar,
                                parameters=parameters,
                                description=description,
                                parameter_list=parameter_list,
                                slidertype=1,
                                parameters_min=parameters_min,
                                parameters_max=parameters_max,
                                parameters_step=parameters_step,
                                }
        end
        
        -- file
          local sliderid, path, defaultvar, description = line:match('slider(%d+)%:(.-)%:(.-)%:(.*)')
          if sliderid then 
            sliders[sliderid] = { defaultvar=defaultvar,
                                path=path,
                                description=description,
                                slidertype=2,
                                }
        end
        
        
      end
    end
    
    local cnt = 0 for key in pairs(sliders) do cnt = cnt + 1 end
    return sliders, cnt
  end
  --------------------------------------------------------------------- 
  function DATA2:JSFX_Read_ParseContent(fp)
    local f = io.open(fp, 'rb')
    if not f then return end
    local content = f:read('all')
    f:close()
    
    if not content:match('desc%:') then return end -- validate JSFX by desc existence
    local hasmodded = content:match('%[AUTOGENERATED_CODE%]')~=nil
    if content:match('@gfx') and not hasmodded then return end -- exclude JSFX with custom gfx section
    
    local sections = {}
    local content_parse = '@header'..content
    local sect_order = 0
    local sliders,sliderscnt
    for sec in content_parse:gmatch('[^@]+') do
      local sec = '@'..sec
      local section = sec:match('@(%a+)')
      if section=='header' then 
        sec = sec:gsub('@header','') 
        sliders,sliderscnt = DATA2:JSFX_Read_ParseContent_ParseSliders(sec)
      end
      sect_order = sect_order + 1
      if section=='gfx' then gfxsectionid =sect_order  end
      if section then sections[sect_order] = {str = sec, section=section } end
    end
    
    return true, {content =content,sections=sections},hasmodded,gfxsectionid or -1,sliders,sliderscnt
  end
  --------------------------------------------------------------------- 
  function DATA2:JSFX_Read() 
    local tree = DATA2:JSFX_Read_ScanPath(GetResourcePath()..'/Effects')
    DATA2.JSFX = {}
    for i = 1, #tree do
      if tree[i]:match('[\\/]') 
        and not tree[i]:lower():match('%-inc')
        and not tree[i]:lower():match('rpl')
        and not tree[i]:lower():match('png')
        and not tree[i]:lower():match('test')
        then
        
        local ret, data,hasmodded,gfxsectionid,sliders,sliderscnt = DATA2:JSFX_Read_ParseContent(tree[i])
        if ret then  
          local id = #DATA2.JSFX+1
          DATA2.JSFX[id] = {path = tree[i], short_name = VF_GetShortSmplName(tree[i]),hasmodded=hasmodded,gfxsectionid=gfxsectionid,sliders=sliders,sliderscnt=sliderscnt}  
          for key in pairs(data) do DATA2.JSFX[id][key] = data[key] end
        end
      end
    end
    
  end
  ---------------------------------------------------------------------  
  function GUI_RESERVED_init(DATA)
    DATA.GUI.buttons = {} 
    
    DATA.GUI.custom_scrollw = 10*DATA.GUI.default_scale
    DATA.GUI.custom_offset = math.floor(DATA.GUI.default_scale*DATA.GUI.default_txt_fontsz/2)
    DATA.GUI.custom_mainw = gfx.w/DATA.GUI.default_scale
    DATA.GUI.custom_mainsepxupd = 150*DATA.GUI.default_scale
    DATA.GUI.custom_setposx = 0--gfx.w - DATA.GUI.custom_mainsepx
    DATA.GUI.custom_mainbuth = 30*DATA.GUI.default_scale
    DATA.GUI.custom_setposy = (DATA.GUI.custom_offset+DATA.GUI.custom_mainbuth)*3*DATA.GUI.default_scale
    DATA.GUI.custom_knobw = 90*DATA.GUI.default_scale
    
    DATA.GUI.buttons.rebuild = { x=0,
                           y=0,
                           w=gfx.w,
                           h=gfx.h,
                           txt = 'destroy all jsfx GUI',
                           func_onrelease = function() 
                           DATA2:JSFX_Read()
                           DATA2:JSFX_Mod()
                           DATA2:JSFX_Write()
                           end
                           }
                           
                           
    --[[
    DATA.GUI.buttons.Rsettings = { x=DATA.GUI.custom_setposx,
                           y=DATA.GUI.custom_offset,
                           w=DATA.GUI.custom_mainw,
                           h=gfx.h - DATA.GUI.custom_offset,
                           txt = 'Settings',
                           --txt_fontsz = DATA.GUI.default_txt_fontsz3,
                           frame_a = 0,
                           offsetframe = DATA.GUI.custom_offset,
                           offsetframe_a = 0.1,
                           ignoremouse = true,
                           }
    DATA:GUIBuildSettings()]]
    
    for but in pairs(DATA.GUI.buttons) do DATA.GUI.buttons[but].key = but end
  end
  ---------------------------------------------------------------------  
  ---------------------------------------------------------------------  
  function GUI_RESERVED_BuildSettings(DATA)
    local readoutw_extw = 150
    
    local  t = 
    { 
     --[[ {str = 'Actions' ,                                  group = 1, itype = 'sep'}, 
        {str = 'Revert init values',                      group = 1, itype = 'button', level = 1, func_onrelease =  function()DATA2:RevertInitialValues() end},
      {str = 'Filtering params (all plugins)' ,           group = 2, itype = 'sep'}, 
        {str = 'Untitled parameters' ,                    group = 2, itype = 'check', level = 1, confkey = 'CONF_filter_untitledparams'},
        {str = 'Bypass / Wet / Delta' ,                   group = 2, itype = 'check', level = 1, confkey = 'CONF_filter_system'},
        table.unpack(keyfilters,1),  
        table.unpack(keyfilters,2),  
        table.unpack(keyfilters,3),  
        table.unpack(keyfilters,4),  ]]
      --{str = 'UI options' ,                               group = 5, itype = 'sep'},  
        --{str = 'Enable shortcuts' ,                       group = 5, itype = 'check', confkey = 'UI_enableshortcuts', level = 1},
        --{str = 'Init UI at mouse position' ,              group = 5, itype = 'check', confkey = 'UI_initatmouse', level = 1},
        --{str = 'Show tootips' ,                           group = 5, itype = 'check', confkey = 'UI_showtooltips', level = 1},
        --{str = 'Process on settings change',              group = 5, itype = 'check', confkey = 'UI_appatchange', level = 1},
    } 
    return t
    
  end
  ----------------------------------------------------------------------
  function VF_CheckFunctions(vrs)  local SEfunc_path = reaper.GetResourcePath()..'/Scripts/MPL Scripts/Functions/mpl_Various_functions.lua'  if  reaper.file_exists( SEfunc_path ) then dofile(SEfunc_path)  if not VF_version or VF_version < vrs then  reaper.MB('Update '..SEfunc_path:gsub('%\\', '/')..' to version '..vrs..' or newer', '', 0) else return true end   else  reaper.MB(SEfunc_path:gsub('%\\', '/')..' not found. You should have ReaPack installed. Right click on ReaPack package and click Install, then click Apply', '', 0) if reaper.APIExists('ReaPack_BrowsePackages') then reaper.ReaPack_BrowsePackages( 'Various functions' ) else reaper.MB('ReaPack extension not found', '', 0) end end end
  --------------------------------------------------------------------  
  local ret = VF_CheckFunctions(3.10) if ret then local ret2 = VF_CheckReaperVrs(5.975,true) if ret2 then main() end end
