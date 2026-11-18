-- MeowMoon Hue Shift v0.1.0
-- Aseprite loads this file as an extension script.
function init(plugin)
  local root = plugin.path
  local mathColor = dofile(app.fs.joinPath(root, "src", "color.lua"))
  local ramp = dofile(app.fs.joinPath(root, "src", "ramp.lua"))(mathColor)
  local palette = dofile(app.fs.joinPath(root, "src", "palette.lua"))
  local dialog = dofile(app.fs.joinPath(root, "src", "dialog.lua"))

  plugin:newCommand{
    id = "MeowMoonGenerateHueShiftRamp",
    title = "Hue Shift: Generate Ramp",
    group = "file_scripts",
    onclick = function()
      dialog.open(ramp, palette)
    end
  }
end
