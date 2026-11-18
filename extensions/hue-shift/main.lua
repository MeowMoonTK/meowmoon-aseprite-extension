-- MeowMoon Hue Shift (version is read from plugin.version).
-- A single public Release check starts when Aseprite opens on Windows.
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
      dialog.open(ramp, palette, wheel, plugin.version)
    end
  }

  if app.isUIAvailable and app.os and app.os.windows then
    local checker = app.fs.joinPath(root, "src", "autoupdate.ps1")
    -- Detached: network requests never block the Hue Shift UI.
    -- Aseprite may ask to allow os.execute() the first time.
    local command = 'cmd.exe /d /c start "" /min powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File "' .. checker .. '" -InstallDir "' .. root .. '"'
    local ok, success, reason, exitCode = pcall(os.execute, command)
    if not ok then
      print("Hue Shift: cannot start update check: " .. tostring(success))
    elseif success == false or (type(success) == "number" and success ~= 0) then
      print("Hue Shift: could not launch the update check (" .. tostring(reason) .. ", " .. tostring(exitCode) .. ")")
    end
  end
end
