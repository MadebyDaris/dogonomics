@echo off
REM ====================================================================
REM Upgrade ONNX Runtime to 1.19.0 (matches Go library v1.19.0)
REM ====================================================================

echo.
echo ========================================
echo   Upgrade to ONNX Runtime 1.19.0
echo ========================================
echo.

echo This will replace your current ONNX Runtime installation with version 1.19.0
echo which matches the Go library API requirements.
echo.

set /p confirm="Do you want to continue? (y/n): "
if /i not "%confirm%"=="y" (
    echo Cancelled.
    pause
    exit /b 0
)

echo.
echo [1/5] Removing old installation...
if exist "C:\onnxruntime\lib" rd /s /q "C:\onnxruntime\lib"
if exist "C:\onnxruntime\include" rd /s /q "C:\onnxruntime\include"
echo.

echo [2/5] Downloading ONNX Runtime v1.19.0 for Windows x64...
powershell -Command ^
    "$ProgressPreference = 'SilentlyContinue';" ^
    "$url = 'https://github.com/microsoft/onnxruntime/releases/download/v1.19.0/onnxruntime-win-x64-1.19.0.zip';" ^
    "$output = 'C:\onnxruntime\onnxruntime-win-x64-1.19.0.zip';" ^
    "Invoke-WebRequest -Uri $url -OutFile $output;" ^
    "Write-Host 'Download complete'"

if %ERRORLEVEL% neq 0 (
    echo ERROR: Download failed
    pause
    exit /b 1
)
echo.

echo [3/5] Extracting...
powershell -Command ^
    "$zipPath = 'C:\onnxruntime\onnxruntime-win-x64-1.19.0.zip';" ^
    "$extractPath = 'C:\onnxruntime';" ^
    "Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force;" ^
    "$sourcePath = 'C:\onnxruntime\onnxruntime-win-x64-1.19.0\*';" ^
    "Copy-Item -Path $sourcePath -Destination $extractPath -Recurse -Force;" ^
    "Remove-Item -Path 'C:\onnxruntime\onnxruntime-win-x64-1.19.0' -Recurse -Force;" ^
    "Remove-Item -Path $zipPath -Force;" ^
    "Write-Host 'Extraction complete'"

if %ERRORLEVEL% neq 0 (
    echo ERROR: Extraction failed
    pause
    exit /b 1
)
echo.

echo [4/5] Updating Go library to v1.19.0...
go get github.com/yalue/onnxruntime_go@v1.19.0
go mod tidy
go mod vendor
echo.

echo [5/5] Verifying...
if exist "C:\onnxruntime\lib\onnxruntime.dll" (
    echo ✓ DLL found
) else (
    echo ✗ DLL missing
    pause
    exit /b 1
)

if exist "C:\onnxruntime\include\onnxruntime_c_api.h" (
    echo ✓ Headers found
) else (
    echo ✗ Headers missing
    pause
    exit /b 1
)

echo.
echo ========================================
echo   Upgrade Complete!
echo ========================================
echo.
echo ONNX Runtime: 1.19.0 (x64)
echo Go Library: v1.19.0
echo API Versions: Matched
echo.
echo You can now run: build-onnx.bat
echo.
pause
