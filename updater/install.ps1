# One-time setup for the private Aseprite auto-updater.
[CmdletBinding()]
param([switch]$NoSchedule, [switch]$SkipFirstCheck)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
  throw 'Install GitHub CLI first: winget install --id GitHub.cli'
}
& gh auth status --hostname github.com *> $null
if ($LASTEXITCODE -ne 0) {
  throw 'Sign in to GitHub CLI first: gh auth login'
}

$destination = Join-Path $env:LOCALAPPDATA 'MeowMoon\AsepriteUpdater'
New-Item -ItemType Directory -Path $destination -Force | Out-Null
foreach ($name in @('update.ps1', 'extensions.json')) {
  $source = Join-Path $PSScriptRoot $name
  if (-not (Test-Path -LiteralPath $source)) { throw ('Missing updater file: ' + $source) }
  $target = Join-Path $destination $name
  if ([IO.Path]::GetFullPath($source) -ne [IO.Path]::GetFullPath($target)) {
    Copy-Item -LiteralPath $source -Destination $target -Force
  }
}

$updater = Join-Path $destination 'update.ps1'
if (-not $NoSchedule) {
  $taskName = 'MeowMoon Aseprite Extensions Updater'
  $arguments = '-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "' + $updater + '"'
  $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $arguments
  $triggers = @(
    (New-ScheduledTaskTrigger -AtLogOn),
    (New-ScheduledTaskTrigger -Daily -At '12:00')
  )
  $principal = New-ScheduledTaskPrincipal -UserId ([Security.Principal.WindowsIdentity]::GetCurrent().Name) -LogonType Interactive -RunLevel Limited
  $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Minutes 5)
  Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $triggers -Principal $principal -Settings $settings -Force | Out-Null
  Write-Host 'Scheduled checks on Windows login and every day at 12:00.'
}

if (-not $SkipFirstCheck) {
  & powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $updater
  if ($LASTEXITCODE -ne 0) { throw 'Initial update check failed. See updater.log.' }
}
Write-Host ('Updater installed at: ' + $destination)
Write-Host 'Log: %LOCALAPPDATA%\MeowMoon\AsepriteUpdater\update.log'
