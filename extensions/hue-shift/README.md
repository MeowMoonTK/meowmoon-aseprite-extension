# MeowMoon Hue Shift v0.1.6 (source)

Generate 3–16 colors with the chosen Center Color, six Hue Shift styles, independent Step Modes, Hue Strength, and HSV Color Map. **Add to Palette** appends without an arbitrary 256-slot limit. The panel shows the installed extension version.

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

## Update check at Aseprite startup (Windows)

1. Install a package containing this new updater (v0.1.5) once through **Edit > Preferences > Extensions > Add Extension**.
2. On every Windows Aseprite startup, Hue Shift checks the public Releases of [MeowMoonTK/meowmoon-aseprite-extension](https://github.com/MeowMoonTK/meowmoon-aseprite-extension) over HTTPS.
3. If a newer stable `hue-shift-vX.Y.Z` tag is published, it downloads the matching `.aseprite-extension` and `.sha256` files, verifies the checksum and extension manifest, and installs the package.
4. Restart Aseprite to activate the new version. Aseprite keeps using the already-loaded version during the current session.

**No GitHub CLI, token, login, Task Scheduler, Windows Startup task, or launcher.** PowerShell 5.1 is included in Windows.

Aseprite may ask permission to use `os.execute` on the first run. Allow this trusted extension so it can launch the check. Internet or GitHub errors never interrupt ramp generation. Diagnostic log: `%LOCALAPPDATA%\MeowMoon\HueShift\update.log`.

**Migration:** Versions 0.1.3 and 0.1.4 were published with a GitHub CLI-dependent updater. If `gh` is unavailable, they cannot automatically bootstrap the new HTTPS updater. Install [v0.1.5](https://github.com/MeowMoonTK/meowmoon-aseprite-extension/releases/tag/hue-shift-v0.1.5) manually once; subsequent releases will be checked automatically.

## Build / release policy

Run `python3 scripts/build_hue_shift.py` only when a build is explicitly requested. GitHub Actions performs tests only and does not publish Releases.

## Verification

Lua regression tests, Windows PowerShell syntax check, and an unauthenticated public Release download/install smoke test run in CI. Live Aseprite GUI execution and permissions must be checked on the target Windows machine.
