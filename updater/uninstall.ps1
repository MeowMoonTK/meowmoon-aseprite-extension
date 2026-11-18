# Remove the Windows updater only; installed Aseprite extensions are untouched.
$taskName = 'MeowMoon Aseprite Extensions Updater'
try {
  Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction Stop
} catch {
  Write-Verbose ('Task Scheduler cleanup skipped: ' + $_.Exception.Message)
}
$startupFolder = [Environment]::GetFolderPath('Startup')
if ($startupFolder) {
  $shortcut = Join-Path $startupFolder ($taskName + '.lnk')
  if (Test-Path -LiteralPath $shortcut) { Remove-Item -LiteralPath $shortcut -Force }
}
$destination = Join-Path $env:LOCALAPPDATA 'MeowMoon\AsepriteUpdater'
if (Test-Path -LiteralPath $destination) {
  Remove-Item -LiteralPath $destination -Recurse -Force
}
Write-Host 'Updater removed. Installed extensions were not changed.'
