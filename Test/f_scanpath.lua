  function ScanPath(path, scan_fullpath)
    local t = {}
    local subdirindex, fileindex = 0,0    
    local path_child
    repeat
        path_child = reaper.EnumerateSubdirectories(path, subdirindex )
        if scan_fullpath and path_child and path..'/'..path_child == scan_fullpath:gsub('\\','/') then 
            t[path_child] = {}
            local tmp = ScanPath(path .. "/" .. path_child)
            t[path_child] = tmp
         elseif path_child then 
          t[path_child] = {}
        end
        subdirindex = subdirindex+1
    until not path_child

    repeat
        fn = reaper.EnumerateFiles( path, fileindex )
        if fn then 
          if not t[path] then t[path] = {} end
          t[path][  #t[path]+1  ] = fn
            --t[#t+1] = fn
        end
        fileindex = fileindex+1
    until not fn
    
    return t
end
