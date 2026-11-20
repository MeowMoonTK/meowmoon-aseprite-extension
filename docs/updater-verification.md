# Updater lifecycle verification

Scope: v0.1.7 source based on b204f04. No version bump, package build or Release.

## Automated evidence (2026-11-20, Windows)

- Lua 5.4: existing 8,820 ramp scenarios, HSV wheel, startup/UI and new updater fault injection.
- Real Windows PowerShell 5.1: cross-process worker exclusion, timeout/termination, cancellation without late JSON, worker error cleanup and retaining verified input for native installation. Test workers write scratch bytes, not installable packages.
- Public Release check from installed version 0.1.5: downloaded existing v0.1.6 and verified SHA-256, ZIP safety and manifest identity/version. No installation.
- CI additionally checks syntax, native-install separation, already-ahead/invalid versions and the detached Windows launcher with spaced paths.

## Regression coverage

- Request write denial and Timer construction/start failure prevent worker launch.
- Shell denial/failure cleans requests. Result read denial (throw or nil/EACCES), read failure, malformed JSON and Lua timeout stop polling and retain the uncertain-completion lock.
- Package and lock persist during native dialogs, nested check attempts and reentrant plugin exit.
- JSON/package cleanup after native return, including false/nil/exception. No return establishes confirmed installation.
- Reject package paths outside the request; report cleanup denial.
- Terminal worker results permit a later check; stop cancels ownership and prohibits further checks from that instance.

## Live Aseprite gate: pending

Aseprite 1.3.18.6 is available on this host. An attempted isolated GUI launch did not expose the installer dialog, so it supplies no installer/permission evidence. No real upgrade or restart verification is claimed. CI does not satisfy this gate.

Before merging as fully integration-verified, use a disposable Aseprite profile:

1. Install an older version natively; record preferences and RGB/OKLCH/grayscale ramps.
2. Trigger this source updater using a verified existing newer Release. Source is 0.1.7 and public Release is 0.1.6, so normal startup correctly proposes no upgrade.
3. Decline shell/file permissions separately; verify error status and working ramp generation. Repeat with permissions accepted by the user.
4. Cancel native installation; verify old version, unconfirmed status, cleanup and a subsequent check.
5. Accept native installation; close Preferences, verify cleanup, restart and confirm new active version, preferences and ramps.
6. Interrupt networking and close Aseprite during a check; verify bounded worker exit and no late retained result/download.

Do not build or publish a package to satisfy this gate without an explicit user request. Acceptance/cancellation cannot be inferred from Options returning true or nil.
