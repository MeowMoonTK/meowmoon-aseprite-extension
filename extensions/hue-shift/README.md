# Hue Shift v0.1.2

Single-purpose Color Ramp generator for Aseprite (private use).

- Choose 3–16 colors, Center Color, one of six Hue Shift styles (including Zigzag), and Hue Strength.
- Aseprite HSV Color Map illustrates each generated color's hue, saturation, and position.
- Add to Palette appends new colors with Undo support; it does not recolor sprites.
- Color generation uses OKLCH gamut mapping.

Install the packaged `.aseprite-extension` via **Edit > Preferences > Extensions**, or install the **optional Windows auto-updater** from [../../updater](../../updater) to receive new private GitHub Releases.

## Manual packaging

From repo root run: `python3 scripts/build_hue_shift.py`

> Known limitation: Aseprite desktop GUI integration and the Windows auto-updater require testing on your PC; GitHub CI covers Lua math, archive packaging, and PowerShell syntax.
