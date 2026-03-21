@echo off
setlocal
echo Forwarding to scripts\dev.ps1 db-setup
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\dev.ps1" db-setup
exit /b %ERRORLEVEL%
