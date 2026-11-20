-- Exercise real panels with a synchronous network boundary.
local originalPopen,originalExecute=io.popen,os.execute
local commands,dialogs,requests={},{},{}
local updates,alerts=nil,0
io.popen=function(command)
  requests[#requests+1]=command
  assert(updates.widgets.check.enabled==false,'Disable Check Updates during a network call')
  return {read=function() return 'releases' end,close=function() return true,'exit',0 end}
end
os.execute=function() error('No detached helper') end
Timer=function() error('No update Timer') end
json={decode=function() return {{tag_name='hue-shift-v0.1.7'}} end}
if not Version then
  Version=function(s)
    local a,b,c=s:match('(%d+)%.(%d+)%.(%d+)')
    return setmetatable({n=tonumber(a)*1000000+tonumber(b)*1000+tonumber(c)},
      {__lt=function(x,y) return x.n<y.n end,__le=function(x,y) return x.n<=y.n end})
  end
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
  fs={tempPath='C:/Temp Folder',joinPath=function(...) return table.concat({...},'/') end},
  fgColor={red=100,green=120,blue=140},pixelColor={rgba=function() return 0 end},
  alert=function() alerts=alerts+1 end,command={Options=function() error('No install expected') end}}
Color=function(c) return c end
ColorMode={RGB=0}
Image=function(w,h) return {width=w,height=h,drawPixel=function() end} end
local plugin={path='extensions/hue-shift',version='0.1.8',
  newCommand=function(_,spec) commands[spec.id]=spec end}
dofile('extensions/hue-shift/main.lua')
init(plugin)
assert(#requests==0 and #dialogs==0,'No startup requests or windows')
commands.MeowMoonGenerateHueShiftRamp.onclick()
local ramp=dialogs[1]
assert(ramp.widgets.updates and not ramp.widgets.check)
assert(ramp.widgets.apply and ramp.widgets.hue_wheel.visible==false)
ramp.data.show_map=true
ramp.widgets.show_map.onclick()
assert(ramp.widgets.hue_wheel.visible==true)
ramp.widgets.updates.onclick()
updates=dialogs[2]
assert(updates.spec.title=='Hue Shift Updates' and updates.widgets.check and not updates.widgets.apply)
assert(#requests==0,'Opening Updates does not check automatically')
commands.MeowMoonCheckHueShiftUpdates.onclick()
assert(#dialogs==2,'Reuse existing update window')
updates.widgets.check.onclick()
assert(#requests==1 and updates.widgets.check.enabled==true)
assert(updates.widgets.update_line_1.text=='Installed v0.1.8 is current.')
assert(alerts==0,'Results stay in update window')
updates:close()
commands.MeowMoonCheckHueShiftUpdates.onclick()
updates=dialogs[3]
assert(updates.widgets.update_line_1.text=='Installed v0.1.8 is current.')
exit(plugin)
assert(not updates.visible)
io.popen,os.execute=originalPopen,originalExecute
print('OK: quiet startup, separate Updates panel, synchronous button lifecycle and retained status')
