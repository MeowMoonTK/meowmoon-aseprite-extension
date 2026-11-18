# Hue Shift extension's private GitHub Release auto-update worker.
# Called by main.lua on each Aseprite launch; no Task Scheduler, no saved token.
[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][string]$InstallDir
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Add-Type -AssemblyName System.IO.Compression.FileSystem

$stateDir = Join-Path $env:LOCALAPPDATA 'MeowMoon\HueShift'
New-Item -ItemType Directory -Path $stateDir -Force | Out-Null
$logFile = Join-Path $stateDir 'update.log'

function Log([string]$message) {
  $line = ' ' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + ' ' + $message
  Add-Content -LiteralPath $logFile -Value $line -Encoding UTF8
  Write-Host $message
}

function Get-ExistingExtension([string]$root, [string]$packageName) {
  if (-not (Test-Path -LiteralPath $root)) { return $null }
  $matchesFound = @()
  foreach ($folder in @(Get-ChildItem -LiteralPath $root -Directory)) {
    $manifestPath = Join-Path $folder.FullName 'package.json'
    if (-not (Test-Path -LiteralPath $manifestPath)) { continue }
    try {
      $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
      if ($manifest.name -eq $packageName) {
        $matchesFound += [pscustomobject]@{
          Path = $folder.FullName
          Version = [version]$manifest.version
        }
      }
    } catch {
      Log ('Skipping malformed installed manifest: ' + $manifestPath)
    }
  }
  if ($matchesFound.Count -gt 1) {
    throw ('Multiple installations of ' + $packageName + ' found; resolve duplicates first.')
  }
  if ($matchesFound.Count -eq 1) { return $matchesFound[0] }
  return $null
}

function Get-LatestRelease([object[]]$releases, [string]$prefix) {
  $candidates = @()
  $regex = '^' + [regex]::Escape($prefix) + '([0-9]+\.[0-9]+\.[0-9]+)$'
  foreach ($release in $releases) {
    if ($release.isDraft -or $release.isPrerelease) { continue }
    if ($release.tagName -match $regex) {
      $candidates += [pscustomobject]@{
        Tag = $release.tagName
        Version = [version]$Matches[1]
      }
    }
  }
  return $candidates | Sort-Object -Property Version -Descending | Select-Object -First 1
}

function Assert-ArchiveSafe([string]$archivePath) {
  $archive = [IO.Compression.ZipFile]::OpenRead($archivePath)
  try {
    $totalBytes = [long]0
    foreach ($entry in $archive.Entries) {
      $name = $entry.FullName
      $totalBytes += $entry.Length
      if ($totalBytes -gt 50MB) { throw 'Extension archive exceeds 50 MB expanded size.' }
      if ($name.StartsWith('/') -or $name.Contains('\') -or
          $name -match '(^|/)\.\.?(/|$)' -or $name -match '^[A-Za-z]:') {
        throw ('Unsafe path in extension archive: ' + $name)
      }
      if (-not $name.EndsWith('/') -and
          $name -notmatch '^[A-Za-z0-9_.-]+(/[A-Za-z0-9_.-]+)*$') {
        throw ('Unexpected path in extension archive: ' + $name)
      }
    }
  } finally {
    $archive.Dispose()
  }
}

function Update-Extension([object]$extension, [object[]]$releases, [string]$root) {
  $latest = Get-LatestRelease $releases $extension.tagPrefix
  if ($null -eq $latest) {
    Log ('No release found for ' + $extension.id)
    return
  }
  if ($extension.packageName -notmatch '^[a-zA-Z0-9._-]+$') {
    throw 'Invalid extension package name.'
  }

  $manifestPath = Join-Path $InstallDir 'package.json'
  if (-not (Test-Path -LiteralPath $manifestPath)) { throw 'Installed manifest is missing.' }
  $installed = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
  if ($installed.name -ne $extension.packageName) { throw 'Installed extension identity mismatch.' }
  $existing = [pscustomobject]@{ Path=$InstallDir; Version=[version]$installed.version }
  $current = if ($existing) { $existing.Version } else { [version]'0.0.0' }
  if ($latest.Version -le $current) {
    Log ($extension.id + ' is current: ' + $current)
    return
  }

  Log ($extension.id + ': ' + $current + ' -> ' + $latest.Version)

  $versionString = $latest.Version.ToString()
  $asset = $extension.assetPrefix + $versionString + '.aseprite-extension'
  $checksumAsset = $extension.assetPrefix + $versionString + '.sha256'
  $tempDir = Join-Path ([IO.Path]::GetTempPath()) ('meowmoon-update-' + [guid]::NewGuid().ToString('N'))
  $target = $InstallDir
  $stage = Join-Path $root ('.stage-' + [guid]::NewGuid().ToString('N'))
  $backup = Join-Path $root ('.backup-' + [guid]::NewGuid().ToString('N'))
  $hasBackup = $false

  New-Item -ItemType Directory -Path $tempDir, $stage -Force | Out-Null
  try {
    & gh release download $latest.Tag --repo 'MeowMoonTK/meowmoon-aseprite-extension' --pattern $asset --pattern $checksumAsset --dir $tempDir
    if ($LASTEXITCODE -ne 0) { throw ('Download failed for ' + $latest.Tag) }
    $archivePath = Join-Path $tempDir $asset
    $checksumPath = Join-Path $tempDir $checksumAsset
    if (-not (Test-Path -LiteralPath $archivePath) -or -not (Test-Path -LiteralPath $checksumPath)) {
      throw 'Release must contain both extension archive and SHA256 checksum.'
    }

    $line = Get-Content -LiteralPath $checksumPath -Raw
    $match = [regex]::Match($line, '^\s*([a-fA-F0-9]{64})\s+')
    if (-not $match.Success) { throw 'Release checksum is malformed.' }
    $expected = $match.Groups[1].Value.ToLowerInvariant()
    $actual = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -ne $expected) { throw 'Extension checksum mismatch; refusing install.' }

    Assert-ArchiveSafe $archivePath
    [IO.Compression.ZipFile]::ExtractToDirectory($archivePath, $stage)
    $manifestPath = Join-Path $stage 'package.json'
    if (-not (Test-Path -LiteralPath $manifestPath)) { throw 'Missing package.json.' }
    $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    if ($manifest.name -ne $extension.packageName -or [version]$manifest.version -ne $latest.Version) {
      throw 'Extension package identity/version does not match the release.'
    }
    if (-not (Test-Path -LiteralPath (Join-Path $stage 'main.lua')) -or
        -not (Test-Path -LiteralPath (Join-Path $stage 'src\autoupdate.ps1'))) {
      throw 'Required extension source files are missing.'
    }

    if (Test-Path -LiteralPath $target) {
      Move-Item -LiteralPath $target -Destination $backup
      $hasBackup = $true
    }
    try {
      Move-Item -LiteralPath $stage -Destination $target
    } catch {
      if ($hasBackup) { Move-Item -LiteralPath $backup -Destination $target }
      throw
    }
    if ($hasBackup) {
      try { Remove-Item -LiteralPath $backup -Recurse -Force -ErrorAction Stop }
      catch { Log ('Old-version cleanup deferred: ' + $_.Exception.Message) }
    }
    Log ($extension.id + ' installed v' + $versionString + '; the new code loads on next Aseprite start.')
  } finally {
    if (Test-Path -LiteralPath $stage) { Remove-Item -LiteralPath $stage -Recurse -Force }
    if (Test-Path -LiteralPath $tempDir) { Remove-Item -LiteralPath $tempDir -Recurse -Force }
  }
}

$mutex = New-Object System.Threading.Mutex($false, 'Local\MeowMoonHueShiftUpdate')
$hasLock = $mutex.WaitOne(0)
if (-not $hasLock) { $mutex.Dispose(); exit 0 }
try {
  if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    throw 'GitHub CLI not found. Install it with: winget install --id GitHub.cli'
  }
  & gh auth status --hostname github.com *> $null
  if ($LASTEXITCODE -ne 0) { throw 'GitHub CLI is not authenticated. Run: gh auth login' }

  $extensionsRoot = Split-Path -Parent $InstallDir
  $config = [pscustomobject]@{
    id = 'hue-shift'
    packageName = 'meowmoon-hue-shift'
    tagPrefix = 'hue-shift-v'
    assetPrefix = 'hue-shift-'
  }
  $releaseText = (& gh release list --repo 'MeowMoonTK/meowmoon-aseprite-extension' --limit 100 --json tagName,isDraft,isPrerelease) -join [Environment]::NewLine
  if ($LASTEXITCODE -ne 0) { throw 'Unable to query private GitHub releases.' }
  $releases = @(ConvertFrom-Json -InputObject $releaseText)
  Update-Extension $config $releases $extensionsRoot
} catch {
  Log ('ERROR: ' + $_.Exception.Message)
} finally {
  $mutex.ReleaseMutex()
  $mutex.Dispose()
}
