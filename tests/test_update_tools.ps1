# CI-only check of the same curl/certutil tools used by Lua. Not packaged.
$ErrorActionPreference='Stop'
$folder=Join-Path ([IO.Path]::GetTempPath()) ('Hue Shift Curl Test '+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $folder | Out-Null
try {
  # Fixed published fixture: package checks do not consume the GitHub API quota.
  $version='0.1.7'
  $tag='hue-shift-v'+$version
  $name='hue-shift-'+$version+'.aseprite-extension'
  $base='https://github.com/MeowMoonTK/meowmoon-aseprite-extension/releases/download/'+$tag+'/'
  $checksum=& curl.exe -q --fail --location --silent --show-error --connect-timeout 5 --max-time 15 --max-filesize 1024 ($base+'hue-shift-'+$version+'.sha256')
  if ($LASTEXITCODE -ne 0) { throw 'Checksum download failed' }
  if ($checksum -notmatch ('^([a-fA-F0-9]{64})\s+\*?'+[regex]::Escape($name)+'\s*$')) { throw 'Invalid checksum file' }
  $expected=$Matches[1].ToLowerInvariant()
  $package=Join-Path $folder $name
  & curl.exe -q --fail --location --silent --show-error --connect-timeout 5 --max-time 60 --max-filesize 52428800 --output $package ($base+$name)
  if ($LASTEXITCODE -ne 0) { throw 'Package download failed' }
  $hashOutput=& certutil.exe -hashfile $package SHA256
  if ($LASTEXITCODE -ne 0) { throw 'certutil failed' }
  $actual=($hashOutput | Where-Object { $_ -match '^[a-fA-F0-9]{64}$' }).Trim().ToLowerInvariant()
  if ($actual -ne $expected) { throw 'Package hash mismatch' }
  Write-Host ('OK: curl downloaded v'+$version+'; certutil SHA-256 matches')
} finally {
  Get-ChildItem -LiteralPath $folder -File | Remove-Item -Force
  Remove-Item -LiteralPath $folder
}
