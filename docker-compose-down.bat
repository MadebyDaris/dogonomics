@echo off
REM ====================================================================
REM Docker Compose DOWN script
REM ====================================================================
REM Stops and removes all containers from the docker-compose stack.
REM ====================================================================

echo.
echo ========================================
echo   Dogonomics - Stop Full Stack
echo ========================================
echo.

docker compose down

if %ERRORLEVEL% neq 0 (
    echo.
    echo ERROR: Failed to stop services!
    pause
    exit /b 1
)

echo.
echo All services stopped and removed.
echo.
pause
