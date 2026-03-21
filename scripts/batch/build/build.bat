@echo off
setlocal
echo Forwarding to scripts\build\build.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\build\build.ps1"
exit /b %ERRORLEVEL%