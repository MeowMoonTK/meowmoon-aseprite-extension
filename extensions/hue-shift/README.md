# Hue Shift v0.1.1

Single-purpose Color Ramp generator for Aseprite. Private use.

## Controls

- **Center Color**: Aseprite color picker; copied exactly into the generated ramp.
- **Colors**: 3–16, default 7; for even counts the left-middle swatch is the anchor.
- **Shift Style**: Monochromatic, Warm Light / Cool Shadow, Cool Light / Warm Shadow, Clockwise, Counterclockwise, Zigzag.
- **Hue Strength**: 0% means no hue shift, 100% means the full style-specific rotation. This does **not** control Lightness or Saturation. Clockwise, Counterclockwise, and Zigzag use up to 80 degrees rotation at 100%; target styles use shortest arcs to their target Hues.
- **Ramp Preview**: Shadows through highlights, with a border around the anchor.
- **Color Map**: An HSV Hue/Saturation wheel showing each generated swatch's Hue (angle) and Saturation (distance from center). The wheel depicts Hue and Saturation only, with the original RGB color in each plotted dot and the swatch legend. Lines connect points from shadow to highlight; a larger outlined dot and '*' in the legend identify the anchor. HSV wheel background is fixed at Value=1; actual swatch brightness is shown in the Ramp Preview.

Changes to the controls repaint both Ramp Preview and the wheel immediately; they do not change sprite pixels or palette until you choose **Add to Palette**.

## Installation

From repository root: python3 scripts/build_hue_shift.py

Install dist/hue-shift-0.1.1.aseprite-extension in Edit > Preferences > Extensions > Add Extension; restart Aseprite.

Open File > Scripts > Hue Shift: Generate Ramp.

## Limitations

- Assumes sRGB; no custom document color profile conversions.
- Grayscale input has no chroma: Hue Shift styles will look monochromatic.
- At black/white anchors one side has limited Lightness range.
- Sprite must have one palette. Refuses to append past 256 colors instead of overwriting.
- Aseprite desktop GUI integration has not yet been exercised. Core Lua and archive format are tested in CI.
