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
Rectangle=function(...) return {...} end
local gc=setmetatable({width=360,height=201},{__index=function() return function() end end})
Dialog=function()
  panel={widgets={},data={},shown=false}
  function panel:modify(spec)
    local widget = assert(self.widgets[spec.id], spec.id)
    for k,v in pairs(spec) do widget[k]=v end
    if spec.color then self.data[spec.id]=spec.color end
    if spec.value then self.data[spec.id]=spec.value end
    if spec.colors then self.data[spec.id]=spec.colors end
  end
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
local plugin={path='extensions/hue-shift',version='0.1.9',newCommand=function(_,spec) commands[#commands+1]=spec end}
dofile('extensions/hue-shift/main.lua')
init(plugin)
assert(#commands==1 and commands[1].id=='MeowMoonGenerateHueShiftRamp')
assert(panel==nil,'Startup must not open any window')
commands[1].onclick()
assert(panel.shown and panel.widgets.apply and panel.widgets.preview and panel.widgets.hue_wheel)
assert(not panel.widgets.update and not panel.widgets.updates and not panel.widgets.check)
assert(panel.widgets.count.min==3 and panel.widgets.count.max==16)
assert(#panel.widgets.style.options==6 and #panel.widgets.step_mode.options==5)
panel.widgets.preview.onpaint{context=gc}
panel.widgets.hue_wheel.onpaint{context=gc}
panel.data.count=8
panel.widgets.count.onchange()
panel.widgets.apply.onclick()
assert(palette.size==10 and transactions==1 and refreshes==1)
assert(panel.widgets.status.text=='Added 8 colors to the palette.')
for index=2,9 do
  local c=assert(palette.colors[index])
  assert(c.red>=0 and c.red<=255 and c.green>=0 and c.green<=255 and c.blue>=0 and c.blue<=255)
end
-- Multi-Anchor hides every single-color shaping control and clamps Target.
panel.data.mode='Multi-Anchor'
panel.widgets.mode.onchange()
for _,id in ipairs({'center','style','step_mode','strength','strength_help'}) do
  assert(panel.widgets[id].visible==false, id..' must be hidden')
end
assert(panel.widgets.anchor_help.visible and #panel.widgets.references.colors==3)
assert(panel.widgets.references.mode=='sort','Use native Aseprite drag/drop shades')
local original=panel.widgets.references.colors
panel.data.references={original[3],original[1],original[2]}
panel.widgets.references.onclick{color=original[3]}
local reordered=panel.widgets.references.colors
assert(reordered[1].red==original[3].red and reordered[2].red==original[1].red
  and reordered[3].red==original[2].red,'Drag must update reference order')
assert(panel.widgets.reference_color.label=='Anchor #1:','Select the dragged reference')
panel.data.reference_color=Color{r=1,g=2,b=3}
panel.widgets.reference_color.onchange()
assert(panel.widgets.references.colors[1].red==1 and panel.widgets.references.colors[2].red==original[1].red,
  'Edit after drag must update its new slot')
local beforeOutside=panel.widgets.references.colors
panel.data.references={beforeOutside[1],beforeOutside[2]} -- native outside drop deletes a color
panel.widgets.references.onclick{}
assert(#panel.widgets.references.colors==3 and panel.widgets.references.colors[3].red==beforeOutside[3].red,
  'Outside drop must restore reference count and order')
panel.widgets.preview.onpaint{context=gc}
panel.widgets.hue_wheel.onpaint{context=gc}
panel.data.show_map=true;panel.widgets.show_map.onclick()
assert(panel.widgets.hue_wheel.visible)
panel.data.show_map=false;panel.widgets.show_map.onclick()
assert(not panel.widgets.hue_wheel.visible)
for _=1,7 do panel.widgets.add_anchor.onclick() end
assert(#panel.widgets.references.colors==8 and not panel.widgets.add_anchor.enabled)
assert(panel.widgets.count.min==8 and panel.data.count==8)
assert(panel.widgets.reference_color.label=='Anchor #8:','New anchor must select its own appended slot')
local first=panel.widgets.references.colors[1]
panel.data.reference_color=first
panel.widgets.reference_color.onchange()
assert(panel.widgets.reference_color.label=='Anchor #8:','Matching another RGB must not change selection')
panel.data.reference_color=Color{r=0,g=0,b=0}
panel.widgets.reference_color.onchange()
assert(panel.widgets.reference_color.label=='Anchor #8:','Dark edit must stay in slot 8')
assert(panel.widgets.references.colors[1].red==first.red)
assert(panel.widgets.references.colors[8].red==0 and panel.widgets.references.colors[8].blue==0)
panel.widgets.apply.onclick()
assert(palette.size==18 and transactions==2 and refreshes==2)
for _=1,6 do panel.widgets.remove_anchor.onclick() end
assert(panel.widgets.count.min==2 and not panel.widgets.remove_anchor.enabled)
local two=panel.widgets.references.colors
panel.data.references={two[2],two[1]}
panel.widgets.references.onclick{color=two[1]}
assert(panel.widgets.references.colors[2].red==two[1].red)
assert(panel.widgets.reference_color.label=='Anchor #2:')
panel.data.references={two[2]}
panel.widgets.references.onclick{}
assert(#panel.widgets.references.colors==2,'Outside drop must not bypass two-anchor minimum')
panel.widgets.remove_anchor.onclick() -- guard even when the UI button is disabled
panel.data.count=2;panel.widgets.count.onchange()
panel.widgets.references.onclick{color=panel.widgets.references.colors[1]}
assert(panel.widgets.reference_color.label=='Anchor #1:')
local second=panel.widgets.references.colors[2]
for _,c in ipairs({Color{r=255,g=255,b=255},Color{r=0,g=0,b=0},Color{r=0,g=0,b=139}}) do
  panel.data.reference_color=c
  panel.widgets.reference_color.onchange()
  local colors=panel.widgets.references.colors
  assert(colors[1].red==c.red and colors[1].green==c.green and colors[1].blue==c.blue)
  assert(colors[2].red==second.red and colors[2].green==second.green and colors[2].blue==second.blue)
  assert(panel.widgets.reference_color.label=='Anchor #1:','Editing must preserve selected slot')
end
panel.widgets.apply.onclick()
assert(palette.size==20 and transactions==3)
panel.data.mode='Single Color';panel.widgets.mode.onchange()
assert(panel.widgets.center.visible and panel.widgets.step_mode.visible)
assert(not panel.widgets.references.visible and panel.data.count==3)
panel.widgets.apply.onclick()
assert(palette.size==23 and transactions==4)
panel=nil
app.isUIAvailable=false
commands[1].onclick()
assert(panel==nil,'Headless mode must not open a panel')
os.execute,io.popen,io.open,os.remove=originalExecute,originalPopen,originalOpen,originalRemove
print('OK: startup, both modes, native drag reorder/outside restore, stable edits, Target and palette append; no tools/timers/files')
