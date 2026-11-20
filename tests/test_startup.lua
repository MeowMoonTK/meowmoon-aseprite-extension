-- Exercise actual panel modules with a mocked Aseprite UI and shell.
local originalOpen,originalExecute,originalRemove=io.open,os.execute,os.remove
local commands,dialogs,timers,files,shells={},{},{},{},{}
local response,resultPath,inInstaller
local installations,alerts=0,0
os.execute=function(command)
  shells[#shells+1]=command
  resultPath=command:match('-ResultFile "(.-)"')
  return true,'exit',0
end
io.open=function(path,mode)
  if mode=='w' then
    files[path]='checking'
    return {write=function() return true end,close=function() return true end}
  end
  if not files[path] then return nil,'No such file',2 end
  return {read=function() return response or files[path] end,close=function() return true end}
end
os.remove=function(path)
  assert(not inInstaller,'Retain package until native Options returns')
  files[path]=nil
  return true
end
json={decode=function(data)
  if data=='checking' then return {status='checking'} end
  if data=='current' then return {status='up_to_date',message='Already current'} end
  if data=='error' then return {status='error',message='HTTP 403'} end
  if data=='update' then return {status='update',version='0.1.9',packagePath=resultPath..'.aseprite-extension'} end
  error('invalid JSON')
end}
Timer=function(spec)
  local timer={callback=spec.ontick,active=false}
  function timer:start() self.active=true end
  function timer:stop() self.active=false end
  timers[#timers+1]=timer
  return timer
end
Dialog=function(spec)
  local dlg={data={},widgets={},spec=spec,visible=false}
  function dlg:show() self.visible=true end
  function dlg:close() self.visible=false;if self.spec.onclose then self.spec.onclose() end end
  function dlg:modify(change)
    local widget=assert(self.widgets[change.id],change.id)
    for k,v in pairs(change) do widget[k]=v end
  end
  setmetatable(dlg,{__index=function(_,kind)
    return function(self,widget)
      if widget and widget.id then
        widget.kind=kind
        self.widgets[widget.id]=widget
        self.data[widget.id]=widget.selected or widget.value or widget.option or widget.color or widget.text
      end
      return self
    end
  end})
  dialogs[#dialogs+1]=dlg
  return dlg
end
app={isUIAvailable=true,os={windows=true},
  fs={tempPath='C:/Temp Folder',joinPath=function(...) return table.concat({...},'/') end,
    isFile=function(path) return files[path]~=nil end},
  fgColor={red=100,green=120,blue=140},pixelColor={rgba=function() return 0 end},
  alert=function() alerts=alerts+1 end,command={}}
Color=function(c) return c end
ColorMode={RGB=0}
Image=function(w,h) return {width=w,height=h,drawPixel=function() end} end
local plugin={path='extensions/hue-shift',version='0.1.8',
  newCommand=function(_,spec) commands[spec.id]=spec end}
dofile('extensions/hue-shift/main.lua')
init(plugin)
assert(#shells==0 and #timers==0 and #dialogs==0,'No startup updates or windows')
commands.MeowMoonGenerateHueShiftRamp.onclick()
local ramp=dialogs[1]
assert(ramp.widgets.updates and not ramp.widgets.check,'Main panel has an Updates launcher only')
assert(ramp.widgets.apply and ramp.widgets.hue_wheel.visible==false)
ramp.data.show_map=true
ramp.widgets.show_map.onclick()
assert(ramp.widgets.hue_wheel.visible==true,'Color Map remains available')
ramp.widgets.updates.onclick()
local updates=dialogs[2]
assert(updates.spec.title=='Hue Shift Updates' and updates.widgets.check)
assert(not updates.widgets.apply,'Update actions are separate from palette actions')
assert(#shells==0 and #timers==0,'Opening Updates does not check automatically')
commands.MeowMoonCheckHueShiftUpdates.onclick()
assert(#dialogs==2,'Reuse existing update window')
updates.widgets.check.onclick()
assert(#shells==1 and updates.widgets.check.enabled==false)
assert(shells[1]:find(' -CurrentVersion "0.1.8"',1,true))
assert(shells[1]:find(' -ResultFile "C:/Temp Folder/',1,true))
timers[1].callback()
assert(timers[1].active,'Initial checking JSON is not terminal')
updates:close()
commands.MeowMoonCheckHueShiftUpdates.onclick()
updates=dialogs[3]
assert(updates.widgets.check.enabled==false)
response='current'
timers[1].callback()
assert(updates.widgets.check.enabled==true)
assert(updates.widgets.update_line_1.text=='Already current','Reopened window receives completion')
assert(next(files)==nil and alerts==0,'Cleanup without extra alerts')
response=nil
updates.widgets.check.onclick()
response='error'
timers[2].callback()
assert(updates.widgets.check.enabled==true and updates.widgets.update_line_1.text:find('403'))
assert(alerts==0,'Errors belong to update window')
app.command.Options=function(args)
  inInstaller=true
  assert(files[args.installExtension])
  installations=installations+1
  inInstaller=false
  return true
end
response=nil
updates.widgets.check.onclick()
files[resultPath..'.aseprite-extension']=true
response='update'
timers[3].callback()
assert(installations==1 and updates.widgets.check.enabled==true and next(files)==nil)
assert(updates.widgets.update_line_1.text:find('Installer closed'))
exit(plugin)
assert(not updates.visible,'Plugin exit closes update window')
io.open,os.execute,os.remove=originalOpen,originalExecute,originalRemove
print('OK: quiet startup, separate Updates window, reopen during fetch, status recovery and native handoff')
