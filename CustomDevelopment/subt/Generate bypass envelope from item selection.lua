-- @description Generate bypass envelope from item selection
-- @version 1.02
-- @author MPL
-- @website http://forum.cockos.com/showthread.php?t=165672 
-- @about Script for showing instruments in currently opened REAPER project
-- @changelog
--  # fix boundaries

    
    
--NOT reaper NOT gfx


-------------------------------------------------------------------------------- init external defaults 
EXT = {
  offsetL = 0,
  ignoregap = 0,
  offsetR = 0,
      }
-------------------------------------------------------------------------------- INIT data
DATA = {
        ES_key = 'MPL_genbypassenv',
        UI_name = 'MPL Generate bypass envelope',
        
        upd = true, 
        perform_quere = {}, 
        }
        
-------------------------------------------------------------------------------- INIT UI locals
for key in pairs(reaper) do _G[key]=reaper[key] end 
--local ctx
-------------------------------------------------------------------------------- UI init variables
UI = {}
-- font  
  UI.font='Arial'
  UI.font1sz=15
  UI.font2sz=14
  UI.font3sz=12
-- style
  UI.pushcnt = 0
  UI.pushcnt2 = 0
-- size / offset
  UI.spacingX = 4
  UI.spacingY = 3
-- mouse
  UI.hoverdelay = 0.8
  UI.hoverdelayshort = 0.8
-- colors 
  UI.main_col = 0x7F7F7F -- grey
  UI.textcol = 0xFFFFFF
  UI.but_hovered = 0x878787
  UI.windowBg = 0x303030
-- alpha
  UI.textcol_a_enabled = 1
  UI.textcol_a_disabled = 0.5
  
  
-- special 
  UI.windowBg_plugin = 0x505050
  UI.butBg_green = 0x00B300
  UI.butBg_red = 0xB30000












function msg(s) 
  if not s then return end 
  if type(s) == 'boolean' then
    if s then s = 'true' else  s = 'false' end
  end
  ShowConsoleMsg(s..'\n') 
end 
-------------------------------------------------------------------------------- 
function UI.MAIN_PushStyle(key, value, value2, iscol)  
  if not iscol then 
    ImGui_PushStyleVar(ctx, key, value, value2)
    UI.pushcnt = UI.pushcnt + 1
  else 
    ImGui_PushStyleColor(ctx, key, math.floor(value2*255)|(value<<8) )
    UI.pushcnt2 = UI.pushcnt2 + 1
  end 
end
-------------------------------------------------------------------------------- 
function UI.MAIN_draw(open) 
  -- window_flags
    local window_flags = ImGui_WindowFlags_None()
    --window_flags = window_flags | ImGui_WindowFlags_NoTitleBar()
    --window_flags = window_flags | ImGui_WindowFlags_NoScrollbar()
    --window_flags = window_flags | ImGui_WindowFlags_MenuBar()
    --window_flags = window_flags | ImGui_WindowFlags_NoMove()
    --window_flags = window_flags | ImGui_WindowFlags_NoResize()
    window_flags = window_flags | ImGui_WindowFlags_NoCollapse()
    --window_flags = window_flags | ImGui_WindowFlags_NoNav()
    --window_flags = window_flags | ImGui_WindowFlags_NoBackground()
    window_flags = window_flags | ImGui_WindowFlags_NoDocking()
    window_flags = window_flags | ImGui_WindowFlags_TopMost()
    --if UI.disable_save_window_pos == true then window_flags = window_flags | ImGui_WindowFlags_NoSavedSettings() end
    --window_flags = window_flags | ImGui_WindowFlags_UnsavedDocument()
    --open = false -- disable the close button
  
  
  -- set style
    UI.pushcnt = 0
    UI.pushcnt2 = 0
  -- rounding
    UI.MAIN_PushStyle(ImGui_StyleVar_FrameRounding(),5)  
    UI.MAIN_PushStyle(ImGui_StyleVar_GrabRounding(),5)  
    UI.MAIN_PushStyle(ImGui_StyleVar_WindowRounding(),10)  
    UI.MAIN_PushStyle(ImGui_StyleVar_ChildRounding(),5)  
    UI.MAIN_PushStyle(ImGui_StyleVar_PopupRounding(),0)  
    UI.MAIN_PushStyle(ImGui_StyleVar_ScrollbarRounding(),9)  
    UI.MAIN_PushStyle(ImGui_StyleVar_TabRounding(),4)   
  -- Borders
    UI.MAIN_PushStyle(ImGui_StyleVar_WindowBorderSize(),0)  
    UI.MAIN_PushStyle(ImGui_StyleVar_FrameBorderSize(),0) 
  -- spacing
    UI.MAIN_PushStyle(ImGui_StyleVar_WindowPadding(),UI.spacingX,UI.spacingY)  
    UI.MAIN_PushStyle(ImGui_StyleVar_FramePadding(),20,5) 
    UI.MAIN_PushStyle(ImGui_StyleVar_CellPadding(),UI.spacingX, UI.spacingY) 
    UI.MAIN_PushStyle(ImGui_StyleVar_ItemSpacing(),UI.spacingX, UI.spacingY)
    UI.MAIN_PushStyle(ImGui_StyleVar_ItemInnerSpacing(),4,0)
    UI.MAIN_PushStyle(ImGui_StyleVar_IndentSpacing(),20)
    UI.MAIN_PushStyle(ImGui_StyleVar_ScrollbarSize(),14)
  -- size
    UI.MAIN_PushStyle(ImGui_StyleVar_GrabMinSize(),30)
    UI.MAIN_PushStyle(ImGui_StyleVar_WindowMinSize(),400,150)
  -- align
    UI.MAIN_PushStyle(ImGui_StyleVar_WindowTitleAlign(),0.5,0.5)
    UI.MAIN_PushStyle(ImGui_StyleVar_ButtonTextAlign(),0.5,0.5)
    --UI.MAIN_PushStyle(ImGui_StyleVar_SelectableTextAlign(),0,0 )
    --UI.MAIN_PushStyle(ImGui_StyleVar_SeparatorTextAlign(),0,0.5 )
    --UI.MAIN_PushStyle(ImGui_StyleVar_SeparatorTextPadding(),20,3 )
    --UI.MAIN_PushStyle(ImGui_StyleVar_SeparatorTextBorderSize(),3 )
  -- alpha
    UI.MAIN_PushStyle(ImGui_StyleVar_Alpha(),0.98)
    --UI.MAIN_PushStyle(ImGui_StyleVar_DisabledAlpha(),0.6 ) 
    UI.MAIN_PushStyle(ImGui_Col_Border(),UI.main_col, 0.3, true)
  -- colors
    --UI.MAIN_PushStyle(ImGui_Col_BorderShadow(),0xFFFFFF, 1, true)
    UI.MAIN_PushStyle(ImGui_Col_Button(),UI.main_col, 0.3, true) 
    UI.MAIN_PushStyle(ImGui_Col_ButtonActive(),UI.main_col, 1, true) 
    UI.MAIN_PushStyle(ImGui_Col_ButtonHovered(),UI.but_hovered, 0.8, true)
    --UI.MAIN_PushStyle(ImGui_Col_CheckMark(),UI.main_col, 0, true)
    --UI.MAIN_PushStyle(ImGui_Col_ChildBg(),UI.main_col, 0, true)
    --UI.MAIN_PushStyle(ImGui_Col_ChildBg(),UI.main_col, 0, true) 
    
    
    --Constant: Col_DockingEmptyBg
    --Constant: Col_DockingPreview
    --Constant: Col_DragDropTarget 
    UI.MAIN_PushStyle(ImGui_Col_DragDropTarget(),0xFF1F5F, 0.6, true)
    UI.MAIN_PushStyle(ImGui_Col_FrameBg(),0x1F1F1F, 0.7, true)
    UI.MAIN_PushStyle(ImGui_Col_FrameBgActive(),UI.main_col, .9, true)
    UI.MAIN_PushStyle(ImGui_Col_FrameBgHovered(),UI.main_col, 1, true)
    UI.MAIN_PushStyle(ImGui_Col_Header(),UI.main_col, 0.5, true) 
    UI.MAIN_PushStyle(ImGui_Col_HeaderActive(),UI.main_col, 1, true) 
    UI.MAIN_PushStyle(ImGui_Col_HeaderHovered(),UI.main_col, 0.98, true) 
    --Constant: Col_MenuBarBg
    --Constant: Col_ModalWindowDimBg
    --Constant: Col_NavHighlight
    --Constant: Col_NavWindowingDimBg
    --Constant: Col_NavWindowingHighlight
    --Constant: Col_PlotHistogram
    --Constant: Col_PlotHistogramHovered
    --Constant: Col_PlotLines
    --Constant: Col_PlotLinesHovered 
    UI.MAIN_PushStyle(ImGui_Col_PopupBg(),0x303030, 0.9, true) 
    UI.MAIN_PushStyle(ImGui_Col_ResizeGrip(),UI.main_col, 1, true) 
    --Constant: Col_ResizeGripActive 
    UI.MAIN_PushStyle(ImGui_Col_ResizeGripHovered(),UI.main_col, 1, true) 
    --Constant: Col_ScrollbarBg
    --Constant: Col_ScrollbarGrab
    --Constant: Col_ScrollbarGrabActive
    --Constant: Col_ScrollbarGrabHovered
    --Constant: Col_Separator
    --Constant: Col_SeparatorActive
    --Constant: Col_SeparatorHovered
    --Constant: Col_SliderGrab
    --Constant: Col_SliderGrabActive
    UI.MAIN_PushStyle(ImGui_Col_Tab(),UI.main_col, 0.37, true) 
    UI.MAIN_PushStyle(ImGui_Col_TabActive(),UI.main_col, 1, true) 
    UI.MAIN_PushStyle(ImGui_Col_TabHovered(),UI.main_col, 0.8, true) 
    --Constant: Col_TabUnfocused
    --ImGui_Col_TabUnfocusedActive
    --UI.MAIN_PushStyle(ImGui_Col_TabUnfocusedActive(),UI.main_col, 0.8, true)
    --Constant: Col_TableBorderLight
    --Constant: Col_TableBorderStrong
    --Constant: Col_TableHeaderBg
    --Constant: Col_TableRowBg
    --Constant: Col_TableRowBgAlt
    UI.MAIN_PushStyle(ImGui_Col_Text(),UI.textcol, UI.textcol_a_enabled, true) 
    --Constant: Col_TextDisabled
    --Constant: Col_TextSelectedBg
    UI.MAIN_PushStyle(ImGui_Col_TitleBg(),UI.main_col, 0.7, true) 
    UI.MAIN_PushStyle(ImGui_Col_TitleBgActive(),UI.main_col, 0.95, true) 
    --Constant: Col_TitleBgCollapsed 
    UI.MAIN_PushStyle(ImGui_Col_WindowBg(),UI.windowBg, 1, true)
    
  -- We specify a default position/size in case there's no data in the .ini file.
    local main_viewport = ImGui_GetMainViewport(ctx)
    local work_pos = {ImGui_Viewport_GetWorkPos(main_viewport)}
    --ImGui_SetNextWindowPos(ctx, work_pos[1] + 20, work_pos[2] + 20, ImGui_Cond_FirstUseEver())
    local useini = ImGui_Cond_FirstUseEver()
    ImGui_SetNextWindowSize(ctx, 400, 200, useini)
    
    
  -- init UI 
    ImGui_PushFont(ctx, DATA.font1) 
    rv,open = ImGui_Begin(ctx, DATA.UI_name, open, window_flags) if not rv then return open end  
    local ImGui_Viewport = ImGui_GetWindowViewport(ctx)
    DATA.display_w, DATA.display_h = ImGui_Viewport_GetSize(ImGui_Viewport)
    
  -- calc stuff for childs
    UI.calc_xoffset,UI.calc_yoffset = reaper.ImGui_GetStyleVar(ctx, ImGui_StyleVar_WindowPadding())
    local framew,frameh = reaper.ImGui_GetStyleVar(ctx, ImGui_StyleVar_FramePadding())
    local calcitemw, calcitemh = ImGui_CalcTextSize(ctx, 'test', nil, nil, false, -1.0)
    UI.calc_itemH = calcitemh + frameh * 2
    UI.calc_itemH_small = math.floor(UI.calc_itemH*0.8)
    
  -- draw stuff
    UI.draw()
    ImGui_PopFont( ctx ) 
    ImGui_PopStyleVar(ctx, UI.pushcnt)
    ImGui_PopStyleColor(ctx, UI.pushcnt2)
    
    ImGui_Dummy(ctx,0,0)
  ImGui_End(ctx)
  
  return open
end
-------------------------------------------------------------------------------- 
function DATA:perform_add(f) DATA.perform_quere[#DATA.perform_quere+1] = f end
-------------------------------------------------------------------------------- 
function DATA:perform()
  if not DATA.perform_quere then return end
  for i = 1, #DATA.perform_quere do if DATA.perform_quere[i] then DATA.perform_quere[i]() end end
  DATA.perform_quere = {} --- clear
end
-------------------------------------------------------------------------------- 
function UI.MAINloop() 
  DATA.clock = os.clock() 
  DATA:handleProjUpdates()
  
  if DATA.upd == true then DATA.CollectData() end 
  DATA.upd = false
  
  -- draw UI
  UI.open = UI.MAIN_draw(true) 
  
  -- data
  if UI.open then defer(UI.MAINloop) end
end
-------------------------------------------------------------------------------- 
function UI.SameLine(ctx) reaper.ImGui_SameLine(ctx) reaper.ImGui_SameLine(ctx)end
-------------------------------------------------------------------------------- 
function UI.MAIN()
  
  EXT:load() 
  -- imgUI init
  ctx = ImGui_CreateContext(DATA.UI_name) 
  -- fonts
  DATA.font1 = ImGui_CreateFont(UI.font, UI.font1sz) ImGui_Attach(ctx, DATA.font1)
  DATA.font2 = ImGui_CreateFont(UI.font, UI.font2sz) ImGui_Attach(ctx, DATA.font2)
  DATA.font3 = ImGui_CreateFont(UI.font, UI.font3sz) ImGui_Attach(ctx, DATA.font3)  
  -- config
  reaper.ImGui_SetConfigVar(ctx, ImGui_ConfigVar_HoverDelayNormal(), UI.hoverdelay)
  reaper.ImGui_SetConfigVar(ctx, ImGui_ConfigVar_HoverDelayShort(), UI.hoverdelayshort)
  
  -- run loop
  defer(UI.MAINloop)
end
-------------------------------------------------------------------------------- 
function EXT:save() 
  if not DATA.ES_key then return end 
  for key in pairs(EXT) do 
    if (type(EXT[key]) == 'string' or type(EXT[key]) == 'number') then 
      SetExtState( DATA.ES_key, key, EXT[key], true  ) 
    end 
  end 
  EXT:load()
end
-------------------------------------------------------------------------------- 
function EXT:load() 
  if not DATA.ES_key then return end
  for key in pairs(EXT) do 
    if (type(EXT[key]) == 'string' or type(EXT[key]) == 'number') then 
      if HasExtState( DATA.ES_key, key ) then 
        local val = GetExtState( DATA.ES_key, key ) 
        EXT[key] = tonumber(val) or val 
      end 
    end  
  end 
  DATA.upd = true
end
-------------------------------------------------------------------------------- 
function DATA:handleProjUpdates()
  local SCC =  GetProjectStateChangeCount( 0 ) if (DATA.upd_lastSCC and DATA.upd_lastSCC~=SCC ) then DATA.upd = true return end  DATA.upd_lastSCC = SCC
  local editcurpos =  GetCursorPosition()  if (DATA.upd_last_editcurpos and DATA.upd_last_editcurpos~=editcurpos ) then DATA.upd = true end DATA.upd_last_editcurpos=editcurpos 
  local reaproj = tostring(EnumProjects( -1 )) if (DATA.upd_last_reaproj and DATA.upd_last_reaproj ~= reaproj) then DATA.upd = true end DATA.upd_last_reaproj = reaproj
end
------------------------------------------------------------------------------------------------------
function VF_Action(s, sectionID, ME )   
  if sectionID == 32060 and ME then 
    MIDIEditor_OnCommand( ME, NamedCommandLookup(s) )
   else
    Main_OnCommand(NamedCommandLookup(s), sectionID or 0) 
  end
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
--------------------------------------------------------------------------------  
function DATA.CollectData_buildsegment()
  -- init first segment
  if #DATA.segments ==0 then return end
  
  local new_t = {}
  -- check / extend existing
  for i = 1, #DATA.segments do
    local segm_st2=DATA.segments[i].segm_st
    local segm_end2=DATA.segments[i].segm_end 
    local changed
    
    for j = 1, #new_t do
      local segm_st=new_t[j].segm_st
      local segm_end=new_t[j].segm_end
      
      -- start is inside existing segment
      if segm_st2 >=segm_st and segm_st2<=segm_end then
        if segm_end2 > segm_end then 
          new_t[j].segm_end = segm_end2
          changed = true
          goto skipnext 
        end
      end
      
      -- item ends inside segment
      if segm_end2 >=segm_st and segm_end2 <=segm_end then 
        if segm_st2 < segm_st then 
          new_t[j].segm_st = segm_st2 
          changed = true
          goto skipnext  
        end
      end
      
      -- item over existing segment
      if segm_st2<segm_st and segm_end2 >segm_end then 
        new_t[j].segm_st = segm_st2
        new_t[j].segm_end = segm_end2
        changed = true
        goto skipnext 
      end 
      
      -- item inside existing segment
      if segm_st2>=segm_st and segm_end2 <=segm_end then 
        changed = true
        goto skipnext 
      end 
      
      
      ::skipnext::
    end
    
    if not changed then new_t[#new_t+1] = CopyTable(DATA.segments[i]) end
  end
  DATA.segments=new_t
end
--------------------------------------------------------------------------------  
function DATA.CollectData()
  local cntit = CountSelectedMediaItems(0)
  DATA.segments = {}
  
  for i = 1, cntit do
    local item = GetSelectedMediaItem(0,i-1) 
    local pos = GetMediaItemInfo_Value( item, 'D_POSITION'  )
    local len = GetMediaItemInfo_Value( item, 'D_LENGTH' ) 
    DATA.segments[#DATA.segments+1] = {segm_st=pos,segm_end =pos+len}
  end
  
  DATA.CollectData_buildsegment()
  
end
--------------------------------------------------------------------------------  
function main()
  UI.MAIN() 
end
----------------------------------------------------------------------------  
function UI.draw_setbuttoncolor(col) 
    UI.MAIN_PushStyle(ImGui_Col_Button(),col, 0.3, true) 
    UI.MAIN_PushStyle(ImGui_Col_ButtonActive(),col, 1, true) 
    UI.MAIN_PushStyle(ImGui_Col_ButtonHovered(),col, 0.8, true)
end
--------------------------------------------------------------------------------  
function UI.draw_unsetbuttoncolor() 
  ImGui_PopStyleColor(ctx,3)
  UI.pushcnt2 = UI.pushcnt2 -3
end
--------------------------------------------------------------------------------  
function UI.draw() 
  local env_txt = '[Get envelope]'
  if DATA.env_valid == true then  env_txt = DATA.env_name end
  if ImGui_Button(ctx, env_txt) then
    local envelope = GetSelectedEnvelope( 0 )
    if not envelope then return end
    DATA.env_valid = true
    DATA.env_ptr = envelope
    local  retval, buf = reaper.GetEnvelopeName( envelope )
    DATA.env_name = buf
  end
  if ImGui_Button(ctx, 'Build envelope') then DATA.BuildEnvelope() end
  
  local slidermoved
  local format = '%.02fs'
  local retval, v = ImGui_SliderDouble(ctx, 'Ignore gap', EXT.ignoregap, 0, 1.5, format, ImGui_SliderFlags_None()) if retval then slidermoved = true EXT.ignoregap = v  end
  local retval, v = ImGui_SliderDouble(ctx, 'Offset start', EXT.offsetL, 0, 1, format, ImGui_SliderFlags_None()) if retval then slidermoved = true EXT.offsetL = v  end
  local retval, v = ImGui_SliderDouble(ctx, 'Offset end', EXT.offsetR, 0, 1, format, ImGui_SliderFlags_None()) if retval then slidermoved = true EXT.offsetR = v  end
  
  
  if ImGui_IsMouseReleased(ctx, ImGui_MouseButton_Left())  then 
    DATA.BuildEnvelope()
    EXT:save() 
  end
end
--------------------------------------------------------------------------------  
function DATA.BuildEnvelope()
  if #DATA.segments == 0 then return end
  if DATA.env_valid ~= true then return end
  if not ValidatePtr( DATA.env_ptr, 'TrackEnvelope*' ) then return end
  local envelope = DATA.env_ptr
   
  
  -- clear env
    local time_start = DATA.segments[1].segm_st
    local time_end = DATA.segments[#DATA.segments].segm_end
    DeleteEnvelopePointRange( envelope, time_start, time_end )
    
  -- form output env
  local shape = 1
  local cnt = #DATA.segments
  for i = 1, cnt do 
    local time = DATA.segments[i].segm_st 
    InsertEnvelopePoint( envelope, time+EXT.offsetL, 0, shape, 0, 0, true )
    if i < cnt then -- not last point
      if DATA.segments[i+1].segm_st-EXT.ignoregap>=DATA.segments[i].segm_end then 
        local time = DATA.segments[i].segm_end 
        InsertEnvelopePoint( envelope, time-EXT.offsetR, 1, shape, 0, 0, true )
      end
    end
    
    if i >1 then -- not first point
      if DATA.segments[i-1].segm_end + EXT.ignoregap<=DATA.segments[i].segm_st then 
        local time = DATA.segments[i].segm_end 
        InsertEnvelopePoint( envelope, time-EXT.offsetR, 1, shape, 0, 0, true )
      end
    end
    
  end
  Envelope_SortPoints( envelope )
  UpdateArrange()
end
--------------------------------------------------------------------------------  
app_vrs = tonumber(reaper.GetAppVersion():match('[%d%.]+'))
if app_vrs < 7 then 
  MB('This script require REAPER 7.0+','',0)
 else
  if not APIExists( 'ImGui_GetVersion' ) then MB('This script require ReaImGui extension','',0) return end
  main()
end