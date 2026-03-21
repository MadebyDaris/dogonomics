param(
    [string[]]$Profiles = @()
)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
Set-Location $root

Write-Host ''
Write-Host 'Dogonomics Backend: Docker Compose Up' -ForegroundColor Cyan

$args = @('compose')
foreach ($p in $Profiles) {
    $args += @('--profile', $p)
}
$args += @('up', '--build')

Write-Host ('docker ' + ($args -join ' '))
& docker @args
