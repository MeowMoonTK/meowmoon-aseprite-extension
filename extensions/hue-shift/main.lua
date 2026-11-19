-- Hue Shift version is read from plugin.version.
local startupTimer

function init(plugin)
  local root=plugin.path
  local mathColor=dofile(app.fs.joinPath(root,"src","color.lua"))
  local ramp=dofile(app.fs.joinPath(root,"src","ramp.lua"))(mathColor)
  local palette=dofile(app.fs.joinPath(root,"src","palette.lua"))
  local wheel=dofile(app.fs.joinPath(root,"src","wheel.lua"))
  local dialog=dofile(app.fs.joinPath(root,"src","dialog.lua"))
  local updater=dofile(app.fs.joinPath(root,"src","update.lua"))(root)

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
      local ok,message=updater.checkNow()
      app.alert{
        title=ok and "Hue Shift Update Check" or "Hue Shift Update Error",
        text=message.."\nLog: "..updater.logPath
      }
    end
  }

  if app.isUIAvailable and app.os and app.os.windows then
    -- Defer the security-gated shell call until Aseprite's UI loop starts.
    if Timer then
      startupTimer=Timer{
        interval=1.0,
        ontick=function()
          startupTimer:stop()
          updater.background()
          startupTimer=nil
        end
      }
      startupTimer:start()
    else
      updater.background()
    end
  end
end

function exit(plugin)
  if startupTimer then
    startupTimer:stop()
    startupTimer=nil
  end
end
