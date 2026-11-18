-- Palette mutation is isolated from rendering and done in one Undo step.
local M = {}

function M.append(sprite, rgbColors)
  if not sprite or not sprite.isValid then
    return false, "Open a sprite before adding a Color Ramp."
  end

  local palettes = sprite.palettes
  if not palettes or #palettes ~= 1 then
    return false, "Sprites with multiple frame palettes are not supported in v0.1."
  end

  local palette = palettes[1]
  local oldSize = #palette
  if oldSize + #rgbColors > 256 then
    return false, "Not enough palette slots (maximum 256). No colors were changed."
  end

  local success, err = pcall(function()
    app.transaction("Hue Shift: Add Color Ramp", function()
      palette:resize(oldSize + #rgbColors)
      for i, rgb in ipairs(rgbColors) do
        palette:setColor(oldSize + i - 1, Color{
          r = rgb.r, g = rgb.g, b = rgb.b, a = 255
        })
      end
    end)
  end)
  if not success then
    return false, "Palette update failed: " .. tostring(err)
  end
  app.refresh()
  return true, "Added " .. #rgbColors .. " colors to the palette."
end

return M
