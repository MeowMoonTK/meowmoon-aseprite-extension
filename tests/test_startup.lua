-- The extension only launches the public Release check in Windows UI mode.
local execute = os.execute
local calls = {}
os.execute = function(command)
  calls[#calls + 1] = command
  return true, "exit", 0
end

app = {
  isUIAvailable = true,
  os = { windows = true },
  fs = { joinPath = function(...) return table.concat({...}, "/") end }
}
local plugin = {
  path = "extensions/hue-shift",
  version = "0.1.5",
  newCommand = function(_, spec)
    assert(spec.id == "MeowMoonGenerateHueShiftRamp")
    assert(type(spec.onclick) == "function")
  end
}

dofile("extensions/hue-shift/main.lua")
init(plugin)
assert(#calls == 1 and calls[1]:find("autoupdate.ps1", 1, true))
assert(calls[1]:find('-InstallDir "extensions/hue-shift"', 1, true))
assert(not calls[1]:find("gh auth", 1, true))
app.os.windows = false
init(plugin)
assert(#calls == 1, "No Windows PowerShell on other platforms.")
app.os.windows = true
app.isUIAvailable = false
init(plugin)
assert(#calls == 1, "No updater in headless mode.")
os.execute = execute

-- Inspect the visible panel footer with Aseprite-compatible dialog mocks.
app.isUIAvailable = true
app.os.windows = false
app.fgColor = { red=100, green=120, blue=140 }
Color = function(c) return c end
ColorMode = { RGB = 0 }
Image = function(w, h) return { width=w, height=h, drawPixel=function() end } end

local shownVersion
Dialog = function()
  local dlg = { data = {} }
  function dlg:label(spec)
    if spec.label == "Version:" then shownVersion = spec.text end
    return self
  end
  return setmetatable(dlg, { __index = function() return function(self) return self end end })
end

local command
plugin.newCommand = function(_, spec) command = spec end
init(plugin)
assert(type(command.onclick) == "function")
command.onclick()
assert(shownVersion == "v0.1.5", "The panel must display the package version.")

print("OK: release check launched on Windows UI startup, panel version from manifest")
