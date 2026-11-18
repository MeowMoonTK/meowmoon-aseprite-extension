# Private extension auto-updater (Windows)

A separate, opt-in Windows auto-updater for the private `MeowMoonTK/meowmoon-aseprite-extension` GitHub repository.

**Requirements:** Windows PowerShell 5.1+, Aseprite, [GitHub CLI](https://cli.github.com/) installed and authenticated with access to the private repo.

## One-time installation

1. Install GitHub CLI: `winget install --id GitHub.cli`
2. Authenticate: `gh auth login`
3. Clone this repository, or download and unzip the `updater/` folder.
4. In PowerShell, run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\updater\install.ps1
```

The installer copies `update.ps1` and `extensions.json` into `%LOCALAPPDATA%\MeowMoon\AsepriteUpdater`. It first attempts Task Scheduler (sign-in and daily 12:00). When registration fails with Access Denied / 0x80070005, it automatically installs a **per-user Startup shortcut** instead (checks at Windows sign-in only; no administrator rights required). The initial check still runs immediately when Aseprite is closed.

To force Startup mode, run `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\updater\install.ps1 -StartupOnly`. For manual-only installation use `-NoSchedule`.

The updater installs/replaces the extension under `%APPDATA%\Aseprite\extensions`. If Aseprite is open, it postpones installation to a future scheduled run; restart Aseprite after an update.

## Operations

Run manually:
```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:LOCALAPPDATA\MeowMoon\AsepriteUpdater\update.ps1"
```

Check versions without installing:
```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:LOCALAPPDATA\MeowMoon\AsepriteUpdater\update.ps1" -CheckOnly
```

Log: `%LOCALAPPDATA%\MeowMoon\AsepriteUpdater\update.log`.

Uninstall automatic updater, including any Startup shortcut (does not uninstall extensions):
```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\updater\uninstall.ps1
```

## Design

- Credentials are managed by `gh auth`. The updater **does not store a token** or make your repository public.
- Every extension has a manifest entry in `extensions.json` with a dedicated release-tag prefix, package name, and asset prefix.
- Selects highest stable semver release matching the extension, not the repository's latest release.
- Requires release assets `hue-shift-X.Y.Z.aseprite-extension` and `hue-shift-X.Y.Z.sha256`; checks SHA256 and embedded manifest.
- Refuses suspicious archive paths, leaves user-installed non-matching extensions untouched, and rolls back if replacement fails.
- Existing UI settings, if added in the future, must live **outside** the extension installation directory so package updates cannot overwrite them.
- No update while Aseprite is running, and no silent Lua/plugin execution outside Aseprite.
- Custom Aseprite user data locations are supported with the `ASEPRITE_USER_FOLDER` environment variable or `-AsepriteUserFolder` when running manually.

## Packaging / releases

When Hue Shift's version changes and the feature branch is merged into `main`, GitHub Actions builds the archive, computes SHA256, and creates a private Release tagged `hue-shift-vX.Y.Z`. Releases do not consume GitHub Actions artifact-upload quota.

**Known limitations:** The background updater relies on a Windows task or per-user Startup shortcut and authenticated GitHub CLI, so it cannot run if those credentials expire, if Task Scheduler is blocked, or if Windows is logged out. Task Scheduler checks at sign-in and noon; Startup fallback checks only at sign-in. Neither monitors Aseprite launches. The initial Windows setup and updating must be verified on your own PC.
