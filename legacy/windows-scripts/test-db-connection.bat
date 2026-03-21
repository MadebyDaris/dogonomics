@echo off
echo ========================================
echo PostgreSQL Connection Test
echo ========================================
echo.

REM Check if psql is available
where psql >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: PostgreSQL 'psql' not found in PATH!
    echo Please install PostgreSQL or add it to your PATH.
    pause
    exit /b 1
)

echo Testing connection to dogonomics database...
echo.

REM Test connection
psql -U dogonomics -h localhost -d dogonomics -c "SELECT version();"

if %errorlevel% neq 0 (
    echo.
    echo ERROR: Could not connect to database!
    echo.
    echo Please check:
    echo   1. PostgreSQL service is running
    echo   2. Database 'dogonomics' exists
    echo   3. User 'dogonomics' has been created
    echo   4. Password is correct (dogonomics_password)
    echo.
    echo Run setup-local-postgres.bat to initialize the database.
    echo.
    pause
    exit /b 1
)

echo.
echo Testing schema...
echo.

psql -U dogonomics -h localhost -d dogonomics -c "\dt"

echo.
echo ========================================
echo Database connection successful!
echo ========================================
echo.
echo You can now run your application with: run.bat
echo.
pause
