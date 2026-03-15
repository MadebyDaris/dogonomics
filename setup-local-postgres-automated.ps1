# Dogonomics PostgreSQL Setup - Automated (PowerShell)
# This script automatically handles database creation and common errors

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Dogonomics PostgreSQL Setup (Automated)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
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

# Try to auto-detect superuser
Write-Host "Detecting PostgreSQL superuser..." -ForegroundColor Yellow
$superuser = $null

foreach ($user in @("postgres", "admin", "superuser")) {
    try {
        $output = & psql -U $user -h localhost -c "\q" 2>&1
        if ($LASTEXITCODE -eq 0) {
            $superuser = $user
            Write-Host "Found superuser: $superuser" -ForegroundColor Green
            break
        }
    }
    catch {
        # Continue to next user
    }
}

# If not found, prompt user
if (-not $superuser) {
    Write-Host ""
    Write-Host "Could not auto-detect superuser. Common superusers: postgres, admin, superuser" -ForegroundColor Yellow
    Write-Host ""
    $superuser = Read-Host "Enter PostgreSQL superuser name (default: postgres)"
    if ([string]::IsNullOrWhiteSpace($superuser)) {
        $superuser = "postgres"
    }
}

# Validate not using 'dogonomics'
if ($superuser -eq "dogonomics") {
    Write-Host ""
    Write-Host "ERROR: Cannot use 'dogonomics' as superuser!" -ForegroundColor Red
    Write-Host "The 'dogonomics' user is created BY this script, not your admin user." -ForegroundColor Red
    Write-Host "Please use the actual PostgreSQL superuser (usually 'postgres')." -ForegroundColor Red
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host ""
Write-Host "Using superuser: $superuser" -ForegroundColor Cyan
Write-Host ""
Write-Host "Creating database 'dogonomics'..." -ForegroundColor Yellow

# Try to get superuser password
$securePassword = Read-Host "Enter password for PostgreSQL superuser '$superuser'" -AsSecureString
$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
$password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
[System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)

$env:PGPASSWORD = $password

# Create database (ignore error if already exists)
try {
    $null = & psql -U $superuser -h localhost -c "CREATE DATABASE dogonomics;" 2>&1
}
catch {
    # Silently continue
}

# Verify database exists
try {
    $null = & psql -U $superuser -h localhost -d dogonomics -c "\q" 2>&1
}
catch {
    Write-Host ""
    Write-Host "ERROR: Could not create or access database 'dogonomics'" -ForegroundColor Red
    Write-Host ""
    Write-Host "Possible causes:" -ForegroundColor Yellow
    Write-Host "  1. Wrong superuser password" -ForegroundColor Yellow
    Write-Host "  2. PostgreSQL not running" -ForegroundColor Yellow
    Write-Host "  3. Network issues (if PostgreSQL on remote host)" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Try these manual commands:" -ForegroundColor Yellow
    Write-Host "  psql -U postgres -h localhost" -ForegroundColor Yellow
    Write-Host "  CREATE DATABASE dogonomics;" -ForegroundColor Yellow
    Write-Host ""
    $env:PGPASSWORD = $null
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host "✓ Database 'dogonomics' exists" -ForegroundColor Green
Write-Host ""
Write-Host "Creating user 'dogonomics'..." -ForegroundColor Yellow

# Create user (ignore error if already exists)
try {
    $null = & psql -U $superuser -h localhost -d dogonomics -c "CREATE USER dogonomics WITH PASSWORD 'dogonomics_password';" 2>&1
}
catch {
    # Silently continue
}

# Grant privileges
try {
    $null = & psql -U $superuser -h localhost -d dogonomics -c "GRANT ALL PRIVILEGES ON DATABASE dogonomics TO dogonomics;" 2>&1
    $null = & psql -U $superuser -h localhost -d dogonomics -c "GRANT ALL ON SCHEMA public TO dogonomics;" 2>&1
    $null = & psql -U $superuser -h localhost -d dogonomics -c "ALTER DATABASE dogonomics OWNER TO dogonomics;" 2>&1
}
catch {
    Write-Host "Warning: Could not grant all privileges" -ForegroundColor Yellow
}

Write-Host "✓ User 'dogonomics' created and granted privileges" -ForegroundColor Green
Write-Host ""
Write-Host "Initializing database schema..." -ForegroundColor Yellow

# Use dogonomics password for schema initialization
$env:PGPASSWORD = "dogonomics_password"

try {
    $null = & psql -U dogonomics -h localhost -d dogonomics -f "internal\database\schema.sql" 2>&1
}
catch {
    Write-Host ""
    Write-Host "ERROR: Failed to initialize database schema!" -ForegroundColor Red
    Write-Host ""
    Write-Host "This might be because:" -ForegroundColor Yellow
    Write-Host "  1. Schema file not found (run from dogonomics_go_backened directory)" -ForegroundColor Yellow
    Write-Host "  2. Database doesn't have proper permissions" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Check that you're in the correct directory and try manually:" -ForegroundColor Yellow
    Write-Host "  psql -U dogonomics -h localhost -d dogonomics -f 'internal\database\schema.sql'" -ForegroundColor Yellow
    Write-Host ""
    $env:PGPASSWORD = $null
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host "✓ Database schema initialized" -ForegroundColor Green
Write-Host ""
Write-Host "Validating setup..." -ForegroundColor Yellow
Write-Host ""

# Verify tables
try {
    $tables = & psql -U dogonomics -h localhost -d dogonomics -t -c "SELECT count(*) FROM information_schema.tables WHERE table_schema='public' AND table_type='BASE TABLE';" 2>&1
    if ($tables -and $tables -gt 0) {
        Write-Host "✓ Database tables found: $([int]$tables)" -ForegroundColor Green
    }
}
catch {
    Write-Host "⚠ Could not verify tables" -ForegroundColor Yellow
}

# Verify TimescaleDB
try {
    $null = & psql -U dogonomics -h localhost -d dogonomics -c "SELECT extversion FROM pg_extension WHERE extname='timescaledb';" 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ TimescaleDB extension is active" -ForegroundColor Green
    }
}
catch {
    Write-Host "⚠ TimescaleDB extension not found (features may be limited)" -ForegroundColor Yellow
}

# Clear password from environment
$env:PGPASSWORD = $null

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "Database setup completed successfully!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Database connection details:" -ForegroundColor Cyan
Write-Host "  Host:     localhost"
Write-Host "  Port:     5432"
Write-Host "  Database: dogonomics"
Write-Host "  User:     dogonomics"
Write-Host "  Password: dogonomics_password"
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Update .env file with these settings (already set in defaults)"
Write-Host "  2. Run: go run dogonomics.go"
Write-Host "  3. API will be at: http://localhost:8080"
Write-Host ""
Read-Host "Press Enter to exit"
