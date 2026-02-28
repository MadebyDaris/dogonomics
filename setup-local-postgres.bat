@echo off
echo ========================================
echo Local PostgreSQL Setup for Dogonomics
echo ========================================
echo.
echo This script will set up the database using your local PostgreSQL installation.
echo.
echo Prerequisites:
echo   - PostgreSQL must be installed on your system
echo   - psql command must be in your PATH
echo.

REM Check if psql is available
where psql >nul 2>&1
if %errorlevel% neq 0 (
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

REM Prompt for PostgreSQL admin credentials
set /p PG_ADMIN_USER="Enter PostgreSQL admin username (default: postgres): "
if "%PG_ADMIN_USER%"=="" set PG_ADMIN_USER=postgres

echo.
echo NOTE: You will be prompted for the '%PG_ADMIN_USER%' password multiple times.
echo.
echo Creating database and user...
echo.

REM Create database, user, and grant privileges
echo Creating database 'dogonomics'...
echo Creating database 'dogonomics'...
psql -U %PG_ADMIN_USER% -h localhost -W -c "CREATE DATABASE dogonomics;"
if %errorlevel% neq 0 (
    echo.
    echo Note: Database may already exist, continuing...
    echo.
)

echo Creating user 'dogonomics'...
psql -U %PG_ADMIN_USER% -h localhost -W -c "CREATE USER dogonomics WITH PASSWORD 'dogonomics_password';"
if %errorlevel% neq 0 (
    echo.
    echo Note: User may already exist, continuing...
    echo.
)

echo Granting privileges...
psql -U %PG_ADMIN_USER% -h localhost -W -c "GRANT ALL PRIVILEGES ON DATABASE dogonomics TO dogonomics;"
psql -U %PG_ADMIN_USER% -h localhost -W -d dogonomics -c "GRANT ALL ON SCHEMA public TO dogonomics;"
psql -U %PG_ADMIN_USER% -h localhost -W -d dogonomics -c "ALTER DATABASE dogonomics OWNER TO dogonomics;"

echo.
echo Initializing database schema...
echo.

REM Set password for dogonomics user
set PGPASSWORD=dogonomics_password

REM Run schema creation
psql -U dogonomics -h localhost -d dogonomics -f "internal\database\schema.sql"

REM Clear password
set PGPASSWORD=

if %errorlevel% neq 0 (
    echo.
    echo ERROR: Failed to initialize database schema!
    pause
    exit /b 1
)

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
echo Make sure your .env file has these settings:
echo   DB_HOST=localhost
echo   DB_PORT=5432
echo   DB_USER=dogonomics
echo   DB_PASSWORD=dogonomics_password
echo   DB_NAME=dogonomics
echo   DB_SSLMODE=disable
echo.
echo You can now run your application!
echo.
pause
