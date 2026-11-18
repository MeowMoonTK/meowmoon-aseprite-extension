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
  for n=3,16 do
    for _, strength in ipairs({0,35,100}) do
      for _, base in ipairs(samples) do
        local out, anchor = ramp.generate{
          center=base, count=n, strength=strength, style=style
        }
        assert(#out == n)
        assert(anchor == math.floor((n+1)/2))
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
print("OK: " .. countCases .. " ramp scenarios, gamut conversions, unrestricted palette append")
