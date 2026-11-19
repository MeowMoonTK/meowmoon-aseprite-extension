-- Simulate the Aseprite GUI, including deferred startup Timer.
local oldExecute=os.execute
local oldOpen=io.open
local calls={}
os.execute=function(command)
  calls[#calls+1]=command
  return true,"exit",0
end
local tick
Timer=function(spec)
  assert(spec.interval==1.0)
  local timer={}
  function timer:start() tick=spec.ontick end
  function timer:stop() end
  return timer
end
app={
  isUIAvailable=true,
  os={windows=true},
  fs={joinPath=function(...)return table.concat({...},"/")end},
  alert=function()end
}
local commands={}
local plugin={
  path="extensions/hue-shift",version="0.1.7",
  newCommand=function(_,spec)commands[spec.id]=spec end
}
dofile("extensions/hue-shift/main.lua")
init(plugin)
assert(#calls==0,"Startup check should wait for Aseprite UI")
assert(type(tick)=="function")
tick()
assert(#calls==1)
assert(calls[1]:find('cmd.exe /d /c start',1,true))
assert(calls[1]:find('autoupdate.ps1" -InstallDir "extensions/hue-shift"',1,true))
assert(commands.MeowMoonCheckHueShiftUpdates)
app.os.windows=false
init(plugin)
assert(#calls==1,"Do not run Windows updater on other platforms")
app.os.windows=true
app.isUIAvailable=false
init(plugin)
assert(#calls==1,"Do not run updater in headless mode")
os.execute=oldExecute

-- Manual check must report a nonzero PowerShell exit code.
io.open=function()return nil end
local updater=dofile("extensions/hue-shift/src/update.lua")("extensions/hue-shift")
local manualCommand
os.execute=function(cmd)
  manualCommand=cmd
  return nil,"exit",5
end
local ok,message=updater.checkNow()
assert(not ok and message:find("failed",1,true))
assert(manualCommand:find("powershell.exe",1,true))
assert(not manualCommand:find("cmd.exe /d /c start",1,true))
os.execute=oldExecute
io.open=oldOpen

-- The extension still shows its installed version and a manual update control.
app.isUIAvailable=true
app.os.windows=true
app.fgColor={red=100,green=120,blue=140}
app.pixelColor={rgba=function()return 0 end}
Color=function(c)return c end
ColorMode={RGB=0}
Image=function(w,h)return{width=w,height=h,drawPixel=function()end}end
local versionShown,checkButton,updateText
Dialog=function()
  local dlg={data={}}
  function dlg:label(spec)
    if spec.label=="Version:" then versionShown=spec.text end
    if spec.id=="update_status" then updateText=spec.text end
    return self
  end
  function dlg:button(spec)
    if spec.id=="update" then checkButton=spec.onclick end
    return self
  end
  return setmetatable(dlg,{__index=function()
    return function(self)return self end
  end})
end
local oldStart=os.execute
local count=0
os.execute=function(cmd)count=count+1;return true,"exit",0 end
init(plugin)
commands.MeowMoonGenerateHueShiftRamp.onclick()
assert(versionShown=="v0.1.7")
assert(type(checkButton)=="function" and type(updateText)=="string")
assert(count==0,"Timer should not trigger until tick")
tick()
assert(count==1)
os.execute=oldStart
print("OK: delayed startup, manual exit-code diagnostics and version panel")
