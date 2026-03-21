@echo off
REM ====================================================================
REM Fix ONNX Runtime Architecture Mismatch
REM ====================================================================

echo.
echo ========================================
echo   Fix ONNX Runtime Architecture
echo ========================================
echo.

echo Current ONNX Runtime installation will be replaced
echo.

set /p confirm="Do you want to continue? (y/n): "
if /i not "%confirm%"=="y" (
    echo Cancelled.
    pause
    exit /b 0
)

echo.
echo [1/4] Removing old ONNX Runtime installation...
if exist "C:\onnxruntime\lib" (
    rd /s /q "C:\onnxruntime\lib"
)
if exist "C:\onnxruntime\include" (
    rd /s /q "C:\onnxruntime\include"
)
if exist "C:\onnxruntime\onnxruntime-win-arm64-1.17.1" (
    rd /s /q "C:\onnxruntime\onnxruntime-win-arm64-1.17.1"
)
echo Old installation removed.
echo.

echo [2/4] Downloading ONNX Runtime v1.17.1 for Windows x64...
powershell -Command ^
    "try {" ^
    "    $ProgressPreference = 'SilentlyContinue';" ^
    "    $url = 'https://github.com/microsoft/onnxruntime/releases/download/v1.17.1/onnxruntime-win-x64-1.17.1.zip';" ^
    "    $output = 'C:\onnxruntime\onnxruntime-win-x64-1.17.1.zip';" ^
    "    Invoke-WebRequest -Uri $url -OutFile $output;" ^
    "    Write-Host 'Download completed successfully';" ^
    "} catch {" ^
    "    Write-Host 'Download failed:' $_.Exception.Message;" ^
    "    exit 1;" ^
    "}"

if %ERRORLEVEL% neq 0 (
    echo ERROR: Download failed!
    pause
    exit /b 1
)

echo.
echo [3/4] Extracting...
powershell -Command ^
    "try {" ^
    "    $zipPath = 'C:\onnxruntime\onnxruntime-win-x64-1.17.1.zip';" ^
    "    $extractPath = 'C:\onnxruntime';" ^
    "    Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force;" ^
    "    $sourcePath = 'C:\onnxruntime\onnxruntime-win-x64-1.17.1\*';" ^
    "    Copy-Item -Path $sourcePath -Destination $extractPath -Recurse -Force;" ^
    "    Remove-Item -Path 'C:\onnxruntime\onnxruntime-win-x64-1.17.1' -Recurse -Force;" ^
    "    Remove-Item -Path $zipPath -Force;" ^
    "    Write-Host 'Extraction completed successfully';" ^
    "} catch {" ^
    "    Write-Host 'Extraction failed:' $_.Exception.Message;" ^
    "    exit 1;" ^
    "}"

if %ERRORLEVEL% neq 0 (
    echo ERROR: Extraction failed!
    pause
    exit /b 1
)

echo.
echo [4/4] Verifying installation...
if exist "C:\onnxruntime\lib\onnxruntime.dll" (
    echo ✓ onnxruntime.dll found
) else (
    echo ✗ onnxruntime.dll NOT found
    pause
    exit /b 1
)

if exist "C:\onnxruntime\include\onnxruntime_c_api.h" (
    echo ✓ Header files found
) else (
    echo ✗ Header files NOT found
    pause
    exit /b 1
)

echo.
echo ========================================
echo   Installation Complete!
echo ========================================
echo.
echo ONNX Runtime v1.17.1 (x64) installed at C:\onnxruntime\
echo.
echo You can now run: build-onnx.bat
echo.
pause
