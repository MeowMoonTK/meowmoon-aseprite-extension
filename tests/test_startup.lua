-- Simulate Aseprite startup and verify auto-update runs only in Windows UI.
local execute = os.execute
local calls = {}
os.execute = function(command) calls[#calls + 1] = command; return true end
app = {
  isUIAvailable = true,
  os = { windows = true },
  fs = { joinPath = function(...) return table.concat({...}, "/") end }
}
local plugin = {
  path = "extensions/hue-shift",
  newCommand = function(_, spec)
    assert(spec.id == "MeowMoonGenerateHueShiftRamp")
    assert(type(spec.onclick) == "function")
  end
}
dofile("extensions/hue-shift/main.lua")
init(plugin)
assert(#calls == 1 and calls[1]:find("autoupdate.ps1", 1, true))
assert(calls[1]:find('-InstallDir "extensions/hue-shift"',1,true))
app.os.windows = false
init(plugin)
assert(#calls == 1)
app.os.windows = true
app.isUIAvailable = false
init(plugin)
assert(#calls == 1)
os.execute = execute

-- Exercise the real dialog constructor and inspect the version footer.
-- Aseprite exposes plugin.version from the installed package.json.
plugin.version = "0.1.4"
app.isUIAvailable = true
app.os.windows = false
app.fgColor = { red=100, green=120, blue=140 }
app.pixelColor = { rgba = function() return 0 end }
Color = function(c) return c end
ColorMode = { RGB = 0 }
Image = function(w,h)
  return { width=w,height=h,drawPixel=function() end }
end
local shownVersion = nil
Dialog = function()
  local dlg = { data = {} }
  function dlg:label(spec)
    if spec.label == "Version:" then shownVersion = spec.text end
    return self
  end
  return setmetatable(dlg, {
    __index = function()
      return function(self) return self end
    end
  })
end
local command
plugin.newCommand = function(_, spec) command = spec end
init(plugin)
assert(type(command.onclick) == "function")
command.onclick()
assert(shownVersion == "v0.1.4", "The extension version must be visible in the panel")

print("OK: Windows startup check and panel displays the installed plugin version")
