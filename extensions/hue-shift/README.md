# Hue Shift v0.1.3

Generate 3–16 colors with a Center Color, six Hue Shift styles (including Zigzag), Hue Strength and HSV Color Map. Append the ramp to the active Sprite palette without recoloring pixels.

## Built-in automatic updates (Windows)

**No Scheduled Task, Windows Startup shortcut, launcher, or separate updater installation.**

1. Install the v0.1.3 `.aseprite-extension` package once via **Edit → Preferences → Extensions → Add Extension**, then restart Aseprite.
2. Ensure GitHub CLI (`gh`) is installed and authenticated to your private GitHub repository: `gh auth login`.
3. The Aseprite plugin's `init(plugin)` launches `src/autoupdate.ps1` in the background on every Aseprite startup.
4. If a newer stable `hue-shift-vX.Y.Z` Release exists, the updater downloads the package and SHA256 checksum, verifies them and replaces its own installed files.
5. The new version loads **the next time Aseprite starts**; the already-running UI continues to use the old version.

Aseprite can request permission for `os.execute()` the first time; permit this trusted personal extension to run the update check. GitHub CLI authentication is the only private repository requirement. The plugin never stores your GitHub token.

Update log: `%LOCALAPPDATA%\MeowMoon\HueShift\update.log`. Network/authentication errors do not block the Color Ramp generator.

**Migration:** v0.1.2 and earlier do not have a built-in updater, so v0.1.3 must be installed once manually. If you previously activated the old, separate updater, you can remove it with `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\updater\uninstall.ps1` from the repository.

## Build locally

Run `python3 scripts/build_hue_shift.py` from the repository root.

## Verification

CI tests OKLCH generation, Lua startup command, archive contents and Windows PowerShell syntax. Startup behavior and self-replacement have not yet been tested inside a real running Aseprite instance.
