# Download and verify Hue Shift. Never install or replace extension directories.
[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][string]$CurrentVersion,
  [Parameter(Mandatory=$true)][string]$ResultFile,
  [switch]$Worker
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
function Write-Result([string]$state,[string]$message,[string]$version,[string]$bundle) {
  $payload = @{ status=$state; message=$message; version=$version; packagePath=$bundle } | ConvertTo-Json -Compress
  if ($Worker) {
    # Only the supervisor publishes a result, after the worker has exited.
    Write-Output $payload
    return
  }
  $tempResult = $ResultFile + '.writing'
  [IO.File]::WriteAllText($tempResult,$payload,[System.Text.UTF8Encoding]::new($false))
  Move-Item -LiteralPath $tempResult -Destination $ResultFile -Force
  try {
    $logDir = Join-Path $env:LOCALAPPDATA 'MeowMoon\HueShift'
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    Add-Content -LiteralPath (Join-Path $logDir 'update.log') -Encoding UTF8 -Value ((Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + ' ' + $state + ': ' + $message)
  } catch {}
}
# The job is the standard PowerShell process boundary. Bound the entire network
# operation, not just individual HTTP requests (DNS/TLS can exceed their limits).
if (-not $Worker) {
  $job = $null
  $mutex = $null
  $ownsMutex = $false
  $delivered = $false
  $keepPackage = $false
  $pending = $ResultFile + '.pending'
  try {
    if (-not (Test-Path -LiteralPath $pending -PathType Leaf)) {
      throw 'Update request is no longer active.'
    }
    # Coordinate detached workers even across plugin reloads/Aseprite instances.
    $mutex = [Threading.Mutex]::new($false, 'Local\MeowMoon-HueShift-ReleaseCheck')
    try { $ownsMutex = $mutex.WaitOne(0) }
    catch [Threading.AbandonedMutexException] { $ownsMutex = $true }
    if (-not $ownsMutex) { throw 'Another Hue Shift Release worker is still running. Try again shortly.' }
    $job = Start-Job -ScriptBlock {
      param($script, $version, $result)
      & $script -CurrentVersion $version -ResultFile $result -Worker
    } -ArgumentList $PSCommandPath, $CurrentVersion, $ResultFile
    $completed = Wait-Job -Job $job -Timeout 120
    if ($null -eq $completed) { throw 'Release worker timed out after 120 seconds.' }
    if ($job.State -ne 'Completed') { throw ('Release worker failed: ' + $job.State) }
    $output = @(Receive-Job -Job $job -ErrorAction Stop)
    if ($output.Count -ne 1) { throw 'Release worker returned no unique result.' }
    $result = $output[0] | ConvertFrom-Json
    if ($result.status -notin @('update','up_to_date','error')) { throw 'Invalid worker status.' }
    if (Test-Path -LiteralPath $pending -PathType Leaf) {
      Write-Result $result.status $result.message $result.version $result.packagePath
      $delivered = $true
      $keepPackage = $result.status -eq 'update'
    }
    if ($result.status -eq 'error') { exit 1 }
    exit 0
  } catch {
    if ($null -ne $job) { Stop-Job -Job $job -ErrorAction SilentlyContinue }
    if (Test-Path -LiteralPath $pending -PathType Leaf) {
      Write-Result 'error' $_.Exception.Message '' ''
      $delivered = $true
    }
    exit 1
  } finally {
    # Terminate/reap before touching any download the worker might still write.
    if ($null -ne $job) {
      Stop-Job -Job $job -ErrorAction SilentlyContinue
      Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
    }
    if ($ownsMutex) { $mutex.ReleaseMutex() }
    if ($null -ne $mutex) { $mutex.Dispose() }
    Remove-Item -LiteralPath ($ResultFile + '.sha256') -Force -ErrorAction SilentlyContinue
    if (-not $keepPackage) {
      Remove-Item -LiteralPath ($ResultFile + '.aseprite-extension') -Force -ErrorAction SilentlyContinue
    }
    if (-not $delivered -or -not (Test-Path -LiteralPath $pending -PathType Leaf)) {
      # Lua cancelled/closed, including a race with result publication.
      foreach ($suffix in @('', '.writing', '.aseprite-extension')) {
        Remove-Item -LiteralPath ($ResultFile + $suffix) -Force -ErrorAction SilentlyContinue
      }
    }
  }
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
  $downloaded = $ResultFile + '.aseprite-extension'
  $checksumFile = $ResultFile + '.sha256'
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
