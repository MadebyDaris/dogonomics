$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
Set-Location $root

Write-Host ''
Write-Host 'Dogonomics Backend: Install ONNX Runtime' -ForegroundColor Cyan
Write-Host 'Delegating to legacy/windows-scripts/runtimesetup.bat'

if (-not (Test-Path '.\legacy\windows-scripts\runtimesetup.bat')) {
    throw 'legacy/windows-scripts/runtimesetup.bat not found.'
}

cmd /c .\legacy\windows-scripts\runtimesetup.bat
