@echo off
setlocal enabledelayedexpansion

echo ======================================
echo    Dogonomics Windows Build Script
echo ======================================
echo.

REM Check if Go is installed
go version >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo ERROR: Go is not installed or not in PATH
    echo https://golang.org/dl/
    pause
    exit /b 1
)

REM Check if GCC is available
gcc --version >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo ERROR: GCC compiler not found
    echo Please install TDM-GCC from: https://jmeubank.github.io/tdm-gcc/
    pause
    exit /b 1
)

REM Check for ONNX Runtime
if not exist "C:\onnxruntime\lib\onnxruntime.dll" (
    echo ERROR: ONNX Runtime not found at C:\onnxruntime\
    echo.
    echo Please run setup_onnx.bat first to download and install ONNX Runtime
    echo Or manually download from: https://github.com/microsoft/onnxruntime/releases
    pause
    exit /b 1
)

echo Checking environment...
echo - Go version: 
go version
echo - GCC version:
gcc --version | findstr "gcc"
echo.

REM Set build environment
echo Setting up build environment...
set CGO_ENABLED=1
set CGO_CFLAGS=-IC:\onnxruntime\include
set CGO_LDFLAGS=-LC:\onnxruntime\lib -lonnxruntime
set PATH=C:\onnxruntime\lib;%PATH%

echo Environment variables set:
echo - CGO_ENABLED: %CGO_ENABLED%
echo - CGO_CFLAGS: %CGO_CFLAGS%
echo - CGO_LDFLAGS: %CGO_LDFLAGS%
echo.

REM Download Go modules
echo Downloading Go modules...
go mod tidy
if %ERRORLEVEL% neq 0 (
    echo ERROR: Failed to download Go modules
    pause
    exit /b 1
)

REM Build the application
echo Building Dogonomics...
echo This may take a few minutes on first build...
go build -v -x -o dogonomics.exe .

if %ERRORLEVEL% equ 0 (
    echo.
    echo ======================================
    echo          BUILD SUCCESSFUL!
    echo ======================================
    echo.
    echo The executable 'dogonomics.exe' has been created.
    echo.
    echo Next steps:
    echo 1. Create a .env file with your API keys (copy from .env.template)
    echo 2. Run: run.bat
    echo    Or: dogonomics.exe
    echo.
) else (
    echo.
    echo ======================================
    echo           BUILD FAILED!
    echo ======================================
    echo.
    echo Common solutions:
    echo 1. Make sure TDM-GCC or MinGW-w64 is installed and in PATH
    echo 2. Verify ONNX Runtime is installed at C:\onnxruntime\
    echo 3. Check that all environment variables are set correctly
    echo 4. Try running as Administrator
    echo.
    pause
    exit /b 1
)

echo Press any key to continue...
pause >nul