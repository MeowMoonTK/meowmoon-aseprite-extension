# MeowMoon Aseprite Extensions

Public repository containing independent Aseprite extensions.

| Extension | Latest Release | Source |
| --- | --- | --- |
| Hue Shift | [v0.1.7](https://github.com/MeowMoonTK/meowmoon-aseprite-extension/releases/tag/hue-shift-v0.1.7) | [extensions/hue-shift](extensions/hue-shift) |

## Hue Shift

Generates color ramps with six hue-shift styles, an HSV Color Map preview, and an Add to Palette action.

Development source **v0.1.8** keeps only the core ramp generator, preview/Color Map and Add to Palette action. The updater and all related commands, scripts and UI have been removed. Install packages manually through Aseprite Preferences > Extensions.

The published [v0.1.7](https://github.com/MeowMoonTK/meowmoon-aseprite-extension/releases/tag/hue-shift-v0.1.7) is an older build and still contains its updater; no replacement Release has been published yet.

**Build policy:** GitHub Actions runs tests only. Package builds and GitHub Releases are made **only on explicit request**.

### Developer build (manual only)

```sh
lua tests/test_hue_shift.lua
lua tests/test_wheel.lua
lua tests/test_startup.lua
python3 scripts/build_hue_shift.py
```

The build produces `dist/hue-shift-<version>.aseprite-extension`. Install through **Edit > Preferences > Extensions > Add Extension**.
