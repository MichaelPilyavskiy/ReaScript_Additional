
  s = 150
  pow = 3
  
  local r = reaper 
  val = 0  
  local __, __, screen_w, screen_h = reaper.my_getViewport(0, 0, s, s  , 0, 0, s, s  , 1)    
  local x, y = (screen_w - s) / 2, (screen_h - s) / 2    
  gfx.init("morph sends", s, s, 0, x, y)  
  -------------------------------------------
  function run()
    gfx.set(1,1,1) 
    if gfx.mouse_cap==1 then val = math.min(1,math.max(0,1 - (gfx.w - gfx.mouse_x) / 150)) end
    gfx.update()    
    tr = reaper.GetSelectedTrack(0,0)
    if tr then 
      retval= reaper.TrackFX_GetParam( tr, 0, 0 )
      if retval > 0 then  val = retval end
      s= {}
      cnt = reaper.GetTrackNumSends( tr, 0 )
      for i = 1, cnt do      
        local v =  -math.abs( ( -(i-1)      +(cnt-1) * val)^pow)  +1 
        s[i] = math.max(0, v)
        gfx.rect(0,(i-1) * gfx.h/cnt, s[i]*gfx.w,gfx.h/cnt)
        reaper.CSurf_OnSendVolumeChange( tr, i-1, s[i], false )
      end
    end    
    if gfx.getchar() >= 0 then  r.defer(run) end
  end
  -------------------------------------------
  run()
