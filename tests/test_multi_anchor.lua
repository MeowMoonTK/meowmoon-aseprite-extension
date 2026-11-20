local color = dofile('extensions/hue-shift/src/color.lua')
local ramp = dofile('extensions/hue-shift/src/ramp.lua')(color)
local function generate(refs,n,extra)
  local opts=extra or {};opts.mode='Multi-Anchor';opts.anchors=refs;opts.count=n
  return ramp.generate(opts)
end
local function check(refs,n)
  local out,positions=generate(refs,n)
  assert(#out==n and #positions==#refs)
  assert(positions[1]==1 and positions[#refs]==n)
  local smallest,largest=math.huge,0
  for i=2,#positions do
    local gap=positions[i]-positions[i-1]
    assert(gap>=1);smallest=math.min(smallest,gap);largest=math.max(largest,gap)
  end
  assert(largest-smallest<=1,'Reference slots must be evenly distributed')
  local first,last=color.rgb_to_grayscale(out[1]),color.rgb_to_grayscale(out[n])
  assert(last-first>150,'Even identical/dark/white references need useful tonal range')
  local previous=-1
  for i,rgb in ipairs(out) do
    for _,v in pairs(rgb) do assert(v>=0 and v<=255 and v==math.floor(v)) end
    local gray=color.rgb_to_grayscale(rgb)
    assert(gray>previous,'Output must be strictly dark to light')
    assert(math.abs(gray-(first+(last-first)*(i-1)/(n-1)))<1.6,'Grayscale spacing must be uniform')
    previous=gray
  end
  return out
end
local samples={{r=0,g=0,b=0},{r=255,g=255,b=255},{r=128,g=128,b=128},
  {r=255,g=0,b=0},{r=0,g=255,b=0},{r=0,g=0,b=255},
  {r=73,g=51,b=86},{r=246,g=214,b=139}}
local cases=0
math.randomseed(7321)
for m=2,8 do
  for n=m,16 do
    for sample=1,20 do
      local refs={}
      for i=1,m do
        refs[i]=sample<=#samples and samples[sample]
          or {r=math.random(0,255),g=math.random(0,255),b=math.random(0,255)}
      end
      local result=check(refs,n)
      local reverse={};for i=m,1,-1 do reverse[#reverse+1]=refs[i] end
      local reversed=generate(reverse,n,{style='invalid',stepMode='invalid',strength=-100})
      for i=1,n do
        for _,c in ipairs({'r','g','b'}) do assert(result[i][c]==reversed[i][c]) end
      end
      cases=cases+1
    end
  end
end
local refs={{r=73,g=51,b=86},{r=203,g=101,b=92},{r=246,g=214,b=139}}
local output=generate(refs,9)
assert(refs[1].r==73 and refs[2].g==101 and refs[3].b==139,'Inputs must not mutate')
assert(output[1].r~=refs[1].r or output[1].g~=refs[1].g or output[1].b~=refs[1].b,
  'References must be soft, not copied verbatim')
local neutral=generate({{r=0,g=0,b=0},{r=255,g=255,b=255}},16)
for _,rgb in ipairs(neutral) do assert(rgb.r==rgb.g and rgb.g==rgb.b,'Neutral inputs must stay neutral') end
-- Crossing hue zero should take the short route, not a full color-wheel turn.
local a=color.oklch_to_rgb(.45,.12,350)
local b=color.oklch_to_rgb(.75,.12,10)
for _,rgb in ipairs(generate({a,b},9)) do
  local h=color.rgb_to_oklch(rgb).h
  assert(h>330 or h<30,'Hue wrap must take the short arc')
end
-- Many alternating hue references are soft constraints, not a mandatory zigzag.
local alternating={}
for i=1,8 do alternating[i]=color.oklch_to_rgb(.24+i*.07,.12,i%2==0 and 30 or 270) end
local function hue_travel(colors)
  local total=0
  for i=2,#colors do
    local a,b=color.rgb_to_oklch(colors[i-1]),color.rgb_to_oklch(colors[i])
    total=total+math.abs((b.h-a.h+540)%360-180)
  end
  return total
end
local sorted=ramp.order_anchors(alternating)
assert(hue_travel(generate(alternating,16)) < hue_travel(sorted)*.65,
  'Soft reference fitting must damp repeated hue reversals')
for _,case in ipairs({{{refs[1]},3}, {refs,2}, {refs,17}, {refs,3.5},
  {{{r=-1,g=0,b=0},refs[1]},4}}) do
  assert(not pcall(generate,case[1],case[2]),'Invalid input must be rejected')
end
local tooMany={};for i=1,9 do tooMany[i]=refs[1] end
assert(not pcall(generate,tooMany,16))
print('OK: '..cases..' multi-anchor cases; tonal order/spacing, gamut, soft references, neutral/wrap and bounds')
