@echo off
setlocal
echo Forwarding to scripts\build\build-onnx.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\build\build-onnx.ps1" -SyncVendor
exit /b %ERRORLEVEL%
