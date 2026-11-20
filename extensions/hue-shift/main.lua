-- Hue Shift version is read from plugin.version.
local activeUpdater
local activeUpdatesDialog

function init(plugin)
  local root=plugin.path
  local mathColor=dofile(app.fs.joinPath(root,"src","color.lua"))
  local ramp=dofile(app.fs.joinPath(root,"src","ramp.lua"))(mathColor)
  local palette=dofile(app.fs.joinPath(root,"src","palette.lua"))
  local wheel=dofile(app.fs.joinPath(root,"src","wheel.lua"))
  local dialog=dofile(app.fs.joinPath(root,"src","dialog.lua"))
  local updatesDialog=dofile(app.fs.joinPath(root,"src","update-dialog.lua"))
  activeUpdatesDialog=updatesDialog
  local updater=dofile(app.fs.joinPath(root,"src","update.lua"))(root,plugin.version)
  activeUpdater=updater

  plugin:newCommand{
    id="MeowMoonGenerateHueShiftRamp",
    title="Hue Shift: Generate Ramp",
    group="file_scripts",
    onclick=function()
      dialog.open(ramp,palette,wheel,plugin.version,updater,updatesDialog)
    end
  }
  plugin:newCommand{
    id="MeowMoonCheckHueShiftUpdates",
    title="Hue Shift: Updates",
    group="file_scripts",
    onclick=function()
      if not (app.os and app.os.windows) then
        app.alert("Hue Shift updater currently supports Windows only.")
        return
      end
      updatesDialog.open(updater,plugin.version)
    end
  }
end

function exit(plugin)
  if activeUpdatesDialog then activeUpdatesDialog.close();activeUpdatesDialog=nil end
  if activeUpdater then
    activeUpdater.stop()
    activeUpdater=nil
  end
end
