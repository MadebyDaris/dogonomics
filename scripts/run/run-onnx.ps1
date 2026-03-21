param(
    [string]$OnnxRoot = 'C:\onnxruntime'
)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
Set-Location $root

Write-Host ''
Write-Host 'Dogonomics Backend: Run ONNX Binary' -ForegroundColor Cyan

if (-not (Test-Path '.env')) {
    Write-Warning '.env file not found. API keys may be missing.'
}

if (-not (Test-Path 'dogonomics-onnx.exe')) {
    throw 'dogonomics-onnx.exe not found. Run scripts/build/build-onnx.ps1 first.'
}

$onnxLib = Join-Path $OnnxRoot 'lib'
if (-not (Test-Path (Join-Path $onnxLib 'onnxruntime.dll'))) {
    Write-Warning "ONNX DLL not found in $onnxLib."
}

$env:PATH = "$env:PATH;$onnxLib"
Write-Host 'Starting API with ONNX at http://localhost:8080'
& .\dogonomics-onnx.exe
