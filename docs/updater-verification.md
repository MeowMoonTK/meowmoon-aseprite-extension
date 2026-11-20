# Manual update verification

Source version remains 0.1.7. Local test packages are allowed; no tag or GitHub Release is created.

## Behavior

No startup update timer, shell, download or permission prompt. The panel's Check Updates button starts one check, disables itself, downloads/verifies newer Releases, then calls Aseprite's Options installer. Native confirmation is retained. Close Preferences and restart if accepted. Cancellation is never reported as installation success.

## Automated checks

- Lua: 8,820 ramp scenarios, HSV wheel, quiet startup, the actual panel button, status/button recovery, updater error paths, timeout/retry, package lifetime and reentrant plugin exit.
- Windows PowerShell: syntax, atomic replacement of the pre-created JSON request, cancellation without recreating a deleted request.
- Public GitHub Releases: download + SHA-256/ZIP/manifest validation, already-current and invalid versions, real detached launcher with a spaced path.

The fetcher uses one PowerShell process and standard .NET HttpClient (30 seconds for each complete response). The earlier supervisor/job/mutex design has been removed.

## Live Aseprite evidence

On Windows with Aseprite 1.3.18.6:

- Built source v0.1.7 locally and installed it in an isolated profile using native Options.
- Restarted that profile. No Hue Shift startup check/permission prompt occurred.
- Replaced the first test build with the final v0.1.7 package through native confirmation; opened the installed panel with version v0.1.7.
- Enabled Aseprite's built-in dialog scrollbars after observing bottom controls clipped in a short window. The actual Check Updates button is reachable and starts a check, disabling itself.
- Compared all nine package entries against both source and native-installed files: exact matches.
- The user granted Aseprite's initial script permission. The first live check exposed that Aseprite JSON objects are `userdata`, whereas the mocks returned tables. Fixed object acceptance and ran tests/test_update.lua with Aseprite's real JSON encoder/decoder via `--batch --script`; all scenarios pass.
- Built/reinstalled the corrected v0.1.7 package through native confirmation. Clicking the real panel button reached public GitHub Releases and displayed `Installed v0.1.7 is current.` After dismissing the alert, the button is enabled and no `meowmoon-update-*` files remain in Aseprite's actual Windows temp folder.
- Final source/package/native-installed entries match exactly after the JSON fix.

The public Release is 0.1.6, older than installed source 0.1.7. A real public check should report up to date; a newer-version automatic handoff cannot be claimed from that response. Download/verification and installer handoff have automated coverage; full newer-version upgrade/cancel and plugin-preference retention remain separate integration cases.

Permission dialogs must be handled by the user. No Aseprite script security bypass is used.
