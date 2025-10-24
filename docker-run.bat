@echo off
REM ====================================================================
REM Docker run script for Dogonomics API
REM ====================================================================
REM Runs a single Docker container (standard or ONNX).
REM For full stack with Prometheus/Grafana, use docker-compose-up.bat
REM ====================================================================

setlocal enabledelayedexpansion

echo.
echo ========================================
echo   Dogonomics - Docker Run
echo ========================================
echo.

REM Check if .env file exists
if not exist ".env" (
    echo WARNING: .env file not found!
    echo.
    echo Docker will run without API keys.
    echo Create a .env file with:
    echo   FINNHUB_API_KEY=your_key_here
    echo   EODHD_API_KEY=your_key_here
    echo.
    set /p continue="Continue anyway? (y/n): "
    if /i not "!continue!"=="y" (
        exit /b 0
    )
)

REM Prompt for image type
echo Select image to run:
echo.
echo   1. Standard (dogonomics:latest)
echo   2. ONNX (dogonomics:onnx)
echo.
set /p choice="Enter your choice (1/2): "

if "%choice%"=="1" (
    set IMAGE=dogonomics:latest
    set MODE=Standard
) else if "%choice%"=="2" (
    set IMAGE=dogonomics:onnx
    set MODE=ONNX
) else (
    echo Invalid choice. Exiting.
    pause
    exit /b 1
)

echo.
echo ========================================
echo   Starting Container
echo ========================================
echo.
echo Image: %IMAGE%
echo Mode: %MODE%
echo Port: 8080
echo.

REM Check if image exists
docker image inspect %IMAGE% >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo ERROR: Image %IMAGE% not found!
    echo.
    echo Please run: docker-build.bat
    echo.
    pause
    exit /b 1
)

REM Stop and remove existing container if running
docker stop dogonomics >nul 2>&1
docker rm dogonomics >nul 2>&1

REM Run the container
echo Starting container...
echo.
docker run -d ^
    --name dogonomics ^
    -p 8080:8080 ^
    --env-file .env ^
    %IMAGE%

if %ERRORLEVEL% neq 0 (
    echo.
    echo ERROR: Failed to start container!
    pause
    exit /b 1
)

echo.
echo ========================================
echo   Container Started Successfully
echo ========================================
echo.
echo Container name: dogonomics
echo.
echo Access points:
echo   - API: http://localhost:8080
echo   - Swagger UI: http://localhost:8080/swagger/index.html
echo   - Metrics: http://localhost:8080/metrics
echo.
echo View logs: docker logs -f dogonomics
echo Stop: docker stop dogonomics
echo.
echo Opening Swagger UI in browser...
timeout /t 3 >nul
start http://localhost:8080/swagger/index.html
echo.
pause
