-- Core-only startup/panel test: external tools, network and timers are forbidden.
local originalExecute,originalPopen,originalOpen,originalRemove=os.execute,io.popen,io.open,os.remove
local function forbidden() error('Core extension must not run tools or touch update files') end
os.execute,io.popen,io.open,os.remove=forbidden,forbidden,forbidden,forbidden
Timer=forbidden
local commands,panel,transactions,refreshes={},nil,0,0
local palette=setmetatable({size=2,colors={}},{__len=function(self) return self.size end})
function palette:resize(size) self.size=size end
function palette:setColor(index,color) self.colors[index]=color end
app={isUIAvailable=true,os={windows=true},
  fs={joinPath=function(...) return table.concat({...},'/') end},
  fgColor={red=100,green=120,blue=140},pixelColor={rgba=function() return 0 end},
  sprite={isValid=true,palettes={palette}},
  transaction=function(_,action) transactions=transactions+1;action() end,
  refresh=function() refreshes=refreshes+1 end,
  alert=function() error('No alert expected') end}
Color=function(c) return {red=c.r or c.red,green=c.g or c.green,blue=c.b or c.blue,alpha=c.a or 255} end
ColorMode={RGB=0}
Image=function(w,h) return {width=w,height=h,drawPixel=function() end} end
Dialog=function()
  panel={widgets={},data={},shown=false}
  function panel:modify(spec) self.widgets[spec.id].text=spec.text end
  function panel:show(spec) self.shown=true;assert(spec.wait==false) end
  return setmetatable(panel,{__index=function(_,kind)
    return function(self,spec)
      if spec and spec.id then
        self.widgets[spec.id]=spec
        self.data[spec.id]=spec.color or spec.value or spec.option or spec.text
      end
      return self
    end
  end})
end
local plugin={path='extensions/hue-shift',version='0.1.8',newCommand=function(_,spec) commands[#commands+1]=spec end}
dofile('extensions/hue-shift/main.lua')
init(plugin)
assert(#commands==1 and commands[1].id=='MeowMoonGenerateHueShiftRamp')
assert(panel==nil,'Startup must not open any window')
commands[1].onclick()
assert(panel.shown and panel.widgets.apply and panel.widgets.preview and panel.widgets.hue_wheel)
assert(not panel.widgets.update and not panel.widgets.updates and not panel.widgets.check)
assert(panel.widgets.count.min==3 and panel.widgets.count.max==16)
assert(#panel.widgets.style.options==6 and #panel.widgets.step_mode.options==5)
panel.data.count=8
panel.widgets.count.onchange()
panel.widgets.apply.onclick()
assert(palette.size==10 and transactions==1 and refreshes==1)
assert(panel.widgets.status.text=='Added 8 colors to the palette.')
for index=2,9 do
  local c=assert(palette.colors[index])
  assert(c.red>=0 and c.red<=255 and c.green>=0 and c.green<=255 and c.blue>=0 and c.blue<=255)
end
panel=nil
app.isUIAvailable=false
commands[1].onclick()
assert(panel==nil,'Headless mode must not open a panel')
os.execute,io.popen,io.open,os.remove=originalExecute,originalPopen,originalOpen,originalRemove
print('OK: core-only startup, one command, color controls and palette append; no tools/timers/update files')
