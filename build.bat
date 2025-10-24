@echo off
REM ====================================================================
REM Build script for Dogonomics API (Standard - No ONNX)
REM ====================================================================
REM This builds a static binary WITHOUT BERT/sentiment analysis support.
REM Use build-onnx.bat if you need BERT sentiment features.
REM ====================================================================

echo.
echo ========================================
echo   Dogonomics API - Standard Build
echo ========================================
echo.

REM Check if Go is installed
where go >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo ERROR: Go is not installed or not in PATH
    echo Please install Go from https://go.dev/dl/
    pause
    exit /b 1
)

echo [1/3] Checking Go version...
go version
echo.

echo [2/3] Building application (no ONNX)...
echo Building: dogonomics.exe
echo.

REM Build without CGO (static binary, no ONNX)
set CGO_ENABLED=0
go build -o dogonomics.exe -ldflags="-s -w" .

if %ERRORLEVEL% neq 0 (
    echo.
    echo ERROR: Build failed!
    pause
    exit /b 1
)

echo.
echo [3/3] Build successful!
echo.
echo Output: dogonomics.exe
echo.
echo NOTE: BERT sentiment analysis is DISABLED in this build.
echo      To enable BERT, use build-onnx.bat instead.
echo.
echo To run: run.bat
echo.
pause