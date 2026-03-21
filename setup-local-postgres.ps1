$ErrorActionPreference = 'Stop'
Write-Host 'Forwarding to scripts/dev.ps1 db-setup'
& "$PSScriptRoot\scripts\dev.ps1" db-setup
