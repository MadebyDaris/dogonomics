$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
Set-Location $root

Write-Host ''
Write-Host 'Dogonomics Backend: Docker Compose Down' -ForegroundColor Cyan

& docker compose down -v
