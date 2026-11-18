-- HSV hue/saturation map for the Hue Shift ramp.
-- Pure conversion/position helpers are usable without an Aseprite runtime.
local M = {}
local tau = math.pi * 2

local function byte(n)
  return math.max(0, math.min(255, math.floor(n * 255 + 0.5)))
end

function M.to_hsv(rgb)
  local r, g, b = rgb.r / 255, rgb.g / 255, rgb.b / 255
  local mx, mn = math.max(r, g, b), math.min(r, g, b)
  local d = mx - mn
  local h = 0
  if d > 0 then
    if mx == r then
      h = ((g - b) / d) % 6
    elseif mx == g then
      h = (b - r) / d + 2
    else
      h = (r - g) / d + 4
    end
    h = (h * 60) % 360
  end
  return { h = h, s = mx <= 0 and 0 or d / mx, v = mx }
end

function M.from_hsv(h, s, v)
  h, s, v = h % 360, math.max(0, math.min(1, s)), math.max(0, math.min(1, v))
  local c = v * s
  local x = c * (1 - math.abs(((h / 60) % 2) - 1))
  local m = v - c
  local r, g, b
  if h < 60 then r, g, b = c, x, 0
  elseif h < 120 then r, g, b = x, c, 0
  elseif h < 180 then r, g, b = 0, c, x
  elseif h < 240 then r, g, b = 0, x, c
  elseif h < 300 then r, g, b = x, 0, c
  else r, g, b = c, 0, x end
  return { r = byte(r+m), g = byte(g+m), b = byte(b+m) }
end

function M.position(rgb, radius)
  local hsv = M.to_hsv(rgb)
  local angle = hsv.h * tau / 360
  local distance = hsv.s * radius
  return math.cos(angle) * distance, -math.sin(angle) * distance, hsv
end

function M.make_image(radius)
  local size = radius * 2 + 1
  local img = Image(size, size, ColorMode.RGB)
  for y = 0, size - 1 do
    local dy = y - radius
    for x = 0, size - 1 do
      local dx = x - radius
      local d = math.sqrt(dx*dx + dy*dy)
      if d <= radius then
        local h = (math.deg(math.atan(-dy, dx)) + 360) % 360
        local rgb = M.from_hsv(h, d / radius, 1)
        img:drawPixel(x, y, app.pixelColor.rgba(rgb.r, rgb.g, rgb.b, 255))
      end
    end
  end
  return img
end

-- The wheel is fixed and cached by the caller. Only dots/lines repaint.
function M.paint(gc, image, colors, anchor)
  local radius = (image.width - 1) / 2
  local cx = 99
  local cy = radius + 10
  local left = cx - radius
  local top = cy - radius
  gc:drawImage(image, left, top)

  gc.color = Color { r=55, g=55, b=55 }
  gc.strokeWidth = 1
  gc:beginPath()
  gc:oval(Rectangle(left, top, image.width, image.height))
  gc:stroke()

  local points = {}
  for i, rgb in ipairs(colors) do
    local dx, dy, hsv = M.position(rgb, radius - 4)
    points[i] = { x = cx + dx, y = cy + dy, hsv = hsv }
  end

  -- A path through Hue/Saturation positions makes zigzag easy to recognize.
  if #points >= 2 then
    gc.color = Color { r=32, g=32, b=32 }
    gc.strokeWidth = 2
    gc:beginPath()
    gc:moveTo(points[1].x, points[1].y)
    for i = 2, #points do
      gc:lineTo(points[i].x, points[i].y)
    end
    gc:stroke()
  end

  -- Plot swatches and label each corresponding Hue in a compact legend.
  for i, rgb in ipairs(colors) do
    local p = points[i]
    local size = i == anchor and 12 or 8
    local x = math.floor(p.x - size/2 + 0.5)
    local y = math.floor(p.y - size/2 + 0.5)

    gc.color = Color { r=18, g=18, b=18 }
    gc:beginPath()
    gc:oval(Rectangle(x-1,y-1,size+2,size+2))
    gc:fill()

    gc.color = Color { r=rgb.r, g=rgb.g, b=rgb.b }
    gc:beginPath()
    gc:oval(Rectangle(x,y,size,size))
    gc:fill()

    if i == anchor then
      gc.color = Color { r=255, g=255, b=255 }
      gc.strokeWidth = 2
      gc:beginPath()
      gc:oval(Rectangle(x-1,y-1,size+2,size+2))
      gc:stroke()
    end

    local legendY = 9 + (i-1)*11
    gc.color = Color { r=rgb.r, g=rgb.g, b=rgb.b }
    gc:fillRect(Rectangle(204,legendY,13,9))
    gc.color = Color { r=215, g=215, b=215 }
    local symbol = i == anchor and "*" or " "
    gc:fillText(string.format("%2d%s  %3d deg", i, symbol, math.floor(p.hsv.h+0.5)), 223, legendY-1)
  end

  gc.color = Color { r=175, g=175, b=175 }
  gc:fillText("Hue: angle / Saturation: radius", 9, 184)
  gc:fillText("* = Anchor", 223, 184)
end

return M
