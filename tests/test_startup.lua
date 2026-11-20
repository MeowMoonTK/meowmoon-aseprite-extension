-- Simulate Aseprite's Windows UI and its native extension installer.
local originalExecute = os.execute
local originalOpen = io.open
local originalTime = os.time
local originalRemove = os.remove
local resultPath, inInstaller
local removed = {}
os.remove = function(path)
  assert(not inInstaller, "Do not delete files while the native installer is using them")
  removed[path] = true
  return true
end
local commands, timers, shells = {}, {}, {}
local mockResponse = nil
local failRead = false
local alerts, installations = {}, {}

os.time = function() return 1740000000 end
os.execute = function(command)
  shells[#shells+1] = command
  resultPath = command:match('-ResultFile "(.-)"')
  return true, "exit", 0
end
io.open = function(path, mode)
  if failRead then error("Aseprite denied read permission") end
  if mode == "w" then return {close=function() return true end} end
  if not mockResponse then return nil, "No such file", 2 end
  local file = {}
  function file:read() return mockResponse end
  function file:close() end
  return file
end
Timer = function(spec)
  local timer = {interval=spec.interval, callback=spec.ontick, active=false}
  function timer:start() self.active=true end
  function timer:stop() self.active=false end
  timers[#timers+1]=timer
  return timer
end
json = {
  decode = function(data)
    if data == "update" then
      return {status="update",version="0.1.8",
        packagePath=resultPath .. ".aseprite-extension"}
    elseif data == "up_to_date" then
      return {status="up_to_date",message="Already current"}
    elseif data == "error" then
      return {status="error",message="GitHub returned 403"}
    end
    error("invalid JSON")
  end
}
app = {
  isUIAvailable=true,
  os={windows=true},
  fs={
    tempPath="C:/Temp Folder",
    joinPath=function(...) return table.concat({...},"/") end,
    isFile=function(p)
      return p == resultPath .. ".aseprite-extension"
    end
  },
  command={
    Options=function(args)
      inInstaller = true
      assert(not removed[args.installExtension])
      -- A manual check from a nested dialog cannot launch another worker.
      local count = #shells
      commands.MeowMoonCheckHueShiftUpdates.onclick()
      assert(#shells == count)
      inInstaller = false
      installations[#installations+1] = args.installExtension
      return true
    end
  },
  alert=function(args) alerts[#alerts+1]=args end
}
local plugin = {
  path="extensions/hue-shift",
  version="0.1.7",
  newCommand=function(_, spec)
    commands[spec.id]=spec
  end
}
dofile("extensions/hue-shift/main.lua")
init(plugin)
assert(commands.MeowMoonGenerateHueShiftRamp)
assert(commands.MeowMoonCheckHueShiftUpdates)
assert(#shells==0,"Startup network check must wait for the UI timer.")
assert(#timers==1 and timers[1].interval==1.0)
timers[1].callback()
assert(#shells==1 and #timers==2)
assert(shells[1]:find("cmd.exe /d /c start",1,true))
assert(shells[1]:find('check-release.ps1" -CurrentVersion "0.1.7"',1,true))
assert(shells[1]:find(' -ResultFile "C:/Temp Folder/',1,true))
assert(not shells[1]:find("autoupdate.ps1",1,true))
assert(#installations==0,"Never install before download verification.")
assert(timers[2].interval==0.5)
timers[2].callback()  -- No status result yet.
assert(#installations==0 and timers[2].active)
mockResponse="update"
timers[2].callback()
assert(not timers[2].active)
assert(#installations==1 and installations[1]:find("%.aseprite%-extension$"))
assert(removed[resultPath] and removed[resultPath .. ".aseprite-extension"])
assert(#alerts==1,"Only the nested busy check displays an informational alert.")
alerts = {}

-- Manual check should still run asynchronously and show up-to-date state.
mockResponse=nil
commands.MeowMoonCheckHueShiftUpdates.onclick()
assert(#shells==2 and #timers==3 and timers[3].active)
mockResponse="up_to_date"
timers[3].callback()
assert(#installations==1)
assert(#alerts==1 and alerts[1].text=="Already current")

-- A failed GitHub response must never call the native installer.
mockResponse=nil
commands.MeowMoonCheckHueShiftUpdates.onclick()
mockResponse="error"
timers[4].callback()
assert(#installations==1)
assert(#alerts==2 and alerts[2].text:find("403",1,true))

-- Permission denial in io.open is a visible error; no install occurs.
mockResponse=nil
commands.MeowMoonCheckHueShiftUpdates.onclick()
failRead=true
timers[5].callback()
failRead=false
assert(#installations==1 and #alerts==3)
assert(alerts[3].text:find("denied",1,true))

-- The original RGB palette dialog is still available and shows version.
app.fgColor={red=100,green=120,blue=140}
app.pixelColor={rgba=function() return 0 end}
Color=function(c) return c end
ColorMode={RGB=0}
Image=function(w,h) return {width=w,height=h,drawPixel=function() end} end
local shownVersion, button, updateText
Dialog=function()
  local dlg={data={}}
  function dlg:label(spec)
    if spec.label=="Version:" then shownVersion=spec.text end
    if spec.id=="update_status" then updateText=spec.text end
    return self
  end
  function dlg:button(spec)
    if spec.id=="update" then button=spec.onclick end
    return self
  end
  return setmetatable(dlg,{
    __index=function() return function(self) return self end end
  })
end
commands.MeowMoonGenerateHueShiftRamp.onclick()
assert(shownVersion=="v0.1.7")
assert(type(button)=="function" and type(updateText)=="string")

-- The extension never runs a Windows updater in headless or non-Windows mode.
local beforeShells=#shells
app.os.windows=false
init(plugin)
assert(#shells==beforeShells)
app.os.windows=true
app.isUIAvailable=false
init(plugin)
assert(#shells==beforeShells)
exit(plugin)
os.execute=originalExecute
io.open=originalOpen
os.time=originalTime
os.remove=originalRemove
print("OK: native updater startup, verified-install handoff, errors and UI")
