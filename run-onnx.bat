@echo off
REM ====================================================================
REM Run script for Dogonomics API (ONNX-enabled with BERT)
REM ====================================================================
REM Runs the ONNX build with BERT sentiment analysis enabled.
REM Requires ONNX Runtime DLL in PATH or C:\onnxruntime\lib\
REM ====================================================================

echo.
echo ========================================
echo   Dogonomics API - ONNX Mode
echo ========================================
echo.

REM Check if .env file exists
if not exist ".env" (
    echo WARNING: .env file not found!
    echo.
    echo Please create a .env file with:
    echo   FINNHUB_API_KEY=your_key_here
    echo   EODHD_API_KEY=your_key_here
    echo.
    pause
)

REM Check if ONNX binary exists
if not exist "dogonomics-onnx.exe" (
    echo ERROR: dogonomics-onnx.exe not found!
    echo.
    echo Please run: build-onnx.bat
    echo.
    pause
    exit /b 1
)

REM Check ONNX Runtime
if not exist "C:\onnxruntime\lib\onnxruntime.dll" (
    echo WARNING: ONNX Runtime DLL not found at C:\onnxruntime\lib\
    echo.
    echo Please run: runtimesetup.bat
    echo Or add ONNX Runtime to your PATH.
    echo.
    pause
)

REM Add ONNX Runtime to PATH for this session
set PATH=%PATH%;C:\onnxruntime\lib

echo Starting Dogonomics API with BERT support...
echo.
echo Server will be available at:
echo   - API: http://localhost:8080
echo   - Swagger UI: http://localhost:8080/swagger/index.html
echo   - Metrics: http://localhost:8080/metrics
echo.
echo BERT sentiment endpoints:
echo   - GET /sentiment/{symbol} - Aggregate sentiment
echo   - GET /finnewsBert/{symbol} - News with BERT sentiment
echo.
echo Press Ctrl+C to stop the server.
echo.
echo ========================================
echo.

dogonomics-onnx.exe
