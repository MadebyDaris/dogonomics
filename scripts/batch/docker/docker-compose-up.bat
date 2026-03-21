@echo off
setlocal
echo Forwarding to scripts\docker\docker-compose-up.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\docker\docker-compose-up.ps1"
exit /b %ERRORLEVEL%
echo.
echo Opening Swagger UI in browser...
timeout /t 3 >nul
start http://localhost:8080/swagger/index.html
echo.
echo Press any key to view logs (Ctrl+C to exit logs)...
pause >nul
docker compose logs -f
