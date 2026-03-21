param(
	[string]$DbHost = 'localhost',
	[int]$Port = 5432,
	[string]$Database = 'dogonomics',
	[string]$AppUser = 'dogonomics',
	[string]$AppPassword = 'dogonomics_password',
	[string]$SuperUser
)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
Set-Location $root

Write-Host ''
Write-Host 'Dogonomics Backend: Setup Local PostgreSQL' -ForegroundColor Cyan

if (-not (Get-Command psql -ErrorAction SilentlyContinue)) {
	throw 'psql not found in PATH. Install PostgreSQL client tools first.'
}

if (-not (Test-Path '.\migrations\001_init.sql')) {
	throw 'migrations/001_init.sql not found.'
}

if ([string]::IsNullOrWhiteSpace($SuperUser)) {
	foreach ($candidate in @('postgres', 'admin', 'superuser')) {
		$null = & psql -w -U $candidate -h $DbHost -p $Port -d postgres -c '\q' 2>$null
		if ($LASTEXITCODE -eq 0) {
			$SuperUser = $candidate
			break
		}
	}
}

if ([string]::IsNullOrWhiteSpace($SuperUser)) {
	$SuperUser = Read-Host 'Enter PostgreSQL superuser name (e.g. postgres)'
}

if ([string]::IsNullOrWhiteSpace($SuperUser)) {
	throw 'No PostgreSQL superuser specified.'
}

Write-Host "Using superuser: $SuperUser"

$roleExists = (& psql -w -U $SuperUser -h $DbHost -p $Port -d postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='$AppUser';" 2>$null).Trim()
if ($roleExists -ne '1') {
	& psql -w -U $SuperUser -h $DbHost -p $Port -d postgres -c "CREATE ROLE $AppUser LOGIN PASSWORD '$AppPassword';"
	if ($LASTEXITCODE -ne 0) {
		throw 'Failed to create application role.'
	}
}

$dbExists = (& psql -w -U $SuperUser -h $DbHost -p $Port -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='$Database';" 2>$null).Trim()
if ($dbExists -ne '1') {
	& psql -w -U $SuperUser -h $DbHost -p $Port -d postgres -c "CREATE DATABASE $Database OWNER $AppUser;"
	if ($LASTEXITCODE -ne 0) {
		throw 'Failed to create database.'
	}
}

& psql -w -U $SuperUser -h $DbHost -p $Port -d postgres -c "GRANT ALL PRIVILEGES ON DATABASE $Database TO $AppUser;"

$env:PGPASSWORD = $AppPassword
try {
	& psql -w -v ON_ERROR_STOP=1 -U $AppUser -h $DbHost -p $Port -d $Database -f '.\migrations\001_init.sql'
	if ($LASTEXITCODE -ne 0) {
		throw 'Failed to initialize schema using migrations/001_init.sql.'
	}
}
finally {
	$env:PGPASSWORD = $null
}

Write-Host ''
Write-Host 'PostgreSQL setup completed successfully.' -ForegroundColor Green
