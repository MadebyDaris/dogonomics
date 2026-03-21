$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
Set-Location $root

Write-Host ''
Write-Host 'Dogonomics Backend: Test DB Connection' -ForegroundColor Cyan

if (-not (Get-Command psql -ErrorAction SilentlyContinue)) {
    throw 'psql not found in PATH. Install PostgreSQL client tools first.'
}

$dbUser = if ($env:DB_USER) { $env:DB_USER } else { 'dogonomics' }
$dbName = if ($env:DB_NAME) { $env:DB_NAME } else { 'dogonomics' }
$dbHost = if ($env:DB_HOST) { $env:DB_HOST } else { 'localhost' }
$dbPort = if ($env:DB_PORT) { $env:DB_PORT } else { '5432' }

if (-not $env:PGPASSWORD -and $env:DB_PASSWORD) {
    $env:PGPASSWORD = $env:DB_PASSWORD
}

& psql -w -U $dbUser -h $dbHost -p $dbPort -d $dbName -c 'SELECT 1 AS ok;'
if ($LASTEXITCODE -ne 0) {
    throw 'Database connection test failed.'
}

Write-Host 'Database connection succeeded.' -ForegroundColor Green
