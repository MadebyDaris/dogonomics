@echo off
setlocal
echo Forwarding to scripts\dev.ps1 db-test
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\dev.ps1" db-test
exit /b %ERRORLEVEL%
