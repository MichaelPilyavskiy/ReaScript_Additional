 -- @description RS5k manager
-- @version 5.0
-- @author MPL
-- @website https://forum.cockos.com/showthread.php?t=207971
-- @about Script for handling ReaSamplomatic5000 data on group of connected tracks
-- @provides
--    [main] mpl_RS5k_StepSequencer.lua
--    [main] mpl_RS5k_manager_Database_NewKit.lua
--    [main] mpl_RS5k_manager_Database_LoadAllPads.lua
--    [main] mpl_RS5k_manager_Database_LoadSelectedPads.lua
--    [main] mpl_RS5k_manager_Database_NextMap.lua
--    [main] mpl_RS5k_manager_Database_PrevMap.lua
--    [main] mpl_RS5k_manager_Database_Lock.lua
--    [main] mpl_RS5k_manager_Sampler_PreviousSample.lua
--    [main] mpl_RS5k_manager_Sampler_NextSample.lua
--    [main] mpl_RS5k_manager_Sampler_RandSample.lua 
--    [main] mpl_RS5k_manager_DrumRack_Solo.lua
--    [main] mpl_RS5k_manager_DrumRack_Mute.lua 
--    [main] mpl_RS5k_manager_DrumRack_Clear.lua
--    [jsfx] mpl_RS5k_manager_MacroControls.jsfx
--    [jsfx] mpl_RS5K_manager_MIDIBUS_choke.jsfx
--    [jsfx] mpl_RS5K_manager_sysex_handler.jsfx
--    [main] mpl_RS5k_manager_ToggleShowChildren.lua
-- @changelog
--    + Settings/On sample add/FX instance: min gain


rs5kman_vrs = '5.0'


is_new_value,filename,sectionID,cmdID,mode,resolution,val,contextstr = reaper.get_action_context()
Entry = reaper.ReaPack_GetOwner( filename )
test = {reaper.ReaPack_GetEntryInfo( Entry )} -- retval, repo, cat, pkg, desc, ptype, ver, author, flags, fileCount = 
-- TODO
--[[  
      
      seq
        if pattern has same GUId than oth er BUT not pooled or pool is diffent https://forum.cockos.com/showthread.php?p=2866575
        groups
        launchpad interaction
        
      sampler/sample
        hot record from master bus 
         
      auto
        auto switch midi bus record arm if playing with another rack 
        autocolor by content
        
      on sample add
        wildcards - device name
        wildcards - children - #notenuber #noteformat #samplename
        wildcards - samples path 
        
      layout
        step seq mode + input write step + scroll control over programming mode
          
      sampler/fx
        compressor
        transient shaper
        
      sampler/send tab - add sends to reverb, delay inside based on existing send tracks (predefine using sends folder name)
      
      sampler/global tweaks
        better handle global tweaks
        
      sampler/device
        FPC style rangesplit  
        
      autoslice
        set minimal length
        do not allow slices with low RMS (glue with previeos slice)
        
      autolufs
        use as a compensation
]]

    
--------------------------------------------------------------------------------  init globals
    for key in pairs(reaper) do _G[key]=reaper[key] end
    app_vrs = tonumber(GetAppVersion():match('[%d%.]+'))
    if app_vrs < 6.73 then return reaper.MB('This script require REAPER 6.73+','',0) end
    --local ImGui
    
    if not reaper.ImGui_GetBuiltinPath then return reaper.MB('This script require reaimgui extension','',0) end
    package.path =   reaper.ImGui_GetBuiltinPath() .. '/?.lua'
    ImGui = require 'imgui' '0.9.3.2'
    
    --[[
      gmem 1025: actions 
        / 10=DATA.upd refresh rack
        / 11=DATA.upd refresh steseq // use 1030 instead
      gmem 1026: read-only - rs5k manager opened state 
      gmem 1027: read-only - rs5k stepseq opened state
      gmem 1028: force stepseq read extstate
      gmem 1029: incoming note for launchpad step seq
      gmem 1030: DATA.upd refresh steseq
    ]]
    
    
    
  -------------------------------------------------------------------------------- init external defaults 
  EXT = {
          viewport_posX = 10,
          viewport_posY = 10,
          viewport_posW = 800,
          viewport_posH = 300, 
          viewport_dockID = 0,
          
          INI_fix = 0,
          
          -- rs5k on add
          CONF_onadd_float = 0,
          CONF_onadd_obeynoteoff = 1,
          CONF_onadd_customtemplate = '',
          CONF_onadd_renametrack = 1,
          CONF_onadd_copytoprojectpath = 0, 
          CONF_onadd_copysubfoldname = 'RS5kmanager_samples' ,
          CONF_onadd_newchild_trackheightflags = 0, -- &1 folder collapsed &2 folder supercollapsed &4 hide tcp &8 hide mcp
          CONF_onadd_newchild_trackheight = 0,
          CONF_onadd_newchild_trackheight_lock = 0,
          CONF_onadd_whitekeyspriority = 0,
          CONF_onadd_ordering = 0, -- 0 sorted by note 1 at the top 2 at the bottom
          CONF_onadd_takeparentcolor = 0,
          CONF_onadd_autosetrange = 0,
          CONF_onadd_renameinst = 0,
          CONF_onadd_renameinst_str = 'RS5k',
          CONF_onadd_autoLUFSnorm = -14, 
          CONF_onadd_autoLUFSnorm_toggle = 0, 
          CONF_onadd_ADSR_flags = 0,--&1 A &2 D &4 S &8 R
          CONF_onadd_ADSR_A = 0,
          CONF_onadd_ADSR_D = 15,
          CONF_onadd_ADSR_S = 0,
          CONF_onadd_ADSR_R = 0.02,
          CONF_onadd_sysexmode = 0,
          CONF_onadd_maxvoices = 1,
          CONF_onadd_minvel = 1,
          CONF_onadd_maxvel = 127,
          CONF_onadd_mingain = 0,
          
          -- midi bus
          CONF_midiinput = 63, -- 63 all 62 midi kb
          CONF_midioutput = -1, 
          CONF_midichannel = 0, -- 0 == all channels 
          
          -- sampler
          CONF_cropthreshold = -60, -- db
          CONF_crop_maxlen = 30,
          CONF_default_velocity = 120,
          CONF_stepmode = 0,
          CONF_stepmode_transientahead = 0.01,
          CONF_stepmode_keeplen = 1, 
          
          -- UI
          
          UI_transparency = 1,
          UI_processoninit = 0,
          UI_addundototabclicks = 0,
          UI_clickonpadselecttrack = 1,
          UI_clickonpadscrolltomixer = 0,
          UI_clickonpadplaysample = 0, --
          UI_incomingnoteselectpad = 0,
          UI_defaulttabsflags = 1|4|8, --1=drumrack   2=device  4=sampler 8=padview 16=macro 32=database 64=midi map 128=children chain
          UI_pads_sendnoteoff = 1,
          UI_drracklayout = 0,
          UI_drracklayout_custommapB64 = '',
          UI_drracklayout_customID = 0,
          UIdatabase_maps_current = 1,
          UI_padcustomnames = '',
          UI_padcustomnamesB64 = '', -- patch for 4.57
          UI_padautocolors = '',
          UI_padautocolorsB64 = '',-- patch for 4.57
          CONF_showplayingmeters = 1,
          CONF_showpadpeaks = 1,
          --UI_optimizedockerusage = 0,
          UI_colRGBA_paddefaultbackgr = 0x1C1C1C7F ,
          UI_colRGBA_paddefaultbackgr_inactive = 0x6060603F,
          UI_col_tinttrackcoloralpha = 0x7F,
          UI_colRGBA_padctrl = 0x4F4F4FFF,
          UI_colRGBA_smplrbackgr = 0xFFFFFF2F,
          UI_allowshortcuts = 1, -- allow space to play
          UI_allowdoplayeronpad = 0,
          UI_showcurrentdbmap = 0,
          UI_colRGBA_maintheme_color = 0x337233FF,
          
          -- other 
          CONF_autorenamemidinotenames = 1|2, 
          CONF_trackorderflags = 0,  -- ==0 sort by date ascending, ==2 sort by date descending, ==3 sort by note ascending, ==4 sort by note descending
          CONF_autoreposition = 0, --0 off
          
          -- 3rd party
          CONF_plugin_mapping_b64 = '', 
          
          -- database 
          CONF_ignoreDBload = 0, 
          CONF_database_map1 = '',
          CONF_database_map2 = '',
          CONF_database_map3 = '',
          CONF_database_map4 = '',
          CONF_database_map5 = '',
          CONF_database_map6 = '',
          CONF_database_map7 = '',
          CONF_database_map8 = '',
           
          -- actions
          CONF_importselitems_removesource = 0,
          CONF_explodeMIDItochildren_note = 36,
          
          -- auto color
          CONF_autocol = 0, -- 1 sort by note 
          
          -- loop check
          CONF_loopcheck = 1, 
          CONF_loopcheck_minlen = 2,
          CONF_loopcheck_maxlen = 8,
          CONF_loopcheck_filter = 'bd,bass,kick',
          --CONF_loopcheck_smoothend_use = 1,
          --CONF_loopcheck_smoothend = 0.005,
          
          -- seq
          CONF_seq_random_probability = 0.5,
          CONF_seq_force_GUIDbasedsharing = 0,
          CONF_seq_treat_mouserelease_as_majorchange  = 0, 
          CONF_seq_patlen_extendchildrenlen = 0,
          CONF_seq_instrumentsorder = 1, 
          CONF_seq_stuffMIDItoLP = 0, 
          CONF_seq_defaultstepcnt = 16, -- -1 follow pattern length
          CONF_seq_env_clamp = 1, -- 0 == allow env points on empty steps
          CONF_seq_steplength = 0.25,
          CONF_seq_autolegato = 0,
         }
        
  -------------------------------------------------------------------------------- INIT data
  DATA = {
          
          scheduler = {},
          
          seq_functionscall = true,
          upd = true,
          upd2 = {
            refreshpeaks = true,
          },
          ES_key = 'MPL_RS5K manager',
          UI_name = 'RS5K manager', 
          version = 4, -- for ext state save
          bandtypemap = {  
                  [-1] = 'Off',
                  [3] = 'Low pass' ,
                  [0] = 'Low shelf',
                  [1] = 'High shelf' ,
                  [8] = 'Band' ,
                  [4] = 'High pass' ,
                  --[5] = 'All pass' ,
                  --[6] = 'Notch' ,
                  --[7] = 'Band pass' ,
                  --[10] = 'Parallel BP' ,
                  --[9] = 'Band alt' ,
                  --[2] = 'Band alt2' ,
                  },
          playingnote = -1,
          playingnote_trigTS = 0,
          MIDI_inputs = {},
          MIDI_outputs = {},
          lastMIDIinputnote = {},
          reaperDB = {},
          MIDIOSC = {}, 
          actions_popup = {},
          VCA_mode = 0,
          plugin_mapping = {},
          settings_cur_note_database =0,
          padcustomnames = {},
          padautocolors = {},
          padcustomnames_selected_id = 1,
          padautocolors_selected_id = 1,
          
          loopcheck_trans_area_frame = 10, 
          loopcheck_testdraw = 0, 
          
          min_steplength = 2^-5, --0,03125
          max_steplength = 2^0, -- 1
          
          peakscache = {},
          boundarystep = {
            [0] = {str='1ms',val=0.001},
            [1] = {str='5ms',val=0.005},
            [2] = {str='10ms',val=0.01},
            [3] = {str='20ms',val=0.02},
            [4] = {str='100ms',val=0.1},
            [4] = {str='200ms',val=0.2},
            [5] = {str='1/8 beat',val=-0.125},
            [6] = {str='1/4 beat',val=-0.25},
            [7] = {str='1/2 beat',val=-0.5},
            [8] = {str='beat',val=-1},
            [9] = {str='bar',val=-4},
            [10] = {str='next transient',val=-100},
          },
          
          
          allow_space_to_play = true,
          allow_container_usage = app_vrs >=7.06,
          MIDIhandler = 'RS5k_manager MIDI_handler',
          
          allowed_db_maps_cnt = 8,
          
          
          
          seq = {} ,
          
          allow_space_to_play = true, 
          allow_container_usage = app_vrs >=7.06,
          MIDIhandler = 'RS5k_manager MIDI_handler',
          
          seq_param_selectorID = 1,
          seq_param_selector = { 
            {param = 'velocity', str= 'Velocity',default=120/127, maxval = 1, minval = 1/127},
            {param = 'offset', str= 'Offset',default=0, maxval = 0.95, minval = -0.95},
            {param = 'split', str= 'Split',default=1, maxval = 8, minval = 1},
            {param = 'steplen_override', str= 'Length',default=1, maxval = 4, minval = 0.1},
            {param = 'meta', str= 'Meta'},
            {param = 'trackenv', str= 'Track'},
            {param = 'trackFXenv', str= 'FX'},
          },
          
          seq_param_selector_metaID = 1,
          seq_param_selector_meta = { 
            {param = 'meta_pitch', str= 'Pitch',default=64, minval = 64-24, maxval = 64+24},
            {param = 'meta_probability', str= 'Probability',default=1, minval = 0, maxval = 1},
          }, 
          
          seq_param_selector_trackenvID = 1,
          seq_param_selector_trackenv = {},
          
          seq_param_selector_trackFXenvID = 1,
          seq_param_selector_trackFXenv = {},
          
          seq_horiz_scroll = 0,
          seq_patlen_extendchildrenlen = 0,
          seq_UI_inlineH_area = 285,
          seq_init_Yscroll = 0,
          seq_LPstepseqmode = 0,
          
          
          }
  DATA.UI_name_vrs = DATA.UI_name..' '..rs5kman_vrs
  
  -------------------------------------------------------------------------------- INIT UI locals
  for key in pairs(reaper) do _G[key]=reaper[key] end 
  --local ctx
  -------------------------------------------------------------------------------- UI init variables
    UI = {
      -- font
        font='Arial',
        font1sz=15,
        font2sz=14,
        font3sz=13,
        font4sz=12,
        font5sz=11,
      -- mouse
        hoverdelay = 0.8,
        hoverdelayshort = 0.5,
      -- size / offset
        spacingX = 4,
        spacingY = 3,
      -- colors / alpha
        main_col = 0x7F7F7F, -- grey
        textcol = 0xFFFFFF, -- white
        textcol_a_enabled = 1,
        textcol_a_disabled = 0.5,
        but_hovered = 0x878787,
        windowBg = 0x303030,
          }
  
    -- size
    UI.w_min = 530
    UI.h_min = 300
    UI.settingsfixedW = 450
    UI.actionsbutW = 60
    UI.settings_itemW = 180 
    UI.settings_indent  = 10
    UI.knob_resY = 150
    UI.sampler_peaksH = 50
    UI.sampler_peaksfullH = 30
    UI.controls_minH = 40
    UI.adsr_rectsz = 10
    UI.scrollbarsz = 10
    
    -- colors
    
    UI.col_red = 0xB31F0F  
    UI.padplaycol = 0x00FF00 
    UI.knob_handle = 0xc8edfa
    UI.knob_handle_normal = UI.knob_handle
    UI.knob_handle_vca =0xFF0000
    UI.knob_handle_vca2 =0xFFFF00
    UI.col_popup = 0x005300 
    UI.def_colRGBA_paddefaultbackgr = 0x1C1C1C7F
    UI.def_colRGBA_paddefaultbackgr_inactive = 0x6060603F
    UI.def_colRGBA_padctrl = 0x4F4F4FFF
    UI.colRGBA_smplrbackgr = 0xFFFFFF2F
    -- various
    UI.tab_context = '' -- for context menu
    
    -- mouse
    UI.dragY_res = 10
    
    -- seq
    UI.seq_stepW = 24
    UI.seq_padH = 28
    UI.seq_separatorH = 3
    UI.seq_padnameW = 120
    UI.seq_activestep_reducesz = 2 
    UI.seq_audiolevelW = 5 
    UI.seq_stepreduceW = 2 
    UI.seq_steprounding = 2
    UI.seq_maxstepcnt = 1024
  
  
  --------------------------------------------------------------------------------  
  function UI.transparentButton(ctx, str_id, w,h)
    ImGui.PushFont(ctx, DATA.font4) 
    UI.draw_setbuttonbackgtransparent()
    ImGui.Button(ctx, str_id, w,h)
    UI.Tools_unsetbuttonstyle()
    ImGui.PopFont(ctx) 
  end

  --------------------------------------------------------------------------------  
  function UI.Tools_setbuttonbackg(col)   
    ImGui.PushStyleColor(ctx, ImGui.Col_Button, col or 0 )
    ImGui.PushStyleColor(ctx, ImGui.Col_ButtonActive, col or 0 )
    ImGui.PushStyleColor(ctx, ImGui.Col_ButtonHovered, col or 0 )
  end
  --UI.Tools_setbuttonbackg()
  --UI.Tools_unsetbuttonstyle()
    --------------------------------------------------------------------------------  
  function UI.Tools_unsetbuttonstyle() ImGui.PopStyleColor(ctx,3) end 
  -------------------------------------------------------------------------------- 
  function UI.Tools_RGBA(col, a_dec) return col<<8|math.floor(a_dec*255) end  
  -------------------------------------------------------------------------------- 
  function UI.MAIN_styledefinition(open) 
    function __f_styledef() end
      UI.anypopupopen = ImGui.IsPopupOpen( ctx, 'mainRCmenu', ImGui.PopupFlags_AnyPopup|ImGui.PopupFlags_AnyPopupLevel )
      
    -- window_flags
      local window_flags = ImGui.WindowFlags_None
      window_flags = window_flags | ImGui.WindowFlags_NoTitleBar
      window_flags = window_flags | ImGui.WindowFlags_NoScrollbar
      --window_flags = window_flags | ImGui.WindowFlags_MenuBar
      --window_flags = window_flags | ImGui.WindowFlags_NoMove()
      --window_flags = window_flags | ImGui.WindowFlags_NoResize
      window_flags = window_flags | ImGui.WindowFlags_NoCollapse
      window_flags = window_flags | ImGui.WindowFlags_NoNav
      --window_flags = window_flags | ImGui.WindowFlags_NoBackground
      --window_flags = window_flags | ImGui.WindowFlags_NoDocking
      --window_flags = window_flags | ImGui.WindowFlags_TopMost
      window_flags = window_flags | ImGui.WindowFlags_NoScrollWithMouse
      --window_flags = window_flags | ImGui.WindowFlags_NoSavedSettings
      --window_flags = window_flags | ImGui.WindowFlags_UnsavedDocument
      --open = false -- disable the close button
    
    
    -- rounding
      ImGui.PushStyleVar(ctx, ImGui.StyleVar_FrameRounding,5)  
      ImGui.PushStyleVar(ctx, ImGui.StyleVar_GrabRounding,3)  
      ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowRounding,10)  
      ImGui.PushStyleVar(ctx, ImGui.StyleVar_ChildRounding,5)  
      ImGui.PushStyleVar(ctx, ImGui.StyleVar_PopupRounding,10)  
      ImGui.PushStyleVar(ctx, ImGui.StyleVar_ScrollbarRounding,9)  
      ImGui.PushStyleVar(ctx, ImGui.StyleVar_TabRounding,4)   
    -- Borders
      ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowBorderSize,0)  
      ImGui.PushStyleVar(ctx, ImGui.StyleVar_FrameBorderSize,0) 
    -- spacing
      ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowPadding,UI.spacingX,UI.spacingY)  
      ImGui.PushStyleVar(ctx, ImGui.StyleVar_FramePadding,UI.spacingX*2,UI.spacingY) 
      ImGui.PushStyleVar(ctx, ImGui.StyleVar_CellPadding,UI.spacingX, UI.spacingY) 
      ImGui.PushStyleVar(ctx, ImGui.StyleVar_ItemSpacing,UI.spacingX, UI.spacingY)
      ImGui.PushStyleVar(ctx, ImGui.StyleVar_ItemInnerSpacing,4,0)
      ImGui.PushStyleVar(ctx, ImGui.StyleVar_IndentSpacing,20)
      ImGui.PushStyleVar(ctx, ImGui.StyleVar_ScrollbarSize,UI.scrollbarsz)
    -- size
      ImGui.PushStyleVar(ctx, ImGui.StyleVar_GrabMinSize,20)
      ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowMinSize,UI.w_min,UI.h_min)
    -- align
      ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowTitleAlign,0.5,0.5)
      ImGui.PushStyleVar(ctx, ImGui.StyleVar_ButtonTextAlign,0.5,0.5)
      ImGui.PushStyleVar(ctx, ImGui.StyleVar_SelectableTextAlign,0,0.5)
      
    -- alpha
      ImGui.PushStyleVar(ctx, ImGui.StyleVar_Alpha,1)
      ImGui.PushStyleColor(ctx, ImGui.Col_Border,           UI.Tools_RGBA(0x000000, 0.3))
    -- colors
      ImGui.PushStyleColor(ctx, ImGui.Col_Button,           UI.Tools_RGBA(UI.main_col, 0.2))
      ImGui.PushStyleColor(ctx, ImGui.Col_ButtonActive,     UI.Tools_RGBA(UI.main_col, 1) )
      ImGui.PushStyleColor(ctx, ImGui.Col_CheckMark,        (EXT.UI_colRGBA_maintheme_color&0xFFFFFF00)|0xF0)
      ImGui.PushStyleColor(ctx, ImGui.Col_ButtonHovered,    UI.Tools_RGBA(UI.but_hovered, 0.8))
      ImGui.PushStyleColor(ctx, ImGui.Col_DragDropTarget,   UI.Tools_RGBA(0xFF1F5F, 0.6))
      ImGui.PushStyleColor(ctx, ImGui.Col_FrameBg,          UI.Tools_RGBA(0x1F1F1F, 0.7))
      ImGui.PushStyleColor(ctx, ImGui.Col_FrameBgActive,    UI.Tools_RGBA(UI.main_col, .6))
      ImGui.PushStyleColor(ctx, ImGui.Col_FrameBgHovered,   UI.Tools_RGBA(UI.main_col, 0.7))
      ImGui.PushStyleColor(ctx, ImGui.Col_Header,           UI.Tools_RGBA(UI.main_col, 0.3) )
      ImGui.PushStyleColor(ctx, ImGui.Col_HeaderActive,     UI.Tools_RGBA(UI.main_col, 1) )
      ImGui.PushStyleColor(ctx, ImGui.Col_HeaderHovered,    UI.Tools_RGBA(UI.main_col, 0.98) )
      ImGui.PushStyleColor(ctx, ImGui.Col_PopupBg,          UI.Tools_RGBA(0x303030, 1) )
      ImGui.PushStyleColor(ctx, ImGui.Col_ResizeGrip,       (EXT.UI_colRGBA_maintheme_color&0xFFFFFF00)|0x90 )
      ImGui.PushStyleColor(ctx, ImGui.Col_ResizeGripHovered,(EXT.UI_colRGBA_maintheme_color&0xFFFFFF00)|0xF0 )
      ImGui.PushStyleColor(ctx, ImGui.Col_ResizeGripActive, (EXT.UI_colRGBA_maintheme_color&0xFFFFFF00)|0xC0 )
      ImGui.PushStyleColor(ctx, ImGui.Col_SliderGrab,       (EXT.UI_colRGBA_maintheme_color&0xFFFFFF00)|0x90) 
      ImGui.PushStyleColor(ctx, ImGui.Col_SliderGrabActive, (EXT.UI_colRGBA_maintheme_color&0xFFFFFF00)|0xC0 )
      ImGui.PushStyleColor(ctx, ImGui.Col_Tab,              (EXT.UI_colRGBA_maintheme_color&0xFFFFFF00)|0x70 )
      ImGui.PushStyleColor(ctx, ImGui.Col_TabSelected,      (EXT.UI_colRGBA_maintheme_color&0xFFFFFF00)|0xD0)
      ImGui.PushStyleColor(ctx, ImGui.Col_TabHovered,       (EXT.UI_colRGBA_maintheme_color&0xFFFFFF00)|0xF0 )
      ImGui.PushStyleColor(ctx, ImGui.Col_Text,             UI.Tools_RGBA(UI.textcol, UI.textcol_a_enabled) )
      ImGui.PushStyleColor(ctx, ImGui.Col_TitleBg,          UI.Tools_RGBA(UI.main_col, 0.7) )
      ImGui.PushStyleColor(ctx, ImGui.Col_TitleBgActive,    UI.Tools_RGBA(UI.main_col, 0.95) )
      ImGui.PushStyleColor(ctx, ImGui.Col_WindowBg,         UI.Tools_RGBA(UI.windowBg, EXT.UI_transparency))
      
    -- We specify a default position/size in case there's no data in the .ini file.
      local main_viewport = ImGui.GetMainViewport(ctx)
      local x, y, w, h =EXT.viewport_posX,EXT.viewport_posY, EXT.viewport_posW,EXT.viewport_posH
      DATA.display_viewport_w, DATA.display_viewport_h = ImGui.Viewport_GetSize(main_viewport) 
      --ImGui.SetNextWindowPos(ctx, x, y, ImGui.Cond_Appearing )
      --ImGui.SetNextWindowSize(ctx, w, h, ImGui.Cond_Appearing)
      --ImGui.SetNextWindowDockID( ctx, EXT.viewport_dockID)
      
    -- init UI 
      ImGui.PushFont(ctx, DATA.font2) 
      DATA.titlename_reduced = ''
      if DATA.parent_track and DATA.parent_track.name and DATA.parent_track.IP_TRACKNUMBER_0based then 
        --DATA.titlename = '[Track '..math.floor(DATA.parent_track.IP_TRACKNUMBER_0based+1)..'] '..DATA.parent_track.name..' // '..DATA.UI_name..' '..rs5kman_vrs 
        DATA.titlename_reduced = DATA.parent_track.name
      end
      
      local rv,open = ImGui.Begin(ctx, DATA.UI_name, open, window_flags) --
      if rv then
        local Viewport = ImGui.GetWindowViewport(ctx)
        DATA.display_x, DATA.display_y = ImGui.Viewport_GetPos(Viewport) 
        DATA.display_w, DATA.display_h = ImGui.Viewport_GetSize(Viewport) 
        DATA.display_x_work, DATA.display_y_work = ImGui.Viewport_GetWorkPos(Viewport)
        -- hidingwindgets
        DATA.display_whratio = DATA.display_w / DATA.display_h
        UI.hide_padoverview = false
        UI.hide_tabs = false 
        if DATA.display_whratio < 1.7 then UI.hide_padoverview = true end
        if DATA.display_w < UI.settingsfixedW * 1.8 then UI.hide_tabs = true end
        --if DATA.display_w > UI.settingsfixedW * 5 then UI.hide_tabs = true end
        
        -- calc stuff for childs
        UI.calc_xoffset,UI.calc_yoffset = ImGui.GetStyleVar(ctx, ImGui.StyleVar_WindowPadding)
        local framew,frameh = ImGui.GetStyleVar(ctx, ImGui.StyleVar_FramePadding)
        local calcitemw, calcitemh = ImGui.CalcTextSize(ctx, 'test')
        UI.calc_itemH = calcitemh + frameh * 2
        
        -- calc settings
        UI.calc_settingsW = UI.settingsfixedW 
        if UI.hide_tabs == true then UI.calc_settingsW = 0 end 
        
        -- calc padoverview
        UI.calc_padoverviewH = DATA.display_h- UI.spacingY*3- UI.calc_itemH
        UI.calc_padoverview_cellside = UI.calc_padoverviewH/32  
        UI.calc_padoverviewW = UI.calc_padoverview_cellside * 4 + UI.spacingX*2
        if UI.calc_padoverviewW < 30 or UI.calc_padoverviewW > 60 or EXT.UI_drracklayout == 2 then UI.hide_padoverview = true end
        if EXT.UI_drracklayout == 1 then --keys
          UI.calc_padoverview_cellside = UI.calc_padoverviewH /22
          UI.calc_padoverviewW = UI.calc_padoverview_cellside * 7 + UI.spacingX*2
        end 
        if UI.hide_padoverview == true and EXT.UI_drracklayout ~= 2 then UI.calc_padoverviewW = 0 end
        if UI.hide_padoverview == true and EXT.UI_drracklayout == 2 then UI.calc_padoverviewW = 28 end
         
        -- rack
        local rack_max_width = 500
        local rack_min_height = 250
        UI.calc_rackX = DATA.display_x + UI.spacingX + UI.calc_padoverviewW
        UI.calc_rackY = DATA.display_y + UI.spacingY 
        if ImGui_IsWindowDocked( ctx ) then UI.calc_rackY = DATA.display_y + UI.spacingY end
        if EXT.UI_drracklayout == 2  then rack_max_width = 600 end --launch
        UI.calc_rackW = math.min(DATA.display_w - UI.calc_settingsW - UI.calc_padoverviewW,rack_max_width)
        UI.calc_rackH = math.max(math.floor(DATA.display_h  -UI.spacingY )-1,rack_min_height)
        
        UI.calc_rack_padw = math.floor((UI.calc_rackW-UI.spacingX*3) / 4)
        UI.calc_rack_padh = math.floor((UI.calc_rackH-UI.spacingY*3) / 4)
        if EXT.UI_drracklayout == 1 then --keys
          UI.calc_rack_padw = math.floor((UI.calc_rackW) / 7)-- -UI.spacingX
          UI.calc_rack_padh = math.floor((UI.calc_rackH) / 4)
        end
        UI.calc_rack_padctrlW = UI.calc_rack_padw / 3 
        UI.calc_rack_padctrlH = UI.calc_rack_padh*0.3
        UI.calc_rack_padnameH = UI.calc_rack_padh-UI.calc_rack_padctrlH 
        
        
        if EXT.UI_drracklayout == 2 then
          local ID = EXT.UI_drracklayout_customID
          if DATA.custom_layouts[ID] then
            local cell_cnt_max = DATA.custom_layouts[ID].cell_cnt_max
            local col_cnt = DATA.custom_layouts[ID].col_cnt
            local row_cnt = DATA.custom_layouts[ID].row_cnt   
            if col_cnt * row_cnt>cell_cnt_max then row_cnt = math.ceil(cell_cnt_max / col_cnt) end
            
            local rackx = UI.calc_rackX
            local racky = UI.calc_rackY
            UI.calc_rack_padw = (UI.calc_rackW-UI.spacingX) / col_cnt
            UI.calc_rack_padh = (UI.calc_rackH-UI.spacingY) / row_cnt
            UI.calc_rack_padctrlH = UI.calc_rack_padh*0.3
            UI.calc_rack_padnameH = UI.calc_rack_padh-UI.calc_rack_padctrlH 
            if UI.calc_rack_padctrlH < 30 then
              UI.calc_rack_padctrlH = 0
              UI.calc_rack_padnameH = UI.calc_rack_padh
            end
            UI.calc_rack_padctrlW = UI.calc_rack_padw / 3 
          end
        end
        
        
        
        
        -- settings
        UI.calc_settingsX = UI.calc_rackW + UI.calc_padoverviewW + UI.spacingX*2
        UI.calc_settingsY = UI.spacingY*2 + UI.calc_itemH
        
        -- small knob controls
        UI.calc_knob_w_small = math.floor((UI.calc_settingsW - UI.spacingX*9) / 8) 
        UI.calc_knob_h_small = 90--math.floor((DATA.display_h  - UI.calc_itemH*3-UI.spacingY*7 - UI.sampler_peaksH)/2)
        -- small macro controls
        UI.calc_macro_w = math.floor((UI.calc_settingsW - UI.spacingX*7) / 4)
        UI.calc_macro_h = 65--math.floor((DATA.display_h - UI.spacingY*4 - UI.calc_itemH*3) / 4)
        
        -- sampler 
        UI.calc_sampler4ctrl_W = math.floor((UI.calc_settingsW - UI.spacingX*5) / 4) 
         
        
        
        -- get drawlist
        UI.draw_list = ImGui.GetWindowDrawList( ctx )
        
        
        -- draw stuff
        DATA.allow_space_to_play = true
        UI.draw() 
        UI.draw_popups()  
        ImGui.Dummy(ctx,0,0)  
        if EXT.UI_allowshortcuts==1 then
          if DATA.allow_space_to_play == true then if ImGui.IsKeyPressed(ctx, ImGui.Key_Space) then if GetPlayState()&1==1 then CSurf_OnStop() else CSurf_OnPlay() end end end
        end
        
        
        
        if DATA.parent_track and DATA.parent_track.valid == true and UI.hide_tabs ~= true  then
          ImGui.SetCursorPos(ctx,UI.calc_settingsX,UI.spacingY)
          ImGui.BeginDisabled(ctx, true) ImGui.Text(ctx, DATA.UI_name_vrs)ImGui.EndDisabled(ctx)
          ImGui.SameLine(ctx)
          ImGui.Dummy(ctx,5,0)
          ImGui.SameLine(ctx)
          ImGui.Text(ctx, DATA.titlename_reduced)
          if EXT.UI_showcurrentdbmap == 1 then 
            local map_name = EXT.UIdatabase_maps_current
            if DATA.database_maps and DATA.database_maps[map_name] and DATA.database_maps[map_name].dbname then 
              map_name = DATA.database_maps[map_name].dbname
            end
            ImGui.SameLine(ctx)
            ImGui.Text(ctx, '/ db map: '..map_name)
          end
        end
        
        ImGui.End(ctx)
      end 
     
     
     if DATA.trig_stopdefer2 ~=true then
       
       local rv,open = ImGui.Begin(ctx, 'StepSequencer', open, window_flags) --
       if rv and open then
         local Viewport = ImGui.GetWindowViewport(ctx)
         DATA.display_x, DATA.display_y = ImGui.Viewport_GetPos(Viewport) 
         DATA.display_w, DATA.display_h = ImGui.Viewport_GetSize(Viewport) 
         DATA.display_x_work, DATA.display_y_work = ImGui.Viewport_GetWorkPos(Viewport)
         -- hidingwindgets
         DATA.display_whratio = DATA.display_w / DATA.display_h
         UI.hide_padoverview = false
         UI.hide_tabs = false 
         if DATA.display_whratio < 1.7 then UI.hide_padoverview = true end
         if DATA.display_w < UI.settingsfixedW * 1.8 then UI.hide_tabs = true end
         --if DATA.display_w > UI.settingsfixedW * 5 then UI.hide_tabs = true end
         
         -- calc stuff for childs
         UI.calc_xoffset,UI.calc_yoffset = ImGui.GetStyleVar(ctx, ImGui.StyleVar_WindowPadding)
         local framew,frameh = ImGui.GetStyleVar(ctx, ImGui.StyleVar_FramePadding)
         local calcitemw, calcitemh = ImGui.CalcTextSize(ctx, 'test')
         UI.calc_itemH = calcitemh + frameh * 2
         
         
         
         
         
          
          -- seq
         UI.calc_seqX = DATA.display_x + UI.spacingX
         UI.calc_seqY = DATA.display_y + UI.calc_itemH + UI.spacingY*2
         UI.calc_seqW = DATA.display_w
         
         if UI.hide_padoverview == true then  UI.calc_seqW = UI.calc_rackW end 
         UI.calc_seq_ctrl_butW = math.floor(UI.seq_padH*0.7)
         UI.calc_seq_ctrl_butH = UI.calc_seq_ctrl_butW  
         UI.calc_seqXL_padname = (UI.calc_seq_ctrl_butW + UI.spacingX)*5
         UI.calc_seqXL_steps = UI.calc_seqXL_padname +UI.seq_padnameW  + UI.seq_audiolevelW + UI.spacingX 
         UI.calc_seqW_steps = DATA.display_w - UI.calc_seqXL_steps
         
         UI.calc_seqW_steps_window = UI.seq_stepW*16
         UI.calc_seqW_steps_visible = math.floor(UI.calc_seqW_steps/UI.seq_stepW)
         
         -- peaks patch (otherwise it will not draw peaks)
         UI.calc_rack_padw = UI.seq_padnameW
         
         -- get drawlist
         UI.draw_list = ImGui.GetWindowDrawList( ctx )
         
         
         -- draw stuff
         DATA.allow_space_to_play = true
         UI.seqdraw() 
         UI.draw_popups()  
         ImGui.Dummy(ctx,0,0)  
         if EXT.UI_allowshortcuts==1 then
           if DATA.allow_space_to_play == true then if ImGui.IsKeyPressed(ctx, ImGui.Key_Space) then 
             --if DATA.mainstate_manager ~= true and DATA.mainstate_seq == true then
               if GetPlayState()&1==1 then CSurf_OnStop() else CSurf_OnPlay() end end 
             --end
           end
         end
         
         ImGui.End(ctx)
       end 
     end
     
     
    -- pop
      ImGui.PopStyleVar(ctx, 22) 
      ImGui.PopStyleColor(ctx, 25) 
      ImGui.PopFont( ctx ) 
    
    -- shortcuts
      
      if UI.anypopupopen == true then 
        if ImGui.IsKeyPressed( ctx, ImGui.Key_Escape,false ) then DATA.trig_closepopup = true end 
       else 
        if ImGui.IsKeyPressed( ctx, ImGui.Key_Escape,false ) then return end
      end
      
        
    return open
  end
  
  
  --------------------------------------------------------------------------------  
  function UI.draw_Seq_Step(note_t, x0,y0)  
    if not note_t then return end 
    
    local note= note_t.noteID 
    if not (DATA.seq and DATA.seq.ext and DATA.seq.ext.children and DATA.seq.ext.children[note] and DATA.seq.ext.children[note].step_cnt) then return end
    
    
    if not DATA.seq.ext.patternlen then return end
    
    function __f_draw_Seq_Step() end
    ImGui.SetCursorPosX(ctx, UI.calc_seqXL_steps)
    if x0 and y0 then ImGui.SetCursorPos(ctx, x0,y0) end
    
    -- loop steps
    local col_activestep = 0xE0E0E000
    local col_cell_1 = 0x5050508F
    local col_cell_2 = (EXT.UI_colRGBA_maintheme_color&0xFFFFFF00)|0x50
    local col_cell_inactive = 0x5050503F
    local col_step_1 = (col_activestep&0xFFFFFF00)|0x90
    local col_step_2 = (EXT.UI_colRGBA_maintheme_color&0xFFFFFF00)|0x9F
    
    local col_step_inactive = (col_activestep&0xFFFFFF00)|0x30
    local col_separator = 0x808080FF
    local col_playcursor = (EXT.UI_colRGBA_maintheme_color&0xFFFFFF00)|0xFF
    
    local step_cnt = DATA.seq.ext.children[note].step_cnt
    if step_cnt == -1 then step_cnt = DATA.seq.ext.patternlen end
    for activestep = DATA.seq.stepoffs+1, DATA.seq.ext.patternlen do
      -- colors/state
        local col_cell = col_cell_1
        if (activestep-1)%8> 3 then col_cell = col_cell_2 end
        if activestep > step_cnt then col_cell = col_cell_inactive end
        
      -- body cells
        ImGui.PushStyleColor(ctx, ImGui.Col_Button, 0)
        ImGui.PushStyleVar(ctx, ImGui.StyleVar_FrameRounding,UI.seq_steprounding) 
        ImGui.Button(ctx, '##stepseq'..note..'step'..activestep, UI.seq_stepW,UI.seq_padH)  
        ImGui.PopStyleColor(ctx)
        ImGui.PopStyleVar(ctx) 
        x1, y1 = reaper.ImGui_GetItemRectMin( ctx )
        x2, y2 = reaper.ImGui_GetItemRectMax( ctx ) 
        ImGui.DrawList_AddRectFilled( UI.draw_list, x1, y1,x2-1, y2-1, col_cell, UI.seq_steprounding, ImGui.DrawFlags_None )
      
      -- separator
        if activestep%16==1 then
          ImGui.DrawList_AddLine( UI.draw_list, x1, y1+1,x1, y2-2, col_separator, 1 )
        end
        
      -- fill step 
        local hstep = (y2-y1)-UI.seq_activestep_reducesz*4
        local wstep = (x2-x1)-UI.seq_activestep_reducesz*4
        if DATA.seq.ext and DATA.seq.ext.children and DATA.seq.ext.children[note] and DATA.seq.ext.children[note].steps then
          local activestep_fill = activestep
          if activestep > step_cnt then activestep_fill = 1+(activestep-1)%step_cnt end
          local col_step = col_step_1
          if (activestep-1)%8> 3 then col_step = col_step_2 end
          if activestep > step_cnt then col_step = col_step_inactive end 
          
          if DATA.seq.ext.children[note].steps[activestep_fill] and DATA.seq.ext.children[note].steps[activestep_fill].val and DATA.seq.ext.children[note].steps[activestep_fill].val > 0 then
            local val = DATA.seq.ext.children[note].steps[activestep_fill].val
            local velocity = DATA.seq.ext.children[note].steps[activestep_fill].velocity
            if velocity then val = velocity end
            local width = 1
            if DATA.seq.ext.children[note].steps[activestep_fill].steplen_override then width = math.max(0.2,DATA.seq.ext.children[note].steps[activestep_fill].steplen_override) end
            
            ImGui.DrawList_AddRectFilled( UI.draw_list, 
              x1+UI.seq_activestep_reducesz*2,
              y1+UI.seq_activestep_reducesz*2 + hstep-hstep*val,
              x1+UI.seq_activestep_reducesz*2 + wstep*width,
              y2-UI.seq_activestep_reducesz*2, 
              col_step, UI.seq_steprounding, ImGui.DrawFlags_None )
          end
        end  
        
      -- split val
        if activestep <= step_cnt and DATA.seq.ext and DATA.seq.ext.children and DATA.seq.ext.children[note] and DATA.seq.ext.children[note].steps and DATA.seq.ext.children[note].steps[activestep] and DATA.seq.ext.children[note].steps[activestep].split then
          local split = math_q(DATA.seq.ext.children[note].steps[activestep].split)
          if split ~=1 then
            ImGui.DrawList_AddText( UI.draw_list, x1+UI.seq_activestep_reducesz, y1+UI.seq_activestep_reducesz, 0xFFFFFFFF, split )
          end
        end
  
      -- offset val
        if activestep <= step_cnt and DATA.seq.ext and DATA.seq.ext.children and DATA.seq.ext.children[note] and DATA.seq.ext.children[note].steps and DATA.seq.ext.children[note].steps[activestep] and DATA.seq.ext.children[note].steps[activestep].offset and DATA.seq.ext.children[note].steps[activestep].offset~=0 then
          local offset = DATA.seq.ext.children[note].steps[activestep].offset
          local fullwstep = (x2-x1)-UI.seq_activestep_reducesz*4
          local xpos = x1 + UI.seq_activestep_reducesz*2 + fullwstep/2+ offset * fullwstep/2
          ImGui.DrawList_AddLine( UI.draw_list, 
            xpos,
            y2-UI.seq_activestep_reducesz*2-1,
            xpos,
            y2-UI.seq_activestep_reducesz*2-5, 
            0xFFFFFFDF,2 )
        end
        
      -- play cursor
        if DATA.seq.active_step and DATA.seq.active_step[note] and DATA.seq.active_step[note] == activestep then
          midx = x1 + (x2-x1)/2 
          midy = y1 + UI.seq_padH/2 
          ImGui.DrawList_AddCircleFilled( UI.draw_list, midx, midy, 4, col_playcursor, 0 )
        end        
        
      -- handle mouse
        local trig_change
        if activestep <= step_cnt then
          if ImGui.IsItemHovered( ctx, ImGui.HoveredFlags_AllowWhenBlockedByPopup ) and ImGui.IsMouseClicked( ctx, ImGui.MouseButton_Left, 0 ) then 
            trig_change = 1
           elseif ImGui.IsItemHovered( ctx, ImGui.HoveredFlags_AllowWhenBlockedByPopup ) and ImGui.IsMouseClicked( ctx, ImGui.MouseButton_Right, 0 ) then
            trig_change = 0
          end
          
          if trig_change then 
            if not DATA.seq.ext.children[note].steps then DATA.seq.ext.children[note].steps = {} end
            if not DATA.seq.ext.children[note].steps[activestep] then DATA.seq.ext.children[note].steps[activestep] = {} end
            
            DATA.seq.ext.children[note].steps[activestep].val = trig_change
            
            local mx, my = reaper.ImGui_GetMousePos( ctx )
            DATA.temp_holdmode_mx=mx
            DATA.temp_holdmode_my=my
            DATA.temp_holdmode_note=note
            DATA.temp_holdmode_value = trig_change
            DATA.temp_holdmode = note 
            DATA.temp_holdmode_stepline = math.floor((activestep-1)/16)
            DATA.temp_holdmode_step = activestep
            if DATA.parent_track.ext.PARENT_LASTACTIVENOTE~=note then 
              DATA.parent_track.ext.PARENT_LASTACTIVENOTE=note
              gmem_write(1025,10 ) -- push a trigger to refresh Rack
              DATA:WriteData_Parent() 
            end
          end     
          
        end
        
        
      ImGui.SameLine(ctx)
      --ImGui.Dummy(ctx,UI.spacingY,0)
    end
    
    
    -- handle mouse over sequencer
    UI.draw_Seq_Step_handlemouse()
    ImGui.SameLine(ctx)
  end
  
  --------------------------------------------------------------------------------  
  function UI.draw_Seq_Step_handlemouse()   
    if not (DATA.temp_holdmode_value and DATA.temp_holdmode and DATA.temp_holdmode_stepline and DATA.temp_holdmode_step ) then return end
    
    if ImGui.IsMouseReleased(ctx, ImGui.MouseButton_Left) or ImGui.IsMouseReleased(ctx, ImGui.MouseButton_Right) then 
      DATA.temp_holdmode_value =nil
      DATA.temp_holdmode =nil
      DATA.temp_holdmode_stepline = nil
      DATA.temp_holdmode_step = nil
      --DATA:_Seq_Print()
      DATA.upd2.seqprint = true
      --DATA.upd = true
      if DATA.parent_track.ext.PARENT_LASTACTIVENOTE~=DATA.temp_holdmode_note then 
        DATA.parent_track.ext.PARENT_LASTACTIVENOTE=DATA.temp_holdmode_note
        DATA:WriteData_Parent() 
      end
      return
    end
    
    local dx, dy = reaper.ImGui_GetMouseDelta( ctx )
    if dx == 0 then return end
    
    local active_note = DATA.temp_holdmode 
    local xsteps = UI.calc_seqX + UI.calc_seqXL_steps
    local mx, my = reaper.ImGui_GetMousePos( ctx )
    --[[local v = (mx-xsteps) /(UI.calc_seqW_steps_window)
    local normval = math.floor(16 * v) + 1
    local step2 = VF_lim(normval,1,16)]]
    local dx = mx - DATA.temp_holdmode_mx
    local step1 = DATA.temp_holdmode_step
    local step2 = math_q(step1 + dx/UI.seq_stepW)
    --[[msg('=')
    msg(dx)
    msg(step1)
    msg(step2)]]
    local s1,s2 = step1, step2
    if step2<step1 then s1,s2 = step2, step1 end
    
    local step_cnt = DATA.seq.ext.children[active_note].step_cnt
    if step_cnt == -1 then step_cnt = DATA.seq.ext.patternlen end
    s2=math.min(s2, step_cnt)
    
    if not DATA.seq.ext.children[active_note] then DATA.seq.ext.children[active_note] = {} end
    if not DATA.seq.ext.children[active_note].steps then DATA.seq.ext.children[active_note].steps = {} end 
    for step = s1,s2 do
      local out = DATA.temp_holdmode_value
      if not DATA.seq.ext.children[active_note].steps[step] then DATA.seq.ext.children[active_note].steps[step] = {} end
      
      -- set step to 0 remove data -DO NOT USE
      --[[if out == 0 and DATA.seq.ext.children[active_note].steps[step] then 
        DATA.seq.ext.children[active_note].steps[step] = nil 
       elseif not (DATA.seq.ext.children[active_note].steps[step].val and DATA.seq.ext.children[active_note].steps[step].val == out)  then  
        DATA.seq.ext.children[active_note].steps[step].val = out 
        local minor_change = true
        DATA.upd2.seqprint = true
        DATA.upd2.seqprint_minor = true
      end]]
      
      
      if not (DATA.seq.ext.children[active_note].steps[step].val and DATA.seq.ext.children[active_note].steps[step].val == out)  then  
        DATA.seq.ext.children[active_note].steps[step].val = out 
        local minor_change = true
        --DATA:_Seq_Print(nil, minor_change)
        DATA.upd2.seqprint = true
        DATA.upd2.seqprint_minor = minor_change
      end
      
    end 
    
    
  end  
    -------------------------------------------------------------------------------- 
  function UI.draw_Seq()   
    
    local mdx, mdy = reaper.ImGui_GetMouseDelta( ctx )
    if mdx ~= 0 and mdy ~=0 then DATA.temp_ismousewheelcontrol_hovered = nil end -- reset on move
    
    local ctrls_w = 100
    -- startup
      if not (DATA.parent_track and DATA.parent_track.valid == true and DATA.seq and DATA.seq.valid == true and DATA.seq.tk_ptr ) then
        UI.draw_Seq_startup() 
        return
      end
  
      
    -- UI name
      ImGui.SameLine(ctx)
      ImGui.BeginDisabled(ctx, true) ImGui.Text(ctx, DATA.UI_name_vrs)ImGui.EndDisabled(ctx)
  
    -- new
      if ImGui.Button(ctx, 'New') then 
        Undo_BeginBlock2(DATA.proj)
        DATA:_Seq_Insert() 
        Undo_EndBlock2(DATA.proj, 'Insert new pattern', 0xFFFFFFFF)
        DATA.upd = true
      end
      
      --[[if ImGui_IsItemClicked( ctx, reaper.ImGui_MouseButton_Right() ) then
        DATA:CollectData_Seq_ConvertMIDI2Steps() 
        DATA:_Seq_Print() 
      end]]
      
      if ImGui.IsItemClicked(ctx, ImGui.MouseButton_Right) then ImGui.OpenPopup( ctx, 'seq_new', ImGui.PopupFlags_None )  end
      ImGui.PushStyleVar(ctx, ImGui.StyleVar_PopupRounding,2)   
      if reaper.ImGui_BeginPopup(ctx,'seq_new') then
        local posx,posy = ImGui.GetCursorPos(ctx)
        if ImGui.Selectable(ctx, 'Import from existing MIDI take') then 
          DATA:CollectData_Seq_ConvertMIDI2Steps() 
          DATA:_Seq_Print() 
        end  
        reaper.ImGui_EndPopup(ctx)
      end
      ImGui.PopStyleVar(ctx)
      
      
      
    -- pattern rename
      ImGui.SameLine(ctx)
      ImGui.SetNextItemWidth(ctx, 150)
      local tkname = DATA.seq.tkname
      if tkname == '' then tkname = '[untitled pattern]' end
      local retval, buf = ImGui.InputText( ctx, '##tkname', tkname, reaper.ImGui_InputTextFlags_None() )
      if ImGui.IsItemActive(ctx) and DATA.allow_space_to_play == true then DATA.allow_space_to_play = false end
      if retval then 
        DATA.seq.tkname = buf
        GetSetMediaItemTakeInfo_String( DATA.seq.tk_ptr, 'P_NAME', DATA.seq.tkname, true )
      end
  
    
    -- patternlen 
      local patternlen = DATA.seq.ext.patternlen 
      ImGui.SameLine(ctx)  
      reaper.ImGui_SetCursorPosX(ctx,DATA.display_w-ctrls_w*2-UI.spacingX*3)
      ImGui.SetNextItemWidth(ctx, ctrls_w)
      --local retval, v = ImGui.SliderDouble  ( ctx, '##Swing_pat', DATA.seq.ext.swing, 0, 1, 'Swing '..math.floor(DATA.seq.ext.swing*100)..'%%', reaper.ImGui_SliderFlags_None() ) 
      local retval, v = ImGui.DragInt    ( ctx, '##patternlen', DATA.seq.ext.patternlen, 0.1, 1, UI.seq_maxstepcnt, 'Length '..DATA.seq.ext.patternlen, reaper.ImGui_SliderFlags_None() )
      if retval then DATA.seq.ext.patternlen = v DATA:_Seq_SetItLength_Beats(DATA.seq.ext.patternlen) end
      if reaper.ImGui_IsItemDeactivatedAfterEdit(ctx) then DATA:_Seq_Print() end 
      if ImGui.IsItemClicked(ctx, ImGui.MouseButton_Right) then ImGui.OpenPopup( ctx, 'patterlen', ImGui.PopupFlags_None )  end
      
      -- mousewheel
      local vertical, horizontal = ImGui.GetMouseWheel( ctx )
      local mousewheel = ImGui.IsItemHovered(ctx) and vertical ~= 0
      if mousewheel then mousewheel = math.abs(vertical)/vertical end 
      if mousewheel then
        if mousewheel > 0 then DATA.seq.ext.patternlen = VF_lim(DATA.seq.ext.patternlen * 2,1,UI.seq_maxstepcnt) else DATA.seq.ext.patternlen = VF_lim(math.floor(DATA.seq.ext.patternlen / 2),1,UI.seq_maxstepcnt) end
        DATA:_Seq_SetItLength_Beats(DATA.seq.ext.patternlen) 
        DATA:_Seq_Print()
        DATA.seq.valid=false
        DATA:CollectData_SeqFillEmptySteps() 
      end
      ImGui.SameLine(ctx) 
      ImGui.SetItemTooltip(ctx,'Pattern length')
      ImGui.PushStyleVar(ctx, ImGui.StyleVar_PopupRounding,2)   
      if reaper.ImGui_BeginPopup(ctx,'patterlen') then
        local posx,posy = ImGui.GetCursorPos(ctx)
        ImGui.SeparatorText(ctx,'Step count')
        local set
        if ImGui.Selectable(ctx, '16 steps', DATA.seq.ext.patternlen==16) then set = 16 end 
        if ImGui.Selectable(ctx, '32 steps', DATA.seq.ext.patternlen==32) then set = 32 end
        if ImGui.Selectable(ctx, '64 steps', DATA.seq.ext.patternlen==64) then set = 64 end 
        if ImGui.Selectable(ctx, '128 steps', DATA.seq.ext.patternlen==128) then set = 128 end
        if ImGui.Selectable(ctx, '1024 steps', DATA.seq.ext.patternlen==1024) then set = 1024 end
        ImGui.SeparatorText(ctx,'Options')
        if ImGui.Checkbox(ctx, 'Change children step count', EXT.CONF_seq_patlen_extendchildrenlen&1==1) then EXT.CONF_seq_patlen_extendchildrenlen=EXT.CONF_seq_patlen_extendchildrenlen~1 EXT:save()end  
        if set then
          DATA.seq.ext.patternlen = set
          DATA:_Seq_SetItLength_Beats(DATA.seq.ext.patternlen)
          DATA:_Seq_Print() 
          DATA.seq.valid=false
          reaper.ImGui_CloseCurrentPopup(ctx)
        end
        ImGui.SeparatorText(ctx,'Actions')
        if ImGui.Selectable(ctx, 'Print to full pattern length', nil, reaper.ImGui_SelectableFlags_None(), 180) then 
          DATA:_Seq_FillNoteStepsToFullLength(note) 
        end  
        
        ImGui.Dummy(ctx,0,UI.spacingY)
        reaper.ImGui_EndPopup(ctx)
      end
      ImGui.PopStyleVar(ctx)
      
      
      
    
    -- swing
    ImGui.SameLine(ctx) 
    ImGui.SetNextItemWidth(ctx, ctrls_w)
    --local retval, v = ImGui.SliderDouble  ( ctx, '##Swing_pat', DATA.seq.ext.swing, 0, 1, 'Swing '..math.floor(DATA.seq.ext.swing*100)..'%%', reaper.ImGui_SliderFlags_None() ) 
    local retval, v = ImGui.DragDouble    ( ctx, '##Swing_pat', DATA.seq.ext.swing, 0.001, 0, 1, 'Swing '..math.floor(DATA.seq.ext.swing*100)..'%%', reaper.ImGui_SliderFlags_None() ) 
    if retval then DATA.seq.ext.swing = v end if reaper.ImGui_IsItemDeactivatedAfterEdit(ctx) then DATA:_Seq_Print() end
    
    ImGui.SetCursorPosX(ctx,UI.calc_seqXL_padname+UI.spacingX*3 + UI.seq_padnameW)
     
    
    
    -- draw main stuff
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowPadding,0,0)  
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_ItemSpacing,0,0) 
    local xoffs_abs = UI.calc_seqX
    local yoffs_abs = UI.calc_seqY+UI.calc_itemH+UI.spacingY
    
    
    ImGui.SetCursorScreenPos(ctx,xoffs_abs,yoffs_abs)  
    
    local xL,yL = ImGui.GetCursorPos(ctx)
    local xA,yA = ImGui.GetCursorScreenPos(ctx)
    UI.draw_Seq_StepProgress(xL,yL, xA+UI.calc_seqXL_steps,yA) 
    
    local flagscroll = 0
    if UI.anypopupopen == true or DATA.temp_ismousewheelcontrol_hovered == true then flagscroll = ImGui.WindowFlags_NoScrollWithMouse end
    if ImGui.BeginChild( ctx, 'seq', 0, -UI.spacingY-UI.scrollbarsz, ImGui.ChildFlags_None|ImGui.ChildFlags_Border, ImGui.WindowFlags_None|flagscroll ) then-- --|ImGui.WindowFlags_MenuBar |ImGui.ChildFlags_Border  ---UI.calc_itemH - 
      
      ImGui.Dummy(ctx,0,UI.spacingY)
      
      -- ascending order
      local note_start = 127
      local note_end = 0
      local incr = -1
      if EXT.CONF_seq_instrumentsorder == 1 then
        note_start = 0
        note_end = 127
        incr = 1
      end
      
      -- loop notes
      for note = note_start,note_end,incr  do
        if DATA.children[note] then 
          if ImGui.BeginChild( ctx, 'seqchildnote'..note, 0, 0,ImGui.ChildFlags_None|ImGui.ChildFlags_AutoResizeY) then   --|ImGui.ChildFlags_Border 
            local y_local = ImGui.GetCursorPosY(ctx)
            UI.draw_Seq_ctrls(DATA.children[note]) 
            ImGui.SetCursorPosY(ctx, y_local)
            UI.draw_Seq_Step(DATA.children[note])
            ImGui.EndChild( ctx)
          end
        end
      end
      
      -- handle refresh after drop @ UI.Drop_UI_interaction_pad(note) 
      if DATA.upd2.refreshscroll then  
        if DATA.upd2.refreshscroll == 1 then 
          DATA.upd2.refreshscroll = DATA.upd2.refreshscroll + 1 -- forward next frame
         elseif DATA.upd2.refreshscroll == 2 then 
          if EXT.CONF_seq_instrumentsorder == 0 then
            ImGui.SetScrollY( ctx, 0) 
           else
            ImGui.SetScrollY( ctx, ImGui.GetScrollMaxY( ctx )+4000) 
          end
          DATA.upd2.refreshscroll = nil 
        end 
      end
      
      -- seq_init_Yscroll
      if DATA.seq_init_Yscroll == 0 then
        DATA.seq_init_Yscroll  = DATA.seq_init_Yscroll  + 1 -- forward next frame
       elseif DATA.seq_init_Yscroll == 1 then
        if EXT.CONF_seq_instrumentsorder == 0 then ImGui.SetScrollY( ctx, ImGui.GetScrollMaxY( ctx )+4000)  end
        DATA.seq_init_Yscroll = 2
      end
      
      
      ImGui.EndChild( ctx)
    end
    
    if ImGui.BeginDragDropTarget( ctx ) then  
      UI.Drop_UI_interaction_pad(-1) 
      ImGui_EndDragDropTarget( ctx )
    end
    
      
    ImGui.PopStyleVar(ctx,2)
    ImGui.Dummy(ctx,0,0)
    
    
    UI.draw_Seq_horizscroll(true) 
    
    
    -- draw Rack button
      local manageravailable
      if DATA.manager_ID then manageravailable = true end
      local xoffs = 200
      local yoffs = 4
      local wbut = 100
      ImGui.SetCursorPos(ctx,xoffs,yoffs)
      if ImGui.InvisibleButton(ctx, 'mode', wbut, 20) then 
        if manageravailable == true then Main_OnCommand(DATA.manager_ID,0) end 
      end
      x1, y1 = reaper.ImGui_GetItemRectMin( ctx )
      x2, y2 = reaper.ImGui_GetItemRectMax( ctx )
      local checkbox_h = 16
      local checkbox_r = math.floor(checkbox_h / 2)
      local center_x = x1
      local center_y = math.floor(y1 + (y2-y1)/2 )-1
      local colfill = 0xF0F0F04F
      if manageravailable == true and ImGui_IsItemHovered(ctx) then colfill = 0xF0F0F09F end
      ImGui.DrawList_AddCircle( UI.draw_list, center_x, center_y, checkbox_r, 0xF0F0F07F, 0, 2 )
      ImGui.DrawList_AddCircleFilled( UI.draw_list, center_x, center_y, checkbox_r-3, colfill, 0 ) 
      ImGui.SetCursorPos(ctx,xoffs+checkbox_r+ UI.spacingX,yoffs+1)
      if manageravailable == true then ImGui.Text(ctx, 'Rack') else ImGui.TextDisabled(ctx, 'Rack') end
      
  end  
  
    --------------------------------------------------------------------------------  
    function UI.draw_Seq_ctrls(note_t)
      
      --function __f_draw_Seq_ctrls() end
      local note= note_t.noteID
      if not (DATA.seq and DATA.seq.ext and DATA.seq.ext.children and DATA.seq.ext.children[note] and DATA.seq.ext.children[note].step_cnt) then return end
      ImGui.PushStyleVar(ctx, ImGui.StyleVar_FramePadding,1,1) 
      ImGui.PushStyleVar(ctx, ImGui.StyleVar_CellPadding,1, 1) 
      ImGui.PushStyleVar(ctx, ImGui.StyleVar_ItemSpacing,UI.spacingX, 1)
      ImGui.PushStyleVar(ctx, ImGui.StyleVar_ButtonTextAlign,0.5,0.5)
      ImGui.PushFont(ctx, DATA.font4) 
      
      -- mute
        local ismute = note_t and note_t.B_MUTE and note_t.B_MUTE == 1
        if ismute==true then ImGui.PushStyleColor(ctx, ImGui.Col_Text, 0xFF0F0FF0 ) end
        if note_t and ImGui.Button(ctx,'M##rackpad_mute'..note,UI.calc_seq_ctrl_butW,UI.seq_padH-1 ) then SetMediaTrackInfo_Value( note_t.tr_ptr, 'B_MUTE', note_t.B_MUTE~1 ) DATA.upd = true end  --UI.calc_seq_ctrl_butH
        if ismute==true then ImGui.PopStyleColor(ctx) end
        ImGui.SameLine(ctx)
        
      -- solo
        local issolo = note_t and note_t.I_SOLO and note_t.I_SOLO > 0 
        if issolo == true then ImGui.PushStyleColor(ctx, ImGui.Col_Text, 0x00FF0FF0 ) end
        if note_t and ImGui.Button(ctx,'S##rackpad_solo'..note,UI.calc_seq_ctrl_butW,UI.seq_padH-1 ) then
          if note_t and note_t.tr_ptr then 
            local outval = 2 if note_t.I_SOLO>0 then outval = 0 end SetMediaTrackInfo_Value( note_t.tr_ptr, 'I_SOLO', outval ) DATA.upd = true
          end 
        end   
        if issolo == true then ImGui.PopStyleColor(ctx) end
        ImGui.SameLine(ctx)
        
        
      -- step_cnt
        local xabsstepcnt, yabsstepcnt = reaper.ImGui_GetCursorScreenPos(ctx)
        local step_cnt = DATA.seq.ext.children[note].step_cnt
        if step_cnt == -1 then step_cnt = DATA.seq.ext.patternlen end
        local floor = true
        local default = -1
        local retval, v, deact,rightclick,mousewheel = UI.VDragInt( ctx, '##step_cnt'..note, UI.calc_seq_ctrl_butW, UI.seq_padH-1, step_cnt, 1, DATA.seq.ext.patternlen,  step_cnt, ImGui.SliderFlags_None, floor, default)
        if retval and DATA.seq.ext.children[note].step_cnt ~= v then
          DATA.seq.ext.children[note].step_cnt = v
        end
        if deact==true then DATA:_Seq_Print() end
        if rightclick == true then ImGui.OpenPopup( ctx, 'step_cnt'..note, ImGui.PopupFlags_None )  end
        if mousewheel then
          if mousewheel > 0 then DATA.seq.ext.children[note].step_cnt = VF_lim(step_cnt * 2,1,DATA.seq.ext.patternlen) else DATA.seq.ext.children[note].step_cnt = VF_lim(math.floor(step_cnt / 2),1,DATA.seq.ext.patternlen) end
          DATA:_Seq_Print()
        end
        ImGui.SameLine(ctx) 
        ImGui.SetItemTooltip(ctx,'Step count')
        ImGui.PushStyleVar(ctx, ImGui.StyleVar_PopupRounding,2)   
        ImGui.PushFont(ctx, DATA.font1) 
        if reaper.ImGui_BeginPopup(ctx,'step_cnt'..note) then
          local posx,posy = ImGui.GetCursorPos(ctx)
          local set
          ImGui.Indent(ctx,10)
          ImGui.SeparatorText(ctx,'Step count')
          local num = {-1,4,8,16,24,32,64,128}
          for i = 1, #num do
            local setnum = num[i]
            local str = setnum..' steps'
            if setnum == -1 then str = 'Follow pattern length' end
            if DATA.seq.ext.patternlen >=setnum or setnum == -1 then
              if ImGui.Selectable(ctx, str, setnum == DATA.seq.ext.children[note].step_cnt, reaper.ImGui_SelectableFlags_None(), 150) then set = setnum end 
            end
          end
          if set then
            DATA.seq.ext.children[note].step_cnt = set
            DATA:_Seq_Print()
            reaper.ImGui_CloseCurrentPopup(ctx)
          end
          
          ImGui.SeparatorText(ctx,'Actions')
          local allow_print_to_full = DATA.seq.ext.children[note].step_cnt ~= -1 and DATA.seq.ext.children[note].step_cnt < DATA.seq.ext.patternlen 
          if allow_print_to_full~=true then ImGui.BeginDisabled(ctx, true)  end
            if ImGui.Selectable(ctx, 'Print to full pattern length', nil, reaper.ImGui_SelectableFlags_None(), 150) then DATA:_Seq_FillNoteStepsToFullLength(note) end  
          if allow_print_to_full~=true then ImGui.EndDisabled(ctx)  end
          
          
          ImGui.Unindent(ctx,10)
          ImGui.Dummy(ctx,0,UI.spacingY)
          reaper.ImGui_EndPopup(ctx)
        end
        ImGui.PopFont(ctx) 
        ImGui.PopStyleVar(ctx)      
        
        
      -- step_cnt step_len LED
        if DATA.seq.ext.children[note].steplength~=0.25 then
          local tri_sz =5
          ImGui_DrawList_AddTriangleFilled( UI.draw_list, xabsstepcnt-tri_sz+UI.calc_seq_ctrl_butW, yabsstepcnt, xabsstepcnt+UI.calc_seq_ctrl_butW, yabsstepcnt, xabsstepcnt+UI.calc_seq_ctrl_butW, yabsstepcnt+tri_sz, 0x00FF00FF )
        end   
  
        -- track vol
        local note_layer_t = DATA.children[note]
        if not (DATA.children[note].TYPE_DEVICE and DATA.children[note].TYPE_DEVICE == true) then 
          if DATA.children[note].layers and DATA.children[note].layers[1] then note_layer_t = DATA.children[note].layers[1] end
        end
        if note_layer_t and note_layer_t.D_VOL then 
          local curposx_abs, curposy_abs = reaper.ImGui_GetCursorScreenPos(ctx)
          UI.draw_knob(
            {str_id = '##spl_trvol'..note,
            is_micro_knob = true,
            val = math.min(1,note_layer_t.D_VOL/2), 
            default_val = 0.5,
            x = curposx_abs, 
            y = curposy_abs,
            w = UI.calc_seq_ctrl_butW,
            h = UI.seq_padH-1,
            name = 'Volume',
            val_form = note_layer_t.D_VOL_format,
            appfunc_atclick = function(v)   end,
            appfunc_atdrag = function(v)  
              note_layer_t.D_VOL =v *2
              SetMediaTrackInfo_Value( note_layer_t.tr_ptr, 'D_VOL', v *2 )
            end,
            })
          ImGui.SameLine(ctx)
          local curposx_abs, curposy_abs = reaper.ImGui_GetCursorScreenPos(ctx)
          UI.draw_knob(
            {str_id = '##spl_trpan'..note,
            is_micro_knob = true,
            centered = true,
            val = note_layer_t.D_PAN, 
            val_max = 1, 
            val_min = -1, 
            default_val = 0,
            x = curposx_abs, 
            y = curposy_abs,
            w = UI.calc_seq_ctrl_butW,
            h = UI.seq_padH-1,
            name = 'Volume',
            val_form = note_layer_t.D_PAN_format,
            appfunc_atclick = function(v)   end,
            appfunc_atdrag = function(v)  
              note_layer_t.D_PAN =v
              SetMediaTrackInfo_Value( note_layer_t.tr_ptr, 'D_PAN', v )
            end,
            })          
        end
        ImGui.SameLine(ctx)
        
        
        
      -- name  
        -- define txt
          local note_format = VF_Format_Note(note,note_t)
          if note_format then
            if EXT.UI_drracklayout == 2 then note_format = note_format..' ('..note..')' end
            if DATA.padcustomnames[note] and DATA.padcustomnames[note] ~= '' then note_format = DATA.padcustomnames[note] end
            if  DATA.parent_track.padcustomnames_overrides and DATA.parent_track.padcustomnames_overrides[note] and DATA.parent_track.padcustomnames_overrides[note] ~= '' then note_format = DATA.parent_track.padcustomnames_overrides[note] end
           else
            note_format = ''
          end
          
          
          --if DATA.padcustomnames[note] and DATA.padcustomnames[note] ~= '' then note_format = DATA.padcustomnames[note] end
          --if  DATA.parent_track.padcustomnames_overrides and DATA.parent_track.padcustomnames_overrides[note] and DATA.parent_track.padcustomnames_overrides[note] ~= '' then note_format = DATA.parent_track.padcustomnames_overrides[note] end
          
          
          local str_maxlen = 20
          if note_format:len()> str_maxlen then note_format = '...'..note_format:sub(-str_maxlen) end
        -- define color
          local color
          if note_t and note_t.I_CUSTOMCOLOR then 
            color = ImGui.ColorConvertNative(note_t.I_CUSTOMCOLOR) 
            color = color & 0x1000000 ~= 0 and (color << 8) | EXT.UI_col_tinttrackcoloralpha-- https://forum.cockos.com/showpost.php?p=2799017&postcount=6
          end 
          if not color then color = EXT.UI_colRGBA_paddefaultbackgr end
          -- if not color then color = EXT.UI_colRGBA_paddefaultbackgr end 
        
        ImGui.PushStyleColor(ctx, ImGui.Col_Button, color)
        local name_localx = reaper.ImGui_GetCursorPosX(ctx)
        
        -- fill name
        --local x1,y1= ImGui_GetCursorScreenPos(ctx)
        --ImGui.DrawList_AddRectFilled( UI.draw_list, x1,y1,x1 + UI.seq_padnameW,y1+UI.seq_padH-1, color or EXT.UI_colRGBA_paddefaultbackgr , 10, ImGui.DrawFlags_None )
        
        ImGui.Button(ctx,note_format..'##rackpad_name'..note,UI.seq_padnameW,UI.seq_padH-1 )
        local x1, y1 = reaper.ImGui_GetItemRectMin( ctx )
        local x2, y2 = reaper.ImGui_GetItemRectMax( ctx )
        if color then ImGui.PopStyleColor(ctx) end
         DATA.children[note].seq_yA={}
         DATA.children[note].seq_yA[0] = y1 -- print for note_seq_params popup
        if ImGui.IsItemClicked( ctx, ImGui.MouseButton_Right ) then 
          DATA.temp_stepline = 0
          gmem_write(1025,10 ) -- push a trigger to refresh Rack
          ImGui.OpenPopup( ctx, 'note_seq_params'..note, ImGui.PopupFlags_None ) 
        end
        
      -- LED database / defice
        if DATA.children[note] then
          local offs = 5
          local ledyspace = 2
          local sz = 4
          local ledx= x1+offs--sz
          local ledy= y1+offs 
          if DATA.children[note].SYSEXMOD == true then                      ImGui.DrawList_AddRectFilled( UI.draw_list, ledx, ledy, ledx+sz, ledy+sz, 0xF0FF50FF, 0, ImGui.DrawFlags_None) ledy=ledy+offs+ledyspace end
        end          
            
            
        UI.draw_Rack_Pads_controls_handlemouse(note_t,note, 'seq_pad')
        
      -- peaks 
        if  DATA.children[note] and DATA.children[note].layers and  DATA.children[note].layers[1] and  DATA.peakscache[note] and  DATA.peakscache[note].peaks_arr  then 
          local is_pad_peak = true
          local dim = true
          UI.draw_peaks('padseq'..note, note_t,  x1, y1, x2-x1, y2-y1,DATA.peakscache[note].peaks_arr, is_pad_peak, dim) 
        end
      -- selection 
        if (DATA.parent_track and DATA.parent_track.ext and DATA.parent_track.ext.PARENT_LASTACTIVENOTE and DATA.parent_track.ext.PARENT_LASTACTIVENOTE  == note) then 
          ImGui.DrawList_AddRect( UI.draw_list, x1, y1+1, x2, y2-1, (EXT.UI_colRGBA_maintheme_color&0xFFFFFF00)|0xF0, 2, ImGui.DrawFlags_None|ImGui.DrawFlags_RoundCornersAll, 1 )
        end  
      -- levels
        local peak_w = UI.seq_audiolevelW
        local xP = x1 + UI.seq_padnameW + 1
        local yP = y1+1
        local hP = y2-y1-3
        if DATA.children[note] and DATA.children[note].peaksRMS_L and (DATA.children[note].peaksRMS_L>0.001 or DATA.children[note].peaksRMS_R >0.001 )then
          local val = math.min((DATA.children[note].peaksRMS_L+DATA.children[note].peaksRMS_R)/2,1)
          ImGui.DrawList_AddRectFilled( UI.draw_list, xP, yP+hP - hP*val+1 , xP+peak_w, yP+hP, (EXT.UI_colRGBA_maintheme_color&0xFFFFFF00)|0xFF, 0, ImGui.DrawFlags_RoundCornersTop) 
          if val > 0.9 then ImGui.DrawList_AddLine( UI.draw_list, xP, yP+1 , xP+peak_w, yP+1, 0xFF0000FF, 1) end 
        end
        
        
      ImGui.PopStyleVar(ctx, 4) 
      ImGui.PopFont(ctx) 
      
      -- inline 
        UI.draw_Seq_ctrls_inline(note_t)    
      
        
      --ImGui.Dummy(ctx,0,UI.spacingY) 
      
    end
    
    --------------------------------------------------------------------------------  
    function UI.draw_Seq_ctrls_inline_handlemouse(note_t)
      local x1, y1 = reaper.ImGui_GetItemRectMin( ctx )
      local x2, y2 = reaper.ImGui_GetItemRectMax( ctx )
      
      local note = note_t.noteID
      local parameter, maxval, minval, default_val, parameter_parent = UI.draw_Seq_ctrls_inline_getactiveparam()
      
      
        --reaper.ImGui_CloseCurrentPopup(ctx)
      if ImGui.IsItemClicked(ctx, ImGui.MouseButton_Left) or ImGui.IsItemClicked(ctx, ImGui.MouseButton_Right) and not ImGui.IsKeyDown(ctx,ImGui.Mod_Alt) then
        local x, y = reaper.ImGui_GetMousePos( ctx )
        DATA.temp_seq_params =
          {x = x,--(x-x1) / (x2-x1),
           y = y,--(y-y1) / (y2-y1),
           }
      end
      
      if ImGui.IsItemClicked(ctx, ImGui.MouseButton_Left) and ImGui.IsKeyDown(ctx,ImGui.Mod_Alt) then 
        local x, y = reaper.ImGui_GetMousePos( ctx )
        local x_norm = VF_lim((x-x1) / (x2-x1)) 
        local active_step = math.ceil(x_norm * UI.calc_seqW_steps_visible + DATA.seq.stepoffs)
        
        if parameter:match('env_') then 
          DATA.seq.ext.children[note].steps[active_step][parameter] = nil
         else 
          DATA.seq.ext.children[note].steps[active_step][parameter] = default_val
        end
        
        DATA.seq.ext.children[note].steps[0][parameter] = 0
        DATA:_Seq_Print()
      end
      
      if (ImGui.IsMouseDown( ctx, ImGui.MouseButton_Left ) or ImGui.IsMouseDown( ctx, ImGui.MouseButton_Right )) 
        and DATA.temp_seq_params and not ImGui.IsKeyDown(ctx,ImGui.Mod_Alt)
        --and (ImGui.IsMouseDragging( ctx, ImGui.MouseButton_Left, 0 ) or ImGui.IsMouseDragging( ctx, ImGui.MouseButton_Right, 0 )) 
        then
        local dx, dy = reaper.ImGui_GetMouseDelta( ctx )
        if dx ~= 0 or dy~=0 then
          local x, y = reaper.ImGui_GetMousePos( ctx )
          --DATA.temp_seq_params.dx = DATA.temp_seq_params.x - x
          --DATA.temp_seq_params.dy = DATA.temp_seq_params.y - y 
          DATA.temp_seq_params.x1_norm = VF_lim((DATA.temp_seq_params.x-x1) / (x2-x1))
          DATA.temp_seq_params.x2_norm = VF_lim((x-x1) / (x2-x1))
          DATA.temp_seq_params.y1_norm = 1-VF_lim((DATA.temp_seq_params.y-y1) / (y2-y1))
          DATA.temp_seq_params.y2_norm = 1-VF_lim((y-y1) / (y2-y1)) 
          UI.draw_Seq_ctrls_inline_appstuff(note_t,ImGui.IsMouseDown( ctx, ImGui.MouseButton_Right )) 
          
        end
      end
      
      if ImGui.IsMouseReleased(ctx, ImGui.MouseButton_Left) or ImGui.IsMouseReleased(ctx, ImGui.MouseButton_Right) then 
        DATA:_Seq_Print()
        DATA.temp_seq_params = nil
      end
    end
    --------------------------------------------------------------------------------  
    function UI.draw_Seq_ctrls_inline_tools(note_t, posx,posy) 
      if not note_t then return end
      local note= note_t.noteID
      
      local butw = (UI.seq_padnameW-UI.spacingX*2)/3
      local butw_3x = UI.seq_padnameW
      local butw_15x = (UI.seq_padnameW-UI.spacingX)/2
      ImGui.PushFont(ctx,DATA.font3)
      
      -- fill ------------------------------------
      ImGui.SeparatorText(ctx, 'Fill')
      if ImGui.Button(ctx,'Fill each 2 steps', butw_3x) then DATA:_Seq_Fill(note, '10') DATA:_Seq_Print() end 
      if ImGui.Button(ctx,'Fill each 4 steps', butw_3x) then DATA:_Seq_Fill(note, '1000') DATA:_Seq_Print() end  
      if ImGui.Button(ctx,'Fill each 8 steps', butw_3x) then DATA:_Seq_Fill(note, '10000000') DATA:_Seq_Print() end 
      
      -- tools ------------------------------------
      ImGui.SeparatorText(ctx, 'Steps')
      
      -- shift
        UI.draw_setbuttonbackgtransparent()
        ImGui.Button(ctx, 'Shift',butw)
        UI.Tools_unsetbuttonstyle()
        ImGui.SameLine(ctx)
        if ImGui.Button(ctx, '<',butw) then DATA:_Seq_ModifyTools(note, 0, 1)  end ImGui.SameLine(ctx)
        if ImGui.Button(ctx, '>',butw) then DATA:_Seq_ModifyTools(note, 0, -1) end
        -- random ------------------------------------
        if ImGui.Button(ctx, 'Rand', butw_15x) then DATA:_Seq_ModifyTools(note, 2) end ImGui.SameLine(ctx)
        local formatIn = math.floor(EXT.CONF_seq_random_probability*100)..'%%'
        reaper.ImGui_SetNextItemWidth(ctx,butw_15x)
        local retval, v = reaper.ImGui_SliderDouble( ctx, '##randseqnote', EXT.CONF_seq_random_probability, 0.05, 0.95, formatIn, reaper.ImGui_SliderFlags_None() )
        if retval then EXT.CONF_seq_random_probability = v end if reaper.ImGui_IsItemDeactivatedAfterEdit(ctx) then EXT:save() end
        if ImGui.Button(ctx, 'Flip', butw_3x) then DATA:_Seq_ModifyTools(note, 1) end
      
      -- step len combo ------------------------------------
      ImGui.SeparatorText(ctx, 'Step length')
        local steplength = DATA.seq.ext.children[note].steplength
        local default = 0.25
        steplength = math.floor(steplength*100000)/100000 
        local steplength_format = ''
        local names_map = 
          {
            {sep='Straigth'},
            {v=0.5,s='1/2'},
            {v=0.25,s='1/4'},
            {v=0.125,s='1/8'},
            {v=0.0625,s='1/16'},
            {v=0.03125,s='1/32'},
            {sep='Triplets'},
            {v=0.33333,s='1/4T'},
            {v=0.16666,s='1/8T'},
            {v=0.08333,s='1/16T'},
            {v=0.04166,s='1/32T'}
          }
        for i = 1, #names_map do if names_map[i].v == steplength then steplength_format = names_map[i].s end end 
        local ctrl_posXstlen, ctrl_posYstlen = ImGui.GetCursorPos(ctx)
        reaper.ImGui_SetNextItemWidth(ctx,butw_15x)
        if ImGui_BeginCombo( ctx, '##steplength'..note, steplength_format, reaper.ImGui_ComboFlags_NoArrowButton()|ImGui.ComboFlags_HeightLargest ) then -- reaper.ImGui_ComboFlags_NoPreview() 
          for i = 1, #names_map do 
            if names_map[i].s then 
              if ImGui.Selectable(ctx,names_map[i].s) then DATA.seq.ext.children[note].steplength = names_map[i].v DATA:_Seq_Print() end
            end
            if names_map[i].sep then
              reaper.ImGui_SeparatorText(ctx, names_map[i].sep)
            end
          end 
          ImGui_EndCombo( ctx )
        end
        ImGui.SameLine(ctx)
        if ImGui.Button(ctx,'Reset##steplenreset',butw_15x)then DATA.seq.ext.children[note].steplength = 0.25 DATA:_Seq_Print() end
        
      -- Actions
      ImGui.PushFont(ctx,DATA.font2)
      ImGui.SeparatorText(ctx, 'Actions')
      --if ImGui.Button(ctx, 'Clear all', butw_3x) then DATA:_Seq_Clear() end 
      if ImGui.BeginMenu( ctx, ' Actions', true ) then
        ImGui.SeparatorText(ctx, 'Pattern general')
        if ImGui.Button(ctx, 'Clear all',-1) then DATA:_Seq_Clear() end  
        UI.draw_chokecombo(note)
        ImGui.SeparatorText(ctx, 'Pad')
        local SysEx_status = DATA.children[note] and DATA.children[note].SYSEXMOD == true 
        if ImGui.Checkbox(ctx, 'SysEx mode',SysEx_status) then if SysEx_status == true then DATA:Action_RS5k_SYSEXMOD_OFF(note) else DATA:Action_RS5k_SYSEXMOD_ON(note) end   end
        ImGui.SameLine(ctx )UI.HelpMarker([[
  ON:
  - add sysex handler JSFX to child track
  - turn sample into freely configurable mode
  - set pitch start to -64
  - set pitch end to 64
  - set note start to 0
  - set note end to 127
  - refresh internal data, this restrict changing start/end note in RS5k
  
  OFF:
  - remove sysex handler
  - turn sample into Sample mode
  - set note start to [note]
  - set note end to [note]
  - refresh internal data, this allow changing start/end note in RS5k
  ]])
  
        if ImGui.Button(ctx, 'Remove pad content',-1) then
          DATA:Sampler_RemovePad(note) 
        end
        ImGui.EndMenu( ctx )
      end
      ImGui.PopFont(ctx)
      
      local parameter, maxval, minval, default_val, parameter_parent, parameterstr = UI.draw_Seq_ctrls_inline_getactiveparam()
      
      -- globals
        ImGui.SeparatorText(ctx, parameterstr) 
        if default_val and DATA.seq.ext.children[note].steps then
          if ImGui.Button(ctx, 'Reset##resparamvalues') then --,-UI.spacingX
            if not DATA.seq.ext.children[note].steps then DATA.seq.ext.children[note].steps = {} end
            for step in pairs( DATA.seq.ext.children[note].steps) do DATA.seq.ext.children[note].steps[step][parameter] = default_val end
            DATA:_Seq_Print() 
          end
        end
        ImGui.SameLine(ctx)
        if default_val and DATA.seq.ext.children[note].steps then
          if ImGui.Button(ctx, 'Random##randparamvalues') then --,-UI.spacingX
            if not DATA.seq.ext.children[note].steps then DATA.seq.ext.children[note].steps = {} end
            for step in pairs( DATA.seq.ext.children[note].steps) do DATA.seq.ext.children[note].steps[step][parameter] = math.random() * (maxval - minval) + minval end
            DATA:_Seq_Print() 
          end
        end   
      
      -- fx
        if parameter_parent == 'trackFXenv' then
          if ImGui.Button(ctx, '+ Add last touched',110) then 
            DATA:_Seq_AddLastTouchedFX() 
          end
          
          if ImGui.Button(ctx, 'Remove',110) then DATA:_Seq_FXremove(note, parameter)  end
          
          
        end
      
      reaper.ImGui_PopFont(ctx)
    end
    --------------------------------------------------------------------------------  
    function UI.draw_Seq_ctrls_inline(note_t) 
      function __f_draw_Seq_ctrls_inline() end
      
      if not note_t then return end
      local note= note_t.noteID
      if not (note and DATA.children[note] and DATA.children[note].seq_yA) then return end
      
      local parameter = DATA.seq_param_selector[DATA.seq_param_selectorID].param
      local width_area = DATA.display_w-UI.calc_seqXL_padname - UI.scrollbarsz-- UI.calc_seqW_steps + UI.seq_audiolevelW + UI.seq_padnameW + UI.spacingX
      local seq_yA = DATA.children[note].seq_yA[DATA.temp_stepline] or DATA.children[note].seq_yA[0]
      if  seq_yA+DATA.seq_UI_inlineH_area  > DATA.display_viewport_h then
        ImGui.SetNextWindowPos( ctx, UI.calc_seqX + UI.calc_seqXL_padname, seq_yA -UI.seq_padH-DATA.seq_UI_inlineH_area-15  , ImGui.Cond_Always, 0, 0 )--
       else
        ImGui.SetNextWindowPos( ctx, UI.calc_seqX + UI.calc_seqXL_padname, seq_yA , ImGui.Cond_Always, 0, 0 )--
      end
      ImGui.SetNextWindowSize( ctx, width_area, 0, ImGui.Cond_Always )
      ImGui.PushStyleVar(ctx, ImGui.StyleVar_PopupRounding,2)  
      
      if ImGui.BeginPopup(ctx,'note_seq_params'..note) then
        local posx,posy = ImGui.GetCursorPos(ctx)
         
        if ImGui.BeginChild(ctx, '##childinlinetools'..note, UI.seq_padnameW+UI.spacingX, 0, ImGui.ChildFlags_None,ImGui.WindowFlags_None|ImGui.WindowFlags_NoScrollbar) then--|reaper.ImGui_ChildFlags_AutoResizeY()
          
            
          -- name  
            ImGui.PushFont(ctx, DATA.font4) 
            -- define txt
              local note_format = VF_Format_Note(note,note_t)
              if DATA.padcustomnames[note] and DATA.padcustomnames[note] ~= '' then note_format = DATA.padcustomnames[note] end
              local str_maxlen = 20
              if note_format:len()> str_maxlen then note_format = '...'..note_format:sub(-str_maxlen) end
            -- define color
              local color
              if note_t and note_t.I_CUSTOMCOLOR then 
                color = ImGui.ColorConvertNative(note_t.I_CUSTOMCOLOR) 
                color = color & 0x1000000 ~= 0 and (color << 8) | EXT.UI_col_tinttrackcoloralpha-- https://forum.cockos.com/showpost.php?p=2799017&postcount=6
              end 
              if not color then color = EXT.UI_colRGBA_paddefaultbackgr end
              -- if not color then color = EXT.UI_colRGBA_paddefaultbackgr end 
              ImGui.PushStyleColor(ctx, ImGui.Col_Button, color)
              ImGui.PushStyleColor(ctx, ImGui.Col_ButtonActive, color)
              ImGui.PushStyleColor(ctx, ImGui.Col_ButtonHovered, color|0xFF)
            -- button
              ImGui.Button(ctx,note_format..'##rackpad_name'..note,UI.seq_padnameW,UI.seq_padH-1 )
              local x1, y1 = reaper.ImGui_GetItemRectMin( ctx )
              local x2, y2 = reaper.ImGui_GetItemRectMax( ctx )
              if color then ImGui.PopStyleColor(ctx,3) end
               DATA.children[note].seq_yA={}
               DATA.children[note].seq_yA[0] = y1 -- print for note_seq_params popup
              if ImGui.IsItemClicked( ctx, ImGui.MouseButton_Left ) or ImGui.IsItemClicked( ctx, ImGui.MouseButton_Right ) then 
                DATA.temp_stepline = 0
                reaper.ImGui_CloseCurrentPopup(ctx)
              end
            
              
            ImGui.PopFont(ctx) 
            
             
            
          ImGui.PushStyleVar(ctx, ImGui.StyleVar_FramePadding,UI.spacingX,UI.spacingY) 
          ImGui.PushStyleVar(ctx, ImGui.StyleVar_CellPadding,UI.spacingX,UI.spacingY) 
          ImGui.PushStyleVar(ctx, ImGui.StyleVar_ItemSpacing,UI.spacingX,UI.spacingY) 
          ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowPadding,UI.spacingX,UI.spacingY)
          UI.draw_Seq_ctrls_inline_tools(note_t) 
          
          ImGui.PopStyleVar(ctx,4)
          reaper.ImGui_EndChild(ctx)
        end 
        
        UI.draw_Seq_Step(note_t, posx + UI.seq_audiolevelW + UI.seq_padnameW + UI.spacingX, posy )  
        UI.draw_Seq_ctrls_inline_drawstuff(note_t, posx, posy+ UI.seq_padH) 
        ImGui.Dummy(ctx,0,UI.spacingY)
        ImGui.Dummy(ctx,UI.seq_padnameW+UI.spacingX*2,0)ImGui.SameLine(ctx)
        UI.draw_Seq_horizscroll()  
        ImGui.Dummy(ctx,0,UI.spacingY)
        reaper.ImGui_EndPopup(ctx)
      end
      ImGui.PopStyleVar(ctx)
      
    end
    --------------------------------------------------------------------------------  
    function UI.draw_Seq_ctrls_inline_drawstuff(note_t, posx, posy)
      
      local reset_w = 80
      local note = note_t.noteID
      local harea = DATA.seq_UI_inlineH_area
      
      local parameter, maxval, minval, default_val, parameter_parent = UI.draw_Seq_ctrls_inline_getactiveparam()
      
      local parameter = DATA.seq_param_selector[DATA.seq_param_selectorID].param
      local default_val = DATA.seq_param_selector[DATA.seq_param_selectorID].default 
      local maxval = DATA.seq_param_selector[DATA.seq_param_selectorID].maxval  or 1
      local minval = DATA.seq_param_selector[DATA.seq_param_selectorID].minval  or 0
      local parameter_parent = parameter
      
      -- handle meta 
      if parameter == 'meta' then
        parameter = DATA.seq_param_selector_meta[DATA.seq_param_selector_metaID].param
        default_val = DATA.seq_param_selector_meta[DATA.seq_param_selector_metaID].default 
        maxval = DATA.seq_param_selector_meta[DATA.seq_param_selector_metaID].maxval  or 1
        minval = DATA.seq_param_selector_meta[DATA.seq_param_selector_metaID].minval  or 0
      end
      
      -- handle trackenv
      if parameter == 'trackenv' and DATA.seq_param_selector_trackenv[DATA.seq_param_selector_trackenvID]  then
        parameter = DATA.seq_param_selector_trackenv[DATA.seq_param_selector_trackenvID].param
        default_val = DATA.seq_param_selector_trackenv[DATA.seq_param_selector_trackenvID].default 
        maxval = DATA.seq_param_selector_trackenv[DATA.seq_param_selector_trackenvID].maxval  or 1
        minval = DATA.seq_param_selector_trackenv[DATA.seq_param_selector_trackenvID].minval  or 0
      end
      
      -- handle trackenv
      if parameter == 'trackFXenv' and DATA.seq_param_selector_trackFXenv[DATA.seq_param_selector_trackFXenvID]  then
        parameter = DATA.seq_param_selector_trackFXenv[DATA.seq_param_selector_trackFXenvID].param
        default_val = DATA.seq_param_selector_trackFXenv[DATA.seq_param_selector_trackFXenvID].default 
        maxval = DATA.seq_param_selector_trackFXenv[DATA.seq_param_selector_trackFXenvID].maxval  or 1
        minval = DATA.seq_param_selector_trackFXenv[DATA.seq_param_selector_trackFXenvID].minval  or 0
      end
      
      -- work area
      ImGui.SetCursorPos(ctx, posx + UI.seq_audiolevelW + UI.seq_padnameW + UI.spacingX, posy + UI.spacingY)
      
      
      --ImGui.Button(ctx,'active_area',-1,harea)
      ImGui.InvisibleButton(ctx,'active_area',-1,harea)
      local x1, y1 = reaper.ImGui_GetItemRectMin( ctx )
      local x2, y2 = reaper.ImGui_GetItemRectMax( ctx )
      UI.draw_Seq_ctrls_inline_handlemouse(note_t) 
      ImGui.Dummy(ctx,0,UI.spacingY)
      
      
      -- patch for missing sysex_handler JSFX
      local misiingsysex = 
        ( parameter_parent == 'meta' and 
          (
            parameter == 'meta_pitch' or 
            parameter == 'meta_probability'
          )
        ) and DATA.children[note].SYSEXHANDLER_isvalid~=true
        
        
        
        
      if misiingsysex then  
        ImGui.SetCursorPosX(ctx, posx + UI.seq_audiolevelW + UI.seq_padnameW + UI.spacingX)
       
        ImGui.DrawList_AddText( UI.draw_list, x1+ 10, y1+50, 0xFFFFFFBF, 
  [[Not available. Drag anywhere in this area to:
  - add sysex handler JSFX to child track
  - turn sample into freely configurable mode
  - set pitch start to -64
  - set pitch end to 64
  - set note start to 0
  - set note end to 127
  
  SysEx handler JSFX basically replace incoming 
  pitch to sequencer pitch defined in inline editor.
  
  It also used for advanced sequencing parameters.
  ]]
  
  )
  
  
      end
      
      -- parameter tabs
      ImGui.SetCursorPosX(ctx, posx + UI.seq_audiolevelW + UI.seq_padnameW + UI.spacingX)
      if ImGui.BeginTabBar( ctx, 'paraminlinetabs', ImGui.TabItemFlags_None|ImGui.TabBarFlags_FittingPolicyResizeDown ) then
        for i = 1, #DATA.seq_param_selector do
          local formatIn = DATA.seq_param_selector[i].str
          if ImGui.BeginTabItem( ctx, formatIn..'##inlinetabs', false, ImGui.TabItemFlags_None ) then DATA.seq_param_selectorID = i  ImGui.EndTabItem( ctx)  end 
        end
        ImGui.EndTabBar( ctx)
      end
      
      if parameter_parent == 'meta' and misiingsysex ~= true then
        ImGui.SetCursorPosX(ctx, posx + UI.seq_audiolevelW + UI.seq_padnameW + UI.spacingX)
        if ImGui.BeginTabBar( ctx, 'paraminlinetabs_meta', ImGui.TabItemFlags_None|ImGui.TabBarFlags_FittingPolicyResizeDown ) then
          for i = 1, #DATA.seq_param_selector_meta do
            local formatIn = DATA.seq_param_selector_meta[i].str
            if ImGui.BeginTabItem( ctx, formatIn..'##inlinetabs_meta', false, ImGui.TabItemFlags_None ) then DATA.seq_param_selector_metaID = i  ImGui.EndTabItem( ctx)  end 
          end
          ImGui.EndTabBar( ctx)
        end
      end
       
      if parameter_parent == 'trackenv' then
        ImGui.SetCursorPosX(ctx, posx + UI.seq_audiolevelW + UI.seq_padnameW + UI.spacingX)
        if ImGui.BeginTabBar( ctx, 'paraminlinetabs_trackenv', ImGui.TabItemFlags_None|ImGui.TabBarFlags_FittingPolicyResizeDown ) then
          for i = 1, #DATA.seq_param_selector_trackenv do
            local formatIn = DATA.seq_param_selector_trackenv[i].str
            if ImGui.BeginTabItem( ctx, formatIn..'##inlinetabs_trackenv', false, ImGui.TabItemFlags_None ) then DATA.seq_param_selector_trackenvID = i  ImGui.EndTabItem( ctx)  end 
          end
          ImGui.EndTabBar( ctx)
        end
      end
      
      if parameter_parent == 'trackFXenv' then
        ImGui.SetCursorPosX(ctx, posx + UI.seq_audiolevelW + UI.seq_padnameW + UI.spacingX)
        local preview = ''
        if DATA.seq_param_selector_trackFXenv[DATA.seq_param_selector_trackFXenvID] then
          preview = DATA.seq_param_selector_trackFXenv[DATA.seq_param_selector_trackFXenvID].str
        end
        reaper.ImGui_SetNextItemWidth(ctx,-1)
        if ImGui.BeginCombo( ctx, '##paraminlinetabs_trackFXenvcomb', preview, reaper.ImGui_ComboFlags_None() ) then
          for i = 1, #DATA.seq_param_selector_trackFXenv do 
            if i~= DATA.seq_param_selector_trackFXenvID then
              local formatIn = DATA.seq_param_selector_trackFXenv[i].str
              if ImGui.Selectable( ctx, formatIn..'##inlinetabs_trackFXenv', false, ImGui.TabItemFlags_None ) then DATA.seq_param_selector_trackFXenvID = i  end 
            end
          end
          ImGui.EndCombo( ctx )
        end
      end
      
      
      -- STEPS
      local stepw = UI.seq_stepW
      local hfull = (y2-y1)
    
      -- steps active
      local stepcol_1 = 0xBFBFBF00
      local stepcol_2 = (EXT.UI_colRGBA_maintheme_color&0xFFFFFF00)|0x2F 
          
      for step = 1+DATA.seq.stepoffs, DATA.seq.ext.patternlen do
        local stepcol = stepcol_1
        if (step-1)%8> 3 then stepcol = stepcol_2 end 
        local xpos = x1 + (stepw) * (step-DATA.seq.stepoffs-1) 
        ImGui.DrawList_AddRectFilled( UI.draw_list, xpos,y1,xpos + stepw -1 ,y2, stepcol|0x0F, UI.seq_steprounding, ImGui.DrawFlags_None )
      end
      
      -- values
      -- draw velocity / offset
        local mousex, mousey = reaper.ImGui_GetMousePos( ctx )
        local hstep = (y2-y1)
        local hstep_half = (y2-y1)*0.5
        
         
        for step = 1+DATA.seq.stepoffs, DATA.seq.ext.patternlen do
          local stepcol = stepcol_1
          if (step-1)%8> 3 then stepcol = stepcol_2 end
          local activestep = step 
          
          local allow_env_on_empty_steps = 
            DATA.seq.ext.children
            and note
            and DATA.seq.ext.children[note]
            and DATA.seq.ext.children[note].steps
            and activestep
            and DATA.seq.ext.children[note].steps[activestep]
            and DATA.seq.ext.children[note].steps[activestep].val 
            and DATA.seq.ext.children[note].steps[activestep].val == 1
          if EXT.CONF_seq_env_clamp == 0 then  
            if parameter_parent:match('env') then allow_env_on_empty_steps = true end
          end
          
          
          if DATA.seq.ext.children[note].steps and DATA.seq.ext.children[note].steps[activestep] and DATA.seq.ext.children[note].steps[activestep].val  and default_val and allow_env_on_empty_steps == true then 
            local val = default_val
            if DATA.seq.ext.children[note].steps and DATA.seq.ext.children[note].steps[activestep] and DATA.seq.ext.children[note].steps[activestep][parameter] then val = DATA.seq.ext.children[note].steps[activestep][parameter] end 
            local xpos = x1 + (stepw) * (step-1-DATA.seq.stepoffs)
            
            local val_norm = (val - minval) / (maxval - minval)
            local ypos = y1
            
            local istrackpanenv = 
                (DATA.seq_param_selectorID ==6 
                  and DATA.seq_param_selector_trackenvID 
                  and DATA.seq_param_selector_trackenv[DATA.seq_param_selector_trackenvID].param 
                  and DATA.seq_param_selector_trackenv[DATA.seq_param_selector_trackenvID].param == 'env_pan'
                 )
            
            if    DATA.seq_param_selectorID == 1 -- velocity
              or  DATA.seq_param_selectorID == 3 -- split
              or  DATA.seq_param_selectorID == 4 -- len
              or  (DATA.seq_param_selectorID == 5 and DATA.seq_param_selector_metaID == 2) -- meta_probability 
              or  (DATA.seq_param_selectorID == 6 and istrackpanenv ~= true)-- track env
              or  DATA.seq_param_selectorID == 7-- track env
              then 
              
              hstep = (y2-y1)*val_norm
              ypos = math.min(y2-1, y1 + hfull - hstep)
              ImGui.DrawList_AddRectFilled( UI.draw_list, xpos,ypos,xpos + stepw -1 ,y2, stepcol|0x6F, UI.seq_steprounding, ImGui.DrawFlags_None )
             elseif 
                  DATA.seq_param_selectorID == 2  -- offset
              or  (DATA.seq_param_selectorID == 5 and DATA.seq_param_selector_metaID == 1) -- meta_pitch 
              or  istrackpanenv == true
              then
              if val_norm > 0.5 then 
                ypos1 = y1 + hstep_half - hstep_half* (val_norm-0.5)*2
                ypos2 = y1 + hstep_half 
               else
                ypos1 = y1 + hstep_half
                ypos2 = ypos1  + (hstep_half - hstep_half*val_norm*2)
              end
              -- patch for missing sysex_handler JSFX
              
                
              if misiingsysex~=true then  
                ImGui.DrawList_AddRectFilled( UI.draw_list, xpos,ypos1,xpos + stepw -1 ,ypos2, stepcol|0x6F, UI.seq_steprounding, ImGui.DrawFlags_None )
              end
            end
            
            -- draw formatted  values
            local txt=val 
            local txyy = math.max(ypos-20,y1)
            if DATA.seq_param_selectorID == 1  then  --velocity
              txt=math.floor(val*127) 
             elseif DATA.seq_param_selectorID == 2  then --offst
               txt=math.floor(val*100)..'%'
             elseif DATA.seq_param_selectorID == 3  then -- split
               txt=math_q(val)        
             elseif DATA.seq_param_selectorID ==4  then --step len
               txt=math.floor(val*100)..'%'   
             elseif DATA.seq_param_selectorID ==5 and DATA.seq_param_selector_metaID ==1 then --meta_pitch
               txt=math_q(val-64)    
             elseif DATA.seq_param_selectorID ==5 and DATA.seq_param_selector_metaID ==2 then --meta_probability
               txt=math.floor(val*100)..'%'  
             elseif (DATA.seq_param_selectorID == 6  and istrackpanenv ~= true) then --track env
               txt=math.floor(val*100)..'%'      
             elseif istrackpanenv == true then --track pan
               if val > 0 then txt= math.floor(val*100)..'L'               
                 elseif val < 0 then txt= math.floor(-val*100)..'R'               
                 elseif val == 0 then txt='C'
               end
             elseif DATA.seq_param_selectorID ==7 then --fx
               txt=math.floor(val*100)..'%'               
            end
            mousediff = VF_lim(255-math.floor(math.abs(mousex-xpos) ),0,255)--+ math.abs(mousey-ypos)
            
            ImGui.PushFont(ctx, DATA.font5) 
            ImGui.DrawList_AddText( UI.draw_list, xpos, txyy, 0xFFFFFF00|mousediff, txt ) 
            ImGui.PopFont(ctx) 
          end
        end
        
    end
    --------------------------------------------------------------------------------  
    function UI.draw_Seq_ctrls_inline_getactiveparam()
      -- define min/max
      local parameter = DATA.seq_param_selector[DATA.seq_param_selectorID].param
      local parameterstr = DATA.seq_param_selector[DATA.seq_param_selectorID].str
      local maxval = DATA.seq_param_selector[DATA.seq_param_selectorID].maxval or 1
      local minval = DATA.seq_param_selector[DATA.seq_param_selectorID].minval or 0 
      local default_val = DATA.seq_param_selector[DATA.seq_param_selectorID].default or 0  
      local parameter_parent = parameter
      
      -- handle meta
      if parameter_parent == 'meta' then
        parameter = DATA.seq_param_selector_meta[DATA.seq_param_selector_metaID].param
        default_val = DATA.seq_param_selector_meta[DATA.seq_param_selector_metaID].default 
        maxval = DATA.seq_param_selector_meta[DATA.seq_param_selector_metaID].maxval  or 1
        minval = DATA.seq_param_selector_meta[DATA.seq_param_selector_metaID].minval  or 0
        parameterstr = 'Meta: '..DATA.seq_param_selector_meta[DATA.seq_param_selector_metaID].str
      end
      
      -- handle trackenv
      if parameter_parent == 'trackenv' and DATA.seq_param_selector_trackenv[DATA.seq_param_selector_trackenvID] then
        parameter = DATA.seq_param_selector_trackenv[DATA.seq_param_selector_trackenvID].param
        default_val = DATA.seq_param_selector_trackenv[DATA.seq_param_selector_trackenvID].default 
        maxval = DATA.seq_param_selector_trackenv[DATA.seq_param_selector_trackenvID].maxval  or 1
        minval = DATA.seq_param_selector_trackenv[DATA.seq_param_selector_trackenvID].minval  or 0
        parameterstr = 'Track envelope'
      end
      
      -- handle trackFXenv
      if parameter_parent == 'trackFXenv' and DATA.seq_param_selector_trackFXenv[DATA.seq_param_selector_trackFXenvID] then
        parameter = DATA.seq_param_selector_trackFXenv[DATA.seq_param_selector_trackFXenvID].param
        default_val = DATA.seq_param_selector_trackFXenv[DATA.seq_param_selector_trackFXenvID].default 
        maxval = DATA.seq_param_selector_trackFXenv[DATA.seq_param_selector_trackFXenvID].maxval  or 1
        minval = DATA.seq_param_selector_trackFXenv[DATA.seq_param_selector_trackFXenvID].minval  or 0
        parameterstr = 'FX envelope'
      end 
      
      return parameter, maxval, minval, default_val, parameter_parent, parameterstr
    end
    --------------------------------------------------------------------------------  
    function UI.draw_Seq_ctrls_inline_appstuff(note_t, rightbutton)
      local note = note_t.noteID 
      local patlen = DATA.seq.ext.patternlen
      local parameter, maxval, minval, default_val, parameter_parent = UI.draw_Seq_ctrls_inline_getactiveparam()
      
     
      
      
      -- patch for missing sysex_handler JSFX
      local misiingsysex = 
        ( parameter_parent == 'meta' and 
          (
            parameter == 'meta_pitch' or 
            parameter == 'meta_probability'
          )
        ) and DATA.children[note].SYSEXHANDLER_isvalid~=true
        
      if misiingsysex then DATA:Action_RS5k_SYSEXMOD_ON(note) end
      
      -- define active step start/stop
      local active_step = math.ceil(DATA.temp_seq_params.x2_norm * UI.calc_seqW_steps_visible + DATA.seq.stepoffs)
      local active_step_init = math.ceil(DATA.temp_seq_params.x1_norm * UI.calc_seqW_steps_visible + DATA.seq.stepoffs)
      local invert
      if active_step_init > active_step and rightbutton== true  then 
        invert = true
        local temp_val = active_step
        active_step = active_step_init
        active_step_init = temp_val
      end
      
      local step_cnt = DATA.seq.ext.children[note].step_cnt
      if step_cnt == -1 then step_cnt = DATA.seq.ext.patternlen end
      active_step = math.min(active_step, step_cnt)
      
      -- left click to directly set value
      if rightbutton~= true then
        if not DATA.seq.ext.children[note].steps then DATA.seq.ext.children[note].steps = {} end
        if not DATA.seq.ext.children[note].steps[active_step] then DATA.seq.ext.children[note].steps[active_step] = {} end
        local out = DATA.temp_seq_params.y2_norm
        out = out* (maxval - minval)  + minval
        DATA.seq.ext.children[note].steps[active_step][parameter] = VF_lim(out, minval,maxval)
        -- preint step 0 for extended features
        if not DATA.seq.ext.children[note].steps[0] then DATA.seq.ext.children[note].steps[0] = {} end
        DATA.seq.ext.children[note].steps[0][parameter] = 0
      end
      
      -- right click to set area
      if rightbutton== true then 
        if active_step_init ~= active_step then
          if not DATA.seq.ext.children[note].steps then DATA.seq.ext.children[note].steps = {} end 
          for step = active_step_init, active_step do
            if not DATA.seq.ext.children[note].steps[step] then DATA.seq.ext.children[note].steps[step] = {} end
            local out1 = DATA.temp_seq_params.y1_norm
            local out2 = DATA.temp_seq_params.y2_norm 
            local scale = (step-active_step_init) / (active_step - active_step_init)
            local out = out1 + (out2- out1) * scale
            if invert ==true then out = out2 + (out1- out2) * scale end
            out = out* (maxval - minval)  + minval
            DATA.seq.ext.children[note].steps[step][parameter] = VF_lim(out, minval,maxval)
            -- preint step 0 for extended features
            if not DATA.seq.ext.children[note].steps[0] then DATA.seq.ext.children[note].steps[0] = {} end
            DATA.seq.ext.children[note].steps[0][parameter] = 0
          end
         else
          local out = DATA.temp_seq_params.y2_norm
          out = out* (maxval - minval)  + minval
          DATA.seq.ext.children[note].steps[active_step][parameter] = VF_lim(out, minval,maxval)
          -- preint step 0 for extended features
          if not DATA.seq.ext.children[note].steps[0] then DATA.seq.ext.children[note].steps[0] = {} end
          DATA.seq.ext.children[note].steps[0][parameter] = 0
          
        end
      end
       
      
      DATA:_Seq_Print(nil, true) 
      
      
      -- enable obey note off is tweaking step length
      if parameter_parent == 'steplen_override' then DATA:Action_SetObeyNoteOff(note) end
    end
    --------------------------------------------------------------------------------  
    function UI.draw_Seq_startup() 
      reaper.ImGui_SetCursorPos(ctx,0 ,UI.calc_itemH + UI.spacingY)
          ImGui.TextWrapped(ctx,
              [[ 
          Basic step sequencer flow: 
              1. Select MIDI item placed in RS5k manager MIDI bus track. Or create it:]]) --ImGui.SameLine(ctx) 
              ImGui.Dummy(ctx,30,0) ImGui.SameLine(ctx)
              if ImGui.Button(ctx, 'Insert new pattern') then 
                Undo_BeginBlock2(DATA.proj)
                DATA:_Seq_Insert() 
                Undo_EndBlock2(DATA.proj, 'Insert new pattern', 0xFFFFFFFF)
                DATA.upd = true
              end
              
              ImGui.TextWrapped(ctx,  
    [[          2. Once MIDI item is selected, RS5k manager are ready to read and write sequencer data.
    
              ]])
              
              
    end
    --------------------------------------------------------------------------------  
    function UI.draw_Seq_horizscroll(is_thin)  
      -- horiz scroll
      local yoffs = -1
      ImGui.SetNextItemWidth(ctx, -1)
      local format = ''
      if DATA.seq.stepoffs and DATA.seq.ext.patternlen and UI.calc_seqW_steps_visible then 
        local maxval = (math.min(DATA.seq.stepoffs+UI.calc_seqW_steps_visible-1,DATA.seq.ext.patternlen))
        maxval = math.max(maxval,16)
        format = (DATA.seq.stepoffs+1)..'-'..maxval..' steps' 
      end
      local bw= -1 
      local xres  = UI.calc_seqW_steps
      if is_thin == true then 
        xres = DATA.display_w
        bw = - 15 
      end
      -- button base
      ImGui.InvisibleButton(ctx, '#scrollseq',bw, UI.scrollbarsz)
      -- draw rect / handle
      local x1, y1 = reaper.ImGui_GetItemRectMin( ctx )
      local x2, y2 = reaper.ImGui_GetItemRectMax( ctx )
      ImGui.DrawList_AddRectFilled( UI.draw_list, x1, y1+yoffs, x2, y2+yoffs, 0x191919FF, 5, reaper.ImGui_DrawFlags_None() )
      local handle_red = 3
      local minx = x1+handle_red
      local handle_w = 50
      local maxx = x2-handle_red*2 - handle_w
      minx = minx + (maxx - minx) * DATA.seq_horiz_scroll 
      ImGui.DrawList_AddRectFilled( UI.draw_list, minx, y1+yoffs+handle_red, minx + handle_w, y2+yoffs-handle_red, 0x595959FF, 5, reaper.ImGui_DrawFlags_None() )
      if DATA.seq.active_pat_step and DATA.seq.ext.patternlen and DATA.seq.ext.patternlen >= 32 then 
        for i = 1, DATA.seq.ext.patternlen, 16 do
          local xsep = math.floor(x1+handle_red+(x2-x1-handle_red*2) * ((i -1)/ DATA.seq.ext.patternlen))
          ImGui.DrawList_AddLine( UI.draw_list, xsep, y1+yoffs, xsep, y2+yoffs, 0x00FF004F, 1 )
        end
        minx = x1+handle_red
        local playcur_w = xres / DATA.seq.ext.patternlen
        local maxx = x2-handle_red*2 - handle_w
        minx = minx + (maxx - minx) * ((DATA.seq.active_pat_step -1)/ DATA.seq.ext.patternlen)
        ImGui.DrawList_AddRectFilled( UI.draw_list, minx, y1+yoffs+handle_red, minx + playcur_w, y2+yoffs-handle_red, 0x00FF008F, 5, reaper.ImGui_DrawFlags_None() )
      end
      
      if ImGui.IsItemClicked(ctx,ImGui.MouseButton_Left) then
        DATA.temp_horscroll_val = DATA.seq_horiz_scroll
        DATA.temp_horscroll_mx = reaper.ImGui_GetMousePos(ctx)
      end
      if ImGui.IsItemActive(ctx) then
        local mx,my =  reaper.ImGui_GetMousePos(ctx)
        DATA.seq_horiz_scroll = VF_lim(DATA.temp_horscroll_val + (mx - DATA.temp_horscroll_mx)/xres,0,0.99)
        DATA:_Seq_RefreshHScroll()
        reaper.ImGui_DrawList_AddText( UI.draw_list, x2-60, y1+yoffs-1, 0xFFFFFFFF, format )
      end
      if reaper.ImGui_IsItemDeactivated(ctx) then DATA:_Seq_RefreshHScroll() end
      
   
      
      
      --local ret, v = ImGui.SliderDouble(ctx,'##horizscroll',DATA.seq_horiz_scroll,0,0.99,format,ImGui.SliderFlags_None)
      
    end
    --------------------------------------------------------------------------------  
    function UI.draw_Seq_StepProgress(xL,yL, xA,yA) 
      --DATA.seq.active_pat_step
      if not DATA.seq  then  end
      
      local patternlen = DATA.seq.ext.patternlen
      
      if DATA.seq.active_pat_step then
        local step =  DATA.seq.active_pat_step
        step= step - DATA.seq.stepoffs--%16
        --if step == 0 then step = 16 end
        local x1 = xA + (step-1) * UI.seq_stepW
        ImGui.DrawList_AddRectFilled( UI.draw_list, x1,yA+UI.spacingY,x1+UI.seq_stepW,yA+UI.spacingY*2,  0XFFFFFF6F, 5,flagsIn ) 
      end
      
    end
  
  --------------------------------------------------------------------------------  
    function UI.seqdraw()  
      if DATA.VCA_mode == 0 then 
        UI.knob_handle  = UI.knob_handle_normal 
       elseif DATA.VCA_mode == 1 then 
        UI.knob_handle = UI.knob_handle_vca
       elseif DATA.VCA_mode == 2 then 
        UI.knob_handle = UI.knob_handle_vca2       
      end
      
      local closew
      if (DATA.parent_track and DATA.parent_track.valid == true) and UI.calc_padoverviewW and UI.hide_padoverview ~= true then closew = UI.calc_padoverviewW-UI.spacingX*2  end
      if ImGui.Button(ctx, 'X',closew) then DATA.trig_stopdefer2 = true end 
      
      UI.draw_Seq() 
      
      if DATA.temp_loopslice_askforadd then -- autoslice_confirmation
        if not DATA.temp_loopslice_askforadd.triggerpopup then
          ImGui.OpenPopup( ctx, 'autoslice_confirmation', ImGui.PopupFlags_None )
          DATA.temp_loopslice_askforadd.triggerpopup = true
        end
      end
      
      if DATA.temp_loopslice_askforadd and DATA.temp_loopslice_askforadd.loop_t then
        local mousex, mousey = ImGui.GetMousePos( ctx )
        local out_w = 200
        local posx =  mousex-out_w/2 -- middle
        local posy = mousey-UI.calc_itemH*4 -- add as single button
        ImGui.SetNextWindowPos( ctx,posx, posy, ImGui.Cond_Once )
        ImGui.SetNextWindowSize( ctx, out_w, 0, ImGui.Cond_Always )
        if ImGui.BeginPopupModal( ctx, 'autoslice_confirmation', true, ImGui.WindowFlags_AlwaysAutoResize|ImGui.ChildFlags_Border ) then
          local loop_t=  DATA.temp_loopslice_askforadd.loop_t
          local note=  DATA.temp_loopslice_askforadd.note
          local filename=  DATA.temp_loopslice_askforadd.filename
          local slice_cnt = #loop_t
          ImGui.Dummy(ctx,0, UI.spacingY)
          ImGui.Text(ctx, 'Loop is detected,\n'..slice_cnt..' slices found')
          
          if ImGui.Button(ctx, 'Slice to pads', -1) then
            DATA.temp_loopslice_askforadd.confirmed = true
            DATA:Auto_LoopSlice()
            ImGui.CloseCurrentPopup( ctx )
          end
          
          if ImGui.Button(ctx, 'Add as single sample', -1) then
            DATA.temp_loopslice_askforadd = nil
            DATA:DropSample(filename, note, {layer=1})
            ImGui.CloseCurrentPopup( ctx )
          end        
          
          if ImGui.Button(ctx, 'Cancel', -1) then
            DATA.temp_loopslice_askforadd = nil
            ImGui.CloseCurrentPopup( ctx )
          end
          
          ImGui.SeparatorText(ctx, 'Slicing options')
          
          if DATA.temp_loopslice_askforadd  then
            if ImGui.Checkbox(ctx, 'Create MIDI take', DATA.temp_loopslice_askforadd.createMIDI) then 
              DATA.temp_loopslice_askforadd.createMIDI = not DATA.temp_loopslice_askforadd.createMIDI 
              if DATA.temp_loopslice_askforadd.createMIDI == true then DATA.temp_loopslice_askforadd.createPattern = false end
            end
            if DATA.temp_loopslice_askforadd.createMIDI == true then 
              if ImGui.Checkbox(ctx, 'Stretch to project bpm', DATA.temp_loopslice_askforadd.stretchmidi) then DATA.temp_loopslice_askforadd.stretchmidi = not DATA.temp_loopslice_askforadd.stretchmidi end
            end
            if ImGui.Checkbox(ctx, 'Create sequencer pattern', DATA.temp_loopslice_askforadd.createPattern) then 
              DATA.temp_loopslice_askforadd.createPattern = not DATA.temp_loopslice_askforadd.createPattern 
              if DATA.temp_loopslice_askforadd.createPattern == true then DATA.temp_loopslice_askforadd.createMIDI = false end
            end
            
            
            
          end
          
          
          
          ImGui.EndPopup(ctx)
        end
      end
      
      if DATA.loopcheck_testdraw == 1 then
        reaper.ImGui_SetCursorPos(ctx, 1000,50)
        if DATA.temp_CDOE_arr then reaper.ImGui_PlotHistogram(ctx, 'arrtemp', DATA.temp_CDOE_arr, 0, '', 0, 1, 700, 100) end
        reaper.ImGui_SetCursorPos(ctx, 1000,150)
        if DATA.temp_CDOE_arr2 then reaper.ImGui_PlotHistogram(ctx, 'arrtemp', DATA.temp_CDOE_arr2, 0, '', 0, 1, 700, 100) end
      end
      
      
    end
  -------------------------------------------------------------------------------- 
  function UI.MAIN_loop() 
    DATA.clock = os.clock() 
    DATA:handleProjUpdates()
    DATA.flicker = math.abs(-1+(math.cos(math.pi*(DATA.clock%2)) + 1))
    
    DATA:CollectData_Always()
    
    if DATA.upd == true then  DATA:CollectData()  end 
    DATA.upd = false 
     
    --[[if DATA.upd_TCP == true then  
      TrackList_AdjustWindows( false ) 
      DATA.upd_TCP = false
    end]]
    
    
    -- draw UI
    if not reaper.ImGui_ValidatePtr( ctx, 'ImGui_Context*') then UI.MAIN_definecontext() end
    UI.open = UI.MAIN_styledefinition(true) 
    
    
    DATA:CollectData2() 
    
    
    -- handle xy
    DATA:handleViewportXYWH()
    
    -- data
    if UI.open  and not DATA.trig_stopdefer then defer(UI.MAIN_loop) else
      gmem_write(1026, 0) -- rs5k manager opened
      --DATA:Auto_StuffSysex_sub('on release') -- send keys layout to launchpad
    end
  end
  -------------------------------------------------------------------------------- 
  function UI.MAIN_definecontext()
    
    
    -- imgUI init
    ctx = ImGui.CreateContext(DATA.UI_name) 
    -- fonts
    DATA.font1 = ImGui.CreateFont(UI.font, UI.font1sz) ImGui.Attach(ctx, DATA.font1)
    DATA.font2 = ImGui.CreateFont(UI.font, UI.font2sz) ImGui.Attach(ctx, DATA.font2)
    DATA.font3 = ImGui.CreateFont(UI.font, UI.font3sz) ImGui.Attach(ctx, DATA.font3)  
    DATA.font4 = ImGui.CreateFont(UI.font, UI.font4sz) ImGui.Attach(ctx, DATA.font4)  
    DATA.font5 = ImGui.CreateFont(UI.font, UI.font5sz) ImGui.Attach(ctx, DATA.font5)  
     
    -- config
    ImGui.SetConfigVar(ctx, ImGui.ConfigVar_HoverDelayNormal, UI.hoverdelay)
    ImGui.SetConfigVar(ctx, ImGui.ConfigVar_HoverDelayShort, UI.hoverdelayshort)
    
    
    -- run loop
    defer(UI.MAIN_loop)
  end
  --------------------------------------------------------------------------------
  function UI.draw_Rack_PadOverview() 
    if UI.hide_padoverview == true then return end
    
    
    ImGui.SetCursorPosY(ctx,UI.spacingY*2 + UI.calc_itemH)
    
    local ovrvieww = UI.calc_padoverview_cellside*4
    if EXT.UI_drracklayout == 1 then ovrvieww = UI.calc_padoverview_cellside*7 end
    --ImGui.InvisibleButton(ctx, '##padoverview',ovrvieww,-1)
    ImGui.PushStyleColor(ctx, ImGui.Col_SliderGrab, 0)
    ImGui.PushStyleColor(ctx, ImGui.Col_SliderGrabActive, 0)
    ImGui.PushStyleColor(ctx, ImGui.Col_FrameBg, 0)
    ImGui.PushStyleColor(ctx, ImGui.Col_FrameBgHovered, 0)
    ImGui.PushStyleColor(ctx, ImGui.Col_FrameBgActive, 0)
    local val = 0
    if DATA.parent_track and DATA.parent_track.ext and DATA.parent_track.ext.PARENT_DRRACKSHIFT then val = DATA.parent_track.ext.PARENT_DRRACKSHIFT /127 end
    local retval, v = ImGui.VSliderDouble( ctx, '##padoverview', ovrvieww,UI.calc_padoverviewH, val, 0, 1, '', ImGui.SliderFlags_None)
    ImGui.PopStyleColor(ctx,5)
    if retval then UI.Layout_PadOverview_handlemouse(v) end
    local x, y = ImGui.GetItemRectMin(ctx)
    local w, h = ImGui.GetItemRectSize(ctx) 
    if EXT.UI_drracklayout == 0 then UI.Layout_PadOverview_generategrid_pads(x+1,y,w,h) end 
    if EXT.UI_drracklayout == 1 then UI.Layout_PadOverview_generategrid_keys(x+1,y,w,h) end 
    --if EXT.UI_drracklayout == 2 then UI.Layout_PadOverview_generategrid_launchpad(x+1,y,w,h) end 
  end
  --------------------------------------------------------------------------------
  function UI.Layout_PadOverview_handlemouse(v)  
    if not (DATA.parent_track and DATA.parent_track.ext) then return end
    -- pads 
    if EXT.UI_drracklayout == 0 or EXT.UI_drracklayout == 2 then
      local activerow = math.floor(v*33)
      local qblock = 4
      if activerow < 1 then activerow = 0 end
      for block = 0, 6 do if activerow >=block*4+1 and activerow <(block*4)+4+1 then activerow =block*4+1 end end
      activerow = math.min(activerow, 28)
      local out_offs = math.floor(activerow*4)
      if out_offs ~= DATA.parent_track.ext.PARENT_DRRACKSHIFT then 
        DATA.parent_track.ext.PARENT_DRRACKSHIFT = out_offs
        DATA:WriteData_Parent()
      end
    end
     
    -- keys
    if EXT.UI_drracklayout == 1 then 
      local out_offs = 127-math.floor((1-v)*127) 
      out_offs = 12 * math.floor(out_offs/12)
      if out_offs ~= DATA.parent_track.ext.PARENT_DRRACKSHIFT then 
        DATA.parent_track.ext.PARENT_DRRACKSHIFT = out_offs
        DATA:WriteData_Parent()
      end
    end
  end
  -----------------------------------------------------------------------------  
  function UI.Layout_PadOverview_generategrid_pads(x,y,w,h)
    if not DATA.children then return end
    local refnote = 127
    for note = 0, 127 do 
      -- handle col
      local blockcol = 0x757575
      if 
        (note >=0 and note<=3)or
        (note >=20 and note<=35)or
        (note >=52 and note<=67)or
        (note >=84 and note<=99)or
        (note >=116 and note<=127) 
      then blockcol =0xD5D5D5 end
      
      
      local backgr_fill2 = 0.6 
      if DATA.children[note] then backgr_fill2 = 0.8  blockcol = 0xf3f6f4 end
      if DATA.playingnote and DATA.playingnote == note  then blockcol = 0xffe494 backgr_fill2 = 0.9 end
      
      
      if note%4 == 0 then x_offs = x end
      local p_min_x = x_offs
      local p_min_y = y+h - UI.calc_padoverview_cellside*(1+(math.floor(note/4)))
      local p_max_x = p_min_x+UI.calc_padoverview_cellside-1
      local p_max_y = p_min_y+UI.calc_padoverview_cellside-1
      ImGui.DrawList_AddRectFilled( UI.draw_list, p_min_x, p_min_y, p_max_x, p_max_y, blockcol<<8|math.floor(backgr_fill2*0xFF), 0, ImGui.DrawFlags_None )
      ImGui_SetCursorScreenPos( ctx, p_min_x, p_min_y )
      ImGui_InvisibleButton( ctx, '##padnote'..note, UI.calc_padoverview_cellside, UI.calc_padoverview_cellside )
      if ImGui.BeginDragDropTarget( ctx ) then  
        --UI.Drop_UI_interaction_padoverview() 
        UI.Drop_UI_interaction_pad(note) 
        ImGui_EndDragDropTarget( ctx )
      end
      x_offs = x_offs + UI.calc_padoverview_cellside
    end
    
    -- selection
    if DATA.parent_track and DATA.parent_track.ext and DATA.parent_track.ext.PARENT_DRRACKSHIFT then
      local row_cnt = math.floor(127/4)
      local activerow = DATA.parent_track.ext.PARENT_DRRACKSHIFT  / 4
      local p_min_x = x
      local p_min_y = y+h - w-UI.calc_padoverview_cellside*(activerow)
      local p_max_x = p_min_x+w-1
      local p_max_y = p_min_y+w
      ImGui.DrawList_AddRect( UI.draw_list, p_min_x, p_min_y, p_max_x, p_max_y, (EXT.UI_colRGBA_maintheme_color&0xFFFFFF00)|0xF0, 0, ImGui.DrawFlags_None, 2 )
    end
    
  end
  -----------------------------------------------------------------------------  
  function UI.Layout_PadOverview_generategrid_launchpad(x,y,w,h)
    if not DATA.children then return end
    local refnote = 127
    for note = 0, 127 do 
      -- handle col
      local blockcol = 0x757575
     --[[ if 
        (note >=0 and note<=3)or
        (note >=20 and note<=35)or
        (note >=52 and note<=67)or
        (note >=84 and note<=99)or
        (note >=116 and note<=127) 
      then blockcol =0xD5D5D5 end]]
      if note %12==0 then blockcol =0xD5D5D5 end
      
      local backgr_fill2 = 0.4 
      if DATA.children[note] then backgr_fill2 = 0.8  blockcol = 0xf3f6f4 end
      if DATA.playingnote and DATA.playingnote == note  then blockcol = 0xffe494 backgr_fill2 = 0.7 end
      
      
      if note%4 == 0 then x_offs = x end
      local p_min_x = x_offs
      local p_min_y = y+h - UI.calc_padoverview_cellside*(1+(math.floor(note/4)))
      local p_max_x = p_min_x+UI.calc_padoverview_cellside-1
      local p_max_y = p_min_y+UI.calc_padoverview_cellside-1
      ImGui.DrawList_AddRectFilled( UI.draw_list, p_min_x, p_min_y, p_max_x, p_max_y, blockcol<<8|math.floor(backgr_fill2*0xFF), 0, ImGui.DrawFlags_None )
      ImGui_SetCursorScreenPos( ctx, p_min_x, p_min_y )
      ImGui_InvisibleButton( ctx, '##padnote'..note, UI.calc_padoverview_cellside, UI.calc_padoverview_cellside )
      if ImGui.BeginDragDropTarget( ctx ) then  
        --UI.Drop_UI_interaction_padoverview() 
        UI.Drop_UI_interaction_pad(note) 
        ImGui_EndDragDropTarget( ctx )
      end
      x_offs = x_offs + UI.calc_padoverview_cellside
    end
    
    -- selection
    if DATA.parent_track and DATA.parent_track.ext and DATA.parent_track.ext.PARENT_DRRACKSHIFT then
      local row_cnt = math.floor(127/4)
      local activerow = DATA.parent_track.ext.PARENT_DRRACKSHIFT  / 4
      local p_min_x = x
      local p_min_y = y+h - w-UI.calc_padoverview_cellside*(activerow)
      local p_max_x = p_min_x+w-1
      local p_max_y = p_min_y+w
      ImGui.DrawList_AddRect( UI.draw_list, p_min_x, p_min_y, p_max_x, p_max_y, (EXT.UI_colRGBA_maintheme_color&0xFFFFFF00)|0xFF, 0, ImGui.DrawFlags_None, 1 )
    end
    
  end
  
  -----------------------------------------------------------------------------  
  function UI.Layout_PadOverview_generategrid_keys(x_offs0,y_offs0,w,h) 
  
    for note = 0, 127 do 
      -- handle col
      local blockcol = 0x757575
      if 
        (
          note%12 == 0
          or note%12 == 2
          or note%12 == 4
          or note%12 == 5
          or note%12 == 7
          or note%12 == 9
          or note%12 == 11
          
        ) 
      then blockcol =0xD5D5D5 end
      
      
      local backgr_fill2 = 0.4 
      if DATA.children[note] then backgr_fill2 = 0.8  blockcol = 0xf3f6f4 end
      if DATA.playingnote and DATA.playingnote == note  then blockcol = 0xffe494 backgr_fill2 = 0.7 end
      
      local x_offs = x_offs0
      local isblack
      if note%12 == 0 then x_offs = x_offs0 end
      if note%12 == 1 then x_offs = x_offs0+UI.calc_padoverview_cellside*0.5 isblack = true end
      if note%12 == 2 then x_offs = x_offs0+UI.calc_padoverview_cellside*1 end
      if note%12 == 3 then x_offs = x_offs0+UI.calc_padoverview_cellside*1.5 isblack = true end
      if note%12 == 4 then x_offs = x_offs0+UI.calc_padoverview_cellside*2 end
      if note%12 == 5 then x_offs = x_offs0+UI.calc_padoverview_cellside*3 end
      if note%12 == 6 then x_offs = x_offs0+UI.calc_padoverview_cellside*3.5 isblack = true end
      if note%12 == 7 then x_offs = x_offs0+UI.calc_padoverview_cellside*4 end
      if note%12 == 8 then x_offs = x_offs0+UI.calc_padoverview_cellside*4.5 isblack = true end
      if note%12 == 9 then x_offs = x_offs0+UI.calc_padoverview_cellside*5 end
      if note%12 == 10 then x_offs = x_offs0+UI.calc_padoverview_cellside*5.5 isblack = true end
      if note%12 == 11 then x_offs = x_offs0+UI.calc_padoverview_cellside*6 end
      local oct = math.floor(note/12)
      local y_offs = y_offs0 +h  - (UI.calc_padoverview_cellside*2) * oct-UI.calc_padoverview_cellside
      if isblack then y_offs = y_offs - UI.calc_padoverview_cellside end
      local p_min_x = x_offs
      local p_min_y = y_offs
      local p_max_x = p_min_x+UI.calc_padoverview_cellside-1
      local p_max_y = p_min_y+UI.calc_padoverview_cellside-1
      ImGui.DrawList_AddRectFilled( UI.draw_list, p_min_x, p_min_y, p_max_x, p_max_y, blockcol<<8|math.floor(backgr_fill2*0xFF), 0, ImGui.DrawFlags_None )
      ImGui_SetCursorScreenPos( ctx, p_min_x, p_min_y )
      ImGui_InvisibleButton( ctx, '##padnote'..note, UI.calc_padoverview_cellside, UI.calc_padoverview_cellside )
      if ImGui.BeginDragDropTarget( ctx ) then  
        --UI.Drop_UI_interaction_padoverview() 
        UI.Drop_UI_interaction_pad(note) 
        ImGui_EndDragDropTarget( ctx )
      end
    end
    
    -- selection
    if DATA.parent_track and DATA.parent_track.ext and DATA.parent_track.ext.PARENT_DRRACKSHIFT then
      local activerow = DATA.parent_track.ext.PARENT_DRRACKSHIFT/12
      local activerecth = UI.calc_padoverview_cellside*2
      
      local p_min_x = x_offs0
      local p_min_y = y_offs0+(10-activerow)*activerecth-1
      local p_max_x = p_min_x+w-1
      local p_max_y = p_min_y+activerecth
      ImGui.DrawList_AddRect( UI.draw_list, p_min_x, p_min_y, p_max_x, p_max_y,(EXT.UI_colRGBA_maintheme_color&0xFFFFFF00)|0xFF, 0, ImGui.DrawFlags_None, 1 )
    end
    
  end
  --------------------------------------------------------------------------------  
  function UI.draw_tabs_settings_combo(extkey, mapt, str_id, name, extw)
    ImGui.SetNextItemWidth(ctx, extw or UI.settings_itemW )
    if ImGui.BeginCombo( ctx, name..str_id, mapt[EXT[extkey] ], ImGui.ComboFlags_None ) then--|ImGui.ComboFlags_NoArrowButton
      for key in spairs(mapt) do 
        if ImGui.Selectable( ctx, mapt[key]..str_id..key, EXT[extkey] == key, ImGui.SelectableFlags_None) then EXT[extkey] = key EXT:save() DATA.upd = true end
      end
      ImGui.EndCombo( ctx)
    end
  end
  --------------------------------------------------------------------------------  
  function UI.draw_flow_COMBO(t)
    local trig_action
    local preview_value
    if t.hide == true then return end
    if type(EXT[t.extstr]) == 'number' then 
      for key in pairs(t.values) do 
        local isint = ({math.modf(EXT[t.extstr])})[2] == 0 and ({math.modf(key)})[2] == 0 
        if type(key) == 'number' and key ~= 0 and ((isint==true and EXT[t.extstr]&key==key) or EXT[t.extstr]==key) then preview_value = t.values[key] break end 
      end
     elseif type(EXT[t.extstr]) == 'string' then 
      preview_value = EXT[t.extstr] 
    end
    if not preview_value and t.values[0] then preview_value = t.values[0] end 
    ImGui.SetNextItemWidth( ctx, t.extw or -1 )
    if ImGui.BeginCombo( ctx, t.key, preview_value ) then
      for id in spairs(t.values) do
        local selected 
        if type(EXT[t.extstr]) == 'number' then 
          
          local isint = ({math.modf(EXT[t.extstr])})[2] == 0 and ({math.modf(id)})[2] == 0 
          selected = ((isint==true and id&EXT[t.extstr]==EXT[t.extstr]) or id==EXT[t.extstr])  and EXT[t.extstr]~= 0 
        end
        if type(EXT[t.extstr]) == 'string' then selected = EXT[t.extstr]==id end
        
        if ImGui.Selectable( ctx, t.values[id],selected  ) then
          EXT[t.extstr] = id
          trig_action = true
          EXT:save()
          if EXT.CONF_applylive == 1 then DATA:Process() end
        end
      end
      ImGui.EndCombo(ctx)
    end
    
    -- reset
    if reaper.ImGui_IsItemHovered( ctx, ImGui.HoveredFlags_None ) and ImGui_IsMouseClicked( ctx, ImGui.MouseButton_Right ) then
      DATA.PRESET_RestoreDefaults(t.extstr)
      trig_action = true
      if EXT.CONF_applylive == 1 then DATA:Process() end
    end  
    if t.tooltip then  ImGui.SetItemTooltip(ctx, t.tooltip) end
    return  trig_action
  end
  --------------------------------------------------------------------------------  
  function UI.draw_tabs_Actions()

    -------------- General
    ImGui.SeparatorText(ctx, 'General')
    ImGui.Indent(ctx, 10)
    -- stick current track 
      local stickstate = DATA.parent_track and DATA.parent_track.ext_load == true
      if DATA.parent_track and DATA.parent_track.trGUID then
        if ImGui.Checkbox( ctx, 'Stick current rack to this project', stickstate) then 
          if DATA.parent_track.ext_load == true then 
            SetProjExtState( DATA.proj, 'MPLRS5KMAN', 'STICKPARENTGUID','')
            DATA.upd = true
           else
            SetProjExtState( DATA.proj, 'MPLRS5KMAN', 'STICKPARENTGUID',DATA.parent_track.trGUID )
            DATA.upd = true
          end
        end
      end
      ImGui.SameLine(ctx)
      UI.HelpMarker('This rack will be always displayed even if selected track is not related to this rack.\nThis also ignores other racks in project.')
    -- fix GUID
      local fixavailable = ''
      local available_extGUID = not (DATA.parent_track and DATA.parent_track.valid == true and DATA.parent_track.ext.PARENT_GUID_INTERNAL)
      if available_extGUID == true then fixavailable = '[not available] ' end
      if available_extGUID ~= true then ImGui.BeginDisabled(ctx, true) end
      if ImGui.Selectable( ctx, fixavailable..'Fix GUID of parent track', EXT.CONF_lastmacroaction==1, reaper.ImGui_SelectableFlags_None(), 0, 0 ) then 
        GetSetMediaTrackInfo_String( DATA.parent_track.ptr, 'GUID', DATA.parent_track.ext.PARENT_GUID_INTERNAL, true )
        DATA.upd = true
      end 
      ImGui.SameLine(ctx) UI.HelpMarker('Use this if rack doesn`t handled by RS5k manager after import template')
      if available_extGUID ~= true then ImGui.EndDisabled(ctx) end
    ImGui.Unindent(ctx, 10)
  
  
    -------------- MIDI
    ImGui.SeparatorText(ctx, 'MIDI')
    ImGui.Indent(ctx, 10) 
    -- explode take
      if ImGui.Button( ctx, 'Explode MIDI bus take to children',-1) then DATA:Action_ExplodeTake() end
      if ImGui.Button( ctx, 'Explode MIDI bus take to children (fixed note)',-1) then DATA:Action_ExplodeTake({modify_note = EXT.CONF_explodeMIDItochildren_note}) end ImGui.SameLine(ctx) UI.HelpMarker('Explode to children but change output notes to fixed note')
        
        reaper.ImGui_SetNextItemWidth(ctx, 100)
        local retval, v = reaper.ImGui_SliderInt( ctx, 'Explode MIDI Bus: fixed note', EXT.CONF_explodeMIDItochildren_note, 0, 127, EXT.CONF_explodeMIDItochildren_note, ImGui.SliderFlags_None )
        if retval then EXT.CONF_explodeMIDItochildren_note = v end
        if reaper.ImGui_IsItemDeactivated(ctx) then EXT:save() end
        
    ImGui.Unindent(ctx, 10)

    -------------- Various
    ImGui.SeparatorText(ctx, 'Various')
    ImGui.Indent(ctx, 10) 
    --
      if ImGui.Selectable( ctx, 'Rebuild peaks') then 
        DATA.peakscache = {}
        DATA:CollectData2_GetPeaks()
        DATA.upd = true
      end
    ImGui.Unindent(ctx, 10)
    

    --[[------------ LP
    ImGui.SeparatorText(ctx, 'LaunchPad')
      ImGui.Indent(ctx, 10)  
      if ImGui.Checkbox( ctx, 'Drum layout', EXT.CONF_seq_sendsysextoLP==0) then       
        DATA:Launchpad_StuffSysex('F0h 00h 20h 29h 02h 0Dh 00h 04h F7h'  ) 
        EXT.CONF_seq_sendsysextoLP = EXT.CONF_seq_sendsysextoLP~1 EXT:save()
        if DATA.MIDIbus.valid == true and DATA.MIDIbus.tr_ptr then SetMediaTrackInfo_Value( DATA.MIDIbus.tr_ptr, 'I_MIDIHWOUT', EXT.CONF_midioutput<<5) end
        DATA.upd = true
      end --  Drum layout
      ImGui.SameLine(ctx) ImGui.Dummy(ctx, 20, 0) ImGui.SameLine(ctx)
      if EXT.CONF_seq_sendsysextoLP == 1 then reaper.ImGui_BeginDisabled(ctx, true )  end
      if ImGui.Checkbox( ctx, 'Enable monitoring', DATA.MIDIbus.valid == true and DATA.MIDIbus.I_RECMON>0) then       DATA:Launchpad_StuffSysex(nil,1 ) DATA.upd = true end --  Drum layout
      if EXT.CONF_seq_sendsysextoLP == 1 then reaper.ImGui_EndDisabled(ctx )  end
      ImGui.Indent(ctx,10)ImGui.TextDisabled(ctx, '+ MIDI bus: disable monitoring, set MIDI HW output')ImGui.Unindent(ctx,10)
      
      if ImGui.Checkbox( ctx, 'Programmer mode + enable send sequencer data to LP', EXT.CONF_seq_sendsysextoLP==1) then   
        DATA:Launchpad_StuffSysex('F0h 00h 20h 29h 02h 0Dh 00h 7Fh F7h'  ) 
        EXT.CONF_seq_sendsysextoLP = EXT.CONF_seq_sendsysextoLP~1 EXT:save()
        if DATA.MIDIbus.valid == true and DATA.MIDIbus.tr_ptr then SetMediaTrackInfo_Value( DATA.MIDIbus.tr_ptr, 'I_MIDIHWOUT', -1) end
        DATA.upd = true
      end --  Programmer mode layout
      ImGui.Indent(ctx,10)ImGui.TextDisabled(ctx, '+ MIDI bus: disable monitoring, unset MIDI HW output')ImGui.Unindent(ctx,10)
            ]]
            
      ImGui.Unindent(ctx, 10)
      
    
  end 
--------------------------------------------------------------------------------  
  function UI.draw_tabs_settings_database()
    if ImGui.CollapsingHeader(ctx, 'Database maps') then
      ImGui.Indent(ctx,UI.settings_indent)

      -- database
      if DATA.database_maps then 
        -- ImGui.SeparatorText(ctx, 'Database maps') -- ImGui.Text(ctx, 'Database maps') 
        --ImGui.Indent(ctx, UI.settings_indent)
        ImGui.SetNextItemWidth(ctx, UI.settings_itemW )
        
        if DATA.temp_rename == true then 
          local retval, buf = reaper.ImGui_InputText( ctx, '##dbcurname', DATA.database_maps[EXT.UIdatabase_maps_current].dbname, ImGui.InputTextFlags_AutoSelectAll|ImGui.InputTextFlags_EnterReturnsTrue )
          if ImGui.IsItemActive(ctx) and DATA.allow_space_to_play == true then DATA.allow_space_to_play = false end
          if retval and buf ~= '' then 
            DATA.temp_rename = false
            DATA.database_maps[EXT.UIdatabase_maps_current].dbname = buf
            DATA:Database_Save()
          end
         else
         
          if ImGui.BeginCombo( ctx, '##Loaddatabasemap', DATA.database_maps[EXT.UIdatabase_maps_current].dbname, ImGui.ComboFlags_None ) then--|ImGui.ComboFlags_NoArrowButton
            for i = 1, DATA.allowed_db_maps_cnt do
              if ImGui.Selectable( ctx, DATA.database_maps[i].dbname..'##dbmapsel'..i, i == EXT.UIdatabase_maps_current, ImGui.SelectableFlags_None) then EXT.UIdatabase_maps_current = i EXT:save() end
            end
            ImGui.EndCombo( ctx)
          end
        end
        ImGui.SameLine(ctx) UI.HelpMarker('Database map defines which database is linked to which note') 
        ImGui.SameLine(ctx) if ImGui.Button(ctx, 'Rename') then DATA.temp_rename = true  end
        ImGui.SameLine(ctx) if ImGui.Button(ctx, 'Save') then DATA:Database_Save()  end
        ImGui.SetNextItemWidth(ctx, 100 )
        local note_format = 'Note '..DATA.settings_cur_note_database..': '..VF_Format_Note(DATA.settings_cur_note_database)
        if ImGui.BeginCombo( ctx, '##dbselectnote', note_format, ImGui.ComboFlags_None ) then
          for note = 0, 127 do
             local note_format = 'Note '..note..': '..VF_Format_Note(note)
            if ImGui.Selectable( ctx, note_format, false, ImGui.SelectableFlags_None) then 
              DATA.settings_cur_note_database = note
            end
          end 
          ImGui.EndCombo( ctx )
        end
        ImGui.SameLine(ctx) 
        ImGui.SetNextItemWidth(ctx, -1)
        local preview = ''
        if DATA.database_maps
          and EXT.UIdatabase_maps_current
          and DATA.database_maps[EXT.UIdatabase_maps_current]
          and DATA.database_maps[EXT.UIdatabase_maps_current].map
          and DATA.settings_cur_note_database
          and DATA.database_maps[EXT.UIdatabase_maps_current].map[DATA.settings_cur_note_database]
          and DATA.database_maps[EXT.UIdatabase_maps_current].map[DATA.settings_cur_note_database].dbname then
          preview = DATA.database_maps[EXT.UIdatabase_maps_current].map[DATA.settings_cur_note_database].dbname
        end
        if ImGui.BeginCombo( ctx, '##dbselect', preview, ImGui.ComboFlags_None ) then
          for dbname in pairs(DATA.reaperDB) do
            if ImGui.Selectable( ctx, dbname, false, ImGui.SelectableFlags_None) then 
              if not  DATA.database_maps[EXT.UIdatabase_maps_current] then  DATA.database_maps[EXT.UIdatabase_maps_current] = {} end
              if not  DATA.database_maps[EXT.UIdatabase_maps_current].map then  DATA.database_maps[EXT.UIdatabase_maps_current].map = {} end
              if not  DATA.database_maps[EXT.UIdatabase_maps_current].map[DATA.settings_cur_note_database] then  DATA.database_maps[EXT.UIdatabase_maps_current].map[DATA.settings_cur_note_database] = {} end
              DATA.database_maps[EXT.UIdatabase_maps_current].map[DATA.settings_cur_note_database].dbname = dbname
              local ignore_current_rack = true
              DATA:Database_Save(ignore_current_rack)
            end
          end
          ImGui.EndCombo( ctx )
        end
        if ImGui.Button(ctx, 'Load to all rack') then 
          DATA:Validate_MIDIbus_AND_ParentFolder() 
          Undo_BeginBlock2(DATA.proj )
          DATA:Database_Load() 
          Undo_EndBlock2( DATA.proj , 'Load database to all rack', 0xFFFFFFFF )
        end
        
        ImGui.SameLine(ctx) if ImGui.Button(ctx, 'Load selected pad') then 
          DATA:Validate_MIDIbus_AND_ParentFolder() 
          Undo_BeginBlock2(DATA.proj )
          DATA:Database_Load(true)
          Undo_EndBlock2( DATA.proj , 'Load database to selected pad only', 0xFFFFFFFF )
        end
        
        
        --ImGui.Unindent(ctx, UI.settings_indent)
      end
      if ImGui.Checkbox( ctx, 'Do not load database',            EXT.CONF_ignoreDBload == 1 ) then EXT.CONF_ignoreDBload =EXT.CONF_ignoreDBload~1 EXT:save() end
      ImGui.SameLine(ctx)
      UI.HelpMarker('May increase loading time, but you wont be able to use databases')
      ImGui.Text( ctx, 'Current loading time: '..(math.floor(10000*DATA.loadtest)/10000)..'s')
      
      
      
      ImGui.Unindent(ctx,UI.settings_indent)
    end  
  end
  function dBFromVal(val) if val < 0.5 then return 20*math.log(val*2, 10) else return (val*12-6) end end
--------------------------------------------------------------------------------  
  function UI.draw_tabs_settings_onsampleadd()
    if ImGui.CollapsingHeader(ctx, 'On sample add') then   
      ImGui.Indent(ctx,UI.settings_indent)
      
      
      if ImGui.CollapsingHeader(ctx, 'FX instance##On sample add_fx') then   
        ImGui.Indent(ctx, UI.settings_indent)
        if ImGui.Checkbox( ctx, 'Rename instance',                                        EXT.CONF_onadd_renameinst == 1 ) then EXT.CONF_onadd_renameinst =EXT.CONF_onadd_renameinst~1 EXT:save() end 
                if EXT.CONF_onadd_renameinst == 1 then
                  ImGui_SetNextItemWidth(ctx, UI.settings_itemW) 
                  local ret, buf = ImGui.InputText( ctx, 'instance name',                    EXT.CONF_onadd_renameinst_str, ImGui.InputTextFlags_EnterReturnsTrue) 
                  if ret then 
                    EXT.CONF_onadd_renameinst_str =buf 
                    EXT:save() 
                  end
                  ImGui.SameLine(ctx)
                  UI.HelpMarker(
        [[Supported wildcards:
          #note - note number
          #layer - layer number
        ]])
                end
        if ImGui.Checkbox( ctx, 'Float RS5k instance',                                    EXT.CONF_onadd_float == 1 ) then EXT.CONF_onadd_float =EXT.CONF_onadd_float~1 EXT:save() end
        if ImGui.Checkbox( ctx, 'Set obey notes-off',                                     EXT.CONF_onadd_obeynoteoff == 1 ) then EXT.CONF_onadd_obeynoteoff =EXT.CONF_onadd_obeynoteoff~1 EXT:save() end 
        if ImGui.Checkbox( ctx, 'Set Gain to normalized LUFS',                            EXT.CONF_onadd_autoLUFSnorm_toggle == 1 ) then EXT.CONF_onadd_autoLUFSnorm_toggle =EXT.CONF_onadd_autoLUFSnorm_toggle~1 EXT:save() end 
        if EXT.CONF_onadd_autoLUFSnorm_toggle == 1 then 
          ImGui.SameLine(ctx)
          reaper.ImGui_SetNextItemWidth(ctx, 100)
          local normformat = EXT.CONF_onadd_autoLUFSnorm ..'dB' 
          local ret, v = ImGui.SliderInt( ctx, 'Normalize to LUFS##normlufsslider',                          EXT.CONF_onadd_autoLUFSnorm, -23, 0, normformat, ImGui.SliderFlags_None ) 
          if ret then EXT.CONF_onadd_autoLUFSnorm = v end 
          if reaper.ImGui_IsItemDeactivatedAfterEdit(ctx) then EXT:save() end
        end
        
        -- max voices
        local ret, v = ImGui.SliderInt( ctx, 'Max voices##CONF_onadd_maxvoices',                          EXT.CONF_onadd_maxvoices, 1, 64, EXT.CONF_onadd_maxvoices, ImGui.SliderFlags_None ) 
        if ret then EXT.CONF_onadd_maxvoices = v end 
        if reaper.ImGui_IsItemDeactivatedAfterEdit(ctx) then EXT:save() end
        
        -- velocity range
        local ret, v = ImGui.SliderInt( ctx, 'Min velocity##CONF_onadd_minvel',                          EXT.CONF_onadd_minvel, 1, EXT.CONF_onadd_maxvel, EXT.CONF_onadd_minvel, ImGui.SliderFlags_None ) 
        if ret then EXT.CONF_onadd_minvel = VF_lim(v,1,127) end  if reaper.ImGui_IsItemDeactivatedAfterEdit(ctx) then EXT:save() end
        local ret, v = ImGui.SliderInt( ctx, 'Max velocity##CONF_onadd_maxvel',                          EXT.CONF_onadd_maxvel, EXT.CONF_onadd_minvel, 127, EXT.CONF_onadd_maxvel, ImGui.SliderFlags_None ) 
        if ret then EXT.CONF_onadd_maxvel = VF_lim(v,1,127) end  if reaper.ImGui_IsItemDeactivatedAfterEdit(ctx) then EXT:save() end
        
        
        
        local mingain_DB = dBFromVal(EXT.CONF_onadd_mingain)
        if mingain_DB < -70 then mingain_DB = '-inf' else mingain_DB = math.floor(mingain_DB*100)/100 end
        local mingain_DB_format = mingain_DB..'dB'
        local ret, v = ImGui.SliderDouble( ctx, 'Min gain##CONF_onadd_mingain',                          EXT.CONF_onadd_mingain, 0, 0.5, mingain_DB, ImGui.SliderFlags_None|ImGui.SliderFlags_NoInput ) 
        if ret then EXT.CONF_onadd_mingain = VF_lim(v,0,0.5) end  if reaper.ImGui_IsItemDeactivatedAfterEdit(ctx) then EXT:save() end
        
        -- adsr
        if ImGui.Checkbox( ctx, '##CONF_onadd_ADSR_flags_a',                                    EXT.CONF_onadd_ADSR_flags&1 == 1 ) then EXT.CONF_onadd_ADSR_flags =EXT.CONF_onadd_ADSR_flags~1 EXT:save() end ImGui.SameLine(ctx)
        if EXT.CONF_onadd_ADSR_flags&1~=1 then ImGui.BeginDisabled(ctx, true) end
        local ret, v = ImGui.SliderDouble( ctx, 'Attack##CONF_onadd_ADSR_A',            EXT.CONF_onadd_ADSR_A*2, 0, 0.1, '%.3f sec', ImGui.SliderFlags_None ) if ret then EXT.CONF_onadd_ADSR_A = VF_lim(v/2,0,2) end if reaper.ImGui_IsItemDeactivatedAfterEdit(ctx) then EXT:save() end
        if EXT.CONF_onadd_ADSR_flags &1~=1 then ImGui.EndDisabled(ctx) end
        
        if ImGui.Checkbox( ctx, '##CONF_onadd_ADSR_flags_d',                                    EXT.CONF_onadd_ADSR_flags&2 == 2) then EXT.CONF_onadd_ADSR_flags =EXT.CONF_onadd_ADSR_flags~2 EXT:save() end ImGui.SameLine(ctx)
        if EXT.CONF_onadd_ADSR_flags&2~=2 then ImGui.BeginDisabled(ctx, true) end
        local ret, v = ImGui.SliderDouble( ctx, 'Decay##CONF_onadd_ADSR_D',            EXT.CONF_onadd_ADSR_D, 0, 15, '%.3f sec', ImGui.SliderFlags_None ) if ret then EXT.CONF_onadd_ADSR_D = VF_lim(v,0,15) end if reaper.ImGui_IsItemDeactivatedAfterEdit(ctx) then EXT:save() end
        if EXT.CONF_onadd_ADSR_flags &2~=2 then ImGui.EndDisabled(ctx) end
        
        if ImGui.Checkbox( ctx, '##CONF_onadd_ADSR_flags_s',                                    EXT.CONF_onadd_ADSR_flags&4 == 4 ) then EXT.CONF_onadd_ADSR_flags =EXT.CONF_onadd_ADSR_flags~4 EXT:save() end ImGui.SameLine(ctx)
        if EXT.CONF_onadd_ADSR_flags&4~=4 then ImGui.BeginDisabled(ctx, true) end
        local format_sus =  20*math.log(EXT.CONF_onadd_ADSR_S*2, 10)..'dB'
        local ret, v = ImGui.SliderDouble( ctx, 'Sustain##CONF_onadd_ADSR_S',            EXT.CONF_onadd_ADSR_S, 0, 0.5, format_sus, ImGui.SliderFlags_None ) if ret then EXT.CONF_onadd_ADSR_S = VF_lim(v/2,0,0.5) end if reaper.ImGui_IsItemDeactivatedAfterEdit(ctx) then EXT:save() end
        if EXT.CONF_onadd_ADSR_flags &4~=4 then ImGui.EndDisabled(ctx) end
        
        if ImGui.Checkbox( ctx, '##CONF_onadd_ADSR_flags_r',                                    EXT.CONF_onadd_ADSR_flags&8 == 8 ) then EXT.CONF_onadd_ADSR_flags =EXT.CONF_onadd_ADSR_flags~8 EXT:save() end ImGui.SameLine(ctx)
        if EXT.CONF_onadd_ADSR_flags&8~=8 then ImGui.BeginDisabled(ctx, true) end
        local ret, v = ImGui.SliderDouble( ctx, 'Release##CONF_onadd_ADSR_R',            EXT.CONF_onadd_ADSR_R*2, 0, 0.5, '%.3f sec', ImGui.SliderFlags_None ) if ret then EXT.CONF_onadd_ADSR_R = VF_lim(v/2,0,2) end if reaper.ImGui_IsItemDeactivatedAfterEdit(ctx) then EXT:save() end
        if EXT.CONF_onadd_ADSR_flags &8~=8 then ImGui.EndDisabled(ctx) end
        
        ImGui.Unindent(ctx, UI.settings_indent)
      end
      
      
      if ImGui.CollapsingHeader(ctx, 'Track##On sample add_Track') then   
        ImGui.Indent(ctx, UI.settings_indent)
        if ImGui.Checkbox( ctx, 'Rename track',                                           EXT.CONF_onadd_renametrack == 1 ) then EXT.CONF_onadd_renametrack =EXT.CONF_onadd_renametrack~1 EXT:save() end 
        ImGui_SetNextItemWidth(ctx, UI.settings_itemW) 
        local ret, buf = ImGui.InputText( ctx, 'Custom template file',                    EXT.CONF_onadd_customtemplate, ImGui.InputTextFlags_EnterReturnsTrue) 
        if ret then 
          EXT.CONF_onadd_customtemplate =buf 
          EXT:save() 
        end
        ImGui.SameLine(ctx)
        UI.HelpMarker('Path to file')
        UI.draw_tabs_settings_combo('CONF_onadd_ordering',{[0]='Sort by note',[1]='To the top', [2]='To the bottom'},'##settings_childorder', 'New reg child order')  
        if ImGui.Checkbox( ctx, 'Set child color from parent color',                                     EXT.CONF_onadd_takeparentcolor == 1 ) then EXT.CONF_onadd_takeparentcolor =EXT.CONF_onadd_takeparentcolor~1 EXT:save() end 
        if ImGui.Checkbox( ctx, 'Enable sysex mode for new childs',                                     EXT.CONF_onadd_sysexmode == 1 ) then EXT.CONF_onadd_sysexmode =EXT.CONF_onadd_sysexmode~1 EXT:save() end 
        ImGui.SameLine(ctx) UI.HelpMarker('This setting require StepSequencer restart')
        ImGui.Unindent(ctx, UI.settings_indent)
        
        
      end
      
      
      if ImGui.CollapsingHeader(ctx, 'Various##On sample add_Various') then     
        ImGui.Indent(ctx, UI.settings_indent)
        if ImGui.Checkbox( ctx, 'Copy samples to project path',                           EXT.CONF_onadd_copytoprojectpath == 1 ) then EXT.CONF_onadd_copytoprojectpath =EXT.CONF_onadd_copytoprojectpath~1 EXT:save() end 
        ImGui.SameLine(ctx)
        if ImGui.Button(ctx,'Open path') then 
          local prpath = reaper.GetProjectPathEx( 0 )
          prpath = prpath..'/'..EXT.CONF_onadd_copysubfoldname..'/'
          RecursiveCreateDirectory( prpath, 0 )
          VF_Open_URL(prpath) 
        end
        if ImGui.Checkbox( ctx, 'Drop to white keys only',                                EXT.CONF_onadd_whitekeyspriority == 1 ) then EXT.CONF_onadd_whitekeyspriority =EXT.CONF_onadd_whitekeyspriority~1 EXT:save() end
        if ImGui.Checkbox( ctx, 'Auto-set velocity range option enabled for new devices',                                     EXT.CONF_onadd_autosetrange == 1 ) then EXT.CONF_onadd_autosetrange =EXT.CONF_onadd_autosetrange~1 EXT:save() end 
        ImGui.Unindent(ctx, UI.settings_indent)
      end
        
        
        
        ImGui.Unindent(ctx,UI.settings_indent)
    end  
  end
--------------------------------------------------------------------------------  
  function UI.draw_tabs_settings_tcpmcp()
    if ImGui.CollapsingHeader(ctx, 'TCP / MCP') then 
      ImGui.Indent(ctx,UI.settings_indent)
    
        if ImGui.Checkbox( ctx, 'Collapse parent folder',                                 EXT.CONF_onadd_newchild_trackheightflags&1==1 ) then 
          EXT.CONF_onadd_newchild_trackheightflags =EXT.CONF_onadd_newchild_trackheightflags~1  if EXT.CONF_onadd_newchild_trackheightflags&2==2 then EXT.CONF_onadd_newchild_trackheightflags = EXT.CONF_onadd_newchild_trackheightflags~2 end
          EXT:save() 
          DATA:Auto_TCPMCP(true)
          DATA.upd = true 
        end
        if ImGui.Checkbox( ctx, 'Supercollapse parent folder',                            EXT.CONF_onadd_newchild_trackheightflags&2==2 ) then 
          EXT.CONF_onadd_newchild_trackheightflags =EXT.CONF_onadd_newchild_trackheightflags~2  if EXT.CONF_onadd_newchild_trackheightflags&1==1 then EXT.CONF_onadd_newchild_trackheightflags = EXT.CONF_onadd_newchild_trackheightflags~1 end
          EXT:save() 
          DATA:Auto_TCPMCP(true)
          DATA.upd = true 
        end
        if ImGui.Checkbox( ctx, 'Hide children TCP',                                      EXT.CONF_onadd_newchild_trackheightflags&4==4 ) then EXT.CONF_onadd_newchild_trackheightflags =EXT.CONF_onadd_newchild_trackheightflags~4 EXT:save() DATA:Auto_TCPMCP(true) DATA.upd = true end
        ImGui.SameLine(ctx) UI.HelpMarker('Performs at every state change')
        if ImGui.Checkbox( ctx, 'Hide children MCP',                                      EXT.CONF_onadd_newchild_trackheightflags&8==8 ) then EXT.CONF_onadd_newchild_trackheightflags =EXT.CONF_onadd_newchild_trackheightflags~8 EXT:save() DATA:Auto_TCPMCP(true) DATA.upd = true end
        ImGui.SameLine(ctx) UI.HelpMarker('Performs at every state change')
        ImGui_SetNextItemWidth(ctx, UI.settings_itemW)  
        local formatin = '%dpx' if EXT.CONF_onadd_newchild_trackheight == 0 then formatin = 'default' end
        local ret, v = ImGui.SliderInt( ctx, 'New child track height',                    EXT.CONF_onadd_newchild_trackheight, 0, 300, formatin, ImGui.SliderFlags_None ) if ret then EXT.CONF_onadd_newchild_trackheight = v end
        if ImGui_IsItemDeactivatedAfterEdit(ctx) then EXT:save() end 
        if EXT.CONF_onadd_newchild_trackheight > 0 then 
          ImGui.SameLine(ctx) if ImGui.Checkbox( ctx, 'Lock',                                      EXT.CONF_onadd_newchild_trackheight_lock&1==1 ) then EXT.CONF_onadd_newchild_trackheight_lock =EXT.CONF_onadd_newchild_trackheight_lock~1 EXT:save() DATA.upd = true end
        end
        
        
      ImGui.Unindent(ctx,UI.settings_indent)
    end  
  end
  
  
--------------------------------------------------------------------------------  
  function UI.draw_tabs_settings_MIDI()
    if ImGui.CollapsingHeader(ctx, 'MIDI bus') then 
      ImGui.Indent(ctx,UI.settings_indent)
      
      --ImGui.SeparatorText(ctx, 'MIDI bus')  
        --ImGui.Indent(ctx, UI.settings_indent)
        UI.draw_tabs_settings_combo('CONF_midiinput',DATA.MIDI_inputs,'##settings_drracklayout_midiin', 'MIDI bus default input') 
        UI.draw_tabs_settings_combo('CONF_midioutput',DATA.MIDI_outputs,'##settings_drracklayout_midiout', 'MIDI bus default output') 
        ImGui.SetNextItemWidth(ctx, UI.settings_itemW) 
        local chanformat = 'Channel '..EXT.CONF_midichannel if EXT.CONF_midichannel == 0 then chanformat = 'All channels' end
        local ret, v = ImGui.SliderInt( ctx, 'MIDI bus channel',                          EXT.CONF_midichannel, 0, 16, chanformat, ImGui.SliderFlags_None ) if ret then EXT.CONF_midichannel = v EXT:save() end
        if ImGui.Button(ctx, 'Initialize MIDI bus') then DATA:Validate_MIDIbus_AND_ParentFolder() end
        if ImGui.Checkbox( ctx, 'Auto rename MIDI bus MIDI notes',                                EXT.CONF_autorenamemidinotenames&1==1 ) then EXT.CONF_autorenamemidinotenames =EXT.CONF_autorenamemidinotenames~1 EXT:save() end
        if ImGui.Checkbox( ctx, 'Auto rename devices and children MIDI notes',                    EXT.CONF_autorenamemidinotenames&2==2 ) then EXT.CONF_autorenamemidinotenames =EXT.CONF_autorenamemidinotenames~2 EXT:save() end
        --ImGui.Unindent(ctx, UI.settings_indent)
        
        ImGui.Unindent(ctx,UI.settings_indent)
    end  
  end
--------------------------------------------------------------------------------  
  function UI.draw_tabs_settings_UI_custompadnames()
        --ImGui.Text(ctx, 'Custom pad names')
        if ImGui.CollapsingHeader(ctx, 'Custom pad names') then 
          
          -- custom note names
          local curname = string.format('%02d', DATA.padcustomnames_selected_id)
          if DATA.padcustomnames[i] then name = DATA.padcustomnames[i] end
          
          ImGui.Indent(ctx, UI.settings_indent)
          reaper.ImGui_SetNextItemWidth( ctx, 50 )
          if ImGui.BeginCombo( ctx, '##custompadnames',curname, ImGui.ComboFlags_None ) then--|ImGui.ComboFlags_NoArrowButton
            for i = 0,127 do
              local name = string.format('%02d', i)
              if DATA.padcustomnames[i] then name = name..' - '..DATA.padcustomnames[i] end
              if ImGui.Selectable( ctx, name..'##custpadname'..i, i == DATA.padcustomnames_selected_id, ImGui.SelectableFlags_None) then DATA.padcustomnames_selected_id = i end
            end
            ImGui.EndCombo( ctx)
          end
          ImGui.SameLine(ctx)
          local retval, buf = ImGui_InputText( ctx, '##custpadnameinput'..DATA.padcustomnames_selected_id, DATA.padcustomnames[DATA.padcustomnames_selected_id], ImGui_InputTextFlags_None() )
          if retval then 
            buf = buf:gsub('[^%a%d%s%-]+','')
            DATA.padcustomnames[DATA.padcustomnames_selected_id] = buf
          end
          if ImGui_IsItemDeactivatedAfterEdit( ctx ) then
            local outstr = ''
            for i = 0, 127 do outstr=outstr..i..'='..'"'..(DATA.padcustomnames[i] or '')..'" ' end
            EXT.UI_padcustomnamesB64 = VF_encBase64(outstr)
            EXT:save() 
          end
          
          if ImGui.Button(ctx, 'General MIDI bank') then --
            EXT.UI_padcustomnamesB64 = VF_encBase64([[
          27="High Q or Filter Snap"
          28="Slap Noise"
          29="Scratch Push"
          30="Scratch Pull"
          31="Drum sticks"
          32="Square Click"
          33="Metronome Click"
          34="Metronome Bell"
          82="Shaker"
          83="Jingle Bell"
          84="Belltree"
          85="Castanets"
          86="Mute Surdo"
          87="Open Surdo"
          
          35="Acoustic Bass Drum or Low Bass Drum"
          36="Electric Bass Drum or High Bass Drum"
          37="Side Stick"
          38="Acoustic Snare"
          39="Hand Clap"
          40="Electric Snare or Rimshot"
          41="Low Floor Tom"
          42="Closed Hi-hat"
          43="High Floor Tom"
          44="Pedal Hi-hat"
          45="Low Tom"
          46="Open Hi-hat"
          47="Low-Mid Tom"
          48="High-Mid Tom"
          49="Crash Cymbal 1"
          50="High Tom"
          51="Ride Cymbal 1"
          52="Chinese Cymbal"
          53="Ride Bell"
          54="Tambourine"
          55="Splash Cymbal"
          56="Cowbell"
          57="Crash Cymbal 2"
          58="Vibraslap"
          59="Ride Cymbal 2"
          60="High Bongo"
          61="Low Bongo"
          62="Mute High Conga"
          63="Open High Conga"
          64="Low Conga"
          65="High Timbale"
          66="Low Timbale"
          67="High Agogô"
          68="Low Agogô"
          69="Cabasa"
          70="Maracas"
          71="Short Whistle"
          72="Long Whistle"
          73="Short Güiro"
          74="Long Güiro"
          75="Claves"
          76="High Woodblock"
          77="Low Woodblock"
          78="Mute Cuíca"
          79="Open Cuíca"
          80="Mute Triangle"
          81="Open Triangle"
  ]]          )
            EXT:save()
            DATA:CollectDataInit_LoadCustomPadStuff()
          end        
          
          ImGui.SameLine(ctx)
          if ImGui.Button(ctx, 'Akai MPC') then --
            EXT.UI_padcustomnamesB64 = VF_encBase64([[
          37="Side stick"
          36="Kick"
          42="Closed hat"
          82="Shaker"
          40="Snare 2"
          38="Snare 1"
          46="Open hat"
          44="Pedal hat"
          48="High tom"
          47="Mid tom 1"
          45="Mid tom 2"
          43="Low tom"
          49="Crash"
          55="Splash"
          51="Ride"
          53="Ride bell"
          
          
  ]]          )
            EXT:save()
            DATA:CollectDataInit_LoadCustomPadStuff()
          end        
          
          
          if ImGui.Button(ctx, 'Clear custom pad names') then 
            EXT.UI_padcustomnamesB64 = ''
            EXT:save()
            DATA:CollectDataInit_LoadCustomPadStuff()
          end
          
          ImGui.Unindent(ctx, UI.settings_indent)
        end
  end
--------------------------------------------------------------------------------  
  function UI.draw_tabs_settings_UI()
    if ImGui.CollapsingHeader(ctx, 'UI interaction') then 
      ImGui.Indent(ctx,UI.settings_indent)
        
        if ImGui.Checkbox( ctx, 'Click on pad select track',                              EXT.UI_clickonpadselecttrack == 1 ) then EXT.UI_clickonpadselecttrack =EXT.UI_clickonpadselecttrack~1 EXT:save() end
        if ImGui.Checkbox( ctx, 'Click on pad scroll mixer',                              EXT.UI_clickonpadscrolltomixer == 1 ) then EXT.UI_clickonpadscrolltomixer =EXT.UI_clickonpadscrolltomixer~1 EXT:save() end
        if ImGui.Checkbox( ctx, 'Click on pad play sample',                              EXT.UI_clickonpadplaysample == 1 ) then EXT.UI_clickonpadplaysample =EXT.UI_clickonpadplaysample~1 EXT:save() end
        ImGui_SetNextItemWidth(ctx, UI.settings_itemW) 
        local ret, v = ImGui.SliderInt( ctx, 'Default playing velocity',                  EXT.CONF_default_velocity, 1, 127, '%d', ImGui.SliderFlags_None ) if ret then EXT.CONF_default_velocity = v EXT:save() end
        if ImGui.Checkbox( ctx, 'Releasing mouse on pad send NoteOff',                             EXT.UI_pads_sendnoteoff == 1 ) then EXT.UI_pads_sendnoteoff =EXT.UI_pads_sendnoteoff~1 EXT:save() end
        if ImGui.Checkbox( ctx, 'Active note follow incoming note',                       EXT.UI_incomingnoteselectpad == 1 ) then EXT.UI_incomingnoteselectpad =EXT.UI_incomingnoteselectpad~1 EXT:save() end
        ImGui.SameLine(ctx)
        UI.HelpMarker('May be CPU hungry')
        if ImGui.Checkbox( ctx, 'Show meters on pads',            EXT.CONF_showplayingmeters == 1 ) then EXT.CONF_showplayingmeters =EXT.CONF_showplayingmeters~1 EXT:save() end
        ImGui.SameLine(ctx)
        UI.HelpMarker('May be CPU hungry')
        if ImGui.Checkbox( ctx, 'Show peaks on pads',            EXT.CONF_showpadpeaks == 1 ) then EXT.CONF_showpadpeaks =EXT.CONF_showpadpeaks~1 EXT:save() end
        ImGui.SameLine(ctx)
        UI.HelpMarker('May be CPU hungry')
        
        
        if ImGui.Checkbox( ctx, 'Allow space to play',                              EXT.UI_allowshortcuts == 1 ) then EXT.UI_allowshortcuts =EXT.UI_allowshortcuts~1 EXT:save() end
        if ImGui.Checkbox( ctx, 'Allow drop layers on pads',                        EXT.UI_allowdoplayeronpad == 1 ) then EXT.UI_allowdoplayeronpad =EXT.UI_allowdoplayeronpad~1 EXT:save() end
        if ImGui.Checkbox( ctx, 'Show current database map at the top of tabs',             EXT.UI_showcurrentdbmap == 1 ) then EXT.UI_showcurrentdbmap =EXT.UI_showcurrentdbmap~1 EXT:save() end
        ImGui.Unindent(ctx,UI.settings_indent)
    end  
  end
    --------------------------------------------------------------------------------
  function UI.draw_tabs_settings_Theming()    
    if ImGui.CollapsingHeader(ctx, 'Theming') then 
      ImGui.Indent(ctx,UI.settings_indent)
      -- main backgr alpha
      ImGui_SetNextItemWidth(ctx, UI.settings_itemW)
      local retval, v = ImGui.SliderDouble( ctx, 'Background transparency', EXT.UI_transparency, 0, 1, math.floor(EXT.UI_transparency*100)..'%%', ImGui.SliderFlags_None )
      if retval then EXT.UI_transparency = v end if ImGui.IsItemDeactivatedAfterEdit(ctx) then EXT:save()  end
      --trackcol tint
      ImGui_SetNextItemWidth(ctx, UI.settings_itemW)
      local retval, v = ImGui.SliderInt( ctx, 'Tint track color to pads', EXT.UI_col_tinttrackcoloralpha, 0, 255, math.floor(100*EXT.UI_col_tinttrackcoloralpha/255)..'%%', ImGui.SliderFlags_None )
      if retval then EXT.UI_col_tinttrackcoloralpha = v end if ImGui.IsItemDeactivatedAfterEdit(ctx) then EXT:save()  end
      
      --Active pad default
      local retval, col_rgba = ImGui.ColorEdit4( ctx, 'Active pad default', EXT.UI_colRGBA_paddefaultbackgr, ImGui.ColorEditFlags_AlphaBar|ImGui.ColorEditFlags_NoInputs )  
      if retval then EXT.UI_colRGBA_paddefaultbackgr = col_rgba end if ImGui.IsItemDeactivatedAfterEdit(ctx) then EXT:save()  end
      ImGui.SameLine(ctx)if ImGui.Button(ctx, 'Reset##res_Active pad default') then EXT.UI_colRGBA_paddefaultbackgr = UI.def_colRGBA_paddefaultbackgr EXT:save() end
      --Inactive pad default
      local retval, col_rgba = ImGui.ColorEdit4( ctx, 'Inactive pad default', EXT.UI_colRGBA_paddefaultbackgr_inactive, ImGui.ColorEditFlags_AlphaBar|ImGui.ColorEditFlags_NoInputs )  
      if retval then EXT.UI_colRGBA_paddefaultbackgr_inactive = col_rgba end if ImGui.IsItemDeactivatedAfterEdit(ctx) then EXT:save()  end
      ImGui.SameLine(ctx)if ImGui.Button(ctx, 'Reset##res_Inactive pad default') then EXT.UI_colRGBA_paddefaultbackgr_inactive = UI.def_colRGBA_paddefaultbackgr_inactive EXT:save() end
      --ctrls
      local retval, col_rgba = ImGui.ColorEdit4( ctx, 'Pad buttons backgr', EXT.UI_colRGBA_padctrl, ImGui.ColorEditFlags_AlphaBar |ImGui.ColorEditFlags_NoInputs)  
      if retval then EXT.UI_colRGBA_padctrl = col_rgba end if ImGui.IsItemDeactivatedAfterEdit(ctx) then EXT:save()  end
      ImGui.SameLine(ctx)if ImGui.Button(ctx, 'Reset##res_Pad buttons backgr') then EXT.UI_colRGBA_padctrl = UI.def_colRGBA_padctrl EXT:save() end
      --ctrls
      local retval, col_rgba = ImGui.ColorEdit4( ctx, 'Sampler peaks backgr', EXT.UI_colRGBA_smplrbackgr, ImGui.ColorEditFlags_AlphaBar|ImGui.ColorEditFlags_NoInputs )  
      if retval then EXT.UI_colRGBA_smplrbackgr = col_rgba end if ImGui.IsItemDeactivatedAfterEdit(ctx) then EXT:save()  end
      ImGui.SameLine(ctx)if ImGui.Button(ctx, 'Reset##res_Sampler peaks backgr') then EXT.UI_colRGBA_smplrbackgr = UI.colRGBA_smplrbackgr EXT:save() end  
      
      --UI_colRGBA_maintheme_color
      local retval, col_rgba = ImGui.ColorEdit4( ctx, 'Various elements color', EXT.UI_colRGBA_maintheme_color, ImGui.ColorEditFlags_AlphaBar|ImGui.ColorEditFlags_NoInputs )  
      if retval then EXT.UI_colRGBA_maintheme_color = col_rgba end if ImGui.IsItemDeactivatedAfterEdit(ctx) then EXT:save()  end
      ImGui.SameLine(ctx)if ImGui.Button(ctx, 'Reset##UI_colRGBA_maintheme_color') then EXT.UI_colRGBA_maintheme_color = EXT.defaults.UI_colRGBA_maintheme_color EXT:save() end      
      
      
      
        
      ImGui.Unindent(ctx,UI.settings_indent)
    end    
  end
    --------------------------------------------------------------------------------
  function UI.draw_tabs_settings_AutoColor()
    if ImGui.CollapsingHeader(ctx, 'Auto color child tracks') then 
      ImGui.Indent(ctx,UI.settings_indent)
      local t = {
        [0]='Off',
        [1]='By note',
        --[2]='By name',
        }
      
      local curname = t[EXT.CONF_autocol]
      if ImGui.BeginCombo( ctx, '##CONF_autocol_selector',curname, ImGui.ComboFlags_None ) then--|ImGui.ComboFlags_NoArrowButton
        for i in pairs(t) do
          local name = t[i]
          if ImGui.Selectable( ctx, name..'##CONF_autocol_selector'..i, i == EXT.CONF_autocol, ImGui.SelectableFlags_None) then EXT.CONF_autocol = i EXT:save() end
        end
        ImGui.EndCombo( ctx)
      end
      
      -- by note
      if EXT.CONF_autocol == 1 then
        
        -- reset all
        ImGui.SameLine(ctx)
        if ImGui.Selectable( ctx, 'Reset ALL##CONF_autocol_selectorresetall', ImGui.SelectableFlags_None) then  
          DATA.padautocolors = {}
          EXT.UI_padautocolorsB64 = '' 
          EXT:save() 
          DATA.upd = true
        end
        
        
        -- custom pad auto colors selector
        local curname = DATA.padautocolors_selected_id
        if  DATA.children and DATA.children[DATA.padautocolors_selected_id] and DATA.children[DATA.padautocolors_selected_id].P_NAME then curname = DATA.padautocolors_selected_id..' '..DATA.children[DATA.padautocolors_selected_id].P_NAME end
        ImGui.Text(ctx, 'Custom pad colors')
        ImGui.Indent(ctx, UI.settings_indent)
        
        reaper.ImGui_SetNextItemWidth( ctx, 200 )
        if ImGui.BeginCombo( ctx, '##padautocolors',curname, ImGui.ComboFlags_None ) then--|ImGui.ComboFlags_NoArrowButton
          for i = 0,127 do
            local name = i
            if  DATA.children and DATA.children[i] and DATA.children[i].P_NAME then name = i..' '..DATA.children[i].P_NAME end
            --if DATA.padautocolors[i] then name = name..' - '..DATA.padautocolors[i] end
            if ImGui.Selectable( ctx, name..'##coloreditpad_autoname'..i, i == DATA.padautocolors_selected_id, ImGui.SelectableFlags_None) then DATA.padautocolors_selected_id = i end
          end
          ImGui.EndCombo( ctx)
        end
        
        
        ImGui.Unindent(ctx, UI.settings_indent)
        ImGui.SameLine(ctx)
        
        -- color input
        local colext = DATA.padautocolors[DATA.padautocolors_selected_id]
        if colext then colext = tonumber(colext) end
        local col_rgba  = colext or 0
        if col_rgba then 
          local retval, col_rgba = ImGui.ColorEdit4( ctx, '##coloreditpad_auto', col_rgba, ImGui.ColorEditFlags_None|ImGui.ColorEditFlags_NoInputs)--|ImGui.ColorEditFlags_NoAlpha )
          if retval then 
            DATA.padautocolors[DATA.padautocolors_selected_id]  = col_rgba
            DATA.upd = true
          end
          if ImGui_IsItemDeactivatedAfterEdit( ctx ) then
            local outstr = ''
            for i = 0, 127 do outstr=outstr..i..'='..'"'..(DATA.padautocolors[i] or '')..'" ' end
            EXT.UI_padautocolorsB64 = VF_encBase64(outstr )
            EXT:save() 
          end
        end
        ImGui.SameLine(ctx)
        
        -- reset color
        if ImGui.Selectable( ctx, 'Reset##CONF_autocol_selectorreset', ImGui.SelectableFlags_None) then 
          DATA.padautocolors[DATA.padautocolors_selected_id]  = 0
          local outstr = ''
          for i = 0, 127 do outstr=outstr..i..'='..'"'..(DATA.padautocolors[i] or '')..'" ' end
          EXT.UI_padautocolorsB64 = VF_encBase64(outstr )
          EXT:save() 
          DATA.upd = true
        end
        
      end
      ImGui.Unindent(ctx,UI.settings_indent)
    end  
  end
    --------------------------------------------------------------------------------
  function UI.draw_tabs_settings_Autoslice()
    if ImGui.CollapsingHeader(ctx, 'Auto slice loop on pad drop') then 
      ImGui.Indent(ctx,UI.settings_indent)
      
      if ImGui.Checkbox( ctx, 'Use Autoslice',                             EXT.CONF_loopcheck == 1 ) then EXT.CONF_loopcheck =EXT.CONF_loopcheck~1 EXT:save() end
      local retval, v, buf
      if EXT.CONF_loopcheck&1==0 then goto skipset end
      
      -- min
       retval, v = ImGui.SliderDouble( ctx, 'Minimum loop length##CONF_loopcheck_minlen', EXT.CONF_loopcheck_minlen, 0.5, EXT.CONF_loopcheck_maxlen, '%.4fsec', ImGui.SliderFlags_None )
      if retval then EXT.CONF_loopcheck_minlen = v end if ImGui.IsItemDeactivatedAfterEdit(ctx) then EXT:save()  end
      if ImGui_IsItemClicked(ctx, ImGui.MouseButton_Right) then EXT.CONF_loopcheck_minlen = 2 EXT:save() end
      -- min
       retval, v = ImGui.SliderDouble( ctx, 'Maximum loop length##CONF_loopcheck_maxlen', EXT.CONF_loopcheck_maxlen, EXT.CONF_loopcheck_minlen, 16, '%.4fsec', ImGui.SliderFlags_None )
      if retval then EXT.CONF_loopcheck_maxlen = v end if ImGui.IsItemDeactivatedAfterEdit(ctx) then EXT:save()  end
      if ImGui_IsItemClicked(ctx, ImGui.MouseButton_Right) then EXT.CONF_loopcheck_maxlen = 8 EXT:save() end      
      
      -- filt 
      retval, buf = reaper.ImGui_InputText( ctx, 'Filter', EXT.CONF_loopcheck_filter, reaper.ImGui_InputTextFlags_None() )ImGui.SameLine(ctx) UI.HelpMarker('Do not auto slice samples containing words in name')
      if retval then EXT.CONF_loopcheck_filter = buf end
      if ImGui.IsItemDeactivatedAfterEdit(ctx) then EXT:save() end
      
      
      
      
      ::skipset::
      ImGui.Unindent(ctx,UI.settings_indent)
    end  
  end
  --------------------------------------------------------------------------------    
  function UI.draw_tabs_settings_StepSequencer()
    if ImGui.CollapsingHeader(ctx, 'Step Sequencer') then  
      ImGui.Indent(ctx,UI.settings_indent)
      
      if ImGui.Checkbox( ctx, 'Share data to same pattern GUIDs',                             EXT.CONF_seq_force_GUIDbasedsharing == 1 ) then EXT.CONF_seq_force_GUIDbasedsharing =EXT.CONF_seq_force_GUIDbasedsharing~1 EXT:save() end
      ImGui.SameLine(ctx) UI.HelpMarker('This setting require StepSequencer restart')
      
      if ImGui.Checkbox( ctx, 'Use ascending order of intruments',                             EXT.CONF_seq_instrumentsorder == 1 ) then EXT.CONF_seq_instrumentsorder =EXT.CONF_seq_instrumentsorder~1 EXT:save() end
      ImGui.SameLine(ctx) UI.HelpMarker('This setting require StepSequencer restart')
      
      if ImGui.Checkbox( ctx, 'Clamp envelopes at active steps only',                             EXT.CONF_seq_env_clamp == 1 ) then EXT.CONF_seq_env_clamp =EXT.CONF_seq_env_clamp~1 EXT:save() end
      ImGui.SameLine(ctx) UI.HelpMarker('This setting require StepSequencer restart')
      
      if ImGui.Checkbox( ctx, 'Auto legato',                                                   EXT.CONF_seq_autolegato == 1 ) then EXT.CONF_seq_autolegato =EXT.CONF_seq_autolegato~1 EXT:save() end
      ImGui.SameLine(ctx) UI.HelpMarker('This setting require StepSequencer restart')
      
      local map  ={
        [-1] = 'Follow pattern length',
        [16] = '16 steps'
      }
      --ImGui.SetNextItemWidth(ctx, -1)
      if ImGui.BeginCombo( ctx, 'Default steps count##defcntsteps', map[EXT.CONF_seq_defaultstepcnt], ImGui.ComboFlags_None ) then
        for val in pairs(map) do
          if ImGui.Selectable( ctx, map[val], false, ImGui.SelectableFlags_None) then 
            EXT.CONF_seq_defaultstepcnt = val
            EXT:save()
          end
        end
        ImGui.EndCombo( ctx )
      end
      
      
     -- 
      
      ImGui.Unindent(ctx,UI.settings_indent)
    end  
  
  end
  --------------------------------------------------------------------------------    
  function UI.draw_tabs_settings_RackLayout()
    if ImGui.CollapsingHeader(ctx, 'Rack Layout') then 
      ImGui.Indent(ctx,UI.settings_indent)
      
      DATA.temp_ignore_incomingevent = true
      UI.draw_tabs_settings_combo('UI_drracklayout',{[0]='[factory] Default / 8x4 pads',[1]='[factory] 2 octaves keys',[3]='[factory] Akai MPC', [2]='Custom'},'##settings_drracklayout', 'DrumRack layout', 220) 
      
        if EXT.UI_drracklayout == 2 then 
        
          local ID = EXT.UI_drracklayout_customID
          if not DATA.custom_layouts[ID]  then DATA:Layout_Init(ID) end
          
          ImGui.SeparatorText(ctx, 'Note placement')
          
          -- cell cnt
          local retval, v = ImGui.SliderDouble( ctx, 'Cell count limit##cell_cnt_max', DATA.custom_layouts[ID].cell_cnt_max, 1, 64, DATA.custom_layouts[ID].cell_cnt_max, ImGui.SliderFlags_None )
          if retval then DATA.custom_layouts[ID].cell_cnt_max = math_q(v) end if ImGui.IsItemDeactivatedAfterEdit(ctx) then DATA:Layout_SaveCustomLayouts()   end
          if ImGui_IsItemClicked(ctx, ImGui.MouseButton_Right) then DATA.custom_layouts[ID].cell_cnt_max = nil DATA:Layout_Init(ID,true) DATA:Layout_SaveCustomLayouts()  end

          -- row_cnt
          local retval, v = ImGui.SliderDouble( ctx, 'Rows##row_cnt', DATA.custom_layouts[ID].row_cnt, 1, 8, DATA.custom_layouts[ID].row_cnt, ImGui.SliderFlags_None )
          if retval then DATA.custom_layouts[ID].row_cnt = math_q(v) end if ImGui.IsItemDeactivatedAfterEdit(ctx) then DATA:Layout_SaveCustomLayouts()   end
          if ImGui_IsItemClicked(ctx, ImGui.MouseButton_Right) then DATA.custom_layouts[ID].row_cnt = nil DATA:Layout_Init(ID,true) DATA:Layout_SaveCustomLayouts()  end

          -- col_cnt
          local retval, v = ImGui.SliderDouble( ctx, 'Columns##col_cnt', DATA.custom_layouts[ID].col_cnt, 1, 8, DATA.custom_layouts[ID].col_cnt, ImGui.SliderFlags_None )
          if retval then DATA.custom_layouts[ID].col_cnt = math_q(v) end if ImGui.IsItemDeactivatedAfterEdit(ctx) then DATA:Layout_SaveCustomLayouts()   end
          if ImGui_IsItemClicked(ctx, ImGui.MouseButton_Right) then DATA.custom_layouts[ID].col_cnt = nil DATA:Layout_Init(ID,true) DATA:Layout_SaveCustomLayouts()  end
           
          
          if ImGui.Checkbox( ctx, 'Top to bottom',                             DATA.custom_layouts[ID].toptobottom == 1 ) then DATA.custom_layouts[ID].toptobottom =DATA.custom_layouts[ID].toptobottom~1  DATA:Layout_SaveCustomLayouts() end
          
          --ImGui.SeparatorText(ctx, 'Notes mapping')
          
          -- startnote
          local retval, v = ImGui.SliderDouble( ctx, 'Start note##cell_cnt_max', DATA.custom_layouts[ID].startnote, 0, 127, DATA.custom_layouts[ID].startnote, ImGui.SliderFlags_None )
          if retval then DATA.custom_layouts[ID].startnote = math_q(v) end if ImGui.IsItemDeactivatedAfterEdit(ctx) then DATA:Layout_SaveCustomLayouts()   end
          if ImGui_IsItemClicked(ctx, ImGui.MouseButton_Right) then DATA.custom_layouts[ID].startnote = nil DATA:Layout_Init(ID,true) DATA:Layout_SaveCustomLayouts()  end
          -- block by X
          local retval, v = ImGui.SliderDouble( ctx, 'BlockX##blockX', DATA.custom_layouts[ID].blockX, 1, 8, DATA.custom_layouts[ID].blockX, ImGui.SliderFlags_None )
          if retval then DATA.custom_layouts[ID].blockX = math_q(v) end if ImGui.IsItemDeactivatedAfterEdit(ctx) then DATA:Layout_SaveCustomLayouts()   end
          if ImGui_IsItemClicked(ctx, ImGui.MouseButton_Right) then DATA.custom_layouts[ID].blockX = nil DATA:Layout_Init(ID,true) DATA:Layout_SaveCustomLayouts()  end          
          
          ImGui.SeparatorText(ctx, 'Mapping overrides')
          -- remove
          if ImGui.Button(ctx, 'Remove overrides' ) then  
            DATA.custom_layouts[ID].mapping_override  = {} 
            DATA:Layout_SaveCustomLayouts()
          end
          -- remove
          if DATA.lastMIDIinputnote and tonumber(DATA.lastMIDIinputnote) and DATA.parent_track.ext.PARENT_LASTACTIVENOTE then 
            if ImGui.Button(ctx, 'Map note '..DATA.lastMIDIinputnote..' to pad '..DATA.parent_track.ext.PARENT_LASTACTIVENOTE ) then  
              if not DATA.custom_layouts[ID].mapping_override then DATA.custom_layouts[ID].mapping_override  = {}  end
              local note = DATA.parent_track.ext.PARENT_LASTACTIVENOTE
              DATA.custom_layouts[ID].mapping_override[note] = DATA.lastMIDIinputnote
              DATA.custom_layouts[ID].mapping_override[DATA.lastMIDIinputnote] = -1
              DATA:Layout_SaveCustomLayouts()
            end
           else
            
            UI.HelpMarker('Press note on keyboard to get mapping source')
          end
          
          
          
          
          
        end
      -- 
      
      ImGui.Unindent(ctx, UI.settings_indent)
      
    end  
  
  end
  ---------------------------------------------------------------------------------------------------------------------------------    
  function UI.Launchpad_drumrackhelp()
            ImGui.Indent(ctx,10)
            ImGui.BeginDisabled(ctx,true) ImGui.TextWrapped(ctx, [[
Launchpad setuplooks like this:
    1. make sure Launchpad is presented in REAPER Preference / Audio / MIDI outputs 
    2. enable it
    3. restart script
    
Then,
    if you using Drum Rack only
    4a. open RS5k manager/Settings/MIDI Bus and select your MIDIOUT LaunchPad output
    4b. Turn OFF sending MIDI feedback from step sequencer
    
    if you using Step Sequencer as well
    4a. open RS5k manager/Settings/MIDI Bus and select your MIDIOUT LaunchPad output
    4b. Turn ON sending MIDI feedback from step sequencer
    
This setting will be used for newly created MIDI buses. So if you already have rack ready to play, you can apply pre-defined LaunchPad output manually in MIDI bus track routing or here:]])ImGui.EndDisabled(ctx)
      
      
      
      local buttxt = 'Set MIDI Hardware output for MIDI bus'
      if EXT.CONF_midioutput == -1 then 
        ImGui.BeginDisabled(ctx,true) 
        buttxt = '[no MIDI Hardware output for MIDI bus set]'
      end
      if ImGui.Button(ctx, buttxt) then 
        if DATA.MIDIbus.valid == true and DATA.MIDIbus.tr_ptr then SetMediaTrackInfo_Value( DATA.MIDIbus.tr_ptr, 'I_MIDIHWOUT', EXT.CONF_midioutput<<5) end
      end
      if EXT.CONF_midioutput == -1 then ImGui.EndDisabled(ctx) end
      
      
      
      ImGui.BeginDisabled(ctx,true) ImGui.TextWrapped(ctx, [[
      
You can then light up pads using just "normal" MIDI output.
MIDI bus will send same MIDI it sends to tracks, which will light up related pads.


BUT if you use step sequencer you have to turn this MIDI Hardware output OFF. Other
    ]]) ImGui.EndDisabled(ctx)
    
    
    ImGui.Unindent(ctx,10)
  end
  
  ---------------------------------------------------------------------------------------------------------------------------------    
  function UI.draw_tabs_settings_Launchpad()
    if ImGui.CollapsingHeader(ctx, 'Launchpad') then 
      ImGui.Indent(ctx,UI.settings_indent)
      --[[--local retval, p_visible = reaper.ImGui_CollapsingHeader( ctx, 'Drum Rack setup' )
      --if retval then UI.Launchpad_drumrackhelp() end
      UI.Launchpad_drumrackhelp()]]
      ImGui.Unindent(ctx,UI.settings_indent)
    end   
  end      
  --------------------------------------------------------------------------------    
    function UI.draw_tabs_settings()
    
    UI.tab_current = 'Settings'
    if not UI.tab_last or (UI.tab_last and UI.tab_last ~= UI.tab_current ) then EXT.UI_activeTab = UI.tab_current EXT:save() end
    
    UI.tab_last = UI.tab_current 
    if ImGui.BeginChild( ctx, '##settingscontent',-1, 0, ImGui.ChildFlags_None, ImGui.WindowFlags_None ) then --|ImGui.ChildFlags_Border- --|ImGui.WindowFlags_NoScrollWithMouse
      
      
      UI.draw_tabs_settings_database()
      UI.draw_tabs_settings_onsampleadd()
      UI.draw_tabs_settings_tcpmcp()
      UI.draw_tabs_settings_MIDI()
      UI.draw_tabs_settings_UI()
      UI.draw_tabs_settings_UI_custompadnames()
      UI.draw_tabs_settings_RackLayout()
      UI.draw_tabs_settings_Theming()
      UI.draw_tabs_settings_AutoColor()
      UI.draw_tabs_settings_Autoslice()
      UI.draw_tabs_settings_StepSequencer() 
      --UI.draw_tabs_settings_Launchpad() 
      
      
      ImGui.EndChild( ctx)
    end
    
  end
  
  --------------------------------------------------------------------------------  
  function UI.draw_Rack()  
    
    if not (DATA.parent_track and DATA.parent_track.valid == true) then return end
    UI.draw_Rack_PadOverview() 
    --
    ImGui.SameLine(ctx) 
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowPadding,0,0)  
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_ItemSpacing,0,0) 
    
    ImGui.SetCursorScreenPos(ctx,UI.calc_rackX,UI.calc_rackY)
    if ImGui.BeginChild( ctx, 'rack', UI.calc_rackW, 0, ImGui.ChildFlags_None, ImGui.WindowFlags_None |ImGui.WindowFlags_NoScrollbar ) then--|ImGui.ChildFlags_Border --|ImGui.WindowFlags_MenuBar
      UI.draw_Rack_Pads()  
      ImGui.EndChild( ctx)
    end
    ImGui.PopStyleVar(ctx,2)
  end 
  --------------------------------------------------------------------------------  
  function UI.Layout_Pads() 
    if EXT.UI_drracklayout ~= 0 then return end
    local cell_cnt_max = 16
    local yoffs = UI.calc_rackY  + UI.calc_rack_padh*3 + UI.spacingY*3--+ UI.calc_rackH
    local xoffs= UI.calc_rackX
    local padID0 = 0
    for note = 0+DATA.parent_track.ext.PARENT_DRRACKSHIFT, cell_cnt_max-1+DATA.parent_track.ext.PARENT_DRRACKSHIFT do
      UI.draw_Rack_Pads_controls(DATA.children[note], note, xoffs, yoffs, UI.calc_rack_padw, UI.calc_rack_padh) 
      xoffs = xoffs + UI.calc_rack_padw + UI.spacingX
      if padID0%4==3 then 
        xoffs = UI.calc_rackX 
        yoffs = yoffs - UI.calc_rack_padh - UI.spacingY
      end
      padID0 = padID0 + 1
    end
  end
  --------------------------------------------------------------------------------  
  function UI.Layout_Custom()  
    
    if EXT.UI_drracklayout ~= 2 then return end
    local ID = EXT.UI_drracklayout_customID
    if not DATA.custom_layouts[ID] then return end
    
    local cell_cnt_max = DATA.custom_layouts[ID].cell_cnt_max
    local col_cnt = DATA.custom_layouts[ID].col_cnt
    local row_cnt = DATA.custom_layouts[ID].row_cnt 
    local startnote = DATA.custom_layouts[ID].startnote 
    local toptobottom = DATA.custom_layouts[ID].toptobottom 
    local blockX = DATA.custom_layouts[ID].blockX 
    
    local rackx = UI.calc_rackX
    local racky = UI.calc_rackY
    local rackw = UI.calc_rackW
    local rackh = UI.calc_rackH
    local padw = UI.calc_rack_padw
    local padh = UI.calc_rack_padh
    
    local real_cell_cnt_max = math.min(cell_cnt_max, col_cnt * row_cnt) 
    local row_cnt_real = row_cnt
    if col_cnt * row_cnt>cell_cnt_max then row_cnt_real = math.ceil(cell_cnt_max / col_cnt) end
    
    local mapping = {}
    for pad = 1, cell_cnt_max do 
      mapping[pad] = pad + startnote-1 
      local note = mapping[pad]
      if DATA.custom_layouts[ID].mapping_override and DATA.custom_layouts[ID].mapping_override[note] then mapping[pad] = DATA.custom_layouts[ID].mapping_override[note] end
    end
    
    local padx_init = rackx
    local pady_init = racky
    local xpos0basedID = 0
    local xpos0basedID_blockoffset = 0
    local ypos0basedID = 0
    if toptobottom == 0 then pady_init = racky + rackh - padh - UI.spacingY end
    for pad = 1, cell_cnt_max do  
      if ypos0basedID == row_cnt_real then
        xpos0basedID_blockoffset = xpos0basedID_blockoffset + blockX
        ypos0basedID = 0
      end
      local padx = padx_init + padw * (xpos0basedID   + xpos0basedID_blockoffset)
      local pady = pady_init + padh * ypos0basedID
      if toptobottom == 0 then pady = pady_init- padh * ypos0basedID end 
      local mapped_note = mapping[pad] 
      if (xpos0basedID  + xpos0basedID_blockoffset) < col_cnt then
        if mapped_note <128 then
          UI.draw_Rack_Pads_controls(DATA.children[mapped_note], mapped_note, padx, pady, padw, padh) 
        end
      end
      xpos0basedID = xpos0basedID + 1
      if xpos0basedID%blockX == 0 then 
        xpos0basedID = 0
        ypos0basedID = ypos0basedID + 1 
      end
      
    end
    
    
    
    --[[local padID0 = 0
    local xpos0basedID_shift = 0
    local ypos0basedID_shift = 0
    for pad = 1, cell_cnt_max do  
    
      local xpos0basedID = padID0%col_cnt
      local padx = rackx + padw * xpos0basedID  
      local ypos0basedID = math.floor(padID0 / col_cnt) + ypos0basedID_shift
      local pady = racky + padh * ypos0basedID
      
      if toptobottom == 0 then
        pady = racky + rackh - padh * (1+ypos0basedID ) - UI.spacingY
      end
      
      
       
      padID0 = padID0 + 1
    end
    ]]
    

    --[[local padID0 = 0
    local xpos0basedID_shift = 0
    local ypos0basedID_shift = 0
    for pad = 1, cell_cnt_max do  
    
      local xpos0basedID = padID0%col_cnt
      local padx = rackx + padw * xpos0basedID  
      local ypos0basedID = math.floor(padID0 / col_cnt) + ypos0basedID_shift
      local pady = racky + padh * ypos0basedID
      
      if toptobottom == 0 then
        pady = racky + rackh - padh * (1+ypos0basedID ) - UI.spacingY
      end
      
      local mapped_note = mapping[pad] 
      UI.draw_Rack_Pads_controls(DATA.children[mapped_note], mapped_note, padx, pady, padw, padh) 
      padID0 = padID0 + 1
    end
    ]]
    
    
  end
  --------------------------------------------------------------------------------  
  function UI.Layout_Keys() 
    if EXT.UI_drracklayout ~= 1 then return end
    
    local cell_cnt_max = 24
      
    local xoffs0 = UI.calc_rackX
    --local yoffs0 = UI.calc_rackY + UI.calc_rackH - UI.calc_rack_padh
    local yoffs0 = UI.calc_rackY  + UI.calc_rack_padh*3 --+ UI.spacingY*3
    local padID0 = 0
    local oct = -1
    local xoffs, yoffs
    for note = DATA.parent_track.ext.PARENT_DRRACKSHIFT, cell_cnt_max-1+DATA.parent_track.ext.PARENT_DRRACKSHIFT do
      xoffs = xoffs0
      yoffs = yoffs0
      local note_oct = note%12
      if note_oct ==0 then oct = oct + 1 end
      if oct == 1 then yoffs = yoffs - UI.calc_rack_padh*2 end
      if note_oct == 0 then xoffs = xoffs0 end
      if note_oct == 1 then xoffs = xoffs0+0.5*UI.calc_rack_padw yoffs=yoffs-UI.calc_rack_padh end
      if note_oct == 2 then xoffs = xoffs0+1*UI.calc_rack_padw end
      if note_oct == 3 then xoffs = xoffs0+1.5*UI.calc_rack_padw yoffs=yoffs-UI.calc_rack_padh end
      if note_oct == 4 then xoffs = xoffs0+UI.calc_rack_padw*2 end
      if note_oct == 5 then xoffs = xoffs0+UI.calc_rack_padw*3 end
      if note_oct == 6 then xoffs = xoffs0+3.5*UI.calc_rack_padw yoffs=yoffs-UI.calc_rack_padh end
      if note_oct == 7 then xoffs = xoffs0+UI.calc_rack_padw*4 end
      if note_oct == 8 then xoffs = xoffs0+4.5*UI.calc_rack_padw yoffs=yoffs-UI.calc_rack_padh end
      if note_oct == 9 then xoffs = xoffs0+UI.calc_rack_padw*5 end
      if note_oct == 10 then xoffs = xoffs0+5.5*UI.calc_rack_padw yoffs=yoffs-UI.calc_rack_padh end
      if note_oct == 11 then xoffs = xoffs0+UI.calc_rack_padw*6 end
      if note >= 0 and note <=127 then UI.draw_Rack_Pads_controls(DATA.children[note], note, xoffs, yoffs, UI.calc_rack_padw, UI.calc_rack_padh) end
      padID0=padID0+1
    end
      
    
  end
    --------------------------------------------------------------------------------  
    function UI.draw_Rack_Pads() 
      
      if not (DATA.parent_track and DATA.parent_track.valid == true) then return end
      
      --ImGui.DrawList_AddRectFilled( UI.draw_list, UI.calc_rackX, UI.calc_rackY, UI.calc_rackX+UI.calc_rackW, UI.calc_rackY+UI.calc_rackH, 0xFFFFFFA0, 0, 0 )
      UI.Layout_Pads() 
      UI.Layout_Keys() 
      UI.Layout_Custom() 
      UI.Layout_PadsAkai() 
      
    end
  --------------------------------------------------------------------------------  
  function UI.Layout_PadsAkai() 
    if EXT.UI_drracklayout ~= 3 then return end
    local cell_cnt_max = 16
    local yoffs = UI.calc_rackY  + UI.calc_rack_padh*3 + UI.spacingY*3--+ UI.calc_rackH
    local xoffs= UI.calc_rackX
    local padID0 = 0
    
    local layout_mpc = {
    37,
    36,
    42,
    82,
    
    40,
    38,
    46,
    44,
    
    48,
    47,
    45,
    43,
    
    
    49,
    55,
    51,
    53,
      
      
      
    }
    
    for note = 0, cell_cnt_max-1 do
      local active_note = layout_mpc[note+1]
      UI.draw_Rack_Pads_controls(DATA.children[active_note], active_note, xoffs, yoffs, UI.calc_rack_padw, UI.calc_rack_padh) 
      xoffs = xoffs + UI.calc_rack_padw + UI.spacingX
      if padID0%4==3 then 
        xoffs = UI.calc_rackX 
        yoffs = yoffs - UI.calc_rack_padh - UI.spacingY
      end
      padID0 = padID0 + 1
    end
  end    
  --------------------------------------------------------------------------------  
  function UI.draw_Rack_Pads_controls_MSP(local_pos_x,local_pos_y,note_t,note)  
  
    if EXT.UI_allowdoplayeronpad == 1 then 
      local retval, filename = reaper.ImGui_GetDragDropPayloadFile( ctx, 0 )
      if retval == true then 
        -- drop layers here
        ImGui.SetCursorPos( ctx, local_pos_x, local_pos_y +UI.calc_rack_padnameH)
        ImGui.Button(ctx,'+ layer##rackpad_droplayer'..note,-1,UI.calc_rack_padctrlH )
        if ImGui.BeginDragDropTarget( ctx ) then  
          local cntlayers = 0
          if DATA.children[note] and DATA.children[note].layers then cntlayers = #DATA.children[note].layers end
          UI.Drop_UI_interaction_device(note, cntlayers + 1)   
          ImGui_EndDragDropTarget( ctx )
        end
        return 
      end
    end
    
    -- mute
      ImGui.SetCursorPos( ctx, local_pos_x, local_pos_y +UI.calc_rack_padnameH)
      local ismute = note_t and note_t.B_MUTE and note_t.B_MUTE == 1
      if ismute==true then ImGui.PushStyleColor(ctx, ImGui.Col_Text, 0xFF0F0FF0 ) end
      if note_t and ImGui.Button(ctx,'M##rackpad_mute'..note,UI.calc_rack_padctrlW,UI.calc_rack_padctrlH ) then SetMediaTrackInfo_Value( note_t.tr_ptr, 'B_MUTE', note_t.B_MUTE~1 ) DATA.upd = true end  
      if ismute==true then ImGui.PopStyleColor(ctx) end
      ImGui.SameLine(ctx)
      
    -- play
      ImGui.InvisibleButton(ctx,'P##rackpad_playinv'..note,UI.calc_rack_padctrlW,UI.calc_rack_padctrlH )
      if ImGui.IsItemActivated( ctx ) then  DATA:Sampler_StuffNoteOn(note)  end
      if ImGui.IsItemDeactivated( ctx ) and EXT.UI_pads_sendnoteoff == 1 then DATA:Sampler_StuffNoteOn(note, 0, true) end
      
      local x1, y1 = reaper.ImGui_GetItemRectMin( ctx )
      local x2, y2 = reaper.ImGui_GetItemRectMax( ctx ) 
      --UI.textcol col_green
      local col = UI.textcol 
      if DATA.lastMIDIinputnote and DATA.lastMIDIinputnote == note then 
        col = UI.padplaycol
      end
      ImGui.PushStyleColor(ctx, ImGui.Col_Text, col<<8|0xFF)
      ImGui.SetCursorScreenPos( ctx, x1+(x2-x1)/2-UI.calc_itemH/2, y1+(y2-y1)/2-UI.calc_itemH/2 )
      if note_t then ImGui.ArrowButton(ctx,'P##rackpad_play'..note ,ImGui.Dir_Right )end
      ImGui.PopStyleColor(ctx)
      
    -- solo
      ImGui.SetCursorScreenPos( ctx, x1+UI.calc_rack_padctrlW, y1 )
      local issolo = note_t and note_t.I_SOLO and note_t.I_SOLO > 0 
      if issolo == true then ImGui.PushStyleColor(ctx, ImGui.Col_Text, 0x00FF0FF0 ) end
      if note_t and ImGui.Button(ctx,'S##rackpad_solo'..note,UI.calc_rack_padctrlW,UI.calc_rack_padctrlH ) then
        if note_t and note_t.tr_ptr then 
          local outval = 2 if note_t.I_SOLO>0 then outval = 0 end SetMediaTrackInfo_Value( note_t.tr_ptr, 'I_SOLO', outval ) DATA.upd = true
        end 
      end   
      if issolo == true then ImGui.PopStyleColor(ctx) end
    end
  --------------------------------------------------------------------------------  
  function UI.draw_Rack_Pads_controls(note_t,note, x,y,w,h) 
    local min_h = UI.controls_minH
    -- name background 
      local color
      if note_t and note_t.I_CUSTOMCOLOR then 
        color = ImGui.ColorConvertNative(note_t.I_CUSTOMCOLOR) 
        color = color & 0x1000000 ~= 0 and (color << 8) |  EXT.UI_col_tinttrackcoloralpha-- https://forum.cockos.com/showpost.php?p=2799017&postcount=6
      end
      
      --[[if EXT.CONF_autocol == 1 and DATA.children[note] and DATA.padautocolors and DATA.padautocolors[note] then 
        color = (DATA.padautocolors[note]>>8)  | 0x1000000
        color = color & 0x1000000 ~= 0 and (color << 8) | 0xFF-- https://forum.cockos.com/showpost.php?p=2799017&postcount=6
      end]]
            
      local h_name = h
      if h > min_h then h_name = UI.calc_rack_padnameH end
      if color then 
        ImGui.DrawList_AddRectFilled( UI.draw_list, x+1, y, x+w-1, y+h, color, 5, ImGui.DrawFlags_RoundCornersTop) 
       else 
        if note_t then
          ImGui.DrawList_AddRectFilled( UI.draw_list, x+1, y, x+w-1, y+h, EXT.UI_colRGBA_paddefaultbackgr, 5, ImGui.DrawFlags_RoundCornersTop)
         else
          ImGui.DrawList_AddRectFilled( UI.draw_list, x+1, y, x+w-1, y+h, EXT.UI_colRGBA_paddefaultbackgr_inactive, 5, ImGui.DrawFlags_RoundCornersTop) 
        end
      end
    
    -- LED database / defice
      if note_t then
        local offs = 5
        local ledyspace = 2
        local sz = 5
        local ledx= x+w-offs-sz
        local ledy= y+offs 
        if note_t.TYPE_DEVICE==true then                      ImGui.DrawList_AddRectFilled( UI.draw_list, ledx, ledy, ledx+sz, ledy+sz, 0x00FF50FF, 0, ImGui.DrawFlags_None) ledy=ledy+offs+ledyspace end
        if note_t.has_setDB then                              ImGui.DrawList_AddRectFilled( UI.draw_list, ledx, ledy, ledx+sz, ledy+sz, 0x0090FFFF, 0, ImGui.DrawFlags_None) ledy=ledy+offs+ledyspace end
        if note_t.has_setDB and note_t.has_setDBlocked then   ImGui.DrawList_AddRectFilled( UI.draw_list, ledx, ledy, ledx+sz, ledy+sz, 0xFF5000FF, 0, ImGui.DrawFlags_None) ledy=ledy+offs+ledyspace end
        if DATA.MIDIbus and DATA.MIDIbus.choke_setup and DATA.MIDIbus.choke_setup[note] then   
                                                              ImGui.DrawList_AddRectFilled( UI.draw_list, ledx, ledy, ledx+sz, ledy+sz, 0xFFFF00FF, 0, ImGui.DrawFlags_None) ledy=ledy+offs+ledyspace end
      end
      
    -- peaks 
      if EXT.UI_drracklayout ~= 2 and 
        DATA.children[note] and
        DATA.children[note].layers and 
        DATA.children[note].layers[1] and 
        DATA.peakscache[note] and 
        DATA.peakscache[note].peaks_arr  then 
        local is_pad_peak = true 
        local dim
        local ypeaks = y+UI.calc_itemH
        local hpeaks = UI.calc_rack_padnameH-UI.calc_itemH
        UI.draw_peaks('pad'..note, note_t, x + UI.spacingX, ypeaks, w-UI.spacingX*2 , hpeaks,DATA.peakscache[note].peaks_arr, is_pad_peak, dim) 
      end
    
    -- controls background 
      if h > min_h and UI.calc_rack_padctrlH > 0 then ImGui.DrawList_AddRectFilled( UI.draw_list, x+1, y+UI.calc_rack_padnameH, x+w-1, y+h-1, EXT.UI_colRGBA_padctrl, 5, ImGui.DrawFlags_RoundCornersBottom ) end
      
    -- controls background
      --ImGui.DrawList_AddRectFilled( UI.draw_list, x+1, y+UI.calc_rack_padnameH, x+w-1, y+h-1, 0xFFFFFF1F, 5, ImGui.DrawFlags_RoundCornersBottom )
    
    -- frame / selection 
      if (DATA.parent_track and DATA.parent_track.ext and DATA.parent_track.ext.PARENT_LASTACTIVENOTE and DATA.parent_track.ext.PARENT_LASTACTIVENOTE  == note) then 
        ImGui.DrawList_AddRect( UI.draw_list, x, y, x+w, y+h, (EXT.UI_colRGBA_maintheme_color&0xFFFFFF00)|0x90, 5, ImGui.DrawFlags_None|ImGui.DrawFlags_RoundCornersAll, 1 )
       else
        ImGui.DrawList_AddRect( UI.draw_list, x, y, x+w, y+h, 0x0000005F              , 5, ImGui.DrawFlags_None|ImGui.DrawFlags_RoundCornersAll, 1 )
      end
      
    
    ImGui.SetCursorScreenPos( ctx, x, y )  
    if ImGui.BeginChild( ctx, '##rackpad'..note, w, h, ImGui.ChildFlags_None , ImGui.WindowFlags_None|ImGui.WindowFlags_NoScrollbar) then--|ImGui.ChildFlags_Border
      local note_format = VF_Format_Note(note,note_t)
      if note_format then
        if EXT.UI_drracklayout == 2 then note_format = note_format..' ('..note..')' end
        if DATA.padcustomnames[note] and DATA.padcustomnames[note] ~= '' then note_format = DATA.padcustomnames[note] end
        if  DATA.parent_track.padcustomnames_overrides and DATA.parent_track.padcustomnames_overrides[note] and DATA.parent_track.padcustomnames_overrides[note] ~= '' then note_format = DATA.parent_track.padcustomnames_overrides[note] end
       else
        note_format = ''
      end
      UI.Tools_setbuttonbackg() 
      
      -- name 
        ImGui.PushFont(ctx, DATA.font3) 
        ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowPadding,UI.spacingX, UI.spacingY)
        local local_pos_x, local_pos_y = ImGui.GetCursorPos( ctx )
        ImGui.SetCursorPos( ctx, local_pos_x+UI.spacingX, local_pos_y+UI.spacingY )
        ImGui.Button(ctx,'##rackpad_name'..note,UI.calc_rack_padw -UI.spacingX *2+1,UI.calc_rack_padnameH-UI.spacingY*2 ) 
        UI.draw_Rack_Pads_controls_handlemouse(note_t,note)
        
        ImGui.SetCursorPos( ctx, local_pos_x+UI.spacingX, local_pos_y+UI.spacingY )
        ImGui.TextWrapped( ctx, note_format )
        
        ImGui.PopStyleVar(ctx)
        ImGui.PopFont(ctx) 
      
      if h > min_h and UI.calc_rack_padctrlH > 0 then UI.draw_Rack_Pads_controls_MSP(local_pos_x,local_pos_y,note_t,note)    end
      
      UI.Tools_unsetbuttonstyle()
      ImGui.EndChild( ctx)
    end
    
    UI.draw_Rack_Pads_controls_levels(note_t,note, x,y,w,h) 
    
  end
  --------------------------------------------------------------------------------  
  function UI.draw_Rack_Pads_controls_levels(note_t,note, x,y,w,h)
    local peak_w = 5
    if not (DATA.children[note] and DATA.children[note].peaksRMS_L) then return end
    local peaksRMS_L = DATA.children[note].peaksRMS_L  
    local peaksRMS_R = DATA.children[note].peaksRMS_R 
    
    local peakH = UI.calc_rack_padnameH-UI.calc_itemH
    local peakLx = x+w-peak_w*2
    local peakLy = y+UI.calc_itemH+peakH*(1-math.min(peaksRMS_L,1))
    ImGui.DrawList_AddRectFilled( UI.draw_list, peakLx, peakLy , peakLx+peak_w, y+UI.calc_rack_padnameH, (EXT.UI_colRGBA_maintheme_color&0xFFFFFF00)|0xFF, 0, ImGui.DrawFlags_RoundCornersTop)
    if peaksRMS_L >0.9 then ImGui.DrawList_AddLine( UI.draw_list, peakLx, y+UI.calc_itemH , peakLx+peak_w, y+UI.calc_itemH, 0xFF0000FF, 1) end
    
    local peakH = UI.calc_rack_padnameH-UI.calc_itemH
    local peakRx = x+w-peak_w-2
    local peakRy = y+UI.calc_itemH+peakH*(1-math.min(peaksRMS_R,1))
    ImGui.DrawList_AddRectFilled( UI.draw_list, peakRx, peakRy , peakRx+peak_w, y+UI.calc_rack_padnameH, (EXT.UI_colRGBA_maintheme_color&0xFFFFFF00)|0xFF, 0, ImGui.DrawFlags_RoundCornersTop)
    if peaksRMS_R >0.9 then ImGui.DrawList_AddLine( UI.draw_list, peakRx, y+UI.calc_itemH , peakRx+peak_w, y+UI.calc_itemH, 0xFF0000FF, 1) end
  end
  
  -------------------------------------------------------------------------------- 
  function UI.draw_popups_macro()
    if DATA.trig_context == 'macro' and DATA.parent_track and DATA.parent_track.ext and DATA.parent_track.ext.PARENT_LASTACTIVEMACRO  then 
      local macroID = DATA.parent_track.ext.PARENT_LASTACTIVEMACRO
      ImGui.SeparatorText(ctx, 'Macro '..macroID)
      -- name
      local custom_name = ''
      if DATA.parent_track.ext and DATA.parent_track.ext.PARENT_MACROEXT and DATA.parent_track.ext.PARENT_MACROEXT[macroID] and DATA.parent_track.ext.PARENT_MACROEXT[macroID].custom_name then custom_name = DATA.parent_track.ext.PARENT_MACROEXT[macroID].custom_name end
      local retval, buf = ImGui.InputText( ctx, 'Macro name', custom_name, ImGui.InputTextFlags_None )--ImGui.InputTextFlags_EnterReturnsTrue
      if retval then 
        if not DATA.parent_track.ext.PARENT_MACROEXT then DATA.parent_track.ext.PARENT_MACROEXT = {} end
        if not DATA.parent_track.ext.PARENT_MACROEXT[macroID] then DATA.parent_track.ext.PARENT_MACROEXT[macroID] = {} end
        if buf == '' then DATA.parent_track.ext.PARENT_MACROEXT[macroID].custom_name = nil else DATA.parent_track.ext.PARENT_MACROEXT[macroID].custom_name = buf end
        DATA:WriteData_Parent() 
      end
      -- col rgb
      local col_current = 0
      if DATA.parent_track.ext.PARENT_MACROEXT and DATA.parent_track.ext.PARENT_MACROEXT[macroID] and DATA.parent_track.ext.PARENT_MACROEXT[macroID].col_rgb then
        col_current = DATA.parent_track.ext.PARENT_MACROEXT[macroID].col_rgb
      end
      local retval, col_rgb = ImGui_ColorEdit3( ctx, 'Macro '..macroID..' color', col_current, ImGui.ColorEditFlags_None|ImGui.ColorEditFlags_NoInputs|ImGui.ColorEditFlags_NoAlpha )
      if retval then
        if not DATA.parent_track.ext.PARENT_MACROEXT then DATA.parent_track.ext.PARENT_MACROEXT = {} end
        if not DATA.parent_track.ext.PARENT_MACROEXT[macroID] then DATA.parent_track.ext.PARENT_MACROEXT[macroID] = {} end
        DATA.parent_track.ext.PARENT_MACROEXT[macroID].col_rgb = col_rgb
        DATA:WriteData_Parent() 
        --ImGui.CloseCurrentPopup(ctx) 
      end
      
      ImGui.SeparatorText(ctx, 'Parameter links')
      if ImGui.Button(ctx,'Add last touched parameter',-1) then 
        Undo_BeginBlock2(DATA.proj )
        DATA:Macro_AddLink()
        Undo_EndBlock2( DATA.proj , 'RS5k manager - Macro - add link', 0xFFFFFFFF )
      end
      if ImGui.Button(ctx,'Clear all links',-1) then 
        Undo_BeginBlock2(DATA.proj )
        DATA:Macro_ClearLink()
        Undo_EndBlock2( DATA.proj , 'RS5k manager - Macro - clear links', 0xFFFFFFFF )
      end 
      ImGui.SeparatorText(ctx, 'MIDI/OSC bindings') 
      
      local retval1, rawmsg, tsval, devIdx, projPos, projLoopCnt = MIDI_GetRecentInputEvent(0)
      local str = ''
      local valid
      if retval1 then 
        local midi2 = rawmsg:byte(2)
        local midi1 = rawmsg:byte(1)  
        if midi1 and midi2 and  midi1&0xB0==0xB0 then valid = true str = 'CC chan'..(1+(midi1&0x0F)*15)..' / CC#'
         --elseif midi1&0x90==0x90 then valid = true str = 'NoteOn '..(1+(midi1&0x0F)*15)..' / Pitch'
         --elseif midi1&0x80==0x80 then valid = true str = 'NoteOn '..(1+(midi1&0x0F)*15)..' / Pitch'
        end
        if str ~='' then str = str..' '..midi2 end
      end
      
      if valid~= true then str = '[not found/not available]' end
      if valid == true then
        if ImGui.Button(ctx,'Bind to: '..str,-1) then DATA:Action_LearnController(DATA.parent_track.ptr, DATA.parent_track.macro.pos, macroID) end 
       else
        ImGui.BeginDisabled(ctx, true)ImGui.Button(ctx,'Bind to: '..str,-1) ImGui.EndDisabled(ctx)
      end
      if ImGui.Button(ctx,'Open native "Learn" window',-1) then
        TrackFX_SetNamedConfigParm(DATA.parent_track.ptr, DATA.parent_track.macro.pos,'last_touched' ,macroID) 
        Main_OnCommand(41144,0) -- FX: Set MIDI learn for last touched FX parameter
      end
      if ImGui.Button(ctx,'Clear bindings',-1) then 
        local clear = true
        DATA:Action_LearnController(DATA.parent_track.ptr, DATA.parent_track.macro.pos, macroID,clear )
      end 
      
      
    end
  end
  -------------------------------------------------------------------------------- 
  function UI.draw_chokecombo(note)
    
    if DATA.allow_container_usage ~= true then ImGui.BeginDisabled(ctx, true) end
    
    ImGui.SeparatorText(ctx, 'Choke setup')
    ImGui.Indent(ctx, 10)
    local preview = 'Cut by '
    for note_src in spairs(DATA.children) do
      if DATA.MIDIbus.choke_setup[note] and DATA.MIDIbus.choke_setup[note][note_src] and DATA.MIDIbus.choke_setup[note][note_src].exist == true then
        preview = preview..note_src..' '
      end
    end
    
    -- clear
    if ImGui.Button(ctx, 'Clear choke setup',-1) then 
      if DATA.MIDIbus.choke_setup[note] then 
        for note_src in pairs(DATA.MIDIbus.choke_setup[note]) do
          if DATA.MIDIbus.choke_setup[note][note_src].exist == true then DATA.MIDIbus.choke_setup[note][note_src].mark_for_remove = true end
        end
      end
      DATA:Choke_Write()
    end
    
    reaper.ImGui_SetNextItemWidth(ctx,-1)
    
    if ImGui.BeginCombo(ctx, '##choke_combo',preview) then 
      for note_src in spairs(DATA.children) do
        if note_src ~= note then 
          local padname = DATA.children[note_src].P_NAME
          local state = DATA.MIDIbus.choke_setup[note] and DATA.MIDIbus.choke_setup[note][note_src] and DATA.MIDIbus.choke_setup[note][note_src].exist == true
          if ImGui.Checkbox(ctx, note_src..' - '..padname..'##choke'..note_src..'note'..note, state) then
            if state == true then -- exist
              DATA.MIDIbus.choke_setup[note][note_src].mark_for_remove = true
             else
              if not DATA.MIDIbus.choke_setup[note] then DATA.MIDIbus.choke_setup[note] = {} end
              if not DATA.MIDIbus.choke_setup[note][note_src] then DATA.MIDIbus.choke_setup[note][note_src] = {add = true} end 
            end
            DATA:Choke_Write()
          end
        end
      end
      ImGui.EndCombo(ctx)
    end
    ImGui.Unindent(ctx, 10)
    
    if DATA.allow_container_usage ~= true then ImGui.EndDisabled(ctx) end
  end
  -------------------------------------------------------------------------------- 
  function UI.draw_popups_pad()
    if DATA.trig_context == 'pad' and DATA.parent_track and DATA.parent_track.ext and DATA.parent_track.ext.PARENT_LASTACTIVENOTE  then 
      ImGui.SeparatorText(ctx, 'Pad '..DATA.parent_track.ext.PARENT_LASTACTIVENOTE)
      
      -- local Rename
      ImGui.Indent(ctx, 10)
      local retval, buf = ImGui_InputText( ctx, '##custpadnameinputparent', DATA.parent_track.padcustomnames_overrides[DATA.parent_track.ext.PARENT_LASTACTIVENOTE], ImGui_InputTextFlags_None() )
      if retval then 
        DATA.parent_track.padcustomnames_overrides[DATA.parent_track.ext.PARENT_LASTACTIVENOTE] = buf
        DATA:WriteData_Parent() 
        DATA.upd = true
      end
      ImGui.Unindent(ctx, 10) 
      
      -- Remove
      local note = DATA.parent_track.ext.PARENT_LASTACTIVENOTE 
      ImGui.Indent(ctx, 10)
      ImGui.PushStyleColor(ctx, ImGui.Col_Button,0xFF50507F )
      ImGui.PushStyleColor(ctx, ImGui.Col_ButtonActive,0xFF5050FF )
      ImGui.PushStyleColor(ctx, ImGui.Col_ButtonHovered,0xFF50509F )
      if ImGui.Button(ctx, 'Remove pad content',-1) then
        DATA:Sampler_RemovePad(note) 
        ImGui.CloseCurrentPopup(ctx) 
      end
      ImGui.PopStyleColor(ctx,3)
      ImGui.Unindent(ctx, 10) 
      --Import
      ImGui.SeparatorText(ctx, 'Import media items')
      ImGui.Indent(ctx, 10)
      if ImGui.Button(ctx, 'Import selected items, starting this pad',0) then
        DATA:Sampler_ImportSelectedItems()
        ImGui.CloseCurrentPopup(ctx) 
      end
      if ImGui.Checkbox(ctx, 'Remove source item from track', EXT.CONF_importselitems_removesource==1) then EXT.CONF_importselitems_removesource=EXT.CONF_importselitems_removesource~1 EXT:save() end
      ImGui.Unindent(ctx, 10) 
      -- import last touched fx
      ImGui.SeparatorText(ctx, 'Import FX to pad')
      ImGui.Indent(ctx, 10) 
      UI.draw_3rdpartyimport_context(note)  
      ImGui.Unindent(ctx, 10)
      
      -- choke
      UI.draw_chokecombo(note)
    end
  end
  -------------------------------------------------------------------------------- 
  function UI.draw_popups() 
    if DATA.trig_openpopup then 
      ImGui.OpenPopup( ctx, 'mainRCmenu', ImGui.PopupFlags_None )
      DATA.trig_context = DATA.trig_openpopup 
      DATA.trig_openpopup = nil
    end
    
  
    local round = 4
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_FrameRounding, round)
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_ChildRounding, round)
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_PopupRounding, round)
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowRounding, round)
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_ButtonTextAlign, 0,0.5)
    
  
    -- draw content
    -- (from reaimgui demo) Always center this window when appearing
    --local center_x, center_y = ImGui.Viewport_GetCenter(ImGui.GetWindowViewport(ctx))
    local windw = 300--DATA.display_w*0.3
    local windh = 300--DATA.display_h*0.5
    local center_x, center_y = ImGui.GetMouseClickedPos( ctx,ImGui.MouseButton_Right  )
    --ImGui.SetNextWindowPos(ctx, center_x+windw/2-25, center_y+windh/2-10, ImGui.Cond_Appearing, 0.5, 0.5)
    ImGui.SetNextWindowPos(ctx, center_x-25, center_y-10, ImGui.Cond_Appearing, 0, 0)
    ImGui.SetNextWindowSize(ctx, 0, 0, ImGui.Cond_Always)
    if ImGui.BeginPopup(ctx, 'mainRCmenu',ImGui.WindowFlags_AlwaysAutoResize|ImGui.ChildFlags_Border) then 
       
      UI.draw_popups_pad()
      UI.draw_popups_macro() 
      UI.draw_popups_rs5k_ctrl()
      
      if DATA.trig_closepopup == true then ImGui.CloseCurrentPopup(ctx) DATA.trig_closepopup = nil end
      ImGui.EndPopup(ctx)
    end 
  
    ImGui.PopStyleVar(ctx, 5)
  end  
  -------------------------------------------------------------------------------- 
  function UI.draw_popups_rs5k_ctrl()  
    
    if not (DATA.trig_context == 'rs5k_ctrl' and DATA.parent_track and DATA.parent_track.ext and DATA.parent_track.ext.PARENT_LASTACTIVENOTE) then return end 
    
    local note =  DATA.parent_track.ext.PARENT_LASTACTIVENOTE
    local layer =  DATA.parent_track.ext.PARENT_LASTACTIVENOTE_LAYER 
    
    if not (DATA.parent_track.macro and DATA.parent_track.macro.sliders) then 
      reaper.ImGui_TextDisabled(ctx, 'Macro links')
      return 
    end
    
    
    local track, fx, param
    if DATA.children[note] and DATA.children[note].layers and DATA.children[note].layers[layer] then
      track =    DATA.children[note].layers[layer].tr_ptr
      fx = DATA.children[note].layers[layer].instrument_pos
    end 
    
    if DATA.trig_openpopup_context == 'gain' then param = DATA.children[note].layers[layer].instrument_volID end 
    if DATA.trig_openpopup_context == 'attack' then param = DATA.children[note].layers[layer].instrument_attackID end
    if DATA.trig_openpopup_context == 'decay' then param = DATA.children[note].layers[layer].instrument_decayID end 
    if DATA.trig_openpopup_context == 'sustain' then param = DATA.children[note].layers[layer].instrument_sustainID end 
    if DATA.trig_openpopup_context == 'release' then param = DATA.children[note].layers[layer].instrument_releaseID end
    
    local destslider
    for slider in pairs(DATA.parent_track.macro.sliders) do
      if DATA.parent_track.macro.sliders[slider].links then 
        for link in pairs(DATA.parent_track.macro.sliders[slider].links) do
          local t = DATA.parent_track.macro.sliders[slider].links[link].note_layer_t
          if t.noteID == note and t.layerID == layer then
            local param_dest = DATA.parent_track.macro.sliders[slider].links[link].param_dest
            if param_dest == param  then
              destslider = slider
              break
            end
          end
        end
      end
    end
    
    if destslider then
      ImGui.SeparatorText(ctx, 'Pad '..DATA.parent_track.ext.PARENT_LASTACTIVENOTE..': '..DATA.trig_openpopup_context)  
      if ImGui.Button(ctx,'Remove from macro '..destslider) then 
        Undo_BeginBlock2(DATA.proj )
        TrackFX_SetNamedConfigParm(track, fx, 'param.'..param..'plink.active', 0)
        Undo_EndBlock2( DATA.proj , 'RS5k manager - Remove link', 0xFFFFFFFF ) 
        ImGui.CloseCurrentPopup(ctx)
      end 
    end
    
    ImGui.SeparatorText(ctx, 'Link to macro')
    for macro = 1, DATA.parent_track.ext.PARENT_MACROCNT do
      if not destslider or (destslider and macro ~= destslider) then
        if ImGui.Selectable(ctx,'Link to macro '..macro) then 
          TrackFX_SetNamedConfigParm( track, fx, 'last_touched',param )
          DATA.parent_track.ext.PARENT_LASTACTIVEMACRO = macro
          DATA:Macro_AddLink()
          ImGui.CloseCurrentPopup(ctx)
        end
      end
    end
    
  end
  --------------------------------------------------------------------------------  
  function UI.draw_tabs_Sampler_trackparams()
    local butw = 40
    local butw_3x = (butw)*3+UI.spacingX*2
    if not (DATA.parent_track and DATA.parent_track.valid == true) then return end
    
    local note_layer_t,note,layer = DATA:Sampler_GetActiveNoteLayer() if not note_layer_t then return end 
    if DATA.children[note].TYPE_DEVICE then note_layer_t = DATA.children[note] end
    
    
    curposx_abs, curposy_abs = reaper.ImGui_GetCursorScreenPos(ctx)
    
    UI.draw_knob(
      {str_id = '##spl_trvol',
      is_small_knob = true,
      val = math.min(1,note_layer_t.D_VOL/2), 
      default_val = 0.5,
      x = curposx_abs, 
      y = curposy_abs,
      w = UI.calc_knob_w_small,
      h = UI.calc_knob_h_small,
      name = 'Volume',
      val_form = note_layer_t.D_VOL_format,
      appfunc_atclick = function(v)   end,
      appfunc_atdrag = function(v)  
        note_layer_t.D_VOL =v *2
        note_layer_t.D_VOL_format =  DATA:CollectData_FormatVolume(note_layer_t.D_VOL)  
        SetMediaTrackInfo_Value( note_layer_t.tr_ptr, 'D_VOL', v *2 )
      end,
      parseinput = function(str_in)
        if not str_in then return end
        if tonumber(str_in) then 
          local out  = VF_lim(WDL_DB2VAL( tonumber(str_in)),0,2)
          SetMediaTrackInfo_Value( note_layer_t.tr_ptr, 'D_VOL',out )
          DATA.upd = true
        end
      end,
      })

      
      
  end
  --------------------------------------------------------------------------------  
  function UI.draw_tabs()
    if UI.hide_tabs == true then return end
    if not (DATA.parent_track and DATA.parent_track.ext) then return end
    
    ImGui.SetCursorPos(ctx, UI.calc_settingsX,UI.calc_settingsY)
    --local xabs,yabs = ImGui.GetCursorScreenPos(ctx)
    --ImGui.SetCursorScreenPos(ctx,xabs,UI.calc_settingsY)
    
    local tabW = -1
    local cur_w = DATA.display_w - ImGui.GetCursorPosX(ctx)
    if cur_w > UI.settingsfixedW then tabW = UI.settingsfixedW end
    if ImGui.BeginChild( ctx, 'tabs', tabW, 0, ImGui.ChildFlags_None , ImGui.WindowFlags_None|ImGui.WindowFlags_NoScrollbar) then --|ImGui.ChildFlags_Border
      if ImGui.BeginTabBar( ctx, 'tabsbar', ImGui.TabItemFlags_None ) then
        
        function __f_tabs() end
        
        
        if ImGui.BeginTabItem( ctx, 'Sampler', false, ImGui.TabItemFlags_None ) then UI.tab_context = 'Sampler' UI.draw_tabs_Sampler()  ImGui.EndTabItem( ctx)  end 
        if ImGui.BeginTabItem( ctx, 'Macro', false, ImGui.TabItemFlags_None ) then UI.tab_context = 'Macro' UI.draw_tabs_macro() ImGui.EndTabItem( ctx)  end 
        if ImGui.BeginTabItem( ctx, 'Settings', false, ImGui.TabItemFlags_None ) then UI.tab_context = 'Settings' UI.draw_tabs_settings() ImGui.EndTabItem( ctx)  end 
        if ImGui.BeginTabItem( ctx, 'Actions', false, ImGui.TabItemFlags_None ) then UI.tab_context = 'Actions' UI.draw_tabs_Actions() ImGui.EndTabItem( ctx)  end 
        
           
        -- draw seq button
          local steseqavailable
          if DATA.stepseq_ID then steseqavailable = true end
          local xoffs = 300
          local wbut = 100
          ImGui.SetCursorPos(ctx,xoffs,0)
          if ImGui.InvisibleButton(ctx, 'mode', wbut, 20) then 
            --[[if steseqavailable == true then 
              Main_OnCommand(DATA.stepseq_ID,0) else ReaPack_BrowsePackages( 'RS5k_StepSequencer' ) 
            end ]]
          end
          
          x1, y1 = reaper.ImGui_GetItemRectMin( ctx )
          x2, y2 = reaper.ImGui_GetItemRectMax( ctx )
          local checkbox_h = 16
          local checkbox_r = math.floor(checkbox_h / 2)
          local center_x = x1
          local center_y = math.floor(y1 + (y2-y1)/2 )-1
          local colfill = 0xF0F0F04F
          if steseqavailable == true and ImGui_IsItemHovered(ctx) then colfill = 0xF0F0F09F end
          ImGui.DrawList_AddCircle( UI.draw_list, center_x, center_y, checkbox_r, 0xF0F0F07F, 0, 2 )
          ImGui.DrawList_AddCircleFilled( UI.draw_list, center_x, center_y, checkbox_r-3, colfill, 0 ) 
          ImGui.SetCursorPos(ctx,xoffs+checkbox_r+ UI.spacingX,2)
          if steseqavailable == true then ImGui.Text(ctx, 'StepSequencer') else ImGui.TextDisabled(ctx, 'StepSequencer') end
            
        
        
        ImGui.EndTabBar( ctx)
      end
      
        
      ImGui.Dummy(ctx,0,0)
      
      
      ImGui.EndChild( ctx)
    end
  end 
  --------------------------------------------------------------------------------  
  function UI.Link(txt, url)
    local color = ImGui.GetStyleColor(ctx, ImGui.Col_CheckMark)
    ImGui.Button(ctx, txt)
    if ImGui.IsItemClicked(ctx) then
      VF_Open_URL(url)
    elseif ImGui.IsItemHovered(ctx) then
      ImGui.SetMouseCursor(ctx, ImGui.MouseCursor_Hand)
    end
  end
  --------------------------------------------------------------------------------  
  function UI.draw_tabs_macro()
    if not DATA.parent_track.valid == true then return end
    
    local MACRO_GUID = DATA.parent_track.ext.PARENT_MACRO_GUID   
    if not (MACRO_GUID and MACRO_GUID~='') then 
      if ImGui.Button(ctx, 'Init macro on parent track') then DATA:Macro_InitChildrenMacro() end
      return 
    end
    
    
    if not (DATA.parent_track.macro and DATA.parent_track.macro.sliders) then return end
    
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowPadding,0,0)  
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_ItemSpacing,0,0)  
    local macro_w = UI.calc_knob_w_small
    local macro_h = UI.calc_macro_h
    local curposx, curposy = ImGui.GetCursorScreenPos(ctx)
    local lane_in_row = 8
    for sliderID = 1, 16 do--#DATA.parent_track.macro.sliders do 
      if DATA.parent_track.macro.sliders[sliderID] then 
        local x = curposx + (macro_w+UI.spacingX) * ((sliderID-1)%lane_in_row)
        local y = curposy + (macro_h+UI.spacingY) * math.floor((sliderID-1)/lane_in_row)
        local colfill_rgb 
        if DATA.parent_track.ext.PARENT_MACROEXT and DATA.parent_track.ext.PARENT_MACROEXT[sliderID] and DATA.parent_track.ext.PARENT_MACROEXT[sliderID].col_rgb then colfill_rgb = DATA.parent_track.ext.PARENT_MACROEXT[sliderID].col_rgb end
          
        local name = 'Macro '..sliderID
        if DATA.parent_track.ext.PARENT_MACROEXT and DATA.parent_track.ext.PARENT_MACROEXT[sliderID] and DATA.parent_track.ext.PARENT_MACROEXT[sliderID].custom_name then name = DATA.parent_track.ext.PARENT_MACROEXT[sliderID].custom_name end
          
        UI.draw_knob(
          {str_id = '##slider'..sliderID,
          is_selected = (DATA.parent_track and DATA.parent_track.ext and DATA.parent_track.ext.PARENT_LASTACTIVEMACRO and DATA.parent_track.ext.PARENT_LASTACTIVEMACRO  == sliderID),
          val = DATA.parent_track.macro.sliders[sliderID].val,
          x = x, 
          y = y,
          w =macro_w,
          h = macro_h,
          colfill_rgb = colfill_rgb,
          name = name, 
          customfont = DATA.font4,
          active_name = DATA.parent_track.macro.sliders[sliderID].has_links ,
          appfunc_atclick = function(v) 
                                  DATA.parent_track.ext.PARENT_LASTACTIVEMACRO = sliderID
                                  DATA:WriteData_Parent()  
                                end,
          appfunc_atclickR = function(v) 
                                  DATA.parent_track.ext.PARENT_LASTACTIVEMACRO = sliderID
                                  DATA:WriteData_Parent()  
                                  DATA.upd = true
                                  if UI.anypopupopen==true then DATA.trig_closepopup = true else DATA.trig_openpopup = 'macro' end
                                end,
          appfunc_atdrag = function(v) DATA.parent_track.macro.sliders[sliderID].val = v TrackFX_SetParamNormalized( DATA.parent_track.ptr, DATA.parent_track.macro.pos, sliderID, v )   end,
          appfunc_atclick_name= function()
                                  DATA.parent_track.ext.PARENT_LASTACTIVEMACRO = sliderID
                                  DATA:WriteData_Parent() 
                                end,
          appfunc_atclick_nameR= function()
                                  DATA.parent_track.ext.PARENT_LASTACTIVEMACRO = sliderID
                                  DATA:WriteData_Parent()  
                                  DATA.upd = true
                                  if UI.anypopupopen==true then DATA.trig_closepopup = true else DATA.trig_openpopup = 'macro' end
                                end,            
          }) 
        ImGui.SameLine(ctx)
      end
    end
    
    
    
    
    ImGui.PopStyleVar(ctx,2)
    ImGui.SetCursorScreenPos(ctx,curposx, curposy+UI.calc_macro_h*2+UI.spacingY*2)
    UI.draw_tabs_macro_links()
  end
  --------------------------------------------------------------------------------  
  function UI.draw_tabs_macro_links_SetParams(UI_min,UI_max,link_t,note_layer_t)
    TrackFX_SetNamedConfigParm(note_layer_t.tr_ptr, link_t.fx_dest, 'param.'..link_t.param_dest..'plink.offset', 0)  
    TrackFX_SetNamedConfigParm(note_layer_t.tr_ptr, link_t.fx_dest, 'param.'..link_t.param_dest..'mod.baseline', UI_min) 
    
    local ret, baseline = TrackFX_GetNamedConfigParm(note_layer_t.tr_ptr, link_t.fx_dest, 'param.'..link_t.param_dest..'mod.baseline')  baseline = tonumber(baseline)
    local ret, scale = TrackFX_GetNamedConfigParm(note_layer_t.tr_ptr, link_t.fx_dest, 'param.'..link_t.param_dest..'plink.scale')  scale = tonumber(scale)
    
    if baseline + scale < 0 or baseline + scale > 1 then 
      UI_max = VF_lim(baseline + scale)
      TrackFX_SetNamedConfigParm(note_layer_t.tr_ptr, link_t.fx_dest, 'param.'..link_t.param_dest..'plink.scale', UI_max - baseline)  
     else
      TrackFX_SetNamedConfigParm(note_layer_t.tr_ptr, link_t.fx_dest, 'param.'..link_t.param_dest..'plink.scale', UI_max - baseline)  
    end
  end
  --------------------------------------------------------------------------------  
  function UI.draw_tabs_macro_links()
    local indent= 20
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowPadding,UI.spacingX,UI.spacingY)  
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_ItemSpacing,UI.spacingX,UI.spacingY)  
    --ImGui.SetCursorPos(ctx, 0,0)
    
      
      
    -- link list
    if ImGui.BeginChild( ctx, 'macrolinks', 0, 0, ImGui.ChildFlags_None|ImGui.ChildFlags_Border, ImGui.WindowFlags_None ) then--|ImGui.ChildFlags_Border --|ImGui.WindowFlags_MenuBar-- |ImGui.WindowFlags_NoScrollbar -- UI.calc_rackW
    
      
      
      
      if (DATA.parent_track.ext and DATA.parent_track.ext.PARENT_LASTACTIVEMACRO) then
        
        local macroID = DATA.parent_track.ext.PARENT_LASTACTIVEMACRO
        if DATA.parent_track.macro.sliders[macroID] and DATA.parent_track.macro.sliders[macroID].links then
          for linkID = 1, #DATA.parent_track.macro.sliders[macroID].links do

          local link_t = DATA.parent_track.macro.sliders[macroID].links[linkID] 
          local note_layer_t= link_t.note_layer_t
          local note = note_layer_t.noteID or 0
          local layer = note_layer_t.layerID or 1
          local P_NAME = note_layer_t.P_NAME or ''
          
          --[[ name
          UI.Tools_setbuttonbackg()
          ImGui.Button(ctx, P_NAME..' [N'..note..' L'..layer..'] - '..DATA.parent_track.macro.sliders[macroID].links[linkID].param_name)
          UI.Tools_unsetbuttonstyle()]]
          
          local linkname = P_NAME..' [N'..note..' L'..layer..'] - '..DATA.parent_track.macro.sliders[macroID].links[linkID].param_name
          
            if ImGui.TreeNode(ctx, linkname, ImGui.TreeNodeFlags_None) then  
              
              --ImGui.Indent(ctx,indent)
            
              --[[ offset
              ImGui.SetNextItemWidth(ctx, 80)
              local formatIn = math.floor(link_t.plink_offset*100)..'%%'
              local retval, v = ImGui_SliderDouble( ctx, 'Offset##offs'..linkID, link_t.plink_offset, -1, 1, formatIn )
              if retval then TrackFX_SetNamedConfigParm(note_layer_t.tr_ptr, link_t.fx_dest, 'param.'..link_t.param_dest..'plink.offset', v) DATA.upd = true end 
              
              -- scale
              ImGui.SameLine(ctx)
              ImGui.SetNextItemWidth(ctx, 80)
              local formatIn = math.floor(link_t.plink_scale*100)..'%%'
              local retval, v = ImGui_SliderDouble( ctx, 'Scale##scale'..linkID, link_t.plink_scale, -1, 1, formatIn )
              if retval then TrackFX_SetNamedConfigParm(note_layer_t.tr_ptr, link_t.fx_dest, 'param.'..link_t.param_dest..'plink.scale', v) DATA.upd = true end     
              ImGui.SameLine(ctx)]]
              
              
              
              -- min
              ImGui.SetNextItemWidth(ctx, 80)
              local retval, v = ImGui_SliderDouble( ctx, 'Min##UI_min'..linkID, link_t.UI_min, 0, 1, '%.3f' )
              if retval then
                v = VF_lim(v,link_t.UI_max)
                UI.draw_tabs_macro_links_SetParams(v,link_t.UI_max,link_t,note_layer_t)
                DATA.upd = true 
              end 
              -- max
              ImGui.SameLine(ctx)
              ImGui.SetNextItemWidth(ctx, 80)
              local retval, v = ImGui_SliderDouble( ctx, 'Max##UI_max'..linkID, link_t.UI_max, 0, 1, '%.3f' )
              if retval then 
                v = VF_lim(v)
                UI.draw_tabs_macro_links_SetParams(link_t.UI_min,v,link_t,note_layer_t)
                DATA.upd = true 
              end 
              
              -- min format
              local buf = link_t.UI_min 
              local noteT = link_t.note_layer_t
              local track = noteT.tr_ptr
              local retval, buf1 = reaper.TrackFX_FormatParamValue( track, link_t.fx_dest, link_t.param_dest, link_t.UI_min )
              if retval then 
                ImGui.SetNextItemWidth(ctx, 80)
                local retval, v = ImGui.InputText( ctx, 'Min##UI_minformat'..linkID, buf1, ImGui.InputTextFlags_None )
                if retval and v ~= '' then 
                  local valout = VF_BFpluginparam(v, track, link_t.fx_dest, link_t.param_dest)
                  if valout then 
                    UI.draw_tabs_macro_links_SetParams(valout,link_t.UI_max,link_t,note_layer_t)
                  end
                end
              end
              -- max format
              local buf = link_t.UI_max
              local noteT = link_t.note_layer_t
              local track = noteT.tr_ptr
              local retval, buf1 = reaper.TrackFX_FormatParamValue( track, link_t.fx_dest, link_t.param_dest, link_t.UI_max )
              if retval then 
                ImGui.SameLine(ctx)
                ImGui.SetNextItemWidth(ctx, 80)
                local retval, v = ImGui.InputText( ctx, 'Max##UI_maxformat'..linkID, buf1, ImGui.InputTextFlags_None )
                if retval and v ~= '' then 
                  local valout = VF_BFpluginparam(v, track, link_t.fx_dest, link_t.param_dest)
                  if valout then 
                    UI.draw_tabs_macro_links_SetParams(link_t.UI_min,valout,link_t,note_layer_t)
                  end
                end
              end
              
              
              
              -- remove
              if ImGui.Button(ctx, 'Remove##rem'..linkID) then
                Undo_BeginBlock2(DATA.proj )
                TrackFX_SetNamedConfigParm(note_layer_t.tr_ptr, link_t.fx_dest, 'param.'..link_t.param_dest..'plink.active', 0)
                Undo_EndBlock2( DATA.proj , 'RS5k manager - Remove link', 0xFFFFFFFF ) 
                DATA.upd = true
              end
              
              -- Mod
              ImGui.SameLine(ctx)
              if ImGui.Button(ctx, 'Mod##modshow'..linkID) then
                TrackFX_SetNamedConfigParm(note_layer_t.tr_ptr, link_t.fx_dest, 'param.'..link_t.param_dest..'mod.visible', 1)
              end            
            
              --ImGui.Unindent(ctx,indent)
              ImGui.TreePop(ctx)
            end
          end
        end
      end 
      
      
      ImGui.Dummy(ctx,0,10)
      
      ImGui.EndChild( ctx)
    end
    ImGui.PopStyleVar(ctx,2)
  end
    ------------------------------------------------------------------------------ 
  function UI.draw_knob(knob_t)
    local debug = 0
    local x,y,w,h = knob_t.x,knob_t.y,knob_t.w,knob_t.h
    local name  = knob_t.name 
    local disabled  = knob_t.disabled 
    local centered  = knob_t.centered 
    local val_form  = knob_t.val_form or '' 
    local str_id  = knob_t.str_id 
    local draw_macro_index  = knob_t.draw_macro_index 
    local is_micro_knob  = knob_t.is_micro_knob 
    local yoffsarc  = knob_t.yoffsarc  or 0
    
    local val_max = knob_t.val_max or 1
    local val_min = knob_t.val_min or 0
    
    ImGui.SetCursorScreenPos(ctx,x,y) 
    local curposx, curposy = ImGui.GetCursorScreenPos(ctx)
    
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowPadding,UI.spacingX, UI.spacingY) 
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_FramePadding,0,UI.spacingY) 
    
    -- size 
      local knobname_h = UI.calc_itemH
      local knobctrl_h = h- knobname_h-      UI.spacingY
      if not knob_t.customfont then ImGui.PushFont(ctx, DATA.font3) else ImGui.PushFont(ctx, knob_t.customfont)  end
      if knob_t.is_small_knob == true then  
        knobname_h = UI.calc_itemH
        knobctrl_h = h- knobname_h-UI.spacingY -UI.calc_itemH
      end
      if is_micro_knob== true then
        knobname_h = 0
        knobctrl_h = h
        yoffsarc = 1
      end
    -- name background 
    
      if is_micro_knob~= true then
        local color
        if knob_t and knob_t.I_CUSTOMCOLOR then 
          color = ImGui.ColorConvertNative(knob_t.I_CUSTOMCOLOR) 
          color = color & 0x1000000 ~= 0 and (color << 8) | 0xFF-- https://forum.cockos.com/showpost.php?p=2799017&postcount=6
        end
        if knob_t and knob_t.colfill_rgb then color = (knob_t.colfill_rgb << 8) | 0xFF end
        if color then 
          ImGui.DrawList_AddRectFilled( UI.draw_list, x+1, y, x+w-1, y+knobname_h, color, 5, ImGui.DrawFlags_RoundCornersTop)
         else 
          if knob_t.active_name == true then
            ImGui.DrawList_AddRectFilled( UI.draw_list, x+1, y, x+w-1, y+knobname_h, EXT.UI_colRGBA_paddefaultbackgr, 5, ImGui.DrawFlags_RoundCornersTop) 
           else
            ImGui.DrawList_AddRectFilled( UI.draw_list, x+1, y, x+w-1, y+knobname_h, EXT.UI_colRGBA_paddefaultbackgr_inactive, 5, ImGui.DrawFlags_RoundCornersTop) 
          end
        end   
      end
    
    -- draw_macro_index
      if draw_macro_index and is_micro_knob~= true then
        local szidx = 8
        ImGui.DrawList_AddTriangleFilled( UI.draw_list, 
          x+w-szidx, y+knobname_h, 
          x+w-1, y+knobname_h, 
          x+w-1, y+knobname_h+szidx, 
          0x00FF00F0)
      end
    
    -- frame / selection  
      if knob_t.is_selected == true  then 
        ImGui.DrawList_AddRect( UI.draw_list, x, y, x+w, y+h, (EXT.UI_colRGBA_maintheme_color&0xFFFFFF00)|0x90, 5, ImGui.DrawFlags_None|ImGui.DrawFlags_RoundCornersAll, 1 )
       else
        ImGui.DrawList_AddRect( UI.draw_list, x, y, x+w, y+h, 0x0000005F              , 5, ImGui.DrawFlags_None|ImGui.DrawFlags_RoundCornersAll, 1 )
      end  
      
      
      if debug ~= 1 then UI.Tools_setbuttonbackg() end
      
      
      local local_pos_x, local_pos_y = ImGui.GetCursorPos( ctx )
      
    -- name  
      if is_micro_knob~= true then
        ImGui.SetCursorPos( ctx, local_pos_x, local_pos_y )
        ImGui.Button(ctx,'##slider_name'..str_id,w ,knobname_h ) 
        if ImGui.IsItemClicked(ctx, ImGui.MouseButton_Left)then
          if knob_t.appfunc_atclick_name then knob_t.appfunc_atclick_name() end
        end
        if ImGui.IsItemClicked(ctx, ImGui.MouseButton_Right)then
          if knob_t.appfunc_atclick_nameR then knob_t.appfunc_atclick_nameR() end
        end
      end
      
    -- control
      ImGui.SetCursorPos( ctx, local_pos_x, local_pos_y+knobname_h )
      ImGui.Button(ctx,'##slider_name2'..str_id,w ,knobctrl_h) 
      UI.draw_knob_handlelatchstate(knob_t)
      local item_w, item_h = reaper.ImGui_GetItemRectSize( ctx )
      
      
       
    
    local val =  0
    if knob_t.val and knob_t.val then val = knob_t.val end
    if not val then return end
    local norm_val = (val - val_min) / (val_max - val_min)
    local draw_list = UI.draw_list
    local roundingIn = 0
    local col_rgba = 0xF0F0F0FF
    
    local radius = math.floor(math.min(item_w, item_h )/2)
    local radius_draw = math.floor(0.8 * radius)
    local center_x = curposx + item_w/2--radius
    local center_y = curposy + item_h/2  + knobname_h - yoffsarc
    local ang_min = -220
    local ang_max = 40
    local val_norm = (val -val_min)/ (val_max - val_min)
    
    local ang_val = ang_min + math.floor((ang_max - ang_min)*val_norm)
    local radiusshift_y = (radius_draw- radius)
    
    -- filled arc
    ImGui.DrawList_PathArcTo(draw_list, center_x, center_y - radiusshift_y, radius_draw, math.rad(ang_min),math.rad(ang_max))
    ImGui.DrawList_PathStroke(draw_list, 0xF0F0F02F,  ImGui.DrawFlags_None, 2)
    
    if not disabled == true then 
      -- value
      local radius_draw2 = radius_draw
      local radius_draw3 = radius_draw-6
      if centered ~= true then 
        -- back arc
        ImGui.DrawList_PathArcTo(draw_list, center_x, center_y - radiusshift_y, radius_draw, math.rad(ang_min),math.rad(ang_val+1))
        --ImGui.DrawList_PathStroke(draw_list, UI.knob_handle<<8|0xFF,  ImGui.DrawFlags_None, 2) 
        -- value
        --ImGui.DrawList_PathLineTo(draw_list, center_x + radius_draw2 * math.cos(math.rad(ang_val)), center_y - radiusshift_y + radius_draw2 * math.sin(math.rad(ang_val)))
        ImGui.DrawList_PathLineTo(draw_list, center_x + radius_draw3 * math.cos(math.rad(ang_val)), center_y -radiusshift_y + radius_draw3 * math.sin(math.rad(ang_val)))
        ImGui.DrawList_PathStroke(draw_list, UI.knob_handle<<8|0xFF,  ImGui.DrawFlags_None, 2)
        --ImGui.DrawList_PathClear(draw_list)
       else
        -- right arc
        if norm_val > 0.5 then 
          ImGui.DrawList_PathArcTo(draw_list, center_x, center_y - radiusshift_y, radius_draw, math.rad(-90),math.rad(ang_val+1))
          ImGui.DrawList_PathLineTo(draw_list, center_x + radius_draw3 * math.cos(math.rad(ang_val)), center_y -radiusshift_y + radius_draw3 * math.sin(math.rad(ang_val+1)))
          ImGui.DrawList_PathStroke(draw_list, UI.knob_handle<<8|0xFF,  ImGui.DrawFlags_None, 2)
          --ImGui.DrawList_PathClear(draw_list)
         else
          ImGui.DrawList_PathLineTo(draw_list, center_x + radius_draw3 * math.cos(math.rad(ang_val)), center_y -radiusshift_y + radius_draw3 * math.sin(math.rad(ang_val+1)))
          ImGui.DrawList_PathArcTo(draw_list, center_x, center_y - radiusshift_y, radius_draw, math.rad(ang_val+1), math.rad(-90))
          
          ImGui.DrawList_PathStroke(draw_list, UI.knob_handle<<8|0xFF,  ImGui.DrawFlags_None, 2)
          --ImGui.DrawList_PathClear(draw_list)
        end
      end
    end
    
    -- text
      if is_micro_knob~= true then
        ImGui.SetCursorPos( ctx, local_pos_x+UI.spacingX, local_pos_y+UI.spacingY )
        ImGui.TextWrapped( ctx, name )
      end
      
    if disabled ~= true and is_micro_knob~= true then 
    -- format value
      ImGui.SetCursorPos( ctx, local_pos_x, local_pos_y+h-UI.calc_itemH-UI.spacingY )
      local formatval_str_id = '##slider_formatval'..str_id
      if not (DATA.knob_strid_input and DATA.knob_strid_input  == formatval_str_id ) then 
        ImGui.Button(ctx,val_form..formatval_str_id,w ,UI.calc_itemH )
       else
        ImGui.SetNextItemWidth(ctx ,w)
        ImGui.SetKeyboardFocusHere( ctx, 0 )
        local retval, buf = ImGui.InputText( ctx, formatval_str_id, val_form, ImGui.InputTextFlags_None|ImGui.InputTextFlags_AutoSelectAll|ImGui.InputTextFlags_EnterReturnsTrue )
        if retval then
          if knob_t.parseinput then knob_t.parseinput(buf) end
          DATA.knob_strid_input = nil
        end
        
      end
      if knob_t.parseinput and ImGui_IsItemHovered( ctx, ImGui.HoveredFlags_None ) and ImGui.IsMouseDoubleClicked( ctx, ImGui.MouseButton_Left ) then
        DATA.knob_strid_input = '##slider_formatval'..str_id
      end
      
    end
    
    
    
    
    ImGui.SetCursorScreenPos(ctx, curposx, curposy)
    ImGui.Dummy(ctx,knob_t.w,  knob_t.h)
    if debug ~= 1 then UI.Tools_unsetbuttonstyle() end
    ImGui.PopStyleVar(ctx,2) 
    ImGui.PopFont(ctx) 
  end
  
  
  --------------------------------------------------------------------------------  
  function UI.draw_knob_handlelatchstate(t)  
    local paramval = t.val or 0
    local val_max = t.val_max or 1
    local val_min = t.val_min or 0
    
    
    if ImGui_IsMouseDoubleClicked( ctx, ImGui.MouseButton_Left ) and ImGui.IsItemHovered( ctx, ImGui.HoveredFlags_None ) then
      if t.default_val then t.appfunc_atdrag(t.default_val) end
    end
    
    -- trig
    if  ImGui.IsItemClicked( ctx, ImGui.MouseButton_Left ) then 
      DATA.temp_latchstate = paramval  
      if t.appfunc_atclick then t.appfunc_atclick() end
      return 
    end
    
    if  ImGui.IsItemClicked( ctx, ImGui.MouseButton_Right ) then 
      DATA.temp_latchstate = paramval 
      if t.appfunc_atclickR then t.appfunc_atclickR() end
      return 
    end

    
    -- drag
    if  ImGui.IsItemActive( ctx ) then
      local x, y = ImGui.GetMouseDragDelta( ctx )
      local outval = DATA.temp_latchstate - y/(t.knob_resY or UI.knob_resY)  
      outval = math.max(val_min,math.min(outval,val_max))
      local dx, dy = ImGui.GetMouseDelta( ctx )
      if dy~=0 then
        if t.appfunc_atdrag then t.appfunc_atdrag(outval) end
      end
    end
    
    if ImGui.IsItemDeactivated( ctx )then
      if t.appfunc_atrelease then t.appfunc_atrelease() DATA.upd = true end
    end
    
    
    local vertical, horizontal = ImGui.GetMouseWheel( ctx )
    if ImGui.IsItemHovered( ctx, ImGui.HoveredFlags_None )  and vertical ~= 0 then
      local outval = paramval + (math.abs(vertical)/vertical)/(t.knob_resY or UI.knob_resY)
      outval = math.max(val_min,math.min(outval,val_max))
      if t.appfunc_atdrag then t.appfunc_atdrag(outval) end
    end
  end
  -------------------------------------------------------------------------------- 
  function UI.HelpMarker(desc, tooltip_code)
    ImGui.TextDisabled(ctx, '(?)')
    if ImGui.BeginItemTooltip(ctx) then
      if tooltip_code then 
        tooltip_code()
       else
        ImGui.PushTextWrapPos(ctx, ImGui.GetFontSize(ctx) * 35.0)
        ImGui.Text(ctx, desc)
        ImGui.PopTextWrapPos(ctx)
      end
      ImGui.EndTooltip(ctx)
    end
  end
  --------------------------------------------------------------------------------  
  function UI.draw_startup()  
    if not (DATA.parent_track and DATA.parent_track.valid == true) then 
      ImGui.TextWrapped(ctx,
          [[ 
      RS5k manager quick tips: 
          1. Select parent track. It will be parent track for drum rack. Or create it:]]) --ImGui.SameLine(ctx) 
          ImGui.Dummy(ctx,30,0) ImGui.SameLine(ctx)
          if ImGui.Button(ctx, 'Insert new parent track') then 
            Undo_BeginBlock2(-1)
            InsertTrackInProject(-1, 0,0) 
            local tr = GetTrack(-1,0)
            GetSetMediaTrackInfo_String( tr, 'P_NAME', 'RS5k manager', true )
            reaper.SetOnlyTrackSelected( tr )
            Undo_EndBlock2(-1, 'Insert RS5k manager parent track', 0xFFFFFFFF)
            DATA.upd = true
          end
          
          ImGui.TextWrapped(ctx,  
[[          2. Once parent track is selected, drum rack is ready for adding samples to it.
          3. Drop sample to pads from OS browser or MediaExplorer to pad.  
          4. RS5k manager will automatically initialize all needed routing setup.
          ]])
          ImGui.TextWrapped(ctx,
          [[
          For bug reports:
            - make sure you are running the latest version of RS5k manager]]..' (you are running version '..rs5kman_vrs..' currently)'..
            [[
            
            - please attach FULL text of error (including error line number) and steps to reproduce.
          ]])
          
          
          UI.Link('Forum thread', 'https://forum.cockos.com/showthread.php?t=207971')
          ImGui.SameLine(ctx) 
          ImGui.SetNextItemWidth(ctx, -1) 
          ImGui.InputText(ctx,'##forumlink','https://forum.cockos.com/showthread.php?t=207971', ImGui.InputTextFlags_AutoSelectAll)
          
          UI.Link('Telegram chat', 'https://t.me/mplscripts_chat')
          ImGui.SameLine(ctx) 
          ImGui.SetNextItemWidth(ctx, -1) 
          ImGui.InputText(ctx,'##telegrchat','https://t.me/mplscripts_chat', ImGui.InputTextFlags_AutoSelectAll)
          
    end
  end
  
-------------------------------------------------------------------------------- 
  function DATA:Action_FixMetadata()
    local parent_track = GetSelectedTrack(-1,0)
    
    -- force current GUID to metadta
      local curGUID = reaper.GetTrackGUID( parent_track )
      GetSetMediaTrackInfo_String ( parent_track, 'P_EXT:MPLRS5KMAN_GUIDINTERNAL', curGUID, true) 
      DATA:CollectData_Parent()
      
    -- loop through children and 
      for i = DATA.parent_track.IP_TRACKNUMBER_0based+1, DATA.parent_track.IP_TRACKNUMBER_0basedlast do 
        local track = GetTrack(DATA.proj, i) 
        GetSetMediaTrackInfo_String( track, 'P_EXT:MPLRS5KMAN_CHILD_PARENTGUID', curGUID, true)  -- change their parent GUID 
        local fx_instr = TrackFX_GetInstrument( track )
        local fx_instrGUID = reaper.TrackFX_GetFXGUID( track, fx_instr )
        if fx_instrGUID then GetSetMediaTrackInfo_String( track, 'P_EXT:MPLRS5KMAN_CHILD_INSTR_FXGUID', fx_instrGUID, true) end
      end
      
  end
-------------------------------------------------------------------------------- 
  function UI.draw_FixingMetadata() 
    function __b_draw_FixingMetadata() end 
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowPadding,0,0)  
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_ItemSpacing,0,0)
    ImGui.SetCursorScreenPos(ctx,UI.calc_rackX,UI.calc_rackY)
    if ImGui.BeginChild( ctx, 'FixingMetadata_modal', UI.calc_rackW, 0, ImGui.ChildFlags_Border, ImGui.WindowFlags_None |ImGui.WindowFlags_NoScrollbar ) then--|ImGui.ChildFlags_Border --|ImGui.WindowFlags_MenuBar
      ImGui.TextWrapped(ctx,
          [[
          
          
    This rack was probably imported from template. Select parent track and        
          ]]) --ImGui.SameLine(ctx) 
          ImGui.Dummy(ctx,30,0) ImGui.SameLine(ctx)
          if ImGui.Button(ctx, '...try to fix##fix') then 
            Undo_BeginBlock2( -1 )
            DATA:Action_FixMetadata()
            Undo_EndBlock2( -1, 'RS5k manager - fix metadata', 0xFFFFFFFF )
          end
      ImGui.EndChild( ctx)
    end
    ImGui.PopStyleVar(ctx,2)
  end
--------------------------------------------------------------------------------  
  function UI.draw()  
    
    DATA.temp_ignore_incomingevent = false
    if DATA.VCA_mode == 0 then 
      UI.knob_handle  = UI.knob_handle_normal 
     elseif DATA.VCA_mode == 1 then 
      UI.knob_handle = UI.knob_handle_vca
     elseif DATA.VCA_mode == 2 then 
      UI.knob_handle = UI.knob_handle_vca2       
    end
    
    local closew
    if (DATA.parent_track and DATA.parent_track.valid == true) and UI.calc_padoverviewW and UI.hide_padoverview ~= true then closew = UI.calc_padoverviewW-UI.spacingX*2  end
    if ImGui.Button(ctx, 'X',closew) then DATA.trig_stopdefer = true end 
    
    UI.draw_startup()
    if DATA.wrong_parent_track_metadata == true then
      
     else
      UI.draw_Rack() 
    end
    
    UI.draw_tabs()
    if DATA.wrong_parent_track_metadata == true then
      UI.draw_FixingMetadata() 
    end
    if DATA.temp_loopslice_askforadd then -- autoslice_confirmation
      if not DATA.temp_loopslice_askforadd.triggerpopup then
        ImGui.OpenPopup( ctx, 'autoslice_confirmation', ImGui.PopupFlags_None )
        DATA.temp_loopslice_askforadd.triggerpopup = true
      end
    end
    
    if DATA.temp_loopslice_askforadd and DATA.temp_loopslice_askforadd.loop_t then
      local mousex, mousey = ImGui.GetMousePos( ctx )
      local out_w = 200
      local posx =  mousex-out_w/2 -- middle
      local posy = mousey-UI.calc_itemH*4 -- add as single button
      ImGui.SetNextWindowPos( ctx,posx, posy, ImGui.Cond_Once )
      ImGui.SetNextWindowSize( ctx, out_w, 0, ImGui.Cond_Always )
      if ImGui.BeginPopupModal( ctx, 'autoslice_confirmation', true, ImGui.WindowFlags_AlwaysAutoResize|ImGui.ChildFlags_Border ) then
        local loop_t=  DATA.temp_loopslice_askforadd.loop_t
        local note=  DATA.temp_loopslice_askforadd.note
        local filename=  DATA.temp_loopslice_askforadd.filename
        local slice_cnt = #loop_t
        ImGui.Dummy(ctx,0, UI.spacingY)
        ImGui.Text(ctx, 'Loop is detected,\n'..slice_cnt..' slices found')
        
        if ImGui.Button(ctx, 'Slice to pads', -1) then
          DATA.temp_loopslice_askforadd.confirmed = true
          DATA:Auto_LoopSlice()
          ImGui.CloseCurrentPopup( ctx )
        end
        
        if ImGui.Button(ctx, 'Add as single sample', -1) then
          DATA.temp_loopslice_askforadd = nil
          DATA:DropSample(filename, note, {layer=1})
          ImGui.CloseCurrentPopup( ctx )
        end        
        
        if ImGui.Button(ctx, 'Cancel', -1) then
          DATA.temp_loopslice_askforadd = nil
          ImGui.CloseCurrentPopup( ctx )
        end
        
        ImGui.SeparatorText(ctx, 'Slicing options')
        
        if DATA.temp_loopslice_askforadd  then
          if ImGui.Checkbox(ctx, 'Create MIDI take', DATA.temp_loopslice_askforadd.createMIDI) then 
            DATA.temp_loopslice_askforadd.createMIDI = not DATA.temp_loopslice_askforadd.createMIDI 
            if DATA.temp_loopslice_askforadd.createMIDI == true then DATA.temp_loopslice_askforadd.createPattern = false end
          end
          if DATA.temp_loopslice_askforadd.createMIDI == true then 
            if ImGui.Checkbox(ctx, 'Stretch to project bpm', DATA.temp_loopslice_askforadd.stretchmidi) then DATA.temp_loopslice_askforadd.stretchmidi = not DATA.temp_loopslice_askforadd.stretchmidi end
          end
          if ImGui.Checkbox(ctx, 'Create sequencer pattern', DATA.temp_loopslice_askforadd.createPattern) then 
            DATA.temp_loopslice_askforadd.createPattern = not DATA.temp_loopslice_askforadd.createPattern 
            if DATA.temp_loopslice_askforadd.createPattern == true then DATA.temp_loopslice_askforadd.createMIDI = false end
          end
          
          
          
        end
        
        
        
        ImGui.EndPopup(ctx)
      end
    end
    
    if DATA.loopcheck_testdraw == 1 then
      reaper.ImGui_SetCursorPos(ctx, 1000,50)
      if DATA.temp_CDOE_arr then reaper.ImGui_PlotHistogram(ctx, 'arrtemp', DATA.temp_CDOE_arr, 0, '', 0, 1, 700, 100) end
      reaper.ImGui_SetCursorPos(ctx, 1000,150)
      if DATA.temp_CDOE_arr2 then reaper.ImGui_PlotHistogram(ctx, 'arrtemp', DATA.temp_CDOE_arr2, 0, '', 0, 1, 700, 100) end
    end
    
    
  end
  --------------------------------------------------------------------------------
  function UI.draw_tabs_Sampler_Startup()
    -- database
    if DATA.database_maps then 
        ImGui.Dummy(ctx, 0, 20)
        ImGui.Indent(ctx, 10)
        reaper.ImGui_TextWrapped(ctx, 'Drop any sample from MediaExplorer or OS explorer to pads to start a control over rack.Curently there is no any selected pad. Select any pad contain sample to edit pad controls.\n\n\nFor advanced users:\nIf you made a setup of database maps (see Settings/Database maps), you can load database to pads.')
        ImGui.SetNextItemWidth(ctx, UI.settings_itemW )
        
        if DATA.temp_rename == true then 
          local retval, buf = reaper.ImGui_InputText( ctx, '##dbcurname', DATA.database_maps[EXT.UIdatabase_maps_current].dbname, ImGui.InputTextFlags_AutoSelectAll|ImGui.InputTextFlags_EnterReturnsTrue )
          if ImGui.IsItemActive(ctx) and DATA.allow_space_to_play == true then DATA.allow_space_to_play = false end
          if retval and buf ~= '' then 
            DATA.temp_rename = false
            DATA.database_maps[EXT.UIdatabase_maps_current].dbname = buf
            DATA:Database_Save()
          end
         else
         
          if ImGui.BeginCombo( ctx, '##Loaddatabasemap', DATA.database_maps[EXT.UIdatabase_maps_current].dbname, ImGui.ComboFlags_None ) then--|ImGui.ComboFlags_NoArrowButton
            for i = 1, 8 do
              if ImGui.Selectable( ctx, DATA.database_maps[i].dbname..'##dbmapsel'..i, i == EXT.UIdatabase_maps_current, ImGui.SelectableFlags_None) then EXT.UIdatabase_maps_current = i EXT:save() end
            end
            ImGui.EndCombo( ctx)
          end
        end
        ImGui.SameLine(ctx)
        
        
        if ImGui.Button(ctx, 'Load to all rack') then 
          DATA:Validate_MIDIbus_AND_ParentFolder() 
          Undo_BeginBlock2(DATA.proj )
          DATA:Database_Load() 
          Undo_EndBlock2( DATA.proj , 'Load database to all rack', 0xFFFFFFFF )
        end
        
        
        if DATA.parent_track.ext.PARENT_LASTACTIVENOTE == -1 then reaper.ImGui_BeginDisabled(ctx, true) end
        ImGui.SameLine(ctx) if ImGui.Button(ctx, 'Load selected pad') then 
          DATA:Validate_MIDIbus_AND_ParentFolder() 
          Undo_BeginBlock2(DATA.proj )
          DATA:Database_Load(true)
          Undo_EndBlock2( DATA.proj , 'Load database to selected pad only', 0xFFFFFFFF )
        end
        if DATA.parent_track.ext.PARENT_LASTACTIVENOTE == -1 then reaper.ImGui_EndDisabled(ctx) end
        
        ImGui.Unindent(ctx, 10)
      end
      
  end
  --------------------------------------------------------------------------------
  function UI.draw_tabs_Sampler()
    local note_layer_t, note, layer = DATA:Sampler_GetActiveNoteLayer() if not (note_layer_t) then UI.draw_tabs_Sampler_Startup() return end 
    local fxbutw = 40
    -- name
    local name = DATA.children[note].P_NAME
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_ButtonTextAlign,0,0.5)
    UI.Tools_setbuttonbackg()
    ImGui.SetNextItemWidth(ctx, 170)
    if DATA.children[note].TYPE_DEVICE == true then ImGui.SetNextItemWidth(ctx, 170) end
    local retval, buf = reaper.ImGui_InputText( ctx, '##sampler_activename', name, ImGui.InputTextFlags_EnterReturnsTrue )
    if retval then
      if DATA.children[note].TYPE_DEVICE == true then 
        GetSetMediaTrackInfo_String( DATA.children[note].tr_ptr, 'P_NAME', buf, true )
       else
        GetSetMediaTrackInfo_String( note_layer_t.tr_ptr, 'P_NAME', buf, true )
      end
      DATA.upd = true
    end
    UI.Tools_unsetbuttonstyle()
    ImGui.PopStyleVar(ctx)
    if ImGui.BeginDragDropTarget( ctx ) then  
      UI.Drop_UI_interaction_sampler() 
      ImGui_EndDragDropTarget( ctx )
    end
    
    -- tooltip full name
    if note_layer_t and note_layer_t.instrument_filename then ImGui.SetItemTooltip(ctx, note_layer_t.instrument_filename) end
    
    -- device fx
      if DATA.children[note].TYPE_DEVICE == true then 
        ImGui.SameLine(ctx)
        if ImGui.Button(ctx, 'FX##device_fx',fxbutw) then TrackFX_Show( DATA.children[note].tr_ptr,0, 1 ) end
      end
    
    ImGui.SameLine(ctx)
    local col_rgb  = DATA.children[note].I_CUSTOMCOLOR 
    
    col_rgb = ImGui.ColorConvertNative(col_rgb)
    local col_rgba = (col_rgb << 8) | 0xFF--col_rgb & 0x1000000 ~= 0 and 
    if col_rgb & 0x1000000 == 0 then col_rgba = 0x5F5F5FFF end
    --local r, g, b = reaper.ColorFromNative( col_rgb )
    --local col_rgba = r<<24|g<<16|b<<8|0xFF
    if col_rgba then 
      local retval, col_rgba = ImGui.ColorEdit4( ctx, '##coloreditpad', col_rgba, ImGui.ColorEditFlags_None|ImGui.ColorEditFlags_NoInputs)--|ImGui.ColorEditFlags_NoAlpha )
      if retval then 
        local r, g, b = (col_rgba>>24)&0xFF, (col_rgba>>16)&0xFF, (col_rgba>>8)&0xFF
        col_rgb = ColorToNative( r, g, b )
        DATA.children[note].I_CUSTOMCOLOR  = col_rgb
        local tr_ptr = DATA.children[note].tr_ptr
        SetMediaTrackInfo_Value( tr_ptr, 'I_CUSTOMCOLOR', col_rgb|0x1000000 )
        if DATA.children[note].layers then 
          for layerid = 1, #DATA.children[note].layers do
            local tr_ptr = DATA.children[note].layers[layerid].tr_ptr
            SetMediaTrackInfo_Value( tr_ptr, 'I_CUSTOMCOLOR', col_rgb|0x1000000 )
          end
        end
        DATA.upd = true
      end
    end
    
    ImGui.SameLine(ctx)
    
    -- layer selector
    local layerselectW = 150
    if DATA.children[note] and DATA.children[note].TYPE_DEVICE==true and layer ~= 0 then
      ImGui.SameLine(ctx)
      preview_value = string.format('%02d',layer)..' '..note_layer_t.P_NAME
      ImGui.SetNextItemWidth(ctx, layerselectW)
      if ImGui.BeginCombo( ctx, '##layerselect', preview_value, ImGui.ComboFlags_None ) then
        for layerID = 1, #DATA.children[note].layers do
          if ImGui.Selectable(ctx, string.format('%02d',layerID)..' '..DATA.children[note].layers[layerID].P_NAME..'##layers_selectorNsame'..layerID,layerID == layer, ImGui.SelectableFlags_None) then
            DATA.parent_track.ext.PARENT_LASTACTIVENOTE_LAYER = layerID
            DATA:WriteData_Parent()
            DATA.upd = true
          end
        end
        ImGui.EndCombo( ctx )
      end 
      ImGui.SameLine(ctx)
     else
      ImGui.SameLine(ctx)
      ImGui.Dummy(ctx,layerselectW,0)
      ImGui.SameLine(ctx)
    end
      
    -- fx
    if layer ~= 0 then 
      if ImGui.Button(ctx, 'FX##sampler_fx',-1) then TrackFX_Show( note_layer_t.tr_ptr, note_layer_t.instrument_pos or 0, 1 ) end
     else
      ImGui.Dummy(ctx,0,0)
    end
    

      
    if ImGui.Button(ctx, '< Previous spl',UI.calc_sampler4ctrl_W) then DATA:Sampler_NextPrevSample(note_layer_t, 1) end 
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, 'Next spl >',UI.calc_sampler4ctrl_W) then DATA:Sampler_NextPrevSample(note_layer_t, 0) end
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, 'Random spl',UI.calc_sampler4ctrl_W) then DATA:Sampler_NextPrevSample(note_layer_t, 2) end
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, 'MediaExplorer',UI.calc_sampler4ctrl_W) then  DATA:Sampler_ShowME() ImGui.CloseCurrentPopup(ctx) end
      
      
      
    -- peaks
   --UI.Tools_setbuttonbackg()
    local plotx, ploty = ImGui.GetCursorPos( ctx)
    local plotx_abs, ploty_abs = ImGui.GetCursorScreenPos( ctx )
    if ImGui.BeginDisabled(ctx, true) then 
      --ImGui.Button(ctx, '[drop area]##sampler_peaks',-1, UI.sampler_peaksH) 
      ImGui.EndDisabled(ctx)
    end
    local x1, y1 = reaper.ImGui_GetItemRectMin( ctx )
    local x2, y2 = reaper.ImGui_GetItemRectMax( ctx )
    --if ImGui.IsItemClicked(ctx, ImGui.MouseButton_Left) and DATA.parent_track.ext and DATA.parent_track.ext.PARENT_LASTACTIVENOTE then DATA:Sampler_StuffNoteOn(DATA.parent_track.ext.PARENT_LASTACTIVENOTE) end
    --if ImGui.IsItemDeactivated(ctx) and DATA.parent_track.ext and DATA.parent_track.ext.PARENT_LASTACTIVENOTE then DATA:Sampler_StuffNoteOn(DATA.parent_track.ext.PARENT_LASTACTIVENOTE, 0 , true) end
    
    local is_slice = note_layer_t.instrument_samplestoffs and (not (note_layer_t.instrument_samplestoffs<0.01 and note_layer_t.instrument_sampleendoffs>0.99))
    local yoffs_peaksfull = 0
    
    
    -- peaks full
    if is_slice==true then
      local peaksX =plotx_abs+UI.adsr_rectsz/2
      local peaksY =ploty_abs
      local peaksW =UI.settingsfixedW
      local peaksH =UI.sampler_peaksfullH
      UI.draw_peaks('curfull',note_layer_t,peaksX-UI.spacingX, peaksY,peaksW, peaksH, note_layer_t.peaks_arr_samplerfull, true )
      yoffs_peaksfull = peaksH + UI.spacingY
      UI.draw_tabs_Sampler_BoundaryEdges(note_layer_t, plotx_abs, ploty_abs,x2,ploty_abs+UI.sampler_peaksfullH)
    end
    
    -- peaks normal
    local peaksX =plotx_abs+UI.adsr_rectsz/2
    local peaksY =ploty_abs +yoffs_peaksfull
    local peaksW =UI.settingsfixedW-UI.adsr_rectsz
    local peaksH =UI.sampler_peaksH
    UI.draw_peaks('cur',note_layer_t,peaksX, peaksY,peaksW, peaksH, note_layer_t.peaks_arr_sampler )    
    --UI.Tools_unsetbuttonstyle(plotx_abs, ploty_abs,-1, UI.sampler_peaksH)
    -- handle click to peaks for play
    local cl_x, cl_y = reaper.ImGui_GetMouseClickedPos( ctx, ImGui.MouseButton_Left )
    if ImGui.IsAnyItemHovered( ctx )~=true and ImGui.IsMouseClicked( ctx, ImGui.MouseButton_Left,0 ) and cl_x >=peaksX and cl_x<=peaksX+peaksW and cl_y >=peaksY and cl_y<=peaksY+peaksH then 
      if DATA.parent_track.ext and DATA.parent_track.ext.PARENT_LASTACTIVENOTE then DATA:Sampler_StuffNoteOn(DATA.parent_track.ext.PARENT_LASTACTIVENOTE) end
    end
    UI.draw_tabs_Sampler_ADSR(note_layer_t, plotx_abs, ploty_abs+yoffs_peaksfull,x2,ploty_abs+UI.sampler_peaksH+yoffs_peaksfull)
    
    --
    ImGui.SetCursorPos( ctx, plotx, ploty+UI.sampler_peaksH+yoffs_peaksfull )
    UI.draw_tabs_Sampler_tabs()
  end
  --------------------------------------------------------------------------------
  function UI.draw_tabs_Sampler_ADSR(note_layer_t, x10,y10,x20,y20) 
    if note_layer_t.ISRS5K ~= true then return end
    local rect_sz = UI.adsr_rectsz
    local x1,y1,x2,y2 = x10+rect_sz,y10+rect_sz,x20-rect_sz,y20-rect_sz -- effective area
    ImGui.PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameRounding(), 1)
    ImGui.PushStyleColor(ctx, reaper.ImGui_Col_Button(),        (EXT.UI_colRGBA_maintheme_color&0xFFFFFF00)|0x90)
    ImGui.PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(),  (EXT.UI_colRGBA_maintheme_color&0xFFFFFF00)|0xB0)
    ImGui.PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), (EXT.UI_colRGBA_maintheme_color&0xFFFFFF00)|0xF0)
    
    -- test
    ImGui.DrawList_AddRectFilled( UI.draw_list, x10,y10,x20,y20, EXT.UI_colRGBA_smplrbackgr, 2, ImGui.DrawFlags_None )
    
    
    --ImGui.DrawList_AddRectFilled( UI.draw_list, x1,y1,x2,y2, 0xFFFFFF0F, 2, ImGui.DrawFlags_None )
    
    -- attack
    UI.draw_tabs_Sampler_ADSR_points(note_layer_t, x10,y10,x20,y20) 
    
    ImGui.PopStyleVar(ctx)
    ImGui.PopStyleColor(ctx,3)
  end
  --------------------------------------------------------------------------------
  function UI.draw_tabs_Sampler_BoundaryEdges(note_layer_t, x10,y10,x20,y20) 
    if note_layer_t.ISRS5K ~= true then return end
    local note = note_layer_t.noteID
    -- backgr fill
    ImGui.DrawList_AddRectFilled( UI.draw_list, x10,y10,x20,y20, 0xFFFFFF0C, 2, ImGui.DrawFlags_None )
    
    -- backgr work area
    local samplestoffs = note_layer_t.instrument_samplestoffs
    local sampleendoffs = note_layer_t.instrument_sampleendoffs
    local w = x20-x10
    local pos1=  math.floor(x10+w*samplestoffs)
    local pos2=  math.floor(x10+w*sampleendoffs )
    local rect_sz = UI.adsr_rectsz
    
    ImGui.DrawList_AddRectFilled( UI.draw_list,pos1,y10,pos2,y20, 0x00FF001F, 2, ImGui.DrawFlags_None )
    
    ImGui.DrawList_AddTriangleFilled(  UI.draw_list, 
      pos1, y10, 
      pos1+rect_sz, y10, 
      pos1, y10+rect_sz, 
      (EXT.UI_colRGBA_maintheme_color&0xFFFFFF00)|0x90 )
      
      
    ImGui.DrawList_AddTriangleFilled(  UI.draw_list, 
      pos2-rect_sz, y20, 
      pos2, y20-rect_sz, 
      pos2, y20,  
      (EXT.UI_colRGBA_maintheme_color&0xFFFFFF00)|0x90 )
    
    
    UI.draw_setbuttonbackgtransparent()
    local x1,y1,x2,y2 = x10+rect_sz,y10+rect_sz,x20-rect_sz,y20-rect_sz -- effective area
    ImGui.SetCursorScreenPos( ctx, pos1, y10 )
    ImGui.Button(ctx, '##adsr_stoffs', UI.adsr_rectsz, UI.adsr_rectsz) 
    if ImGui.IsItemClicked( ctx ) then 
      DATA.temp_sampleboundary_st = note_layer_t.instrument_samplestoffs
    end
    if ImGui.IsItemActive( ctx ) then
      local x, y = reaper.ImGui_GetMouseDragDelta( ctx, x1, y1, ImGui.MouseButton_Left, 0 )
      local deltaX = x/(x2-x1)
      note_layer_t.instrument_samplestoffs = VF_lim(deltaX + DATA.temp_sampleboundary_st,0,note_layer_t.instrument_sampleendoffs)
      TrackFX_SetParamNormalized( note_layer_t.tr_ptr, note_layer_t.instrument_pos, note_layer_t.instrument_samplestoffsID, note_layer_t.instrument_samplestoffs )    
      DATA:CollectData_Children_InstrumentParams(note_layer_t,true) -- minor refresh formatted values
      DATA.peakscache[note]  = nil
    end 
    
    ImGui.SetCursorScreenPos( ctx, pos2-UI.adsr_rectsz, y20-UI.adsr_rectsz ) 
    ImGui.Button(ctx, '##adsr_enoffs', UI.adsr_rectsz, UI.adsr_rectsz)
    if ImGui.IsItemClicked( ctx ) then 
      DATA.temp_sampleboundary_end = note_layer_t.instrument_sampleendoffs
    end
    if ImGui.IsItemActive( ctx ) then
      local x, y = reaper.ImGui_GetMouseDragDelta( ctx, x1, y1, ImGui.MouseButton_Left, 0 )
      local deltaX = x/(x2-x1)
      note_layer_t.instrument_sampleendoffs = VF_lim(deltaX + DATA.temp_sampleboundary_end,note_layer_t.instrument_samplestoffs,1)
      TrackFX_SetParamNormalized( note_layer_t.tr_ptr, note_layer_t.instrument_pos, note_layer_t.instrument_sampleendoffsID, note_layer_t.instrument_sampleendoffs )   
      DATA:CollectData_Children_InstrumentParams(note_layer_t,true) -- minor refresh formatted values
      DATA.peakscache[note]  = nil
    end
    
    UI.Tools_unsetbuttonstyle()
    
    UI.Tools_setbuttonbackg(0x00FF005F)
    local midbutW = pos2-pos1-UI.adsr_rectsz*2
    local midbutH = 10
    if midbutW > 5 then
      ImGui.SetCursorScreenPos( ctx, pos1+UI.adsr_rectsz, y10 + (y20-y10- midbutH )/2 ) 
      ImGui.Button(ctx, '##adsr_midoffs', midbutW, midbutH)
      if ImGui.IsItemClicked( ctx ) then 
        DATA.temp_sampleboundary_len = note_layer_t.instrument_sampleendoffs - note_layer_t.instrument_samplestoffs
        DATA.temp_sampleboundary_st = note_layer_t.instrument_samplestoffs
      end
      if ImGui.IsItemActive( ctx ) and DATA.temp_sampleboundary_len then
        --local mousex, mousey = reaper.ImGui_GetMousePos( ctx )
        local x, y = reaper.ImGui_GetMouseDragDelta( ctx, x1, y1, ImGui.MouseButton_Left, 0 )
        local deltaX = x/(x2-x1)
        
        DATA.temp_sampleboundary_len = note_layer_t.instrument_sampleendoffs - note_layer_t.instrument_samplestoffs
        
        local samplestoffs_out = VF_lim(DATA.temp_sampleboundary_st + deltaX,0,note_layer_t.instrument_sampleendoffs)
        local sampleendoffs_out = VF_lim(samplestoffs_out + DATA.temp_sampleboundary_len,note_layer_t.instrument_samplestoffs,1)
        local len = sampleendoffs_out - samplestoffs_out
        if DATA.temp_sampleboundary_len ==len then
          note_layer_t.instrument_samplestoffs = samplestoffs_out
          note_layer_t.instrument_sampleendoffs =sampleendoffs_out
          
          TrackFX_SetParamNormalized( note_layer_t.tr_ptr, note_layer_t.instrument_pos, note_layer_t.instrument_samplestoffsID, note_layer_t.instrument_samplestoffs )   
          TrackFX_SetParamNormalized( note_layer_t.tr_ptr, note_layer_t.instrument_pos, note_layer_t.instrument_sampleendoffsID, note_layer_t.instrument_sampleendoffs )   
          DATA:CollectData_Children_InstrumentParams(note_layer_t,true) -- minor refresh formatted values
          
          DATA.peakscache[note]  = nil
        end
      end
    end
    UI.Tools_unsetbuttonstyle()
  end
  --------------------------------------------------------------------------------
  function UI.draw_tabs_Sampler_ADSR_point_getpos(x1,y1,x2,y2, xpos, ypos, centered)  
    if not xpos then return end
    if not centered then 
      return x1 + (x2-x1-UI.adsr_rectsz)*xpos, y1 + (y2-y1-UI.adsr_rectsz)*(1-ypos)
     else
      return x1 + (x2-x1-UI.adsr_rectsz)*xpos+UI.adsr_rectsz/2, y1 + (y2-y1-UI.adsr_rectsz)*(1-ypos)+UI.adsr_rectsz/2
    end
  end
    --------------------------------------------------------------------------------
  function UI.draw_tabs_Sampler_ADSR_points(note_layer_t, x1,y1,x2,y2)  
    local note,layer = note_layer_t.noteID, layerID 
    local samplelen =note_layer_t.SAMPLELEN
    
    if not note_layer_t.instrument_attack_norm then return end
    -- delay
    local xpos = 0--note_layer_t.instrument_samplestoffs
    local ypos = 0 
    local xpos_del, ypos_del = UI.draw_tabs_Sampler_ADSR_point_getpos(x1,y1,x2,y2, xpos, ypos) 
    if not xpos_del then return end
    
    
    -- attack
    local att_mult = 10
    local xpos = note_layer_t.instrument_attack_norm *att_mult
    local ypos = 0.8--note_layer_t.instrument_vol  
    local xpos_att, ypos_att = UI.draw_tabs_Sampler_ADSR_point_getpos(x1,y1,x2,y2, xpos, ypos) 
    local attoffs = (xpos_del-x1)
    xpos_att = xpos_att + attoffs
    ImGui.SetCursorScreenPos( ctx, xpos_att, ypos_att )
    ImGui.Button(ctx, '##adsr_attvol', UI.adsr_rectsz, UI.adsr_rectsz)
    if ImGui.IsItemActive( ctx ) then
    
      local mousex, mousey = reaper.ImGui_GetMousePos( ctx )
      local v = VF_lim( ( mousex - x1 - attoffs ) / (x2-x1),0,1 )---note_layer_t.instrument_samplestoffs
      note_layer_t.instrument_attack = v * note_layer_t.instrument_attack_max
      TrackFX_SetParamNormalized( note_layer_t.tr_ptr, note_layer_t.instrument_pos, note_layer_t.instrument_attackID,note_layer_t.instrument_attack/att_mult )  
      
      --[[note_layer_t.instrument_vol = 1-VF_lim((mousey - y1)/(y2-y1))
      TrackFX_SetParamNormalized( note_layer_t.tr_ptr, note_layer_t.instrument_pos, note_layer_t.instrument_volID, note_layer_t.instrument_vol )   
      ]]
      DATA:CollectData_Children_InstrumentParams(note_layer_t,true) -- minor refresh formatted values 
    end        
    
    -- delay - attack line 
    ImGui.DrawList_AddLine( UI.draw_list,xpos_del + UI.adsr_rectsz/2, ypos_del + UI.adsr_rectsz/2,xpos_att + UI.adsr_rectsz/2, ypos_att + UI.adsr_rectsz/2, (EXT.UI_colRGBA_maintheme_color&0xFFFFFF00)|0x90, 2 )
        
    -- decay
    local delmult = 1
    local susult = 2
    local xpos = note_layer_t.instrument_decay_norm *delmult
    local ypos = note_layer_t.instrument_sustain*susult*0.8
    local xpos_dec, ypos_dec = UI.draw_tabs_Sampler_ADSR_point_getpos(x1,y1,x2,y2, xpos, ypos) 
    xpos_dec = xpos_att + xpos * (x2-x1)
    ImGui.SetCursorScreenPos( ctx, xpos_dec, ypos_dec ) 
    ImGui.Button(ctx, '##adsr_decsus', UI.adsr_rectsz, UI.adsr_rectsz )
    if ImGui.IsItemActive( ctx ) then
    
      local mousex, mousey = reaper.ImGui_GetMousePos( ctx )
      local offs = note_layer_t.instrument_attack_norm*att_mult --+ note_layer_t.instrument_samplestoffs
      local v = VF_lim( ( mousex - x1 ) / (x2-x1), offs,1)
      v = v - offs
      note_layer_t.instrument_decay = v * note_layer_t.instrument_decay_max
      TrackFX_SetParamNormalized( note_layer_t.tr_ptr, note_layer_t.instrument_pos, note_layer_t.instrument_decayID, v*note_layer_t.instrument_decay_max/delmult )  
      
      local v2 = 1-VF_lim((mousey - y1)/(y2-y1))
      note_layer_t.instrument_sustain =v2
      TrackFX_SetParamNormalized( note_layer_t.tr_ptr, note_layer_t.instrument_pos, note_layer_t.instrument_sustainID, v2/susult ) 
      
      DATA:CollectData_Children_InstrumentParams(note_layer_t,true) -- minor refresh formatted values 
    end          
    
    -- attack - decay line 
    ImGui.DrawList_AddLine( UI.draw_list,xpos_att + UI.adsr_rectsz/2, ypos_att + UI.adsr_rectsz/2, xpos_dec + UI.adsr_rectsz/2, ypos_dec + UI.adsr_rectsz/2, (EXT.UI_colRGBA_maintheme_color&0xFFFFFF00)|0x90, 2 )
    
    
    -- release
    local xpos = note_layer_t.instrument_release_norm 
    local ypos = 0 
    local xpos_rel, ypos_rel = UI.draw_tabs_Sampler_ADSR_point_getpos(x1,y1,x2,y2, xpos, ypos) 
    xpos_rel = xpos_rel + (note_layer_t.instrument_attack_norm*att_mult  + note_layer_t.instrument_decay_norm*delmult) * (x2-x1)--+ note_layer_t.instrument_samplestoffs
    ImGui.SetCursorScreenPos( ctx, xpos_rel, ypos_rel )
    ImGui.Button(ctx, '##adsr_rel', UI.adsr_rectsz, UI.adsr_rectsz)
    if ImGui.IsItemActive( ctx ) then
      local mousex, mousey = reaper.ImGui_GetMousePos( ctx )
      
      local offs = note_layer_t.instrument_attack_norm*att_mult  + note_layer_t.instrument_decay_norm*delmult--+ note_layer_t.instrument_samplestoffs
      local v = VF_lim( ( mousex - x1 ) / (x2-x1), offs,1)
      v = v - offs
      note_layer_t.instrument_release = v * note_layer_t.instrument_release_max
      TrackFX_SetParamNormalized( note_layer_t.tr_ptr, note_layer_t.instrument_pos, note_layer_t.instrument_releaseID,note_layer_t.instrument_release )  
      
      DATA:CollectData_Children_InstrumentParams(note_layer_t,true) -- minor refresh formatted values
    end
    
    -- delay - attack line 
    ImGui.DrawList_AddLine( UI.draw_list,xpos_dec + UI.adsr_rectsz/2, ypos_dec + UI.adsr_rectsz/2, xpos_rel + UI.adsr_rectsz/2, ypos_rel + UI.adsr_rectsz/2, (EXT.UI_colRGBA_maintheme_color&0xFFFFFF00)|0x90, 2 )
    
    
    
    -- loop offs
    if note_layer_t.instrument_loop == 1 then
      local loopoffs = note_layer_t.instrument_loopoffs_norm
      local rect_sz = UI.adsr_rectsz
      local pos1 = x1+(x2-x1) * loopoffs + UI.spacingX
      ImGui.DrawList_AddTriangleFilled(  UI.draw_list, 
        pos1-rect_sz, y1, 
        pos1, y1, 
        pos1, y1+rect_sz, 
        (EXT.UI_colRGBA_maintheme_color&0xFFFFFF00)|0x90 )
        
      UI.draw_setbuttonbackgtransparent()
      ImGui.SetCursorScreenPos( ctx, pos1-rect_sz, y1 )
      ImGui.Button(ctx, '##adsr_loopoffs', UI.adsr_rectsz, UI.adsr_rectsz) 
      UI.Tools_unsetbuttonstyle()
      if ImGui.IsItemActive( ctx ) then
        local mousex, mousey = reaper.ImGui_GetMousePos( ctx )
        note_layer_t.instrument_loopoffs_norm = VF_lim((mousex - x1)/(x2-x1))
        TrackFX_SetParamNormalized( note_layer_t.tr_ptr, note_layer_t.instrument_pos, note_layer_t.instrument_loopoffsID, note_layer_t.instrument_loopoffs_norm*note_layer_t.instrument_loopoffs_max )    
        DATA:CollectData_Children_InstrumentParams(note_layer_t,true) -- minor refresh formatted values
      end 
    end
     
  end
  --------------------------------------------------------------------------------
  function UI.draw_peaks (id,note_layer_t,plotx_abs,ploty_abs,w,h, arr, is_pad_peak, dim) 
    if EXT.CONF_showpadpeaks == 0 and not id:match('cur') then return end
    if not arr then return end
    local note = note_layer_t.noteID
    
    local size = arr.get_alloc()
    local size_new = math.floor(size/2)
    if size_new < 0 then return end
     
    local peakscol =  0xFFFFFF7F
    if dim then peakscol =  0xFFFFFF35 end
    local last_xpos =plotx_abs
    for i = 1, size_new do
      local xpos = math.floor(plotx_abs + w * i/size_new )
      if xpos ~= last_xpos then
        local ypos =  math.floor(ploty_abs + h/2 * (1- arr[i]))
        local ypos2 =  math.floor(ploty_abs + h/2 * (1- arr[i+size_new]))
        ImGui_DrawList_AddRectFilled( UI.draw_list, last_xpos, ypos, xpos+1, ypos2, peakscol, 0, ImGui.DrawFlags_None )
      end
      last_xpos = xpos
    end
    
    -- show loop in sampler mode
    if is_pad_peak ~= true then
      local loop = note_layer_t.instrument_loop
      if loop >0 then
        local loopoffs = note_layer_t.instrument_loopoffs_norm
        ImGui_DrawList_AddRectFilled( UI.draw_list, plotx_abs+w*loopoffs, ploty_abs, plotx_abs+w, ploty_abs+h-3, 0x00FF001F, 0, ImGui.DrawFlags_None )
      end
    end
    
  end
  --------------------------------------------------------------------------------
  function UI.draw_tabs_Sampler_tabs()
    --if reaper.ImGui_BeginChild(ctx, '##draw_tabs_Sampler_tabs', 0, 140) then
      if ImGui.BeginTabBar( ctx, 'tabsbar_sampler', ImGui.TabItemFlags_None ) then 
        
        
        local note_layer_t = DATA:Sampler_GetActiveNoteLayer()
        if note_layer_t then
          if note_layer_t.ISRS5K then
            
            if ImGui.BeginTabItem( ctx, 'General', false, ImGui.TabItemFlags_None ) then        UI.draw_tabs_Sampler_tabs_rs5kcontrols()ImGui.EndTabItem( ctx) end
            if ImGui.BeginTabItem( ctx, 'Sample', false, ImGui.TabItemFlags_None ) then         UI.draw_tabs_Sampler_tabs_sample()      ImGui.EndTabItem( ctx) end 
            
            if ImGui.BeginTabItem( ctx, 'Boundary', false, ImGui.TabItemFlags_None ) then       UI.draw_tabs_Sampler_tabs_boundary()    ImGui.EndTabItem( ctx) end 
            if ImGui.BeginTabItem( ctx, 'FX', false, ImGui.TabItemFlags_None ) then             UI.draw_tabs_Sampler_tabs_FX()          ImGui.EndTabItem( ctx) end   
            if ImGui.BeginTabItem( ctx, 'Device', false, ImGui.TabItemFlags_None ) then         UI.draw_tabs_Sampler_tabs_device()      ImGui.EndTabItem( ctx) end
           else
            if ImGui.BeginTabItem( ctx, 'General (3rd party)', false, ImGui.TabItemFlags_None ) then        UI.draw_tabs_Sampler_tabs_3rdpartycontrols()ImGui.EndTabItem( ctx) end
            if ImGui.BeginTabItem( ctx, 'FX', false, ImGui.TabItemFlags_None ) then             UI.draw_tabs_Sampler_tabs_FX()          ImGui.EndTabItem( ctx) end 
            if ImGui.BeginTabItem( ctx, 'Device', false, ImGui.TabItemFlags_None ) then         UI.draw_tabs_Sampler_tabs_device()      ImGui.EndTabItem( ctx) end
          end
          if ImGui.BeginTabItem( ctx, 'Track', false, ImGui.TabItemFlags_None ) then UI.draw_tabs_Sampler_trackparams()  ImGui.EndTabItem( ctx)   end  
        end
        
                  
        ImGui.EndTabBar( ctx)
      end
      --reaper.ImGui_EndChild(ctx)
   -- end
  end
  --------------------------------------------------------------------------------
  function UI.draw_tabs_Sampler_tabs_boundary()
    local note_layer_t = DATA:Sampler_GetActiveNoteLayer() if not note_layer_t then return end
    if note_layer_t.TYPE_DEVICE== true then return end
    
    
    local curposx_abs, curposy_abs = ImGui.GetCursorScreenPos(ctx)
    
    -- loop
    local retval, v = ImGui.Checkbox( ctx, 'Loop', note_layer_t.instrument_loop==1 )
    if retval then TrackFX_SetParamNormalized( note_layer_t.tr_ptr, note_layer_t.instrument_pos, 12, note_layer_t.instrument_loop~1 ) DATA.upd = true end      
    -- instrument_noteoff
    local retval, v = ImGui.Checkbox( ctx, 'Obey note-off', note_layer_t.instrument_noteoff==1 )
    if retval then TrackFX_SetParamNormalized( note_layer_t.tr_ptr, note_layer_t.instrument_pos, 11, note_layer_t.instrument_noteoff~1 ) DATA.upd = true end  
    
    -- slice bpm
    local looptempo = note_layer_t.SAMPLEBPM or ''
    if looptempo == 0 then looptempo = reaper.Master_GetTempo() end
    reaper.ImGui_SetNextItemWidth(ctx, 50)
    local retval, buf = reaper.ImGui_InputText( ctx, 'BPM##tempo', looptempo, reaper.ImGui_InputTextFlags_None()|reaper.ImGui_InputTextFlags_CharsDecimal() )
    if reaper.ImGui_IsItemDeactivatedAfterEdit(ctx) then  
      local track = note_layer_t.tr_ptr
      DATA:WriteData_Child(track, {
        SET_SAMPLEBPM = tonumber(buf),
      }) 
      DATA.upd = true
    end
    
    
    ImGui.SetCursorScreenPos(ctx, curposx_abs + (UI.calc_knob_w_small + UI.spacingX)*2, curposy_abs)
    if ImGui.BeginChild(ctx,'tabsbar_sampler_boundarychild', 0,0,reaper.ImGui_ChildFlags_Border()) then
      if ImGui.BeginTabBar( ctx, '##tabsbar_sampler_boundary', ImGui.TabItemFlags_None ) then 
        
        -- start offset
        if ImGui.BeginTabItem( ctx, 'Start offset##sampler_boundary_Start', false, ImGui.TabItemFlags_None ) then
          local formatIn = DATA.boundarystep[EXT.CONF_stepmode].str
          reaper.ImGui_SetNextItemWidth(ctx, 100)
          local retval, v = reaper.ImGui_SliderInt( ctx, 'Step##shiftboundary', EXT.CONF_stepmode, 0, #DATA.boundarystep, formatIn, ImGui.SliderFlags_None )
          if retval then EXT.CONF_stepmode = v end if reaper.ImGui_IsItemDeactivatedAfterEdit(ctx) then EXT:save() end
          if EXT.CONF_stepmode == 10 then
            ImGui.SameLine(ctx)
            reaper.ImGui_SetNextItemWidth(ctx, 100)
            local retval, v = reaper.ImGui_SliderDouble( ctx, 'ahead##shiftboundary_ahead', EXT.CONF_stepmode_transientahead, 0, 0.1, '%.3f sec', ImGui.SliderFlags_None )
            if retval then EXT.CONF_stepmode_transientahead = v end if reaper.ImGui_IsItemDeactivatedAfterEdit(ctx) then EXT:save() end
          end
          local retval, v = ImGui.Checkbox( ctx, 'Keep slice length', EXT.CONF_stepmode_keeplen==1 )
          if retval then EXT.CONF_stepmode_keeplen=EXT.CONF_stepmode_keeplen~1 EXT:save() end  
          
          if EXT.CONF_stepmode ~= 10 then
            if ImGui.Button(ctx, '< Start##movestoffslefthome') then 
              local dir = -1
              DATA:Action_ShiftOffset(note_layer_t, 2, dir) 
            end 
            ImGui.SameLine(ctx)
            if ImGui.Button(ctx, '< Move left##movestoffsleft') then  
              local dir = -1
              DATA:Action_ShiftOffset(note_layer_t, 0, dir) 
            end
            ImGui.SameLine(ctx)
          end 
          if ImGui.Button(ctx, 'Move right >##movestoffsright') then 
            local dir = 1
            DATA:Action_ShiftOffset(note_layer_t, 0, dir) 
          end 
          
          ImGui.EndTabItem( ctx) 
        end
        
        -- end offset
        if ImGui.BeginTabItem( ctx, 'End offset##sampler_boundary_end', false, ImGui.TabItemFlags_None ) then
          local formatIn = DATA.boundarystep[EXT.CONF_stepmode].str
          reaper.ImGui_SetNextItemWidth(ctx, 100)
          local retval, v = reaper.ImGui_SliderInt( ctx, 'Step##shiftboundaryenf', EXT.CONF_stepmode, 0, #DATA.boundarystep, formatIn, ImGui.SliderFlags_None )
          if retval then EXT.CONF_stepmode = v end if reaper.ImGui_IsItemDeactivatedAfterEdit(ctx) then EXT:save() end
          if EXT.CONF_stepmode == 10 then
            ImGui.SameLine(ctx)
            reaper.ImGui_SetNextItemWidth(ctx, 100)
            local retval, v = reaper.ImGui_SliderDouble( ctx, 'ahead##shiftboundary_ahead', EXT.CONF_stepmode_transientahead, 0, 0.1, '%.3f sec', ImGui.SliderFlags_None )
            if retval then EXT.CONF_stepmode_transientahead = v end if reaper.ImGui_IsItemDeactivatedAfterEdit(ctx) then EXT:save() end
          end
          local retval, v = ImGui.Checkbox( ctx, 'Keep slice length', EXT.CONF_stepmode_keeplen==1 )
          if retval then EXT.CONF_stepmode_keeplen=EXT.CONF_stepmode_keeplen~1 EXT:save() end  
          
          if EXT.CONF_stepmode ~= 10 then
            if ImGui.Button(ctx, '< Move left##movestoffsleftend') then  
              local dir = -1
              DATA:Action_ShiftOffset(note_layer_t, 1, dir) 
            end
            ImGui.SameLine(ctx)
          end 
          if ImGui.Button(ctx, 'Move right >##movestoffsrightend') then 
            local dir = 1
            DATA:Action_ShiftOffset(note_layer_t, 1, dir) 
          end 
          ImGui.SameLine(ctx)
          if ImGui.Button(ctx, 'End >##moveendoffsrighttoend') then 
            local dir = 1
            DATA:Action_ShiftOffset(note_layer_t, 3, dir) 
          end 
          ImGui.EndTabItem( ctx) 
        end
        
        
        -- tools
        if ImGui.BeginTabItem( ctx, 'Tools##sampler_boundary_Tools', false, ImGui.TabItemFlags_None ) then 
          -- crop sample
          local toolongsample =  note_layer_t.SAMPLELEN and note_layer_t.SAMPLELEN > EXT.CONF_crop_maxlen
          if toolongsample then ImGui.BeginDisabled(ctx,true) end
          if ImGui.Button( ctx, 'Crop sample') then DATA:Action_CropToAudibleBoundaries(note_layer_t) end 
          ImGui.SameLine(ctx)
          ImGui.SetNextItemWidth(ctx, 90) 
          local ret, v = ImGui.SliderDouble( ctx, 'Threshold##cropsplthresh', EXT.CONF_cropthreshold, -80, -10, '%.0f dB', ImGui.SliderFlags_None ) 
          if ret then EXT.CONF_cropthreshold = v end if reaper.ImGui_IsItemDeactivatedAfterEdit(ctx) then EXT:save() end  -- Sampler: Crop threshold
          if toolongsample then ImGui.EndDisabled(ctx) end 
          
          ImGui.EndTabItem( ctx) 
        end
        ImGui.EndTabBar( ctx)
      end
      ImGui.EndChild(ctx)
    end
  end
  --------------------------------------------------------------------------------
  function UI.draw_tabs_Sampler_tabs_sample() 
    local note_layer_t = DATA:Sampler_GetActiveNoteLayer() if not note_layer_t then return end
    if note_layer_t.TYPE_DEVICE== true then return end
    
    ImGui.Dummy(ctx,0,0)
    
    if ImGui.Button(ctx, '< Previous spl',UI.calc_sampler4ctrl_W) then DATA:Sampler_NextPrevSample(note_layer_t, 1) end 
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, 'Next spl >',UI.calc_sampler4ctrl_W) then DATA:Sampler_NextPrevSample(note_layer_t, 0) end
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, 'Random spl',UI.calc_sampler4ctrl_W) then DATA:Sampler_NextPrevSample(note_layer_t, 2) end
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, 'MediaExplorer',UI.calc_sampler4ctrl_W) then  DATA:Sampler_ShowME() ImGui.CloseCurrentPopup(ctx) end
    
    
    -- database stuff
    local retval, v = ImGui.Checkbox( ctx, 'Use database', note_layer_t.SET_useDB&1==1 )
    if retval then 
      DATA:CollectDataInit_ParseREAPERDB()
      DATA:WriteData_Child(note_layer_t.tr_ptr, { SET_useDB = note_layer_t.SET_useDB~1, SET_useDB_lastID = 0, })  
      DATA.upd = true 
    end 
    
    
    if note_layer_t.SET_useDB&1==1 then  
      -- select db
      ImGui.SameLine(ctx)
      ImGui.SetNextItemWidth(ctx, -1)
      if ImGui.BeginCombo( ctx, '##dbselect', note_layer_t.SET_useDB_name, ImGui.ComboFlags_None ) then
        for dbname in pairs(DATA.reaperDB) do
          if ImGui.Selectable( ctx, dbname, false, ImGui.SelectableFlags_None) then 
            DATA:WriteData_Child(note_layer_t.tr_ptr, {SET_useDB_name = dbname})  
            DATA.upd = true 
          end
        end
        ImGui.EndCombo( ctx )
      end
      
      -- lock
      local retval, v = ImGui.Checkbox( ctx, 'Lock from "New random kit" action', note_layer_t.SET_useDB&2==2 )
      if retval then 
        DATA:WriteData_Child(note_layer_t.tr_ptr, {SET_useDB = note_layer_t.SET_useDB~2})  
        DATA.upd = true 
      end
      ImGui.SameLine(ctx)
      ImGui.Dummy(ctx,UI.spacingX,40)
      --ImGui.SameLine(ctx)
      
      -- new kit
      ImGui.PushStyleColor(ctx, ImGui.Col_Button, 0xFF000050)
      if ImGui.Button(ctx, 'New random database kit',-30) then  
        Undo_BeginBlock2(DATA.proj )
        DATA:Sampler_NewRandomKit()
        Undo_EndBlock2( DATA.proj , 'RS5k manager - New kit', 0xFFFFFFFF )
      end
      ImGui.PopStyleColor(ctx)
      ImGui.SameLine(ctx)
      UI.HelpMarker('Randomize ALL samples linked to databases in current rack') 
    end
    
  end
  -----------------------------------------------------------------------------------------  
  function UI.draw_tabs_Sampler_tabs_FX()
    local note_layer_t, note = DATA:Sampler_GetActiveNoteLayer() if not note_layer_t then return end
    if note_layer_t.TYPE_DEVICE== true then return end
    local curposx_abs, curposy_abs = ImGui.GetCursorScreenPos(ctx)
     
    UI.draw_knob(
      {str_id = '##note_layer_fx_reaeq_cut',
      is_small_knob = true,
      val = note_layer_t.fx_reaeq_cut,
      x = curposx_abs, 
      y = curposy_abs,
      w = UI.calc_knob_w_small,
      h = UI.calc_knob_h_small,
      name = 'Freq',
      --knob_resY = 10000,
      val_form = note_layer_t.fx_reaeq_cut_format,
      appfunc_atclick = function(v)   end,
      appfunc_atdrag = function(v) 
        DATA:Validate_InitFilterDrive(note_layer_t) 
        if note_layer_t.fx_reaeq_pos then 
          note_layer_t.fx_reaeq_cut =v 
          TrackFX_SetParamNormalized( note_layer_t.tr_ptr, note_layer_t.fx_reaeq_pos, 0, v ) 
          DATA:CollectData_Children_FXParams(note_layer_t)  
        end
      end,
      parseinput = function(str_in)
        if not str_in then return end
        local v = VF_BFpluginparam(str_in, note_layer_t.tr_ptr, note_layer_t.fx_reaeq_pos, 0)
        TrackFX_SetParamNormalized( note_layer_t.tr_ptr, note_layer_t.fx_reaeq_pos, 0, v )    
        DATA:CollectData_Children_InstrumentParams(note_layer_t,true) -- minor refresh formatted values
      end,
      }) 
    
    UI.draw_knob(
      {str_id = '##note_layer_fx_reaeq_gain', 
      is_small_knob = true,
      val =note_layer_t.fx_reaeq_gain,
      x = curposx_abs + UI.calc_knob_w_small + UI.spacingX, 
      y = curposy_abs,
      w = UI.calc_knob_w_small,
      h = UI.calc_knob_h_small,
      name = 'Gain',
      --knob_resY = 10000,
      disabled = (note_layer_t.fx_reaeq_bandtype == -1  or note_layer_t.fx_reaeq_bandtype == 3 or note_layer_t.fx_reaeq_bandtype == 4),
      val_form = note_layer_t.fx_reaeq_gain_format,
      appfunc_atclick = function(v)   end,
      appfunc_atdrag = function(v) 
        DATA:Validate_InitFilterDrive(note_layer_t) 
        if note_layer_t.fx_reaeq_pos then 
          note_layer_t.fx_reaeq_gain =v 
          TrackFX_SetParamNormalized( note_layer_t.tr_ptr, note_layer_t.fx_reaeq_pos, 1, v ) 
          DATA:CollectData_Children_FXParams(note_layer_t)  
        end
      end,
      parseinput = function(str_in)
        if not str_in then return end
        local v = VF_BFpluginparam(str_in, note_layer_t.tr_ptr, note_layer_t.fx_reaeq_pos, 1)
        TrackFX_SetParamNormalized( note_layer_t.tr_ptr, note_layer_t.fx_reaeq_pos, 1, v )  
        DATA:CollectData_Children_InstrumentParams(note_layer_t,true) -- minor refresh formatted values
      end,
      })

    -- filter
    ImGui.SetCursorScreenPos(ctx,curposx_abs, curposy_abs+ UI.calc_knob_h_small+UI.spacingY)
    
    ImGui.SetNextItemWidth(ctx, UI.calc_knob_w_small*2+UI.spacingX)
    local preview_value = 'Filter OFF'
    if note_layer_t.fx_reaeq_bandenabled == true  then  preview_value = DATA.bandtypemap[note_layer_t.fx_reaeq_bandtype] end
    if ImGui.BeginCombo( ctx, '##filter', preview_value, ImGui.ComboFlags_None ) then
      for band_type_val in spairs(DATA.bandtypemap) do
        local label = DATA.bandtypemap[band_type_val]
        if ImGui.Selectable( ctx, label, p_selected, ImGui.SelectableFlags_None ) then
          DATA:Validate_InitFilterDrive(note_layer_t) 
          if note_layer_t.fx_reaeq_pos then 
            if band_type_val == -1 then 
              TrackFX_SetNamedConfigParm( note_layer_t.tr_ptr, note_layer_t.fx_reaeq_pos, 'BANDENABLED0', 0 )
             else
              TrackFX_SetNamedConfigParm( note_layer_t.tr_ptr, note_layer_t.fx_reaeq_pos, 'BANDTYPE0', band_type_val )
              TrackFX_SetNamedConfigParm( note_layer_t.tr_ptr, note_layer_t.fx_reaeq_pos, 'BANDENABLED0', 1 )
            end
          end
          DATA.upd = true
        end
      end
      ImGui.EndCombo( ctx)
    end
  
    UI.draw_knob(
      {str_id = '##note_layer_fx_ws_drive', 
      is_small_knob = true,
      val =note_layer_t.fx_ws_drive,
      default_val = 0,
      x = curposx_abs + (UI.calc_knob_w_small + UI.spacingX)*2, 
      y = curposy_abs,
      w = UI.calc_knob_w_small,
      h = UI.calc_knob_h_small,
      name = 'Drive',
      --knob_resY = 10000,
      val_form = note_layer_t.fx_ws_drive_format,
      appfunc_atclick = function(v)   end,
      appfunc_atdrag = function(v) 
        DATA:Validate_InitFilterDrive(note_layer_t) 
        if note_layer_t.fx_ws_pos then 
          note_layer_t.fx_ws_drive =v 
          TrackFX_SetParamNormalized( note_layer_t.tr_ptr, note_layer_t.fx_ws_pos, 0, v ) 
          DATA:CollectData_Children_FXParams(note_layer_t)  
        end
      end,
      })
    
    
    
    
  end
    ----------------------------------------------------------------------------------------- 
  function UI.draw_tabs_Sampler_tabs_3rdpartycontrols_store(x,y,note_layer_t,key)
    if not (note_layer_t and note_layer_t.instrument_fx_name) then return end
    local fx_name = note_layer_t.instrument_fx_name
    local retval, trackidx, itemidx, takeidx, fxidx, parm = GetTouchedOrFocusedFX( 0 )
    
    if not retval then return end
    
    ImGui.SetCursorScreenPos(ctx, x,y)
    if ImGui.Button(ctx, 'Link##'..key, UI.calc_knob_w_small) then
      if not DATA.plugin_mapping[fx_name] then DATA.plugin_mapping[fx_name] = {} end
      DATA.plugin_mapping[fx_name][key] = parm
      DATA:CollectDataInit_PluginParametersMapping_Set() 
      DATA.upd = true
    end
    --
    --DATA.plugin_mapping
  end
    ----------------------------------------------------------------------------------------- 
  function UI.draw_tabs_Sampler_tabs_3rdpartycontrols()
    local note_layer_t,note,layer = DATA:Sampler_GetActiveNoteLayer() if not note_layer_t then return end
    if not note_layer_t.instrument_pos then return end
    if note_layer_t.ISRS5K then return end
    local curposx_abs, curposy_abs = ImGui.GetCursorScreenPos(ctx)
    
    UI.draw_knob(
      {str_id = '##spl_vol',
      is_small_knob = true,
      val = note_layer_t.instrument_vol,
      x = curposx_abs, 
      y = curposy_abs,
      w = UI.calc_knob_w_small,
      h = UI.calc_knob_h_small,
      name = 'Gain',
      val_form = note_layer_t.instrument_vol_format,
      appfunc_atclick = function(v)   end,
      appfunc_atdrag = function(v)  
        if not note_layer_t.instrument_volID then return end
        note_layer_t.instrument_vol =v 
        TrackFX_SetParamNormalized( note_layer_t.tr_ptr, note_layer_t.instrument_pos, note_layer_t.instrument_volID, v )    
        DATA:CollectData_Children_InstrumentParams(note_layer_t,true) -- minor refresh formatted values
      end,
      parseinput = function(str_in)
        if not note_layer_t.instrument_volID then return end
        if not str_in then return end
        local v = VF_BFpluginparam(str_in, note_layer_t.tr_ptr, note_layer_t.instrument_pos, note_layer_t.instrument_volID)
        TrackFX_SetParamNormalized( note_layer_t.tr_ptr, note_layer_t.instrument_pos, note_layer_t.instrument_volID, v )    
        DATA:CollectData_Children_InstrumentParams(note_layer_t,true) -- minor refresh formatted values
      end,
      })
    UI.draw_tabs_Sampler_tabs_3rdpartycontrols_store(curposx_abs,curposy_abs+UI.calc_knob_h_small+UI.spacingY,note_layer_t,'instrument_volID')
    
    local xpos = curposx_abs + UI.calc_knob_w_small + UI.spacingX
    UI.draw_knob(
      {str_id = '##note_layer_tune',
      is_small_knob = true,
      val = note_layer_t.instrument_tune,
      x = xpos, 
      y = curposy_abs,
      w = UI.calc_knob_w_small,
      h = UI.calc_knob_h_small,
      name = 'Tune',
      knob_resY = 10000,
      val_form = note_layer_t.instrument_tune_format,
      appfunc_atclick = function(v)   end,
      appfunc_atdrag = function(v) 
        if not note_layer_t.instrument_tuneID then return end
        note_layer_t.instrument_tune =v 
        TrackFX_SetParamNormalized( note_layer_t.tr_ptr, note_layer_t.instrument_pos, note_layer_t.instrument_tuneID, v )    
        DATA:CollectData_Children_InstrumentParams(note_layer_t,true) -- minor refresh formatted values
      end,
      parseinput = function(str_in)
        if not str_in then return end
        if not note_layer_t.instrument_tuneID then return end
        local v = VF_BFpluginparam(str_in, note_layer_t.tr_ptr, note_layer_t.instrument_pos, note_layer_t.instrument_tuneID) 
        TrackFX_SetParamNormalized( note_layer_t.tr_ptr, note_layer_t.instrument_pos, note_layer_t.instrument_tuneID, v )    
        DATA:CollectData_Children_InstrumentParams(note_layer_t,true) -- minor refresh formatted values
      end,
      })  
    UI.draw_tabs_Sampler_tabs_3rdpartycontrols_store(xpos,curposy_abs+UI.calc_knob_h_small+UI.spacingY,note_layer_t,'instrument_tuneID')
    
    UI.draw_knob(
      {str_id = '##note_layer_instrument_attack',
      is_small_knob = true,
      val = note_layer_t.instrument_attack,
      x = curposx_abs + (UI.calc_knob_w_small + UI.spacingX)*3, 
      y = curposy_abs,
      w = UI.calc_knob_w_small,
      h = UI.calc_knob_h_small,
      name = 'Attack',
      --knob_resY = 10000,
      val_form = note_layer_t.instrument_attack_format,
      appfunc_atclick = function(v)   end,
      appfunc_atdrag = function(v) 
        if not note_layer_t.instrument_attackID then return end
        note_layer_t.instrument_attack =v 
        TrackFX_SetParamNormalized( note_layer_t.tr_ptr, note_layer_t.instrument_pos, note_layer_t.instrument_attackID, v)    
        DATA:CollectData_Children_InstrumentParams(note_layer_t,true) -- minor refresh formatted values
      end,
      parseinput = function(str_in)
        if not str_in then return end
        if not note_layer_t.instrument_attackID then return end
        local v = VF_BFpluginparam(str_in, note_layer_t.tr_ptr, note_layer_t.instrument_pos, note_layer_t.instrument_attackID) 
        TrackFX_SetParamNormalized( note_layer_t.tr_ptr, note_layer_t.instrument_pos, note_layer_t.instrument_attackID, v )    
        DATA:CollectData_Children_InstrumentParams(note_layer_t,true) -- minor refresh formatted values
      end,
      }) 
    UI.draw_tabs_Sampler_tabs_3rdpartycontrols_store(curposx_abs + (UI.calc_knob_w_small + UI.spacingX)*3,curposy_abs+UI.calc_knob_h_small+UI.spacingY,note_layer_t,'instrument_attackID')
    
    UI.draw_knob(
      {str_id = '##note_layer_instrument_decay',
      is_small_knob = true,
      val = note_layer_t.instrument_decay,
      x = curposx_abs + (UI.calc_knob_w_small + UI.spacingX)*4, 
      y = curposy_abs,
      w = UI.calc_knob_w_small,
      h = UI.calc_knob_h_small,
      name = 'Decay',
      --knob_resY = 10000,
      val_form = note_layer_t.instrument_decay_format,
      appfunc_atclick = function(v)   end,
      appfunc_atdrag = function(v) 
        if not note_layer_t.instrument_decayID then return end
        note_layer_t.instrument_decay =v 
        TrackFX_SetParamNormalized( note_layer_t.tr_ptr, note_layer_t.instrument_pos, note_layer_t.instrument_decayID, v )    
        DATA:CollectData_Children_InstrumentParams(note_layer_t,true) -- minor refresh formatted values
      end,
      parseinput = function(str_in)
        if not str_in then return end
        if not note_layer_t.instrument_decayID then return end
        local v = VF_BFpluginparam(str_in, note_layer_t.tr_ptr, note_layer_t.instrument_pos, note_layer_t.instrument_decayID) 
        TrackFX_SetParamNormalized( note_layer_t.tr_ptr, note_layer_t.instrument_pos, note_layer_t.instrument_decayID, v )    
        DATA:CollectData_Children_InstrumentParams(note_layer_t,true) -- minor refresh formatted values
      end,
      }) 
    UI.draw_tabs_Sampler_tabs_3rdpartycontrols_store(curposx_abs + (UI.calc_knob_w_small + UI.spacingX)*4,curposy_abs+UI.calc_knob_h_small+UI.spacingY,note_layer_t,'instrument_decayID')
        
    UI.draw_knob(
      {str_id = '##note_layer_instrument_sustain',
      is_small_knob = true,
      val = note_layer_t.instrument_sustain,
      x = curposx_abs + (UI.calc_knob_w_small + UI.spacingX)*5, 
      y = curposy_abs,
      w = UI.calc_knob_w_small,
      h = UI.calc_knob_h_small,
      name = 'Sustain',
      --knob_resY = 10000,
      val_form = note_layer_t.instrument_sustain_format,
      appfunc_atclick = function(v)   end,
      appfunc_atdrag = function(v) 
        if not note_layer_t.instrument_sustainID then return end
        note_layer_t.instrument_sustain =v
        TrackFX_SetParamNormalized( note_layer_t.tr_ptr, note_layer_t.instrument_pos, note_layer_t.instrument_sustainID, v)    
        DATA:CollectData_Children_InstrumentParams(note_layer_t,true) -- minor refresh formatted values
      end,
      parseinput = function(str_in)
        if not str_in then return end
        if not note_layer_t.instrument_sustainID then return end
        local v = VF_BFpluginparam(str_in, note_layer_t.tr_ptr, note_layer_t.instrument_pos, note_layer_t.instrument_sustainID) 
        TrackFX_SetParamNormalized( note_layer_t.tr_ptr, note_layer_t.instrument_pos, note_layer_t.instrument_sustainID, v )    
        DATA:CollectData_Children_InstrumentParams(note_layer_t,true) -- minor refresh formatted values
      end,
      }) 
    UI.draw_tabs_Sampler_tabs_3rdpartycontrols_store(curposx_abs + (UI.calc_knob_w_small + UI.spacingX)*5,curposy_abs+UI.calc_knob_h_small+UI.spacingY,note_layer_t,'instrument_sustainID')
    
    UI.draw_knob(
      {str_id = '##note_layer_instrument_release',
      is_small_knob = true,
      val = note_layer_t.instrument_release,
      x = curposx_abs + (UI.calc_knob_w_small + UI.spacingX)*6, 
      y = curposy_abs,
      w = UI.calc_knob_w_small,
      h = UI.calc_knob_h_small,
      name = 'Release',
      --knob_resY = 10000,
      val_form = note_layer_t.instrument_release_format,
      appfunc_atclick = function(v)   end,
      appfunc_atdrag = function(v) 
        if not note_layer_t.instrument_releaseID then return end
        note_layer_t.instrument_release =v
        TrackFX_SetParamNormalized( note_layer_t.tr_ptr, note_layer_t.instrument_pos, note_layer_t.instrument_releaseID, v )    
        DATA:CollectData_Children_InstrumentParams(note_layer_t,true) -- minor refresh formatted values
      end,
      parseinput = function(str_in)
        if not str_in then return end
        if not note_layer_t.instrument_releaseID then return end
        local v = VF_BFpluginparam(str_in, note_layer_t.tr_ptr, note_layer_t.instrument_pos, note_layer_t.instrument_releaseID) 
        TrackFX_SetParamNormalized( note_layer_t.tr_ptr, note_layer_t.instrument_pos, note_layer_t.instrument_releaseID, v )    
        DATA:CollectData_Children_InstrumentParams(note_layer_t,true) -- minor refresh formatted values
      end,
      }) 
    UI.draw_tabs_Sampler_tabs_3rdpartycontrols_store(curposx_abs + (UI.calc_knob_w_small + UI.spacingX)*6,curposy_abs+UI.calc_knob_h_small+UI.spacingY,note_layer_t,'instrument_releaseID')
  end  
    ----------------------------------------------------------------------------------------- 
  function UI.draw_tabs_Sampler_tabs_rs5kcontrols_tune(note_layer_t, val)
    local note_layer_t,note,layer = DATA:Sampler_GetActiveNoteLayer() if not note_layer_t then return end
    
    local out = note_layer_t.instrument_tune + val/160 
    note_layer_t.instrument_tune =v 
    TrackFX_SetParamNormalized( note_layer_t.tr_ptr, note_layer_t.instrument_pos, note_layer_t.instrument_tuneID, out )    
    DATA:CollectData_Children_InstrumentParams(note_layer_t,true) -- minor refresh formatted values
    
  end
    ----------------------------------------------------------------------------------------- 
  function UI.draw_tabs_Sampler_tabs_rs5kcontrols()
    local note_layer_t,note,layer = DATA:Sampler_GetActiveNoteLayer() if not note_layer_t then return end
    if not note_layer_t.instrument_pos then return end
    if not note_layer_t.ISRS5K then return end
    local curposx_abs, curposy_abs = ImGui.GetCursorScreenPos(ctx)
    
    UI.draw_knob(
      {str_id = '##spl_vol',
      is_small_knob = true,
      val = note_layer_t.instrument_vol, 
      default_val = 0.5,
      x = curposx_abs, 
      y = curposy_abs,
      w = UI.calc_knob_w_small,
      h = UI.calc_knob_h_small,
      name = 'Gain',
      val_form = note_layer_t.instrument_vol_format,
      appfunc_atclick = function(v)   end,
      appfunc_atdrag = function(v)  
        note_layer_t.instrument_vol =v 
        TrackFX_SetParamNormalized( note_layer_t.tr_ptr, note_layer_t.instrument_pos, note_layer_t.instrument_volID, v )    
        DATA:CollectData_Children_InstrumentParams(note_layer_t,true) -- minor refresh formatted values 
      end,
      parseinput = function(str_in)
        if not str_in then return end
        local v = VF_BFpluginparam(str_in, note_layer_t.tr_ptr, note_layer_t.instrument_pos, note_layer_t.instrument_volID)
        TrackFX_SetParamNormalized( note_layer_t.tr_ptr, note_layer_t.instrument_pos, note_layer_t.instrument_volID, v )    
        DATA:CollectData_Children_InstrumentParams(note_layer_t,true) -- minor refresh formatted values
      end,
      appfunc_atclickR = function(v) if UI.anypopupopen==true then DATA.trig_closepopup = true else DATA.trig_openpopup = 'rs5k_ctrl' DATA.trig_openpopup_context = 'gain' end  end,
      draw_macro_index = note_layer_t['instrument_volID_MACRO'],
      })
      
    UI.draw_knob(
      {str_id = '##note_layer_tune',
      is_small_knob = true,
      val = note_layer_t.instrument_tune, 
      default_val = 0.5,
      x = curposx_abs + UI.calc_knob_w_small + UI.spacingX, 
      y = curposy_abs,
      w = UI.calc_knob_w_small,
      h = UI.calc_knob_h_small,
      name = 'Tune',
      knob_resY = 10000,
      val_form = note_layer_t.instrument_tune_format,
      appfunc_atclick = function(v)   end,
      appfunc_atdrag = function(v) 
        note_layer_t.instrument_tune =v 
        TrackFX_SetParamNormalized( note_layer_t.tr_ptr, note_layer_t.instrument_pos, note_layer_t.instrument_tuneID, v )    
        DATA:CollectData_Children_InstrumentParams(note_layer_t,true) -- minor refresh formatted values
      end,
      parseinput = function(str_in)
        if not str_in then return end
        local v = VF_BFpluginparam(str_in, note_layer_t.tr_ptr, note_layer_t.instrument_pos, note_layer_t.instrument_tuneID) 
        TrackFX_SetParamNormalized( note_layer_t.tr_ptr, note_layer_t.instrument_pos, note_layer_t.instrument_tuneID, v )    
        DATA:CollectData_Children_InstrumentParams(note_layer_t,true) -- minor refresh formatted values
      end,
      draw_macro_index = note_layer_t['instrument_tuneID_MACRO'],
      })  
    
    -- tune stuff
      local labelw = 40
      ImGui.SetCursorScreenPos(ctx, curposx_abs + (UI.calc_knob_w_small + UI.spacingX)*2, curposy_abs + UI.spacingY)
      if ImGui.Button(ctx, '-##oct-') then UI.draw_tabs_Sampler_tabs_rs5kcontrols_tune(note_layer_t,-12) end
      ImGui.SameLine(ctx)
      ImGui.Button(ctx, 'oct', labelw)
      ImGui.SameLine(ctx)
      if ImGui.Button(ctx, '+##oct+') then UI.draw_tabs_Sampler_tabs_rs5kcontrols_tune(note_layer_t,12) end
      
      ImGui.SetCursorScreenPos(ctx, curposx_abs + (UI.calc_knob_w_small + UI.spacingX)*2, curposy_abs + UI.calc_knob_h_small*1/3 + UI.spacingY)
      if ImGui.Button(ctx, '-##semi-') then UI.draw_tabs_Sampler_tabs_rs5kcontrols_tune(note_layer_t,-1) end
      ImGui.SameLine(ctx)
      ImGui.Button(ctx, 'semi', labelw)
      ImGui.SameLine(ctx)
      if ImGui.Button(ctx, '+##semi+') then UI.draw_tabs_Sampler_tabs_rs5kcontrols_tune(note_layer_t,1) end
      
      ImGui.SetCursorScreenPos(ctx, curposx_abs + (UI.calc_knob_w_small + UI.spacingX)*2, curposy_abs + UI.calc_knob_h_small*2/3 + UI.spacingY)
      if ImGui.Button(ctx, '-##cent-') then UI.draw_tabs_Sampler_tabs_rs5kcontrols_tune(note_layer_t,-0.01) end
      ImGui.SameLine(ctx)
      ImGui.Button(ctx, 'cent', labelw)
      ImGui.SameLine(ctx)
      if ImGui.Button(ctx, '+##cent+') then UI.draw_tabs_Sampler_tabs_rs5kcontrols_tune(note_layer_t,0.01) end
    
    
    ImGui.SetCursorScreenPos(ctx, curposx_abs , curposy_abs + UI.calc_knob_h_small +  UI.spacingY)
    
    --if ImGui.Checkbox(ctx, 'Tweak ALL samples ',(DATA.VCA_mode or 0 )&1==1) then DATA.VCA_mode = (DATA.VCA_mode or 0 )~1 end
    --if ImGui.Checkbox(ctx, 'Tweak ony current pad layers',(DATA.VCA_mode or 0 )&2==2 or (DATA.VCA_mode or 0 )&1==1) then DATA.VCA_mode = (DATA.VCA_mode or 0 )~2 end
    
    local attmult = 10
    UI.draw_knob(
      {str_id = '##note_layer_instrument_attack',
      is_small_knob = true,
      val = math.min(1,note_layer_t.instrument_attack_norm*attmult), 
      default_val = 0,
      x = curposx_abs + (UI.calc_knob_w_small + UI.spacingX)*4, 
      y = curposy_abs,
      w = UI.calc_knob_w_small,
      h = UI.calc_knob_h_small,
      name = 'Attack',
      --knob_resY = 10000,
      val_form = note_layer_t.instrument_attack_format,
      appfunc_atclick = function(v)   end,
      appfunc_atdrag = function(v) 
        note_layer_t.instrument_attack =v /note_layer_t.instrument_attack_max
        TrackFX_SetParamNormalized( note_layer_t.tr_ptr, note_layer_t.instrument_pos, note_layer_t.instrument_attackID, v*note_layer_t.instrument_attack_max/attmult )    
        DATA:CollectData_Children_InstrumentParams(note_layer_t,true) -- minor refresh formatted values
      end,
      parseinput = function(str_in)
        if not str_in then return end
        local v = VF_BFpluginparam(str_in, note_layer_t.tr_ptr, note_layer_t.instrument_pos, note_layer_t.instrument_attackID) 
        TrackFX_SetParamNormalized( note_layer_t.tr_ptr, note_layer_t.instrument_pos, note_layer_t.instrument_attackID, v )    
        DATA:CollectData_Children_InstrumentParams(note_layer_t,true) -- minor refresh formatted values
      end,
      appfunc_atclickR = function(v) if UI.anypopupopen==true then DATA.trig_closepopup = true else DATA.trig_openpopup = 'rs5k_ctrl' DATA.trig_openpopup_context = 'attack' end  end,
      draw_macro_index = note_layer_t['instrument_attackID_MACRO'],
      }) 
    
    local delmult = 40
    UI.draw_knob(
      {str_id = '##note_layer_instrument_decay',
      is_small_knob = true,
      val = math.min(note_layer_t.instrument_decay*delmult,1),
      default_val = 0.5,
      x = curposx_abs + (UI.calc_knob_w_small + UI.spacingX)*5, 
      y = curposy_abs,
      w = UI.calc_knob_w_small,
      h = UI.calc_knob_h_small,
      name = 'Decay',
      --knob_resY = 10000,
      val_form = note_layer_t.instrument_decay_format,
      appfunc_atclick = function(v)   end,
      appfunc_atdrag = function(v) 
        note_layer_t.instrument_decay =v  / delmult
        TrackFX_SetParamNormalized( note_layer_t.tr_ptr, note_layer_t.instrument_pos, note_layer_t.instrument_decayID, v/delmult )    
        DATA:CollectData_Children_InstrumentParams(note_layer_t,true) -- minor refresh formatted values
      end,
      parseinput = function(str_in)
        if not str_in then return end
        local v = VF_BFpluginparam(str_in, note_layer_t.tr_ptr, note_layer_t.instrument_pos, note_layer_t.instrument_decayID) 
        TrackFX_SetParamNormalized( note_layer_t.tr_ptr, note_layer_t.instrument_pos, note_layer_t.instrument_decayID, v )    
        DATA:CollectData_Children_InstrumentParams(note_layer_t,true) -- minor refresh formatted values
      end,
      appfunc_atclickR = function(v) if UI.anypopupopen==true then DATA.trig_closepopup = true else DATA.trig_openpopup = 'rs5k_ctrl' DATA.trig_openpopup_context = 'decay' end  end,
      draw_macro_index = note_layer_t['instrument_decayID_MACRO'],
      }) 

        
    UI.draw_knob(
      {str_id = '##note_layer_instrument_sustain',
      is_small_knob = true,
      val =  math.min(1,note_layer_t.instrument_sustain*2),
      default_val = 0.5,
      x = curposx_abs + (UI.calc_knob_w_small + UI.spacingX)*6, 
      y = curposy_abs,
      w = UI.calc_knob_w_small,
      h = UI.calc_knob_h_small,
      name = 'Sustain',
      --knob_resY = 10000,
      val_form = note_layer_t.instrument_sustain_format,
      appfunc_atclick = function(v)   end,
      appfunc_atdrag = function(v) 
        note_layer_t.instrument_sustain =v
        TrackFX_SetParamNormalized( note_layer_t.tr_ptr, note_layer_t.instrument_pos, note_layer_t.instrument_sustainID, v/2)    
        DATA:CollectData_Children_InstrumentParams(note_layer_t,true) -- minor refresh formatted values
      end,
      parseinput = function(str_in)
        if not str_in then return end
        local v = VF_BFpluginparam(str_in, note_layer_t.tr_ptr, note_layer_t.instrument_pos, note_layer_t.instrument_sustainID) 
        TrackFX_SetParamNormalized( note_layer_t.tr_ptr, note_layer_t.instrument_pos, note_layer_t.instrument_sustainID, v )    
        DATA:CollectData_Children_InstrumentParams(note_layer_t,true) -- minor refresh formatted values
      end,
      appfunc_atclickR = function(v) if UI.anypopupopen==true then DATA.trig_closepopup = true else DATA.trig_openpopup = 'rs5k_ctrl' DATA.trig_openpopup_context = 'sustain' end  end,
      draw_macro_index = note_layer_t['instrument_sustainID_MACRO'],
      }) 


    UI.draw_knob(
      {str_id = '##note_layer_instrument_release',
      is_small_knob = true,
      val = note_layer_t.instrument_release_norm,
      default_val = 0.01,
      x = curposx_abs + (UI.calc_knob_w_small + UI.spacingX)*7, 
      y = curposy_abs,
      w = UI.calc_knob_w_small,
      h = UI.calc_knob_h_small,
      name = 'Release',
      --knob_resY = 10000,
      val_form = note_layer_t.instrument_release_format,
      appfunc_atclick = function(v)   end,
      appfunc_atdrag = function(v) 
        note_layer_t.instrument_release =v /note_layer_t.instrument_release_max
        TrackFX_SetParamNormalized( note_layer_t.tr_ptr, note_layer_t.instrument_pos, note_layer_t.instrument_releaseID, v*note_layer_t.instrument_release_max )    
        DATA:CollectData_Children_InstrumentParams(note_layer_t,true) -- minor refresh formatted values
      end,
      parseinput = function(str_in)
        if not str_in then return end
        local v = VF_BFpluginparam(str_in, note_layer_t.tr_ptr, note_layer_t.instrument_pos, note_layer_t.instrument_releaseID) 
        TrackFX_SetParamNormalized( note_layer_t.tr_ptr, note_layer_t.instrument_pos, note_layer_t.instrument_releaseID, v )    
        DATA:CollectData_Children_InstrumentParams(note_layer_t,true) -- minor refresh formatted values
      end,
      appfunc_atclickR = function(v) if UI.anypopupopen==true then DATA.trig_closepopup = true else DATA.trig_openpopup = 'rs5k_ctrl' DATA.trig_openpopup_context = 'release' end  end,
      draw_macro_index = note_layer_t['instrument_releaseID_MACRO'],
      }) 
            
  end
  --------------------------------------------------------------------------------  
  function UI.draw_setbuttonbackgtransparent() 
      ImGui.PushStyleColor(ctx, ImGui.Col_Button,0) 
      ImGui.PushStyleColor(ctx, ImGui.Col_ButtonActive,0) 
      ImGui.PushStyleColor(ctx, ImGui.Col_ButtonHovered,0) 
  end
  ---------------------------------------------------------------------  
  function UI.Drop_UI_interaction_device(note, layer) 
    -- validate is file or pad dropped
    local retval, count = ImGui.AcceptDragDropPayloadFiles( ctx, 127, ImGui.DragDropFlags_None )
    if not retval then return end
      
    Undo_BeginBlock2(DATA.proj )
    for i = 1, count do 
      local retval, filename = reaper.ImGui_GetDragDropPayloadFile( ctx, i-1 )
      if not retval then return end 
      DATA:DropSample(filename, note + i-1, {layer=layer})
    end 
    Undo_EndBlock2( DATA.proj , 'RS5k manager - drop samples to pads', 0xFFFFFFFF ) 
  
  end
  
  ---------------------------------------------------------------------  
  function UI.Drop_UI_interaction_sampler() 
    -- validate is file or pad dropped
    local retval, count = ImGui.AcceptDragDropPayloadFiles( ctx, 1, ImGui.DragDropFlags_None )
    if not retval then return end
    
    -- drop on sampler
    if DATA.parent_track.ext.PARENT_LASTACTIVENOTE and DATA.parent_track.ext.PARENT_LASTACTIVENOTE_LAYER then  
      local retval, filename = reaper.ImGui_GetDragDropPayloadFile( ctx, 0 )
      if retval then 
        local note_layer_t, note, layer = DATA:Sampler_GetActiveNoteLayer() if not note_layer_t then return end
        DATA:DropSample(filename, note, {layer=layer})
      end
    end
  end   
  --------------------------------------------------------------------------------
  function UI.draw_tabs_Sampler_tabs_device()
    local note_layer_t, note, layer0 = DATA:Sampler_GetActiveNoteLayer() if not note_layer_t then return end  
    
    
    if not (DATA.children[note] and DATA.children[note].TYPE_DEVICE== true) then ImGui.BeginDisabled(ctx, true) end
      local retval, v = ImGui.Checkbox( ctx, 'Autovelocity', DATA.children[note].TYPE_DEVICE_AUTORANGE )
      ImGui.SameLine(ctx)
      UI.HelpMarker('Auto-set velocity range option enabled for new devices')
      if retval then 
        local tr = DATA.children[note].tr_ptr
        local out = 0
        if v == true then out = 1 end
        DATA:WriteData_Child(tr, {SET_MarkType_TYPE_DEVICE_AUTORANGE = out}) 
        DATA.upd = true
      end
      ImGui.SameLine(ctx)
      if ImGui.Button(ctx, 'Refresh##autosetvelrange', 80) then DATA:Auto_Device_RefreshVelocityRange(note) end
    if not (DATA.children[note] and DATA.children[note].TYPE_DEVICE== true) then ImGui.EndDisabled(ctx) end
    
    -- device drop 
    ImGui.SameLine(ctx)
    ImGui.Button(ctx, '[Drop layers]', 110)
    if ImGui.BeginDragDropTarget( ctx ) then  
      local cntlayers = 0
      if DATA.children[note] and DATA.children[note].layers then cntlayers = #DATA.children[note].layers end
      UI.Drop_UI_interaction_device(note, cntlayers + 1)   
      ImGui_EndDragDropTarget( ctx )
    end
    
    -- device drop FX
    ImGui.SameLine(ctx)
    local cntlayers = 0
    if DATA.children[note] and DATA.children[note].layers then cntlayers = #DATA.children[note].layers end
    local drop_data = {layer = cntlayers + 1}
    UI.draw_3rdpartyimport_context(note,drop_data) 
    
    
    if ImGui.BeginChild( ctx, 'device' ,0,-UI.spacingY) then--,ImGui.ChildFlags_None, ImGui.WindowFlags_NoScrollWithMouse
      ImGui.PushStyleVar(ctx, ImGui.StyleVar_FramePadding,0,UI.spacingY) 
      ImGui.PushStyleVar(ctx, ImGui.StyleVar_GrabMinSize,5)
      
      
      local name_w = 185
      local slider_w = 60
      
      
      --- layers list
      for layer = 1, #DATA.children[note].layers do
        
        local posx,posy = ImGui.GetCursorPos(ctx)
        local layer_t = DATA.children[note].layers[layer]
        
        -- name
        ImGui.SetNextItemWidth(ctx, name_w)
        if ImGui.Checkbox(ctx, '##layer'..layer, layer == layer0) then
          DATA.parent_track.ext.PARENT_LASTACTIVENOTE_LAYER = layer
          DATA:WriteData_Parent()
          DATA.upd = true
        end
        ImGui.SameLine(ctx)
        UI.draw_setbuttonbackgtransparent() 
        ImGui.Button(ctx, layer_t.P_NAME..'##layerbut'..layer,  name_w-30)
        ImGui.PopStyleColor(ctx,3)
        
        -- D_VOL
        ImGui.SetCursorPos(ctx,posx+name_w,posy)
        ImGui.SetNextItemWidth(ctx, slider_w)
        local formatIn = layer_t.D_VOL_format
        local retval, v = reaper.ImGui_SliderDouble( ctx, '##layervol'..layer, layer_t.D_VOL, 0, 2, formatIn, ImGui.SliderFlags_None )
        if retval then SetMediaTrackInfo_Value( layer_t.tr_ptr, 'D_VOL',v ) DATA.upd = true end
        ImGui.SameLine(ctx)
        
        -- D_PAN
        ImGui.SetNextItemWidth(ctx, slider_w)
        local formatIn = layer_t.D_PAN_format
        local retval, v = reaper.ImGui_SliderDouble( ctx, '##layerpan'..layer, layer_t.D_PAN, -1,1, formatIn, ImGui.SliderFlags_None )
        if retval then SetMediaTrackInfo_Value( layer_t.tr_ptr, 'D_PAN',v ) DATA.upd = true end
        ImGui.SameLine(ctx)
        
        -- solo
        if layer_t.I_SOLO>0 then ImGui.PushStyleColor(ctx, ImGui.Col_Text, 0x00FF00FF ) end
        if ImGui.Button(ctx, 'S##layerS'..layer, 23)  then 
          Undo_BeginBlock2(DATA.proj )
          local outval = 2 if layer_t.I_SOLO>0 then outval = 0 end SetMediaTrackInfo_Value( layer_t.tr_ptr, 'I_SOLO', outval ) DATA.upd = true
          Undo_EndBlock2( DATA.proj , 'RS5k manager - Solo pad', 0xFFFFFFFF ) 
        end 
        if layer_t.I_SOLO>0 then ImGui.PopStyleColor(ctx ) end
          
        -- mute
        ImGui.SameLine(ctx)
        if layer_t.B_MUTE>0 then ImGui.PushStyleColor(ctx, ImGui.Col_Text, 0xFF0000FF ) end
        if ImGui.Button(ctx, 'M##layerM'..layer, 23)  then
          Undo_BeginBlock2(DATA.proj )
          SetMediaTrackInfo_Value( layer_t.tr_ptr, 'B_MUTE', layer_t.B_MUTE~1 ) DATA.upd = true
          Undo_EndBlock2( DATA.proj , 'RS5k manager - Mute pad', 0xFFFFFFFF )         
        end
        if layer_t.B_MUTE>0 then ImGui.PopStyleColor(ctx ) end
        
        -- remove
        ImGui.SameLine(ctx)
        if ImGui.Button(ctx, 'X##layerem'..layer, -1) then DATA:Sampler_RemovePad(note,layer) end
        
      end
      
      
      
      
      ImGui.PopStyleVar(ctx,2)  
      ImGui.EndChild( ctx)
    end
  end
  --------------------------------------------------------------------------------   
  function _main_LoadLibraries()
    local info = debug.getinfo(1,'S');  
    local script_path = info.source:match([[^@?(.*[\/])[^\/]-$]]) 
    --dofile(script_path .. "mpl_RS5K_manager_functions.lua")
  end
  -----------------------------------------------------------------------------------------  
  function mpl_FixExtStateINI()
    -- IO
      local val = reaper.GetExtState( 'MPL_Scripts', 'INI_fix' )
      val = tonumber(val) or 0
      if val==1 then return end -- if this configuration is not fixed yet
      
      local fn = reaper.get_ini_file():lower()
      local fn_ext = fn:gsub('reaper%.ini', 'reaper-extstate.ini' )
      if not reaper.file_exists(fn_ext) then return end
      local content
      local f=io.open(fn_ext,'rb')
      if f then
        content = f:read('a')
        f:close()
      end
      if not content then return end 
    
    -- print chunk to table
      t = {} local i = 0 for line in content:gmatch('[^\r\n]+') do i=i+1 t[i]=line end local sz=#t
    
    -- modify chunk
      lines_cache = {}
      for i = sz,1,-1 do
        local cond
        local line = t[i] 
        local line_exist
        if lines_cache[line] then line_exist = true end
        lines_cache[line] = true
        local line_is_section = line:match('%[(.-)%]')~=nil and line:match('=') == nil
        local emptyline = line:match('%s+')==line
        local key,value = line:match('([%_%a%d]+)%=(.*)')
        local missedkv = not (key and value) and line~='[MPL_RS5K manager]'
        local key_is_number = key and key:match('[%_%d]+')==key 
        if (emptyline==true or missedkv==true or key_is_number == true or line_exist == true) and line_is_section~=true then table.remove(t,i) end
      end 
      local chunk_new = table.concat(t,'\n')  
    
    -- backup
      local fn_ext_backup = fn_ext..'-backup'
      if not reaper.file_exists(fn_ext_backup) then
        local f=io.open(fn_ext_backup,'wb')
        if f then
          f:write(content)
          f:close()
        end
      end
    
    -- write chunk_new
      local f=io.open(fn_ext,'wb')
      if f then
        content = f:write(chunk_new)
        f:close()
      end
    
    reaper.SetExtState( 'MPL_Scripts', 'INI_fix', 1, false  ) -- refresh state
    reaper.SetExtState( 'MPL_Scripts', 'INI_fix', 1, true  ) -- print persistently 
    
    
  end
  ------------------------------------------------------------------------------------------------------
  function literalize(str) -- http://stackoverflow.com/questions/1745448/lua-plain-string-gsub
     if str then  return str:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", function(c) return "%" .. c end) end
  end 
  -----------------------------------------------------------------------------------------  
  function _main() 
    _main_LoadLibraries()
    
    -- get sequencer ID
    for idx =0, 1000000 do
      local retval, name = reaper.kbd_enumerateActions( section, idx )
      if not ( retval and retval~= 0) then return end
      if name:match('mpl_') and name:match('RS5k') and name:match('StepSeq') then
        DATA.stepseq_ID = retval
        break
      end
    end
    
    -- load functions
    
    
    local loadtest = time_precise()
    
    gmem_attach('RS5K_manager')
    gmem_write(1026, 1) -- rs5k manager opened
    
    EXT.defaults = CopyTable(EXT)
    EXT:load() 
    DATA.REAPERini = VF_LIP_load( reaper.get_ini_file()) 
    DATA:CollectDataInit_MIDIdevices()  
    DATA:CollectDataInit_ParseREAPERDB()  
    DATA.loadtest = time_precise() - loadtest -- measure load databases
    
    UI.MAIN_definecontext()   -- + EXT:load
    
    -- after EXT:load
    DATA:CollectDataInit_PluginParametersMapping_Get() 
    DATA:CollectDataInit_ReadDBmaps()
    DATA:CollectDataInit_LoadCustomPadStuff()
    DATA:CollectDataInit_LoadCustomLayouts()
    DATA:CollectDataInit_EnumeratePlugins()
    --mpl_FixExtStateINI()
  end 
  
    --[[-------------------------------------------------------------------  
    function DATA:Launchpad_StuffSysex(SysEx_msg, mon_state0) 
      local mon_state = 0 if mon_state0 then mon_state = mon_state0 end
      if  DATA.MIDIbus and DATA.MIDIbus.tr_ptr and DATA.MIDIbus.valid == true then SetMediaTrackInfo_Value( DATA.MIDIbus.tr_ptr, 'I_RECMON', mon_state ) end -- prevent 
          
      if SysEx_msg and EXT.CONF_midioutput and EXT.CONF_midioutput ~=-1  then 
        local SysEx_msg_bin = '' for hex in SysEx_msg:gmatch('[A-F,0-9]+') do  SysEx_msg_bin = SysEx_msg_bin..string.char(tonumber(hex, 16)) end 
        SendMIDIMessageToHardware(EXT.CONF_midioutput, SysEx_msg_bin)   
      end
    end  ]]
    
    -------------------------------------------------------------------------------  
    function DATA:CollectData_Seq_ConvertMIDI2Steps() 
      local take = DATA.seq.tk_ptr
      if not reaper.TakeIsMIDI(take) then return end
      
      local it_pos = DATA.seq.it_pos
      local retval, measures, cml, it_pos_fullbeats, cdenom = reaper.TimeMap2_timeToBeats( -1, it_pos )
      local retval, notecnt, ccevtcnt, textsyxevtcnt = reaper.MIDI_CountEvts( take )
      for noteidx = 1, notecnt do 
        local retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote( take, noteidx-1 )
        local proj_time = MIDI_GetProjTimeFromPPQPos( take, startppqpos )
        local retval, measures, cml, proj_time_fullbeats, cdenom = reaper.TimeMap2_timeToBeats( -1, proj_time )
        
        local beat_pos =  1+ math.max(0,math.min(15,math.floor((proj_time_fullbeats - it_pos_fullbeats)*4)))
        if not DATA.seq.ext.children[pitch] then DATA.seq.ext.children[pitch] = {} end
        if not DATA.seq.ext.children[pitch].steps then DATA.seq.ext.children[pitch].steps = {} end
        if not DATA.seq.ext.children[pitch].steps[beat_pos] then  DATA.seq.ext.children[pitch].steps[beat_pos] = {} end
        DATA.seq.ext.children[pitch].steps[beat_pos].val = 1
        DATA.seq.ext.children[pitch].steps[beat_pos].velocity = vel/127
      end
      
      local outstr = table.savestring(DATA.seq.ext) --outstr = VF_encBase64(outstr) -- 4.43 off 
      GetSetMediaItemTakeInfo_String( take, 'P_EXT:MPLRS5KMAN_PATDATA', outstr, true)
      GetSetMediaItemTakeInfo_String( take, 'P_EXT:MPLRS5KMAN_PATDATA_IGNOREB64', 1, true) -- 4.43 patch DO NOT REMOVE
      --msg(os.date()..' '..time_precise()-test)
      DATA:_Seq_PrintMIDI_ShareGUID(DATA.seq ,outstr) -- store pattern data to the same GUID takes 
      
    end  
    --------------------------------------------------------------------------------  
    function DATA:_Seq_PrintEnvelopes_GetEnvByParamName(track, param) local seq_envelope
      if not track then return end
      if not param then return end
      if not param:match('env_') then return end
      
      if param:match('env_pan') then 
        seq_envelope = GetTrackEnvelopeByChunkName( track, '<PANENV2' )
        if seq_envelope then  
          return seq_envelope, GetEnvelopeScalingMode( seq_envelope )
        end
      end
      
      if param:match('env_tracksend') then 
        local destGUID = param:match('(%{.-%})')
        if not destGUID then return end 
        local cntsends = GetTrackNumSends( track, 0 )
        for sendidx = 1, cntsends do 
          local P_DESTTRACK = GetTrackSendInfo_Value( track, 0, sendidx-1, 'P_DESTTRACK' )
          local P_DESTTRACKGUID = GetTrackGUID(P_DESTTRACK)
          if P_DESTTRACKGUID == destGUID then 
            seq_envelope =  GetTrackSendInfo_Value( track, 0, sendidx-1, 'P_ENV:<VOLENV' )
            if seq_envelope then  
              return seq_envelope, GetEnvelopeScalingMode( seq_envelope )
            end
          end
        end
      end
      
      if param:match('env_FX') then 
        local fxGUID,paramID = param:match('env_FX_(%{.-%})([%d]+)')
        if fxGUID and paramID then
          local ret,tr, fxid = VF_GetFXByGUID(fxGUID, track, DATA.proj)
          if fxid then
            local retval, minval, maxval = reaper.TrackFX_GetParam( track, fxid, paramID)
            seq_envelope = GetFXEnvelope( track, fxid, paramID, true )
            if seq_envelope then  return seq_envelope, GetEnvelopeScalingMode( seq_envelope ),minval, maxval end
          end
        end
      end
      
      
    
    end
    --------------------------------------------------------------------------------  
    function DATA:_Seq_PrintEnvelopes_writesteps(param_t, note)
      -- param t
        local seq_envelope = param_t.seq_envelope
        local scaling_mode = param_t.scaling_mode
        local minval = param_t.minval
        local maxval = param_t.maxval
        local param = param_t.param
         
      -- seq
        local t = DATA.seq
      
      -- pat data
        local pat_st = t.it_pos 
        local pat_end = pat_st + t.it_len
        local step_cnt = t.ext.children[note].step_cnt 
        if step_cnt == -1 then step_cnt = t.ext.patternlen end
        local steplength = 0.25
        if t.ext.children[note].steplength then steplength = t.ext.children[note].steplength end 
        local patlen_mult = 1
        if steplength<0.25 then patlen_mult = math.ceil(0.25/steplength) end
        local app_swing 
        if t.ext.swing~= 0 and steplength==0.25 then app_swing = t.ext.swing end
        if not t.ext.children[note].steps then t.ext.children[note].steps = {} end
        if not t.ext.children[note].steps[1] then t.ext.children[note].steps[1] = {val = 0} end
      
      -- clear env 
        DeleteEnvelopePointRange( seq_envelope, pat_st, pat_end-0.001 )
        
      -- boundary clamp
        local retval, cur_value, dVdS, ddVdS, dddVdS = Envelope_Evaluate( seq_envelope, pat_st-0.001, DATA.SR, 1 ) 
        local retval, cur_value_end, dVdS, ddVdS, dddVdS = Envelope_Evaluate( seq_envelope, pat_end, DATA.SR, 1 ) 
        local shape = 0
        local tension = 0
        InsertEnvelopePoint( seq_envelope, pat_st, cur_value, shape, tension, false, true )
        InsertEnvelopePoint( seq_envelope, pat_end-0.001, cur_value_end, shape, tension, false, true )
        local cur_value_scaled = ScaleFromEnvelopeMode( scaling_mode, cur_value )
        
      -- write values
        -- loop pattern length
        for step = 1, t.ext.patternlen*patlen_mult do 
          -- step pos
            local step_active = step%step_cnt 
            if step_active == 0 then step_active = step_cnt end 
            
          -- clamp strat of pattern if step not exist
            local allow_empty_steps =  t.ext.children[note].steps[step_active].val == 1
            if EXT.CONF_seq_env_clamp == 0 then allow_empty_steps = true end
            
            if not (t.ext.children[note].steps and t.ext.children[note].steps[step_active]) and step ~= 1 then goto skipnextstep end  
            local active = t.ext.children[note].steps[step_active] and t.ext.children[note].steps[step_active].val and allow_empty_steps == true
            
            if step ~= 1  then
              if not active then goto skipnextstep end  
            end
            
          -- val definition
            local val = t.ext.children[note].steps[step_active][param] 
            if not val or (step == 1 and not active)  then val = cur_value_scaled end
            val = ScaleToEnvelopeMode( scaling_mode, minval + val*(maxval-minval) ) 
            
          -- position
            local offset = 0
            local sw_shift = 0
            if t.ext.children[note].steps[step_active].offset then offset = t.ext.children[note].steps[step_active].offset*steplength end 
            if app_swing and step%2==0 then sw_shift = app_swing*steplength*0.5 end
            local beatpos = (step-1)*steplength
            local beatlen = steplength
            local beatpos_st = math.max(0, beatpos + offset + sw_shift)
            local beatpos_end =  math.min(beatpos+beatlen + offset ,t.ext.patternlen) 
            local point_pos = TimeMap2_beatsToTime(   DATA.proj, t.it_pos_fullbeats + beatpos_st )  
            if point_pos > pat_end then goto skipnextstep end  
          -- insert point
            local shape = 1
            local tension = 0 
            InsertEnvelopePoint( seq_envelope, point_pos, val, shape, tension, false, true ) 
            
          ::skipnextstep::
        end
        
      -- sort 
        Envelope_SortPoints( seq_envelope )
      
    end
    --------------------------------------------------------------------------------  
    function DATA:_Seq_PrintEnvelopes_note(note)
      if not (DATA.children[note] and DATA.seq.ext.children[note].steps and DATA.seq.ext.children[note].steps[0]) then return end -- 0 as a step check for existing params
      
      local srctr = DATA.children[note].tr_ptr 
      
      -- get parameters
      local parameters = {} 
      for param in pairs(DATA.seq.ext.children[note].steps[0]) do 
        local seq_envelope, scaling_mode,minval, maxval = DATA:_Seq_PrintEnvelopes_GetEnvByParamName(srctr, param)
        if seq_envelope then
          if not minval then minval = 0 end
          if not maxval then maxval = 1 end
          parameters[#parameters+1] = {
            param=param,
            seq_envelope=seq_envelope,
            scaling_mode=scaling_mode,
            minval=minval,
            maxval=maxval,
            } 
            
          -- initialize if not  exist
          local retval, ACTIVE = GetSetEnvelopeInfo_String( seq_envelope, 'ACTIVE', '', false )
          if ACTIVE and ACTIVE == '0' then 
            GetSetEnvelopeInfo_String( seq_envelope, 'ACTIVE', '1', true ) 
            GetSetEnvelopeInfo_String( seq_envelope, 'VISIBLE', '1', true ) 
            TrackList_AdjustWindows( false )
          end
          
        end
      end 
      local parameter_sz = #parameters
      if parameter_sz == 0 then return end 
      for paramID = 1, parameter_sz do DATA:_Seq_PrintEnvelopes_writesteps(parameters[paramID], note) end
      
    end
    --------------------------------------------------------------------------------  
    function DATA:_Seq_PrintEnvelopes(t)
      if not (t.ext and t.ext.children) then return end
      for note in pairs(t.ext.children) do DATA:_Seq_PrintEnvelopes_note(note, seqstart_fullbeats) end 
    end 
    --------------------------------------------------------------------------------   
    function DATA:_Seq_FXremove(note, parameter)
      local fxGUID,paramID = parameter:match('env_FX_(%{.-%})([%d]+)')
      if paramID and tonumber(paramID) then paramID = tonumber(paramID) end
      if not (fxGUID and paramID) then return end
      DATA.seq.ext.children[note].env_FXparamlist[fxGUID][paramID] = nil
      if DATA.seq.ext.children[note].steps then 
        for step in pairs(DATA.seq.ext.children[note].steps) do
          DATA.seq.ext.children[note].steps[step][parameter] = nil
          DATA.seq.ext.children[note].steps[step][parameter..'_shape'] = nil
          DATA.seq.ext.children[note].steps[step][parameter..'_tension'] = nil
        end
      end
      
      DATA:_Seq_Print()
    end
    --------------------------------------------------------------------------------  
    function DATA:_Seq_AddLastTouchedFX() 
      local retval, trackidx, itemidx, takeidx, fxidx, parm = GetTouchedOrFocusedFX( 0 )
      if not retval then return end
      local track = GetTrack(DATA.proj,trackidx)
      if not track then return end
      if itemidx >=0 then return end
      
      local note_layer_t, note, layer = DATA:Sampler_GetActiveNoteLayer()  
      if not note_layer_t then return end
      if note_layer_t.tr_ptr ~= track then return end
      
      if not DATA.seq.ext.children[note] then DATA.seq.ext.children[note] = {} end
      if not DATA.seq.ext.children[note].env_FXparamlist then DATA.seq.ext.children[note].env_FXparamlist = {} end
      
      local fxGUID = TrackFX_GetFXGUID( track, fxidx )
      if not fxGUID then return end
      if not DATA.seq.ext.children[note].env_FXparamlist[fxGUID] then DATA.seq.ext.children[note].env_FXparamlist[fxGUID] = {} end
      DATA.seq.ext.children[note].env_FXparamlist[fxGUID][parm] = 1
      DATA.temp_forceLTP_kselection = {fxGUID=fxGUID,parm=parm}
      
      DATA:_Seq_Print()
    end
    --------------------------------------------------------------------------------  
    function DATA:_Seq_CollectTrackEnv(fxGUID0,parm0 ) 
      local note_layer_t,note, layer = DATA:Sampler_GetActiveNoteLayer()  
      if not note_layer_t then return end
      
      -- track env 
      DATA.seq_param_selector_trackenv = {}
      
      -- pan
      DATA.seq_param_selector_trackenv[#DATA.seq_param_selector_trackenv+1] = {
        param = 'env_pan', 
        str= 'Pan',
        default=0, 
        minval = -1, 
        maxval = 1
        } 
        
      -- add sends
      if note_layer_t.sends then
        for sendidx = 1, #note_layer_t.sends do
          local P_DESTTRACKGUID=  note_layer_t.sends[sendidx].P_DESTTRACKGUID
          local str = 'Send: '..note_layer_t.sends[sendidx].P_DESTTRACKname
          DATA.seq_param_selector_trackenv[#DATA.seq_param_selector_trackenv+1] = {
            param = 'env_tracksend'..P_DESTTRACKGUID, 
            str= str,
            default=0, 
            minval = 0, 
            maxval = 1
            }
        end
      end
      
      
      -- track env  
      DATA.seq_param_selector_trackFXenv = {}
      if DATA.seq.ext.children[note].env_FXparamlist then 
        for fxGUID in spairs(DATA.seq.ext.children[note].env_FXparamlist) do
          for paramID in spairs(DATA.seq.ext.children[note].env_FXparamlist[fxGUID]) do
            if DATA.children[note] and DATA.children[note].tr_ptr then 
              local ret, tr, fxid = VF_GetFXByGUID(fxGUID, DATA.children[note].tr_ptr, DATA.proj)
              if fxid then
                local retval, fxname = reaper.TrackFX_GetFXName( DATA.children[note].tr_ptr, fxid )
                fxname = VF_ReduceFXname(fxname)
                local retval, paramname = reaper.TrackFX_GetParamName( DATA.children[note].tr_ptr, fxid,paramID)
                local id = #DATA.seq_param_selector_trackFXenv+1
                DATA.seq_param_selector_trackFXenv[id] = {
                    param = 'env_FX_'..fxGUID..paramID, 
                    str= fxname..' / #'..paramID..' - '..paramname, 
                    default=0, 
                    minval = 0, 
                    maxval = 1
                    }
                if DATA.temp_forceLTP_kselection and  DATA.temp_forceLTP_kselection.fxGUID and DATA.temp_forceLTP_kselection.parm then
                  if DATA.temp_forceLTP_kselection.fxGUID == fxGUID and DATA.temp_forceLTP_kselection.parm == paramID then 
                    DATA.seq_param_selector_trackFXenvID = id
                    DATA.temp_forceLTP_kselection = nil
                  end
                end
              end
            end
          end
        end
      end
      
    end
    -------------------------------------------------------------------------------- 
    function DATA:_Seq_Clear(note)
      if not (DATA.seq.ext and DATA.seq.ext.children ) then return end
      
      if note and DATA.seq.ext.children[note] and DATA.seq.ext.children[note].steps then DATA.seq.ext.children[note].steps = nil return end
      
      -- all
      local t = {}
      for note in pairs(DATA.seq.ext.children) do t[#t+1] = note end 
      for i = 1, #t do 
        local note = t[i]
        if DATA.seq.ext.children[note  ] then DATA.seq.ext.children[note ].steps = nil end 
      end
      DATA:_Seq_Print(true) 
    end
      -------------------------------------------------------------------------------- 
    function DATA:_Seq_FillNoteStepsToFullLength(note)   --Print to full pattern length 
    
      if note then
        if not (DATA.seq.ext and DATA.seq.ext.children and note and DATA.seq.ext.children[note]) then return end
        local step_cnt = DATA.seq.ext.children[note].step_cnt
        for step = step_cnt+1, DATA.seq.ext.patternlen do
          local activestep = (step%step_cnt)
          if activestep == 0 then activestep = step_cnt end
          DATA.seq.ext.children[note].steps[step] = CopyTable(DATA.seq.ext.children[note].steps[activestep])
        end 
        
        DATA.seq.ext.children[note].step_cnt = -1
        DATA:_Seq_Print()
      end
      
      if not note then
        if not (DATA.seq.ext and DATA.seq.ext.children) then return end 
        for note in pairs(DATA.seq.ext.children) do
          local step_cnt = DATA.seq.ext.children[note].step_cnt
          if step_cnt ~= -1 then
            for step = step_cnt+1, DATA.seq.ext.patternlen do
              local activestep = (step%step_cnt)
              if activestep == 0 then activestep = step_cnt end
              DATA.seq.ext.children[note].steps[step] = CopyTable(DATA.seq.ext.children[note].steps[activestep])
            end 
            DATA.seq.ext.children[note].step_cnt = -1
          end 
          
        end
        DATA:_Seq_Print()
      end
      
      
    end
      -------------------------------------------------------------------------------- 
    function DATA:_Seq_Fill(note, pat)
      if not (DATA.seq.ext and DATA.seq.ext.children and note and DATA.seq.ext.children[note]) then return end
      local tfill = {}
      for char in pat:gmatch('.') do
        local val = 0
        if char == '1' then val = 1 end
        tfill[#tfill+1] = val
      end
      
      local step_cnt = DATA.seq.ext.children[note].step_cnt
      if step_cnt == -1 then step_cnt = DATA.seq.ext.patternlen end
      for i = 1, step_cnt do 
        local src_step= 1+((i-1)%#tfill)
        if tfill[src_step] and tfill[src_step] then val = tfill[src_step] end
        if not DATA.seq.ext.children[note] then DATA.seq.ext.children[note] = {} end
        if not DATA.seq.ext.children[note].steps then DATA.seq.ext.children[note].steps = {} end
        if not DATA.seq.ext.children[note].steps[i] then DATA.seq.ext.children[note].steps[i] = {} end
        DATA.seq.ext.children[note].steps[i].val = val or 0
      end
      
    end
    --------------------------------------------------------------------------------  
    function DATA:_Seq_Print(do_not_ignore_empty, minor_change) 
      if not (DATA.MIDIbus and DATA.MIDIbus.tr_ptr and DATA.MIDIbus.valid) then return end
      if not (DATA.seq.it_ptr and DATA.seq.tk_ptr) then return end
      if not DATA.seq.ext.children then return end 
      local item = DATA.seq.it_ptr
      local take = DATA.seq.tk_ptr
      if not (take and ValidatePtr2(DATA.proj, take, 'MediaItem_Take*')) then DATA.seq = nil return end
      
      
      if minor_change~=true then 
        Undo_BeginBlock2(DATA.proj)
        --test = time_precise()
        local outstr = table.savestring(DATA.seq.ext) --outstr = VF_encBase64(outstr) -- 4.43 off 
        GetSetMediaItemTakeInfo_String( take, 'P_EXT:MPLRS5KMAN_PATDATA', outstr, true)
        GetSetMediaItemTakeInfo_String( take, 'P_EXT:MPLRS5KMAN_PATDATA_IGNOREB64', 1, true) -- 4.43 patch DO NOT REMOVE
        --msg(os.date()..' '..time_precise()-test)
        DATA:_Seq_PrintMIDI_ShareGUID(DATA.seq ,outstr) -- store pattern data to the same GUID takes 
        Undo_EndBlock2(DATA.proj, 'Pattern edit', 0xFFFFFFFF)
        
        
      end 
      DATA:_Seq_PrintEnvelopes(DATA.seq)
      DATA:_Seq_PrintMIDI(DATA.seq) 
      GetSetMediaItemTakeInfo_String( take, 'P_EXT:MPLRS5KMAN_PATGUID', DATA.seq.ext.GUID, true) 
      
    end
    --------------------------------------------------------------------------------  
    function DATA:_Seq_PrintMIDI_ShareGUID(parent_t ,outstr) 
      if EXT.CONF_seq_force_GUIDbasedsharing~= 1 then return end
      
      local parenttake = parent_t.tk_ptr
      local parentGUID = parent_t.ext.GUID
      local form_data = parent_t.form_data
      local tr = DATA.MIDIbus.tr_ptr 
      local cnt = reaper.CountTrackMediaItems( tr)
      for itemidx = 1, cnt do
        local item = reaper.GetTrackMediaItem(tr, itemidx-1)
        local take = GetActiveTake(item)
        local it_pos = reaper.GetMediaItemInfo_Value( item,'D_POSITION' )  
        local ret, GUID = GetSetMediaItemTakeInfo_String( take, 'P_EXT:MPLRS5KMAN_PATGUID', '', false)
        if parenttake ~= take and ret and GUID ~= '' and GUID == parentGUID then  
          GetSetMediaItemTakeInfo_String( take, 'P_EXT:MPLRS5KMAN_PATDATA', outstr, true)
          local src = GetMediaItemTake_Source( take )
        end
      end
      
    end 
    --------------------------------------------------------------------------------  
    function math_q(num)  if math.abs(num - math.floor(num)) < math.abs(num - math.ceil(num)) then return math.floor(num) else return math.ceil(num) end end
    --------------------------------------------------------------------------------  
    function DATA:Auto_LoopSlice_CreatePattern(loop_t) 
      if not loop_t then return end
      local slicecnt = math.min(16,#loop_t)
      
      DATA:_Seq_Insert(true)
      DATA:CollectData() -- to refresh note existing data
      if not DATA.seq.ext then DATA.seq.ext = {} end 
      if not DATA.seq.ext.children then DATA.seq.ext.children = {} end 
      function __f_slice2pattern_modloopt() end
      
      local steplength = 0.25
      for slice = 1, slicecnt do
        local note = loop_t[slice].outnote
        if note then
          DATA.seq.ext.children[note] = {
            steplength =steplength,
            step_cnt = slicecnt,
            steps = {}
            }
          DATA.seq.ext.children[note].steps[slice] = {val = 1}
        end
      end
      
      DATA.seq.ext.patternlen = slicecnt
      DATA:_Seq_Print() 
    end  
    --------------------------------------------------------------------------------  
    function DATA:_Seq_Insert(skip_seqcheck) 
      if not (DATA.MIDIbus and DATA.MIDIbus.tr_ptr and DATA.MIDIbus.valid) then return end
      local track = DATA.MIDIbus.tr_ptr
      local curpos = GetCursorPosition()
      
      -- get quantized pos
      local retval, measures, cml, fullbeats, cdenom = reaper.TimeMap2_timeToBeats( DATA.proj, curpos )
      local posst = TimeMap2_beatsToTime(  DATA.proj, 0, measures )
      local posend = TimeMap2_beatsToTime(  DATA.proj, 0, measures+1)
      
      local item = CreateNewMIDIItemInProj( track, posst, posend )
      SelectAllMediaItems( DATA.proj, false )
      SetMediaItemSelected( item, true )
      SetMediaItemInfo_Value( item, 'B_LOOPSRC',1 )
      
      UpdateItemInProject(item)
      DATA:CollectData_Seq(skip_seqcheck) 
    end
    
    -------------------------------------------------------------------------------  
    function DATA:CollectData_Seq(skip_seqcheck) 
      if skip_seqcheck~=true then
        if DATA.seq_functionscall ~= true then return end 
      end
      local retval, cur_projfn = reaper.EnumProjects( -1 ) 
      local last_valid_seq = CopyTable(DATA.seq)
      local item = GetSelectedMediaItem( -1, 0 )
      
      if last_valid_seq and last_valid_seq.valid==true and ValidatePtr(last_valid_seq.it_ptr, 'MediaItem*') then  
        if last_valid_seq.proj == DATA.proj then -- if same project
          if not item or (item and last_valid_seq.it_ptr == item)  then
            
            DATA.seq = last_valid_seq 
            return
          end
        end 
      end
      
      
      
      -- init pattern defaults
      DATA.seq = {
        valid = false,
        proj = DATA.proj,
        ext = {
                patternlen = 16,
                patternsteplen = EXT.CONF_seq_steplength, 
                children={}, 
                step_defaults={},
                swing = 0,
              },
        }
      
      
      -- init  
      
      if not item then return end
      local take = GetActiveTake(item)
      DATA.seq.valid = true
      DATA.seq.it_ptr = item
      DATA.seq.tk_ptr = take 
      DATA.seq.it_pos = GetMediaItemInfo_Value( item, 'D_POSITION' )
      local retval, measures, cml, seqstart_fullbeats, cdenom = reaper.TimeMap2_timeToBeats(DATA.proj, DATA.seq.it_pos ) 
      DATA.seq.it_pos_fullbeats = seqstart_fullbeats
      DATA.seq.it_len = GetMediaItemInfo_Value( item, 'D_LENGTH' )
      DATA.seq.I_GROUPID = GetMediaItemInfo_Value( item, 'I_GROUPID' )
      DATA.seq.D_STARTOFFS = GetMediaItemTakeInfo_Value( take,'D_STARTOFFS' )
      DATA.seq.D_PLAYRATE = GetMediaItemTakeInfo_Value( take,'D_PLAYRATE' )
      local source = GetMediaItemTake_Source( take ) 
      local qnlen, lengthIsQN = reaper.GetMediaSourceLength( source )
      DATA.seq.srclen_sec = TimeMap_QNToTime_abs( DATA.proj, qnlen)
      if DATA.seq.D_STARTOFFS < 0 then
        DATA.seq.it_pos_compensated = DATA.seq.it_pos - DATA.seq.D_STARTOFFS
       elseif DATA.seq.D_STARTOFFS > 0 then
        DATA.seq.it_pos_compensated = DATA.seq.it_pos + (DATA.seq.srclen_sec  - DATA.seq.D_STARTOFFS) /DATA.seq.D_PLAYRATE
       else
        DATA.seq.it_pos_compensated = DATA.seq.it_pos
      end
      local retval, measures, cml, fullbeats_pos, cdenom = reaper.TimeMap2_timeToBeats( DATA.proj, DATA.seq.it_pos )
      local retval, measures, cml, fullbeats_end, cdenom = reaper.TimeMap2_timeToBeats( DATA.proj, DATA.seq.it_pos +  DATA.seq.it_len )
      DATA.seq.it_len_beats =fullbeats_end - fullbeats_pos
      DATA.seq.srccount =  DATA.seq.it_len  / math.max(0.1,DATA.seq.srclen_sec)
      
      
      DATA.seq.tkname = ''
      local retval, tkname = reaper.GetSetMediaItemTakeInfo_String( take, 'P_NAME', '', false )
      if retval then DATA.seq.tkname = tkname  end
      
      
      -- load ext data
      local patdata
      local ret_patdata_b64, patdata_b64 = GetSetMediaItemTakeInfo_String( take, 'P_EXT:MPLRS5KMAN_PATDATA', '', false)
      local ret, MPLRS5KMAN_PATDATA_IGNOREB64 = GetSetMediaItemTakeInfo_String( take, 'P_EXT:MPLRS5KMAN_PATDATA_IGNOREB64', '', false) -- 4.43 use native b64 converter
      if (MPLRS5KMAN_PATDATA_IGNOREB64 and tonumber(MPLRS5KMAN_PATDATA_IGNOREB64) and tonumber(MPLRS5KMAN_PATDATA_IGNOREB64) == 1) then 
        patdata = patdata_b64
       else
        if ret_patdata_b64 and patdata_b64 then patdata = VF_decBase64(patdata_b64) end
      end
      if patdata and patdata ~= '' then DATA.seq.ext = table.loadstring(patdata) end
      if not DATA.seq.ext then DATA.seq.ext = {} end
      if not DATA.seq.ext.children then DATA.seq.ext.children = {} end
      if not DATA.seq.ext.patternsteplen then DATA.seq.ext.patternsteplen = 0.25 end-- 4.38+ 
      if not DATA.seq.ext.GUID then DATA.seq.ext.GUID = genGuid() end-- 4.39+
      if not DATA.seq.ext.step_defaults then DATA.seq.ext.step_defaults = {} end-- 4.40+
      if not DATA.seq.ext.swing then DATA.seq.ext.swing = 0 end-- 4.42
      
      
      DATA:CollectData_SeqFillEmptySteps() 
      DATA:_Seq_RefreshHScroll()
      DATA:_Seq_CollectTrackEnv()
      
      local IDorder = 0
      for note in spairs(DATA.seq.ext.children) do
        IDorder = IDorder + 1
        DATA.seq.ext.children[note].IDorder = 9-IDorder
      end
      
      -- form matrix
      DATA.lp_matrix = {}
      for row = 1, 8 do
        DATA.lp_matrix[row] = {}
        for col = 1, 8 do
          DATA.lp_matrix[row][col] = {MIDI_note = col + ((9-row)*10)}
        end
      end
      
      
    end
    -------------------------------------------------------------------------------  
    function DATA:CollectData_SeqFillEmptySteps() 
      for note in spairs(DATA.children) do
        if not DATA.seq.ext.children[note] then DATA.seq.ext.children[note] = {} end
        if not DATA.seq.ext.children[note].steps then DATA.seq.ext.children[note].steps = {} end -- this is fixing wrong offset on misssing first step at DATA:_Seq_PrintMIDI(t) --{val=0} 
        if not DATA.seq.ext.children[note].step_cnt then DATA.seq.ext.children[note].step_cnt = EXT.CONF_seq_defaultstepcnt end--DATA.seq.ext.patternlen end -- init 16 steps 
        if not DATA.seq.ext.children[note].steplength then DATA.seq.ext.children[note].steplength = 0.25 end -- init 16 steps  
        for step = 1, DATA.seq.ext.children[note].step_cnt do
          if not DATA.seq.ext.children[note].steps[step] then DATA.seq.ext.children[note].steps[step] = {} end
          if not DATA.seq.ext.children[note].steps[step].val then DATA.seq.ext.children[note].steps[step].val = 0 end
        end
      end
    end
    --------------------------------------------------------------------------------  
    function DATA:_Seq_RefreshHScroll()
      patlen = DATA.seq.ext.patternlen or 16
      DATA.seq.max_scroll = math.max(16,patlen-16) 
      DATA.seq.stepoffs = math.floor((DATA.seq_horiz_scroll or 0)*DATA.seq.max_scroll)
      if DATA.seq.ext.patternlen >= 128 then
        DATA.seq.stepoffs = 16 * math.floor(DATA.seq.stepoffs / 16) 
      end
    end
    
    --------------------------------------------------------------------------------  
    function DATA:_Seq_ModifyTools(note, mode, dir) 
      if not (DATA.seq.ext and DATA.seq.ext.children and note and DATA.seq.ext.children[note]) then return end
      local step_cnt = DATA.seq.ext.children[note].step_cnt
      if step_cnt == -1 then step_cnt = DATA.seq.ext.patternlen end
      local init = CopyTable(DATA.seq.ext.children[note].steps)
      
      if not init then return end
      -- shift
      if mode == 0 then 
        for i = 1, step_cnt do
          local src_step = i+1*dir
          if src_step > step_cnt then src_step = 1 end
          if src_step < 1 then src_step = step_cnt end
          if not DATA.seq.ext.children[note] then DATA.seq.ext.children[note] = {} end
          if not DATA.seq.ext.children[note].steps then DATA.seq.ext.children[note].steps = {} end
          if not DATA.seq.ext.children[note].steps[i] then DATA.seq.ext.children[note].steps[i] = {} end
          
          
          --local val = 0 
          --if init[src_step] and init[src_step].val then val = init[src_step].val end
          --DATA.seq.ext.children[note].steps[i].val = val or 0
          DATA.seq.ext.children[note].steps[i] = init[src_step]
        end
      end
      
      -- flip
      if mode == 1 then 
        for i = 1, step_cnt do
          local src_step = step_cnt - i + 1
          if init[src_step] and init[src_step].val then val = init[src_step].val end
          if not DATA.seq.ext.children[note] then DATA.seq.ext.children[note] = {} end
          if not DATA.seq.ext.children[note].steps then DATA.seq.ext.children[note].steps = {} end
          if not DATA.seq.ext.children[note].steps[i] then DATA.seq.ext.children[note].steps[i] = {} end 
          --local val = 0 
          --DATA.seq.ext.children[note].steps[i].val = val or 0
          DATA.seq.ext.children[note].steps[i] = init[src_step]
        end
      end
      
      -- flip
      if mode == 2 then 
        
        math.randomseed(time_precise()*10000)
        for i = 1, step_cnt do
          local val = 0 
          local rand = math.random()
          if rand <= EXT.CONF_seq_random_probability then val = 1 else val = 0 end 
          if init[src_step] and init[src_step].val then val = init[src_step].val end
          if not DATA.seq.ext.children[note] then DATA.seq.ext.children[note] = {} end
          if not DATA.seq.ext.children[note].steps then DATA.seq.ext.children[note].steps = {} end
          if not DATA.seq.ext.children[note].steps[i] then DATA.seq.ext.children[note].steps[i] = {} end
          DATA.seq.ext.children[note].steps[i].val = val or 0
        end
      end
      
      
      DATA:_Seq_Print() 
    end
    --------------------------------------------------------------------------------  
    function DATA:_Seq_PrintMIDI(t, do_not_ignore_empty, overrides) 
      local item = t.it_ptr
      local take = t.tk_ptr
      local item_pos = t.it_pos
      
      local metashift = 0
      local ppqreduce = 1
       
      if not (item and take) then return end
      if not t.ext.children then return end
      
      -- init ppq
      form_data = {}
      local steplength = 0.25 -- do not touch
      local _, _, _ seqstart_fullbeats = reaper.TimeMap2_timeToBeats( DATA.proj, item_pos ) 
      local seqend_sec = TimeMap2_beatsToTime(     DATA.proj, seqstart_fullbeats + DATA.seq.ext.patternlen *steplength ) 
      local seqend_endppq = MIDI_GetPPQPosFromProjTime( take, seqend_sec) 
      t.seqend_endppq = seqend_endppq -- send to childs export
      
      -- form table
      for note in pairs(t.ext.children) do
        
        if not DATA.children[note] then goto skipnextnote end
        local steplength = 0.25
        local default_velocity = 120 -- TODO store per note
        if t.ext.children[note].steplength then steplength = t.ext.children[note].steplength end 
        local step_cnt = t.ext.children[note].step_cnt 
        if step_cnt == -1 then step_cnt = DATA.seq.ext.patternlen end
        
        local patlen_mult = 1
        if steplength<0.25 then patlen_mult = math.ceil(0.25/steplength) end
        
        local app_swing 
        if DATA.seq.ext.swing~= 0 and steplength==0.25 then app_swing = DATA.seq.ext.swing end
        
        if not t.ext.children[note].steps then t.ext.children[note].steps = {} end
        if not t.ext.children[note].steps[1] then t.ext.children[note].steps[1] = {val = 0} end
        for step = 1, DATA.seq.ext.patternlen*patlen_mult do
          local step_active = step%step_cnt 
          if step_active == 0 then step_active = step_cnt end
          if not (t.ext.children[note].steps and t.ext.children[note].steps[step_active]) then goto skipnextstep end
          
          -- val 
          local val = t.ext.children[note].steps[step_active].val
          
          -- velocity
          local velocity = 0
          if val == 1 then velocity = default_velocity end
          if val == 1 and t.ext.children[note].steps[step_active].velocity then velocity = math.floor(t.ext.children[note].steps[step_active].velocity*127) end
          if velocity == 0 and step_active ~= 1 then goto skipnextstep end 
          
          -- split
          local split = 1
          if t.ext.children[note].steps[step_active].split then split = math_q(t.ext.children[note].steps[step_active].split) end 
          
          -- meta
          local addmeta
          local meta_pitch = 64
          if t.ext.children[note].steps[step_active].meta_pitch then meta_pitch = t.ext.children[note].steps[step_active].meta_pitch end 
          local meta_probability = 1
          if t.ext.children[note].steps[step_active].meta_probability then meta_probability = t.ext.children[note].steps[step_active].meta_probability end 
          if val ==1 and (meta_pitch ~= 64 or meta_probability ~= 1) then 
            addmeta = true
          end
          
          
          -- offset  / swing
          local offset = 0
          local sw_shift = 0
          if t.ext.children[note].steps[step_active].offset then offset = t.ext.children[note].steps[step_active].offset*steplength end 
          if app_swing and step%2==0 then sw_shift = app_swing*steplength*0.5 end
          local beatpos = (step-1)*steplength
          local beatlen = steplength
          if t.ext.children[note].steps[step_active].steplen_override then 
            beatlen = steplength * t.ext.children[note].steps[step_active].steplen_override
          end
          local beatpos_st = math.max(0, beatpos +offset + sw_shift)
          local beatpos_end =  math.min(beatpos+beatlen + offset ,DATA.seq.ext.patternlen)
          if  beatpos_st > DATA.seq.ext.patternlen then goto skipnextstep end
          
          
          local steppos_start_sec = TimeMap2_beatsToTime(   DATA.proj, seqstart_fullbeats + beatpos_st ) 
          local steppos_end_sec = TimeMap2_beatsToTime(     DATA.proj, seqstart_fullbeats + beatpos_end) 
          local steppos_start_ppq = MIDI_GetPPQPosFromProjTime( take, steppos_start_sec ) 
          local steppos_end_ppq = MIDI_GetPPQPosFromProjTime( take, steppos_end_sec )
          if  steppos_end_ppq - steppos_start_ppq < 2 then goto skipnextstep end
          
          --if sw_shift ~= 0 or offset ~= 0 then split = 1 end 
          
          if steppos_start_ppq < seqend_endppq then--and steppos_end_ppq < seqend_endppq then
            
            steppos_end_ppq = math.min(steppos_end_ppq, seqend_endppq)
            steppos_start_ppq = math.floor(steppos_start_ppq)
            steppos_end_ppq = math.floor(steppos_end_ppq)
            
            if split == 1 then 
              
              local meta
              if addmeta then
                    meta = {
                        [1] = note, -- note
                        [2] = math_q(meta_pitch or 64), -- pitch
                        [3] = math_q((meta_probability or 1)*127), -- probability
                    }
              end
              
              -- single note
              form_data[#form_data+1] = {
                ppq_start = steppos_start_ppq,
                ppq_end = steppos_end_ppq-ppqreduce,
                pitch = note,
                vel = velocity,
                meta=CopyTable(meta),
              }
              
              
              
             else
             
              -- split note
              local ppq_len = steppos_end_ppq - steppos_start_ppq
              local sliceppq_len = math.floor(ppq_len / split)
              for i = 1, split do
                local slice_steppos_start_ppq = steppos_start_ppq + sliceppq_len*(i-1)
                local slice_steppos_end_ppq = slice_steppos_start_ppq + sliceppq_len
                local meta
                if addmeta then
                    meta = {
                      [1] = note, -- note
                      [2] = math_q(meta_pitch or 64), -- pitch
                      [3] = math_q((meta_probability or 1)*127), -- probability
                    }
                end
                
                form_data[#form_data+1] = {
                  ppq_start = slice_steppos_start_ppq,
                  ppq_end = slice_steppos_end_ppq-ppqreduce,
                  pitch = note,
                  vel = velocity,
                  meta=meta,
                }
              end
              
              
              
            end
            
            
            
          end
          ::skipnextstep::
        end  
        
        ::skipnextnote::
      end
      if #form_data< 1 and do_not_ignore_empty ~= true then return end
      
      
      
      
      
      
      -- output to MIDI 
      local offset = 0
      local flags = 0
      local ppq 
      
      local lastppq = 0
      local str = ''
      local sz = #form_data
      for i = 1, sz do 
        
        --meta
        local SysEx_msg_bin = '' 
        if form_data[i].meta then
          local SysEx_msg = 'F0 60 01 '
          for id = 1, #form_data[i].meta do SysEx_msg= SysEx_msg..string.format("%X", form_data[i].meta[id])..' ' end SysEx_msg= SysEx_msg..'F7'
          for hex in SysEx_msg:gmatch('[A-F,0-9]+') do  SysEx_msg_bin = SysEx_msg_bin..string.char(tonumber(hex, 16)) end 
        end
        
        -- notes
        local pitch = form_data[i].pitch
        if pitch and  form_data[i].vel then
          local ppq = form_data[i].ppq_start
          local offset = ppq - lastppq
          
          -- note ON
          local offs_sysex = offset
          local offs_noteon = offset
          if SysEx_msg_bin ~= '' then 
            str = str..string.pack("i4Bs4", offs_sysex, flags, SysEx_msg_bin)
            offs_noteon = 0
          end
          str = str..string.pack("i4Bi4BBB", offs_noteon, flags, 3, 0x90, pitch, form_data[i].vel ) 
          lastppq = ppq
          
          -- noteOFF
          local ppq = form_data[i].ppq_end
          local offset = ppq - lastppq
          str = str..string.pack("i4Bi4BBB", offset, flags, 3, 0x80, pitch, 0)
          
          lastppq = ppq 
        end
        
        
      end
      
      -- close loop source
        local ppq = t.seqend_endppq
        local offset = math.floor(ppq - lastppq)
        local str_per_msg = string.pack("i4BI4BBB", offset, flags, 3, 0xB0, 123, 0)
        str = str..str_per_msg
      
      
      MIDI_SetAllEvts(take, str) 
      MIDI_Sort(take) 
      
      DATA:_Seq_PrintMIDI_AutoLegato(take)
      
      SetMediaItemTakeInfo_Value( take,'D_STARTOFFS',DATA.seq.D_STARTOFFS )
      
      return form_data
    end
    --------------------------------------------------------------------------------  
    function DATA:_Seq_PrintMIDI_AutoLegato(take)
      if EXT.CONF_seq_autolegato ==0 then return str end
      
      if not take or not TakeIsMIDI(take) then return end
      
      -- Get take end position in PPQ
      local item = GetMediaItemTake_Item(take)
      local itemStart = GetMediaItemInfo_Value(item, "D_POSITION")
      local itemLen = GetMediaItemInfo_Value(item, "D_LENGTH")
      local itemEnd = itemStart + itemLen
      local takeEndPPQ = MIDI_GetPPQPosFromProjTime(take, itemEnd)
      
      
      local notes = {}
      local _, noteCount, _, _ = MIDI_CountEvts(take)
      
      -- Collect notes by channel + pitch
      for i = 0, noteCount - 1 do
        local retval, sel, muted, startppq, endppq, chan, pitch, vel =
          MIDI_GetNote(take, i)
      
        if retval then
          local key = chan * 128 + pitch
          notes[key] = notes[key] or {}
          table.insert(notes[key], {
            index = i,
            startppq = startppq
          })
        end
      end
      
      -- Process groups
      for _, group in pairs(notes) do
        table.sort(group, function(a, b)
          return a.startppq < b.startppq
        end)
      
        for i = 1, #group do
          local cur = group[i]
          local nextNote = group[i + 1]
      
          local newEndPPQ
          if nextNote then
            newEndPPQ = nextNote.startppq
          else
            newEndPPQ = takeEndPPQ
          end
      
          if newEndPPQ > cur.startppq then
            MIDI_SetNote(
              take,
              cur.index,
              nil, nil,
              cur.startppq,
              newEndPPQ,
              nil, nil, nil,
              false
            )
          end
        end
      end
      
      
      MIDI_Sort(take)
    end
    --------------------------------------------------------------------------------  
    function DATA:_Seq_SetItLength_Beats(patternlen) 
      if not (DATA.MIDIbus and DATA.MIDIbus.tr_ptr and DATA.MIDIbus.valid) then return end
      if not (DATA.seq.it_ptr and DATA.seq.tk_ptr and DATA.seq.ext.patternsteplen) then return end
      
      if DATA.seq.D_STARTOFFS~= 0 then return end
      if DATA.seq.srccount~= 1 then return end
      
      local out_len_beats = DATA.seq.ext.patternlen * DATA.seq.ext.patternsteplen 
      local retval, measures, cml, fullbeats_pos, cdenom = reaper.TimeMap2_timeToBeats( DATA.proj, DATA.seq.it_pos )
      local out_end_sec_OLD = TimeMap2_beatsToTime( proj, fullbeats_pos +  out_len_beats)
      
      local out_len_beats = patternlen * DATA.seq.ext.patternsteplen 
      local retval, measures, cml, fullbeats_pos, cdenom = reaper.TimeMap2_timeToBeats( DATA.proj, DATA.seq.it_pos )
      local out_end_sec = TimeMap2_beatsToTime( proj, fullbeats_pos +  out_len_beats)
      
      SetMediaItemInfo_Value( DATA.seq.it_ptr, 'D_LENGTH', out_end_sec - DATA.seq.it_pos )
      UpdateItemInProject(DATA.seq.it_ptr)
      
      
      if EXT.CONF_seq_patlen_extendchildrenlen ==1 and DATA.seq.ext and DATA.seq.ext.children then 
        for note in pairs(DATA.seq.ext.children) do if DATA.seq.ext.children[note].step_cnt ~= -1 then DATA.seq.ext.children[note].step_cnt = patternlen end end
      end
      
    end
    --------------------------------------------------------------------------------  
    function msg(s)  if not s then return end  if type(s) == 'boolean' then if s then s = 'true' else  s = 'false' end end ShowConsoleMsg(s..'\n') end 
    ---------------------------------------------------------------------------------------------------------------------
    function VF_SmoothT(t, smooth)
      local t0 = CopyTable(t)
      for i = 2, #t do t[i]= t0[i] * (t[i] - (t[i] - t[i-1])*smooth )  end
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
    ---------------------------------------------------------------------------------------------------------------------
    function VF_NormalizeT(t, threshold)
      if not t then return end
      local sz
      if type(t) == 'table' then sz = #t else sz = t.get_alloc() end
      local m = 0 
      local val 
      for i= 1, sz do m = math.max(math.abs(t[i]),m) end
      for i= 1, sz do
        val = t[i] / m  
        if threshold and val < threshold then val = 0 end
        t[i] = val
      end
    end 
    ---------------------------------------------------------------------------------------------------------------------
    function VF_GetParentFolder(dir) return dir:match('(.*)[%\\/]') end
    ---------------------------------------------------
    function VF_ReduceFXname(s)
      local s_out = s:match('[%:%/%s]+(.*)')
      if not s_out then return s end
      s_out = s_out:gsub('%(.-%)','') 
      --if s_out:match('%/(.*)') then s_out = s_out:match('%/(.*)') end
      local pat_js = '.*[%/](.*)'
      if s_out:match(pat_js) then s_out = s_out:match(pat_js) end  
      if not s_out then return s else 
        if s_out ~= '' then return s_out else return s end
      end
    end
    ------------------------------------------------------- 
    function VF_BFpluginparam(find_Str, tr, fx, param) 
      if not find_Str then return end
      local find_Str_val = find_Str:match('[%d%-%.]+')
      if not (find_Str_val and tonumber(find_Str_val)) then return end
      local find_val =  tonumber(find_Str_val)
      
      local iterations = 500
      local mindiff = 10^-14
      local precision = 10^-10
      local min, max = 0,1
      for i = 1, iterations do -- iterations
        local param_low = VF_BFpluginparam_GetFormattedParamInternal(tr , fx, param, min) 
        local param_mid = VF_BFpluginparam_GetFormattedParamInternal(tr , fx, param, min + (max-min)/2) 
        local param_high = VF_BFpluginparam_GetFormattedParamInternal(tr , fx, param, max)  
        if find_val <= param_low then return min  end
        if find_val == param_mid and math.abs(min-max) < mindiff then return VF_BFpluginparam_PreciseCheck(tr, fx, param, find_val, min, max, precision) end
        if find_val >= param_high then return max end
        if find_val > param_low and find_val < param_mid then 
          min = min 
          max = min + (max-min)/2 
          if math.abs(min-max) < mindiff then return VF_BFpluginparam_PreciseCheck(tr, fx, param, find_val, min, max, precision) end
         else
          min = min + (max-min)/2 
          max = max 
          if math.abs(min-max) < mindiff then return VF_BFpluginparam_PreciseCheck(tr, fx, param, find_val, min, max, precision) end
        end
      end 
      
    end 
    -------------------------------------------------------  
    function VF_BFpluginparam_GetFormattedParamInternal(tr, fx, param, val)
      local param_n
      if val then TrackFX_SetParamNormalized( tr, fx, param, val ) end
      local _, buf = TrackFX_GetFormattedParamValue( tr , fx, param, '' )
      --local param_str = buf:match('%-[%d%.]+') or buf:match('[%d%.]+')
      local param_str = buf:match('[%d%a%-%.]+')
      if param_str then param_n = tonumber(param_str) end
      if not param_n and param_str:lower():match('%-inf') then param_n = - math.huge
      elseif not param_n and param_str:lower():match('inf') then param_n = math.huge end
      return param_n
    end
    -------------------------------------------------------  
    function VF_BFpluginparam_PreciseCheck(tr, fx, param, find_val, min, max, precision)
      for value_precise = min, max, precision do
        local param_form = VF_BFpluginparam_GetFormattedParamInternal(tr , fx, param, value_precise)  
        if find_val == param_form then  return value_precise end
      end
      return min + (max-min)/2 
    end 
      -----------------------------------------------------------------------------  
    function VF_Open_URL(url) if GetOS():match("OSX") then os.execute('open "" '.. url) else os.execute('start "" '.. url)  end  end  
  
    ---------------------------------------------------------------------
    function VF_GetLTP()
      local retval, tracknumber, fxnumber, paramnumber = reaper.GetLastTouchedFX() 
      local tr, trGUID, fxGUID, param, paramname, ret, fxname,paramformat
      if retval then 
        tr = CSurf_TrackFromID( tracknumber, false )
        trGUID = GetTrackGUID( tr )
        fxGUID = TrackFX_GetFXGUID( tr, fxnumber )
        retval, buf = reaper.GetTrackName( tr )
        ret, paramname = TrackFX_GetParamName( tr, fxnumber, paramnumber, '')
        ret, fxname = TrackFX_GetFXName( tr, fxnumber, '' )
        paramval = TrackFX_GetParam( tr, fxnumber, paramnumber )
        retval, paramformat = TrackFX_GetFormattedParamValue(  tr, fxnumber, paramnumber, '' )
       else 
        return
      end
      return {tr = tr,
              trtracknumber=tracknumber,
              trGUID = trGUID,
              fxGUID = fxGUID,
              trname = buf,
              paramnumber=paramnumber,
              paramname=paramname,
              paramformat = paramformat,
              paramval=paramval,
              fxnumber=fxnumber,
              fxname=fxname
              }
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
  -----------------------------------------------------------------------------------------    -- http://lua-users.org/wiki/SaveTableToFile
  function table.exportstring( s ) return string.format("%q", s) end
  
  --// The Save Function
  function table.savestring(  tbl )
  local outstr = ''
    local charS,charE = "   ","\n"
  
    -- initiate variables for save procedure
    local tables,lookup = { tbl },{ [tbl] = 1 }
    outstr = outstr..'\n'..( "return {"..charE )
  
    for idx,t in ipairs( tables ) do
       outstr = outstr..'\n'..( "-- Table: {"..idx.."}"..charE )
       outstr = outstr..'\n'..( "{"..charE )
       local thandled = {}
  
       for i,v in ipairs( t ) do
          thandled[i] = true
          local stype = type( v )
          -- only handle value
          if stype == "table" then
             if not lookup[v] then
                table.insert( tables, v )
                lookup[v] = #tables
             end
             outstr = outstr..'\n'..( charS.."{"..lookup[v].."},"..charE )
          elseif stype == "string" then
             outstr = outstr..'\n'..(  charS..table.exportstring( v )..","..charE )
          elseif stype == "number" then
             outstr = outstr..'\n'..(  charS..tostring( v )..","..charE )
          end
       end
  
       for i,v in pairs( t ) do
          -- escape handled values
          if (not thandled[i]) then
          
             local str = ""
             local stype = type( i )
             -- handle index
             if stype == "table" then
                if not lookup[i] then
                   table.insert( tables,i )
                   lookup[i] = #tables
                end
                str = charS.."[{"..lookup[i].."}]="
             elseif stype == "string" then
                str = charS.."["..table.exportstring( i ).."]="
             elseif stype == "number" then
                str = charS.."["..tostring( i ).."]="
             end
          
             if str ~= "" then
                stype = type( v )
                -- handle value
                if stype == "table" then
                   if not lookup[v] then
                      table.insert( tables,v )
                      lookup[v] = #tables
                   end
                   outstr = outstr..'\n'..( str.."{"..lookup[v].."},"..charE )
                elseif stype == "string" then
                   outstr = outstr..'\n'..( str..table.exportstring( v )..","..charE )
                elseif stype == "number" then
                   outstr = outstr..'\n'..( str..tostring( v )..","..charE )
                end
             end
          end
       end
       outstr = outstr..'\n'..( "},"..charE )
    end
    outstr = outstr..'\n'..( "}" )
    return outstr
  end
  
  --// The Load Function
  function table.loadstring( str )
  if str == '' then return end
    local ftables,err = load( str )
    if err then return _,err end
    local tables = ftables()
    for idx = 1,#tables do
       local tolinki = {}
       for i,v in pairs( tables[idx] ) do
          if type( v ) == "table" then
             tables[idx][i] = tables[v[1]]
          end
          if type( i ) == "table" and tables[i[1]] then
             table.insert( tolinki,{ i,tables[i[1]] } )
          end
       end
       -- link indices
       for _,v in ipairs( tolinki ) do
          tables[idx][v[2]],tables[idx][v[1]] =  tables[idx][v[1]],nil
       end
    end
    return tables[1]
  end  
    ------------------------------------------------------------------------------------------------------
    function VF_lim(val, min,max) --local min,max 
      if not min or not max then min, max = 0,1 end 
      return math.max(min,  math.min(val, max) ) 
    end
      ---------------------------------------------------------------------  
    function VF_LIP_load(fileName) -- https://github.com/Dynodzzo/Lua_INI_Parser/blob/master/LIP.lua
      assert(type(fileName) == 'string', 'Parameter "fileName" must be a string.');
      local file = assert(io.open(fileName, 'r'), 'Error loading file : ' .. fileName);
      local data = {};
      local section;
      for line in file:lines() do
        local tempSection = line:match('^%[([^%[%]]+)%]$');
        if(tempSection)then
          section = tonumber(tempSection) and tonumber(tempSection) or tempSection;
          data[section] = data[section] or {};
        end
        local param, value = line:match('^([%w|_]+)%s-=%s-(.+)$');
        if(param and value ~= nil)then
          if(tonumber(value))then
            value = tonumber(value);
          elseif(value == 'true')then
            value = true;
          elseif(value == 'false')then
            value = false;
          end
          if(tonumber(param))then
            param = tonumber(param);
          end
          if data[section] then 
            data[section][param] = value;
          end
        end
      end
      file:close();
      return data;
    end
      ---------------------------------------------------------------------------------------------------------------------
    function VF_encBase64(data) -- https://stackoverflow.com/questions/34618946/lua-base64-encode
      if not data then return end
      local b='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/' -- You will need this for encoding/decoding
        return ((data:gsub('.', function(x) 
            local r,b='',x:byte()
            for i=8,1,-1 do r=r..(b%2^i-b%2^(i-1)>0 and '1' or '0') end
            return r;
        end)..'0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
            if (#x < 6) then return '' end
            local c=0
            for i=1,6 do c=c+(x:sub(i,i)=='1' and 2^(6-i) or 0) end
            return b:sub(c+1,c+1)
        end)..({ '', '==', '=' })[#data%3+1])
    end
    ------------------------------------------------------------------------------------------------------
    function VF_decBase64(data) -- https://stackoverflow.com/questions/34618946/lua-base64-encode
      if not data then return end
      local b='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/' -- You will need this for encoding/decoding
        data = string.gsub(data, '[^'..b..'=]', '')
        return (data:gsub('.', function(x)
            if (x == '=') then return '' end
            local r,f='',(b:find(x)-1)
            for i=6,1,-1 do r=r..(f%2^i-f%2^(i-1)>0 and '1' or '0') end
            return r;
        end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
            if (#x ~= 8) then return '' end
            local c=0
            for i=1,8 do c=c+(x:sub(i,i)=='1' and 2^(8-i) or 0) end
                return string.char(c)
        end))
    end
    ---------------------------------------------------------------------------------------------------------------------
    function VF_GetShortSmplName(path) 
      local fn = path
      fn = fn:gsub('%\\','/')
      if fn then fn = fn:reverse():match('(.-)/') end
      if fn then fn = fn:reverse() end
      return fn
    end
    ---------------------------------------------------------------------  
    function VF_Format_Pan(D_PAN) 
      local D_PAN_format = 'C'
      if D_PAN > 0 then 
        D_PAN_format = math.floor(math.abs(D_PAN*100))..'R'
       elseif D_PAN < 0 then 
        D_PAN_format = math.floor(math.abs(D_PAN*100))..'L'
      end
      return D_PAN_format
    end
    ----------------------------------------------------------------------- 
    function VF_Format_Note(note ,t) 
      local offs = 0
      if DATA.REAPERini and DATA.REAPERini.REAPER and DATA.REAPERini.REAPER.midioctoffs then offs = DATA.REAPERini.REAPER.midioctoffs-1 end
      local val = math.floor(note)
      local oct = math.floor(note / 12) + offs
      local note = math.fmod(note,  12)
      local key_names = {'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'}
      
      local out_str 
      
      -- handle names
        if t and t.P_NAME then return t.P_NAME end
        
      -- note  
        if note and oct and key_names[note+1] then 
          return key_names[note+1]..oct-1 
        end
    end
    
    ------------------------------------------------------------------------------------------------------
    function WDL_DB2VAL(x) return math.exp((x)*0.11512925464970228420089957273422) end  --https://github.com/majek/wdl/blob/master/WDL/db2val.h
    ------------------------------------------------------------------------------------------------------
    function WDL_VAL2DB(x)   --https://github.com/majek/wdl/blob/master/WDL/db2val.h
      if not x or (x and x < 0.0000000298023223876953125) then return -150.0 end
      local v=math.log(x)*8.6858896380650365530225783783321
      if v<-150.0 then return -150.0 else return v end
    end
    --------------------------------------------------
    function VF_GetTrackByGUID(giv_guid, reaproj)
      if not (giv_guid and giv_guid:gsub('%p+','')) then return end
      for i = 1, CountTracks(reaproj or -1) do
        local tr = GetTrack(reaproj or -1,i-1)
        local retval, GUID = reaper.GetSetMediaTrackInfo_String( tr, 'GUID', '', false )
        if GUID:gsub('%p+','') == giv_guid:gsub('%p+','') then return tr end
      end
    end
    ---------------------------------------------------
    function VF_GetFXByGUID(GUID, tr, proj)
      if not GUID then return end
      local pat = '[%p]+'
      if not tr then
        for trid = 1, CountTracks(proj or -1) do
          local tr = GetTrack(proj,trid-1)
          local fxcnt_main = TrackFX_GetCount( tr ) 
          local fxcnt = fxcnt_main + TrackFX_GetRecCount( tr ) 
          for fx = 1, fxcnt do
            local fx_dest = fx
            if fx > fxcnt_main then fx_dest = 0x1000000 + fx - fxcnt_main end  
            if TrackFX_GetFXGUID( tr, fx-1):gsub(pat,'') == GUID:gsub(pat,'') then return true, tr, fx-1 end 
          end
        end  
       else
        if not (ValidatePtr2(proj or -1, tr, 'MediaTrack*')) then return end
        local fxcnt_main = TrackFX_GetCount( tr ) 
        local fxcnt = fxcnt_main + TrackFX_GetRecCount( tr ) 
        for fx = 1, fxcnt do
          local fx_dest = fx
          if fx > fxcnt_main then fx_dest = 0x1000000 + fx - fxcnt_main end  
          if TrackFX_GetFXGUID( tr, fx_dest-1):gsub(pat,'') == GUID:gsub(pat,'') then return true, tr, fx_dest-1 end 
        end
      end    
    end
    
    -------------------------------------------------------------------------------- 
    function DATA:CollectData2() -- do various stuff after refresh main data 
      if not DATA.upd2 then return end
      
      if DATA.upd2.updatedevicevelocityrange then DATA:Auto_Device_RefreshVelocityRange(DATA.upd2.updatedevicevelocityrange) DATA.upd2.updatedevicevelocityrange = nil end
      if DATA.upd2.seqprint then DATA:_Seq_Print(nil, DATA.upd2.seqprint_minor) DATA.upd2.seqprint=nil DATA.upd2.seqprint_minor=nil end
      if DATA.upd2.refreshpeaks then DATA:CollectData2_GetPeaks() DATA.upd2.refreshpeaks = false end
      --DATA.upd2.refreshscroll
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
      
      if not DATA.seq_functionscall then 
        gmem_write(1025, 11) -- DATA.upd - step seq
      end
      
      DATA:_Seq_RefreshStepSeq()
    end
    -------------------------------------------------------------------------------- 
    function DATA:_Seq_RefreshStepSeq() 
      if not DATA.seq_functionscall then 
        gmem_write(1030,1 ) -- DATA.upd refresh steseq 
        gmem_write(1028, 1) -- force step seq to refresh EXT
       else
        gmem_write(1030,1 ) -- DATA.upd refresh steseq 
      end
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
      
      --DATA.upd = true
    end
    -------------------------------------------------------------------------------- 
    function DATA:handleViewportXYWH()
      if not (DATA.display_x and DATA.display_y) then return end 
      if not DATA.display_x_last then DATA.display_x_last = DATA.display_x end
      if not DATA.display_y_last then DATA.display_y_last = DATA.display_y end
      if not DATA.display_w_last then DATA.display_w_last = DATA.display_w end
      if not DATA.display_h_last then DATA.display_h_last = DATA.display_h end
      
      if  DATA.display_x_last~= DATA.display_x 
        or DATA.display_y_last~= DATA.display_y 
        or DATA.display_w_last~= DATA.display_w 
        or DATA.display_h_last~= DATA.display_h 
        --or (DATA.display_dockID and DATA.display_dockID ~= DATA.dockID)
        then 
        DATA.display_schedule_save = os.clock() 
      end
      if DATA.display_schedule_save and os.clock() - DATA.display_schedule_save > 0.3 then 
        EXT.viewport_posX = DATA.display_x
        EXT.viewport_posY = DATA.display_y
        EXT.viewport_posW = DATA.display_w
        EXT.viewport_posH = DATA.display_h
        --EXT.viewport_dockID = DATA.display_dockID
        EXT:save() 
        DATA.display_schedule_save = nil 
      end
      DATA.display_x_last = DATA.display_x
      DATA.display_y_last = DATA.display_y
      DATA.display_w_last = DATA.display_w
      DATA.display_h_last = DATA.display_h
      
      --DATA.display_dockID = DATA.dockID
    end
    -------------------------------------------------------------------------------- 
    function DATA:handleProjUpdates()
      local SCC =  GetProjectStateChangeCount( 0 ) if (DATA.upd_lastSCC and DATA.upd_lastSCC~=SCC ) then DATA.upd = true end  DATA.upd_lastSCC = SCC
      local editcurpos =  GetCursorPosition()  if (DATA.upd_last_editcurpos and DATA.upd_last_editcurpos~=editcurpos ) then DATA.upd = true end DATA.upd_last_editcurpos=editcurpos 
      local reaproj = tostring(EnumProjects( -1 )) if (DATA.upd_last_reaproj and DATA.upd_last_reaproj ~= reaproj) then DATA.upd = true end DATA.upd_last_reaproj = reaproj
    end
      function VF_GetProjectSampleRate() return tonumber(reaper.format_timestr_pos( 1-reaper.GetProjectTimeOffset( 0,false ), '', 4 )) end -- get sample rate obey project start offset
    --------------------------------------------------------------------------------  
    function DATA:CollectData()  
      DATA.proj, DATA.proj_fn = EnumProjects( -1 )
      DATA.projstr = tostring(DATA.proj)
      DATA.SR = VF_GetProjectSampleRate() 
      DATA.wrong_parent_track_metadata = false
      
      
      
       -- parent
      DATA.parent_track = {
          valid = false,
          name = '', 
        }
      DATA:CollectData_Parent()
      
      -- children
      DATA.MIDIbus = {} 
      DATA.children = {}
      DATA:CollectData_Children()
      
      -- macro
      DATA:CollectData_Macro()
       
      -- other
      DATA:Choke_Read() 
      
      -- seq
      DATA:CollectData_Seq()
      
      --
      local allow_trig_auto_stuff = true
      if DATA.mainstate_manager == true and DATA.mainstate_seq == true then 
        if DATA.seq_functionscall == true then 
          if gmem_read(1028) == 1 then
            EXT:load()
            DATA.upd = true
            gmem_write(1028, 0)
          end
          allow_trig_auto_stuff = false 
        end
      end
      if allow_trig_auto_stuff == true then 
        -- auto handle stuff
        DATA:Auto_MIDIrouting() 
        DATA:Auto_MIDInotenames() 
        DATA:Auto_TCPMCP() 
      end
      
      DATA.upd2.refreshpeaks = true
    end
    -------------------------------------------------------------------------------- 
    function DATA:Auto_TCPMCP(force_show)
      if not (DATA.parent_track and DATA.parent_track.valid == true) then return end 
      local upd
      
      -- reset after settings change
        if force_show == true then 
          SetMediaTrackInfo_Value( DATA.parent_track.ptr, 'I_FOLDERCOMPACT', 0)
          for note in pairs(DATA.children) do
            local tr = DATA.children[note].tr_ptr
            SetMediaTrackInfo_Value( tr, 'B_SHOWINMIXER', 1)
            SetMediaTrackInfo_Value( tr, 'B_SHOWINTCP',1 )
            -- children
            for layer = 1, #DATA.children[note].layers do 
              local tr = DATA.children[note].layers[layer].tr_ptr
              if tr then 
                SetMediaTrackInfo_Value( tr, 'B_SHOWINMIXER', 1 )
                SetMediaTrackInfo_Value( tr, 'B_SHOWINTCP', 1 ) 
              end
            end
          end
          upd=true
        end
      
      -- set folder state
        if EXT.CONF_onadd_newchild_trackheightflags &1==1 then       -- set folder collapsed
          SetMediaTrackInfo_Value( DATA.parent_track.ptr, 'I_FOLDERCOMPACT', 1)
         elseif EXT.CONF_onadd_newchild_trackheightflags &2==2 then       -- set folder collapsed
          SetMediaTrackInfo_Value( DATA.parent_track.ptr, 'I_FOLDERCOMPACT', 2)
         elseif EXT.CONF_onadd_newchild_trackheightflags &2~=2 and EXT.CONF_onadd_newchild_trackheightflags &1~=1 then       -- set folder collapsed
          --local foldstate = GetMediaTrackInfo_Value( DATA.parent_track.ptr, 'I_FOLDERCOMPACT')   
          --if foldstate ~=0 then SetMediaTrackInfo_Value( DATA.parent_track.ptr, 'I_FOLDERCOMPACT', 0)       end
        end
    
      -- set children states 
        if EXT.CONF_onadd_newchild_trackheightflags &4==4 or  EXT.CONF_onadd_newchild_trackheightflags &8==8 then 
          for note in pairs(DATA.children) do
            local tr = DATA.children[note].tr_ptr
            if not anytr then anytr = tr end
            -- device
            if tr then 
              if EXT.CONF_onadd_newchild_trackheightflags &8==8 and GetMediaTrackInfo_Value( tr, 'B_SHOWINMIXER') == 1 then SetMediaTrackInfo_Value( tr, 'B_SHOWINMIXER', 0 ) upd=true end
              if EXT.CONF_onadd_newchild_trackheightflags &4==4 and GetMediaTrackInfo_Value( tr, 'B_SHOWINTCP') == 1 then SetMediaTrackInfo_Value( tr, 'B_SHOWINTCP', 0 ) upd=true end  
            end
            -- children
            for layer = 1, #DATA.children[note].layers do 
              local tr = DATA.children[note].layers[layer].tr_ptr
              if tr then 
                if EXT.CONF_onadd_newchild_trackheightflags &8==8 and GetMediaTrackInfo_Value( tr, 'B_SHOWINMIXER') == 1 then SetMediaTrackInfo_Value( tr, 'B_SHOWINMIXER', 0 ) upd=true end
                if EXT.CONF_onadd_newchild_trackheightflags &4==4 and GetMediaTrackInfo_Value( tr, 'B_SHOWINTCP') == 1 then SetMediaTrackInfo_Value( tr, 'B_SHOWINTCP', 0 ) upd=true end  
              end
            end
          end
        end
        
      -- refresh stuff 
        if upd==true then 
          TrackList_AdjustWindows( false )  
          reaper.UpdateTimeline()
          reaper.UpdateArrange()
        end
    end
    -------------------------------------------------------------------------------- 
    function DATA:CollectDataInit_ParseREAPERDB()
      if EXT.CONF_ignoreDBload == 1 then return end 
      local reaperini = get_ini_file()
      local backend = VF_LIP_load(reaperini)
      local exp_section = backend.reaper_explorer
      if not exp_section then 
        exp_section = backend.reaper_sexplorer
        if not exp_section then return end
      end 
      
      
      local reaperDB = {}
      for key in pairs(exp_section) do
        if key:match('Shortcut') then 
          if tostring(exp_section[key]) and tostring(exp_section[key]):lower():match('reaperfilelist') then 
            local db_key = key:gsub('Shortcut','ShortcutT')
            if exp_section[db_key] then   
              local dbame = exp_section[db_key]
              local db_filename = exp_section[key]
              DATA.reaperDB[dbame] = {filename = db_filename}
              
              local fullfp =  GetResourcePath()..'/MediaDB/'..db_filename
              local t = {}
              if  file_exists( fullfp ) then  
                t = {}
                local f =io.open(fullfp,'rb')
                local content = ''
                if f then  content = f:read('a') end f:close() 
                for line in content:gmatch('[^\r\n]+') do
                  if line:match('FILE %"(.-)%"') then
                    local fp = line:match('FILE %"(.-)%"')
                    t [#t+1] = {fp = fp,
                                fp_short  =VF_GetShortSmplName(fp)
                                }
                  end 
                end
              end
              
              DATA.reaperDB[dbame].files = t
              
            end
          end
        end
      end
      
    end
    ---------------------------------------------------------------------------------------------------------------------
    function DATA:CollectData2_GetPeaks_grabpeaks(t, padw, ignoreboundary) 
      local filename = t.instrument_filename
      if not filename then return end
      if not padw then return end
      
      local src = PCM_Source_CreateFromFileEx(filename, true )
      if not src then return end  
      local src_len =  GetMediaSourceLength( src ) 
      local stoffs_sec = 0
      local slice_len = src_len
      if ignoreboundary~= true then
        stoffs_sec = t.instrument_samplestoffs * src_len
        slice_len = src_len * (t.instrument_sampleendoffs - t.instrument_samplestoffs) 
      end
      local SR = GetMediaSourceSampleRate( src )
      local peakrate = SR
      if padw ~= -1 then
        peakrate =  math.max(padw / slice_len,200)
      end
       
      -- if slice_len > 30 then return {}, slice_len end   
      if slice_len < 0.01 then return  end   
      local n_ch = 1
      local want_extra_type = 0--115  -- 's' char 
      local n_spls = math.floor(slice_len*peakrate)
      if n_spls < 10 then return end  
      local buf = new_array(n_spls * n_ch * 2) -- min, max, spectral each chan(but now mono only)
      local retval =  PCM_Source_GetPeaks(    src, 
                                          peakrate, 
                                          stoffs_sec,--starttime, 
                                          n_ch,--numchannels, 
                                          n_spls, 
                                          want_extra_type, 
                                          buf ) 
      --buf.clear() 
      PCM_Source_Destroy( src )
      return buf, SR
    end
    ---------------------------------------------------------------------------------------------------------------------
    function DATA:CollectData2_GetPeaks()
      for note in pairs(DATA.children) do
        if DATA.children[note].layers and DATA.children[note].layers[1] then   
          local t = DATA.children[note].layers[1] 
          if not (DATA.peakscache[note] and DATA.peakscache[note].peaks_arr_valid==true and DATA.peakscache[note].peaks_arr) then 
            
            local arr = DATA:CollectData2_GetPeaks_grabpeaks(t, UI.calc_rack_padw) 
            if not DATA.peakscache[note] then DATA.peakscache[note] = {} end
            DATA.peakscache[note].peaks_arr = arr
            DATA.peakscache[note].peaks_arr_valid = true
          end
        end
      end
      
      local t, note, layer = DATA:Sampler_GetActiveNoteLayer()
      if DATA.children and DATA.children[note] and DATA.children[note].layers and DATA.children[note].layers[1] then
        if not (t.peaks_arr_sampler and t.peaks_arr_sampler_valid==true) then 
          t.peaks_arr_sampler = DATA:CollectData2_GetPeaks_grabpeaks(t, UI.settingsfixedW) 
          local full = true
          t.peaks_arr_samplerfull = DATA:CollectData2_GetPeaks_grabpeaks(t, UI.settingsfixedW, full) 
          t.peaks_arr_sampler_valid = true
        end
      end
    end    
    --------------------------------------------------------------------------------
    function DATA:CollectData_Always_RecentEvent()
      if not DATA.SR then return end
      local triggernote
      local retval, rawmsg, tsval, devIdx, projPos, projLoopCnt = MIDI_GetRecentInputEvent(0)
      if retval == 0 then return end -- stop if return null sequence
      if not ((devIdx & 0x10000) == 0 or devIdx == 0x1003e) then return end-- should works without this after REAPER6.39rc2, so thats just in case
      local isNoteOn = rawmsg:byte(1)>>4 == 0x9
      local isNoteOff = rawmsg:byte(1)>>4 == 0x8
      local playingnote = rawmsg:byte(2) 
      if isNoteOn == true and tsval > -4800 then -- only reeeally latest messages 
      
        -- input seq edit handler
          if DATA.seq_functionscall == true then 
            if DATA.temp_lasttrigsend_init and (not DATA.temp_lasttrigsend or (DATA.temp_lasttrigsend and time_precise() - DATA.temp_lasttrigsend>0.5) ) then
              DATA.temp_lasttrigsend = time_precise()
              gmem_write(1029,playingnote ) -- push a trigger to step seq
            end
            DATA.temp_lasttrigsend_init = true
          end
          
        if (DATA.lastMIDIinputnote and DATA.lastMIDIinputnote ~= playingnote) then triggernote = true  end
        DATA.lastMIDIinputnote = playingnote 
      end--{retval=retval, rawmsg=rawmsg, tsval=tsval, devIdx=devIdx, projPos=projPos, projLoopCnt=projLoopCnt,playingnote = rawmsg:byte(2) } 
  
      
      if triggernote == true then 
        if  EXT.UI_incomingnoteselectpad == 1 and DATA.parent_track and DATA.parent_track.ext then
          if EXT.CONF_seq_sendsysextoLP ~= 1 then
            DATA.parent_track.ext.PARENT_LASTACTIVENOTE = DATA.lastMIDIinputnote
            DATA:WriteData_Parent() --trigger write parent at script initialization // false storing last touched note to ext state
            DATA.upd = true
          end
        end
      end
      
    end
    --------------------------------------------------------------------------------
    function DATA:CollectData_Always()
      
      DATA.mainstate_manager = gmem_read(1026) == 1
      DATA.mainstate_seq = gmem_read(1027) == 1
      
      DATA:CollectData_Always_RecentEvent()
      DATA:CollectData_Always_ExtActions() 
      DATA:CollectData_Always_Peaks() 
      DATA:CollectData_Always_StepPositions()
      --DATA:CollectData_Always_LaunchPadInteraction()
      
    end
    ----------------------------------------------------------------------
    function DATA:CollectData_Always_Peaks() 
      if not DATA.children then return end
      if EXT.CONF_showplayingmeters == 0 then return end
      local max_sz = 2
      for note in pairs(DATA.children) do
        if not DATA.children[note].peaks then DATA.children[note].peaks = {} end
        local track = DATA.children[note].tr_ptr
        if track and ValidatePtr2(-1,track, 'MediaTrack*') then
          local L = Track_GetPeakInfo( track, 0 )
          local R = Track_GetPeakInfo( track, 1 )
          table.insert(DATA.children[note].peaks, 1, {L,R})
          local sz = #DATA.children[note].peaks
          local rmsL,rmsR = 0,0
          for i = 1, sz do
            rmsL = rmsL + DATA.children[note].peaks[i][1]
            rmsR = rmsR + DATA.children[note].peaks[i][2]
          end
          DATA.children[note].peaksRMS_L = rmsL / sz
          DATA.children[note].peaksRMS_R = rmsR / sz
          if sz>max_sz then DATA.children[note].peaks[max_sz+1] = nil end
        end
        
      end
    end
    ----------------------------------------------------------------------
    function DATA:CollectData_Always_ExtActions()
      local refreshSEQ = gmem_read(1030)
      if DATA.seq_functionscall == true and refreshSEQ == 1 then 
        DATA.upd = true
        DATA.seq.valid = false
        gmem_write(1030,0 )
      end
      
      local actions = gmem_read(1025)
      if actions == 0 then return end
      if DATA.seq_functionscall == true then  
        -- sequencer
        if actions == 11 then 
          DATA.upd = true 
          gmem_write(1025,0 )
        end 
        return -- restrict ext actions for sequencer  
       else
       
        -- rack
        if actions == 10 then 
          DATA.upd = true 
          gmem_write(1025,0 )  
        end 
      end 
      ---------------------------------------------------------- rack 
      -- Device / New kit
      if actions == 1 then    DATA:Sampler_NewRandomKit() end 
      
      
      -- prev sample
      if actions == 2 then   
        local note_layer_t = DATA:Sampler_GetActiveNoteLayer() 
        DATA:Sampler_NextPrevSample(note_layer_t,1) 
      end
      
      -- next sample
      if actions == 3 then  
        local note_layer_t, spls = DATA:Sampler_GetActiveNoteLayer()
        DATA:Sampler_NextPrevSample(note_layer_t,0 )  
      end
      
      -- rand sample
      if actions == 4 then   
        local note_layer_t, spls = DATA:Sampler_GetActiveNoteLayer()
        DATA:Sampler_NextPrevSample(note_layer_t,2 ) 
      end
    
      if actions == 6 then   -- lock active note database changes 
        if DATA.parent_track and DATA.parent_track.ext then
          
          local note_layer_t = DATA:Sampler_GetActiveNoteLayer() 
          if note_layer_t and note_layer_t.TYPE_DEVICE~= true then 
            Undo_BeginBlock2(DATA.proj )
            DATA:WriteData_Child(note_layer_t.tr_ptr, {SET_useDB = note_layer_t.SET_useDB~2})  
            Undo_EndBlock2( DATA.proj , 'RS5k manager - lock sample from randomization', 0xFFFFFFFF )
            DATA.upd = true
          end
          
        end 
      end
      
      if actions == 7 then   -- drumrack solo
        if DATA.parent_track and DATA.parent_track.ext then 
          local note = DATA.parent_track.ext.PARENT_LASTACTIVENOTE
          local note_t = DATA.children[note]
          Undo_BeginBlock2(DATA.proj )
          local outval = 2 if note_t.I_SOLO>0 then outval = 0 end SetMediaTrackInfo_Value( note_t.tr_ptr, 'I_SOLO', outval ) DATA.upd = true
          Undo_EndBlock2( DATA.proj , 'RS5k manager - Solo pad', 0xFFFFFFFF ) 
        end 
      end
      
      if actions == 8 then   -- drumrack mute
        if DATA.parent_track and DATA.parent_track.ext then 
          local note = DATA.parent_track.ext.PARENT_LASTACTIVENOTE
          local note_t = DATA.children[note]
          Undo_BeginBlock2(DATA.proj )
          SetMediaTrackInfo_Value( note_t.tr_ptr, 'B_MUTE', note_t.B_MUTE~1 ) DATA.upd = true
          Undo_EndBlock2( DATA.proj , 'RS5k manager - Mute pad', 0xFFFFFFFF ) 
        end 
      end
    
      if actions == 9 then   -- drumrack clear
        if DATA.parent_track and DATA.parent_track.ext then 
          DATA:Sampler_RemovePad(DATA.parent_track.ext.PARENT_LASTACTIVENOTE)
        end
      end
      
      
      -- 10 = sequencer
      -- 11 = rack
      
      if actions == 12 then   --RS5k_manager_Database_LoadAllPads
        DATA:Validate_MIDIbus_AND_ParentFolder() 
        Undo_BeginBlock2(DATA.proj )
        DATA:Database_Load() 
        Undo_EndBlock2( DATA.proj , 'Load database to all rack', 0xFFFFFFFF )
      end
      
      if actions == 13 then   --RS5k_manager_Database_LoadSelectedPads
        DATA:Validate_MIDIbus_AND_ParentFolder() 
        Undo_BeginBlock2(DATA.proj )
        DATA:Database_Load(true)
        Undo_EndBlock2( DATA.proj , 'Load database to selected pad only', 0xFFFFFFFF )
      end    
      
      if actions == 14 then   --RS5k_manager_Database_PrevMap
        EXT.UIdatabase_maps_current = EXT.UIdatabase_maps_current - 1
        if EXT.UIdatabase_maps_current == 0 then EXT.UIdatabase_maps_current = DATA.allowed_db_maps_cnt end
        EXT:save()
      end 
      
      if actions == 15 then   --RS5k_manager_Database_NextMap
        EXT.UIdatabase_maps_current = EXT.UIdatabase_maps_current + 1
        if EXT.UIdatabase_maps_current > DATA.allowed_db_maps_cnt then EXT.UIdatabase_maps_current = 1 end
        EXT:save()
      end 
      
      gmem_write(1025,0 ) -- clear to prevent infinite update
      
      
    end
    -----------------------------------------------------------------------
    function DATA:Sampler_RemovePad(note, layer) 
      if not (note and DATA.children and DATA.children[note]) then return end 
      local tr_ptr = DATA.children[note].tr_ptr
      if layer and DATA.children[note].layers and DATA.children[note].layers[layer] and DATA.children[note].layers[layer].tr_ptr then tr_ptr = DATA.children[note].layers[layer].tr_ptr end 
      --[[if not layer and not tr_ptr then 
        layer = 1
        if DATA.children[note].layers and DATA.children[note].layers[layer] then tr_ptr = DATA.children[note].layers[layer].tr_ptr end 
      end]]
      
      if not (tr_ptr and ValidatePtr2(-1,tr_ptr,'MediaTrack*')) then return end
      
      Undo_BeginBlock2(DATA.proj )
      --DeleteTrack( tr_ptr )
      Main_OnCommand(40769,0)-- Unselect (clear selection of) all tracks/items/envelope points 
      SetOnlyTrackSelected( tr_ptr )
      --Main_OnCommand(40184,0)-- Remove items/tracks/envelope points (depending on focus) - no prompting // THIS remove device with childrens AND handles keeping structure 
      Main_OnCommand(40005,0)-- Track: Remove tracks
      Undo_EndBlock2( DATA.proj , 'RS5k manager - Remove pad', 0xFFFFFFFF ) 
      SetOnlyTrackSelected( DATA.parent_track.ptr )
      DATA.upd = true
    end 
    ---------------------------------------------------------------------------------------------------------------------
    function DATA:Sampler_GetActiveNoteLayer()  
      if not (DATA.parent_track and DATA.parent_track.valid == true) then return end
      local layer =  DATA.parent_track.ext.PARENT_LASTACTIVENOTE_LAYER or 1  
      local note if not DATA.parent_track.ext.PARENT_LASTACTIVENOTE then return else note =DATA.parent_track.ext.PARENT_LASTACTIVENOTE end
      
      if DATA.children[note] 
        and DATA.children[note].layers 
        and DATA.children[note].layers[layer] then  
        return DATA.children[note].layers[layer],note,layer
      end
      
      if DATA.children[note] and DATA.children[note].layers and not DATA.children[note].layers[layer] then  
        return DATA.children[note],note,0
      end
      
    end
    -------------------------------------------------------------------------------- 
    function DATA:Sampler_NextPrevSample_getfilestable(note_layer_t) 
      local noteID = note_layer_t.noteID
      if noteID then DATA.peakscache[noteID] = nil end
      
      local fn = note_layer_t.instrument_filename:gsub('\\', '/') 
      local path = fn:reverse():match('[%/]+.*'):reverse():sub(0,-2)
      local cur_file =     fn:reverse():match('.-[%/]'):reverse():sub(2)
      local files_table = {}
      if note_layer_t.SET_useDB&1~=1 then 
        local i = 0
        repeat
          local fp = reaper.EnumerateFiles( path, i )
          if fp and reaper.IsMediaExtension(fp:gsub('.+%.', ''), false) then
            files_table[#files_table+1] = { fp = path..'/'..fp,
                                            fp_short  =fp
                                          }
          end
          i = i+1
        until fp == nil
        table.sort(files_table, function(a,b) return a.fp_short<b.fp_short end )
       else
        local db_name = note_layer_t.SET_useDB_name
        if db_name and DATA.reaperDB[db_name] then files_table = DATA.reaperDB[db_name].files end
      end
      return files_table,cur_file
    end
    -------------------------------------------------------------------------------- 
    function DATA:Sampler_NextPrevSample(note_layer_t, mode) 
       
      if not mode then mode = 0 end
      if not (note_layer_t and note_layer_t.ISRS5K) then return end
      
     
      local files_table,cur_file = DATA:Sampler_NextPrevSample_getfilestable(note_layer_t) 
      local trig_id
      local undohistory_str = 'Next sample'
      local files_tablesz = #files_table 
      
      local currentID = note_layer_t.SET_useDB_lastID
      if not currentID and mode ~=2 then 
        for i = 1, #files_table do if files_table[i].fp_short == cur_file then  currentID=i break end  end
      end
      
      if mode == 0  then    -- search file list next
        if #files_table < 2 then return end
        trig_id = currentID + 1
        if trig_id > files_tablesz then trig_id = 1 end--wrap
        goto trig_file_section
      end
      
      if mode == 1  then    -- search file list prev
        if files_tablesz < 2 then return end
        trig_id = currentID - 1
        if trig_id <1 then trig_id = files_tablesz end--wrap
        goto trig_file_section
      end
        
      if mode ==2 then        -- search file list random
        math.randomseed(time_precise()*10000)
        if #files_table < 2 then return end
        trig_id = math.floor(math.random(#files_table)) +1
        goto trig_file_section 
      end    
      
      ::trig_file_section::
      if trig_id and files_table[trig_id] then 
        local trig_file = files_table[trig_id].fp
        Undo_BeginBlock2(DATA.proj )
        DATA:DropSample(trig_file, note_layer_t.noteID, {layer=note_layer_t.layerID})  
        Undo_EndBlock2( DATA.proj , 'RS5k manager - '..undohistory_str, 0xFFFFFFFF ) 
        DATA:WriteData_Child(note_layer_t.tr_ptr, {SET_useDB_lastID = trig_id})   
      end
        
    end
    
    --------------------------------------------------------------------------------  
    function DATA:CollectDataInit_MIDIdevices()
      DATA.Launchpad_output = false
      DATA.MIDI_inputs = {[63]='All inputs',[62]='Virtual keyboard'}
      for dev = 1, reaper.GetNumMIDIInputs() do
        local retval, nameout = reaper.GetMIDIInputName( dev-1, '' )
        if retval then DATA.MIDI_inputs[dev-1] = nameout end
      end
      
      DATA.MIDI_outputs = {[-1]='[none]'}
      for dev = 1, reaper.GetNumMIDIOutputs() do
        local retval, nameout = reaper.GetMIDIOutputName( dev-1, '' )
        if retval then DATA.MIDI_outputs[dev-1] = nameout end
        
        if EXT.CONF_midioutput == dev-1 and 
          
          (
            nameout:lower():match('lpmini') or
            nameout:lower():match('lppro')
          )
         then
          
          DATA.Launchpad_output = true
        end
      end
      
      
      
    end
    --------------------------------------------------------------------- 
    function DATA:Auto_Device_RefreshVelocityRange(note)
      if not (DATA.children and DATA.children[note] and DATA.children[note].layers) then return end
      if DATA.children[note].TYPE_DEVICE_AUTORANGE == false then return end
      
      if #DATA.children[note].layers == 0 then return end
      
      local min_velID = 17
      local max_velID = 18
      local block_sz = 127 / #DATA.children[note].layers
      
      for layer =1, #DATA.children[note].layers do
        if DATA.children[note].layers[layer].ISRS5K == true then 
          local track = DATA.children[note].layers[layer].tr_ptr
          local instrument_pos = DATA.children[note].layers[layer].instrument_pos
          
          TrackFX_SetParamNormalized( track, instrument_pos, min_velID, (block_sz*(layer-1))  *1/127)
          TrackFX_SetParamNormalized( track, instrument_pos, max_velID, (-1+block_sz*(layer))  *1/127 )
          if layer == #DATA.children[note].layers then 
            TrackFX_SetParamNormalized( track, instrument_pos, max_velID, 1)
          end
        end 
      end
    end
    --------------------------------------------------------------------- 
    function DATA:Auto_MIDInotenames() 
      if not (DATA.parent_track and DATA.parent_track.valid == true) then return end 
      
      for note = 0,127 do 
        if EXT.CONF_autorenamemidinotenames&1==1 then 
          -- midi bus
          if DATA.MIDIbus.valid == true then
            local outname = ''
            if DATA.children[note] and DATA.children[note].P_NAME then outname = DATA.children[note].P_NAME end
            if DATA.padcustomnames and DATA.padcustomnames[note] and DATA.padcustomnames[note] ~='' then outname = DATA.padcustomnames[note] end
            local curname = GetTrackMIDINoteNameEx( DATA.proj,  DATA.MIDIbus.tr_ptr, note,-1 )
            if curname ~= outname then SetTrackMIDINoteNameEx( DATA.proj,  DATA.MIDIbus.tr_ptr, note, -1, outname) end
          end
        end
        
        if EXT.CONF_autorenamemidinotenames&2==2 then 
          -- clear device
          if DATA.children[note] and DATA.children[note].tr_ptr and DATA.children[note].TYPE_DEVICE == true then 
            local curname = GetTrackMIDINoteNameEx( DATA.proj,  DATA.children[note].tr_ptr, note,-1 )
            if curname ~= '' then SetTrackMIDINoteNameEx( DATA.proj, DATA.children[note].tr_ptr, note, -1, '') end
          end
          -- set reg childrens to only theirs notes
          if DATA.children[note] and DATA.children[note].tr_ptr and DATA.children[note].layers then 
            for layer =1 , #DATA.children[note].layers do
              for tracknote = 0, 127 do
                local outname = ''
                if tracknote == note then outname =DATA.children[note].layers[layer].P_NAME end
                local curname = GetTrackMIDINoteNameEx( DATA.proj,  DATA.children[note].layers[layer].tr_ptr, tracknote,-1 )
                if curname ~= outname then SetTrackMIDINoteNameEx( DATA.proj,  DATA.children[note].layers[layer].tr_ptr, tracknote, -1, outname) end
              end 
            end
          end
          
        end
      end
    end
    -----------------------------------------------------------------------  
    function DATA:Validate_InitFilterDrive(note_layer_t) 
      local track = note_layer_t.tr_ptr
      if not note_layer_t.fx_reaeq_isvalid then 
        local reaeq_pos = TrackFX_AddByName( track, 'ReaEQ', 0, 1 )
        TrackFX_Show( track, reaeq_pos, 2 )
        TrackFX_SetNamedConfigParm( track, reaeq_pos, 'BANDTYPE0',3 )
        TrackFX_SetParamNormalized( track, reaeq_pos, 0, 1 )
        local GUID = reaper.TrackFX_GetFXGUID( track, reaeq_pos )
        DATA:WriteData_Child(track, {FX_REAEQ_GUID = GUID}) 
        DATA.upd = true
      end
       
      if not note_layer_t.fx_ws_isvalid then
        local ws_pos = TrackFX_AddByName( track, 'waveShapingDstr', 0, 1 )--'Distortion\\waveShapingDstr'
        TrackFX_Show( track, ws_pos, 2 )
        TrackFX_SetParamNormalized( track, ws_pos, 0, 0 )
        local GUID = reaper.TrackFX_GetFXGUID( track, ws_pos )
        DATA:WriteData_Child(track, {FX_WS_GUID = GUID}) 
        DATA.upd = true
      end
    end
    --------------------------------------------------------------------- 
    function DATA:Auto_MIDIrouting() 
      if not (DATA.parent_track and DATA.parent_track.valid == true) then return end 
      if not (DATA.MIDIbus.valid == true) then return end
      local MIDItr = DATA.MIDIbus.tr_ptr
      if not reaper.ValidatePtr2(DATA.proj, MIDItr, 'MediaTrack*') then return end
      
      local cntsends = GetTrackNumSends( MIDItr, 0 )
      local sends = {}
      for sendidx = 1, cntsends do
        local I_SRCCHAN = GetTrackSendInfo_Value( MIDItr, 0, sendidx-1, 'I_SRCCHAN' )
        local P_DESTTRACK = GetTrackSendInfo_Value( MIDItr, 0, sendidx-1, 'P_DESTTRACK' )
        local I_MIDIFLAGS = GetTrackSendInfo_Value( MIDItr, 0, sendidx-1, 'I_MIDIFLAGS' )
        local retval, P_DESTTRACK_GUID = reaper.GetSetMediaTrackInfo_String( P_DESTTRACK, 'GUID', '', false )
        if I_SRCCHAN == -1 then
          sends[P_DESTTRACK_GUID] = {
            I_MIDIFLAGS=I_MIDIFLAGS,
            sendidx=sendidx-1,
          }
        end
      end
        
      -- validate links
        for note in pairs(DATA.children) do
          -- make sure there is no midi send to device  
          if DATA.children[note].TYPE_DEVICE == true and DATA.children[note].TR_GUID and sends[DATA.children[note].TR_GUID] then RemoveTrackSend( MIDItr, 0, sends[DATA.children[note].TR_GUID].sendidx ) end
          
          -- check devicechilds/regular childs has receive from MIDI track
          if DATA.children[note].layers then
            for layer in pairs(DATA.children[note].layers) do
              if DATA.children[note].layers[layer] and DATA.children[note].layers[layer].TR_GUID then
                local destGUID = DATA.children[note].layers[layer].TR_GUID
                
                if not sends[destGUID] or (sends[destGUID] and sends[destGUID].I_MIDIFLAGS ~= DATA.parent_track.ext.PARENT_MIDIFLAGS) then   
                  local sendidx = CreateTrackSend( MIDItr, DATA.children[note].layers[layer].tr_ptr )
                  if sendidx >=0 then
                    SetTrackSendInfo_Value( MIDItr, 0, sendidx, 'I_SRCCHAN',-1 )
                    SetTrackSendInfo_Value( MIDItr, 0, sendidx, 'I_MIDIFLAGS',DATA.parent_track.ext.PARENT_MIDIFLAGS )
                  end
                end
                
              end 
            end
          end
          
        end   
    end
    -----------------------------------------------------------------------
    function DATA:Sampler_NewRandomKit() 
      if not (DATA.parent_track and DATA.parent_track.ext) then return end
      Undo_BeginBlock2(DATA.proj )
      
      for note in pairs(DATA.children) do 
        if DATA.children[note].TYPE_DEVICE~= true then 
          for layer =1,#DATA.children[note].layers do 
            local note_layer_t = DATA.children[note].layers[layer]
            if note_layer_t.SET_useDB&1==1 and  note_layer_t.SET_useDB&2~=2 then 
              DATA:Sampler_NextPrevSample(note_layer_t, 2)  
            end
          end
        end
      end
      
      
      Undo_EndBlock2( DATA.proj , 'RS5k manager - New kit', 0xFFFFFFFF )
      DATA.upd=true
    end
    -------------------------------------------------------------------------------- 
    function DATA:CollectData_Parent()  
      DATA.parent_track.ext_load = false
      -- get track pointer
        local parent_track 
        local retval, trGUIDext = reaper.GetProjExtState( DATA.proj, 'MPLRS5KMAN', 'STICKPARENTGUID' )
        if retval and trGUIDext ~= '' then 
          parent_track = VF_GetTrackByGUID(trGUIDext, DATA.proj)
          if not parent_track then 
            parent_track = GetSelectedTrack(DATA.proj,0) 
            SetProjExtState( DATA.proj, 'MPLRS5KMAN', 'STICKPARENTGUID','' )
          end -- load selected track if external is not found
          DATA.parent_track.ext_load = true
         else
          -- get selected track
          parent_track = GetSelectedTrack(DATA.proj,0)
        end 
      
      -- catch parent by childen
        if parent_track then 
          local ret, parGUID = DATA:CollectData_IsChildOwnedByParent(parent_track)
          if parGUID and parGUID ~= '' then parent_track = VF_GetTrackByGUID(parGUID,DATA.proj) end 
        end
        
      if not parent_track then return end 
      
      -- get native data
        local retval, trGUID = GetSetMediaTrackInfo_String( parent_track, 'GUID', '', false ) 
        local retval, name = GetSetMediaTrackInfo_String( parent_track, 'P_NAME', '', false )
        local IP_TRACKNUMBER_0based = GetMediaTrackInfo_Value( parent_track, 'IP_TRACKNUMBER')-1 
        local I_FOLDERDEPTH = GetMediaTrackInfo_Value( parent_track, 'I_FOLDERDEPTH')
        local I_CUSTOMCOLOR = GetMediaTrackInfo_Value( parent_track, 'I_CUSTOMCOLOR')
        local cnt_tracks = CountTracks( DATA.proj )
        local IP_TRACKNUMBER_0basedlast = IP_TRACKNUMBER_0based
        
        if I_FOLDERDEPTH == 1 then
          local depth = 0
          for trid = IP_TRACKNUMBER_0based + 1, cnt_tracks do
            local tr = GetTrack(DATA.proj, trid-1)
            depth = depth + GetMediaTrackInfo_Value( tr, 'I_FOLDERDEPTH')
            if depth <= 0 then 
              IP_TRACKNUMBER_0basedlast = trid-1
              break
            end
          end
        end 
         
      -- init ext data
        DATA.parent_track.ext = {
            PARENT_DRRACKSHIFT = 36,
            PARENT_MACROCNT = 16,
            PARENT_LASTACTIVENOTE = -1,
            PARENT_LASTACTIVENOTE_LAYER = 1,
            PARENT_LASTACTIVEMACRO = -1,
            PARENT_MIDIFLAGS = 0,
            PARENT_MACRO_GUID = '',
            PARENT_PADNAMES_OVERRIDES_b64 = ''
          }
          
          
          
          
          
          
        if EXT.UI_drracklayout == 2 then DATA.parent_track.ext.PARENT_DRRACKSHIFT = 11 end
      -- read values v3 (backw compatibility)
        local retval, chunk = GetSetMediaTrackInfo_String(parent_track, 'P_EXT:MPLRS5KMAN', '', false )
        if retval and chunk ~= '' then
          for line in chunk:gmatch('[^\r\n]+') do
            local key,value = line:match('([%p%a%d]+)%s([%p%a%d]+)')
            if key and value then 
              DATA.parent_track.ext[key] = tonumber(value) or value
            end
          end
        end
      
      -- v4
        
        local ret, GUIDINTERNAL = GetSetMediaTrackInfo_String ( parent_track, 'P_EXT:MPLRS5KMAN_GUIDINTERNAL', '', false)         if ret then DATA.parent_track.ext.PARENT_GUID_INTERNAL = GUIDINTERNAL end
        local parent_track_GUID = reaper.GetTrackGUID(  parent_track )
        if GUIDINTERNAL ~= '' and GUIDINTERNAL ~= parent_track_GUID then
          DATA.wrong_parent_track_metadata = true
        end
        
        local ret, DRRACKSHIFT = GetSetMediaTrackInfo_String ( parent_track, 'P_EXT:MPLRS5KMAN_DRRACKSHIFT', 0, false)            if ret then DATA.parent_track.ext.PARENT_DRRACKSHIFT = tonumber(DRRACKSHIFT) end
        local ret, MACROCNT = GetSetMediaTrackInfo_String ( parent_track, 'P_EXT:MPLRS5KMAN_MACROCNT', 0, false)                  if ret then DATA.parent_track.ext.PARENT_MACROCNT = tonumber(MACROCNT) end
        local ret, LASTACTIVENOTE = GetSetMediaTrackInfo_String ( parent_track, 'P_EXT:MPLRS5KMAN_LASTACTIVENOTE', 0, false)      if ret then DATA.parent_track.ext.PARENT_LASTACTIVENOTE = tonumber(LASTACTIVENOTE) end
        local ret, LASTACTIVENOTE_LAYER = GetSetMediaTrackInfo_String ( parent_track, 'P_EXT:MPLRS5KMAN_LASTACTIVENOTE_LAYER', 0, false)  if ret then DATA.parent_track.ext.PARENT_LASTACTIVENOTE_LAYER = tonumber(LASTACTIVENOTE_LAYER ) end
        local ret, LASTACTIVEMACRO = GetSetMediaTrackInfo_String ( parent_track, 'P_EXT:MPLRS5KMAN_LASTACTIVEMACRO', 0, false)    if ret then DATA.parent_track.ext.PARENT_LASTACTIVEMACRO = tonumber(LASTACTIVEMACRO ) end
        local ret, MIDIFLAGS = GetSetMediaTrackInfo_String ( parent_track, 'P_EXT:MPLRS5KMAN_MIDIFLAGS', 0, false)                if ret then DATA.parent_track.ext.PARENT_MIDIFLAGS = tonumber(MIDIFLAGS) end
        local ret, MACRO_GUID = GetSetMediaTrackInfo_String ( parent_track, 'P_EXT:MPLRS5KMAN_MACRO_GUID', 0, false)              if ret then DATA.parent_track.ext.PARENT_MACRO_GUID = MACRO_GUID end
        local ret, MACROEXT_B64 = GetSetMediaTrackInfo_String ( parent_track, 'P_EXT:MPLRS5KMAN_MACROEXT_B64', 0, false)
        if ret then 
          DATA.parent_track.ext.PARENT_MACROEXT_B64 = MACROEXT_B64      
          DATA.parent_track.ext.PARENT_MACROEXT = table.loadstring(VF_decBase64(MACROEXT_B64)) or {}
        end  
        local ret, PARENT_PADNAMES_OVERRIDES_b64 = GetSetMediaTrackInfo_String ( parent_track, 'P_EXT:MPLRS5KMAN_PARENT_PADNAMES_OVERRIDES_b64', 0, false) 
        DATA.parent_track.padcustomnames_overrides = {}
        if PARENT_PADNAMES_OVERRIDES_b64~='' then
          local str = VF_decBase64(PARENT_PADNAMES_OVERRIDES_b64)
          for pair in str:gmatch('[%d]+%=".-"') do
            local id, val = pair:match('([%d]+)="(.-)%"')
            if id and val then 
              id = tonumber(id)
              if id then  DATA.parent_track.padcustomnames_overrides[id] = val end
            end
          end
        end
        
                    
                    
        
      DATA.parent_track.valid = true
      DATA.parent_track.ptr = parent_track
      DATA.parent_track.trGUID = trGUID
      DATA.parent_track.name = name
      DATA.parent_track.IP_TRACKNUMBER_0based = IP_TRACKNUMBER_0based
      DATA.parent_track.IP_TRACKNUMBER_0basedlast = IP_TRACKNUMBER_0basedlast
      DATA.parent_track.I_FOLDERDEPTH = I_FOLDERDEPTH
      DATA.parent_track.I_CUSTOMCOLOR = I_CUSTOMCOLOR
      
      
    end
    ---------------------------------------------------------------------
    function DATA:CollectData_IsChildOwnedByParent(track)  
      local ret, parGUID = GetSetMediaTrackInfo_String( track, 'P_EXT:MPLRS5KMAN_CHILD_PARENTGUID', '', false) 
      if DATA.parent_track.trGUID and parGUID == DATA.parent_track.trGUID then ret = true else ret = false end 
      
      return ret, parGUID
    end
    --------------------------------------------------------------------- 
    function DATA:CollectData_Macro()
      DATA.parent_track.macro = {}
      if DATA.parent_track.valid ~= true then return end
      local MACRO_GUID = DATA.parent_track.ext.PARENT_MACRO_GUID   
      if not (MACRO_GUID and MACRO_GUID~='') then 
        --DATA:Macro_InitChildrenMacro()
        return 
      end
  
      -- validate macro jsfx
        local ret,tr, MACRO_pos = VF_GetFXByGUID(MACRO_GUID, DATA.parent_track.ptr, DATA.proj)
        if not (ret and MACRO_pos and MACRO_pos ~= -1) then return end
        DATA.parent_track.macro.pos = MACRO_pos 
        DATA.parent_track.macro.fxGUID = MACRO_GUID
        DATA.parent_track.macro.valid = true
  
      -- get sliders
        DATA.parent_track.macro.sliders = {}
        for i = 1, 16 do
          local param_val = TrackFX_GetParamNormalized( DATA.parent_track.ptr, MACRO_pos, i )
          DATA.parent_track.macro.sliders[i] = {
            val = param_val,
          }
        end
  
      -- get links 
        for note in pairs(DATA.children) do
          if DATA.children[note] and DATA.children[note].layers then 
            for layer in pairs(DATA.children[note].layers) do
              has_links = DATA:CollectData_Macro_sub(DATA.children[note].layers[layer])
            end
          end
        end
        
      -- print to children table
        for slider in pairs(DATA.parent_track.macro.sliders) do
          if DATA.parent_track.macro.sliders[slider].links then 
            for link in pairs(DATA.parent_track.macro.sliders[slider].links) do
              local t = DATA.parent_track.macro.sliders[slider].links[link].note_layer_t
              for key in pairs(t) do
                if key:match('instrument_') and key:match('ID') and not key:match('MACRO')  then 
                  local param = t[key]
                  local param_dest = DATA.parent_track.macro.sliders[slider].links[link].param_dest
                  if param_dest == param  then t[key..'_MACRO'] = slider end
                end
              end
            end
          end
        end
        
        
    end
    -------------------------------------------------------------------  
    function DATA:CollectData_Macro_sub(note_layer_t)
      if not note_layer_t then return end
      if not note_layer_t.tr_ptr then return end
      for fxid = 1,  TrackFX_GetCount( note_layer_t.tr_ptr ) do
        if fxid ~= note_layer_t.MACRO_pos then
          for paramnumber = 0, TrackFX_GetNumParams( note_layer_t.tr_ptr, fxid-1 )-1 do
            local isactive = ({TrackFX_GetNamedConfigParm(note_layer_t.tr_ptr, fxid-1, 'param.'..paramnumber..'plink.active')})[2] isactive = tonumber(isactive) 
            if isactive and isactive ==1 then
              local src_fx = ({TrackFX_GetNamedConfigParm(note_layer_t.tr_ptr, fxid-1, 'param.'..paramnumber..'plink.effect')})[2] src_fx = tonumber(src_fx) 
              local src_param = ({TrackFX_GetNamedConfigParm(note_layer_t.tr_ptr, fxid-1, 'param.'..paramnumber..'plink.param')})[2] src_param = tonumber(src_param) 
              if src_fx and src_fx == note_layer_t.MACRO_pos then
                local retval, pname = reaper.TrackFX_GetParamName( note_layer_t.tr_ptr, fxid-1,paramnumber)
                local macroID = src_param  
                if DATA.parent_track.macro.sliders[macroID] then 
                  if not DATA.parent_track.macro.sliders[macroID].links then DATA.parent_track.macro.sliders[macroID].links = {} end
                  local linkID = #DATA.parent_track.macro.sliders[macroID].links+1
                  local baseline = ({TrackFX_GetNamedConfigParm(note_layer_t.tr_ptr, fxid-1, 'param.'..paramnumber..'mod.baseline')})[2] baseline = tonumber(baseline) 
                  local plink_offset = ({TrackFX_GetNamedConfigParm(note_layer_t.tr_ptr, fxid-1, 'param.'..paramnumber..'plink.offset')})[2] plink_offset = tonumber(plink_offset) 
                  local plink_scale = ({TrackFX_GetNamedConfigParm(note_layer_t.tr_ptr, fxid-1, 'param.'..paramnumber..'plink.scale')})[2] plink_scale = tonumber(plink_scale) 
                  local plink_offset_format = math.floor(plink_offset*100)..'%'
                  local plink_scale_format = math.floor(plink_scale*100)..'%'
                  
                  
                  local UI_min = baseline
                  local UI_max = baseline + plink_scale
                  
                  
                  DATA.parent_track.macro.sliders[macroID].links[linkID] = {
                      linkID=linkID,
                      param_name = pname,
                      plink_offset = plink_offset,
                      plink_offset_format = plink_offset_format,
                      plink_scale = plink_scale,
                      plink_scale_format = plink_scale_format,
                      note_layer_t = note_layer_t,
                      fx_dest = fxid-1,
                      param_dest = paramnumber,
                      UI_min = UI_min,
                      UI_max = UI_max,
                      baseline=baseline,
                    }
                  DATA.parent_track.macro.sliders[macroID].has_links = true 
                end 
              end
            end
          end
        end
      end 
      return has_links
    end
    -------------------------------------------------------------------------------- 
    function DATA:CollectData_FormatVolume(D_VOL)  
      return ( math.floor(WDL_VAL2DB(D_VOL)*10)/10) ..'dB'
    end
    
    -------------------------------------------------------------------------------- 
    function DATA:CollectData_Children()   
      if DATA.parent_track.valid ~= true then return end 
      for i = DATA.parent_track.IP_TRACKNUMBER_0based+1, DATA.parent_track.IP_TRACKNUMBER_0basedlast do -- loop through track inside selected folder
      
        -- validate parent
          local track = GetTrack(DATA.proj, i) 
          if DATA:CollectData_IsChildOwnedByParent(track) ~= true  then goto nexttrack end
          
        -- handle midi
          local retMIDI = DATA:CollectData_Children_MIDIbus(track) 
          if retMIDI == true then goto nexttrack end         
   
          
        -- get track data
          local retval, trGUID =             GetSetMediaTrackInfo_String( track, 'GUID', '', false ) 
          local retval, P_NAME =             GetSetMediaTrackInfo_String( track, 'P_NAME', '', false ) 
          local IP_TRACKNUMBER_0based =             GetMediaTrackInfo_Value( track, 'IP_TRACKNUMBER')
          local D_VOL =                      GetMediaTrackInfo_Value( track, 'D_VOL' )
          local D_VOL_format =               DATA:CollectData_FormatVolume(D_VOL)  
          local D_PAN =                      GetMediaTrackInfo_Value( track, 'D_PAN' )
          local D_PAN_format =               VF_Format_Pan(D_PAN)
          local B_MUTE =                     GetMediaTrackInfo_Value( track, 'B_MUTE' )
          local I_SOLO =                     GetMediaTrackInfo_Value( track, 'I_SOLO' )
          local I_CUSTOMCOLOR =              GetMediaTrackInfo_Value( track, 'I_CUSTOMCOLOR' )
          local I_FOLDERDEPTH =              GetMediaTrackInfo_Value( track, 'I_FOLDERDEPTH' ) 
          local I_PLAY_OFFSET_FLAG =         GetMediaTrackInfo_Value( track, 'I_PLAY_OFFSET_FLAG' ) 
          local D_PLAY_OFFSET =              GetMediaTrackInfo_Value( track, 'D_PLAY_OFFSET' ) 
          local PLAY_OFFSET = 0
          if I_PLAY_OFFSET_FLAG&1==0 then
            if I_PLAY_OFFSET_FLAG&2==2 then PLAY_OFFSET = D_PLAY_OFFSET / DATA.SR else PLAY_OFFSET = D_PLAY_OFFSET end
          end
          local PLAY_OFFSET_format =        math.floor(PLAY_OFFSET*1000)..'ms'
          local sends = {}
          local cntsends = GetTrackNumSends( track, 0 )
          for sendidx = 1, cntsends do 
            local sD_VOL = GetTrackSendInfo_Value( track, 0, sendidx-1, 'D_VOL' )
            local sD_PAN = GetTrackSendInfo_Value( track, 0, sendidx-1, 'D_PAN' )
            local P_DESTTRACK = GetTrackSendInfo_Value( track, 0, sendidx-1, 'P_DESTTRACK' )
            if P_DESTTRACK then 
              local ret, P_DESTTRACKname = GetTrackName(P_DESTTRACK)
              local P_DESTTRACKGUID = GetTrackGUID(P_DESTTRACK)
              sends[sendidx] ={
                D_VOL=sD_VOL,
                D_PAN=sD_PAN,
                P_DESTTRACK=P_DESTTRACK,
                P_DESTTRACKname=P_DESTTRACKname,
                P_DESTTRACKGUID=P_DESTTRACKGUID,
                
                }
            end
          end
          
          
        -- validate attached note
          local ret, note =                   GetSetMediaTrackInfo_String         ( track, 'P_EXT:MPLRS5KMAN_NOTE',0, false) 
          note = tonumber(note) 
          if not note then goto nexttrack end 
          
        -- init note/layer
          if not DATA.children[note] then DATA.children[note] = {
            layers = {}, 
            P_NAME = P_NAME,
            I_CUSTOMCOLOR = I_CUSTOMCOLOR,
            B_MUTE = B_MUTE,
            I_SOLO = I_SOLO,
            tr_ptr = track,
            noteID=note,
            IP_TRACKNUMBER_0based=IP_TRACKNUMBER_0based,
            sends=sends,
          } end 
        
        -- SYSHANDLER
          if DATA.children[note].SYSEXHANDLER_isvalid~=true then 
            local SYSHANDLER_ID = TrackFX_AddByName(track, 'sysex_handler', false, 0 )
            if SYSHANDLER_ID ~= -1 then
              DATA.children[note].SYSEXHANDLER_isvalid = true
              DATA.children[note].SYSEXHANDLER_ID = SYSHANDLER_ID
            end
            local ret, SYSEXMOD =          GetSetMediaTrackInfo_String   ( track, 'P_EXT:MPLRS5KMAN_SYSEXMOD', 0, false) SYSEXMOD = (tonumber(SYSEXMOD) or 0)==1
            DATA.children[note].SYSEXMOD = SYSEXMOD
          end
          
                  
        -- define type (regular_child / device / device_child)
          local ret, TYPE_REGCHILD =          GetSetMediaTrackInfo_String   ( track, 'P_EXT:MPLRS5KMAN_TYPE_REGCHILD', 0, false) TYPE_REGCHILD = (tonumber(TYPE_REGCHILD) or 0)==1
          local ret, TYPE_DEVICECHILD =       GetSetMediaTrackInfo_String   ( track, 'P_EXT:MPLRS5KMAN_TYPE_DEVICECHILD', 0, false) TYPE_DEVICECHILD = (tonumber(TYPE_DEVICECHILD) or 0)==1
          local ret, TYPE_DEVICE =            GetSetMediaTrackInfo_String   ( track, 'P_EXT:MPLRS5KMAN_TYPE_DEVICE', 0, false) TYPE_DEVICE =  (tonumber(TYPE_DEVICE) or 0)==1 
          local ret, TYPE_DEVICE_AUTORANGE =            GetSetMediaTrackInfo_String   ( track, 'P_EXT:MPLRS5KMAN_TYPE_DEVICE_AUTORANGE', 0, false) TYPE_DEVICE_AUTORANGE =  (tonumber(TYPE_DEVICE_AUTORANGE) or EXT.CONF_onadd_autosetrange)==1 
          
         
          
          local ret, TYPE_DEVICECHILD_PARENTDEVICEGUID = GetSetMediaTrackInfo_String   ( track, 'P_EXT:MPLRS5KMAN_TYPE_DEVICECHILD_PARENTDEVICEGUID', 0, false)
          local TYPE_DEVICECHILD_valid 
  
        -- various
          local ret, MPLRS5KMAN_TSADD = GetSetMediaTrackInfo_String   ( track, 'P_EXT:MPLRS5KMAN_TSADD', 0, false) MPLRS5KMAN_TSADD = tonumber(MPLRS5KMAN_TSADD) or 0
                    
                    
        -- refresh / patch on missing or non-valid devices
          if TYPE_DEVICE ~= true then 
          
            TYPE_DEVICECHILD_valid = false 
            if TYPE_DEVICECHILD_PARENTDEVICEGUID then 
              local devicetr = VF_GetTrackByGUID(TYPE_DEVICECHILD_PARENTDEVICEGUID, DATA.proj)
              if devicetr then
                TYPE_DEVICECHILD_valid = true
                --[[local ret, note_device =        GetSetMediaTrackInfo_String   ( devicetr, 'P_EXT:MPLRS5KMAN_NOTE',0, false) note_device = tonumber(note_device)
                if note_device then 
                  note = note_device 
                  GetSetMediaTrackInfo_String ( track, 'P_EXT:MPLRS5KMAN_NOTE',note, true) -- refresh device child note , make sure track is not inside different device
                end]]
               else
                TYPE_REGCHILD = true -- patch for case if TYPE_DEVICECHILD_PARENTDEVICEGUID is found but parent device is not valid
              end
             else
              TYPE_REGCHILD = true -- patch for case if TYPE_DEVICECHILD_PARENTDEVICEGUID not found but TYPE_REGCHILD not set 
            end 
            
          end
          
        -- add layer to note if device child
          if TYPE_DEVICECHILD == true or TYPE_REGCHILD == true then  
              local midifilt_pos = TrackFX_AddByName( track, 'midi_note_filter', false, 0) 
              if midifilt_pos == - 1 then midifilt_pos = nil end
              
              local layer = #DATA.children[note].layers +1 
              DATA.children[note].layers[layer] = { 
                                                
                                                noteID = note,
                                                layerID = layer,
                                                
                                                tr_ptr = track,
                                                TR_GUID =  trGUID,
                                                
                                                TYPE_REGCHILD=TYPE_REGCHILD, 
                                                TYPE_DEVICECHILD=TYPE_DEVICECHILD,
                                                TYPE_DEVICECHILD_PARENTDEVICEGUID=TYPE_DEVICECHILD_PARENTDEVICEGUID,
                                                TYPE_DEVICECHILD_valid = TYPE_DEVICECHILD_valid,
                                                MPLRS5KMAN_TSADD=MPLRS5KMAN_TSADD,
                                                
                                                D_VOL = D_VOL,
                                                D_VOL_format = D_VOL_format,
                                                D_PAN = D_PAN,
                                                D_PAN_format = D_PAN_format,
                                                B_MUTE = B_MUTE,
                                                I_SOLO = I_SOLO,
                                                I_CUSTOMCOLOR = I_CUSTOMCOLOR,
                                                I_FOLDERDEPTH = I_FOLDERDEPTH,
                                                P_NAME=P_NAME,
                                                IP_TRACKNUMBER_0based=IP_TRACKNUMBER_0based,
                                                PLAY_OFFSET = PLAY_OFFSET,
                                                PLAY_OFFSET_format = PLAY_OFFSET_format,
                                                
                                                midifilt_pos=midifilt_pos,
                                                sends=sends,
                                                }
            DATA:CollectData_Children_ExtState          (DATA.children[note].layers[layer])  
            DATA:CollectData_Children_InstrumentParams  (DATA.children[note].layers[layer]) 
            DATA:CollectData_Children_FXParams          (DATA.children[note].layers[layer]) 
            if DATA.children[note].layers[layer].SET_useDB&1==1 then DATA.children[note].has_setDB = true end
            if DATA.children[note].layers[layer].SET_useDB&2==2 then DATA.children[note].has_setDBlocked = true end
            
          end
          
        -- add device data
          if TYPE_DEVICE then 
            DATA.children[note].TYPE_DEVICE = TYPE_DEVICE  
            DATA.children[note].TYPE_DEVICE_AUTORANGE=TYPE_DEVICE_AUTORANGE
            DATA.children[note].tr_ptr = track
            DATA.children[note].TR_GUID = trGUID
            DATA.children[note].MACRO_GUID = MACRO_GUID
            DATA.children[note].noteID = note
            DATA.children[note].MACRO_pos =MACRO_pos
            
            DATA.children[note].D_VOL = D_VOL
            DATA.children[note].D_VOL_format = D_VOL_format
            DATA.children[note].D_PAN = D_PAN
            DATA.children[note].D_PAN_format = D_PAN_format
            DATA.children[note].B_MUTE = B_MUTE
            DATA.children[note].I_SOLO = I_SOLO
            DATA.children[note].I_CUSTOMCOLOR = I_CUSTOMCOLOR
            DATA.children[note].I_FOLDERDEPTH = I_FOLDERDEPTH
            DATA.children[note].P_NAME = P_NAME
            DATA.children[note].sends = sends
          end
        
        
        ::nexttrack::
      end
      
      -- make sure layer exist otherwise set to 1
      if DATA.parent_track.ext.PARENT_LASTACTIVENOTE and DATA.parent_track.ext.PARENT_LASTACTIVENOTE_LAYER and DATA.children[DATA.parent_track.ext.PARENT_LASTACTIVENOTE] and 
        not ( DATA.children[DATA.parent_track.ext.PARENT_LASTACTIVENOTE].layers and DATA.children[DATA.parent_track.ext.PARENT_LASTACTIVENOTE].layers[DATA.parent_track.ext.PARENT_LASTACTIVENOTE_LAYER] ) 
       then 
        DATA.parent_track.ext.PARENT_LASTACTIVENOTE_LAYER = 1 
      end
      
    end  
    
    
    ---------------------------------------------------------------------   
    function DATA:CollectData_Children_InstrumentParams_RS5k(note_layer_t, track,instrument_pos)
      
      if not note_layer_t.ISRS5K then return end
      
      note_layer_t.instrument_enabled = TrackFX_GetEnabled( track, instrument_pos )
      note_layer_t.instrument_volID = 0
      note_layer_t.instrument_vol = TrackFX_GetParamNormalized( track, instrument_pos, note_layer_t.instrument_volID ) 
      note_layer_t.instrument_vol_format=({TrackFX_GetFormattedParamValue( track, instrument_pos, note_layer_t.instrument_volID )})[2]..'dB'
      note_layer_t.instrument_panID = 1
      note_layer_t.instrument_pan = TrackFX_GetParamNormalized( track, instrument_pos, note_layer_t.instrument_panID ) 
      note_layer_t.instrument_pan_format=({TrackFX_GetFormattedParamValue( track, instrument_pos, note_layer_t.instrument_panID )})[2]
      note_layer_t.instrument_attackID = 9
      note_layer_t.instrument_attack = TrackFX_GetParamNormalized( track, instrument_pos,note_layer_t.instrument_attackID ) 
      note_layer_t.instrument_attack_format=({TrackFX_GetFormattedParamValue( track, instrument_pos, note_layer_t.instrument_attackID )})[2]..'ms'
      note_layer_t.instrument_decayID = 24
      note_layer_t.instrument_decay = TrackFX_GetParamNormalized( track, instrument_pos, note_layer_t.instrument_decayID ) 
      note_layer_t.instrument_decay_format=({TrackFX_GetFormattedParamValue( track, instrument_pos, note_layer_t.instrument_decayID )})[2]..'ms'
      note_layer_t.instrument_sustainID = 25
      note_layer_t.instrument_sustain = TrackFX_GetParamNormalized( track, instrument_pos, note_layer_t.instrument_sustainID ) 
      note_layer_t.instrument_sustain_format=({TrackFX_GetFormattedParamValue( track, instrument_pos, note_layer_t.instrument_sustainID )})[2]..'dB'
      note_layer_t.instrument_releaseID = 10
      note_layer_t.instrument_release = TrackFX_GetParamNormalized( track, instrument_pos, note_layer_t.instrument_releaseID ) 
      note_layer_t.instrument_release_format=({TrackFX_GetFormattedParamValue( track, instrument_pos, note_layer_t.instrument_releaseID )})[2]..'ms'
      note_layer_t.instrument_loopID = 12
      note_layer_t.instrument_loop = TrackFX_GetParamNormalized( track, instrument_pos, note_layer_t.instrument_loopID )
      note_layer_t.instrument_samplestoffsID = 13
      note_layer_t.instrument_samplestoffs = TrackFX_GetParamNormalized( track, instrument_pos, note_layer_t.instrument_samplestoffsID ) 
      note_layer_t.instrument_samplestoffs_format = (math.floor(note_layer_t.instrument_samplestoffs*1000)/10)..'%'
      note_layer_t.instrument_sampleendoffsID = 14
      note_layer_t.instrument_sampleendoffs = TrackFX_GetParamNormalized( track, instrument_pos, note_layer_t.instrument_sampleendoffsID ) 
      note_layer_t.instrument_sampleendoffs_format = (math.floor(note_layer_t.instrument_sampleendoffs*1000)/10)..'%'
      note_layer_t.instrument_loopoffsID = 23
      note_layer_t.instrument_loopoffs = TrackFX_GetParamNormalized( track, instrument_pos, note_layer_t.instrument_loopoffsID ) 
      note_layer_t.instrument_loopoffs_format = math.floor(note_layer_t.instrument_loopoffs *30*10000)/10
      
      note_layer_t.instrument_loopoffs_max = 1
      note_layer_t.instrument_attack_max = 1 
      note_layer_t.instrument_decay_max = 1 
      note_layer_t.instrument_release_max = 1 
      if note_layer_t.SAMPLELEN and note_layer_t.SAMPLELEN ~= 0 then 
        local st_s = note_layer_t.instrument_samplestoffs * note_layer_t.SAMPLELEN
        local end_s = note_layer_t.instrument_sampleendoffs * note_layer_t.SAMPLELEN
        note_layer_t.instrument_loopoffs_max = (end_s - st_s) / 30 
        note_layer_t.instrument_loopoffs_norm =  VF_lim(note_layer_t.instrument_loopoffs / note_layer_t.instrument_loopoffs_max )
        note_layer_t.instrument_attack_max = math.min(1,note_layer_t.SAMPLELEN/2) 
        note_layer_t.instrument_attack_norm = VF_lim(note_layer_t.instrument_attack / note_layer_t.instrument_attack_max   ) 
        note_layer_t.instrument_decay_max = math.min(1,note_layer_t.SAMPLELEN/15) 
        note_layer_t.instrument_decay_norm =  VF_lim(note_layer_t.instrument_decay / note_layer_t.instrument_decay_max  ) 
        note_layer_t.instrument_release_max = math.min(1,note_layer_t.SAMPLELEN/2) 
        note_layer_t.instrument_release_norm =  VF_lim(note_layer_t.instrument_release / note_layer_t.instrument_release_max )        
      end
      
      note_layer_t.instrument_maxvoicesID = 8
      note_layer_t.instrument_maxvoices = TrackFX_GetParamNormalized( track, instrument_pos, note_layer_t.instrument_maxvoicesID ) 
      note_layer_t.instrument_maxvoices_format = math.floor(note_layer_t.instrument_maxvoices*64)
      note_layer_t.instrument_tuneID = 15
      note_layer_t.instrument_tune = TrackFX_GetParamNormalized( track, instrument_pos, note_layer_t.instrument_tuneID ) 
      note_layer_t.instrument_tune_format = ({TrackFX_GetFormattedParamValue( track, instrument_pos, note_layer_t.instrument_tuneID )})[2]..'st'
      note_layer_t.instrument_filename = ({TrackFX_GetNamedConfigParm(  track, instrument_pos, 'FILE0') })[2]
      note_layer_t.instrument_noteoffID = 11
      note_layer_t.instrument_noteoff = TrackFX_GetParamNormalized( track, instrument_pos, note_layer_t.instrument_noteoffID ) 
      note_layer_t.instrument_noteoff_format = math.floor(note_layer_t.instrument_noteoff) 
      local filename_short = VF_GetShortSmplName(note_layer_t.instrument_filename) if filename_short and filename_short:match('(.*)%.[%a]+') then filename_short = filename_short:match('(.*)%.[%a]+') end 
      note_layer_t.instrument_filename_short = filename_short 
    end
    ---------------------------------------------------------------------   
    function DATA:CollectData_Children_InstrumentParams_3rdparty(note_layer_t, track,instrument_pos)
      if note_layer_t.ISRS5K==true then return end
      
      note_layer_t.instrument_enabled = TrackFX_GetEnabled( track, instrument_pos )
      local retval, fx_name = TrackFX_GetNamedConfigParm( track, instrument_pos, 'fx_name' )
      note_layer_t.instrument_fx_name = fx_name
      
      if not (DATA.plugin_mapping and DATA.plugin_mapping[fx_name] )then return end
      
      local supported_params = {
          'instrument_volID',
          'instrument_tuneID',
          'instrument_attackID',
          'instrument_decayID',
          'instrument_sustainID',
          'instrument_releaseID',
        }
      
      for pid=1, #supported_params do
        local param = supported_params[pid]
        local paramclear = param:match('(.*)ID')
        if DATA.plugin_mapping[fx_name][param] and paramclear then 
          note_layer_t[param] = DATA.plugin_mapping[fx_name][param]
          note_layer_t[paramclear] = TrackFX_GetParamNormalized( track, instrument_pos, note_layer_t[param] ) 
          note_layer_t[paramclear..'_format']=({TrackFX_GetFormattedParamValue( track, instrument_pos, note_layer_t[param] )})[2]
        end
      end
    end
    ---------------------------------------------------------------------   
    function DATA:CollectData_Children_InstrumentParams(note_layer_t, is_minor)
      local track = note_layer_t.tr_ptr
      local instrument_pos
      
      -- validate tr
      if is_minor ~= true then 
        local ret, tr, instrument_pos0 = VF_GetFXByGUID(note_layer_t.INSTR_FXGUID, track, DATA.proj)
        if not ret then 
          -- try to catch by instance name
          local instrument_pos0_1 = TrackFX_AddByName( track, 'rs5k', false, 0 )
          local instrument_pos0_2 = TrackFX_AddByName( track, 'reasamplo', false, 0 )
          if instrument_pos0_1 ~= -1 then 
            instrument_pos0 = instrument_pos0_1 
           elseif instrument_pos0_2 ~= -1 then 
            instrument_pos0 = instrument_pos0_2 
           else
            return 
          end
          local instrumentGUID = TrackFX_GetFXGUID( track, instrument_pos0 )
          DATA:WriteData_Child(track, {
            SET_instrFXGUID = instrumentGUID,
          }) 
        end 
        note_layer_t.instrument_pos=instrument_pos0
        instrument_pos=instrument_pos0
       else
        instrument_pos = note_layer_t.instrument_pos
      end 
      
      DATA:CollectData_Children_InstrumentParams_RS5k(note_layer_t, track, instrument_pos)
      DATA:CollectData_Children_InstrumentParams_3rdparty(note_layer_t, track, instrument_pos)
      
    end 
    ---------------------------------------------------------------------  
    function DATA:CollectData_Children_FXParams(note_layer_t)  
      
      if not note_layer_t then return end
      -- ReaEQ
      note_layer_t.fx_reaeq_isvalid = false
      if note_layer_t.FX_REAEQ_GUID then  
        local ret,tr, reaeqpos = VF_GetFXByGUID(note_layer_t.FX_REAEQ_GUID, note_layer_t.tr_ptr)
        if ret and reaeqpos and reaeqpos ~= -1 then    
          local track = note_layer_t.tr_ptr
          note_layer_t.fx_reaeq_isvalid = true
          note_layer_t.fx_reaeq_pos = reaeqpos
          note_layer_t.fx_reaeq_cut = TrackFX_GetParamNormalized( track, reaeqpos, 0 )
          note_layer_t.fx_reaeq_gain = TrackFX_GetParamNormalized( track, reaeqpos, 1)
          note_layer_t.fx_reaeq_bw = TrackFX_GetParamNormalized( track, reaeqpos, 2 )
          local fr= math.floor(({TrackFX_GetFormattedParamValue( track, reaeqpos, 0 )})[2])
          if fr>10000 then fr = (math.floor(fr/100)/10)..'k' end
          note_layer_t.fx_reaeq_cut_format = fr..'Hz'
          
          note_layer_t.fx_reaeq_gain_format = ({TrackFX_GetFormattedParamValue( track, reaeqpos, 1 )})[2]..'dB'
          note_layer_t.fx_reaeq_bw_format = ({TrackFX_GetFormattedParamValue( track, reaeqpos, 2 )})[2]
          note_layer_t.fx_reaeq_bandenabled = ({TrackFX_GetNamedConfigParm( track, reaeqpos, 'BANDENABLED0' )})[2]=='1'
          note_layer_t.fx_reaeq_bandtype = tonumber(({TrackFX_GetNamedConfigParm( track, reaeqpos, 'BANDTYPE0' )})[2])
          local reaeq_bandtype_format = ''
          if DATA.bandtypemap and DATA.bandtypemap[note_layer_t.fx_reaeq_bandtype] then reaeq_bandtype_format = DATA.bandtypemap[note_layer_t.fx_reaeq_bandtype] end
          note_layer_t.fx_reaeq_bandtype_format = reaeq_bandtype_format  
        end
      end
      
      -- WS
      note_layer_t.fx_ws_isvalid = false
      if note_layer_t.FX_WS_GUID then
        local ret,tr, wspos = VF_GetFXByGUID(note_layer_t.FX_WS_GUID, note_layer_t.tr_ptr)
        if ret and wspos and wspos ~= -1 then 
          local track = note_layer_t.tr_ptr
          note_layer_t.fx_ws_isvalid = true
          note_layer_t.fx_ws_pos = wspos
          note_layer_t.fx_ws_drive = TrackFX_GetParamNormalized( track, wspos, 0 )
          note_layer_t.fx_ws_drive_format = (math.floor(1000*note_layer_t.fx_ws_drive)/10)..'%'
        end
      end
      
      
      
    end 
    --------------------------------------------------------------------- 
    function DATA:CollectData_Children_ExtState(t) 
        local track = t.tr_ptr
      -- main plug data
        local ret, INSTR_FXGUID = GetSetMediaTrackInfo_String  ( track, 'P_EXT:MPLRS5KMAN_CHILD_INSTR_FXGUID', 0, false)   if INSTR_FXGUID == '' then INSTR_FXGUID = nil end 
        local ret, ISRS5K = GetSetMediaTrackInfo_String   ( track, 'P_EXT:MPLRS5KMAN_CHILD_ISRS5K', 0, false) ISRS5K = (tonumber(ISRS5K) or 0)==1  
        t.INSTR_FXGUID=     INSTR_FXGUID
        t.ISRS5K=           ISRS5K
      
      -- rs5k specific 
        local ret, SAMPLELEN = GetSetMediaTrackInfo_String( track, 'P_EXT:MPLRS5KMAN_SAMPLELEN', '', false)  SAMPLELEN = tonumber(SAMPLELEN) or 0 
        t.SAMPLELEN = SAMPLELEN
        local ret, SAMPLEBPM = GetSetMediaTrackInfo_String( track, 'P_EXT:MPLRS5KMAN_SAMPLEBPM', '', false)  SAMPLEBPM = tonumber(SAMPLEBPM) or 0 
        t.SAMPLEBPM = SAMPLEBPM   
        local ret, LUFSNORM = GetSetMediaTrackInfo_String( track, 'P_EXT:MPLRS5KMAN_LUFSNORM', '', false)
        t.LUFSNORM = LUFSNORM   
        
         
      --[[  3rd party ADSR + tune map
        local ret, INSTR_PARAM_CACHE = GetSetMediaTrackInfo_String( track, 'P_EXT:MPLRS5KMAN_CHILD_INSTR_PARAM_CACHE', '', false) INSTR_PARAM_CACHE = tonumber(INSTR_PARAM_CACHE) or nil
        local ret, INSTR_PARAM_VOL = GetSetMediaTrackInfo_String( track, 'P_EXT:MPLRS5KMAN_CHILD_INSTR_PARAM_VOL', '', false) INSTR_PARAM_VOL = tonumber(INSTR_PARAM_VOL) or nil
        local ret, INSTR_PARAM_TUNE = GetSetMediaTrackInfo_String( track, 'P_EXT:MPLRS5KMAN_CHILD_INSTR_PARAM_TUNE', '', false) INSTR_PARAM_TUNE = tonumber(INSTR_PARAM_TUNE) or nil
        local ret, INSTR_PARAM_ATT = GetSetMediaTrackInfo_String( track, 'P_EXT:MPLRS5KMAN_CHILD_INSTR_PARAM_ATT', '', false) INSTR_PARAM_ATT = tonumber(INSTR_PARAM_ATT) or nil
        local ret, INSTR_PARAM_DEC = GetSetMediaTrackInfo_String( track, 'P_EXT:MPLRS5KMAN_CHILD_INSTR_PARAM_DEC', '', false) INSTR_PARAM_DEC = tonumber(INSTR_PARAM_DEC) or nil
        local ret, INSTR_PARAM_SUS = GetSetMediaTrackInfo_String( track, 'P_EXT:MPLRS5KMAN_CHILD_INSTR_PARAM_SUS', '', false) INSTR_PARAM_SUS = tonumber(INSTR_PARAM_SUS) or nil
        local ret, INSTR_PARAM_REL = GetSetMediaTrackInfo_String( track, 'P_EXT:MPLRS5KMAN_CHILD_INSTR_PARAM_REL', '', false) INSTR_PARAM_REL = tonumber(INSTR_PARAM_REL) or nil 
        t.INSTR_PARAM_CACHE=INSTR_PARAM_CACHE
        t.INSTR_PARAM_VOL=INSTR_PARAM_VOL
        t.INSTR_PARAM_TUNE=INSTR_PARAM_TUNE
        t.INSTR_PARAM_ATT=INSTR_PARAM_ATT
        t.INSTR_PARAM_DEC=INSTR_PARAM_DEC
        t.INSTR_PARAM_SUS=INSTR_PARAM_SUS
        t.INSTR_PARAM_REL=INSTR_PARAM_REL]]
        
      -- midi filter
        local ret, MIDIFILTGUID = GetSetMediaTrackInfo_String  ( track, 'P_EXT:MPLRS5KMAN_CHILD_MIDIFILTGUID', 0, false)  if MIDIFILTGUID == '' then MIDIFILTGUID = nil end
        t.MIDIFILTGUID=MIDIFILTGUID
      
      -- reaeq// validate
        local ret, FX_REAEQ_GUID = GetSetMediaTrackInfo_String( track, 'P_EXT:MPLRS5KMAN_CHILD_FX_REAEQ_GUID', '', false) if FX_REAEQ_GUID == '' then FX_REAEQ_GUID = nil end 
        if FX_REAEQ_GUID then 
          local ret, tr, eqpos = VF_GetFXByGUID(FX_REAEQ_GUID:gsub('[%{%}]',''),track, DATA.proj) 
          if not eqpos then FX_REAEQ_GUID=nil end
        end
        t.FX_REAEQ_GUID = FX_REAEQ_GUID
      
      -- waveshaper // validate
        local ret, FX_WS_GUID = GetSetMediaTrackInfo_String( track, 'P_EXT:MPLRS5KMAN_CHILD_FX_WS_GUID', '', false) if FX_WS_GUID == '' then FX_WS_GUID = nil end 
        if FX_WS_GUID then 
          local ret, tr, wspos = VF_GetFXByGUID(FX_WS_GUID:gsub('[%{%}]',''),track, DATA.proj) 
          if not wspos then FX_WS_GUID=nil end
        end
        t.FX_WS_GUID=FX_WS_GUID
      
      -- macro
        local _, MACRO_GUID = GetSetMediaTrackInfo_String ( track, 'P_EXT:MPLRS5KMAN_MACRO_GUID', 0, false) if MACRO_GUID == '' then MACRO_GUID = nil end 
        local  ret, tr, MACRO_pos
        if MACRO_GUID then ret, tr, MACRO_pos = VF_GetFXByGUID(MACRO_GUID:gsub('[%{%}]',''),track, DATA.proj) end
        if not MACRO_pos then MACRO_GUID = nil  end 
        t.MACRO_GUID = MACRO_GUID 
        t.MACRO_pos = MACRO_pos
      
      -- list samples in path or database
        local ret, SPLLISTDB = GetSetMediaTrackInfo_String( track, 'P_EXT:MPLRS5KMAN_CHILD_SPLLISTDB', '', false) SPLLISTDB = tonumber(SPLLISTDB) or 0
        t.SET_useDB=SPLLISTDB
        local ret, SET_useDB_lastID = GetSetMediaTrackInfo_String( track, 'P_EXT:MPLRS5KMAN_CHILD_SPLLISTDB_ID', '', false) SET_useDB_lastID = tonumber(SET_useDB_lastID) or 0
        t.SET_useDB_lastID = SET_useDB_lastID
        local ret, SPLLISTDB_name = GetSetMediaTrackInfo_String( track, 'P_EXT:MPLRS5KMAN_CHILD_SPLLISTDB_NAME', '', false) if SPLLISTDB_name == '' then SPLLISTDB_name = nil end 
        t.SET_useDB_name=SPLLISTDB_name
        
        
    end
    -------------------------------------------------------------------------------- 
    function DATA:CollectData_Children_MIDIbus(track)
      local ret, isMIDIbus = GetSetMediaTrackInfo_String ( track, 'P_EXT:MPLRS5KMAN_MIDIBUS', 0, false)    
      isMIDIbus = (tonumber(isMIDIbus) or 0)==1   
      if not (ret and isMIDIbus == true) then return end
      local IP_TRACKNUMBER_0based = GetMediaTrackInfo_Value( track, 'IP_TRACKNUMBER')-1
      local I_FOLDERDEPTH = GetMediaTrackInfo_Value( track, 'I_FOLDERDEPTH')
      local I_RECMON = GetMediaTrackInfo_Value( track, 'I_RECMON')
      
      
      DATA.MIDIbus = {  tr_ptr = track, 
                        IP_TRACKNUMBER_0based = IP_TRACKNUMBER_0based,
                        valid = true,
                        I_FOLDERDEPTH = I_FOLDERDEPTH,
                        I_RECMON = I_RECMON,
                    } 
       
      return true
    end
    -----------------------------------------------------------------------------  
    function DATA:Sampler_StuffNoteOn(note, vel, is_off) 
     if not note then return end
     
     
      if not is_off then 
        StuffMIDIMessage( 0, 0x90, note, vel or EXT.CONF_default_velocity ) 
       else
        StuffMIDIMessage( 0, 0x80, note, 0 ) 
      end
    end
   ------------------------------------------------------------------------------------------ 
   function DATA:Layout_Init(ID, fill_unexistent)  
     local defaults = {
         cell_cnt_max=64,
         startnote = 36,
         blockX = 4,
         toptobottom = 0,
         row_cnt = 8,
         col_cnt = 8,
         
       }
       
     if not fill_unexistent then 
       DATA.custom_layouts[ID] = CopyTable(defaults)
      else
       if not DATA.custom_layouts[ID] then DATA.custom_layouts[ID] = {} end
       for key in pairs(defaults) do
         if not DATA.custom_layouts[ID][key] then DATA.custom_layouts[ID][key] = defaults[key] end
       end
     end
     
   end
    ------------------------------------------------------------------------------------------ 
    function DATA:CollectDataInit_LoadCustomLayouts()  
      local s_b64 = EXT.UI_drracklayout_custommapB64
      DATA.custom_layouts = table.loadstring(s_b64) or {}
      local ID = EXT.UI_drracklayout_customID
      if not DATA.custom_layouts[ID]  then DATA:Layout_Init(ID) end
      DATA:Layout_Init(ID, true)
      
    end
    ------------------------------------------------------------------------------------------ 
    function DATA:Layout_SaveCustomLayouts()  
      EXT.UI_drracklayout_custommapB64 = table.savestring(DATA.custom_layouts ) or ""
      EXT:save()
    end
    ---------------------------------------------------------------------  
    function DATA:WriteData_Parent() 
      if not (DATA.parent_track and DATA.parent_track.ext and DATA.parent_track.valid == true) then return end
      GetSetMediaTrackInfo_String( DATA.parent_track.ptr, 'P_EXT:MPLRS5KMAN_VERSION', DATA.version, true)
      
      -- v4.14+
      if DATA.parent_track.trGUID  then  
        local ret, GUIDINTERNAL = GetSetMediaTrackInfo_String ( DATA.parent_track.ptr, 'P_EXT:MPLRS5KMAN_GUIDINTERNAL', '', false) 
        if not ret then GetSetMediaTrackInfo_String ( DATA.parent_track.ptr, 'P_EXT:MPLRS5KMAN_GUIDINTERNAL', DATA.parent_track.trGUID, true) end
      end
      
      -- v4 separate stuff from chunk
      if DATA.parent_track.ext then 
        
        if DATA.parent_track.ext.PARENT_DRRACKSHIFT  then GetSetMediaTrackInfo_String ( DATA.parent_track.ptr, 'P_EXT:MPLRS5KMAN_DRRACKSHIFT', DATA.parent_track.ext.PARENT_DRRACKSHIFT or '', true) end
        if DATA.parent_track.ext.PARENT_LASTACTIVENOTE  then GetSetMediaTrackInfo_String ( DATA.parent_track.ptr, 'P_EXT:MPLRS5KMAN_LASTACTIVENOTE', DATA.parent_track.ext.PARENT_LASTACTIVENOTE or '', true) end
        if DATA.parent_track.ext.PARENT_LASTACTIVENOTE_LAYER  then GetSetMediaTrackInfo_String ( DATA.parent_track.ptr, 'P_EXT:MPLRS5KMAN_LASTACTIVENOTE_LAYER', DATA.parent_track.ext.PARENT_LASTACTIVENOTE_LAYER or '', true) end
        if DATA.parent_track.ext.PARENT_MACROCNT  then GetSetMediaTrackInfo_String ( DATA.parent_track.ptr, 'P_EXT:MPLRS5KMAN_MACROCNT', DATA.parent_track.ext.PARENT_MACROCNT or '', true) end
        if DATA.parent_track.ext.PARENT_LASTACTIVEMACRO  then GetSetMediaTrackInfo_String ( DATA.parent_track.ptr, 'P_EXT:MPLRS5KMAN_LASTACTIVEMACRO', DATA.parent_track.ext.PARENT_LASTACTIVEMACRO or '', true) end
        if DATA.parent_track.ext.PARENT_MIDIFLAGS  then GetSetMediaTrackInfo_String ( DATA.parent_track.ptr, 'P_EXT:MPLRS5KMAN_MIDIFLAGS', DATA.parent_track.ext.PARENT_MIDIFLAGS or '', true) end
        if DATA.parent_track.ext.PARENT_MACRO_GUID  then GetSetMediaTrackInfo_String ( DATA.parent_track.ptr, 'P_EXT:MPLRS5KMAN_MACRO_GUID', DATA.parent_track.ext.PARENT_MACRO_GUID or '', true) end
        if DATA.parent_track.ext.PARENT_MACROEXT    then
          local outstr = table.savestring(DATA.parent_track.ext.PARENT_MACROEXT)
          GetSetMediaTrackInfo_String ( DATA.parent_track.ptr, 'P_EXT:MPLRS5KMAN_MACROEXT_B64', VF_encBase64(outstr), true)
        end 
        if DATA.parent_track.padcustomnames_overrides then 
          --DATA.parent_track.padcustomnames_overrides[selected_pad] = buf
          local outstr = ''
          for i = 0, 127 do outstr=outstr..i..'='..'"'..(DATA.parent_track.padcustomnames_overrides[i] or '')..'" ' end
          local PARENT_PADNAMES_OVERRIDES_b64 = VF_encBase64(outstr)
          GetSetMediaTrackInfo_String ( DATA.parent_track.ptr, 'P_EXT:MPLRS5KMAN_PARENT_PADNAMES_OVERRIDES_b64', PARENT_PADNAMES_OVERRIDES_b64, true) 
        end
      end 
      
      -- clear string
      GetSetMediaTrackInfo_String( DATA.parent_track.ptr, 'P_EXT:MPLRS5KMAN', '', true) 
    end
    ---------------------------------------------------------------------
    function DATA:WriteData_Child(tr, t) 
      if not ValidatePtr2(DATA.proj,tr,'MediaTrack*') then return end
      GetSetMediaTrackInfo_String( tr, 'P_EXT:MPLRS5KMAN_VERSION', DATA.version, true)
      
      -- v4.14+
      if DATA.parent_track.trGUID  then  
        local ret, GUIDINTERNAL = GetSetMediaTrackInfo_String ( DATA.parent_track.ptr, 'P_EXT:MPLRS5KMAN_GUIDINTERNAL', '', false) 
        if not ret then GetSetMediaTrackInfo_String ( DATA.parent_track.ptr, 'P_EXT:MPLRS5KMAN_GUIDINTERNAL', DATA.parent_track.trGUID, true) end
      end
      
      -- meta FX
        if t.MACRO_GUID then GetSetMediaTrackInfo_String( tr, 'P_EXT:MPLRS5KMAN_MACRO_GUID', t.MACRO_GUID, true) end
        if t.MIDIFILT_GUID then GetSetMediaTrackInfo_String( tr, 'P_EXT:MPLRS5KMAN_CHILD_MIDIFILTGUID', t.MIDIFILT_GUID, true) end 
        if t.FX_REAEQ_GUID then GetSetMediaTrackInfo_String( tr, 'P_EXT:MPLRS5KMAN_CHILD_FX_REAEQ_GUID', t.FX_REAEQ_GUID, true) end      
        if t.FX_WS_GUID then GetSetMediaTrackInfo_String( tr, 'P_EXT:MPLRS5KMAN_CHILD_FX_WS_GUID', t.FX_WS_GUID, true) end      
        
      -- types
        if t.SET_MarkParentForChild then GetSetMediaTrackInfo_String( tr, 'P_EXT:MPLRS5KMAN_CHILD_PARENTGUID', t.SET_MarkParentForChild, true) end 
        if t.SET_MarkType_RegularChild then 
          GetSetMediaTrackInfo_String( tr, 'P_EXT:MPLRS5KMAN_TYPE_REGCHILD', 1, true)
          GetSetMediaTrackInfo_String( tr, 'P_EXT:MPLRS5KMAN_TYPE_DEVICECHILD', '', true) 
         elseif t.SET_MarkType_Device then 
          GetSetMediaTrackInfo_String( tr, 'P_EXT:MPLRS5KMAN_TYPE_DEVICE', 1, true)
          GetSetMediaTrackInfo_String( tr, 'P_EXT:MPLRS5KMAN_TYPE_REGCHILD', '', true)
         elseif t.SET_MarkType_MIDIbus then 
          GetSetMediaTrackInfo_String( tr, 'P_EXT:MPLRS5KMAN_MIDIBUS', 1, true)
         elseif t.SET_MarkType_DeviceChild_deviceGUID then 
          --GetSetMediaTrackInfo_String( tr, 'P_EXT:MPLRS5KMAN_TYPE_DEVICECHILD', 1, true) 
          GetSetMediaTrackInfo_String( tr, 'P_EXT:MPLRS5KMAN_TYPE_REGCHILD', '', true)
          GetSetMediaTrackInfo_String( tr, 'P_EXT:MPLRS5KMAN_TYPE_DEVICECHILD_PARENTDEVICEGUID', t.SET_MarkType_DeviceChild_deviceGUID, true) 
         elseif t.SET_MarkType_TYPE_DEVICE_AUTORANGE then 
          GetSetMediaTrackInfo_String( tr, 'P_EXT:MPLRS5KMAN_TYPE_DEVICE_AUTORANGE', t.SET_MarkType_TYPE_DEVICE_AUTORANGE, true)         
        end 
        
      -- rs5k manager data
        if t.SET_noteID then GetSetMediaTrackInfo_String( tr, 'P_EXT:MPLRS5KMAN_NOTE', t.SET_noteID, true) end 
        if t.SET_instrFXGUID then GetSetMediaTrackInfo_String( tr, 'P_EXT:MPLRS5KMAN_CHILD_INSTR_FXGUID', t.SET_instrFXGUID, true) end 
        if t.SET_isrs5k then  GetSetMediaTrackInfo_String( tr, 'P_EXT:MPLRS5KMAN_CHILD_ISRS5K', 1, true) end      
        if t.SET_useDB then GetSetMediaTrackInfo_String( tr, 'P_EXT:MPLRS5KMAN_CHILD_SPLLISTDB', t.SET_useDB, true) end  
        if t.SET_useDB_name then GetSetMediaTrackInfo_String( tr, 'P_EXT:MPLRS5KMAN_CHILD_SPLLISTDB_NAME', t.SET_useDB_name, true) end  
        if t.SET_useDB_lastID then GetSetMediaTrackInfo_String( tr, 'P_EXT:MPLRS5KMAN_CHILD_SPLLISTDB_ID', t.SET_useDB_lastID, true) end  
        if t.SET_SAMPLELEN then GetSetMediaTrackInfo_String( tr, 'P_EXT:MPLRS5KMAN_SAMPLELEN', t.SET_SAMPLELEN, true) end  
        if t.SET_SAMPLEBPM then GetSetMediaTrackInfo_String( tr, 'P_EXT:MPLRS5KMAN_SAMPLEBPM', t.SET_SAMPLEBPM, true) end  
        if t.SET_LUFSNORM then GetSetMediaTrackInfo_String( tr, 'P_EXT:MPLRS5KMAN_LUFSNORM', t.SET_LUFSNORM, true) end  
        if t.SET_SYSEXMOD then GetSetMediaTrackInfo_String( tr, 'P_EXT:MPLRS5KMAN_SYSEXMOD', t.SET_SYSEXMOD, true) end  
        
        --[[if t.INSTR_PARAM_CACHE then GetSetMediaTrackInfo_String( tr, 'P_EXT:MPLRS5KMAN_CHILD_INSTR_PARAM_CACHE', t.INSTR_PARAM_CACHE, true) end
        if t.INSTR_PARAM_VOL then GetSetMediaTrackInfo_String( tr, 'P_EXT:MPLRS5KMAN_CHILD_INSTR_PARAM_VOL', t.INSTR_PARAM_VOL, true) end
        if t.INSTR_PARAM_TUNE then GetSetMediaTrackInfo_String( tr, 'P_EXT:MPLRS5KMAN_CHILD_INSTR_PARAM_TUNE', t.INSTR_PARAM_TUNE, true) end
        if t.INSTR_PARAM_ATT then GetSetMediaTrackInfo_String( tr, 'P_EXT:MPLRS5KMAN_CHILD_INSTR_PARAM_ATT', t.INSTR_PARAM_ATT, true) end
        if t.INSTR_PARAM_DEC then GetSetMediaTrackInfo_String( tr, 'P_EXT:MPLRS5KMAN_CHILD_INSTR_PARAM_DEC', t.INSTR_PARAM_DEC, true) end
        if t.INSTR_PARAM_SUS then GetSetMediaTrackInfo_String( tr, 'P_EXT:MPLRS5KMAN_CHILD_INSTR_PARAM_SUS', t.INSTR_PARAM_SUS, true) end
        if t.INSTR_PARAM_REL then GetSetMediaTrackInfo_String( tr, 'P_EXT:MPLRS5KMAN_CHILD_INSTR_PARAM_REL', t.INSTR_PARAM_REL, true) end]]
        
      
    end
    ---------------------------------------------------------------------  
    function DATA:Drop_Pad_Swap(src_pad,dest_pad)  
      -- set dest device/devicechidren
      if DATA.children[dest_pad] then   
        DATA:WriteData_Child(DATA.children[dest_pad].tr_ptr, {SET_noteID = src_pad})  
        if DATA.children[dest_pad].layers then
          for layer = 1, #DATA.children[dest_pad].layers do
            DATA:WriteData_Child(DATA.children[dest_pad].layers[layer].tr_ptr, {SET_noteID = src_pad})  
            DATA:DropSample_ExportToRS5kSetNoteRange(DATA.children[dest_pad].layers[layer], src_pad) 
          end
        end 
        local filename  if DATA.children[dest_pad] and DATA.children[dest_pad].layers and DATA.children[dest_pad].layers[1] and DATA.children[dest_pad].layers[1].instrument_filename then filename = DATA.children[dest_pad].layers[1].instrument_filename end
        DATA:DropSample_RenameTrack(DATA.children[dest_pad].tr_ptr,src_pad,filename) 
      end
      
      -- set src device/devicechidren
      if DATA.children[src_pad] then   
        DATA:WriteData_Child(DATA.children[src_pad].tr_ptr, {SET_noteID = dest_pad})  
        if DATA.children[src_pad].layers then
          for layer = 1, #DATA.children[src_pad].layers do
            DATA:WriteData_Child(DATA.children[src_pad].layers[layer].tr_ptr, {SET_noteID = dest_pad})  
            DATA:DropSample_ExportToRS5kSetNoteRange(DATA.children[src_pad].layers[layer], dest_pad)
          end
        end
        local filename  if DATA.children[src_pad] and DATA.children[src_pad].layers and DATA.children[src_pad].layers[1] and DATA.children[src_pad].layers[1].instrument_filename then filename = DATA.children[src_pad].layers[1].instrument_filename end
        DATA:DropSample_RenameTrack(DATA.children[src_pad].tr_ptr,dest_pad,filename) 
      end 
      
      DATA.peakscache[src_pad] = nil
      DATA.peakscache[dest_pad] = nil
      DATA.upd = true
      DATA.autoreposition = true
    end
    ---------------------------------------------------------------------  
    function DATA:Drop_Pad(src_pad0,dest_pad0)
      if not src_pad0 and dest_pad0 then return end
      src_pad,dest_pad = tonumber(src_pad0),tonumber(dest_pad0)
      if not src_pad and dest_pad then return end
      
      if not DATA.paddrop_mode then 
        DATA:Drop_Pad_Swap(src_pad,dest_pad)  
       elseif DATA.paddrop_mode == 1 
        and DATA.children[src_pad] 
        and not DATA.children[dest_pad] 
        and DATA.children[src_pad].layers
        and #DATA.children[src_pad].layers==1
        and DATA.children[src_pad].layers[1] 
        and DATA.children[src_pad].layers[1].instrument_filename  then -- copy stuff to dest pad if it is free
        local filename = DATA.children[src_pad].layers[1].instrument_filename
        local drop_data = {
          layer = 1, 
          EOFFS = DATA.children[src_pad].layers[1].instrument_sampleendoffs,
          SOFFS = DATA.children[src_pad].layers[1].instrument_samplestoffs,
        }
        DATA:DropSample(filename, dest_pad0, drop_data)
        DATA.paddrop_mode = nil
      end
      DATA:_Seq_RefreshStepSeq()
    end
    ---------------------------------------------------------------------  
    function DATA:Validate_MIDIbus_AND_ParentFolder() -- set parent as folder if need, since it is a first validation check in DATA:DropSample
      if not (DATA.parent_track and DATA.parent_track.valid == true) then return end
      if (DATA.MIDIbus and DATA.MIDIbus.valid == true) then return end
      
      -- make sure parent extstate is set
      if not ( DATA.parent_track and DATA.parent_track.ext_load == true) then 
        DATA:WriteData_Parent() 
      end
      
      -- insert new
      InsertTrackAtIndex( DATA.parent_track.IP_TRACKNUMBER_0based+1, false )
      local MIDI_tr = GetTrack(DATA.proj, DATA.parent_track.IP_TRACKNUMBER_0based+1)
      
      -- set params
      GetSetMediaTrackInfo_String( MIDI_tr, 'P_NAME', 'MIDI bus', 1 )
      SetMediaTrackInfo_Value( MIDI_tr, 'I_RECMON', 1 )
      SetMediaTrackInfo_Value( MIDI_tr, 'I_RECARM', 1 )
      SetMediaTrackInfo_Value( MIDI_tr, 'I_RECMODE', 0 ) -- record MIDI out
      local channel,physical_input = EXT.CONF_midichannel, EXT.CONF_midiinput
      SetMediaTrackInfo_Value( MIDI_tr, 'I_RECINPUT', 4096 + channel + (physical_input<<5)) -- set input to all MIDI
      if EXT.CONF_midioutput ~= -1 then SetMediaTrackInfo_Value( MIDI_tr, 'I_MIDIHWOUT', EXT.CONF_midioutput<<5) end -- MIDI hardware output
      
      
      -- make parent track folder
      if DATA.parent_track.I_FOLDERDEPTH ~= 1 then
        SetMediaTrackInfo_Value( DATA.parent_track.ptr, 'I_FOLDERDEPTH',1 )
        SetMediaTrackInfo_Value( MIDI_tr,               'I_FOLDERDEPTH',DATA.parent_track.I_FOLDERDEPTH-1 ) 
      end 
      
      DATA:WriteData_Child(MIDI_tr, {
        SET_MarkParentForChild = DATA.parent_track.trGUID,
        SET_MarkType_MIDIbus = true,
        })  
        
      -- refresh last track in tree if parent track was at initial state
      if DATA.parent_track.IP_TRACKNUMBER_0basedlast == DATA.parent_track.IP_TRACKNUMBER_0based then
        DATA.parent_track.IP_TRACKNUMBER_0basedlast = DATA.parent_track.IP_TRACKNUMBER_0based +1
      end
      
      --[[ add midi note filter
      local fxname = 'JS: midi/midi_note_filter'
      local filtID = TrackFX_AddByName( MIDI_tr, fxname, true, -1 )
      if filtID&0xF000000~=0x1000000 then filtID = filtID|0x1000000  end
      TrackFX_SetOpen( MIDI_tr, filtID, false )
      TrackFX_SetParam( MIDI_tr, filtID, 0, 0 )
      TrackFX_SetParam( MIDI_tr, filtID, 1, 127 )
      TrackFX_SetParam( MIDI_tr, filtID, 2, 0 )]]
      
      DATA:CollectData_Children_MIDIbus(MIDI_tr)
      DATA.upd = true
    end
    -----------------------------------------------------------------------  
    function DATA:DropSample_ExportToRS5k_CopySrc(filename)
      local prpath = reaper.GetProjectPathEx( 0 )
      local filename_path = VF_GetParentFolder(filename)
      local filename_name = VF_GetShortSmplName(filename)
      if prpath and filename_path and filename_name then
        prpath = prpath..'/'..EXT.CONF_onadd_copysubfoldname..'/'
        
        RecursiveCreateDirectory( prpath, 0 )
        local src = filename
        local dest = prpath..filename_name
        local fsrc = io.open(src, 'rb')
        if fsrc then
          content = fsrc:read('a') 
          fsrc:close()
          fdest = io.open(dest, 'wb')
          if fdest then 
            fdest:write(content)
            fdest:close()
            return dest
          end
        end
      end
      return filename
    end
    --------------------------------------------------------------------- 
    function DATA:DropSample_ExportToRS5kSetNoteRange(note_layer_t, note) 
      local oldnote_t 
      local old_note = note_layer_t.noteID
      if old_note and DATA.children[old_note] then oldnote_t = DATA.children[old_note] end
      
      
      local tr = note_layer_t.tr_ptr
      local instrument_pos = note_layer_t.instrument_pos
      local midifilt_pos = note_layer_t.midifilt_pos
      if not note then return end
      if not midifilt_pos  then 
        if not (oldnote_t and oldnote_t.SYSEXMOD == true) then
          TrackFX_SetParamNormalized( tr, instrument_pos, 3, note/127 ) -- note range start
          TrackFX_SetParamNormalized( tr, instrument_pos, 4, note/127 ) -- note range end
        end
       else 
        TrackFX_SetParamNormalized( tr, midifilt_pos, 0, note/128)
        TrackFX_SetParamNormalized( tr, midifilt_pos, 1, note/128)
      end
      
      if oldnote_t and oldnote_t.SYSEXHANDLER_ID then 
        TrackFX_SetParam( oldnote_t.tr_ptr, oldnote_t.SYSEXHANDLER_ID, 0, note ) -- set new note
      end
    end
    --------------------------------------------------------------------- 
    function DATA:DropSample_AddNewTrack(deviceparent, note, SET_MarkType_DeviceChild_deviceGUID) 
      -- define position
      local ID = DATA.parent_track.IP_TRACKNUMBER_0based+1 -- after parent
      
      -- add / handle tree
      InsertTrackAtIndex( ID, false )
      local new_tr = GetTrack(DATA.proj, ID)  
      
      -- add custom template
      if deviceparent ~= true and EXT.CONF_onadd_customtemplate ~= '' then 
        local f = io.open(EXT.CONF_onadd_customtemplate,'rb')
        local content
        if f then 
          content = f:read('a')
          f:close()
        end
        local GUID = GetTrackGUID( new_tr )
        content = content:gsub('TRACK ', 'TRACK '..GUID)
        SetTrackStateChunk( new_tr, content, false )
        TrackFX_Show( new_tr, 0, 0 ) -- hide chain
        for fxid = 1,  TrackFX_GetCount( new_tr ) do TrackFX_Show( new_tr,fxid-1, 2 ) end-- hide chain
      end  
      
      -- set height
      if EXT.CONF_onadd_newchild_trackheight > 0 then 
        SetMediaTrackInfo_Value( new_tr, 'I_HEIGHTOVERRIDE', EXT.CONF_onadd_newchild_trackheight ) 
        if EXT.CONF_onadd_newchild_trackheight_lock == 1 then   
          SetMediaTrackInfo_Value( new_tr, 'B_HEIGHTLOCK', 1)   
        end
      end 
      
      -- print timestamp
      GetSetMediaTrackInfo_String(  new_tr, 'P_EXT:MPLRS5KMAN_TSADD', os.time(), true) 
      if EXT.CONF_onadd_takeparentcolor == 1 then SetMediaTrackInfo_Value( new_tr, 'I_CUSTOMCOLOR',DATA.parent_track.I_CUSTOMCOLOR ) end
      
      -- auto color
      if EXT.CONF_autocol == 1 and DATA.padautocolors and DATA.padautocolors[note] then 
        local r,g,b = 
          (DATA.padautocolors[note]>>24)&0xFF, 
          (DATA.padautocolors[note]>>16)&0xFF, 
          (DATA.padautocolors[note]>>8)&0xFF
        local color = ColorToNative(r,g,b)|0x1000000
        SetMediaTrackInfo_Value( new_tr, 'I_CUSTOMCOLOR', color )
      end
      
      -- move in structure
      DATA:DropSample_AddNewTrack_Move(new_tr, deviceparent, note, SET_MarkType_DeviceChild_deviceGUID)
      
      return new_tr
    end 
    --------------------------------------------------------------------- 
    function DATA:DropSample_AddNewTrack_Move(new_tr, deviceparent, note, SET_MarkType_DeviceChild_deviceGUID)
      local exact_note 
      local next_note 
      for note0 in spairs(DATA.children) do
        if note0 == note then exact_note = true end
        if note0 > note then next_note = note0 break end
      end    
      
      -- new regular child
        if deviceparent~=true and not SET_MarkType_DeviceChild_deviceGUID then
          local beforeTrackIdx
          if next_note then
            beforeTrackIdx = DATA.children[next_note].IP_TRACKNUMBER_0based
           else
            if (DATA.MIDIbus and DATA.MIDIbus.IP_TRACKNUMBER_0based) then
              beforeTrackIdx = DATA.MIDIbus.IP_TRACKNUMBER_0based+1 -- goes before midi bus
             else
              beforeTrackIdx = DATA.parent_track.IP_TRACKNUMBER_0based+1 -- goes after parent
            end
          end
          
          if EXT.CONF_onadd_ordering == 0 then -- 0 sorted by note 1 at the top 2 at the bottom
            DATA:Auto_Reposition_TrackGetSelection()
            SetOnlyTrackSelected( new_tr )
            ReorderSelectedTracks( beforeTrackIdx, 0 )
            DATA:Auto_Reposition_TrackRestoreSelection()
           elseif EXT.CONF_onadd_ordering == 1 then
            -- after parent
           elseif EXT.CONF_onadd_ordering == 2 then
            
            local last_tr = GetTrack(DATA.proj, DATA.parent_track.IP_TRACKNUMBER_0basedlast+1)
            if last_tr then
              local last_trdepth = GetMediaTrackInfo_Value( last_tr, 'I_FOLDERDEPTH' ) 
              DATA:Auto_Reposition_TrackGetSelection()
              SetOnlyTrackSelected( new_tr ) 
              beforeTrackIdx = DATA.parent_track.IP_TRACKNUMBER_0basedlast+2 -- goes after last track
              DATA.parent_track.IP_TRACKNUMBER_0basedlast = DATA.parent_track.IP_TRACKNUMBER_0basedlast + 1 -- MUST refresh otherwise break structure
              ReorderSelectedTracks( beforeTrackIdx, 0 )
              if last_trdepth == -1 then -- last track was 2nd level
                SetMediaTrackInfo_Value( last_tr, 'I_FOLDERDEPTH', 0)-- set midi bus to normal child
                SetMediaTrackInfo_Value( new_tr, 'I_FOLDERDEPTH', -1 )-- set new_tr to enclose parent
               else
                SetMediaTrackInfo_Value( last_tr, 'I_FOLDERDEPTH', last_trdepth + 1 ) -- set midi bus to normal child
                SetMediaTrackInfo_Value( new_tr, 'I_FOLDERDEPTH', last_trdepth )-- set new_tr to enclose parent
              end
              DATA:Auto_Reposition_TrackRestoreSelection()
            end
            
          end
        end
      
      -- new layer
        if deviceparent~=true and SET_MarkType_DeviceChild_deviceGUID and exact_note then
          local beforeTrackIdx = DATA.children[note].IP_TRACKNUMBER_0based +1 -- goes after parent 
          DATA:Auto_Reposition_TrackGetSelection()
          SetOnlyTrackSelected( new_tr )
          ReorderSelectedTracks( beforeTrackIdx, 0 )--make sure parent is folder
          DATA:Auto_Reposition_TrackRestoreSelection()
          DATA.upd2.updatedevicevelocityrange = note
        end
     
      -- new device
        if deviceparent==true then
          if exact_note then -- child exist
            SetOnlyTrackSelected( new_tr )
            local beforeTrackIdx = DATA.children[note].IP_TRACKNUMBER_0based -- before child
            ReorderSelectedTracks( beforeTrackIdx, 0 )
            local child_tr = GetTrack(-1,DATA.children[note].IP_TRACKNUMBER_0based)
            SetMediaTrackInfo_Value( new_tr, 'I_FOLDERDEPTH', 1 ) -- enclose new device
            local I_FOLDERDEPTH = GetMediaTrackInfo_Value( child_tr, 'I_FOLDERDEPTH') -- enclose new device
            SetMediaTrackInfo_Value( child_tr, 'I_FOLDERDEPTH', I_FOLDERDEPTH-1 ) -- enclose new device
            return
          end
          
          local beforeTrackIdx
          if (DATA.MIDIbus and DATA.MIDIbus.IP_TRACKNUMBER_0based) then
            beforeTrackIdx = DATA.MIDIbus.IP_TRACKNUMBER_0based -- before midi bus
           else
            beforeTrackIdx = DATA.parent_track.IP_TRACKNUMBER_0based+1 -- after parent
          end
          if next_note then beforeTrackIdx = DATA.children[next_note].IP_TRACKNUMBER_0based end -- before next note if any
          DATA:Auto_Reposition_TrackGetSelection()
          SetOnlyTrackSelected( new_tr )
          ReorderSelectedTracks( beforeTrackIdx, 0 )
          DATA:Auto_Reposition_TrackRestoreSelection()
        end
        
    end
    ---------------------------------------------------------------------  
    function DATA:DropSample_ValidateTrack(note, layer)
      local track 
      
      -- track exists
      if  
        layer and 
        DATA.children[note] and 
        DATA.children[note].layers and 
        DATA.children[note].layers[layer] and 
        DATA.children[note].layers[layer].tr_ptr and 
        ValidatePtr2(DATA.proj, DATA.children[note].layers[layer].tr_ptr, 'MediaTrack*') then 
       return DATA.children[note].layers[layer].tr_ptr 
      end 
      
      
      -- add 
        local SET_MarkType_DeviceChild_deviceGUID
        if DATA.children[note] and DATA.children[note].TYPE_DEVICE == true then
          local deviceGUID = DATA.children[note].TR_GUID
          SET_MarkType_DeviceChild_deviceGUID = deviceGUID
         else
          -- add device parent 
          if layer ~= 1 then
            local device_parent = DATA:DropSample_AddNewTrack(true, note) 
            local retval, deviceGUID = GetSetMediaTrackInfo_String( device_parent, 'GUID', '', false  )
            SET_MarkType_DeviceChild_deviceGUID = deviceGUID
            GetSetMediaTrackInfo_String( device_parent, 'P_NAME', 'Note '..note, 1 )
            DATA:WriteData_Child(device_parent, {
              SET_MarkParentForChild = DATA.parent_track.trGUID,
              SET_MarkType_Device = true,
              SET_noteID=note,
              SET_noteID=note,
              }) 
          end
        end
        
        
        local track = DATA:DropSample_AddNewTrack(false, note, SET_MarkType_DeviceChild_deviceGUID)
        DATA:WriteData_Child(track, {
          SET_MarkParentForChild = DATA.parent_track.trGUID,
          SET_MarkType_RegularChild = true,
          SET_MarkType_DeviceChild_deviceGUID=SET_MarkType_DeviceChild_deviceGUID,
          SET_noteID=note,
          }) 
        return track
        
        
      
    end  
    
    -----------------------------------------------------------------------  
    function DATA:DropFX_Export(track, instrument_pos, note, fxname)  
      local midifilt_pos = TrackFX_AddByName( track, 'midi_note_filter', false, -1000 ) 
      DATA:DropSample_ExportToRS5kSetNoteRange({tr_ptr=track, instrument_pos=instrument_pos,midifilt_pos=midifilt_pos}, note) 
      
      -- set parameters
        if EXT.CONF_onadd_float == 0 then TrackFX_SetOpen( track, instrument_pos, false ) end
      
      -- store external data
        local instrumentGUID = TrackFX_GetFXGUID( track, instrument_pos+1)
        DATA:WriteData_Child(track, {
          SET_instrFXGUID = instrumentGUID,
          SET_noteID=note,
          SET_isrs5k=false,
        }) 
      
      -- rename track
        if EXT.CONF_onadd_renametrack==1 then 
          GetSetMediaTrackInfo_String( track, 'P_NAME', fxname, true )
        end
        
    end
    ---------------------------------------------------------------------  
    function DATA:DropFX(fx_namesrc, fxname, fxidx, src_track, note, drop_data)
      if not (fx_namesrc and src_track and note) then return end
      local layer = 1
      if drop_data and drop_data.layer then layer = drop_data.layer end
      
      -- validate parenbt track
      if not (DATA.parent_track and DATA.parent_track.valid == true) then return end 
      DATA:Validate_MIDIbus_AND_ParentFolder() -- make sure parent track is folder for tree consistency 
      DATA.upd = true
       
      -- validate track    
      local track = DATA:DropSample_ValidateTrack(note, layer)
      if not track then return end
      
      -- validate instr pos
      local instrument_pos 
      if DATA.children[note] and DATA.children[note].layers and DATA.children[note].layers[layer or 1] and DATA.children[note].layers[layer or 1].instrument_pos then instrument_pos = DATA.children[note].layers[layer or 1].instrument_pos end 
      if instrument_pos then TrackFX_Delete( track, instrument_pos ) end
      
      -- insert rs5k
      TrackFX_CopyToTrack( src_track, fxidx, track, 0, true )
      local instrument_pos = TrackFX_AddByName( track, fx_namesrc, false, 0)  
      if instrument_pos == -1 then return end
      DATA:DropFX_Export(track, instrument_pos, note, fxname) 
      
      
      DATA.autoreposition = true   
      DATA:_Seq_RefreshStepSeq()
    end
    ---------------------------------------------------------------------  
    function DATA:DropSample(filename, note, drop_data)
      if not (filename and note) then return end
      
      local layer = 1
      if drop_data and drop_data.layer then layer = drop_data.layer end
      if not (drop_data.SOFFS and drop_data.EOFFS) then drop_data.SOFFS = 0 drop_data.EOFFS = 1 end --4.37
      
      -- validate parent track
      if not (DATA.parent_track and DATA.parent_track.valid == true) then return end 
      DATA:Validate_MIDIbus_AND_ParentFolder() -- make sure parent track is folder for tree consistency 
      DATA.upd = true
       
      -- validate track    
      local track = DATA:DropSample_ValidateTrack(note, layer)
      if not track then return end
      
      -- validate instr pos
      local instrument_pos 
      if DATA.children[note] and DATA.children[note].layers and DATA.children[note].layers[layer or 1] and DATA.children[note].layers[layer or 1].instrument_pos then instrument_pos = DATA.children[note].layers[layer or 1].instrument_pos end 
      
      -- insert rs5k
      if not instrument_pos then
        instrument_pos = TrackFX_AddByName( track, 'ReaSamplomatic5000', false, 0) -- query
        if instrument_pos == -1 then instrument_pos = TrackFX_AddByName( track, 'ReaSamplomatic5000', false, -1000 ) end
        if instrument_pos == -1 then return end
      end
      
      -- validate instrument_noteoff
      local instrument_noteoff
      if DATA.children[note] and DATA.children[note].layers and DATA.children[note].layers[layer or 1] and DATA.children[note].layers[layer or 1].instrument_noteoff then instrument_noteoff = DATA.children[note].layers[layer or 1].instrument_noteoff end 
      if instrument_noteoff then 
        if not drop_data.srct then drop_data.srct = {} end
        drop_data.srct.instrument_noteoff = instrument_noteoff
      end
      
      DATA:DropSample_ExportToRS5k(track, instrument_pos, filename, note, drop_data) 
      DATA.autoreposition = true
      
      DATA:_Seq_RefreshStepSeq()
    end   
    -----------------------------------------------------------------------  
    function DATA:DropSample_ExportToRS5k(track, instrument_pos, filename, note, drop_data) 
        
      -- validate filename
        if not (track and  instrument_pos and filename and filename~='')  then return end  
        
        DATA.peakscache[note] = nil
      -- handle file
        if EXT.CONF_onadd_copytoprojectpath == 1 then filename = DATA:DropSample_ExportToRS5k_CopySrc(filename) end 
      -- set parameters
        if EXT.CONF_onadd_float == 0 then TrackFX_SetOpen( track, instrument_pos, false ) end
        
        TrackFX_SetNamedConfigParm( track, instrument_pos, 'FILE0', filename)
        TrackFX_SetNamedConfigParm( track, instrument_pos, 'DONE', '')
        if EXT.CONF_onadd_renameinst == 1 and EXT.CONF_onadd_renameinst_str ~= '' then
          local str = EXT.CONF_onadd_renameinst_str
          str = str:gsub('%#note',note)
          if drop_data.layer then str = str:gsub('%#layer',drop_data.layer) else str = str:gsub('%#layer','') end
          TrackFX_SetNamedConfigParm( track, instrument_pos, 'renamed_name', str)
        end
        
        local temp_t = {
          tr_ptr = track,
          instrument_pos = instrument_pos
        }
        
        -- various
        TrackFX_SetParamNormalized( track, instrument_pos, 2, EXT.CONF_onadd_mingain) -- gain for min vel 
        TrackFX_SetParamNormalized( track, instrument_pos, 8, (EXT.CONF_onadd_maxvoices-1)/63 ) -- max voices 
        TrackFX_SetParamNormalized( track, instrument_pos, 17, EXT.CONF_onadd_minvel/127 )
        TrackFX_SetParamNormalized( track, instrument_pos, 18, EXT.CONF_onadd_maxvel/127 )
        
        -- obey note off
        local obeynoteoff = EXT.CONF_onadd_obeynoteoff if drop_data and drop_data.srct and drop_data.srct.instrument_noteoff then obeynoteoff = drop_data.srct.instrument_noteoff end
        TrackFX_SetParamNormalized( track, instrument_pos, 11, obeynoteoff) -- obey note offs
        
        -- ADSR 
        local attack =    math.min(2,EXT.CONF_onadd_ADSR_A)       if EXT.CONF_onadd_ADSR_flags&1==1 then TrackFX_SetParamNormalized( track, instrument_pos, 9, attack )  end
        local decay_sec = math.min(15,EXT.CONF_onadd_ADSR_D-0.01)/15   if EXT.CONF_onadd_ADSR_flags&2==2 then TrackFX_SetParamNormalized( track, instrument_pos, 24, decay_sec )  end
        local sustain=    math.min(2,EXT.CONF_onadd_ADSR_S)       if EXT.CONF_onadd_ADSR_flags&4==4 then TrackFX_SetParamNormalized( track, instrument_pos, 25, sustain )  end
        local release =   math.min(2,EXT.CONF_onadd_ADSR_R)       if EXT.CONF_onadd_ADSR_flags&8==8 then TrackFX_SetParamNormalized( track, instrument_pos, 10, release )  end
         
      -- set offsets
        if drop_data and drop_data.SOFFS and drop_data.EOFFS then
          TrackFX_SetParamNormalized( track, instrument_pos, 13, drop_data.SOFFS )
          TrackFX_SetParamNormalized( track, instrument_pos, 14, drop_data.EOFFS )
        end
      
      -- store external data
        local src = PCM_Source_CreateFromFileEx( filename, true )
        if src then
          local src_len =  GetMediaSourceLength( src )  
          
          -- auto normalization
          if EXT.CONF_onadd_autoLUFSnorm_toggle == 1 then 
            
            local normalizeTo = 0
            local normalizeTarget = EXT.CONF_onadd_autoLUFSnorm
            
            local norm_check1 = 0
            local norm_check2 = 0
            
            if drop_data.SOFFS then norm_check1 = drop_data.SOFFS * src_len end
            if drop_data.EOFFS then norm_check2 = drop_data.EOFFS * src_len end
            
            local LUFSNORM = CalculateNormalization( src, normalizeTo, normalizeTarget, norm_check1, norm_check2 ) 
            local LUFSNORM_db = WDL_VAL2DB(LUFSNORM)
            drop_data.LUFSNORM_db = LUFSNORM_db
            
            LUFSNORM_db = drop_data.LUFSNORM_db
            LUFSNORM_db= tostring(LUFSNORM_db)
            local v = VF_BFpluginparam(LUFSNORM_db, track, instrument_pos,0)
            v = VF_lim(v,0.1,1)
            TrackFX_SetParamNormalized( track, instrument_pos,0, v )   
            function __f_lufs_compensation() end
          end
          
          PCM_Source_Destroy( src )
          
          if src_len then  
            local instrumentGUID = TrackFX_GetFXGUID( track, instrument_pos)
            local SAMPLEBPM ,LUFSNORM_db
            if drop_data.SAMPLEBPM then SAMPLEBPM = drop_data.SAMPLEBPM end
            if drop_data.LUFSNORM_db then LUFSNORM_db = drop_data.LUFSNORM_db end
            DATA:WriteData_Child(track, {
              SET_SAMPLELEN = src_len,
              SET_SAMPLEBPM = SAMPLEBPM,
              SET_LUFSNORM = LUFSNORM_db,
              SET_instrFXGUID = instrumentGUID,
              SET_noteID=note,
              SET_isrs5k=true,
            }) 
            
          end 
        end
        
      -- rename track
        DATA:DropSample_RenameTrack(track,note,filename,drop_data) 
        
      -- set DB
        if drop_data.set_DB then 
          DATA:WriteData_Child(track, {
            SET_useDB = 1,
            SET_useDB_name = drop_data.set_DB})  
        end
        
      -- sysex mode
        if EXT.CONF_onadd_sysexmode == 1 then DATA:Action_RS5k_SYSEXMOD_ON(note, true, track, instrument_pos)end 
        TrackFX_SetNamedConfigParm( track, instrument_pos, 'MODE',1 ) 
        DATA:DropSample_ExportToRS5kSetNoteRange(temp_t, note) 
        local SYSEXMOD = DATA.children[note] and DATA.children[note].SYSEXMOD == true
        if SYSEXMOD == true then 
          TrackFX_SetParamNormalized( track, instrument_pos, 3,0 ) -- note start
          TrackFX_SetParamNormalized( track, instrument_pos, 4, 1 ) -- note end
          TrackFX_SetParamNormalized( track, instrument_pos, 5, 0.5 ) -- pitch for start
          TrackFX_SetParamNormalized( track, instrument_pos, 6, 0.5 ) -- pitch for end
          TrackFX_SetNamedConfigParm( track, instrument_pos, 'MODE', 0 ) -- turn sample into freely configurable mode
        end
    end  
    -----------------------------------------------------------------------  
    function DATA:DropSample_RenameTrack(track,note,filename,drop_data) 
      if EXT.CONF_onadd_renametrack~=1 then return end
      local outname = '' 
      if DATA.padcustomnames and DATA.padcustomnames[note] and DATA.padcustomnames[note] ~='' then outname = DATA.padcustomnames[note] end
      if outname == '' and filename then
        local filename_sh = VF_GetShortSmplName(filename)
        if filename_sh and filename_sh:match('(.*)%.[%a]+') then filename_sh = filename_sh:match('(.*)%.[%a]+') end -- remove extension
        if drop_data and drop_data.tr_name_add and filename_sh then filename_sh = filename_sh .. ' '..drop_data.tr_name_add end
        outname = filename_sh
      end
      if outname then
        GetSetMediaTrackInfo_String( track, 'P_NAME', outname, true )
      end
    end
    --------------------------------------------------------------------------------  
    function DATA:Action_ExplodeTake_sub_readparent(take)
      local MIDIdata = {}
      local gotAllOK, MIDIstring = MIDI_GetAllEvts(take, "")
      local MIDIlen = MIDIstring:len()
      local stringPos = 1
      local offset, flags, msg1
      local ppq_pos = 0
      local sysex_handler = {}
      while stringPos < MIDIlen do
        offset, flags, msg1, stringPos = string.unpack("i4Bs4", MIDIstring, stringPos) 
        ppq_pos = ppq_pos + offset
        
        
        local validsysex = msg1:len()>3 and msg1:byte(1)==0xF0 and msg1:byte(2)==0x60 and msg1:byte(3)==0x01
        local CC = msg1:len()==3 and msg1:byte(1)&0xF0==0xB0
        local noteON = msg1:len()==3 and msg1:byte(1)&0xF0==0x90
        local noteOFF = msg1:len()==3 and msg1:byte(1)&0xF0==0x80
        
        local active_note = msg1:byte(2)
        if not active_note then goto skipmsg end
        if validsysex == true then active_note = msg1:byte(4) end 
        if CC == true and active_note == 123 then active_note = 'AllNotesOFF' end
         
        if not MIDIdata[active_note] then MIDIdata[active_note] = {} end
        local id = #MIDIdata[active_note] + 1 
        MIDIdata[active_note][id] = 
          {
            ppq_pos=ppq_pos,
            msg1=msg1,
            flags=flags
          }
          
        if sysex_handler [active_note] then 
          MIDIdata[active_note][id].meta = CopyTable(sysex_handler [active_note]) 
          sysex_handler [active_note] = nil
        end
        
        ::skipmsg::
      end
        
      return MIDIdata
    end
  --------------------------------------------------------------------------------  
    function DATA:Action_ExplodeTake_sub_writechildren(options, item, take, MIDIdata)
      -- get boundary
        local D_POSITION = GetMediaItemInfo_Value( item, 'D_POSITION' )
        local D_LENGTH = GetMediaItemInfo_Value( item, 'D_LENGTH' )
        local B_LOOPSRC = GetMediaItemInfo_Value( item, 'B_LOOPSRC' ) 
        local D_STARTOFFS = GetMediaItemTakeInfo_Value( take, 'D_STARTOFFS' )
        local D_PLAYRATE = GetMediaItemTakeInfo_Value( take, 'D_PLAYRATE' )
        local I_CUSTOMCOLOR = GetMediaItemTakeInfo_Value( take, 'I_CUSTOMCOLOR' )
        local pcmsrc = GetMediaItemTake_Source( take )
        local srclen, lengthIsQN = reaper.GetMediaSourceLength( pcmsrc )
        
        
      for note in pairs(MIDIdata) do
        if note and DATA.children[note] then
          local track = DATA.children[note].tr_ptr
          local SYSEXMOD = DATA.children[note].SYSEXMOD
          if DATA.children[note].SYSEXHANDLER_ID and DATA.children[note].SYSEXHANDLER_isvalid==true then TrackFX_SetEnabled( track, DATA.children[note].SYSEXHANDLER_ID, false ) end
          if DATA.children[note].layers and DATA.children[note].layers[1] and DATA.children[note].layers[1].midifilt_pos then TrackFX_SetEnabled( DATA.children[note].layers[1].tr_ptr, DATA.children[note].layers[1].midifilt_pos, false ) end 
          if track then
          
            local new_item = CreateNewMIDIItemInProj( track, D_POSITION, D_POSITION + D_LENGTH )
            local childtake = GetActiveTake(new_item)
            SetMediaItemTakeInfo_Value( childtake, 'D_STARTOFFS',D_STARTOFFS )
            SetMediaItemTakeInfo_Value( childtake, 'D_PLAYRATE',D_PLAYRATE ) 
            SetMediaItemTakeInfo_Value( childtake, 'I_CUSTOMCOLOR',I_CUSTOMCOLOR ) 
            SetMediaItemInfo_Value( new_item, 'B_LOOPSRC',B_LOOPSRC )
            
            -- add events
            local MIDIstring = ""
            local offset = 0
            local ppq_pos_last = 0
            for i = 1, #MIDIdata[note] do 
              local ppq_pos = MIDIdata[note][i].ppq_pos
              offset = ppq_pos - ppq_pos_last
              local out_msg1 = MIDIdata[note][i].msg1
              if options.modify_note then 
                local out_pitch=  options.modify_note
                out_msg1 = string.char(out_msg1:byte(1), out_pitch ,out_msg1:byte(3) )
              end
              MIDIstring = MIDIstring..string.pack("i4Bs4",offset, MIDIdata[note][i].flags, out_msg1)
              ppq_pos_last = ppq_pos 
              ::nextevent::
            end
            
            -- add all note off
            AllNotesOFF_t = MIDIdata['AllNotesOFF'][1]
            local ppq_pos = AllNotesOFF_t.ppq_pos
            offset = ppq_pos - ppq_pos_last
            MIDIstring = MIDIstring..string.pack("i4Bs4",offset, 0, AllNotesOFF_t.msg1)
            MIDI_SetAllEvts(childtake, MIDIstring)
            MIDI_Sort(childtake)
            
            if SYSEXMOD == true then DATA:Action_ExplodeTake_sub_sysexhandler(childtake) end
          end
        end
      end
      
      
    end
    --------------------------------------------------------------------------------  
    function DATA:Action_ExplodeTake_sub_sysexhandler(take)
      local gotAllOK, MIDIstring = MIDI_GetAllEvts(take, "")
      local MIDIlen = MIDIstring:len()
      local stringPos = 1
      local offset, flags, msg1
      local ppq_pos = 0
      local sysex_handler = {}
      local MIDIstring_out = ''
      
      local pitch_correction = 0; 
      local val_rand = 0;
      local probability = 1; 
      
      while stringPos < MIDIlen do
        offset, flags, msg1, stringPos = string.unpack("i4Bs4", MIDIstring, stringPos) 
        
        --// received sysex is F0 60 01 ...some_parameters.. F7
        if msg1:len() > 3 and msg1:byte(1)==0xF0 and msg1:byte(2)==0x60 and msg1:byte(3)==0x01 then 
          pitch_correction = msg1:byte(5);
          probability = msg1:byte(6)/127; 
          MIDIstring_out = MIDIstring_out..string.pack("i4Bs4", offset, 0, '') -- clear / preserve offset 
            
            
        --// note ON        
         elseif msg1:len() == 3 and msg1:byte(1)==0x90 then
          outpitch = 64;
          if pitch_correction ~= 0 then outpitch = pitch_correction end;
          MIDIstring_out = MIDIstring_out..string.pack("i4BI4BBB", offset, flags, 3, 
            msg1:byte(1),
            outpitch,
            msg1:byte(3))
            
        --// note OFF        
         elseif msg1:len() == 3 and msg1:byte(1)==0x80 then    
          outpitch = 64;
          if pitch_correction ~= 0 then outpitch = pitch_correction end;
          MIDIstring_out = MIDIstring_out..string.pack("i4BI4BBB", offset, flags, 3, 
            msg1:byte(1),
            outpitch,
            msg1:byte(3))
         elseif msg1:len() == 3 and msg1:byte(1)==0xB0 then    
          MIDIstring_out = MIDIstring_out..string.pack("i4BI4BBB", offset, flags, 3, 
            msg1:byte(1),
            msg1:byte(2),
            msg1:byte(3))          
        end
      end
      MIDI_SetAllEvts(take, MIDIstring_out)
      MIDI_Sort(take)
      
      
      --[[
      
      local outpitch = note
      if SYSEXMOD == true then 
        outpitch = 64 
        if tableEvents[i].meta and tableEvents[i].meta.pitchcorection then outpitch  = tableEvents[i].meta.pitchcorection end
      end
      
      
      activenote = msg1:byte(4)
      pitchcorection = msg1:byte(5)
      if pitchcorection == 0 then pitchcorection = 64 end
      probability = msg1:byte(6)
      meta[activenote]={
          pitchcorection=pitchcorection,
          probability=probability
        }]]
    end
    --------------------------------------------------------------------------------  
    function DATA:Action_ExplodeTake_sub(options, item)
      if not item then return end
      local take = GetActiveTake(item)
      if not (take and reaper.TakeIsMIDI(take)) then return end
      MIDI_Sort(take)
      MIDIdata = DATA:Action_ExplodeTake_sub_readparent(take)
      if not MIDIdata then return end
      DATA:Action_ExplodeTake_sub_writechildren(options, item, take, MIDIdata) 
      
      -- mute item
      SetMediaItemInfo_Value( item, 'B_MUTE', 1 )
    end
  --------------------------------------------------------------------------------  
    function DATA:Action_ExplodeTake(options)
      Undo_BeginBlock2(DATA.proj)
      for i = 1, reaper.CountSelectedMediaItems(DATA.proj) do
        local item = GetSelectedMediaItem(DATA.proj, i-1)
        DATA:Action_ExplodeTake_sub(options, item)
      end
      Undo_EndBlock2(DATA.proj, 'Explode MIDI bus take by note', 0xFFFFFFFF)
    end
    --[[
    
    --------------------------------------------------------------------------------  
      function DATA:Action_ExplodeTake_old01062025()
        Undo_BeginBlock2(DATA.proj)
        for i = 1, reaper.CountSelectedMediaItems(DATA.proj) do
          local item = GetSelectedMediaItem(DATA.proj, i-1)
          if not item then goto nextitem end
          local take = GetActiveTake(item)
          if not (take and reaper.TakeIsMIDI(take)) then goto nextitem end
          
          MIDI_Sort(take)
          
          local D_POSITION = GetMediaItemInfo_Value( item, 'D_POSITION' )
          local D_LENGTH = GetMediaItemInfo_Value( item, 'D_LENGTH' )
          local B_LOOPSRC = GetMediaItemInfo_Value( item, 'B_LOOPSRC' )
          SetMediaItemInfo_Value( item, 'B_MUTE', 1 )
          local D_STARTOFFS = GetMediaItemTakeInfo_Value( take, 'D_STARTOFFS' )
          local D_PLAYRATE = GetMediaItemTakeInfo_Value( take, 'D_PLAYRATE' )
          local I_CUSTOMCOLOR = GetMediaItemTakeInfo_Value( take, 'I_CUSTOMCOLOR' )
          local pcmsrc = GetMediaItemTake_Source( take )
          local srclen, lengthIsQN = reaper.GetMediaSourceLength( pcmsrc )
          
          local t_pitch= {}
           tableEvents = {}
          local t = 0
          local gotAllOK, MIDIstring = MIDI_GetAllEvts(take, "")
          local MIDIlen = MIDIstring:len()
          local stringPos = 1
          local offset, flags, msg1
          local val = 1
          local meta = {}
          local ppq_pos = 0
          while stringPos < MIDIlen do
            offset, flags, msg1, stringPos = string.unpack("i4Bs4", MIDIstring, stringPos) 
            ppq_pos = ppq_pos + offset
            if msg1:len()>3 and msg1:byte(1)==0xF0 and msg1:byte(2)==0x60 and msg1:byte(3)==0x01 then
              activenote = msg1:byte(4)
              pitchcorection = msg1:byte(5)
              if pitchcorection == 0 then pitchcorection = 64 end
              probability = msg1:byte(6)
              meta={
                pitchcorection=pitchcorection,
                probability=probability
                }
              tableEvents[#tableEvents+1] = {
                offset=offset,
                flags=flags,
                msg1='',
              }
              goto nextevt
            end
                
            local pitch = msg1:byte(2) 
            tableEvents[#tableEvents+1] = {
              offset=offset,
              flags=flags,
              msg1=msg1,
              tp= string.format("%x", msg1:byte(1)),
              meta=CopyTable(meta),
            }
            meta=nil
            t_pitch[pitch]=true 
            
            ::nextevt::
          end
          
          
          for note in pairs(t_pitch) do
            if note and DATA.children[note] then
              local track = DATA.children[note].tr_ptr
              local SYSEXMOD = DATA.children[note].SYSEXMOD
              if DATA.children[note].SYSEXHANDLER_ID and DATA.children[note].SYSEXHANDLER_isvalid==true then TrackFX_SetEnabled( track, DATA.children[note].SYSEXHANDLER_ID, false ) end
              if DATA.children[note].layers and DATA.children[note].layers[1] and DATA.children[note].layers[1].midifilt_pos then TrackFX_SetEnabled( DATA.children[note].layers[1].tr_ptr, DATA.children[note].layers[1].midifilt_pos, false ) end 
              if track then
                local new_item = CreateNewMIDIItemInProj( track, D_POSITION, D_POSITION + D_LENGTH )
                local childtake = GetActiveTake(new_item)
                SetMediaItemTakeInfo_Value( childtake, 'D_STARTOFFS',D_STARTOFFS )
                SetMediaItemTakeInfo_Value( childtake, 'D_PLAYRATE',D_PLAYRATE ) 
                SetMediaItemTakeInfo_Value( childtake, 'I_CUSTOMCOLOR',I_CUSTOMCOLOR ) 
                SetMediaItemInfo_Value( new_item, 'B_LOOPSRC',B_LOOPSRC )  
                local MIDIstring = ""
                for i = 1, #tableEvents-1 do
                  
                  
                  
                  
                  if msg1:byte(2) ~= note then MIDIstring = MIDIstring..string.pack("i4Bs4", tableEvents[i].offset, tableEvents[i].flags, '') goto nextevent end  
                  
                  if tableEvents[i].meta and tableEvents[i].meta.pitchcorection  then
                    test = tableEvents[i].meta
                    MIDIstring = MIDIstring..string.pack("i4BI4BBB", tableEvents[i].offset, tableEvents[i].flags, 3, 
                      tableEvents[i].msg1:byte(1),
                      tableEvents[i].meta.pitchcorection,
                      tableEvents[i].msg1:byte(3))
                   else
                    if SYSEXMOD == true then -- alway print 64
                      MIDIstring = MIDIstring..string.pack("i4BI4BBB", tableEvents[i].offset, tableEvents[i].flags, 3, 
                        tableEvents[i].msg1:byte(1),
                        64,
                        tableEvents[i].msg1:byte(3))
                     else
                      MIDIstring = MIDIstring..string.pack("i4Bs4", tableEvents[i].offset, tableEvents[i].flags, tableEvents[i].msg1)
                    end
                  end
                  
                  
                  ::nextevent::
                end
                MIDIstring = MIDIstring..string.pack("i4Bs4", tableEvents[#tableEvents].offset, tableEvents[#tableEvents].flags, tableEvents[#tableEvents].msg1)
                MIDI_SetAllEvts(childtake, MIDIstring)
                MIDI_Sort(childtake)
              end
            end
          end
          
          ::nextitem::
        end
        Undo_EndBlock2(DATA.proj, 'Explode MIDI bus take by note', 0xFFFFFFFF)
      end
      ]]
  --------------------------------------------------------------------------------  
    function DATA:Database_Load(sel_pad_only)
      if not EXT.UIdatabase_maps_current then return end
      if not DATA.reaperDB then return end
      local mapID = EXT.UIdatabase_maps_current
      if not (DATA.database_maps[mapID] and DATA.database_maps[mapID].map) then return end
      
      for note in spairs(DATA.database_maps[mapID].map) do
        if not sel_pad_only or (sel_pad_only == true and DATA.parent_track.ext.PARENT_LASTACTIVENOTE and note == DATA.parent_track.ext.PARENT_LASTACTIVENOTE) then
        
          local dbname = DATA.database_maps[mapID].map[note].dbname
          if DATA.reaperDB[dbname] and DATA.reaperDB[dbname].files then
            local sz = #DATA.reaperDB[dbname].files
            if sz>0 then
              local rand_fid = 1 + math.floor(math.random(sz-1))
              local fp = DATA.reaperDB[dbname].files[rand_fid].fp
              DATA:DropSample(fp, note, {set_DB = dbname})
            end
          end
        
        end
      end
    end
  --------------------------------------------------------------------------------  
    function DATA:Database_Save(ignore_current_rack)  
      if not EXT.UIdatabase_maps_current then return end
      if not DATA.reaperDB then return end
      local mapID = EXT.UIdatabase_maps_current
      if not (DATA.database_maps[mapID] and DATA.database_maps[mapID].map) then return end
      
      if not ignore_current_rack then
        for note in pairs(DATA.children) do
          if DATA.children[note].layers 
            and DATA.children[note].layers[1] 
            and DATA.children[note].layers[1].SET_useDB_name
           then
            local dbname = DATA.children[note].layers[1].SET_useDB_name
            if not DATA.database_maps[mapID].map[note] then DATA.database_maps[mapID].map[note] = {} end
            DATA.database_maps[mapID].map[note].dbname=dbname
          end
        end
      end
      
      local s = 'DBNAME '..DATA.database_maps[mapID].dbname..'\n'
      if not DATA.database_maps[mapID].map then return '' end
      for note in pairs(DATA.database_maps[mapID].map) do
        s = s..'NOTE'..note
        for param in pairs(DATA.database_maps[mapID].map[note]) do 
          local tp =  type(DATA.database_maps[mapID].map[note][param]) 
          if tp == 'string' or tp == 'number' then 
            s = s ..' <'..param..'>'..DATA.database_maps[mapID].map[note][param]..'</'..param..'>' 
          end
        end
        s = s..'\n'
      end
      
      EXT['CONF_database_map'..mapID] = VF_encBase64(s)
      EXT:save() 
    end  
    
    -----------------------------------------------------------------------  
    function DATA:Sampler_ShowME(note0, layer0) 
      local note 
      if not note then 
        if not DATA.parent_track and DATA.parent_track.ext and DATA.parent_track.ext.PARENT_LASTACTIVENOTE then return end 
        note = DATA.parent_track.ext.PARENT_LASTACTIVENOTE 
       else 
        note = note0 
      end
      local layer if not layer then layer = 1 else layer = layer0 end
      if not DATA.children[note] then return end
      local t = DATA.children[note].layers[layer] -- layer == 1 do stuff on device/instrument or first layer only // layer defined = do stuff on defined layer 
      if not t.instrument_filename then return end
      OpenMediaExplorer( t.instrument_filename, false )
    end  
    
    -------------------------------------------------------------------------------- 
    function DATA:Action_LearnController(tr,fxnumber,paramnumber, clear)
      if not (tr and fxnumber and paramnumber) then return end
      local midi1, midi2
      local retval1, rawmsg, tsval, devIdx, projPos, projLoopCnt = MIDI_GetRecentInputEvent(0)
      
      --[[local retval, tracknumber, fxnumber, paramnumber = reaper.GetLastTouchedFX()
      if not retval then return end 
      local trid = tracknumber&0xFFFF
      local itid = (tracknumber>>16)&0xFFFF
      if itid > 0 then return end -- ignore item FX
      local tr
      if trid==0 then tr = GetMasterTrack(0) else tr = GetTrack(0,trid-1) end
      if not tr then return end]]
      
      if clear~= true then
        if retval1 == 0 then return end
        midi2 = rawmsg:byte(2)
        midi1 = rawmsg:byte(1)  
        Undo_BeginBlock2( DATA.proj )
        TrackFX_SetNamedConfigParm( tr, fxnumber, 'param.'..paramnumber..'.learn.midi1', midi1)
        TrackFX_SetNamedConfigParm( tr, fxnumber, 'param.'..paramnumber..'.learn.midi2', midi2) 
        Undo_EndBlock2( DATA.proj, 'Bind controller to RS5k manager', 0xFFFFFFFF )
       else
        Undo_BeginBlock2( DATA.proj )
        TrackFX_SetNamedConfigParm( tr, fxnumber, 'param.'..paramnumber..'.learn.midi1', '')
        TrackFX_SetNamedConfigParm( tr, fxnumber, 'param.'..paramnumber..'.learn.midi2', '') 
        Undo_EndBlock2( DATA.proj, 'Clear macro binding', 0xFFFFFFFF )
      end
    end
    
    -----------------------------------------------------------------------------  
    function DATA:Macro_ConfirmLastTouchedParamIsChild()
      local t = VF_GetLTP()
      if not t then return end
      local note_out, layer_out
      local lt_TR_GUID = t.trGUID
      for note in pairs(DATA.children) do
        if DATA.children[note].TR_GUID then 
          if DATA.children[note].TR_GUID == lt_TR_GUID then 
            return true, DATA.children[note], t.fxnumber, t.paramnumber
          end
        end
        if DATA.children[note].layers then
          for layer in pairs(DATA.children[note].layers) do
            if DATA.children[note].layers[layer].TR_GUID and DATA.children[note].layers[layer].TR_GUID == lt_TR_GUID then
              return true, DATA.children[note].layers[layer], t.fxnumber, t.paramnumber
            end
          end
        end
      end
    end
    -----------------------------------------------------------------------------  
    function DATA:Macro_AddLink(srct0,fxnumber0,paramnumber0, offset0, scale0)
      DATA.upd = true
      -- validate stuff
        if DATA.parent_track.valid ~= true then return end 
        if not DATA.parent_track.ext.PARENT_LASTACTIVEMACRO then return end 
        if DATA.parent_track.ext.PARENT_LASTACTIVEMACRO == -1 then return end
      
      -- validate locals / last touched param
        local ret, srct, fxnumber, paramnumber = DATA:Macro_ConfirmLastTouchedParamIsChild()
        if not ret and not srct0 then 
          return 
         elseif (srct0 and fxnumber0 and paramnumber0) then
          srct, fxnumber, paramnumber = srct0, fxnumber0, paramnumber0
        end 
      
      -- init child macro
        if not srct.MACRO_pos then DATA:Macro_InitChildrenMacro(true, srct) fxnumber=fxnumber+1 end 
        
      -- link
        local param_src = tonumber(DATA.parent_track.ext.PARENT_LASTACTIVEMACRO)
        local fx_src = tonumber(srct.MACRO_pos)
        
        TrackFX_SetNamedConfigParm(srct.tr_ptr, fxnumber, 'param.'..paramnumber..'.plink.active', 1)
        TrackFX_SetNamedConfigParm(srct.tr_ptr, fxnumber, 'param.'..paramnumber..'.plink.scale', scale0 or 1)
        TrackFX_SetNamedConfigParm(srct.tr_ptr, fxnumber, 'param.'..paramnumber..'.plink.offset', offset0 or 0)
        TrackFX_SetNamedConfigParm(srct.tr_ptr, fxnumber, 'param.'..paramnumber..'.plink.effect',fx_src)
        TrackFX_SetNamedConfigParm(srct.tr_ptr, fxnumber, 'param.'..paramnumber..'.plink.param', param_src)
        TrackFX_SetNamedConfigParm(srct.tr_ptr, fxnumber, 'param.'..paramnumber..'.plink.midi_bus', 0)
        TrackFX_SetNamedConfigParm(srct.tr_ptr, fxnumber, 'param.'..paramnumber..'.plink.midi_chan', 0)
        TrackFX_SetNamedConfigParm(srct.tr_ptr, fxnumber, 'param.'..paramnumber..'.plink.midi_msg', 0)
        TrackFX_SetNamedConfigParm(srct.tr_ptr, fxnumber, 'param.'..paramnumber..'.plink.midi_msg2', 0)
        TrackFX_SetNamedConfigParm(srct.tr_ptr, fxnumber, 'param.'..paramnumber..'.mod.active', 1)
        TrackFX_SetNamedConfigParm(srct.tr_ptr, fxnumber, 'param.'..paramnumber..'.mod.visible', 0)
    end
    
    --------------------------------------------------------------------------------  
    function DATA:CollectDataInit_EnumeratePlugins()
      local plugs_data = {
        types = {},
        vendors = {},
      } 
      for i = 1, 10000 do
        local retval, name, ident = reaper.EnumInstalledFX( i-1 )
        if not retval then break end
        if name:match('i%:') then
          local checkname=name
            :gsub('%(x64%)','')
            :gsub('%(x86%)','')
          local vendor = checkname:match('%((.-)%)')
          if not vendor or (vendor and vendor == '')then vendor = '[unknown]'end
          fxtype = name:match('(.-)%:') or 'Other'
          plugs_data.types[fxtype]=(plugs_data.types[fxtype] or 0) + 1
          plugs_data.vendors[vendor]=(plugs_data.vendors[vendor] or 0) + 1
          
          plugs_data[#plugs_data+1] = {name = name, 
                                       reduced_name = VF_ReduceFXname(name) ,
                                       ident = ident,
                                       vendor=vendor,
                                       fxtype=fxtype,
                                       }
    
        end                                   
      end
      DATA.installed_plugins = plugs_data
    end
    -------------------------------------------------------------------------------- 
    function UI.draw_3rdpartyimport_context_add(buf, note, drop_data) 
      local track = GetMasterTrack(-1) 
      local fxidx = TrackFX_AddByName( track, buf, false, -1 )
      if fxidx ~= -1 then
        local retval, fx_namesrc = reaper.TrackFX_GetNamedConfigParm( track, fxidx, 'fx_name' )
        local fx_name = VF_ReduceFXname(fx_namesrc)
        DATA:DropFX(fx_namesrc, fx_name, fxidx, track, note, drop_data)
        ImGui.CloseCurrentPopup(ctx)
      end
    end
      -------------------------------------------------------------------------------- 
    function UI.draw_3rdpartyimport_context(note,drop_data)  
      ImGui.SetNextItemWidth( ctx,-100)
      if ImGui.BeginMenu( ctx, 'Import FXi', true ) then 
        local cnt_com = #DATA.installed_plugins 
        
        -- by type
        reaper.ImGui_SeparatorText(ctx, 'By type')
        for typestr in spairs(DATA.installed_plugins.types) do
          local cnt = DATA.installed_plugins.types[typestr]
          if ImGui.BeginMenu( ctx, typestr..' ('..cnt..')', true ) then 
            for i = 1, cnt_com do
              if DATA.installed_plugins[i].fxtype == typestr then 
                local name = DATA.installed_plugins[i].name or 'untitled'
                if name:match('%:(.*)') then name = name:match('%:(.*)') end
                local retval, p_selected = reaper.ImGui_MenuItem( ctx, name..'##plug'..i..typestr )
                if retval then UI.draw_3rdpartyimport_context_add(DATA.installed_plugins[i].name, note, drop_data)  end
              end
            end
            ImGui.EndMenu( ctx)
          end
        end
        
        -- by vendor
        reaper.ImGui_SeparatorText(ctx, 'By vendor')
        for vendorstr in spairs(DATA.installed_plugins.vendors) do
          local cnt = DATA.installed_plugins.vendors[vendorstr]
          if ImGui.BeginMenu( ctx, vendorstr..' ('..cnt..')', true ) then 
            for i = 1, cnt_com do
              if DATA.installed_plugins[i].vendor == vendorstr then 
                local name = DATA.installed_plugins[i].name or 'untitled'
                local retval, p_selected = reaper.ImGui_MenuItem( ctx, name..'##plug'..i..vendorstr )
                if retval then UI.draw_3rdpartyimport_context_add(DATA.installed_plugins[i].name, note, drop_data)  end
              end
            end
            ImGui.EndMenu( ctx)
          end
        end
        
        -- enter
        reaper.ImGui_SeparatorText(ctx, 'By entered name')
        local retval, buf = reaper.ImGui_InputText( ctx, '##fxinput', '', ImGui.InputTextFlags_EnterReturnsTrue )
        if retval then
        
          UI.draw_3rdpartyimport_context_add(buf, note, drop_data) 
          
        end
        
        
        ImGui.EndMenu( ctx)
      end
      
    end
    -----------------------------------------------------------------------  
    function DATA:Macro_InitChildrenMacro(child_mode, srct)
      --if DATA.parent_track.macro.valid == true and not child_mode then return end
      
      local fxname = 'mpl_RS5k_manager_MacroControls.jsfx'
      
      -- master
      if not child_mode then
        local macroJSFX_pos =  TrackFX_AddByName( DATA.parent_track.ptr, fxname, false, 0 )
        if macroJSFX_pos == -1 then
          macroJSFX_pos =  TrackFX_AddByName( DATA.parent_track.ptr, fxname, false, -1000 ) 
          local macroJSFX_fxGUID = reaper.TrackFX_GetFXGUID( DATA.parent_track.ptr, macroJSFX_pos ) 
          DATA.parent_track.ext.PARENT_MACRO_GUID =macroJSFX_fxGUID
          DATA:WriteData_Parent()
          TrackFX_Show( DATA.parent_track.ptr, macroJSFX_pos, 0|2 )
          for i = 1, 16 do TrackFX_SetParamNormalized( DATA.parent_track.ptr, macroJSFX_pos, 33+i, i/1024 ) end -- init source gmem IDs
        end
        return macroJSFX_pos
      end
      
      
      -- child_mode
      if child_mode == true then 
        if not srct then return end
        if not srct.MACRO_pos then
          macroJSFX_pos =  TrackFX_AddByName( srct.tr_ptr, fxname, false, -1000 )
          if macroJSFX_pos == -1 then return end --MB('RS5k manager_MacroControls JSFX is missing. Make sure you installed it correctly via ReaPack.', '', 0) end
          local macroJSFX_fxGUID = reaper.TrackFX_GetFXGUID( srct.tr_ptr, macroJSFX_pos )  
          TrackFX_Show( srct.tr_ptr, macroJSFX_pos, 0|2 )
          TrackFX_SetParamNormalized( srct.tr_ptr, macroJSFX_pos, 0, 1 ) -- set mode to slave
          for i = 1, 16 do TrackFX_SetParamNormalized( srct.tr_ptr, macroJSFX_pos, 17+i, i/1024 ) end -- ini source gmem IDs
          DATA:WriteData_Child(srct.tr_ptr, {MACRO_GUID=macroJSFX_fxGUID})
          srct.MACRO_pos = macroJSFX_pos
          return macroJSFX_pos
        end
      end
      
    end
    -----------------------------------------------------------------------  
    function DATA:Macro_ClearLink()
      if not (DATA.parent_track.ext and DATA.parent_track.ext.PARENT_LASTACTIVEMACRO) then return end 
      local macroID = DATA.parent_track.ext.PARENT_LASTACTIVEMACRO
      if not DATA.parent_track.macro.sliders[macroID].links then return end
      for link = #DATA.parent_track.macro.sliders[macroID].links, 1, -1 do
        local tmacro = DATA.parent_track.macro.sliders[macroID].links[link]
        TrackFX_SetNamedConfigParm(tmacro.note_layer_t.tr_ptr, tmacro.fx_dest, 'param.'..tmacro.param_dest..'plink.active', 0) 
      end
          
    end    
    
    ----------------------------------------------------------------------
    function DATA:Actions_TemporaryGetAudio(filename) 
      
      local PCM_Source = PCM_Source_CreateFromFile( filename )
      local srclen, lengthIsQN = reaper.GetMediaSourceLength( PCM_Source )
      if srclen > EXT.CONF_crop_maxlen then
        --if PCM_Source then  PCM_Source_Destroy( PCM_Source )  end
        return
      end
      
      
      -- add temp stuff for audio read
      local tr_cnt = CountTracks(DATA.proj)
      InsertTrackInProject( DATA.proj, tr_cnt, 0 )
      local temp_track  = GetTrack(DATA.proj, tr_cnt) 
      local temp_item = AddMediaItemToTrack( temp_track )
      local temp_take = AddTakeToMediaItem( temp_item )
      SetMediaItemTake_Source( temp_take, PCM_Source )
      SetMediaItemInfo_Value( temp_item, 'D_POSITION', 0 )
      SetMediaItemInfo_Value( temp_item, 'D_LENGTH',srclen ) 
      local SR = reaper.GetMediaSourceSampleRate( PCM_Source )  
      local window_spls = SR  * srclen 
      local samplebuffer = reaper.new_array(window_spls) 
      local accessor = CreateTakeAudioAccessor( temp_take )
      GetAudioAccessorSamples( accessor, SR, 1, 0, window_spls, samplebuffer ) 
      --if reaper.ValidatePtr2( DATA.proj, PCM_Source, 'PCM_Source*' ) then  PCM_Source_Destroy( PCM_Source )  end
      DestroyAudioAccessor( accessor ) 
      DeleteTrack( temp_track )
      
      local samplebuffer_t = samplebuffer.table()
      samplebuffer.clear()
      return samplebuffer_t,srclen,SR
    end
    ----------------------------------------------------------------------
    function DATA:Action_CropToAudibleBoundaries(note_layer_t) 
      if not note_layer_t then return end 
      local filename = note_layer_t.instrument_filename
      if not filename then return end
      local samplebuffer_t = DATA:Actions_TemporaryGetAudio(filename)  
      if not samplebuffer_t then return end
      
      -- threshold
      local threshold_lin = WDL_DB2VAL(EXT.CONF_cropthreshold)
      local cnt_peaks = #samplebuffer_t 
      local loopst = 0
      local loopend = 1
      for i = 1, cnt_peaks do if math.abs(samplebuffer_t[i]) > threshold_lin then loopst = i/cnt_peaks break end end
      for i = cnt_peaks, 1, -1 do if math.abs(samplebuffer_t[i]) > threshold_lin then loopend = i/cnt_peaks break end end  
      TrackFX_SetParamNormalized( note_layer_t.tr_ptr, note_layer_t.instrument_pos, 13, loopst ) 
      TrackFX_SetParamNormalized( note_layer_t.tr_ptr, note_layer_t.instrument_pos, 14, loopend ) 
      DATA.upd = true
    end  
    
    --------------------------------------------------------------------------------
    function DATA:Action_ShiftOffset_NextTransient(note_layer_t)  
      if not note_layer_t then return end 
      
      local instrument_samplestoffs = note_layer_t.instrument_samplestoffs
      local instrument_sampleendoffs = note_layer_t.instrument_sampleendoffs
      local SAMPLELEN = note_layer_t.SAMPLELEN
      local transientahead  = EXT.CONF_stepmode_transientahead / SAMPLELEN
      
      local filename = note_layer_t.instrument_filename
      if not filename then return end
      local buf,srclen,SR = DATA:Actions_TemporaryGetAudio(filename)  
      if not buf then return end
       
      local bufsz = #buf
      local startID = math.floor(bufsz* instrument_samplestoffs)  
      local check_area = math.floor(0.05*SR)
      local step_skip = 10
      for i = startID+check_area, bufsz-check_area, step_skip do
        local curval = math.abs(buf[i])
        if curval < 0.01 then goto nextframe end 
        local rmsarea = 0
        for i2 = i , i+check_area do rmsarea = rmsarea + math.abs(buf[i2]) end rmsarea=rmsarea / check_area 
        if rmsarea < 0.05 then goto nextframe end
        
        if curval / rmsarea < 0.1  then
          
          -- search loudest peak
          local maxpeakID  = i
          local maxval = 0
          for i2 = i-step_skip , i+check_area+step_skip do 
            if math.abs(buf[i2]) > maxval then  maxpeakID = i2 end
            maxval = math.max(maxval, math.abs(buf[i2]) )
          end
          
          --[[ reverse search minimum
          local minpeakID  = maxpeakID
          local minval = 0
          for i2 = maxpeakID , maxpeakID-check_area,-1 do 
            if math.abs(buf[i2]) < minval then  minpeakID = i2 end
            minval = math.min(minval, math.abs(buf[i2]) )
            if math.abs(buf[i2]) < 0.01 then minpeakID = i2 break end 
          end]]
          
          local outID = maxpeakID
          out_shift = VF_lim(outID/bufsz - instrument_samplestoffs)
          
          break
          
        end
        ::nextframe::
      end
      if out_shift then out_shift = out_shift - transientahead end
      
      return out_shift
    end
      --------------------------------------------------------------------------------
    function DATA:Action_ShiftOffset(note_layer_t, mode, dir)
      if not (note_layer_t and note_layer_t.ISRS5K == true ) then return end
      local note = note_layer_t.noteID
      
      local instrument_samplestoffs = note_layer_t.instrument_samplestoffs
      local instrument_sampleendoffs = note_layer_t.instrument_sampleendoffs
      local SAMPLELEN = note_layer_t.SAMPLELEN
      if not (SAMPLELEN and SAMPLELEN > 0) then return end
      
      local rel_length = instrument_sampleendoffs-instrument_samplestoffs
      
      local step_value = DATA.boundarystep[EXT.CONF_stepmode].val
      
      local out_shift
      if step_value > 0 then -- seconds
        step_value_rel = step_value / SAMPLELEN
        out_shift = step_value_rel
       elseif step_value == -100 then -- search for next transient
        out_shift = DATA:Action_ShiftOffset_NextTransient(note_layer_t)
       elseif step_value < 0 then -- beats
        local step_value_beats = math.abs(step_value)
        local bpm = note_layer_t.SAMPLEBPM or 0
        if bpm == 0 then bpm = reaper.Master_GetTempo() end
        local beat_time = 60 / bpm
        out_shift = (beat_time * step_value_beats) / SAMPLELEN
      end
      
      if not out_shift then return end
      
      local outst = instrument_samplestoffs
      local outend = instrument_sampleendoffs
      
      -- shift start
        if mode == 0 then 
          outst = VF_lim(instrument_samplestoffs + out_shift*dir) 
          if EXT.CONF_stepmode_keeplen==1 then outend = VF_lim(instrument_sampleendoffs + out_shift*dir) end
      -- shift start to boundary
         elseif mode == 2 then
          if dir == -1 then 
            out_shift = -instrument_samplestoffs
           else
            out_shift = instrument_sampleendoffs-instrument_samplestoffs
          end 
          outst = VF_lim(instrument_samplestoffs + out_shift) 
          if EXT.CONF_stepmode_keeplen==1 then outend = VF_lim(instrument_sampleendoffs + out_shift) end     
          
      -- shift end
         elseif mode == 1 then 
           outend  = VF_lim(instrument_sampleendoffs + out_shift*dir) 
           if EXT.CONF_stepmode_keeplen==1 then outst = VF_lim(instrument_samplestoffs + out_shift*dir) end
      -- shift end to doundary
         elseif mode == 3 then 
          if dir == -1 then 
            out_shift = - instrument_sampleendoffs
           else
            out_shift = 1-instrument_sampleendoffs
          end
          outend  = VF_lim(instrument_sampleendoffs + out_shift) 
          if EXT.CONF_stepmode_keeplen==1 then outst = VF_lim(instrument_samplestoffs + out_shift) end   
        end
      
      if outend - outst < 0.01 then return end
      note_layer_t.instrument_samplestoffs = outst
      note_layer_t.instrument_sampleendoffs = outend
      TrackFX_SetParamNormalized( note_layer_t.tr_ptr, note_layer_t.instrument_pos, 13, outst ) 
      TrackFX_SetParamNormalized( note_layer_t.tr_ptr, note_layer_t.instrument_pos, 14, outend )
      DATA.upd = true
      DATA.peakscache[note]  = nil
    end  
    
    ------------------------------------------------------------------------------------------   
    function DATA:CollectDataInit_PluginParametersMapping_Get() 
      DATA.plugin_mapping = table.loadstring(VF_decBase64(EXT.CONF_plugin_mapping_b64)) or {}
    end
    ------------------------------------------------------------------------------------------   
    function DATA:CollectDataInit_PluginParametersMapping_Set() 
      EXT.CONF_plugin_mapping_b64 = VF_encBase64(table.savestring(DATA.plugin_mapping))
      EXT:save()
    end  
    
    --------------------------------------------------------------------  
    function DATA:Auto_LoopSlice_CDOE(item) 
    
      local FFTsz = 512
      local window_overlap = 2
      local ED_sum = {positions = {}, values = {}, onsets = {}}
       
      -- init pointers
      local item_len = GetMediaItemInfo_Value( item, 'D_LENGTH' )
      local take = GetActiveTake(item)
      if not take or TakeIsMIDI(take ) then return end 
      local pcm_src  =  GetMediaItemTake_Source( take )
      local SR = reaper.GetMediaSourceSampleRate( pcm_src )  
      local window_spls = FFTsz
      local window_sec = window_spls / SR
      local samplebuffer = reaper.new_array(window_spls) 
      local accessor = CreateTakeAudioAccessor( take )
      
      -- grab [FFT magnitude & phase] per frame -> bin
      
      local i = 0
      local FFTt = {}
      for pos_seek = 0, item_len, window_sec/window_overlap do
        GetAudioAccessorSamples( accessor, SR, 1, pos_seek, window_spls, samplebuffer ) 
        
        local rms = 0
        for i = 1, window_spls do rms = rms + math.abs(samplebuffer[i]) end rms = rms / window_spls
        
        samplebuffer.fft_real(FFTsz, true, 1 ) 
        i = i + 1
        ED_sum.positions[i] = pos_seek--math.max(pos_seek +  window_sec/window_overlap)
        FFTt[i] = {rms=rms} 
        local bin2 = -1
        for val = 1, FFTsz-2, 2 do 
          local Re = samplebuffer[val]
          local Im = samplebuffer[val + 1]
          local magnitude = math.sqrt(Re^2 + Im^2)
          local phase = math.atan(Im, Re)
          local bin = 1 + (val - 1)/2
          FFTt[i][bin] = {magnitude=magnitude,phase=phase}
        end
      end
      samplebuffer.clear()
      reaper.DestroyAudioAccessor( accessor )
      
      -- calculate CDOE difference
      local sz = #FFTt[1]
      test = sz
      local hp = 30 -- DC offset / HP
      local lp = sz--math.floor(sz*0.5) -- slightly low pass
      ED_sum.values[1] = 0
      ED_sum.values[2] = 0
      for frame = 3, #FFTt do
        local rms = FFTt[frame].rms
        local t = FFTt[frame]
        local t_prev = FFTt[frame-1]
        local t_prev2 = FFTt[frame-2] 
        local sum = 0
        local Euclidean_distance, magnitude_targ, Im1, Im2, Re1, Re2
        for bin = hp, lp do
          magnitude_targ = t_prev[bin].magnitude
          phase_targ = t_prev[bin].phase + (t_prev[bin].phase - t_prev2[bin].phase) 
          Re2 = magnitude_targ * math.cos(phase_targ)
          Im2 = magnitude_targ * math.sin(phase_targ)
          Re1 = t[bin].magnitude * math.cos(t[bin].phase)
          Im1 = t[bin].magnitude * math.sin(t[bin].phase) 
          Euclidean_distance = math.sqrt((Re2 - Re1)^2 + (Im2 - Im1)^2)
          sum = sum + Euclidean_distance --*(1-bin/sz) -- weight to highs
        end 
        ED_sum.values[frame] = sum--^0.9 --* rms
      end 
      
      local szED = #ED_sum.values
      ED_sum.values[szED] =0
      --VF_Weight()
      --VF_NormalizeT(ED_sum.values)
      
      -- build threshold env
      ED_sum.weight_threshold = {}
      local threshold_area = DATA.loopcheck_trans_area_frame -- forward frame
      for i = 1, szED-threshold_area do 
        ED_sum.values[i] = ED_sum.values[i]
        local rms = 0
        for i2 = i, i+threshold_area do rms=rms+ED_sum.values[i2] end rms = rms / threshold_area
        ED_sum.weight_threshold[i] = rms 
      end
      for i = szED-threshold_area, szED do ED_sum.weight_threshold[i] = ED_sum.weight_threshold[szED-threshold_area] end
      ED_sum.values[1] = ED_sum.values[3]
      ED_sum.values[2] = ED_sum.values[3]
      
      VF_NormalizeT(ED_sum.weight_threshold)
      VF_NormalizeT(ED_sum.values, 0.001)
      -- apply compression
      for i = 1, szED do
        ED_sum.values[i] = ED_sum.values[i] * (1-ED_sum.weight_threshold[i])
      end
      VF_NormalizeT(ED_sum.values)
  
      -- get onsets
      local minval = 0.01
      local minareasum = DATA.loopcheck_trans_area_frame * minval
      local sz = #ED_sum.values 
      local val = 0 
      local lastid = 1
      for i = 1, sz-DATA.loopcheck_trans_area_frame do
        val = 0 
        if i==1 then  val = 1  end
        local curval = ED_sum.values[i]
        local arearms = 0
        local minpeak = math.huge
        local maxpeak = 0
        local minpeakID = i
        local maxpeakID = i
        for i2 = i, i+DATA.loopcheck_trans_area_frame do
          arearms = arearms + ED_sum.values[i2]
          if ED_sum.values[i2] > maxpeak then maxpeakID = i2 end
          maxpeak = math.max(maxpeak, ED_sum.values[i2])
          if ED_sum.values[i2] < minpeak then minpeakID = i2 end
          minpeak = math.min(minpeak, ED_sum.values[i2])
        end
        arearms = arearms / DATA.loopcheck_trans_area_frame
        if minpeak / arearms < 0.4  
          and minpeakID < maxpeakID
          and arearms > 0.2
          then 
          val = 1 
          lastid = i 
        end
        ::nextframe::
        ED_sum.onsets[i] = val
      end
      
      
      -- filter closer onsets
      for i = 1, sz-1 do
        if ED_sum.onsets[i] == 1 and ED_sum.onsets[i+1] == 1  then 
          local minpeak = math.huge
          local minpeakID = i
          for i2 = i, i+DATA.loopcheck_trans_area_frame do
            if ED_sum.values[i2] == 0 then break end
            if ED_sum.values[i2] < minpeak then minpeakID = i2 end
            minpeak = math.min(minpeak, ED_sum.values[i2])
          end
          
          for i2 = i, i+DATA.loopcheck_trans_area_frame do ED_sum.onsets[i2] =0 end
          ED_sum.onsets[minpeakID] =1 
        end
      end
      
      
      -- fine tune positions 
      local area = 0.05 -- sec
      local window_spls = math.floor(area*2 * SR)
      local samplebuffer = reaper.new_array(window_spls) 
      local accessor = CreateTakeAudioAccessor( take )
      for i = 2, sz do
        if ED_sum.onsets[i] == 1 then
          local pos_seek = ED_sum.positions[i] - area/2
          GetAudioAccessorSamples( accessor, SR, 1, pos_seek, window_spls, samplebuffer )
          local minval = math.huge
          local pos_min = ED_sum.positions[i]
          local val
          for i2 = 1, window_spls do
            val = math.abs(samplebuffer[i2])
            if val < minval then ED_sum.positions[i] = pos_seek + i2/SR end
            minval = math.min(minval, val)
          end
        end
      end
      samplebuffer.clear()
      reaper.DestroyAudioAccessor( accessor )
      
      -- fine tune
      return ED_sum
    end  
    ---------------------------------------------------------------------  
    function DATA:Auto_LoopSlice_extract_loopt(filename) 
      local loop_t= {}
      
      -- check by name
      local filter = EXT.CONF_loopcheck_filter:lower():gsub('%s+','')
      local words = {}
      for word in filter:gmatch('[^,]+') do words[word] = true end
      local test_filename = filename:lower():gsub('[%s%p]+','')
      for word in pairs(words) do if test_filename:match(word) then return end end
      
      -- build PCM
      local PCM_Source = PCM_Source_CreateFromFile( filename )
      local srclen, lengthIsQN = GetMediaSourceLength( PCM_Source )
      if lengthIsQN ==true or (srclen < EXT.CONF_loopcheck_minlen or srclen > EXT.CONF_loopcheck_maxlen) then 
        --PCM_Source_Destroy( PCM_Source )
        return
      end
      
      -- get bpm
      local bpm = 60 / (srclen / 4)
      if bpm < 80 then 
        bpm = bpm *2 
       elseif bpm >180 then 
        bpm = bpm /2
       else
        bpm = 0
      end
      if bpm%1 > 0.98 then  bpm = math.ceil(bpm) elseif bpm%1 < 0.02 then  bpm = math.floor(bpm) end
      
      -- add temp stuff for audio read
      local tr_cnt = CountTracks(DATA.proj)
      InsertTrackInProject( DATA.proj, tr_cnt, 0 )
      local temp_track  = GetTrack(DATA.proj, tr_cnt) 
      local temp_item = AddMediaItemToTrack( temp_track )
      local temp_take = AddTakeToMediaItem( temp_item )
      SetMediaItemTake_Source( temp_take, PCM_Source )
      SetMediaItemInfo_Value( temp_item, 'D_POSITION', 0 )
      SetMediaItemInfo_Value( temp_item, 'D_LENGTH',srclen ) 
      local CDOE = DATA:Auto_LoopSlice_CDOE(temp_item)
      if DATA.loopcheck_testdraw == 1 then
        DATA.temp_CDOE_arr = reaper.new_array(CDOE.values)
        DATA.temp_CDOE_arr2 = reaper.new_array(CDOE.onsets)
      end
      DeleteTrack( temp_track )
      
      -- form start/end offset
      if not (CDOE and CDOE.positions and CDOE.onsets) then return end
      local sz = #CDOE.onsets
      local frame_st
      for i = 1, sz do
        if CDOE.onsets[i] == 1 or i==sz then 
          if not frame_st then 
            frame_st = i 
           else
            local startframe = frame_st+2
            if frame_st == 1 then startframe = 1 end
            local endframe = math.min(sz,i+2)
            
            local pos_sec_st = CDOE.positions[startframe]
            local pos_sec_end = CDOE.positions[endframe]
            if pos_sec_st and pos_sec_end then
              local SOFFS = pos_sec_st / srclen
              local EOFFS = pos_sec_end / srclen
              loop_t[#loop_t+1] = {
                SOFFS = SOFFS,
                EOFFS = EOFFS,
                debug_len = pos_sec_end - pos_sec_st
              }
              frame_st = i
            end
          end
        end
      end
      
      
      if #loop_t<2 then return end
      
      return loop_t, bpm, srclen
    end
    ---------------------------------------------------------------------  
    function DATA:Auto_LoopSlice_ShareDATA(loop_t,note,filename,bpm) 
      PreventUIRefresh( 1 )
      Undo_BeginBlock2( DATA.proj)
      for i = 1, #loop_t do 
        local outnote = note + i-1  
        if outnote > 127 then break end
        loop_t[i].outnote = outnote 
        
        DATA:DropSample(
            filename, 
            outnote, 
            {
              layer=1,
              SOFFS=loop_t[i].SOFFS,
              EOFFS=loop_t[i].EOFFS,
              tr_name_add = '- slice '..i,
              SAMPLEBPM = bpm,
            }
          )
      end
      Undo_EndBlock2( DATA.proj , 'RS5k manager - drop and slice loop to pads', 0xFFFFFFFF ) 
      PreventUIRefresh( -1 )
    end
    --------------------------------------------------------------------- 
    function DATA:Auto_LoopSlice_CreateMIDI(stretchmidi, srclen,loop_t,note, bpm)
      if not (note and srclen and loop_t ) then return end
      if  DATA.MIDIbus and DATA.MIDIbus.tr_ptr and DATA.MIDIbus.valid == true then
        local new_item = CreateNewMIDIItemInProj( DATA.MIDIbus.tr_ptr, GetCursorPosition(), GetCursorPosition() + srclen )
        local take = GetActiveTake(new_item)
        for i = 1, #loop_t do 
          local outnote = note + i-1 
          if outnote > 127 then break end
          local pos_st = loop_t[i].SOFFS * srclen
          local pos_end = loop_t[i].EOFFS * srclen
          local startppqpos = MIDI_GetPPQPosFromProjTime( take, pos_st +GetCursorPosition()  )
          local endppqpos = MIDI_GetPPQPosFromProjTime( take, pos_end +GetCursorPosition()  )
          MIDI_InsertNote( take, false, false, startppqpos, endppqpos, 0, outnote, 100, false ) 
        end
        MIDI_Sort( take )
        
        SetMediaItemInfo_Value( new_item, 'B_LOOPSRC', 1)
        
        if stretchmidi == true and bpm ~= 0 then 
          local bpm_proj = Master_GetTempo()
          local outrate = bpm_proj / bpm
          if outrate > 2 then 
            outrate = outrate / 2 
           elseif outrate < 0.5 then 
            outrate = outrate * 2 
          end
          
          
          if outrate > 0.5 and outrate < 2 then 
            SetMediaItemTakeInfo_Value( take, 'D_PLAYRATE', outrate )
            SetMediaItemInfo_Value( new_item, 'D_LENGTH',srclen/outrate ) 
          end
        end
      end
    end
    ---------------------------------------------------------------------  
    function DATA:Auto_LoopSlice(note, count)   -- test audio framgment if it contain slices
      function __f_loopslice() end
      if EXT.CONF_loopcheck&1==0 then return end  
      
      local loop_t = {}
      local createMIDI,createPattern
      local retval, filename = reaper.ImGui_GetDragDropPayloadFile( ctx, 0 )
      local bpm, srclen
      
      -- if ask then stop to RESTORE collected data
        if DATA.temp_loopslice_askforadd and DATA.temp_loopslice_askforadd.confirmed == true then 
          loop_t = CopyTable(DATA.temp_loopslice_askforadd.loop_t)
          note = DATA.temp_loopslice_askforadd.note
          filename = DATA.temp_loopslice_askforadd.filename
          bpm = DATA.temp_loopslice_askforadd.bpm
          srclen = DATA.temp_loopslice_askforadd.srclen
          createMIDI = DATA.temp_loopslice_askforadd.createMIDI
          stretchmidi = DATA.temp_loopslice_askforadd.stretchmidi
          createPattern = DATA.temp_loopslice_askforadd.createPattern
          
          DATA.temp_loopslice_askforadd = nil
          goto applycollecteddata
         else 
          loop_t, bpm, srclen = DATA:Auto_LoopSlice_extract_loopt(filename) 
        end
      
      
      -- if ask then stop to SAVE collected data
        if not DATA.temp_loopslice_askforadd then 
          if not (loop_t and #loop_t>1) then return end 
          DATA.temp_loopslice_askforadd = 
          { note=note,
            loop_t=loop_t,
            filename = filename,
            bpm = bpm,
            srclen =srclen,
            createMIDI = false,
            stretchmidi = true,
            createPattern = false,
          }
          
          local do_not_share = true
          return false, do_not_share
        end 
      
      ::applycollecteddata::
      DATA:Auto_LoopSlice_ShareDATA(loop_t,note,filename,bpm)  
      if createMIDI==true then 
        DATA:Auto_LoopSlice_CreateMIDI(stretchmidi, srclen,loop_t, note, bpm) 
       elseif createPattern==true then 
        DATA:Auto_LoopSlice_CreatePattern(loop_t) 
      end
      
      if #loop_t>1 then return true end
      
    end
    
    ------------------------------------------------------------------------------------------ 
    function DATA:CollectDataInit_LoadCustomPadStuff() 
      DATA.padcustomnames = {}
      local str = EXT.UI_padcustomnames
      -- 4.57 patch fixing extstate multiline issue https://forum.cockos.com/showthread.php?t=298318
      local strB64 = EXT.UI_padcustomnamesB64
      if str~='' then
        EXT.UI_padcustomnamesB64 = VF_encBase64(EXT.UI_padcustomnames)
        EXT.UI_padcustomnames = ''
        EXT:save()
       else
        str = VF_decBase64(strB64)
      end
      if str == '' then return end
      for pair in str:gmatch('[%d]+%=".-"') do
        local id, val = pair:match('([%d]+)="(.-)%"')
        if id and val then 
          id = tonumber(id)
          if id then DATA.padcustomnames[id] = val end
        end
      end
      
      DATA.padautocolors = {}
      local str = EXT.UI_padautocolors
      -- 4.57 patch fixing extstate multiline issue https://forum.cockos.com/showthread.php?t=298318
      local strB64 = EXT.UI_padautocolorsB64
      if str~='' then
        EXT.UI_padautocolorsB64 = VF_encBase64(EXT.UI_padautocolors)
        EXT.UI_padautocolors = ''
        EXT:save()
       else
        str = VF_decBase64(strB64)
      end
      
      if str == '' then return end
      for pair in str:gmatch('[%d]+%=".-"') do
        local id, val = pair:match('([%d]+)="(.-)%"')
        if id and val then 
          id = tonumber(id)
          if id then DATA.padautocolors[id] = tonumber(val) end
        end
      end
      
      
    end
    ------------------------------------------------------------------------------------------   
    function DATA:CollectDataInit_ReadDBmaps()
      DATA.database_maps = {}
      for i = 1,8 do
        DATA.database_maps[i] = {}
        local dbmapchunk_b64 = EXT['CONF_database_map'..i]
        if dbmapchunk_b64 then 
          local dbmapchunk = VF_decBase64(dbmapchunk_b64)
          local map = {}
          local dbname = 'Untitled '..i
          for line in dbmapchunk:gmatch('[^\r\n]+') do 
            if line:match('NOTE(%d+)') then 
              local note = line:match('NOTE(%d+)')
              if note then note =  tonumber(note) end
              if note then
                local params = {}
                for param in line:gmatch('%<.-%>.-%<%/.-%>') do 
                  local key = param:match('%<(.-)%>')
                  local val = param:match('%<.-%>(.-)%<%/.-%>')
                  params[key] = tonumber(val ) or val
                end
                map[note] = params
              end
            end
            if line:match('DBNAME (.*)') then dbname = line:match('DBNAME (.*)') end
          end
          
          DATA.database_maps[i] = {
            valid = true, 
            dbmapchunk = dbmapchunk,
            map=map, 
            dbname = dbname}
                      
        end
      end
    end
    ------------------------------------------------------------------------------------------   
    function DATA:Sampler_ImportSelectedItems() 
      local note =  0
      if  DATA.parent_track.ext and DATA.parent_track.ext.PARENT_LASTACTIVENOTE then note = DATA.parent_track.ext.PARENT_LASTACTIVENOTE end
      
      
      Undo_BeginBlock2(DATA.proj)
      local items_to_remove = {}
      for  i = 1, CountSelectedMediaItems(-1) do
        local drop_data = {layer=1}
        local item = GetSelectedMediaItem(-1,i-1)
        
        local retval, GUID = reaper.GetSetMediaItemInfo_String( item, 'GUID', '', false ) 
        items_to_remove[GUID] = true
        
        local tk = GetActiveTake( item ) 
        if not(tk and not TakeIsMIDI( tk )) then goto nextitem end
        
        local section,src_len 
        local src = GetMediaItemTake_Source( tk)
        local src_len =  GetMediaSourceLength( src )
        
        -- handle reversed source
        if not src or (src and GetMediaSourceType( src ) == 'SECTION') then  
          parent_src =  GetMediaSourceParent( src ) 
          src_len =  GetMediaSourceLength( parent_src )
         else
          parent_src = src
        end
        
        -- handle section
        if parent_src then
          if GetMediaSourceType( src ) == 'SECTION' then 
            local retval, offs, len, rev = reaper.PCM_Source_GetSectionInfo( src )
            drop_data.SOFFS = offs / src_len
            drop_data.EOFFS = (offs + len)/ src_len
           elseif GetMediaSourceType( src ) == 'WAVE' then
            local take = GetActiveTake(item)
            local D_STARTOFFS = GetMediaItemTakeInfo_Value( take, 'D_STARTOFFS' )
            local D_LENGTH = GetMediaItemInfo_Value( item, 'D_LENGTH' )
            local D_PLAYRATE = GetMediaItemTakeInfo_Value( take, 'D_PLAYRATE' )
            drop_data.SOFFS = D_STARTOFFS  / src_len
            drop_data.EOFFS = (D_STARTOFFS + D_LENGTH*D_PLAYRATE)/ src_len
          end
        end  
        
        if parent_src then 
          local filenamebuf = GetMediaSourceFileName( parent_src )
          if filenamebuf then 
            filenamebuf = filenamebuf:gsub('\\','/')
            DATA:DropSample(filenamebuf,note+i-1, drop_data) 
          end
        end
        
        ::nextitem::
      end
      
      if EXT.CONF_importselitems_removesource == 1 then
        for itemGUID in pairs(items_to_remove ) do 
          local it = VF_GetMediaItemByGUID(DATA.proj, itemGUID)
          if it then DeleteTrackMediaItem(  reaper.GetMediaItemTrack( it ), it ) end
        end
      end
      Undo_EndBlock2(DATA.proj, 'RS5k manager - import selected items', 0xFFFFFFFF)
      
      UpdateArrange()
    end
    ---------------------------------------------------------------------
    function VF_GetMediaItemByGUID(optional_proj, itemGUID)
      local optional_proj0 = optional_proj or -1
      local itemCount = CountMediaItems(optional_proj);
      for i = 1, itemCount do
        local item = GetMediaItem(0, i-1);
        local retval, stringNeedBig = GetSetMediaItemInfo_String(item, "GUID", '', false)
        if stringNeedBig  == itemGUID then return item end
      end
    end 
    -------------------------------------------------------------------------------- 
    function DATA:Auto_Reposition_TrackGetSelection()
      DATA.TrackSelection = {}
      local cnt = CountTracks(-1)
      for i = 1, cnt do
        local track = GetTrack(-1,i-1)
        local GUID = GetTrackGUID( track )
        if IsTrackSelected( track ) then DATA.TrackSelection[GUID] = true end
      end
    end
    -------------------------------------------------------------------------------- 
    function DATA:Auto_Reposition_TrackRestoreSelection()
      local cnt = CountTracks(-1)
      for i = 1, cnt do
        local track = GetTrack(-1,i-1)
        local GUID = GetTrackGUID( track )
        SetTrackSelected( track, DATA.TrackSelection[GUID]==true )
      end 
      DATA.TrackSelection = {}
    end
    
    --------------------------------------------------------------------------------
    function DATA:CollectData_Always_StepPositions() 
      if not (DATA.proj and reaper.ValidatePtr(DATA.proj, 'ReaProject*')) then return end
      if not (DATA.parent_track and DATA.parent_track.valid == true and DATA.seq and DATA.seq.valid == true and DATA.seq.tk_ptr ) then return end
      DATA.seq.active_step = {}
      
      local curpos = GetCursorPositionEx( DATA.proj )--+0.01
      if GetPlayStateEx( DATA.proj  )&1==1 then curpos = GetPlayPositionEx( DATA.proj ) end
      
      local beats, measures, cml, curpos_fullbeats, cdenom = TimeMap2_timeToBeats( DATA.proj, curpos )
      local it_pos = DATA.seq.it_pos
      local it_pos_compensated = DATA.seq.it_pos_compensated
      local it_len = DATA.seq.it_len
      local it_end = it_pos + it_len
      if not (curpos>=it_pos and curpos<=it_end) then return end
      
      
      
      local patternsteplen = 0.25
      local patternlen =DATA.seq.ext.patternlen or 16
      local beats, measures, cml, patstart_fullbeats, cdenom = TimeMap2_timeToBeats( DATA.proj, it_pos_compensated ) 
      local pat_progress = (((curpos_fullbeats-patstart_fullbeats)/patternsteplen)/patternlen)%1
      
      testpatternlen= (curpos_fullbeats-patstart_fullbeats)
      local pat_beats_com = patternlen*patternsteplen
      DATA.seq.active_pat_progress = pat_progress
      DATA.seq.active_pat_step = math.floor(pat_progress*patternlen)+1
      
      for note in pairs(DATA.children) do 
        local step_cnt = -1
        if DATA.seq.ext.children[note] and DATA.seq.ext.children[note].step_cnt then step_cnt = DATA.seq.ext.children[note].step_cnt end
        if step_cnt == -1 then step_cnt = DATA.seq.ext.patternlen or EXT.CONF_seq_defaultstepcnt end
        local steplength = EXT.CONF_seq_steplength
        if DATA.seq.ext.children[note] and DATA.seq.ext.children[note].steplength then steplength = DATA.seq.ext.children[note].steplength end
        local available_steps_per_pattern = pat_beats_com / steplength
        local activestep = math.floor(available_steps_per_pattern * pat_progress)+1
        if step_cnt < patternlen then 
          activestep = activestep %step_cnt
          if activestep == 0 then activestep = step_cnt end
        end
        
        --DATA.children[note].activestep = activestep
        --DATA.children[note].available_steps_per_pattern = available_steps_per_pattern
        DATA.seq.active_step[note] = activestep
      end
      
      DATA.temp_pos_progress = pat_progress
      if not DATA.temp_pos_progress_last or (DATA.temp_pos_progress_last and DATA.temp_pos_progress_last ~= DATA.temp_pos_progress) then
        DATA:Launchpad_SendState()
      end
      DATA.temp_pos_progress_last = DATA.temp_pos_progress
    end
   
      --------------------------------------------------------------------------------  
    function VF_Open_URL(url) if GetOS():match("OSX") then os.execute('open "" '.. url) else os.execute('start "" '.. url)  end  end    
    --------------------------------------------------------------------- 
    function DATA:Choke_Read()  
      DATA.MIDIbus.choke_setup = {}
      local ret, midi_choke_Container = DATA:MIDI_Handler_Read() 
      if not ret then return end
      
      
      local tr =  DATA.MIDIbus.tr_ptr 
      local fxcnt = TrackFX_GetCount(tr)
      local retval, container_count = reaper.TrackFX_GetNamedConfigParm( tr, midi_choke_Container, 'container_count' )
      for subitem = 1, container_count do
        local choke_childID = 0x2000000 + subitem*(fxcnt+1) + (midi_choke_Container+1)
        local retval, fxname = reaper.TrackFX_GetNamedConfigParm( tr, choke_childID, 'renamed_name' )
        local dest,src = fxname:match('choke (%d+) by (%d+)')
        if src and tonumber(src) then src = tonumber(src) end
        if dest and tonumber(dest) then dest = tonumber(dest) end
        if dest and src then
          if not DATA.MIDIbus.choke_setup[dest] then DATA.MIDIbus.choke_setup[dest] = {} end 
          local retval, container_itemID = reaper.TrackFX_GetNamedConfigParm( tr, midi_choke_Container, 'container_item.'..(subitem-1) )
          DATA.MIDIbus.choke_setup[dest][src] = {exist = true, container_itemID = tonumber(container_itemID)}
        end
      end
    end  
    --------------------------------------------------------------------- 
    function DATA:MIDI_Handler_Read(allow_to_write)   
      if DATA.allow_container_usage ~= true then return end  
      if not DATA.MIDIbus.tr_ptr then return end 
      local container_name = DATA.MIDIhandler
      local tr =  DATA.MIDIbus.tr_ptr 
      local midi_choke_Container =  TrackFX_AddByName( tr, container_name, false, 0 ) 
      if allow_to_write~= true then 
        if midi_choke_Container == -1 then return end
       else 
        if midi_choke_Container == -1 then 
          midi_choke_Container =  TrackFX_AddByName( tr, 'Container', false, -1000 )
          TrackFX_SetNamedConfigParm( tr, midi_choke_Container, 'renamed_name', container_name )
          TrackFX_SetOpen( tr, midi_choke_Container, false ) 
        end 
        if midi_choke_Container == -1 then return end
      end
      DATA.MIDIbus.midi_choke_Container = midi_choke_Container
      return true, midi_choke_Container
    end  
    --------------------------------------------------------------------- 
    function DATA:Choke_Write()  
      -- get/init container ID
      local ret, midi_choke_Container = DATA:MIDI_Handler_Read(true) 
      if not ret then return end
      
      -- colect for remove 
      local tr =  DATA.MIDIbus.tr_ptr 
      local removeID = {}
      local retval, container_count = reaper.TrackFX_GetNamedConfigParm( tr, midi_choke_Container, 'container_count' )
      for dest in pairs(DATA.MIDIbus.choke_setup) do
        for src in pairs( DATA.MIDIbus.choke_setup[dest]) do
          if DATA.MIDIbus.choke_setup[dest][src].mark_for_remove == true then 
            removeID[DATA.MIDIbus.choke_setup[dest][src].container_itemID] = true
          end
        end
      end
      
      -- mark for add
      local add_FX = {}
      local addcnt = 0
      for dest in pairs(DATA.MIDIbus.choke_setup) do
        for src in pairs( DATA.MIDIbus.choke_setup[dest]) do
          if DATA.MIDIbus.choke_setup[dest][src].add == true then 
            if not add_FX[dest] then add_FX[dest] = {} end
            add_FX[dest][#add_FX[dest]+1] = src
            addcnt=addcnt+1
          end
        end
      end
      
      for fxID in spairs(removeID, function(t,a,b) return b < a end) do
        TrackFX_Delete( tr,fxID )
      end
      
      for dest in pairs(add_FX) do
        for id=1, #add_FX[dest] do
          local src = add_FX[dest][id]
          local choke_ID =  TrackFX_AddByName( tr, 'mpl_RS5K_manager_MIDIBUS_choke', false, -1 )
          local retval, container_count = reaper.TrackFX_GetNamedConfigParm( tr, midi_choke_Container, 'container_count' )
          local subitem = container_count + 1
          local choke_childID_dest = 0x2000000 + subitem*(TrackFX_GetCount(tr)+1) + (midi_choke_Container+1) 
          TrackFX_CopyToTrack( tr, choke_ID, tr, choke_childID_dest, true )
          local choke_childID_dest = 0x2000000 + subitem*(TrackFX_GetCount(tr)+1) + (midi_choke_Container+1) 
          TrackFX_SetOpen( tr, choke_childID_dest, false ) 
          TrackFX_SetNamedConfigParm( tr, choke_childID_dest, 'renamed_name', 'choke '..dest..' by '..src )
          TrackFX_SetParam( tr, choke_childID_dest, 0, src )
          TrackFX_SetParam( tr, choke_childID_dest, 1, dest )
        end
      end
      
      -- set obey note off
      if addcnt > 0 then
        for dest in pairs(add_FX) do DATA:Action_SetObeyNoteOff(dest) end
        DATA.upd = true 
      end
    end    
    --------------------------------------------------------------------- 
    function DATA:Action_SetObeyNoteOff(note)
      local note_t = DATA.children[note]
      if note_t and note_t.layers then
        for layer = 1, #note_t.layers do
          local note_layer_t = note_t.layers[layer]
          local obeynoteoff = TrackFX_GetParamNormalized( note_layer_t.tr_ptr, note_layer_t.instrument_pos, 11 )
          if note_layer_t.ISRS5K and obeynoteoff == 0 then TrackFX_SetParamNormalized( note_layer_t.tr_ptr, note_layer_t.instrument_pos, 11, 1 ) end
        end
      end
    end
    --------------------------------------------------------------------- 
    function DATA:MIDI_SysexHandler_fixmultiple(track,fx0)
      -- 4.57 patch
      local cnt = TrackFX_GetCount( track )
      for fx = cnt,1,-1 do
        local retval, buf = reaper.TrackFX_GetNamedConfigParm( track, fx-1, 'renamed_name' )
        if buf == 'sysex_handler' then 
          if fx0 ~= fx-1  then TrackFX_Delete( track, fx-1 ) end
        end
      end
    end
    --------------------------------------------------------------------- 
    function DATA:MIDI_SysexHandler_init(note, drop_tr)   
      local tr
      if not drop_tr then
        if not (DATA.children and DATA.children[note]) then return end
        tr =  DATA.children[note].tr_ptr 
       else 
        tr=drop_tr
      end
      
      if not tr then return end
      local dr_id = -1000
      if drop_tr then dr_id = 0 end
      local sysex_handler =  TrackFX_AddByName( tr, 'RS5K_manager_sysex_handler', false, dr_id )  
      if sysex_handler == -1 then sysex_handler = TrackFX_AddByName( tr, 'sysex_handler', false, 0 ) end
      
      if sysex_handler ~= -1 then  
       elseif dr_id == 0 then
        sysex_handler =  TrackFX_AddByName( tr, 'sysex_handler', false, 0 ) 
        if sysex_handler == -1 then sysex_handler =  TrackFX_AddByName( tr, 'RS5K_manager_sysex_handler', false, -1000 )  end
       else
        return
      end 
      
      if sysex_handler ~= -1 then
        TrackFX_SetNamedConfigParm( tr, sysex_handler, 'renamed_name', 'sysex_handler' )
        TrackFX_SetParam( tr, sysex_handler, 0, note ) -- set note
        TrackFX_SetOpen( tr, sysex_handler, false )  
        DATA:MIDI_SysexHandler_fixmultiple(tr,sysex_handler)
      end
      
      local midifilt_pos = TrackFX_AddByName( tr, 'midi_note_filter', false, 0) 
      if midifilt_pos ~= 0 then reaper.TrackFX_CopyToTrack( tr, midifilt_pos, tr, 0, true ) end
      return true
    end  
    --------------------------------------------------------------------- 
    function DATA:Action_RS5k_SYSEXMOD_ON(note, at_rs5k_drop, drop_tr, drop_rs5kpos)
      if DATA.children[note] then DATA.children[note].SYSEXMOD = true end
      if at_rs5k_drop==true then 
        DATA:WriteData_Child(drop_tr,{SET_SYSEXMOD=1})
        TrackFX_SetNamedConfigParm( drop_tr, drop_rs5kpos, 'MODE', 0 ) -- turn sample into freely configurable mode
        TrackFX_SetParam( drop_tr, drop_rs5kpos, 3, 0 ) -- set note start to 0
        TrackFX_SetParam( drop_tr, drop_rs5kpos, 4, 1 ) -- set note end to 127
        TrackFX_SetParam( drop_tr, drop_rs5kpos, 5, 0.5 - 0.5*64/80 ) -- set pitch start to -64
        TrackFX_SetParam( drop_tr, drop_rs5kpos, 6, 0.5 + 0.5*64/80 ) -- set pitch end to 64
        DATA:MIDI_SysexHandler_init(note, drop_tr) -- add sysex handler to child track
        return
      end
      
      
      Undo_BeginBlock2(-1) 
      local note_t = DATA.children[note]
      if note_t then 
        DATA:WriteData_Child(note_t.tr_ptr,{SET_SYSEXMOD=1})
        note_t.SYSEXHANDLER_isvalid = true 
      end
      if note_t and note_t.layers then
        for layer = 1, #note_t.layers do
          local note_layer_t = note_t.layers[layer]
          if note_layer_t.ISRS5K then 
            local track = note_layer_t.tr_ptr
            local fx = note_layer_t.instrument_pos 
            TrackFX_SetNamedConfigParm( track, fx, 'MODE', 0 ) -- turn sample into freely configurable mode
            TrackFX_SetParam( track, fx, 3, 0 ) -- set note start to 0
            TrackFX_SetParam( track, fx, 4, 1 ) -- set note end to 127
            TrackFX_SetParam( track, fx, 5, 0.5 - 0.5*64/80 ) -- set pitch start to -64
            TrackFX_SetParam( track, fx, 6, 0.5 + 0.5*64/80 ) -- set pitch end to 64
          end
        end
      end
      
      DATA:MIDI_SysexHandler_init(note) -- add sysex handler to child track
      Undo_EndBlock2(-1, 'Convert pad '..note..' to SysEx mode', 0xFFFFFFFF)
      
      
      --DATA.upd = true
      
    end
    --------------------------------------------------------------------- 
    function DATA:Action_RS5k_SYSEXMOD_OFF(note)
      Undo_BeginBlock2(-1) 
      local note_t = DATA.children[note]
      if note_t then DATA:WriteData_Child(note_t.tr_ptr,{SET_SYSEXMOD=0}) end
      
      if note_t and note_t.layers then
        for layer = 1, #note_t.layers do
          local note_layer_t = note_t.layers[layer]
          if note_layer_t.ISRS5K then 
            local track = note_layer_t.tr_ptr
            local fx = note_layer_t.instrument_pos 
            TrackFX_SetNamedConfigParm( track, fx, 'MODE', 1 )
            TrackFX_SetParam( track, fx, 3, note/127 )
            TrackFX_SetParam( track, fx, 4, note/127 ) 
            TrackFX_SetParamNormalized( track, fx, 5, 0.5 ) -- pitch for start
            TrackFX_SetParamNormalized( track, fx, 6, 0.5 ) -- pitch for end
          end
        end
      end
      
      -- remove handler
      local tr =  note_t.tr_ptr 
      local sysex_handler =  TrackFX_AddByName( tr, 'sysex_handler', false, 0 ) 
      if sysex_handler ~= -1 then TrackFX_Delete( tr, sysex_handler ) end
      
      Undo_EndBlock2(-1, 'Convert pad '..note..' to normal mode', 0xFFFFFFFF)
      
    end
    
    --------------------------------------------------------------------------------  
    function UI.VDragInt(ctx, str_id, size_w, size_h, v, v_min, v_max, formatIn, flagsIn, floor, default, image)
      
      ImGui.PushStyleVar(ctx, ImGui.StyleVar_FramePadding,1,1) 
      ImGui.PushStyleVar(ctx, ImGui.StyleVar_CellPadding,1, 1) 
      ImGui.PushStyleVar(ctx, ImGui.StyleVar_ItemSpacing,1, 1)
      ImGui.PushStyleVar(ctx, ImGui.StyleVar_ButtonTextAlign,0.5,0.5)
      ImGui.PushFont(ctx, DATA.font4) 
      
      local x,y = reaper.ImGui_GetCursorPos(ctx)
      local v_out
      local dx, dy = reaper.ImGui_GetMouseDelta( ctx )
      ImGui.PushStyleVar(ctx, ImGui.StyleVar_GrabMinSize,size_h/2)
      ImGui.PopStyleVar(ctx)
      
      ImGui.InvisibleButton( ctx, str_id, size_w, size_h, reaper.ImGui_ButtonFlags_None() )
      local x1, y1 = reaper.ImGui_GetItemRectMin( ctx )
      local x2, y2 = reaper.ImGui_GetItemRectMax( ctx )
      if reaper.ImGui_IsItemActivated(ctx) then 
        local x, y = reaper.ImGui_GetMousePos( ctx )
        DATA.temp_VDragInt_y = y
        DATA.temp_VDragInt_v = v
        DATA.temp_VDragInt_str_id = str_id
      end
      if reaper.ImGui_IsItemActive(ctx) and DATA.temp_VDragInt_y and DATA.temp_VDragInt_v and DATA.temp_VDragInt_str_id == str_id then
        local x, y = reaper.ImGui_GetMousePos( ctx )
        local dy = DATA.temp_VDragInt_y - y
        v_out = VF_lim(DATA.temp_VDragInt_v + dy/UI.dragY_res,v_min, v_max)
        if floor then v_out = math.floor(v_out) end
      end
      if ImGui.IsItemHovered(ctx) then DATA.temp_ismousewheelcontrol_hovered = true end
      if default and ImGui.IsItemHovered(ctx) and ImGui.IsMouseDoubleClicked(ctx, ImGui.MouseButton_Left) then v_out = default dy = 1 end
      local deact = ImGui.IsItemDeactivated(ctx)
      local rightclick = ImGui.IsItemHovered(ctx) and ImGui.IsMouseClicked(ctx, ImGui.MouseButton_Right)
      local vertical, horizontal = ImGui.GetMouseWheel( ctx )
      local mousewheel = ImGui.IsItemHovered(ctx) and vertical ~= 0
      if mousewheel then mousewheel = math.abs(vertical)/vertical end
        
      ImGui.SetCursorPos(ctx,x,y)
      
      if formatIn then ImGui.Button(ctx, formatIn..str_id..'info',size_w, size_h) end
    
      
      ImGui.PopFont(ctx) 
      ImGui.PopStyleVar(ctx,4)
      
      -- prevent commit when mouse is not moving
      if dy == 0 then return nil, nil,deact,rightclick,mousewheel end 
      if v_out then return  true,v_out,deact,rightclick,mousewheel end
    end
    
    ---------------------------------------------------------------------  
    function UI.Drop_UI_interaction_pad(note) 
      if note == -1 then
        local starting_emptynote = 36
        for i=starting_emptynote,127 do if not DATA.children[i] then 
          note = i 
          DATA.parent_track.ext.PARENT_LASTACTIVENOTE = note
          DATA.temp_scroll_to_note = note
          DATA:WriteData_Parent()
          break 
          end 
        end
      end
      
      -- validate is file or pad dropped
      local retval, count = ImGui.AcceptDragDropPayloadFiles( ctx, 127, ImGui.DragDropFlags_None )
      if retval then 
        DATA.upd2.refreshscroll = 1 --UI.draw_Seq() refresh
        local loop_success
        if count == 1 then loop_success, do_not_share = DATA:Auto_LoopSlice(note, count) end
        
        if do_not_share == true then return end
        
        
        -- import sample directly
        if loop_success ~= true then
        
          Undo_BeginBlock2(DATA.proj )
          for i = 1, count do 
            local retval, filename = reaper.ImGui_GetDragDropPayloadFile( ctx, i-1 )
            if not retval then return end  
            DATA:DropSample(filename, note + i-1, {layer=1})
          end 
          Undo_EndBlock2( DATA.proj , 'RS5k manager - drop samples to pads', 0xFFFFFFFF ) 
        end
          
        
       else
        local retval, payload = reaper.ImGui_AcceptDragDropPayload( ctx, 'moving_pad', '', ImGui.DragDropFlags_None )-- accept pad drop
        if retval and DATA.parent_track.ext.PARENT_LASTACTIVENOTE then 
          Undo_BeginBlock2(DATA.proj )
          local retval, types, payload, is_preview, is_delivery = reaper.ImGui_GetDragDropPayload( ctx )
          if retval and tonumber(payload)then 
            DATA:Drop_Pad(tonumber(payload),note)  
            gmem_write(1026,11|(DATA.parent_track.ext.PARENT_LASTACTIVENOTE<<8)|(note<<16))
          end  
          Undo_EndBlock2( DATA.proj , 'RS5k manager - move pad', 0xFFFFFFFF ) 
        end 
      end
    end
    -------------------------------------------------------------------  
    function DATA:Launchpad_SendState()
      if EXT.CONF_seq_stuffMIDItoLP == 0 then return end
      if not DATA.lp_matrix then return end
      
      
      -- form matrix
        local row = 0
        for note in spairs(DATA.seq.active_step) do
          row = row + 1
          
          if DATA.lp_matrix[row] then for col = 1, 8 do DATA.lp_matrix[row][col].state = 0 end end -- reset row states
          for step = 1, 8 do
            if    DATA.seq 
              and DATA.seq.ext 
              and DATA.seq.ext.children 
              and DATA.seq.ext.children[note] 
              and DATA.seq.ext.children[note].steps 
              and DATA.seq.ext.children[note].steps[step] 
              and DATA.seq.ext.children[note].steps[step].val 
              and DATA.seq.ext.children[note].steps[step].val == 1 
              and DATA.lp_matrix[row] 
              and DATA.lp_matrix[row][step] then 
              DATA.lp_matrix[row][step].state = 2
            end
          end
          local active_step = DATA.seq.active_step[note]
          if DATA.lp_matrix[row] and DATA.lp_matrix[row][active_step] then
            DATA.lp_matrix[row][active_step].state = 1
          end
        end
      
      local col_state
      for row = 1, 8 do
        for col = 1, 8 do
          col_state = 0
          if DATA.lp_matrix[row][col].state == 1 then col_state = 21 end
          if DATA.lp_matrix[row][col].state == 2 then col_state = 13 end
          StuffMIDIMessage( 16+EXT.CONF_midioutput, 0x90, DATA.lp_matrix[row][col].MIDI_note, col_state )
        end
      end 
      
      
    end 
    ----------------------------------------------------------------------
    function DATA:CollectData_Always_LaunchPadInteraction()
      if DATA.seq_functionscall ~= true then return end
      if not (DATA.seq and DATA.seq.ext and DATA.seq.ext.children) then return end
      
      local playingnote = gmem_read(1029)
      if playingnote ~= -1 then
        gmem_write(1029,-1)
        
        col_edit = playingnote%10 -- step
        row_edit = math.floor(playingnote/10) -- note
        local note_edit
        local step_edit = col_edit
        
        for note in pairs(DATA.seq.ext.children) do if DATA.seq.ext.children[note].IDorder == row_edit then note_edit = note break end end
        if note_edit  and step_edit then  
        
          
          if not DATA.seq.ext.children[note_edit].steps then DATA.seq.ext.children[note_edit].steps = {} end
          if not DATA.seq.ext.children[note_edit].steps[step_edit] then DATA.seq.ext.children[note_edit].steps[step_edit] = {val = 0} end
          DATA.seq.ext.children[note_edit].steps[step_edit].val = DATA.seq.ext.children[note_edit].steps[step_edit].val~1
          DATA:_Seq_Print()
          DATA:Launchpad_SendState()
        end
        
      end
      
      
    end
    
    --[[-------------------------------------------------------------------  
    function DATA:Auto_StuffSysex_dec2hex(dec)  local pat = "%02X" return  string.format(pat, dec) end
    function DATA:Auto_StuffSysex() 
      if EXT.UI_drracklayout == 2 then DATA:Auto_StuffSysex_sub('set/refresh active state') end 
    end  
    
    ---------------------------------------------------------------------  
    function DATA:Auto_StuffSysex_sub(cmd) local SysEx_msg  
      if  not (EXT.CONF_launchpadsendMIDI == 1 and EXT.UI_drracklayout == 2) then return end 
      -- search HW MIDI out 
        local is_LPminiMK3
        local is_LPProMK3
        --local LPminiMK3_name = "LPMiniMK3 MIDI"
        local LPminiMK3_name = "MIDIOUT2 (LPMiniMK3 MIDI)"
        local LPProMK3_name = "LPProMK3 MIDI"
        for dev = 1, reaper.GetNumMIDIOutputs() do
          local retval, nameout = reaper.GetMIDIOutputName( dev-1, '' )
          if retval and nameout == LPminiMK3_name then HWdevoutID =  dev-1 is_LPminiMK3 = true break end --nameout:match(LPminiMK3_name)
          if retval and nameout == LPProMK3_name then HWdevoutID =  dev-1 is_LPProMK3 = true break end 
        end
        if not HWdevoutID then return end
      
      -- action on release
      if cmd == 'on release' then -- set to key layout
        if is_LPminiMK3 ==true then 
          SysEx_msg = 'F0h 00h 20h 29h 02h 0Dh 00h 05 F7h' 
          DATA:Launchpad_StuffSysex(SysEx_msg, HWdevoutID) 
        end
        if is_LPProMK3 ==true then 
          SysEx_msg = 'F0h 00h 20h 29h 02h 0Eh 00h 04 00 00h F7h' 
          DATA:Launchpad_StuffSysex(SysEx_msg, HWdevoutID) 
        end
      end
      
      
      
      -- 
        if cmd == 'set/refresh active state' then
          SysEx_msg = 'F0h 00h 20h 29h 02h 0Dh 00h 7F F7h' 
          DATA:Launchpad_StuffSysex(SysEx_msg, HWdevoutID) 
        end
      
      --if cmd == 'drum layout' then
        if cmd == 'drum mode' then
          if is_LPminiMK3 ==true then 
            SysEx_msg = 'F0h 00h 20h 29h 02h 0Dh 10h 01 F7h' 
            DATA:Launchpad_StuffSysex(SysEx_msg, HWdevoutID) 
          end
        end
        
        
        if is_LPminiMK3 ==true or is_LPProMK3==true then 
          for ledId = 0, 81 do
            if DATA.children and DATA.children[ledId] and DATA.children[ledId].I_CUSTOMCOLOR then
              local msgtype = 90
              if DATA.parent_track and DATA.parent_track.ext and DATA.parent_track.ext.PARENT_LASTACTIVENOTE and DATA.parent_track.ext.PARENT_LASTACTIVENOTE == ledId then msgtype = 92 end
              SysEx_msg = msgtype..' '..string.format("%02X", ledId)..' 16'
              DATA:Launchpad_StuffSysex(SysEx_msg, HWdevoutID) 
             else
              local col = '00'
              if DATA.parent_track and DATA.parent_track.ext and DATA.parent_track.ext.PARENT_LASTACTIVENOTE and DATA.parent_track.ext.PARENT_LASTACTIVENOTE == ledId then col = '03' end
              SysEx_msg = '90 '..string.format("%02X", ledId)..' '..col
              DATA:Launchpad_StuffSysex(SysEx_msg, HWdevoutID) 
            end
          end
        end
        
      end]]
      
      
      --[[
      
      if cmd == 'programmer mode' then
        if is_LPminiMK3 ==true then 
          SysEx_msg = 'F0h 00h 20h 29h 02h 0Dh 00h 7F F7h' 
          DATA:Launchpad_StuffSysex(SysEx_msg, HWdevoutID) 
        end
        if is_LPProMK3 ==true then 
          SysEx_msg = 'F0h 00h 20h 29h 02h 0Eh 00h 11 00 00h F7h'
          DATA:Launchpad_StuffSysex(SysEx_msg, HWdevoutID) 
        end
      end
      
      
      
      if cmd == 'programmer mode: set colors' then
        
          local colorstr = '' 
          for ledId = 0, 81 do
            if DATA.children and DATA.children[ledId] and DATA.children[ledId].I_CUSTOMCOLOR then
              local lightingtype = 3 
              local color = ImGui.ColorConvertNative(DATA.children[ledId].I_CUSTOMCOLOR) & 0xFFFFFF 
              r = math.floor(((color>>16)&0xFF) * 0.5)
              g = math.floor(((color>>8)&0xFF) * 0.5)
              b = math.floor(((color>>0)&0xFF) * 0.5)
              colorstr = colorstr..
                DATA:Auto_StuffSysex_dec2hex(lightingtype)..' '..
                DATA:Auto_StuffSysex_dec2hex(ledId)..' '..
                string.format("%X", r)..' '..
                string.format("%X", g)..' '..
                string.format("%X", b)..' ' 
             else
              local lightingtype = 0
              local palettecol = 0
              colorstr = colorstr..
                DATA:Auto_StuffSysex_dec2hex(lightingtype)..' '..
                DATA:Auto_StuffSysex_dec2hex(ledId)..' '..
                DATA:Auto_StuffSysex_dec2hex(palettecol)..' '
            end
          end
          
          if is_LPminiMK3 ==true then SysEx_msg = 'F0h 00h 20h 29h 02h 0Dh 03h '..colorstr..'F7h' end
          if is_LPProMK3 ==true then SysEx_msg = 'F0h 00h 20h 29h 02h 0Eh 03h '..colorstr..'F7h' end 
    
      end
      
    end ]]
    
    --------------------------------------------------------------------------------  
    function UI.draw_Rack_Pads_controls_handlemouse(note_t,note,popup_content0)
      if note == -1 then return end
      local popup_content
      if not popup_content0 then popup_content = 'pad' else popup_content = popup_content0 end
      if not (note_t and note_t.TYPE_DEVICE==true) and  ImGui.BeginDragDropTarget( ctx ) then  
        UI.Drop_UI_interaction_pad(note) 
        ImGui_EndDragDropTarget( ctx )
      end 
      
      if ImGui.IsItemActivated(ctx) then 
        if EXT.UI_clickonpadplaysample ==1 then DATA:Sampler_StuffNoteOn(note) end
      end
      
      if ImGui.IsItemClicked( ctx, ImGui.MouseButton_Right ) then 
        DATA.parent_track.ext.PARENT_LASTACTIVENOTE=note
        DATA:WriteData_Parent() 
        DATA.upd = true
        if popup_content0 ~= 'seq_pad' then 
          if UI.anypopupopen==true then DATA.trig_closepopup = true else DATA.trig_openpopup = popup_content end
        end
      end
      
      if ImGui.IsItemClicked(ctx,ImGui.MouseButton_Left) then -- click select track
        if EXT.UI_clickonpadselecttrack == 1 and note_t then SetOnlyTrackSelected( note_t.tr_ptr )  end
        if EXT.UI_clickonpadscrolltomixer == 1 and note_t then  SetMixerScroll( note_t.tr_ptr )  end
        DATA.parent_track.ext.PARENT_LASTACTIVENOTE=note 
        DATA.padcustomnames_selected_id = note
        DATA.padautocolors_selected_id = note
        DATA.settings_cur_note_database=note
        DATA:WriteData_Parent() 
        DATA.upd = true 
        if popup_content0 == 'seq_pad' then DATA:Sampler_StuffNoteOn(note) end
      end
       
      if ImGui.IsItemDeactivated( ctx ) then 
        if EXT.UI_pads_sendnoteoff == 1 then DATA:Sampler_StuffNoteOn(note, 0, true) end
      end
      
      if popup_content0 ~= 'seq_pad' then 
        if note_t and note_t.noteID and ImGui.BeginDragDropSource( ctx, ImGui.DragDropFlags_None ) then  
          ImGui.SetDragDropPayload( ctx, 'moving_pad', note_t.noteID, ImGui.Cond_Once )
          ImGui.Text(ctx, 'Move pad ['..note_t.noteID..'] '..note_t.P_NAME)
          DATA.paddrop_ID = note_t.noteID
          if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Mod_Ctrl()) then DATA.paddrop_mode = 1 end
          ImGui.EndDragDropSource(ctx)
        end
      end
    end
    -----------------------------------------------------------------------------------------       
  _main()
   