@echo off
setlocal
echo Forwarding to scripts\run\run-onnx.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\run\run-onnx.ps1"
exit /b %ERRORLEVEL%
