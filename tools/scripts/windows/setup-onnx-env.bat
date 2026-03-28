@echo off
REM ====================================================================
REM Setup ONNX Environment - Fix version mismatch and install compiler
REM ====================================================================

echo.
echo ========================================
echo   ONNX Environment Setup
echo ========================================
echo.

REM Step 1: Check ONNX Runtime version
echo [1/5] Checking ONNX Runtime installation...
if not exist "C:\onnxruntime\VERSION_NUMBER" (
    echo ERROR: ONNX Runtime not found at C:\onnxruntime\
    echo Please run: runtimesetup.bat
    pause
    exit /b 1
)

set /p ONNX_VERSION=<C:\onnxruntime\VERSION_NUMBER
echo Found ONNX Runtime version: %ONNX_VERSION%
echo.

REM Step 2: Downgrade Go library to match ONNX Runtime 1.17.1
echo [2/5] Updating Go module to match ONNX Runtime version...
echo Running: go get github.com/yalue/onnxruntime_go@v1.17.0
go get github.com/yalue/onnxruntime_go@v1.17.0

if %ERRORLEVEL% neq 0 (
    echo ERROR: Failed to update Go module
    pause
    exit /b 1
)

echo Running: go mod tidy
go mod tidy
echo.

REM Step 3: Check for GCC compiler
echo [3/5] Checking for C compiler (required for CGO)...
where gcc >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo.
    echo WARNING: GCC compiler not found!
    echo.
    echo You need a C compiler for CGO. Options:
    echo 1. TDM-GCC (recommended): https://jmeubank.github.io/tdm-gcc/
    echo 2. MinGW-w64: https://www.mingw-w64.org/
    echo.
    echo After installing, add it to your PATH and run this script again.
    echo.
    set /p continue="Do you want to continue anyway? (y/n): "
    if /i not "!continue!"=="y" (
        pause
        exit /b 1
    )
) else (
    gcc --version
    echo GCC found!
)
echo.

REM Step 4: Verify ONNX Runtime files
echo [4/5] Verifying ONNX Runtime installation...
if not exist "C:\onnxruntime\lib\onnxruntime.dll" (
    echo ERROR: onnxruntime.dll not found
    pause
    exit /b 1
)
if not exist "C:\onnxruntime\include\onnxruntime_c_api.h" (
    echo ERROR: Header files not found
    pause
    exit /b 1
)
echo All required files found!
echo.

REM Step 5: Test build
echo [5/5] Testing ONNX build...
echo.
set CGO_ENABLED=1
set CGO_CFLAGS=-IC:\onnxruntime\include
set CGO_LDFLAGS=-LC:\onnxruntime\lib -lonnxruntime

echo Building test...
go build -tags onnx -o test-onnx.exe . >build-test.log 2>&1

if %ERRORLEVEL% neq 0 (
    echo.
    echo ERROR: Build test failed!
    echo.
    echo Check build-test.log for details
    type build-test.log
    echo.
    pause
    exit /b 1
)

echo Build test successful!
del test-onnx.exe
del build-test.log
echo.

echo ========================================
echo   Setup Complete!
echo ========================================
echo.
echo ONNX Runtime version: %ONNX_VERSION%
echo Go library version: v1.17.0 (matched)
echo.
echo You can now run: build-onnx.bat
echo.
pause
