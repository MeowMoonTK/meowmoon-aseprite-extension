#!/usr/bin/env python3
"""Build an independent Aseprite extension archive from the monorepo."""
import json
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED

ROOT = Path(__file__).resolve().parents[1]
EXT = ROOT / "extensions" / "hue-shift"
manifest = json.loads((EXT / "package.json").read_text(encoding="utf-8"))
version = manifest["version"]
out = ROOT / "dist" / f"hue-shift-{version}.aseprite-extension"
out.parent.mkdir(parents=True, exist_ok=True)
paths = [
    "package.json",
    "main.lua",
    "src/color.lua",
    "src/ramp.lua",
    "src/palette.lua",
    "src/wheel.lua",
    "src/dialog.lua",
    "src/autoupdate.ps1",
    "src/update.lua",
]
with ZipFile(out, "w", compression=ZIP_DEFLATED) as archive:
    for path in paths:
        archive.write(EXT / path, arcname=path)
print(out)
