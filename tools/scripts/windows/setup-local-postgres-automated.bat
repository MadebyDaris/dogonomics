@echo off
REM Dogonomics PostgreSQL Setup - Automated with Error Recovery
REM This script automatically detects and creates the database, handling common errors

setlocal enabledelayedexpansion

echo ========================================
echo Dogonomics PostgreSQL Setup (Automated)
echo ========================================
echo.

REM Check if psql is available
psql --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: PostgreSQL 'psql' command not found!
    echo.
    echo Please install PostgreSQL from: https://www.postgresql.org/download/windows/
    echo Make sure to add PostgreSQL bin directory to your PATH.
    echo.
    echo Typical path: C:\Program Files\PostgreSQL\16\bin
    echo.
    pause
    exit /b 1
)

echo PostgreSQL found!
echo.

REM Try to detect the superuser - check common names
echo Detecting PostgreSQL superuser...

set SUPERUSER=
for %%U in (postgres admin superuser) do (
    psql -U %%U -h localhost -c "\q" >nul 2>&1
    if errorlevel 0 (
        set SUPERUSER=%%U
        echo Found superuser: !SUPERUSER!
        goto :superuser_found
    )
)

:superuser_found
if "!SUPERUSER!"=="" (
    echo.
    echo Could not auto-detect superuser. Common superusers: postgres, admin, superuser
    echo.
    set /p SUPERUSER="Enter PostgreSQL superuser name: "
    if "!SUPERUSER!"=="" (
        echo ERROR: No superuser specified
        pause
        exit /b 1
    )
)

if "!SUPERUSER!"=="dogonomics" (
    echo.
    echo ERROR: Cannot use 'dogonomics' as superuser!
    echo The 'dogonomics' user is created BY this script, not your admin user.
    echo Please use the actual PostgreSQL superuser (usually 'postgres').
    echo.
    pause
    exit /b 1
)

echo.
echo Creating database 'dogonomics'...

REM Try to create database (will fail silently if exists)
psql -U !SUPERUSER! -h localhost -c "CREATE DATABASE dogonomics;" 2>nul

REM Check if database exists now
psql -U !SUPERUSER! -h localhost -d dogonomics -c "\q" >nul 2>&1
if errorlevel 1 (
    echo ERROR: Could not create or access database 'dogonomics'
    echo.
    echo Possible causes:
    echo   1. Wrong superuser password
    echo   2. PostgreSQL not running
    echo   3. Network issues
    echo.
    echo Try these manual commands:
    echo   psql -U postgres -h localhost
    echo   CREATE DATABASE dogonomics;
    echo.
    pause
    exit /b 1
)

echo ✓ Database 'dogonomics' exists
echo.
echo Creating user 'dogonomics'...

REM Create user (will fail silently if exists)
psql -U !SUPERUSER! -h localhost -d dogonomics -c "CREATE USER dogonomics WITH PASSWORD 'dogonomics_password';" 2>nul

REM Grant privileges
echo Granting privileges...
psql -U !SUPERUSER! -h localhost -d dogonomics -c "GRANT ALL PRIVILEGES ON DATABASE dogonomics TO dogonomics;" >nul 2>&1
psql -U !SUPERUSER! -h localhost -d dogonomics -c "GRANT ALL ON SCHEMA public TO dogonomics;" >nul 2>&1
psql -U !SUPERUSER! -h localhost -d dogonomics -c "ALTER DATABASE dogonomics OWNER TO dogonomics;" >nul 2>&1

echo ✓ User 'dogonomics' created and granted privileges
echo.
echo Initializing database schema...

REM Set environment variable for password
set PGPASSWORD=dogonomics_password

REM Run schema
psql -U dogonomics -h localhost -d dogonomics -f "internal\database\schema.sql" 2>nul

if errorlevel 1 (
    echo ERROR: Failed to initialize database schema!
    echo.
    echo This might be because:
    echo   1. Schema file not found (run from dogonomics_go_backened directory)
    echo   2. Database doesn't have proper permissions
    echo.
    echo Check that you're in the correct directory and try manually:
    echo   psql -U dogonomics -h localhost -d dogonomics -f "internal\database\schema.sql"
    echo.
    set PGPASSWORD=
    pause
    exit /b 1
)

echo ✓ Database schema initialized
echo.
echo Validating setup...
echo.

REM Verify tables
for /f "delims=" %%I in ('psql -U dogonomics -h localhost -d dogonomics -t -c "SELECT count(*) FROM information_schema.tables WHERE table_schema='public' AND table_type='BASE TABLE';" 2^>nul') do set TABLES=%%I

if "!TABLES!"=="" (
    echo WARNING: Could not verify tables
) else (
    echo ✓ Database tables found: !TABLES!
)

REM Verify TimescaleDB
psql -U dogonomics -h localhost -d dogonomics -c "SELECT extversion FROM pg_extension WHERE extname='timescaledb';" >nul 2>&1
if errorlevel 0 (
    echo ✓ TimescaleDB extension is active
) else (
    echo ⚠ TimescaleDB extension not found (features may be limited)
)

REM Clear password
set PGPASSWORD=

echo.
echo ========================================
echo Database setup completed successfully!
echo ========================================
echo.
echo Database connection details:
echo   Host:     localhost
echo   Port:     5432
echo   Database: dogonomics
echo   User:     dogonomics
echo   Password: dogonomics_password
echo.
echo Next steps:
echo   1. Update .env file with these settings (already set in defaults)
echo   2. Run: go run dogonomics.go
echo   3. API will be at: http://localhost:8080
echo.

pause
