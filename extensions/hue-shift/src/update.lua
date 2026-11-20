-- Sequential curl + native installer, following JRiggles' MIT updater approach.
-- No Timer, detached process, PowerShell helper or JSON status files.
return function(_, installedVersion)
  local U={busy=false,state="idle",launchStatus="Click Check Updates to check for a new version."}
  local stopped=false
  local function status(kind,message)
    U.state,U.launchStatus=kind,message
    if U.onStatus then pcall(U.onStatus,kind,message) end
  end
  local function quote(value)
    assert(not value:find('["%%!\r\n]'),"Unsupported character in update path.")
    return '"'..value..'"'
  end
  local function run(command)
    assert(not stopped,"Update check cancelled.")
    local pipe,err=io.popen(command..' 2>&1',"r")
    assert(pipe,"Cannot run update tool: "..tostring(err))
    local read,output=pcall(function() return pipe:read("*a") end)
    local closed,ok=pcall(function() return pipe:close() end)
    assert(read and output,"Cannot read update tool output.")
    if not (closed and (ok==true or ok==0)) then
      if output:find('403',1,true) then error('GitHub rejected the request (HTTP 403). Try again later.',0) end
      error("Update tool failed: "..output,0)
    end
    assert(not stopped,"Update check cancelled.")
    return output
  end
  local function curl(url,seconds,limit,path)
    local command='curl.exe -q --fail --location --silent --show-error'
      ..' --proto "=https" --proto-redir "=https" --connect-timeout 5 --max-time '..seconds
      ..' --max-filesize '..limit..' --user-agent MeowMoon-HueShift'
    if path then command=command..' --output '..quote(path) end
    return run(command..' '..quote(url))
  end
  function U.checkNow()
    if stopped then return false,"Updater has stopped." end
    if U.busy then return false,"An update check or installer is already running." end
    if not (app.isUIAvailable and app.os and app.os.windows) then
      return false,"The built-in updater supports Windows GUI mode."
    end
    U.busy=true
    local packagePath
    local ok,err=pcall(function()
      status("checking","Checking GitHub Releases...")
      local releases=json.decode(curl('https://api.github.com/repos/MeowMoonTK/meowmoon-aseprite-extension/releases?per_page=100',15,1048576))
      local latest
      for _,release in ipairs(releases) do
        local version=release.tag_name and release.tag_name:match('^hue%-shift%-v(%d+%.%d+%.%d+)$')
        if version and not release.draft and not release.prerelease then
          local parsed=Version(version)
          if not latest or parsed>latest.parsed then
            latest={version=version,parsed=parsed,tag=release.tag_name}
          end
        end
      end
      assert(latest,"No stable Hue Shift Release found.")
      if Version(tostring(installedVersion))>=latest.parsed then
        status("up_to_date","Installed v"..tostring(installedVersion).." is current.")
        return
      end
      local name='hue-shift-'..latest.version..'.aseprite-extension'
      local base='https://github.com/MeowMoonTK/meowmoon-aseprite-extension/releases/download/'..latest.tag..'/'
      local checksum=curl(base..'hue-shift-'..latest.version..'.sha256',15,1024)
      local expected,filename=checksum:match('^(%x+)%s+%*?(%S+)%s*$')
      assert(expected and #expected==64 and filename==name,"Invalid release checksum file.")
      packagePath=app.fs.joinPath(app.fs.tempPath,'meowmoon-hue-shift-'..os.time()..'-'
        ..math.random(100000,999999)..'.aseprite-extension')
      status("downloading","Downloading Hue Shift v"..latest.version.."...")
      curl(base..name,60,52428800,packagePath)
      local hashOutput=run('certutil.exe -hashfile '..quote(packagePath)..' SHA256')
      local actual
      for word in hashOutput:gmatch('%x+') do if #word==64 then actual=word:lower();break end end
      assert(actual==expected:lower(),"Package SHA-256 does not match the release checksum.")
      -- Aseprite validates/opens the archive and owns manifest/upgrade handling.
      status("verified","Verified v"..latest.version..". Confirm installation in Aseprite.")
      local result=app.command.Options{installExtension=packagePath}
      assert(result~=false,"Aseprite installer did not complete.")
      status("installer_closed","Installer closed. If you accepted the update, restart Aseprite.")
    end)
    if not ok then status("error",tostring(err):gsub('^.-:%d+: ','')) end
    -- Exactly one temporary file, retained through the synchronous installer.
    if packagePath then
      local removed,result=pcall(os.remove,packagePath)
      if not removed or not result then
        local checked,exists=pcall(app.fs.isFile,packagePath)
        if not checked or exists then
          U.launchStatus=U.launchStatus.." Could not delete the downloaded package."
        end
      end
    end
    U.busy=false
    if U.onStatus then pcall(U.onStatus,U.state,U.launchStatus) end
    return ok,U.launchStatus
  end
  function U.stop() stopped=true end -- checkNow owns cleanup, even during plugin unload.
  return U
end
