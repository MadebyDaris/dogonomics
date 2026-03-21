@echo off
setlocal
echo Forwarding to scripts\dev.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\dev.ps1" %*
exit /b %ERRORLEVEL%
