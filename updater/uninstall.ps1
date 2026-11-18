# Remove the Windows updater only; installed Aseprite extensions are untouched.
$taskName = 'MeowMoon Aseprite Extensions Updater'
Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
$destination = Join-Path $env:LOCALAPPDATA 'MeowMoon\AsepriteUpdater'
if (Test-Path -LiteralPath $destination) {
  Remove-Item -LiteralPath $destination -Recurse -Force
}
Write-Host 'Updater removed. Installed extensions were not changed.'
