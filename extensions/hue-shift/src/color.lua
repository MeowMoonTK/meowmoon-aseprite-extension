-- Pure Lua sRGB <-> OKLCH conversions.
-- Uses Bjorn Ottosson's published Oklab transform matrices (MIT).
local M = {}

local function clamp(x, lo, hi)
  return math.max(lo, math.min(hi, x))
end

local function srgb_to_linear(x)
  x = clamp(x, 0, 1)
  if x <= 0.04045 then return x / 12.92 end
  return ((x + 0.055) / 1.055) ^ 2.4
end

local function linear_to_srgb(x)
  if x <= 0.0031308 then return 12.92 * x end
  return 1.055 * (x ^ (1 / 2.4)) - 0.055
end

function M.rgb_to_oklch(rgb)
  local r = srgb_to_linear(rgb.r / 255)
  local g = srgb_to_linear(rgb.g / 255)
  local b = srgb_to_linear(rgb.b / 255)

  local l = (0.4122214708*r + 0.5363325363*g + 0.0514459929*b) ^ (1/3)
  local m = (0.2119034982*r + 0.6806995451*g + 0.1073969566*b) ^ (1/3)
  local s = (0.0883024619*r + 0.2817188376*g + 0.6299787005*b) ^ (1/3)

  local L = 0.2104542553*l + 0.7936177850*m - 0.0040720468*s
  local a = 1.9779984951*l - 2.4285922050*m + 0.4505937099*s
  local bb = 0.0259040371*l + 0.7827717662*m - 0.8086757660*s
  local C = math.sqrt(a*a + bb*bb)
  local h = C < 0.000001 and 0 or (math.deg(math.atan(bb, a)) % 360)

  return { L = clamp(L, 0, 1), C = C, h = h }
end

local function oklch_to_linear(L, C, h)
  local a = C * math.cos(math.rad(h))
  local b = C * math.sin(math.rad(h))
  local l = (L + 0.3963377774*a + 0.2158037573*b) ^ 3
  local m = (L - 0.1055613458*a - 0.0638541728*b) ^ 3
  local s = (L - 0.0894841775*a - 1.2914855480*b) ^ 3
  return {
    4.0767416621*l - 3.3077115913*m + 0.2309699292*s,
   -1.2684380046*l + 2.6097574011*m - 0.3413193965*s,
   -0.0041960863*l - 0.7034186147*m + 1.7076147010*s
  }
end

local function in_gamut(v)
  -- Tolerance accommodates floating-point roundoff near black/white.
  return v[1] >= -1e-7 and v[1] <= 1+1e-7
     and v[2] >= -1e-7 and v[2] <= 1+1e-7
     and v[3] >= -1e-7 and v[3] <= 1+1e-7
end

function M.oklch_to_rgb(L, C, h)
  L, C = clamp(L, 0, 1), math.max(C, 0)
  local linear = oklch_to_linear(L, C, h)

  if not in_gamut(linear) then
    -- Preserve perceptual lightness and hue; reduce chroma only.
    local lo, hi = 0, C
    for _ = 1, 28 do
      local mid = (lo + hi) * 0.5
      if in_gamut(oklch_to_linear(L, mid, h)) then
        lo = mid
      else
        hi = mid
      end
    end
    linear = oklch_to_linear(L, lo, h)
  end

  local function to_byte(x)
    return math.floor(clamp(linear_to_srgb(x), 0, 1) * 255 + 0.5)
  end
  return { r = to_byte(linear[1]), g = to_byte(linear[2]), b = to_byte(linear[3]) }
end

return M
