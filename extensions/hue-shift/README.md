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

## Native Aseprite update workflow (Windows, v0.1.7 source)

Hue Shift checks for stable GitHub Releases one second after Aseprite's UI initializes. Checking does not block the color editor. When a newer Release is available:

1. A small PowerShell helper fetches the Release archive and its SHA-256 file over HTTPS.
2. It validates the SHA-256, ZIP entries and extension identity/version, then writes a JSON status result to the Windows temporary directory.
3. Lua receives that result and calls Aseprite's native installer:
   \`app.command.Options{ installExtension = verifiedPackagePath }\`
4. **Aseprite asks you to confirm the upgrade**. Restart Aseprite to activate the new version.

**PowerShell no longer removes, renames, uninstalls or replaces extension folders.** Only Aseprite's native installer changes the installation. A successful download does not prove the user confirmed installation.

You can check manually using the **Check Updates** button in Hue Shift or **File > Scripts > Hue Shift: Check Updates**. This command also checks asynchronously and displays the result when finished. Already up-to-date installations stay quiet on startup.

### Permissions and diagnostics

On first use, Aseprite might ask for permission to execute PowerShell and read the temporary result file. **Give full trust to this script** / **Give Script Full Access** allows subsequent startup checks. Hue Shift's palette generator is usable even when these permissions are declined. Failed checks display diagnostics when invoked manually.

Detailed log: \`%LOCALAPPDATA%\MeowMoon\HueShift\update.log\`. No GitHub CLI, authentication, separate extension or scheduled task is needed. The feature currently supports Windows; background checks do not run on other operating systems.

### Migrating from older versions

Releases v0.1.5 and v0.1.6 contain the previous self-updater. If that updater cannot run on your computer, it **cannot bootstrap this replacement**. Install the first Release containing the native installer manually once using Aseprite Preferences > Extensions > Add Extension. After that, subsequent Releases can be proposed through Aseprite's installer.

### Design references

This implementation follows the native-install approach demonstrated by [Aseprite Extension Updater](https://github.com/JRiggles/Aseprite-Extension-Updater) (John Riggles, MIT). It does not copy that project's unmaintained networking logic or require its separate extension. [Aseprite's app.command API](https://aseprite.org/api/app_command) and [Timer API](https://aseprite.org/api/timer) are the platform sources. Installation remains user-confirmed rather than silent.

## Build / release policy

Run `python3 scripts/build_hue_shift.py` only when a build is explicitly requested. GitHub Actions performs tests only and does not publish Releases.

## Verification

Lua regression tests, Windows PowerShell syntax check, and an unauthenticated public Release download/install smoke test run in CI. Live Aseprite GUI execution and permissions must be checked on the target Windows machine.
