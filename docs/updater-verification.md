# v0.1.8 updater rewrite

Published v0.1.7 assets are unchanged. This branch replaces the updater implementation for development v0.1.8.

## Runtime

Check Updates -> curl metadata -> Aseprite Version comparison -> curl checksum/package -> Windows certutil SHA-256 -> native Options installer -> package cleanup.

There is no Timer, PowerShell script, background worker, JSON result file or polling. Metadata/checksum are read through io.popen into memory. The only temporary runtime file is the downloaded .aseprite-extension, retained until Options returns. Aseprite owns archive/manifest/installation handling.

This is sequential, following the structure of JRiggles' MIT updater. It can block UI while waiting for network: 5-second connect timeout, 15-second metadata/checksum request limits, 60-second package limit. Native confirmation and script permission prompts remain part of Aseprite.

## Validation

- Lua regression covers latest stable selection, native Version/JSON compatibility when run in Aseprite batch, no-update, tool launch/read/exit failures, permissions, checksum failures, native installer error/cancel returns and plugin unload. No Timer is permitted in the fixtures.
- Panel regression covers quiet startup, separate Updates window, button disabled during synchronous calls and retained result after reopening.
- Windows curl downloaded the published v0.1.7 package; certutil SHA-256 matched the published checksum.
- Live batch metadata check reached GitHub but received HTTP 403 because this host's unauthenticated API quota was exhausted (remaining=0). It returned a controlled error rather than opening the GUI or crashing. A successful live metadata result is not claimed from that attempt.

The rewritten GUI/native-upgrade path has not yet been exercised end to end. Do not equate mocked installer success or CI with a real completed upgrade. No new Release is published by this work.

Reference: https://github.com/JRiggles/Aseprite-Extension-Updater/blob/main/extension/ase-extension-updater.lua
