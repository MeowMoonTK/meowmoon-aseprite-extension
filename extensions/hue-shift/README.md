# MeowMoon Hue Shift v0.1.8 (development)

Generate 3–16 colors with the chosen Center Color, six Hue Shift styles, independent Step Modes, Hue Strength, and HSV Color Map. **Add to Palette** appends without an arbitrary 256-slot limit. The panel shows the installed extension version.

This version contains only the ramp generator and palette controls. It makes no network requests, runs no external tools and creates no temporary update files. Install packages manually through Aseprite Preferences > Extensions.

## Center color placement for even ramps

For odd color counts, the original RGB stays in the single middle slot. For even color counts, it automatically selects between the two center slots. With **8 colors**, a source darker than neutral gray `#808080` is placed at **slot 4**, while one at least as bright as `#808080` is placed at **slot 5**.

Brightness is measured as the source color's **grayscale-equivalent sRGB value** (Rec.709 linear-light luminance, encoded back to neutral sRGB), rather than comparing OKLab L to `0.5` or averaging the R/G/B channels. This keeps vivid green and blue distinguishable in grayscale brightness. The selected anchor retains the exact source RGB; the preview's Anchor indicator follows its position.

## Step Mode (independent of Shift Style)

- **Balanced (default):** nearly equal measured **sRGB grayscale brightness** increments across dark and light sides, with adaptive headroom near black and white.
- **Full Range:** each side independently uses 80% of its available grayscale brightness range; produces wider extremes but less uniform increments.
- **Shadow Detail:** Balanced grayscale range, with more values near the darkest endpoint.
- **Highlight Detail:** Balanced grayscale range, with more values near the brightest endpoint.
- **Soft Ends:** Eased grayscale spacing near the anchor and both extremes, stronger differences in between.

Step Mode now controls the **grayscale value of each final RGB color** (0–255 Rec.709 luminance encoded as sRGB), rather than dividing OKLab L. Each color's Hue and intended Chroma still follow the original Shift Style. The generator searches for an OKLab L that produces the target gray after sRGB gamut mapping, reducing Chroma when necessary. The original RGB stays untouched at the anchor. Balanced prioritizes uniform grayscale increments over reaching the darkest and lightest possible endpoints; at 8-bit precision individual steps may differ by a fraction of a gray level.

## Build / release policy

Run `python3 scripts/build_hue_shift.py` only when a build is explicitly requested. GitHub Actions performs tests only and does not publish Releases.

## Verification

CI runs the color-ramp, HSV wheel and core startup/panel regression tests.
