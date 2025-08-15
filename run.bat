@echo off
setlocal enabledelayedexpansion

echo ======================================
echo     Dogonomics Backened API
echo     IDIRENE Daris.
echo ======================================
echo.

REM Check if the executable exists
if not exist "dogonomics.exe" (
    echo ERROR: dogonomics.exe not found
    echo Please run build.bat first to build the application
    echo.
    pause
    exit /b 1
)

REM Check if ONNX Runtime DLL is accessible
set PATH=C:\onnxruntime\lib;%PATH%
if not exist "C:\onnxruntime\lib\onnxruntime.dll" (
    echo ERROR: ONNX Runtime DLL not found
    echo Please run runtimesetup.bat to install ONNX Runtime
    echo.
    pause
    exit /b 1
)

REM Check for .env file
if not exist ".env" (
    echo WARNING: .env file not found, needed for all your keys for the
    echo Various API's used
    echo.
    if exist ".env.template" (
        echo Creating .env file from template...
        copy ".env.template" ".env" >nul
        echo .env file created. Please edit it with your API keys.
        echo.
        set /p choice="Do you want to edit the .env file now? (y/n): "
        if /i "!choice!"=="y" (
            notepad .env
        )
    ) else (
        echo Please create a .env file with your API keys:
        echo FINNHUB_API_KEY=your_key_here
        echo POLYGON_API_KEY=your_key_here  
        echo EODHD_API_KEY=your_key_here
        echo.
        pause
    )
)

REM Check if model files exist
echo Checking for BERT model files...
if not exist "sentAnalysis\DoggoFinBERT.onnx" (
    echo WARNING: BERT model file not found at sentAnalysis\DoggoFinBERT.onnx
    echo Sentiment analysis features will not work without the model file.
    echo.
)

if not exist "sentAnalysis\finbert\vocab.txt" (
    echo WARNING: Vocabulary file not found at sentAnalysis\finbert\vocab.txt
    echo Sentiment analysis features will not work without the vocabulary file.
    echo.
)

echo Starting Dogonomics API Server...
echo.
echo The server will be available at: http://localhost:8080
echo.
echo Available endpoints:
echo - GET /health - Health check
echo - GET /quote/AAPL - Get stock quote
echo - GET /sentiment/AAPL - Get news with sentiment analysis
echo - GET /test - System test
echo.
echo Press Ctrl+C to stop the server
echo.

REM Set environment for runtime
set CGO_ENABLED=1

REM Run the application
dogonomics.exe

if %ERRORLEVEL% neq 0 (
    echo.
    echo ======================================
    echo         SERVER STOPPED WITH ERROR
    echo ======================================
    echo.
    echo Common issues and solutions:
    echo.
    echo 1. Port 8080 already in use:
    echo    - Close other applications using port 8080
    echo    - Or set PORT environment variable to use different port
    echo.
    echo 2. Missing API keys:
    echo    - Check your .env file has valid API keys
    echo.
    echo 3. ONNX Runtime errors:
    echo    - Ensure C:\onnxruntime\lib is in your PATH
    echo    - Try running as Administrator
    echo.
    echo 4. Model file errors:
    echo    - Ensure BERT model files are in sentAnalysis directory
    echo.
)

echo.
echo Press any key to exit...
pause >nul