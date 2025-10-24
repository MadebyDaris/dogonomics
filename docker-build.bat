@echo off
REM ====================================================================
REM Docker build script for Dogonomics API
REM ====================================================================
REM Builds Docker images for both standard and ONNX-enabled versions.
REM ====================================================================

setlocal enabledelayedexpansion

echo.
echo ========================================
echo   Dogonomics - Docker Build
echo ========================================
echo.

REM Check if Docker is available
where docker >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo ERROR: Docker is not installed or not in PATH
    echo Please install Docker Desktop from https://www.docker.com/products/docker-desktop
    pause
    exit /b 1
)

REM Check Docker daemon
docker info >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo ERROR: Docker daemon is not running
    echo Please start Docker Desktop
    pause
    exit /b 1
)

echo Docker is running.
echo.

REM Prompt user for build type
echo Select build type:
echo.
echo   1. Standard build (No ONNX, faster, smaller image)
echo   2. ONNX build (With BERT sentiment, larger image)
echo   3. Both (Build both images)
echo.
set /p choice="Enter your choice (1/2/3): "

if "%choice%"=="1" goto :build_standard
if "%choice%"=="2" goto :build_onnx
if "%choice%"=="3" goto :build_both
echo Invalid choice. Exiting.
pause
exit /b 1

:build_standard
echo.
echo ========================================
echo   Building Standard Image
echo ========================================
echo.
echo Image: dogonomics:latest
echo Dockerfile: Dockerfile
echo.
docker build -t dogonomics:latest .
if %ERRORLEVEL% neq 0 (
    echo.
    echo ERROR: Standard build failed!
    pause
    exit /b 1
)
echo.
echo Standard build complete: dogonomics:latest
echo.
goto :end

:build_onnx
echo.
echo ========================================
echo   Building ONNX Image
echo ========================================
echo.
echo Image: dogonomics:onnx
echo Dockerfile: Dockerfile.onnx
echo.
echo NOTE: This build may take several minutes.
echo.
docker build -f Dockerfile.onnx -t dogonomics:onnx .
if %ERRORLEVEL% neq 0 (
    echo.
    echo ERROR: ONNX build failed!
    pause
    exit /b 1
)
echo.
echo ONNX build complete: dogonomics:onnx
echo.
goto :end

:build_both
echo.
echo ========================================
echo   Building Both Images
echo ========================================
echo.

echo [1/2] Building standard image...
docker build -t dogonomics:latest .
if %ERRORLEVEL% neq 0 (
    echo ERROR: Standard build failed!
    pause
    exit /b 1
)
echo Standard build complete.
echo.

echo [2/2] Building ONNX image...
docker build -f Dockerfile.onnx -t dogonomics:onnx .
if %ERRORLEVEL% neq 0 (
    echo ERROR: ONNX build failed!
    pause
    exit /b 1
)
echo ONNX build complete.
echo.

:end
echo ========================================
echo   Build Summary
echo ========================================
echo.
docker images | findstr "dogonomics"
echo.
echo To run containers:
echo   Standard: docker-run.bat
echo   Full stack: docker-compose-up.bat
echo.
pause
