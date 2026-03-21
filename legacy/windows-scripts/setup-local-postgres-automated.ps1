$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

Write-Host 'Delegating to setup-local-postgres-automated.bat' -ForegroundColor Cyan
cmd /c .\setup-local-postgres-automated.bat
exit $LASTEXITCODE
