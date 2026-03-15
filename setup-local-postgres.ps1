# Local PostgreSQL Setup for Dogonomics (PowerShell version)
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Local PostgreSQL Setup for Dogonomics" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "This script will set up the database using your local PostgreSQL installation."
Write-Host ""
Write-Host "Prerequisites:"
Write-Host "  - PostgreSQL must be installed on your system"
Write-Host "  - psql command must be in your PATH"
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

# Prompt for PostgreSQL admin credentials (use superuser, typically 'postgres')
$PG_ADMIN_USER = Read-Host "Enter PostgreSQL superuser name (default: postgres) [NOT 'dogonomics']"
if ([string]::IsNullOrWhiteSpace($PG_ADMIN_USER)) {
    $PG_ADMIN_USER = "postgres"
}

if ($PG_ADMIN_USER -eq "dogonomics") {
    Write-Host "ERROR: You must use the PostgreSQL superuser (typically 'postgres'), not 'dogonomics'" -ForegroundColor Red
    Write-Host "The 'dogonomics' user is being created by this script." -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host ""
Write-Host "Creating database and user..." -ForegroundColor Yellow
Write-Host ""

# Prompt for password and convert SecureString to plain text
$securePassword = Read-Host "Enter password for PostgreSQL user '$PG_ADMIN_USER'" -AsSecureString
$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
$env:PGPASSWORD = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
[System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)

# Create database
Write-Host "Creating database 'dogonomics'..."
& psql -U $PG_ADMIN_USER -h localhost -c "CREATE DATABASE dogonomics;" 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Note: Database may already exist, continuing..." -ForegroundColor Yellow
}

# Create user
Write-Host "Creating user 'dogonomics'..."
& psql -U $PG_ADMIN_USER -h localhost -c "CREATE USER dogonomics WITH PASSWORD 'dogonomics_password';" 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Note: User may already exist, continuing..." -ForegroundColor Yellow
}

# Grant privileges
Write-Host "Granting privileges..."
& psql -U $PG_ADMIN_USER -h localhost -c "GRANT ALL PRIVILEGES ON DATABASE dogonomics TO dogonomics;" | Out-Null
& psql -U $PG_ADMIN_USER -h localhost -d dogonomics -c "GRANT ALL ON SCHEMA public TO dogonomics;" | Out-Null
& psql -U $PG_ADMIN_USER -h localhost -d dogonomics -c "ALTER DATABASE dogonomics OWNER TO dogonomics;" | Out-Null

Write-Host ""
Write-Host "Initializing database schema..." -ForegroundColor Yellow
Write-Host ""

# Clear PGPASSWORD and set for dogonomics user
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
Write-Host "Validating database setup..." -ForegroundColor Yellow
Write-Host ""

# Set password again for validation queries
$env:PGPASSWORD = "dogonomics_password"

# Verify tables exist
$tables = & psql -U dogonomics -h localhost -d dogonomics -t -c "SELECT count(*) FROM information_schema.tables WHERE table_schema='public' AND table_type='BASE TABLE';"
if ([int]$tables -gt 0) {
    Write-Host "✓ Database tables created successfully ($tables tables found)" -ForegroundColor Green
} else {
    Write-Host "✗ ERROR: No tables found in database!" -ForegroundColor Red
    $env:PGPASSWORD = $null
    Read-Host "Press Enter to exit"
    exit 1
}

# Verify TimescaleDB extension
$hasTimescaleDB = & psql -U dogonomics -h localhost -d dogonomics -t -c "SELECT count(*) FROM pg_extension WHERE extname='timescaledb';"
if ([int]$hasTimescaleDB -gt 0) {
    Write-Host "✓ TimescaleDB extension is active" -ForegroundColor Green
} else {
    Write-Host "✗ WARNING: TimescaleDB extension not found (features may be limited)" -ForegroundColor Yellow
}

# Verify hypertables exist
$hypertables = & psql -U dogonomics -h localhost -d dogonomics -t -c "SELECT count(*) FROM timescaledb_information.hypertables;"
if ([int]$hypertables -gt 0) {
    Write-Host "✓ Hypertables created successfully ($hypertables hypertables found)" -ForegroundColor Green
} else {
    Write-Host "⚠ Note: No hypertables found (may be expected if schema uses standard tables)" -ForegroundColor Yellow
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
