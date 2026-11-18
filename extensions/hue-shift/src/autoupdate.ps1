# Built-in Hue Shift updater for PUBLIC GitHub Releases.
# Called asynchronously by Aseprite on Windows startup. No gh, token, or scheduler.
[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$InstallDir)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Add-Type -AssemblyName System.IO.Compression.FileSystem
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

$repo = 'MeowMoonTK/meowmoon-aseprite-extension'
$packageName = 'meowmoon-hue-shift'
$tagPattern = '^hue-shift-v([0-9]+\.[0-9]+\.[0-9]+)$'
$stateDir = Join-Path $env:LOCALAPPDATA 'MeowMoon\HueShift'
New-Item -ItemType Directory -Path $stateDir -Force | Out-Null
$logFile = Join-Path $stateDir 'update.log'

function Log([string]$message) {
  Add-Content -LiteralPath $logFile -Encoding UTF8 -Value (
    (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + ' ' + $message
  )
}

function Assert-SafeArchive([string]$archivePath) {
  $zip = [IO.Compression.ZipFile]::OpenRead($archivePath)
  try {
    $size = [long]0
    $names = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    foreach ($entry in $zip.Entries) {
      $name = $entry.FullName
      $size += $entry.Length
      if ($size -gt 50MB) { throw 'Archive exceeds 50 MB uncompressed.' }
      if ($name.StartsWith('/') -or $name.Contains('\') -or
          $name -match '(^|/)\.\.?(/|$)' -or $name -match '^[A-Za-z]:' -or
          $name -notmatch '^[A-Za-z0-9_.-]+(/[A-Za-z0-9_.-]+)*/?$') {
        throw ('Unsafe path in archive: ' + $name)
      }
      if (-not $names.Add($name)) { throw ('Duplicate archive path: ' + $name) }
    }
  } finally {
    $zip.Dispose()
  }
}

$mutex = New-Object System.Threading.Mutex($false, 'Local\MeowMoonHueShiftUpdate')
$locked = $false
try {
  $locked = $mutex.WaitOne(0)
  if (-not $locked) { return }
  Log 'Checking public GitHub Releases.'

  $target = [IO.Path]::GetFullPath($InstallDir)
  $manifestPath = Join-Path $target 'package.json'
  if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    throw 'Extension package.json is missing.'
  }
  $installed = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
  if ($installed.name -ne $packageName) { throw 'Installed package identity does not match Hue Shift.' }
  $installedVersion = [version]$installed.version

  $headers = @{
    'Accept' = 'application/vnd.github+json'
    'User-Agent' = 'MeowMoon-HueShift-Updater'
  }
  $api = 'https://api.github.com/repos/' + $repo + '/releases?per_page=100'
  $releases = Invoke-RestMethod -Uri $api -Headers $headers -TimeoutSec 20 -ErrorAction Stop
  # Invoke-RestMethod already returns the JSON release array; wrapping its call
  # inside @() nests the array and hides tag_name from each release object.
  $latest = $null
  foreach ($release in $releases) {
    if ($release.draft -or $release.prerelease) { continue }
    if ($release.tag_name -notmatch $tagPattern) { continue }
    $candidateVersion = [version]$Matches[1]
    if ($null -eq $latest -or $candidateVersion -gt $latest.Version) {
      $latest = [pscustomobject]@{
        Tag = $release.tag_name
        Version = $candidateVersion
        Assets = @($release.assets)
      }
    }
  }
  if ($null -eq $latest) { Log 'No stable Hue Shift Release found.'; return }
  if ($latest.Version -le $installedVersion) {
    Log ('Current: v' + $installedVersion + '; latest: v' + $latest.Version)
    return
  }

  $version = $latest.Version.ToString()
  $archiveName = 'hue-shift-' + $version + '.aseprite-extension'
  $checksumName = 'hue-shift-' + $version + '.sha256'
  $available = @($latest.Assets | ForEach-Object { $_.name })
  if ($archiveName -notin $available -or $checksumName -notin $available) {
    throw ('Release ' + $latest.Tag + ' is missing required assets.')
  }

  Log ('Updating Hue Shift v' + $installedVersion + ' -> v' + $version)
  $parent = Split-Path -Parent $target
  $nonce = [guid]::NewGuid().ToString('N')
  $downloadDir = Join-Path ([IO.Path]::GetTempPath()) ('hue-shift-' + $nonce)
  $stage = Join-Path $parent ('.hue-shift-stage-' + $nonce)
  $backup = Join-Path $parent ('.hue-shift-backup-' + $nonce)
  $movedOld = $false
  New-Item -ItemType Directory -Path $downloadDir,$stage -Force | Out-Null
  try {
    $archivePath = Join-Path $downloadDir $archiveName
    $checksumPath = Join-Path $downloadDir $checksumName
    $baseUrl = 'https://github.com/' + $repo + '/releases/download/' + $latest.Tag + '/'
    Invoke-WebRequest -Uri ($baseUrl + $archiveName) -Headers $headers -UseBasicParsing -TimeoutSec 60 -OutFile $archivePath -ErrorAction Stop | Out-Null
    Invoke-WebRequest -Uri ($baseUrl + $checksumName) -Headers $headers -UseBasicParsing -TimeoutSec 30 -OutFile $checksumPath -ErrorAction Stop | Out-Null

    $checksumText = (Get-Content -LiteralPath $checksumPath -Raw).Trim()
    $checksumPattern = '^([a-fA-F0-9]{64})\s+\*?' + [regex]::Escape($archiveName) + '$'
    if ($checksumText -notmatch $checksumPattern) { throw 'Release SHA256 file is malformed.' }
    $expected = $Matches[1].ToLowerInvariant()
    $actual = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -ne $expected) { throw 'SHA256 mismatch; update cancelled.' }

    Assert-SafeArchive $archivePath
    [IO.Compression.ZipFile]::ExtractToDirectory($archivePath,$stage)
    $newManifestPath = Join-Path $stage 'package.json'
    if (-not (Test-Path -LiteralPath $newManifestPath -PathType Leaf)) {
      throw 'Release is missing package.json.'
    }
    $newManifest = Get-Content -LiteralPath $newManifestPath -Raw | ConvertFrom-Json
    if ($newManifest.name -ne $packageName -or [version]$newManifest.version -ne $latest.Version) {
      throw 'Release package name/version does not match its tag.'
    }
    foreach ($required in @('main.lua','src\autoupdate.ps1')) {
      if (-not (Test-Path -LiteralPath (Join-Path $stage $required) -PathType Leaf)) {
        throw ('Release is missing ' + $required)
      }
    }

    # Plugin Lua is already loaded. Changes become active on NEXT Aseprite startup.
    Move-Item -LiteralPath $target -Destination $backup -ErrorAction Stop
    $movedOld = $true
    try {
      Move-Item -LiteralPath $stage -Destination $target -ErrorAction Stop
    } catch {
      if ($movedOld -and -not (Test-Path -LiteralPath $target)) {
        Move-Item -LiteralPath $backup -Destination $target -ErrorAction Stop
        $movedOld = $false
      }
      throw
    }
    Log ('Installed Hue Shift v' + $version + '; restart Aseprite to activate it.')
    if ($movedOld) {
      try { Remove-Item -LiteralPath $backup -Recurse -Force -ErrorAction Stop }
      catch { Log ('Old-version backup could not be removed: ' + $_.Exception.Message) }
    }
  } finally {
    if (Test-Path -LiteralPath $stage) {
      Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue
    }
    if (Test-Path -LiteralPath $downloadDir) {
      Remove-Item -LiteralPath $downloadDir -Recurse -Force -ErrorAction SilentlyContinue
    }
  }
} catch {
  Log ('ERROR: ' + $_.Exception.Message)
  exit 1
} finally {
  if ($locked) { $mutex.ReleaseMutex() }
  $mutex.Dispose()
}
