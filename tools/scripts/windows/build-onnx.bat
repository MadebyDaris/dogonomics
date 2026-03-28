@echo off
REM ====================================================================
REM Build script for Dogonomics API (ONNX-enabled with BERT)
REM ====================================================================
REM This builds the API with BERT sentiment analysis support.
REM Requires ONNX Runtime installed at C:\onnxruntime\
REM ====================================================================

echo.
echo ========================================
echo   Dogonomics API - ONNX Build
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

echo [1/5] Checking Go version...
go version
echo.

echo [2/5] Checking ONNX Runtime installation...
if not exist "C:\onnxruntime\lib\onnxruntime.dll" (
    echo.
    echo ERROR: ONNX Runtime not found at C:\onnxruntime\
    echo.
    echo Please run: runtimesetup.bat
    echo Or manually install ONNX Runtime to C:\onnxruntime\
    echo.
    pause
    exit /b 1
)
echo ONNX Runtime found: C:\onnxruntime\
echo.

echo [3/5] Syncing vendor directory...
go mod vendor
if %ERRORLEVEL% neq 0 (
    echo WARNING: Failed to sync vendor directory
)
echo.

echo [4/5] Setting up CGO environment for ONNX...
set CGO_ENABLED=1
set CGO_CFLAGS=-IC:\onnxruntime\include
set CGO_LDFLAGS=-LC:\onnxruntime\lib -lonnxruntime
echo CGO_ENABLED=%CGO_ENABLED%
echo CGO_CFLAGS=%CGO_CFLAGS%
echo CGO_LDFLAGS=%CGO_LDFLAGS%
echo.

echo [5/5] Building application with ONNX support...
echo Building: dogonomics-onnx.exe
echo.

go build -tags onnx -o dogonomics-onnx.exe -ldflags="-s -w" .

if %ERRORLEVEL% neq 0 (
    echo.
    echo ERROR: Build failed!
    echo.
    echo Common issues:
    echo - ONNX Runtime not installed: run runtimesetup.bat
    echo - Missing C compiler: install TDM-GCC from https://jmeubank.github.io/tdm-gcc/
    echo - Version mismatch: run setup-onnx-env.bat to fix
    echo.
    echo Quick fix:
    echo   1. Run: setup-onnx-env.bat
    echo   2. Install TDM-GCC if needed
    echo   3. Run this script again
    echo.
    pause
    exit /b 1
)

echo.
echo ========================================
echo   Build successful!
echo ========================================
echo.
echo Output: dogonomics-onnx.exe
echo.
echo BERT sentiment analysis is ENABLED.
echo.
echo To run: run-onnx.bat
echo.
pause
