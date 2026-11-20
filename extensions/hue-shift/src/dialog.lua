-- Native Aseprite Color Ramp dialog with HSV wheel overview.
local M = {}

function M.open(ramp, paletteWriter, wheel, version, updater)
  if not app.isUIAvailable then return end

  local picked = app.fgColor
  local center = { r = picked.red, g = picked.green, b = picked.blue }
  local opts = {
    center = center,
    count = 7,
    style = "Warm Light / Cool Shadow",
    stepMode = "Balanced",
    strength = 50
  }
  local preview, anchor = ramp.generate(opts)
  -- Wheel pixels are computed once; repaint only the dots and path.
  local wheelImage = wheel.make_image(80)
  local dlg = Dialog{ title = "MeowMoon Hue Shift" }

  local function recompute()
    local data = dlg.data
    local c = data.center
    opts.center = { r = c.red, g = c.green, b = c.blue }
    opts.count = data.count
    opts.style = data.style
    opts.stepMode = data.step_mode
    opts.strength = data.strength
    preview, anchor = ramp.generate(opts)
    dlg:repaint()
  end

  dlg:color{
    id = "center",
    label = "Center Color:",
    color = Color{ r = center.r, g = center.g, b = center.b },
    onchange = recompute
  }
  dlg:slider{
    id = "count",
    label = "Colors:",
    min = 3, max = 16, value = 7,
    onchange = recompute
  }
  dlg:combobox{
    id = "style",
    label = "Shift Style:",
    options = ramp.styles,
    option = opts.style,
    onchange = recompute
  }
  dlg:combobox{
    id = "step_mode",
    label = "Step Mode:",
    options = ramp.stepModes,
    option = opts.stepMode,
    onchange = recompute
  }
  dlg:slider{
    id = "strength",
    label = "Hue Strength:",
    min = 0, max = 100, value = 50,
    onchange = recompute
  }
  dlg:label{
    label = "Strength:",
    text = "0% = no Hue shift; 100% = full style rotation"
  }
  dlg:canvas{
    id = "preview",
    label = "Ramp:",
    width = 360,
    height = 65,
    autoscaling = true,
    onpaint = function(ev)
      local gc = ev.context
      local count = #preview
      local gutter, gap = 6, 2
      local usable = gc.width - gutter * 2
      local y, h = 7, 36
      for i, rgb in ipairs(preview) do
        local left = gutter + math.floor((i - 1) * usable / count)
        local right = gutter + math.floor(i * usable / count)
        gc.color = Color{ r = rgb.r, g = rgb.g, b = rgb.b }
        gc:fillRect(Rectangle(left, y, math.max(1, right-left-gap), h))
        if i == anchor then
          gc.color = Color{ r = 255, g = 255, b = 255 }
          gc.strokeWidth = 1
          gc:strokeRect(Rectangle(left, y, math.max(1, right-left-gap), h))
        end
      end
      gc.color = Color{ r = 190, g = 190, b = 190 }
      gc:fillText("Shadow", gutter, 49)
      gc:fillText("Anchor #" .. anchor, math.floor(gc.width * 0.42), 49)
      gc:fillText("Light", gc.width - 45, 49)
    end
  }
  dlg:canvas{
    id = "hue_wheel",
    label = "Color Map:",
    width = 360,
    height = 201,
    autoscaling = true,
    onpaint = function(ev)
      wheel.paint(ev.context, wheelImage, preview, anchor)
    end
  }
  dlg:label{
    id = "status",
    label = "Status:",
    text = "Preview only. No sprite changes yet."
  }
  dlg:label{
    label = "Version:",
    text = "v" .. tostring(version or "unknown")
  }
  if updater and app.os and app.os.windows then
    dlg:label{
      id = "update_status",
      label = "Updates:",
      text = updater.launchStatus
    }
    dlg:button{
      id = "update",
      text = "Check Updates",
      enabled = not updater.busy,
      onclick = function()
        dlg:modify{ id = "update", enabled = false }
        dlg:modify{ id = "update_status", text = "Checking releases..." }
        local ok, message = updater.checkNow(function(kind, status)
          pcall(function()
            dlg:modify{ id = "update_status", text = status }
            dlg:modify{ id = "update", enabled = kind ~= "verified" and kind ~= "checking" }
          end)
        end)
        if not ok then
          dlg:modify{ id = "update", enabled = not updater.busy }
          dlg:modify{ id = "update_status", text = message }
          app.alert{ title = "Hue Shift Updates", text = message }
        end
      end
    }
  end
  dlg:button{
    id = "apply",
    text = "Add to Palette",
    onclick = function()
      local ok, message = paletteWriter.append(app.sprite, preview)
      dlg:modify{ id = "status", text = message }
      if not ok then app.alert{ title = "Hue Shift", text = message } end
    end
  }
  dlg:button{ text = "Close" }
  dlg:show{ wait = false, autoscrollbars = true }
end

return M
