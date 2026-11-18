# Hue Shift v0.1.0

A single-purpose Color Ramp generator for Aseprite. This extension is intended for private use.

## Controls

- **Center Color**: Pick any RGB color; the original RGB bytes remain exactly the same in the ramp.
- **Colors**: 3 to 16 colors, default 7. Even counts keep the anchor in the *left* middle cell.
- **Shift Style**:
  - Monochromatic (no Hue change)
  - Warm Light / Cool Shadow (shadow toward 255 degrees, light toward 75 degrees)
  - Cool Light / Warm Shadow (shadow toward 25 degrees, light toward 215 degrees)
  - Clockwise (progressively increasing Hue)
  - Counterclockwise (progressively decreasing Hue)
  - Zigzag (alternating Hue direction per step from the anchor)
- **Strength**: 0–100% Hue variation. Lightness still changes at 0%.

The preview does not modify a Sprite. **Add to Palette** appends the whole ramp to the active Sprite's palette in a single undoable transaction. No existing palette entry or pixel is changed.

## Requirements

- Aseprite **1.3 or newer** for canvas preview and Lua plugins.
- An open Sprite to append colors. The preview works without a Sprite.
- One palette per Sprite; the extension stops safely for multiple frame palettes.
- Maximum 256 palette entries (a conservative limit for both RGB and Indexed mode).
- Hue calculation assumes sRGB and uses OKLCH with chroma reduction for out-of-gamut colors. It does not convert custom document color profiles.

## Installation

Build with `python3 scripts/build_hue_shift.py` from the repository root.
Install the produced `.aseprite-extension` from **Edit > Preferences > Extensions > Add Extension** and restart Aseprite.

Run **File > Scripts > Hue Shift: Generate Ramp**.

## Known limitations

- Fully black/white center colors cannot produce a symmetrical visible ramp: there is no room for darker/lighter shades on one side.
- Gray center colors have zero chroma, so the Hue Shift styles appear monochromatic.
- A full 256-color palette cannot accept more colors without changing/removing existing entries; v0.1 refuses instead of overwriting.
- In RGB mode, appending palette entries does not recolor pixels already painted.
- Live testing inside the Aseprite desktop UI is still required; automated tests cover color generation and palette-writing logic with mocks.
