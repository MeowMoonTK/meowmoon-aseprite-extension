-- Hue Shift version is read from plugin.version.
local activeUpdater

function init(plugin)
  local root=plugin.path
  local mathColor=dofile(app.fs.joinPath(root,"src","color.lua"))
  local ramp=dofile(app.fs.joinPath(root,"src","ramp.lua"))(mathColor)
  local palette=dofile(app.fs.joinPath(root,"src","palette.lua"))
  local wheel=dofile(app.fs.joinPath(root,"src","wheel.lua"))
  local dialog=dofile(app.fs.joinPath(root,"src","dialog.lua"))
  local updater=dofile(app.fs.joinPath(root,"src","update.lua"))(root,plugin.version)
  activeUpdater=updater

  plugin:newCommand{
    id="MeowMoonGenerateHueShiftRamp",
    title="Hue Shift: Generate Ramp",
    group="file_scripts",
    onclick=function()
      dialog.open(ramp,palette,wheel,plugin.version,updater)
    end
  }
  plugin:newCommand{
    id="MeowMoonCheckHueShiftUpdates",
    title="Hue Shift: Check Updates",
    group="file_scripts",
    onclick=function()
      if not (app.os and app.os.windows) then
        app.alert("Hue Shift updater currently supports Windows only.")
        return
      end
      local ok, message=updater.checkNow()
      if not ok then app.alert{title="Hue Shift Updates",text=message} end
    end
  }
end

function exit(plugin)
  if activeUpdater then
    activeUpdater.stop()
    activeUpdater=nil
  end
end
