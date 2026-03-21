@echo off
setlocal
echo Building docker images (standard and onnx)
docker build -t dogonomics:latest .
if %ERRORLEVEL% neq 0 exit /b %ERRORLEVEL%
docker build -f Dockerfile.onnx -t dogonomics:onnx .
exit /b %ERRORLEVEL%
echo ONNX build complete.
echo.

:end
echo ========================================
echo   Build Summary
echo ========================================
echo.
docker images | findstr "dogonomics"
echo.
echo To run containers:
echo   Standard: docker-run.bat
echo   Full stack: docker-compose-up.bat
echo.
pause
