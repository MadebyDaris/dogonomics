@echo off
REM ====================================================================
REM Docker Compose script for Dogonomics Full Stack
REM ====================================================================
REM Starts the complete stack:
REM   - Dogonomics API
REM   - Prometheus (metrics collection)
REM   - Grafana (dashboards)
REM ====================================================================

setlocal enabledelayedexpansion

echo.
echo ========================================
echo   Dogonomics - Full Stack
echo ========================================
echo.

REM Check if .env file exists
if not exist ".env" (
    echo WARNING: .env file not found!
    echo.
    echo The API will run without API keys.
    echo Create a .env file with:
    echo   FINNHUB_API_KEY=your_key_here
    echo   EODHD_API_KEY=your_key_here
    echo.
    set /p continue="Continue anyway? (y/n): "
    if /i not "!continue!"=="y" (
        exit /b 0
    )
)

REM Check if docker-compose.yml exists
if not exist "docker-compose.yml" (
    echo ERROR: docker-compose.yml not found!
    pause
    exit /b 1
)

echo Select mode:
echo.
echo   1. Standard (No BERT sentiment)
echo   2. ONNX (With BERT sentiment)
echo.
set /p choice="Enter your choice (1/2): "

if "%choice%"=="1" (
    set BUILD_MODE=standard
    echo.
    echo Starting full stack with standard build...
) else if "%choice%"=="2" (
    set BUILD_MODE=onnx
    echo.
    echo Starting full stack with ONNX build...
    echo.
    echo NOTE: First-time ONNX build may take several minutes.
) else (
    echo Invalid choice. Exiting.
    pause
    exit /b 1
)

echo.
echo ========================================
echo   Starting Services
echo ========================================
echo.
echo Services:
echo   - dogonomics (API)
echo   - prometheus (Metrics)
echo   - grafana (Dashboards)
echo.

REM Start services
if "%BUILD_MODE%"=="onnx" (
    REM For ONNX, override the build to use Dockerfile.onnx
    docker compose build --build-arg DOCKERFILE=Dockerfile.onnx dogonomics
    if %ERRORLEVEL% neq 0 (
        echo ERROR: Failed to build ONNX image!
        pause
        exit /b 1
    )
)

docker compose up -d

if %ERRORLEVEL% neq 0 (
    echo.
    echo ERROR: Failed to start services!
    pause
    exit /b 1
)

echo.
echo ========================================
echo   Services Started Successfully
echo ========================================
echo.
echo Access points:
echo.
echo   API:
echo     - Swagger UI: http://localhost:8080/swagger/index.html
echo     - API Docs: http://localhost:8080/swagger/doc.json
echo     - Metrics: http://localhost:8080/metrics
echo     - Health: http://localhost:8080/health
echo.
echo   Prometheus:
echo     - Web UI: http://localhost:9090
echo     - Targets: http://localhost:9090/targets
echo.
echo   Grafana:
echo     - Web UI: http://localhost:3000
echo     - Username: admin
echo     - Password: admin
echo.
echo Commands:
echo   View logs: docker compose logs -f
echo   Stop all: docker compose down
echo   Restart: docker compose restart
echo.
echo Opening Swagger UI in browser...
timeout /t 3 >nul
start http://localhost:8080/swagger/index.html
echo.
echo Press any key to view logs (Ctrl+C to exit logs)...
pause >nul
docker compose logs -f
