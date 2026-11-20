-- One background fetcher; only Aseprite installs the verified extension.
return function(root, installedVersion)
  local U = {busy=false, state="idle", launchStatus="Click Check Updates to check for a new version."}
  local timer, resultPath, callback, began
  local installing, stopped, polling, cleaning = false, false, false, false

  local function status(kind, message)
    U.state, U.launchStatus = kind, message
    if callback then pcall(callback, kind, message) end
    if U.onStatus then pcall(U.onStatus,kind,message) end
  end

  local function stopTimer()
    local current=timer
    timer=nil
    if current then pcall(function() current:stop() end) end
  end

  local function cleanup()
    if not resultPath or cleaning then return end
    cleaning=true
    local failed = false
    -- Delete the request first: the fetcher cannot publish after cancellation.
    -- Never delete a path received from JSON.
    for _, suffix in ipairs({"", ".writing", ".aseprite-extension"}) do
      local path = resultPath .. suffix
      local ok, removed = pcall(os.remove, path)
      if not ok or not removed then
        local checked, exists = pcall(app.fs.isFile, path)
        if not checked or exists then failed=true end
      end
    end
    if failed then
      U.launchStatus = U.launchStatus .. " Could not remove all temporary files."
      if callback then pcall(callback,U.state,U.launchStatus) end
    end
    cleaning=false
  end

  local function finish(kind, message)
    stopTimer()
    status(kind,message)
    cleanup()
    callback=nil
    U.busy=false
    if U.onStatus then pcall(U.onStatus,U.state,U.launchStatus) end
  end

  local function readResult()
    local opened, file, reason, errno = pcall(io.open,resultPath,"r")
    if not opened or (not file and errno ~= 2) then
      finish("error","Cannot read update result: " .. tostring(opened and reason or file))
      return
    end
    if file then
      local read, contents = pcall(function() return file:read("*a") end)
      pcall(function() file:close() end)
      local parsed, result = false, nil
      if read and contents then parsed,result=pcall(json.decode,contents) end
      -- Aseprite returns a JSON object userdata; standalone tests may use tables.
      if not parsed or (type(result) ~= "table" and type(result) ~= "userdata") then
        finish("error","Invalid update result.")
        return
      end
      if result.status == "up_to_date" then
        finish("up_to_date",tostring(result.message or "Already up to date."))
        return
      elseif result.status == "error" then
        finish("error","Update check failed: " .. tostring(result.message))
        return
      elseif result.status == "update" then
        stopTimer() -- Keep the busy lock and input throughout the modal command.
        local path=resultPath .. ".aseprite-extension"
        local checked, exists=pcall(app.fs.isFile,path)
        if result.packagePath ~= path or not checked or not exists
           or type(result.version) ~= "string" or not result.version:match("^%d+%.%d+%.%d+$") then
          finish("error","Verified update package is missing or invalid.")
          return
        end
        if not (app.command and app.command.Options) then
          finish("error","Aseprite's extension installer is unavailable.")
          return
        end
        installing=true
        status("verified","Verified v" .. result.version .. "; opening Aseprite installer...")
        local ok,value=pcall(app.command.Options,{installExtension=path})
        installing=false
        -- Options returns after its dialogs close, including cancellation.
        -- Native installation may unload the plugin during this call.
        if not ok or value == false then
          finish("error","Aseprite installer failed: " .. tostring(value))
        else
          finish("installer_closed","Installer closed. If you accepted the update, restart Aseprite.")
        end
        return
      elseif result.status ~= "checking" then
        finish("error","Unexpected update status: " .. tostring(result.status))
        return
      end
    end
    -- Three full-body HTTP requests have 30-second timeouts in the fetcher.
    if os.time()-began >= 120 then finish("error","Update check timed out. You can try again.") end
  end

  local function poll()
    -- Security prompts run a nested UI loop. Pause before any gated file I/O
    -- so another Timer tick cannot re-enter this Lua callback while it waits.
    if polling or stopped or not U.busy then return end
    polling=true
    local current=timer
    if current then current:stop() end
    local ok,err=pcall(readResult)
    if not ok then finish("error","Cannot process update result: " .. tostring(err)) end
    if timer==current and current and U.busy and not stopped then current:start() end
    polling=false
  end

  local function check(onFinish)
    if stopped then return false,"Updater has stopped." end
    if U.busy then return false,"An update check or installer is already running." end
    if not (app.isUIAvailable and app.os and app.os.windows) then
      return false,"The built-in updater supports Windows GUI mode."
    end
    if not Timer then return false,"Aseprite Timer API is unavailable." end
    local version=tostring(installedVersion)
    if not version:match("^%d+%.%d+%.%d+$") then return false,"Invalid extension version." end
    callback=onFinish
    U.busy=true
    resultPath=app.fs.joinPath(app.fs.tempPath,"meowmoon-update-" .. tostring(os.time())
      .. "-" .. tostring(math.random(100000,999999)) .. ".json")
    local opened,file,reason=pcall(io.open,resultPath,"w")
    if not opened or not file then
      finish("error","Cannot create update request: " .. tostring(opened and reason or file))
      return false,U.launchStatus
    end
    local written,writeResult=pcall(function() return file:write('{"status":"checking"}') end)
    local closed,closeResult=pcall(function() return file:close() end)
    if not written or not writeResult or not closed or not closeResult then
      finish("error","Cannot write update request.")
      return false,U.launchStatus
    end
    began=os.time()
    local ready,err=pcall(function()
      timer=Timer{interval=0.5,ontick=poll}
    end)
    if not ready then
      finish("error","Cannot start update timer: " .. tostring(err))
      return false,U.launchStatus
    end
    status("checking","Checking GitHub Releases...")
    local script=app.fs.joinPath(root,"src","check-release.ps1")
    local command='cmd.exe /d /c start "" /min powershell.exe -WindowStyle Hidden'
      .. ' -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "' .. script
      .. '" -CurrentVersion "' .. version .. '" -ResultFile "' .. resultPath .. '"'
    local called,code=pcall(os.execute,command)
    if not called or code == nil or code == false or (type(code)=="number" and code~=0) then
      finish("error","Cannot start update check: " .. tostring(code))
      return false,U.launchStatus
    end
    if stopped then cleanup();U.busy=false;return false,"Updater has stopped." end
    began=os.time()
    local started,startError=pcall(function() timer:start() end)
    if not started then
      finish("error","Cannot start update timer: " .. tostring(startError))
      return false,U.launchStatus
    end
    return true,U.launchStatus
  end
  U.checkNow=check
  function U.stop()
    stopped=true
    stopTimer()
    callback=nil
    if not installing then cleanup() end
  end
  return U
end
