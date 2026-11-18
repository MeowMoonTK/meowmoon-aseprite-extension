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
  path = "C:/Aseprite/extensions/meowmoon-hue-shift",
  newCommand = function(_, spec)
    assert(spec.id == "MeowMoonGenerateHueShiftRamp")
    assert(type(spec.onclick) == "function")
  end
}
dofile("extensions/hue-shift/main.lua")
init(plugin)
assert(#calls == 1 and calls[1]:find("autoupdate.ps1", 1, true))
assert(calls[1]:find('-InstallDir "C:/Aseprite/extensions/meowmoon-hue-shift"',1,true))
app.os.windows = false
init(plugin)
assert(#calls == 1)
app.os.windows = true
app.isUIAvailable = false
init(plugin)
assert(#calls == 1)
os.execute = execute
print("OK: Hue Shift starts one background release check during Windows GUI startup")
