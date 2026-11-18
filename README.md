# MeowMoon Aseprite Extensions

Public repository containing independent Aseprite extensions.

| Extension | Latest Release | Source |
| --- | --- | --- |
| Hue Shift | [v0.1.5](https://github.com/MeowMoonTK/meowmoon-aseprite-extension/releases/tag/hue-shift-v0.1.5) | [extensions/hue-shift](extensions/hue-shift) |

## Hue Shift

Generates color ramps with six hue-shift styles, an HSV Color Map preview, and an Add to Palette action.

**Windows auto-update:** The installed extension checks public GitHub Releases during Aseprite startup. It uses Windows PowerShell and HTTPS without authentication, GitHub CLI, Scheduled Tasks, or external updater installations. New versions become active the next time Aseprite opens.

**Build policy:** GitHub Actions runs tests only. Package builds and GitHub Releases are made **only on explicit request**.

### Developer build (manual only)

```sh
lua tests/test_hue_shift.lua
lua tests/test_wheel.lua
lua tests/test_startup.lua
python3 scripts/build_hue_shift.py
```

The build produces `dist/hue-shift-<version>.aseprite-extension`. Install through **Edit > Preferences > Extensions > Add Extension**.
