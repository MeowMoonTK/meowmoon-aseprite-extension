# MeowMoon Hue Shift v0.1.8 (development)

Generate 3–16 colors with the chosen Center Color, six Hue Shift styles, independent Step Modes, Hue Strength, and HSV Color Map. **Add to Palette** appends without an arbitrary 256-slot limit. The panel shows the installed extension version.

## v0.1.8 panel work

Ramp settings and preview are grouped separately. The main panel keeps **Add to Palette** and **Close** as its action row; **Updates...** belongs to the version/header area and opens a compact modeless window with its own status and Check Updates button. Long status messages wrap in that window. The Color Map is available through **Show Color Map** and starts collapsed so the default panel fits smaller windows.

Published release: [v0.1.7](https://github.com/MeowMoonTK/meowmoon-aseprite-extension/releases/tag/hue-shift-v0.1.7). Version 0.1.8 is development source only.

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

1. Open **Updates...** near the version in the Hue Shift panel (or File > Scripts > Hue Shift: Updates), then click **Check Updates** in its separate window.
2. Sequential curl requests check stable public GitHub Releases and download a newer package and its checksum. Windows certutil verifies SHA-256; Aseprite validates the archive and manifest during installation.
3. Aseprite opens Preferences > Extensions and asks to replace the installed extension. Accept or cancel there.
4. Close Preferences. If accepted, restart Aseprite and check the version shown in the Hue Shift panel.

Only Aseprite's [native Options command](https://aseprite.org/api/command/Options) changes the installed extension. The updater never unpacks or replaces its installation directory. Returning from Options does not prove installation: the panel tells you to restart **if you accepted**.

The rewrite uses the same sequential shape as JRiggles' updater: call `curl`, wait for the response, compare with Aseprite's `Version` API, download, verify SHA-256 with Windows `certutil`, and invoke `app.command.Options`. There are no updater Timers, PowerShell helpers, detached workers, status JSON files, or polling callbacks.

Only one downloaded `.aseprite-extension` file is written to `app.fs.tempPath`. Release metadata and the small checksum response stay in memory. The package is retained until native Options returns, then removed. Aseprite owns archive/manifest validation and installation. Results and errors stay in the separate Updates window.

This deliberately sequential implementation can keep Aseprite waiting during network calls. Connection timeout is 5 seconds; metadata/checksum requests have 15-second limits and the package download has a 60-second limit. GitHub API refusals/rate limits are shown as errors and can be retried later. Opening the panel does not start requests.

Aseprite may ask for script file/execute permissions on the first manual check. Declining permissions must leave ramp generation usable. Results and errors stay in the Updates window, without extra alerts. The network calls run synchronously; reopening the window retains the most recent result. Temporary-file cleanup failures appear in status. Forced shutdown or denied deletion can leave temporary files for OS/user cleanup.

Releases v0.1.5/v0.1.6 contain the old self-updater. Install the first version containing this replacement through Preferences > Extensions > Add Extension once. They cannot reliably bootstrap the replacement themselves.

Design references: [Aseprite Extension Updater](https://github.com/JRiggles/Aseprite-Extension-Updater) (John Riggles, MIT) demonstrates download + native installation. [Verification evidence](../../docs/updater-verification.md) distinguishes automated checks from live GUI checks.

## Build / release policy

Run `python3 scripts/build_hue_shift.py` only when a build is explicitly requested. GitHub Actions performs tests only and does not publish Releases.

## Verification

Lua regression tests and Windows curl/certutil download/verification checks run in CI. Live Aseprite GUI execution and permissions must be checked on the target Windows machine.
