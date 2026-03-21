@echo off
setlocal
echo Forwarding to scripts\run\run.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\run\run.ps1"
exit /b %ERRORLEVEL%