@echo off
setlocal enabledelayedexpansion

echo ===============================================
echo    ONNX Runtime Setup Script for Windows
echo ===============================================
echo.

REM Check if PowerShell is available
powershell -Command "Write-Host 'PowerShell is available'" >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo ERROR: PowerShell is required for this script
    pause
    exit /b 1
)

REM Check if ONNX Runtime is already installed
if exist "C:\onnxruntime\lib\onnxruntime.dll" (
    echo ONNX Runtime appears to already be installed at C:\onnxruntime\
    set /p choice="Do you want to reinstall? (y/n): "
    if /i not "!choice!"=="y" (
        echo Skipping installation.
        goto :setenv
    )
)

echo Creating installation directory...
if not exist "C:\onnxruntime" mkdir "C:\onnxruntime"

echo Downloading ONNX Runtime v1.17.1 for Windows x64...
echo This may take a few minutes depending on your internet connection...

powershell -Command ^
    "try {" ^
    "    $ProgressPreference = 'SilentlyContinue';" ^
    "    $url = 'https://github.com/microsoft/onnxruntime/releases/download/v1.17.1/onnxruntime-win-arm64-1.17.1.zip';" ^
    "    $output = 'C:\onnxruntime\onnxruntime-win-x64-1.21.0.zip';" ^
    "    Invoke-WebRequest -Uri $url -OutFile $output;" ^
    "    Write-Host 'Download completed successfully';" ^
    "} catch {" ^
    "    Write-Host 'Download failed:' $_.Exception.Message;" ^
    "    exit 1;" ^
    "}"

if %ERRORLEVEL% neq 0 (
    echo ERROR: Failed to download ONNX Runtime
    echo Please check your internet connection and try again
    pause
    exit /b 1
)

echo Extracting ONNX Runtime...
powershell -Command ^
    "try {" ^
    "    $zipPath = 'C:\onnxruntime\onnxruntime-win-x64-1.21.0.zip';" ^
    "    $extractPath = 'C:\onnxruntime';" ^
    "    Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force;" ^
    "    $sourcePath = 'C:\onnxruntime\onnxruntime-win-x64-1.21.0\*';" ^
    "    Copy-Item -Path $sourcePath -Destination $extractPath -Recurse -Force;" ^
    "    Remove-Item -Path 'C:\onnxruntime\onnxruntime-win-x64-1.21.0' -Recurse -Force;" ^
    "    Remove-Item -Path $zipPath -Force;" ^
    "    Write-Host 'Extraction completed successfully';" ^
    "} catch {" ^
    "    Write-Host 'Extraction failed:' $_.Exception.Message;" ^
    "    exit 1;" ^
    "}"

if %ERRORLEVEL% neq 0 (
    echo ERROR: Failed to extract ONNX Runtime
    pause
    exit /b 1
)

echo Verifying installation...
if exist "C:\onnxruntime\lib\onnxruntime.dll" (
    echo ✓ onnxruntime.dll found
) else (
    echo ✗ onnxruntime.dll NOT found
    goto :error
)

if exist "C:\onnxruntime\include\onnxruntime_c_api.h" (
    echo ✓ Header files found
) else (
    echo ✗ Header files NOT found
    goto :error
)

:setenv
echo.
echo ===============================================
echo         Setting Environment Variables
echo ===============================================
echo.

REM Set environment variables for current session
set CGO_ENABLED=1
set CGO_CFLAGS=-IC:\onnxruntime\include
set CGO_LDFLAGS=-LC:\onnxruntime\lib -lonnxruntime

echo Environment variables for current session:
echo - CGO_ENABLED: %CGO_ENABLED%
echo - CGO_CFLAGS: %CGO_CFLAGS%
echo - CGO_LDFLAGS: %CGO_LDFLAGS%
echo.

echo Adding C:\onnxruntime\lib to system PATH...
powershell -Command ^
    "try {" ^
    "    $oldPath = [Environment]::GetEnvironmentVariable('PATH', 'User');" ^
    "    if ($oldPath -notlike '*C:\onnxruntime\lib*') {" ^
    "        $newPath = $oldPath + ';C:\onnxruntime\lib';" ^
    "        [Environment]::SetEnvironmentVariable('PATH', $newPath, 'User');" ^
    "        Write-Host 'PATH updated successfully';" ^
    "    } else {" ^
    "        Write-Host 'PATH already contains ONNX Runtime lib directory';" ^
    "    }" ^
    "} catch {" ^
    "    Write-Host 'Failed to update PATH:' $_.Exception.Message;" ^
    "}"

echo.
echo ===============================================
echo            INSTALLATION COMPLETE!
echo ===============================================
echo.
echo ONNX Runtime has been successfully installed to C:\onnxruntime\
echo.
echo IMPORTANT: You may need to restart your command prompt or IDE
echo for the PATH changes to take effect.
echo.
echo You can now run: build.bat to build the Dogonomics application
echo.
goto :end

:error
echo.
echo ===============================================
echo           INSTALLATION FAILED!
echo ===============================================
echo.
echo Please try the following:
echo 1. Run this script as Administrator
echo 2. Check your internet connection
echo 3. Manually download from: https://github.com/microsoft/onnxruntime/releases
echo.

:end
echo Press any key to exit...
pause >nul