@echo off
echo ========================================
echo Local PostgreSQL Setup for Dogonomics
echo ========================================
echo.
echo This script will start a local PostgreSQL container for development.
echo.

REM Check if Docker is running
docker info >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: Docker is not running!
    echo Please start Docker Desktop and try again.
    pause
    exit /b 1
)

echo Starting PostgreSQL container...
echo.

docker run -d ^
    --name dogonomics-postgres ^
    -e POSTGRES_USER=dogonomics ^
    -e POSTGRES_PASSWORD=dogonomics_password ^
    -e POSTGRES_DB=dogonomics ^
    -p 5432:5432 ^
    -v "%cd%\internal\database\schema.sql:/docker-entrypoint-initdb.d/01-schema.sql" ^
    postgres:14-alpine

if %errorlevel% neq 0 (
    echo.
    echo ERROR: Failed to start PostgreSQL container!
    echo.
    echo If the container already exists, you can:
    echo   1. Stop it:  docker stop dogonomics-postgres
    echo   2. Remove it: docker rm dogonomics-postgres
    echo   3. Then run this script again
    echo.
    pause
    exit /b 1
)

echo.
echo ========================================
echo PostgreSQL container started successfully!
echo ========================================
echo.
echo Database connection details:
echo   Host:     localhost
echo   Port:     5432
echo   Database: dogonomics
echo   User:     dogonomics
echo   Password: dogonomics_password
echo.
echo The database schema has been automatically initialized.
echo.
echo To stop the database:
echo   docker stop dogonomics-postgres
echo.
echo To remove the database (WARNING: data will be lost):
echo   docker rm -f dogonomics-postgres
echo.
echo To view database logs:
echo   docker logs dogonomics-postgres
echo.
echo Make sure your .env file has these settings:
echo   DB_HOST=localhost
echo   DB_PORT=5432
echo   DB_USER=dogonomics
echo   DB_PASSWORD=dogonomics_password
echo   DB_NAME=dogonomics
echo   DB_SSLMODE=disable
echo.
pause
