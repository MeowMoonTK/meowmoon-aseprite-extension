# MeowMoon Aseprite Extensions

Private monorepo for independent Aseprite extensions.

| Extension | Status | Source |
| --- | --- | --- |
| Hue Shift | v0.1.4 | [extensions/hue-shift](extensions/hue-shift) |

Each directory inside `extensions/` is an independent extension with its own Aseprite `package.json`, implementation, tests, and release version.

## Build and test

```sh
lua tests/test_hue_shift.lua
python3 scripts/build_hue_shift.py
```

The build produces `dist/hue-shift-0.1.0.aseprite-extension`. Install it via **Edit > Preferences > Extensions > Add Extension**, restart Aseprite, and open **File > Scripts > Hue Shift: Generate Ramp**.
