# Local PostgreSQL Setup for Dogonomics (Simple version - password visible)
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Local PostgreSQL Setup for Dogonomics" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "This script will set up the database using your local PostgreSQL installation."
Write-Host ""

# Check if psql is available
$psqlExists = Get-Command psql -ErrorAction SilentlyContinue
if (-not $psqlExists) {
    Write-Host "ERROR: PostgreSQL 'psql' command not found!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please install PostgreSQL from: https://www.postgresql.org/download/windows/"
    Write-Host "Make sure to add PostgreSQL bin directory to your PATH."
    Write-Host ""
    Write-Host "Typical path: C:\Program Files\PostgreSQL\16\bin"
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host "PostgreSQL found!" -ForegroundColor Green
Write-Host ""

# Prompt for PostgreSQL admin credentials
$PG_ADMIN_USER = Read-Host "Enter PostgreSQL admin username (default: postgres)"
if ([string]::IsNullOrWhiteSpace($PG_ADMIN_USER)) {
    $PG_ADMIN_USER = "postgres"
}

Write-Host ""
Write-Host "Creating database and user..." -ForegroundColor Yellow
Write-Host ""
Write-Host "NOTE: You will be prompted for the postgres password 4 times." -ForegroundColor Yellow
Write-Host ""

# Create database
Write-Host "Creating database 'dogonomics'..."
& psql -U $PG_ADMIN_USER -h localhost -W -c "CREATE DATABASE dogonomics;"
if ($LASTEXITCODE -ne 0) {
    Write-Host "Note: Database may already exist, continuing..." -ForegroundColor Yellow
}

# Create user
Write-Host "Creating user 'dogonomics'..."
& psql -U $PG_ADMIN_USER -h localhost -W -c "CREATE USER dogonomics WITH PASSWORD 'dogonomics_password';"
if ($LASTEXITCODE -ne 0) {
    Write-Host "Note: User may already exist, continuing..." -ForegroundColor Yellow
}

# Grant privileges
Write-Host "Granting privileges..."
& psql -U $PG_ADMIN_USER -h localhost -W -c "GRANT ALL PRIVILEGES ON DATABASE dogonomics TO dogonomics;"
& psql -U $PG_ADMIN_USER -h localhost -W -d dogonomics -c "GRANT ALL ON SCHEMA public TO dogonomics;"
& psql -U $PG_ADMIN_USER -h localhost -W -d dogonomics -c "ALTER DATABASE dogonomics OWNER TO dogonomics;"

Write-Host ""
Write-Host "Initializing database schema..." -ForegroundColor Yellow
Write-Host ""

# Set password for dogonomics user
$env:PGPASSWORD = "dogonomics_password"

# Run schema creation
& psql -U dogonomics -h localhost -d dogonomics -f "internal\database\schema.sql"

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "ERROR: Failed to initialize database schema!" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

# Clear password from environment
$env:PGPASSWORD = $null

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "Database setup completed successfully!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Database connection details:"
Write-Host "  Host:     localhost"
Write-Host "  Port:     5432"
Write-Host "  Database: dogonomics"
Write-Host "  User:     dogonomics"
Write-Host "  Password: dogonomics_password"
Write-Host ""
Write-Host "Make sure your .env file has these settings:"
Write-Host "  DB_HOST=localhost"
Write-Host "  DB_PORT=5432"
Write-Host "  DB_USER=dogonomics"
Write-Host "  DB_PASSWORD=dogonomics_password"
Write-Host "  DB_NAME=dogonomics"
Write-Host "  DB_SSLMODE=disable"
Write-Host ""
Write-Host "You can now run your application!" -ForegroundColor Green
Write-Host ""
Read-Host "Press Enter to exit"
