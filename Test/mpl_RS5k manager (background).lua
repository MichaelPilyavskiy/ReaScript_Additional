-- @description RS5k manager
-- @version 1.50
-- @author MPL
-- @website http://forum.cockos.com/showthread.php?t=188335
-- @provides
--    mpl_RS5k_manager_functions/mpl_RS5k_manager_trackfunc.lua
--    mpl_RS5k_manager_functions/mpl_RS5k_manager_basefunc.lua
--    mpl_RS5k_manager_functions/mpl_RS5k_manager_GUI.lua
--    mpl_RS5k_manager_functions/mpl_RS5k_manager_MOUSE.lua
--    mpl_RS5k_manager_functions/mpl_RS5k_manager_PAT.lua
--    mpl_RS5k_manager_functions/mpl_RS5k_manager_data.lua
--    mpl_RS5k_manager_functions/mpl_RS5k_manager_obj.lua
-- @changelog
--    # Cleaning most code, split functions. Because it is serious code change, I might not noticed some bugs coming from old structure. Feel free to post them into common thread at http://forum.cockos.com/showthread.php?t=188335
--    + Pads: allow to drandrop samples from MediaExplorer (REAPER 5.91pre1+). 
--    # Pads: clear waveform on empty pad click 
--    # StepSeq: add sequence validation at some cases
--    - scrolling for sample browser, patterns, step sequencer temporarily removed
  
  local vrs = 'v1.50'
  local scr_title = 'RS5K manager'
  --NOT gfx NOT reaper
  --  INIT -------------------------------------------------
  for key in pairs(reaper) do _G[key]=reaper[key]  end  
  local conf = {}  
  local refresh = { GUI_onStart = true, 
                    GUI = false, 
                    data = false,
                    GUI_WF = false,
                    conf = false}
  local mouse = {}
  local obj = {}
  data = {}
  local pat = {}
        
  ---------------------------------------------------  
  
  function Main_RefreshExternalLibs()     -- lua example by Heda -- http://github.com/ReaTeam/ReaScripts-Templates/blob/master/Files/Require%20external%20files%20for%20the%20script.lua
    local info = debug.getinfo(1,'S');
    local script_path = info.source:match([[^@?(.*[\/])[^\/]-$]]) 
    dofile(script_path .. "mpl_RS5k_manager_functions/mpl_RS5k_manager_trackfunc.lua")
    dofile(script_path .. "mpl_RS5k_manager_functions/mpl_RS5k_manager_basefunc.lua")
    dofile(script_path .. "mpl_RS5k_manager_functions/mpl_RS5k_manager_GUI.lua")
    dofile(script_path .. "mpl_RS5k_manager_functions/mpl_RS5k_manager_MOUSE.lua")
    dofile(script_path .. "mpl_RS5k_manager_functions/mpl_RS5k_manager_PAT.lua")    
    dofile(script_path .. "mpl_RS5k_manager_functions/mpl_RS5k_manager_obj.lua")  
    dofile(script_path .. "mpl_RS5k_manager_functions/mpl_RS5k_manager_data.lua")  
  end  

  ---------------------------------------------------
  
  function run()
    obj.clock = os.clock()
    
    MOUSE(conf, obj, data, refresh, mouse, pat)
    CheckUpdates(obj, conf, refresh)
    if refresh.data == true                      then Data_Update             (conf, obj, data, refresh, mouse, pat) refresh.data = nil end    
    if refresh.conf == true                       then ExtState_Save(conf)                                            refresh.conf = nil end
    if refresh.projExtData == true                then ExtState_Save_Patterns  (conf, obj, data, refresh, mouse, pat) refresh.projExtData = nil end      
    if refresh.GUI == true or refresh.GUI_onStart == true then OBJ_Update              (conf, obj, data, refresh, mouse, pat) end 
 
                                                GUI_draw               (conf, obj, data, refresh, mouse, pat)    
                                               
    local char =gfx.getchar()  
    ShortCuts(char)
    if char >= 0 and char ~= 27 then defer(run) else atexit(gfx.quit) end
  end
    
  ---------------------------------------------------

  Main_RefreshExternalLibs()
  ExtState_Load(conf)  
  pat = ExtState_Load_Patterns(data, conf) -- load parent GUID 
  gfx.init('MPL RS5k manager '..vrs,
            conf.wind_w, 
            conf.wind_h, 
            conf.dock, conf.wind_x, conf.wind_y)
  OBJ_init(obj)
  OBJ_initButtons(conf, obj, data, refresh, mouse, pat)
  OBJ_Update(conf, obj, data, refresh, mouse, pat) 
  
  conf.dev_mode = 0
  run()
  
  
