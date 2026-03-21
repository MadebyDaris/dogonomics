@echo off
setlocal
echo Forwarding to scripts\docker\docker-compose-up.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\docker\docker-compose-up.ps1"
exit /b %ERRORLEVEL%
