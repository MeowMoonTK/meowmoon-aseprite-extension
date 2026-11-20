# MeowMoon Aseprite Extensions

Public repository containing independent Aseprite extensions.

| Extension | Latest Release | Source |
| --- | --- | --- |
| Hue Shift | [v0.1.5](https://github.com/MeowMoonTK/meowmoon-aseprite-extension/releases/tag/hue-shift-v0.1.5) | [extensions/hue-shift](extensions/hue-shift) |

## Hue Shift

Generates color ramps with six hue-shift styles, an HSV Color Map preview, and an Add to Palette action.

**Windows updates:** Click **Check Updates** in the extension panel. It checks public GitHub Releases, downloads and verifies newer packages, then opens Aseprite's native upgrade confirmation. Restart after accepting. No checks run on startup. No GitHub CLI, authentication, scheduled tasks or external updater extension is needed.

**Build policy:** GitHub Actions runs tests only. Package builds and GitHub Releases are made **only on explicit request**.

### Developer build (manual only)

```sh
lua tests/test_hue_shift.lua
lua tests/test_wheel.lua
lua tests/test_startup.lua
python3 scripts/build_hue_shift.py
```

The build produces `dist/hue-shift-<version>.aseprite-extension`. Install through **Edit > Preferences > Extensions > Add Extension**.
