-- @description BuildFXTree
-- @version 1.0
-- @author MPL
-- @website https://forum.cockos.com/showthread.php?t=188335
-- @changelog
--	init

 --------------------------------------------------------------------------
  function mpl_BuildFXTree_iscontainer(tr, i)local ret, container_count = reaper.TrackFX_GetNamedConfigParm( tr, i, 'container_count') if ret==true  then return tonumber(container_count)  end  end
  --------------------------------------------------------------------------
  function mpl_BuildFXTree_adddata(tr, tree, i, add)
    local fxid  = i
    local GUID = reaper.TrackFX_GetFXGUID( tr, fxid|0x2000000 )
    if not GUID then return end
    local retval, buf = reaper.TrackFX_GetFXName( tr, fxid|0x2000000 ) 
    local isopen = reaper.TrackFX_GetOpen( tr, fxid|0x2000000 )  
    local container_count = mpl_BuildFXTree_iscontainer(tr, fxid|0x2000000)
    if not add then 
      tree[i] = {
        fxname = buf,
        isopen=isopen,
        GUID=GUID,
        fxid = i
      }
     else
      tree[i].GUID=GUID
      tree[i].fxname = buf
      tree[i].fxid = i
    end
  end
  ------------------------------------------------------------------------------
  function mpl_BuildFXTree_recursive(tr, tree, i)
    local container_count = mpl_BuildFXTree_iscontainer(tr, i|0x2000000)
    if not tonumber(container_count) then return end
    container_count = tonumber(container_count)
    tree[i]= {iscont = true}
    mpl_BuildFXTree_adddata(tr, tree, i, true)
    
    tree[i].shift = (tree.fxcnt + 1)
    
    if not tree[i].fxcnt then 
      local child_fxid = tree.fxcnt * (1 + container_count) + container_count 
      for id in pairs(tree) do if tonumber(id) then tree[i].fxcnt = child_fxid end end
    end
    
    for child = 1, container_count do
      local child_fxid = child * (tree.fxcnt + 1) + i
      tree[i][child_fxid] = {}
      mpl_BuildFXTree_adddata(tr, tree[i], child_fxid)
      mpl_BuildFXTree_recursive(tr, tree[i], child_fxid)
    end
  end
  --------------------------------------------------------------------------
  function mpl_BuildFXTree(tr)
    -- table with referencing ID tree
    local tree = {}
    local cnt =  reaper.TrackFX_GetCount( tr) 
    tree.fxcnt= cnt
    for i = 1, cnt do
      mpl_BuildFXTree_adddata (tr, tree, i)
      tree[i].fxcnt = cnt
      mpl_BuildFXTree_recursive(tr, tree, i)
    end 
    local tree_exploded = mpl_ExplodeFXTree(tree) 
    return tree, tree_exploded
  end
  --------------------------------------------------------------------------
  function mpl_ExplodeFXTree_recursive(exploded_tree, tree) 
    for fxid in pairs(tree) do
      if tonumber(fxid) then
        local idx = #exploded_tree + 1
        exploded_tree[idx] = tree[fxid]
        exploded_tree[idx].level = tree.level + 1
        exploded_tree[idx].parentcontainerID = fxid
        exploded_tree[idx].fxcnt = nil -- clean
        if tree[fxid].iscont == true then
          mpl_ExplodeFXTree_recursive(exploded_tree, tree[fxid])
        end
      end
    end
  end
  --------------------------------------------------------------------------
  function mpl_ExplodeFXTree(tree)
    local exploded_tree = {}
    for fxid in pairs(tree) do
      if tonumber(fxid) then
        local idx = #exploded_tree + 1
        exploded_tree[idx] = tree[fxid]
        exploded_tree[idx].fxcnt = nil -- clean
        exploded_tree[idx].level = 1
        if exploded_tree[fxid].iscont == true then
          mpl_ExplodeFXTree_recursive(exploded_tree, tree[fxid])
          exploded_tree[idx].level = level
        end
      end
    end
    return exploded_tree
  end
  --------------------------------------------------------------------------  
  function mpl_EnumerateFXCointainers(tr) 
    local tree_src, tree_exploded = mpl_BuildFXTree(tr) 
    local GUID = {}
    for i = 1, #tree_exploded do
      if tree_exploded[i].iscont == true then 
        GUID[#GUID+1] = {GUID=tree_exploded[i].GUID,
                         fxID = tree_exploded[i].fxid,
                         fxname = tree_exploded[i].fxname,
                         }
      end
    end
    t = tree_src
    return GUID
  end
  --------------------------------------------------------------------------  
  function mpl_GetContainer(tr,GUID) 
    local tree_src, tree_exploded = mpl_BuildFXTree(tr) 
    for i = 1, #tree_exploded do
      if tree_exploded[i].iscont == true and tree_exploded[i].GUID==GUID then return true, tree_exploded[i].fxid, tree_exploded[i].shift end
    end
  end
  --------------------------------------------------------------------------   
  function mpl_MoveFxToContainer(tr, container_guid,src_fx)
    local ret, container, container_shift = mpl_GetContainer(tr, container_guid)
    if ret then 
      src_fx = (src_fx + 1 ) | 0x2000000
      dest_fx = (container + container_shift) | 0x2000000
      reaper.TrackFX_CopyToTrack( tr, src_fx, tr, dest_fx, true )
    end
  end




  --------------------------------------------------------------------------    
  function main()
    local tr = reaper.GetSelectedTrack(0,0)
    if not tr then return end 
    
    -- test 0
    --tree_src, tree_exploded = mpl_BuildFXTree(tr) 
    
    -- test 1 
    --GUID_t = mpl_EnumerateFXCointainers(tr)
    --ret, container, container_shift = mpl_GetContainer(tr,GUID_t[1].GUID)
    
    -- test2 
    --GUID_t = mpl_EnumerateFXCointainers(tr)
    --mpl_MoveFxToContainer(tr, GUID_t[1].GUID, 0) -- add first fx to first container 
  end
  --------------------------------------------------------------------------
  main()