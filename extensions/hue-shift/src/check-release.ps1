# Download and verify Hue Shift. Never install or replace extension directories.
[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][string]$CurrentVersion,
  [Parameter(Mandatory=$true)][string]$ResultFile
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
function Write-Result([string]$state,[string]$message,[string]$version,[string]$bundle) {
  $payload = @{ status=$state; message=$message; version=$version; packagePath=$bundle } | ConvertTo-Json -Compress
  $tempResult = $ResultFile + '.writing'
  [IO.File]::WriteAllText($tempResult,$payload,[System.Text.UTF8Encoding]::new($false))
  Move-Item -LiteralPath $tempResult -Destination $ResultFile -Force
  try {
    $logDir = Join-Path $env:LOCALAPPDATA 'MeowMoon\HueShift'
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    Add-Content -LiteralPath (Join-Path $logDir 'update.log') -Encoding UTF8 -Value ((Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + ' ' + $state + ': ' + $message)
  } catch {}
}
function Verify-Extension([string]$archivePath,[version]$expectedVersion) {
  $zip = [IO.Compression.ZipFile]::OpenRead($archivePath)
  try {
    $total = [long]0
    $names = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    $manifestEntry = $null
    foreach ($entry in $zip.Entries) {
      $name = $entry.FullName
      $total += $entry.Length
      if ($total -gt 50MB) { throw 'Package exceeds 50 MB uncompressed.' }
      if ($name.StartsWith('/') -or $name.Contains('\') -or $name -match '(^|/)\.\.?(/|$)' -or $name -match '^[A-Za-z]:' -or $name -notmatch '^[A-Za-z0-9_.-]+(/[A-Za-z0-9_.-]+)*/?$') {
        throw ('Unsafe package path: ' + $name)
      }
      if (-not $names.Add($name)) { throw ('Duplicate package entry: ' + $name) }
      if ($name -eq 'package.json') { $manifestEntry = $entry }
    }
    foreach ($required in @('package.json','main.lua')) {
      if (-not $names.Contains($required)) { throw ('Package missing ' + $required) }
    }
    $reader = New-Object IO.StreamReader($manifestEntry.Open())
    try { $manifest = $reader.ReadToEnd() | ConvertFrom-Json }
    finally { $reader.Dispose() }
    if ($manifest.name -ne 'meowmoon-hue-shift' -or [version]$manifest.version -ne $expectedVersion) {
      throw 'Package name or version does not match the Release.'
    }
  } finally {
    $zip.Dispose()
  }
}
$downloaded = $null
$checksumFile = $null
try {
  if ($CurrentVersion -notmatch '^[0-9]+\.[0-9]+\.[0-9]+$') { throw 'Invalid installed extension version.' }
  if (-not (Test-Path -LiteralPath (Split-Path -Parent $ResultFile) -PathType Container)) { throw 'Result directory does not exist.' }
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
  $headers = @{ 'Accept'='application/vnd.github+json'; 'User-Agent'='MeowMoon-HueShift-Updater' }
  $releases = Invoke-RestMethod -Uri 'https://api.github.com/repos/MeowMoonTK/meowmoon-aseprite-extension/releases?per_page=100' -Headers $headers -TimeoutSec 20 -ErrorAction Stop
  $latest = $null
  foreach ($release in $releases) {
    if ($release.draft -or $release.prerelease) { continue }
    if ($release.tag_name -notmatch '^hue-shift-v([0-9]+\.[0-9]+\.[0-9]+)$') { continue }
    $version = [version]$Matches[1]
    if ($null -eq $latest -or $version -gt $latest.Version) {
      $latest = [pscustomobject]@{ Tag=$release.tag_name; Version=$version; Assets=@($release.assets) }
    }
  }
  if ($null -eq $latest) { throw 'No stable Hue Shift Release found.' }
  if ($latest.Version -le [version]$CurrentVersion) {
    Write-Result 'up_to_date' ('Installed v' + $CurrentVersion + ' is current.') $CurrentVersion ''
    exit 0
  }
  $versionText = $latest.Version.ToString()
  $archiveName = 'hue-shift-' + $versionText + '.aseprite-extension'
  $checksumName = 'hue-shift-' + $versionText + '.sha256'
  $available = @($latest.Assets | ForEach-Object { $_.name })
  if ($archiveName -notin $available -or $checksumName -notin $available) {
    throw ('Release ' + $latest.Tag + ' lacks the package or SHA256 file.')
  }
  $destination = Split-Path -Parent $ResultFile
  $nonce = [guid]::NewGuid().ToString('N')
  $downloaded = Join-Path $destination ('hue-shift-' + $nonce + '.aseprite-extension')
  $checksumFile = Join-Path $destination ('hue-shift-' + $nonce + '.sha256')
  $baseUrl = 'https://github.com/MeowMoonTK/meowmoon-aseprite-extension/releases/download/' + $latest.Tag + '/'
  Invoke-WebRequest -Uri ($baseUrl + $archiveName) -Headers $headers -UseBasicParsing -TimeoutSec 60 -OutFile $downloaded -ErrorAction Stop | Out-Null
  Invoke-WebRequest -Uri ($baseUrl + $checksumName) -Headers $headers -UseBasicParsing -TimeoutSec 30 -OutFile $checksumFile -ErrorAction Stop | Out-Null
  $checksumText = (Get-Content -LiteralPath $checksumFile -Raw).Trim()
  $checksumPattern = '^([a-fA-F0-9]{64})\s+\*?' + [regex]::Escape($archiveName) + '$'
  if ($checksumText -notmatch $checksumPattern) { throw 'Malformed SHA256 file.' }
  $expectedHash = $Matches[1].ToLowerInvariant()
  $actualHash = (Get-FileHash -LiteralPath $downloaded -Algorithm SHA256).Hash.ToLowerInvariant()
  if ($actualHash -ne $expectedHash) { throw 'SHA256 verification failed.' }
  Verify-Extension $downloaded $latest.Version
  Write-Result 'update' ('Verified Hue Shift v' + $versionText + '.') $versionText $downloaded
  # Keep the verified package until the Aseprite installer consumes it.
  $downloaded = $null
  exit 0
} catch {
  Write-Result 'error' $_.Exception.Message '' ''
  exit 1
} finally {
  if ($checksumFile -and (Test-Path -LiteralPath $checksumFile)) {
    Remove-Item -LiteralPath $checksumFile -Force -ErrorAction SilentlyContinue
  }
  if ($downloaded -and (Test-Path -LiteralPath $downloaded)) {
    Remove-Item -LiteralPath $downloaded -Force -ErrorAction SilentlyContinue
  }
}
