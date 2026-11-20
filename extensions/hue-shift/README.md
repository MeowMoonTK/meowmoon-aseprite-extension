# MeowMoon Hue Shift v0.1.7 (source)

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

## Updates from the panel (Windows)

Hue Shift does not check for updates when Aseprite starts or when the panel opens.

1. Click **Check Updates** in the Hue Shift panel (or use File > Scripts > Hue Shift: Check Updates).
2. One background PowerShell process checks stable public GitHub Releases. If newer, it downloads the package and SHA-256 file and verifies the checksum, ZIP entries and extension identity/version.
3. Aseprite opens Preferences > Extensions and asks to replace the installed extension. Accept or cancel there.
4. Close Preferences. If accepted, restart Aseprite and check the version shown in the Hue Shift panel.

Only Aseprite's [native Options command](https://aseprite.org/api/command/Options) changes the installed extension. The updater never unpacks or replaces its installation directory. Returning from Options does not prove installation: the panel tells you to restart **if you accepted**.

The button is disabled during a check/installer. Three HTTP requests use .NET HttpClient's 30-second full-response timeout; Lua stops polling after 120 seconds. Errors end the check and leave color generation available. The package is retained until the native command returns, including plugin unload during an upgrade; then the request/package are removed. Removing the request also prevents late results after cancellation. No supervisor, child job, scheduled task, or separate updater extension is used.

Aseprite may ask for script file/execute permissions on the first manual check. Declining permissions must leave ramp generation usable. Check errors appear in the panel and an alert; temporary-file cleanup failures appear in status. Forced shutdown or denied deletion can leave temporary files for OS/user cleanup.

Releases v0.1.5/v0.1.6 contain the old self-updater. Install the first version containing this replacement through Preferences > Extensions > Add Extension once. They cannot reliably bootstrap the replacement themselves.

Design references: [Aseprite Extension Updater](https://github.com/JRiggles/Aseprite-Extension-Updater) (John Riggles, MIT) demonstrates download + native installation. [Verification evidence](../../docs/updater-verification.md) distinguishes automated checks from live GUI checks.

## Build / release policy

Run `python3 scripts/build_hue_shift.py` only when a build is explicitly requested. GitHub Actions performs tests only and does not publish Releases.

## Verification

Lua regression tests, Windows PowerShell syntax check, and an unauthenticated public Release download/verification test run in CI. Live Aseprite GUI execution and permissions must be checked on the target Windows machine.
