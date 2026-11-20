# Fetch and verify only. Aseprite owns confirmation and installation.
[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][string]$CurrentVersion,
  [Parameter(Mandatory=$true)][string]$ResultFile
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
function Write-Result([string]$state,[string]$message,[string]$version,[string]$bundle) {
  # Lua creates the result before launch and deletes it on cancellation.
  # File.Replace is atomic and cannot recreate a deleted/cancelled request.
  if (-not (Test-Path -LiteralPath $ResultFile -PathType Leaf)) { return $false }
  $staging = $ResultFile + '.writing'
  $payload = @{status=$state; message=$message; version=$version; packagePath=$bundle} | ConvertTo-Json -Compress
  [IO.File]::WriteAllText($staging,$payload,[Text.UTF8Encoding]::new($false))
  try { [IO.File]::Replace($staging,$ResultFile,[System.Management.Automation.Language.NullString]::Value) }
  catch {
    if (-not (Test-Path -LiteralPath $ResultFile)) { return $false }
    throw
  }
  return $true
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
$client = $null
try {
  if ($CurrentVersion -notmatch '^[0-9]+\.[0-9]+\.[0-9]+$') { throw 'Invalid installed extension version.' }
  if (-not (Test-Path -LiteralPath (Split-Path -Parent $ResultFile) -PathType Container)) { throw 'Result directory does not exist.' }
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
  Add-Type -AssemblyName System.Net.Http
  $client = [Net.Http.HttpClient]::new()
  $client.Timeout = [TimeSpan]::FromSeconds(30)
  $client.MaxResponseContentBufferSize = 50MB
  $client.DefaultRequestHeaders.Add('Accept', 'application/vnd.github+json')
  $client.DefaultRequestHeaders.Add('User-Agent', 'MeowMoon-HueShift-Updater')
  $releaseBytes = $client.GetByteArrayAsync('https://api.github.com/repos/MeowMoonTK/meowmoon-aseprite-extension/releases?per_page=100').GetAwaiter().GetResult()
  $releases = [Text.Encoding]::UTF8.GetString($releaseBytes) | ConvertFrom-Json
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
    Write-Result 'up_to_date' ('Installed v' + $CurrentVersion + ' is current.') $CurrentVersion '' | Out-Null
    exit 0
  }
  $versionText = $latest.Version.ToString()
  $archiveName = 'hue-shift-' + $versionText + '.aseprite-extension'
  $checksumName = 'hue-shift-' + $versionText + '.sha256'
  $available = @($latest.Assets | ForEach-Object { $_.name })
  if ($archiveName -notin $available -or $checksumName -notin $available) {
    throw ('Release ' + $latest.Tag + ' lacks the package or SHA256 file.')
  }
  $downloaded = $ResultFile + '.aseprite-extension'
  $baseUrl = 'https://github.com/MeowMoonTK/meowmoon-aseprite-extension/releases/download/' + $latest.Tag + '/'
  $bytes = $client.GetByteArrayAsync($baseUrl + $archiveName).GetAwaiter().GetResult()
  [IO.File]::WriteAllBytes($downloaded, $bytes)
  $checksumBytes = $client.GetByteArrayAsync($baseUrl + $checksumName).GetAwaiter().GetResult()
  $checksumText = [Text.Encoding]::UTF8.GetString($checksumBytes).Trim()
  $checksumPattern = '^([a-fA-F0-9]{64})\s+\*?' + [regex]::Escape($archiveName) + '$'
  if ($checksumText -notmatch $checksumPattern) { throw 'Malformed SHA256 file.' }
  $expectedHash = $Matches[1].ToLowerInvariant()
  $actualHash = (Get-FileHash -LiteralPath $downloaded -Algorithm SHA256).Hash.ToLowerInvariant()
  if ($actualHash -ne $expectedHash) { throw 'SHA256 verification failed.' }
  Verify-Extension $downloaded $latest.Version
  if (Write-Result 'update' ('Verified Hue Shift v' + $versionText + '.') $versionText $downloaded) {
    $downloaded = $null # Lua retains this input until Options returns.
  }
  exit 0
} catch {
  Write-Result 'error' $_.Exception.Message '' '' | Out-Null
  exit 1
} finally {
  if ($null -ne $client) { $client.Dispose() }
  Remove-Item -LiteralPath ($ResultFile + '.writing') -Force -ErrorAction SilentlyContinue
  if ($downloaded -and (Test-Path -LiteralPath $downloaded)) {
    Remove-Item -LiteralPath $downloaded -Force -ErrorAction SilentlyContinue
  }
}
