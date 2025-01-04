for key in pairs(reaper) do _G[key]=reaper[key]  end 
  
  function main()
    local first_tr = GetTrack(0,0)
    PreventUIRefresh( 1 )
    for i = 1, CountSelectedMediaItems(0) do
      local item = GetSelectedMediaItem(0,i-1)
      local itpos = GetMediaItemInfo_Value( item, 'D_POSITION' )
      local itlen = GetMediaItemInfo_Value( item, 'D_LENGTH' )
      local ittr = GetMediaItemTrack( item )
      if ittr == first_tr then goto skip end 
      local retval, outstr = GetSetMediaItemInfo_String( item, 'P_NOTES', '', false )
      if retval == false or outstr == '' then goto skip end
      local VP_item = AddMediaItemToTrack( first_tr )
      SetMediaItemInfo_Value( VP_item, 'D_POSITION', itpos ) 
      SetMediaItemInfo_Value( VP_item, 'D_LENGTH', itlen ) 
      local tk = AddTakeToMediaItem( VP_item )
      local fxid = TakeFX_AddByName( tk, 'Video processor', -1 )
      reaper.TakeFX_Show( tk, fxid, 2 )
      TakeFX_SetNamedConfigParm( tk, fxid, 'VIDEO_CODE', 
[[
// Text overlay
#text="]]..outstr..[["; // set to string to override
font="Arial";

//@param1:size 'text height' 0.05 0.01 0.2 0.1 0.001
//@param2:ypos 'y position' 0.95 0 1 0.5 0.01
//@param3:xpos 'x position' 0 0 1 0.5 0.01
//@param4:border 'border' 0 0 1 0.5 0.01
//@param5:fgc 'text bright' 1.0 0 1 0.5 0.01
//@param6:fga 'text alpha' 1.0 0 1 0.5 0.01
//@param7:bgc 'bg bright' 0 0 1 0.5 0.01
//@param8:bga 'bg alpha' 0.5 0 1 0.5 0.01
//@param10:ignoreinput 'ignore input' 0 0 1 0.5 1

input = ignoreinput ? -2:0;
project_wh_valid===0 ? input_info(input,project_w,project_h);
gfx_a2=0;
gfx_blit(input,1);
gfx_setfont(size*project_h,font);
strcmp(#text,"")==0 ? input_get_name(-1,#text);
gfx_str_measure(#text,txtw,txth);
yt = (project_h- txth*(1+border*2))*ypos;
gfx_set(bgc,bgc,bgc,bga);
gfx_fillrect(0, yt, project_w, txth*(1+border*2));
gfx_set(fgc,fgc,fgc,fga);
gfx_str_draw(#text,xpos * (project_w-txtw),yt+txth*border);
]]) 
      TakeFX_SetParam( tk, fxid, 0, 0.07 )--//@param1:size 'text height' 0.05 0.01 0.2 0.1 0.001
      TakeFX_SetParam( tk, fxid, 1, 1)--//@param2:ypos 'y position' 0.95 0 1 0.5 0.01
      TakeFX_SetParam( tk, fxid, 2, 0.5)--//@param3:xpos 'x position' 0 0 1 0.5 0.01
      TakeFX_SetParam( tk, fxid, 3, 0.1 )--//@param4:border 'border' 0 0 1 0.5 0.01
      TakeFX_SetParam( tk, fxid, 4, 1 )--//@param5:fgc 'text bright' 1.0 0 1 0.5 0.01
      TakeFX_SetParam( tk, fxid, 5, 1 )--//@param6:fga 'text alpha' 1.0 0 1 0.5 0.01
      TakeFX_SetParam( tk, fxid, 6, 0 )--//@param7:bgc 'bg bright' 0 0 1 0.5 0.01
      TakeFX_SetParam( tk, fxid, 7, 0.8 )--//@param8:bga 'bg alpha' 0.5 0 1 0.5 0.01
      TakeFX_SetParam( tk, fxid, 8, 0 )--//@param10:ignoreinput 'ignore input' 0 0 1 0.5 1
      ::skip::
    end
    PreventUIRefresh( -1 )
  end
  
  main()
