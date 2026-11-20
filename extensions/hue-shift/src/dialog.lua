-- Native Aseprite Color Ramp dialog with HSV wheel overview.
local M = {}

function M.open(ramp, paletteWriter, wheel, version)
  if not app.isUIAvailable then return end

  local picked = app.fgColor
  local center = { r = picked.red, g = picked.green, b = picked.blue }
  local opts = {
    mode = "Single Color",
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
  local references = {{r=73,g=51,b=86}, center, {r=246,g=214,b=139}}
  local selectedReference = 1
  local syncing = false
  local singleControls = {"center", "style", "step_mode", "strength", "strength_help"}

  local function sync_references()
    syncing = true
    local multi = opts.mode == "Multi-Anchor"
    dlg:modify{ id="anchor_help", visible=multi }
    selectedReference = math.min(selectedReference, #references)
    local swatches = {}
    for i, rgb in ipairs(references) do swatches[i] = Color{r=rgb.r,g=rgb.g,b=rgb.b} end
    dlg:modify{ id="references", visible=multi, colors=swatches }
    dlg:modify{ id="reference_color", visible=multi, label="Anchor #"..selectedReference..":",
      color=swatches[selectedReference] }
    dlg:modify{ id="remove_anchor", visible=multi, enabled=#references > 2 }
    dlg:modify{ id="add_anchor", visible=multi, enabled=#references < 8 }
    for _, id in ipairs(singleControls) do dlg:modify{ id=id, visible=not multi } end
    local minimum = multi and #references or 3
    opts.count = math.max(opts.count, minimum)
    dlg:modify{ id="count", label=multi and "Target:" or "Colors:", min=minimum, value=opts.count }
    syncing = false
  end

  local function recompute()
    if syncing then return end
    local data = dlg.data
    local c = data.center
    opts.center = { r = c.red, g = c.green, b = c.blue }
    opts.count = math.max(data.count, opts.mode == "Multi-Anchor" and #references or 3)
    opts.style = data.style
    opts.stepMode = data.step_mode
    opts.strength = data.strength
    opts.anchors = references
    preview, anchor = ramp.generate(opts)
    dlg:modify{ id="status", text="Preview only. No sprite changes yet." }
    dlg:repaint()
  end

  dlg:combobox{
    id="mode", label="Mode:", options={"Single Color", "Multi-Anchor"}, option=opts.mode,
    onchange=function()
      if syncing then return end
      opts.mode = dlg.data.mode
      sync_references()
      recompute()
    end
  }
  dlg:label{ id="anchor_help", label="Dark -> Light:",
    text="Drag references to reorder; click to edit.", visible=false }
  local function select_color(c)
    for i, rgb in ipairs(references) do
      if rgb.r == c.red and rgb.g == c.green and rgb.b == c.blue then
        selectedReference = i
        break
      end
    end
  end
  dlg:shades{
    id="references", label="References:", mode="sort", colors={}, visible=false,
    onclick=function(ev)
      if syncing then return end
      local colors = dlg.data.references
      -- Native shades removes a color when dropped outside the strip. A drag
      -- here only reorders: restore the strip on an outside drop, even at 2.
      if type(colors) ~= "table" or #colors ~= #references then
        sync_references()
        return
      end
      local reordered = {}
      for i, c in ipairs(colors) do reordered[i] = {r=c.red,g=c.green,b=c.blue} end
      references = reordered
      if ev.color then select_color(ev.color) end
      sync_references()
      recompute()
    end
  }
  dlg:color{
    id="reference_color", label="Anchor #1:", visible=false,
    color=Color{r=references[1].r,g=references[1].g,b=references[1].b},
    onchange=function()
      if syncing then return end
      local c = dlg.data.reference_color
      references[selectedReference] = {r=c.red,g=c.green,b=c.blue}
      sync_references()
      recompute()
    end
  }
  dlg:button{
    id="add_anchor", text="+ Add Anchor", visible=false,
    onclick=function()
      if #references >= 8 then return end
      local c = app.fgColor
      references[#references+1] = {r=c.red,g=c.green,b=c.blue}
      selectedReference = #references
      sync_references()
      recompute()
    end
  }
  dlg:button{
    id="remove_anchor", text="Remove Anchor", visible=false,
    onclick=function()
      if #references <= 2 then return end
      table.remove(references, selectedReference)
      sync_references()
      recompute()
    end
  }
  dlg:newrow()
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
    id = "strength_help",
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
      local markers = {}
      if type(anchor) == "table" then
        for _, position in ipairs(anchor) do markers[position] = true end
      else markers[anchor] = true end
      for i, rgb in ipairs(preview) do
        local left = gutter + math.floor((i - 1) * usable / count)
        local right = gutter + math.floor(i * usable / count)
        gc.color = Color{ r = rgb.r, g = rgb.g, b = rgb.b }
        gc:fillRect(Rectangle(left, y, math.max(1, right-left-gap), h))
        if markers[i] then
          gc.color = Color{ r = 255, g = 255, b = 255 }
          gc.strokeWidth = 1
          gc:strokeRect(Rectangle(left, y, math.max(1, right-left-gap), h))
        end
      end
      gc.color = app.theme and app.theme.color.text or Color{ r = 190, g = 190, b = 190 }
      gc:fillText("Shadow", gutter, 49)
      local caption = type(anchor) == "table" and (#references .. " references") or ("Anchor #" .. anchor)
      gc:fillText(caption, math.floor(gc.width * 0.38), 49)
      gc:fillText("Light", gc.width - 45, 49)
    end
  }
  dlg:check{
    id="show_map", label="Color Map:", text="Show HSV map", selected=false,
    onclick=function() dlg:modify{ id="hue_wheel", visible=dlg.data.show_map } end
  }
  dlg:canvas{
    id = "hue_wheel",
    visible = false,
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
