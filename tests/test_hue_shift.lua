local color = dofile("extensions/hue-shift/src/color.lua")
local ramp = dofile("extensions/hue-shift/src/ramp.lua")(color)
local paletteWriter = dofile("extensions/hue-shift/src/palette.lua")

local function near(a,b,eps)
  return math.abs(a-b) <= eps
end

local samples = {
  {r=0,g=0,b=0}, {r=255,g=255,b=255},
  {r=255,g=0,b=0}, {r=0,g=255,b=0}, {r=0,g=0,b=255},
  {r=86,g=138,b=96}, {r=90,g=90,b=90}
}
for _, rgb in ipairs(samples) do
  local lab = color.rgb_to_oklch(rgb)
  local output = color.oklch_to_rgb(lab.L,lab.C,lab.h)
  assert(near(output.r,rgb.r,2) and near(output.g,rgb.g,2) and near(output.b,rgb.b,2),
    "OKLCH round trip failed")
end

local countCases = 0
for _, style in ipairs(ramp.styles) do
  for _, mode in ipairs(ramp.stepModes) do
    for n=3,16 do
      for _, strength in ipairs({0,35,100}) do
        for _, base in ipairs(samples) do
          local out, anchor = ramp.generate{
            center=base, count=n, strength=strength, style=style,
            stepMode=mode
          }
        assert(#out == n)
        local expectedAnchor = math.floor((n+1)/2)
        if n % 2 == 0 and color.rgb_to_grayscale(base) >= 128 then
          expectedAnchor = expectedAnchor + 1
        end
        assert(anchor == expectedAnchor, "Anchor differs from grayscale midpoint")
        assert(out[anchor].r==base.r and out[anchor].g==base.g and out[anchor].b==base.b)
        local lastGray = -1
        for _, rgb in ipairs(out) do
          for _, key in ipairs({"r","g","b"}) do
            assert(rgb[key] == math.floor(rgb[key]) and rgb[key]>=0 and rgb[key]<=255)
          end
          local gray = color.rgb_to_grayscale(rgb)
          assert(gray + 0.8 >= lastGray, "Output grayscale was not monotonic")
          lastGray = gray
        end
          countCases = countCases + 1
        end
      end
    end
  end
end


-- Step Modes must change measured grayscale distribution, not just labels.
local neutral = { r=180, g=180, b=180 }
local function sample(mode, center, style, count, strength)
  return ramp.generate{
    center=center or neutral, count=count or 9, strength=strength or 50,
    style=style or "Monochromatic", stepMode=mode
  }
end
local function gray(rgb)
  return color.rgb_to_grayscale(rgb)
end
local balanced, middle = sample("Balanced")
local full = sample("Full Range")
local dark = sample("Shadow Detail")
local bright = sample("Highlight Detail")
local smooth = sample("Soft Ends")
assert(middle == 5)
local deltaShadow = gray(balanced[middle]) - gray(balanced[middle-1])
local deltaHighlight = gray(balanced[middle+1]) - gray(balanced[middle])
assert(math.abs(deltaShadow - deltaHighlight) < 1.5,
  "Balanced should use comparable grayscale brightness steps around the center")
assert(gray(full[1]) < gray(balanced[1]),
  "Full Range should preserve a wider shadow reach")
assert(gray(dark[middle-1]) < gray(balanced[middle-1]),
  "Shadow Detail should reserve more samples near the dark endpoint")
assert(gray(bright[middle+1]) > gray(balanced[middle+1]),
  "Highlight Detail should reserve more samples near the bright endpoint")
assert(gray(smooth[middle-1]) > gray(balanced[middle-1])
   and gray(smooth[middle+1]) < gray(balanced[middle+1]),
  "Soft Ends should have smaller gray steps near the center")

-- Stable original RGB anchor and near-extreme headroom are important.
for _, mode in ipairs(ramp.stepModes) do
  local out, middleIndex = sample(mode)
  assert(out[middleIndex].r==neutral.r and out[middleIndex].g==neutral.g
      and out[middleIndex].b==neutral.b, "Step Mode must preserve center RGB")
end
assert(not pcall(ramp.generate, {
  center=neutral,count=9,strength=50,style="Monochromatic",stepMode="unknown"
}))
local implicit = ramp.generate{center=neutral,count=9,strength=50,style="Monochromatic"}
for i,c in ipairs(implicit) do
  assert(c.r==balanced[i].r and c.g==balanced[i].g and c.b==balanced[i].b)
end
local fromBlack = sample("Balanced",{r=0,g=0,b=0})
local fromWhite = sample("Balanced",{r=255,g=255,b=255})
assert(gray(fromBlack[#fromBlack]) > 130, "Black-centered ramp lost highlights")
assert(gray(fromWhite[1]) < 125, "White-centered ramp lost shadows")

-- Screenshot regression: an 8-color bright olive source used to produce
-- four-times larger grayscale steps in shadows than highlights.
local screenshotAnchor = {r=175,g=179,b=129}
local olive, anchorIndex = sample("Balanced",screenshotAnchor,"Monochromatic",8,50)
local smallest, largest = math.huge, 0
for i=2,#olive do
  local difference = gray(olive[i]) - gray(olive[i-1])
  assert(difference > 0, "Balanced grayscale steps must rise")
  smallest = math.min(smallest,difference)
  largest = math.max(largest,difference)
end
assert(largest / smallest < 1.10,
  "Output grayscale must not repeat the 4x shadow/highlight disparity")
assert(olive[anchorIndex].r==screenshotAnchor.r
   and olive[anchorIndex].g==screenshotAnchor.g
   and olive[anchorIndex].b==screenshotAnchor.b)

-- Saturated hue changes and gamut compression must still meet target
-- grayscale brightness, across both light and dark sides.
local vivid = {
  {r=240,g=25,b=20}, {r=15,g=210,b=35}, {r=25,g=35,b=240},
  {r=250,g=200,b=10}, {r=95,g=35,b=185}, {r=50,g=150,b=155}
}
for _, center in ipairs(vivid) do
  for _, style in ipairs(ramp.styles) do
    local output, anchor = sample("Balanced",center,style,8,100)
    local gray0 = gray(center)
    local leftSteps,rightSteps=anchor-1,#output-anchor
    local ss=0.8*gray0/leftSteps
    local hs=0.8*(255-gray0)/rightSteps
    local minimum,maximum=math.min(ss,hs),math.max(ss,hs)
    local balance=maximum>0 and math.min(1,4*minimum/maximum) or 0
    ss=ss*(1-balance)+minimum*balance
    hs=hs*(1-balance)+minimum*balance
    for i,c in ipairs(output) do
      local expected
      if i<anchor then expected=gray0-(anchor-i)*ss
      elseif i>anchor then expected=gray0+(i-anchor)*hs
      else expected=gray0 end
      assert(math.abs(gray(c)-expected)<1.5,
        "RGB grayscale misses Step target at slot "..i.." for "..style)
    end
  end
end

-- Capture the OKLCH inputs before gamut mapping: switching Step Mode
-- must not modify intended Hue or Chroma at any palette position.
local testMath={
  rgb_to_oklch=function() return {L=0.72,C=0.05,h=150} end,
  rgb_to_grayscale=function(c)
    return c.r > 1 and 180 or c.r * 255
  end,
  oklch_to_rgb=function(L,C,h) return {r=L,g=C,b=h} end
}
local pureRamp=dofile("extensions/hue-shift/src/ramp.lua")(testMath)
for _, style in ipairs(pureRamp.styles) do
  local reference, anchor = pureRamp.generate{
    center={r=120,g=150,b=80},count=9,strength=70,
    style=style,stepMode="Balanced"
  }
  for _, mode in ipairs(pureRamp.stepModes) do
    local result=pureRamp.generate{
      center={r=120,g=150,b=80},count=9,strength=70,
      style=style,stepMode=mode
    }
    for i=1,#result do
      if i~=anchor then
        assert(near(result[i].g,reference[i].g,1e-10),"Step Mode changed Chroma")
        assert(near(result[i].b,reference[i].b,1e-10),"Step Mode changed Hue")
      end
    end
  end
end

-- Even counts switch the anchor by measured gray, odd counts do not.
local evenCases={
  {rgb={r=0,g=0,b=0},expected=4},
  {rgb={r=127,g=127,b=127},expected=4},
  {rgb={r=128,g=128,b=128},expected=5},
  {rgb={r=255,g=255,b=255},expected=5},
  {rgb={r=255,g=0,b=0},expected=4},
  {rgb={r=0,g=255,b=0},expected=5},
  {rgb={r=0,g=0,b=255},expected=4},
  {rgb={r=175,g=179,b=129},expected=5}
}
for _, case in ipairs(evenCases) do
  for _, mode in ipairs(ramp.stepModes) do
    local result, anchor=sample(mode,case.rgb,"Warm Light / Cool Shadow",8,50)
    assert(anchor==case.expected,"Grayscale anchor mismatch")
    assert(result[anchor].r==case.rgb.r and result[anchor].g==case.rgb.g
        and result[anchor].b==case.rgb.b,"Source RGB changed")
  end
end
for _, count in ipairs({4,6,10,16}) do
  local _,left=ramp.generate{
    center={r=127,g=127,b=127},count=count,strength=50,
    style="Monochromatic",stepMode="Balanced"
  }
  local _,right=ramp.generate{
    center={r=128,g=128,b=128},count=count,strength=50,
    style="Monochromatic",stepMode="Balanced"
  }
  assert(left==count/2 and right==count/2+1)
end
for _, count in ipairs({3,5,7,9,15}) do
  for _, v in ipairs({0,128,255}) do
    local _, anchor=ramp.generate{
      center={r=v,g=v,b=v},count=count,strength=50,
      style="Monochromatic",stepMode="Balanced"
    }
    assert(anchor==(count+1)/2)
  end
end
assert(near(color.rgb_to_grayscale({r=128,g=128,b=128}),128,1e-9))
assert(gray({r=0,g=255,b=0})>128 and gray({r=255,g=0,b=0})<128)

-- Palette writer tests using Aseprite-compatible mocks.
local function makePalette(size)
  local pal = { size=size, entries={} }
  return setmetatable(pal, {
    __len = function(t) return t.size end,
    __index = {
      resize = function(t, n) t.size=n end,
      setColor = function(t, idx, col) t.entries[idx]=col end
    }
  })
end
local p = makePalette(5)
local s = { isValid = true, palettes = {p} }
_G.Color = function(c) return c end
local commits = 0
_G.app = {
  transaction=function(label, fn) assert(label:find("Hue Shift")); commits=commits+1; fn() end,
  refresh=function() end
}
local colors = ramp.generate{ center=samples[6],count=7,strength=50,style=ramp.styles[2] }
local ok,msg = paletteWriter.append(s, colors)
assert(ok and #p == 12 and commits == 1 and p.entries[5].r ~= nil and p.entries[11].b ~= nil)
-- Palette capacity does not constrain ramp generation or append.
-- Aseprite decides whether a document's palette can be resized.
local large = makePalette(251)
local added = paletteWriter.append({isValid=true,palettes={large}},colors)
assert(added and #large == 258 and commits == 2)
assert(large.entries[251].r ~= nil and large.entries[257].b ~= nil)
local multi = paletteWriter.append({isValid=true,palettes={p,p}},colors)
assert(not multi)
print("OK: " .. countCases .. " ramp scenarios; grayscale output targets, five Step Modes, gamut, palette append")
