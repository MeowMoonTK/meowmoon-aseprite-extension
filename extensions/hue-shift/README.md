# MeowMoon Hue Shift v0.1.6 (source)

Generate 3–16 colors with the chosen Center Color, six Hue Shift styles, independent Step Modes, Hue Strength, and HSV Color Map. **Add to Palette** appends without an arbitrary 256-slot limit. The panel shows the installed extension version.

## Step Mode (independent of Shift Style)

- **Balanced (default):** equal OKLab Lightness spacing on both sides for ordinary center colors; adaptively preserves usable range near black and white.
- **Full Range:** original independent shadow/highlight ranges, useful when stronger extremes are wanted.
- **Shadow Detail:** Balanced endpoints, but places more intermediate shades near the darkest endpoint.
- **Highlight Detail:** Balanced endpoints, but places more shades near the brightest endpoint.
- **Soft Ends:** Balanced endpoints with eased spacing near the center and both extremes, stronger differences in between.

Step Mode adjusts **only Lightness (OKLab L)**. Hue and Chroma progression do not change when switching Step Modes; Shift Style controls hue direction. With a fixed-position center color, Balanced equalizes brightness increments by reducing the available tonal range on the side with more headroom instead of preserving both extreme endpoints.

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
