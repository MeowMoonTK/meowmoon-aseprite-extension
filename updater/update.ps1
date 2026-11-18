# MeowMoon private Aseprite extension updater (Windows PowerShell 5.1+).
# Runs non-interactively from Task Scheduler; never stores GitHub credentials.
[CmdletBinding()]
param(
  [switch]$CheckOnly,
  [string]$Repository = 'MeowMoonTK/meowmoon-aseprite-extension',
  [string]$ConfigPath = (Join-Path $PSScriptRoot 'extensions.json'),
  [string]$AsepriteUserFolder = ''
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Add-Type -AssemblyName System.IO.Compression.FileSystem

$stateDir = Join-Path $env:LOCALAPPDATA 'MeowMoon\AsepriteUpdater'
New-Item -ItemType Directory -Path $stateDir -Force | Out-Null
$logFile = Join-Path $stateDir 'update.log'

function Log([string]$message) {
  $line = ' ' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + ' ' + $message
  Add-Content -LiteralPath $logFile -Value $line -Encoding UTF8
  Write-Output $message
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

  $existing = Get-ExistingExtension $root $extension.packageName
  $current = if ($existing) { $existing.Version } else { [version]'0.0.0' }
  if ($latest.Version -le $current) {
    Log ($extension.id + ' is current: ' + $current)
    return
  }

  Log ($extension.id + ': ' + $current + ' -> ' + $latest.Version)
  if ($CheckOnly) { return }

  # Deliberately defer updates while Aseprite is running.
  if (@(Get-Process -Name 'Aseprite', 'AsepriteTrial' -ErrorAction SilentlyContinue).Count -gt 0) {
    Log 'Aseprite is running; postponed until next scheduled check.'
    return
  }

  $versionString = $latest.Version.ToString()
  $asset = $extension.assetPrefix + $versionString + '.aseprite-extension'
  $checksumAsset = $extension.assetPrefix + $versionString + '.sha256'
  $tempDir = Join-Path ([IO.Path]::GetTempPath()) ('meowmoon-update-' + [guid]::NewGuid().ToString('N'))
  $target = if ($existing) { $existing.Path } else { Join-Path $root $extension.packageName }
  $stage = Join-Path $root ('.stage-' + [guid]::NewGuid().ToString('N'))
  $backup = Join-Path $root ('.backup-' + [guid]::NewGuid().ToString('N'))
  $hasBackup = $false

  New-Item -ItemType Directory -Path $tempDir, $stage -Force | Out-Null
  try {
    & gh release download $latest.Tag --repo $Repository --pattern $asset --pattern $checksumAsset --dir $tempDir
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
    if (-not (Test-Path -LiteralPath (Join-Path $stage 'main.lua'))) {
      throw 'Missing main.lua in extension.'
    }

    # Avoid race with the user launching Aseprite during download.
    if (@(Get-Process -Name 'Aseprite', 'AsepriteTrial' -ErrorAction SilentlyContinue).Count -gt 0) {
      Log 'Aseprite launched during download; postponed.'
      return
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
    if ($hasBackup) { Remove-Item -LiteralPath $backup -Recurse -Force }
    Log ($extension.id + ' installed: v' + $versionString + '. Restart Aseprite to load it.')
  } finally {
    if (Test-Path -LiteralPath $stage) { Remove-Item -LiteralPath $stage -Recurse -Force }
    if (Test-Path -LiteralPath $tempDir) { Remove-Item -LiteralPath $tempDir -Recurse -Force }
  }
}

try {
  if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    throw 'GitHub CLI not found. Install it with: winget install --id GitHub.cli'
  }
  & gh auth status --hostname github.com *> $null
  if ($LASTEXITCODE -ne 0) { throw 'GitHub CLI is not authenticated. Run: gh auth login' }

  if (-not $AsepriteUserFolder) {
    $AsepriteUserFolder = if ($env:ASEPRITE_USER_FOLDER) {
      $env:ASEPRITE_USER_FOLDER
    } else {
      Join-Path $env:APPDATA 'Aseprite'
    }
  }
  $extensionsRoot = Join-Path $AsepriteUserFolder 'extensions'
  if (-not (Test-Path -LiteralPath $ConfigPath)) { throw 'Missing extensions.json.' }

  $config = @(Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json)
  $releaseText = (& gh release list --repo $Repository --limit 100 --json tagName,isDraft,isPrerelease) -join [Environment]::NewLine
  if ($LASTEXITCODE -ne 0) { throw 'Unable to query private GitHub releases.' }
  $releases = @(ConvertFrom-Json -InputObject $releaseText)

  New-Item -ItemType Directory -Path $extensionsRoot -Force | Out-Null
  foreach ($extension in $config) {
    Update-Extension $extension $releases $extensionsRoot
  }
} catch {
  Log ('ERROR: ' + $_.Exception.Message)
  exit 1
}
