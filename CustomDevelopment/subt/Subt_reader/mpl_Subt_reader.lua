  version = '0.22 // 01.06.24'
  UI_title = 'SubtReader' 
  
  
  
  --[[changelog
    -- 0.22 // 01.06.24
      # ignore {}
    -- 0.21 // 14.04.24
      + Color Artist by exact name: notify is message is tool long
      + Color Artist by exact name: support file path input
      + Color Artist by exact name: notify is file not found
    -- 0.20 // 05.04.24
      + Color items by matched text: set selection 
      # Color items by matched text: obey artist name
      # Color Artist by exact name: ignore // 
    -- 0.19 // 13.03.24
      + Color Artist by exact name: set selection 
    -- 0.18 // 12.03.24
      # fix Color Artist by exact name parser 
    -- 0.17 // 08.01.24
      # fix error if track has no items
      # fix color by artist string match 
    -- 0.16 // 02.01.24
      # move parse_artist to global config, add menu option
      # move progress_enabled to global config, add menu option
      # fix artist parsing
      # use +1px for checking if text match boundaries
      + Menu: Color items by matched text
    -- 0.15 // 31.12.23
      # faster array search for RT_GetCurrentNote()
      # improve redraw at freeze mode
      
    -- 0.14 // 29.12.23
      + UI.freezemode_limitratio
      + UI.freezemode_incrementpixel
      + UI.freezemode_offsetnote
      
    -- 0.13 // 29.12.23
      # fix multiline parsing
      
    -- 0.12 // 24.12.23
      # add back UI.text_fixed_w
      # fix text wrap some cases
      + UI.progress_recordonly
      
    -- 0.11d // 23.12.23
      - UI.text_fixed_w, use gfx.w as text limit instead
      # fix calculating yoffset
      # fix alpha limit
      + Menu: Color artist by exact name
      # refresh text limit at window size change
      
    -- 0.11c // 23.12.23
      # fix missed alpha patch
      # timecode and artis follow UI.txt_yoffset 
      # fix gfx.w as right limit
      
    -- 0.11b // 23.12.23
      # fix calc inertia obey separator
      # improve inertia formula
      # fix progress_ parameters
      # revert UI.txt_yoffset 
      
    -- 0.11a // 23.12.23
      # fix multiline pattern match
      
    -- 0.11 // 23.12.23
      + UI.fadeout_curnote
      # fix parsing empty lines
      # fix parsing space at start of line
      
    -- 0.10 // 20.12.23
      # Rebuilt all code
      + Action: color  by artist
      + improve UI.fontsz_note + align
      + improve UI.fontsz_artist + align
      + improve UI.fontsz_timecode + align
      - remove timecode_back_fullh / artist_back_fullh
      + UI.txt_separatorH
      - remove UI.txt_yoffset 
      
    -- 0.05 // 11.12.23
      - Remove UI.lines_per_window from freeze mode
      # Support UI.note_h for freeze mode
      # wrap artis row
      # fix UI.offset_note
      # progress bar follow transition
      + Add UI.progress_top_offset
      + fix UI.txt_yoffset 
      
    -- 0.04 // 10.12.23
      # do not display progress bar if already 100%
      + Add UI.progress_right_offset
      + Add UI.progress_use_offset
      + Add UI.progress_enabled
      + Add UI.fontsz_artist
    
    -- 0.03b // 02.12.23
      + Add UI.note_h
      
    -- 0.03a // 02.12.23
      + Add UI.dock
      # add current_progrgess2 for progress bar bound to item edges
      # improve UI.txt_yoffset
      
    -- 0.03 // 02.12.23
      # format timecode as HH:MM:SS
      # improve no track marked message blitting/refresh at project change
      + Highlight off current note is play cursor pass item end
      - remove UI.timecode_width_ratio---+
      
      + Add UI.timecode_width_px
      + Add UI.txt_xoffset
      + Add UI.fill_background_color_alpha
      + Add UI.artist_back_a
      + Add UI.parse_artist, enabled by default, auto parse artist + draw additional row if artist is found
      + Add UI.artist_color_from_itcol
      + Add UI.note_color_from_itcol
      + Add UI.timecode_back_fullh
      + Add UI.artist_back_fullh
      + Menu: freeze mode
      + Keyboard: add space to play
      
    -- 0.02 // 01.12.23
      + Support _conf file to overwrite internal params 
      + UI: progress bar  
      + UI: word wrap
      + UI: dock
      + UI: list simultaneous notes
      + Ext: UI.txt_yoffset - offset each note
      + Ext: UI.progress_col
      + Ext: UI.progress_a
      + Ext: UI.timecode_color_from_itcol
      # fix last note
      
    -- 0.01 29.11.23
      - init reading items
      - allow to set fixed track per project
      - implement inertia
      
  ]]
  
  --  init data ---------------------------------------------------------------------------------------------- 
  DATA = {}
  UI = { 
    -- general
    progress_recordonly = 0,
    
    -- timing
    transition_sec = 0.7,
    fadeout_curnote = 0.9,-- typically 0.9, a progress when active note start to loose alpha when going to end of item
    
    -- item color obeying
    timecode_color_from_itcol = 1,
    artist_color_from_itcol = 1,
    note_color_from_itcol = 1, 
    
    -- normal mode
    offset_note =3,
    
    -- freezemode 
    freezemode_limitratio = 0.8,
    freezemode_incrementpixel = 10,
    freezemode_offsetnote = 1,
    
    -- progress 
    progress_right_offset = 30,
    progress_top_offset = 0,
    progress_col = '#FF0F0F', 
    progress_a = 0.5,
    
    -- width
    timecode_width_px = 100,
    artist_width = 120,
    text_fixed_w = 450,
    
    -- height
    txt_separatorH = 20,
    txt_yoffset = 2,
    
    --colors
    theme_backgr = '#191919',
    txt_col_notrack = '#C5C5C5',
    txt_col_notes = '#C5C5C5',
    txt_col_timecode = '#C5C5C5',
    txt_col_artist = '#C5C5C5',
    
    --alpha
    txt_alpha_active=1,
    txt_alpha_inactive=0.3,
    fill_background_color_alpha=0.4,
    
    -- font
    font = 'SF Pro Display', 
    fontsz_note = 25,
    fontsz_artist = 20,
    fontsz_timecode = 15,
    
    }
  UPD = { ui =                startinit or false,
          onprojstatechange = startinit or false,
          uilayer =           {},
          ext =               startinit or false,
      }    
  EXT = {
    wind_x = 200,
    wind_y = 200,
    wind_w = 400,
    wind_h = 800,
    freeze_mode = 0,
    wind_dock = 0,
    wind_dockID = 1,
    extstate = 'MPL_SubtReader',
    msgtitle = 'SubtReader',
    has_artist_com = 1,
    progress_usetextw = 1, 
    parse_artist = 1, 
    progress_enabled = 1,
        } 
  QUERE = {}
  ---------------------------------------------------------------------------------------------------------------------- 
  function msg(s) if not s then s='nil' end if type(s) == 'boolean' then if s then s = 'true' else  s = 'false' end end ShowConsoleMsg(os.date()..' '..s..'\n') end 
  function Main_EXTSTATE_read() for key in pairs(EXT) do local val = GetExtState(EXT.extstate, key) if key~='extstate' and val ~= '' then EXT[key] = tonumber(val) or val end end end
  function Main_EXTSTATE_write() for key in pairs(EXT) do if key~='extstate' then SetExtState(EXT.extstate, key, EXT[key], true )end  end end
  ----------------------------------------------------------------------------------------------------------------------
  function _GUI_atProjStateChange(flags)  
    DATA.ReaProj = EnumProjects( -1 )
    DATA:Read() 
  end
  ----------------------------------------------------------------------------------------------------------------------
  function GUI_dock()
    local state = gfx.dock(-1)
    if state >0 then state = 0 else state = EXT.wind_dockID end
    gfx.quit()
    UI_init(state)
  end  
------------------------------------------------------------------------------------------------  
  function VF_GetMediaTrackByGUID(optional_proj, GUID)
    local optional_proj0 = optional_proj or 0
    for i= 1, CountTracks(optional_proj0) do tr = GetTrack(0,i-1 )if reaper.GetTrackGUID( tr ) == GUID then return tr end end
    local mast = reaper.GetMasterTrack( optional_proj0 ) if reaper.GetTrackGUID( mast ) == GUID then return mast end
  end  
  ----------------------------------------------------------------------------------------------------------------------
  function DATA:Read_ValidateTrack()
    local retval, val = GetProjExtState( DATA.ReaProj, 'Subtreader_track', 'GUID' )
    if not retval or (retval and val == '') then DATA.track_valid = false return end
    
    local  tr = VF_GetMediaTrackByGUID(DATA.ReaProj, val)
    if not tr then DATA.track_valid = false return end
    DATA.track_valid = true
    DATA.tr = tr
  end
  ----------------------------------------------------------------------------------------------------------------------
  function DATA:Read_itemsinfo_parseArtist(txt)
    local artist, note, has_artist = '', ''
    if txt:match('^%[(.-)%].*') then
      has_artist = true
      artist = txt:match('^%[(.-)%]')
      note = txt:match('%[.-%](.*)')
      note = note:gsub('{.-}','')
      ---if note:match('\n(.*)') then note = note:match('\n(.*)') end
     else
      note = txt
    end 
    return artist, note, has_artist
  end
  ----------------------------------------------------------------------------------------------------------------------
  function DATA:Read_itemsinfo()
    local txt_w = gfx.w-UI.timecode_width_px 
    if EXT.has_artist_com == 1 then txt_w = gfx.w- (UI.artist_width+UI.timecode_width_px) end
    DATA.subt = {}
    local cnt = CountTrackMediaItems( DATA.tr )
    local idx = 0
    
    for i =1 , cnt do
      local it = GetTrackMediaItem(  DATA.tr, i-1 )
      local retval, note = GetSetMediaItemInfo_String( it, 'P_NOTES', '', false )
      local pos = GetMediaItemInfo_Value( it, 'D_POSITION' )
      local len_item = GetMediaItemInfo_Value( it, 'D_LENGTH' )
      local timecode_format = format_timestr_pos( pos, '', 5 )
      if timecode_format:match('%d+%:%d+%:%d+') then timecode_format = timecode_format:match('%d+%:%d+%:%d+') end
      local col = GetMediaItemInfo_Value( it, 'I_CUSTOMCOLOR')
      
      -- read item
      if idx > 0 and pos - DATA.subt[idx].pos < 0.01 then
        -- sub item
        if not DATA.subt[idx].sub then DATA.subt[idx].sub = {} end
        
        local artist, txt,has_artist = '','' if EXT.parse_artist == 1 then artist, txt, has_artist = DATA:Read_itemsinfo_parseArtist(note) else artist, txt = '', note end 
        local retval, itGUID = GetSetMediaItemInfo_String( it, 'GUID', '', 0 )
        local idsub = #DATA.subt[idx].sub+1
        DATA.subt[idx].sub[idsub] = {
                        id=idx,
                        idsub=idsub,
                        note=txt,
                        artist=artist,
                        pos = pos,
                        len_item=len_item,
                        col = col,
                        timecode_format=timecode_format,
                        itGUID=itGUID,
                        itptr = it,
                        }
       else
        -- parent
        idx = idx + 1
        if idx>1 then DATA.subt[idx-1].len = pos - DATA.subt[idx-1].pos end
        
        local artist, txt,has_artist = '','' if EXT.parse_artist == 1 then artist, txt, has_artist = DATA:Read_itemsinfo_parseArtist(note) else artist, txt = '', note end 
        local retval, itGUID = GetSetMediaItemInfo_String( it, 'GUID', '', 0 )
        DATA.subt[idx] = {
                        id=idx,
                        note=txt, 
                        artist=artist,
                        pos = pos,
                        len_item=len_item,
                        col = col,
                        timecode_format=timecode_format,
                        itGUID=itGUID,
                        itptr = it,
                        }

      end
    end
  end
  ----------------------------------------------------------------------------------------------------------------------
  function DATA:Read_separate_multilinetxt_sub(t,font,fontsz,mode0)
    local notetxt = t.note or ''
    notetxt = notetxt:match('[%s+]?(.*)')
    --notetxt=notetxt:gsub('[\r\n]+',' ')
    
    local x0 = UI.timecode_width_px
    if EXT.has_artist_com == 1 then x0 = UI.timecode_width_px + UI.artist_width end 
    
    local txtwlim = math.min(gfx.w-x0,UI.text_fixed_w)
    local mode = 0 if mode0 then mode = mode0 end
    if mode == 1 then 
      txtwlim = UI.artist_width
      notetxt = t.artist or '' 
    end
    
    local outputname = 'note_multiline'
    if mode == 1 then outputname = 'artist_multiline' end
    
    t[outputname] = {}
    if gfx.measurestr(notetxt) < txtwlim and not notetxt:match('[\n\r]+') then
      t[outputname][1] = notetxt
      if mode == 0 then t.note_1stlinew = gfx.measurestr(notetxt)end
      return
    end
      
    local h_txt = gfx.texth 
    local lines = {}
    
    
    if mode == 0 then
      -- txt
      local i = 1
      for word in notetxt:gmatch('[^%s]+') do
        if not lines[i] then lines[i] = {} end
        lines[i][#lines[i]+1] = word
        local comline_test = table.concat(lines[i], ' ')
        if gfx.measurestr(comline_test) > txtwlim then -- reset
          table.remove(lines[i],#lines[i])
          i = i + 1
          lines[i] = {}
          lines[i][1] = word
        end
      end
      for i = 1, #lines do
        local comline_test = table.concat(lines[i], ' ')
        t[outputname][i] = comline_test
      end
      
     else 
      -- artist
      for artist in notetxt:gmatch('(%[.-%])') do t[outputname][#t[outputname]+1] = artist end
      if #t[outputname] == 0 then t[outputname][1] = notetxt end
    end
    
    
    -- check for empty lines
    for i = #t[outputname],1,-1 do if t[outputname][i] == '' then table.remove(t[outputname], i) end end
    
    if #t[outputname] > 0 and mode == 0 then t.note_1stlinew = gfx.measurestr(t[outputname][1]) end
    
  end
  ----------------------------------------------------------------------------------------------------------------------
  function DATA:Read_separate_multilinetxt()
    gfx.setfont(1,UI.font or 'Arial', UI.fontsz_note+1, '' )
    for i = 1, #DATA.subt do
      DATA:Read_separate_multilinetxt_sub(DATA.subt[i], UI.font, UI.fontsz_note)
      DATA:Read_separate_multilinetxt_sub(DATA.subt[i], UI.font, UI.fontsz_note,1)
      if DATA.subt[i].sub then for j = 1, #DATA.subt[i].sub do 
        DATA:Read_separate_multilinetxt_sub(DATA.subt[i].sub[j], UI.font, UI.fontsz_artist) 
        DATA:Read_separate_multilinetxt_sub(DATA.subt[i].sub[j], UI.font, UI.fontsz_artist, 1) 
      end end
    end
    
  end
  ----------------------------------------------------------------------------------------------------------------------
  function DATA:Read_calculateinitYoffset_sub(t)
    local shift = DATA.yoffset_texth * #t.note_multiline
    t.yoffset = DATA.yoffset
    DATA.yoffset = DATA.yoffset + shift + UI.txt_separatorH
  end
  ----------------------------------------------------------------------------------------------------------------------
  function DATA:Read_calculateinitYoffset() 
    DATA.yoffset = 0
    gfx.setfont(1,UI.font or 'Arial',   
      math.max(UI.fontsz_note,UI.fontsz_artist,UI.fontsz_timecode)
      , '' )
      
    DATA.yoffset_texth = gfx.texth--+UI.txt_separatorH
    for i = 1, #DATA.subt do
      DATA:Read_calculateinitYoffset_sub(DATA.subt[i])
      
      
      if DATA.subt[i].sub then for j = 1, #DATA.subt[i].sub do 
        DATA:Read_calculateinitYoffset_sub(DATA.subt[i].sub[j])  
      end end
    end
  end
  ----------------------------------------------------------------------------------------------------------------------
  function DATA:Read_calculateHcom()
    for i = 1, #DATA.subt do 
      local h = math.max( #DATA.subt[i].artist_multiline,#DATA.subt[i].note_multiline)*gfx.texth
      if DATA.subt[i].sub then for j = 1, #DATA.subt[i].sub do h =h+ UI.txt_separatorH + math.max( #DATA.subt[i].sub[j].artist_multiline,#DATA.subt[i].sub[j].note_multiline)*gfx.texth end end 
      DATA.subt[i].comh = h
    end
  end
  ----------------------------------------------------------------------------------------------------------------------
  function DATA:Read()
    DATA.subt = {} -- reset
    DATA.ReaProj = EnumProjects( -1 ) 
    DATA:Read_ValidateTrack()
    if DATA.track_valid ~= true then return end
    DATA:Read_itemsinfo()
    DATA:Read_separate_multilinetxt()
    DATA:Read_calculateinitYoffset()
    DATA:Read_calculateHcom()
  end
  ----------------------------------------------------------------------------------------------------------------------
  function DATA:Write_SeSeltrackAsMain()
    local tr = GetSelectedTrack(0,0)
    if tr then
      local trGUID = reaper.GetTrackGUID( tr )
      SetProjExtState( DATA.ReaProj, 'Subtreader_track', 'GUID', trGUID )
      DATA:Read()
    end
    UPD.ui = true
  end

  ---------------------------------------------------------------------------------------------------------------------
  function UI_draw_backgr() 
    local layer = 1
    if UPD.ui == true then
      gfx.dest = layer -- background
      gfx.setimgdim(layer, -1, -1)
      gfx.setimgdim(layer, gfx.w,gfx.h)
      UI_setHex(UI.theme_backgr) gfx.a = 1 gfx.rect(0,0,gfx.w,gfx.h)
    end 
  end
  ---------------------------------------------------------------------------------------------------------------------
  function UI_draw_notrack() 
      --UI_setHex(UI.txt_col_notrack or '#FFFFFF') 
      gfx.set(1,1,1,1)
      --gfx.a = 1   
      --gfx.setfont(1,UI.font or 'Arial', UI.fontsz_notrack, '' )
      
      local offs = 10
      gfx.x = offs
      gfx.y = offs
      gfx.set(1,1,1,1)
      gfx.drawstr('[No track pinned / Select track and click]')
  end
  --------------------------------------------------------------------------------------------------------------------- 
  function UI2_DrawStuff_timecode(t,setalpha)
    local x0 = 0 
    local y0 = t.yoffset - DATA.yoffset_listshift -- UI.txt_yoffset + 
    
    if not t then return end
    gfx.setfont(1,UI.font_timecode or 'Arial', UI.fontsz_timecode, '' )
    if UI.timecode_color_from_itcol == 1 then 
      local itcol = t.col
      if itcol ~= 0 then
        local r, g, b = reaper.ColorFromNative( itcol ) gfx.set(r/255,g/255,b/255)
        gfx.a = UI.fill_background_color_alpha
        local h0 = gfx.texth
        gfx.rect(x0 ,y0,UI.timecode_width_px-1,t.comh-2+UI.txt_separatorH,1)--DATA.yoffset_texth-1,1)--math.floor(gfx.w*UI.timecode_width_ratio)
      end
    end
    UI_setHex(UI.txt_col_timecode or '#FFFFFF') 
    gfx.a = t.setalpha  or UI.txt_alpha_inactive
    gfx.x = x0  --+ UI.txt_xoffset
    gfx.y = y0+ UI.txt_yoffset
    --gfx.drawstr(t.timecode_format)
    
    --[[
    flags&1: center horizontally
    flags&2: right justify
    flags&4: center vertically
    flags&8: bottom justify
    ]]
    local flags = 1|4
    gfx.drawstr(t.timecode_format, flags, UI.timecode_width_px + x0,y0 + DATA.yoffset_texth+ UI.txt_yoffset) 
    
    if y0 > gfx.h then return true end
  end
  --------------------------------------------------------------------------------------------------------------------- 
  function UI2_DrawStuff_txt(t,setalpha)
    if not t then return end
    
    local x0 = UI.timecode_width_px
    if EXT.has_artist_com == 1 then x0 = UI.timecode_width_px + UI.artist_width end 
    local y0 = t.yoffset - DATA.yoffset_listshift --UI.txt_yoffset + 
    
    gfx.setfont(1,UI.font_timecode or 'Arial', UI.fontsz_note, '' )
    if UI.note_color_from_itcol == 1 then 
      local itcol = t.col
      if itcol ~= 0 then
        local r, g, b = reaper.ColorFromNative( itcol ) gfx.set(r/255,g/255,b/255)
        gfx.a = UI.fill_background_color_alpha
        local h0 = gfx.texth
        gfx.rect(x0,y0,gfx.w-x0,t.comh-2+UI.txt_separatorH,1)--math.floor(gfx.w*UI.timecode_width_ratio)
      end
    end
    UI_setHex(UI.txt_col_notes or '#FFFFFF') 
    gfx.a = t.setalpha or UI.txt_alpha_inactive
    
    for i = 1, #t.note_multiline do 
      local ycur = y0 + gfx.texth*(i-1)
      gfx.x = x0
      gfx.y = ycur+ UI.txt_yoffset
      --gfx.drawstr(t.note_multiline[i]) 
      
      --gfx.drawstr(t.timecode_format)
      
      --[[
      flags&1: center horizontally
      flags&2: right justify
      flags&4: center vertically
      flags&8: bottom justify
      ]]
      local flags = 4
      gfx.drawstr(t.note_multiline[i], flags, math.min(gfx.w,x0+UI.text_fixed_w) , ycur + DATA.yoffset_texth+ UI.txt_yoffset  ) 
      
    end  
    return x0,y0,t.note_1stlinew
  end
  --------------------------------------------------------------------------------------------------------------------- 
  function UI2_DrawStuff_calcalpha(t)
    -- cur note
    t.setalpha = UI.txt_alpha_inactive
    if DATA.curnote_Id and t.id and DATA.curnote_Id == t.id then
      if DATA.curnote_progress2 then
        
        if DATA.curnote_progress2 > 0 and DATA.curnote_progress2 < UI.fadeout_curnote then
          t.setalpha = UI.txt_alpha_active
         else
          local transition = 1-((DATA.curnote_progress2 - UI.fadeout_curnote) *10)
          t.setalpha = UI.txt_alpha_inactive + (UI.txt_alpha_active - UI.txt_alpha_inactive) * transition
        end
      end
    end
    -- next note
    if DATA.curnote_Id and t.id and DATA.curnote_Id == t.id-1 and DATA.trans_progress ~= 0 then t.setalpha = UI.txt_alpha_inactive + (UI.txt_alpha_active - UI.txt_alpha_inactive) * DATA.trans_progress end
    t.setalpha = math.min(1,math.max(t.setalpha,0))
  end
  --------------------------------------------------------------------------------------------------------------------- 
  function UI2_DrawStuff_artist(t)
    if EXT.has_artist_com == 0 then return end 
    if not t then return end
    
    local x0 = UI.timecode_width_px
    local y0 =  t.yoffset - DATA.yoffset_listshift --UI.txt_yoffset +
    
    gfx.setfont(1,UI.font_timecode or 'Arial', UI.fontsz_artist, '' )
    
    if UI.artist_color_from_itcol == 1 then 
      local itcol = t.col
      if itcol ~= 0 then
        local r, g, b = reaper.ColorFromNative( itcol ) gfx.set(r/255,g/255,b/255)
        gfx.a = UI.fill_background_color_alpha
        local h0 = gfx.texth
        gfx.rect(x0,y0,UI.artist_width-1,t.comh-2+UI.txt_separatorH,1)
      end
    end
    
    UI_setHex(UI.txt_col_artist or '#FFFFFF') 
    gfx.a = t.setalpha or UI.txt_alpha_inactive
    for i = 1, #t.artist_multiline do 
      local ycur = y0 + gfx.texth*(i-1)
      gfx.x = x0 --+UI.txt_yoffset
      gfx.y = ycur+ UI.txt_yoffset
      --[[
      flags&1: center horizontally
      flags&2: right justify
      flags&4: center vertically
      flags&8: bottom justify
      ]]
      local flags = 1|4
      gfx.drawstr(t.artist_multiline[i], flags,UI.artist_width + x0,ycur + DATA.yoffset_texth+ UI.txt_yoffset) 
    end 
  end
  --------------------------------------------------------------------------------------------------------------------- 
  function UI2_DrawStuff_progress(t,x,y,w)
    if not x then return end
    if t.id and t.id ~= DATA.curnote_Id then return end
    if EXT.progress_enabled == 0 then return end
    if not (UI.progress_recordonly == 0 or (UI.progress_recordonly == 1 and  reaper.GetPlayState()&4==4)) then return end
    UI_setHex(UI.progress_col or '#FFFFFF') 
    gfx.a = UI.progress_a
    local progress = DATA.curnote_progress2 or 0

    
    if progress > 0 and progress < 1 then
      if EXT.progress_usetextw == 0 then 
        gfx.rect(x,y+UI.progress_top_offset,(gfx.w-x-UI.progress_right_offset)*progress,3,1)
       else
        gfx.rect(x,y,w*progress,3,1)
      end
    end
  end
  --------------------------------------------------------------------------------------------------------------------- 
  function DATA:calc_inertia()
    local trans_progress = 1-(DATA.curnote_remaining / UI.transition_sec)
    trans_progress = math.min(1,math.max(trans_progress,0))
    trans_progress2 =(0.5+0.5*(math.cos(math.pi*trans_progress-math.pi)))^2
    DATA.trans_progress = trans_progress
    if trans_progress >0 and trans_progress < 1 then DATA.trans_progress = trans_progress2 end
    
     
  end
  --------------------------------------------------------------------------------------------------------------------- 
  function UI2_DrawStuff_freezemode()
    DATA.trans_progress = 0
    if not DATA.yoffset_listshift then DATA.yoffset_listshift = 0 end
    
    
    local cur_offset = DATA.subt[DATA.curnote_Id].yoffset 
    local prev_offset = cur_offset
    if DATA.subt[DATA.curnote_Id-UI.freezemode_offsetnote] then prev_offset = DATA.subt[DATA.curnote_Id-UI.freezemode_offsetnote].yoffset end
    
    if cur_offset < DATA.yoffset_listshift then
      DATA.yoffset_listshift_set = prev_offset
     elseif cur_offset - DATA.yoffset_listshift > gfx.h*UI.freezemode_limitratio then
      DATA.yoffset_listshift_set = prev_offset
    end
    
    if DATA.yoffset_listshift_set then
      if DATA.yoffset_listshift_set < DATA.yoffset_listshift then
        DATA.yoffset_listshift = DATA.yoffset_listshift_set
       elseif DATA.yoffset_listshift_set > DATA.yoffset_listshift then
        if DATA.yoffset_listshift_set - DATA.yoffset_listshift > gfx.h then
          DATA.yoffset_listshift = DATA.yoffset_listshift_set
         else
          DATA.yoffset_listshift = math.min(DATA.yoffset_listshift_set,DATA.yoffset_listshift + UI.freezemode_incrementpixel)
        end
      end
    end
    
    local ret_outofbounds,x,y,w 
    local st = math.max(1,DATA.curnote_Id-30)
    for i = st, #DATA.subt do
      if DATA.subt[i] and DATA.subt[i].id then   
        UI2_DrawStuff_calcalpha(DATA.subt[i])
        ret_outofbounds = UI2_DrawStuff_timecode(DATA.subt[i])
        if ret_outofbounds == true then return end
        UI2_DrawStuff_artist(DATA.subt[i])
        local x,y,w = UI2_DrawStuff_txt(DATA.subt[i])
        UI2_DrawStuff_progress(DATA.subt[i], x,y,w)
        if DATA.subt[i].sub then
          for j = 1, #DATA.subt[i].sub do
            UI2_DrawStuff_artist(DATA.subt[i].sub[j])
            x,y,w = UI2_DrawStuff_txt(DATA.subt[i].sub[j])
          end
        end
      end
    end 
    
  end
  --------------------------------------------------------------------------------------------------------------------- 
  function UI2_DrawStuff()
    
    if not DATA.curnote_Id then return end
    if #DATA.subt < 1 then return end
    
    if EXT.freeze_mode == 1 then
      UI2_DrawStuff_freezemode()
      return
    end
    
    
    if EXT.freeze_mode == 0 then
      local yoffsid = math.min(math.max(1,DATA.curnote_Id-UI.offset_note), #DATA.subt)  
      DATA.yoffset_listshift = DATA.subt[yoffsid].yoffset  
      DATA:calc_inertia()
      if DATA.trans_progress ~= 1 then DATA.yoffset_listshift = DATA.yoffset_listshift + DATA.trans_progress * (DATA.subt[yoffsid].comh +UI.txt_separatorH) end 
      if DATA.curnote_Id < 1 + UI.offset_note then DATA.yoffset_listshift = 0 end
      DATA.yoffset_listshift = math.floor(DATA.yoffset_listshift)
    end
    
    
    local ret_outofbounds,x,y,w
    for i = DATA.curnote_Id-UI.offset_note, #DATA.subt do
      if DATA.subt[i] and DATA.subt[i].id then 
        UI2_DrawStuff_calcalpha(DATA.subt[i])
        ret_outofbounds = UI2_DrawStuff_timecode(DATA.subt[i])
        if ret_outofbounds == true then return end
        UI2_DrawStuff_artist(DATA.subt[i])
        local x,y,w = UI2_DrawStuff_txt(DATA.subt[i])
        UI2_DrawStuff_progress(DATA.subt[i], x,y,w)
        if DATA.subt[i].sub then
          for j = 1, #DATA.subt[i].sub do
            UI2_DrawStuff_artist(DATA.subt[i].sub[j])
            x,y,w = UI2_DrawStuff_txt(DATA.subt[i].sub[j])
          end
        end
      end
    end 

  end
  ---------------------------------------------------------------------------------------------------------------------
  function UI_draw()  
    UI_draw_backgr()
    gfx.dest = -1 
    gfx.a = 1
    gfx.blit(1, 1, 0, 0,0,gfx.w,gfx.h, 0,0,gfx.w,gfx.h, 0,0) 
    if DATA.track_valid == true then
      UI2_DrawStuff()
    end
    if DATA.track_valid ~= true then gfx.dest = -1 gfx.a = 1 UI_draw_notrack() end
    gfx.update()
  end
  ---------------------------------------------------
  function UI_menu(t)
    local str, check ,hidden,submenu,submenu_end,subsubmenu_endmenu= '', '','','',''
    local remapped_functionsID = 0
    local inc = 0
    for i = 1, #t do
      remapped_functionsID = remapped_functionsID + 1
      local map0 = remapped_functionsID
      if t[i].state==true then check = '!' else check = '' end
      if t[i].hidden then hidden = '#' else hidden = '' end
      if t[i].submenu_end then submenu_end = '|<' else subsubmenu_endmenu = '' end
      if t[i].str == '' then map0 = -1 remapped_functionsID = remapped_functionsID -1 end--remapped_functionsID = 1 inc = inc + 1
      if t[i].submenu then submenu = '>'  map0 = -1 remapped_functionsID = remapped_functionsID -1 else submenu = '' end--remapped_functionsID = 0 inc = inc + 1
      t[i].map = map0
      str = str..submenu..check..hidden..t[i].str..submenu_end
      str = str..'|' 
    end
    gfx.x = gfx.mouse_x
    gfx.y = gfx.mouse_y
    local ret = gfx.showmenu(str) 
    for i = 1, #t do 
      if t[i].map == ret and t[i].func then  
        t[i].func()
        break 
      end 
    end 
  end
  ------
  -----------------------------------------------------------------------------  
  function UI_handleProjUpdates()
    local SCC =  GetProjectStateChangeCount( 0 )
    if (UI.lastSCC and UI.lastSCC~=SCC ) then UPD.onprojstatechange = true end
    UI.lastSCC = SCC
    
    local editcurpos =  GetCursorPosition() 
    if (UI.last_editcurpos and UI.last_editcurpos~=editcurpos ) then UPD.onprojstatechange = true end
    UI.last_editcurpos=editcurpos 
    
    local reaproj = tostring(EnumProjects( -1 ))
    UI.reaproj = reaproj
    if UI.last_reaproj and UI.last_reaproj ~= UI.reaproj then UPD.onprojtabchange = true end
    UI.last_reaproj = reaproj
  end
  ---------------------------------------------------------------------------------------------------------------------          
  function UI_init(state)  
    gfx.ext_retina = UI.retina or 0
    gfx.init((UI_title or 'Test')..' '..version,EXT.wind_w,EXT.wind_h,EXT.wind_dock,EXT.wind_x,EXT.wind_y)  --state or EXT.wind_dock
    UI.retina_scaling = gfx.ext_retina
    --UI.retina_scaling = 2
  end 
  ---------------------------------------------------------------------------------------------------------------------
  function UI_handlexywhchange()
    local  dock, wx,wy,ww,wh = gfx.dock(-1, 0,0,0,0)
    ww = gfx.w
    wh = gfx.h
    if not UI.gfxx_last or  
      (UI.gfxx_last 
      and (UI.gfxw_last ~= ww 
      or UI.gfxh_last ~= wh
      or UI.gfxx_last ~= wx
      or UI.gfxy_last ~= wy
      or UI.gfxdock_last ~= dock
      ) )
      then 
      UPD.ui = true
      UPD.ext = true
      EXT.wind_x = wx
      EXT.wind_y = wy
      EXT.wind_w = ww
      EXT.wind_h = wh
      EXT.wind_dock = dock
      if dock > 0 then EXT.wind_dockID = dock end
    end
    UI.gfxx_last = wx
    UI.gfxy_last = wy
    UI.gfxw_last = ww--gfx.w
    UI.gfxh_last = wh--gfx.h
    UI.gfxdock_last = dock
  end
  ---------------------------------------------------------------------------------------------------------------------
  function translit2english(ru_str)
    local map = {
      ['а']='00a',
      ['б']='00b',
      ['в']='00v',
      ['г']='00g',
      ['д']='00d',
      ['е']='0ye',
      ['ё']='0yo',
      ['ж']='0zh',
      ['з']='00z',
      ['и']='00i',
      ['й']='00j',
      ['к']='00k',
      ['л']='00l',
      ['м']='00m',
      ['н']='00n',
      ['о']='00o',
      ['п']='00p',
      ['р']='00r',
      ['с']='00s',
      ['т']='00t',
      ['у']='00u',
      ['ф']='00f',
      ['х']='00h',
      ['ц']='00c',
      ['ч']='0ch',
      ['ш']='0sh',
      ['щ']='sch',
      ['ъ']='00`',
      ['ы']='0yi',
      ['ь']='0``',
      ['э']='0ae',
      ['ю']='00u',
      ['я']='0ya',
      }
      
      --[[local map = {
      ['а']='00a',
      ['А']='00a',
      ['б']='00b',
      ['Б']='00b',
      ['в']='00v',
      ['В']='00v',
      ['г']='00g',
      ['Г']='00g',
      ['д']='00d',
      ['Д']='00d',
      ['е']='0ye',
      ['Е']='0ye',
      ['ё']='0yo',
      ['Ё']='0yo',
      ['ж']='0zh',
      ['Ж']='0zh',
      ['з']='00z',
      ['З']='00z',
      ['и']='00i',
      ['И']='00i',
      ['й']='00j',
      ['Й']='00j',
      ['к']='00k',
      ['К']='00k',
      ['л']='00l',
      ['Л']='00l',
      ['м']='00m',
      ['М']='00m',
      ['н']='00n',
      ['Н']='00n',
      ['о']='00o',
      ['О']='00o',
      ['п']='00p',
      ['П']='00p',
      ['р']='00r',
      ['Р']='00r',
      ['с']='00s',
      ['С']='00s',
      ['т']='00t',
      ['Т']='00t',
      ['у']='00u',
      ['У']='00u',
      ['ф']='00f',
      ['Ф']='00f',
      ['х']='00h',
      ['Х']='00h',
      ['ц']='00c',
      ['Ц']='00c',
      ['ч']='0ch',
      ['Ч']='0ch',
      ['ш']='0sh',
      ['Ш']='0sh',
      ['щ']='sch',
      ['Щ']='sch',
      ['ъ']='00`',
      ['Ъ']='00`',
      ['ы']='0yi',
      ['Ы']='0yi',
      ['ь']='0``',
      ['Ь']='0``',
      ['э']='0ae',
      ['Э']='0ae',
      ['ю']='00u',
      ['Ю']='00u',
      ['я']='0ya',
      ['Я']='0ya',
      }]]
    local out = ''
    for pos, codepoint in utf8.codes(ru_str) do 
      if utf8.char(codepoint) then 
        local chrru = utf8.char(codepoint)
        if map[chrru] then chrru = map[chrru] end
        out = out..chrru
      end
    end
    return out
  end
  ----------------------------------------------------------------------------------------------------------------------
  function DATA:Color_ByText(inputtxt)
    if not (inputtxt and inputtxt ~= '' ) then return end
    reaper.Undo_BeginBlock2( 0 )
    
    inputtxt = translit2english(inputtxt)
    local retval, color = reaper.GR_SelectColor(  reaper.GetMainHwnd() )
    if retval == 0 then return end 
    for i = 1, #DATA.subt do
      if translit2english(DATA.subt[i].note):match(inputtxt)  or (DATA.subt[i].artist and translit2english(DATA.subt[i].artist):match(inputtxt))
        then 
          reaper.SetMediaItemInfo_Value( DATA.subt[i].itptr, 'I_CUSTOMCOLOR', color|0x1000000) 
          reaper.SetMediaItemSelected( DATA.subt[i].itptr, true )
        end
    end 
    UPD.ui = true
    UPD.onprojstatechange = true
    reaper.UpdateArrange()
    
    reaper.Undo_EndBlock2( 0, 'Color by text', 0xFFFFFFFF )
  end
  ----------------------------------------------------------------------------------------------------------------------
  function DATA:Color_Artist(mode, artist_t)
    if not DATA.curnote_Id then return end
    if not mode then mode  =  0 end
    reaper.Undo_BeginBlock2( 0 )
    local curnote = DATA.curnote_Id
    local curartist = translit2english(DATA.subt[curnote].artist )
    
    local retval, color = reaper.GR_SelectColor(  reaper.GetMainHwnd() )
    if retval == 0 then return end 
    for i = 1, #DATA.subt do
      if mode == 0 and curartist == translit2english(DATA.subt[i].artist) then reaper.SetMediaItemInfo_Value( DATA.subt[i].itptr, 'I_CUSTOMCOLOR', color|0x1000000) end
      if mode == 1 then
        for j=1, #artist_t do
          local artist = artist_t[j]
          if artist:gsub('[%s%p]+','') == DATA.subt[i].artist:gsub('[%s%p]+','') then 
            reaper.SetMediaItemInfo_Value( DATA.subt[i].itptr, 'I_CUSTOMCOLOR', color|0x1000000) 
            reaper.SetMediaItemSelected( DATA.subt[i].itptr, true )
          end
        end
      end
    end 
    UPD.ui = true
    UPD.onprojstatechange = true
    reaper.UpdateArrange()
    
    reaper.Undo_EndBlock2( 0, 'Color artist', 0xFFFFFFFF )
    
  end
  ----------------------------------------------------------------------------------------------------------------------
  function DATA:menu()
    local t = {
          {str = '#Actions:'},
          { str = 'Set selected track as main', func = function() DATA:Write_SeSeltrackAsMain() end },
          { str = 'Color current artist items', func = function() DATA:Color_Artist() end },
          { str = 'Color artist by exact name', func = function() 
              local retval, retvals_csv = reaper.GetUserInputs( 'Artist to color', 1, ',extrawidth=400', '' )
              if not retval then return end
              
              if retvals_csv:len()==1023 then
                MB('Input is too long', 'ColByArtist',0)
              end
              if retvals_csv:lower():match('%.txt') then
                local f = io.open(retvals_csv, 'rb')
                if f then 
                  retvals_csv = f:read('a') 
                  f:close()
                 else
                  MB('File not found', 'ColByArtist',0)
                  return
                end
              end
              
              artists= {}
              retvals_csv = retvals_csv:gsub('//','')
              for word in retvals_csv:gmatch('[^,]+') do
                if word:match('%s+(.*)') then word = word:match('%s+(.*)') end
                artists[#artists+1] = word 
              end  
              DATA:Color_Artist(1,artists) 
            end }, 
          { str = 'Color items by matched text', func = function() 
              local retval, retvals_csv = reaper.GetUserInputs( 'Color items by matched text', 1, ',extrawidth=400', '' )
              if not retval then return end
              DATA:Color_ByText(retvals_csv) 
            end },
          { str = 'Dock|',  state = EXT.wind_dock == 1,  func = function() EXT.wind_dock = EXT.wind_dock~1 UPD.onprojstatechange = true UPD.ext = true GUI_dock() end },
          {str = '#Options:'},
          { str = 'Freeze mode',  state = EXT.freeze_mode == 1,  func = function() EXT.freeze_mode = EXT.freeze_mode~1 UPD.onprojstatechange = true UPD.ext = true  end },
          { str = 'Show role',  state = EXT.has_artist_com == 1,  func = function() EXT.has_artist_com = EXT.has_artist_com~1 UPD.onprojstatechange = true  UPD.ext = true  end },
          { str = 'Parse artist',  state = EXT.parse_artist == 1,  func = function() EXT.parse_artist = EXT.parse_artist~1 UPD.onprojstatechange = true  UPD.ext = true  end },
          { str = 'Progress: enabled',  state = EXT.progress_enabled == 1,  func = function() EXT.progress_enabled = EXT.progress_enabled~1 UPD.onprojstatechange = true  UPD.ext = true  end },
          { str = 'Progress: use text width',  state = EXT.progress_usetextw == 1,  func = function() EXT.progress_usetextw = EXT.progress_usetextw~1 UPD.onprojstatechange = true  UPD.ext = true  end },
          
        }
    UI_menu(t)
  end
  ----------------------------------------------------------------------------------------------------------------------
  function _RT()  
    DATA.clock = os.clock()
    DATA.playpos = GetPlayPosition()
    if GetPlayState()&1~=1 then DATA.playpos = GetCursorPosition() end
    
    -- no data
    if not DATA.track_valid == true then
      if UI.mouse_Lrelease == true then DATA:Write_SeSeltrackAsMain() end
    end
    
    -- right menu
    if UI.mouse_Rrelease == true then DATA:menu() end
    
    -- search current note
    if DATA.track_valid == true then RT_GetCurrentNote() end
  end
  ---------------------------------------------------------------------------------------------------------------------
  function RT_GetCurrentNote()
    --[[if not DATA.last_clock then DATA.last_clock = DATA.clock end
    if DATA.clock - DATA.last_clock < 0.1 then return end 
    DATA.last_clock = DATA.clock]]
    
    -- get cur note
    local comcnt = #DATA.subt
    --[[for i = 1,comcnt-1 do
    
      if DATA.playpos > DATA.subt[i].pos and DATA.playpos < DATA.subt[i+1].pos then 
        DATA.curnote_Id = i
        DATA.curnote_progress = 0
        if i <comcnt then
          DATA.curnote_progress = (DATA.playpos-DATA.subt[i].pos) / (DATA.subt[i+1].pos-DATA.subt[i].pos)
          DATA.curnote_progress2 = math.min((DATA.playpos-DATA.subt[i].pos) / (  (DATA.subt[i].pos+DATA.subt[i].len_item)-DATA.subt[i].pos),1)
          DATA.curnote_remaining = (1-DATA.curnote_progress) * DATA.subt[i].len
          DATA.curnote_afteritem = DATA.playpos > DATA.subt[i].pos + DATA.subt[i].len_item
        end 
        break
      end
      
    end]]
    
    IDst = 1
    IDsep = math.floor(#DATA.subt / 2)
    IDend = #DATA.subt
    cnt_try = #DATA.subt
    
    for i = 1, cnt_try do
      if DATA.subt[IDst] and DATA.subt[IDsep] and DATA.subt[IDend] then
        if DATA.playpos >= DATA.subt[IDst].pos and DATA.playpos <= DATA.subt[IDsep].pos then 
          IDst = IDst
          IDend = IDsep
          IDsep = math.floor(IDsep / 2) 
        end
        
        if DATA.playpos > DATA.subt[IDsep].pos and DATA.playpos <= DATA.subt[IDend].pos then 
          IDst = IDsep
          IDend = IDend
          IDsep = IDsep + math.floor((IDend - IDsep) / 2) 
        end
        
        if IDend - IDst < 2 then
          i = IDst
          DATA.curnote_Id = i
          DATA.curnote_progress = 0
          if i <comcnt then
            DATA.curnote_progress = (DATA.playpos-DATA.subt[i].pos) / (DATA.subt[i+1].pos-DATA.subt[i].pos)
            DATA.curnote_progress2 = math.min((DATA.playpos-DATA.subt[i].pos) / (  (DATA.subt[i].pos+DATA.subt[i].len_item)-DATA.subt[i].pos),1)
            DATA.curnote_remaining = (1-DATA.curnote_progress) * DATA.subt[i].len
            DATA.curnote_afteritem = DATA.playpos > DATA.subt[i].pos + DATA.subt[i].len_item
          end 
          break
        end
        
      end
      ::nexttry::
    end
    
    
    if DATA.subt[comcnt] and DATA.playpos > DATA.subt[comcnt].pos then
      DATA.curnote_Id =comcnt 
      DATA.curnote_progress = 0
      DATA.curnote_progress2 = 0
      DATA.curnote_remaining = 0
    end
    
    if GetPlayState()&1~=1 then 
      DATA.follow_ID = DATA.curnote_Id 
     else
      if not DATA.follow_ID then DATA.follow_ID = DATA.curnote_Id  end
      --if DATA.follow_ID and DATA.curnote_Id > DATA.follow_ID + UI.lines_per_window -2 then DATA.follow_ID = DATA.curnote_Id  end
    end
    test = DATA.subt[DATA.curnote_Id ]
  end
  ---------------------------------------------------------------------------------------------------------------------
  function QUERE_perform()
    if #QUERE == 0 then return end
    local sched_time = 0.5
    if not DATA.queretrig or (DATA.queretrig and os.clock() - DATA.queretrig  > sched_time) then
      local f = QUERE[1]
      f{}
      table.remove(QUERE, 1) 
      DATA.queretrig = os.clock()
    end
    
  end
  ---------------------------------------------------------------------------------------------------------------------
  function UI_setHex(hex_str) -- https://gist.github.com/jasonbradley/4357406
    if not hex_str then return end
    local hex = hex_str:gsub("#","")
    local r,g,b = tonumber("0x"..hex:sub(1,2)), tonumber("0x"..hex:sub(3,4)), tonumber("0x"..hex:sub(5,6))
    gfx.set(r/255,g/255,b/255) 
  end
  ---------------------------------------------------------------------------------------------------------------------
  function UI_mouse()
    UI.mouse_char = math.floor(gfx.getchar())
    UI.mouse_cap = gfx.mouse_cap 
    UI.mouse_moving = not UI.mouse_x or (UI.mouse_x ~= gfx.mouse_x or UI.mouse_y ~= gfx.mouse_y)
    UI.mouse_x = gfx.mouse_x
    UI.mouse_y = gfx.mouse_y 
    UI.kbCtrl = UI.mouse_cap&4==4
    UI.kbShift = UI.mouse_cap&8==8
    UI.wheel = gfx.mouse_wheel
    if UI.wheel_last then
      UI.wheel_trig = UI.wheel_last ~= UI.wheel
      UI.wheel_dir = UI.wheel_last < UI.wheel
    end
    UI.wheel_last = UI.wheel
    
    
    UI.mouse_Lstate = gfx.mouse_cap&1 == 1 
    UI.mouse_Ltrig = (UI.mouse_Lstatelast~= nil and UI.mouse_Lstatelast==false and UI.mouse_Lstate==true)
    UI.mouse_Lrelease = (UI.mouse_Lstatelast~= nil and UI.mouse_Lstatelast==true and UI.mouse_Lstate== false)
    UI.mouse_Lstatelast = UI.mouse_Lstate
    
    UI.mouse_Rstate = gfx.mouse_cap&2 == 2
    UI.mouse_Rtrig = (UI.mouse_Rstatelast~= nil and UI.mouse_Rstatelast==false and UI.mouse_Rstate==true)
    UI.mouse_Rrelease = (UI.mouse_Rstatelast~= nil and UI.mouse_Rstatelast==true and UI.mouse_Rstate== false)
    UI.mouse_Rstatelast = UI.mouse_Rstate
     
    -- handle drop stuff
    UI.droppedfiles = {files = {}, exist = false}
    for i = 0, 1000 do
      local DRret, DRstr = gfx.getdropfile(i)
      if DRret == 0 then break end
      UI.droppedfiles.files[i+1] = DRstr
      UI.droppedfiles.exist = true
    end
    gfx.getdropfile(-1)
    
    -- trigger elements refresh
    local refreshoffs = 200 -- offset boundaries for hovering check 
    UI.hovered_t = {}
    if (UI.mouse_moving ==true  and (UI.mouse_x>-refreshoffs and  UI.mouse_x<gfx.w+refreshoffs and UI.mouse_y>-refreshoffs and  UI.mouse_y<gfx.h+refreshoffs ))
      or UI.mouse_Ltrig == true 
      or UI.mouse_Rtrig == true 
      or UI.droppedfiles.exist == true
      or UI.mouse_latchkey ~= nil
      then 
      UI_UpdateElements()
    end 
    
    --handle latch
    if UI.mouse_Lstate == true and UI.mouse_latchkey and UI.mouse_latchvalue and UI.elm[UI.mouse_latchkey] and UI.elm[UI.mouse_latchkey].is_slider then
      local outval = UI.mouse_latchvalue + (UI.mouse_y - UI.mouse_latchy) / (UI.elm[UI.mouse_latchkey].value_harea or gfx.h)
      outval = math.min( math.max(outval, 0),1)
      UI.elm[UI.mouse_latchkey].value = outval
      if UI.elm[UI.mouse_latchkey].func_ondragL then UI.elm[UI.mouse_latchkey].func_ondragL() end
    end
    
    
    
  end  
  ---------------------------------------------------------------------------------------------------------------------
  function UI_UpdateElements()
    if not UI.elm then return end
    for key in pairs(UI.elm) do
      if key~= '__index' and type(UI.elm[key]) ~= 'function' and not UI.elm[key].ignoremouse then 
        UI.elm[key]:mouse_handlehovering()  
      end 
    end
  end 
  ---------------------------------------------------------------------------------------------------------------------
  function UI_run()
    
    -- data loop
    local char = gfx.getchar() 
    -- UI draw
    UI_handlexywhchange() 
    UI_handleProjUpdates()
    QUERE_perform()
    
    
    _RT()
    if UPD.ui == true and _GUI_build then _GUI_build() UPD.ui = false end  -- generates all the controls stuff
    if (UPD.ui == true or UPD.onprojstatechange == true) and _GUI_atProjStateChange then _GUI_atProjStateChange() UPD.onprojstatechange = false end  
    UI_mouse()
    UI_draw() 
    if UPD.ext == true then Main_EXTSTATE_write() UPD.ext = false end
    for key in pairs(UPD) do UPD[key] = false end UPD.uilayer={}
    if char == 32 then Main_OnCommand(40044,0) end
    if char ~= -1 then reaper.defer(UI_run) end
  end 
  ------------------------------------------------------------------------------------------------
  function _Main()
    for key in pairs(reaper) do _G[key]=reaper[key] end -- simplify all function
    Main_EXTSTATE_read() -- read script data 
    
    -- parse ext
      local is_new_value,filename,sectionID,cmdID,mode,resolution,val,contextstr = reaper.get_action_context()
      local fp_conf = filename:gsub('%.lua','_conf.txt') 
      if not reaper.file_exists( fp_conf ) then 
        local f = io.open(fp_conf,'w')
        if f then 
          f:write('')
          f:close()
        end
       else
        local f = assert(loadfile(fp_conf)) f()
      end
      UI.script_path = filename:gsub('mpl_SubtReader_main.lua','') 
    
    UI_init()
    gfx.setfont(1,UI.font or 'Arial', UI.fontsz, 0 )
    DATA:Read()  
    UI_run()  
    atexit(gfx.quit) -- stop at quit
  end 
  --------------------------------------------------------------------------------------------------------------------- 
  _Main()