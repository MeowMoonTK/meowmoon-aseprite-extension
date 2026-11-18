# One-time setup for the private Aseprite auto-updater.
[CmdletBinding()]
param([switch]$NoSchedule, [switch]$StartupOnly, [switch]$SkipFirstCheck)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($NoSchedule -and $StartupOnly) { throw 'Choose either -NoSchedule or -StartupOnly.' }

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
function Install-StartupShortcut {
  $startupFolder = [Environment]::GetFolderPath('Startup')
  if (-not $startupFolder) { throw 'Windows Startup folder is unavailable.' }
  New-Item -ItemType Directory -Path $startupFolder -Force | Out-Null
  $shortcutPath = Join-Path $startupFolder 'MeowMoon Aseprite Extensions Updater.lnk'
  $shell = New-Object -ComObject WScript.Shell
  $shortcut = $shell.CreateShortcut($shortcutPath)
  $shortcut.TargetPath = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
  $shortcut.Arguments = '-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File "' + $updater + '"'
  $shortcut.WorkingDirectory = $destination
  $shortcut.Description = 'Check for private Aseprite extension updates at user sign-in'
  $shortcut.WindowStyle = 7
  $shortcut.Save()
  Write-Host 'Startup fallback installed: checks at Windows sign-in (not every day at noon).'
}

if ($StartupOnly) {
  Install-StartupShortcut
} elseif (-not $NoSchedule) {
  try {
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
  $oldShortcut = Join-Path ([Environment]::GetFolderPath('Startup')) 'MeowMoon Aseprite Extensions Updater.lnk'
  if (Test-Path -LiteralPath $oldShortcut) { Remove-Item -LiteralPath $oldShortcut -Force }
  Write-Host 'Scheduled checks on Windows login and every day at 12:00.'
  } catch {
    Write-Warning ('Task Scheduler access denied or unavailable: ' + $_.Exception.Message)
    Install-StartupShortcut
  }
}

if (-not $SkipFirstCheck) {
  & powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $updater
  if ($LASTEXITCODE -ne 0) { throw 'Initial update check failed. See updater.log.' }
}
Write-Host ('Updater installed at: ' + $destination)
Write-Host 'Log: %LOCALAPPDATA%\MeowMoon\AsepriteUpdater\update.log'
