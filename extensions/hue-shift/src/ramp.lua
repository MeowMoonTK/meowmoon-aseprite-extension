-- Hue style sets hue direction; Step Mode controls how far each ramp
-- color travels along the shadow/highlight path.
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

  M.stepModes = {
    "Balanced",
    "Full Range",
    "Shadow Detail",
    "Highlight Detail",
    "Soft Ends"
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
      -- Zigzag alternates direction per actual palette step, not interpolated distance.
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

  local function step_progress(mode, t, shadow)
    if (mode == "Shadow Detail" and shadow)
        or (mode == "Highlight Detail" and not shadow) then
      -- Reach deeper into the side early, reserving more samples at the endpoint.
      return 1 - (1 - t) ^ 2
    elseif mode == "Soft Ends" then
      -- Concentrate colors close to the anchor and both endpoints.
      return t * t * (3 - 2 * t)
    end
    return t
  end

  function M.generate(opts)
    assert(type(opts) == "table", "options table expected")
    local n = assert(tonumber(opts.count), "count is required")
    assert(n == math.floor(n) and n >= 3 and n <= 16, "count must be 3..16")
    local power = assert(tonumber(opts.strength), "strength is required") / 100
    assert(power >= 0 and power <= 1, "strength must be 0..100")

    local mode = opts.stepMode or "Balanced"
    local knownMode = false
    for _, name in ipairs(M.stepModes) do
      if name == mode then knownMode = true; break end
    end
    assert(knownMode, "Unknown Step Mode: " .. tostring(mode))

    local center = assert(opts.center, "center color required")
    local rgb = {
      r = assert(center.r), g = assert(center.g), b = assert(center.b)
    }
    local base = colorMath.rgb_to_oklch(rgb)
    local anchor = math.floor((n + 1) / 2) -- even counts: left-middle cell
    local leftSteps, rightSteps = anchor - 1, n - anchor

    -- In Balanced modes, the same OKLab Lightness increment is used for
    -- each step on either side. This prevents a bright anchor from making
    -- shadow steps much larger than highlight steps (or the reverse).
    -- Full Range keeps the old independently scaled end-to-end lightness.
    local evenStep = 0.80 * math.min(
      base.L / leftSteps, (1 - base.L) / rightSteps
    )
    local result = {}
    for i = 1, n do
      if i == anchor then
        -- The source RGB is copied byte-for-byte, not round-tripped.
        result[i] = { r = rgb.r, g = rgb.g, b = rgb.b }
      else
        local shadow = i < anchor
        local steps = math.abs(i - anchor)
        local sideSteps = shadow and leftSteps or rightSteps
        local t = steps / sideSteps
        local d = step_progress(mode, t, shadow)
        local sign = shadow and -1 or 1

        local L
        if mode == "Full Range" then
          -- Original behavior for comparison: each side extends independently.
          local headroom = shadow and base.L or (1 - base.L)
          L = base.L + sign * 0.80 * headroom * d
        else
          L = base.L + sign * evenStep * sideSteps * d
        end
        local C = base.C * (1 - 0.18 * d)
        local h = (base.h + hue_shift(opts.style, base.h, sign * d, d, power, steps)) % 360
        result[i] = colorMath.oklch_to_rgb(L, C, h)
      end
    end
    return result, anchor
  end

  return M
end
