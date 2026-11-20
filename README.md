# MeowMoon Aseprite Extensions

Public repository containing independent Aseprite extensions.

| Extension | Latest Release | Source |
| --- | --- | --- |
| Hue Shift | [v0.1.10](https://github.com/MeowMoonTK/meowmoon-aseprite-extension/releases/tag/hue-shift-v0.1.10) | [extensions/hue-shift](extensions/hue-shift) |

## Hue Shift

Generates color ramps with six single-color hue-shift styles, an HSV Color Map preview, and an Add to Palette action. **Multi-Anchor** uses 2–8 soft color references in fixed slots, with a Target color count and dark-to-light output.

Source retains the core ramp generator, preview/Color Map and Add to Palette action. The updater and all related commands, scripts and UI have been removed. Install packages manually through Aseprite Preferences > Extensions.

**v0.1.10** keeps Anchor slots stable during color edits and adds drag-to-reorder with a persistent selection highlight. Outside drops and interrupted drags cancel safely. The optional HSV Color Map remains available.

**Build policy:** GitHub Actions runs tests only. Package builds and GitHub Releases are made **only on explicit request**.

### Developer build (manual only)

```sh
lua tests/test_hue_shift.lua
lua tests/test_wheel.lua
lua tests/test_startup.lua
lua tests/test_multi_anchor.lua
python3 scripts/build_hue_shift.py
```

The build produces `dist/hue-shift-<version>.aseprite-extension`. Install through **Edit > Preferences > Extensions > Add Extension**.
