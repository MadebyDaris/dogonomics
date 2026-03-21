$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
Set-Location $root

Write-Host ''
Write-Host 'Dogonomics Backend: Run Standard Binary' -ForegroundColor Cyan

if (-not (Test-Path '.env')) {
    Write-Warning '.env file not found. API keys may be missing.'
}

if (-not (Test-Path 'dogonomics.exe')) {
    throw 'dogonomics.exe not found. Run scripts/build/build.ps1 first.'
}

Write-Host 'Starting API at http://localhost:8080'
& .\dogonomics.exe
