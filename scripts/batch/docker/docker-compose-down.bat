@echo off
setlocal
echo Forwarding to scripts\docker\docker-compose-down.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\docker\docker-compose-down.ps1"
exit /b %ERRORLEVEL%
