# Test the real atomic publisher without network or installing an extension.
$ErrorActionPreference = 'Stop'
$source = Get-Content (Join-Path $PSScriptRoot '../extensions/hue-shift/src/check-release.ps1') -Raw
$tokens = $null
$errors = $null
$ast = [Management.Automation.Language.Parser]::ParseInput($source,[ref]$tokens,[ref]$errors)
if ($errors.Count) { throw ($errors | Out-String) }
$publisher = $ast.Find({param($node)
  $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Write-Result'
}, $true)
. ([scriptblock]::Create($publisher.Extent.Text))
$folder = Join-Path ([IO.Path]::GetTempPath()) ('Hue Shift Fetch Test ' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $folder | Out-Null
try {
  $ResultFile = Join-Path $folder 'status.json'
  Set-Content -LiteralPath $ResultFile -Encoding ascii -Value '{"status":"checking"}'
  if (-not (Write-Result 'up_to_date' 'Already current' '0.1.7' '')) { throw 'Publication failed' }
  $result = Get-Content -LiteralPath $ResultFile -Raw | ConvertFrom-Json
  if ($result.status -ne 'up_to_date') { throw 'Publication did not replace initial request' }
  if (Test-Path -LiteralPath ($ResultFile + '.writing')) { throw 'Publication left staging file' }
  Remove-Item -LiteralPath $ResultFile
  if (Write-Result 'update' 'Cancelled' '0.1.8' 'unused') { throw 'Cancelled request was published' }
  if (Test-Path -LiteralPath $ResultFile) { throw 'Cancelled request was recreated' }
  Write-Host 'OK: atomic result replacement and cancellation without late result'
} finally {
  Get-ChildItem -LiteralPath $folder -File | Remove-Item -Force
  Remove-Item -LiteralPath $folder
}
