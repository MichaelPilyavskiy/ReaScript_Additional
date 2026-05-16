-- @description RS5k manager
-- @version 5.0 02.03.26
-- @author MPL
-- @website https://forum.cockos.com/showthread.php?t=207971
-- @about Script for handling ReaSamplomatic5000 data on group of connected tracks
-- @provides
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
--    + Overhaul for all the code
--    + UI: move control block above rack
--    + UI: various sizing policy improvements
--    + UI/Sampler: move color/FX buttons left to device/layer name
--    + UI/Sampler: move switch sample buttons to icons at peaks view
--    + UI/Sampler: show sample path above sample peaks
--    + UI/Sampler: draw ADR controls as flags
--    + UI/Sampler: scale ADSR controls at tune change
--    + UI/DatabaseMaps: separate tab, display all mapping
--    + Macro: draw/edit real limits instead drag values
--    + Macro: fix show multiple connections
--    + MIDI bus: allow to use parent track as MIDI bus (REAPER 7.61+)
--    # Structure: do not validate device children by external state data, use 2nd level children inside device folder as reference
--    # Knob: (replicating Ableton behaviour a bit more ) shift to tweak precisely, doubleclick to reset, doubleclick on value to enter manually
--    # Peaks: slightly reduce noise threshold for displayed peaks
--    # Peaks: improve peaks caching
--    # Pad overview: always shown for 4x4 and keys layout, hide otherwise
--    + Layout: remove layout creator sliders, add text editor
--    + Layout: add launchpad layout generator (full 8x8 and botton left-block-only)
--    # Sampler/Tune: remove additional controls, use normal drag to change semitones, shift drag to fine tune, ctrl drag to change octaves
--    + Sampler/switching samples: use caching of folder tree instead read full tree each time switching sample
--    + Sampler/switching samples: recalculate adaptive ADR limits immediately
--    + Sampler: limit adaptive attack to 0.2 by default
--    + Sampler: limit adaptive decay to 1 by default
--    + Sampler: when tweaking attack or decay, immediately recalculate adaptive limits
--    + Sampler: when tweaking tune, immediately recalculate adaptive limits
--    + Settings/Drum Rack/Pad: on drop replace sample on existing pads
--    + Settings/MIDI/Pad: Active note follow incoming note, when stopped or paused


  
--[[ TODO
  notifications
    database change
    database load / switch
    
  drop
    database
    next/prev/rnd sample
    pad overview
    device child list
    device name 
    sampler peaks
  
  --
  Rs5k subprojects https://forum.cockos.com/showpost.php?p=2905141&postcount=904
  
  sampler
    grid
    navigator
  tabs 
    rack
    macro
    seq
    browser
    actions
    mixer
  settings
    red when custom template file invalid
    allow to use rack parent as midi bus
    UI_shownotenumbers_at_pads
    UI_colRGBA_windowBg
    CONF_ADSR_A_maxadaptive
    hide children TCP -> ...for new tracks
  theme 
    peak color UI_colRGBA_peaks
  midi
   filter note off at input FX
  rack
    pad
      follow note only when stopped
    pad/led
      single led, popup to draw all related info  
      show if autorange enabled for this pad
  seq
    if pattern has same GUId than oth er BUT not pooled or pool is diffent https://forum.cockos.com/showthread.php?p=2866575
    pattern groups
    launchpad interaction as a sequencer
  sampler
    hot record from master bus 
    compressor
    transient shaper
    add sends to reverb, delay inside based on existing send tracks (predefine using sends folder name) // only for device / toplevel child
    better handle global tweaks
    FPC style rangesplit  
  auto
    auto switch midi bus record arm if playing with another rack 
    autocolor by content  
  on sample add
    wildcards - device name
    wildcards - children - #notenuber #noteformat #samplename
    wildcards - samples path   
  autoslice
    set minimal length
    do not allow slices with low RMS (glue with previeos slice) 
  autolufs
    use as a compensation
  export/import
    whole rack in custom format
    C:\ProgramData\Ableton\Live 12 Suite\Resources\Core Library\Samples\Multisamples\Drum Machines\808
    C:\ProgramData\Ableton\Live 12 Suite\Resources\Core Library\Racks\Drum Racks\Drum Machines
]]
  
  
  -- NOT reaper NOT imgui NOT gfx

  for key in pairs(reaper) do _G[key]=reaper[key] end
  local vrsmin = 7.06 -- choke features
  local app_vrs = tonumber(GetAppVersion():match('[%d%.]+'))
  if app_vrs < vrsmin then return reaper.MB('This script require REAPER '..vrsmin..'+','',0) end
  local prerecsends_available = vrsmin >= 7.61
  
  if not reaper.ImGui_GetBuiltinPath then return reaper.MB('This script require ReaImGui extension','',0) end
  package.path =   reaper.ImGui_GetBuiltinPath() .. '/?.lua'
  ImGui = require 'imgui' '0.10'
  
  local is_new_value,filename,sectionID,cmdID,mode,resolution,val,contextstr = reaper.get_action_context()
  local Entry = reaper.ReaPack_GetOwner( filename )
  local reapackentry = {reaper.ReaPack_GetEntryInfo( Entry )} -- retval, repo, cat, pkg, desc, ptype, ver, author, flags, fileCount = 
  rs5kman_vrs = tonumber(reapackentry[7])
  
  DATA = {
    
    -- VARIABLES ------------------------------------
      var = {
        sampler = {}, 
        rack = {
          var = {},
          children = {},
          parent = {
            params={}
          },
          midibus = {
            choke = {}
          },
          layout = {},
          macro = {},
          peaks = { 
            children = {},
          },
        },
        
        UI_name = 'RS5K manager',
        alpha_normal = 0x70,
        alpha_normal_alt = 0x40,
        alpha_active = 0xFF,
        alpha_hovered = 0xCC,
        mouseY_resolution = 200,
        mouseY_resolution_tune = 400,
        ADSR_A_reaper_normalize_ratio = 2,
        ADSR_D_reaper_normalize_ratio = 15,
        ADSR_R_reaper_normalize_ratio = 2,
        ADSR_A_maxadaptive = 0.2,
        ADSR_D_maxadaptive = 1,
        db_maps_allowed_cnt = 8,
        
        ext = { -- extstate variables
          ES_key = 'MPL_RS5K manager',
          UI_font='Arial',
          CONF_plugin_mapping_b64 = '', 
          CONF_database_map1 = '',
          CONF_database_map2 = '',
          CONF_database_map3 = '',
          CONF_database_map4 = '',
          CONF_database_map5 = '',
          CONF_database_map6 = '',
          CONF_database_map7 = '',
          CONF_database_map8 = '',
          UI_padcustomnamesB64 = '', -- since 4.57
          UI_padautocolorsB64 = '',-- since 4.57
          CONF_midiinput = 63, -- 63 all 62 midi kb
          CONF_midioutput = -1, 
          CONF_midichannel = 0, -- 0 == all channels
          CONF_ignoreDBload = 0, 
          UI_colRGBA_maintheme = 0x33823300, 
          UI_colRGBA_buttonBg = 0x90909000,
          UI_allowshortcuts = 1, 
          CONF_databasemaps_currentID = 1,  
          UI_drracklayout = 0,
          UI_drracklayout_customB64 = '',
          UI_recentinput_lag = 0.05, -- diff between closer MIDI triggers, seconds 
          UI_incomingnoteselectpad = 0, 
          UI_colRGBA_paddefaultbackgr = 0x1C1C1C7F ,
          UI_colRGBA_paddefaultbackgr_inactive = 0x6060603F, 
          UI_colRGBA_padctrl = 0x4F4F4FFF, 
          UI_allowdoplayeronpad = 0,
          UI_clickonpadplaysample = 0, 
          UI_col_tinttrackcoloralpha = 0x7F, 
          CONF_onadd_autosetrange = 0, 
          UI_showplayingmeters = 1,
          UI_shownotenumbers_at_pads = 1,
          UI_pads_sendnoteoff = 1,
          CONF_default_velocity = 120, -- trigger pads manually
          UI_colRGBA_windowBg = 0x303030FF, 
          CONF_onadd_copysubfoldname = 'RS5kmanager_samples', 
          CONF_onadd_copytoprojectpath = 0,  
          CONF_onadd_autoLUFSnorm = -14,  
          CONF_onadd_autoLUFSnorm_toggle = 0,
          CONF_onadd_takeparentcolor = 0, 
          CONF_onadd_newchild_trackheight = 0,
          CONF_onadd_newchild_trackheightflags = 0, -- &1 folder collapsed &2 folder supercollapsed &4 hide tcp &8 hide mcp 
          CONF_onadd_newchild_trackheight_lock = 0,
          CONF_autocol = 0, -- color to global pad colors override 
          CONF_onadd_customtemplate = '', 
          CONF_onadd_ordering = 0, -- 0 sorted by note 1 at the top 2 at the bottom
          CONF_onadd_float = 0,
          CONF_onadd_maxvoices = 1,
          CONF_onadd_minvel = 1,
          CONF_onadd_maxvel = 127,
          CONF_onadd_mingain = 0, 
          CONF_onadd_obeynoteoff = 1,
          CONF_onadd_ADSR_A = 0,
          CONF_onadd_ADSR_D = 15,
          CONF_onadd_ADSR_S = 0,
          CONF_onadd_ADSR_R = 0.02, 
          CONF_onadd_ADSR_flags = 0,--&1 A &2 D &4 S &8 R
          CONF_onadd_sysexmode = 0,
          UI_colRGBA_peaks = 0xFFFFFF40, 
          UI_preference_page = '',
          UI_clickonpadselecttrack = 1,
          UI_clickonpadscrolltomixer = 0, 
          CONF_onadd_replaceexistingpads = 0,
          CONF_onadd_renametrack = 1,
          CONF_autorenamemidinotenames = 1|2,
          CONF_useprerecsends = 1,
          UI_noteselpadoverride_autofollow = 1,
        },
        
        
        UI_linear = {
          spacingX = 3,
          spacingY = 3,
          round_corners = 3,
          scrollbarW = 10, 
          mainwindW_min = 380,
          settingsW_min = 600,
          mainwindH_min = 300,
          padoverview_cellside = 10,
          pad_controls_H = 20,
          pad_header_H = 15, 
          menu_indentX  = 10,
          settings_itemW = 180 ,
          tabbar_W = 500,
          samplepeaksH = 130,
          knobW = 58,
          knobH = 70,
          macro_but_sz = 8,
          font_sz_small = 13, 
          font_sz_tabs = 14,
          font_sz_padname = 13,
          font_sz_settings = 13,
          font_sz_knobname = 11,
        },
        
        UI_colors = {
          textcol = 0xFFFFFFFF,
          fill_active_values_in_sliders = 0x9F9F9F9F,
          InputTextBg = 0x404040F0,
          peaksBg = 0x40404000,
          knobBg = 0x303030FF,
          knobnameBg = 0x505050FF,
          knob_handle = 0xc8edfaFF,
          adsrmarkers = 0xAFAFAF00,
        }
      }, 
      
      
      
    -- PROCESS ------------------------------------
      process = { -- get/set non-rack data
        realtime = {}, -- realtime 30Hz collecting each loop
        midi = {},
        rack = { -- get/set various rack data 
          parent = {},
          children = {
            layer = {
              instrument = {},
            },
            sample = {},
            instrument = {},
            replace_sample = {},
            sysex = {},
            },
          midibus = {},
          layout = {},
          macro = {
            get = {},
            set = {},
          },
          peaks = {},
          database = {},
          PAD_OVERRIDES = {},
          changesample = {
            dropped_files = {}, 
            assign_destination = {}, 
            dropsampletopad = {},
            dropsampletodevicename = {},
            dropsampletolayername = {},
            dropsampletoPadAddLayer = {},
            grabfromdatabase = {},
            moving_pad = {},
          },
        },
        sampler = {
          peaks = {},
        }, 
        ext = { -- extstate actions
          plugin_mapping = {},
          db_maps = {},
          PAD_OVERRIDES = {},
        },
        actions = {},
        
      },
      
      
      
    -- UI draw ------------------------------------ 
      draw = {
        images = {},
        styledef = {},
        rack = {-- rack specific ui render
          pad = {},
        },
        tabsL = {},
        tabsR = {}, 
        sampler = {
          content = {
            child_peaks = {
              markers_adsr={}
            },
            child_tabs = {
              general = {},
            },
          },
        },
        databasemaps = {},
        settings = {}, 
        macro = {},
        popups = {},
      },
      
      
    -- VARIOUS ------------------------------------ 
      utils = {
        table = {},
      }, 
      cache = {
        folder_content = {}
      },
      ImGui = {},
      
      
  }
        
  -----------------------------------------------------------------------------------------  
  function DATA:func_def()
    self:func_def_images() 
    self:func_def_ImGui_Overrides()
    self:func_def_extstate()
    self:func_def_extstate_databasemaps()
    self:func_def_utils() 
    self:func_def_UI() 
    DATA:func_def_UI_draw_tabsL() 
    DATA:func_def_UI_draw_tabsR() 
    self:func_def_UI_draw_settings() 
    self:func_def_UI_draw_rack() 
    self:func_def_UI_draw_rack_pad() 
    DATA:func_def_UI_draw_databasemaps() 
    DATA:func_def_UI_draw_sampler() 
    DATA:func_def_UI_draw_sampler_childtabs()
    DATA:func_def_UI_draw_sampler_childpeaks()
    DATA:func_def_UI_draw_macro()
    DATA:func_def_UI_draw_popups()
    self:func_def_process() 
    self:func_def_process_changesample() 
    DATA:func_def_process_rack()
    DATA:func_def_process_rack_midibus() 
    DATA:func_def_process_rack_children()
    DATA:func_def_process_rack_macro() 
    DATA:func_def_process_realtime() 
  end 
  
  ----------------------------------------------------------------------------------------  
  function DATA:func_def_process_changesample()  
    -- drop sample to pad
    self.process.rack.changesample.dropsampletopad.all = 
    function(note) 
      if self.var.rack.valid ~= true then return end
      
      -- check dropped files or pad
      --
      local retval, payload = reaper.ImGui_AcceptDragDropPayload( ctx, 'moving_pad', '', flagsIn )
      if retval then 
        payload = tonumber(payload)
        self.process.rack.changesample.moving_pad.all(payload,note)
        return
      end
      local retval_files, count = ImGui.AcceptDragDropPayloadFiles( ctx, 0, ImGui.DragDropFlags_None )
      if not retval_files then return end
      
      self.process.rack.changesample.dropped_files.clean()
      self.process.rack.changesample.dropped_files.collect()
      self.process.rack.midibus.validate() 
      self.process.rack.changesample.assign_destination.dropsampletopad(note)
      self.process.rack.changesample.sharesamples() 
      self.process.rack.midibus.build_routing() 
      self.process.rack.read()
      self.process.at_project_change()
    end
    ------------------------------------------------------------
    self.process.rack.changesample.sharesamples = 
    function(drop_options)
      if not self.temp_drop_files then return end
      
      for fileID =1, #self.temp_drop_files do
        local filename = self.temp_drop_files[fileID].filename
        local dest_note = self.temp_drop_files[fileID].dest_note
        local dest_layer = self.temp_drop_files[fileID].dest_layer
        local dest_options = self.temp_drop_files[fileID].dest_options 
        if not filename then filename = dest_options.fp end
        
        if not (filename and dest_note and dest_layer) then break end
        -- replace is RS5k exist
        local track_exist, is_rs5k = self.process.rack.is_instance_already_exist(dest_note,dest_layer)
        if track_exist and is_rs5k==true then
          self.process.rack.children.replace_sample.all(dest_note, dest_layer, filename, dest_options)
          goto skip_next_fileID
        end 
        
        -- skip if 3rd party
        if track_exist and is_rs5k~=true then goto skip_next_fileID end -- 3rd party FX
        
        -- regular track
        if dest_device~= true then self.process.rack.changesample.dropped_files.add_regular_child(dest_note, dest_layer, filename, dest_options) end
        
        -- device child track
        if dest_device then
          if not (self.var.rack.children[dest_note] and self.var.rack.children[dest_note].exists == true) then 
            local new_track_device = self.process.rack.changesample.dropped_files.add_device(dest_note) -- create device
            if new_track_device then self.process.rack.changesample.dropped_files.add_regular_child(dest_note,dest_layer, filename, dest_options, new_track_device) end 
           elseif self.var.rack.children[dest_note].exists and self.var.rack.children[dest_note].device and  self.var.rack.children[dest_note].device.TYPE_DEVICE == true then 
            self.process.rack.changesample.dropped_files.add_regular_child(dest_note,dest_layer, filename, dest_options, self.var.rack.children[dest_note].params.track) 
           elseif self.var.rack.children[dest_note].exists and self.var.rack.children[dest_note].device and  self.var.rack.children[dest_note].device.TYPE_DEVICE ~= true then 
            -- convert existed child to device 
            local cur_track = self.var.rack.children[dest_note].params.track
            local new_track_device = self.process.rack.changesample.dropped_files.add_device(dest_note) -- create device 
            self.process.rack.changesample.dropped_files.add_regular_child(dest_note,dest_layer, filename, dest_options, new_track_device) 
            local IP_TRACKNUMBER = GetMediaTrackInfo_Value( new_track_device, 'IP_TRACKNUMBER' )
             
            self.process.track_selection_save()
            SetOnlyTrackSelected( cur_track )
            if new_track_device then 
              IP_TRACKNUMBER = GetMediaTrackInfo_Value( new_track_device, 'IP_TRACKNUMBER' )
              ReorderSelectedTracks( IP_TRACKNUMBER, 1 )
            end
            self.process.track_selection_restore() 
          end 
        end 
        
        ::skip_next_fileID::
      end
    end  
    ------------------------------------------------------------
    self.process.rack.changesample.assign_destination.dropsampletopad= 
    function(note_dest)  
      -- share to available notes
      local available_notes = {}
      for note0 = note_dest, 127 do
        local track_exist, is_rs5k = self.process.rack.is_instance_already_exist(note0,1) 
        -- skip if 3rd party
        if track_exist and is_rs5k~=true then goto skip_next_note end -- 3rd party FX 
         -- not allow replacing existing pads
        if self.var.ext.CONF_onadd_replaceexistingpads.current == 1 or (self.var.ext.CONF_onadd_replaceexistingpads.current == 0  and not (self.var.rack.children[note_dest] and self.var.rack.children[note_dest].exists == true)) then available_notes[#available_notes+1] = {note0,1} end
        
        ::skip_next_note::
      end  
      
      -- assign
      for i = 1, #self.temp_drop_files do
        if not available_notes[i] then break end
        self.temp_drop_files[i].dest_note = available_notes[i][1]
        self.temp_drop_files[i].dest_layer = available_notes[i][2]
      end 
    end
    ------------------------------------------------------------
    self.process.rack.changesample.dropped_files.clean = function() self.temp_drop_files= {} end  
    ------------------------------------------------------------
    self.process.rack.changesample.dropped_files.collect =  
    function()
      self.temp_drop_files= {}
      local retval1, count = ImGui.AcceptDragDropPayloadFiles( ctx, 127, ImGui.DragDropFlags_None )
      if retval1 then
        for i = 1, count do 
          local retval, filename = reaper.ImGui_GetDragDropPayloadFile( ctx, i-1 )
          if not retval then break end  
          local ext = filename:gsub('.+%.', '')
          if ext and ext:lower():match('mid')==nil and IsMediaExtension(ext, false) then
            self.temp_drop_files[#self.temp_drop_files+1] = {filename=filename}
          end
        end 
        return true
      end
    end     
    ------------------------------------------------------------
    self.process.rack.changesample.dropped_files.collect = 
    function(source, options)
      self.temp_drop_files= {}
      
      if source == 'database' then 
        local ret
        if options.fp then 
          self.temp_drop_files[#self.temp_drop_files+1] = {filename=options.fp}
          ret = true
        end
        return ret
      end
      
      local retval1, count = ImGui.AcceptDragDropPayloadFiles( ctx, 127, ImGui.DragDropFlags_None )
      if retval1 then
        for i = 1, count do 
          local retval, filename = reaper.ImGui_GetDragDropPayloadFile( ctx, i-1 )
          if not retval then break end  
          local ext = filename:gsub('.+%.', '')
          if ext and ext:lower():match('mid')==nil and IsMediaExtension(ext, false) then
            self.temp_drop_files[#self.temp_drop_files+1] = {filename=filename}
          end
        end 
        return true
      end
    end  
    
    --------------------------------------------------------------
    -- drop sample to device name
    self.process.rack.changesample.dropsampletodevicename.all = 
    function(note) 
      if self.var.rack.valid ~= true then return end
      self.process.rack.changesample.dropped_files.clean()
      self.process.rack.changesample.dropped_files.collect()
      self.process.rack.midibus.validate() 
      self.process.rack.changesample.assign_destination.dropsampletodevicename(note)
      self.process.rack.changesample.sharesamples() 
      self.process.rack.midibus.build_routing() 
      self.process.rack.read()
      self.process.at_project_change()
    end
    ------------------------------------------------------------
    self.process.rack.changesample.assign_destination.dropsampletodevicename= 
    function(note_dest) 
      if not (self.temp_drop_files and self.temp_drop_files[1]) then return end
      --for i = 1, #self.temp_drop_files do
        self.temp_drop_files[1].dest_note = note_dest
        self.temp_drop_files[1].dest_layer = self.var.rack.var.LASTACTIVENOTE_LAYER or 1
      --end 
    end
    
    
    --------------------------------------------------------------
    -- drop sample to layer name
    self.process.rack.changesample.dropsampletolayername.all =
    function(note)
      if self.var.rack.valid ~= true then return end
      self.process.rack.changesample.dropped_files.clean()
      self.process.rack.changesample.dropped_files.collect()
      self.process.rack.midibus.validate() 
      self.process.rack.changesample.assign_destination.dropsampletodevicename(note)
      self.process.rack.changesample.sharesamples() 
      self.process.rack.midibus.build_routing() 
      self.process.rack.read()
      self.process.rack.peaks.all({clear=true})
    end
    
    
    --------------------------------------------------------------
    -- drop sample to layer name 
    self.process.rack.changesample.dropsampletoPadAddLayer.all =
    function(note)
      if self.var.rack.valid ~= true then return end
      self.process.rack.changesample.dropped_files.clean()
      self.process.rack.changesample.dropped_files.collect()
      self.process.rack.midibus.validate() 
      self.process.rack.changesample.assign_destination.dropsampletoPadAddLayer(note)
      self.process.rack.changesample.sharesamples() 
      self.process.rack.midibus.build_routing() 
      self.process.rack.read()
      self.process.at_project_change()
    end
    ------------------------------------------------------------
    self.process.rack.changesample.assign_destination.dropsampletoPadAddLayer=
    function(note_dest) 
      for i = 1, #self.temp_drop_files do
        self.temp_drop_files[i].dest_note = note_dest
        self.temp_drop_files[i].dest_layer = i
        self.temp_drop_files[i].dest_device = true
      end 
    end
    
    
    --------------------------------------------------------------
    -- grab sample from database
    self.process.rack.changesample.grabfromdatabase.all =
    function(note, options)
      if self.var.rack.valid ~= true then return end
      self.process.rack.midibus.validate() 
      self.process.rack.changesample.assign_destination.grabfromdatabase(note, options)
      self.process.rack.changesample.sharesamples() 
      self.process.rack.midibus.build_routing()  
    end
    ------------------------------------------------------------
    self.process.rack.changesample.assign_destination.grabfromdatabase=
    function(note_dest, options) 
      self.temp_drop_files = {[1]={}}
      self.temp_drop_files[1].dest_note = note_dest
      self.temp_drop_files[1].dest_layer = 1
      self.temp_drop_files[1].dest_options = options
    end
    
    
    
    -- drop pad to pad
    ------------------------------------------------------------
    self.process.rack.changesample.moving_pad.all = 
    function(src_note, dest_note) 
      self.process.rack.changesample.moving_pad.simple_move(src_note, dest_note) -- if dest pad is free
      
      function __b_changesample_dropPad() end
      --[[ 
      self.temp_paddrop_mode = 0 -- move/replace
      if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Mod_Ctrl()) then self.temp_paddrop_mode = 1 end -- swap
      if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Mod_Shift()) then self.temp_paddrop_mode = 2 end -- shift further pads
      ]]
      local track = self.var.rack.parent.params.track
      GetSetMediaTrackInfo_String ( track, 'P_EXT:MPLRS5KMAN_LASTACTIVENOTE',dest_note, true)
      self.var.rack.var.LASTACTIVENOTE = dest_note
      self.process.rack.read()
      self.process.at_project_change()
    end
    ------------------------------------------------------------
    self.process.rack.changesample.moving_pad.simple_move=
    function(src_note, dest_note) 
      -- check
        if (self.var.rack.children[dest_note] and self.var.rack.children[dest_note].exists) then return end 
        if not self.var.rack.children[src_note] then return end
      -- change ext data
        if self.var.rack.children[src_note].layers then
          for layer = 1, #self.var.rack.children[src_note].layers do
            local track = self.var.rack.children[src_note].layers[layer].params.track
            GetSetMediaTrackInfo_String( track, 'P_EXT:MPLRS5KMAN_NOTE', dest_note, true) 
          end
        end
        local dev_tr = self.var.rack.children[src_note].params.track
        GetSetMediaTrackInfo_String( dev_tr, 'P_EXT:MPLRS5KMAN_NOTE', dest_note, true) 
      -- set note range
        self.process.rack.children.SetNoteRange(src_note, dest_note) 
    end
    ------------------------------------------------------------
    self.process.rack.children.SetNoteRange =
    function(src_note, dest_note)
      if not (self.var.rack.children[src_note] and self.var.rack.children[src_note].layers) then return end
      local sysex = 
        self.var.rack.children[src_note] and 
        self.var.rack.children[src_note].SysEx and 
        self.var.rack.children[src_note].SysEx.mode and 
        self.var.rack.children[src_note].SysEx.mode&1==1
      
      -- change layers
      for layer = 1, #self.var.rack.children[src_note].layers do 
        local track = self.var.rack.children[src_note].layers[layer].params.track   
        if not self.var.rack.children[src_note].layers[layer].instrument then goto skiplayer end
        local instrument_pos = self.var.rack.children[src_note].layers[layer].instrument.pos  
        
        -- change midifilter settings
        if self.var.rack.children[src_note].layers[layer].fx and self.var.rack.children[src_note].layers[layer].fx.midifilter and self.var.rack.children[src_note].layers[layer].fx.midifilter.pos then 
          midifilt_pos = self.var.rack.children[src_note].layers[layer].fx.midifilter.pos 
          TrackFX_SetParamNormalized( track, midifilt_pos, 0, dest_note/128)
          TrackFX_SetParamNormalized( track, midifilt_pos, 1, dest_note/128)
          goto skiplayer
        end
        
        -- change rs5k
        local is_rs5k = self.var.rack.children[src_note].layers[layer].instrument and self.var.rack.children[src_note].layers[layer].instrument.is_rs5k and self.var.rack.children[src_note].layers[layer].instrument.is_rs5k == true
        if is_rs5k == true and sysex ~= true then 
          TrackFX_SetParamNormalized( track, instrument_pos, 3, dest_note/127 ) -- note range start
          TrackFX_SetParamNormalized( track, instrument_pos, 4, dest_note/127 ) -- note range end
        end
        
        -- sysex handler
        if sysex == true then 
          local handler_pos = self.var.rack.children[src_note].SysEx.handler_pos
          TrackFX_SetParam( track, handler_pos, 0, dest_note ) -- set new note
        end
        
        ::skiplayer::
      end
      
    end
    
    
    --[[
    
    ---------------------------------------------------------------------  
    f unction DATA:Drop_Pad(src_pad0,dest_pad0)
      if not src_pad0 and dest_pad0 then return end
      src_pad,dest_pad = tonumber(src_pad0),tonumber(dest_pad0)
      if not src_pad and dest_pad then return end
      
      if not DATA.paddrop_mode then 
        DATA:Drop_Pad_Swap(src_pad,dest_pad)  
       elseif DATA.paddrop_mode == 1 
        and self.var.rack.children[note][src_pad] 
        and not self.var.rack.children[note][dest_pad] 
        and self.var.rack.children[note][src_pad].layers
        and #self.var.rack.children[note][src_pad].layers==1
        and self.var.rack.children[note][src_pad].layers[1] 
        and self.var.rack.children[note][src_pad].layers[1].instrument_filename  then -- copy stuff to dest pad if it is free
        local filename = self.var.rack.children[note][src_pad].layers[1].instrument_filename
        local drop_data = {
          layer = 1, 
          EOFFS = self.var.rack.children[note][src_pad].layers[1].instrument_sampleendoffs,
          SOFFS = self.var.rack.children[note][src_pad].layers[1].instrument_samplestoffs,
        }
        DATA:DropSample(filename, dest_pad0, drop_data)
        DATA.paddrop_mode = nil
      end
      DATA:_Seq_RefreshStepSeq()
    end
    ---------------------------------------------------------------------  
    f unction DATA:Drop_Pad_Swap(src_pad,dest_pad)  
      -- set dest device/devicechidren
      if self.var.rack.children[note][dest_pad] then   
        self.ext.child.set(self.var.rack.children[note][dest_pad].tr_ptr, {SET_noteID = src_pad})  
        if self.var.rack.children[note][dest_pad].layers then
          for layer = 1, #self.var.rack.children[note][dest_pad].layers do
            self.ext.child.set(self.var.rack.children[note][dest_pad].layers[layer].tr_ptr, {SET_noteID = src_pad})  
            DATA:DropSample_ExportToRS5kSetNoteRange(self.var.rack.children[note][dest_pad].layers[layer], src_pad) 
          end
        end 
        local filename  if self.var.rack.children[note][dest_pad] and self.var.rack.children[note][dest_pad].layers and self.var.rack.children[note][dest_pad].layers[1] and self.var.rack.children[note][dest_pad].layers[1].instrument_filename then filename = self.var.rack.children[note][dest_pad].layers[1].instrument_filename end
        
      end
      
      -- set src device/devicechidren
      if self.var.rack.children[note][src_pad] then   
        self.ext.child.set(self.var.rack.children[note][src_pad].tr_ptr, {SET_noteID = dest_pad})  
        if self.var.rack.children[note][src_pad].layers then
          for layer = 1, #self.var.rack.children[note][src_pad].layers do
            self.ext.child.set(self.var.rack.children[note][src_pad].layers[layer].tr_ptr, {SET_noteID = dest_pad})  
            DATA:DropSample_ExportToRS5kSetNoteRange(self.var.rack.children[note][src_pad].layers[layer], dest_pad)
          end
        end
        local filename  if self.var.rack.children[note][src_pad] and self.var.rack.children[note][src_pad].layers and self.var.rack.children[note][src_pad].layers[1] and self.var.rack.children[note][src_pad].layers[1].instrument_filename then filename = self.var.rack.children[note][src_pad].layers[1].instrument_filename end
        
      end 
      
      DATA.peakscache[src_pad] = nil
      DATA.peakscache[dest_pad] = nil
      DATA.upd = true
      DATA.autoreposition = true
    end
    ]]
    
    ------------------------------------------------------------
    self.process.rack.changesample.dropped_files.add_regular_child = 
    function(dest_note,dest_layer, filename, drop_options, new_track_device)
      -- add track
      local new_track = self.process.rack.children.create_new_child(dest_note, new_track_device)
      if not new_track then return end
      
      -- add metadata
      self.process.rack.children.print_basic_metadata(dest_note, new_track)
      
      -- add rs5k
      local instrument_pos = self.process.rack.children.add_rs5k_instance(dest_note, new_track)
      if not instrument_pos then return end
      
      -- immediately set track and pos for replacing empty sample
      if not self.var.rack.children[dest_note] then                                 self.var.rack.children[dest_note] = {} end
      if not self.var.rack.children[dest_note].params then                          self.var.rack.children[dest_note].params = self.process.rack.get_track_params(new_track) end
      if not self.var.rack.children[dest_note].layers then                          self.var.rack.children[dest_note].layers = {} end
      if not self.var.rack.children[dest_note].layers[dest_layer] then              self.var.rack.children[dest_note].layers[dest_layer] = {} end
      if not self.var.rack.children[dest_note].layers[dest_layer].params then       self.var.rack.children[dest_note].layers[dest_layer].params = self.process.rack.get_track_params(new_track) end
      if not self.var.rack.children[dest_note].layers[dest_layer].instrument then   self.var.rack.children[dest_note].layers[dest_layer].instrument = {} end
      
      
      self.var.rack.children[dest_note].layers[dest_layer].instrument.pos = instrument_pos 
      self.process.rack.children.init_rs5k_parameters(dest_note, new_track, instrument_pos)
      self.process.rack.children.replace_sample.all(dest_note, dest_layer, filename, drop_options)
      return new_track
    end
    
    
    ------------------------------------------------------------
    self.process.rack.changesample.dropped_files.add_device = 
    function(dest_note)
      -- add track
      local new_track = self.process.rack.children.create_new_child(dest_note)
      if not new_track then return end
      
      -- add metadata
      self.process.rack.children.print_basic_metadata(dest_note, new_track, true) 
      
      -- immediately set track and pos for replacing empty sample
      if not self.var.rack.children[dest_note] then                                 self.var.rack.children[dest_note] = {} end 
      self.var.rack.children[dest_note].params = self.process.rack.get_track_params(new_track)
      
      if not self.var.rack.children[dest_note].layers then                          self.var.rack.children[dest_note].layers = {} end
      self.var.rack.children[dest_note].device = {
        TYPE_DEVICE=true, 
        TYPE_DEVICE_AUTORANGE = self.var.ext.CONF_onadd_autosetrange.current
      }
      GetSetMediaTrackInfo_String( new_track, 'P_EXT:MPLRS5KMAN_TYPE_DEVICE_AUTORANGE', self.var.ext.CONF_onadd_autosetrange.current, true) 
      
      
      return new_track
    end
    
    
    
    
  end
  --------------------------------------------------------------------------------------------------------------
  function DATA:func_def_process_rack_macro()  
    --------------------------------------------------------------------------------  
    self.process.rack.macro.showFX =
    function(link_t)
      local child_t = link_t.child_t 
      if not child_t then return end
      local track = child_t.params.track
      local dest_fx = link_t.dest_fx
      local dest_param = link_t.dest_param
      TrackFX_Show( track, dest_fx, 3 )
    end
    --------------------------------------------------------------------------------  
    self.process.rack.macro.showmod =
    function(link_t)
      local child_t = link_t.child_t 
      if not child_t then return end
      local track = child_t.params.track
      local dest_fx = link_t.dest_fx
      local dest_param = link_t.dest_param
      TrackFX_SetNamedConfigParm(track, dest_fx, 'param.'..dest_param..'mod.visible', 1) 
    end
    --------------------------------------------------------------------------------  
    self.process.rack.macro.bypass = 
    function(link_t)
      local child_t = link_t.child_t 
      if not child_t then return end
      local track = child_t.params.track
      local dest_fx = link_t.dest_fx
      local dest_param = link_t.dest_param
      TrackFX_SetNamedConfigParm(track, dest_fx, 'param.'..dest_param..'plink.active', 0)
      self.process.at_project_state_change()
    end 
    --------------------------------------------------------------------------------  
    self.process.rack.macro.InitMaster =
    function() 
      local track = self.var.rack.parent.params.track
      local fxname = 'mpl_RS5k_manager_MacroControls.jsfx' -- MacroControls 
      local macroJSFX_pos =  TrackFX_AddByName( track, fxname, false, 0 )
      if macroJSFX_pos == -1 then
        macroJSFX_pos =  TrackFX_AddByName( track, fxname, false, -1000 ) 
        local macroJSFX_fxGUID = reaper.TrackFX_GetFXGUID( track, macroJSFX_pos ) 
        TrackFX_Show( track, macroJSFX_pos, 0|2 )
        for i = 1, 16 do TrackFX_SetParamNormalized( track, macroJSFX_pos, 33+i, i/1024 ) end -- init source gmem IDs
      end
      self.process.rack.macro.get.all()  -- immediately refresh
    end
    -----------------------------------------------------------------------  
    self.process.rack.macro.InitChild =
    function(note, layer)
      if not (
        self.var.rack.children[note] and 
        self.var.rack.children[note].layers and 
        self.var.rack.children[note].layers[layer] and
        self.var.rack.children[note].layers[layer].params and
        self.var.rack.children[note].layers[layer].params.track )
        then return end
      local track = self.var.rack.children[note].layers[layer].params.track
      local macro_pos = self.var.rack.children[note].layers[layer].macro_pos
      if not macro_pos then
        local fxname = 'mpl_RS5k_manager_MacroControls.jsfx' -- MacroControls 
        local macroJSFX_pos =  TrackFX_AddByName( track, fxname, false, -1000 )
        if macroJSFX_pos == -1 then return end
        local macroJSFX_fxGUID = reaper.TrackFX_GetFXGUID( track, macroJSFX_pos )  
        TrackFX_Show( track, macroJSFX_pos, 0|2 )
        TrackFX_SetParamNormalized( track, macroJSFX_pos, 0, 1 ) -- set mode to slave
        for i = 1, 16 do TrackFX_SetParamNormalized( track, macroJSFX_pos, 17+i, i/1024 ) end -- ini source gmem IDs
        self.var.rack.children[note].layers[layer].macro_pos = macroJSFX_pos
      end
    end
    -----------------------------------------------------------------------  
    self.process.rack.macro.get_JSFXpos = 
    function(track)
      if self.var.rack.parent.valid ~= true then return end  
      -- validate rack parent macro controls
      local fxname = 'RS5k_manager_MacroControls' 
      local fxname2 = 'mpl_RS5k_manager_MacroControls.jsfx' 
      local macroJSFX_pos =  TrackFX_AddByName(track, fxname, false, 0 )
      local macroJSFX_pos2 =  TrackFX_AddByName(track, fxname2, false, 0 )
      if macroJSFX_pos ~= -1 then return macroJSFX_pos end
      if macroJSFX_pos2 ~= -1 then return macroJSFX_pos2 end
    end
    -------------------------------------------------------------------  
    self.process.rack.macro.get.sliders = 
    function()
      self.var.rack.macro.sliders = {}
      for i = 1, 16 do
        local param_val = TrackFX_GetParamNormalized( self.var.rack.parent.params.track, self.var.rack.macro.pos, i )
        self.var.rack.macro.sliders[i] = {
          val = param_val,
        }
      end
    end
    -------------------------------------------------------------------  
    self.process.rack.macro.get.calculateParamRange=
    function(baseline, offset, scale) 
      
      -- Calculate the two extreme points
      local min_val = baseline + offset * scale 
      local max_val = baseline + (1+offset)*scale 
      
      
      return min_val, max_val
    end 
    -------------------------------------------------------------------  
    self.process.rack.macro.get.slider_links = 
    function()
      for note in pairs(self.var.rack.children) do
        if not self.var.rack.children[note].layers then goto skipnextnote end
        for layer in pairs(self.var.rack.children[note].layers) do
          local child_track = self.var.rack.children[note].layers[layer].params.track
          local macroJSFX_pos = self.process.rack.macro.get_JSFXpos(child_track) 
          if macroJSFX_pos then self.var.rack.children[note].layers[layer].macro_pos = macroJSFX_pos else goto skipnextlayer end -- 0 based
          
          for fxid = 1,  TrackFX_GetCount( child_track ) do
            if fxid -1 == macroJSFX_pos then goto skipnextFX end
            
            for paramnumber = 0, TrackFX_GetNumParams( child_track, fxid-1 )-1 do
              local isactive = ({TrackFX_GetNamedConfigParm(child_track, fxid-1, 'param.'..paramnumber..'plink.active')})[2] isactive = (tonumber(isactive) or 0 ) == 1
              if isactive ~= true then goto skipnextparam end 
              
              local src_fx =    ({TrackFX_GetNamedConfigParm(child_track, fxid-1, 'param.'..paramnumber..'plink.effect')})[2] src_fx = tonumber(src_fx) 
              local src_param = ({TrackFX_GetNamedConfigParm(child_track, fxid-1, 'param.'..paramnumber..'plink.param')})[2]  src_param = tonumber(src_param) 
              if not (src_fx and src_fx == macroJSFX_pos) then goto skipnextparam end 
              local macroID = src_param   
              if not (macroID>=1 and macroID<=16) then goto skipnextparam end  
              self.var.rack.macro.sliders[macroID].has_links = true
              
              local paramID = paramnumber
              
              if not self.var.rack.macro.sliders[macroID].links then self.var.rack.macro.sliders[macroID].links = {} end
              if not self.var.rack.macro.sliders[macroID].links[note] then self.var.rack.macro.sliders[macroID].links[note] = {} end
              if not self.var.rack.macro.sliders[macroID].links[note][layer] then self.var.rack.macro.sliders[macroID].links[note][layer] = {} end
              if not self.var.rack.macro.sliders[macroID].links[note][layer][paramID] then self.var.rack.macro.sliders[macroID].links[note][layer][paramID] = {} end
              
              self.var.rack.macro.sliders[macroID].links[note][layer][paramID].src_fx = src_fx
              self.var.rack.macro.sliders[macroID].links[note][layer][paramID].src_param = src_param
              self.var.rack.macro.sliders[macroID].links[note][layer][paramID].dest_fx = fxid-1
              self.var.rack.macro.sliders[macroID].links[note][layer][paramID].dest_param = paramnumber
              
              local val_child = TrackFX_GetParamNormalized( child_track, fxid-1, paramnumber ) 
              self.var.rack.macro.sliders[macroID].links[note][layer][paramID].val_child = val_child
              local retval, val_format = reaper.TrackFX_GetFormattedParamValue( child_track, fxid-1, paramnumber )
              self.var.rack.macro.sliders[macroID].links[note][layer][paramID].val_format = val_format 
              local retval, param_name = reaper.TrackFX_GetParamName( child_track, fxid-1,paramnumber)
              self.var.rack.macro.sliders[macroID].links[note][layer][paramID].param_name = param_name
              local baseline = ({TrackFX_GetNamedConfigParm(child_track, fxid-1, 'param.'..paramnumber..'mod.baseline')})[2] baseline = tonumber(baseline) 
              self.var.rack.macro.sliders[macroID].links[note][layer][paramID].baseline = baseline
              local plink_offset = ({TrackFX_GetNamedConfigParm(child_track, fxid-1, 'param.'..paramnumber..'plink.offset')})[2] plink_offset = tonumber(plink_offset) 
              self.var.rack.macro.sliders[macroID].links[note][layer][paramID].plink_offset = plink_offset
              local plink_scale = ({TrackFX_GetNamedConfigParm(child_track, fxid-1, 'param.'..paramnumber..'plink.scale')})[2] plink_scale = tonumber(plink_scale) 
              self.var.rack.macro.sliders[macroID].links[note][layer][paramID].plink_scale = plink_scale
              
              self.var.rack.macro.sliders[macroID].links[note][layer][paramID].plink_min, self.var.rack.macro.sliders[macroID].links[note][layer][paramID].plink_max = self.process.rack.macro.get.calculateParamRange(baseline, plink_offset, plink_scale )
              
              ::skipnextparam::
            end
            ::skipnextFX::
          end
          
          ::skipnextlayer::
        end
        ::skipnextnote::
      end
      
      for macroID in pairs(self.var.rack.macro.sliders) do
        if self.var.rack.macro.sliders[macroID].links then 
          for note in self.utils.spairs(self.var.rack.macro.sliders[macroID].links) do 
            for layer in self.utils.spairs(self.var.rack.macro.sliders[macroID].links[note] ) do 
              for paramID in pairs(self.var.rack.macro.sliders[macroID].links[note][layer]) do
                local child_t = self.var.rack.children[note].layers[layer]
                self.var.rack.macro.sliders[macroID].links[note][layer][paramID].child_t = child_t
              end
            end
          end
        end
      end
      
    end
    ------------------------------------------------------------------
    self.process.rack.macro.get.extstate_from_parent = 
    function()
      if self.var.rack.valid ~= true then return end local parent_track = self.var.rack.parent.params.track if not parent_track then return end
      local ret, MACROEXT_B64 = GetSetMediaTrackInfo_String ( parent_track, 'P_EXT:MPLRS5KMAN_MACROEXT_B64', 0, false)
      if not ret then return end
      self.var.rack.macro.extstate = self.utils.table.loadstring(DATA.utils.base64.dec(MACROEXT_B64)) or {} 
    end 
    --------------------------------------------------------------------------------  
    self.process.rack.macro.set.extstate_to_parent = 
    function()
      if self.var.rack.valid ~= true then return end local parent_track = self.var.rack.parent.params.track if not parent_track then return end
      local tablestring = self.utils.table.savestring(self.var.rack.macro.extstate)
      local b64string = self.utils.base64.enc(tablestring)
      GetSetMediaTrackInfo_String ( parent_track, 'P_EXT:MPLRS5KMAN_MACROEXT_B64', b64string, 1 )
    end
    -------------------------------------------------------------------
    self.process.rack.macro.get.all = 
    function()
      self.process.rack.macro.get.validate()
      if self.var.rack.macro.valid ~= true then return end
      self.process.rack.macro.get.extstate_from_parent()
      self.process.rack.macro.get.sliders()
      self.process.rack.macro.get.slider_links()
    end
    -------------------------------------------------------------------
    self.process.rack.macro.get.validate=
    function()
      if self.var.rack.valid ~= true then return end 
      local parent_track = self.var.rack.parent.params.track
      if not parent_track then return end 
      local macroJSFX_pos = self.process.rack.macro.get_JSFXpos(parent_track)   
      if macroJSFX_pos then
        self.var.rack.macro.valid = true
        self.var.rack.macro.pos = macroJSFX_pos
      end
    end 
    --------------------------------------------------------------------------------
    self.process.rack.macro.add_link =
    function(macroID)
      if self.var.rack.valid ~= true then return end local parent_track = self.var.rack.parent.params.track if not parent_track then return end
      
      -- last touched param
      local retval, trackidx, itemidx, takeidx, fxnumber, paramnumber = reaper.GetTouchedOrFocusedFX( 0 )
      if retval~= true then return end
      if itemidx ~= -1 then return end -- ignore take FX
      if takeidx ~= -1 then return end -- ignore take FX
      if trackidx == -1 then return end -- ignore master
      
      local track = GetTrack(-1,trackidx)
      local israckchild, note, layer = self.process.rack.children.TrackIsRackChild(track)
      if not (israckchild and note) then return end
      
      local macro_pos = self.var.rack.children[note].layers[layer].macro_pos
      if not macro_pos then 
        self.process.rack.macro.InitChild(note, layer or 1)
        fxnumber = fxnumber + 1
        macro_pos = self.var.rack.children[note].layers[layer].macro_pos
        if not macro_pos then return  end
      end
       
      -- link
      local param_src = macroID
      local fx_src = macro_pos
      
      TrackFX_SetNamedConfigParm(track, fxnumber, 'param.'..paramnumber..'.plink.active', 1)
      TrackFX_SetNamedConfigParm(track, fxnumber, 'param.'..paramnumber..'.plink.scale', scale0 or 1)
      TrackFX_SetNamedConfigParm(track, fxnumber, 'param.'..paramnumber..'.plink.offset', offset0 or 0)
      TrackFX_SetNamedConfigParm(track, fxnumber, 'param.'..paramnumber..'.plink.effect',fx_src)
      TrackFX_SetNamedConfigParm(track, fxnumber, 'param.'..paramnumber..'.plink.param', param_src)
      TrackFX_SetNamedConfigParm(track, fxnumber, 'param.'..paramnumber..'.plink.midi_bus', 0)
      TrackFX_SetNamedConfigParm(track, fxnumber, 'param.'..paramnumber..'.plink.midi_chan', 0)
      TrackFX_SetNamedConfigParm(track, fxnumber, 'param.'..paramnumber..'.plink.midi_msg', 0)
      TrackFX_SetNamedConfigParm(track, fxnumber, 'param.'..paramnumber..'.plink.midi_msg2', 0)
      TrackFX_SetNamedConfigParm(track, fxnumber, 'param.'..paramnumber..'.mod.active', 1)
      TrackFX_SetNamedConfigParm(track, fxnumber, 'param.'..paramnumber..'.mod.visible', 0)
    end
    -----------------------------------------------------------------------  
    self.process.rack.macro.clear_links = 
    function (macroID)
      if self.var.rack.valid ~= true then return end local parent_track = self.var.rack.parent.params.track if not parent_track then return end 
      if not (self.var.rack.macro.sliders[macroID] and self.var.rack.macro.sliders[macroID].links) then return end 
      for note in pairs( self.var.rack.macro.sliders[macroID].links) do
        for layer in pairs( self.var.rack.macro.sliders[macroID].links[note]) do
          for paramID in pairs( self.var.rack.macro.sliders[macroID].links[note][layer]) do
            local link_t = self.var.rack.macro.sliders[macroID].links[note][layer][paramID]
            local child_t = link_t.child_t
            TrackFX_SetNamedConfigParm(child_t.params.track, link_t.dest_fx, 'param.'..link_t.dest_param..'plink.active', 0) 
          end
        end
      end 
    end 
    -----------------------------------------------------------------------  
    self.process.rack.macro.learn =
    function(macroID)
      if self.var.rack.valid ~= true then return end local parent_track = self.var.rack.parent.params.track if not parent_track then return end 
      TrackFX_SetNamedConfigParm(parent_track, self.var.rack.macro.pos,'last_touched' ,macroID) 
      Main_OnCommand(41144,0) -- FX: Set MIDI learn for last touched FX parameter
    end
  end      
  --------------------------------------------------------------------------------------------------------------
  function DATA:func_def_UI_draw_sampler_childtabs() 
    self.draw.sampler.content.child_tabs.all =
    function()
      if ImGui.BeginChild( ctx, '##child_tabs', -1, -1, reaper.ImGui_ChildFlags_None() ) then
        if ImGui.BeginTabBar(ctx, '##child_tabs_bar') then
          if ImGui.BeginTabItem(ctx, 'General##child_tabs_it') then self.draw.sampler.content.child_tabs.general.all() ImGui.EndTabItem(ctx) end
          ImGui.EndTabBar(ctx)
        end
        ImGui.EndChild( ctx )
      end
    end 
    ---------------------------------------------------------------------
    self.draw.sampler.content.child_tabs.general.single =
    function(note, layer, params)
      local name =params.name
      local str_id =params.str_id
      local param =params.param
      local paramID =params.paramID
      local default_val =params.default_val
      local value_normalized = self.var.rack.children[note].layers[layer].instrument[param].val
      local value_max = 1
      if self.var.rack.children[note].layers[layer].instrument[param].max_adaptive then 
        value_max = self.var.rack.children[note].layers[layer].instrument[param].max_adaptive
        value_normalized = self.var.rack.children[note].layers[layer].instrument[param].val / value_max
      end 
      self.ImGui.Custom_Knob(ctx, name..str_id, self.var.UI_linear.knobW,self.var.UI_linear.knobH,
        {   value_normalized = value_normalized,
            value_formatted = self.var.rack.children[note].layers[layer].instrument[param].val_formatted,
            f_atclick_knob = function() self.temp_rack_snapshot = CopyTable(self.var.rack) end,
            f_atdrag_knob = function(dy) 
              if params.f_atdrag_knob then params.f_atdrag_knob(dy) else -- customized fro tune
                local slow_coeff = value_max
                if reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Shift()) then slow_coeff = 0.05 end
                local dval = slow_coeff * dy/self.var.mouseY_resolution
                local outval = self.temp_rack_snapshot.children[note].layers[layer].instrument[param].val - dval
                outval = self.utils.lim(outval, 0, value_max ) 
                self.process.rack.children.instrument.setval(note, layer, paramID,outval)  
                self.var.rack.children[note].layers[layer].instrument[param].val = outval -- immediately set
                self.process.rack.children.layer.instrument.formatparams(note, layer) 
                self.process.rack.children.layer.instrument.calc_max_adaptive(note, layer)
              end
            end,
            f_atdc_knob = function(dy)  
              local outval = default_val
              self.process.rack.children.instrument.setval(note, layer, paramID,outval) 
              self.var.rack.children[note].layers[layer].instrument[param].val = outval -- immediately set
              self.process.rack.children.layer.instrument.formatparams(note, layer) 
              self.process.rack.children.layer.instrument.calc_max_adaptive(note, layer)
            end,
            f_atdc_value = function() 
              ImGui.OpenPopup( ctx, str_id..'popup', ImGui.PopupFlags_None )
            end,
            f_value_popup = function()
              local mx, my = reaper.ImGui_GetMousePos(ctx)
              reaper.ImGui_SetNextWindowPos(ctx, mx, my, reaper.ImGui_Cond_Appearing())
              reaper.ImGui_SetNextWindowSize(ctx, 200,200, reaper.ImGui_Cond_Appearing())
              if ImGui.BeginPopup( ctx, str_id..'popup', ImGui.PopupFlags_None ) then
                reaper.ImGui_SetKeyboardFocusHere(ctx)
                self.temp_inputvalue_bufIn = self.var.rack.children[note].layers[layer].instrument[param].val_formatted 
                local retval, buf = reaper.ImGui_InputText( ctx, str_id..'popupinput', self.temp_inputvalue_bufIn, ImGui.InputTextFlags_AutoSelectAll )
                if retval then self.temp_inputvalue_bufIn = buf end
                if reaper.ImGui_IsItemDeactivatedAfterEdit(ctx) then  
                  local outval= self.utils.brutforce(buf, self.var.rack.children[note].layers[layer].params.track, self.var.rack.children[note].layers[layer].instrument.pos, paramID) 
                  if outval then 
                    outval = self.utils.lim(outval, 0, value_max )
                    self.process.rack.children.instrument.setval(note, layer, paramID,outval)  
                    self.var.rack.children[note].layers[layer].instrument[param].val = outval -- immediately set
                    self.process.rack.children.layer.instrument.formatparams(note, layer) 
                    self.process.rack.children.layer.instrument.calc_max_adaptive(note, layer)
                    reaper.ImGui_CloseCurrentPopup(ctx)
                  end
                end
                ImGui.EndPopup( ctx)
              end
            end
        })
    end
    ---------------------------------------------------------------------
    self.draw.sampler.content.child_tabs.general.all = 
    function()
      local note = self.var.rack.var.LASTACTIVENOTE or -1
      local layer = self.var.rack.var.LASTACTIVENOTE_LAYER or -1
      
      if not (self.var.rack.children[note] and self.var.rack.children[note].layers and self.var.rack.children[note].layers[layer] and self.var.rack.children[note].layers[layer].instrument) then return end
      
      if not self.var.rack.children[note].layers[layer].instrument.vol then return end
      self.draw.sampler.content.child_tabs.general.single(note, layer,{
        name = 'Gain',
        str_id = '##rs5k_vol',
        param = 'vol',
        paramID = self.var.rack.children[note].layers[layer].instrument.vol.param_ID,
        default_val = 0.5,
        }) 
        ImGui.SameLine(ctx)
        
      self.draw.sampler.content.child_tabs.general.single(note, layer,{
        name = 'Tune',
        str_id = '##rs5k_tune',
        param = 'tune',
        paramID = self.var.rack.children[note].layers[layer].instrument.tune.param_ID,
        default_val = 0.5,
        f_atdrag_knob = function(dy) 
          local dval
          if dy == 0 then return end
          if reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Shift()) then -- finetune
            dval = 0.02 * dy/self.var.mouseY_resolution_tune
           elseif reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Ctrl()) then -- octave quantized 
            dval = 0.1*dy/self.var.mouseY_resolution
            dval = 12*math.floor(dval*160) / 160
           else -- semitone quantized
            dval = dy/self.var.mouseY_resolution
            local dval_sign = math.abs(dval)/dval
            local dval_semitone = dval_sign * math.floor(math.abs(dval*160))
            dval = dval_semitone / 160
          end
          if not dval then return end
          local outval = self.utils.lim(self.temp_rack_snapshot.children[note].layers[layer].instrument.tune.val - dval )
          self.process.rack.children.instrument.setval(note, layer, 15, outval)
          self.var.rack.children[note].layers[layer].instrument.tune.val = outval -- immediately set
          self.process.rack.children.layer.instrument.formatparams(note, layer) 
          self.process.rack.children.layer.instrument.calc_max_adaptive(note, layer) 
        end
        })
        ImGui.SameLine(ctx)
         
      ImGui.Dummy(ctx,self.var.UI_linear.knobW,0 ) ImGui.SameLine(ctx)
      self.draw.sampler.content.child_tabs.general.single(note, layer,{
        name = 'Attack',
        str_id = '##rs5k_attack',
        param = 'attack',
        paramID = self.var.rack.children[note].layers[layer].instrument.attack.param_ID,
        default_val = 0,
        }) 
        ImGui.SameLine(ctx)
        
      self.draw.sampler.content.child_tabs.general.single(note, layer,{
        name = 'Decay',
        str_id = '##rs5k_Decay',
        param = 'decay',
        paramID = self.var.rack.children[note].layers[layer].instrument.decay.param_ID,
        default_val = 0,
        }) 
        ImGui.SameLine(ctx)  
        
      self.draw.sampler.content.child_tabs.general.single(note, layer,{
        name = 'Sustain',
        str_id = '##rs5k_Sustain',
        param = 'sustain',
        paramID = self.var.rack.children[note].layers[layer].instrument.sustain.param_ID,
        default_val = 0,
        }) 
        ImGui.SameLine(ctx)     
        
      self.draw.sampler.content.child_tabs.general.single(note, layer,{
        name = 'Release',
        str_id = '##rs5k_Release',
        param = 'release',
        paramID = self.var.rack.children[note].layers[layer].instrument.release.param_ID,
        default_val = 0,
        }) 
        ImGui.SameLine(ctx)  
        
    end
  end
  --------------------------------------------------------------------------------------------------------------
  function DATA:func_def_UI_draw_sampler_childpeaks()
    self.draw.sampler.content.child_peaks.all = 
    function()
      if ImGui.BeginChild( ctx, '##peakseditor', -1, self.var.UI_linear.samplepeaksH, reaper.ImGui_ChildFlags_None(), reaper.ImGui_WindowFlags_None() ) then
        local note = self.var.rack.var.LASTACTIVENOTE or -1
        local layer = self.var.rack.var.LASTACTIVENOTE_LAYER or -1
        local xav, yav = reaper.ImGui_GetContentRegionAvail(ctx)
        local wind_x, wind_y = ImGui.GetCursorScreenPos(ctx)
        
        self.draw.sampler.content.child_peaks.waveformpeaks( note, layer, wind_x, wind_y, xav, yav)
        self.draw.sampler.content.child_peaks.mousehandler( note, layer, wind_x, wind_y, xav, yav) 
        self.draw.sampler.content.child_peaks.markers_adsr.all( note, layer, wind_x+2, wind_y, xav-2, yav) 
        self.draw.sampler.content.child_peaks.filename(note, layer, wind_x, wind_y, xav, yav)
        self.draw.sampler.content.child_peaks.spl_switch(note, layer,wind_x, wind_y, xav, yav)
        
        ImGui.EndChild( ctx )
      end
    end
    ---------------------------------------------------------------------
    self.draw.sampler.content.child_peaks.markers_adsr.single =
    function(note, layer,x1,y1,w,h, params)
      if self.var.rack.children[note].layers[layer].instrument.is_rs5k ~= true then return end
      local zoomarea = (self.var.sampler.peaksEOFFS-self.var.sampler.peaksSOFFS) 
      local marker_lineH = 30
      local butH = 20
      local ymark1 = y1 + h-marker_lineH
      local ymark2 = y1 + h
      
      local param = params.key
      local SAMPLELEN = params.SAMPLELEN
      local tune = self.var.rack.children[note].layers[layer].instrument.tune.val
      local semitones = 160*(tune-0.5)
      local rate = 1/(2^(semitones / 12))
      SAMPLELEN = SAMPLELEN *rate
      
      local vall_add = params.vall_add or 0
      local markername = params.markername
      local norm_ratio = params.norm_ratio
      
      local value_normalized = vall_add + norm_ratio * ( self.var.rack.children[note].layers[layer].instrument[param].val) / SAMPLELEN
      
      if self.var.sampler.peaksSOFFS and value_normalized >= self.var.sampler.peaksSOFFS and value_normalized <= self.var.sampler.peaksEOFFS then  
        local xpos = x1 + w*(value_normalized-self.var.sampler.peaksSOFFS)/zoomarea
        ImGui.DrawList_AddLine( self.draw.draw_list,xpos,ymark1,xpos,ymark2, self.var.UI_colors.adsrmarkers|0xFF, 2 )
        ImGui.SetCursorScreenPos(ctx, xpos, ymark1)
        ImGui.SetNextItemAllowOverlap(ctx)
        ImGui.PushStyleVar(ctx, ImGui.StyleVar_FrameRounding,0)
        self.ImGui.Custom_InvisibleButton(ctx, markername..'##spl_peaks_adsr_'..param,0,butH, self.var.UI_colors.adsrmarkers|0x60) 
        -- drag
        if reaper.ImGui_IsItemClicked(ctx) then self.temp_peaksclickXpos = xpos end
        if  ImGui.IsItemActive( ctx ) and self.temp_peaksclickXpos then
          local dxdrag = reaper.ImGui_GetMouseDragDelta( ctx ,reaper.ImGui_GetMouseClickedPos(ctx,reaper.ImGui_MouseButton_Left()))
          local dx, dy = ImGui.GetMouseDelta( ctx )
          if dx~=0 then
            local xpos_new = self.utils.lim(self.temp_peaksclickXpos  + dxdrag,x1,x1+w-1)
            local value_normalized = -vall_add + self.var.sampler.peaksSOFFS +(zoomarea * (xpos_new - x1)) / (w )
            local outval = (1/norm_ratio)*(value_normalized * SAMPLELEN)
            outval = self.utils.lim(outval)
            local paramID = self.var.rack.children[note].layers[layer].instrument[param].param_ID
            self.process.rack.children.instrument.setval(note, layer, paramID, outval)  
            self.var.rack.children[note].layers[layer].instrument[param].val = outval -- immediately set
            self.process.rack.children.layer.instrument.formatparams(note, layer)
            self.process.rack.children.layer.instrument.calc_max_adaptive(note, layer)
          end
        end
        ImGui.PopStyleVar(ctx)
      end
    end
    ---------------------------------------------------------------------
    self.draw.sampler.content.child_peaks.markers_adsr.all =
    function(note, layer,x1,y1,w,h)
      if not self.var.rack.children[note].layers[layer].instrument.attack then return end
      if not self.var.rack.children[note].layers[layer].extstate and self.var.rack.children[note].layers[layer].extstate.SAMPLELEN  then return end
      local SAMPLELEN = self.var.rack.children[note].layers[layer].extstate.SAMPLELEN
      self.draw.sampler.content.child_peaks.markers_adsr.single(note, layer,x1,y1,w,h,{key = 'attack', norm_ratio = self.var.ADSR_A_reaper_normalize_ratio, markername = 'A',SAMPLELEN=SAMPLELEN })
      local vall_add = self.var.ADSR_A_reaper_normalize_ratio * ( self.var.rack.children[note].layers[layer].instrument.attack.val) / SAMPLELEN 
      self.draw.sampler.content.child_peaks.markers_adsr.single(note, layer,x1,y1,w,h,{key = 'decay', norm_ratio = self.var.ADSR_D_reaper_normalize_ratio, markername = 'D',SAMPLELEN=SAMPLELEN, vall_add = vall_add})
      vall_add = vall_add + self.var.ADSR_D_reaper_normalize_ratio * ( self.var.rack.children[note].layers[layer].instrument.decay.val) / SAMPLELEN
      self.draw.sampler.content.child_peaks.markers_adsr.single(note, layer,x1,y1,w,h,{key = 'release', norm_ratio = self.var.ADSR_R_reaper_normalize_ratio, markername = 'R',SAMPLELEN=SAMPLELEN, vall_add = vall_add })
    end
    ---------------------------------------------------------------------
    self.draw.sampler.content.child_peaks.mousehandler =
    function(note, layer,x1,y1,w,h)
      local SOFFS_new, EOFFS_new
      local min_zoom = 0.01
      -- xy
      local mx, my = ImGui.GetMousePos(ctx)
      local x = (mx - x1)/w
      local y = (my - y1)/h
      
      if not self.var.sampler.peaksSOFFS then self.var.sampler.peaksSOFFS = 0 end
      if not self.var.sampler.peaksEOFFS then self.var.sampler.peaksEOFFS = 1 end 
      if not self.var.sampler.zoom then self.var.sampler.zoom = 1 end
      
      -- mid drag
      if ImGui.IsItemHovered( ctx ) and ImGui.IsMouseClicked( ctx, ImGui.MouseButton_Middle ) then self.temp_samplepeaksdraginit = CopyTable(self.var.sampler) end
      if ImGui.IsItemHovered( ctx ) and ImGui.IsMouseDown( ctx, ImGui.MouseButton_Middle ) and self.temp_samplepeaksdraginit then 
        local dx,dy = ImGui.GetMouseDelta(ctx)
        if dx ~= 0 then 
          local clickx, clicky = ImGui.GetMouseClickedPos( ctx, ImGui.MouseButton_Middle )
          local deltax = ImGui.GetMouseDragDelta( ctx , clickx, clicky, ImGui.MouseButton_Middle ,0)
          deltax = (deltax) / w
          if self.temp_samplepeaksdraginit.peaksSOFFS - deltax > 0.9 then deltax = (self.temp_samplepeaksdraginit.peaksSOFFS - 0.9) end
          SOFFS_new = self.utils.lim(self.temp_samplepeaksdraginit.peaksSOFFS - deltax*self.var.sampler.zoom)
          EOFFS_new = self.utils.lim(self.temp_samplepeaksdraginit.peaksEOFFS - deltax*self.var.sampler.zoom,math.max(min_zoom,SOFFS_new),1 ) 
        end
      end
      
      -- wheel
      local wheel = ImGui.GetMouseWheel(ctx) 
      if wheel ~= 0 and ImGui.IsItemHovered( ctx ) then 
        wheel = math.abs(wheel) / wheel
        self.var.sampler.zoom = self.utils.lim(1 - wheel*0.1, min_zoom,2)
        if self.var.sampler.zoom == zoom then return end
        
        -- get cur offs
        local x1 = self.var.sampler.peaksSOFFS
        local x2 = self.var.sampler.peaksEOFFS
        local x0 =  x1 + x * (x2 - x1) 
        local range_zoomed = self.var.sampler.zoom
        
        -- set
        SOFFS_new = self.utils.lim(x0 + self.var.sampler.zoom * (x1-x0))
        EOFFS_new = self.utils.lim(x0 + self.var.sampler.zoom * (x2-x0),SOFFS_new,1)
      end
      
      -- apply
      if SOFFS_new and EOFFS_new then 
        self.var.sampler.zoom = EOFFS_new - SOFFS_new
        
        -- limit relative to sample len
        if self.var.rack.children[note].layers[layer].extstate and self.var.rack.children[note].layers[layer].extstate.SAMPLELEN  then 
          local minarea = 0.01 -- seconds
          if self.var.sampler.zoom * self.var.rack.children[note].layers[layer].extstate.SAMPLELEN < minarea then 
            self.var.sampler.zoom = minarea / self.var.rack.children[note].layers[layer].extstate.SAMPLELEN
            return
          end
        end
        
        -- limit zoom to its minimum
        if self.var.sampler.zoom < min_zoom then return end
        
        self.var.sampler.peaksSOFFS = SOFFS_new
        self.var.sampler.peaksEOFFS = EOFFS_new
        self.process.sampler.peaks.collect()
      end
      
    end
    ---------------------------------------------------------------------
    self.draw.sampler.content.child_peaks.filename = 
    function(note,layer, wind_x, wind_y, xav, yav)
      local filename
      if (self.var.rack.children[note] and self.var.rack.children[note].layers and self.var.rack.children[note].layers[layer] and self.var.rack.children[note].layers[layer].instrument and self.var.rack.children[note].layers[layer].instrument.sample and self.var.rack.children[note].layers[layer].instrument.sample.filename) then 
        filename =self.var.rack.children[note].layers[layer].instrument.sample.filename 
      end
      if not filename then return end
      ImGui.SetCursorScreenPos(ctx, wind_x, wind_y)
      ImGui.PushStyleColor(ctx, ImGui.Col_FrameBg, 0) 
      ImGui.PushFont(ctx, self.font, self.var.UI_linear.font_sz_small)
      ImGui.SetNextItemWidth(ctx,-1)
      ImGui.InputText( ctx,'##peakseditor_splname', filename, reaper.ImGui_InputTextFlags_ReadOnly()|reaper.ImGui_InputTextFlags_ElideLeft())
      ImGui.PopFont(ctx)
      ImGui.PopStyleColor(ctx)
    end
    ---------------------------------------------------------------------
    self.draw.sampler.content.child_peaks.spl_switch = 
    function(note,layer,wind_x, wind_y, xav, yav) 
      local controlsoffsY = 20
      ImGui.SetCursorScreenPos(ctx, wind_x + xav - 95, wind_y + controlsoffsY) -- + yav -
      if ImGui.ArrowButton(ctx,'##peakseditor_prevspl',ImGui.Dir_Left) then self.process.rack.children.sample.switch(0,self.var.rack.var.LASTACTIVENOTE,self.var.rack.var.LASTACTIVENOTE_LAYER) end ImGui.SetItemTooltip( ctx,'Previous sample')
      ImGui.SameLine(ctx)
      if ImGui.ArrowButton(ctx,'##peakseditor_nextspl',ImGui.Dir_Right) then self.process.rack.children.sample.switch(1,self.var.rack.var.LASTACTIVENOTE,self.var.rack.var.LASTACTIVENOTE_LAYER) end ImGui.SetItemTooltip( ctx,'Next sample')
      ImGui.SameLine(ctx)
      if self.ImGui.Custom_ImageButton( ctx, '##peakseditor_randspl', 20, nil, "random", 0xF0F0F0BF  ) then self.process.rack.children.sample.switch(2,self.var.rack.var.LASTACTIVENOTE,self.var.rack.var.LASTACTIVENOTE_LAYER) end  ImGui.SetItemTooltip( ctx,'Random sample')
      ImGui.SameLine(ctx)
      if self.ImGui.Custom_ImageButton( ctx, '##peakseditor_ME', 20, nil, "folder", 0xF0F0F0BF  ) then self.process.rack.children.sample.shoME(self.var.rack.var.LASTACTIVENOTE,self.var.rack.var.LASTACTIVENOTE_LAYER) end  ImGui.SetItemTooltip( ctx,'Random sample')
    end
    ---------------------------------------------------------------------
    self.draw.sampler.content.child_peaks.waveformpeaks = 
    function(note,layer,wind_x, wind_y, xav, yav) 
      self.var.sampler.peaksW = xav 
      
      reaper.ImGui_DrawList_AddRectFilled( self.draw.draw_list, xav, yav, xav+wind_x, yav+wind_y, 0x000000FF, self.var.UI_linear.round_corners, reaper.ImGui_DrawFlags_None())
      local col_upr_left, col_upr_right, col_bot_right, col_bot_left =
        self.var.UI_colors.peaksBg|0xF0,
        self.var.UI_colors.peaksBg|0x50,
        self.var.UI_colors.peaksBg|0x50,
        self.var.UI_colors.peaksBg|0x50
      ImGui.DrawList_AddRectFilledMultiColor( self.draw.draw_list, wind_x, wind_y, wind_x+xav, wind_y+yav, col_upr_left, col_upr_right, col_bot_right, col_bot_left )
      if (self.var.sampler.peaks_array) then self.draw.peaks(self.var.sampler.peaks_array, wind_x,wind_y,xav,yav) end
      ImGui.SetNextItemAllowOverlap(ctx)
      ImGui.SetCursorScreenPos(ctx, wind_x, wind_y)
      ImGui.InvisibleButton(ctx, 'peaksarea', xav, yav)
      
    end
  end
  --------------------------------------------------------------------------------------------------------------
  function DATA:func_def_UI_draw_sampler()  
    self.draw.sampler.all = 
    function()
      local note = -1
      if self.var.rack.var.LASTACTIVENOTE then note = self.var.rack.var.LASTACTIVENOTE end
      if self.var.rack.children[note] then
        self.draw.sampler.content.all()
       else
        self.draw.sampler.startup()
      end
    end
    ---------------------------------------------------------------------
    self.draw.sampler.content.all = 
    function ()
      -- validate device
      local note = self.var.rack.var.LASTACTIVENOTE or -1
      if not self.var.rack.children[note] then ImGui.TextDisabled(ctx, 'Device not found') return end 
      self.draw.sampler.content.device_header() 
      self.draw.sampler.content.child_header()
      self.draw.sampler.content.child_peaks.all()
      self.draw.sampler.content.child_tabs.all() 
    end 
    ---------------------------------------------------------------------
    self.draw.sampler.startup =
    function ()
      -- info
      ImGui.Dummy(ctx, 0, 20)
      ImGui.Indent(ctx, 10)
      ImGui.TextWrapped(ctx, 'Drop any sample from MediaExplorer or OS explorer to pads to start a control over rack. Curently there is no any selected pad. Select any pad contain sample to edit pad controls.')
      
      
      
      if self.var.ext.CONF_ignoreDBload.current == 0 then 
        ImGui.Dummy(ctx, 0, 20)
        ImGui.TextWrapped(ctx, 'For advanced users:\nIf you made a setup of database maps (see Settings/Database maps), you can load database to pads.')
        
        if ImGui.Button(ctx, 'Load random samples to all rack',ctrlW) then self.process.ext.db_maps.load() end ImGui.SameLine(ctx)
        if ImGui.Button(ctx, '...or to selected pad only',-1) then self.process.ext.db_maps.load(true) end
        ImGui.SetNextItemWidth(ctx,self.var.UI_linear.settings_itemW) self.draw.databasemaps.selector() ImGui.SameLine(ctx)
        if reaper.ImGui_ArrowButton(ctx,'##switchdbprev',reaper.ImGui_Dir_Left()) then self.process.ext.db_maps.switchlist(-1) end ImGui.SameLine(ctx)
        if reaper.ImGui_ArrowButton(ctx,'##switchdbnext',reaper.ImGui_Dir_Right()) then self.process.ext.db_maps.switchlist(1) end ImGui.SameLine(ctx)
        
        ImGui.Button(ctx, 'Rename##renamecurrentmap',-1) 
        ImGui.OpenPopupOnItemClick( ctx, 'renamecurrentmappopup', reaper.ImGui_PopupFlags_None() )
        if ImGui.BeginPopup( ctx, 'renamecurrentmappopup', reaper.ImGui_PopupFlags_None() ) then
          if self.var.ext.CONF_databasemaps_currentID.current and  self.var.ext.db_maps and self.var.ext.db_maps[self.var.ext.CONF_databasemaps_currentID.current] and self.var.ext.db_maps[self.var.ext.CONF_databasemaps_currentID.current].dbname then preview = self.var.ext.db_maps[self.var.ext.CONF_databasemaps_currentID.current].dbname end  
          local retval, buf = reaper.ImGui_InputText( ctx, '##dbcurname', preview, ImGui.InputTextFlags_None)--AutoSelectAll )
          if retval then self.var.ext.db_maps[self.var.ext.CONF_databasemaps_currentID.current].dbname = buf end
          if reaper.ImGui_IsItemDeactivatedAfterEdit(ctx) then self.process.ext.db_maps.set() end
          ImGui.EndPopup( ctx )
        end
      end 
      
      
    end
    ---------------------------------------------------------------------
    self.draw.sampler.content.child_header =
    function()
      local note = self.var.rack.var.LASTACTIVENOTE or -1 
      local layer = self.var.rack.var.LASTACTIVENOTE_LAYER or -1
      if not (self.var.rack.children[note].device and self.var.rack.children[note].device.TYPE_DEVICE == true ) then return end
      
      ImGui.SameLine(ctx)
      ImGui.BulletText(ctx,'')
      ImGui.SameLine(ctx)  
      
      if (self.var.rack.children[note].layers and self.var.rack.children[note].layers[layer] ) then
        -- child color
          local col_rgb  = self.var.rack.children[note].layers[layer].params.I_CUSTOMCOLOR  or 0 
          local retval, col_rgba = ImGui.ColorEdit4( ctx, '##coloreditpadchild', self.utils.getImGuiRGBAfromReaperRGB(col_rgb), ImGui.ColorEditFlags_None|ImGui.ColorEditFlags_NoInputs)--|ImGui.ColorEditFlags_NoAlpha )
          if retval then 
            local r, g, b = (col_rgba>>24)&0xFF, (col_rgba>>16)&0xFF, (col_rgba>>8)&0xFF
            col_rgb = ColorToNative( r, g, b )
            self.var.rack.children[note].layers[layer].params.I_CUSTOMCOLOR  = col_rgb|0x1000000
            self.process.rack.children.set_track_color(note, layer, col_rgb)
          end
        
        -- child FX
          ImGui.SameLine(ctx)
          local note = self.var.rack.var.LASTACTIVENOTE or -1
          if ImGui.Button(ctx, 'FX##child_fx') then self.process.rack.children.openFX(note, layer) end 
      end
      
      -- layer_selector
        ImGui.SameLine(ctx) 
        self.draw.sampler.content.layer_selector()
    end
    ---------------------------------------------------------------------
    self.draw.sampler.content.device_header =
    function()
      local note = self.var.rack.var.LASTACTIVENOTE or -1
      -- device color
        local col_rgb  = self.var.rack.children[note].params.I_CUSTOMCOLOR  or 0 
        local retval, col_rgba = ImGui.ColorEdit4( ctx, '##coloreditpaddevice', self.utils.getImGuiRGBAfromReaperRGB(col_rgb), ImGui.ColorEditFlags_None|ImGui.ColorEditFlags_NoInputs)--|ImGui.ColorEditFlags_NoAlpha )
        if retval then 
          local r, g, b = (col_rgba>>24)&0xFF, (col_rgba>>16)&0xFF, (col_rgba>>8)&0xFF
          col_rgb = ColorToNative( r, g, b )
          self.var.rack.children[note].params.I_CUSTOMCOLOR  = col_rgb|0x1000000
          self.process.rack.children.set_track_color(note,nil, col_rgb)
        end
      
      -- device FX
        ImGui.SameLine(ctx)
        local note = self.var.rack.var.LASTACTIVENOTE or -1
        if ImGui.Button(ctx, 'FX##device_fx') then self.process.rack.children.openFX(note) end
      
      -- deviceName
        ImGui.SameLine(ctx)
        self.draw.sampler.content.deviceName()
    end 
    ----------------------------------------------------------------------
    self.draw.sampler.content.layer_selector = 
    function()
      local note = self.var.rack.var.LASTACTIVENOTE or -1
      if not self.var.rack.children[note] then return end 
      local layer = self.var.rack.var.LASTACTIVENOTE_LAYER or -1
      
      local layerselectW = 150
      if not (self.var.rack.children[note] and self.var.rack.children[note].device and self.var.rack.children[note].device.TYPE_DEVICE==true and layer ~= 0)  then return end
      local preview_value = string.format('%02d',layer)..' '..self.var.rack.children[note].layers[layer].params.P_NAME
      ImGui.SetNextItemWidth(ctx, -1)
      ImGui.PushStyleColor(ctx, ImGui.Col_FrameBg, self.var.UI_colors.InputTextBg) 
      if ImGui.BeginCombo( ctx, '##layerselect', preview_value, ImGui.ComboFlags_None ) then
        for layerID = 1, #self.var.rack.children[note].layers do
          if ImGui.Selectable(ctx, string.format('%02d',layerID)..' '..self.var.rack.children[note].layers[layerID].params.P_NAME..'##layers_selectorNsame'..layerID,layerID == layer, ImGui.SelectableFlags_None) then
            self.var.rack.var.LASTACTIVENOTE_LAYER = layerID
            self.process.rack.parent.set_ext_state() 
            self.process.sampler.peaks.collect()
          end
        end
        ImGui.EndCombo( ctx )
      end 
      
      if ImGui.BeginDragDropTarget( ctx ) then  
        self.process.rack.changesample.dropsampletolayername.all(note)
        ImGui_EndDragDropTarget( ctx )
      end
      
      
      ImGui.PopStyleColor(ctx)
    end
    ---------------------------------------------------------------------
    self.draw.sampler.content.deviceName=
    function()
      local note = self.var.rack.var.LASTACTIVENOTE or -1
      local layer = self.var.rack.var.LASTACTIVENOTE_LAYER or -1
      
      -- name
      ImGui.PushStyleVar(ctx, ImGui.StyleVar_ButtonTextAlign,0,0.5)
      ImGui.PushStyleColor(ctx, ImGui.Col_FrameBg, self.var.UI_colors.InputTextBg) 
      ImGui.SetNextItemWidth(ctx, 150)
      local retval, buf = reaper.ImGui_InputText( ctx, '##sampler_activename', self.var.rack.children[note].params.P_NAME, ImGui.InputTextFlags_EnterReturnsTrue )
      if retval then
        self.var.rack.children[note].params.P_NAME = buf -- immediately refresh
        self.process.rack.children.set_track_name(note, buf)
      end
      ImGui.PopStyleVar(ctx)
      ImGui.PopStyleColor(ctx)
      
      if ImGui.BeginDragDropTarget( ctx ) then  
        self.process.rack.changesample.dropsampletodevicename.all(note)
        ImGui_EndDragDropTarget( ctx )
      end 
      
      if  self.var.rack.children[note].layers and 
          self.var.rack.children[note].layers[layer] and 
          self.var.rack.children[note].layers[layer].instrument and 
          self.var.rack.children[note].layers[layer].instrument.sample and 
          self.var.rack.children[note].layers[layer].instrument.sample.filename then
        ImGui.SetItemTooltip(ctx, self.var.rack.children[note].layers[layer].instrument.sample.filename)
      end
    end
  end
  --------------------------------------------------------------------------------------------------------------
  function DATA:func_def_UI_draw_databasemaps() 
    self.draw.databasemaps.all = 
    function()
      local ctrlW = 280
      if ImGui.Checkbox( ctx, 'Do not load databases',                                   self.var.ext.CONF_ignoreDBload.current == 1 ) then self.var.ext.CONF_ignoreDBload.current =self.var.ext.CONF_ignoreDBload.current~1 self.process.ext.save() end ImGui.SameLine(ctx)
      self.ImGui.Custom_HelpMarker('May increase loading time, but you wont be able to use databases\n'..'Current loading time: '..(math.floor(10000*self.var.loadtime)/10000)..' seconds')
      
      if self.var.ext.CONF_ignoreDBload.current == 1 then reaper.ImGui_BeginDisabled(ctx,true) end 
        if ImGui.Button(ctx, 'Load random samples to all rack',ctrlW) then self.process.ext.db_maps.load() end ImGui.SameLine(ctx)
        if ImGui.Button(ctx, '...or to selected pad only',-1) then self.process.ext.db_maps.load(true) end
        ImGui.SetNextItemWidth(ctx,ctrlW) self.draw.databasemaps.selector() ImGui.SameLine(ctx)
        if reaper.ImGui_ArrowButton(ctx,'##switchdbprev',reaper.ImGui_Dir_Left()) then self.process.ext.db_maps.switchlist(-1) end ImGui.SameLine(ctx)
        if reaper.ImGui_ArrowButton(ctx,'##switchdbnext',reaper.ImGui_Dir_Right()) then self.process.ext.db_maps.switchlist(1) end ImGui.SameLine(ctx)
        
        ImGui.Button(ctx, 'Rename##renamecurrentmap',-1) 
        ImGui.OpenPopupOnItemClick( ctx, 'renamecurrentmappopup', reaper.ImGui_PopupFlags_None() )
        if ImGui.BeginPopup( ctx, 'renamecurrentmappopup', reaper.ImGui_PopupFlags_None() ) then
          if self.var.ext.CONF_databasemaps_currentID.current and  self.var.ext.db_maps and self.var.ext.db_maps[self.var.ext.CONF_databasemaps_currentID.current] and self.var.ext.db_maps[self.var.ext.CONF_databasemaps_currentID.current].dbname then preview = self.var.ext.db_maps[self.var.ext.CONF_databasemaps_currentID.current].dbname end  
          local retval, buf = reaper.ImGui_InputText( ctx, '##dbcurname', preview, ImGui.InputTextFlags_None)--AutoSelectAll )
          if retval then self.var.ext.db_maps[self.var.ext.CONF_databasemaps_currentID.current].dbname = buf end
          if reaper.ImGui_IsItemDeactivatedAfterEdit(ctx) then self.process.ext.db_maps.set() end
          ImGui.EndPopup( ctx )
        end
        self.draw.databasemaps.mapping()
      if self.var.ext.CONF_ignoreDBload.current == 1 then reaper.ImGui_EndDisabled(ctx) end 
    end 
    
    ---------------------------------------------------------------------
    self.draw.databasemaps.mapping= 
    function()
      ImGui.SeparatorText(ctx, 'Mapping') 
      -- overview
        ImGui.InvisibleButton( ctx, '##temp_setnotedbmap', -150,20 )
        if retval then self.temp_setnotedbmap = v end
        local x1, y1 = reaper.ImGui_GetItemRectMin( ctx )
        local w1, h1 = reaper.ImGui_GetItemRectSize( ctx )
        local stepW = w1 / 128
        for note = 0, 127 do
          if 
            self.var.ext.db_maps and
            self.var.ext.db_maps[self.var.ext.CONF_databasemaps_currentID.current] and
            self.var.ext.db_maps[self.var.ext.CONF_databasemaps_currentID.current].mapping and
            self.var.ext.db_maps[self.var.ext.CONF_databasemaps_currentID.current].mapping[note] then 
            ImGui.DrawList_AddRectFilled( self.draw.draw_list, x1+stepW*note, y1, x1+stepW*(note+1), y1+h1, self.var.UI_colors.fill_active_values_in_sliders, 1, reaper.ImGui_DrawFlags_None() )
          end
        end
        ImGui.DrawList_AddRect( self.draw.draw_list, x1, y1, x1+w1, y1+h1, 0x505050FF, 1, reaper.ImGui_DrawFlags_None() )
        ImGui.SameLine(ctx)
        if ImGui.Button(ctx, 'Clear mapping',-1) then  self.process.ext.db_maps.clear()  end
        
      -- mapping
      if ImGui.BeginChild( ctx, '##databasemapsmappingchild', -1, -1, ImGui.ChildFlags_None , ImGui.WindowFlags_None ) then 
        ImGui.PushStyleVar(ctx, ImGui.StyleVar_ButtonTextAlign, 0, 0.5)
        local pad_name 
        local selnote = self.var.rack.var.LASTACTIVENOTE or -1
        for note = 0, 127 do
          pad_name = 'Note '..note
          if self.var.rack.layout.mapping and self.var.rack.layout.mapping[note] and self.var.rack.layout.mapping[note].pad_name then pad_name = self.var.rack.layout.mapping[note].pad_name end
          local bcol  if selnote == note then bcol = self.var.ext.UI_colRGBA_maintheme.current|0xFF  end
          self.ImGui.Custom_InvisibleButton(ctx, pad_name, 100,h, bcol)
          
          ImGui.SameLine(ctx)
          local is_note_device = self.var.rack.children[note] and self.var.rack.children[note].device and self.var.rack.children[note].device.TYPE_DEVICE == true
          local is_available_to_set =
            (self.var.rack.children[note] and 
              self.var.rack.children[note].layers and 
              self.var.rack.children[note].layers[1] ) ~= nil 
          local flags = 0 
          if self.var.rack.children[note] and 
            self.var.rack.children[note].layers and 
            self.var.rack.children[note].layers[1] and 
            self.var.rack.children[note].layers[1].extstate and 
            self.var.rack.children[note].layers[1].extstate.SPLLISTDB_flags then 
            flags = self.var.rack.children[note].layers[1].extstate.SPLLISTDB_flags
          end 
          
          if is_available_to_set ~= true  then ImGui.BeginDisabled(ctx, true)  end
          if ImGui.Checkbox(ctx, 'Use##dbuse'..note, flags&1==1 ) then self.process.ext.db_maps.setflags(note,1) end ImGui.SameLine(ctx)
          if ImGui.Checkbox(ctx, 'Lock##dbLock'..note, flags&2==2 ) then self.process.ext.db_maps.setflags(note,2) end self.ImGui.Custom_HelpMarker('Lock from "New random kit" action',nil,true) ImGui.SameLine(ctx) 
          if is_available_to_set ~= true  then ImGui.EndDisabled(ctx)  end
          
          if is_note_device  == true  then ImGui.TextDisabled(ctx, 'Load map to device is not supported') goto nextnote  end
          
          -- db selector
            local preview = ''
            local dbmapnumber = self.var.ext.CONF_databasemaps_currentID.current or -1
            if self.var.ext.db_maps 
              and dbmapnumber
              and self.var.ext.db_maps[dbmapnumber]
              and self.var.ext.db_maps[dbmapnumber].mapping
              and self.var.ext.db_maps[dbmapnumber].mapping[note]
              and self.var.ext.db_maps[dbmapnumber].mapping[note].dbname then
              preview = self.var.ext.db_maps[dbmapnumber].mapping[note].dbname
            end
            reaper.ImGui_SetNextItemWidth(ctx,-1)
            if ImGui.BeginCombo( ctx, '##dbselect'..note, preview, ImGui.ComboFlags_None ) then
              if ImGui.Selectable( ctx, 'Clear', false, ImGui.SelectableFlags_None) then 
                self.var.ext.db_maps[dbmapnumber].mapping[note] = nil
                self.process.ext.db_maps.set()
              end
              for dbname in pairs(self.var.MEdatabase) do
                if ImGui.Selectable( ctx, dbname, false, ImGui.SelectableFlags_None) then 
                  if not  self.var.ext.db_maps[dbmapnumber] then  self.var.ext.db_maps[dbmapnumber] = {} end
                  if not  self.var.ext.db_maps[dbmapnumber].mapping then  self.var.ext.db_maps[dbmapnumber].mapping = {} end
                  if not  self.var.ext.db_maps[dbmapnumber].mapping[note] then  self.var.ext.db_maps[dbmapnumber].mapping[note] = {} end
                  self.var.ext.db_maps[dbmapnumber].mapping[note].dbname = dbname
                  self.process.ext.db_maps.set()
                end
              end
              ImGui.EndCombo( ctx )
            end
          ::nextnote::
        end
        ImGui.PopStyleVar(ctx)
        ImGui.EndChild( ctx)
      end 
    end 
    ---------------------------------------------------------------------
    self.draw.databasemaps.selector= 
    function()
      if self.var.ext.db_maps then   
        if ImGui.BeginCombo( ctx, '##Loaddatabasemap_samplstartup', self.var.ext.db_maps[self.var.ext.CONF_databasemaps_currentID.current].dbname, ImGui.ComboFlags_None ) then--|ImGui.ComboFlags_NoArrowButton
          for i = 1, self.var.db_maps_allowed_cnt do
            if ImGui.Selectable( ctx, self.var.ext.db_maps[i].dbname..'##dbmapsel'..i, i == self.var.ext.CONF_databasemaps_currentID.current, ImGui.SelectableFlags_None) then self.var.ext.CONF_databasemaps_currentID.current = i self.process.ext.save() end
          end
          ImGui.EndCombo( ctx)
        end
      end
    end
    
  end
  --------------------------------------------------------------------------------------------------------------
  function DATA:func_def_UI_draw_tabsL()
    self.draw.tabsL.all =
    function() 
      local xav, yav = ImGui.GetContentRegionAvail(ctx)
      ImGui.PushFont(ctx, self.font, self.var.UI_linear.font_sz_tabs)
      if ImGui.BeginChild( ctx, '##area_tabsL', self.var.UI_linear.dyn_tabbar_W, -1, ImGui.ChildFlags_None, ImGui.WindowFlags_None ) then 
      
        self.process.rack.calc_peaks_W()-- calc pad width for peaks
        
        ImGui.Dummy(ctx,0,0)ImGui.SameLine(ctx)
        if ImGui.BeginTabBar( ctx, '##area_tabsL_bar', ImGui.TabBarFlags_None) then 
            
          -- close
            if ImGui.TabItemButton(ctx, 'X##area_controlblock_close') then DATA.trigger_close = true end ImGui.SetItemTooltip( ctx, 'Close' )-- ImGui.SameLine(ctx)
            
          -- settings + decorations
          if ImGui.TabItemButton(ctx, '  ##area_controlblock_settings') then self.process.opensettings_trigger = true end ImGui.SetItemTooltip( ctx, 'Settings' )
            local x1,y1 = ImGui.GetItemRectMin(ctx)
            local w,h = ImGui.GetItemRectSize(ctx)
            local scaling = 0.7
            x1 = x1+w/2-scaling*w/2
            y1 = y1+h/2-scaling*h/2 
            ImGui.DrawList_AddImage( self.draw.draw_list, self.draw.images.settings, x1 ,y1 ,x1+scaling*w,y1+scaling*h) 
            ImGui.SetItemTooltip( ctx, 'Current rack name' )  
            
          -- rack
            local rackname = 'Rack'
            if self.var.rack.valid==true and self.var.rack.parent.params.P_NAME then rackname = self.var.rack.parent.params.P_NAME end
            if ImGui.BeginTabItem( ctx, rackname..'##area_tabsL_rack', false, ImGui.TabBarFlags_None ) then self.draw.rack.all() ImGui.EndTabItem( ctx) end 
            
          
            
          reaper.ImGui_EndTabBar( ctx )
        end 
        
        ImGui.EndChild( ctx)
      end 
      ImGui.PopFont(ctx)
    end
  end
  --------------------------------------------------------------------------------------------------------------
  function DATA:func_def_UI_draw_tabsR()
    self.draw.tabsR.all =
    function()
      local xav, yav = ImGui.GetContentRegionAvail(ctx)
      if xav < self.var.UI_linear.tabbar_W then return end 
      ImGui.PushFont(ctx, self.font, self.var.UI_linear.font_sz_tabs)
      if ImGui.BeginChild( ctx, '##area_tabs', self.var.UI_linear.tabbar_W, -1, ImGui.ChildFlags_None, ImGui.WindowFlags_None ) then
        ImGui.Dummy(ctx,0,0)ImGui.SameLine(ctx)
        if ImGui.BeginTabBar( ctx, '##area_tabs_bar', ImGui.TabBarFlags_None ) then  
          if ImGui.BeginTabItem( ctx, 'Sampler##area_tabs_Sampler', false, ImGui.TabBarFlags_None ) then self.draw.sampler.all() ImGui.EndTabItem( ctx) end
          if ImGui.BeginTabItem( ctx, 'Macro##area_tabsL_macro', false, ImGui.TabBarFlags_None ) then self.draw.macro.all() ImGui.EndTabItem( ctx) end    
          if ImGui.BeginTabItem( ctx, 'DB map##area_tabs_databasemaps', false, ImGui.TabBarFlags_None) then self.draw.databasemaps.all() ImGui.EndTabItem( ctx) end
          reaper.ImGui_EndTabBar( ctx )
        end
        ImGui.EndChild( ctx)
      end 
      ImGui.PopFont(ctx)
    end
  end
  --------------------------------------------------------------------------------------------------------------
  function DATA:func_def_process_rack_children()  
    -------------------------------------------------------------------
    self.process.rack.children.TrackIsRackChild=
    function(track)
      if not track then return end
      for note in pairs(self.var.rack.children) do
        
        if self.var.rack.children[note].layers then
          for layer in pairs(self.var.rack.children[note].layers) do
            if self.var.rack.children[note].layers[layer].params and self.var.rack.children[note].layers[layer].params.track and track == self.var.rack.children[note].layers[layer].params.track then return true, note, layer end
          end
        end
        
        if self.var.rack.children[note].params and self.var.rack.children[note].params.track and track == self.var.rack.children[note].params.track then return true, note, layer end
        
      end
    end
    -------------------------------------------------------------------
    self.process.rack.children.selecttrack= function(note) if not (self.var.rack.children[note] and self.var.rack.children[note].params) then return end local track = self.var.rack.children[note].params.track if track then SetOnlyTrackSelected(track )  end end
    -------------------------------------------------------------------
    self.process.rack.children.SetMixerScroll= function(note) if not (self.var.rack.children[note] and self.var.rack.children[note].params) then return end local track = self.var.rack.children[note].params.track if track then SetMixerScroll(track )  end end
    -------------------------------------------------------------------
    self.process.rack.children.instrument.setval = 
    function(note, layer, paramID, outval, val_key)
      local track = self.var.rack.children[note].layers[layer].params.track
      local instrument_pos = self.var.rack.children[note].layers[layer].instrument.pos
      TrackFX_SetParamNormalized( track, instrument_pos, paramID, outval )    
    end
    -------------------------------------------------------------------
    self.process.rack.children.sample.shoME =
    function(note, layer)
      if not (note and layer) then return end
      if not (self.var.rack.children[note] and self.var.rack.children[note].layers and self.var.rack.children[note].layers[layer] and self.var.rack.children[note].layers[layer].instrument and self.var.rack.children[note].layers[layer].instrument.sample and self.var.rack.children[note].layers[layer].instrument.sample.filename) then return end
      OpenMediaExplorer( filename, false )
    end  
    -------------------------------------------------------------------
    self.process.rack.children.sample.get_files_in_path = 
    function(path, file_name)
      local files_table = {}
      local i = 0
      local id = 0
      local id_current
      if not self.cache.folder_content[path] then
        repeat 
          i = i+1
          local fp = reaper.EnumerateFiles( path, i-1 )
          if fp and reaper.IsMediaExtension(fp:gsub('.+%.', ''), false) then
            id = id + 1
            if not id_current and fp == file_name then id_current = id end
            files_table[id] = { fp = path..'/'..fp, fp_short  =fp }
          end 
        until fp == nil
        table.sort(files_table, function(a,b) return a.fp_short<b.fp_short end )
        self.cache.folder_content[path] = files_table
        return files_table, id_current 
       else
        local sz = #self.cache.folder_content[path]
        local fp
        for id = 1, sz do
          fp = self.cache.folder_content[path][id].fp_short
          if not id_current and fp == file_name then id_current = id end
        end
        return self.cache.folder_content[path], id_current
      end
      
    end
    -------------------------------------------------------------------
    self.process.rack.children.sample.switch = 
    function(mode, note, layer)
      if not (note and layer) then return end
      if not (self.var.rack.children[note] and self.var.rack.children[note].layers and self.var.rack.children[note].layers[layer] and self.var.rack.children[note].layers[layer].instrument and self.var.rack.children[note].layers[layer].instrument.sample and self.var.rack.children[note].layers[layer].instrument.sample.filename) then return end
      
      local SPLLISTDB_flags =0
      if self.var.rack.children[note].layers[layer].extstate and self.var.rack.children[note].layers[layer].extstate.SPLLISTDB_flags then SPLLISTDB_flags = self.var.rack.children[note].layers[layer].extstate.SPLLISTDB_flags end 
      local fp = self.var.rack.children[note].layers[layer].instrument.sample.filename
      local path = self.utils.GetParentFolder(fp)
      local file_name = self.utils.GetSampleNameFromPath(fp)
      
      if SPLLISTDB_flags&1==1 and SPLLISTDB_flags&2==2 then return end -- skip if databse used and locked
      
      local files_table, id_current 
      if SPLLISTDB_flags&1~=1 then
        files_table, id_current = self.process.rack.children.sample.get_files_in_path(path, file_name)
       else
        id_current = 1
        if self.var.rack.children[note].layers[layer].extstate and self.var.rack.children[note].layers[layer].extstate.SPLLISTDB_ID then id_current = self.var.rack.children[note].layers[layer].extstate.SPLLISTDB_ID end 
        local SPLLISTDB_NAME
        if self.var.rack.children[note].layers[layer].extstate and self.var.rack.children[note].layers[layer].extstate.SPLLISTDB_NAME then SPLLISTDB_NAME = self.var.rack.children[note].layers[layer].extstate.SPLLISTDB_NAME end 
        if SPLLISTDB_NAME and self.var.MEdatabase and self.var.MEdatabase[SPLLISTDB_NAME].files and self.var.MEdatabase[SPLLISTDB_NAME].files and #self.var.MEdatabase[SPLLISTDB_NAME].files > 2 then files_table = self.var.MEdatabase[SPLLISTDB_NAME].files end 
      end 
      if not files_table then return end
      if not (id_current and #files_table > 0) then return end
      
      -- handle mode
      local id_new
      if mode == 0 then -- previous
        id_new = id_current -1 
        if id_new == 0 then id_new = #files_table end -- wrap
       elseif mode ==1 then -- next
        id_new = id_current +1 
        if id_new == #files_table + 1 then id_new = 1 end -- wrap
       elseif mode == 2 then -- random
        math.randomseed(time_precise()*10000)
        if #files_table < 2 then id_new = 1 end
        id_new = math.floor(math.random(#files_table-1))+1
      end
      
      local new_filename = files_table[id_new].fp
      self.var.rack.children[note].layers[layer].instrument.sample.filename = new_filename
      self.process.rack.children.replace_sample.all(note, layer, new_filename, {SOFFS = 0, EOFFS=1})
      self.process.sampler.peaks.collect()
      self.process.rack.children.layer.instrument.calc_max_adaptive(note, layer)
      -- refresh database stuff
      if SPLLISTDB_flags&1==1 then
        self.var.rack.children[note].layers[layer].extstate.SPLLISTDB_ID = id_new
        self.process.rack.children.ext_print_database_data(note, layer, {SPLLISTDB_ID = id_new}) -- immediately refresh
      end 
    end
    -------------------------------------------------------------------
    self.process.rack.children.set_track_color = 
    function(note, layer, col_rgb)
      if not (note and col_rgb) then return end
      if not (self.var.rack.children[note] and self.var.rack.children[note].params.track) then return end 
      -- set device and its chldrens
      if not layer then
        SetMediaTrackInfo_Value( self.var.rack.children[note].params.track, 'I_CUSTOMCOLOR', col_rgb|0x1000000 )
        if self.var.rack.children[note].layers then 
          for layerid = 1, #self.var.rack.children[note].layers do
            local track = self.var.rack.children[note].layers[layerid].params.track
            self.var.rack.children[note].layers[layerid].params.I_CUSTOMCOLOR = col_rgb|0x1000000 -- immediately refresh children
            SetMediaTrackInfo_Value( track, 'I_CUSTOMCOLOR', col_rgb|0x1000000 )
          end
        end
       else -- otherwise set layer only
        local track = self.var.rack.children[note].layers[layer].params.track
        SetMediaTrackInfo_Value( track, 'I_CUSTOMCOLOR', col_rgb|0x1000000 )
      end
    end
    -------------------------------------------------------------------
    self.process.rack.children.openFX =
    function(note, layer) 
      if not (note) then return end
      if not layer then
        if not (self.var.rack.children[note] and self.var.rack.children[note].params.track) then return end
        TrackFX_Show( self.var.rack.children[note].params.track,0, 1 )
       else
        if not (self.var.rack.children[note] and self.var.rack.children[note].layers and self.var.rack.children[note].layers[layer] and self.var.rack.children[note].layers[layer].params.track) then return end
        TrackFX_Show(self.var.rack.children[note].layers[layer].params.track,0, 1 )
      end
    end
    -------------------------------------------------------------------
    self.process.rack.children.set_track_name = 
    function(note, buf)
      if not (note and buf) then return end
      if not (self.var.rack.children[note] and self.var.rack.children[note].params.track) then return end
      GetSetMediaTrackInfo_String( self.var.rack.children[note].params.track, 'P_NAME', buf, true )
    end
    -------------------------------------------------------------------
    self.process.rack.children.print_basic_metadata = 
    function (note, track, is_device)
      if not (note and track) then return end
      self.process.rack.write_version_to_track(track)
      GetSetMediaTrackInfo_String( track, 'P_EXT:MPLRS5KMAN_TSADD', os.time(), true) -- print timestamp 
      GetSetMediaTrackInfo_String( track, 'P_EXT:MPLRS5KMAN_CHILD_PARENTGUID', self.var.rack.parent.params.trGUID, true) -- print parent 
      GetSetMediaTrackInfo_String( track, 'P_EXT:MPLRS5KMAN_NOTE', note, true) 
      if is_device == true then 
        GetSetMediaTrackInfo_String( track, 'P_EXT:MPLRS5KMAN_TYPE_DEVICE', 1, true) 
       else
        GetSetMediaTrackInfo_String( track, 'P_EXT:MPLRS5KMAN_TYPE_REGCHILD', 1, true) -- print child mark
      end
    end
    -------------------------------------------------------------------
    self.process.rack.children.init_rs5k_parameters = 
    function (note, track, instrument_pos)
      if not (note and track and instrument_pos) then return end  
      -- various
        TrackFX_SetParamNormalized( track, instrument_pos, 2, self.var.ext.CONF_onadd_mingain.current) -- gain for min vel  
        TrackFX_SetParamNormalized( track, instrument_pos, 8, (self.var.ext.CONF_onadd_maxvoices.current-1)/63 ) -- max voices  
        TrackFX_SetParamNormalized( track, instrument_pos, 17, self.var.ext.CONF_onadd_minvel.current/127 ) 
        TrackFX_SetParamNormalized( track, instrument_pos, 18, self.var.ext.CONF_onadd_maxvel.current/127 )  
      -- obey note off
        TrackFX_SetParamNormalized( track, instrument_pos, 11, self.var.ext.CONF_onadd_obeynoteoff.current) -- obey note offs 
      -- ADSR 
        local attack =    math.min(self.var.ADSR_A_reaper_normalize_ratio,self.var.ext.CONF_onadd_ADSR_A.current)       if self.var.ext.CONF_onadd_ADSR_flags.current&1==1 then TrackFX_SetParamNormalized( track, instrument_pos, 9, attack )  end   
        local decay_sec = math.min(self.var.ADSR_D_reaper_normalize_ratio,self.var.ext.CONF_onadd_ADSR_D.current-0.01)/15   if self.var.ext.CONF_onadd_ADSR_flags.current&2==2 then TrackFX_SetParamNormalized( track, instrument_pos, 24, decay_sec )  end 
        local sustain=    math.min(2,self.var.ext.CONF_onadd_ADSR_S.current)       if self.var.ext.CONF_onadd_ADSR_flags.current&4==4 then TrackFX_SetParamNormalized( track, instrument_pos, 25, sustain )  end
        local release =   math.min(self.var.ADSR_A_reaper_normalize_ratio,self.var.ext.CONF_onadd_ADSR_R.current)       if self.var.ext.CONF_onadd_ADSR_flags.current&8==8 then TrackFX_SetParamNormalized( track, instrument_pos, 10, release )  end  
      -- note
        TrackFX_SetParamNormalized( track, instrument_pos, 3, note/127 ) -- note range start
        TrackFX_SetParamNormalized( track, instrument_pos, 4, note/127 ) -- note range end
      -- mode
        TrackFX_SetNamedConfigParm( track, instrument_pos, 'MODE',1 )  
    end
    -------------------------------------------------------------------
    self.process.rack.children.add_rs5k_instance = 
    function(note, track) 
      -- insert
        local instrument_pos = TrackFX_AddByName( track, 'ReaSamplomatic5000', false, -1)
      -- set closed 
        if instrument_pos ~= -1 and self.var.ext.CONF_onadd_float.current == 0 then TrackFX_SetOpen( track, instrument_pos, false ) end
       
      -- return pos if valid
        if instrument_pos == -1 then instrument_pos = nil end
        return instrument_pos 
    end
    -------------------------------------------------------------------
    self.process.rack.children.move_to_structure= 
    function(track, note, new_track_device) 
        
      -- move after device if presented
      if new_track_device then 
        local IP_TRACKNUMBER = GetMediaTrackInfo_Value( new_track_device, 'IP_TRACKNUMBER' )
        ReorderSelectedTracks( IP_TRACKNUMBER, 1 ) -- extend device 
        return
      end
      
      -- rack is empty
      if self.var.rack.IP_TRACKNUMBER_start == self.var.rack.IP_TRACKNUMBER_end then
        self.process.track_selection_save()
        SetOnlyTrackSelected( track )
        ReorderSelectedTracks( self.var.rack.IP_TRACKNUMBER_end+1 , 1) -- extend device 
        self.process.track_selection_restore()
        return
      end
       
      -- new children at top
      if self.var.ext.CONF_onadd_ordering.current == 1 then 
        local destID_0based = self.var.rack.IP_TRACKNUMBER_start + 1 
        self.process.track_selection_save()
        SetOnlyTrackSelected( track )
        ReorderSelectedTracks( destID_0based, 1 ) -- extend device 
        self.process.track_selection_restore()
        return 
      end
      
      -- new children at bottom
      if self.var.ext.CONF_onadd_ordering.current == 2 then   
        self.process.track_selection_save()
        SetOnlyTrackSelected( track )
        ReorderSelectedTracks( self.var.rack.IP_TRACKNUMBER_end+1 , 2) -- extend device 
        self.process.track_selection_restore()
        return
      end
      
      -- sort by note
      if self.var.ext.CONF_onadd_ordering.current == 0 then -- add after existing previous note -- sorted by note
      
        for note0 in self.utils.spairs(self.var.rack.children) do
          if self.var.rack.children[note0].exists then   
            if note0 < note then last_note_before_dest = note0 end
            if note0 > note then next_note_after_dest = note0 break end
          end
        end  
        
        -- before first
        if not last_note_before_dest and next_note_after_dest then 
          self.process.track_selection_save()
          SetOnlyTrackSelected( track )
          ReorderSelectedTracks( self.var.rack.IP_TRACKNUMBER_start+1, 0 )
          self.process.track_selection_restore()
          return
        end
        
        -- after last
        if last_note_before_dest and not next_note_after_dest then 
          self.process.track_selection_save()
          SetOnlyTrackSelected( track )
          ReorderSelectedTracks( self.var.rack.IP_TRACKNUMBER_end+1, 2 )
          self.process.track_selection_restore()
          return
        end
        
        -- between
        if last_note_before_dest and next_note_after_dest then 
          local destID_0based = self.var.rack.children[last_note_before_dest].params.IP_TRACKNUMBER_end
          self.process.track_selection_save()
          SetOnlyTrackSelected( track )
          ReorderSelectedTracks( destID_0based, 0 )
          self.process.track_selection_restore()
          return
        end
        
      end
    end
    -------------------------------------------------------------------
    self.process.rack.children.create_new_child =
    function(note, new_track_device)
    
      if not note then return end
      -- add track
        local cnt_tracks = CountTracks(self.var.proj)
        InsertTrackAtIndex(cnt_tracks, false ) 
        local track = GetTrack(self.var.proj, cnt_tracks)
        local trGUID = GetTrackGUID(track)
      -- immediately set track
        if not self.var.rack.children[note] then self.var.rack.children[note] = {} end
        if not self.var.rack.children[note].params then self.var.rack.children[note].params = {} end 
        self.var.rack.children[note].params.track = track
        self.var.rack.children[note].params.trGUID = trGUID 
      -- add_custom_template
        self.process.apply_template(track)
      -- default name
        GetSetMediaTrackInfo_String( track, 'P_NAME', 'Note '..note, 1 )  
      -- inherrit color from parent
        if self.var.ext.CONF_onadd_takeparentcolor.current == 1 then SetMediaTrackInfo_Value( track, 'I_CUSTOMCOLOR',self.var.rack.parent.params.I_CUSTOMCOLOR ) end -- color from parent  
      -- set height
        if self.var.ext.CONF_onadd_newchild_trackheight.current > 0 then  
          SetMediaTrackInfo_Value( track, 'I_HEIGHTOVERRIDE', self.var.ext.CONF_onadd_newchild_trackheight.current ) 
          if self.var.ext.CONF_onadd_newchild_trackheight_lock.current == 1 then SetMediaTrackInfo_Value( track, 'B_HEIGHTLOCK', 1) end 
        end   
      -- auto color
        if self.var.ext.CONF_autocol.current == 1 and self.var.ext.PAD_OVERRIDES.colors and self.var.ext.PAD_OVERRIDES.colors[note] then 
          local r,g,b = 
            (self.var.ext.PAD_OVERRIDES.colors[note]>>24)&0xFF, 
            (self.var.ext.PAD_OVERRIDES.colors[note]>>16)&0xFF, 
            (self.var.ext.PAD_OVERRIDES.colors[note]>>8)&0xFF
          local color = ColorToNative(r,g,b)|0x1000000
          SetMediaTrackInfo_Value( track, 'I_CUSTOMCOLOR', color )
        end 
      -- move
        self.process.rack.children.move_to_structure(track, note, new_track_device) 
      -- immediately increase rack search boundaries
        self.var.rack.IP_TRACKNUMBER_end = self.var.rack.IP_TRACKNUMBER_end + 1 
      -- SYSEXMOD
        if self.var.ext.CONF_onadd_sysexmode.current == 1 then self.process.rack.children.sysex.set(note)end  
        
      return track
    end 
    -------------------------------------------------------------------
    self.process.rack.children.sysex.get =
    function(note)  
      local track = self.var.rack.children[note].params.track
      local SYSHANDLER_ID = TrackFX_AddByName(track, 'sysex_handler', false, 0 )
      if SYSHANDLER_ID ~= -1 then
        self.var.rack.children[note].SysEx.valid = true
        self.var.rack.children[note].SysEx.handler_pos = SYSHANDLER_ID
      end
      local ret, SYSEXMOD =          GetSetMediaTrackInfo_String   ( track, 'P_EXT:MPLRS5KMAN_SYSEXMOD', 0, false) SYSEXMOD = (tonumber(SYSEXMOD) or 0)--==1
      self.var.rack.children[note].SysEx.mode = SYSEXMOD
    end
    --------------------------------------------------------------------- 
    self.process.rack.children.sysex.fixmultiple=
    function(track,fx0) 
      -- 4.57 patch
      local cnt = TrackFX_GetCount( track )
      for fx = cnt,1,-1 do
        local retval, buf = reaper.TrackFX_GetNamedConfigParm( track, fx-1, 'renamed_name' )
        if buf == 'sysex_handler' then 
          if fx0 ~= fx-1  then TrackFX_Delete( track, fx-1 ) end
        end
      end
    end
    -------------------------------------------------------------------
    self.process.rack.children.sysex.set =
    function(note)
      if not (self.var.rack.children[note] and self.var.rack.children[note].params and self.var.rack.children[note].params.track) then return end
      local track = self.var.rack.children[note].params.track
       
      -- validate sysex_handler_pos
      local sysex_handler_pos =  TrackFX_AddByName( track, 'RS5K_manager_sysex_handler', false, 1 )  
      if sysex_handler_pos == -1 then sysex_handler_pos = TrackFX_AddByName( track, 'sysex_handler', false, 1 ) end
      if sysex_handler_pos == -1 then  return end
      TrackFX_CopyToTrack( track, sysex_handler_pos, track, 0, true )
      sysex_handler_pos = 0
      
      -- move midi filter before sysex_handler_pos
      local midifilt_pos = TrackFX_AddByName( track, 'midi_note_filter', false, 0) 
      if midifilt_pos > 0 then TrackFX_CopyToTrack( track, midifilt_pos, track, 0, true ) sysex_handler_pos = 1 end
      
      -- configure sysex handler
      TrackFX_SetNamedConfigParm( track, sysex_handler_pos, 'renamed_name', 'sysex_handler' )
      TrackFX_SetParam( track, sysex_handler_pos, 0, note ) -- set note
      TrackFX_SetOpen( track, sysex_handler_pos, false )   
      
      -- 4.57 patch
      self.process.rack.children.sysex.fixmultiple(track,sysex_handler_pos)
      
      -- immediately refresh
      if not self.var.rack.children[note].SysEx then self.var.rack.children[note].SysEx = {} end
      self.var.rack.children[note].SysEx.handler_pos = sysex_handler_pos
      self.var.rack.children[note].SysEx.valid = true
      
      -- enable for ext state
      GetSetMediaTrackInfo_String( track, 'P_EXT:MPLRS5KMAN_SYSEXMOD', 1, true)
      
      -- configure rs5k instances in layers
      if self.var.rack.children[note].layers then 
        for layer = 1, #self.var.rack.children[note].layers do
          if not self.var.rack.children[note].layers[layer] then goto skiplayer end
          if not (self.var.rack.children[note].layers[layer].instrument and self.var.rack.children[note].layers[layer].instrument.pos) then goto skiplayer end
          local track = self.var.rack.children[note].layers[layer].params.track
          local rs5k_pos = self.var.rack.children[note].layers[layer].instrument.pos
          
          TrackFX_SetNamedConfigParm( track, rs5k_pos, 'MODE', 0 ) -- turn sample into freely configurable mode
          TrackFX_SetParam( track, rs5k_pos, 3, 0 ) -- set note start to 0
          TrackFX_SetParam( track, rs5k_pos, 4, 1 ) -- set note end to 127
          TrackFX_SetParam( track, rs5k_pos, 5, 0.5 - 0.5*64/80 ) -- set pitch start to -64
          TrackFX_SetParam( track, rs5k_pos, 6, 0.5 + 0.5*64/80 ) -- set pitch end to 64
          
          ::skiplayer::
        end
      end
      
    end
    
    -------------------------------------------------------------------
    self.process.rack.children.ext_print_database_data = 
    function(note, layer, options)
      function __b_ext_print_database_data() end
      if not layer then layer = 1 end
      local track = self.var.rack.children[note].layers[layer].params.track
      if not track then return end 
      if options and options.SPLLISTDB_NAME then 
        GetSetMediaTrackInfo_String( track, 'P_EXT:MPLRS5KMAN_CHILD_SPLLISTDB_NAME', options.SPLLISTDB_NAME, true) 
        if not self.var.rack.children[note].layers[layer].extstate then self.var.rack.children[note].layers[layer].extstate = {} end
        self.var.rack.children[note].layers[layer].extstate.SPLLISTDB_NAME = options.SPLLISTDB_NAME -- immediately refresh
      end
      if options and options.SPLLISTDB_ID then 
        GetSetMediaTrackInfo_String( track, 'P_EXT:MPLRS5KMAN_CHILD_SPLLISTDB_ID', options.SPLLISTDB_ID, true) 
        if not self.var.rack.children[note].layers[layer].extstate then self.var.rack.children[note].layers[layer].extstate = {} end
        self.var.rack.children[note].layers[layer].extstate.SPLLISTDB_ID = options.SPLLISTDB_ID -- immediately refresh
      end
      if options and options.SPLLISTDB then 
        GetSetMediaTrackInfo_String( track, 'P_EXT:MPLRS5KMAN_CHILD_SPLLISTDB',options.SPLLISTDB, true) 
        if not self.var.rack.children[note].layers[layer].extstate then self.var.rack.children[note].layers[layer].extstate = {} end
        self.var.rack.children[note].layers[layer].extstate.SPLLISTDB_flags = options.SPLLISTDB -- immediately refresh
      end
    end
    -------------------------------------------------------------------
    self.process.rack.children.ext_print_sample_data = 
    function(note, layer, LUFSNORM, SAMPLELEN)
      local track = self.var.rack.children[note].layers[layer].params.track
      if not track then return end
      if LUFSNORM then    
        GetSetMediaTrackInfo_String( track, 'P_EXT:MPLRS5KMAN_LUFSNORM', LUFSNORM, true) 
        if not self.var.rack.children[note].layers[layer].extstate then self.var.rack.children[note].layers[layer].extstate = {} end
        self.var.rack.children[note].layers[layer].extstate.LUFSNORM = LUFSNORM -- immediately refresh
      end
      if SAMPLELEN then   
        GetSetMediaTrackInfo_String( track, 'P_EXT:MPLRS5KMAN_SAMPLELEN', SAMPLELEN, true)  
        if not self.var.rack.children[note].layers[layer].extstate then self.var.rack.children[note].layers[layer].extstate = {} end
        self.var.rack.children[note].layers[layer].extstate.SAMPLELEN = SAMPLELEN -- immediately refresh
      end 
    end
    -------------------------------------------------------------------
    self.process.rack.children.refresh_peaks=
    function(note,layer,filename)
      self.var.sampler.peaksSOFFS = 0
      self.var.sampler.peaksEOFFS = 1
      self.var.sampler.zoom = 1
      local peaks_W = self.var.rack.peaks.children[note].peaks_W or 100
      if peaks_W < 10 then peaks_W = 200 end
      if layer == 1 and self.var.rack.peaks.children[note] then self.var.rack.peaks.children[note].peaks_array = self.process.rack.peaks.get(filename, peaks_W) end
    end
    -------------------------------------------------------------------
    self.process.rack.children.replace_sample.all = 
    function(note, layer, filename, drop_options)
      if not drop_options then drop_options  = {} end
      if self.var.ext.CONF_onadd_copytoprojectpath.current == 1 then filename = self.utils.copy_source_to_proj_folder(filename) end  
      
      local track = self.var.rack.children[note].layers[layer].params.track
      local instrument_pos = self.var.rack.children[note].layers[layer].instrument.pos
      
      -- set sample
        TrackFX_SetNamedConfigParm( track, instrument_pos, 'FILE0', filename)
        TrackFX_SetNamedConfigParm( track, instrument_pos, 'DONE', '')
      -- rename instance
        local filename_short, filename_short_without_extension = self.utils.GetSampleNameFromPath(filename)
        local instance_name = filename_short_without_extension..' (RS5K)'
        TrackFX_SetNamedConfigParm( track, instrument_pos, 'renamed_name', instance_name) 
      -- immediately refresh internals
        if not self.var.rack.children[note].layers[layer].instrument then self.var.rack.children[note].layers[layer].instrument = {} end
        if not self.var.rack.children[note].layers[layer].instrument.sample then self.var.rack.children[note].layers[layer].instrument.sample = {} end
        self.var.rack.children[note].layers[layer].instrument.sample.filename  = filename
        self.var.rack.children[note].layers[layer].instrument.sample.filename_short  = filename_short
      -- print calculated sample data to track
        local LUFSNORM, SAMPLELEN = self.process.calc_sample_data(filename, drop_options) -- options is {SOFFS EOFFS}
        self.process.rack.children.ext_print_sample_data(note, layer, LUFSNORM, SAMPLELEN)
        
      -- set offsets
        if drop_options and drop_options.SOFFS and drop_options.EOFFS then
          TrackFX_SetParamNormalized( track, instrument_pos, 13, drop_options.SOFFS )
          TrackFX_SetParamNormalized( track, instrument_pos, 14, drop_options.EOFFS )
        end
        
      -- immediately refresh pad peaks
        self.process.rack.children.refresh_peaks(note,layer,filename) 
        
      -- rename track
        self.process.rack.children.replace_sample.rename_track(note, drop_options, filename_short)
        
      -- rename layer track 
        local device_track = self.var.rack.children[note].layers[layer].params.track
        if device_track then GetSetMediaTrackInfo_String( device_track, 'P_NAME', filename_short_without_extension, true) end
        
      -- write database attach
        self.process.rack.children.ext_print_database_data(note, layer, drop_options)
        
      -- refresh rs5k position /GUID
        if instrument_pos ~= -1 then 
          local INSTR_FXGUID = reaper.TrackFX_GetFXGUID(track, instrument_pos)
          GetSetMediaTrackInfo_String( track, 'P_EXT:MPLRS5KMAN_CHILD_INSTR_FXGUID', INSTR_FXGUID, true) 
          GetSetMediaTrackInfo_String( track, 'P_EXT:MPLRS5KMAN_CHILD_ISRS5K', 1, true) 
        end
        
    end
    -------------------------------------------------------------------
    self.process.rack.children.replace_sample.rename_track = 
    function(note, drop_options, new_name)
      if drop_options and drop_options.restreict_child_track_renaming == true then return end
      if self.var.ext.CONF_onadd_renametrack.current~=1 then return end
      
      local track = self.var.rack.children[note].params.track
      if track then GetSetMediaTrackInfo_String( track, 'P_NAME', new_name, true) end
    end
    -------------------------------------------------------------------
    self.process.rack.children.mute = 
    function(note)
      if not (self.var.rack.children and self.var.rack.children[note]) then return end
      local track = self.var.rack.children[note].params.track 
      local B_MUTE = GetMediaTrackInfo_Value( track, 'B_MUTE')~1
      SetMediaTrackInfo_Value( track, 'B_MUTE', B_MUTE )
      self.var.rack.children[note].params.B_MUTE = B_MUTE
    end
    ------------------------------------------------------------------- 
    self.process.rack.children.solo = 
    function(note)
      if not (self.var.rack.children and self.var.rack.children[note]) then return end
      local track = self.var.rack.children[note].params.track
      local I_SOLO = GetMediaTrackInfo_Value( track, 'I_SOLO')
      local outval = 2 if I_SOLO>0 then outval = 0 end 
      SetMediaTrackInfo_Value( track, 'I_SOLO', outval )
      self.var.rack.children[note].params.I_SOLO = outval
    end
    
    -------------------------------------------------------------------
    self.process.rack.children.remove=
    function (note, layer) 
      if not (self.var.rack.children and self.var.rack.children[note]) then return end
      local track = self.var.rack.children[note].params.track
      if layer then 
        if not (self.var.rack.children[note].layers and self.var.rack.children[note].layers[layer]) then return end
        track = self.var.rack.children[note].layers[layer].params.track
      end
      
      if not (track and ValidatePtr2(-1,track,'MediaTrack*')) then return end
      
      Undo_BeginBlock2(self.var.proj )
      --DeleteTrack( tr_ptr )
      Main_OnCommand(40769,0)-- Unselect (clear selection of) all tracks/items/envelope points 
      SetOnlyTrackSelected( track )
      --Main_OnCommand(40184,0)-- Remove items/tracks/envelope points (depending on focus) - no prompting // THIS remove device with childrens AND handles keeping structure 
      Main_OnCommand(40005,0)-- Track: Remove tracks
      Undo_EndBlock2( self.var.proj , 'RS5k manager - Remove pad', 0xFFFFFFFF ) 
      SetOnlyTrackSelected(self.var.rack.parent.params.track )
      self.process.rack.clear_peaks(note)
    end 
    -------------------------------------------------------------------
    self.process.rack.children.layer.getFX =
    function( note, layer)
      local track = self.var.rack.children[note].layers[layer].params.track 
      --  midi filter
      local midifilt_avail
      local midifilt_pos = TrackFX_AddByName( track, 'midi_note_filter', false, 0) 
      if midifilt_pos ~= - 1 then
        self.var.rack.children[note].layers[layer].fx.midifilter = {
          pos = midifilt_pos
        }
      end 
      
      -- reaeq// validate
      local ret, FX_REAEQ_GUID = GetSetMediaTrackInfo_String( track, 'P_EXT:MPLRS5KMAN_CHILD_FX_REAEQ_GUID', '', false) 
      if FX_REAEQ_GUID then 
        if FX_REAEQ_GUID == '' then FX_REAEQ_GUID = nil end 
        if FX_REAEQ_GUID then 
          local ret, tr, eqpos = self.utils.GetFXByGUID(FX_REAEQ_GUID:gsub('[%{%}]',''),track, self.var.proj) 
          if not eqpos then FX_REAEQ_GUID=nil end
          self.var.rack.children[note].layers[layer].fx.eq = {}
          self.var.rack.children[note].layers[layer].fx.eq.pos = eqpos
          self.var.rack.children[note].layers[layer].fx.eq.cut = TrackFX_GetParamNormalized( track, eqpos, 0 ) 
          local cut_format= math.floor(({TrackFX_GetFormattedParamValue( track, eqpos, 0 )})[2]) if cut_format>10000 then cut_format = (math.floor(cut_format/100)/10)..'k' end self.var.rack.children[note].layers[layer].fx.eq.cut_format = cut_format..'Hz'
          self.var.rack.children[note].layers[layer].fx.eq.gain = TrackFX_GetParamNormalized( track, eqpos, 1)
          self.var.rack.children[note].layers[layer].fx.eq.gain_format = ({TrackFX_GetFormattedParamValue( track, eqpos, 1 )})[2]..'dB'
          self.var.rack.children[note].layers[layer].fx.eq.bw = TrackFX_GetParamNormalized( track, eqpos, 2 )
          self.var.rack.children[note].layers[layer].fx.eq.bw_format = ({TrackFX_GetFormattedParamValue( track, eqpos, 2 )})[2]
          self.var.rack.children[note].layers[layer].fx.eq.bandenabled = ({TrackFX_GetNamedConfigParm( track, eqpos, 'BANDENABLED0' )})[2]=='1'
          self.var.rack.children[note].layers[layer].fx.eq.bandtype = tonumber(({TrackFX_GetNamedConfigParm( track, eqpos, 'BANDTYPE0' )})[2])
          local reaeq_bandtype_format = '' if DATA.bandtypemap and DATA.bandtypemap[self.var.rack.children[note].layers[layer].fx.eq.bandtype] then reaeq_bandtype_format = DATA.bandtypemap[self.var.rack.children[note].layers[layer].fx.eq.bandtype] end self.var.rack.children[note].layers[layer].fx.eq.bandtype_format = reaeq_bandtype_format  
        end
      end
      
      -- waveshaper // validate
      local ret, FX_WS_GUID = GetSetMediaTrackInfo_String( track, 'P_EXT:MPLRS5KMAN_CHILD_FX_WS_GUID', '', false)
      if FX_WS_GUID then 
        if FX_WS_GUID == '' then FX_WS_GUID = nil end 
        if FX_WS_GUID then 
          local ret, tr, wspos = self.utils.GetFXByGUID(FX_WS_GUID:gsub('[%{%}]',''),track, self.var.proj) 
          if not wspos then FX_WS_GUID=nil end
          self.var.rack.children[note].layers[layer].fx.shaper = {}
          self.var.rack.children[note].layers[layer].fx.shaper.pos = wspos
          self.var.rack.children[note].layers[layer].fx.shaper.drive = TrackFX_GetParamNormalized( track, wspos, 0 )
          self.var.rack.children[note].layers[layer].fx.shaper.drivedrive_format = (math.floor(1000*self.var.rack.children[note].layers[layer].fx.shaper.drive)/10)..'%'
        end
      end
      
    end
    -------------------------------------------------------------------
    self.process.rack.children.layer.instrument.calc_max_adaptive =  
    function(note,layer)
      local track = self.var.rack.children[note].layers[layer].params.track 
      -- calc adaptive param if available
      if not ( self.var.rack.children[note].layers[layer].extstate.SAMPLELEN and self.var.rack.children[note].layers[layer].extstate.SAMPLELEN ~= 0 and self.var.rack.children[note].layers[layer].instrument  and self.var.rack.children[note].layers[layer].instrument.valid == true ) then return end
      local SAMPLELEN = self.var.rack.children[note].layers[layer].extstate.SAMPLELEN
      
      if not self.var.rack.children[note].layers[layer].instrument.tune then return end
      local tune = self.var.rack.children[note].layers[layer].instrument.tune.val
      local semitones = 160*(tune-0.5)
      local rate = 1/(2^(semitones / 12))
      SAMPLELEN = SAMPLELEN *rate
      
      local st_s = self.var.rack.children[note].layers[layer].instrument.SOFFS.val * SAMPLELEN
      local end_s = self.var.rack.children[note].layers[layer].instrument.EOFFS.val * SAMPLELEN
      self.var.rack.children[note].layers[layer].instrument.offset_loop.max_adaptive =    (end_s - st_s) / 30  
      -- ADR
      self.var.rack.children[note].layers[layer].instrument.attack.max_adaptive =         math.min(1,math.min(SAMPLELEN,self.var.ADSR_A_maxadaptive)/self.var.ADSR_A_reaper_normalize_ratio) 
      local attacksec = self.var.rack.children[note].layers[layer].instrument.attack.val*self.var.ADSR_A_reaper_normalize_ratio
      self.var.rack.children[note].layers[layer].instrument.decay.max_adaptive =          math.min(1,math.min(SAMPLELEN-attacksec,self.var.ADSR_D_maxadaptive)/self.var.ADSR_D_reaper_normalize_ratio) 
      local decaysec = self.var.rack.children[note].layers[layer].instrument.decay.val*self.var.ADSR_D_reaper_normalize_ratio
      self.var.rack.children[note].layers[layer].instrument.release.max_adaptive =        math.min(1,math.min(SAMPLELEN-attacksec-decaysec)/self.var.ADSR_R_reaper_normalize_ratio) 
    end
    -------------------------------------------------------------------
    self.process.rack.children.layer.instrument.formatparams =
    function (note,layer)
      local track = self.var.rack.children[note].layers[layer].params.track
      local instrument_pos = self.var.rack.children[note].layers[layer].instrument.pos
      if self.var.rack.children[note].layers[layer].instrument.is_rs5k ~= true then return end
      
      -- read values / format values
      for param in pairs(self.var.rack.children[note].layers[layer].instrument) do
        if type(self.var.rack.children[note].layers[layer].instrument[param]) == 'table' and self.var.rack.children[note].layers[layer].instrument[param].param_ID then 
          -- get param
            local param_ID = self.var.rack.children[note].layers[layer].instrument[param].param_ID  
          -- format param
            if  param == 'vol' or 
                param == 'tune' or 
                param == 'attack' or 
                param == 'decay' or 
                param == 'sustain' or 
                param == 'release' or 
                param == 'maxvoices' 
              then 
                local add_str
                if param =='vol' then add_str = 'dB' end
                if param =='tune' then add_str = 'st' end
                if param =='attack' then add_str = 'ms' end
                if param =='decay' then add_str = 'ms' end
                if param =='sustain' then add_str = 'dB' end
                if param =='release' then add_str = 'ms' end
                local track = self.var.rack.children[note].layers[layer].params.track
                local param_ID = self.var.rack.children[note].layers[layer].instrument[param].param_ID
                local instrument_pos = self.var.rack.children[note].layers[layer].instrument.pos
                local formatted_value = ({TrackFX_GetFormattedParamValue( track, instrument_pos, param_ID )})[2]..(add_str or '')
                self.var.rack.children[note].layers[layer].instrument[param].val_formatted = formatted_value
            end
        end
      end 
    end
    -------------------------------------------------------------------
    self.process.rack.children.layer.instrument.getparams = 
    function(note,layer)
      local track = self.var.rack.children[note].layers[layer].params.track
      -- child - instrument API data 
      if self.var.rack.children[note].layers[layer].instrument.valid ~= true then return end  
      local instrument_pos = self.var.rack.children[note].layers[layer].instrument.pos
      
      -- float
      self.var.rack.children[note].layers[layer].instrument.active = TrackFX_GetEnabled( track, instrument_pos )
      local fx_name = ({TrackFX_GetNamedConfigParm( track, instrument_pos, 'fx_name' )})[2]
      self.var.rack.children[note].layers[layer].instrument.fx_name = fx_name
      if self.var.rack.children[note].layers[layer].instrument.is_rs5k == true then
        self.var.rack.children[note].layers[layer].instrument.vol =      {param_ID = 0}
        self.var.rack.children[note].layers[layer].instrument.pan =         {param_ID = 1}
        self.var.rack.children[note].layers[layer].instrument.attack =      {param_ID = 9}
        self.var.rack.children[note].layers[layer].instrument.decay =       {param_ID = 24}
        self.var.rack.children[note].layers[layer].instrument.sustain =     {param_ID = 25}
        self.var.rack.children[note].layers[layer].instrument.release =     {param_ID = 10}
        self.var.rack.children[note].layers[layer].instrument.loop =        {param_ID = 12}
        self.var.rack.children[note].layers[layer].instrument.SOFFS = {param_ID = 13}
        self.var.rack.children[note].layers[layer].instrument.EOFFS =  {param_ID = 14}
        self.var.rack.children[note].layers[layer].instrument.offset_loop = {param_ID = 23}
        self.var.rack.children[note].layers[layer].instrument.maxvoices =   {param_ID = 8}
        self.var.rack.children[note].layers[layer].instrument.tune =        {param_ID = 15}
        self.var.rack.children[note].layers[layer].instrument.noteoff =     {param_ID = 11} 
       elseif (self.var.ext.plugin_mapping and self.var.ext.plugin_mapping[fx_name] ) then -- 3rd party 
        local supported_params = {
            'instrument_volID',
            'instrument_tuneID',
            'instrument_attackID',
            'instrument_decayID',
            'instrument_sustainID',
            'instrument_releaseID',
          }
        for pid=1, #supported_params do
          local param_str = supported_params[pid]
          local paramclear = param_str:match('instrument_(.-)ID')
          if self.var.ext.plugin_mapping[fx_name][param_str] then self.var.rack.children[note].layers[layer].instrument[paramclear] = {param_ID = self.var.ext.plugin_mapping[fx_name][param]} end
        end 
      end
      
      for param in pairs(self.var.rack.children[note].layers[layer].instrument) do
        if type(self.var.rack.children[note].layers[layer].instrument[param]) == 'table' and self.var.rack.children[note].layers[layer].instrument[param].param_ID then 
          local param_ID = self.var.rack.children[note].layers[layer].instrument[param].param_ID
          self.var.rack.children[note].layers[layer].instrument[param].val = TrackFX_GetParamNormalized( track, instrument_pos, param_ID )
        end
      end
      
      -- rs5k filename
      if self.var.rack.children[note].layers[layer].instrument.is_rs5k == true then
        local filename = ({TrackFX_GetNamedConfigParm(  track, instrument_pos, 'FILE0') })[2]
        local filename_short = self.utils.GetSampleNameFromPath(filename) 
        if filename_short and filename_short:match('(.*)%.[%a]+') then filename_short = filename_short:match('(.*)%.[%a]+') end -- remove extension
        self.var.rack.children[note].layers[layer].instrument.sample = { filename = filename, filename_short = filename_short }
      end 
      
    end
    -------------------------------------------------------------------
    self.process.rack.children.layer.instrument.validate =
    function(note,layer)
      self.var.rack.children[note].layers[layer].instrument = {valid = false}
      local track = self.var.rack.children[note].layers[layer].params.track
      
      -- child - instrument ext data
      local ret, INSTR_FXGUID = GetSetMediaTrackInfo_String  ( track, 'P_EXT:MPLRS5KMAN_CHILD_INSTR_FXGUID', 0, false)   if INSTR_FXGUID == '' then INSTR_FXGUID = nil end 
      local ret, ISRS5K = GetSetMediaTrackInfo_String   ( track, 'P_EXT:MPLRS5KMAN_CHILD_ISRS5K', 0, false) ISRS5K = (tonumber(ISRS5K) or 0)==1  
      
      -- get by GUID from ext state
      local ret, tr, instrument_pos 
      if INSTR_FXGUID then 
        ret, tr, instrument_pos  = self.utils.GetFXByGUID(INSTR_FXGUID:gsub('[%{%}]',''), track, self.var.proj)  
        if instrument_pos then 
          local retval, buf = reaper.TrackFX_GetNamedConfigParm( track, instrument_pos, 'original_name' )
          buf = buf:lower()
          if buf:match('%(rs5k%)') or buf:match('reasamplomatic') then ISRS5K = true end
        end
      end
      
      if not ret then 
        local cntfx = TrackFX_GetCount( track )
        for fx = 1, cntfx do
          local retval, buf = reaper.TrackFX_GetNamedConfigParm( track, fx-1, 'original_name' )
          buf = buf:lower()
          if buf:match('%(rs5k%)') or buf:match('reasamplomatic') then
            ISRS5K = true
            instrument_pos = fx-1
            INSTR_FXGUID = TrackFX_GetFXGUID( track, fx-1)
            break
          end
        end
      end
      
      -- apply
      if instrument_pos then
        self.var.rack.children[note].layers[layer].instrument.pos = instrument_pos
        self.var.rack.children[note].layers[layer].instrument.valid = true
        self.var.rack.children[note].layers[layer].instrument.fxGUID=     INSTR_FXGUID
        self.var.rack.children[note].layers[layer].instrument.is_rs5k=    ISRS5K
      end
    end
    -------------------------------------------------------------------
    self.process.rack.children.layer.get_extstate_data = 
    function(note,layer)
      local track = self.var.rack.children[note].layers[layer].params.track
      
      self.var.rack.children[note].layers[layer].extstate = {}
      -- various
        self.var.rack.children[note].layers[layer].extstate.LUFSNORM = tonumber(  ({GetSetMediaTrackInfo_String( track, 'P_EXT:MPLRS5KMAN_LUFSNORM', '', false)})[2]  ) or 0  -- lufs calculated
        self.var.rack.children[note].layers[layer].extstate.TSADD = tonumber(({GetSetMediaTrackInfo_String( track, 'P_EXT:MPLRS5KMAN_TSADD', '', false)})[2]) or 0  -- date added  
      -- database stuff
        self.var.rack.children[note].params.has_database_usage = false
        self.var.rack.children[note].params.has_database_locked = false
        local ret, SPLLISTDB_flags = GetSetMediaTrackInfo_String( track, 'P_EXT:MPLRS5KMAN_CHILD_SPLLISTDB', '', false) SPLLISTDB_flags = (tonumber(SPLLISTDB_flags) or 0 )
        if SPLLISTDB_flags&1==1 then 
          self.var.rack.children[note].layers[layer].extstate.SPLLISTDB_flags = SPLLISTDB_flags 
          self.var.rack.children[note].params.has_database_usage = true
        end
        if SPLLISTDB_flags&2==2 then 
          self.var.rack.children[note].params.has_database_locked = true  
        end
        local ret, SPLLISTDB_ID = GetSetMediaTrackInfo_String( track, 'P_EXT:MPLRS5KMAN_CHILD_SPLLISTDB_ID', '', false) SPLLISTDB_ID = tonumber(SPLLISTDB_ID) or 0
        self.var.rack.children[note].layers[layer].extstate.SPLLISTDB_ID = SPLLISTDB_ID
        local ret, SPLLISTDB_NAME = GetSetMediaTrackInfo_String( track, 'P_EXT:MPLRS5KMAN_CHILD_SPLLISTDB_NAME', '', false) if SPLLISTDB_NAME == '' then SPLLISTDB_NAME = nil end 
        self.var.rack.children[note].layers[layer].extstate.SPLLISTDB_NAME=SPLLISTDB_NAME 
      -- rs5k specific ext data
        local ret, SAMPLELEN = GetSetMediaTrackInfo_String( track, 'P_EXT:MPLRS5KMAN_SAMPLELEN', '', false)  SAMPLELEN = tonumber(SAMPLELEN) or 0 
        self.var.rack.children[note].layers[layer].extstate.SAMPLELEN = SAMPLELEN
        local ret, SAMPLEBPM = GetSetMediaTrackInfo_String( track, 'P_EXT:MPLRS5KMAN_SAMPLEBPM', '', false)  SAMPLEBPM = tonumber(SAMPLEBPM) or 0 
        self.var.rack.children[note].layers[layer].extstate.SAMPLEBPM = SAMPLEBPM   
        
    end
    -------------------------------------------------------------------
    self.process.rack.children.layer.get_tracks = 
    function(note)
      local device_track = self.var.rack.children[note].params.track
      self.var.rack.children[note].layers = {}
      if self.var.rack.children[note].device.TYPE_DEVICE == true then 
        -- find device children
        local depth=self.var.rack.children[note].params.I_FOLDERDEPTH
        local IP_TRACKNUMBER=self.var.rack.children[note].params.IP_TRACKNUMBER
        local layer = 0
        for i = IP_TRACKNUMBER+1, self.var.rack.IP_TRACKNUMBER_end do
          -- grab only top level
          local track = GetTrack(self.var.proj, i) 
          local params = self.process.rack.get_track_params(track)
          if depth == 1 then
            layer = layer + 1
            self.var.rack.children[note].layers[layer] = {
              params = params,
            }
          end
          depth = depth + params.I_FOLDERDEPTH
          if depth == 0 then break end
        end 
       else
        self.var.rack.children[note].layers[1] = {params = self.process.rack.get_track_params(device_track)}
      end
    end
    -------------------------------------------------------------------
    self.process.rack.children.layer.get_device_state =  
    function(note) 
      local track = self.var.rack.children[note].params.track
      local ret, TYPE_DEVICE =            GetSetMediaTrackInfo_String   ( track, 'P_EXT:MPLRS5KMAN_TYPE_DEVICE', 0, false) TYPE_DEVICE =  (tonumber(TYPE_DEVICE) or 0)==1 
      local ret, TYPE_DEVICE_AUTORANGE =  GetSetMediaTrackInfo_String   ( track, 'P_EXT:MPLRS5KMAN_TYPE_DEVICE_AUTORANGE', 0, false)  TYPE_DEVICE_AUTORANGE =  (tonumber(TYPE_DEVICE_AUTORANGE) or self.var.ext.CONF_onadd_autosetrange.current)==1  
      self.var.rack.children[note].device = {
        TYPE_DEVICE = TYPE_DEVICE,
        TYPE_DEVICE_AUTORANGE = TYPE_DEVICE_AUTORANGE
      }
      
    end
    -------------------------------------------------------------------
    self.process.rack.children.find = 
    function()
      if self.var.rack.parent.valid ~= true then return end local parent_track = self.var.rack.parent.params.track if not parent_track then return end
      
      local depth=self.var.rack.parent.params.I_FOLDERDEPTH
      for i = self.var.rack.IP_TRACKNUMBER_start+1, self.var.rack.IP_TRACKNUMBER_end do
        -- validate parent
        local track = GetTrack(self.var.proj, i) 
        local parent_track_from_child = self.process.rack.IsChildOwnedByParent(track)
        if parent_track_from_child ~= parent_track then goto nexttrack end
        
        -- validate attached note
        local ret, note =                   GetSetMediaTrackInfo_String         ( track, 'P_EXT:MPLRS5KMAN_NOTE',0, false) 
        note = tonumber(note) if not note then goto nexttrack end 
        
        -- grab only top level
        local params = self.process.rack.get_track_params(track)
        if depth == 1 then
          if not self.var.rack.children[note] then self.var.rack.children[note] = {} end
          self.var.rack.children[note].exists = true
          self.var.rack.children[note].params = params
          self.var.rack.children[note].SysEx = {} 
        end
        depth = depth + params.I_FOLDERDEPTH
        ::nexttrack::
      end
    end
  end
  --------------------------------------------------------------------------------------------------------------
  function DATA:func_def_process_rack_midibus()  
    self.process.rack.midibus.validate =  
    function() 
      if self.var.rack.valid ~= true then return end 
      if self.var.rack.midibus.valid == true then return end 
      self.process.rack.midibus.init() 
      self.process.rack.midibus.find()
      self.process.rack.midibus.build_routing()
      return true
    end
    --------------------------------------------------------------------- 
    self.process.rack.midibus.build_routing=
    function ()
      if not (self.var.rack.parent and self.var.rack.parent.valid == true) then return end 
      
      if not (self.var.rack.midibus.valid == true) then return end 
      local MIDItr = self.var.rack.midibus.params.track
      if not reaper.ValidatePtr2(self.var.proj, MIDItr, 'MediaTrack*') then return end
      
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
        for note in pairs(self.var.rack.children) do
          if not (self.var.rack.children[note] and self.var.rack.children[note].exists and self.var.rack.children[note].params) then goto skipchild end
          
          -- make sure there is no midi send to device  
          local TYPE_DEVICE = self.var.rack.children[note].device and self.var.rack.children[note].device.TYPE_DEVICE and self.var.rack.children[note].device.TYPE_DEVICE == true
          local trGUID = self.var.rack.children[note].params.trGUID
          if TYPE_DEVICE == true and trGUID and sends[trGUID] then RemoveTrackSend( MIDItr, 0, sends[trGUID].sendidx ) end
          
          -- check devicechilds/regular childs has receive from MIDI track
          if self.var.rack.children[note].layers then 
            for layer in pairs(self.var.rack.children[note].layers) do
              if self.var.rack.children[note].layers[layer] and self.var.rack.children[note].layers[layer].params.trGUID then
                local destGUID = self.var.rack.children[note].layers[layer].params.trGUID
                
                if not sends[destGUID] or 
                  (sends[destGUID] and sends[destGUID].I_MIDIFLAGS ~= self.var.rack.var.MIDIFLAGS) 
                  then   
                  local sendidx = CreateTrackSend( MIDItr, self.var.rack.children[note].layers[layer].params.track )
                  if sendidx >=0 then
                    SetTrackSendInfo_Value( MIDItr, 0, sendidx, 'I_SRCCHAN',-1 )
                    SetTrackSendInfo_Value( MIDItr, 0, sendidx, 'I_MIDIFLAGS',self.var.rack.var.MIDIFLAGS )
                    if self.var.ext.CONF_useprerecsends.current == 0 then
                      SetTrackSendInfo_Value( MIDItr, 0, sendidx, 'I_SENDMODE', 3 )
                     else 
                      SetTrackSendInfo_Value( MIDItr, 0, sendidx, 'I_SENDMODE', 8 )
                    end
                  end
                end
                
              end 
            end
          end
          ::skipchild::
        end   
    end
    ------------------------------------------------------------
    self.process.rack.midibus.init = 
    function()
      if self.var.rack.valid ~= true then return end 
      local parent_track = self.var.rack.parent.params.track if not parent_track then return end
      
      if self.var.ext.CONF_useprerecsends.current == 0 then
        -- insert new
        InsertTrackAtIndex( self.var.rack.IP_TRACKNUMBER_start+1, false )
        local MIDI_tr = GetTrack(self.var.proj, self.var.rack.IP_TRACKNUMBER_start+1)
        -- immediately increase rack search boundaries
        self.var.rack.IP_TRACKNUMBER_end = self.var.rack.IP_TRACKNUMBER_end + 1  
        -- if parent track is the only one in structure
        if self.var.rack.IP_TRACKNUMBER_start == self.var.rack.IP_TRACKNUMBER_end then 
          SetMediaTrackInfo_Value( self.var.rack.parent.params.track,'I_FOLDERDEPTH',1 ) 
          SetMediaTrackInfo_Value( MIDI_tr, 'I_FOLDERDEPTH',-self.var.rack.parent.params.real_FOLDERDEPTH-1 ) 
        end 
       else
        MIDI_tr = parent_track
      end
      -- set params
      if self.var.ext.CONF_useprerecsends.current == 0 then GetSetMediaTrackInfo_String( MIDI_tr, 'P_NAME', 'MIDI bus', 1 ) end
      SetMediaTrackInfo_Value( MIDI_tr, 'I_RECMON', 1 )
      SetMediaTrackInfo_Value( MIDI_tr, 'I_RECARM', 1 )
      SetMediaTrackInfo_Value( MIDI_tr, 'I_RECMODE', 0 ) -- record MIDI out
      local channel,physical_input = self.var.ext.CONF_midichannel.current, self.var.ext.CONF_midiinput.current   
      SetMediaTrackInfo_Value( MIDI_tr, 'I_RECINPUT', 4096 + channel + (physical_input<<5)) -- set input to all MIDI
      if self.var.ext.CONF_midioutput.current ~= -1 then SetMediaTrackInfo_Value( MIDI_tr, 'I_MIDIHWOUT', self.var.ext.CONF_midioutput.current<<5) end -- MIDI hardware output  
      self.process.rack.midibus.set_ext_state(MIDI_tr)
      
    end
    -------------------------------------------------------------------
    self.process.rack.midibus.find =
    function()
      if self.var.rack.parent.valid ~= true then return end local parent_track = self.var.rack.parent.params.track if not parent_track then return end 
      
      if self.var.ext.CONF_useprerecsends.current == 1 then
        local ret, isMIDIbus = GetSetMediaTrackInfo_String ( parent_track, 'P_EXT:MPLRS5KMAN_MIDIBUS', 0, false) -- MIDI bus
        if ret and tonumber(isMIDIbus) and tonumber(isMIDIbus) == 1 then   
          self.var.rack.midibus.valid = true
          self.var.rack.midibus.params = self.process.rack.get_track_params(parent_track) 
        end
      end
      
      
      local depth=self.var.rack.parent.params.I_FOLDERDEPTH
      for i = self.var.rack.IP_TRACKNUMBER_start+1, self.var.rack.IP_TRACKNUMBER_end do
        -- validate parent
        local track = GetTrack(self.var.proj, i) 
        local ret, isMIDIbus = GetSetMediaTrackInfo_String ( track, 'P_EXT:MPLRS5KMAN_MIDIBUS', 0, false) -- MIDI bus
        if ret and tonumber(isMIDIbus) and tonumber(isMIDIbus) == 1 then   
          self.var.rack.midibus.valid = true
          self.var.rack.midibus.params = self.process.rack.get_track_params(track) 
          return true
        end
      end
    end
    -------------------------------------------------------------------
    self.process.rack.midibus.get_choke_setup =
    function()
      if self.var.rack.midibus.valid~=true then return end
      self.var.rack.midibus.choke.valid = false
      local track = self.var.rack.midibus.params.track
      local midi_choke_container_name = 'RS5k_manager MIDI_handler'
      local container_pos =  TrackFX_AddByName( track, midi_choke_container_name, false, 0 ) 
      if container_pos == -1 then return end
      self.var.rack.midibus.choke.valid = true
      self.var.rack.midibus.choke.container_pos = container_pos 
      self.var.rack.midibus.choke.child_JSFX = {}
      
      local fxcnt = TrackFX_GetCount(track)
      local retval, container_count = reaper.TrackFX_GetNamedConfigParm( track, container_pos, 'container_count' )
      for subitem = 1, container_count do
        local choke_childID = 0x2000000 + subitem*(fxcnt+1) + (container_pos+1)
        local retval, fxname = TrackFX_GetNamedConfigParm( track, choke_childID, 'renamed_name' )
        local dest,src = fxname:match('choke (%d+) by (%d+)')
        if src and tonumber(src) then src = tonumber(src) end
        if dest and tonumber(dest) then dest = tonumber(dest) end
        if dest and src then 
          if not self.var.rack.midibus.choke.child_JSFX[dest] then self.var.rack.midibus.choke.child_JSFX[dest] = {} end  
          local retval, container_itemID = reaper.TrackFX_GetNamedConfigParm( track, container_pos, 'container_item.'..(subitem-1) )
          local val_src = TrackFX_GetParam( track, container_itemID, 0 ) 
          local val_dest = TrackFX_GetParam( track, container_itemID, 1 ) 
          local valid = val_src == src and val_dest == dest
          self.var.rack.midibus.choke.child_JSFX[dest][src] = {
            container_itemID = tonumber(container_itemID),
            valid = valid,
          }
        end
      end
    end 
    -------------------------------------------------------------------
    self.process.rack.midibus.set_ext_state =
    function(MIDI_tr)
      local track = MIDI_tr
      if not MIDI_tr then 
        if self.var.rack.midibus.valid~=true then return end
        track = self.var.rack.midibus.params.track
      end
      GetSetMediaTrackInfo_String( track, 'P_EXT:MPLRS5KMAN_CHILD_PARENTGUID', self.var.rack.parent.params.trGUID, true)
      GetSetMediaTrackInfo_String( track, 'P_EXT:MPLRS5KMAN_MIDIBUS', 1, true)
      self.process.rack.write_version_to_track(track)
    end
  end
  --------------------------------------------------------------------------------------------------------------
  function DATA:func_def_process_rack() 
    self.process.rack.read =  
    function() 
      -- reset
        self.var.rack.valid = false
        self.var.rack.children = {} 
        self.var.rack.midibus = {choke={}}
      -- project variables
        self.var.SR = tonumber(reaper.format_timestr_pos( 1-reaper.GetProjectTimeOffset(self.var.proj,false ), '', 4 )) 
      -- get parent
        self.process.rack.parent.find()
        if self.var.rack.parent.valid ~= true then self.var.rack.var = {} return end  -- reset variables 
        self.var.rack.valid = true -- confirm rack is valid if at least parent track is found
        self.process.rack.parent.get_params()  
        self.process.rack.parent.get_rack_vars()
        self.process.rack.parent.define_structure_limits()
        self.process.rack.PAD_OVERRIDES.get() -- from parent ext state
      -- get midi bus 
        self.process.rack.midibus.find() 
        self.process.rack.midibus.get_choke_setup() 
      -- get children
        self.process.rack.children.find()
        for note in pairs(self.var.rack.children) do 
          self.process.rack.children.sysex.get(note)
          self.process.rack.children.layer.get_device_state(note)
          self.process.rack.children.layer.get_tracks(note) 
          for layer in pairs(self.var.rack.children[note].layers) do
            self.process.rack.children.layer.get_extstate_data(note, layer) 
            self.process.rack.children.layer.instrument.validate(note, layer) 
            self.process.rack.children.layer.instrument.getparams(note, layer) 
            self.process.rack.children.layer.instrument.formatparams(note, layer) 
            self.process.rack.children.layer.instrument.calc_max_adaptive(note, layer) 
            self.process.rack.children.layer.getFX(note, layer) 
          end 
        end
      -- fix_missed_layer
        self.process.rack.parent.fix_missed_layer() 
      -- build layout  
        self.process.rack.layout.get()
      -- get macro
        self.process.rack.macro.get.all()   
    end 
    ------------------------------------------------------------
    self.process.rack.is_instance_already_exist = 
    function(dest_note,dest_layer)
      local track_exist = 
        self.var.rack.children and 
        self.var.rack.children[dest_note] and 
        self.var.rack.children[dest_note].layers and 
        self.var.rack.children[dest_note].layers[dest_layer] and 
        self.var.rack.children[dest_note].layers[dest_layer].params and  
        self.var.rack.children[dest_note].layers[dest_layer].params.track and  
        ValidatePtr2(self.var.proj, self.var.rack.children[dest_note].layers[dest_layer].params.track, 'MediaTrack*')
      local is_rs5k
      if track_exist == true then 
        is_rs5k = 
        self.var.rack.children[dest_note].layers[dest_layer].instrument and 
        self.var.rack.children[dest_note].layers[dest_layer].instrument.is_rs5k == true
      end
      return track_exist, is_rs5k
    end
    -------------------------------------------------------------------
    self.process.rack.calc_peaks_W=
    function()
      if not self.var.rack.layout.parameters then return end
      local xav, yav = ImGui_GetContentRegionAvail(ctx)
      xav= xav - self.var.UI_linear.dyn_rackW
      local padW, padH = math.floor(xav / self.var.rack.layout.parameters.col_cnt )-self.var.UI_linear.spacingX, math.floor(yav / self.var.rack.layout.parameters.row_cnt )-self.var.UI_linear.spacingY
      for note=0,127 do-- in pairs(self.var.rack.layout.mapping) do 
        if not self.var.rack.peaks.children[note] then self.var.rack.peaks.children[note]={} end
        self.var.rack.peaks.children[note].peaks_W = padW 
      end
    end 
    
    -------------------------------------------------------------------
    self.process.rack.parent.init = 
    function() 
      Undo_BeginBlock2(-1)
      InsertTrackInProject(-1, 0,0) 
      local tr = GetTrack(-1,0)
      GetSetMediaTrackInfo_String( tr, 'P_NAME', 'RS5k manager', true )
      reaper.SetOnlyTrackSelected( tr )
      self.utils.action(40913) --Track: Vertical scroll selected tracks into view
      Undo_EndBlock2(-1, 'Insert RS5k manager parent track', 0xFFFFFFFF)
      self.process.rack.write_version_to_track(tr)
    end 
    -------------------------------------------------------------------
    self.process.rack.write_version_to_track = function(parent_track) GetSetMediaTrackInfo_String(parent_track, 'P_EXT:MPLRS5KMAN_VERSION', rs5kman_vrs, true) end
    -------------------------------------------------------------------
    self.process.rack.parent.set_ext_state =
    function()
      if self.var.rack.valid ~= true then return end local parent_track = self.var.rack.parent.params.track if not parent_track then return end
      
      -- v4.14+
        if self.var.rack.parent.params.trGUID  then  
          local ret, GUIDINTERNAL = GetSetMediaTrackInfo_String ( parent_track, 'P_EXT:MPLRS5KMAN_GUIDINTERNAL', '', false) 
          if not ret then GetSetMediaTrackInfo_String ( parent_track, 'P_EXT:MPLRS5KMAN_GUIDINTERNAL', self.var.rack.parent.params.trGUID, true) end
        end
        if not self.var.rack.parent.GUIDINTERNAL then GetSetMediaTrackInfo_String (parent_track, 'P_EXT:MPLRS5KMAN_GUIDINTERNAL', self.var.rack.parent.params.trGUID, true) end -- v4.14+, for possible auto fix after import
        
      self.process.rack.write_version_to_track(parent_track) -- this also make parent track valid
      GetSetMediaTrackInfo_String ( parent_track, 'P_EXT:MPLRS5KMAN_LASTACTIVENOTE', self.var.rack.var.LASTACTIVENOTE or '', true)
      GetSetMediaTrackInfo_String ( parent_track, 'P_EXT:MPLRS5KMAN_LASTACTIVENOTE_LAYER', self.var.rack.var.LASTACTIVENOTE_LAYER or '', true)
      GetSetMediaTrackInfo_String ( parent_track, 'P_EXT:MPLRS5KMAN_DRRACKSHIFT', self.var.rack.var.DRRACKSHIFT or ''                   , true)
      GetSetMediaTrackInfo_String ( parent_track, 'P_EXT:MPLRS5KMAN_MACROCNT', self.var.rack.var.MACROCNT or ''                         , true)
      GetSetMediaTrackInfo_String ( parent_track, 'P_EXT:MPLRS5KMAN_LASTACTIVEMACRO', self.var.rack.var.LASTACTIVEMACRO or ''           , true)
      GetSetMediaTrackInfo_String ( parent_track, 'P_EXT:MPLRS5KMAN_MIDIFLAGS', self.var.rack.var.MIDIFLAGS or ''                       , true)
    end
    -------------------------------------------------------------------
    self.process.rack.parent.set_DRRACKSHIFT = 
    function(note)
      if self.var.rack.valid ~= true then return end local parent_track = self.var.rack.parent.params.track if not parent_track then return end 
      if self.var.ext.UI_drracklayout.current == 0 then -- grid
        local outnote = note - note%8
        if outnote >=8 then 
          outnote = note - note%16 + 4
        end
        self.var.rack.var.DRRACKSHIFT = outnote
        self.process.rack.parent.set_ext_state() 
      end 
      if self.var.ext.UI_drracklayout.current == 1 then --keys
        local outnote = note - note%24
        self.var.rack.var.DRRACKSHIFT = outnote
        self.process.rack.parent.set_ext_state()
      end 
    end
    -------------------------------------------------------------------
    self.process.rack.peaks.clear =
    function ()
      if self.var.rack.valid ~= true then return end
      for note in pairs(self.var.rack.peaks.children) do 
        self.var.rack.peaks.children[note] = {}
        if self.var.rack.peaks.children[note].layers then 
          for layer in pairs(self.var.rack.peaks.children[note].layers) do
            self.var.rack.peaks.children[note].layers = {}
          end 
        end
      end
    end
    -------------------------------------------------------------------
    self.process.rack.peaks.all=
    function(options)
      local fill_missing_only = options and options.fill_missing_only
      local clear = options and options.clear
      -- reset
      if clear == true then self.process.rack.peaks.clear() end
      for note in pairs(self.var.rack.children) do  
        
        if  self.var.rack.peaks.children and 
            self.var.rack.peaks.children[note] and 
            self.var.rack.peaks.children[note].peaks_W and
            self.var.rack.children[note].layers and 
            self.var.rack.children[note].layers[1] and
            self.var.rack.children[note].layers[1].instrument and 
            self.var.rack.children[note].layers[1].instrument.sample and 
            self.var.rack.children[note].layers[1].instrument.sample.filename
         then 
          
          if not self.var.rack.peaks.children then self.var.rack.peaks.children = {}end
          if not self.var.rack.peaks.children[note] then self.var.rack.peaks.children[note] = {} end
          if fill_missing_only ~= true or (fill_missing_only == true and self.var.rack.peaks.children[note].peaks_array == nil) then 
            self.var.rack.peaks.children[note].peaks_array = self.process.rack.peaks.get(self.var.rack.children[note].layers[1].instrument.sample.filename, self.var.rack.peaks.children[note].peaks_W)
          end
        end
        for layer in pairs(self.var.rack.children[note].layers) do
        
        end 
      end
    end
    -------------------------------------------------------------------
    self.process.rack.peaks.get=
    function(filename, padw, options)
      if not filename then return end
      if not padw then return end
      local src = PCM_Source_CreateFromFileEx(filename, true )
      if not src then return end  
      local src_len =  GetMediaSourceLength( src ) 
      local stoffs_sec = 0
      local slice_len = src_len
      -- handle sliced data
      if options and options.SOFFS and options.EOFFS then
        stoffs_sec = options.SOFFS * src_len
        slice_len = src_len * (options.EOFFS - options.SOFFS) 
      end
      local SR = GetMediaSourceSampleRate( src )
      local peakrate = SR
      if padw ~= -1 then
        peakrate =  math.max(padw / slice_len,200)
      end
      if slice_len < 0.01 then return end   
      local n_ch = 1 -- force mono
      local want_extra_type = 0
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
      PCM_Source_Destroy( src )    
      
      return buf
    end
    
    -------------------------------------------------------------------
    self.process.rack.parent.fix_missed_layer = 
    function() -- fix_missing_layer // make sure layer exist otherwise reset to 1
      if  self.var.rack.var.LASTACTIVENOTE and self.var.rack.var.LASTACTIVENOTE_LAYER and self.var.rack.children[self.var.rack.var.LASTACTIVENOTE] and 
          not ( 
            self.var.rack.children[self.var.rack.var.LASTACTIVENOTE].layers and 
            self.var.rack.children[self.var.rack.var.LASTACTIVENOTE].layers[self.var.rack.var.LASTACTIVENOTE_LAYER] 
          ) 
       then 
        self.var.rack.var.LASTACTIVENOTE_LAYER = 1 
      end
    end
    
    
    -------------------------------------------------------------------
    self.process.rack.get_track_params = 
      function(track) 
        local params = {} 
        
        -- api params
        local retval, trGUID =             GetSetMediaTrackInfo_String( track, 'GUID', '', false )  params.trGUID =  trGUID  
        local retval, P_NAME =             GetSetMediaTrackInfo_String( track, 'P_NAME', '', false ) params.P_NAME=P_NAME
        params.IP_TRACKNUMBER =             GetMediaTrackInfo_Value( track, 'IP_TRACKNUMBER')-1
        params.D_VOL =                      GetMediaTrackInfo_Value( track, 'D_VOL' )
        params.D_PAN =                      GetMediaTrackInfo_Value( track, 'D_PAN' )
        params.B_MUTE =                     GetMediaTrackInfo_Value( track, 'B_MUTE' )
        params.I_SOLO =                     GetMediaTrackInfo_Value( track, 'I_SOLO' )
        params.I_CUSTOMCOLOR =              GetMediaTrackInfo_Value( track, 'I_CUSTOMCOLOR' )
        params.I_FOLDERDEPTH =              GetMediaTrackInfo_Value( track, 'I_FOLDERDEPTH' )  
        params.I_RECMON =                   GetMediaTrackInfo_Value( track, 'I_RECMON' )  
        local I_PLAY_OFFSET_FLAG =         GetMediaTrackInfo_Value( track, 'I_PLAY_OFFSET_FLAG' ) 
        local D_PLAY_OFFSET =              GetMediaTrackInfo_Value( track, 'D_PLAY_OFFSET' ) 
        local PLAY_OFFSET = 0 if I_PLAY_OFFSET_FLAG&1==0 then if I_PLAY_OFFSET_FLAG&2==2 then PLAY_OFFSET = D_PLAY_OFFSET / DATA.SR else PLAY_OFFSET = D_PLAY_OFFSET end end 
        params.PLAY_OFFSET = PLAY_OFFSET
        params.PLAY_OFFSET_format = PLAY_OFFSET_format  
        params.track = track  
        
        
        -- get structure limits 
        params.IP_TRACKNUMBER_start = params.IP_TRACKNUMBER
        params.IP_TRACKNUMBER_end = params.IP_TRACKNUMBER
        local cnt_tracks = CountTracks( self.var.proj )
        if params.I_FOLDERDEPTH == 1 then
          local depth = 0
          for trid = params.IP_TRACKNUMBER + 1, cnt_tracks do
            local tr = GetTrack(self.var.proj, trid-1)
            depth = depth + GetMediaTrackInfo_Value( tr, 'I_FOLDERDEPTH')
            if depth <= 0 then 
              IP_TRACKNUMBER_0basedlast = trid-1
              break
            end
          end
        end 
        params.IP_TRACKNUMBER_end = IP_TRACKNUMBER_0basedlast
        
        -- get sends
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
        params.sends = sends
          
        return params
      end
    -------------------------------------------------------------------
    self.process.rack.parent.define_structure_limits = 
    function() 
      if self.var.rack.parent.valid ~= true then return end local parent_track = self.var.rack.parent.params.track if not parent_track then return end
      -- get structure limits 
      local IP_TRACKNUMBER_0based = self.var.rack.parent.params.IP_TRACKNUMBER
      local cnt_tracks = CountTracks( self.var.proj )
      local IP_TRACKNUMBER_0basedlast = IP_TRACKNUMBER_0based
      if self.var.rack.parent.params.I_FOLDERDEPTH == 1 then
        local depth = 0
        for trid = IP_TRACKNUMBER_0based + 1, cnt_tracks do
          local tr = GetTrack(self.var.proj, trid-1)
          depth = depth + GetMediaTrackInfo_Value( tr, 'I_FOLDERDEPTH')
          if depth <= 0 then 
            IP_TRACKNUMBER_0basedlast = trid-1
            break
          end
        end
      end
      self.var.rack.IP_TRACKNUMBER_start = IP_TRACKNUMBER_0based
      self.var.rack.IP_TRACKNUMBER_end = IP_TRACKNUMBER_0basedlast
    end
    -------------------------------------------------------------------
    self.process.rack.parent.find = 
    function() 
      self.var.rack.parent.valid = false -- reset 
      self.var.rack.parent.loaded_externally = false
      
      local parent_track 
      
      -- get sticked track override
      local retval, trGUIDext = GetProjExtState(self.var.proj, 'MPLRS5KMAN', 'STICKPARENTGUID' )
      if retval and trGUIDext ~= '' then 
        parent_track = self.utils.GetTrackByGUID(trGUIDext, self.var.proj) 
        if ValidatePtr2( self.var.proj, parent_track, 'MediaTrack*' ) then 
          self.var.rack.parent.loaded_externally = true 
        end
      end 
      
      -- validate selected track 
      if not parent_track then
        parent_track = GetSelectedTrack(self.var.proj,0)
        local ret
        if parent_track then ret = GetSetMediaTrackInfo_String(parent_track, 'P_EXT:MPLRS5KMAN_VERSION', '', false) end
        if not ret then parent_track = nil end
      end  
      
      -- catch parent by childen
      if parent_track then 
        local parent_track_from_child = self.process.rack.IsChildOwnedByParent(parent_track)
        if parent_track_from_child then parent_track = parent_track_from_child end
      end
      
      if parent_track then
        self.var.rack.parent.params.track = parent_track
        self.var.rack.parent.valid = true
      end
    end
    -------------------------------------------------------------------
    self.process.rack.parent.get_rack_vars = 
    function()
      if self.var.rack.parent.valid ~= true then return end local parent_track = self.var.rack.parent.params.track if not parent_track then return end
      self.var.rack.var.DRRACKSHIFT = 36
      self.var.rack.var.MACROCNT = 16
      self.var.rack.var.LASTACTIVENOTE = -1
      self.var.rack.var.LASTACTIVENOTE_LAYER = 1
      self.var.rack.var.LASTACTIVEMACRO = -1
      self.var.rack.var.MIDIFLAGS = 0
      --self.var.rack.PADNAMES_OVERRIDES = {}  
      -- grab rack parameters
      local ret, DRRACKSHIFT = GetSetMediaTrackInfo_String ( parent_track, 'P_EXT:MPLRS5KMAN_DRRACKSHIFT', 0, false)                    if ret then self.var.rack.var.DRRACKSHIFT =   tonumber(DRRACKSHIFT) end 
      local ret, MACROCNT = GetSetMediaTrackInfo_String ( parent_track, 'P_EXT:MPLRS5KMAN_MACROCNT', 0, false)                          if ret then self.var.rack.var.MACROCNT =      tonumber(MACROCNT) end 
      local ret, LASTACTIVENOTE = GetSetMediaTrackInfo_String ( parent_track, 'P_EXT:MPLRS5KMAN_LASTACTIVENOTE', 0, false)              if ret then self.var.rack.var.LASTACTIVENOTE = tonumber(LASTACTIVENOTE) end
      local ret, LASTACTIVENOTE_LAYER = GetSetMediaTrackInfo_String ( parent_track, 'P_EXT:MPLRS5KMAN_LASTACTIVENOTE_LAYER', 0, false)  if ret then self.var.rack.var.LASTACTIVENOTE_LAYER = tonumber(LASTACTIVENOTE_LAYER ) end
      local ret, LASTACTIVEMACRO = GetSetMediaTrackInfo_String ( parent_track, 'P_EXT:MPLRS5KMAN_LASTACTIVEMACRO', 0, false)            if ret then self.var.rack.var.LASTACTIVEMACRO = tonumber(LASTACTIVEMACRO ) end
      local ret, MIDIFLAGS = GetSetMediaTrackInfo_String ( parent_track, 'P_EXT:MPLRS5KMAN_MIDIFLAGS', 0, false)                        if ret then self.var.rack.var.MIDIFLAGS = tonumber(MIDIFLAGS) end
    end
    -------------------------------------------------------------------  
    self.process.rack.parent.get_params = 
    function()  
      if self.var.rack.parent.valid ~= true then return end local parent_track = self.var.rack.parent.params.track if not parent_track then return end
      self.var.rack.parent.params = self.process.rack.get_track_params(parent_track) 
      self.var.rack.parent.params.real_FOLDERDEPTH = self.process.get_track_depth(parent_track)
      -- handling imported templates with changed parent and children GUIDs
      self.var.rack.parent.wrong_parent_track_metadata = false 
      local parent_track_GUID = GetTrackGUID(  parent_track )
      local ret, GUIDINTERNAL = GetSetMediaTrackInfo_String ( parent_track, 'P_EXT:MPLRS5KMAN_GUIDINTERNAL', '', false)   -- get original GUID stored with template       
      if ret and GUIDINTERNAL ~= '' and GUIDINTERNAL ~= parent_track_GUID then
        self.var.rack.parent.wrong_parent_track_metadata = true
        self.var.rack.parent.GUIDINTERNAL = GUIDINTERNAL
      end 
      
    end
    -------------------------------------------------------------------
    self.process.rack.IsChildOwnedByParent =  function (track) local ret, parGUID = GetSetMediaTrackInfo_String( track, 'P_EXT:MPLRS5KMAN_CHILD_PARENTGUID', '', false) return self.utils.GetTrackByGUID(parGUID,self.var.proj) end
    -------------------------------------------------------------------
    self.process.rack.PAD_OVERRIDES.get = 
    function()
      if self.var.rack.parent.valid ~= true then return end local parent_track = self.var.rack.parent.params.track if not parent_track then return end
      self.var.rack.PAD_OVERRIDES = {names={}} 
      local ret, PARENT_PADNAMES_OVERRIDES_b64 = GetSetMediaTrackInfo_String ( parent_track, 'P_EXT:MPLRS5KMAN_PARENT_PADNAMES_OVERRIDES_b64', 0, false)  
      if PARENT_PADNAMES_OVERRIDES_b64~='' then
        local str = self.utils.base64.dec(PARENT_PADNAMES_OVERRIDES_b64)
        for pair in str:gmatch('[%d]+%=".-"') do
          local note, val = pair:match('([%d]+)="(.-)%"')
          if note and val and val ~= '' then 
            note = tonumber(note)
            if note then self.var.rack.PAD_OVERRIDES.names[note] = val end
          end
        end
      end
    end
    -------------------------------------------------------------------    
    self.process.rack.PAD_OVERRIDES.set =
    function()
      if self.var.rack.parent.valid ~= true then return end
      local parent_track = self.var.rack.parent.params.track
      if not parent_track then return end
      if self.var.rack.PAD_OVERRIDES and self.var.rack.PAD_OVERRIDES.names then 
        local outstr = ''
        for i = 0, 127 do outstr=outstr..i..'='..'"'..(self.var.rack.PAD_OVERRIDES.names[i] or '')..'" ' end
        local PARENT_PADNAMES_OVERRIDES_b64 = self.utils.base64.enc(outstr)
        GetSetMediaTrackInfo_String ( parent_track, 'P_EXT:MPLRS5KMAN_PARENT_PADNAMES_OVERRIDES_b64', PARENT_PADNAMES_OVERRIDES_b64, true) 
      end
    end
    -------------------------------------------------------------------
    self.process.rack.layout.get = 
    function ()  
      if not (self.var.rack.valid == true and self.var.rack.var and self.var.rack.var.DRRACKSHIFT) then return end
      self.var.rack.layout.parameters = {  -- init
          cell_cnt_max=64,
          row_cnt = 8,
          col_cnt = 8, 
        }  
      local ID = self.var.ext.UI_drracklayout.current 
      self.var.rack.layout.mapping = {}
      
      -- FACTORY / ableton rack
      if ID == 0 then 
        self.var.rack.layout.parameters.cell_cnt_max = 16
        self.var.rack.layout.parameters.row_cnt = 4
        self.var.rack.layout.parameters.col_cnt = 4 
        local xoffs = 0
        local yoffs = 3
        local padID0 = 0
        for note = self.var.rack.var.DRRACKSHIFT, self.var.rack.layout.parameters.cell_cnt_max-1+self.var.rack.var.DRRACKSHIFT do
          self.var.rack.layout.mapping[note] = { xoffs=xoffs,  yoffs=yoffs, }
          xoffs = xoffs + 1
          if padID0%4==3 then 
            xoffs = 0
            yoffs = yoffs - 1
          end
          padID0 = padID0 + 1
        end 
        goto getpadnames
      end 
      
      -- FACTORY / keys
      if ID == 1 then 
        self.var.rack.layout.parameters.cell_cnt_max = 24
        self.var.rack.layout.parameters.row_cnt = 4
        self.var.rack.layout.parameters.col_cnt = 7 
        local xoffs = 0
        local yoffs = 0
        local padID0 = 0
        local oct = 0
        for note = self.var.rack.var.DRRACKSHIFT, self.var.rack.layout.parameters.cell_cnt_max-1+self.var.rack.var.DRRACKSHIFT do 
          local note_oct = note%12
          if note_oct == 0 then xoffs = 0 yoffs = 3
            elseif note_oct == 1 then xoffs = 0.5 yoffs = 2
            elseif note_oct == 2 then xoffs = 1   yoffs = 3
            elseif note_oct == 3 then xoffs = 1.5   yoffs = 2
            elseif note_oct == 4 then xoffs = 2   yoffs = 3
            elseif note_oct == 5 then xoffs = 3   yoffs = 3
            elseif note_oct == 6 then xoffs = 3.5   yoffs = 2
            elseif note_oct == 7 then xoffs = 4   yoffs = 3
            elseif note_oct == 8 then xoffs = 4.5   yoffs = 2
            elseif note_oct == 9 then xoffs = 5   yoffs = 3
            elseif note_oct == 10 then xoffs = 5.5   yoffs = 2
            elseif note_oct == 11 then xoffs = 6   yoffs = 3 
          end
          if note_oct == 0 then oct = oct + 1 end
          if oct == 1 then yoffs = yoffs +2 end
          self.var.rack.layout.mapping[note] = {
            xoffs=xoffs, 
            yoffs=yoffs-2,
          }
        end 
        goto getpadnames
      end 
      
      -- FACTORY / akai pad (FIXED OFFSET)
      if ID == 3 then 
        self.var.rack.layout.parameters.cell_cnt_max = 16
        self.var.rack.layout.parameters.row_cnt = 4
        self.var.rack.layout.parameters.col_cnt = 4 
        
        self.var.rack.layout.mapping[37] = { xoffs=0,  yoffs=3 }
        self.var.rack.layout.mapping[36] = { xoffs=1,  yoffs=3 }
        self.var.rack.layout.mapping[42] = { xoffs=2,  yoffs=3 }
        self.var.rack.layout.mapping[82] = { xoffs=3,  yoffs=3 } 
        
        self.var.rack.layout.mapping[38] = { xoffs=1,  yoffs=2 } 
        self.var.rack.layout.mapping[40] = { xoffs=0,  yoffs=2 } 
        self.var.rack.layout.mapping[46] = { xoffs=2,  yoffs=2 }
        self.var.rack.layout.mapping[44] = { xoffs=3,  yoffs=2 }
        
        self.var.rack.layout.mapping[48] = { xoffs=0,  yoffs=1 }
        self.var.rack.layout.mapping[47] = { xoffs=1,  yoffs=1 }
        self.var.rack.layout.mapping[45] = { xoffs=2,  yoffs=1 }
        self.var.rack.layout.mapping[43] = { xoffs=3,  yoffs=1 }
        
        self.var.rack.layout.mapping[49] = { xoffs=0,  yoffs=0 }
        self.var.rack.layout.mapping[55] = { xoffs=1,  yoffs=0 }
        self.var.rack.layout.mapping[51] = { xoffs=2,  yoffs=0 }
        self.var.rack.layout.mapping[53] = { xoffs=3,  yoffs=0 }
        goto getpadnames
      end 
      
      -- custom
      if ID == 2 then 
        local cell_cnt_max,row_cnt,col_cnt
        local strB64 = self.var.ext.UI_drracklayout_customB64.current
        local str = self.utils.base64.dec(strB64)
        local pat = '(%d+)[%s]*x([%d%.]+)[%s]*y([%d%.]+)'
        for line in str:gmatch('[^\r\n]+') do
          line = line:lower()
          if not cell_cnt_max and line:match('cell_cnt_max.-([%d%.]+)') then if tonumber(line:match('cell_cnt_max.-([%d%.]+)')) then cell_cnt_max = tonumber(line:match('cell_cnt_max.-([%d%.]+)')) end end
          if not row_cnt and line:match('row_cnt.-([%d%.]+)') then if tonumber(line:match('row_cnt.-([%d%.]+)')) then row_cnt = tonumber(line:match('row_cnt.-([%d%.]+)')) end end
          if not col_cnt and line:match('col_cnt.-([%d%.]+)') then if tonumber(line:match('col_cnt.-([%d%.]+)')) then col_cnt = tonumber(line:match('col_cnt.-([%d%.]+)')) end end
          if line:match(pat) then
            local note, x, y = line:match(pat)
            if note then note = tonumber(note) end 
            if x then x = tonumber(x) end
            if y then y = tonumber(y) end
            if note and x and y then  self.var.rack.layout.mapping[note] = { xoffs=x,  yoffs=y } end
          end
        end
        if cell_cnt_max  then self.var.rack.layout.parameters.cell_cnt_max = cell_cnt_max end
        if row_cnt  then self.var.rack.layout.parameters.row_cnt = row_cnt end
        if col_cnt  then self.var.rack.layout.parameters.col_cnt = col_cnt end
      end
      
      ::getpadnames::
      
    end 
    ---------------------------------------------------------------------------------------
    self.process.rack.layout.generate_custom =  
    function(buf)
      self.temp_layout_multiline = buf
      self.var.ext.UI_drracklayout_customB64.current = self.utils.base64.enc(buf)
      self.process.ext.save()
      self.process.rack.layout.get()
    end 
    
  end
  -----------------------------------------------------------------------------------------   
  function DATA:func_def_process_realtime()  
    ------------------------------------------------------------
    self.process.realtime.collect=
    function() 
      self.var.clock = os.clock() 
      self.var.time_precise = time_precise() 
      self.var.flicker = math.abs(-1+(math.cos(math.pi*(self.var.clock%2)) + 1))
      self.var.SCC =  GetProjectStateChangeCount( 0 )
      self.var.editcurpos =  GetCursorPosition()
      self.var.proj = tostring(EnumProjects( -1 ))  
      self.var.playstate = GetPlayStateEx( -1 )
      self.process.realtime.recent_midi()
      self.process.realtime.meters() 
    end
    ------------------------------------------------------------
    self.process.realtime.meters = 
    function() 
      if self.var.rack.valid ~= true then return end
      local max_sz = 3
      if self.var.ext.UI_showplayingmeters.current == 0 then return end  
      for note in pairs(self.var.rack.children) do
        if not self.var.rack.children[note] then goto skipnextnote end
        if not self.var.rack.children[note].params.meters then self.var.rack.children[note].params.meters = {} end  
        local track = self.var.rack.children[note].params.track
        if track and ValidatePtr2(self.var.proj,track, 'MediaTrack*') then
          local L = Track_GetPeakInfo( track, 0 )
          local R = Track_GetPeakInfo( track, 1 )
          table.insert(self.var.rack.children[note].params.meters, 1, {L,R})
          local sz = #self.var.rack.children[note].params.meters
          local rmsL,rmsR = 0,0
          for i = 1, sz do
            rmsL = math.max(rmsL, math.abs(self.var.rack.children[note].params.meters[i][1]))
            rmsR =  math.max(rmsR, math.abs(self.var.rack.children[note].params.meters[i][2]))
          end
          self.var.rack.children[note].params.metersRMS_L = rmsL
          self.var.rack.children[note].params.metersRMS_R = rmsR 
          
          if sz>max_sz then self.var.rack.children[note].params.meters[max_sz+1] = nil end
          
        end 
        ::skipnextnote::
      end
    end
    ------------------------------------------------------------
    self.process.realtime.recent_midi = 
    function()
      local retval, rawmsg, tsval, devIdx, projPos, projLoopCnt = MIDI_GetRecentInputEvent(0)
      local is_noteOn 
      if retval == 0 then return  end -- stop if return null sequence
      if not ((devIdx & 0x10000) == 0 or devIdx == 0x1003e) then return end-- should works without this after REAPER6.39rc2, so thats just in case - Justin
      is_noteOn = rawmsg:byte(1)>>4 == 0x9 and rawmsg:byte(3) ~= 0 
      if not (is_noteOn==true and tsval > -self.var.SR * self.var.ext.UI_recentinput_lag.current) then return end  -- only reeeally latest messages
      self.var.recentinput_note = rawmsg:byte(2) 
      self.var.recentinput_trigTS = self.var.time_precise
    end   
    ------------------------------------------------------------
    self.process.realtime.handle = 
    function() 
      local trig_at_project_state_change
      local trig_inputmidi_note
      local trig_at_project_change
      
      -- project state
      if (self.var.SCClast and self.var.SCClast~=self.var.SCC ) then trig_at_project_state_change = true end  self.var.SCClast = self.var.SCC
      if (self.var.editcurposlast and self.var.editcurposlast~=self.var.editcurpos ) then trig_at_project_state_change = true end  self.var.editcurposlast = self.var.editcurpos
      if (self.var.projlast and self.var.projlast~=self.var.proj ) then trig_at_project_change = true end  self.var.projlast = self.var.proj
      
      -- input midi
      local notechange = self.var.recentinput_note and self.var.recentinput_notelast and self.var.recentinput_notelast ~= self.var.recentinput_note
      local trigdiffTS = self.var.recentinput_trigTSlast and self.var.recentinput_trigTSlast and self.var.recentinput_trigTSlast ~= self.var.recentinput_trigTS and self.var.recentinput_trigTS - self.var.recentinput_trigTSlast > self.var.ext.UI_recentinput_lag.current
      self.var.recentinput_trigTSlast = self.var.recentinput_trigTS
      self.var.recentinput_notelast = self.var.recentinput_note
      if notechange == true or trigdiffTS == true then trig_inputmidi_note = self.var.recentinput_note end
      
      -- app
      if trig_inputmidi_note then  
        if self.var.ext.UI_incomingnoteselectpad.current&1==1 and
          (self.var.ext.UI_incomingnoteselectpad.current&2~=2 or ( self.var.ext.UI_incomingnoteselectpad.current&2==2 and not (self.var.playstate&1==1 and self.var.playstate&2~=2)) ) then 
          self.var.rack.var.LASTACTIVENOTE = trig_inputmidi_note
          self.var.rack.var.LASTACTIVENOTE_LAYER = 1
          self.process.rack.parent.set_ext_state()
        end
      end
      if trig_at_project_state_change then self.process.at_project_state_change() end
      if trig_at_project_change then self.process.at_project_change() end
    end
    ------------------------------------------------------------
    self.process.realtime.ext_actions = 
    function()
      local actions = gmem_read(1025)
      if actions == 0 then return end
      
      -- rack --
      if actions == 2 then self.process.rack.children.sample.switch(0,self.var.rack.var.LASTACTIVENOTE,self.var.rack.var.LASTACTIVENOTE_LAYER)  end -- RS5k_manager_Sampler_PreviousSample
      if actions == 3 then self.process.rack.children.sample.switch(1,self.var.rack.var.LASTACTIVENOTE,self.var.rack.var.LASTACTIVENOTE_LAYER)  end -- RS5k_manager_Sampler_RandSample
      if actions == 4 then self.process.rack.children.sample.switch(2,self.var.rack.var.LASTACTIVENOTE,self.var.rack.var.LASTACTIVENOTE_LAYER)  end -- RS5k_manager_Sampler_NextSample
      if actions == 6 then self.process.ext.db_maps.setflags(self.var.rack.var.LASTACTIVENOTE,2)  end -- RS5k_manager_Database_Lock
      if actions == 7 then self.process.rack.children.solo(self.var.rack.var.LASTACTIVENOTE) end  -- RS5k_manager_DrumRack_Solo
      if actions == 8 then self.process.rack.children.mute(self.var.rack.var.LASTACTIVENOTE) end  -- RS5k_manager_DrumRack_Mute
      if actions == 9 then self.process.rack.children.remove(self.var.rack.var.LASTACTIVENOTE) end  -- RS5k_manager_DrumRack_Clear
      if actions == 12 then self.process.ext.db_maps.load() end -- RS5k_manager_Database_LoadAllPads
      if actions == 13 then self.process.ext.db_maps.load(true) end -- RS5k_manager_Database_LoadSelectedPads 
      if actions == 14 then self.process.ext.db_maps.switchlist(-1) end--RS5k_manager_Database_PrevMap
      if actions == 15 then self.process.ext.db_maps.switchlist(1) end--RS5k_manager_Database_NextMap
       
      if actions ~= 0 then gmem_write(1025,0 ) end -- clear to prevent infinite update
    end
  end
  -----------------------------------------------------------------------------------------  
  function DATA:func_def_process()  
    self.process.at_close = 
    function()
      
    end
    ------------------------------------------------------------
    self.process.at_project_state_change = 
    function()
      self.process.rack.read()
      self.temp_schedule_afterUI = true -- cache peaks only is some is missing 
    end
    ------------------------------------------------------------
    self.process.at_project_change = 
    function() 
      self.process.rack.clear_peaks()
      self.process.at_project_state_change() 
      self.process.rack.peaks.all({clear=true})
    end 
    ------------------------------------------------------------
    self.process.at_project_state_change_afterUI =  
    function()
      self.process.rack.peaks.all({fill_missing_only =true}) -- cache peaks only is some is missing 
      self.process.sampler.peaks.collect()
    end 
    ------------------------------------------------------------
    self.process.onceafterUI = 
    function() 
      self.process.rack.peaks.all()
      self.process.sampler.peaks.collect()
    end
    ------------------------------------------------------------
    self.process.actions.toggle_play = function() if GetPlayState()&1==1 then CSurf_OnStop() else CSurf_OnPlay() end end
    ------------------------------------------------------------
    self.process.sampler.peaks.collect = 
    function()
      local note = self.var.rack.var.LASTACTIVENOTE or -1 
      local layer = self.var.rack.var.LASTACTIVENOTE_LAYER or -1
      if not (self.var.rack.children[note] and self.var.rack.children[note].layers and self.var.rack.children[note].layers[layer] ) then return end
      if  self.var.rack.children[note].layers and 
          self.var.rack.children[note].layers[layer] and 
          self.var.rack.children[note].layers[layer].instrument and 
          self.var.rack.children[note].layers[layer].instrument.sample and 
          self.var.rack.children[note].layers[layer].instrument.sample.filename then
        filename = self.var.rack.children[note].layers[layer].instrument.sample.filename
      end
      if self.var.sampler.peaksW and filename then 
        self.var.sampler.peaks_array = self.process.rack.peaks.get(filename, self.var.sampler.peaksW or 100, {SOFFS = self.var.sampler.peaksSOFFS or 0, EOFFS = self.var.sampler.peaksEOFFS or 1})
      end
    end
    ------------------------------------------------------------
    self.process.midi.stuff_note = 
    function(note, vel, is_off) 
      if not note then return end 
      if not is_off then 
        StuffMIDIMessage( 0, 0x90, note, vel or self.var.ext.CONF_default_velocity.current) 
       else
        StuffMIDIMessage( 0, 0x80, note, 0 ) 
      end
    end
    ------------------------------------------------------------    
    self.process.MIDIdevices =  
    function()
      self.var.MIDIdevices = {}
      self.var.MIDIdevices.Launchpad_output = false 
      
      self.var.MIDIdevices.inputs = {[63]='All inputs',[62]='Virtual keyboard'}
      for dev = 1, reaper.GetNumMIDIInputs() do
        local retval, nameout = reaper.GetMIDIInputName( dev-1, '' )
        if retval then self.var.MIDIdevices.inputs[dev-1] = nameout end
      end
      
      self.var.MIDIdevices.outputs = {[-1]='[none]'}
      for dev = 1, reaper.GetNumMIDIOutputs() do
        local retval, nameout = reaper.GetMIDIOutputName( dev-1, '' )
        if retval then self.var.MIDIdevices.outputs[dev-1] = nameout end 
        if self.var.ext.CONF_midioutput.current == dev-1 and   
          (
            nameout:lower():match('lpmini') or
            nameout:lower():match('lppro')
          )
         then 
          self.var.MIDIdevices.Launchpad_output = true
        end
      end
    end
    ------------------------------------------------------------            
    self.process.MEdatabase = 
    function() 
      self.var.MEdatabase = {} 
      
      if self.var.ext.CONF_ignoreDBload.current == 1 then return end  
      if not self.var.REAPERini then return end 
      
      local exp_section = self.var.REAPERini.reaper_explorer
      if not exp_section then 
        exp_section = self.var.REAPERini.reaper_sexplorer
        if not exp_section then return end
      end 
      
      for key in pairs(exp_section) do
        if not key:match('Shortcut') then goto skipnextkey end 
        if not (tostring(exp_section[key]) and tostring(exp_section[key]):lower():match('reaperfilelist')) then goto skipnextkey end
        local db_key = key:gsub('Shortcut','ShortcutT') 
        if not exp_section[db_key]  then goto skipnextkey end  
        local dbame = exp_section[db_key]
        local db_filename = exp_section[key] 
        
        self.var.MEdatabase[dbame] = {filename = db_filename} 
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
                          fp_short  =self.utils.GetSampleNameFromPath(fp) 
                         }
            end 
          end
        end 
        self.var.MEdatabase[dbame].files = t  
        ::skipnextkey::
      end
    end
    ------------------------------------------------------------
    self.process.plugins = 
    function() 
      self.var.plugins = { list = {}, types = {}, vendors = {}, } 
      for i = 1, 3000 do
        local retval, name, ident = EnumInstalledFX( i-1 )
        if not retval then break end
        if name:match('i%:') then
          local checkname=name
            :gsub('%(x64%)','')
            :gsub('%(x86%)','')
          local vendor = checkname:match('%((.-)%)')
          if not vendor or (vendor and vendor == '')then vendor = '[unknown]'end
          fxtype = name:match('(.-)%:') or 'Other'
          self.var.plugins.types[fxtype]=(self.var.plugins.types[fxtype] or 0) + 1
          self.var.plugins.vendors[vendor]=(self.var.plugins.vendors[vendor] or 0) + 1 
          self.var.plugins.list[#self.var.plugins.list+1] = {name = name, reduced_name = self.utils.reduceFXname(name) , ident = ident, vendor=vendor, fxtype=fxtype, } 
        end                                   
      end
    end
    ------------------------------------------------------------
    self.process.REAPERini = 
    function() -- https://github.com/Dynodzzo/Lua_INI_Parser/blob/master/LIP.lua
      local fileName = reaper.get_ini_file()
      assert(type(fileName) == 'string', 'Parameter "fileName" must be a string.');
      local file = assert(io.open(fileName, 'r'), 'Error loading file : ' .. fileName);
      local data = {};
      local section;
      for line in file:lines() do
        local tempSection = line:match('^%[([^%[%] ]+)%]$');
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
      self.var.REAPERini = data;
    end
    ------------------------------------------------------------  
    self.process.calc_sample_data =
    function(filename, options)
      local src = PCM_Source_CreateFromFileEx( filename, true )
      if not src then return end 
      local src_len =  GetMediaSourceLength( src )  
      if not src_len then return end
      
      -- boundaries
      local norm_check1 = 0
      local norm_check2 = 0 
      if options and options.SOFFS then norm_check1 = options.SOFFS * src_len end
      if options and options.EOFFS then norm_check2 = options.EOFFS * src_len end 
      
      -- auto normalization
      if self.var.ext.CONF_onadd_autoLUFSnorm_toggle.current == 1 then  
        local normalizeTo = 0
        local normalizeTarget = self.var.ext.CONF_onadd_autoLUFSnorm.current   
        LUFSNORM = CalculateNormalization( src, normalizeTo, normalizeTarget, norm_check1, norm_check2 ) 
      end
      
      PCM_Source_Destroy( src )
      return LUFSNORM, src_len
    end
    -------------------------------------------------------------------
    self.process.apply_template =
    function(new_tr)
      -- add custom template
      if is_device_parent ~= true and self.var.ext.CONF_onadd_customtemplate.current ~= '' then  
        local f = io.open(self.var.ext.CONF_onadd_customtemplate.current,'rb')
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
    end
    -------------------------------------------------------------------
    self.process.track_selection_save =
    function ()
      self.temp_TrackSelection = {}
      local cnt = CountTracks(-1)
      for i = 1, cnt do
        local track = GetTrack(-1,i-1)
        local GUID = GetTrackGUID( track )
        if IsTrackSelected( track ) then self.temp_TrackSelection[GUID] = true end
      end
    end
    -------------------------------------------------------------------  
    self.process.track_selection_restore =
    function ()
      if not self.temp_TrackSelection then return end
      local cnt = CountTracks(-1)
      for i = 1, cnt do
        local track = GetTrack(-1,i-1)
        local GUID = GetTrackGUID( track )
        SetTrackSelected( track, self.temp_TrackSelection[GUID]==true )
      end 
      self.temp_TrackSelection = {}
    end
    ------------------------------------------------------------------- 
    self.process.get_track_depth=
    function(track)
      if not track then return end
      local cnt = CountTracks(self.var.proj)
      local com_depth = 0
      for i = 1, cnt do
        local tr = GetTrack(self.var.proj, i-1)
        depth = GetMediaTrackInfo_Value( tr, 'I_FOLDERDEPTH' ) 
        if tr == track then return com_depth end
        com_depth = com_depth + depth
      end
      return com_depth
    end
  end      
  -------------------------------------------------------------------------------- 
  function DATA:func_def_UI_draw_macro() 
    self.draw.macro.slider =
    function(sliderID)
      -- name / str_id
      local name = 'Macro '..sliderID
      local str_id ='##'..name
      if self.var.rack.macro.extstate and self.var.rack.macro.extstate[sliderID] and self.var.rack.macro.extstate[sliderID].custom_name then name = self.var.rack.macro.extstate[sliderID].custom_name end
      -- val
      local value_normalized = self.var.rack.macro.sliders[sliderID].val 
      local default_val =0
      local value_formatted = math.floor(value_normalized * 100)..'%'
      
      local frame_col 
      if self.var.rack.macro.extstate and self.var.rack.macro.extstate[sliderID] then frame_col = self.var.rack.macro.extstate[sliderID].col_rgb end
      
      -- knob 
      self.ImGui.Custom_Knob(ctx, name..str_id, self.var.UI_linear.knobW,self.var.UI_linear.knobH,
        {   value_normalized = value_normalized,
            value_formatted = value_formatted,
            custom_knobnameBg = frame_col,
            f_atclick_knob = function() self.temp_rack_snapshot = CopyTable(self.var.rack) end,
            f_atdrag_knob = function(dy) 
              local slow_coeff = 1
              if reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Shift()) then slow_coeff = 0.05 end
              local dval = slow_coeff * dy/self.var.mouseY_resolution
              local outval = self.temp_rack_snapshot.macro.sliders[sliderID].val - dval
              outval = self.utils.lim(outval, 0, value_max ) 
              TrackFX_SetParamNormalized(self.var.rack.parent.params.track, self.var.rack.macro.pos, sliderID, outval )
              self.var.rack.macro.sliders[sliderID].val = outval
            end,
            f_atdc_knob = function(dy)  
              local outval = 0
              TrackFX_SetParamNormalized(self.var.rack.parent.params.track, self.var.rack.macro.pos, sliderID, outval )
              self.var.rack.macro.sliders[sliderID].val = outval
            end,
            f_atclick_name = function()
              self.process.popup_trigger = 'macro_context' 
            end,
            
        })
    end
    --------------------------------------------------------------------------------  
    self.draw.macro.links_limits=
    function(link_t, note, layer, paramID)
      if ImGui.BeginChild( ctx, '##links_limitsnote'..note..'layer'..layer..'paramID'..paramID..'childlimedit', -1, 20, ImGui.ChildFlags_None, ImGui.WindowFlags_None ) then
        local but_sz = self.var.UI_linear.macro_but_sz
        local col_theme = self.var.ext.UI_colRGBA_maintheme.current
        local xav = ImGui.GetContentRegionAvail(ctx)
        local xscreen, yscreen = ImGui.GetCursorScreenPos(ctx)
        xav = xav - self.var.UI_linear.macro_but_sz
        --ImGui.InvisibleButton(ctx,'##rack.macro.sliders.links.linklimits'..note..'layer'..layer,-1,20)
        --local x1,y1 = ImGui.GetItemRectMin(ctx)
        --local x2,y2 = ImGui.GetItemRectMax(ctx)
        local x1,y1 = xscreen, yscreen
        local x2,y2 = xscreen + xav, yscreen + 20 
        local graphX = x1
        local graphW = x2-x1
        ImGui.DrawList_AddRect(self.draw.draw_list, x1,y1,x2,y2, col_theme|0x50, DATA.var.UI_linear.round_corners)
        local val_child = link_t.val_child
        local xval = x1 + (x2-x1)*val_child
        local val_sz = 5
        -- range
        local plink_min =link_t.plink_min
        local plink_max = link_t.plink_max
        local minx = self.utils.lim(x1 + (x2-x1)*plink_min, x1,x2)
        local maxx = self.utils.lim(x1 + (x2-x1)*plink_max, x1,x2)
        ImGui.DrawList_AddRectFilled(self.draw.draw_list, math.min(minx,maxx),y1+1, math.max(minx,maxx),y2-1, 0x404040FF )
        -- value
        ImGui_DrawList_AddLine( self.draw.draw_list, xval, y1, xval, y2,col_theme|0xF0, 2 ) 
        local dx= ImGui.GetMouseDelta(ctx) 
        -- controls / min
        ImGui.SetCursorScreenPos(ctx, minx,y2-but_sz)
        ImGui.InvisibleButton(ctx,'##rack.macro.sliders.links.linklimits'..note..'layer'..layer..'paramID'..paramID..'min',but_sz,but_sz) 
        if ImGui.IsItemActive(ctx) and dx ~=0 then 
          local mx,my = ImGui.GetMousePos(ctx) 
          local min_new = (mx - graphX) / graphW
          min_new = self.utils.lim(min_new)
          self.process.rack.macro.set.slider_link_boundary(link_t, note, layer,min_new)
        end 
        local x1m,y1m = ImGui.GetItemRectMin(ctx)
        local x2m,y2m = ImGui.GetItemRectMax(ctx)
        ImGui_DrawList_AddTriangleFilled( self.draw.draw_list, x1m, y2m, x1m, y2m-but_sz, x1m+but_sz, y2m, col_theme|0xF0 ) 
        -- controls / max
        ImGui.SetCursorScreenPos(ctx, maxx-but_sz,y1)
        if ImGui.InvisibleButton(ctx,'##rack.macro.sliders.links.linklimits'..note..'layer'..layer..'paramID'..paramID..'max',but_sz,but_sz) then end
        if ImGui.IsItemActive(ctx) and dx ~=0 then 
          local mx,my = ImGui.GetMousePos(ctx) 
          local max_new = (mx - graphX) / graphW
          max_new = self.utils.lim(max_new)
          self.process.rack.macro.set.slider_link_boundary(link_t, note, layer,nil,max_new)
        end
        local x1m,y1m = ImGui.GetItemRectMin(ctx)
        local x2m,y2m = ImGui.GetItemRectMax(ctx)
        ImGui_DrawList_AddTriangleFilled( self.draw.draw_list, x1m, y1m, x1m+but_sz, y1m, x1m+but_sz, y1m+but_sz, col_theme|0xF0 )
        
        ImGui.EndChild(ctx)
      end
    end
    -------------------------------------------------------------------------------- 
    self.process.rack.macro.set.slider_link_boundary = 
    function(link_t, note, layer, min_val, max_val)
      if min_val then link_t.plink_min = min_val else min_val = link_t.plink_min end
      if max_val then link_t.plink_max = max_val else max_val = link_t.plink_max end
      
      local baseline = min_val
      local scale = max_val - min_val
      local offset = (min_val - baseline) / scale 
       
      local note_layer_t = link_t.child_t
      TrackFX_SetNamedConfigParm(note_layer_t.params.track, link_t.dest_fx, 'param.'..link_t.dest_param..'plink.scale', scale)  
      TrackFX_SetNamedConfigParm(note_layer_t.params.track, link_t.dest_fx, 'param.'..link_t.dest_param..'plink.offset', offset)  
      TrackFX_SetNamedConfigParm(note_layer_t.params.track, link_t.dest_fx, 'param.'..link_t.dest_param..'mod.baseline', min_val)  
      
    end
    --------------------------------------------------------------------------------  
    self.draw.macro.links=
    function()
      local macroID = self.var.rack.var.LASTACTIVEMACRO
      if not (self.var.rack.macro.sliders[macroID] and self.var.rack.macro.sliders[macroID].links) then return end
      
      for note in self.utils.spairs(self.var.rack.macro.sliders[macroID].links) do
        for layer in self.utils.spairs(self.var.rack.macro.sliders[macroID].links[note]) do
          for paramID in self.utils.spairs(self.var.rack.macro.sliders[macroID].links[note][layer]) do
            ImGui.PushFont(ctx, self.draw.font_ptr, self.var.UI_linear.font_sz_small)
            local link_t = self.var.rack.macro.sliders[macroID].links[note][layer][paramID]
            local child_t = link_t.child_t 
            local col = 0x50505000
            local name = '[N'..note..' L'..layer..']'
            if child_t and child_t.params then  
              if child_t.params.I_CUSTOMCOLOR and child_t.params.I_CUSTOMCOLOR&0x1000000==0x1000000 then 
                r, g, b = reaper.ColorFromNative( child_t.params.I_CUSTOMCOLOR )
                col = (r<<24)|(g<<16)|(b<<8)|0xFF
              end
              if child_t.params.P_NAME then name = name   ..' '..child_t.params.P_NAME end 
              if link_t.param_name then name = name   ..' - '..link_t.param_name end 
            end 
            
            -- name / show mod
            ImGui.PushStyleVar(ctx, reaper.ImGui_StyleVar_ButtonTextAlign(), 0,0.5) 
            if self.ImGui.Custom_InvisibleButton(ctx, name..'##rack.macro.sliders'..macroID..'.links'..note..'layer'..layer..'paramID'..paramID,250,nil, col) then self.process.rack.macro.showmod(link_t) end
            ImGui.PopStyleVar(ctx)
            ImGui.SameLine(ctx) 
            -- show FX
            if ImGui.Button(ctx,'FX##rack.macro.sliders'..macroID..'.links'..note..'layer'..layer..'paramID'..paramID..'fx' ) then self.process.rack.macro.showFX(link_t) end 
            ImGui.SameLine(ctx)
            -- bypass linf
            if self.ImGui.Custom_InvisibleButton(ctx,'X##rack.macro.sliders'..macroID..'.links'..note..'layer'..layer..'paramID'..paramID..'removelink',nil,nil,0xF0505000 ) then self.process.rack.macro.bypass(link_t) end 
            ImGui.SameLine(ctx) 
            -- show mapping limits
            self.draw.macro.links_limits(link_t, note, layer, paramID)
            ImGui.PopFont(ctx)
          end
        end
      end
      
    end
    -------------------------------------------------------------
    self.draw.macro.all =
    function()
      if self.var.rack.valid~=true then return end
      if ImGui.BeginChild( ctx, '##area_macro', -1, -1, ImGui.ChildFlags_None, ImGui.WindowFlags_None ) then
        local xav, yav = ImGui_GetContentRegionAvail(ctx) 
        
        -- init macro on parent if missing
        if not (self.var.rack.macro and self.var.rack.macro.valid == true) then -- and self.var.rack.macro.sliders
          if ImGui.Button(ctx, 'Init macro on parent track',-1) then self.process.rack.macro.InitMaster() end
        end
        
        -- sliders 
        if not self.var.rack.macro.sliders then goto skipsliders end
        if ImGui.BeginChild( ctx, '##area_macro_sliders', 0, 0, ImGui.ChildFlags_Borders|reaper.ImGui_ChildFlags_AutoResizeY(), ImGui.WindowFlags_None ) then
          for i =1, #self.var.rack.macro.sliders do 
            self.draw.macro.slider(i)
            if i%8~= 0 then ImGui.SameLine(ctx) end
          end 
          ImGui.EndChild( ctx)
        end   
        ::skipsliders::
        
        if ImGui.BeginChild( ctx, '##area_macro_links', 0, -1, ImGui.ChildFlags_None, ImGui.WindowFlags_None ) then
          self.draw.macro.links()
          ImGui.Dummy(ctx,0,0)
          ImGui.EndChild( ctx)
        end 
        
        ImGui.EndChild( ctx)
      end 
    end
  end
  
  -------------------------------------------------------------------------------- 
  function DATA:func_def_UI_draw_rack() 
    self.draw.rack.all =
    function()
      if ImGui.BeginChild( ctx, '##area_rack', self.var.UI_linear.dyn_rackW, -1, ImGui.ChildFlags_None, ImGui.WindowFlags_None ) then
        local xav, yav = ImGui_GetContentRegionAvail(ctx)
        test = xav /yav 
        if (self.var.ext.UI_drracklayout.current == 0 or self.var.ext.UI_drracklayout.current == 1 ) and xav /yav > 1 then 
          self.draw.rack.padoverview() 
          ImGui.SameLine(ctx)
        end 
        if self.var.rack.valid ==true then   
          self.draw.rack.pads_layout() 
         else 
          self.draw.rack.startup() 
        end
        ImGui.EndChild( ctx)
      end 
    end
    -------------------------------------------------------------------     
    self.draw.rack.startup = 
    function ()  
      ImGui.PushFont( ctx, self.fon, self.var.UI_linear.font_sz_small )
      if ImGui.BeginChild( ctx, 'rackpads', -1,-1, ImGui.ChildFlags_None, ImGui.WindowFlags_None |ImGui.WindowFlags_NoScrollbar ) then--|ImGui.ChildFlags_Borders --|ImGui.WindowFlags_MenuBar
        ImGui.TextColored(ctx,0x90FF90FF, 'RS5k manager quick tips') 
        if ImGui.Button(ctx, '1. Create parent track for drum rack',-1) then 
          self.process.rack.parent.init() 
          self.process.rack.read()
        end 
        ImGui.TextWrapped(ctx,  
  [[  2. Once parent track is created, RS5k manager is ready for adding samples to it.
  3. Drop sample to pads from OS browser or MediaExplorer to pad, the script will automatically make all needed routing setup.
                    ]])
        ImGui.TextWrapped(ctx,
  [[    For bug reports: make sure you are running the latest version of RS5k manager, please attach FULL text of error (including error line number) and steps to reproduce.
  ]]) 
                    
        self.utils.link('Forum thread', 'https://forum.cockos.com/showthread.php?t=207971')
        ImGui.SameLine(ctx) 
        ImGui.SetNextItemWidth(ctx, -1) 
        ImGui.InputText(ctx,'##forumlink','https://forum.cockos.com/showthread.php?t=207971', ImGui.InputTextFlags_AutoSelectAll|ImGui.InputTextFlags_ReadOnly)
        
        self.utils.link('MPL Telegram', 'https://t.me/m_pilyavskiy')
        ImGui.SameLine(ctx) 
        ImGui.SetNextItemWidth(ctx, -1) 
        ImGui.InputText(ctx,'##telegrchat','https://t.me/m_pilyavskiy', ImGui.InputTextFlags_AutoSelectAll|ImGui.InputTextFlags_ReadOnly)
        
        self.utils.link('Donate (Boosty)', 'https://boosty.to/mpl57')
        ImGui.SameLine(ctx) 
        ImGui.SetNextItemWidth(ctx, -1) 
        ImGui.InputText(ctx,'##boosty','https://boosty.to/mpl57', ImGui.InputTextFlags_AutoSelectAll|ImGui.InputTextFlags_ReadOnly)
        ImGui.EndChild( ctx)
      end    
      reaper.ImGui_PopFont( ctx )
    end
    ------------------------------------------------
    self.process.rack.clear_peaks = 
    function(child0)
      if not self.var.rack.peaks.children then return end 
      if child0 then self.var.rack.peaks.children[child0].peaks_array = nil return end
      for child in pairs(self.var.rack.peaks.children) do
        self.var.rack.peaks.children[child].peaks_array = nil
      end
    end
    ------------------------------------------------
    self.draw.rack.padoverview =
    function() 
      -- available only for grid8x8 and keys
        if not (self.var.ext.UI_drracklayout.current == 0 or self.var.ext.UI_drracklayout.current == 1) then  return end
      -- init
        local regavX, regavY = ImGui.GetContentRegionAvail(ctx) 
        local cell_sz, childW
        cell_sz = math.floor(regavY / 31 ) 
        childW = cell_sz * 4 
      -- increase width for keys
        if self.var.ext.UI_drracklayout.current == 1 then  
          cell_sz = math.max(3,math.ceil(regavY / 23 ) ) 
          childW = cell_sz * 7
        end
      
      if ImGui.BeginChild( ctx, '##rack_padoverview_child', childW, -1, ImGui.ChildFlags_None, ImGui.WindowFlags_None|ImGui.WindowFlags_NoScrollWithMouse|ImGui.WindowFlags_NoScrollbar ) then -- ChildFlags_Borders
        ImGui.PushStyleVar(ctx, ImGui.StyleVar_ItemSpacing,0,0) 
        local xav, yav = ImGui.GetContentRegionAvail(ctx)
        local posx, posy = ImGui.GetCursorPos(ctx) 
        
        -- slider
          ImGui.PushStyleColor(ctx, ImGui.Col_SliderGrab, 0)
          ImGui.PushStyleColor(ctx, ImGui.Col_SliderGrabActive, 0)
          ImGui.PushStyleColor(ctx, ImGui.Col_FrameBg, 0)
          ImGui.PushStyleColor(ctx, ImGui.Col_FrameBgHovered, 0)
          ImGui.PushStyleColor(ctx, ImGui.Col_FrameBgActive, 0)
          local retval, v = ImGui.VSliderDouble( ctx, '##padoverview', xav-1, yav, val, 0, 1, '', ImGui.SliderFlags_None)
          if retval then 
            local mx, my = reaper.ImGui_GetMouseDelta( ctx )
            if my ~= 0 then
              local notehover = math.floor(v*127)
              self.process.rack.parent.set_DRRACKSHIFT(notehover) 
              self.process.rack.layout.get()
              
            end
          end 
          ImGui.PopStyleColor(ctx,5)
        
        
        -- draw elements
          ImGui.SetCursorPos(ctx, posx, posy) 
          local notehover
          local but_hold
          local sel_rect 
          
        -- grid 
          if self.var.ext.UI_drracklayout.current ~= 0 then goto skipgridlayout end
          for noteID = 0, 127 do
            local note = 124 - noteID + 2 * (noteID%4) 
            local blockcol = 0x454545
            local backgr_fill = 1
            if (note >=0 and note<=3)or
              (note >=20 and note<=35)or
              (note >=52 and note<=67)or
              (note >=84 and note<=99)or
              (note >=116 and note<=127) 
            then blockcol =0x757575 end  
            if self.var.rack.children[note] and self.var.rack.children[note].exists==true then backgr_fill2 = 1  blockcol = 0xD0D0D0 end -- highlight used  -- self.var.UI_linear.colors.main_theme 
            if self.var.recentinput_note and self.var.recentinput_note == note  then blockcol = 0xffe494 backgr_fill = 1 end  -- highlight playing
            ImGui.InvisibleButton( ctx, '##padoverview_'..note, cell_sz, cell_sz )
            if ImGui.BeginDragDropTarget( ctx ) then  
              self.process.rack.changesample.dropsampletopad.all(note)
              ImGui_EndDragDropTarget( ctx )
            end
            local p_min_x, p_min_y = ImGui.GetItemRectMin(ctx)
            local p_max_x, p_max_y = ImGui.GetItemRectMax(ctx)
            ImGui.DrawList_AddRectFilled( self.draw.draw_list, p_min_x, p_min_y, p_max_x-1, p_max_y-1, blockcol<<8|math.floor(backgr_fill*0xFF), 0, ImGui.DrawFlags_None ) 
            if noteID%4 ~= 3 then ImGui.SameLine(ctx) end 
            if self.var.rack.valid == true and self.var.rack.var.DRRACKSHIFT and note == self.var.rack.var.DRRACKSHIFT then sel_rect = {p_min_x=p_min_x, p_min_y=p_min_y-cell_sz*3,p_max_x=p_max_x+cell_sz*3, p_max_y =p_max_y} end 
          end
          ::skipgridlayout::
        
        
        -- draw keys 
        local map = 
          {
            [0] = {x=0,   y=1},
            [1] = {x=0.5, y=0},
            [2] = {x=1,   y=1},
            [3] = {x=1.5,   y=0},
            [4] = {x=2,   y=1},
            [5] = {x=3,   y=1},
            [6] = {x=3.5,   y=0},
            [7] = {x=4,   y=1},
            [8] = {x=4.5,   y=0},
            [9] = {x=5,   y=1},
            [10] = {x=5.5,   y=0},
            [11] = {x=6,   y=1},
          }
        if self.var.ext.UI_drracklayout.current ~= 1 then goto skipgridlayout2 end
        for note = 0, 127 do
          local oct = math.floor(note/12)
          if map[note%12] then ImGui.SetCursorPos( ctx, math.floor(map[note%12].x * cell_sz), math.floor(map[note%12].y * cell_sz) + cell_sz * 20 - oct * cell_sz*2 ) end
          local blockcol = 0x454545 
          local backgr_fill = 1
          if ( note%12 == 0
              or note%12 == 2
              or note%12 == 4
              or note%12 == 5
              or note%12 == 7
              or note%12 == 9
              or note%12 == 11 
            ) then blockcol =0x656565 end 
          if self.var.rack.children[note] and self.var.rack.children[note].exists==true then backgr_fill2 = 1  blockcol = 0xD0D0D0 end -- highlight used  -- self.var.UI_linear.colors.main_theme 
          if self.var.recentinput_note and self.var.recentinput_note == note  then blockcol = 0xffe494 backgr_fill = 1 end  -- highlight playing
          ImGui.InvisibleButton( ctx, '##padoverview_'..note, cell_sz, cell_sz )
          if ImGui.BeginDragDropTarget( ctx ) then  
            self.process.rack.changesample.dropsampletopad.all(note)
            ImGui_EndDragDropTarget( ctx )
          end
          local p_min_x, p_min_y = ImGui.GetItemRectMin(ctx)
          local p_max_x, p_max_y = ImGui.GetItemRectMax(ctx)
          ImGui.DrawList_AddRectFilled( self.draw.draw_list, p_min_x, p_min_y, p_max_x-1, p_max_y-1, blockcol<<8|math.floor(backgr_fill*0xFF), 0, ImGui.DrawFlags_None )  
          if self.var.rack.valid == true and self.var.rack.var.DRRACKSHIFT and note == self.var.rack.var.DRRACKSHIFT then sel_rect = {p_min_x=p_min_x, p_min_y=p_min_y-cell_sz*3,p_max_x=p_max_x+cell_sz*6, p_max_y =p_max_y} end 
          if note%12 ~= 11 then ImGui.SameLine(ctx) end
        end
        ::skipgridlayout2::
        
        
        -- draw selection rect
        if sel_rect then 
          local col_rect = (self.var.ext.UI_colRGBA_maintheme.current&0xFFFFFF00)|0xFF 
          ImGui.DrawList_AddRect( self.draw.draw_list, sel_rect.p_min_x, sel_rect.p_min_y, sel_rect.p_max_x, sel_rect.p_max_y,col_rect, 3, ImGui.DrawFlags_None,3 ) 
        end 
        
        ImGui.PopStyleVar(ctx)
        ImGui.EndChild( ctx)
      end
    end
    
    -------------------------------------------------------------------
    self.draw.rack.pads_layout =
    function()
      if not self.var.rack.layout.parameters then return end
      if ImGui.BeginChild( ctx, 'rackpads', -1,-1, ImGui.ChildFlags_None, ImGui.WindowFlags_None |ImGui.WindowFlags_NoScrollbar ) then--|ImGui.ChildFlags_Borders --|ImGui.WindowFlags_MenuBar
        local xav, yav = ImGui_GetContentRegionAvail(ctx)
        local xpos,ypos = ImGui.GetCursorPos(ctx)
        local padW, padH = math.floor(xav / self.var.rack.layout.parameters.col_cnt )-self.var.UI_linear.spacingX, math.floor(yav / self.var.rack.layout.parameters.row_cnt )-self.var.UI_linear.spacingY
        self.var.UI_linear.padW=padW
        self.var.UI_linear.padH=padH 
        for note in pairs(self.var.rack.layout.mapping) do
          local xoffs = self.var.rack.layout.mapping[note].xoffs * padW + self.var.rack.layout.mapping[note].xoffs * self.var.UI_linear.spacingX
          local yoffs = self.var.rack.layout.mapping[note].yoffs * padH + self.var.rack.layout.mapping[note].yoffs * self.var.UI_linear.spacingY
          ImGui.SetCursorPos(ctx, xpos + xoffs, ypos + yoffs)
          self.draw.rack.pad.all(note, padW, padH)
        end
        ImGui.Dummy(ctx,0,0) 
        ImGui.EndChild( ctx)
      end
    end
  end
  
  -------------------------------------------------------------------------------- 
  function DATA:func_def_UI_draw_rack_pad()  
    self.draw.rack.pad.all=
    function(note, w, h)
      if ImGui.BeginChild( ctx, 'rackpads_singlepad'..note, w, h, ImGui.ChildFlags_None, ImGui.WindowFlags_None |ImGui.WindowFlags_NoScrollbar ) then-- --|ImGui.WindowFlags_MenuBar
        local x,y = ImGui.GetCursorScreenPos(ctx)
        self.draw.rack.pad.background(note, x,y,w,h)
        self.draw.rack.pad.frame(note, x,y,w,h)
        self.draw.rack.pad.peaks(note, x,y,w,h)
        self.draw.rack.pad.meters(note, x,y,w,h) 
        self.draw.rack.pad.led(note, x,y,w,h)
        self.draw.rack.pad.name(note, x,y,w,h)
        self.draw.rack.pad.pad_controls(note, x,y,w,h)
        self.draw.rack.pad.pad_activearea(note, x,y,w,h)
        ImGui.EndChild(ctx)
      end
    end
    ---------------------------------------------
    self.draw.rack.pad.pad_activearea = 
    function(note, x,y,w,h) 
      reaper.ImGui_SetCursorScreenPos(ctx, x+1, y)
      if h-self.var.UI_linear.pad_controls_H < 0.5*h then 
        ImGui.InvisibleButton(ctx, '##rackpad_main'..note, w-2, h)
       else
        ImGui.InvisibleButton(ctx, '##rackpad_main'..note, w-2, h-self.var.UI_linear.pad_controls_H)
      end 
      
      -- handle drop target  
        if self.var.rack.children and self.var.rack.children[note] and self.var.rack.children[note].exists then
          if ImGui.BeginDragDropSource( ctx, ImGui.DragDropFlags_None ) then  
            ImGui.SetDragDropPayload( ctx, 'moving_pad', note, ImGui.Cond_Once )
            ImGui.Text(ctx, 'Move pad ['..note..'] '..self.var.rack.children[note].params.P_NAME)
            self.temp_paddrop_ID = note
            ImGui.EndDragDropSource(ctx)
          end  
        end
      -- handle drop source
        if ImGui.BeginDragDropTarget( ctx ) then self.process.rack.changesample.dropsampletopad.all(note) ImGui_EndDragDropTarget( ctx ) end  
      
      -- on click
          if ImGui.IsItemActivated( ctx ) then 
            if self.var.ext.UI_clickonpadplaysample.current ==1 then self.process.midi.stuff_note(note) end
            if self.var.ext.UI_clickonpadselecttrack.current == 1 then self.process.rack.children.selecttrack(note) end
            if self.var.ext.UI_clickonpadscrolltomixer.current == 1 then self.process.rack.children.SetMixerScroll(note) end
          end 
          if ImGui.IsItemDeactivated( ctx ) then
            if self.var.ext.UI_clickonpadplaysample.current ==1 and self.ext.cur.UI_pads_sendnoteoff == 1 then self.process.midi.stuff_note(note, 0, true) end 
          end
        
      -- store current note
        if ImGui.IsItemClicked( ctx, ImGui.MouseButton_Left ) then 
          -- apply current note
            self.var.rack.var.LASTACTIVENOTE = note
            self.var.rack.var.LASTACTIVENOTE_LAYER = 1
            self.process.rack.parent.set_ext_state() 
          -- reset and calc peaks
            self.var.sampler.peaksSOFFS = 0 
            self.var.sampler.peaksEOFFS = 1
            self.var.sampler.zoom = 1  
            self.process.sampler.peaks.collect()
        end
        
      -- store current note + popup
        if ImGui.IsItemClicked( ctx, ImGui.MouseButton_Right ) then 
          self.var.rack.var.LASTACTIVENOTE = note
          self.var.rack.var.LASTACTIVENOTE_LAYER = 1
          self.process.rack.parent.set_ext_state()
          -- open context popup
            -- TO DO context
        end 
      
    end
    ---------------------------------------------
    self.draw.rack.pad.frame =--/ selection 
    function(note, x,y,w,h) 
      local color --= 0x0000005F
      if (self.var.rack.var.LASTACTIVENOTE and self.var.rack.var.LASTACTIVENOTE == note) then color = (self.var.ext.UI_colRGBA_maintheme.current&0xFFFFFF00)|0xF0 end
      if color then ImGui.DrawList_AddRect( self.draw.draw_list, x, y, x+w, y+h, color, self.var.UI_linear.round_corners+3, ImGui.DrawFlags_None|ImGui.DrawFlags_RoundCornersAll,2 ) end
    end
    ---------------------------------------------
    self.draw.rack.pad.led = 
    function(note, x,y,w,h)
      if not self.var.rack.children[note]  then return end--and self.var.rack.children[note].exists
      local offs = 5
      local ledxspace = 2
      local sz = 5
      local ledx= x+w-sz-ledxspace-2
      local ledy= y+ h-self.var.UI_linear.pad_controls_H-6
      if self.var.rack.children[note].device and self.var.rack.children[note].device.TYPE_DEVICE==true then         ImGui.DrawList_AddRectFilled( self.draw.draw_list, ledx, ledy, ledx+sz, ledy+sz, 0x00FF50FF, 0, ImGui.DrawFlags_None) ledx=ledx-sz-ledxspace end
      if self.var.rack.children[note].params.has_database_usage then   ImGui.DrawList_AddRectFilled( self.draw.draw_list, ledx, ledy, ledx+sz, ledy+sz, 0x0090FFFF, 0, ImGui.DrawFlags_None) ledx=ledx-sz-ledxspace end
      if self.var.rack.children[note].params.has_database_locked then   ImGui.DrawList_AddRectFilled( self.draw.draw_list, ledx, ledy, ledx+sz, ledy+sz, 0xFF5000FF, 0, ImGui.DrawFlags_None) ledx=ledx-sz-ledxspace end
      if self.var.rack.midibus and self.var.rack.midibus.choke and self.var.rack.midibus.choke.child_JSFX and self.var.rack.midibus.choke.child_JSFX[note] then   
                                                            ImGui.DrawList_AddRectFilled( self.draw.draw_list, ledx, ledy, ledx+sz, ledy+sz, 0xFFFF00FF, 0, ImGui.DrawFlags_None) ledx=ledx+offs+ledxspace end
    end
    ---------------------------------------------
    self.draw.rack.pad.background = 
    function(note, x,y,w,h)
      local default_color = self.var.ext.UI_colRGBA_paddefaultbackgr_inactive.current
      local default_color_existingtrack = self.var.ext.UI_colRGBA_paddefaultbackgr.current
      local color = default_color
      
      -- track has color
      if self.var.rack.children[note] and self.var.rack.children[note].exists and self.var.rack.children[note].params and self.var.rack.children[note].params.I_CUSTOMCOLOR then 
        color = ImGui.ColorConvertNative(self.var.rack.children[note].params.I_CUSTOMCOLOR) 
        color = color & 0x1000000 ~= 0 and (color << 8) | self.var.ext.UI_col_tinttrackcoloralpha.current-- https://forum.cockos.com/showpost.php?p=2799017&postcount=6 
      end  
      
      -- track has default color
      if self.var.rack.children[note] and self.var.rack.children[note].exists and self.var.rack.children[note].params and self.var.rack.children[note].params.I_CUSTOMCOLOR and self.var.rack.children[note].params.I_CUSTOMCOLOR & 0x1000000 == 0 then 
        color = default_color_existingtrack
      end
      
      -- rack overrided
      if self.var.ext.CONF_autocol.current == 1 then 
        if self.var.ext.PAD_OVERRIDES and self.var.ext.PAD_OVERRIDES.colors and self.var.ext.PAD_OVERRIDES.colors[note] then color = self.var.ext.PAD_OVERRIDES.colors[note]|0xFF end
      end
      
      -- draw
      local controls_block_draw = h-self.var.UI_linear.pad_controls_H < 0.5*h
      if controls_block_draw == true then 
        color = (color&0xFFFFFF00)|0x90 -- dim color
        ImGui.DrawList_AddRectFilled( self.draw.draw_list, x+1, y, x+w-1, y+h, color, 5, ImGui.DrawFlags_RoundCornersTop)  
       else
        ImGui.DrawList_AddRectFilled( self.draw.draw_list, x+1, y, x+w-1, y+h-self.var.UI_linear.pad_controls_H, color, 5, ImGui.DrawFlags_RoundCornersTop)  
        ImGui.DrawList_AddRectFilled( self.draw.draw_list, x+1, y+h-self.var.UI_linear.pad_controls_H, x+w-1, y+h-1, self.var.ext.UI_colRGBA_padctrl.current, 5, ImGui.DrawFlags_RoundCornersBottom )
      end
    end
    ---------------------------------------------
    self.draw.rack.pad.peaks = 
    function(note, x,y,w,h)
      local out_w = w-4 
      if not self.var.rack.peaks.children[note] then self.var.rack.peaks.children[note]={} end
      self.var.rack.peaks.children[note].peaks_W = out_w
      if not (self.var.rack.peaks.children and self.var.rack.peaks.children[note] and self.var.rack.peaks.children[note].peaks_array) then return end
      self.draw.peaks(self.var.rack.peaks.children[note].peaks_array, x+2,y+self.var.UI_linear.pad_header_H,out_w,h-self.var.UI_linear.pad_controls_H-self.var.UI_linear.pad_header_H)
    end
    ---------------------------------------------
    self.draw.rack.pad.meters = 
    function(note, x,y,w,h)
      local peak_w = 5 
      if not (self.var.rack.children and self.var.rack.children[note] and self.var.rack.children[note].params.metersRMS_L) then return end
      local metersRMS_L = self.var.rack.children[note].params.metersRMS_L   
      local metersRMS_R = self.var.rack.children[note].params.metersRMS_R 
      local RMS = (0.5*(metersRMS_L+metersRMS_R))^2
      
      local peakH_full = (h-self.var.UI_linear.pad_controls_H-self.var.UI_linear.pad_header_H)*(math.min(metersRMS_L,1))
      local peakLx = x+w-peak_w-2
      local peakLy = y+h-self.var.UI_linear.pad_controls_H-peakH_full
      local  col_upr_left = 0xFFf050FF
      local col_bot_right = 0x50FF50FF
      ImGui.DrawList_AddRectFilledMultiColor( self.draw.draw_list, peakLx, peakLy, peakLx+peak_w, peakLy+peakH_full, col_upr_left, col_upr_left, col_bot_right, col_bot_right)
      if metersRMS_L >0.8 then ImGui.DrawList_AddLine( self.draw.draw_list, peakLx, y+self.var.UI_linear.pad_header_H , peakLx+peak_w, y+self.var.UI_linear.pad_header_H, 0xFF0000FF, 2) end
    end
    ---------------------------------------------
    self.draw.rack.pad.name = 
    function(note)
      local pad_name = self.utils.format_note(note)
      
      -- track name
      if self.var.rack.children and self.var.rack.children[note] and self.var.rack.children[note].params and self.var.rack.children[note].params.P_NAME then pad_name = self.var.rack.children[note].params.P_NAME end
      -- global overrides
      if self.var.ext.PAD_OVERRIDES and self.var.ext.PAD_OVERRIDES.names and self.var.ext.PAD_OVERRIDES.names[note] then pad_name = self.var.ext.PAD_OVERRIDES.names[note] end
      -- rack overrides 
      if self.var.rack.PAD_OVERRIDES and self.var.rack.PAD_OVERRIDES.names and self.var.rack.PAD_OVERRIDES.names[note] then pad_name = self.var.rack.PAD_OVERRIDES.names[note] end
      
      ImGui.PushFont(ctx, self.font, self.var.UI_linear.font_sz_padname)  
      ImGui.Dummy(ctx, 1,0)
      ImGui.SameLine(ctx)
      ImGui.TextWrapped( ctx, pad_name )
      ImGui.PopFont(ctx) 
    end
    ---------------------------------------------
    self.draw.rack.pad.pad_controls = 
    function(note, x,y,w,h) 
      if h-self.var.UI_linear.pad_controls_H < 0.5*h then return end
      ImGui.SetCursorScreenPos(ctx, x,y + h-self.var.UI_linear.pad_controls_H)
      
      -- drop layers here
      if self.var.ext.UI_allowdoplayeronpad.current == 1 then  
        local retval, filename = reaper.ImGui_GetDragDropPayloadFile( ctx, 0 )
        if retval == true then 
          local alpha = 0.6
          if self.temp_hovered_note and self.temp_hovered_note == note then alpha = self.var.flicker end 
          ImGui.PushStyleColor(ctx, ImGui.Col_Button,   self.utils.rgb_alphadec(0xFF1F5F, alpha)) 
          ImGui.PushFont(ctx, self.font, self.var.UI_linear.font_sz_small) 
          ImGui.Button(ctx,'+ layer##rackpad_droplayer'..note,-1,-1 )
          if ImGui.IsItemHovered(ctx, ImGui.HoveredFlags_AllowWhenBlockedByActiveItem|ImGui.HoveredFlags_AllowWhenOverlapped) then self.temp_hovered_note = note end
          ImGui.PopFont(ctx) 
          if ImGui.BeginDragDropTarget( ctx ) then  
            self.process.rack.changesample.dropsampletoPadAddLayer.all(note)
            ImGui_EndDragDropTarget( ctx )
          end 
          ImGui.PopStyleColor(ctx)
          return 
        end
      end
      
      -- mute lay solo
      self.var.UI_linear.pad_controlsW = math.floor((self.var.UI_linear.padW-self.var.UI_linear.spacingX*2)/3)
      ImGui.PushFont(ctx, self.font, self.var.UI_linear.font_sz_small) 
      -- mute
        local ismute = note and self.var.rack.children and self.var.rack.children[note] and self.var.rack.children[note].params and self.var.rack.children[note].params.B_MUTE and self.var.rack.children[note].params.B_MUTE == 1
        if ismute==true then ImGui.PushStyleColor(ctx, ImGui.Col_Text, 0xFF0F0FF0 ) end 
        if self.ImGui.Custom_InvisibleButton (ctx,'M##rackpad_mute'..note,self.var.UI_linear.pad_controlsW,-1 ) then self.process.rack.children.mute(note) end   
        if ismute==true then ImGui.PopStyleColor(ctx) end
        ImGui.SameLine(ctx)
        
      -- play
        self.ImGui.Custom_InvisibleButton (ctx,'##rackpad_playinv'..note,self.var.UI_linear.pad_controlsW,-1  )
        if ImGui.IsItemActivated( ctx ) then self.process.midi.stuff_note(note) end 
        if ImGui.IsItemDeactivated( ctx ) and self.var.ext.UI_pads_sendnoteoff.current == 1 then self.process.midi.stuff_note(note, 0, true) end 
        ImGui.SameLine(ctx)
        local x1, y1 = reaper.ImGui_GetItemRectMin( ctx )
        local x2, y2 = reaper.ImGui_GetItemRectMax( ctx ) 
        local midx,midy = x1+0.5*(x2-x1), y1+0.5*(y2-y1)
        local tri_sz = 4
        local color = self.var.UI_colors.textcol
        if self.var.recentinput_note and self.var.recentinput_note == note and self.var.recentinput_trigTS and time_precise() - self.var.recentinput_trigTS < 1 then color = self.var.ext.UI_colRGBA_maintheme.current|self.var.alpha_active end
        reaper.ImGui_DrawList_AddTriangleFilled( self.draw.draw_list, 
          midx-tri_sz, midy-tri_sz, 
          midx+tri_sz,midy, 
          midx-tri_sz,midy+tri_sz, 
          color )
        
        
      -- solo
        local issolo = note and self.var.rack.children and self.var.rack.children[note] and self.var.rack.children[note].params and self.var.rack.children[note].params.I_SOLO and self.var.rack.children[note].params.I_SOLO >0
        if issolo == true then ImGui.PushStyleColor(ctx, ImGui.Col_Text, 0x00FF0FF0 ) end
        if self.ImGui.Custom_InvisibleButton (ctx,'S##rackpad_solo'..note,self.var.UI_linear.pad_controlsW,-1 ) then  self.process.rack.children.solo(note) end
        if issolo == true then ImGui.PopStyleColor(ctx) end
          
      ImGui.PopFont(ctx) 
        
      end
  end    
  -------------------------------------------------------------------------------- 
  function DATA:func_def_UI_draw_settings() 
    self.draw.settings.all= 
    function()
      ImGui.PushFont(ctx, self.draw.font_ptr, self.var.UI_linear.font_sz_settings)  
      if ImGui.BeginPopup( ctx, 'settings_popup', ImGui.PopupFlags_None ) then
        -- version
          ImGui.BeginDisabled(ctx, true) ImGui.Text(ctx, 'RS5k manager '..rs5kman_vrs) ImGui.EndDisabled(ctx)
          ImGui.SameLine(ctx)
          ImGui.Dummy(ctx,5,0)
          
        if ImGui.BeginChild( ctx, '##settings_popup_child',self.var.UI_linear.settingsW_min, self.var.UI_linear.mainwindH_min,ImGui.ChildFlags_None, ImGui.WindowFlags_None ) then 
          
          -- draw categories tree  
            if ImGui_BeginListBox( ctx, '##Preferences', 180, -1 ) then
              ImGui.SeparatorText( ctx, 'General') 
                if ImGui.Selectable( ctx, 'Keyboard',                     self.var.ext.UI_preference_page.current == 'General_Keyboard' ) then  self.var.ext.UI_preference_page.current = 'General_Keyboard' self.process.ext.save() end 
              ImGui.SeparatorText( ctx, 'On sample drop')
                if ImGui.Selectable( ctx, 'Track##onsampledrop_track',     self.var.ext.UI_preference_page.current == 'onsampledrop_track' ) then self.var.ext.UI_preference_page.current = 'onsampledrop_track' self.process.ext.save() end
                if ImGui.Selectable( ctx, 'Various##onsampledrop_various',     self.var.ext.UI_preference_page.current == 'onsampledrop_various' ) then self.var.ext.UI_preference_page.current = 'onsampledrop_various' self.process.ext.save() end
              ImGui.SeparatorText( ctx, 'Drum Rack')
                if ImGui.Selectable( ctx, 'Layout',                       self.var.ext.UI_preference_page.current == 'rack_layout' ) then self.var.ext.UI_preference_page.current = 'rack_layout' self.process.ext.save() end
                if ImGui.Selectable( ctx, 'Pad##rack_pad',                self.var.ext.UI_preference_page.current == 'rack_pad' ) then self.var.ext.UI_preference_page.current = 'rack_pad' self.process.ext.save() end
                if ImGui.Selectable( ctx, 'Overrides##rack_overrides',    self.var.ext.UI_preference_page.current == 'rack_overrides' ) then self.var.ext.UI_preference_page.current = 'rack_overrides' self.process.ext.save() end
              ImGui.SeparatorText( ctx, 'MIDI')
                if ImGui.Selectable( ctx, 'Pad##midi_pad',                self.var.ext.UI_preference_page.current == 'midi_pad' ) then self.var.ext.UI_preference_page.current = 'midi_pad' self.process.ext.save() end
                if ImGui.Selectable( ctx, 'MIDI bus##midibus',            self.var.ext.UI_preference_page.current == 'midibus' ) then self.var.ext.UI_preference_page.current = 'midibus' self.process.ext.save() end
              reaper.ImGui_EndListBox( ctx )
            end
            ImGui.SameLine(ctx)
            
          -- draw actual settings  
            if ImGui.BeginChild( ctx, '##settings_popup_child2',-1,-1,ImGui.ChildFlags_None, ImGui.WindowFlags_None ) then
              if self.draw.settings[self.var.ext.UI_preference_page.current] then self.draw.settings[self.var.ext.UI_preference_page.current]() end
              ImGui.EndChild( ctx) 
            end
            
          ImGui.EndChild( ctx) 
        end 
        ImGui.EndPopup( ctx ) 
      end
      ImGui.PopFont(ctx)
    end
    ---------------------------------------------------------------------------------------
    self.draw.settings.General_Keyboard = 
    function()
      if ImGui.Checkbox( ctx, 'Allow shortcuts',                                  self.var.ext.UI_allowshortcuts.current == 1 ) then self.var.ext.UI_allowshortcuts.current =self.var.ext.UI_allowshortcuts.current~1 self.process.ext.save() end
    end
    ---------------------------------------------------------------------------------------
    self.draw.settings.rack_layout=
    function()
      -- combo
        local close_at_execute = true
        self.draw.combo('UI_drracklayout',{[0]='[factory] Default / 8x4 pads',[1]='[factory] 2 octaves keys',[2]='Custom',[3]='[factory] Akai MPC'},'##settings_drracklayout', 'DrumRack layout', 220, function() self.process.rack.layout.get() reaper.ImGui_CloseCurrentPopup(ctx) end)
      -- input
        if not self.temp_layout_multiline then self.temp_layout_multiline = self.utils.base64.dec(self.var.ext.UI_drracklayout_customB64.current) end
        local retval, buf = reaper.ImGui_InputTextMultiline( ctx, '##UI_drracklayout_customB64_str', self.temp_layout_multiline, -1, 150, ImGui.InputTextFlags_None )
        if retval then 
          self.temp_layout_multiline = buf
          self.var.ext.UI_drracklayout_customB64.current = self.utils.base64.enc(buf)
          self.process.ext.save()
          self.process.rack.layout.get()
        end
      -- Launchpad (bot left block) template
        if ImGui.Button(ctx, 'Generate Launchpad (bot left block) template',-1) then 
          local buf = 
[[cell_cnt_max = 16
row_cnt = 4 
col_cnt = 4 
]] 
          for note = 36, 51 do buf = buf..'\n'..note..' x'..(note%4)..' y'..(3-math.floor((note-36) / 4)) end 
          self.process.rack.layout.generate_custom(buf) 
        end   
        
      -- Launchpad (bot left block) template
        if ImGui.Button(ctx, 'Generate Launchpad (full 8x8) template',-1) then 
          local buf = 
[[cell_cnt_max = 64
row_cnt = 8 
col_cnt = 8 
]] 
          for note = 36, 51 do buf = buf..'\n'..note..' x'..(note%4)..' y'..(7-math.floor((note-36) / 4)) end 
          for note = 52, 67 do buf = buf..'\n'..note..' x'..(note%4)..' y'..(3-math.floor((note-52) / 4)) end 
          for note = 68, 83 do buf = buf..'\n'..note..' x'..(4+(note%4))..' y'..(7-math.floor((note-68) / 4)) end 
          for note = 84, 99 do buf = buf..'\n'..note..' x'..(4+(note%4))..' y'..(3-math.floor((note-84) / 4)) end 
          self.process.rack.layout.generate_custom(buf) 
        end  
    end
    ---------------------------------------------------------------------------------------
    self.draw.settings.rack_pad=
    function() 
      if ImGui.Checkbox( ctx, 'Click on pad select track',                              self.var.ext.UI_clickonpadselecttrack.current == 1 ) then self.var.ext.UI_clickonpadselecttrack.current =self.var.ext.UI_clickonpadselecttrack.current~1 self.process.ext.save() end
      
      if ImGui.Checkbox( ctx, 'Click on pad scroll mixer',                               self.var.ext.UI_clickonpadscrolltomixer.current == 1 ) then self.var.ext.UI_clickonpadscrolltomixer.current =self.var.ext.UI_clickonpadscrolltomixer.current~1 self.process.ext.save() end
      if ImGui.Checkbox( ctx, 'Allow drop layers on pads',                               self.var.ext.UI_allowdoplayeronpad.current == 1 ) then self.var.ext.UI_allowdoplayeronpad.current =self.var.ext.UI_allowdoplayeronpad.current~1 self.process.ext.save() end
      if ImGui.Checkbox( ctx, 'Show meters on pads',                                    self.var.ext.UI_showplayingmeters.current == 1 ) then self.var.ext.UI_showplayingmeters.current =self.var.ext.UI_showplayingmeters.current~1 self.process.ext.save() end ImGui.SameLine(ctx) self.ImGui.Custom_HelpMarker('May be CPU hungry') 
    end
    ---------------------------------------------------------------------------------------
    self.draw.settings.onsampledrop_track = 
    function()
      if ImGui.Checkbox( ctx, 'Rename track',                                           self.var.ext.CONF_onadd_renametrack.current == 1 ) then self.var.ext.CONF_onadd_renametrack.current =self.var.ext.CONF_onadd_renametrack.current~1 self.process.ext.save() end 
      ImGui_SetNextItemWidth(ctx, self.var.UI_linear.settings_itemW)   local ret, buf = ImGui.InputText( ctx, 'Custom template file',                    self.var.ext.CONF_onadd_customtemplate.current, ImGui.InputTextFlags_None)  
        if ret then self.var.ext.CONF_onadd_customtemplate.current =buf  self.process.ext.save() end ImGui.SameLine(ctx) self.ImGui.Custom_HelpMarker('FULL path to TrackTemplate file')
        self.draw.combo('CONF_onadd_ordering',{[0]='Sort by note',[1]='To the top', [2]='To the bottom'},'##settings_childorder', 'New reg child order', self.var.UI_linear.settings_itemW)  
        if ImGui.Checkbox( ctx, 'Set child color from parent color',                    self.var.ext.CONF_onadd_takeparentcolor.current == 1 ) then self.var.ext.CONF_onadd_takeparentcolor.current =self.var.ext.CONF_onadd_takeparentcolor.current~1 self.process.ext.save() end 
    end 
    ---------------------------------------------------------------------------------------
    self.draw.settings.onsampledrop_various = 
    function()
      if ImGui.Checkbox( ctx, 'On drop multiple replace sample on existing pads',       self.var.ext.CONF_onadd_replaceexistingpads.current == 1 ) then self.var.ext.CONF_onadd_replaceexistingpads.current =self.var.ext.CONF_onadd_replaceexistingpads.current~1 self.process.ext.save() end
      if ImGui.Checkbox( ctx, 'Auto-set velocity range option enabled for new devices', self.var.ext.CONF_onadd_autosetrange.current == 1 ) then self.var.ext.CONF_onadd_autosetrange.current =self.var.ext.CONF_onadd_autosetrange.current~1 self.process.ext.save() end 
      if ImGui.Checkbox( ctx, 'Enable sysex mode for new childs',                       self.var.ext.CONF_onadd_sysexmode.current == 1 ) then self.var.ext.CONF_onadd_sysexmode.current =self.var.ext.CONF_onadd_sysexmode.current~1 self.process.ext.save() end
      
    end
    ---------------------------------------------------------------------------------------
    self.draw.settings.midi_pad=
    function()
      if ImGui.Checkbox( ctx, 'Click on pad play sample (stuff MIDI to MIDI bus)',                               self.var.ext.UI_clickonpadplaysample.current == 1 ) then self.var.ext.UI_clickonpadplaysample.current =self.var.ext.UI_clickonpadplaysample.current~1 self.process.ext.save() end
      ImGui_SetNextItemWidth(ctx, self.var.UI_linear.settings_itemW) 
      local ret, v = ImGui.SliderInt( ctx, 'Default playing velocity',                  self.var.ext.CONF_default_velocity.current, 1, 127, '%d', ImGui.SliderFlags_None ) if ret then self.var.ext.CONF_default_velocity.current = v self.process.ext.save() end
      if ImGui.Checkbox( ctx, 'Releasing mouse on pad send NoteOff',                    self.var.ext.UI_pads_sendnoteoff.current == 1 ) then self.var.ext.UI_pads_sendnoteoff.current =self.var.ext.UI_pads_sendnoteoff.current~1 self.process.ext.save() end
      if ImGui.Checkbox( ctx, 'Active note follow incoming note',                       self.var.ext.UI_incomingnoteselectpad.current&1==1 ) then self.var.ext.UI_incomingnoteselectpad.current =self.var.ext.UI_incomingnoteselectpad.current~1 self.process.ext.save() end ImGui.SameLine(ctx) self.ImGui.Custom_HelpMarker('May be CPU hungry')
      if self.var.ext.UI_incomingnoteselectpad.current&1==1 then
        ImGui.Indent(ctx,self.var.UI_linear.menu_indentX)
        if ImGui.Checkbox( ctx, 'Only when stopped or paused',                       self.var.ext.UI_incomingnoteselectpad.current&2==2) then self.var.ext.UI_incomingnoteselectpad.current =self.var.ext.UI_incomingnoteselectpad.current~2 self.process.ext.save() end 
        ImGui.Unindent(ctx,self.var.UI_linear.menu_indentX)
      end
    end
    ---------------------------------------------------------------------------------------
    self.draw.settings.midibus = 
    function()
      if ImGui.Button(ctx, 'Initialize / validate MIDI bus',-1) then self.process.rack.midibus.validate()  end
      if prerecsends_available==true then ImGui.BeginDisabled(ctx,true) end
      if ImGui.Checkbox( ctx, 'Use pre-receive sends',                    self.var.ext.CONF_useprerecsends.current&1==1 ) then self.var.ext.CONF_useprerecsends.current =self.var.ext.CONF_useprerecsends.current~1 self.process.ext.save() end ImGui.SameLine(ctx) ImGui.TextDisabled(ctx, 'require REAPER 7.61+')
      if prerecsends_available==true then ImGui.EndDisabled(ctx) end
      self.draw.combo('CONF_midiinput',self.var.MIDIdevices.inputs,'##settings_drracklayout_midiin', 'MIDI bus default input') 
      self.draw.combo('CONF_midioutput',self.var.MIDIdevices.outputs,'##settings_drracklayout_midiout', 'MIDI bus default output')  
      ImGui.SetNextItemWidth(ctx, self.var.UI_linear.settings_itemW )
      local chanformat = 'Channel '..self.var.ext.CONF_midichannel.current if self.var.ext.CONF_midichannel.current == 0 then chanformat = 'All channels' end
      local ret, v = ImGui.SliderInt( ctx, 'MIDI bus channel',                          self.var.ext.CONF_midichannel.current, 0, 16, chanformat, ImGui.SliderFlags_None ) if ret then self.var.ext.CONF_midichannel.current = v self.process.ext.save() end
      if ImGui.Checkbox( ctx, 'Auto rename MIDI bus MIDI notes',                                self.var.ext.CONF_autorenamemidinotenames.current&1==1 ) then self.var.ext.CONF_autorenamemidinotenames.current =self.var.ext.CONF_autorenamemidinotenames.current~1 self.process.ext.save() end
      if ImGui.Checkbox( ctx, 'Auto rename devices and children MIDI notes',                    self.var.ext.CONF_autorenamemidinotenames.current&2==2 ) then self.var.ext.CONF_autorenamemidinotenames.current =self.var.ext.CONF_autorenamemidinotenames.current~2 self.process.ext.save() end
      
    end
    ---------------------------------------------------------------------------------------
    self.draw.settings.rack_overrides = 
    function()
      ImGui.TextDisabled(ctx, 'This are global overrides (stored into REAPER ext state).\nLocal Rack overrides have priority over this.')
      if ImGui.Checkbox( ctx, 'Slider follow incoming MIDI note##UI_noteselpadoverride_autofollow',                                   self.var.ext.UI_noteselpadoverride_autofollow.current == 1 ) then self.var.ext.UI_noteselpadoverride_autofollow.current =self.var.ext.UI_noteselpadoverride_autofollow.current~1 self.process.ext.save() end
      
      -- selector
      if not self.temp_setrackoverrides then self.temp_setrackoverrides = 36 end
      if self.var.ext.UI_noteselpadoverride_autofollow.current == 1 then ImGui.BeginDisabled(ctx,true) end 
      local retval, v = reaper.ImGui_SliderInt( ctx, '##temp_setrackoverrides_names', self.temp_setrackoverrides, 0, 127, '%d', reaper.ImGui_SliderFlags_None() )
      if self.var.ext.UI_noteselpadoverride_autofollow.current == 1 then ImGui.EndDisabled(ctx) end
      local x1, y1 = reaper.ImGui_GetItemRectMin( ctx )
      local w1, h1 = reaper.ImGui_GetItemRectSize( ctx )
      local stepW = w1 / 128
      local lineH = h1*0.5
      for note = 0, 127 do 
        if self.var.ext and self.var.ext.PAD_OVERRIDES and self.var.ext.PAD_OVERRIDES.names and self.var.ext.PAD_OVERRIDES.names[note] then 
          ImGui.DrawList_AddRectFilled( self.draw.draw_list, x1+stepW*note, y1, x1+stepW*(note+1), y1+lineH, self.var.UI_colors.fill_active_values_in_sliders, 1, reaper.ImGui_DrawFlags_None() )
        end
        if self.var.ext and self.var.ext.PAD_OVERRIDES and self.var.ext.PAD_OVERRIDES.colors and self.var.ext.PAD_OVERRIDES.colors[note] then 
          local col = self.var.ext.PAD_OVERRIDES.colors[note] -- self.var.UI_colors.fill_active_values_in_sliders
          ImGui.DrawList_AddRectFilled( self.draw.draw_list, x1+stepW*note, y1+lineH, x1+stepW*(note+1), y1+h1, col|0xFF, 1, reaper.ImGui_DrawFlags_None() )
        end
      end
      
      -- names
      ImGui.SeparatorText(ctx, 'Pad names global overrides') 
      ImGui.Indent(ctx, self.var.UI_linear.menu_indentX)
        if ImGui.Button(ctx, 'Clean all##set_cleanpadnames') then             self.process.ext.PAD_OVERRIDES.set_clean()  end ImGui.SameLine(ctx)
        if ImGui.Button(ctx, 'General MIDI bank') then                    self.process.ext.PAD_OVERRIDES.set_GeneralMIDI()  end ImGui.SameLine(ctx)
        if ImGui.Button(ctx, 'Akai MPC') then                             self.process.ext.PAD_OVERRIDES.set_akaimpc()   end
        
        if self.temp_setrackoverrides then 
          note = self.temp_setrackoverrides
          local note_name = string.format('%02d', note) ..' / '..self.utils.format_note(note)
          self.ImGui.Custom_InvisibleButton(ctx,note_name,100 )
          ImGui.SameLine(ctx)
          local buf_init = self.var.ext.PAD_OVERRIDES.names[note]
          local retval, buf = ImGui_InputText( ctx, '##custpadnameinput'..note, buf_init, ImGui_InputTextFlags_None() )
          if retval then 
            buf = buf:gsub('[^%a%d%s%-]+','')
            self.var.ext.PAD_OVERRIDES.names[note] = buf
          end
          if ImGui_IsItemDeactivatedAfterEdit( ctx ) then 
            self.process.ext.PAD_OVERRIDES.set()  
          end
        end
              
        ImGui.Unindent(ctx, self.var.UI_linear.menu_indentX)
              
      -- names
      ImGui.SeparatorText(ctx, 'Pad color global overrides')
      ImGui.Indent(ctx, self.var.UI_linear.menu_indentX)
        self.draw.combo('CONF_autocol',{[0]='Off',[1]='By note'},'##CONF_autocol', 'Mode', 220)  
        if self.var.ext.CONF_autocol.current == 1 then
          if ImGui.Button(ctx, 'Clean all##set_cleanpadcolors') then             
            self.process.ext.PAD_OVERRIDES.set_clean_colors() 
          end --ImGui.SameLine(ctx)
          
          -- color input
          local colext = 0
          if self.temp_setrackoverrides and self.var.ext.PAD_OVERRIDES.colors and self.var.ext.PAD_OVERRIDES.colors[self.temp_setrackoverrides] then colext =  self.var.ext.PAD_OVERRIDES.colors[self.temp_setrackoverrides] end
          if colext then colext = tonumber(colext) end
          local col_rgba  = colext or 0
          if col_rgba then 
            local retval, col_rgba = ImGui.ColorEdit4( ctx, '##coloreditpad_auto', col_rgba|0xFF, ImGui.ColorEditFlags_None|ImGui.ColorEditFlags_NoInputs)--|ImGui.ColorEditFlags_NoAlpha )
            if retval then 
              self.var.ext.PAD_OVERRIDES.colors[self.temp_setrackoverrides]  = col_rgba
            end
            if ImGui_IsItemDeactivatedAfterEdit( ctx ) then
              self.process.ext.PAD_OVERRIDES.set()  
            end
          end
          ImGui.SameLine(ctx)
          
          -- reset color
          if ImGui.Selectable( ctx, 'Reset##CONF_autocol_selectorreset', ImGui.SelectableFlags_None) then 
            if self.temp_setrackoverrides and self.var.ext.PAD_OVERRIDES.colors and self.var.ext.PAD_OVERRIDES.colors[self.temp_setrackoverrides] then self.var.ext.PAD_OVERRIDES.colors[self.temp_setrackoverrides] = nil end 
            self.process.ext.PAD_OVERRIDES.set() 
          end
          
        end
      ImGui.Unindent(ctx, self.var.UI_linear.menu_indentX)
    end     
  end       
  -----------------------------------------------------------------------------------------  
  function DATA:func_def_images() 
    self.draw.images.settings = ImGui.CreateImageFromMem( 
              "\x89\x50\x4E\x47\x0D\x0A\x1A\x0A\x00\x00\x00\x0D\x49\x48\x44\x52\z
                \x00\x00\x00\x10\x00\x00\x00\x10\x08\x06\x00\x00\x00\x1F\xF3\xFF\z
                \x61\x00\x00\x00\x09\x70\x48\x59\x73\x00\x00\x0E\xC4\x00\x00\x0E\z
                \xC4\x01\x95\x2B\x0E\x1B\x00\x00\x00\xCB\x49\x44\x41\x54\x38\x8D\z
                \xA5\x93\x31\x0E\x82\x40\x14\x44\x27\x54\xB4\x26\x54\x1E\x81\x92\z
                \x96\xCB\x78\x03\xA9\x36\x5E\x66\xBD\x85\x31\x96\x1C\x4A\x4C\xB4\z
                \x78\x16\x7C\xE2\xCF\xB2\xA8\xE8\x24\x3F\x61\x87\x99\xC9\xDF\xDD\z
                \xBF\xD2\x02\x80\x06\xB8\x59\x35\x4B\x3A\x6F\x28\x81\xDA\xAD\x23\z
                \x2F\x44\xC7\xD7\x40\x99\x33\x5F\x4C\xDC\x03\x07\xE0\xEA\x02\xAE\z
                \x40\xB0\x7F\x98\xB6\x54\x92\xBA\x16\x75\xDA\x45\xFF\xD1\xF2\x42\z
                \x3F\xF9\x0A\x97\x71\x72\xDF\x77\x49\x7B\x49\x1B\xAB\xBD\x71\x13\z
                \xCE\xE9\x69\xC7\x64\xCF\x5D\xE6\x90\xBB\xE4\x4C\x22\xD0\x88\xF1\z
                \x9A\x52\x54\x99\x80\x2A\xA3\xBB\x15\xA9\x30\xB3\xB5\x77\x9C\x0A\z
                \x49\xAD\xA4\xA3\xA4\xC1\xF1\xBB\x8C\xD6\x73\x83\x79\x5A\xDF\x62\z
                \x70\xAD\x3D\x18\x67\x61\x6B\x75\x30\x6E\x42\x98\xC5\xFF\x7A\x8D\z
                \x93\xF9\xBF\x41\x62\x3E\xCA\x81\x35\xA3\xEC\x42\x7E\x7B\x4C\x39\z
                \xF0\xE5\x73\x7E\x02\x48\x9A\x14\xC1\x22\x7B\xBC\xF1\x00\x00\x00\z
                \x00\x49\x45\x4E\x44\xAE\x42\x60\x82")
                
                
     self.draw.images.random = ImGui.CreateImageFromMem(
                 "\x89\x50\x4E\x47\x0D\x0A\x1A\x0A\x00\x00\x00\x0D\x49\x48\x44\x52\z
                  \x00\x00\x00\x40\x00\x00\x00\x40\x08\x06\x00\x00\x00\xAA\x69\x71\z
                  \xDE\x00\x00\x00\x09\x70\x48\x59\x73\x00\x00\x0E\xC4\x00\x00\x0E\z
                  \xC4\x01\x95\x2B\x0E\x1B\x00\x00\x04\x73\x49\x44\x41\x54\x78\x9C\z
                  \xE5\x9B\x4D\x68\x1D\x55\x18\x86\xBF\xB9\x48\x28\xA5\x84\x4B\x09\z
                  \x25\x48\x29\x22\x45\xA4\x14\x91\x92\x85\x88\x74\x51\x4A\x57\xC5\z
                  \x85\x14\xB1\x20\x11\x8A\x4A\x11\x11\xE9\x4A\x44\xDC\x94\xAE\xC4\z
                  \xA5\x74\x21\xA1\x94\xE0\x42\xBA\x2A\xA5\xA8\x88\x14\x2D\x82\x35\z
                  \x14\xCD\x42\xA4\x88\x84\x22\xB1\x96\x52\x4B\x90\x20\xF1\x52\x1E\z
                  \x17\x67\x86\x4C\x4F\xE6\xE7\x9D\x39\x33\x77\x6E\xEE\x7D\x20\xAB\z
                  \xCC\x7C\xE7\x7B\xDF\xF9\xCE\x99\xF3\x33\xD7\x6C\x1B\x03\x4C\x03\z
                  \xEF\x03\xBD\xAE\x73\xE9\x04\xA0\x8F\xE3\x0B\x60\xA6\xEB\x7C\x86\z
                  \x4E\xCA\x00\x80\x55\xE0\x70\xD7\x39\x0D\x15\xCF\x00\x80\xC1\x44\z
                  \x75\x89\x0C\x03\x12\x26\xA3\x4B\x14\x18\x30\x19\x5D\xA2\xC4\x80\z
                  \xF1\xEF\x12\x82\x01\xA5\x5D\x22\x02\x96\xCD\x6C\x5F\x41\x3B\xFF\z
                  \x99\xD9\x5F\x66\xF6\x83\x99\x2D\x44\x51\xF4\x63\x0B\x5A\x72\x01\z
                  \x8E\x98\xD9\x6B\x66\x36\x67\x66\xBB\xBD\x7F\xF7\xCC\x6C\x8F\x18\z
                  \xEA\x4F\x33\x3B\x19\x45\xD1\x77\x7E\x03\x2B\xA2\x8B\x09\x0B\xC0\z
                  \x8E\x50\x61\x65\x00\x3B\x81\xCF\x2B\xE6\x56\xC6\xD6\x2E\x41\x75\z
                  \x03\x00\xBE\xA1\x45\x13\x80\xA9\xB8\x8D\xB6\xD8\xEC\x12\xD4\x33\z
                  \x00\xDC\xD3\x69\x65\x70\x01\xCE\x37\xA5\xB4\x80\x55\xE0\x70\x88\z
                  \x80\x97\xCD\xEC\x6C\x53\xA2\x13\x80\x53\x66\x76\xBA\xE9\xB8\x19\z
                  \xF4\xCD\xEC\xC9\x90\x0A\x48\x38\xD5\x54\x46\xC0\x1C\xF0\x6F\x60\z
                  \x3E\x0A\xBF\x02\x07\x93\x46\x57\x02\x83\x6D\xE0\x46\xEA\x50\xF1\z
                  \x33\xC0\xED\xC0\x5C\x14\x16\x81\x5D\xE9\x86\x57\x1A\x08\xFA\x00\z
                  \x38\x10\x20\xFE\x31\xE0\x5A\x03\x79\x14\xB1\x0E\xBC\x9E\xD5\xF8\z
                  \x34\x6E\x42\x91\xF5\xB7\x1B\xF8\x44\x6C\x60\x05\x50\xDF\xC9\x7E\z
                  \x0E\x1F\x8B\x6D\x5C\xF4\xF2\xDB\x27\xDE\xB7\x59\xF2\x35\x92\xEB\z
                  \x01\x97\xC4\x86\x6E\x00\x3B\x2B\xC6\x7F\x45\x8C\xBD\x84\xF7\xEA\z
                  \x45\x9B\x09\x3E\x5A\xF2\x35\x4D\xD8\x11\x8B\x53\xB8\x84\xF8\x7A\z
                  \x04\x9E\xC1\x95\x66\x19\x77\x81\x2D\xB3\xD5\x12\x03\xB2\x4B\x3E\z
                  \xC0\x84\x3D\xE8\xE3\xC5\x47\x42\xBC\x3E\xF0\x9B\x10\x6B\x40\xCE\z
                  \xAA\xAE\xC0\x80\xFA\x25\x5F\x92\xF4\x41\x60\x4D\x34\xE1\xCD\x82\z
                  \x38\x3D\xE0\xAA\x18\xE7\xED\x82\x38\x59\x06\x84\x97\x7C\x11\xC0\z
                  \xB1\xF8\xA9\x94\x31\x00\x8E\xE5\xC4\x38\x2B\x8A\xBF\x50\x92\x4B\z
                  \xDA\x80\x66\x4B\xBE\xA4\xE1\xD3\xA2\x80\x35\xBC\x52\x04\x5E\x04\z
                  \x1E\x0A\xF7\x6E\x19\xF4\x32\xF2\x48\x0C\x68\xA7\xE4\x4B\x1A\x57\z
                  \x5F\x5D\xB7\x81\xD9\xF8\x9E\xA7\xD0\xBA\xD0\x5D\x60\xAF\x90\x43\z
                  \x9F\xB6\x4B\xBE\xA0\xF1\x1E\x70\x59\x34\x61\x09\x98\x05\x7E\x11\z
                  \xAE\xCD\x1D\xF4\x46\x0E\xDC\x9A\xFD\xA6\x68\xC2\x03\xF1\xBA\xB7\z
                  \xBA\xD6\x55\x09\xE0\x71\xE0\x0F\x51\x5C\x19\x0B\x5D\xEB\xA9\x05\z
                  \xF0\x2C\xF0\x4F\xA0\xF8\x1B\x0C\x61\xA7\xA9\x35\x80\xE3\x68\xA3\z
                  \x7B\x16\x77\x10\x06\xBD\x91\x07\x78\xA7\x86\xF8\x0D\xE0\x85\xAE\z
                  \x73\x6F\x0C\xF4\xD5\x63\xC2\xF6\x1A\xF4\xCA\xC0\xAD\xED\x57\x45\z
                  \xF1\x6B\xC4\x73\x84\xB1\x01\xF8\xB0\x62\x05\x54\x5E\x42\x8F\x2C\z
                  \xE8\xD3\x5C\x1F\x79\x09\x3D\xB2\x00\x4F\xA3\xAF\x14\xB3\x38\xD7\z
                  \xB5\x86\xDA\xE0\xE6\xE4\xB7\x02\xC4\x27\xCC\x77\xAD\xA5\x32\x54\z
                  \x5B\xDB\x97\xB1\xC1\x76\x59\x07\x24\x00\xE7\x44\x71\xF7\xC4\xEB\z
                  \xEE\x03\xFB\xBB\xD6\x25\x01\x9C\x10\x45\x2D\xE3\x76\x98\xAF\x8B\z
                  \xD7\xDF\x02\xFC\x93\xE0\xD1\x02\xB7\xA1\xA9\xCC\xFF\xEF\x03\x4F\z
                  \xC4\xF7\xCC\xA0\x8F\x15\xD7\x80\xA9\x8E\x65\x66\x13\x3F\xCD\xDF\z
                  \x05\x11\x03\xE0\xA8\x77\xEF\x7E\xF4\xEE\xA0\x6C\x89\x5D\x64\x98\z
                  \x1B\x22\xB8\x99\xDE\xD7\xA2\x80\x33\x39\x31\x9E\x43\x3F\x03\x7C\z
                  \xAF\x20\x97\xE1\x6F\x89\xA1\x6F\x85\x7D\x56\x12\xE7\x04\xDA\xA4\z
                  \xE9\x21\xF0\x52\x4E\x0C\x7F\x53\xB4\xB1\x83\xDA\xBC\xA4\x5F\x15\z
                  \xC5\xFF\x84\x30\xBD\x05\xCE\x88\xF1\xD6\x81\xB9\x8C\xFB\xB3\xB6\z
                  \xC5\xDB\xE9\x12\xC0\x21\xB4\xB2\xBD\x47\x3C\xE8\x89\x71\xD5\xD5\z
                  \xE3\x1D\xBC\xD3\xA1\x1C\x03\xA0\xE9\x2E\x81\x3B\x15\x52\x8E\xAE\z
                  \x07\x54\x3C\x2A\xC7\x8D\x29\x57\x44\x13\x96\x49\x3D\xDD\x02\x03\z
                  \xA0\xA9\x2E\x11\x27\xF8\xAD\x98\x60\xE6\xA0\x27\xB4\xB1\x0B\xB7\z
                  \x73\xAC\x70\x95\x78\xE1\x54\x62\x40\x42\x71\x97\xA0\xF8\x78\xBC\z
                  \x8F\x5E\xA2\x85\x83\x9E\x60\xC2\x2C\xFA\x07\x12\x9F\xE2\xE6\x14\z
                  \xE1\xC7\xE3\x34\xF3\x81\xC4\x4D\x1A\x58\xD3\x03\x07\xD0\xB7\xCF\z
                  \xAB\x92\xDD\x25\x08\x37\xA0\xD2\xA0\x27\x98\x70\x04\xB7\x28\x6A\z
                  \x8B\x47\xBB\x04\x61\x06\x54\x1E\xF4\x44\x13\xE6\x9B\x50\x5A\x40\z
                  \x63\x1F\x49\xBD\xDB\xB4\xF8\x94\x09\x55\xB7\xD6\xAA\xB2\x0E\xCC\z
                  \x87\x18\xB0\xD8\x96\xF8\x94\x09\x17\x9A\x52\x9B\x81\xFB\x9C\x9E\z
                  \x7A\x06\x7C\xCF\x70\xBE\x17\x9E\xA2\xB9\xCD\x96\x34\x5F\x91\x7C\z
                  \xD0\x45\x75\x03\x2E\x03\xD3\x6D\x8B\xF7\x4C\x38\x4F\xFD\x53\xA7\z
                  \x34\x03\xE0\x03\x52\x1B\xB0\x11\xB0\x64\x66\x65\xC7\x52\x7F\x9B\z
                  \xD9\xCF\x66\xB6\x18\x45\xD1\x97\x6D\x0A\xCE\x03\x38\x64\x66\x6F\z
                  \x98\xD9\xF3\xB6\xF9\x89\x7C\xF8\xE7\xF2\xDB\x19\xF4\x1F\x4C\x6C\z
                  \x96\xFC\x38\x21\x18\xB0\xA5\xE4\xC7\x8A\x12\x03\x26\xFA\x47\x53\z
                  \xE3\x59\xF2\x3E\x19\x06\x8C\x77\xC9\xFB\x78\x06\x8C\x7F\xC9\xFB\z
                  \xA4\x0C\x98\x8C\x92\xF7\xC1\xED\x65\x04\x95\xFC\xFF\x7D\x24\x79\z
                  \xF5\x1F\xAF\x5A\x8C\x00\x00\x00\x00\x49\x45\x4E\x44\xAE\x42\x60\
                  \x82")
                  
        self.draw.images.folder = ImGui.CreateImageFromMem(
         "\x89\x50\x4E\x47\x0D\x0A\x1A\x0A\x00\x00\x00\x0D\x49\x48\x44\x52\z
          \x00\x00\x00\x40\x00\x00\x00\x40\x08\x06\x00\x00\x00\xAA\x69\x71\z
          \xDE\x00\x00\x00\x04\x73\x42\x49\x54\x08\x08\x08\x08\x7C\x08\x64\z
          \x88\x00\x00\x00\x09\x70\x48\x59\x73\x00\x00\x0D\xD7\x00\x00\x0D\z
          \xD7\x01\x42\x28\x9B\x78\x00\x00\x00\x19\x74\x45\x58\x74\x53\x6F\z
          \x66\x74\x77\x61\x72\x65\x00\x77\x77\x77\x2E\x69\x6E\x6B\x73\x63\z
          \x61\x70\x65\x2E\x6F\x72\x67\x9B\xEE\x3C\x1A\x00\x00\x00\x23\x74\z
          \x45\x58\x74\x54\x69\x74\x6C\x65\x00\x52\x68\x6F\x6E\xC2\xA0\x2D\z
          \x20\x57\x68\x69\x74\x65\x20\x2D\x20\x46\x6F\x6C\x64\x65\x72\x20\z
          \x2D\x20\x36\x34\x70\x78\xA8\x6E\x7D\x5F\x00\x00\x00\x1A\x74\x45\z
          \x58\x74\x41\x75\x74\x68\x6F\x72\x00\x52\x61\x7A\x61\x6E\x61\x6A\z
          \x61\x74\x6F\x20\x48\x61\x72\x65\x6E\x6F\x6D\x65\x56\x80\xF9\xB3\z
          \x00\x00\x00\x20\x74\x45\x58\x74\x43\x72\x65\x61\x74\x69\x6F\x6E\z
          \x20\x54\x69\x6D\x65\x00\x46\x65\x62\x72\x75\x61\x72\x79\x20\x31\z
          \x36\x74\x68\x20\x32\x30\x31\x30\x9F\x32\x71\x6B\x00\x00\x08\x1F\z
          \x49\x44\x41\x54\x78\x9C\xED\x5B\x4D\x68\x1C\xC9\x15\xFE\xAA\xBA\z
          \xBA\x25\x59\x5E\x81\x85\x11\xF8\x12\xFB\x10\x6C\x23\x74\xC9\xC5\z
          \xD7\x1C\x0C\x36\xE4\xE0\x4B\xF0\xC1\xF8\x94\x63\x2E\x1B\x12\x67\z
          \x0D\x39\x84\x64\x61\x21\x04\xC7\xE4\xB2\x39\xE4\x10\x7C\x31\xF8\z
          \xE8\x10\xC8\x5A\x36\x61\x61\xF7\x94\xF8\xB2\x24\x10\x88\x6C\xB0\z
          \x23\xB2\xB1\xBC\x06\x6F\x24\x8D\x46\x33\xDD\xF5\xF3\x72\x98\xAE\z
          \x51\xE9\xA9\xAA\xA7\xC7\xAB\x9F\xB5\xB4\x0F\x9A\xE9\xAE\xDF\xF7\z
          \xBE\xF7\xD5\x7B\xAF\x47\x23\x41\x44\x38\xCA\x22\x0F\x5A\x81\x83\z
          \x96\x6F\x00\x38\x68\x05\x0E\x5A\x8E\x3C\x00\x8A\x37\x3C\x78\xF0\z
          \x60\x22\xCB\xB2\x5F\x10\xD1\x4F\x89\x28\x17\x42\x44\x27\xC6\xDA\z
          \x53\x01\xB5\x6E\x77\x59\x96\x3D\x23\xA2\x4F\xAC\xB5\x9F\x16\x45\z
          \xF1\xF0\xE2\xC5\x8B\x5F\x7C\x25\xED\x77\x41\x04\x57\xFA\xD1\xA3\z
          \x47\x1F\x4C\x4D\x4D\xFD\xE4\xF4\xE9\xD3\x53\x93\x93\x93\x43\x43\z
          \xC3\x4F\xDE\xE6\xD7\x08\x3F\x79\x9B\xB5\x16\xFD\x7E\x1F\x65\x59\z
          \x52\xA7\xD3\xE9\xAD\xAD\xAD\xC1\x39\xF7\x7B\x22\xFA\xE0\xF2\xE5\z
          \xCB\x5F\xEE\xB1\x9D\x49\xD9\x01\xC0\xC3\x87\x0F\xAB\x73\xE7\xCE\z
          \xE5\x45\x51\xC0\x5A\xBB\xBB\x9B\x09\x01\x29\x25\xA4\x1C\x9C\xBC\z
          \xD7\xAF\x5F\x97\x2B\x2B\x2B\xC6\x18\xF3\x9B\x4E\xA7\xF3\xEB\xAB\z
          \x57\xAF\xF6\x76\x75\xC3\x16\xB2\x23\x06\x10\x51\x5E\x14\x05\x8C\z
          \x31\x43\x4F\xEE\xD6\xE5\x9C\x83\x31\x06\x55\x55\x41\x6B\x8D\x93\z
          \x27\x4F\x4E\x2C\x2C\x2C\x4C\xCF\xCD\xCD\xBD\x77\xE2\xC4\x89\x67\z
          \x8B\x8B\x8B\xDF\xDB\x6F\x00\x76\x30\x60\x71\x71\x91\x16\x16\x16\z
          \x60\x8C\xD9\x17\x05\xB2\x2C\x43\x9E\xE7\xE8\x76\xBB\x58\x5E\x5E\z
          \xEE\x1A\x63\xFE\x61\xAD\xFD\x9D\xD6\xFA\x4F\x57\xAE\x5C\xE9\xEC\z
          \xF5\xFE\x51\x00\xE6\xE7\xE7\xF7\x0D\x00\x60\x70\x34\xB2\x2C\x83\z
          \x94\x12\xAB\xAB\xAB\x58\x5D\x5D\xED\x74\xBB\xDD\x29\x22\xDA\x11\z
          \xA4\xDF\x70\x7D\x4D\x44\x1F\x4A\x29\x7F\x7E\xE9\xD2\xA5\x6E\xD8\z
          \x17\xDD\xC0\xD3\x75\x3F\xC5\x5A\x0B\x21\x04\xA6\xA7\xA7\x71\xFC\z
          \xF8\xF1\x77\xA4\x94\xC3\x80\xCB\x03\x6F\x78\xF1\xC0\x1B\x3B\x76\z
          \x55\x55\xE5\x2F\x5E\xBC\xF8\x61\xAF\xD7\xB3\x00\xDE\x0B\xF7\x4D\z
          \x02\x70\x10\xEF\x08\x7B\x05\x7C\x96\x65\x38\x75\xEA\xD4\xE4\xF3\z
          \xE7\xCF\x7F\x84\x36\x00\x38\xE7\xF6\x9D\x01\x7B\x29\xCE\x39\xE4\z
          \x79\x0E\x22\xCA\x79\x5F\x14\x00\xAD\x35\xB4\xD6\x7B\xAF\xD9\xD7\z
          \x40\xA2\x00\xF4\xFB\x7D\x54\x55\xB5\xDF\xBA\xEC\xA9\xA4\x6A\x1A\z
          \x71\xE7\xCE\x9D\xC9\xD9\xD9\xD9\xF7\x9D\x73\x3F\x06\xB0\x83\x22\z
          \x87\x54\xB4\x94\xF2\xB7\x65\x59\xFE\x52\xCD\xCE\xCE\xBE\x3F\x33\z
          \x33\xF3\xEE\xD9\xB3\x67\x73\xA5\x76\x12\x22\xF5\x2E\x40\x44\xC3\z
          \x28\x1C\x8E\xE1\xED\xA9\x4F\x1E\x63\xA4\x94\xAD\xE7\x8E\xD2\x81\z
          \xEB\xC9\xC5\x18\x93\x3F\x79\xF2\xE4\xDD\xF5\xF5\x75\x88\xFB\xF7\z
          \xEF\x97\x17\x2E\x5C\x28\x94\x52\x49\x9A\x84\x1B\x35\x19\x1A\x6B\z
          \x77\xCE\x25\xC7\xC5\xC0\xE6\x63\x63\xC0\xF8\xB1\x29\x00\x46\x81\z
          \x92\x65\x19\x8C\x31\x78\xFC\xF8\x71\xA5\x88\x48\x48\x29\x87\x85\z
          \x4F\x6C\x31\xAE\x70\xEC\xE5\x27\xF5\x39\xCA\xE8\xA6\x7D\xC6\x59\z
          \xB3\xCD\x5E\x7E\x8C\x31\xC6\x03\x2B\xA4\x94\xB2\x6C\x5A\x24\xBC\z
          \x62\x00\xA5\xDA\x9B\x84\x17\x33\x61\xA1\xC3\x95\x8D\xCD\x6D\x32\z
          \x9E\x7B\x3F\x65\x9B\x73\x0E\x52\xCA\x52\x11\x51\x69\xAD\x3D\x1E\z
          \x2E\x9E\xF2\x68\xDB\x36\xAE\x08\x57\xC6\x1F\x0B\x6E\x30\x37\xB4\z
          \xC9\xB8\xD8\x9E\xFC\x3E\xC5\x08\x1F\x7F\x88\xA8\x94\x42\x88\x7E\z
          \xD0\x10\xF5\x78\xCC\xD0\x18\x0B\x52\x06\xF9\x7B\xFE\x3D\x42\x4C\z
          \x78\x89\x1B\x5B\x3F\xC6\xC8\x14\x10\x29\xBB\x6A\x27\xF4\x15\x11\z
          \x6D\x1A\x63\x90\xE7\xF9\x8E\x4D\x9A\x24\xA5\x00\x0F\x52\x6D\xCE\z
          \x7F\x6A\xDF\xB6\xC0\xC6\xAA\xD6\xD8\xDC\x90\x79\xF5\xEB\xFE\xA6\z
          \x14\x42\xF4\x52\x0C\x18\xA5\x00\x80\xA4\xB7\x9A\x8E\xD1\x28\x49\z
          \x8D\x1D\x05\x68\x8A\x29\xB1\x23\x51\x83\xD1\x53\x00\x36\x9C\x73\z
          \x20\xA2\x21\x42\xB1\xB3\x13\xD2\x96\x9F\x61\x0E\x42\xD8\x9E\x0A\z
          \x4A\x4D\x31\x80\x33\x2A\x66\x58\x53\x5A\x8E\x3D\xFB\x94\x4C\x34\z
          \x48\xAD\xB5\xD3\x37\x24\x11\x75\xAD\xB5\x61\x60\xD8\x46\xA9\xD8\z
          \xD9\xE2\xCF\xA9\x17\x27\xBF\x21\x37\x30\x9C\xCF\xD7\xE5\x86\xC5\z
          \x74\x19\x75\x1F\xD3\x8B\xB7\xD7\x36\x77\x15\x11\x75\x7C\x01\x14\z
          \x7A\x36\xF4\x5A\xAC\x9D\x23\x1D\x8B\xEC\xA1\x72\xB1\xEA\x2F\x26\z
          \x29\xEF\x72\x43\xF8\x18\xBE\x7E\x38\x86\xCF\x0F\xEA\x9E\x8E\x72\z
          \xCE\x75\xB4\xD6\xD1\xB3\x12\x52\xB8\x89\xC6\x29\xC3\x46\x45\xF3\z
          \x26\x10\x52\x6B\x78\xE1\x80\x8F\xC3\x14\x22\x82\x31\x06\xCE\xB9\z
          \x8E\x02\xB0\x66\xAD\xDD\x66\x64\x58\xBE\xC6\x0C\xF7\x8A\xF1\x98\z
          \x91\xF2\x48\xCC\x5B\xE1\x7A\xA9\x2A\x30\x34\xB4\x29\xF8\xA6\x80\z
          \x6D\x62\x44\xCD\xFA\x35\x45\x44\xEB\x3E\x06\x84\x81\xB0\xC9\xE3\z
          \x61\x5F\xA8\x64\x28\x4D\xDE\x6E\x62\x4C\x6C\x8D\x14\x30\x7E\x0E\z
          \x77\x14\x9F\xC3\xD7\xF1\x31\x80\x88\xD6\x95\x73\x6E\xC3\x18\x63\z
          \x01\x64\xFC\xAC\xF3\x45\x43\x45\x53\xD1\x36\x66\x4C\xCC\x90\x98\z
          \xB1\xA9\x0C\x91\x02\x21\x76\xBE\x53\xC6\x87\xCF\xF5\xCB\x90\x75\z
          \xCE\x6D\x28\x22\xDA\xB4\xD6\x1A\x6B\x6D\x16\x53\x22\x95\x8E\x52\z
          \x68\xA7\xE8\x3C\x0E\x43\x9A\x3C\x9F\xD2\x27\x66\x68\xEA\xD9\x5A\z
          \x0B\x6B\xAD\x21\xA2\x4D\x25\x84\xE8\x1A\x63\x6C\x48\xFF\x54\x54\z
          \xE7\xC7\x82\x57\x7D\xB1\x71\x4D\x06\x72\x69\x2A\xAF\x9B\xB2\x43\z
          \xAA\x8F\x1F\x0F\x7F\x5F\x67\x01\x2B\x84\xE8\x2A\x22\xDA\x74\xCE\z
          \x39\x9E\x93\x63\x41\x8E\x2B\x16\x82\x15\x02\xC1\xDB\xFC\xBC\x51\z
          \x47\xA0\x09\x08\x9E\xE6\x78\x70\x8C\xC5\x15\x1F\xD7\x62\x29\x92\z
          \x88\x6C\xC8\x00\xE7\x19\xC0\x95\xE6\x4A\xC4\x36\x49\x29\xEC\x9F\z
          \x53\xF3\x42\x19\x15\x33\x62\xF9\x3F\x95\x21\x62\xF3\xB8\x6E\x5A\z
          \x6B\x12\x42\x74\x95\x73\x6E\xD3\x5A\x4B\x61\x35\x18\x2A\xC4\x4B\z
          \xDE\xF0\x3E\x75\x56\x63\xA5\x6C\xDB\x1A\x80\xEF\x35\xAA\x8E\x48\z
          \xE9\x10\xA3\x7E\xA8\x97\xB5\x96\x9C\x73\x43\x06\x20\xC5\x00\x4F\z
          \xF3\x70\x13\x1E\x23\x78\x2C\x08\xBD\xCE\xD7\x6C\x2B\x29\x36\xA6\z
          \x8C\x4F\x31\x81\xD7\x34\x7E\xAC\x31\x06\x43\x06\x10\x91\x18\x87\z
          \x01\xBC\x4E\xE0\x1E\xE7\xF3\x9A\x8E\x50\x4A\xB8\x51\xA9\x00\xD7\z
          \x66\x2C\x6F\x03\x00\xE7\x9C\x70\xCE\x6D\x2A\xA5\xD4\x6A\x55\x55\z
          \x19\x6D\x55\x47\x49\xE3\x63\x86\x73\x69\x32\xB2\x2D\x00\x6D\x52\z
          \x64\xAC\x8D\x53\x9E\x8F\x09\x19\x6D\x8C\xC9\x84\x10\xFF\x53\x00\z
          \x5E\x5A\x6B\x27\x3D\x03\x52\xDE\xE4\x19\x21\x16\xE9\xC3\xBE\x36\z
          \xB5\xC1\x38\x40\xB4\x65\x43\xEA\x4D\xD6\x8B\xEF\x37\xC6\x4C\x29\z
          \xA5\xBE\x10\x44\x84\x7B\xF7\xEE\x6D\x9C\x39\x73\x66\x3A\xA6\x74\z
          \x68\x14\xF7\x60\x2A\x40\x8E\xDB\x96\x32\xBA\xA9\x2D\x6C\x1F\x95\z
          \x05\x62\x63\x96\x97\x97\x37\xAE\x5D\xBB\xF6\x8E\xAA\x95\x7A\xAD\z
          \xB5\x9E\xF6\x3F\x5D\xE1\x8A\xC6\x3C\xC8\x99\x32\xEA\x4B\x12\x1E\z
          \x14\x53\x92\x62\x4B\xDB\x6C\x10\x3E\xA7\xE6\xD4\x7F\x8A\xFF\x12\z
          \xD8\xFA\xDB\xE0\x4B\xAD\xF5\xB7\xEA\xBF\xA0\x6E\x53\x24\xE6\xF5\z
          \x51\x9E\x1D\x37\xE2\x37\x49\x18\x73\xDE\x24\x25\xC6\x6A\x80\xFA\z
          \xBB\x80\x97\x40\x0D\x80\x73\xEE\x73\xAD\xF5\x05\xA5\x54\x34\x6D\z
          \xA5\xCE\x78\x9B\x1A\x81\xF7\x8D\x23\x6D\x83\x61\x2A\x0B\xC4\x80\z
          \x90\x52\x42\x6B\x0D\xE7\xDC\xE7\xC0\x16\x03\xFE\x5D\x7F\x41\x10\z
          \xA5\x68\x53\xFA\x0B\xC7\xC4\xAA\xBE\xAF\xCA\x86\x18\xB5\x39\xC0\z
          \x6D\xD2\x61\x28\x35\x03\x9E\x01\x35\x00\x44\xF4\x1F\x6B\x6D\x49\z
          \x44\x13\x6D\xCE\x57\x53\xFE\x6F\xBA\x6F\x9B\x05\x52\x73\x62\xF7\z
          \x6D\x0C\xE6\x62\xAD\x2D\x39\x03\x56\xAA\xAA\x2A\x89\x68\xE2\x4D\z
          \x7F\x19\xD2\x74\x04\x78\x7F\x5B\x49\x05\x5D\xDE\x37\x8E\x08\x21\z
          \x50\x55\x55\x09\x60\x05\xD8\x62\xC0\x0B\x63\x0C\x85\xE5\xF0\x6E\z
          \xCB\xB8\x00\xBC\xA9\x81\xA3\x44\x4A\x09\x6B\x2D\x09\x21\xFE\x0B\z
          \xD4\x00\x08\x21\xFE\x6E\x8C\x39\xE6\x2B\xC1\xBD\xD8\x7C\xAF\x0C\z
          \x1A\x47\x84\x10\xB0\xD6\x42\x6B\x3D\xD5\xEB\xF5\x3E\x03\xB0\xF5\z
          \x3B\xC1\xBB\x77\xEF\xFE\x6B\x66\x66\xE6\x5C\x9E\xE7\x87\xEA\x07\z
          \x52\xA1\xF8\x0C\xD0\xE9\x74\xFE\x79\xFD\xFA\xF5\x05\x60\xFB\x6F\z
          \x84\xFE\x5C\x55\xD5\xB7\xF3\x3C\xCF\xBE\x0E\xDE\xDA\x2B\xA9\xAA\z
          \xCA\x12\xD1\x47\xFE\x59\x02\x80\x10\x42\x54\x55\xF5\x97\x7E\xBF\z
          \xBF\xE9\x53\xE1\x61\xBD\xCA\xB2\xDC\x30\xC6\x7C\x2C\xEA\xA0\xA4\z
          \xEA\x1B\xF1\xF4\xE9\xD3\xBF\xCE\xCF\xCF\x2B\xAD\x35\xB2\x2C\x3B\z
          \x74\xC7\xC0\xD3\xDF\x5A\x9B\x2F\x2D\x2D\xFD\x0D\x03\xBF\x43\x00\z
          \x10\x00\x32\x00\xF9\xAD\x5B\xB7\xBE\x3F\x37\x37\xF7\x87\x63\xC7\z
          \x8E\x15\x45\x51\x0C\x7F\xD6\x3E\x2A\xC7\x37\xB5\xB5\x99\xDB\xA6\z
          \x82\x6B\xEA\x1B\xD5\xEF\x9C\x43\x55\x55\xE8\x76\xBB\xE5\xAB\x57\z
          \xAF\x7E\x70\xF3\xE6\xCD\x3F\x02\xD0\x00\x6C\x08\x40\x01\x60\xFA\z
          \xC6\x8D\x1B\xDF\x3D\x7F\xFE\xFC\xCF\x8A\xA2\xF8\x0E\x11\xED\x5E\z
          \x51\x7F\x80\x22\x84\xA0\xB2\x2C\x3F\x5B\x5A\x5A\xFA\xD5\xED\xDB\z
          \xB7\x3F\x01\xD0\x05\x50\x81\x01\x90\x03\x98\x0A\xAE\x89\xBA\x2D\z
          \xAB\xC7\xBC\x6D\x60\x50\x7D\x59\x0C\xBC\x5D\x02\xE8\x05\x97\x06\z
          \x60\x7D\x16\x70\x00\x4C\x3D\x88\xEA\x4E\x85\x81\xF1\x12\x6F\x9F\z
          \xF1\x5E\x08\x03\xDB\x2C\x06\xF6\x69\x0C\x3C\x6F\xEA\xF6\x41\x1D\z
          \xE0\x03\x21\xB6\x0C\xF6\x5E\x7F\x9B\x8D\xF7\xE2\x41\xF0\x6C\xF0\z
          \x80\x10\x11\x91\x08\x5E\x2A\xBC\xA1\x21\xDD\xDF\x76\xE3\xBD\x50\z
          \xF0\x49\xC0\xC0\x7A\x00\x3B\xFF\x63\x04\xD8\x06\xC6\xA1\x12\x8A\z
          \x18\x1B\x05\xE0\x28\xC9\x91\xFF\xCF\xD1\x23\x0F\xC0\xFF\x01\xBE\z
          \xEE\x47\xB9\x2A\xEC\xBB\x58\x00\x00\x00\x00\x49\x45\x4E\x44\xAE\z
          \x42\x60\x82"    )  
  
    end
  -------------------------------------------------------------------------------- 
  function DATA:func_def_ImGui_Overrides() 
    -------------------------------------------------------------------------------- 
    self.ImGui.Custom_HelpMarker =
    function(desc, tooltip_code, do_not_show_question_sign)
      if do_not_show_question_sign ~= true then ImGui.TextDisabled(ctx, '(?)') end
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
    self.ImGui.Custom_Knob = 
    function(ctx, str_id, size_wIn, size_hIn, data)
      if not data then return end
      if ImGui.BeginChild( ctx, str_id, size_wIn, size_hIn, reaper.ImGui_ChildFlags_None(), reaper.ImGui_WindowFlags_None() ) then
        ImGui.PushFont(ctx,self.font,self.var.UI_linear.font_sz_knobname)
        local x,y = ImGui.GetCursorScreenPos(ctx)
        local xav,yav = ImGui.GetContentRegionAvail(ctx)
        local nameH = math.floor(yav * 0.25)
        local valueH = 20
        local knobH = math.floor((yav - valueH-nameH)*1.3)
        
        
        -- background name
          local col_rgba = self.var.UI_colors.knobnameBg
          if data.custom_knobnameBg then col_rgba = (data.custom_knobnameBg<<8)|0xFF end
          ImGui.DrawList_AddRectFilled( self.draw.draw_list, x+1, y, x+xav-1, y+nameH, col_rgba, 3, reaper.ImGui_DrawFlags_None()|reaper.ImGui_DrawFlags_RoundCornersTop() )
        -- background
          local col_rgba = self.var.UI_colors.knobBg
          ImGui.DrawList_AddRectFilled( self.draw.draw_list, x, y+nameH, x+xav, y+yav, col_rgba, 3, reaper.ImGui_DrawFlags_None()|reaper.ImGui_DrawFlags_RoundCornersBottom() ) 
        -- background name
          local col_rgba = self.var.UI_colors.knobnameBg
          --ImGui.DrawList_AddRectFilled( self.draw.draw_list, x, y+yav - valueH, x+xav, y+yav, col_rgba, 3, reaper.ImGui_DrawFlags_None()|reaper.ImGui_DrawFlags_RoundCornersBottom() )           
        -- frame
          ImGui.DrawList_AddRect( self.draw.draw_list, x, y, x+xav, y+yav, 0x0000006F, 3, reaper.ImGui_DrawFlags_None(),1 ) 
        -- name 
          self.ImGui.Custom_InvisibleButton(ctx,str_id..'_name', -1,nameH) 
          if reaper.ImGui_IsItemClicked(ctx) and data.f_atclick_name then data.f_atclick_name() end
        -- filled arc
          local center_x = x + xav/2
          local center_y = y + nameH + knobH /2
          local radius = math.floor(math.min(xav, knobH )/2)
          local radius_draw = math.floor(0.8 * radius)
          local ang_min = -220
          local ang_max = 40
          ImGui.DrawList_PathArcTo(self.draw.draw_list, center_x, center_y , radius_draw, math.rad(ang_min),math.rad(ang_max))
          ImGui.DrawList_PathStroke(self.draw.draw_list, 0xF0F0F02F,  ImGui.DrawFlags_None, 2) 
        -- value arc
          local val_norm = data.value_normalized or 0
          local ang_val
          if not disabled == true then 
            -- value
            local radius_draw2 = radius_draw
            local radius_draw3 = radius_draw-6
            if centered ~= true then 
              val_norm = self.utils.lim(val_norm)
              ang_val = ang_min + math.floor((ang_max - ang_min)*val_norm)
              -- back arc
              ImGui.DrawList_PathArcTo(self.draw.draw_list, center_x, center_y , radius_draw, math.rad(ang_min),math.rad(ang_val+1))
              ImGui.DrawList_PathLineTo(self.draw.draw_list, center_x + radius_draw3 * math.cos(math.rad(ang_val)), center_y  + radius_draw3 * math.sin(math.rad(ang_val)))
              ImGui.DrawList_PathStroke(self.draw.draw_list, self.var.UI_colors.knob_handle,  ImGui.DrawFlags_None, 2)
             else
              val_norm = self.utils.lim(val_norm,-1,1)
              ang_val = ang_min + math.floor((ang_max - ang_min)*val_norm)
              -- right arc
              if norm_val > 0.5 then 
                ImGui.DrawList_PathArcTo(self.draw.draw_list, center_x, center_y, radius_draw, math.rad(-90),math.rad(ang_val+1))
                ImGui.DrawList_PathLineTo(self.draw.draw_list, center_x + radius_draw3 * math.cos(math.rad(ang_val)), center_y  + radius_draw3 * math.sin(math.rad(ang_val+1)))
                ImGui.DrawList_PathStroke(self.draw.draw_list, self.var.UI_colors.knob_handle,  ImGui.DrawFlags_None, 2)
               else
                ImGui.DrawList_PathLineTo(self.draw.draw_list, center_x + radius_draw3 * math.cos(math.rad(ang_val)), center_y  + radius_draw3 * math.sin(math.rad(ang_val+1)))
                ImGui.DrawList_PathArcTo(self.draw.draw_list, center_x, center_y, radius_draw, math.rad(ang_val+1), math.rad(-90)) 
                ImGui.DrawList_PathStroke(self.draw.draw_list, self.var.UI_colors.knob_handle,  ImGui.DrawFlags_None, 2)
              end
            end
          end 
        -- value readout
          local value_formatted = data.value_formatted 
          local txtw,txth = ImGui_CalcTextSize(ctx,value_formatted)
          ImGui.SetCursorScreenPos(ctx,x+(xav-txtw)*0.5,y+yav-valueH+2) 
          ImGui.Text(ctx,value_formatted)
          if ImGui.IsMouseDoubleClicked( ctx, ImGui.MouseButton_Left )and ImGui.IsItemHovered( ctx, ImGui.HoveredFlags_None )  then if data.f_atdc_value then data.f_atdc_value() end end
          if data.f_value_popup then data.f_value_popup() end 
          
        -- workarea
          ImGui.SetCursorScreenPos(ctx,x+1,y+nameH) 
          self.ImGui.Custom_InvisibleButton(ctx,'##click area'..str_id, -1,yav -valueH-nameH ) -- ImGui.Button
          -- doubleclick
          if ImGui_IsMouseDoubleClicked( ctx, ImGui.MouseButton_Left ) and ImGui.IsItemHovered( ctx, ImGui.HoveredFlags_None ) then if data.f_atdc_knob then data.f_atdc_knob() end end
          -- click
          if reaper.ImGui_IsItemClicked(ctx) and not ImGui.IsMouseDoubleClicked( ctx, ImGui.MouseButton_Left ) then if data.f_atclick_knob then data.f_atclick_knob() end end 
          -- drag
          if  ImGui.IsItemActive( ctx ) then
            local x, y = ImGui.GetMouseDragDelta( ctx )
            local dx, dy = ImGui.GetMouseDelta( ctx )
            if dy~=0 then
              if data.f_atdrag_knob then data.f_atdrag_knob(y) end
            end
          end
          
        ImGui.PopFont(ctx) 
        ImGui.EndChild( ctx )
      end 
      
    end
    -------------------------------------------------------------------------------- 
    self.ImGui.Custom_ImageButton = 
    function(ctx, str_id, size_wIn, size_hIn, imagekey, tint_col_rgbaIn)
      local ret = ImGui_Button(ctx, str_id, size_wIn, size_hIn)
      if imagekey and self.draw.images[imagekey] and ImGui_ValidatePtr( self.draw.images[imagekey], 'ImGui_Image*' ) then
        local p_min_x, p_min_y = ImGui.GetItemRectMin(ctx)
        local p_max_x, p_max_y = ImGui.GetItemRectMax(ctx)
        local wsz, hsz = ImGui.GetItemRectSize(ctx)
        local w, h = ImGui.Image_GetSize( self.draw.images[imagekey] )
        local scale = ( math.min(wsz, hsz)-self.var.UI_linear.spacingX) /  math.min(w,h) 
        local xpos = p_min_x +0.5*( wsz-w*scale) 
        local ypos = p_min_y +0.5*( hsz-h*scale) 
        local uv_min_xIn, uv_min_yIn, uv_max_xIn, uv_max_yIn = nil,nil,nil,nil
        ImGui.DrawList_AddImage( self.draw.draw_list, self.draw.images[imagekey], xpos, ypos,  xpos+w*scale,  ypos+h*scale, uv_min_xIn, uv_min_yIn, uv_max_xIn, uv_max_yIn, tint_col_rgbaIn ) 
      end
      return ret
    end
    --------------------------------------------------------------------------------     
    self.ImGui.Custom_InvisibleButton = 
    function(ctx,txt,w,h,color,txtcol)
      if not color then 
        ImGui.PushStyleColor(ctx, ImGui.Col_Button,0)
        ImGui.PushStyleColor(ctx, ImGui.Col_ButtonActive,0)
        ImGui.PushStyleColor(ctx, ImGui.Col_ButtonHovered,0)
       else
        ImGui.PushStyleColor(ctx, ImGui.Col_Button,color|0x70)
        ImGui.PushStyleColor(ctx, ImGui.Col_ButtonActive,color|0xFF)
        ImGui.PushStyleColor(ctx, ImGui.Col_ButtonHovered,color|0xCC)
      end
      if txtcol then ImGui.PushStyleColor(ctx, ImGui.Col_Text,txtcol) end
      local ret = ImGui.Button(ctx,txt,w,h)
      ImGui.PopStyleColor(ctx, 3)
      if txtcol then ImGui.PopStyleColor(ctx, 1) end
      return ret
    end
    
  end
  -------------------------------------------------------------------------------- 
  function DATA:func_def_UI_draw_popups()
    self.draw.popups.all = 
    function()
      if self.process.popup_trigger then 
        ImGui.OpenPopup( ctx, self.process.popup_trigger )
        self.process.popup_trigger = nil
      end
      if ImGui.BeginPopup( ctx, 'macro_context' ) then
        local macroID = self.var.rack.var.LASTACTIVEMACRO
        self.draw.popups.macro_knob_context(macroID)
        ImGui.EndPopup( ctx )
      end
    end
    --------------------------------------------------------------------------------  
    self.draw.popups.macro_knob_context = 
    function(macroID)
      if not macroID then return end
      ImGui.SeparatorText(ctx, 'Macro '..macroID)
      
      -- name
      local custom_name = ''
      if self.var.rack.macro.extstate and self.var.rack.macro.extstate[macroID] and self.var.rack.macro.extstate[macroID].custom_name then custom_name = self.var.rack.macro.extstate[macroID].custom_name end
      local retval, buf = ImGui.InputText( ctx, 'Macro name', custom_name, ImGui.InputTextFlags_None )--ImGui.InputTextFlags_EnterReturnsTrue
      if retval then 
        if not self.var.rack.macro.extstate then self.var.rack.macro.extstate = {} end
        if not self.var.rack.macro.extstate[macroID] then self.var.rack.macro.extstate[macroID] = {} end
        self.var.rack.macro.extstate[macroID].custom_name = buf
        
      end
      if reaper.ImGui_IsItemDeactivatedAfterEdit(ctx) then self.process.rack.macro.set.extstate_to_parent() end
      
      -- col rgb
      local col_rgb = 0
      if self.var.rack.macro.extstate and self.var.rack.macro.extstate[macroID] and self.var.rack.macro.extstate[macroID].col_rgb then col_rgb = self.var.rack.macro.extstate[macroID].col_rgb end 
      local retval, col_rgb = ImGui_ColorEdit3( ctx, 'Macro '..macroID..' color', col_rgb, ImGui.ColorEditFlags_None|ImGui.ColorEditFlags_NoInputs|ImGui.ColorEditFlags_NoAlpha )
      if retval then
        if not self.var.rack.macro.extstate then self.var.rack.macro.extstate = {} end
        if not self.var.rack.macro.extstate[macroID] then self.var.rack.macro.extstate[macroID] = {} end
        self.var.rack.macro.extstate[macroID].col_rgb = col_rgb
      end
      if reaper.ImGui_IsItemDeactivatedAfterEdit(ctx) then self.process.rack.macro.set.extstate_to_parent() end
      
      ImGui.SeparatorText(ctx, 'Parameter links')
      -- Add last touched parameter
      if ImGui.Button(ctx,'Add last touched parameter',-1) then 
        Undo_BeginBlock2(-1 )
        self.process.rack.macro.add_link(macroID)
        Undo_EndBlock2( -1 , 'RS5k manager - Macro - add link', 0xFFFFFFFF )
      end
      
      --Clear all links
      if ImGui.Button(ctx,'Clear all links',-1) then 
        Undo_BeginBlock2(-1 )
        self.process.rack.macro.clear_links(macroID)
        Undo_EndBlock2(-1 , 'RS5k manager - Macro - clear links', 0xFFFFFFFF )
      end 
      
      -- Learn
      if ImGui.Button(ctx,'Learn',-1) then  
        self.process.rack.macro.learn(macroID)
      end
      
      
    end
    
    
    
  end
  -------------------------------------------------------------------------------- 
  function DATA:func_def_UI()
    self.draw.init =  
    function() 
      ctx = ImGui.CreateContext(self.var.UI_name) 
      self.draw.font_ptr = ImGui.CreateFont(self.var.ext.UI_font.current) 
      ImGui.Attach(ctx, self.draw.font_ptr) 
      for imgptr in pairs(self.draw.images) do ImGui.Attach(ctx, self.draw.images[imgptr])  end
    end
    self.draw.reinit_context_at_loss = function() if not reaper.ImGui_ValidatePtr( ctx, 'ImGui_Context*') then self.draw.init() end end
    --------------------------------------------------------------------------
    self.draw.all =  
    function()
      self.draw.styledef.push()
      local window_flags = ImGui.WindowFlags_None
      window_flags = window_flags | ImGui.WindowFlags_NoTitleBar
      window_flags = window_flags | ImGui.WindowFlags_NoScrollbar
      window_flags = window_flags | ImGui.WindowFlags_NoCollapse
      window_flags = window_flags | ImGui.WindowFlags_NoNav
      window_flags = window_flags | ImGui.WindowFlags_NoScrollWithMouse 
      
      local visible, open = ImGui.Begin(ctx, 'RS5k Manager', false, window_flags)
      if visible then
        self.draw.draw_list = ImGui.GetWindowDrawList( ctx )  
        local yoffs = ImGui.GetCursorPosY(ctx)  
        self.draw.calculate_dynamic_var() 
        self.draw.shortcuts()  
        self.draw.tabsL.all() 
        ImGui.SameLine(ctx) ImGui.SetCursorPosY(ctx,yoffs)  self.draw.tabsR.all()    
        ImGui.Dummy(ctx, 0,0) 
        self.draw.popups.all() 
        
        if self.process.opensettings_trigger then ImGui.OpenPopup( ctx, 'settings_popup', reaper.ImGui_PopupFlags_None() ) self.process.opensettings_trigger = false end self.draw.settings.all()  
        ImGui.End(ctx)
      end
      self.draw.styledef.pop() 
    end
    --------------------------------------------------------------------------  
    self.draw.styledef.push =
    function()
      -- font 
        ImGui.PushFont(ctx, self.draw.font_ptr, self.var.UI_linear.font_sz_small) 
      -- rounding
        ImGui.PushStyleVar(ctx, ImGui.StyleVar_FrameRounding,self.var.UI_linear.round_corners)   
        ImGui.PushStyleVar(ctx, ImGui.StyleVar_GrabRounding,self.var.UI_linear.round_corners)  
        ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowRounding,self.var.UI_linear.round_corners)  
        ImGui.PushStyleVar(ctx, ImGui.StyleVar_ChildRounding,self.var.UI_linear.round_corners)  
        ImGui.PushStyleVar(ctx, ImGui.StyleVar_PopupRounding,self.var.UI_linear.round_corners)  
        ImGui.PushStyleVar(ctx, ImGui.StyleVar_ScrollbarRounding,self.var.UI_linear.round_corners)  
        ImGui.PushStyleVar(ctx, ImGui.StyleVar_TabRounding,self.var.UI_linear.round_corners)   
      -- Borders
        ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowBorderSize,0)  
        ImGui.PushStyleVar(ctx, ImGui.StyleVar_FrameBorderSize,0) 
      -- spacing
        ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowPadding,self.var.UI_linear.spacingX,self.var.UI_linear.spacingY)
        ImGui.PushStyleVar(ctx, ImGui.StyleVar_FramePadding,self.var.UI_linear.spacingX*2,self.var.UI_linear.spacingY) 
        ImGui.PushStyleVar(ctx, ImGui.StyleVar_CellPadding,self.var.UI_linear.spacingX, self.var.UI_linear.spacingY) 
        ImGui.PushStyleVar(ctx, ImGui.StyleVar_ItemSpacing,self.var.UI_linear.spacingX, self.var.UI_linear.spacingY)
        ImGui.PushStyleVar(ctx, ImGui.StyleVar_ItemInnerSpacing,4,0)
        ImGui.PushStyleVar(ctx, ImGui.StyleVar_IndentSpacing,20)
        ImGui.PushStyleVar(ctx, ImGui.StyleVar_ScrollbarSize,self.var.UI_linear.scrollbarW)
      -- size
        ImGui.PushStyleVar(ctx, ImGui.StyleVar_GrabMinSize,20)
        ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowMinSize,self.var.UI_linear.mainwindW_min,self.var.UI_linear.mainwindH_min)
      -- align
        ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowTitleAlign,0.5,0.5)
        ImGui.PushStyleVar(ctx, ImGui.StyleVar_ButtonTextAlign,0.5,0.5)
        ImGui.PushStyleVar(ctx, ImGui.StyleVar_SelectableTextAlign,0,0.5)
        
      -- alpha
        ImGui.PushStyleVar(ctx, ImGui.StyleVar_Alpha,1)
      -- colors 
        ImGui.PushStyleColor(ctx, ImGui.Col_DragDropTarget,   self.utils.rgb_alphadec(0xFF1F5F, 0.6))
        ImGui.PushStyleColor(ctx, ImGui.Col_Text,             self.var.UI_colors.textcol)
        ImGui.PushStyleColor(ctx, ImGui.Col_Button,           self.var.ext.UI_colRGBA_buttonBg.current|self.var.alpha_normal)
        ImGui.PushStyleColor(ctx, ImGui.Col_ButtonActive,     self.var.ext.UI_colRGBA_buttonBg.current|self.var.alpha_active)
        ImGui.PushStyleColor(ctx, ImGui.Col_ButtonHovered,    self.var.ext.UI_colRGBA_buttonBg.current|self.var.alpha_hovered)
        
        ImGui.PushStyleColor(ctx, ImGui.Col_WindowBg,         self.var.ext.UI_colRGBA_windowBg.current|self.var.alpha_active)
        
        ImGui.PushStyleColor(ctx, ImGui.Col_Tab,              self.var.ext.UI_colRGBA_maintheme.current|self.var.alpha_normal)
        ImGui.PushStyleColor(ctx, ImGui.Col_TabSelected,      self.var.ext.UI_colRGBA_maintheme.current|self.var.alpha_active)
        ImGui.PushStyleColor(ctx, ImGui.Col_TabHovered,       self.var.ext.UI_colRGBA_maintheme.current|self.var.alpha_hovered)
        
        ImGui.PushStyleColor(ctx, ImGui.Col_FrameBg,          self.var.ext.UI_colRGBA_maintheme.current|self.var.alpha_normal_alt)
        ImGui.PushStyleColor(ctx, ImGui.Col_FrameBgActive,    self.var.ext.UI_colRGBA_maintheme.current|self.var.alpha_active)
        ImGui.PushStyleColor(ctx, ImGui.Col_FrameBgHovered,   self.var.ext.UI_colRGBA_maintheme.current|self.var.alpha_hovered)
        
        ImGui.PushStyleColor(ctx, ImGui.Col_Header,          self.var.ext.UI_colRGBA_maintheme.current|self.var.alpha_normal)
        ImGui.PushStyleColor(ctx, ImGui.Col_HeaderActive,    self.var.ext.UI_colRGBA_maintheme.current|self.var.alpha_active)
        ImGui.PushStyleColor(ctx, ImGui.Col_HeaderHovered,   self.var.ext.UI_colRGBA_maintheme.current|self.var.alpha_hovered)
    end
      
    self.draw.styledef.pop =
    function()
      ImGui.PopStyleVar(ctx, 22) 
      ImGui.PopStyleColor(ctx, 15) 
      ImGui.PopFont( ctx ) 
    end 
    
    --------------------------------------------------------------------------
    self.draw.calculate_dynamic_var =   
    function()
      local ratio = 1.4
      self.var.UI_linear.dyn_xav, self.var.UI_linear.dyn_yav = ImGui.GetContentRegionAvail(ctx)
      self.var.UI_linear.dyn_rackW = math.min(self.var.UI_linear.dyn_yav*ratio,self.var.UI_linear.dyn_xav)  
      self.var.UI_linear.dyn_tabbar_W =  self.var.UI_linear.dyn_yav*ratio
    end
    -------------------------------------------------------------------------- 
    self.draw.shortcuts=
    function() 
      if self.var.ext.UI_allowshortcuts.current==0 then return end 
      if ImGui.Shortcut(ctx,  ImGui.Key_Space,ImGui.InputFlags_None) then self.process.actions.toggle_play() end
    end  
    
    --------------------------------------------------------------------------
    self.draw.peaks = 
    function(arr, x,y,w,h) 
      if not arr then return end
      local size = arr.get_alloc()
      local size_new = math.floor(size/2)
      if size_new < 0 then return end
      local peakscol =  self.var.ext.UI_colRGBA_peaks.current
      local thresh = 0.02
      local last_xpos,val1,val2 =x
      for i = 1, size_new do
        local xpos = math.floor(x + w * i/size_new )
        if xpos ~= last_xpos and xpos - last_xpos >=1 then
          val1 = arr[i]
          val2 = arr[i+size_new]
          if val1<thresh then val1 = 0 end
          if val2>thresh then val2 = 0 end
          local ypos =  math.floor(y + h/2 * (1- val1))
          local ypos2 =  math.floor(y + h/2 * (1- val2))
          ImGui_DrawList_AddRectFilled( self.draw.draw_list, last_xpos, ypos, xpos, ypos2, peakscol, 0, ImGui.DrawFlags_None )
          --ImGui.DrawList_PathLineTo( self.draw.draw_list,xpos, ypos)
          --ImGui.DrawList_PathLineTo( self.draw.draw_list,xpos+1, ypos2)
        end
        last_xpos = xpos
      end 
      --reaper.ImGui_DrawList_PathStroke( self.draw.draw_list, peakscol, ImGui.DrawFlags_None , 1 )
    end
    --------------------------------------------------------------------------
    self.draw.combo = 
    function(extkey, mapt, str_id, name, extw, func_at_execute)
      ImGui.SetNextItemWidth(ctx, extw or self.var.UI_linear.settings_itemW )
      local trig
      if ImGui.BeginCombo( ctx, name..str_id, mapt[self.var.ext[extkey].current ], ImGui.ComboFlags_None ) then--|ImGui.ComboFlags_NoArrowButton
        for key in self.utils.spairs(mapt) do  
          if ImGui.Selectable( ctx, mapt[key]..str_id..key, self.var.ext[extkey].current == key, ImGui.SelectableFlags_None) then 
            self.var.ext[extkey].current = key  
            self.process.ext.save()
            trig = true
            break
          end
        end
        ImGui.EndCombo( ctx)
      end
      if trig and func_at_execute then func_at_execute() end
    end
  end
  -----------------------------------------------------------------------------------------  
  function DATA:func_def_extstate_databasemaps()
    -- database maps ---------------------------------
    self.process.ext.db_maps.get = 
    function()
      self.var.ext.db_maps = {}
      for i = 1,8 do
        self.var.ext.db_maps[i] = {}
        local dbmapchunk_b64 = self.var.ext['CONF_database_map'..i].current
        if dbmapchunk_b64 then 
          local dbmapchunk = self.utils.base64.dec(dbmapchunk_b64) 
          local mapping = {}
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
                mapping[note] = params
              end
            end
            if line:match('DBNAME (.*)') then dbname = line:match('DBNAME (.*)') end
          end
          
          self.var.ext.db_maps[i] = {
            valid = true, 
            dbmapchunk = dbmapchunk,
            mapping=mapping, 
            dbname = dbname}
                      
        end
      end
    end
            
    self.process.ext.db_maps.set = 
    function()
      for mapID = 1, #self.var.ext.db_maps do  
        local s = 'DBNAME '..self.var.ext.db_maps[mapID].dbname..'\n'
        if not self.var.ext.db_maps[mapID].mapping then goto skipnextID end
        for note in pairs(self.var.ext.db_maps[mapID].mapping) do
          s = s..'NOTE'..note
          for param in pairs(self.var.ext.db_maps[mapID].mapping[note]) do 
            local tp =  type(self.var.ext.db_maps[mapID].mapping[note][param]) 
            if tp == 'string' or tp == 'number' then s = s ..' <'..param..'>'..self.var.ext.db_maps[mapID].mapping[note][param]..'</'..param..'>' end
          end
          s = s..'\n'
        end
        self.var.ext['CONF_database_map'..mapID].current = self.utils.base64.enc(s) 
        ::skipnextID::
      end 
      self.process.ext.save() 
    end 
     
    self.process.ext.db_maps.clear =
    function (selected_pad_only)
      self.var.ext.db_maps[self.var.ext.CONF_databasemaps_currentID.current].mapping = {}
      self.process.ext.db_maps.set()
    end
    ------------------------------------------------------------
    self.process.ext.db_maps.switchlist=
    function(dir)
      if dir > 0 then 
        self.var.ext.CONF_databasemaps_currentID.current = self.var.ext.CONF_databasemaps_currentID.current + 1 
        if self.var.ext.CONF_databasemaps_currentID.current > self.var.db_maps_allowed_cnt then self.var.ext.CONF_databasemaps_currentID.current = 1 end  
       else
        self.var.ext.CONF_databasemaps_currentID.current = self.var.ext.CONF_databasemaps_currentID.current - 1 
        if self.var.ext.CONF_databasemaps_currentID.current ==0 then self.var.ext.CONF_databasemaps_currentID.current = self.var.db_maps_allowed_cnt end 
      end
      self.process.ext.save()
    end
    ---------------------------------------------------------------------
    self.process.ext.db_maps.setflags = 
    function(note,flag)
      local layer = 1
      local is_available_to_set =
        ( note and 
          note~=-1 and 
          self.var.rack.children[note] and 
          self.var.rack.children[note].layers and 
          self.var.rack.children[note].layers[layer] ) ~= nil
      
      if is_available_to_set~=true then return end
      
      local flags = 0 
      if self.var.rack.children[note] and 
        self.var.rack.children[note].layers and 
        self.var.rack.children[note].layers[layer] and 
        self.var.rack.children[note].layers[layer].extstate and 
        self.var.rack.children[note].layers[layer].extstate.SPLLISTDB_flags then 
        flags = self.var.rack.children[note].layers[layer].extstate.SPLLISTDB_flags
      end 
      local new_flag = flags~flag
      self.var.rack.children[note].layers[layer].extstate.SPLLISTDB_flags = new_flag
      -- immediately refresh
      self.process.rack.children.ext_print_database_data(note, layer, {SPLLISTDB = new_flag}) 
      self.process.rack.children.layer.get_extstate_data(note, layer) -- 
    end
    ---------------------------------------------------------------------
    self.process.ext.db_maps.load =
    function (selected_pad_only)
      if not self.var.ext.CONF_databasemaps_currentID.current then return end 
      if not self.var.MEdatabase then return end 
      local mapID = self.var.ext.CONF_databasemaps_currentID.current
      if not (self.var.ext.db_maps[mapID] and self.var.ext.db_maps[mapID].mapping) then return end
      for note in self.utils.spairs(self.var.ext.db_maps[mapID].mapping) do 
        if not (not selected_pad_only or (selected_pad_only == true and self.var.rack.var.LASTACTIVENOTE and note == self.var.rack.var.LASTACTIVENOTE)) then goto skipnextnote end
        if (self.var.rack.children[note] and self.var.rack.children[note].device and self.var.rack.children[note].device.TYPE_DEVICE == true )then goto skipnextnote end  
        
        -- skip locked children
        if  
            self.var.rack.children[note] and
            self.var.rack.children[note].layers and
            self.var.rack.children[note].layers[1] and
            self.var.rack.children[note].layers[1].extstate and
            self.var.rack.children[note].layers[1].extstate.SPLLISTDB_flags and
            self.var.rack.children[note].layers[1].extstate.SPLLISTDB_flags&2==2 then
          goto skipnextnote
        end
        
        local dbname = self.var.ext.db_maps[mapID].mapping[note].dbname
        if not (self.var.MEdatabase[dbname] and self.var.MEdatabase[dbname].files) then goto skipnextnote end 
        local sz = #self.var.MEdatabase[dbname].files
        if sz>0 then
          local rand_fid = 1 + math.floor(math.random(sz-1))
          local fp = self.var.MEdatabase[dbname].files[rand_fid].fp
          self.process.rack.changesample.grabfromdatabase.all(note, {fp = fp, SPLLISTDB_NAME=dbname, SPLLISTDB_ID = rand_fid, SPLLISTDB = 1})
        end 
        
        ::skipnextnote::
      end 
      self.process.rack.read() 
    end
    ---------------------------------------------------------------------
  end
  -----------------------------------------------------------------------------------------  
  function DATA:func_def_extstate()
  
    -- ext state init definitions ---------------------------------
    for key in pairs(self.var.ext) do self.var.ext[key] = {default = self.var.ext[key]} end
    
    -- load global ---------------------------------
    self.process.ext.load = 
    function() 
      if not self.var.ext.ES_key.default then return end
      for key in pairs(self.var.ext) do 
        if not ((type(self.var.ext[key].default) == 'string' or type(self.var.ext[key].default) == 'number')) then  goto skipnextkey end
        local val = self.var.ext[key].default
        if HasExtState( self.var.ext.ES_key.default, key ) then val = GetExtState( self.var.ext.ES_key.default, key )  end
        self.var.ext[key].current = tonumber(val) or val 
        ::skipnextkey::
      end 
    end
    
    -- save global ---------------------------------
    self.process.ext.save = 
    function()
      if not self.var.ext.ES_key.default then return end
      for key in pairs(self.var.ext) do 
        if not (type(self.var.ext[key])=='table' and self.var.ext[key].current) then goto skipnextkey end
        local curval = self.var.ext[key].current
        if (type(curval) == 'string' or type(curval) == 'number') then SetExtState(self.var.ext.ES_key.default, key, curval, true) end 
        ::skipnextkey::
      end 
    end
      
    -- plugin_mapping ---------------------------------
    self.process.ext.plugin_mapping.get = function() self.var.ext.plugin_mapping = self.utils.table.loadstring(self.utils.base64.dec(self.var.ext.CONF_plugin_mapping_b64.current)) or {} end
    
    
    
    
    
    -- pad oveerides---------------------------------
    self.process.ext.PAD_OVERRIDES.get_loadfromstring =
    function(str,key)
      if not self.var.ext.PAD_OVERRIDES then self.var.ext.PAD_OVERRIDES = {} end
      self.var.ext.PAD_OVERRIDES[key] = {} 
      if str and str ~= '' then
        for pair in str:gmatch('[%d]+%=".-"') do
          local note, val = pair:match('([%d]+)="(.-)%"')
          if note and val and val ~= ''then 
            note = tonumber(note)
            if note then self.var.ext.PAD_OVERRIDES[key][note] = tonumber(val) or val end
          end
        end
      end
    end
        
    self.process.ext.PAD_OVERRIDES.get = 
    function() 
      local map = { -- map 4x ext state
        ['names'] = {ext='padcustomnames'},
        ['colors'] = {ext='padautocolors'}
      } 
      for key in pairs(map) do
        local extkey=map[key].ext 
        local strB64 = self.var.ext['UI_'..extkey..'B64'].current
        local str = self.utils.base64.dec(strB64) 
        self.process.ext.PAD_OVERRIDES.get_loadfromstring(str,key)
      end
    end
        
    self.process.ext.PAD_OVERRIDES.set = 
    function()
      if not self.var.ext.PAD_OVERRIDES.names then self.var.ext.PAD_OVERRIDES.names  = {}   end
      if not self.var.ext.PAD_OVERRIDES.colors then self.var.ext.PAD_OVERRIDES.colors  = {}   end
      local outstr = '' for note = 0, 127 do outstr=outstr..note..'='..'"'..(self.var.ext.PAD_OVERRIDES.names[note] or '')..'" ' end
      self.var.ext.UI_padcustomnamesB64.current = self.utils.base64.enc(outstr)
      local outstr = '' for note = 0, 127 do outstr=outstr..note..'='..'"'..(self.var.ext.PAD_OVERRIDES.colors[note] or '')..'" ' end
      self.var.ext.UI_padautocolorsB64.current = self.utils.base64.enc(outstr) 
      self.process.ext.save() 
    end
        
    self.process.ext.PAD_OVERRIDES.set_clean =
    function()
      local str=''
      self.var.ext.UI_padcustomnamesB64.current = ''
      self.process.ext.PAD_OVERRIDES.get_loadfromstring(str,'names')
      self.process.ext.save()
      
    end
        
    self.process.ext.PAD_OVERRIDES.set_clean_colors =
    function()
      local str=''
      self.var.ext.UI_padautocolorsB64.current = ''
      self.process.ext.save() 
      self.var.ext.PAD_OVERRIDES.colors = {}
    end
        
    self.process.ext.PAD_OVERRIDES.set_akaimpc = 
    function()
      local str=[[
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
                    ]]    
      self.var.ext.UI_padcustomnamesB64.current = self.utils.base64.enc(str)
      self.process.ext.PAD_OVERRIDES.get_loadfromstring(str,'names')
      self.process.ext.save() 
    end
                        
    self.process.ext.PAD_OVERRIDES.set_GeneralMIDI =   
    function()
      local str=[[
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
                    81="Open Triangle"]]
      self.var.ext.UI_padcustomnamesB64.current = self.utils.base64.enc(str)
      self.process.ext.PAD_OVERRIDES.get_loadfromstring(str,'names')
      self.process.ext.save() 
    end
    
    
  end

  -------------------------------------------------------------------------------- 
  function DATA:func_def_utils() 
    self.utils.spairs = 
        function(t, order) --http://stackoverflow.com/questions/15706270/sort-a-table-in-lua
          local keys = {}
          for k in pairs(t) do keys[#keys+1] = k end
          if order then table.sort(keys, function(a,b) return order(t, a, b) end)  else  table.sort(keys) end
          local i = 0
          return function()
                    i = i + 1
                    if keys[i] then return keys[i], t[keys[i] ] end
                 end
        end
    --------------------------------------------------------  
    self.utils.rgb_alphadec = function(colRGB, a_dec) return colRGB<<8|math.floor(a_dec*255) end
    --------------------------------------------------------
    self.utils.lim = 
    function(val, min,max) --local min,max 
      if not min or not max then min, max = 0,1 end 
      return math.max(min,  math.min(val, max) ) 
    end
    --------------------------------------------------------
    self.utils.GetSampleNameFromPath = 
    function(path) 
      local fn = path
      fn = fn:gsub('%\\','/')
      if fn then fn = fn:reverse():match('(.-)/') end
      local fn_without_extension = fn
      if fn then 
        fn_without_extension = fn:match('%.(.*)')
        if fn_without_extension then fn_without_extension = fn_without_extension:reverse() end
      end
      if fn then fn = fn:reverse() end
      return fn, fn_without_extension
    end
    --------------------------------------------------------    
    self.utils.load_libraries = 
    function() 
      local info = debug.getinfo(1,'S');  
      local script_path = info.source:match([[^@?(.*[\/])[^\/]-$]]) 
      dofile(script_path .. "mpl_RS5K_manager_functions.lua")
    end
    --------------------------------------------------------  
    self.utils.base64 = {
        dec = function (data) -- https://stackoverflow.com/questions/34618946/lua-base64-encode
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
                end,
       enc = function(data) -- https://stackoverflow.com/questions/34618946/lua-base64-encode
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
              }
    --------------------------------------------------------    
    self.utils.table.loadstring = function ( str ) -- http://lua-users.org/wiki/SaveTableToFile
      if str == '' then return end
        local ftables,err = load( str )
        if err then return _,err end
        local tables = ftables()
        for idx = 1,#tables do
           local tolinki = {}
           for i,v in pairs( tables[idx] ) do
              if type( v ) == "table" then
                 tables[idx][i] = tables[v[1] ]
              end
              if type( i ) == "table" and tables[i[1] ] then
                 table.insert( tolinki,{ i,tables[i[1] ] } )
              end
           end
           -- link indices
           for _,v in ipairs( tolinki ) do
              tables[idx][v[2] ],tables[idx][v[1] ] =  tables[idx][v[1] ],nil
           end
        end
        return tables[1]
      end
    --------------------------------------------------------
    self.utils.table.savestring= -- http://lua-users.org/wiki/SaveTableToFile
    function(  tbl )
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
               outstr = outstr..'\n'..(  charS..string.format("%q", v)..","..charE )
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
                  str = charS.."["..string.format("%q", i).."]="
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
                     outstr = outstr..'\n'..( str..string.format("%q", v)..","..charE )
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
    --------------------------------------------------------
    self.utils.reduceFXname=
      function(s)
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
    -------------------------------------------------------- 
    self.utils.GetTrackByGUID = 
      function (giv_guid, proj)
        if not (giv_guid and giv_guid:gsub('%p+','')) then return end
        for i = 1, CountTracks(proj or -1) do
          local tr = GetTrack(proj or -1,i-1)
          local retval, GUID = reaper.GetSetMediaTrackInfo_String( tr, 'GUID', '', false )
          if GUID:gsub('%p+','') == giv_guid:gsub('%p+','') then return tr end
        end
      end
    --------------------------------------------------------
    self.utils.GetFXByGUID = 
      function(GUID, tr, proj)
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
    --------------------------------------------------------
    self.utils.WDL_DB2VAL= function(x) return math.exp((x)*0.11512925464970228420089957273422) end  --https://github.com/majek/wdl/blob/master/WDL/db2val.h
    --------------------------------------------------------
    self.utils.WDL_VAL2DB= function(x) if not x or (x and x < 0.0000000298023223876953125) then return -150.0 end local v=math.log(x)*8.6858896380650365530225783783321 if v<-150.0 then return -150.0 else return v end end 
    --------------------------------------------------------
    self.utils.format_note = 
      function (note)
        local note_src= note
        local offs = 0
        if self.REAPERini and self.var.REAPERini and self.var.REAPERini.REAPER and self.var.REAPERini.REAPER.midioctoffs then offs = self.var.REAPERini.REAPER.midioctoffs-1 end 
        local val = math.floor(note)
        local oct = math.floor(note / 12) + offs
        local note = math.fmod(note,  12)
        local key_names = {'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'} 
        local out_str  
        if self.var.ext.UI_shownotenumbers_at_pads.current == 1 then
          if note and oct and key_names[note+1] then return note_src..' '..key_names[note+1]..oct-1 end
         else
          if note and oct and key_names[note+1] then return key_names[note+1]..oct-1 end
        end 
      end 
    --------------------------------------------------------
    self.utils.open_url = function (url) if GetOS():match("OSX") then os.execute('open "" '.. url) else os.execute('start "" '.. url)  end  end  
    --------------------------------------------------------
    self.utils.link = function (txt, url) local color = ImGui.GetStyleColor(ctx, ImGui.Col_CheckMark) ImGui.Button(ctx, txt) if ImGui.IsItemClicked(ctx) then self.utils.open_url(url) elseif ImGui.IsItemHovered(ctx) then ImGui.SetMouseCursor(ctx, ImGui.MouseCursor_Hand) end end  
    --------------------------------------------------------
    self.utils.action = function (s, sectionID, ME )   if sectionID == 32060 and ME then MIDIEditor_OnCommand( ME, NamedCommandLookup(s) ) else Main_OnCommand(NamedCommandLookup(s), sectionID or 0)  end end  
    --------------------------------------------------------
    self.utils.GetParentFolder = function (dir) return dir:match('(.*)[%\\/]') end
    --------------------------------------------------------
    self.utils.copy_source_to_proj_folder =
    function(filename)
      local prpath = GetProjectPathEx( 0 )
      local filename_path = self.utils.GetParentFolder(filename)
      local filename_name = self.utils.GetSampleNameFromPath(filename)
      if prpath and filename_path and filename_name then
        prpath = prpath..'/'..self.var.ext.CONF_onadd_copysubfoldname.current..'/'  
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
    ----------------------------------------------------------------------
    self.utils.getImGuiRGBAfromReaperRGB = 
    function(col_rgb)
      col_rgb = ImGui.ColorConvertNative(col_rgb)
      local col_rgba = (col_rgb << 8) | 0xFF
      if col_rgb & 0x1000000 == 0 then col_rgba = 0x5F5F5FFF end
      return col_rgba
    end
    ----------------------------------------------------------------------
    self.utils.brutforce = 
    function (find_Str, ptr, fx, param) 
      -- init check
        if not (find_Str and find_Str~= '' and tonumber(find_Str)) then return end  
      -- catch ptr
        local ptr_type
        if ValidatePtr2(-1,ptr, 'MediaTrack*') then ptr_type = 'Track' elseif ValidatePtr2(-1,ptr, 'MediaItem_Take*') then ptr_type = 'Take' end 
        if not ptr_type then return end
      -- convert det val to number
        local dest_val = find_Str:match('[%d%-%.]+') 
        if dest_val and tonumber(dest_val) then dest_val = tonumber(dest_val) end 
        if not dest_val then return end
      -- brutforce iterate
        local iterations = 100
        local min, max, mid = 0,1,0.5
        for i = 1, iterations do -- iterations
          mid = min + 0.5*(max - min) 
          _G[ptr_type..'FX_SetParamNormalized']( ptr, fx, param, mid ) 
          local _, buf = _G[ptr_type..'FX_GetFormattedParamValue']( ptr , fx, param, '' )
          local val = buf:match('[%d%-%.]+') 
          if val and tonumber(val) then val = tonumber(val) end  
          if val then 
            if val <= dest_val then 
              min = mid
             else
              max = mid
            end
          end
          --if math.abs(mid - val) < 10^-14 then break end
        end 
        return mid 
    end 
    
    ----------------------------------------------------------------------
    self.utils.brutforce = 
    function (find_Str, ptr, fx, param) 
      -- convert det val to number
        local find_Str_val = find_Str:match('[%d%-%.]+') 
        if find_Str_val and tonumber(find_Str_val) then find_Str_val = tonumber(find_Str_val) end 
        if not find_Str_val then return end
      -- init check
        local find_val =  tonumber(find_Str_val)
      
      local iterations = 500
      local mindiff = 10^-14
      local precision = 10^-10
      local min, max = 0,1
      for i = 1, iterations do -- iterations
        local param_low = self.utils.brutforce_sub.GetFormattedParamInternal(ptr , fx, param, min) 
        local param_mid = self.utils.brutforce_sub.GetFormattedParamInternal(ptr , fx, param, min + (max-min)/2) 
        local param_high = self.utils.brutforce_sub.GetFormattedParamInternal(ptr , fx, param, max)  
        if find_val <= param_low then return min  end
        if find_val == param_mid and math.abs(min-max) < mindiff then return self.utils.brutforce_sub.PreciseCheck(ptr, fx, param, find_val, min, max, precision) end
        if find_val >= param_high then return max end
        if find_val > param_low and find_val < param_mid then 
          min = min 
          max = min + (max-min)/2 
          if math.abs(min-max) < mindiff then return self.utils.brutforce_sub.PreciseCheck(ptr, fx, param, find_val, min, max, precision) end
         else
          min = min + (max-min)/2 
          max = max 
          if math.abs(min-max) < mindiff then return self.utils.brutforce_sub.PreciseCheck(ptr, fx, param, find_val, min, max, precision) end
        end
      end 
    end 
    -------------------------------------------------------  
    self.utils.brutforce_sub = {
      GetFormattedParamInternal = 
      function (ptr, fx, param, val)
        -- catch ptr
          local ptr_type
          if ValidatePtr2(-1,ptr, 'MediaTrack*') then ptr_type = 'Track' elseif ValidatePtr2(-1,ptr, 'MediaItem_Take*') then ptr_type = 'Take' end 
          if not ptr_type then return end 
        local param_n
        if val then _G[ptr_type..'FX_SetParamNormalized']( ptr, fx, param, val ) end
        local _, buf = _G[ptr_type..'FX_GetFormattedParamValue']( ptr , fx, param, '' )
        --local param_str = buf:match('%-[%d%.]+') or buf:match('[%d%.]+')
        local param_str = buf:match('[%d%a%-%.]+')
        if param_str then param_n = tonumber(param_str) end
        if not param_n and param_str:lower():match('%-inf') then param_n = - math.huge
        elseif not param_n and param_str:lower():match('inf') then param_n = math.huge end
        return param_n
      end,
      
      PreciseCheck = 
      function (tr, fx, param, find_val, min, max, precision)
        for value_precise = min, max, precision do
          local param_form = self.utils.brutforce_sub.GetFormattedParamInternal(ptr , fx, param, value_precise)  
          if find_val == param_form then  return value_precise end
        end
        return min + (max-min)/2 
      end 
    }
    self.utils.math_q = function (num)  if math.abs(num - math.floor(num)) < math.abs(num - math.ceil(num)) then return math.floor(num) else return math.ceil(num) end end
  end    
  -----------------------------------------------------------------------------------------  
  function DATA:main()  
    gmem_attach('RS5K_manager') 
    self:func_def()
    -- get ext state
    self.process.ext.load() 
    self.process.ext.plugin_mapping.get() 
    self.process.ext.db_maps.get() 
    self.process.ext.PAD_OVERRIDES.get() 
    
    -- collect static data
    self.process.REAPERini() 
    self.process.MIDIdevices() 
    -- measure load databases
      local loadtest = time_precise() 
      self.process.MEdatabase() 
      self.var.loadtime = time_precise() - loadtest 
    self.process.plugins()
    
    -- initialize rack data at first run before UI start
    self.process.rack.read()
    -- UI
    self.draw.init()
    _main_loop() 
  end 
  -------------------------------------------------------------------------------- 
  function _main_loop() 
    --DATA.temp_ignore_incomingevent = false
    DATA.process.realtime.collect() 
    DATA.process.realtime.handle()
    DATA.process.realtime.ext_actions()
    DATA.draw.reinit_context_at_loss()
    DATA.draw.all() 
    if DATA.var.firstrun_executed ~=true then DATA.process.onceafterUI() DATA.var.firstrun_executed = true end
    if DATA.temp_schedule_afterUI == true then DATA.process.at_project_state_change_afterUI() DATA.temp_schedule_afterUI = nil end
    if not DATA.trigger_close then defer(_main_loop) return end
    DATA.process.at_close()
  end
  --------------------------------------------------------------------------------  
  function msg(s) if not s then return end  if type(s) == 'boolean' then if s then s = 'true' else  s = 'false' end end ShowConsoleMsg(s..'\n') end 
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
  -----------------------------------------------------------------------------------------   
  DATA:main() 
  
  
  
  
  
  
  
  
  --[[
          
  self.realtime.collect.active_step_positions() ] ]
  
  --[[
  
  child = { 
    set =  
      function(tr, t) 
        local function __B_setextstatechild() 
        
        -- meta FX
          if t.MIDIFILT_GUID then GetSetMediaTrackInfo_String( tr, 'P_EXT:MPLRS5KMAN_CHILD_MIDIFILTGUID', t.MIDIFILT_GUID, true) end 
          if t.FX_REAEQ_GUID then GetSetMediaTrackInfo_String( tr, 'P_EXT:MPLRS5KMAN_CHILD_FX_REAEQ_GUID', t.FX_REAEQ_GUID, true) end      
          if t.FX_WS_GUID then GetSetMediaTrackInfo_String( tr, 'P_EXT:MPLRS5KMAN_CHILD_FX_WS_GUID', t.FX_WS_GUID, true) end      
          
        -- types
          if t.SET_MarkParentForChild then GetSetMediaTrackInfo_String( tr, 'P_EXT:MPLRS5KMAN_CHILD_PARENTGUID', t.SET_MarkParentForChild, true) end 
          if t.SET_MarkType_RegularChild then 
            GetSetMediaTrackInfo_String( tr, 'P_EXT:MPLRS5KMAN_TYPE_REGCHILD', 1, true)
           elseif t.SET_MarkType_Device then 
            GetSetMediaTrackInfo_String( tr, 'P_EXT:MPLRS5KMAN_TYPE_DEVICE', 1, true)
            GetSetMediaTrackInfo_String( tr, 'P_EXT:MPLRS5KMAN_TYPE_REGCHILD', '', true)
           elseif t.SET_MarkType_DeviceChild_deviceGUID then 
            GetSetMediaTrackInfo_String( tr, 'P_EXT:MPLRS5KMAN_TYPE_REGCHILD', '', true)
            GetSetMediaTrackInfo_String( tr, 'P_EXT:MPLRS5KMAN_TYPE_DEVICECHILD_PARENTDEVICEGUID', t.SET_MarkType_DeviceChild_deviceGUID, true) 
           elseif t.SET_MarkType_TYPE_DEVICE_AUTORANGE then 
            GetSetMediaTrackInfo_String( tr, 'P_EXT:MPLRS5KMAN_TYPE_DEVICE_AUTORANGE', t.SET_MarkType_TYPE_DEVICE_AUTORANGE, true)         
          end 
          
        -- rs5k manager data
          
          if t.SET_instrFXGUID then GetSetMediaTrackInfo_String( tr, 'P_EXT:MPLRS5KMAN_CHILD_INSTR_FXGUID', t.SET_instrFXGUID, true) end 
          if t.SET_isrs5k then  GetSetMediaTrackInfo_String( tr, 'P_EXT:MPLRS5KMAN_CHILD_ISRS5K', 1, true) end      
          
          if t.SPLLISTDB_ID then GetSetMediaTrackInfo_String( tr, 'P_EXT:MPLRS5KMAN_CHILD_SPLLISTDB_ID', t.SPLLISTDB_ID, true) end  
          if t.SET_SAMPLELEN then GetSetMediaTrackInfo_String( tr, 'P_EXT:MPLRS5KMAN_SAMPLELEN', t.SET_SAMPLELEN, true) end  
          if t.SET_SAMPLEBPM then GetSetMediaTrackInfo_String( tr, 'P_EXT:MPLRS5KMAN_SAMPLEBPM', t.SET_SAMPLEBPM, true) end  
          if t.SET_LUFSNORM then GetSetMediaTrackInfo_String( tr, 'P_EXT:MPLRS5KMAN_LUFSNORM', t.SET_LUFSNORM, true) end  
          if t.SET_SYSEXMOD then GetSetMediaTrackInfo_String( tr, 'P_EXT:MPLRS5KMAN_SYSEXMOD', t.SET_SYSEXMOD, true) end  
          
      end,
  },   
  ]]
  -------------------------------------------------------------------
  --[[
  function()
    local parent_track=  self.var.rack.parent.params.track
    local ret, MACROEXT_B64 = GetSetMediaTrackInfo_String ( parent_track, 'P_EXT:MPLRS5KMAN_MACROEXT_B64', 0, false)
    if not ret then return end
    self.var.rack.macro.extstate = DATA.utils.table.loadstring(DATA.utils.base64.dec(MACROEXT_B64)) or {}  
    ]] 
  --[[if DATA.parent_track.ext.PARENT_MACROEXT    then
    local outstr = table.savestring(DATA.parent_track.ext.PARENT_MACROEXT)
    GetSetMediaTrackInfo_String ( DATA.parent_track.ptr, 'P_EXT:MPLRS5KMAN_MACROEXT_B64', VF_encBase64(outstr), true)
  end ]] 
  
  
  --[[
        
        
  ]]
  
  local function __b_drop() end
  --[[ 
    
    
    DATA:DropSample_ExportToRS5kSetNoteRange(temp_t, note) 
    local SYSEXMOD = self.var.rack.children[note] and self.var.rack.children[note].SYSEXMOD == true
    if SYSEXMOD == true then 
      TrackFX_SetParamNormalized( track, instrument_pos, 3,0 ) -- note start
      TrackFX_SetParamNormalized( track, instrument_pos, 4, 1 ) -- note end
      TrackFX_SetParamNormalized( track, instrument_pos, 5, 0.5 ) -- pitch for start
      TrackFX_SetParamNormalized( track, instrument_pos, 6, 0.5 ) -- pitch for end
      TrackFX_SetNamedConfigParm( track, instrument_pos, 'MODE', 0 ) -- turn sample into freely configurable mode
    end
    
    
    
    ]]
          
        --[[
          self.process = {
              
            rack = {
                choke = {
                  --[[init = 
                    function()
                      midi_choke_Container =  TrackFX_AddByName( tr, 'Container', false, -1000 )
                      TrackFX_SetNamedConfigParm( tr, midi_choke_Container, 'renamed_name', container_name )
                      TrackFX_SetOpen( tr, midi_choke_Container, false ) 
                    end] ]
                }
              },
              
            } -- end rack
          
          }  
        end]]
        
            --[[
          self.realtime = {
            
                
              active_step_positions =
                function()
                  
                  --[[ active_step_positions --------------------------------------
                  if not DATA.seq.var.it_pos then goto skipcursteppos end
                  DATA.seq.var.active_step = 0
                  local curpos = GetCursorPositionEx(self.var.proj )
                  if GetPlayStateEx( self.var.proj  )&1==1 then curpos = GetPlayPositionEx( self.var.proj ) end
                  local beats, measures, cml, curpos_fullbeats, cdenom = TimeMap2_timeToBeats( self.var.proj, curpos )
                  if not (curpos>=DATA.seq.var.it_pos and curpos<=DATA.seq.var.it_end) then goto skipcursteppos end
                  local beats, measures, cml, patstart_fullbeats, cdenom = TimeMap2_timeToBeats(self.var.proj, DATA.seq.var.it_pos_compensated ) 
                  local pat_progress = (((curpos_fullbeats-patstart_fullbeats)/DATA.seq.var.patternsteplen)/DATA.seq.var.patternlen)%1
                  local pat_beats_com = DATA.seq.var.patternlen*DATA.seq.var.patternsteplen
                  DATA.seq.var.pat_progress = pat_progress
                  DATA.seq.var.pat_step = math.floor(pat_progress*DATA.seq.var.pattern_len)+1
                  
                  for note in pairs(DATA.seq.children) do 
                    local available_steps_per_pattern = pat_beats_com / DATA.seq.children[note].step_length
                    local activestep = math.floor(available_steps_per_pattern * pat_progress)+1
                    if DATA.seq.children[note].step_cnt < DATA.seq.var.pattern_len then 
                      activestep = activestep %DATA.seq.children[note].step_cnt
                      if activestep == 0 then activestep = step_cnt end
                    end 
                    DATA.seq.children[note].active_step = activestep
                  end 
                  ::skipcursteppos::] ]
                end,
                  
                
              
            },
        
          }
        end] ]
        
      
      
          --[[
        
        },
        },
        
        
      }]]
    
    --[[ImGui.PushStyleColor(ctx, ImGui.Col_Border,           self.var.UI_colors.border) 
    
    ImGui.PushStyleColor(ctx, ImGui.Col_CheckMark,        (self.var.ext.UI_colRGBA_maintheme.current&0xFFFFFF00)|0xF0)
    
    
    ImGui.PushStyleColor(ctx, ImGui.Col_FrameBg,          self.utils.rgb_alphadec(0x1F1F1F, 0.7))
    ImGui.PushStyleColor(ctx, ImGui.Col_FrameBgActive,    self.utils.rgb_alphadec(UI.main_col, .6))
    ImGui.PushStyleColor(ctx, ImGui.Col_FrameBgHovered,   self.utils.rgb_alphadec(UI.main_col, 0.7))
    ImGui.PushStyleColor(ctx, ImGui.Col_Header,           self.utils.rgb_alphadec(UI.main_col, 0.3) )
    ImGui.PushStyleColor(ctx, ImGui.Col_HeaderActive,     self.utils.rgb_alphadec(UI.main_col, 1) )
    ImGui.PushStyleColor(ctx, ImGui.Col_HeaderHovered,    self.utils.rgb_alphadec(UI.main_col, 0.98) )
    ImGui.PushStyleColor(ctx, ImGui.Col_PopupBg,          self.utils.rgb_alphadec(0x303030, 1) )
    ImGui.PushStyleColor(ctx, ImGui.Col_ResizeGrip,       (self.var.ext.UI_colRGBA_maintheme.current&0xFFFFFF00)|0x90 )
    ImGui.PushStyleColor(ctx, ImGui.Col_ResizeGripHovered,(self.var.ext.UI_colRGBA_maintheme.current&0xFFFFFF00)|0xF0 )
    ImGui.PushStyleColor(ctx, ImGui.Col_ResizeGripActive, (self.var.ext.UI_colRGBA_maintheme.current&0xFFFFFF00)|0xC0 )
    ImGui.PushStyleColor(ctx, ImGui.Col_SliderGrab,       (self.var.ext.UI_colRGBA_maintheme.current&0xFFFFFF00)|0x90) 
    ImGui.PushStyleColor(ctx, ImGui.Col_SliderGrabActive, (self.var.ext.UI_colRGBA_maintheme.current&0xFFFFFF00)|0xC0 )
    ImGui.PushStyleColor(ctx, ImGui.Col_Tab,              (self.var.ext.UI_colRGBA_maintheme.current&0xFFFFFF00)|0x70 )
    ImGui.PushStyleColor(ctx, ImGui.Col_TabSelected,      (self.var.ext.UI_colRGBA_maintheme.current&0xFFFFFF00)|0xD0)
    ImGui.PushStyleColor(ctx, ImGui.Col_TabHovered,       (self.var.ext.UI_colRGBA_maintheme.current&0xFFFFFF00)|0xF0 )
    
    ImGui.PushStyleColor(ctx, ImGui.Col_TitleBg,          self.utils.rgb_alphadec(UI.main_col, 0.7) )
    ImGui.PushStyleColor(ctx, ImGui.Col_TitleBgActive,    self.utils.rgb_alphadec(UI.main_col, 0.95) )
    ]]
    --[[database app
  apply =
    function(selected_pad_only)
      
        DATA:Validate_MIDIbus_AND_ParentFolder() 
        Undo_BeginBlock2(self.var.proj )
        DATA:Database_Load() 
        Undo_EndBlock2( self.var.proj , 'Load database to all rack', 0xFFFFFFFF )
      end
      
      ImGui.SameLine(ctx) if ImGui.Button(ctx, 'Load selected pad') then 
        DATA:Validate_MIDIbus_AND_ParentFolder() 
        Undo_BeginBlock2(self.var.proj )
        DATA:Database_Load(true)
        Undo_EndBlock2( self.var.proj , 'Load database to selected pad only', 0xFFFFFFFF )
    end,]]
    
    --main_col = 0x7F7F7F, -- grey
  
    
  --[[
      UI = {
        -- font
          font1sz=15,
          font2sz=14,
          font3sz=13,
          font4sz=12,
          font5sz=11,
        -- mouse
          hoverdelay = 0.8,
          hoverdelayshort = 0.5,
        -- size / offset
          
        -- colors / alpha
          textcol_a_disabled = 0.5,
          but_hovered = 0x878787,
          ,
            }
      
      -- size
      UI.settingsfixedW = 450
      UI.actionsbutW = 60
      
      UI.knob_resY = 150
      UI.sampler_peaksH = 50
      UI.sampler_peaksfullH = 30
      
      UI.adsr_rectsz = 10
      self.var.UI_linear.
      
      -- colors
      
      UI.col_red = 0xB31F0F  
      UI.padplaycol = 0x00FF00 
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
      UI.seq_maxstepcnt = 1024] ]
  
  ------------------------------------------------------------------------------ init external defaults 
  local EXT = {
  
          -- UI various
          
          
          -- settings
            
            -- rack
            
              
            
            -- midi 
             
             
            
            
            -- drop  
             
            
          --[[ rs5k on add
          
          CONF_onadd_whitekeyspriority = 0,
          
          CONF_onadd_renameinst = 0,
          CONF_onadd_renameinst_str = 'RS5k',
          
          
          -- sampler
          CONF_cropthreshold = -60, -- db
          CONF_crop_maxlen = 30,
          
          CONF_stepmode = 0,
          CONF_stepmode_transientahead = 0.01,
          CONF_stepmode_keeplen = 1, 
          
          -- UI
          
          UI_processoninit = 0,
          UI_addundototabclicks = 0,
          UI_defaulttabsflags = 1|4|8, --1=drumrack   2=device  4=sampler 8=padview 16=macro 32=database 64=midi map 128=children chain
          UIdb_maps_cur = 1,
          
          --UI_optimizedockerusage = 0,
          
          UI_colRGBA_smplrbackgr = 0xFFFFFF2F,
          
          -- other 
          CONF_trackorderflags = 0,  -- ==0 sort by date ascending, ==2 sort by date descending, ==3 sort by note ascending, ==4 sort by note descending
          CONF_autoreposition = 0, --0 off
           
          -- actions
          CONF_importselitems_removesource = 0,
          CONF_explodeMIDItochildren_note = 36,
          
          
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
          ] ]
          
         }
        
  
  DATA = {
    temp = {},
    ui = {
      draw = {},
      var = {},
    },
    ,
    MIDIdevices = {},
    MEdatabase = {},
    test = {},
    rack = {
        var = {},
        parent = {},
        midibus = {},
        children = {},
        macro = {},
        layout = {}, 
      },
    seq = {
      var = {},
      children = {},
    },      
    plugins = {}, -- installed plugins
    refresh = {
      pad_peaks = true, -- calc peaks after UI load
    }, 
    var = {},     -- variabled, static and dynamic
    process = {},
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
    } 
    
  -----------------------------------------------------------------------------------------  
  f unction DATA:func_def_process_changesample_rs5k()  
    
    
        local function __b_export5k() end 
        -- set DB
          if drop_data.set_DB then 
            self.ext.child.set(track, {
              SET_useDB = 1,
              SET_useDB_name = drop_data.set_DB})  
          end
    }
  end
    --[[
    
    
        
        --[[
        
        ---------------------------------------------------------------------  
        f unction UI.Drop_UI_interaction_pad(note) 
          
          
          -- validate is file or pad dropped
          local retval, count = ImGui.AcceptDragDropPayloadFiles( ctx, 127, ImGui.DragDropFlags_None )
          if retval then 
            DATA.upd2.refreshscroll = 1 --UI.draw_Seq() refresh
            local loop_success
            if count == 1 then loop_success, do_not_share = DATA:Auto_LoopSlice(note, count) end
            
            if do_not_share == true then return end
            
            
            -- import sample directly
            if loop_success ~= true then
            
              Undo_BeginBlock2(self.var.proj )
              for i = 1, count do 
                local retval, filename = reaper.ImGui_GetDragDropPayloadFile( ctx, i-1 )
                if not retval then return end  
                DATA:DropSample(filename, note + i-1, {layer=1})
              end 
              Undo_EndBlock2( self.var.proj , 'RS5k manager - drop samples to pads', 0xFFFFFFFF ) 
            end
              
            
           else
            local retval, payload = reaper.ImGui_AcceptDragDropPayload( ctx, 'moving_pad', '', ImGui.DragDropFlags_None )-- accept pad drop
            if retval and self.var.rack.var.LASTACTIVENOTE then 
              Undo_BeginBlock2(self.var.proj )
              local retval, types, payload, is_preview, is_delivery = reaper.ImGui_GetDragDropPayload( ctx )
              if retval and tonumber(payload)then 
                DATA:Drop_Pad(tonumber(payload),note)  
                gmem_write(1026,11|(self.var.rack.var.LASTACTIVENOTE<<8)|(note<<16))
              end  
              Undo_EndBlock2( self.var.proj , 'RS5k manager - move pad', 0xFFFFFFFF ) 
            end 
          end
        end
        
      end
    },
    ] ]
  -----------------------------------------------------------------------------------------  
  f unction DATA:func_def_process_children()         
   self.process.rack.children = {
    
      
  
      
      
    --[[
      handle_last_track_aftermove = 
        function()
          local prelastID = self.var.rack.IP_TRACKNUMBER_end
          local prelast_tr = GetTrack(self.var.proj,prelastID)
          
          local lastID = self.var.rack.IP_TRACKNUMBER_end+1
          local last_tr = GetTrack(self.var.proj,lastID)
          if last_tr then
            local prelast_trdepth = GetMediaTrackInfo_Value( prelast_tr, 'I_FOLDERDEPTH' )
            local last_trdepth = GetMediaTrackInfo_Value( last_tr, 'I_FOLDERDEPTH' )
            if last_trdepth ==0 then 
              SetMediaTrackInfo_Value( prelast_tr, 'I_FOLDERDEPTH', 0)
              SetMediaTrackInfo_Value( last_tr, 'I_FOLDERDEPTH', -1)
            end
          end
        end,
        
        
        --[[ add device if not exists and layer ~= 1
        if layer ~= 1 and is_parent_device ~= true then
          InsertTrackAtIndex( 0, false ) local device_parent = GetTrack(self.var.proj, 0) -- add new track
          local retval, deviceGUID = GetSetMediaTrackInfo_String( device_parent, 'GUID', '', false  )
          GetSetMediaTrackInfo_String( device_parent, 'P_NAME', 'Device / Note '..note, 1 )
          
          self.ext.child.set(device_parent, {
            SET_MarkParentForChild = self.var.rack.parent.params.trGUID,
            SET_MarkType_Device = true,
            SET_noteID=note,
            }) 
        end]]
        
        --[[
      
         
              
        move_track = {
          new_layer = 
            function(note, new_tr, is_device_parent, device_parentGUID)   
              if not (is_device_parent~=true and device_parentGUID)  then return end 
              local beforeTrackIdx = self.var.rack.children[note].params.IP_TRACKNUMBER +1 -- goes after parent  
              self.process.track_selection_save()
              SetOnlyTrackSelected( new_tr )
              ReorderSelectedTracks( beforeTrackIdx, 0 )--make sure parent is folder
              self.process.track_selection_restore()
              self.refresh.devicevelocityrange = note
            end, 
          
            
            new_device = 
              function(note, new_tr, is_device_parent, device_parentGUID) 
                if is_device_parent~=true then return end
                if self.var.rack.children[note].device ~= true then -- child exist / convert child regular to child device
                  SetOnlyTrackSelected( new_tr )
                  local beforeTrackIdx = self.var.rack.children[note].params.IP_TRACKNUMBER -- before child
                  ReorderSelectedTracks( beforeTrackIdx, 0 )
                  local child_tr = GetTrack(-1,self.var.rack.children[note].params.IP_TRACKNUMBER)
                  SetMediaTrackInfo_Value( new_tr, 'I_FOLDERDEPTH', 1 ) -- enclose new device
                  local I_FOLDERDEPTH = GetMediaTrackInfo_Value( child_tr, 'I_FOLDERDEPTH') -- enclose new device
                  SetMediaTrackInfo_Value( child_tr, 'I_FOLDERDEPTH', I_FOLDERDEPTH-1 ) -- enclose new device
                end
              end,
          }, 
          ] ]
        }
  end
  -----------------------------------------------------------------------------------------  
  function DATA:func_def_refresh() 
          --if self.refresh.devicevelocityrange then DATA:Auto_Device_RefreshVelocityRange(self.refresh.devicevelocityrange) self.refresh.devicevelocityrange = nil end
          
          atprojstatechange = 
            function() 
              --[[--------------------------------------------------------------------------------   
                if allow_trig_auto_stuff == true then 
                  -- auto handle stuff
                  self.process.rack.midibus.build_routing() 
                  DATA:Auto_MIDInotenames() 
                  DATA:Auto_TCPMCP() 
                end
                
                DATA.upd2.refreshpeaks = true
              end
              
            end,] ]
            
        end
        
    self.refresh.at_close = 
        function()
          
        end
        --[[
        refresh after ui in v4
        
        if DATA.upd2.seqprint then DATA:_Seq_Print(nil, DATA.upd2.seqprint_minor) DATA.upd2.seqprint=nil DATA.upd2.seqprint_minor=nil end
        if DATA.upd2.refreshpeaks then DATA:CollectData2_GetPeaks() DATA.upd2.refreshpeaks = false end
        --DATA.upd2.refreshscroll
        --[[if DATA.upd_TCP == true then  
          TrackList_AdjustWindows( false ) 
          DATA.upd_TCP = false
        end]] 
        
        
        --[[ At end 
        if UI.open and not DATA.trig_stopdefer then  else
          gmem_write(1026, 0) -- rs5k manager opened
          --DATA:Auto_StuffSysex_sub('on release') -- send keys layout to launchpad
        end] ]
  end
      
  function DATA:func_def_collect_seq() 
    self.process.seq = {
    
      init = 
        function()
          
          DATA.seq.valid = false
          local item = GetSelectedMediaItem( -1, 0 )
          if not item then return end
          local take = GetActiveTake(item)
          if not (take and TakeIsMIDI(take)) then return end
           
          DATA.seq.item = item
          DATA.seq.take = take
          
          DATA.seq.children={}
          DATA.seq.step_defaults={}
          
          DATA.seq.var = {
            swing = 0,
            length = 16,
            steplength = DATA.ext.cur.CONF_seq_steplength,
          }
          
          DATA.seq.valid = true
          
        end,
      
      itemtake_params = 
        function()
          local item = DATA.seq.item
          local take = DATA.seq.take
          local D_POSITION = GetMediaItemInfo_Value( item, 'D_POSITION' )
          local D_LENGTH = GetMediaItemInfo_Value( item, 'D_LENGTH' )
          local retval, measures, cml, D_POSITION_fullbeats, cdenom = TimeMap2_timeToBeats(-1, D_POSITION )
          local D_STARTOFFS = GetMediaItemTakeInfo_Value( take,'D_STARTOFFS' )
          local source = GetMediaItemTake_Source( take )
          local qnlen, lengthIsQN = reaper.GetMediaSourceLength( source )
          local srclen_sec = TimeMap_QNToTime_abs( -1, qnlen)
          if D_STARTOFFS < 0 then
            D_POSITION_compensated = D_POSITION - D_STARTOFFS
           elseif D_STARTOFFS > 0 then
            D_POSITION_compensated = D_STARTOFFS + (srclen_sec  - D_STARTOFFS) / D_PLAYRATE
           else
            D_POSITION_compensated = D_STARTOFFS
          end 
          local retval, measures, cml, fullbeats_pos, cdenom = reaper.TimeMap2_timeToBeats( self.var.proj, D_POSITION )
          local retval, measures, cml, fullbeats_end, cdenom = reaper.TimeMap2_timeToBeats( self.var.proj, D_POSITION +  D_LENGTH )
          local src_count =  D_LENGTH  / math.max(0.1,srclen_sec)   
          DATA.seq.itemtake_params = {
            D_POSITION = D_POSITION,
            D_POSITION_fullbeats = D_POSITION_fullbeats,
            D_POSITION_compensated = D_POSITION_compensated,
            D_LENGTH = D_LENGTH,
            D_STARTOFFS = D_STARTOFFS,
            D_PLAYRATE = GetMediaItemTakeInfo_Value( take,'D_PLAYRATE' ),
            I_GROUPID = GetMediaItemInfo_Value( item, 'I_GROUPID' ),
            D_LENGTH_beats =fullbeats_end - fullbeats_pos,
            takename = ({GetSetMediaItemTakeInfo_String( take, 'P_NAME', '', false )})[2], 
            src_len_sec = srclen_sec,
            src_count=src_count,
          }
        end,
        
        
      ext = 
        function()
          --[[DATA.seq.ext = {}
          local item = DATA.seq.item
          local take = DATA.seq.take
          
          local patdata, seq_ext
          local ret_patdata_b64, patdata_b64 = GetSetMediaItemTakeInfo_String( take, 'P_EXT:MPLRS5KMAN_PATDATA', '', false)
          local ret, MPLRS5KMAN_PATDATA_IGNOREB64 = GetSetMediaItemTakeInfo_String( take, 'P_EXT:MPLRS5KMAN_PATDATA_IGNOREB64', '', false) -- 4.43 use native b64 converter
          if (MPLRS5KMAN_PATDATA_IGNOREB64 and tonumber(MPLRS5KMAN_PATDATA_IGNOREB64) and tonumber(MPLRS5KMAN_PATDATA_IGNOREB64) == 1) then 
            patdata = patdata_b64
           else
            if ret_patdata_b64 and patdata_b64 then patdata = DATA.utils.base64.dec(patdata_b64) end
          end
          if patdata and patdata ~= '' then seq_ext = DATA.utils.table.loadstring(patdata) or {} end
          
          if seq_ext.patternsteplen then      seq_ext.steplength_override = seq_ext.patternsteplen end-- v4 patch
          if seq_ext.steplength_override then DATA.seq.ext.steplength_override = seq_ext.steplength_override end
          if seq_ext.GUID then                DATA.seq.ext.GUID_internal =  seq_ext.GUID end
          if seq_ext.step_defaults then       DATA.seq.ext.step_defaults =  seq_ext.step_defaults end
          if seq_ext.swing then               DATA.seq.ext.swing =          seq_ext.swing end] ]
        end,
        
      track_env = 
        function()
        
        
        
        end,
        
        
      all = 
        function() 
          self.process.seq.init() 
          if DATA.seq.valid ~= true then return end
          self.process.seq.itemtake_params() 
          self.process.seq.ext() 
          self.process.seq.track_env() 
        end,
        
    }
    
  end
  
            
               
              --[[
              UI.draw_tabs_settings_onsampleadd()
              UI.draw_tabs_settings_tcpmcp()
              UI.draw_tabs_settings_MIDI()
              UI.draw_tabs_settings_UI()
              UI.draw_tabs_settings_UI_custompadnames()
              UI.draw_tabs_settings_Theming()
              UI.draw_tabs_settings_AutoColor()
              UI.draw_tabs_settings_Autoslice()
              UI.draw_tabs_settings_StepSequencer() 
              --UI.draw_tabs_settings_Launchpad() 
              ]]
  --[[
  -------------------------------------------------------------------------------- 
  f unction UI.MAIN_styledefinition(open) 
      UI.anypopupopen = ImGui.IsPopupOpen( ctx, 'mainRCmenu', ImGui.PopupFlags_AnyPopup|ImGui.PopupFlags_AnyPopupLevel )
      
    -- init UI 
      
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
        UI.calc_padoverviewH = DATA.display_h- self.var.UI_linear.spacingY*3- UI.calc_itemH
        UI.calc_padoverview_cellside = UI.calc_padoverviewH/32  
        UI.calc_padoverviewW = UI.calc_padoverview_cellside * 4 + self.var.UI_linear.spacingX*2
        if UI.calc_padoverviewW < 30 or UI.calc_padoverviewW > 60 or self.var.ext.UI_drracklayout.current == 2 then UI.hide_padoverview = true end
        if self.var.ext.UI_drracklayout.current == 1 then --keys
          UI.calc_padoverview_cellside = UI.calc_padoverviewH /22
          UI.calc_padoverviewW = UI.calc_padoverview_cellside * 7 + self.var.UI_linear.spacingX*2
        end 
        if UI.hide_padoverview == true and self.var.ext.UI_drracklayout.current ~= 2 then UI.calc_padoverviewW = 0 end
        if UI.hide_padoverview == true and self.var.ext.UI_drracklayout.current == 2 then UI.calc_padoverviewW = 28 end
         
        -- rack
        local rack_max_width = 500
        local rack_min_height = 250
        UI.calc_rackX = DATA.display_x + self.var.UI_linear.spacingX + UI.calc_padoverviewW
        UI.calc_rackY = DATA.display_y + self.var.UI_linear.spacingY 
        if ImGui_IsWindowDocked( ctx ) then UI.calc_rackY = DATA.display_y + self.var.UI_linear.spacingY end
        if self.var.ext.UI_drracklayout.current == 2  then rack_max_width = 600 end --launch
        UI.calc_rackW = math.min(DATA.display_w - UI.calc_settingsW - UI.calc_padoverviewW,rack_max_width)
        UI.calc_rackH = math.max(math.floor(DATA.display_h  -self.var.UI_linear.spacingY )-1,rack_min_height)
        
        UI.calc_rack_padw = math.floor((UI.calc_rackW-self.var.UI_linear.spacingX*3) / 4)
        UI.calc_rack_padh = math.floor((UI.calc_rackH-self.var.UI_linear.spacingY*3) / 4)
        if self.var.ext.UI_drracklayout.current == 1 then --keys
          UI.calc_rack_padw = math.floor((UI.calc_rackW) / 7)-- -self.var.UI_linear.spacingX
          UI.calc_rack_padh = math.floor((UI.calc_rackH) / 4)
        end
        UI.calc_rack_padctrlW = UI.calc_rack_padw / 3 
        UI.calc_rack_padctrlH = UI.calc_rack_padh*0.3
        UI.calc_rack_padnameH = UI.calc_rack_padh-UI.calc_rack_padctrlH 
        
        
        
        
        -- settings
        UI.calc_settingsX = UI.calc_rackW + UI.calc_padoverviewW + self.var.UI_linear.spacingX*2
        UI.calc_settingsY = self.var.UI_linear.spacingY*2 + UI.calc_itemH
        
        -- small knob controls
        UI.calc_knob_w_small = math.floor((UI.calc_settingsW - self.var.UI_linear.spacingX*9) / 8) 
        UI.calc_knob_h_small = 90--math.floor((DATA.display_h  - UI.calc_itemH*3-self.var.UI_linear.spacingY*7 - UI.sampler_peaksH)/2)
        -- small macro controls
        UI.calc_macro_w = math.floor((UI.calc_settingsW - self.var.UI_linear.spacingX*7) / 4)
        UI.calc_macro_h = 65--math.floor((DATA.display_h - self.var.UI_linear.spacingY*4 - UI.calc_itemH*3) / 4)
        
        -- sampler 
        UI.calc_sampler4ctrl_W = math.floor((UI.calc_settingsW - self.var.UI_linear.spacingX*5) / 4) 
         
        
        
        -- get drawlist
        
        
        -- draw stuff
        DATA.allow_space_to_play = true
        UI.draw() 
        UI.draw_popups()  
        ImGui.Dummy(ctx,0,0)  
        
        
        
        
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
         UI.calc_seqX = DATA.display_x + self.var.UI_linear.spacingX
         UI.calc_seqY = DATA.display_y + UI.calc_itemH + self.var.UI_linear.spacingY*2
         UI.calc_seqW = DATA.display_w
         
         if UI.hide_padoverview == true then  UI.calc_seqW = UI.calc_rackW end 
         UI.calc_seq_ctrl_butW = math.floor(UI.seq_padH*0.7)
         UI.calc_seq_ctrl_butH = UI.calc_seq_ctrl_butW  
         UI.calc_seqXL_padname = (UI.calc_seq_ctrl_butW + self.var.UI_linear.spacingX)*5
         UI.calc_seqXL_steps = UI.calc_seqXL_padname +UI.seq_padnameW  + UI.seq_audiolevelW + self.var.UI_linear.spacingX 
         UI.calc_seqW_steps = DATA.display_w - UI.calc_seqXL_steps
         
         UI.calc_seqW_steps_window = UI.seq_stepW*16
         UI.calc_seqW_steps_visible = math.floor(UI.calc_seqW_steps/UI.seq_stepW)
         
         -- peaks patch (otherwise it will not draw peaks)
         UI.calc_rack_padw = UI.seq_padnameW
         
         -- get drawlist
         self.draw.draw_list = ImGui.GetWindowDrawList( ctx )
         
         
         -- draw stuff
         DATA.allow_space_to_play = true
         UI.seqdraw() 
         UI.draw_popups()  
         ImGui.Dummy(ctx,0,0)  
         ImGui.End(ctx)
       end 
     end
     
     
    
    -- shortcuts
      
      if UI.anypopupopen == true then 
        if ImGui.IsKeyPressed( ctx, ImGui.Key_Escape,false ) then DATA.trig_closepopup = true end 
       else 
        if ImGui.IsKeyPressed( ctx, ImGui.Key_Escape,false ) then return end
      end
      
        
    return open
  end
  ] ]  
  ------------------------------------------------------------------
  _main()] ]
  
  
  
      
  --[[------------------------------------------------------------------------------  init globals
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
      ] ]
      
      
      
    
    -------------------------------------------------------------------------------- INIT data
    DATA = {
            
            scheduler = {},
            
            seq_functionscall = true,
            upd = true,
            upd2 = {
              refreshpeaks = true,
            },
            
            
            version = 4, -- for ext state save
            playingnote = -1,
            playingnote_trigTS = 0,
            MIDI_inputs = {},
            MIDI_outputs = {},
            lastMIDIinputnote = {},
            var.MEdatabase = {},
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
      
    
    
    --------------------------------------------------------------------------------  
    f unction UI.transparentButton(ctx, str_id, w,h)
      ImGui.PushFont(ctx, self.font4) 
      UI.draw_setbuttonbackgtransparent()
      ImGui.Button(ctx, str_id, w,h)
      UI.Tools_unsetbuttonstyle()
      ImGui.PopFont(ctx) 
    end
  
    --------------------------------------------------------------------------------  
    f unction UI.Tools_setbuttonbackg(col)   
      ImGui.PushStyleColor(ctx, ImGui.Col_Button, col or 0 )
      ImGui.PushStyleColor(ctx, ImGui.Col_ButtonActive, col or 0 )
      ImGui.PushStyleColor(ctx, ImGui.Col_ButtonHovered, col or 0 )
    end
    --UI.Tools_setbuttonbackg()
    --UI.Tools_unsetbuttonstyle()
      --------------------------------------------------------------------------------  
    f unction UI.Tools_unsetbuttonstyle() ImGui.PopStyleColor(ctx,3) end 
    
    
    --------------------------------------------------------------------------------  
    f unction UI.draw_Seq_Step(note_t, x0,y0)  
      if not note_t then return end 
      
      local note= note_t.noteID 
      if not (DATA.seq and DATA.seq.ext and DATA.seq.ext.children and DATA.seq.ext.children[note] and DATA.seq.ext.children[note].step_cnt) then return end
      
      
      if not DATA.seq.ext.patternlen then return end
      
      f unction __f_draw_Seq_Step() end
      ImGui.SetCursorPosX(ctx, UI.calc_seqXL_steps)
      if x0 and y0 then ImGui.SetCursorPos(ctx, x0,y0) end
      
      -- loop steps
      local col_activestep = 0xE0E0E000
      local col_cell_1 = 0x5050508F
      local col_cell_2 = (EXT.UI_colRGBA_maintheme&0xFFFFFF00)|0x50
      local col_cell_inactive = 0x5050503F
      local col_step_1 = (col_activestep&0xFFFFFF00)|0x90
      local col_step_2 = (EXT.UI_colRGBA_maintheme&0xFFFFFF00)|0x9F
      
      local col_step_inactive = (col_activestep&0xFFFFFF00)|0x30
      local col_separator = 0x808080FF
      local col_playcursor = (EXT.UI_colRGBA_maintheme&0xFFFFFF00)|0xFF
      
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
          ImGui.DrawList_AddRectFilled( self.draw.drawlist, x1, y1,x2-1, y2-1, col_cell, UI.seq_steprounding, ImGui.DrawFlags_None )
        
        -- separator
          if activestep%16==1 then
            ImGui.DrawList_AddLine( self.draw.drawlist, x1, y1+1,x1, y2-2, col_separator, 1 )
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
              
              ImGui.DrawList_AddRectFilled( self.draw.drawlist, 
                x1+UI.seq_activestep_reducesz*2,
                y1+UI.seq_activestep_reducesz*2 + hstep-hstep*val,
                x1+UI.seq_activestep_reducesz*2 + wstep*width,
                y2-UI.seq_activestep_reducesz*2, 
                col_step, UI.seq_steprounding, ImGui.DrawFlags_None )
            end
          end  
          
        -- split val
          if activestep <= step_cnt and DATA.seq.ext and DATA.seq.ext.children and DATA.seq.ext.children[note] and DATA.seq.ext.children[note].steps and DATA.seq.ext.children[note].steps[activestep] and DATA.seq.ext.children[note].steps[activestep].split then
            local split = self.utils.math_q(DATA.seq.ext.children[note].steps[activestep].split)
            if split ~=1 then
              ImGui.DrawList_AddText( self.draw.drawlist, x1+UI.seq_activestep_reducesz, y1+UI.seq_activestep_reducesz, 0xFFFFFFFF, split )
            end
          end
    
        -- offset val
          if activestep <= step_cnt and DATA.seq.ext and DATA.seq.ext.children and DATA.seq.ext.children[note] and DATA.seq.ext.children[note].steps and DATA.seq.ext.children[note].steps[activestep] and DATA.seq.ext.children[note].steps[activestep].offset and DATA.seq.ext.children[note].steps[activestep].offset~=0 then
            local offset = DATA.seq.ext.children[note].steps[activestep].offset
            local fullwstep = (x2-x1)-UI.seq_activestep_reducesz*4
            local xpos = x1 + UI.seq_activestep_reducesz*2 + fullwstep/2+ offset * fullwstep/2
            ImGui.DrawList_AddLine( self.draw.drawlist, 
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
            ImGui.DrawList_AddCircleFilled( self.draw.drawlist, midx, midy, 4, col_playcursor, 0 )
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
              if self.var.rack.var.LASTACTIVENOTE~=note then 
                self.var.rack.var.LASTACTIVENOTE=note
                gmem_write(1025,10 ) -- push a trigger to refresh Rack
                DATA:WriteData_Parent() 
              end
            end     
            
          end
          
          
        ImGui.SameLine(ctx)
        --ImGui.Dummy(ctx,self.var.UI_linear.spacingY,0)
      end
      
      
      -- handle mouse over sequencer
      UI.draw_Seq_Step_handlemouse()
      ImGui.SameLine(ctx)
    end
    
    --------------------------------------------------------------------------------  
    f unction UI.draw_Seq_Step_handlemouse()   
      if not (DATA.temp_holdmode_value and DATA.temp_holdmode and DATA.temp_holdmode_stepline and DATA.temp_holdmode_step ) then return end
      
      if ImGui.IsMouseReleased(ctx, ImGui.MouseButton_Left) or ImGui.IsMouseReleased(ctx, ImGui.MouseButton_Right) then 
        DATA.temp_holdmode_value =nil
        DATA.temp_holdmode =nil
        DATA.temp_holdmode_stepline = nil
        DATA.temp_holdmode_step = nil
        --DATA:_Seq_Print()
        DATA.upd2.seqprint = true
        --DATA.upd = true
        if self.var.rack.var.LASTACTIVENOTE~=DATA.temp_holdmode_note then 
          self.var.rack.var.LASTACTIVENOTE=DATA.temp_holdmode_note
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
      local step2 = VF_lim(normval,1,16)] ]
      local dx = mx - DATA.temp_holdmode_mx
      local step1 = DATA.temp_holdmode_step
      local step2 = self.utils.math_q(step1 + dx/UI.seq_stepW)
      --[[msg('=')
      msg(dx)
      msg(step1)
      msg(step2)] ]
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
        end] ]
        
        
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
    f unction UI.draw_Seq()   
      
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
          Undo_BeginBlock2(self.var.proj)
          DATA:_Seq_Insert() 
          Undo_EndBlock2(self.var.proj, 'Insert new pattern', 0xFFFFFFFF)
          DATA.upd = true
        end
        
        --[[if ImGui_IsItemClicked( ctx, reaper.ImGui_MouseButton_Right() ) then
          DATA:CollectData_Seq_ConvertMIDI2Steps() 
          DATA:_Seq_Print() 
        end] ]
        
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
        reaper.ImGui_SetCursorPosX(ctx,DATA.display_w-ctrls_w*2-self.var.UI_linear.spacingX*3)
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
          if ImGui.Checkbox(ctx, 'Change children step count', self.ext.cur.CONF_seq_patlen_extendchildrenlen&1==1) then self.ext.cur.CONF_seq_patlen_extendchildrenlen=self.ext.cur.CONF_seq_patlen_extendchildrenlen~1 self.process.ext.save()end  
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
          
          ImGui.Dummy(ctx,0,self.var.UI_linear.spacingY)
          reaper.ImGui_EndPopup(ctx)
        end
        ImGui.PopStyleVar(ctx)
        
        
        
      
      -- swing
      ImGui.SameLine(ctx) 
      ImGui.SetNextItemWidth(ctx, ctrls_w)
      --local retval, v = ImGui.SliderDouble  ( ctx, '##Swing_pat', DATA.seq.ext.swing, 0, 1, 'Swing '..math.floor(DATA.seq.ext.swing*100)..'%%', reaper.ImGui_SliderFlags_None() ) 
      local retval, v = ImGui.DragDouble    ( ctx, '##Swing_pat', DATA.seq.ext.swing, 0.001, 0, 1, 'Swing '..math.floor(DATA.seq.ext.swing*100)..'%%', reaper.ImGui_SliderFlags_None() ) 
      if retval then DATA.seq.ext.swing = v end if reaper.ImGui_IsItemDeactivatedAfterEdit(ctx) then DATA:_Seq_Print() end
      
      ImGui.SetCursorPosX(ctx,UI.calc_seqXL_padname+self.var.UI_linear.spacingX*3 + UI.seq_padnameW)
       
      
      
      -- draw main stuff
      ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowPadding,0,0)  
      ImGui.PushStyleVar(ctx, ImGui.StyleVar_ItemSpacing,0,0) 
      local xoffs_abs = UI.calc_seqX
      local yoffs_abs = UI.calc_seqY+UI.calc_itemH+self.var.UI_linear.spacingY
      
      
      ImGui.SetCursorScreenPos(ctx,xoffs_abs,yoffs_abs)  
      
      local xL,yL = ImGui.GetCursorPos(ctx)
      local xA,yA = ImGui.GetCursorScreenPos(ctx)
      UI.draw_Seq_StepProgress(xL,yL, xA+UI.calc_seqXL_steps,yA) 
      
      local flagscroll = 0
      if UI.anypopupopen == true or DATA.temp_ismousewheelcontrol_hovered == true then flagscroll = ImGui.WindowFlags_NoScrollWithMouse end
      if ImGui.BeginChild( ctx, 'seq', 0, -self.var.UI_linear.spacingY-self.var.UI_linear.scrollbarW, ImGui.ChildFlags_None|ImGui.ChildFlags_Border, ImGui.WindowFlags_None|flagscroll ) then-- --|ImGui.WindowFlags_MenuBar |ImGui.ChildFlags_Border  ---UI.calc_itemH - 
        
        ImGui.Dummy(ctx,0,self.var.UI_linear.spacingY)
        
        -- ascending order
        local note_start = 127
        local note_end = 0
        local incr = -1
        if self.ext.cur.CONF_seq_instrumentsorder == 1 then
          note_start = 0
          note_end = 127
          incr = 1
        end
        
        -- loop notes
        for note = note_start,note_end,incr  do
          if self.var.rack.children[note] then 
            if ImGui.BeginChild( ctx, 'seqchildnote'..note, 0, 0,ImGui.ChildFlags_None|ImGui.ChildFlags_AutoResizeY) then   --|ImGui.ChildFlags_Border 
              local y_local = ImGui.GetCursorPosY(ctx)
              UI.draw_Seq_ctrls(self.var.rack.children[note]) 
              ImGui.SetCursorPosY(ctx, y_local)
              UI.draw_Seq_Step(self.var.rack.children[note])
              ImGui.EndChild( ctx)
            end
          end
        end
        
        -- handle refresh after drop @ UI.Drop_UI_interaction_pad(note) 
        if DATA.upd2.refreshscroll then  
          if DATA.upd2.refreshscroll == 1 then 
            DATA.upd2.refreshscroll = DATA.upd2.refreshscroll + 1 -- forward next frame
           elseif DATA.upd2.refreshscroll == 2 then 
            if self.ext.cur.CONF_seq_instrumentsorder == 0 then
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
          if self.ext.cur.CONF_seq_instrumentsorder == 0 then ImGui.SetScrollY( ctx, ImGui.GetScrollMaxY( ctx )+4000)  end
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
        ImGui.DrawList_AddCircle( self.draw.drawlist, center_x, center_y, checkbox_r, 0xF0F0F07F, 0, 2 )
        ImGui.DrawList_AddCircleFilled( self.draw.drawlist, center_x, center_y, checkbox_r-3, colfill, 0 ) 
        ImGui.SetCursorPos(ctx,xoffs+checkbox_r+ self.var.UI_linear.spacingX,yoffs+1)
        if manageravailable == true then ImGui.Text(ctx, 'Rack') else ImGui.TextDisabled(ctx, 'Rack') end
        
    end  
    
      --------------------------------------------------------------------------------  
      f unction UI.draw_Seq_ctrls(note_t)
        
        --f unction __f_draw_Seq_ctrls() end
        local note= note_t.noteID
        if not (DATA.seq and DATA.seq.ext and DATA.seq.ext.children and DATA.seq.ext.children[note] and DATA.seq.ext.children[note].step_cnt) then return end
        ImGui.PushStyleVar(ctx, ImGui.StyleVar_FramePadding,1,1) 
        ImGui.PushStyleVar(ctx, ImGui.StyleVar_CellPadding,1, 1) 
        ImGui.PushStyleVar(ctx, ImGui.StyleVar_ItemSpacing,self.var.UI_linear.spacingX, 1)
        ImGui.PushStyleVar(ctx, ImGui.StyleVar_ButtonTextAlign,0.5,0.5)
        ImGui.PushFont(ctx, self.font4) 
        
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
          ImGui.PushFont(ctx, self.font1) 
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
            ImGui.Dummy(ctx,0,self.var.UI_linear.spacingY)
            reaper.ImGui_EndPopup(ctx)
          end
          ImGui.PopFont(ctx) 
          ImGui.PopStyleVar(ctx)      
          
          
        -- step_cnt step_len LED
          if DATA.seq.ext.children[note].steplength~=0.25 then
            local tri_sz =5
            ImGui_DrawList_AddTriangleFilled( self.draw.drawlist, xabsstepcnt-tri_sz+UI.calc_seq_ctrl_butW, yabsstepcnt, xabsstepcnt+UI.calc_seq_ctrl_butW, yabsstepcnt, xabsstepcnt+UI.calc_seq_ctrl_butW, yabsstepcnt+tri_sz, 0x00FF00FF )
          end   
    
          -- track vol
          local note_layer_t = self.var.rack.children[note]
          if not (self.var.rack.children[note].TYPE_DEVICE and self.var.rack.children[note].TYPE_DEVICE == true) then 
            if self.var.rack.children[note].layers and self.var.rack.children[note].layers[1] then note_layer_t = self.var.rack.children[note].layers[1] end
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
          --ImGui.DrawList_AddRectFilled( self.draw.drawlist, x1,y1,x1 + UI.seq_padnameW,y1+UI.seq_padH-1, color or EXT.UI_colRGBA_paddefaultbackgr , 10, ImGui.DrawFlags_None )
          
          ImGui.Button(ctx,note_format..'##rackpad_name'..note,UI.seq_padnameW,UI.seq_padH-1 )
          local x1, y1 = reaper.ImGui_GetItemRectMin( ctx )
          local x2, y2 = reaper.ImGui_GetItemRectMax( ctx )
          if color then ImGui.PopStyleColor(ctx) end
           self.var.rack.children[note].seq_yA={}
           self.var.rack.children[note].seq_yA[0] = y1 -- print for note_seq_params popup
          if ImGui.IsItemClicked( ctx, ImGui.MouseButton_Right ) then 
            DATA.temp_stepline = 0
            gmem_write(1025,10 ) -- push a trigger to refresh Rack
            ImGui.OpenPopup( ctx, 'note_seq_params'..note, ImGui.PopupFlags_None ) 
          end
          
        -- LED database / defice
          if self.var.rack.children[note] then
            local offs = 5
            local ledyspace = 2
            local sz = 4
            local ledx= x1+offs--sz
            local ledy= y1+offs 
            if self.var.rack.children[note].SYSEXMOD == true then                      ImGui.DrawList_AddRectFilled( self.draw.drawlist, ledx, ledy, ledx+sz, ledy+sz, 0xF0FF50FF, 0, ImGui.DrawFlags_None) ledy=ledy+offs+ledyspace end
          end          
              
              
          UI.draw_Rack_Pads_controls_handlemouse(note_t,note, 'seq_pad')
          
        -- peaks 
          if  self.var.rack.children[note] and self.var.rack.children[note].layers and  self.var.rack.children[note].layers[1] and  DATA.peakscache[note] and  DATA.peakscache[note].peaks_arr  then 
            local is_pad_peak = true
            local dim = true
            UI.draw_peaks('padseq'..note, note_t,  x1, y1, x2-x1, y2-y1,DATA.peakscache[note].peaks_arr, is_pad_peak, dim) 
          end
        -- selection 
          if (DATA.parent_track and DATA.parent_track.ext and self.var.rack.var.LASTACTIVENOTE and self.var.rack.var.LASTACTIVENOTE  == note) then 
            ImGui.DrawList_AddRect( self.draw.drawlist, x1, y1+1, x2, y2-1, (EXT.UI_colRGBA_maintheme&0xFFFFFF00)|0xF0, 2, ImGui.DrawFlags_None|ImGui.DrawFlags_RoundCornersAll, 1 )
          end  
        -- levels
          local peak_w = UI.seq_audiolevelW
          local xP = x1 + UI.seq_padnameW + 1
          local yP = y1+1
          local hP = y2-y1-3
          if self.var.rack.children[note] and self.var.rack.children[note].peaksRMS_L and (self.var.rack.children[note].peaksRMS_L>0.001 or self.var.rack.children[note].peaksRMS_R >0.001 )then
            local val = math.min((self.var.rack.children[note].peaksRMS_L+self.var.rack.children[note].peaksRMS_R)/2,1)
            ImGui.DrawList_AddRectFilled( self.draw.drawlist, xP, yP+hP - hP*val+1 , xP+peak_w, yP+hP, (EXT.UI_colRGBA_maintheme&0xFFFFFF00)|0xFF, 0, ImGui.DrawFlags_RoundCornersTop) 
            if val > 0.9 then ImGui.DrawList_AddLine( self.draw.drawlist, xP, yP+1 , xP+peak_w, yP+1, 0xFF0000FF, 1) end 
          end
          
          
        ImGui.PopStyleVar(ctx, 4) 
        ImGui.PopFont(ctx) 
        
        -- inline 
          UI.draw_Seq_ctrls_inline(note_t)    
        
          
        --ImGui.Dummy(ctx,0,self.var.UI_linear.spacingY) 
        
      end
      
      --------------------------------------------------------------------------------  
      f unction UI.draw_Seq_ctrls_inline_handlemouse(note_t)
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
      f unction UI.draw_Seq_ctrls_inline_tools(note_t, posx,posy) 
        if not note_t then return end
        local note= note_t.noteID
        
        local butw = (UI.seq_padnameW-self.var.UI_linear.spacingX*2)/3
        local butw_3x = UI.seq_padnameW
        local butw_15x = (UI.seq_padnameW-self.var.UI_linear.spacingX)/2
        ImGui.PushFont(ctx,self.font3)
        
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
          local formatIn = math.floor(self.ext.cur.CONF_seq_random_probability*100)..'%%'
          reaper.ImGui_SetNextItemWidth(ctx,butw_15x)
          local retval, v = reaper.ImGui_SliderDouble( ctx, '##randseqnote', self.ext.cur.CONF_seq_random_probability, 0.05, 0.95, formatIn, reaper.ImGui_SliderFlags_None() )
          if retval then self.ext.cur.CONF_seq_random_probability = v end if reaper.ImGui_IsItemDeactivatedAfterEdit(ctx) then self.process.ext.save() end
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
        ImGui.PushFont(ctx,self.font2)
        ImGui.SeparatorText(ctx, 'Actions')
        --if ImGui.Button(ctx, 'Clear all', butw_3x) then DATA:_Seq_Clear() end 
        if ImGui.BeginMenu( ctx, ' Actions', true ) then
          ImGui.SeparatorText(ctx, 'Pattern general')
          if ImGui.Button(ctx, 'Clear all',-1) then DATA:_Seq_Clear() end  
          UI.draw_chokecombo(note)
          ImGui.SeparatorText(ctx, 'Pad')
          local SysEx_status = self.var.rack.children[note] and self.var.rack.children[note].SYSEXMOD == true 
          if ImGui.Checkbox(ctx, 'SysEx mode',SysEx_status) then if SysEx_status == true then DATA:Action_RS5k_SYSEXMOD_OFF(note) else self.process.rack.children.sysex.enable(note) end   end
          ImGui.SameLine(ctx )self.ImGui.Custom_HelpMarker([[
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
    ] ])
    
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
            if ImGui.Button(ctx, 'Reset##resparamvalues') then --,-self.var.UI_linear.spacingX
              if not DATA.seq.ext.children[note].steps then DATA.seq.ext.children[note].steps = {} end
              for step in pairs( DATA.seq.ext.children[note].steps) do DATA.seq.ext.children[note].steps[step][parameter] = default_val end
              DATA:_Seq_Print() 
            end
          end
          ImGui.SameLine(ctx)
          if default_val and DATA.seq.ext.children[note].steps then
            if ImGui.Button(ctx, 'Random##randparamvalues') then --,-self.var.UI_linear.spacingX
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
      f unction UI.draw_Seq_ctrls_inline(note_t) 
        f unction __f_draw_Seq_ctrls_inline() end
        
        if not note_t then return end
        local note= note_t.noteID
        if not (note and self.var.rack.children[note] and self.var.rack.children[note].seq_yA) then return end
        
        local parameter = DATA.seq_param_selector[DATA.seq_param_selectorID].param
        local width_area = DATA.display_w-UI.calc_seqXL_padname - self.var.UI_linear.scrollbarW-- UI.calc_seqW_steps + UI.seq_audiolevelW + UI.seq_padnameW + self.var.UI_linear.spacingX
        local seq_yA = self.var.rack.children[note].seq_yA[DATA.temp_stepline] or self.var.rack.children[note].seq_yA[0]
        if  seq_yA+DATA.seq_UI_inlineH_area  > DATA.display_viewport_h then
          ImGui.SetNextWindowPos( ctx, UI.calc_seqX + UI.calc_seqXL_padname, seq_yA -UI.seq_padH-DATA.seq_UI_inlineH_area-15  , ImGui.Cond_Always, 0, 0 )--
         else
          ImGui.SetNextWindowPos( ctx, UI.calc_seqX + UI.calc_seqXL_padname, seq_yA , ImGui.Cond_Always, 0, 0 )--
        end
        ImGui.SetNextWindowSize( ctx, width_area, 0, ImGui.Cond_Always )
        ImGui.PushStyleVar(ctx, ImGui.StyleVar_PopupRounding,2)  
        
        if ImGui.BeginPopup(ctx,'note_seq_params'..note) then
          local posx,posy = ImGui.GetCursorPos(ctx)
           
          if ImGui.BeginChild(ctx, '##childinlinetools'..note, UI.seq_padnameW+self.var.UI_linear.spacingX, 0, ImGui.ChildFlags_None,ImGui.WindowFlags_None|ImGui.WindowFlags_NoScrollbar) then--|reaper.ImGui_ChildFlags_AutoResizeY()
            
              
            -- name  
              ImGui.PushFont(ctx, self.font4) 
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
                 self.var.rack.children[note].seq_yA={}
                 self.var.rack.children[note].seq_yA[0] = y1 -- print for note_seq_params popup
                if ImGui.IsItemClicked( ctx, ImGui.MouseButton_Left ) or ImGui.IsItemClicked( ctx, ImGui.MouseButton_Right ) then 
                  DATA.temp_stepline = 0
                  reaper.ImGui_CloseCurrentPopup(ctx)
                end
              
                
              ImGui.PopFont(ctx) 
              
               
              
            ImGui.PushStyleVar(ctx, ImGui.StyleVar_FramePadding,self.var.UI_linear.spacingX,self.var.UI_linear.spacingY) 
            ImGui.PushStyleVar(ctx, ImGui.StyleVar_CellPadding,self.var.UI_linear.spacingX,self.var.UI_linear.spacingY) 
            ImGui.PushStyleVar(ctx, ImGui.StyleVar_ItemSpacing,self.var.UI_linear.spacingX,self.var.UI_linear.spacingY) 
            ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowPadding,self.var.UI_linear.spacingX,self.var.UI_linear.spacingY)
            UI.draw_Seq_ctrls_inline_tools(note_t) 
            
            ImGui.PopStyleVar(ctx,4)
            reaper.ImGui_EndChild(ctx)
          end 
          
          UI.draw_Seq_Step(note_t, posx + UI.seq_audiolevelW + UI.seq_padnameW + self.var.UI_linear.spacingX, posy )  
          UI.draw_Seq_ctrls_inline_drawstuff(note_t, posx, posy+ UI.seq_padH) 
          ImGui.Dummy(ctx,0,self.var.UI_linear.spacingY)
          ImGui.Dummy(ctx,UI.seq_padnameW+self.var.UI_linear.spacingX*2,0)ImGui.SameLine(ctx)
          UI.draw_Seq_horizscroll()  
          ImGui.Dummy(ctx,0,self.var.UI_linear.spacingY)
          reaper.ImGui_EndPopup(ctx)
        end
        ImGui.PopStyleVar(ctx)
        
      end
      --------------------------------------------------------------------------------  
      f unction UI.draw_Seq_ctrls_inline_drawstuff(note_t, posx, posy)
        
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
        ImGui.SetCursorPos(ctx, posx + UI.seq_audiolevelW + UI.seq_padnameW + self.var.UI_linear.spacingX, posy + self.var.UI_linear.spacingY)
        
        
        --ImGui.Button(ctx,'active_area',-1,harea)
        ImGui.InvisibleButton(ctx,'active_area',-1,harea)
        local x1, y1 = reaper.ImGui_GetItemRectMin( ctx )
        local x2, y2 = reaper.ImGui_GetItemRectMax( ctx )
        UI.draw_Seq_ctrls_inline_handlemouse(note_t) 
        ImGui.Dummy(ctx,0,self.var.UI_linear.spacingY)
        
        
        -- patch for missing sysex_handler JSFX
        local misiingsysex = 
          ( parameter_parent == 'meta' and 
            (
              parameter == 'meta_pitch' or 
              parameter == 'meta_probability'
            )
          ) and self.var.rack.children[note].SYSEXHANDLER_isvalid~=true
          
          
          
          
        if misiingsysex then  
          ImGui.SetCursorPosX(ctx, posx + UI.seq_audiolevelW + UI.seq_padnameW + self.var.UI_linear.spacingX)
         
          ImGui.DrawList_AddText( self.draw.drawlist, x1+ 10, y1+50, 0xFFFFFFBF, 
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
    ] ]
    
    )
    
    
        end
        
        -- parameter tabs
        ImGui.SetCursorPosX(ctx, posx + UI.seq_audiolevelW + UI.seq_padnameW + self.var.UI_linear.spacingX)
        if ImGui.BeginTabBar( ctx, 'paraminlinetabs', ImGui.TabItemFlags_None|ImGui.TabBarFlags_FittingPolicyResizeDown ) then
          for i = 1, #DATA.seq_param_selector do
            local formatIn = DATA.seq_param_selector[i].str
            if ImGui.BeginTabItem( ctx, formatIn..'##inlinetabs', false, ImGui.TabItemFlags_None ) then DATA.seq_param_selectorID = i  ImGui.EndTabItem( ctx)  end 
          end
          ImGui.EndTabBar( ctx)
        end
        
        if parameter_parent == 'meta' and misiingsysex ~= true then
          ImGui.SetCursorPosX(ctx, posx + UI.seq_audiolevelW + UI.seq_padnameW + self.var.UI_linear.spacingX)
          if ImGui.BeginTabBar( ctx, 'paraminlinetabs_meta', ImGui.TabItemFlags_None|ImGui.TabBarFlags_FittingPolicyResizeDown ) then
            for i = 1, #DATA.seq_param_selector_meta do
              local formatIn = DATA.seq_param_selector_meta[i].str
              if ImGui.BeginTabItem( ctx, formatIn..'##inlinetabs_meta', false, ImGui.TabItemFlags_None ) then DATA.seq_param_selector_metaID = i  ImGui.EndTabItem( ctx)  end 
            end
            ImGui.EndTabBar( ctx)
          end
        end
         
        if parameter_parent == 'trackenv' then
          ImGui.SetCursorPosX(ctx, posx + UI.seq_audiolevelW + UI.seq_padnameW + self.var.UI_linear.spacingX)
          if ImGui.BeginTabBar( ctx, 'paraminlinetabs_trackenv', ImGui.TabItemFlags_None|ImGui.TabBarFlags_FittingPolicyResizeDown ) then
            for i = 1, #DATA.seq_param_selector_trackenv do
              local formatIn = DATA.seq_param_selector_trackenv[i].str
              if ImGui.BeginTabItem( ctx, formatIn..'##inlinetabs_trackenv', false, ImGui.TabItemFlags_None ) then DATA.seq_param_selector_trackenvID = i  ImGui.EndTabItem( ctx)  end 
            end
            ImGui.EndTabBar( ctx)
          end
        end
        
        if parameter_parent == 'trackFXenv' then
          ImGui.SetCursorPosX(ctx, posx + UI.seq_audiolevelW + UI.seq_padnameW + self.var.UI_linear.spacingX)
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
        local stepcol_2 = (EXT.UI_colRGBA_maintheme&0xFFFFFF00)|0x2F 
            
        for step = 1+DATA.seq.stepoffs, DATA.seq.ext.patternlen do
          local stepcol = stepcol_1
          if (step-1)%8> 3 then stepcol = stepcol_2 end 
          local xpos = x1 + (stepw) * (step-DATA.seq.stepoffs-1) 
          ImGui.DrawList_AddRectFilled( self.draw.drawlist, xpos,y1,xpos + stepw -1 ,y2, stepcol|0x0F, UI.seq_steprounding, ImGui.DrawFlags_None )
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
            if self.ext.cur.CONF_seq_env_clamp == 0 then  
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
                ImGui.DrawList_AddRectFilled( self.draw.drawlist, xpos,ypos,xpos + stepw -1 ,y2, stepcol|0x6F, UI.seq_steprounding, ImGui.DrawFlags_None )
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
                  ImGui.DrawList_AddRectFilled( self.draw.drawlist, xpos,ypos1,xpos + stepw -1 ,ypos2, stepcol|0x6F, UI.seq_steprounding, ImGui.DrawFlags_None )
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
                 txt=self.utils.math_q(val)        
               elseif DATA.seq_param_selectorID ==4  then --step len
                 txt=math.floor(val*100)..'%'   
               elseif DATA.seq_param_selectorID ==5 and DATA.seq_param_selector_metaID ==1 then --meta_pitch
                 txt=self.utils.math_q(val-64)    
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
              
              ImGui.PushFont(ctx, self.font5) 
              ImGui.DrawList_AddText( self.draw.drawlist, xpos, txyy, 0xFFFFFF00|mousediff, txt ) 
              ImGui.PopFont(ctx) 
            end
          end
          
      end
      --------------------------------------------------------------------------------  
      f unction UI.draw_Seq_ctrls_inline_getactiveparam()
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
      f unction UI.draw_Seq_ctrls_inline_appstuff(note_t, rightbutton)
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
          ) and self.var.rack.children[note].SYSEXHANDLER_isvalid~=true
          
        if misiingsysex then self.process.rack.children.sysex.enable(note) end
        
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
      f unction UI.draw_Seq_startup() 
        reaper.ImGui_SetCursorPos(ctx,0 ,UI.calc_itemH + self.var.UI_linear.spacingY)
            ImGui.TextWrapped(ctx,
                [[ 
            Basic step sequencer flow: 
                1. Select MIDI item placed in RS5k manager MIDI bus track. Or create it:] ]) --ImGui.SameLine(ctx) 
                ImGui.Dummy(ctx,30,0) ImGui.SameLine(ctx)
                if ImGui.Button(ctx, 'Insert new pattern') then 
                  Undo_BeginBlock2(self.var.proj)
                  DATA:_Seq_Insert() 
                  Undo_EndBlock2(self.var.proj, 'Insert new pattern', 0xFFFFFFFF)
                  DATA.upd = true
                end
                
                ImGui.TextWrapped(ctx,  
      [[          2. Once MIDI item is selected, RS5k manager are ready to read and write sequencer data.
      
                ] ])
                
                
      end
      --------------------------------------------------------------------------------  
      f unction UI.draw_Seq_horizscroll(is_thin)  
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
        ImGui.InvisibleButton(ctx, '#scrollseq',bw, self.var.UI_linear.scrollbarW)
        -- draw rect / handle
        local x1, y1 = reaper.ImGui_GetItemRectMin( ctx )
        local x2, y2 = reaper.ImGui_GetItemRectMax( ctx )
        ImGui.DrawList_AddRectFilled( self.draw.drawlist, x1, y1+yoffs, x2, y2+yoffs, 0x191919FF, 5, reaper.ImGui_DrawFlags_None() )
        local handle_red = 3
        local minx = x1+handle_red
        local handle_w = 50
        local maxx = x2-handle_red*2 - handle_w
        minx = minx + (maxx - minx) * DATA.seq_horiz_scroll 
        ImGui.DrawList_AddRectFilled( self.draw.drawlist, minx, y1+yoffs+handle_red, minx + handle_w, y2+yoffs-handle_red, 0x595959FF, 5, reaper.ImGui_DrawFlags_None() )
        if DATA.seq.active_pat_step and DATA.seq.ext.patternlen and DATA.seq.ext.patternlen >= 32 then 
          for i = 1, DATA.seq.ext.patternlen, 16 do
            local xsep = math.floor(x1+handle_red+(x2-x1-handle_red*2) * ((i -1)/ DATA.seq.ext.patternlen))
            ImGui.DrawList_AddLine( self.draw.drawlist, xsep, y1+yoffs, xsep, y2+yoffs, 0x00FF004F, 1 )
          end
          minx = x1+handle_red
          local playcur_w = xres / DATA.seq.ext.patternlen
          local maxx = x2-handle_red*2 - handle_w
          minx = minx + (maxx - minx) * ((DATA.seq.active_pat_step -1)/ DATA.seq.ext.patternlen)
          ImGui.DrawList_AddRectFilled( self.draw.drawlist, minx, y1+yoffs+handle_red, minx + playcur_w, y2+yoffs-handle_red, 0x00FF008F, 5, reaper.ImGui_DrawFlags_None() )
        end
        
        if ImGui.IsItemClicked(ctx,ImGui.MouseButton_Left) then
          DATA.temp_horscroll_val = DATA.seq_horiz_scroll
          DATA.temp_horscroll_mx = reaper.ImGui_GetMousePos(ctx)
        end
        if ImGui.IsItemActive(ctx) then
          local mx,my =  reaper.ImGui_GetMousePos(ctx)
          DATA.seq_horiz_scroll = VF_lim(DATA.temp_horscroll_val + (mx - DATA.temp_horscroll_mx)/xres,0,0.99)
          DATA:_Seq_RefreshHScroll()
          reaper.ImGui_DrawList_AddText( self.draw.drawlist, x2-60, y1+yoffs-1, 0xFFFFFFFF, format )
        end
        if reaper.ImGui_IsItemDeactivated(ctx) then DATA:_Seq_RefreshHScroll() end
        
     
        
        
        --local ret, v = ImGui.SliderDouble(ctx,'##horizscroll',DATA.seq_horiz_scroll,0,0.99,format,ImGui.SliderFlags_None)
        
      end
      --------------------------------------------------------------------------------  
      f unction UI.draw_Seq_StepProgress(xL,yL, xA,yA) 
        --DATA.seq.active_pat_step
        if not DATA.seq  then  end
        
        local patternlen = DATA.seq.ext.patternlen
        
        if DATA.seq.active_pat_step then
          local step =  DATA.seq.active_pat_step
          step= step - DATA.seq.stepoffs--%16
          --if step == 0 then step = 16 end
          local x1 = xA + (step-1) * UI.seq_stepW
          ImGui.DrawList_AddRectFilled( self.draw.drawlist, x1,yA+self.var.UI_linear.spacingY,x1+UI.seq_stepW,yA+self.var.UI_linear.spacingY*2,  0XFFFFFF6F, 5,flagsIn ) 
        end
        
      end
    
    --------------------------------------------------------------------------------  
      f unction UI.seqdraw()  
        if DATA.VCA_mode == 0 then 
          UI.knob_handle  = UI.knob_handle_normal 
         elseif DATA.VCA_mode == 1 then 
          UI.knob_handle = UI.knob_handle_vca
         elseif DATA.VCA_mode == 2 then 
          UI.knob_handle = UI.knob_handle_vca2       
        end
        
        local closew
        if (DATA.parent_track and DATA.parent_track.valid == true) and UI.calc_padoverviewW and UI.hide_padoverview ~= true then closew = UI.calc_padoverviewW-self.var.UI_linear.spacingX*2  end
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
            ImGui.Dummy(ctx,0, self.var.UI_linear.spacingY)
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
    f unction UI.draw_flow_COMBO(t)
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
        for id in self.utils.spairs(t.values) do
          local selected 
          if type(EXT[t.extstr]) == 'number' then 
            
            local isint = ({math.modf(EXT[t.extstr])})[2] == 0 and ({math.modf(id)})[2] == 0 
            selected = ((isint==true and id&EXT[t.extstr]==EXT[t.extstr]) or id==EXT[t.extstr])  and EXT[t.extstr]~= 0 
          end
          if type(EXT[t.extstr]) == 'string' then selected = EXT[t.extstr]==id end
          
          if ImGui.Selectable( ctx, t.values[id],selected  ) then
            EXT[t.extstr] = id
            trig_action = true
            self.process.ext.save()
            if self.ext.cur.CONF_applylive == 1 then DATA:Process() end
          end
        end
        ImGui.EndCombo(ctx)
      end
      
      -- reset
      if reaper.ImGui_IsItemHovered( ctx, ImGui.HoveredFlags_None ) and ImGui_IsMouseClicked( ctx, ImGui.MouseButton_Right ) then
        DATA.PRESET_RestoreDefaults(t.extstr)
        trig_action = true
        if self.ext.cur.CONF_applylive == 1 then DATA:Process() end
      end  
      if t.tooltip then  ImGui.SetItemTooltip(ctx, t.tooltip) end
      return  trig_action
    end
    --------------------------------------------------------------------------------  
    f unction UI.draw_tabs_Actions()
  
      -------------- General
      ImGui.SeparatorText(ctx, 'General')
      ImGui.Indent(ctx, 10)
      -- stick current track 
        local stickstate = DATA.parent_track and DATA.parent_track.ext_load == true
        if DATA.parent_track and DATA.parent_track.trGUID then
          if ImGui.Checkbox( ctx, 'Stick current rack to this project', stickstate) then 
            if DATA.parent_track.ext_load == true then 
              SetProjExtState( self.var.proj, 'MPLRS5KMAN', 'STICKPARENTGUID','')
              DATA.upd = true
             else
              SetProjExtState( self.var.proj, 'MPLRS5KMAN', 'STICKPARENTGUID',DATA.parent_track.trGUID )
              DATA.upd = true
            end
          end
        end
        ImGui.SameLine(ctx)
        self.ImGui.Custom_HelpMarker('This rack will be always displayed even if selected track is not related to this rack.\nThis also ignores other racks in project.')
      -- fix GUID
        local fixavailable = ''
        local available_extGUID = not (DATA.parent_track and DATA.parent_track.valid == true and DATA.parent_track.ext.PARENT_GUID_INTERNAL)
        if available_extGUID == true then fixavailable = '[not available] ' end
        if available_extGUID ~= true then ImGui.BeginDisabled(ctx, true) end
        if ImGui.Selectable( ctx, fixavailable..'Fix GUID of parent track', self.ext.cur.CONF_lastmacroaction==1, reaper.ImGui_SelectableFlags_None(), 0, 0 ) then 
          GetSetMediaTrackInfo_String( DATA.parent_track.ptr, 'GUID', DATA.parent_track.ext.PARENT_GUID_INTERNAL, true )
          DATA.upd = true
        end 
        ImGui.SameLine(ctx) self.ImGui.Custom_HelpMarker('Use this if rack doesn`t handled by RS5k manager after import template')
        if available_extGUID ~= true then ImGui.EndDisabled(ctx) end
      ImGui.Unindent(ctx, 10)
    
    
      -------------- MIDI
      ImGui.SeparatorText(ctx, 'MIDI')
      ImGui.Indent(ctx, 10) 
      -- explode take
        if ImGui.Button( ctx, 'Explode MIDI bus take to children',-1) then DATA:Action_ExplodeTake() end
        if ImGui.Button( ctx, 'Explode MIDI bus take to children (fixed note)',-1) then DATA:Action_ExplodeTake({modify_note = self.ext.cur.CONF_explodeMIDItochildren_note}) end ImGui.SameLine(ctx) self.ImGui.Custom_HelpMarker('Explode to children but change output notes to fixed note')
          
          reaper.ImGui_SetNextItemWidth(ctx, 100)
          local retval, v = reaper.ImGui_SliderInt( ctx, 'Explode MIDI Bus: fixed note', self.ext.cur.CONF_explodeMIDItochildren_note, 0, 127, self.ext.cur.CONF_explodeMIDItochildren_note, ImGui.SliderFlags_None )
          if retval then self.ext.cur.CONF_explodeMIDItochildren_note = v end
          if reaper.ImGui_IsItemDeactivated(ctx) then self.process.ext.save() end
          
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
        if ImGui.Checkbox( ctx, 'Drum layout', self.ext.cur.CONF_seq_sendsysextoLP==0) then       
          DATA:Launchpad_StuffSysex('F0h 00h 20h 29h 02h 0Dh 00h 04h F7h'  ) 
          self.ext.cur.CONF_seq_sendsysextoLP = self.ext.cur.CONF_seq_sendsysextoLP~1 self.process.ext.save()
          if DATA.MIDIbus.valid == true and DATA.MIDIbus.tr_ptr then SetMediaTrackInfo_Value( DATA.MIDIbus.tr_ptr, 'I_MIDIHWOUT', self.var.ext.CONF_midioutput.current<<5) end
          DATA.upd = true
        end --  Drum layout
        ImGui.SameLine(ctx) ImGui.Dummy(ctx, 20, 0) ImGui.SameLine(ctx)
        if self.ext.cur.CONF_seq_sendsysextoLP == 1 then reaper.ImGui_BeginDisabled(ctx, true )  end
        if ImGui.Checkbox( ctx, 'Enable monitoring', DATA.MIDIbus.valid == true and DATA.MIDIbus.I_RECMON>0) then       DATA:Launchpad_StuffSysex(nil,1 ) DATA.upd = true end --  Drum layout
        if self.ext.cur.CONF_seq_sendsysextoLP == 1 then reaper.ImGui_EndDisabled(ctx )  end
        ImGui.Indent(ctx,10)ImGui.TextDisabled(ctx, '+ MIDI bus: disable monitoring, set MIDI HW output')ImGui.Unindent(ctx,10)
        
        if ImGui.Checkbox( ctx, 'Programmer mode + enable send sequencer data to LP', self.ext.cur.CONF_seq_sendsysextoLP==1) then   
          DATA:Launchpad_StuffSysex('F0h 00h 20h 29h 02h 0Dh 00h 7Fh F7h'  ) 
          self.ext.cur.CONF_seq_sendsysextoLP = self.ext.cur.CONF_seq_sendsysextoLP~1 self.process.ext.save()
          if DATA.MIDIbus.valid == true and DATA.MIDIbus.tr_ptr then SetMediaTrackInfo_Value( DATA.MIDIbus.tr_ptr, 'I_MIDIHWOUT', -1) end
          DATA.upd = true
        end --  Programmer mode layout
        ImGui.Indent(ctx,10)ImGui.TextDisabled(ctx, '+ MIDI bus: disable monitoring, unset MIDI HW output')ImGui.Unindent(ctx,10)
              ] ]
              
        ImGui.Unindent(ctx, 10)
        
      
    end 
    f unction dBFromVal(val) if val < 0.5 then return 20*math.log(val*2, 10) else return (val*12-6) end end
  --------------------------------------------------------------------------------  
    f unction UI.draw_tabs_settings_onsampleadd()
      if ImGui.CollapsingHeader(ctx, 'On sample add') then   
        ImGui.Indent(ctx,self.var.UI_linear.menu_indentX)
        
        
        if ImGui.CollapsingHeader(ctx, 'FX instance##On sample add_fx') then   
          ImGui.Indent(ctx, self.var.UI_linear.menu_indentX)
          if ImGui.Checkbox( ctx, 'Rename instance',                                        self.ext.cur.CONF_onadd_renameinst == 1 ) then self.ext.cur.CONF_onadd_renameinst =self.ext.cur.CONF_onadd_renameinst~1 self.process.ext.save() end 
                  if self.ext.cur.CONF_onadd_renameinst == 1 then
                    ImGui_SetNextItemWidth(ctx, self.var.UI_linear.settings_itemW) 
                    local ret, buf = ImGui.InputText( ctx, 'instance name',                    self.ext.cur.CONF_onadd_renameinst_str, ImGui.InputTextFlags_EnterReturnsTrue) 
                    if ret then 
                      self.ext.cur.CONF_onadd_renameinst_str =buf 
                      self.process.ext.save() 
                    end
                    ImGui.SameLine(ctx)
                    self.ImGui.Custom_HelpMarker(
          [[Supported wildcards:
            #note - note number
            #layer - layer number
          ] ])
                  end
          if ImGui.Checkbox( ctx, 'Float RS5k instance',                                    self.var.ext.CONF_onadd_float.current == 1 ) then self.var.ext.CONF_onadd_float.current =self.var.ext.CONF_onadd_float.current~1 self.process.ext.save() end
          if ImGui.Checkbox( ctx, 'Set obey notes-off',                                     self.var.ext.CONF_onadd_obeynoteoff.current == 1 ) then self.var.ext.CONF_onadd_obeynoteoff.current =self.var.ext.CONF_onadd_obeynoteoff.current~1 self.process.ext.save() end 
          if ImGui.Checkbox( ctx, 'Set Gain to normalized LUFS',                            self.var.ext.CONF_onadd_autoLUFSnorm_toggle.current == 1 ) then self.var.ext.CONF_onadd_autoLUFSnorm_toggle.current =self.var.ext.CONF_onadd_autoLUFSnorm_toggle.current~1 self.process.ext.save() end 
          if self.var.ext.CONF_onadd_autoLUFSnorm_toggle.current == 1 then 
            ImGui.SameLine(ctx)
            reaper.ImGui_SetNextItemWidth(ctx, 100)
            local normformat = self.var.ext.CONF_onadd_autoLUFSnorm.current ..'dB' 
            local ret, v = ImGui.SliderInt( ctx, 'Normalize to LUFS##normlufsslider',                          self.var.ext.CONF_onadd_autoLUFSnorm.current, -23, 0, normformat, ImGui.SliderFlags_None ) 
            if ret then self.var.ext.CONF_onadd_autoLUFSnorm.current = v end 
            if reaper.ImGui_IsItemDeactivatedAfterEdit(ctx) then self.process.ext.save() end
          end
          
          -- max voices
          local ret, v = ImGui.SliderInt( ctx, 'Max voices##CONF_onadd_maxvoices',                          self.var.ext.CONF_onadd_maxvoices.current, 1, 64, self.var.ext.CONF_onadd_maxvoices.current, ImGui.SliderFlags_None ) 
          if ret then self.var.ext.CONF_onadd_maxvoices.current = v end 
          if reaper.ImGui_IsItemDeactivatedAfterEdit(ctx) then self.process.ext.save() end
          
          -- velocity range
          local ret, v = ImGui.SliderInt( ctx, 'Min velocity##CONF_onadd_minvel',                          self.var.ext.CONF_onadd_minvel.current, 1, self.var.ext.CONF_onadd_maxvel.current, self.var.ext.CONF_onadd_minvel.current, ImGui.SliderFlags_None ) 
          if ret then self.var.ext.CONF_onadd_minvel.current = VF_lim(v,1,127) end  if reaper.ImGui_IsItemDeactivatedAfterEdit(ctx) then self.process.ext.save() end
          local ret, v = ImGui.SliderInt( ctx, 'Max velocity##CONF_onadd_maxvel',                          self.var.ext.CONF_onadd_maxvel.current, self.var.ext.CONF_onadd_minvel.current, 127, self.var.ext.CONF_onadd_maxvel.current, ImGui.SliderFlags_None ) 
          if ret then self.var.ext.CONF_onadd_maxvel.current = VF_lim(v,1,127) end  if reaper.ImGui_IsItemDeactivatedAfterEdit(ctx) then self.process.ext.save() end
          
          
          
          local mingain_DB = dBFromVal(self.var.ext.CONF_onadd_mingain.current)
          if mingain_DB < -70 then mingain_DB = '-inf' else mingain_DB = math.floor(mingain_DB*100)/100 end
          local mingain_DB_format = mingain_DB..'dB'
          local ret, v = ImGui.SliderDouble( ctx, 'Min gain##CONF_onadd_mingain',                          self.var.ext.CONF_onadd_mingain.current, 0, 0.5, mingain_DB, ImGui.SliderFlags_None|ImGui.SliderFlags_NoInput ) 
          if ret then self.var.ext.CONF_onadd_mingain.current = VF_lim(v,0,0.5) end  if reaper.ImGui_IsItemDeactivatedAfterEdit(ctx) then self.process.ext.save() end
          
          -- adsr
          if ImGui.Checkbox( ctx, '##CONF_onadd_ADSR_flags_a',                                    self.var.ext.CONF_onadd_ADSR_flags.current&1 == 1 ) then self.var.ext.CONF_onadd_ADSR_flags.current =self.var.ext.CONF_onadd_ADSR_flags.current~1 self.process.ext.save() end ImGui.SameLine(ctx)
          if self.var.ext.CONF_onadd_ADSR_flags.current&1~=1 then ImGui.BeginDisabled(ctx, true) end
          local ret, v = ImGui.SliderDouble( ctx, 'Attack##CONF_onadd_ADSR_A',            self.var.ext.CONF_onadd_ADSR_A.current*2, 0, 0.1, '%.3f sec', ImGui.SliderFlags_None ) if ret then self.var.ext.CONF_onadd_ADSR_A.current = VF_lim(v/2,0,2) end if reaper.ImGui_IsItemDeactivatedAfterEdit(ctx) then self.process.ext.save() end
          if self.var.ext.CONF_onadd_ADSR_flags.current &1~=1 then ImGui.EndDisabled(ctx) end
          
          if ImGui.Checkbox( ctx, '##CONF_onadd_ADSR_flags_d',                                    self.var.ext.CONF_onadd_ADSR_flags.current&2 == 2) then self.var.ext.CONF_onadd_ADSR_flags.current =self.var.ext.CONF_onadd_ADSR_flags.current~2 self.process.ext.save() end ImGui.SameLine(ctx)
          if self.var.ext.CONF_onadd_ADSR_flags.current&2~=2 then ImGui.BeginDisabled(ctx, true) end
          local ret, v = ImGui.SliderDouble( ctx, 'Decay##CONF_onadd_ADSR_D',            self.var.ext.CONF_onadd_ADSR_D.current, 0, 15, '%.3f sec', ImGui.SliderFlags_None ) if ret then self.var.ext.CONF_onadd_ADSR_D.current = VF_lim(v,0,15) end if reaper.ImGui_IsItemDeactivatedAfterEdit(ctx) then self.process.ext.save() end
          if self.var.ext.CONF_onadd_ADSR_flags.current &2~=2 then ImGui.EndDisabled(ctx) end
          
          if ImGui.Checkbox( ctx, '##CONF_onadd_ADSR_flags_s',                                    self.var.ext.CONF_onadd_ADSR_flags.current&4 == 4 ) then self.var.ext.CONF_onadd_ADSR_flags.current =self.var.ext.CONF_onadd_ADSR_flags.current~4 self.process.ext.save() end ImGui.SameLine(ctx)
          if self.var.ext.CONF_onadd_ADSR_flags.current&4~=4 then ImGui.BeginDisabled(ctx, true) end
          local format_sus =  20*math.log(self.var.ext.CONF_onadd_ADSR_S.current*2, 10)..'dB'
          local ret, v = ImGui.SliderDouble( ctx, 'Sustain##CONF_onadd_ADSR_S',            self.var.ext.CONF_onadd_ADSR_S.current, 0, 0.5, format_sus, ImGui.SliderFlags_None ) if ret then self.var.ext.CONF_onadd_ADSR_S.current = VF_lim(v/2,0,0.5) end if reaper.ImGui_IsItemDeactivatedAfterEdit(ctx) then self.process.ext.save() end
          if self.var.ext.CONF_onadd_ADSR_flags.current &4~=4 then ImGui.EndDisabled(ctx) end
          
          if ImGui.Checkbox( ctx, '##CONF_onadd_ADSR_flags_r',                                    self.var.ext.CONF_onadd_ADSR_flags.current&8 == 8 ) then self.var.ext.CONF_onadd_ADSR_flags.current =self.var.ext.CONF_onadd_ADSR_flags.current~8 self.process.ext.save() end ImGui.SameLine(ctx)
          if self.var.ext.CONF_onadd_ADSR_flags.current&8~=8 then ImGui.BeginDisabled(ctx, true) end
          local ret, v = ImGui.SliderDouble( ctx, 'Release##CONF_onadd_ADSR_R',            self.var.ext.CONF_onadd_ADSR_R.current*2, 0, 0.5, '%.3f sec', ImGui.SliderFlags_None ) if ret then self.var.ext.CONF_onadd_ADSR_R.current = VF_lim(v/2,0,2) end if reaper.ImGui_IsItemDeactivatedAfterEdit(ctx) then self.process.ext.save() end
          if self.var.ext.CONF_onadd_ADSR_flags.current &8~=8 then ImGui.EndDisabled(ctx) end
          
          ImGui.Unindent(ctx, self.var.UI_linear.menu_indentX)
        end
        
        
        
        
        if ImGui.CollapsingHeader(ctx, 'Various##On sample add_Various') then     
          ImGui.Indent(ctx, self.var.UI_linear.menu_indentX)
          if ImGui.Checkbox( ctx, 'Copy samples to project path',                           self.var.ext.CONF_onadd_copytoprojectpath.current == 1 ) then self.var.ext.CONF_onadd_copytoprojectpath.current =self.var.ext.CONF_onadd_copytoprojectpath.current~1 self.process.ext.save() end 
          ImGui.SameLine(ctx)
          if ImGui.Button(ctx,'Open path') then 
            local prpath = reaper.GetProjectPathEx( 0 )
            prpath = prpath..'/'..self.var.ext.CONF_onadd_copysubfoldname.current..'/'
            RecursiveCreateDirectory( prpath, 0 )
            VF_Open_URL(prpath) 
          end
          if ImGui.Checkbox( ctx, 'Drop to white keys only',                                self.ext.cur.CONF_onadd_whitekeyspriority == 1 ) then self.ext.cur.CONF_onadd_whitekeyspriority =self.ext.cur.CONF_onadd_whitekeyspriority~1 self.process.ext.save() end
          
          ImGui.Unindent(ctx, self.var.UI_linear.menu_indentX)
        end
          
          
          
          ImGui.Unindent(ctx,self.var.UI_linear.menu_indentX)
      end  
    end
  --------------------------------------------------------------------------------  
    f unction UI.draw_tabs_settings_tcpmcp()
      if ImGui.CollapsingHeader(ctx, 'TCP / MCP') then 
        ImGui.Indent(ctx,self.var.UI_linear.menu_indentX)
      
          if ImGui.Checkbox( ctx, 'Collapse parent folder',                                 self.var.ext.CONF_onadd_newchild_trackheight.currentflags&1==1 ) then 
            self.var.ext.CONF_onadd_newchild_trackheight.currentflags =self.var.ext.CONF_onadd_newchild_trackheight.currentflags~1  if self.var.ext.CONF_onadd_newchild_trackheight.currentflags&2==2 then self.var.ext.CONF_onadd_newchild_trackheight.currentflags = self.var.ext.CONF_onadd_newchild_trackheight.currentflags~2 end
            self.process.ext.save() 
            DATA:Auto_TCPMCP(true)
            DATA.upd = true 
          end
          if ImGui.Checkbox( ctx, 'Supercollapse parent folder',                            self.var.ext.CONF_onadd_newchild_trackheight.currentflags&2==2 ) then 
            self.var.ext.CONF_onadd_newchild_trackheight.currentflags =self.var.ext.CONF_onadd_newchild_trackheight.currentflags~2  if self.var.ext.CONF_onadd_newchild_trackheight.currentflags&1==1 then self.var.ext.CONF_onadd_newchild_trackheight.currentflags = self.var.ext.CONF_onadd_newchild_trackheight.currentflags~1 end
            self.process.ext.save() 
            DATA:Auto_TCPMCP(true)
            DATA.upd = true 
          end
          if ImGui.Checkbox( ctx, 'Hide children TCP',                                      self.var.ext.CONF_onadd_newchild_trackheight.currentflags&4==4 ) then self.var.ext.CONF_onadd_newchild_trackheight.currentflags =self.var.ext.CONF_onadd_newchild_trackheight.currentflags~4 self.process.ext.save() DATA:Auto_TCPMCP(true) DATA.upd = true end
          ImGui.SameLine(ctx) self.ImGui.Custom_HelpMarker('Performs at every state change')
          if ImGui.Checkbox( ctx, 'Hide children MCP',                                      self.var.ext.CONF_onadd_newchild_trackheight.currentflags&8==8 ) then self.var.ext.CONF_onadd_newchild_trackheight.currentflags =self.var.ext.CONF_onadd_newchild_trackheight.currentflags~8 self.process.ext.save() DATA:Auto_TCPMCP(true) DATA.upd = true end
          ImGui.SameLine(ctx) self.ImGui.Custom_HelpMarker('Performs at every state change')
          ImGui_SetNextItemWidth(ctx, self.var.UI_linear.settings_itemW)  
          local formatin = '%dpx' if self.var.ext.CONF_onadd_newchild_trackheight.current == 0 then formatin = 'default' end
          local ret, v = ImGui.SliderInt( ctx, 'New child track height',                    self.var.ext.CONF_onadd_newchild_trackheight.current, 0, 300, formatin, ImGui.SliderFlags_None ) if ret then self.var.ext.CONF_onadd_newchild_trackheight.current = v end
          if ImGui_IsItemDeactivatedAfterEdit(ctx) then self.process.ext.save() end 
          if self.var.ext.CONF_onadd_newchild_trackheight.current > 0 then 
            ImGui.SameLine(ctx) if ImGui.Checkbox( ctx, 'Lock',                                      self.var.ext.CONF_onadd_newchild_trackheight_lock.current&1==1 ) then self.var.ext.CONF_onadd_newchild_trackheight_lock.current =self.var.ext.CONF_onadd_newchild_trackheight_lock.current~1 self.process.ext.save() DATA.upd = true end
          end
          
          
        ImGui.Unindent(ctx,self.var.UI_linear.menu_indentX)
      end  
    end
    
    
  --------------------------------------------------------------------------------  
    f unction UI.draw_tabs_settings_Theming()    
      if ImGui.CollapsingHeader(ctx, 'Theming') then 
        ImGui.Indent(ctx,self.var.UI_linear.menu_indentX)
        -- main backgr alpha
        ImGui_SetNextItemWidth(ctx, self.var.UI_linear.settings_itemW)
        local retval, v = ImGui.SliderDouble( ctx, 'Background transparency', EXT.UI_transparency, 0, 1, math.floor(EXT.UI_transparency*100)..'%%', ImGui.SliderFlags_None )
        if retval then EXT.UI_transparency = v end if ImGui.IsItemDeactivatedAfterEdit(ctx) then self.process.ext.save()  end
        --trackcol tint
        ImGui_SetNextItemWidth(ctx, self.var.UI_linear.settings_itemW)
        local retval, v = ImGui.SliderInt( ctx, 'Tint track color to pads', EXT.UI_col_tinttrackcoloralpha, 0, 255, math.floor(100*EXT.UI_col_tinttrackcoloralpha/255)..'%%', ImGui.SliderFlags_None )
        if retval then EXT.UI_col_tinttrackcoloralpha = v end if ImGui.IsItemDeactivatedAfterEdit(ctx) then self.process.ext.save()  end
        
        --Active pad default
        local retval, col_rgba = ImGui.ColorEdit4( ctx, 'Active pad default', EXT.UI_colRGBA_paddefaultbackgr, ImGui.ColorEditFlags_AlphaBar|ImGui.ColorEditFlags_NoInputs )  
        if retval then EXT.UI_colRGBA_paddefaultbackgr = col_rgba end if ImGui.IsItemDeactivatedAfterEdit(ctx) then self.process.ext.save()  end
        ImGui.SameLine(ctx)if ImGui.Button(ctx, 'Reset##res_Active pad default') then EXT.UI_colRGBA_paddefaultbackgr = UI.def_colRGBA_paddefaultbackgr self.process.ext.save() end
        --Inactive pad default
        local retval, col_rgba = ImGui.ColorEdit4( ctx, 'Inactive pad default', EXT.UI_colRGBA_paddefaultbackgr_inactive, ImGui.ColorEditFlags_AlphaBar|ImGui.ColorEditFlags_NoInputs )  
        if retval then EXT.UI_colRGBA_paddefaultbackgr_inactive = col_rgba end if ImGui.IsItemDeactivatedAfterEdit(ctx) then self.process.ext.save()  end
        ImGui.SameLine(ctx)if ImGui.Button(ctx, 'Reset##res_Inactive pad default') then EXT.UI_colRGBA_paddefaultbackgr_inactive = UI.def_colRGBA_paddefaultbackgr_inactive self.process.ext.save() end
        --ctrls
        local retval, col_rgba = ImGui.ColorEdit4( ctx, 'Pad buttons backgr', EXT.UI_colRGBA_padctrl, ImGui.ColorEditFlags_AlphaBar |ImGui.ColorEditFlags_NoInputs)  
        if retval then EXT.UI_colRGBA_padctrl = col_rgba end if ImGui.IsItemDeactivatedAfterEdit(ctx) then self.process.ext.save()  end
        ImGui.SameLine(ctx)if ImGui.Button(ctx, 'Reset##res_Pad buttons backgr') then EXT.UI_colRGBA_padctrl = UI.def_colRGBA_padctrl self.process.ext.save() end
        --ctrls
        local retval, col_rgba = ImGui.ColorEdit4( ctx, 'Sampler peaks backgr', EXT.UI_colRGBA_smplrbackgr, ImGui.ColorEditFlags_AlphaBar|ImGui.ColorEditFlags_NoInputs )  
        if retval then EXT.UI_colRGBA_smplrbackgr = col_rgba end if ImGui.IsItemDeactivatedAfterEdit(ctx) then self.process.ext.save()  end
        ImGui.SameLine(ctx)if ImGui.Button(ctx, 'Reset##res_Sampler peaks backgr') then EXT.UI_colRGBA_smplrbackgr = UI.colRGBA_smplrbackgr self.process.ext.save() end  
        
        --UI_colRGBA_maintheme
        local retval, col_rgba = ImGui.ColorEdit4( ctx, 'Various elements color', EXT.UI_colRGBA_maintheme, ImGui.ColorEditFlags_AlphaBar|ImGui.ColorEditFlags_NoInputs )  
        if retval then EXT.UI_colRGBA_maintheme = col_rgba end if ImGui.IsItemDeactivatedAfterEdit(ctx) then self.process.ext.save()  end
        ImGui.SameLine(ctx)if ImGui.Button(ctx, 'Reset##UI_colRGBA_maintheme') then EXT.UI_colRGBA_maintheme = EXT.defaults.UI_colRGBA_maintheme self.process.ext.save() end      
        
        
        
          
        ImGui.Unindent(ctx,self.var.UI_linear.menu_indentX)
      end    
    end
      --------------------------------------------------------------------------------
    f unction UI.draw_tabs_settings_Autoslice()
      if ImGui.CollapsingHeader(ctx, 'Auto slice loop on pad drop') then 
        ImGui.Indent(ctx,self.var.UI_linear.menu_indentX)
        
        if ImGui.Checkbox( ctx, 'Use Autoslice',                             self.ext.cur.CONF_loopcheck == 1 ) then self.ext.cur.CONF_loopcheck =self.ext.cur.CONF_loopcheck~1 self.process.ext.save() end
        local retval, v, buf
        if self.ext.cur.CONF_loopcheck&1==0 then goto skipset end
        
        -- min
         retval, v = ImGui.SliderDouble( ctx, 'Minimum loop length##CONF_loopcheck_minlen', self.ext.cur.CONF_loopcheck_minlen, 0.5, self.ext.cur.CONF_loopcheck_maxlen, '%.4fsec', ImGui.SliderFlags_None )
        if retval then self.ext.cur.CONF_loopcheck_minlen = v end if ImGui.IsItemDeactivatedAfterEdit(ctx) then self.process.ext.save()  end
        if ImGui_IsItemClicked(ctx, ImGui.MouseButton_Right) then self.ext.cur.CONF_loopcheck_minlen = 2 self.process.ext.save() end
        -- min
         retval, v = ImGui.SliderDouble( ctx, 'Maximum loop length##CONF_loopcheck_maxlen', self.ext.cur.CONF_loopcheck_maxlen, self.ext.cur.CONF_loopcheck_minlen, 16, '%.4fsec', ImGui.SliderFlags_None )
        if retval then self.ext.cur.CONF_loopcheck_maxlen = v end if ImGui.IsItemDeactivatedAfterEdit(ctx) then self.process.ext.save()  end
        if ImGui_IsItemClicked(ctx, ImGui.MouseButton_Right) then self.ext.cur.CONF_loopcheck_maxlen = 8 self.process.ext.save() end      
        
        -- filt 
        retval, buf = reaper.ImGui_InputText( ctx, 'Filter', self.ext.cur.CONF_loopcheck_filter, reaper.ImGui_InputTextFlags_None() )ImGui.SameLine(ctx) self.ImGui.Custom_HelpMarker('Do not auto slice samples containing words in name')
        if retval then self.ext.cur.CONF_loopcheck_filter = buf end
        if ImGui.IsItemDeactivatedAfterEdit(ctx) then self.process.ext.save() end
        
        
        
        
        ::skipset::
        ImGui.Unindent(ctx,self.var.UI_linear.menu_indentX)
      end  
    end
    --------------------------------------------------------------------------------    
    f unction UI.draw_tabs_settings_StepSequencer()
      if ImGui.CollapsingHeader(ctx, 'Step Sequencer') then  
        ImGui.Indent(ctx,self.var.UI_linear.menu_indentX)
        
        if ImGui.Checkbox( ctx, 'Share data to same pattern GUIDs',                             self.ext.cur.CONF_seq_force_GUIDbasedsharing == 1 ) then self.ext.cur.CONF_seq_force_GUIDbasedsharing =self.ext.cur.CONF_seq_force_GUIDbasedsharing~1 self.process.ext.save() end
        ImGui.SameLine(ctx) self.ImGui.Custom_HelpMarker('This setting require StepSequencer restart')
        
        if ImGui.Checkbox( ctx, 'Use ascending order of intruments',                             self.ext.cur.CONF_seq_instrumentsorder == 1 ) then self.ext.cur.CONF_seq_instrumentsorder =self.ext.cur.CONF_seq_instrumentsorder~1 self.process.ext.save() end
        ImGui.SameLine(ctx) self.ImGui.Custom_HelpMarker('This setting require StepSequencer restart')
        
        if ImGui.Checkbox( ctx, 'Clamp envelopes at active steps only',                             self.ext.cur.CONF_seq_env_clamp == 1 ) then self.ext.cur.CONF_seq_env_clamp =self.ext.cur.CONF_seq_env_clamp~1 self.process.ext.save() end
        ImGui.SameLine(ctx) self.ImGui.Custom_HelpMarker('This setting require StepSequencer restart')
        
        if ImGui.Checkbox( ctx, 'Auto legato',                                                   self.ext.cur.CONF_seq_autolegato == 1 ) then self.ext.cur.CONF_seq_autolegato =self.ext.cur.CONF_seq_autolegato~1 self.process.ext.save() end
        ImGui.SameLine(ctx) self.ImGui.Custom_HelpMarker('This setting require StepSequencer restart')
        
        local map  ={
          [-1] = 'Follow pattern length',
          [16] = '16 steps'
        }
        --ImGui.SetNextItemWidth(ctx, -1)
        if ImGui.BeginCombo( ctx, 'Default steps count##defcntsteps', map[self.ext.cur.CONF_seq_defaultstepcnt], ImGui.ComboFlags_None ) then
          for val in pairs(map) do
            if ImGui.Selectable( ctx, map[val], false, ImGui.SelectableFlags_None) then 
              self.ext.cur.CONF_seq_defaultstepcnt = val
              self.process.ext.save()
            end
          end
          ImGui.EndCombo( ctx )
        end
        
        
       -- 
        
        ImGui.Unindent(ctx,self.var.UI_linear.menu_indentX)
      end  
    
    end
    ---------------------------------------------------------------------------------------------------------------------------------    
    f unction UI.Launchpad_drumrackhelp()
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
      
  This setting will be used for newly created MIDI buses. So if you already have rack ready to play, you can apply pre-defined LaunchPad output manually in MIDI bus track routing or here:] ])ImGui.EndDisabled(ctx)
        
        
        
        local buttxt = 'Set MIDI Hardware output for MIDI bus'
        if self.var.ext.CONF_midioutput.current == -1 then 
          ImGui.BeginDisabled(ctx,true) 
          buttxt = '[no MIDI Hardware output for MIDI bus set]'
        end
        if ImGui.Button(ctx, buttxt) then 
          if DATA.MIDIbus.valid == true and DATA.MIDIbus.tr_ptr then SetMediaTrackInfo_Value( DATA.MIDIbus.tr_ptr, 'I_MIDIHWOUT', self.var.ext.CONF_midioutput.current<<5) end
        end
        if self.var.ext.CONF_midioutput.current == -1 then ImGui.EndDisabled(ctx) end
        
        
        
        ImGui.BeginDisabled(ctx,true) ImGui.TextWrapped(ctx, [[
        
  You can then light up pads using just "normal" MIDI output.
  MIDI bus will send same MIDI it sends to tracks, which will light up related pads.
  
  
  BUT if you use step sequencer you have to turn this MIDI Hardware output OFF. Other
      ] ]) ImGui.EndDisabled(ctx)
      
      
      ImGui.Unindent(ctx,10)
    end
    
    ---------------------------------------------------------------------------------------------------------------------------------    
    f unction UI.draw_tabs_settings_Launchpad()
      if ImGui.CollapsingHeader(ctx, 'Launchpad') then 
        ImGui.Indent(ctx,self.var.UI_linear.menu_indentX)
        --[[--local retval, p_visible = reaper.ImGui_CollapsingHeader( ctx, 'Drum Rack setup' )
        --if retval then UI.Launchpad_drumrackhelp() end
        UI.Launchpad_drumrackhelp()] ]
        ImGui.Unindent(ctx,self.var.UI_linear.menu_indentX)
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
          pady = racky + rackh - padh * (1+ypos0basedID ) - self.var.UI_linear.spacingY
        end
        
        
         
        padID0 = padID0 + 1
      end
      ] ]
      
  
      --[[local padID0 = 0
      local xpos0basedID_shift = 0
      local ypos0basedID_shift = 0
      for pad = 1, cell_cnt_max do  
      
        local xpos0basedID = padID0%col_cnt
        local padx = rackx + padw * xpos0basedID  
        local ypos0basedID = math.floor(padID0 / col_cnt) + ypos0basedID_shift
        local pady = racky + padh * ypos0basedID
        
        if toptobottom == 0 then
          pady = racky + rackh - padh * (1+ypos0basedID ) - self.var.UI_linear.spacingY
        end
        
        local mapped_note = mapping[pad] 
        UI.draw_Rack_Pads_controls(self.var.rack.children[note][mapped_note], mapped_note, padx, pady, padw, padh) 
        padID0 = padID0 + 1
      end
      ] ]
      
      
    end
   
    
    -------------------------------------------------------------------------------- 
    f unction UI.draw_chokecombo(note)
      
      if DATA.allow_container_usage ~= true then ImGui.BeginDisabled(ctx, true) end
      
      ImGui.SeparatorText(ctx, 'Choke setup')
      ImGui.Indent(ctx, 10)
      local preview = 'Cut by '
      for note_src in self.utils.spairs(self.var.rack.children[note]) do
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
        for note_src in self.utils.spairs(self.var.rack.children[note]) do
          if note_src ~= note then 
            local padname = self.var.rack.children[note][note_src].P_NAME
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
    f unction UI.draw_popups_pad()
      if DATA.trig_context == 'pad' and DATA.parent_track and DATA.parent_track.ext and self.var.rack.var.LASTACTIVENOTE  then 
        ImGui.SeparatorText(ctx, 'Pad '..self.var.rack.var.LASTACTIVENOTE)
        
        -- local Rename
        ImGui.Indent(ctx, 10)
        local retval, buf = ImGui_InputText( ctx, '##custpadnameinputparent', DATA.parent_track.padcustomnames_overrides[self.var.rack.var.LASTACTIVENOTE], ImGui_InputTextFlags_None() )
        if retval then 
          DATA.parent_track.padcustomnames_overrides[self.var.rack.var.LASTACTIVENOTE] = buf
          DATA:WriteData_Parent() 
          DATA.upd = true
        end
        ImGui.Unindent(ctx, 10) 
        
        -- Remove
        local note = self.var.rack.var.LASTACTIVENOTE 
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
        if ImGui.Checkbox(ctx, 'Remove source item from track', self.ext.cur.CONF_importselitems_removesource==1) then self.ext.cur.CONF_importselitems_removesource=self.ext.cur.CONF_importselitems_removesource~1 self.process.ext.save() end
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
    f unction UI.draw_popups() 
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
    f unction UI.draw_popups_rs5k_ctrl()  
      
      if not (DATA.trig_context == 'rs5k_ctrl' and DATA.parent_track and DATA.parent_track.ext and self.var.rack.var.LASTACTIVENOTE) then return end 
      
      local note =  self.var.rack.var.LASTACTIVENOTE
      local layer =  self.var.rack.var.LASTACTIVENOTE_LAYER 
      
      if not (DATA.parent_track.macro and DATA.parent_track.macro.sliders) then 
        reaper.ImGui_TextDisabled(ctx, 'Macro links')
        return 
      end
      
      
      local track, fx, param
      if self.var.rack.children[note] and self.var.rack.children[note].layers and self.var.rack.children[note].layers[layer] then
        track =    self.var.rack.children[note].layers[layer].tr_ptr
        fx = self.var.rack.children[note].layers[layer].instrument_pos
      end 
      
      if DATA.trig_openpopup_context == 'gain' then param = self.var.rack.children[note].layers[layer].instrument_volID end 
      if DATA.trig_openpopup_context == 'attack' then param = self.var.rack.children[note].layers[layer].instrument_attackID end
      if DATA.trig_openpopup_context == 'decay' then param = self.var.rack.children[note].layers[layer].instrument_decayID end 
      if DATA.trig_openpopup_context == 'sustain' then param = self.var.rack.children[note].layers[layer].instrument_sustainID end 
      if DATA.trig_openpopup_context == 'release' then param = self.var.rack.children[note].layers[layer].instrument_releaseID end
      
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
        ImGui.SeparatorText(ctx, 'Pad '..self.var.rack.var.LASTACTIVENOTE..': '..DATA.trig_openpopup_context)  
        if ImGui.Button(ctx,'Remove from macro '..destslider) then 
          Undo_BeginBlock2(self.var.proj )
          TrackFX_SetNamedConfigParm(track, fx, 'param.'..param..'plink.active', 0)
          Undo_EndBlock2( self.var.proj , 'RS5k manager - Remove link', 0xFFFFFFFF ) 
          ImGui.CloseCurrentPopup(ctx)
        end 
      end
      
      ImGui.SeparatorText(ctx, 'Link to macro')
      for macro = 1, DATA.parent_track.ext.PARENT_MACROCNT do
        if not destslider or (destslider and macro ~= destslider) then
          if ImGui.Selectable(ctx,'Link to macro '..macro) then 
            TrackFX_SetNamedConfigParm( track, fx, 'last_touched',param )
            self.var.rack.var.LASTACTIVEMACRO = macro
            self.process.rack.macro.add_link()
            ImGui.CloseCurrentPopup(ctx)
          end
        end
      end
      
    end
    --------------------------------------------------------------------------------  
    f unction UI.draw_tabs_Sampler_trackparams()
      local butw = 40
      local butw_3x = (butw)*3+self.var.UI_linear.spacingX*2
      if not (DATA.parent_track and DATA.parent_track.valid == true) then return end
      
      local note_layer_t,note,layer = DATA:Sampler_GetActiveNoteLayer() if not note_layer_t then return end 
      if self.var.rack.children[note].TYPE_DEVICE then note_layer_t = self.var.rack.children[note] end
      
      
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
    f unction UI.draw_tabs()
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
          
          f unction __f_tabs() end
          
          
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
              end ] ]
            end
            
            x1, y1 = reaper.ImGui_GetItemRectMin( ctx )
            x2, y2 = reaper.ImGui_GetItemRectMax( ctx )
            local checkbox_h = 16
            local checkbox_r = math.floor(checkbox_h / 2)
            local center_x = x1
            local center_y = math.floor(y1 + (y2-y1)/2 )-1
            local colfill = 0xF0F0F04F
            if steseqavailable == true and ImGui_IsItemHovered(ctx) then colfill = 0xF0F0F09F end
            ImGui.DrawList_AddCircle( self.draw.drawlist, center_x, center_y, checkbox_r, 0xF0F0F07F, 0, 2 )
            ImGui.DrawList_AddCircleFilled( self.draw.drawlist, center_x, center_y, checkbox_r-3, colfill, 0 ) 
            ImGui.SetCursorPos(ctx,xoffs+checkbox_r+ self.var.UI_linear.spacingX,2)
            if steseqavailable == true then ImGui.Text(ctx, 'StepSequencer') else ImGui.TextDisabled(ctx, 'StepSequencer') end
              
          
          
          ImGui.EndTabBar( ctx)
        end
        
          
        ImGui.Dummy(ctx,0,0)
        
        
        ImGui.EndChild( ctx)
      end
    end 
    
  -------------------------------------------------------------------------------- 
    f unction DATA:Action_FixMetadata()
      local parent_track = GetSelectedTrack(-1,0)
      
      -- force current GUID to metadta
        local curGUID = reaper.GetTrackGUID( parent_track )
        GetSetMediaTrackInfo_String ( parent_track, 'P_EXT:MPLRS5KMAN_GUIDINTERNAL', curGUID, true) 
        DATA:CollectData_Parent()
        
      -- loop through children and 
        for i = DATA.parent_track.IP_TRACKNUMBER_0based+1, DATA.parent_track.IP_TRACKNUMBER_0basedlast do 
          local track = GetTrack(self.var.proj, i) 
          GetSetMediaTrackInfo_String( track, 'P_EXT:MPLRS5KMAN_CHILD_PARENTGUID', curGUID, true)  -- change their parent GUID 
          local fx_instr = TrackFX_GetInstrument( track )
          local fx_instrGUID = reaper.TrackFX_GetFXGUID( track, fx_instr )
          if fx_instrGUID then GetSetMediaTrackInfo_String( track, 'P_EXT:MPLRS5KMAN_CHILD_INSTR_FXGUID', fx_instrGUID, true) end
        end
        
    end
  -------------------------------------------------------------------------------- 
    f unction UI.draw_FixingMetadata() 
      f unction __b_draw_FixingMetadata() end 
      ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowPadding,0,0)  
      ImGui.PushStyleVar(ctx, ImGui.StyleVar_ItemSpacing,0,0)
      ImGui.SetCursorScreenPos(ctx,UI.calc_rackX,UI.calc_rackY)
      if ImGui.BeginChild( ctx, 'FixingMetadata_modal', UI.calc_rackW, 0, ImGui.ChildFlags_Border, ImGui.WindowFlags_None |ImGui.WindowFlags_NoScrollbar ) then--|ImGui.ChildFlags_Border --|ImGui.WindowFlags_MenuBar
        ImGui.TextWrapped(ctx,
            [[
            
            
      This rack was probably imported from template. Select parent track and        
            ] ]) --ImGui.SameLine(ctx) 
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
    f unction UI.draw()  
      
      
      if DATA.VCA_mode == 0 then 
        UI.knob_handle  = UI.knob_handle_normal 
       elseif DATA.VCA_mode == 1 then 
        UI.knob_handle = UI.knob_handle_vca
       elseif DATA.VCA_mode == 2 then 
        UI.knob_handle = UI.knob_handle_vca2       
      end
      
      local closew
      if (DATA.parent_track and DATA.parent_track.valid == true) and UI.calc_padoverviewW and UI.hide_padoverview ~= true then closew = UI.calc_padoverviewW-self.var.UI_linear.spacingX*2  end
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
          ImGui.Dummy(ctx,0, self.var.UI_linear.spacingY)
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
    f unction UI.draw_tabs_Sampler_ADSR(note_layer_t, x10,y10,x20,y20) 
      if note_layer_t.ISRS5K ~= true then return end
      local rect_sz = UI.adsr_rectsz
      local x1,y1,x2,y2 = x10+rect_sz,y10+rect_sz,x20-rect_sz,y20-rect_sz -- effective area
      ImGui.PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameRounding(), 1)
      ImGui.PushStyleColor(ctx, reaper.ImGui_Col_Button(),        (EXT.UI_colRGBA_maintheme&0xFFFFFF00)|0x90)
      ImGui.PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(),  (EXT.UI_colRGBA_maintheme&0xFFFFFF00)|0xB0)
      ImGui.PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), (EXT.UI_colRGBA_maintheme&0xFFFFFF00)|0xF0)
      
      -- test
      ImGui.DrawList_AddRectFilled( self.draw.drawlist, x10,y10,x20,y20, EXT.UI_colRGBA_smplrbackgr, 2, ImGui.DrawFlags_None )
      
      
      --ImGui.DrawList_AddRectFilled( self.draw.drawlist, x1,y1,x2,y2, 0xFFFFFF0F, 2, ImGui.DrawFlags_None )
      
      -- attack
      UI.draw_tabs_Sampler_ADSR_points(note_layer_t, x10,y10,x20,y20) 
      
      ImGui.PopStyleVar(ctx)
      ImGui.PopStyleColor(ctx,3)
    end
    --------------------------------------------------------------------------------
    f unction UI.draw_tabs_Sampler_BoundaryEdges(note_layer_t, x10,y10,x20,y20) 
      if note_layer_t.ISRS5K ~= true then return end
      local note = note_layer_t.noteID
      -- backgr fill
      ImGui.DrawList_AddRectFilled( self.draw.drawlist, x10,y10,x20,y20, 0xFFFFFF0C, 2, ImGui.DrawFlags_None )
      
      -- backgr work area
      local samplestoffs = note_layer_t.instrument_samplestoffs
      local sampleendoffs = note_layer_t.instrument_sampleendoffs
      local w = x20-x10
      local pos1=  math.floor(x10+w*samplestoffs)
      local pos2=  math.floor(x10+w*sampleendoffs )
      local rect_sz = UI.adsr_rectsz
      
      ImGui.DrawList_AddRectFilled( self.draw.drawlist,pos1,y10,pos2,y20, 0x00FF001F, 2, ImGui.DrawFlags_None )
      
      ImGui.DrawList_AddTriangleFilled(  self.draw.drawlist, 
        pos1, y10, 
        pos1+rect_sz, y10, 
        pos1, y10+rect_sz, 
        (EXT.UI_colRGBA_maintheme&0xFFFFFF00)|0x90 )
        
        
      ImGui.DrawList_AddTriangleFilled(  self.draw.drawlist, 
        pos2-rect_sz, y20, 
        pos2, y20-rect_sz, 
        pos2, y20,  
        (EXT.UI_colRGBA_maintheme&0xFFFFFF00)|0x90 )
      
      
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
    f unction UI.draw_tabs_Sampler_ADSR_point_getpos(x1,y1,x2,y2, xpos, ypos, centered)  
      if not xpos then return end
      if not centered then 
        return x1 + (x2-x1-UI.adsr_rectsz)*xpos, y1 + (y2-y1-UI.adsr_rectsz)*(1-ypos)
       else
        return x1 + (x2-x1-UI.adsr_rectsz)*xpos+UI.adsr_rectsz/2, y1 + (y2-y1-UI.adsr_rectsz)*(1-ypos)+UI.adsr_rectsz/2
      end
    end
      --------------------------------------------------------------------------------
    f unction UI.draw_tabs_Sampler_ADSR_points(note_layer_t, x1,y1,x2,y2)  
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
        ] ]
        DATA:CollectData_Children_InstrumentParams(note_layer_t,true) -- minor refresh formatted values 
      end        
      
      -- delay - attack line 
      ImGui.DrawList_AddLine( self.draw.drawlist,xpos_del + UI.adsr_rectsz/2, ypos_del + UI.adsr_rectsz/2,xpos_att + UI.adsr_rectsz/2, ypos_att + UI.adsr_rectsz/2, (EXT.UI_colRGBA_maintheme&0xFFFFFF00)|0x90, 2 )
          
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
      ImGui.DrawList_AddLine( self.draw.drawlist,xpos_att + UI.adsr_rectsz/2, ypos_att + UI.adsr_rectsz/2, xpos_dec + UI.adsr_rectsz/2, ypos_dec + UI.adsr_rectsz/2, (EXT.UI_colRGBA_maintheme&0xFFFFFF00)|0x90, 2 )
      
      
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
      ImGui.DrawList_AddLine( self.draw.drawlist,xpos_dec + UI.adsr_rectsz/2, ypos_dec + UI.adsr_rectsz/2, xpos_rel + UI.adsr_rectsz/2, ypos_rel + UI.adsr_rectsz/2, (EXT.UI_colRGBA_maintheme&0xFFFFFF00)|0x90, 2 )
      
      
      
      -- loop offs
      if note_layer_t.instrument_loop == 1 then
        local loopoffs = note_layer_t.instrument_loopoffs_norm
        local rect_sz = UI.adsr_rectsz
        local pos1 = x1+(x2-x1) * loopoffs + self.var.UI_linear.spacingX
        ImGui.DrawList_AddTriangleFilled(  self.draw.drawlist, 
          pos1-rect_sz, y1, 
          pos1, y1, 
          pos1, y1+rect_sz, 
          (EXT.UI_colRGBA_maintheme&0xFFFFFF00)|0x90 )
          
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
    f unction UI.draw_tabs_Sampler_tabs()
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
    f unction UI.draw_tabs_Sampler_tabs_boundary()
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
        self.ext.child.set(track, {
          SET_SAMPLEBPM = tonumber(buf),
        }) 
        DATA.upd = true
      end
      
      
      ImGui.SetCursorScreenPos(ctx, curposx_abs + (UI.calc_knob_w_small + self.var.UI_linear.spacingX)*2, curposy_abs)
      if ImGui.BeginChild(ctx,'tabsbar_sampler_boundarychild', 0,0,reaper.ImGui_ChildFlags_Border()) then
        if ImGui.BeginTabBar( ctx, '##tabsbar_sampler_boundary', ImGui.TabItemFlags_None ) then 
          
          -- start offset
          if ImGui.BeginTabItem( ctx, 'Start offset##sampler_boundary_Start', false, ImGui.TabItemFlags_None ) then
            local formatIn = DATA.boundarystep[self.ext.cur.CONF_stepmode].str
            reaper.ImGui_SetNextItemWidth(ctx, 100)
            local retval, v = reaper.ImGui_SliderInt( ctx, 'Step##shiftboundary', self.ext.cur.CONF_stepmode, 0, #DATA.boundarystep, formatIn, ImGui.SliderFlags_None )
            if retval then self.ext.cur.CONF_stepmode = v end if reaper.ImGui_IsItemDeactivatedAfterEdit(ctx) then self.process.ext.save() end
            if self.ext.cur.CONF_stepmode == 10 then
              ImGui.SameLine(ctx)
              reaper.ImGui_SetNextItemWidth(ctx, 100)
              local retval, v = reaper.ImGui_SliderDouble( ctx, 'ahead##shiftboundary_ahead', self.ext.cur.CONF_stepmode_transientahead, 0, 0.1, '%.3f sec', ImGui.SliderFlags_None )
              if retval then self.ext.cur.CONF_stepmode_transientahead = v end if reaper.ImGui_IsItemDeactivatedAfterEdit(ctx) then self.process.ext.save() end
            end
            local retval, v = ImGui.Checkbox( ctx, 'Keep slice length', self.ext.cur.CONF_stepmode_keeplen==1 )
            if retval then self.ext.cur.CONF_stepmode_keeplen=self.ext.cur.CONF_stepmode_keeplen~1 self.process.ext.save() end  
            
            if self.ext.cur.CONF_stepmode ~= 10 then
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
            local formatIn = DATA.boundarystep[self.ext.cur.CONF_stepmode].str
            reaper.ImGui_SetNextItemWidth(ctx, 100)
            local retval, v = reaper.ImGui_SliderInt( ctx, 'Step##shiftboundaryenf', self.ext.cur.CONF_stepmode, 0, #DATA.boundarystep, formatIn, ImGui.SliderFlags_None )
            if retval then self.ext.cur.CONF_stepmode = v end if reaper.ImGui_IsItemDeactivatedAfterEdit(ctx) then self.process.ext.save() end
            if self.ext.cur.CONF_stepmode == 10 then
              ImGui.SameLine(ctx)
              reaper.ImGui_SetNextItemWidth(ctx, 100)
              local retval, v = reaper.ImGui_SliderDouble( ctx, 'ahead##shiftboundary_ahead', self.ext.cur.CONF_stepmode_transientahead, 0, 0.1, '%.3f sec', ImGui.SliderFlags_None )
              if retval then self.ext.cur.CONF_stepmode_transientahead = v end if reaper.ImGui_IsItemDeactivatedAfterEdit(ctx) then self.process.ext.save() end
            end
            local retval, v = ImGui.Checkbox( ctx, 'Keep slice length', self.ext.cur.CONF_stepmode_keeplen==1 )
            if retval then self.ext.cur.CONF_stepmode_keeplen=self.ext.cur.CONF_stepmode_keeplen~1 self.process.ext.save() end  
            
            if self.ext.cur.CONF_stepmode ~= 10 then
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
            local toolongsample =  note_layer_t.SAMPLELEN and note_layer_t.SAMPLELEN > self.ext.cur.CONF_crop_maxlen
            if toolongsample then ImGui.BeginDisabled(ctx,true) end
            if ImGui.Button( ctx, 'Crop sample') then DATA:Action_CropToAudibleBoundaries(note_layer_t) end 
            ImGui.SameLine(ctx)
            ImGui.SetNextItemWidth(ctx, 90) 
            local ret, v = ImGui.SliderDouble( ctx, 'Threshold##cropsplthresh', self.ext.cur.CONF_cropthreshold, -80, -10, '%.0f dB', ImGui.SliderFlags_None ) 
            if ret then self.ext.cur.CONF_cropthreshold = v end if reaper.ImGui_IsItemDeactivatedAfterEdit(ctx) then self.process.ext.save() end  -- Sampler: Crop threshold
            if toolongsample then ImGui.EndDisabled(ctx) end 
            
            ImGui.EndTabItem( ctx) 
          end
          ImGui.EndTabBar( ctx)
        end
        ImGui.EndChild(ctx)
      end
    end
    -----------------------------------------------------------------------------------------  
    f unction UI.draw_tabs_Sampler_tabs_FX()
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
        x = curposx_abs + UI.calc_knob_w_small + self.var.UI_linear.spacingX, 
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
      ImGui.SetCursorScreenPos(ctx,curposx_abs, curposy_abs+ UI.calc_knob_h_small+self.var.UI_linear.spacingY)
      
      ImGui.SetNextItemWidth(ctx, UI.calc_knob_w_small*2+self.var.UI_linear.spacingX)
      local preview_value = 'Filter OFF'
      if note_layer_t.fx_reaeq_bandenabled == true  then  preview_value = DATA.bandtypemap[note_layer_t.fx_reaeq_bandtype] end
      if ImGui.BeginCombo( ctx, '##filter', preview_value, ImGui.ComboFlags_None ) then
        for band_type_val in self.utils.spairs(DATA.bandtypemap) do
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
        x = curposx_abs + (UI.calc_knob_w_small + self.var.UI_linear.spacingX)*2, 
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
    f unction UI.draw_tabs_Sampler_tabs_3rdpartycontrols_store(x,y,note_layer_t,key)
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
    f unction UI.draw_tabs_Sampler_tabs_3rdpartycontrols()
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
      UI.draw_tabs_Sampler_tabs_3rdpartycontrols_store(curposx_abs,curposy_abs+UI.calc_knob_h_small+self.var.UI_linear.spacingY,note_layer_t,'instrument_volID')
      
      local xpos = curposx_abs + UI.calc_knob_w_small + self.var.UI_linear.spacingX
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
      UI.draw_tabs_Sampler_tabs_3rdpartycontrols_store(xpos,curposy_abs+UI.calc_knob_h_small+self.var.UI_linear.spacingY,note_layer_t,'instrument_tuneID')
      
      UI.draw_knob(
        {str_id = '##note_layer_instrument_attack',
        is_small_knob = true,
        val = note_layer_t.instrument_attack,
        x = curposx_abs + (UI.calc_knob_w_small + self.var.UI_linear.spacingX)*3, 
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
      UI.draw_tabs_Sampler_tabs_3rdpartycontrols_store(curposx_abs + (UI.calc_knob_w_small + self.var.UI_linear.spacingX)*3,curposy_abs+UI.calc_knob_h_small+self.var.UI_linear.spacingY,note_layer_t,'instrument_attackID')
      
      UI.draw_knob(
        {str_id = '##note_layer_instrument_decay',
        is_small_knob = true,
        val = note_layer_t.instrument_decay,
        x = curposx_abs + (UI.calc_knob_w_small + self.var.UI_linear.spacingX)*4, 
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
      UI.draw_tabs_Sampler_tabs_3rdpartycontrols_store(curposx_abs + (UI.calc_knob_w_small + self.var.UI_linear.spacingX)*4,curposy_abs+UI.calc_knob_h_small+self.var.UI_linear.spacingY,note_layer_t,'instrument_decayID')
          
      UI.draw_knob(
        {str_id = '##note_layer_instrument_sustain',
        is_small_knob = true,
        val = note_layer_t.instrument_sustain,
        x = curposx_abs + (UI.calc_knob_w_small + self.var.UI_linear.spacingX)*5, 
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
      UI.draw_tabs_Sampler_tabs_3rdpartycontrols_store(curposx_abs + (UI.calc_knob_w_small + self.var.UI_linear.spacingX)*5,curposy_abs+UI.calc_knob_h_small+self.var.UI_linear.spacingY,note_layer_t,'instrument_sustainID')
      
      UI.draw_knob(
        {str_id = '##note_layer_instrument_release',
        is_small_knob = true,
        val = note_layer_t.instrument_release,
        x = curposx_abs + (UI.calc_knob_w_small + self.var.UI_linear.spacingX)*6, 
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
      UI.draw_tabs_Sampler_tabs_3rdpartycontrols_store(curposx_abs + (UI.calc_knob_w_small + self.var.UI_linear.spacingX)*6,curposy_abs+UI.calc_knob_h_small+self.var.UI_linear.spacingY,note_layer_t,'instrument_releaseID')
    end  
      ----------------------------------------------------------------------------------------- 
    f unction UI.draw_tabs_Sampler_tabs_rs5kcontrols_tune(note_layer_t, val)
      local note_layer_t,note,layer = DATA:Sampler_GetActiveNoteLayer() if not note_layer_t then return end
      
      local out = note_layer_t.instrument_tune + val/160 
      note_layer_t.instrument_tune =v 
      TrackFX_SetParamNormalized( note_layer_t.tr_ptr, note_layer_t.instrument_pos, note_layer_t.instrument_tuneID, out )    
      DATA:CollectData_Children_InstrumentParams(note_layer_t,true) -- minor refresh formatted values
      
    end
    ---------------------------------------------------------------------  
    f unction UI.Drop_UI_interaction_device(note, layer) 
      -- validate is file or pad dropped
      local retval, count = ImGui.AcceptDragDropPayloadFiles( ctx, 127, ImGui.DragDropFlags_None )
      if not retval then return end
        
      Undo_BeginBlock2(self.var.proj )
      for i = 1, count do 
        local retval, filename = reaper.ImGui_GetDragDropPayloadFile( ctx, i-1 )
        if not retval then return end 
        DATA:DropSample(filename, note + i-1, {layer=layer})
      end 
      Undo_EndBlock2( self.var.proj , 'RS5k manager - drop samples to pads', 0xFFFFFFFF ) 
    
    end
    
    ---------------------------------------------------------------------  
    f unction UI.Drop_UI_interaction_sampler() 
      -- validate is file or pad dropped
      local retval, count = ImGui.AcceptDragDropPayloadFiles( ctx, 1, ImGui.DragDropFlags_None )
      if not retval then return end
      
      -- drop on sampler
      if self.var.rack.var.LASTACTIVENOTE and self.var.rack.var.LASTACTIVENOTE_LAYER then  
        local retval, filename = reaper.ImGui_GetDragDropPayloadFile( ctx, 0 )
        if retval then 
          local note_layer_t, note, layer = DATA:Sampler_GetActiveNoteLayer() if not note_layer_t then return end
          DATA:DropSample(filename, note, {layer=layer})
        end
      end
    end   
    --------------------------------------------------------------------------------
    f unction UI.draw_tabs_Sampler_tabs_device()
      local note_layer_t, note, layer0 = DATA:Sampler_GetActiveNoteLayer() if not note_layer_t then return end  
      
      
      if not (self.var.rack.children[note] and self.var.rack.children[note].TYPE_DEVICE== true) then ImGui.BeginDisabled(ctx, true) end
        local retval, v = ImGui.Checkbox( ctx, 'Autovelocity', self.var.rack.children[note].TYPE_DEVICE_AUTORANGE )
        ImGui.SameLine(ctx)
        self.ImGui.Custom_HelpMarker('Auto-set velocity range option enabled for new devices')
        if retval then 
          local tr = self.var.rack.children[note].tr_ptr
          local out = 0
          if v == true then out = 1 end
          self.ext.child.set(tr, {SET_MarkType_TYPE_DEVICE_AUTORANGE = out}) 
          DATA.upd = true
        end
        ImGui.SameLine(ctx)
        if ImGui.Button(ctx, 'Refresh##autosetvelrange', 80) then DATA:Auto_Device_RefreshVelocityRange(note) end
      if not (self.var.rack.children[note] and self.var.rack.children[note].TYPE_DEVICE== true) then ImGui.EndDisabled(ctx) end
      
      -- device drop 
      ImGui.SameLine(ctx)
      ImGui.Button(ctx, '[Drop layers]', 110)
      if ImGui.BeginDragDropTarget( ctx ) then  
        local cntlayers = 0
        if self.var.rack.children[note] and self.var.rack.children[note].layers then cntlayers = #self.var.rack.children[note].layers end
        UI.Drop_UI_interaction_device(note, cntlayers + 1)   
        ImGui_EndDragDropTarget( ctx )
      end
      
      -- device drop FX
      ImGui.SameLine(ctx)
      local cntlayers = 0
      if self.var.rack.children[note] and self.var.rack.children[note].layers then cntlayers = #self.var.rack.children[note].layers end
      local drop_data = {layer = cntlayers + 1}
      UI.draw_3rdpartyimport_context(note,drop_data) 
      
      
      if ImGui.BeginChild( ctx, 'device' ,0,-self.var.UI_linear.spacingY) then--,ImGui.ChildFlags_None, ImGui.WindowFlags_NoScrollWithMouse
        ImGui.PushStyleVar(ctx, ImGui.StyleVar_FramePadding,0,self.var.UI_linear.spacingY) 
        ImGui.PushStyleVar(ctx, ImGui.StyleVar_GrabMinSize,5)
        
        
        local name_w = 185
        local slider_w = 60
        
        
        --- layers list
        for layer = 1, #self.var.rack.children[note].layers do
          
          local posx,posy = ImGui.GetCursorPos(ctx)
          local layer_t = self.var.rack.children[note].layers[layer]
          
          -- name
          ImGui.SetNextItemWidth(ctx, name_w)
          if ImGui.Checkbox(ctx, '##layer'..layer, layer == layer0) then
            self.var.rack.var.LASTACTIVENOTE_LAYER = layer
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
            Undo_BeginBlock2(self.var.proj )
            local outval = 2 if layer_t.I_SOLO>0 then outval = 0 end SetMediaTrackInfo_Value( layer_t.tr_ptr, 'I_SOLO', outval ) DATA.upd = true
            Undo_EndBlock2( self.var.proj , 'RS5k manager - Solo pad', 0xFFFFFFFF ) 
          end 
          if layer_t.I_SOLO>0 then ImGui.PopStyleColor(ctx ) end
            
          -- mute
          ImGui.SameLine(ctx)
          if layer_t.B_MUTE>0 then ImGui.PushStyleColor(ctx, ImGui.Col_Text, 0xFF0000FF ) end
          if ImGui.Button(ctx, 'M##layerM'..layer, 23)  then
            Undo_BeginBlock2(self.var.proj )
            SetMediaTrackInfo_Value( layer_t.tr_ptr, 'B_MUTE', layer_t.B_MUTE~1 ) DATA.upd = true
            Undo_EndBlock2( self.var.proj , 'RS5k manager - Mute pad', 0xFFFFFFFF )         
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
    -----------------------------------------------------------------------------------------  
    f unction mpl_FixExtStateINI()
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
    f unction literalize(str) -- http://stackoverflow.com/questions/1745448/lua-plain-string-gsub
       if str then  return str:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", function(c) return "%" .. c end) end
    end 
    
    
      --[[-------------------------------------------------------------------  
      f unction DATA:Launchpad_StuffSysex(SysEx_msg, mon_state0) 
        local mon_state = 0 if mon_state0 then mon_state = mon_state0 end
        if  DATA.MIDIbus and DATA.MIDIbus.tr_ptr and DATA.MIDIbus.valid == true then SetMediaTrackInfo_Value( DATA.MIDIbus.tr_ptr, 'I_RECMON', mon_state ) end -- prevent 
            
        if SysEx_msg and self.var.ext.CONF_midioutput.current and self.var.ext.CONF_midioutput.current ~=-1  then 
          local SysEx_msg_bin = '' for hex in SysEx_msg:gmatch('[A-F,0-9]+') do  SysEx_msg_bin = SysEx_msg_bin..string.char(tonumber(hex, 16)) end 
          SendMIDIMessageToHardware(self.var.ext.CONF_midioutput.current, SysEx_msg_bin)   
        end
      end  ] ]
      
      -------------------------------------------------------------------------------  
      f unction DATA:CollectData_Seq_ConvertMIDI2Steps() 
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
      f unction DATA:_Seq_PrintEnvelopes_GetEnvByParamName(track, param) local seq_envelope
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
            local ret,tr, fxid = VF_GetFXByGUID(fxGUID, track, self.var.proj)
            if fxid then
              local retval, minval, maxval = reaper.TrackFX_GetParam( track, fxid, paramID)
              seq_envelope = GetFXEnvelope( track, fxid, paramID, true )
              if seq_envelope then  return seq_envelope, GetEnvelopeScalingMode( seq_envelope ),minval, maxval end
            end
          end
        end
        
        
      
      end
      --------------------------------------------------------------------------------  
      f unction DATA:_Seq_PrintEnvelopes_writesteps(param_t, note)
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
              if self.ext.cur.CONF_seq_env_clamp == 0 then allow_empty_steps = true end
              
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
              local point_pos = TimeMap2_beatsToTime(   self.var.proj, t.it_pos_fullbeats + beatpos_st )  
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
      f unction DATA:_Seq_PrintEnvelopes_note(note)
        if not (self.var.rack.children[note] and DATA.seq.ext.children[note].steps and DATA.seq.ext.children[note].steps[0]) then return end -- 0 as a step check for existing params
        
        local srctr = self.var.rack.children[note].tr_ptr 
        
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
      f unction DATA:_Seq_PrintEnvelopes(t)
        if not (t.ext and t.ext.children) then return end
        for note in pairs(t.ext.children) do DATA:_Seq_PrintEnvelopes_note(note, seqstart_fullbeats) end 
      end 
      --------------------------------------------------------------------------------   
      f unction DATA:_Seq_FXremove(note, parameter)
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
      f unction DATA:_Seq_AddLastTouchedFX() 
        local retval, trackidx, itemidx, takeidx, fxidx, parm = GetTouchedOrFocusedFX( 0 )
        if not retval then return end
        local track = GetTrack(self.var.proj,trackidx)
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
      f unction DATA:_Seq_Clear(note)
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
      f unction DATA:_Seq_FillNoteStepsToFullLength(note)   --Print to full pattern length 
      
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
      f unction DATA:_Seq_Fill(note, pat)
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
      f unction DATA:_Seq_Print(do_not_ignore_empty, minor_change) 
        if not (DATA.MIDIbus and DATA.MIDIbus.tr_ptr and DATA.MIDIbus.valid) then return end
        if not (DATA.seq.it_ptr and DATA.seq.tk_ptr) then return end
        if not DATA.seq.ext.children then return end 
        local item = DATA.seq.it_ptr
        local take = DATA.seq.tk_ptr
        if not (take and ValidatePtr2(self.var.proj, take, 'MediaItem_Take*')) then DATA.seq = nil return end
        
        
        if minor_change~=true then 
          Undo_BeginBlock2(self.var.proj)
          --test = time_precise()
          local outstr = table.savestring(DATA.seq.ext) --outstr = VF_encBase64(outstr) -- 4.43 off 
          GetSetMediaItemTakeInfo_String( take, 'P_EXT:MPLRS5KMAN_PATDATA', outstr, true)
          GetSetMediaItemTakeInfo_String( take, 'P_EXT:MPLRS5KMAN_PATDATA_IGNOREB64', 1, true) -- 4.43 patch DO NOT REMOVE
          --msg(os.date()..' '..time_precise()-test)
          DATA:_Seq_PrintMIDI_ShareGUID(DATA.seq ,outstr) -- store pattern data to the same GUID takes 
          Undo_EndBlock2(self.var.proj, 'Pattern edit', 0xFFFFFFFF)
          
          
        end 
        DATA:_Seq_PrintEnvelopes(DATA.seq)
        DATA:_Seq_PrintMIDI(DATA.seq) 
        GetSetMediaItemTakeInfo_String( take, 'P_EXT:MPLRS5KMAN_PATGUID', DATA.seq.ext.GUID, true) 
        
      end
      --------------------------------------------------------------------------------  
      f unction DATA:_Seq_PrintMIDI_ShareGUID(parent_t ,outstr) 
        if self.ext.cur.CONF_seq_force_GUIDbasedsharing~= 1 then return end
        
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
      f unction self.utils.math_q(num)  if math.abs(num - math.floor(num)) < math.abs(num - math.ceil(num)) then return math.floor(num) else return math.ceil(num) end end
      --------------------------------------------------------------------------------  
      f unction DATA:Auto_LoopSlice_CreatePattern(loop_t) 
        if not loop_t then return end
        local slicecnt = math.min(16,#loop_t)
        
        DATA:_Seq_Insert(true)
        DATA:CollectData() -- to refresh note existing data
        if not DATA.seq.ext then DATA.seq.ext = {} end 
        if not DATA.seq.ext.children then DATA.seq.ext.children = {} end 
        f unction __f_slice2pattern_modloopt() end
        
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
      f unction DATA:_Seq_Insert(skip_seqcheck) 
        if not (DATA.MIDIbus and DATA.MIDIbus.tr_ptr and DATA.MIDIbus.valid) then return end
        local track = DATA.MIDIbus.tr_ptr
        local curpos = GetCursorPosition()
        
        -- get quantized pos
        local retval, measures, cml, fullbeats, cdenom = reaper.TimeMap2_timeToBeats( self.var.proj, curpos )
        local posst = TimeMap2_beatsToTime(  self.var.proj, 0, measures )
        local posend = TimeMap2_beatsToTime(  self.var.proj, 0, measures+1)
        
        local item = CreateNewMIDIItemInProj( track, posst, posend )
        SelectAllMediaItems( self.var.proj, false )
        SetMediaItemSelected( item, true )
        SetMediaItemInfo_Value( item, 'B_LOOPSRC',1 )
        
        UpdateItemInProject(item)
        DATA:CollectData_Seq(skip_seqcheck) 
      end
      
      --------------------------------------------------------------------------------  
      f unction DATA:_Seq_ModifyTools(note, mode, dir) 
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
            if rand <= self.ext.cur.CONF_seq_random_probability then val = 1 else val = 0 end 
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
      f unction DATA:_Seq_PrintMIDI(t, do_not_ignore_empty, overrides) 
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
        local _, _, _ seqstart_fullbeats = reaper.TimeMap2_timeToBeats( self.var.proj, item_pos ) 
        local seqend_sec = TimeMap2_beatsToTime(     self.var.proj, seqstart_fullbeats + DATA.seq.ext.patternlen *steplength ) 
        local seqend_endppq = MIDI_GetPPQPosFromProjTime( take, seqend_sec) 
        t.seqend_endppq = seqend_endppq -- send to childs export
        
        -- form table
        for note in pairs(t.ext.children) do
          
          if not self.var.rack.children[note] then goto skipnextnote end
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
            if t.ext.children[note].steps[step_active].split then split = self.utils.math_q(t.ext.children[note].steps[step_active].split) end 
            
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
            
            
            local steppos_start_sec = TimeMap2_beatsToTime(   self.var.proj, seqstart_fullbeats + beatpos_st ) 
            local steppos_end_sec = TimeMap2_beatsToTime(     self.var.proj, seqstart_fullbeats + beatpos_end) 
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
                          [2] = self.utils.math_q(meta_pitch or 64), -- pitch
                          [3] = self.utils.math_q((meta_probability or 1)*127), -- probability
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
                        [2] = self.utils.math_q(meta_pitch or 64), -- pitch
                        [3] = self.utils.math_q((meta_probability or 1)*127), -- probability
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
      f unction DATA:_Seq_PrintMIDI_AutoLegato(take)
        if self.ext.cur.CONF_seq_autolegato ==0 then return str end
        
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
      f unction DATA:_Seq_SetItLength_Beats(patternlen) 
        if not (DATA.MIDIbus and DATA.MIDIbus.tr_ptr and DATA.MIDIbus.valid) then return end
        if not (DATA.seq.it_ptr and DATA.seq.tk_ptr and DATA.seq.ext.patternsteplen) then return end
        
        if DATA.seq.D_STARTOFFS~= 0 then return end
        if DATA.seq.srccount~= 1 then return end
        
        local out_len_beats = DATA.seq.ext.patternlen * DATA.seq.ext.patternsteplen 
        local retval, measures, cml, fullbeats_pos, cdenom = reaper.TimeMap2_timeToBeats( self.var.proj, DATA.seq.it_pos )
        local out_end_sec_OLD = TimeMap2_beatsToTime( proj, fullbeats_pos +  out_len_beats)
        
        local out_len_beats = patternlen * DATA.seq.ext.patternsteplen 
        local retval, measures, cml, fullbeats_pos, cdenom = reaper.TimeMap2_timeToBeats( self.var.proj, DATA.seq.it_pos )
        local out_end_sec = TimeMap2_beatsToTime( proj, fullbeats_pos +  out_len_beats)
        
        SetMediaItemInfo_Value( DATA.seq.it_ptr, 'D_LENGTH', out_end_sec - DATA.seq.it_pos )
        UpdateItemInProject(DATA.seq.it_ptr)
        
        
        if self.ext.cur.CONF_seq_patlen_extendchildrenlen ==1 and DATA.seq.ext and DATA.seq.ext.children then 
          for note in pairs(DATA.seq.ext.children) do if DATA.seq.ext.children[note].step_cnt ~= -1 then DATA.seq.ext.children[note].step_cnt = patternlen end end
        end
        
      end
      ---------------------------------------------------------------------------------------------------------------------
      f unction VF_SmoothT(t, smooth)
        local t0 = CopyTable(t)
        for i = 2, #t do t[i]= t0[i] * (t[i] - (t[i] - t[i-1])*smooth )  end
      end 
  
      ---------------------------------------------------------------------------------------------------------------------
      f unction VF_NormalizeT(t, threshold)
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
      ------------------------------------------------------- 
      f unction VF_BFpluginparam(find_Str, tr, fx, param) 
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
    
    -----------------------------------------------------------------------------------------    -- 
    
    
    
    
  
      ---------------------------------------------------------------------  
      f unction VF_Format_Pan(D_PAN) 
        local D_PAN_format = 'C'
        if D_PAN > 0 then 
          D_PAN_format = math.floor(math.abs(D_PAN*100))..'R'
         elseif D_PAN < 0 then 
          D_PAN_format = math.floor(math.abs(D_PAN*100))..'L'
        end
        return D_PAN_format
      end
      
      -------------------------------------------------------------------------------- 
      f unction self.process.ext.save() 
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
      f unction DATA:_Seq_RefreshStepSeq() 
        if not DATA.seq_functionscall then 
          gmem_write(1030,1 ) -- DATA.upd refresh steseq 
          gmem_write(1028, 1) -- force step seq to refresh EXT
         else
          gmem_write(1030,1 ) -- DATA.upd refresh steseq 
        end
      end
      -------------------------------------------------------------------------------- 
      f unction DATA:handleViewportXYWH()
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
          self.process.ext.save() 
          DATA.display_schedule_save = nil 
        end
        DATA.display_x_last = DATA.display_x
        DATA.display_y_last = DATA.display_y
        DATA.display_w_last = DATA.display_w
        DATA.display_h_last = DATA.display_h
        
        --DATA.display_dockID = DATA.dockID
      end
        f unction VF_GetProjectSampleRate() return tonumber(reaper.format_timestr_pos( 1-reaper.GetProjectTimeOffset( 0,false ), '', 4 )) end -- get sample rate obey project start offset
      
      -------------------------------------------------------------------------------- 
      f unction DATA:Auto_TCPMCP(force_show)
        if not (DATA.parent_track and DATA.parent_track.valid == true) then return end 
        local upd
        
        -- reset after settings change
          if force_show == true then 
            SetMediaTrackInfo_Value( DATA.parent_track.ptr, 'I_FOLDERCOMPACT', 0)
            for note in pairs(self.var.rack.children[note]) do
              local tr = self.var.rack.children[note].tr_ptr
              SetMediaTrackInfo_Value( tr, 'B_SHOWINMIXER', 1)
              SetMediaTrackInfo_Value( tr, 'B_SHOWINTCP',1 )
              -- children
              for layer = 1, #self.var.rack.children[note].layers do 
                local tr = self.var.rack.children[note].layers[layer].tr_ptr
                if tr then 
                  SetMediaTrackInfo_Value( tr, 'B_SHOWINMIXER', 1 )
                  SetMediaTrackInfo_Value( tr, 'B_SHOWINTCP', 1 ) 
                end
              end
            end
            upd=true
          end
        
        -- set folder state
          if self.var.ext.CONF_onadd_newchild_trackheight.currentflags &1==1 then       -- set folder collapsed
            SetMediaTrackInfo_Value( DATA.parent_track.ptr, 'I_FOLDERCOMPACT', 1)
           elseif self.var.ext.CONF_onadd_newchild_trackheight.currentflags &2==2 then       -- set folder collapsed
            SetMediaTrackInfo_Value( DATA.parent_track.ptr, 'I_FOLDERCOMPACT', 2)
           elseif self.var.ext.CONF_onadd_newchild_trackheight.currentflags &2~=2 and self.var.ext.CONF_onadd_newchild_trackheight.currentflags &1~=1 then       -- set folder collapsed
            --local foldstate = GetMediaTrackInfo_Value( DATA.parent_track.ptr, 'I_FOLDERCOMPACT')   
            --if foldstate ~=0 then SetMediaTrackInfo_Value( DATA.parent_track.ptr, 'I_FOLDERCOMPACT', 0)       end
          end
      
        -- set children states 
          if self.var.ext.CONF_onadd_newchild_trackheight.currentflags &4==4 or  self.var.ext.CONF_onadd_newchild_trackheight.currentflags &8==8 then 
            for note in pairs(self.var.rack.children[note]) do
              local tr = self.var.rack.children[note].tr_ptr
              if not anytr then anytr = tr end
              -- device
              if tr then 
                if self.var.ext.CONF_onadd_newchild_trackheight.currentflags &8==8 and GetMediaTrackInfo_Value( tr, 'B_SHOWINMIXER') == 1 then SetMediaTrackInfo_Value( tr, 'B_SHOWINMIXER', 0 ) upd=true end
                if self.var.ext.CONF_onadd_newchild_trackheight.currentflags &4==4 and GetMediaTrackInfo_Value( tr, 'B_SHOWINTCP') == 1 then SetMediaTrackInfo_Value( tr, 'B_SHOWINTCP', 0 ) upd=true end  
              end
              -- children
              for layer = 1, #self.var.rack.children[note].layers do 
                local tr = self.var.rack.children[note].layers[layer].tr_ptr
                if tr then 
                  if self.var.ext.CONF_onadd_newchild_trackheight.currentflags &8==8 and GetMediaTrackInfo_Value( tr, 'B_SHOWINMIXER') == 1 then SetMediaTrackInfo_Value( tr, 'B_SHOWINMIXER', 0 ) upd=true end
                  if self.var.ext.CONF_onadd_newchild_trackheight.currentflags &4==4 and GetMediaTrackInfo_Value( tr, 'B_SHOWINTCP') == 1 then SetMediaTrackInfo_Value( tr, 'B_SHOWINTCP', 0 ) upd=true end  
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
      ---------------------------------------------------------------------------------------------------------------------
      f unction DATA:CollectData2_GetPeaks()
        for note in pairs(self.var.rack.children[note]) do
          if self.var.rack.children[note].layers and self.var.rack.children[note].layers[1] then   
            local t = self.var.rack.children[note].layers[1] 
            if not (DATA.peakscache[note] and DATA.peakscache[note].peaks_arr_valid==true and DATA.peakscache[note].peaks_arr) then 
              local arr = DATA:CollectData2_GetPeaks_grabpeaks(t, UI.calc_rack_padw) 
              if not DATA.peakscache[note] then DATA.peakscache[note] = {} end
              DATA.peakscache[note].peaks_arr = arr
              DATA.peakscache[note].peaks_arr_valid = true
            end
          end
        end
        
        local t, note, layer = DATA:Sampler_GetActiveNoteLayer()
        if self.var.rack.children[note] and self.var.rack.children[note] and self.var.rack.children[note].layers and self.var.rack.children[note].layers[1] then
          if not (t.peaks_arr_sampler and t.peaks_arr_sampler_valid==true) then 
            t.peaks_arr_sampler = DATA:CollectData2_GetPeaks_grabpeaks(t, UI.settingsfixedW) 
            local full = true
            t.peaks_arr_samplerfull = DATA:CollectData2_GetPeaks_grabpeaks(t, UI.settingsfixedW, full) 
            t.peaks_arr_sampler_valid = true
          end
        end
      end    
      
      ---------------------------------------------------------------------------------------------------------------------
      f unction DATA:Sampler_GetActiveNoteLayer()  
        if not (DATA.parent_track and DATA.parent_track.valid == true) then return end
        local layer =  self.var.rack.var.LASTACTIVENOTE_LAYER or 1  
        local note if not self.var.rack.var.LASTACTIVENOTE then return else note =self.var.rack.var.LASTACTIVENOTE end
        
        if self.var.rack.children[note] 
          and self.var.rack.children[note].layers 
          and self.var.rack.children[note].layers[layer] then  
          return self.var.rack.children[note].layers[layer],note,layer
        end
        
        if self.var.rack.children[note] and self.var.rack.children[note].layers and not self.var.rack.children[note].layers[layer] then  
          return self.var.rack.children[note],note,0
        end
        
      end
      --------------------------------------------------------------------- 
      f unction DATA:Auto_Device_RefreshVelocityRange(note)
        if not (self.var.rack.children[note] and self.var.rack.children[note] and self.var.rack.children[note].layers) then return end
        if self.var.rack.children[note].TYPE_DEVICE_AUTORANGE == false then return end
        
        if #self.var.rack.children[note].layers == 0 then return end
        
        local min_velID = 17
        local max_velID = 18
        local block_sz = 127 / #self.var.rack.children[note].layers
        
        for layer =1, #self.var.rack.children[note].layers do
          if self.var.rack.children[note].layers[layer].ISRS5K == true then 
            local track = self.var.rack.children[note].layers[layer].tr_ptr
            local instrument_pos = self.var.rack.children[note].layers[layer].instrument_pos
            
            TrackFX_SetParamNormalized( track, instrument_pos, min_velID, (block_sz*(layer-1))  *1/127)
            TrackFX_SetParamNormalized( track, instrument_pos, max_velID, (-1+block_sz*(layer))  *1/127 )
            if layer == #self.var.rack.children[note].layers then 
              TrackFX_SetParamNormalized( track, instrument_pos, max_velID, 1)
            end
          end 
        end
      end
      --------------------------------------------------------------------- 
      f unction DATA:Auto_MIDInotenames() 
        if not (DATA.parent_track and DATA.parent_track.valid == true) then return end 
        
        for note = 0,127 do 
          if self.var.ext.CONF_autorenamemidinotenames.current&1==1 then 
            -- midi bus
            if DATA.MIDIbus.valid == true then
              local outname = ''
              if self.var.rack.children[note] and self.var.rack.children[note].P_NAME then outname = self.var.rack.children[note].P_NAME end
              if DATA.padcustomnames and DATA.padcustomnames[note] and DATA.padcustomnames[note] ~='' then outname = DATA.padcustomnames[note] end
              local curname = GetTrackMIDINoteNameEx( self.var.proj,  DATA.MIDIbus.tr_ptr, note,-1 )
              if curname ~= outname then SetTrackMIDINoteNameEx( self.var.proj,  DATA.MIDIbus.tr_ptr, note, -1, outname) end
            end
          end
          
          if self.var.ext.CONF_autorenamemidinotenames.current&2==2 then 
            -- clear device
            if self.var.rack.children[note] and self.var.rack.children[note].tr_ptr and self.var.rack.children[note].TYPE_DEVICE == true then 
              local curname = GetTrackMIDINoteNameEx( self.var.proj,  self.var.rack.children[note].tr_ptr, note,-1 )
              if curname ~= '' then SetTrackMIDINoteNameEx( self.var.proj, self.var.rack.children[note].tr_ptr, note, -1, '') end
            end
            -- set reg childrens to only theirs notes
            if self.var.rack.children[note] and self.var.rack.children[note].tr_ptr and self.var.rack.children[note].layers then 
              for layer =1 , #self.var.rack.children[note].layers do
                for tracknote = 0, 127 do
                  local outname = ''
                  if tracknote == note then outname =self.var.rack.children[note].layers[layer].P_NAME end
                  local curname = GetTrackMIDINoteNameEx( self.var.proj,  self.var.rack.children[note].layers[layer].tr_ptr, tracknote,-1 )
                  if curname ~= outname then SetTrackMIDINoteNameEx( self.var.proj,  self.var.rack.children[note].layers[layer].tr_ptr, tracknote, -1, outname) end
                end 
              end
            end
            
          end
        end
      end
      -----------------------------------------------------------------------  
      f unction DATA:Validate_InitFilterDrive(note_layer_t) 
        local track = note_layer_t.tr_ptr
        if not note_layer_t.fx_reaeq_isvalid then 
          local reaeq_pos = TrackFX_AddByName( track, 'ReaEQ', 0, 1 )
          TrackFX_Show( track, reaeq_pos, 2 )
          TrackFX_SetNamedConfigParm( track, reaeq_pos, 'BANDTYPE0',3 )
          TrackFX_SetParamNormalized( track, reaeq_pos, 0, 1 )
          local GUID = reaper.TrackFX_GetFXGUID( track, reaeq_pos )
          self.ext.child.set(track, {FX_REAEQ_GUID = GUID}) 
          DATA.upd = true
        end
         
        if not note_layer_t.fx_ws_isvalid then
          local ws_pos = TrackFX_AddByName( track, 'waveShapingDstr', 0, 1 )--'Distortion\\waveShapingDstr'
          TrackFX_Show( track, ws_pos, 2 )
          TrackFX_SetParamNormalized( track, ws_pos, 0, 0 )
          local GUID = reaper.TrackFX_GetFXGUID( track, ws_pos )
          self.ext.child.set(track, {FX_WS_GUID = GUID}) 
          DATA.upd = true
        end
      end
      -------------------------------------------------------------------------------- 
      f unction DATA:CollectData_FormatVolume(D_VOL)  
        return ( math.floor(WDL_VAL2DB(D_VOL)*10)/10) ..'dB'
      end
      
      
      -----------------------------------------------------------------------  
      f unction DATA:DropFX_Export(track, instrument_pos, note, fxname)  
        local midifilt_pos = TrackFX_AddByName( track, 'midi_note_filter', false, -1000 ) 
        DATA:DropSample_ExportToRS5kSetNoteRange({tr_ptr=track, instrument_pos=instrument_pos,midifilt_pos=midifilt_pos}, note) 
        
        -- set parameters
          if self.var.ext.CONF_onadd_float.current == 0 then TrackFX_SetOpen( track, instrument_pos, false ) end
        
        -- store external data
          local instrumentGUID = TrackFX_GetFXGUID( track, instrument_pos+1)
          self.ext.child.set(track, {
            SET_instrFXGUID = instrumentGUID,
            SET_noteID=note,
            SET_isrs5k=false,
          }) 
        
        -- rename track
          if self.ext.cur.CONF_onadd_renametrack==1 then 
            GetSetMediaTrackInfo_String( track, 'P_NAME', fxname, true )
          end
          
      end
      ---------------------------------------------------------------------  
      f unction DATA:DropFX(fx_namesrc, fxname, fxidx, src_track, note, drop_data)
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
        if self.var.rack.children[note] and self.var.rack.children[note].layers and self.var.rack.children[note].layers[layer or 1] and self.var.rack.children[note].layers[layer or 1].instrument_pos then instrument_pos = self.var.rack.children[note].layers[layer or 1].instrument_pos end 
        if instrument_pos then TrackFX_Delete( track, instrument_pos ) end
        
        -- insert rs5k
        TrackFX_CopyToTrack( src_track, fxidx, track, 0, true )
        local instrument_pos = TrackFX_AddByName( track, fx_namesrc, false, 0)  
        if instrument_pos == -1 then return end
        DATA:DropFX_Export(track, instrument_pos, note, fxname) 
        
        
        DATA.autoreposition = true   
        DATA:_Seq_RefreshStepSeq()
      end
      --------------------------------------------------------------------------------  
      f unction DATA:Action_ExplodeTake_sub_readparent(take)
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
      f unction DATA:Action_ExplodeTake_sub_writechildren(options, item, take, MIDIdata)
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
          if note and self.var.rack.children[note] then
            local track = self.var.rack.children[note].tr_ptr
            local SYSEXMOD = self.var.rack.children[note].SYSEXMOD
            if self.var.rack.children[note].SYSEXHANDLER_ID and self.var.rack.children[note].SYSEXHANDLER_isvalid==true then TrackFX_SetEnabled( track, self.var.rack.children[note].SYSEXHANDLER_ID, false ) end
            if self.var.rack.children[note].layers and self.var.rack.children[note].layers[1] and self.var.rack.children[note].layers[1].midifilt_pos then TrackFX_SetEnabled( self.var.rack.children[note].layers[1].tr_ptr, self.var.rack.children[note].layers[1].midifilt_pos, false ) end 
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
                if options and options.modify_note then 
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
      f unction DATA:Action_ExplodeTake_sub_sysexhandler(take)
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
          }] ]
      end
      --------------------------------------------------------------------------------  
      f unction DATA:Action_ExplodeTake_sub(options, item)
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
      f unction DATA:Action_ExplodeTake(options)
        Undo_BeginBlock2(self.var.proj)
        for i = 1, reaper.CountSelectedMediaItems(self.var.proj) do
          local item = GetSelectedMediaItem(self.var.proj, i-1)
          DATA:Action_ExplodeTake_sub(options, item)
        end
        Undo_EndBlock2(self.var.proj, 'Explode MIDI bus take by note', 0xFFFFFFFF)
      end
      --[[
      
      --------------------------------------------------------------------------------  
        f unction DATA:Action_ExplodeTake_old01062025()
          Undo_BeginBlock2(self.var.proj)
          for i = 1, reaper.CountSelectedMediaItems(self.var.proj) do
            local item = GetSelectedMediaItem(self.var.proj, i-1)
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
              if note and self.var.rack.children[note] then
                local track = self.var.rack.children[note].tr_ptr
                local SYSEXMOD = self.var.rack.children[note].SYSEXMOD
                if self.var.rack.children[note].SYSEXHANDLER_ID and self.var.rack.children[note].SYSEXHANDLER_isvalid==true then TrackFX_SetEnabled( track, self.var.rack.children[note].SYSEXHANDLER_ID, false ) end
                if self.var.rack.children[note].layers and self.var.rack.children[note].layers[1] and self.var.rack.children[note].layers[1].midifilt_pos then TrackFX_SetEnabled( self.var.rack.children[note].layers[1].tr_ptr, self.var.rack.children[note].layers[1].midifilt_pos, false ) end 
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
          Undo_EndBlock2(self.var.proj, 'Explode MIDI bus take by note', 0xFFFFFFFF)
        end
        ] ]
      
      
      
      
      
      -------------------------------------------------------------------------------- 
      f unction UI.draw_3rdpartyimport_context_add(buf, note, drop_data) 
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
      f unction UI.draw_3rdpartyimport_context(note,drop_data)  
        ImGui.SetNextItemWidth( ctx,-100)
        if ImGui.BeginMenu( ctx, 'Import FXi', true ) then 
          local cnt_com = #DATA.installed_plugins 
          
          -- by type
          reaper.ImGui_SeparatorText(ctx, 'By type')
          for typestr in self.utils.spairs(DATA.installed_plugins.types) do
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
          for vendorstr in self.utils.spairs(DATA.installed_plugins.vendors) do
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
      
      
      ----------------------------------------------------------------------
      f unction DATA:Actions_TemporaryGetAudio(filename) 
        
        local PCM_Source = PCM_Source_CreateFromFile( filename )
        local srclen, lengthIsQN = reaper.GetMediaSourceLength( PCM_Source )
        if srclen > self.ext.cur.CONF_crop_maxlen then
          --if PCM_Source then  PCM_Source_Destroy( PCM_Source )  end
          return
        end
        
        
        -- add temp stuff for audio read
        local tr_cnt = CountTracks(self.var.proj)
        InsertTrackInProject( self.var.proj, tr_cnt, 0 )
        local temp_track  = GetTrack(self.var.proj, tr_cnt) 
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
        --if reaper.ValidatePtr2( self.var.proj, PCM_Source, 'PCM_Source*' ) then  PCM_Source_Destroy( PCM_Source )  end
        DestroyAudioAccessor( accessor ) 
        DeleteTrack( temp_track )
        
        local samplebuffer_t = samplebuffer.table()
        samplebuffer.clear()
        return samplebuffer_t,srclen,SR
      end
      ----------------------------------------------------------------------
      f unction DATA:Action_CropToAudibleBoundaries(note_layer_t) 
        if not note_layer_t then return end 
        local filename = note_layer_t.instrument_filename
        if not filename then return end
        local samplebuffer_t = DATA:Actions_TemporaryGetAudio(filename)  
        if not samplebuffer_t then return end
        
        -- threshold
        local threshold_lin = WDL_DB2VAL(self.ext.cur.CONF_cropthreshold)
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
      f unction DATA:Action_ShiftOffset_NextTransient(note_layer_t)  
        if not note_layer_t then return end 
        
        local instrument_samplestoffs = note_layer_t.instrument_samplestoffs
        local instrument_sampleendoffs = note_layer_t.instrument_sampleendoffs
        local SAMPLELEN = note_layer_t.SAMPLELEN
        local transientahead  = self.ext.cur.CONF_stepmode_transientahead / SAMPLELEN
        
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
            end] ]
            
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
      f unction DATA:Action_ShiftOffset(note_layer_t, mode, dir)
        if not (note_layer_t and note_layer_t.ISRS5K == true ) then return end
        local note = note_layer_t.noteID
        
        local instrument_samplestoffs = note_layer_t.instrument_samplestoffs
        local instrument_sampleendoffs = note_layer_t.instrument_sampleendoffs
        local SAMPLELEN = note_layer_t.SAMPLELEN
        if not (SAMPLELEN and SAMPLELEN > 0) then return end
        
        local rel_length = instrument_sampleendoffs-instrument_samplestoffs
        
        local step_value = DATA.boundarystep[self.ext.cur.CONF_stepmode].val
        
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
            if self.ext.cur.CONF_stepmode_keeplen==1 then outend = VF_lim(instrument_sampleendoffs + out_shift*dir) end
        -- shift start to boundary
           elseif mode == 2 then
            if dir == -1 then 
              out_shift = -instrument_samplestoffs
             else
              out_shift = instrument_sampleendoffs-instrument_samplestoffs
            end 
            outst = VF_lim(instrument_samplestoffs + out_shift) 
            if self.ext.cur.CONF_stepmode_keeplen==1 then outend = VF_lim(instrument_sampleendoffs + out_shift) end     
            
        -- shift end
           elseif mode == 1 then 
             outend  = VF_lim(instrument_sampleendoffs + out_shift*dir) 
             if self.ext.cur.CONF_stepmode_keeplen==1 then outst = VF_lim(instrument_samplestoffs + out_shift*dir) end
        -- shift end to doundary
           elseif mode == 3 then 
            if dir == -1 then 
              out_shift = - instrument_sampleendoffs
             else
              out_shift = 1-instrument_sampleendoffs
            end
            outend  = VF_lim(instrument_sampleendoffs + out_shift) 
            if self.ext.cur.CONF_stepmode_keeplen==1 then outst = VF_lim(instrument_samplestoffs + out_shift) end   
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
      f unction DATA:CollectDataInit_PluginParametersMapping_Set() 
        self.ext.cur.CONF_plugin_mapping_b64 = VF_encBase64(table.savestring(DATA.plugin_mapping))
        self.process.ext.save()
      end  
      
      --------------------------------------------------------------------  
      f unction DATA:Auto_LoopSlice_CDOE(item) 
      
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
      f unction DATA:Auto_LoopSlice_extract_loopt(filename) 
        local loop_t= {}
        
        -- check by name
        local filter = self.ext.cur.CONF_loopcheck_filter:lower():gsub('%s+','')
        local words = {}
        for word in filter:gmatch('[^,]+') do words[word] = true end
        local test_filename = filename:lower():gsub('[%s%p]+','')
        for word in pairs(words) do if test_filename:match(word) then return end end
        
        -- build PCM
        local PCM_Source = PCM_Source_CreateFromFile( filename )
        local srclen, lengthIsQN = GetMediaSourceLength( PCM_Source )
        if lengthIsQN ==true or (srclen < self.ext.cur.CONF_loopcheck_minlen or srclen > self.ext.cur.CONF_loopcheck_maxlen) then 
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
        local tr_cnt = CountTracks(self.var.proj)
        InsertTrackInProject( self.var.proj, tr_cnt, 0 )
        local temp_track  = GetTrack(self.var.proj, tr_cnt) 
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
      f unction DATA:Auto_LoopSlice_ShareDATA(loop_t,note,filename,bpm) 
        PreventUIRefresh( 1 )
        Undo_BeginBlock2( self.var.proj)
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
        Undo_EndBlock2( self.var.proj , 'RS5k manager - drop and slice loop to pads', 0xFFFFFFFF ) 
        PreventUIRefresh( -1 )
      end
      --------------------------------------------------------------------- 
      f unction DATA:Auto_LoopSlice_CreateMIDI(stretchmidi, srclen,loop_t,note, bpm)
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
      f unction DATA:Auto_LoopSlice(note, count)   -- test audio framgment if it contain slices
        f unction __f_loopslice() end
        if self.ext.cur.CONF_loopcheck&1==0 then return end  
        
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
      f unction DATA:Sampler_ImportSelectedItems() 
        local note =  0
        if  DATA.parent_track.ext and self.var.rack.var.LASTACTIVENOTE then note = self.var.rack.var.LASTACTIVENOTE end
        
        
        Undo_BeginBlock2(self.var.proj)
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
        
        if self.ext.cur.CONF_importselitems_removesource == 1 then
          for itemGUID in pairs(items_to_remove ) do 
            local it = VF_GetMediaItemByGUID(self.var.proj, itemGUID)
            if it then DeleteTrackMediaItem(  reaper.GetMediaItemTrack( it ), it ) end
          end
        end
        Undo_EndBlock2(self.var.proj, 'RS5k manager - import selected items', 0xFFFFFFFF)
        
        UpdateArrange()
      end
      ---------------------------------------------------------------------
      f unction VF_GetMediaItemByGUID(optional_proj, itemGUID)
        local optional_proj0 = optional_proj or -1
        local itemCount = CountMediaItems(optional_proj);
        for i = 1, itemCount do
          local item = GetMediaItem(0, i-1);
          local retval, stringNeedBig = GetSetMediaItemInfo_String(item, "GUID", '', false)
          if stringNeedBig  == itemGUID then return item end
        end
      end 
      
     
        --------------------------------------------------------------------------------  
      f unction VF_Open_URL(url) if GetOS():match("OSX") then os.execute('open "" '.. url) else os.execute('start "" '.. url)  end  end    
  
      --------------------------------------------------------------------- 
      f unction DATA:Choke_Write()  
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
        
        for fxID in self.utils.spairs(removeID, function(t,a,b) return b < a end) do
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
      f unction DATA:Action_SetObeyNoteOff(note)
        local note_t = self.var.rack.children[note]
        if note_t and note_t.layers then
          for layer = 1, #note_t.layers do
            local note_layer_t = note_t.layers[layer]
            local obeynoteoff = TrackFX_GetParamNormalized( note_layer_t.tr_ptr, note_layer_t.instrument_pos, 11 )
            if note_layer_t.ISRS5K and obeynoteoff == 0 then TrackFX_SetParamNormalized( note_layer_t.tr_ptr, note_layer_t.instrument_pos, 11, 1 ) end
          end
        end
      end
      
      --------------------------------------------------------------------- 
      f unction DATA:Action_RS5k_SYSEXMOD_OFF(note)
        Undo_BeginBlock2(-1) 
        local note_t = self.var.rack.children[note]
        if note_t then self.ext.child.set(note_t.tr_ptr,{SET_SYSEXMOD=0}) end
        
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
      f unction UI.VDragInt(ctx, str_id, size_w, size_h, v, v_min, v_max, formatIn, flagsIn, floor, default, image)
        
        ImGui.PushStyleVar(ctx, ImGui.StyleVar_FramePadding,1,1) 
        ImGui.PushStyleVar(ctx, ImGui.StyleVar_CellPadding,1, 1) 
        ImGui.PushStyleVar(ctx, ImGui.StyleVar_ItemSpacing,1, 1)
        ImGui.PushStyleVar(ctx, ImGui.StyleVar_ButtonTextAlign,0.5,0.5)
        ImGui.PushFont(ctx, self.font4) 
        
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
      
      -------------------------------------------------------------------  
      f unction DATA:Launchpad_SendState()
        if self.ext.cur.CONF_seq_stuffMIDItoLP == 0 then return end
        if not DATA.lp_matrix then return end
        
        
        -- form matrix
          local row = 0
          for note in self.utils.spairs(DATA.seq.active_step) do
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
            StuffMIDIMessage( 16+self.var.ext.CONF_midioutput.current, 0x90, DATA.lp_matrix[row][col].MIDI_note, col_state )
          end
        end 
        
        
      end 
      ----------------------------------------------------------------------
      f unction DATA:CollectData_Always_LaunchPadInteraction()
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
      f unction DATA:Auto_StuffSysex_dec2hex(dec)  local pat = "%02X" return  string.format(pat, dec) end
      
      ---------------------------------------------------------------------  
      f unction DATA:Auto_StuffSysex_sub(cmd) local SysEx_msg  
        if  not (self.ext.cur.CONF_launchpadsendMIDI == 1 and EXT.UI_drracklayout == 2) then return end 
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
              if self.var.rack.children[note] and self.var.rack.children[note][ledId] and self.var.rack.children[note][ledId].I_CUSTOMCOLOR then
                local msgtype = 90
                if DATA.parent_track and DATA.parent_track.ext and self.var.rack.var.LASTACTIVENOTE and self.var.rack.var.LASTACTIVENOTE == ledId then msgtype = 92 end
                SysEx_msg = msgtype..' '..string.format("%02X", ledId)..' 16'
                DATA:Launchpad_StuffSysex(SysEx_msg, HWdevoutID) 
               else
                local col = '00'
                if DATA.parent_track and DATA.parent_track.ext and self.var.rack.var.LASTACTIVENOTE and self.var.rack.var.LASTACTIVENOTE == ledId then col = '03' end
                SysEx_msg = '90 '..string.format("%02X", ledId)..' '..col
                DATA:Launchpad_StuffSysex(SysEx_msg, HWdevoutID) 
              end
            end
          end
          
        end] ]
        
        
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
              if self.var.rack.children[note] and self.var.rack.children[note][ledId] and self.var.rack.children[note][ledId].I_CUSTOMCOLOR then
                local lightingtype = 3 
                local color = ImGui.ColorConvertNative(self.var.rack.children[note][ledId].I_CUSTOMCOLOR) & 0xFFFFFF 
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
        
      end ] ]
      
      
      
      
      
      
      
        
      -- LZW Compression Algorithm (pure Lua)
      local LZW = {}
      
      -- Compress a string using LZW
      f unction LZW.compress(input)
          if #input == 0 then return "" end
          
          -- Build the initial dictionary (256 ASCII characters)
          local dict = {}
          local dictSize = 256
          for i = 0, 255 do
              dict[string.char(i)] = i
          end
          
          -- Initialize variables
          local w = ""
          local result = {}
          local bits = 9  -- Start with 9-bit codes
          
          for i = 1, #input do
              local c = input:sub(i, i)
              local wc = w .. c
              
              if dict[wc] then
                  w = wc
              else
                  -- Add w to output
                  table.insert(result, dict[w])
                  
                  -- Add wc to dictionary
                  dict[wc] = dictSize
                  dictSize = dictSize + 1
                  
                  -- Check if we need to increase bit size
                  if dictSize > (1 << bits) - 1 then
                      bits = bits + 1
                      -- Maximum bits for Lua integer safety (up to 32 bits)
                      if bits > 32 then bits = 32 end
                  end
                  
                  w = c
              end
          end
          
          -- Output the last code
          if w ~= "" then
              table.insert(result, dict[w])
          end
          
          -- Convert codes to binary string
          return LZW._codesToBinary(result, bits)
      end
      
      -- Decompress binary string using LZW
      f unction LZW.decompress(binaryInput)
          if #binaryInput == 0 then return "" end
          
          -- First, extract the codes from binary
          local codes, bits = LZW._binaryToCodes(binaryInput)
          if #codes == 0 then return "" end
          
          -- Rebuild the dictionary
          local dict = {}
          local dictSize = 256
          for i = 0, 255 do
              dict[i] = string.char(i)
          end
          
          -- Initialize variables
          local result = {}
          local w = dict[codes[1] ]
          table.insert(result, w)
          
          for i = 2, #codes do
              local k = codes[i]
              local entry
              
              if dict[k] then
                  entry = dict[k]
              elseif k == dictSize then
                  entry = w .. w:sub(1, 1)
              else
                  error("Invalid compressed data")
              end
              
              table.insert(result, entry)
              
              -- Add to dictionary
              dict[dictSize] = w .. entry:sub(1, 1)
              dictSize = dictSize + 1
              
              w = entry
          end
          
          return table.concat(result)
      end
      
      
      -- Convert codes to binary string
      f unction LZW._codesToBinary(codes, bits)
          local result = {}
          local buffer = 0
          local bufferBits = 0
          
          -- Store bits per code at the beginning (5 bits for bits value, up to 32)
          local header = string.char(math.min(bits, 255))
          table.insert(result, header)
          
          for _, code in ipairs(codes) do
              -- Add code to buffer
              buffer = buffer << bits
              buffer = buffer | code
              bufferBits = bufferBits + bits
              
              -- Write complete bytes
              while bufferBits >= 8 do
                  bufferBits = bufferBits - 8
                  local byte = (buffer >> bufferBits) & 0xFF
                  table.insert(result, string.char(byte))
                  buffer = buffer & ((1 << bufferBits) - 1)
              end
          end
          
          -- Write remaining bits
          if bufferBits > 0 then
              local byte = (buffer << (8 - bufferBits)) & 0xFF
              table.insert(result, string.char(byte))
              -- Store how many bits are valid in the last byte
              table.insert(result, string.char(bufferBits))
          else
              table.insert(result, string.char(0))  -- 0 means no partial byte
          end
          
          return table.concat(result)
      end
      
      -- Convert binary string back to codes
      f unction LZW._binaryToCodes(binaryInput)
          if #binaryInput < 2 then return {}, 0 end
          
          local result = {}
          
          -- Read header
          local bits = binaryInput:byte(1)
          if bits > 32 then bits = bits - 256 end  -- Handle signed byte
          bits = math.max(9, math.min(32, bits))
          
          local buffer = 0
          local bufferBits = 0
          local pos = 2  -- Skip header
          
          -- Read last byte info
          local lastByteBits = binaryInput:byte(#binaryInput)
          local totalBytes = #binaryInput - 2  -- Exclude header and last byte info
          
          for i = 1, totalBytes do
              local byte = binaryInput:byte(pos)
              pos = pos + 1
              
              buffer = (buffer << 8) | byte
              bufferBits = bufferBits + 8
              
              while bufferBits >= bits do
                  bufferBits = bufferBits - bits
                  local code = (buffer >> bufferBits) & ((1 << bits) - 1)
                  table.insert(result, code)
                  buffer = buffer & ((1 << bufferBits) - 1)
              end
          end
          
          -- Handle last partial byte
          if lastByteBits > 0 and lastByteBits < 8 then
              -- We have some valid bits in the last byte
              if totalBytes > 0 then
                  buffer = buffer << lastByteBits
                  bufferBits = bufferBits + lastByteBits
                  
                  if bufferBits >= bits then
                      bufferBits = bufferBits - bits
                      local code = (buffer >> bufferBits) & ((1 << bits) - 1)
                      table.insert(result, code)
                  end
              end
          end
          
          return result, bits
      end
      
      
      
      
      f = io.open([[C:\src.mp3] ],'rb')
      content = f:read('a')
      f:close()
      
      f1 = io.open([[C:\test.txt] ],'wb')
      f1:write( LZW.compress(content)) 
      f1:close()
      
      f2 = io.open([[C:\test.txt] ],'rb')
      content = f2:read('a')
      f2:close()
      
      
      f3 = io.open([[C:\Users\MPL\Desktop\dest.mp3] ],'wb')
      f3:write( LZW.decompress(content)) 
      f3:close()
      -----------------------------------------------------------------------------------------       
    
  --------------------------------------------------------------------------------  
  f unction DATA:_Seq_CollectTrackEnv(fxGUID0,parm0 ) 
    local note_layer_t,note, layer = DATA:Sampler_GetActiveNoteLayer()  
    if not note_layer_t then return end
    
    -- track env 
    DATA.seq_param_selector_trackenv = {}
    
    -- pan
    DATA.seq_param_selector_trackenv[#DATA.seq_param_selector_trackenv+1] = {
      param = 'env_pan', 
      str = 'Pan',
      default = 0, 
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
      for fxGUID in self.utils.spairs(DATA.seq.ext.children[note].env_FXparamlist) do
        for paramID in self.utils.spairs(DATA.seq.ext.children[note].env_FXparamlist[fxGUID]) do
          if self.var.rack.children[note] and self.var.rack.children[note].tr_ptr then 
            local ret, tr, fxid = VF_GetFXByGUID(fxGUID, self.var.rack.children[note].tr_ptr, self.var.proj)
            if fxid then
              local retval, fxname = reaper.TrackFX_GetFXName( self.var.rack.children[note].tr_ptr, fxid )
              fxname = VF_ReduceFXname(fxname)
              local retval, paramname = reaper.TrackFX_GetParamName( self.var.rack.children[note].tr_ptr, fxid,paramID)
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
  
  
  if self.ext.cur.CONF_onadd_renameinst == 1 and self.ext.cur.CONF_onadd_renameinst_str ~= '' then
    local str = self.ext.cur.CONF_onadd_renameinst_str
    str = str:gsub('%#note',note)
    if drop_data.layer then str = str:gsub('%#layer',drop_data.layer) else str = str:gsub('%#layer','') end
  end
  
  -- apply normalisation
  local LUFSNORM_db = self.utils.WDL_VAL2DB(LUFSNORM)
  drop_data.LUFSNORM_db = LUFSNORM_db
  LUFSNORM_db = drop_data.LUFSNORM_db
  LUFSNORM_db= tostring(LUFSNORM_db)
  local v = VF_BFpluginparam(LUFSNORM_db, track, instrument_pos,0)
  v = VF_lim(v,0.1,1)
  TrackFX_SetParamNormalized( track, instrument_pos,0, v )  
  
  
  ]]