@echo off
REM ====================================================================
REM Run script for Dogonomics API (Standard - No ONNX)
REM ====================================================================
REM Runs the standard build without BERT sentiment analysis.
REM Use run-onnx.bat if you built with ONNX support.
REM ====================================================================

echo.
echo ========================================
echo   Dogonomics API - Starting Server
echo ========================================
echo.

REM Check if .env file exists
if not exist ".env" (
    echo WARNING: .env file not found!
    echo.
    echo Please create a .env file with:
    echo   FINNHUB_API_KEY=your_key_here
    echo   EODHD_API_KEY=your_key_here
    echo.
    pause
)

REM Check if binary exists
if not exist "dogonomics.exe" (
    echo ERROR: dogonomics.exe not found!
    echo.
    echo Please run: build.bat
    echo.
    pause
    exit /b 1
)

echo Starting Dogonomics API...
echo.
echo Server will be available at:
echo   - API: http://localhost:8080
echo   - Swagger UI: http://localhost:8080/swagger/index.html
echo   - Metrics: http://localhost:8080/metrics
echo.
echo Press Ctrl+C to stop the server.
echo.
echo ========================================
echo.

dogonomics.exe