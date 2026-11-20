# Exercise the real job supervisor with isolated fake worker bodies.
$ErrorActionPreference = 'Stop'
$source = Get-Content (Join-Path $PSScriptRoot '../extensions/hue-shift/src/check-release.ps1') -Raw
$supervisor = $source.Substring(0, $source.IndexOf('function Verify-Extension'))
$folder = Join-Path ([IO.Path]::GetTempPath()) ('Hue Shift Worker Test ' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $folder | Out-Null
function Assert($condition, $message) { if (-not $condition) { throw $message } }
try {
  foreach ($mode in @('timeout','cancel','error','update','busy')) {
    $script = Join-Path $folder ($mode + '.ps1')
    $status = Join-Path $folder ($mode + '.json')
    New-Item -ItemType File -Path ($status + '.pending') | Out-Null
    $body = @'
[IO.File]::WriteAllText($ResultFile + '.aseprite-extension', 'scratch bytes, not an installable package')
[IO.File]::WriteAllText($ResultFile + '.sha256', 'scratch')
[IO.File]::WriteAllText($ResultFile + '.workerpid', [string]$PID)
'@
    $head = $supervisor
    switch ($mode) {
      'timeout' {
        $head = $supervisor.Replace('Wait-Job -Job $job -Timeout 120','Wait-Job -Job $job -Timeout 2')
        $body += "`nStart-Sleep -Seconds 30`n"
      }
      'cancel' {
        $body += "`nRemove-Item -LiteralPath (`$ResultFile + '.pending')`nWrite-Result 'update' 'verified' '0.1.8' (`$ResultFile + '.aseprite-extension')`n"
      }
      'error' { $body += "`nWrite-Result 'error' 'synthetic failure' '' ''`n" }
      'busy' { $body += "`nthrow 'Contention test must never start a worker'`n" }
      'update' { $body += "`nWrite-Result 'update' 'verified' '0.1.8' (`$ResultFile + '.aseprite-extension')`n" }
    }
    [IO.File]::WriteAllText($script, $head + $body)
    $watch = [Diagnostics.Stopwatch]::StartNew()
    $heldMutex = $null
    if ($mode -eq 'busy') {
      $heldMutex = [Threading.Mutex]::new($false, 'Local\MeowMoon-HueShift-ReleaseCheck')
      Assert ($heldMutex.WaitOne(0)) 'Test must acquire worker mutex'
    }
    try {
      & powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $script -CurrentVersion '0.1.7' -ResultFile $status
    } finally {
      if ($null -ne $heldMutex) { $heldMutex.ReleaseMutex(); $heldMutex.Dispose() }
    }
    $watch.Stop()
    Assert (-not (Test-Path -LiteralPath ($status + '.sha256'))) "$mode checksum must be removed"
    if ($mode -eq 'cancel') {
      Assert (-not (Test-Path -LiteralPath $status)) 'Cancelled request must not publish late JSON'
    } else {
      $result = Get-Content -LiteralPath $status -Raw | ConvertFrom-Json
      $expected = if ($mode -eq 'update') { 'update' } else { 'error' }
      Assert ($result.status -eq $expected) "$mode returned wrong status: $($result | ConvertTo-Json -Compress)"
    }
    if ($mode -eq 'update') {
      Assert (Test-Path -LiteralPath ($status + '.aseprite-extension')) 'Verified input must remain for native installer'
    } else {
      Assert (-not (Test-Path -LiteralPath ($status + '.aseprite-extension'))) "$mode must remove incomplete package"
    }
    if ($mode -eq 'busy') {
      Assert ($result.message -match 'still running') 'Contending process must report existing worker'
      Assert (-not (Test-Path -LiteralPath ($status + '.workerpid'))) 'Contending process must not start a worker'
    }
    if (Test-Path -LiteralPath ($status + '.workerpid')) {
      $workerId = [int](Get-Content -LiteralPath ($status + '.workerpid'))
      Assert ($null -eq (Get-Process -Id $workerId -ErrorAction SilentlyContinue)) 'Supervisor must reap worker before returning'
    }
    if ($mode -eq 'error') { Assert ($result.message -eq 'synthetic failure') 'Must receive worker error, not supervisor launch failure' }
    if ($mode -eq 'timeout') {
      Assert ($result.message -match 'timed out') 'Must exercise actual worker timeout'
      Assert ($watch.Elapsed.TotalSeconds -lt 20) 'Worker was not terminated promptly'
    }
    Write-Host "OK: worker $mode"
  }
} finally {
  Get-ChildItem -LiteralPath $folder -File | Remove-Item -Force
  Remove-Item -LiteralPath $folder
}
$global:LASTEXITCODE = 0
