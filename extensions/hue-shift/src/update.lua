-- Native Aseprite extension updater.
-- Inspired by John Riggles' MIT-licensed Aseprite Extension Updater.
-- PowerShell ONLY fetches/verifies a Release; Aseprite installs it.
return function(root, installedVersion)
  local U = {
    launchStatus = "Not checked this session",
    busy = false,
    logPath = (os.getenv("LOCALAPPDATA") or "%LOCALAPPDATA%")
      .. "\\MeowMoon\\HueShift\\update.log"
  }

  local checker = app.fs.joinPath(root, "src", "check-release.ps1")
  local pollTimer = nil
  local resultPath = nil
  local began = 0
  local manual = false
  local onFinish = nil
  local TIMEOUT_SECONDS = 140

  local function notify(kind, message)
    U.launchStatus = message
    if onFinish then
      pcall(onFinish, kind, message)
    end
    if kind == "error" and manual then
      app.alert{ title = "Hue Shift Update Error",
                 text = message .. "\nDetails: " .. U.logPath }
    elseif kind == "up_to_date" and manual then
      app.alert{ title = "Hue Shift Updates", text = message }
    end
  end

  local function stopTimer()
    if pollTimer then pollTimer:stop(); pollTimer = nil end
    U.busy = false
  end

  local function processResult(result)
    stopTimer()
    if type(result) ~= "table" then
      notify("error", "Invalid updater response.")
      return
    end
    if result.status == "up_to_date" then
      notify("up_to_date", result.message or "Already up to date.")
    elseif result.status == "error" then
      notify("error", "Update check failed: " .. tostring(result.message))
    elseif result.status == "update" then
      local path = result.packagePath
      if type(path) ~= "string"
         or not path:match("%.aseprite%-extension$")
         or not app.fs.isFile(path) then
        notify("error", "Downloaded package is missing or has an invalid path.")
        return
      end
      if not (app.command and app.command.Options) then
        notify("error", "Aseprite's native extension installer is unavailable.")
        return
      end
      -- The native installer owns upgrade confirmation, replacement and
      -- preferences preservation. Never alter the installed directory here.
      U.launchStatus = "Aseprite installer opened for Hue Shift v" ..
        tostring(result.version) .. "; confirm and restart."
      if onFinish then pcall(onFinish, "update", U.launchStatus) end
      local ok, installed = pcall(app.command.Options, { installExtension = path })
      if not ok or installed == false then
        notify("error", "Could not open Aseprite's installer: " .. tostring(installed))
      end
    else
      notify("error", "Unexpected updater status: " .. tostring(result.status))
    end
  end

  local function poll()
    -- The downloader writes JSON atomically only once it has finished.
    local opened, file = pcall(io.open, resultPath, "r")
    if not opened then
      stopTimer()
      notify("error", "Aseprite denied read access to the update result: " .. tostring(file))
      return
    end
    if file then
      local ok, contents = pcall(function()
        local value = file:read("*a")
        file:close()
        return value
      end)
      if not ok then
        stopTimer()
        notify("error", "Cannot read update result: " .. tostring(contents))
        return
      end
      local parsed, result = pcall(json.decode, contents)
      if not parsed then
        stopTimer()
        notify("error", "Updater returned invalid JSON: " .. tostring(result))
        return
      end
      processResult(result)
      return
    end
    if os.time() - began >= TIMEOUT_SECONDS then
      stopTimer()
      notify("error", "Update check timed out; inspect " .. U.logPath)
    end
  end

  function U.check(isManual, callback)
    if U.busy then return false, "An update check is already running." end
    if not (app.isUIAvailable and app.os and app.os.windows) then
      return false, "The built-in updater currently supports Windows GUI mode."
    end
    if type(Timer) ~= "function" then
      return false, "Aseprite Timer API is unavailable."
    end
    local v = tostring(installedVersion)
    if not v:match("^%d+%.%d+%.%d+$") then
      return false, "Invalid extension version: " .. v
    end

    manual = not not isManual
    onFinish = callback
    local nonce = tostring(os.time()) .. "-" .. tostring(math.random(100000,999999))
    resultPath = app.fs.joinPath(app.fs.tempPath, "meowmoon-update-" .. nonce .. ".json")
    began = os.time()
    U.busy = true
    U.launchStatus = "Checking GitHub Releases..."
    local args = '-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass'
      .. ' -File "' .. checker .. '"'
      .. ' -CurrentVersion "' .. v .. '"'
      .. ' -ResultFile "' .. resultPath .. '"'
    local command = 'cmd.exe /d /c start "" /min powershell.exe -WindowStyle Hidden ' .. args
    local called, code, reason, exitCode = pcall(os.execute, command)
    if not called or code == false or code == nil
       or (type(code) == "number" and code ~= 0) then
      U.busy = false
      local errorText = not called and tostring(code)
        or ("Shell launch failed: " .. tostring(reason) .. " " .. tostring(exitCode))
      notify("error", errorText)
      return false, errorText
    end
    pollTimer = Timer{ interval = 0.5, ontick = poll }
    pollTimer:start()
    return true, U.launchStatus
  end

  function U.background()
    return U.check(false)
  end

  function U.checkNow(callback)
    return U.check(true, callback)
  end

  function U.stop()
    stopTimer()
    onFinish = nil
  end

  return U
end
