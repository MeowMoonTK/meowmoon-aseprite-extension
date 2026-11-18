-- MeowMoon Hue Shift v0.1.4
-- Check private GitHub Releases on startup. No Task Scheduler.
function init(plugin)
  local root = plugin.path
  local mathColor = dofile(app.fs.joinPath(root, "src", "color.lua"))
  local ramp = dofile(app.fs.joinPath(root, "src", "ramp.lua"))(mathColor)
  local palette = dofile(app.fs.joinPath(root, "src", "palette.lua"))
  local wheel = dofile(app.fs.joinPath(root, "src", "wheel.lua"))
  local dialog = dofile(app.fs.joinPath(root, "src", "dialog.lua"))
  plugin:newCommand{
    id = "MeowMoonGenerateHueShiftRamp",
    title = "Hue Shift: Generate Ramp",
    group = "file_scripts",
    onclick = function()
      dialog.open(ramp, palette, wheel)
    end
  }

  if app.isUIAvailable and app.os and app.os.windows then
    local checker = app.fs.joinPath(root, "src", "autoupdate.ps1")
    -- Launch a detached check so opening Aseprite is not delayed by network calls.
    -- Aseprite might request permission for os.execute() on first use.
    local command = 'cmd.exe /d /c start "" /min powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File "' .. checker .. '" -InstallDir "' .. root .. '"'
    local ok, err = pcall(os.execute, command)
    if not ok then
      print("Hue Shift: startup update check could not be started: " .. tostring(err))
    end
  end
end
