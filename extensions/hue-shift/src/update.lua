-- Built-in Windows release check with synchronous manual diagnostics.
return function(root)
  local U={
    logPath=(os.getenv("LOCALAPPDATA") or "%LOCALAPPDATA%")
      .."\\MeowMoon\\HueShift\\update.log",
    launchStatus="Not checked this session"
  }
  local checker=app.fs.joinPath(root,"src","autoupdate.ps1")
  local args='-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass'
    ..' -File "'..checker..'" -InstallDir "'..root..'"'

  local function execute(command)
    local called,result,reason,code=pcall(os.execute,command)
    if not called then return false,tostring(result) end
    if result==false or result==nil
      or (type(result)=="number" and result~=0) then
      return false,"PowerShell launch failed: "..tostring(reason).." "..tostring(code)
    end
    return true,"Command ran"
  end

  function U.readLog()
    local ok,f=pcall(io.open,U.logPath,"r")
    if not ok or not f then return nil end
    local contents=f:read("*a") or ""
    f:close()
    return contents:match("([^\r\n]+)%s*$")
  end

  function U.background()
    local command='cmd.exe /d /c start "" /min powershell.exe -WindowStyle Hidden '..args
    local ok,reason=execute(command)
    U.launchStatus=ok and "Background check launched"
      or ("Startup check failed: "..reason)
    if not ok then print("Hue Shift: "..U.launchStatus) end
    return ok,U.launchStatus
  end

  function U.checkNow()
    -- No cmd start: capture the updater's actual exit code.
    U.launchStatus="Checking releases..."
    local ok,reason=execute('powershell.exe -WindowStyle Hidden '..args)
    local message=U.readLog()
    if not ok then
      U.launchStatus="Update failed: "..(message or reason)
    elseif message and message:find("ERROR:",1,true) then
      ok=false
      U.launchStatus="Update failed: "..message
    else
      U.launchStatus=message or "Check completed. See update log."
    end
    return ok,U.launchStatus
  end
  return U
end
