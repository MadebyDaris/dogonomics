param(
    [string]$OnnxRoot = 'C:\onnxruntime',
    [switch]$SyncVendor
)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
Set-Location $root

Write-Host ''
Write-Host 'Dogonomics Backend: ONNX Build' -ForegroundColor Cyan
Write-Host 'Working directory:' $root

$go = Get-Command go -ErrorAction SilentlyContinue
if (-not $go) {
    throw 'Go is not installed or not in PATH. Install from https://go.dev/dl/'
}

$onnxDll = Join-Path $OnnxRoot 'lib\onnxruntime.dll'
if (-not (Test-Path $onnxDll)) {
    throw "ONNX runtime not found at $onnxDll. Run runtimesetup.bat or scripts/onnx/install-runtime.ps1 first."
}

if ($SyncVendor) {
    Write-Host 'Syncing vendor directory...'
    go mod vendor
}

$env:CGO_ENABLED = '1'
$env:CGO_CFLAGS = "-I$OnnxRoot\include"
$env:CGO_LDFLAGS = "-L$OnnxRoot\lib -lonnxruntime"

Write-Host 'Building dogonomics-onnx.exe (ONNX enabled)...'
go build -tags onnx -o dogonomics-onnx.exe -ldflags='-s -w' ./cmd/dogonomics

Write-Host 'Build complete: dogonomics-onnx.exe' -ForegroundColor Green
