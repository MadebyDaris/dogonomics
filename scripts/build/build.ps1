param(
    [switch]$VerboseOutput
)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
Set-Location $root

Write-Host ''
Write-Host 'Dogonomics Backend: Standard Build' -ForegroundColor Cyan
Write-Host 'Working directory:' $root

$go = Get-Command go -ErrorAction SilentlyContinue
if (-not $go) {
    throw 'Go is not installed or not in PATH. Install from https://go.dev/dl/'
}

if ($VerboseOutput) {
    go version
}

$env:CGO_ENABLED = '0'
Write-Host 'Building dogonomics.exe (ONNX disabled)...'
go build -o dogonomics.exe -ldflags='-s -w' ./cmd/dogonomics

Write-Host 'Build complete: dogonomics.exe' -ForegroundColor Green
