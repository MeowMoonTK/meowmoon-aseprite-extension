-- PowerShell fetches/verifies; only Aseprite installs extensions.
return function(root, installedVersion)
  local U = { launchStatus = "Not checked this session", state = "idle", busy = false,
    logPath = (os.getenv("LOCALAPPDATA") or "%LOCALAPPDATA%") .. "\\MeowMoon\\HueShift\\update.log" }
  local checker = app.fs.joinPath(root, "src", "check-release.ps1")
  local pollTimer, resultPath, began, onFinish
  local manual, installing, stopped = false, false, false
  local TIMEOUT_SECONDS = 140 -- PowerShell bounds its worker at 120 seconds.

  local function notify(kind, message)
    U.state, U.launchStatus = kind, message
    if onFinish then pcall(onFinish, kind, message) end
    if kind == "error" then
      if manual then
        app.alert{title="Hue Shift Update Error", text=message .. "\nDetails: " .. U.logPath}
      else
        -- Retain in the panel, and leave a diagnostic without a startup popup.
        print("Hue Shift: " .. message)
      end
    elseif kind == "up_to_date" and manual then
      app.alert{title="Hue Shift Updates", text=message}
    end
  end

  local function stopTimer()
    if pollTimer then pcall(function() pollTimer:stop() end); pollTimer = nil end
  end

  local function remove(path)
    local ok, removed, message = pcall(os.remove, path)
    -- A missing file needs no cleanup. Do not ignore permission errors.
    if ok and removed then return true end
    local checked, exists = pcall(app.fs.isFile, path)
    if checked and not exists then return true end
    return false, tostring(ok and message or removed)
  end

  local function cleanup()
    if not resultPath then return end
    local failures = {}
    -- Exact per-request files only; never use a path supplied by JSON.
    for _, suffix in ipairs({".pending", "", ".writing", ".aseprite-extension", ".sha256"}) do
      local ok, message = remove(resultPath .. suffix)
      if not ok then failures[#failures+1] = message end
    end
    if #failures > 0 then
      U.launchStatus = U.launchStatus .. " Temporary-file cleanup failed: " .. table.concat(failures, "; ")
      if onFinish then pcall(onFinish, U.state, U.launchStatus) end
      print("Hue Shift: " .. U.launchStatus)
    end
  end

  local function finish(kind, message, uncertain)
    stopTimer()
    -- If no terminal worker response was read, keep the lock this session.
    -- A stopped timer alone cannot prove that a detached process has exited.
    notify(kind, message)
    cleanup()
    onFinish = nil
    U.busy = not not uncertain
  end

  local function processResult(result)
    stopTimer() -- Keep busy through native dialogs and cleanup.
    if type(result) ~= "table" then
      finish("error", "Invalid updater response.", true)
    elseif result.status == "up_to_date" then
      finish("up_to_date", tostring(result.message or "Already up to date."))
    elseif result.status == "error" then
      finish("error", "Update check failed: " .. tostring(result.message))
    elseif result.status == "update" then
      local path = result.packagePath
      local exists, isFile = pcall(app.fs.isFile, resultPath .. ".aseprite-extension")
      if path ~= resultPath .. ".aseprite-extension" or not exists or not isFile
         or type(result.version) ~= "string" or not result.version:match("^%d+%.%d+%.%d+$") then
        finish("error", "Downloaded package is missing or has an invalid path/version.")
        return
      end
      if not (app.command and app.command.Options) then
        finish("error", "Aseprite's native extension installer is unavailable.")
        return
      end
      notify("verified", "Verified Hue Shift v" .. result.version .. "; opening Aseprite installer...")
      installing = true
      local ok, value = pcall(app.command.Options, {installExtension=path})
      installing = false
      -- Options is synchronous (including its confirmation dialog). Keep the
      -- package until it returns, including when plugin exit runs reentrantly.
      if not ok or value == false then
        finish("error", "Aseprite installer did not complete: " .. tostring(value))
      else
        finish("installer_closed", "Aseprite installer closed. Installation is unconfirmed; if accepted, restart Aseprite.")
      end
    else
      finish("error", "Unexpected updater status: " .. tostring(result.status), true)
    end
  end

  local function poll()
    local opened, file, reason, code = pcall(io.open, resultPath, "r")
    if not opened or (not file and code ~= 2) then
      finish("error", "Cannot read update result (access may be denied): " .. tostring(opened and reason or file)
        .. ". Restart Aseprite before retrying.", true)
      return
    end
    if file then
      local ok, contents = pcall(function() return file:read("*a") end)
      pcall(function() file:close() end)
      if not ok or not contents then
        finish("error", "Cannot read update result: " .. tostring(contents), true)
        return
      end
      local parsed, result = pcall(json.decode, contents)
      if not parsed then
        finish("error", "Updater returned invalid JSON: " .. tostring(result), true)
        return
      end
      processResult(result)
    elseif os.time() - began >= TIMEOUT_SECONDS then
      finish("error", "Update check timed out. Restart Aseprite before retrying; inspect " .. U.logPath, true)
    end
  end

  function U.check(isManual, callback)
    if stopped then return false, "Updater stopped; restart Aseprite before retrying." end
    if U.busy then return false, "Update check or installer is active, or its completion is unknown. Restart Aseprite if it timed out." end
    if not (app.isUIAvailable and app.os and app.os.windows) then
      return false, "The built-in updater currently supports Windows GUI mode."
    end
    if type(Timer) ~= "function" then return false, "Aseprite Timer API is unavailable." end
    local v = tostring(installedVersion)
    if not v:match("^%d+%.%d+%.%d+$") then return false, "Invalid extension version: " .. v end
    manual, onFinish = not not isManual, callback
    local nonce = tostring(os.time()) .. "-" .. tostring(math.random(100000,999999))
    resultPath = app.fs.joinPath(app.fs.tempPath, "meowmoon-update-" .. nonce .. ".json")
    U.busy = true
    -- Establish writable result ownership before starting any detached process.
    local opened, file, reason = pcall(io.open, resultPath .. ".pending", "w")
    if not opened or not file then
      finish("error", "Cannot create update request: " .. tostring(opened and reason or file))
      return false, U.launchStatus
    end
    local closed, closeResult = pcall(function() return file:close() end)
    if not closed or not closeResult then
      finish("error", "Cannot close update request.")
      return false, U.launchStatus
    end
    began = os.time()
    notify("checking", "Checking GitHub Releases...")
    -- Create/start the timer first so a Timer failure cannot strand a worker.
    local timerOK, timerError = pcall(function()
      pollTimer = Timer{interval=0.5, ontick=poll}
      pollTimer:start()
    end)
    if not timerOK then
      finish("error", "Cannot start update timer: " .. tostring(timerError))
      return false, U.launchStatus
    end
    local args = '-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass'
      .. ' -File "' .. checker .. '" -CurrentVersion "' .. v .. '" -ResultFile "' .. resultPath .. '"'
    local called, code, reason, exitCode = pcall(os.execute,
      'cmd.exe /d /c start "" /min powershell.exe -WindowStyle Hidden ' .. args)
    if not called or code == false or code == nil or (type(code) == "number" and code ~= 0) then
      local message = not called and tostring(code)
        or ("Shell launch failed: " .. tostring(reason) .. " " .. tostring(exitCode))
      finish("error", message)
      return false, message
    end
    return true, U.launchStatus
  end
  function U.background() return U.check(false) end
  function U.checkNow(callback) return U.check(true, callback) end
  function U.stop()
    stopped = true
    stopTimer()
    onFinish = nil
    -- Native install can unload this plugin while still reading its package.
    if not installing then cleanup() end
  end
  return U
end
