-- All styles use the same lightness/chroma ramp; only hue placement varies.
return function(colorMath)
  local M = {}

  M.styles = {
    "Monochromatic",
    "Warm Light / Cool Shadow",
    "Cool Light / Warm Shadow",
    "Clockwise",
    "Counterclockwise",
    "Zigzag"
  }

  local function shortest_hue_delta(startHue, targetHue)
    return (targetHue - startHue + 540) % 360 - 180
  end

  local function hue_shift(style, baseHue, x, distance, strength, stepsFromAnchor)
    if style == "Monochromatic" then
      return 0
    elseif style == "Clockwise" then
      return x * 80 * strength
    elseif style == "Counterclockwise" then
      return -x * 80 * strength
    elseif style == "Zigzag" then
      -- Alternate the direction on each successive step away from the anchor.
      local sign = stepsFromAnchor % 2 == 1 and -1 or 1
      return sign * 80 * distance * strength
    elseif style == "Warm Light / Cool Shadow"
        or style == "Cool Light / Warm Shadow" then
      local target
      if style == "Warm Light / Cool Shadow" then
        target = x < 0 and 255 or 75
      else
        target = x < 0 and 25 or 215
      end
      return shortest_hue_delta(baseHue, target) * distance * strength
    end
    error("Unknown Hue Shift style: " .. tostring(style))
  end

  function M.generate(opts)
    assert(type(opts) == "table", "options table expected")
    local n = assert(tonumber(opts.count), "count is required")
    assert(n == math.floor(n) and n >= 3 and n <= 16, "count must be 3..16")
    local power = assert(tonumber(opts.strength), "strength is required") / 100
    assert(power >= 0 and power <= 1, "strength must be 0..100")

    local center = assert(opts.center, "center color required")
    local rgb = {
      r = assert(center.r), g = assert(center.g), b = assert(center.b)
    }
    local base = colorMath.rgb_to_oklch(rgb)
    local anchor = math.floor((n + 1) / 2) -- even counts: left-middle cell
    local result = {}
    for i = 1, n do
      if i == anchor then
        -- The source RGB is copied byte-for-byte, not round-tripped.
        result[i] = { r = rgb.r, g = rgb.g, b = rgb.b }
      else
        local steps = math.abs(i - anchor)
        local sideSpan = i < anchor and (anchor - 1) or (n - anchor)
        local d = steps / sideSpan
        local x = (i < anchor and -1 or 1) * d

        -- Adapt the range to the anchor so extreme colors never overshoot.
        local L
        if i < anchor then
          L = base.L * (1 - 0.80 * d)
        else
          L = base.L + (1 - base.L) * 0.80 * d
        end
        local C = base.C * (1 - 0.18 * d)
        local h = (base.h + hue_shift(opts.style, base.h, x, d, power, steps)) % 360
        result[i] = colorMath.oklch_to_rgb(L, C, h)
      end
    end
    return result, anchor
  end

  return M
end
