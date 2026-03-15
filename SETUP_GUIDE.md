# Dogonomics Backend Setup Guide

This guide covers setting up the Dogonomics backend for local development and Docker-based deployment.

## 📋 Prerequisites

### For All Setups
- **Go** 1.24.5+ ([download](https://golang.org/dl/))
- **Git** for version control
- **.env file** with API keys (copy from `.env.example` and add your keys)

### For Local Development
- **PostgreSQL** 14+ ([download](https://www.postgresql.org/download/windows/))
- **Redis** 7+ ([download](https://redis.io/download))
- `psql` command in your PATH

### For Docker Setup
- **Docker Desktop** with Docker Compose ([download](https://www.docker.com/products/docker-desktop))
- ~2GB free disk space for images and volumes

## 🚀 Quick Start

### Option 1: Docker (Recommended - Easiest)

```powershell
# 1. Start the full stack (PostgreSQL, Redis, API, Monitoring)
docker compose up --build

# The API will be available at http://localhost:8080
# Swagger docs at http://localhost:8080/swagger/index.html
# Grafana at http://localhost:3000 (admin/admin)
```

**To stop the stack:**
```powershell
docker compose down
```

**To restart without rebuilding:**
```powershell
docker compose up
```

### Option 2: Local PostgreSQL (Automated - NEW!)

The easiest local setup option - auto-detects your PostgreSQL superuser:

```powershell
# 1. Automated setup (detects superuser automatically)
.\setup-local-postgres-automated.ps1

# Or use the batch version:
.\setup-local-postgres-automated.bat

# 2. Create .env file and add your API keys
copy .env.example .env
# Edit .env and add FINNHUB_API_KEY, etc.

# 3. Run the backend
go run dogonomics.go
```

**What this script does:**
- Auto-detects your PostgreSQL superuser (postgres, admin, or superuser)
- Creates database and user automatically
- Initializes the schema with validation
- Handles common errors gracefully

### Option 3: Local PostgreSQL + Docker Redis

```powershell
# 1. Setup local PostgreSQL (with validation)
.\setup-local-postgres.ps1

# 2. Start Redis in Docker
docker run -d --name dogonomics-redis -p 6379:6379 redis:7-alpine

# 3. Create .env file and add your API keys
copy .env.example .env
# Edit .env and add FINNHUB_API_KEY, etc.

# 4. Run the backend
go run dogonomics.go
```

### Option 4: Local Everything

```powershell
# 1. Install PostgreSQL locally (if not already installed)
# 2. Setup database (with validation)
.\setup-local-postgres.ps1

# 3. Install Redis locally (if not already installed)
# 4. Start Redis
redis-server

# 5. Create .env file
copy .env.example .env
# Edit .env and add your API keys

# 6. Run the backend
go run dogonomics.go
```

## 🛠️ Database Setup Details

### Local PostgreSQL Setup (Windows PowerShell)

```powershell
# Run the secure setup script (recommended)
.\setup-local-postgres.ps1

# Or use the simple version (password visible in terminal)
.\setup-local-postgres-simple.ps1
```

**When prompted for "PostgreSQL superuser name":**
- Press **Enter** to use the default `postgres`
- DO NOT enter `dogonomics` - that user is being created by the script
- If unsure, see `POSTGRESQL_ADMIN_USER.md` for help
1. Verifies PostgreSQL is installed and `psql` is in PATH
2. Prompts for PostgreSQL admin credentials
3. Creates database `dogonomics`
4. Creates user `dogonomics` with password `dogonomics_password`
5. Grants all privileges
6. Initializes the database schema from `internal/database/schema.sql`
7. Validates the setup by checking tables and TimescaleDB extension

**Troubleshooting:**
- If `psql` is not found, add PostgreSQL bin directory to your PATH
  - Default: `C:\Program Files\PostgreSQL\16\bin`
- If a previous run failed, you can:
  ```sql
  DROP DATABASE IF EXISTS dogonomics;
  DROP USER IF EXISTS dogonomics;
  ```
  Then run the setup script again.

### Docker Compose Setup

```yaml
# Included services in docker-compose.yml:
services:
  timescaledb:      # PostgreSQL with TimescaleDB extension
  redis:            # In-memory cache
  dogonomics:       # API server
  dogonomics-onnx:  # API with BERT sentiment (optional)
  prometheus:       # Metrics collector
  grafana:          # Metrics visualization
  kafka:            # Event streaming (optional)
  zookeeper:        # Kafka coordinator (optional)
```

**Start Docker services:**
```powershell
# Standard stack (API + DB + Redis + Monitoring)
docker compose up --build

# With BERT sentiment analysis
docker compose --profile onnx up --build

# With Kafka event streaming
docker compose --profile kafka up --build

# With everything
docker compose --profile onnx --profile kafka up --build
```

**Environment variables used by Docker:**
```env
DB_USER=dogonomics                      # PostgreSQL username
DB_PASSWORD=dogonomics_password         # PostgreSQL password
DB_NAME=dogonomics                      # Database name
FINNHUB_API_KEY=<your_api_key>         # Required for stocks API
PORT=8080                               # API port
GRAFANA_PASSWORD=admin                  # Grafana admin password
```

## 🔧 Configuration

### .env File

Copy `.env.example` to `.env` and fill in your API keys:

```env
# Required API Keys
FINNHUB_API_KEY=your_key_here
POLYGON_API_KEY=your_key_here
EODHD_API_KEY=your_key_here
ALPHA_VANTAGE_API_KEY=your_key_here
GNEWS_API_KEY=your_key_here

# Database (for local setup)
DB_HOST=localhost
DB_PORT=5432
DB_USER=dogonomics
DB_PASSWORD=dogonomics_password
DB_NAME=dogonomics
DB_SSLMODE=disable

# Application
PORT=8080
GIN_MODE=debug
```

**Where to get API keys:**
- [Finnhub](https://finnhub.io) - Stock data
- [Polygon.io](https://polygon.io) - Ticker data
- [EODHD](https://eodhd.com) - Financial news
- [Alpha Vantage](https://www.alphavantage.co) - Commodities
- [GNews](https://gnews.io) - General news

### Database Configuration

**Connection pool settings** (in `internal/database/connection.go`):
- Max connections: 10
- Min connections: 2
- Max connection lifetime: 1 hour
- Max idle time: 30 minutes

**Timeouts:**
- Default query timeout: 30 seconds (can be configured via context)
- Connection health check: every 1 minute

## 📊 Database Schema

The database uses **TimescaleDB** (PostgreSQL 14 with time-series optimization) with the following tables:

### Hypertables (Time-Series Data)
- **api_requests** - API request logging (30-day retention)
- **stock_quotes** - Real-time stock data
- **news_items** - Financial news articles
- **sentiment_analysis** - FinBERT sentiment results
- **chart_data** - Historical OHLCV data
- **treasury_data** - Treasury yields (90-day retention)
- **commodity_data** - Commodity prices (90-day retention)

### Regular Tables
- **company_profiles** - Company metadata
- **aggregate_sentiment** - Daily sentiment rollups

### Views & Aggregates
- `recent_sentiment_with_news` - Joined sentiment + news data
- `daily_sentiment_summary` - Continuous aggregate (refreshes every 30 min)

## ✅ Verification

### Check Database Connection

```powershell
# For local PostgreSQL setup
.\test-db-connection.bat

# Or manually:
psql -U dogonomics -h localhost -d dogonomics -c "SELECT version();"
```

### Check API Health

```bash
# Once the API is running:
curl http://localhost:8080/health

# View Swagger docs:
# http://localhost:8080/swagger/index.html
```

### Check Docker Services

```powershell
# View all services
docker compose ps

# View logs for a specific service
docker compose logs timescaledb
docker compose logs dogonomics

# View real-time logs
docker compose logs -f dogonomics
```

## 🔍 Monitoring & Debugging

### Prometheus (Metrics)
- **URL:** http://localhost:9090
- **Targets:** Shows health of scraped metrics endpoints

### Grafana (Dashboards)
- **URL:** http://localhost:3000
- **Default:** admin / admin
- **Dashboards:** API performance, database metrics

### View API Logs

```powershell
# Docker
docker compose logs -f dogonomics

# Local
# Logs to console and to database (api_requests table)
```

### View Database Logs

```powershell
# Docker
docker compose logs -f timescaledb

# Local PostgreSQL
# Logs typically at: C:\Program Files\PostgreSQL\16\data\log\
```

## 🐛 Troubleshooting

### "PostgreSQL not found" / `psql` command not working

**Solution:** Add PostgreSQL to PATH
```powershell
# Find your PostgreSQL installation
Get-Command psql  # Check if it exists

# If not found, add to PATH permanently:
# Settings → System → Advanced system settings → Environment Variables
# Add: C:\Program Files\PostgreSQL\16\bin
```

### "Database dogonomics already exists"

**Solution:** Drop and recreate
```powershell
# Stop using the database first
# Then run as postgres user:
psql -U postgres -h localhost -c "DROP DATABASE IF EXISTS dogonomics;"
psql -U postgres -h localhost -c "DROP USER IF EXISTS dogonomics;"

# Then run setup script again
.\setup-local-postgres.ps1
```

### Docker container won't start

**Solution:** Check for port conflicts
```powershell
# See what's using port 5432
netstat -ano | findstr :5432

# Or stop existing containers
docker ps  # List running containers
docker stop <container_id>

# Restart Docker setup
docker compose down
docker compose up --build
```

### "Connection refused" when running API

**Solutions:**
1. Ensure PostgreSQL/Redis are running:
   ```powershell
   # Check Docker services
   docker compose ps
   
   # Check local processes
   Get-Process postgres
   Get-Process redis
   ```

2. Verify .env file has correct connection details
3. Check database is initialized:
   ```powershell
   psql -U dogonomics -h localhost -d dogonomics -c "\dt"
   ```

### "No tables in database" after setup

**Solution:** Manually reinitialize schema
```powershell
# Set password in environment
$env:PGPASSWORD = "dogonomics_password"

# Run schema initialization
psql -U dogonomics -h localhost -d dogonomics -f "internal\database\schema.sql"

# Clear password
$env:PGPASSWORD = $null
```

### API starts but database features not working

**Cause:** Database connection failed but app continued (graceful degradation)
**Solution:** 
1. Check app logs for "Database connection failed" message
2. Verify connection details in .env
3. Verify database is running and healthy
4. Restart the API

## 📚 Additional Resources

- **Go Documentation:** https://golang.org/doc/
- **PostgreSQL:** https://www.postgresql.org/docs/
- **TimescaleDB:** https://docs.timescale.com/
- **Gin Web Framework:** https://gin-gonic.com/
- **Docker Compose:** https://docs.docker.com/compose/
- **Grafana:** https://grafana.com/docs/grafana/

## 💡 Tips for Development

1. **Use Docker for database** - Easier than local setup, no persistent data to manage
2. **Keep .env in .gitignore** - Never commit secrets
3. **Use `gin` mode for faster reloading:**
   ```env
   GIN_MODE=debug  # Auto-reloads on file changes
   ```
4. **Monitor database metrics** - Use Grafana to watch query performance
5. **Check logs frequently** - Both app and database logs help debug issues

## 🆘 Getting Help

- Check this guide's Troubleshooting section
- Review application logs: `docker compose logs` or console output
- Check database health: `psql` commands or Grafana
- Review API responses: Swagger docs at `/swagger/index.html`

---

**Last updated:** March 2026  
**Tested with:** Go 1.24.5, PostgreSQL 14, Docker Desktop, Windows 11
