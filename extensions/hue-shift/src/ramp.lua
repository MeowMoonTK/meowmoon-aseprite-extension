-- Hue Shift Style controls hue direction. Step Mode controls the measured
-- grayscale brightness of the final sRGB colors, not input OKLab Lightness.
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
      -- Redistribute grayscale targets toward the far endpoint.
      return 1 - (1 - t) ^ 2
    elseif mode == "Soft Ends" then
      -- Ease grayscale targets near the anchor and both endpoints.
      return t * t * (3 - 2 * t)
    end
    return t
  end

  -- Inverting grayscale through the real RGB output accounts for hue changes,
  -- gamut compression and 8-bit quantization. C/h still come from Shift Style;
  -- they never depend on the selected Step Mode.
  local function rgb_at_grayscale(target, chroma, hue)
    local low, high = 0, 1
    local best, bestError = nil, math.huge
    -- The final output is 8-bit RGB, so 16 bisections suffice; choose the
    -- closest measured grayscale, not simply the final bisection midpoint.
    for _ = 1, 16 do
      local L = (low + high) * 0.5
      local rgb = colorMath.oklch_to_rgb(L, chroma, hue)
      local observed = colorMath.rgb_to_grayscale(rgb) / 255
      local error = math.abs(observed - target)
      if error < bestError then
        best, bestError = rgb, error
      end
      if observed < target then low = L else high = L end
    end
    return best
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
    -- With even counts the source occupies one of the two middle slots.
    -- Compare its grayscale equivalent with neutral 50% gray (#808080):
    -- dark sources get more highlight slots (left-middle anchor); light
    -- sources get more shadow slots (right-middle anchor).
    local anchor = math.floor((n + 1) / 2)
    if n % 2 == 0 and colorMath.rgb_to_grayscale(rgb) >= 128 then
      anchor = anchor + 1
    end
    local leftSteps, rightSteps = anchor - 1, n - anchor

    -- Allocate the available GRAYSCALE range, leaving 20% headroom at
    -- black/white. Balanced uses a common brightness increment unless that
    -- would collapse a ramp anchored very close to either extreme.
    local gray0 = colorMath.rgb_to_grayscale(rgb) / 255
    local nativeShadowStep = 0.80 * gray0 / leftSteps
    local nativeHighlightStep = 0.80 * (1 - gray0) / rightSteps
    local minStep = math.min(nativeShadowStep, nativeHighlightStep)
    local maxStep = math.max(nativeShadowStep, nativeHighlightStep)
    local balance = maxStep > 0 and math.min(1, 4 * minStep / maxStep) or 0
    local shadowStep = nativeShadowStep * (1 - balance) + minStep * balance
    local highlightStep = nativeHighlightStep * (1 - balance) + minStep * balance
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
        local lightnessT = step_progress(mode, t, shadow)
        local sign = shadow and -1 or 1

        local grayTarget
        if mode == "Full Range" then
          -- Each side independently occupies 80% of its available gray range.
          local headroom = shadow and gray0 or (1 - gray0)
          grayTarget = gray0 + sign * 0.80 * headroom * lightnessT
        else
          local stepG = shadow and shadowStep or highlightStep
          grayTarget = gray0 + sign * stepG * sideSteps * lightnessT
        end
        -- Chroma and hue follow their existing profiles. Solve for the
        -- Lightness whose FINAL gamut-mapped RGB has the desired gray value.
        local C = base.C * (1 - 0.18 * t)
        local h = (base.h + hue_shift(opts.style, base.h, sign * t, t, power, steps)) % 360
        result[i] = rgb_at_grayscale(grayTarget, C, h)
      end
    end
    return result, anchor
  end

  return M
end
