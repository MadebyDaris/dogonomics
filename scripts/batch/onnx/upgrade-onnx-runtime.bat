@echo off
setlocal
echo Forwarding to scripts\onnx\install-runtime.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\onnx\install-runtime.ps1"
exit /b %ERRORLEVEL%
