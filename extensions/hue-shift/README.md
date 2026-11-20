# MeowMoon Hue Shift v0.1.9

Generate 3–16 colors with the chosen Center Color, six Hue Shift styles, independent Step Modes, Hue Strength, and HSV Color Map. **Add to Palette** appends without an arbitrary 256-slot limit. The panel shows the installed extension version.

## Multi-Anchor

Select **Mode > Multi-Anchor** to generate a ramp from **2–8 color references**. Reference slots stay in their input order: editing a color never reorders the swatches or changes the selected slot, even when it matches another reference. Click a reference swatch to select it, then use its color button to edit it. **Add Anchor** appends the current foreground color and selects the new slot; **Remove Anchor** removes the selected reference, down to a minimum of two. Adding/removing references redistributes the remaining slots evenly across Target.

**Target** is the total output count (reference count through 16). Reference slots are evenly distributed across the ramp; when intervals cannot divide evenly, their lengths differ by at most one color. The first and last references guide the dark and light ends. References are soft constraints: output Hue, Chroma and Lightness may all differ from their input colors. There is no center color, Shift Style, Hue Strength, Step Mode or easing in this mode.

The generator fits a smoothed, unwrapped OKLCH hue/chroma path in the supplied reference order; it does not sort by input brightness. Neutral references borrow nearby chromatic hue instead of introducing an arbitrary hue. Final sRGB grayscale brightness increases uniformly across a useful tonal range, with gamut compression and reduced chroma near the ends, even if a bright reference occupies the dark-end slot. Extra references guide the path but do not force every hue reversal into the result; contradictory references can still produce bends, so inspect the preview/Color Map.

The **Show HSV map** checkbox expands the optional Color Map. Reference markers indicate their fitted output slots, not exact copies of the reference RGB. Preview edits do not change the sprite; **Add to Palette** appends the current result in one undoable transaction.

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
