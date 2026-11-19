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
        local lastL = -1
        for _, rgb in ipairs(out) do
          for _, key in ipairs({"r","g","b"}) do
            assert(rgb[key] == math.floor(rgb[key]) and rgb[key]>=0 and rgb[key]<=255)
          end
          local L = color.rgb_to_oklch(rgb).L
          assert(L + 0.008 >= lastL, "Lightness was not monotonic")
          lastL = L
        end
          countCases = countCases + 1
        end
      end
    end
  end
end


-- Step modes must alter measured OKLab lightness spacing, not just labels.
local neutral = { r=180, g=180, b=180 }
local function sample(mode)
  return ramp.generate{
    center=neutral, count=9, strength=50, style="Monochromatic", stepMode=mode
  }
end
local function lightness(rgb)
  return color.rgb_to_oklch(rgb).L
end
local balanced, middle = sample("Balanced")
local old = sample("Full Range")
local dark = sample("Shadow Detail")
local bright = sample("Highlight Detail")
local smooth = sample("Soft Ends")
assert(middle == 5)
local deltaShadow = lightness(balanced[middle]) - lightness(balanced[middle-1])
local deltaHighlight = lightness(balanced[middle+1]) - lightness(balanced[middle])
assert(math.abs(deltaShadow - deltaHighlight) < 0.015,
  "Balanced should use comparable lightness steps around the center")
assert(lightness(old[1]) < lightness(balanced[1]),
  "Full Range should keep the stronger shadow reach of the old algorithm")
assert(lightness(dark[middle-1]) < lightness(balanced[middle-1]),
  "Shadow Detail should reserve more samples near the dark endpoint")
assert(lightness(bright[middle+1]) > lightness(balanced[middle+1]),
  "Highlight Detail should reserve more samples near the light endpoint")
assert(lightness(smooth[middle-1]) > lightness(balanced[middle-1])
   and lightness(smooth[middle+1]) < lightness(balanced[middle+1]),
  "Soft Ends should have smaller color steps near the center")
for _, mode in ipairs(ramp.stepModes) do
  local out, centerIndex = sample(mode)
  assert(out[centerIndex].r==neutral.r and out[centerIndex].g==neutral.g
      and out[centerIndex].b==neutral.b,
    "Every Step Mode must preserve the original center RGB")
end
local okInvalid = pcall(ramp.generate, {
  center=neutral, count=9, strength=50,
  style="Monochromatic", stepMode="unknown"
})
assert(not okInvalid, "Unknown Step Mode must be rejected")
-- No explicit option must default to Balanced.
local implicit = ramp.generate{center=neutral,count=9,strength=50,style="Monochromatic"}
for i, c in ipairs(implicit) do
  assert(c.r==balanced[i].r and c.g==balanced[i].g and c.b==balanced[i].b)
end


-- A symmetric range is impossible when the source is pure black or white.
-- Balanced must still produce useful colors on the side with headroom.
local fromBlack = ramp.generate{
  center={r=0,g=0,b=0}, count=9, strength=0,
  style="Monochromatic", stepMode="Balanced"
}
assert(lightness(fromBlack[9]) > 0.5,
  "Balanced must not collapse the bright side of a black-centered ramp")
local fromWhite = ramp.generate{
  center={r=255,g=255,b=255}, count=9, strength=0,
  style="Monochromatic", stepMode="Balanced"
}
assert(lightness(fromWhite[1]) < 0.5,
  "Balanced must not collapse the dark side of a white-centered ramp")


-- The screenshot had roughly 4x stronger OKLab Lightness steps
-- in shadows than highlights. Balanced must remove that disparity.
local screenshotAnchor = {r=175, g=179, b=129}
local screenshotOut, screenshotMid = ramp.generate{
  center=screenshotAnchor, count=8, strength=50,
  style="Monochromatic", stepMode="Balanced"
}
local minDiff, maxDiff = math.huge, 0
for i=2,#screenshotOut do
  local diff = lightness(screenshotOut[i]) - lightness(screenshotOut[i-1])
  assert(diff > 0, "Balanced must increase Lightness.")
  minDiff = math.min(minDiff, diff)
  maxDiff = math.max(maxDiff, diff)
end
assert(maxDiff / minDiff < 1.15,
  "Balanced should not have the screenshot's 4x dark/light disparity.")
assert(screenshotOut[screenshotMid].r==screenshotAnchor.r
   and screenshotOut[screenshotMid].g==screenshotAnchor.g
   and screenshotOut[screenshotMid].b==screenshotAnchor.b)

-- Capture input OKLCH values (before gamut compression) to ensure
-- that switching Step Mode changes ONLY Lightness, not Hue or Chroma.
local testMath = {
  rgb_to_oklch = function() return {L=0.72,C=0.05,h=150} end,
  oklch_to_rgb = function(L,C,h) return {r=L,g=C,b=h} end
}
local pureRamp = dofile("extensions/hue-shift/src/ramp.lua")(testMath)
for _, style in ipairs(pureRamp.styles) do
  local reference, anchorIndex = pureRamp.generate{
    center={r=120,g=150,b=80},count=9,strength=70,
    style=style,stepMode="Balanced"
  }
  for _, mode in ipairs(pureRamp.stepModes) do
    local result = pureRamp.generate{
      center={r=120,g=150,b=80},count=9,strength=70,
      style=style,stepMode=mode
    }
    for i=1,#result do
      if i~=anchorIndex then
        assert(near(result[i].g,reference[i].g,1e-10),
          "Step Mode must not change Chroma: "..mode)
        assert(near(result[i].b,reference[i].b,1e-10),
          "Step Mode must not change Hue: "..mode)
      end
    end
  end
end


-- Grayscale placement for even palettes:
-- #808080 is the neutral reference; a bright source moves from 4 to 5
-- in an 8-color ramp to allow four shadows, a dark one stays at 4.
local evenCases = {
  {rgb={r=0,g=0,b=0}, expected=4},
  {rgb={r=127,g=127,b=127}, expected=4},
  {rgb={r=128,g=128,b=128}, expected=5},
  {rgb={r=255,g=255,b=255}, expected=5},
  -- Saturated colors use luminance-weighted grayscale, not raw RGB
  -- channel average and not the hue/chroma of the source.
  {rgb={r=255,g=0,b=0}, expected=4},
  {rgb={r=0,g=255,b=0}, expected=5},
  {rgb={r=0,g=0,b=255}, expected=4},
  {rgb={r=175,g=179,b=129}, expected=5}
}
for _, case in ipairs(evenCases) do
  for _, mode in ipairs(ramp.stepModes) do
    local result, anchor = ramp.generate{
      center=case.rgb,count=8,strength=50,
      style="Warm Light / Cool Shadow",stepMode=mode
    }
    assert(anchor == case.expected,
      "Wrong grayscale anchor for RGB " ..
      case.rgb.r .. "," .. case.rgb.g .. "," .. case.rgb.b ..
      " in " .. mode)
    assert(result[anchor].r == case.rgb.r
       and result[anchor].g == case.rgb.g
       and result[anchor].b == case.rgb.b,
      "The original RGB must remain unchanged at the selected anchor")
  end
end
for _, count in ipairs({4,6,10,16}) do
  local _, leftAnchor = ramp.generate{
    center={r=127,g=127,b=127},count=count,
    strength=50,style="Monochromatic",stepMode="Balanced"
  }
  local _, rightAnchor = ramp.generate{
    center={r=128,g=128,b=128},count=count,
    strength=50,style="Monochromatic",stepMode="Balanced"
  }
  assert(leftAnchor == count/2 and rightAnchor == count/2+1,
    "Any even count must support either midpoint anchor")
end
for _, count in ipairs({3,5,7,9,15}) do
  for _, gray in ipairs({0,128,255}) do
    local _, anchor = ramp.generate{
      center={r=gray,g=gray,b=gray},count=count,
      strength=50,style="Monochromatic",stepMode="Balanced"
    }
    assert(anchor == (count+1)/2, "Odd counts must retain one center")
  end
end
assert(near(color.rgb_to_grayscale({r=128,g=128,b=128}),128,1e-9))
assert(color.rgb_to_grayscale({r=0,g=255,b=0}) > 128)
assert(color.rgb_to_grayscale({r=255,g=0,b=0}) < 128)

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
print("OK: " .. countCases .. " ramp scenarios, five Step Modes, gamut conversions, unrestricted palette append")
