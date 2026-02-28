# Dogonomics Documentation

Comprehensive reference for the Dogonomics API backend — database setup, API endpoints, BERT inference, Docker deployment, and troubleshooting.

---

## Table of Contents

- [Dogonomics Documentation](#dogonomics-documentation)
  - [Table of Contents](#table-of-contents)
  - [Database Setup](#database-setup)
    - [Docker Compose (Recommended)](#docker-compose-recommended)
    - [Local PostgreSQL](#local-postgresql)
    - [Schema Overview](#schema-overview)
    - [TimescaleDB](#timescaledb)
  - [API Endpoints](#api-endpoints)
    - [Stock \& Market Data](#stock--market-data)
    - [News](#news)
    - [Sentiment Analysis](#sentiment-analysis)
    - [Treasury](#treasury)
    - [Commodities](#commodities)
    - [Infrastructure](#infrastructure)
  - [FinBERT Inference](#finbert-inference)
    - [POST /finbert/inference](#post-finbertinference)
    - [ONNX Runtime Integration](#onnx-runtime-integration)
  - [Docker Deployment](#docker-deployment)
    - [Standard Build](#standard-build)
    - [ONNX-Enabled Build](#onnx-enabled-build)
    - [Full Stack](#full-stack)
  - [Redis Caching](#redis-caching)
  - [Monitoring](#monitoring)
    - [Prometheus](#prometheus)
    - [Grafana](#grafana)
    - [Health Check](#health-check)
  - [ROI with Sentiment Analysis](#roi-with-sentiment-analysis)
  - [Troubleshooting](#troubleshooting)
    - [Database](#database)
    - [Redis](#redis)
    - [BERT / ONNX](#bert--onnx)
    - [PostgreSQL Local Setup](#postgresql-local-setup)
    - [Maintenance](#maintenance)

---

## Database Setup

Dogonomics uses **TimescaleDB** (PostgreSQL 14 + TimescaleDB extension) for time-series data storage. The pgx/v5 driver connects natively — no special Go client needed.

### Docker Compose (Recommended)

```bash
# Start full stack (TimescaleDB + Redis + API + Prometheus + Grafana)
docker compose up --build

# Stop all services
docker compose down
```

The database is automatically initialised from `internal/database/schema.sql` on first start.

**Default credentials** (override in `.env`):

| Setting    | Value              |
|------------|--------------------|
| Host       | `localhost` / `timescaledb` (in-container) |
| Port       | `5432`             |
| Database   | `dogonomics`       |
| User       | `dogonomics`       |
| Password   | `dogonomics`       |

### Local PostgreSQL

If you prefer running the database without Docker:

1. **Install PostgreSQL 14+** from [postgresql.org](https://www.postgresql.org/download/windows/).
2. Run the setup script:
   ```powershell
   .\setup-local-postgres.ps1    # PowerShell (recommended)
   .\setup-local-postgres.bat    # or CMD
   ```
3. Verify the connection:
   ```bat
   .\test-db-connection.bat
   ```
4. Configure `.env`:
   ```env
   DB_HOST=localhost
   DB_PORT=5432
   DB_USER=dogonomics
   DB_PASSWORD=dogonomics
   DB_NAME=dogonomics
   DB_SSLMODE=disable
   ```

> **Note:** Local PostgreSQL does not include the TimescaleDB extension by default. Install it separately or use the Docker image `timescale/timescaledb:latest-pg14` for full hypertable support.

### Schema Overview

| Table                  | Type        | Description |
|------------------------|-------------|-------------|
| `api_requests`         | Hypertable  | API request logs, auto-retained 30 days |
| `stock_quotes`         | Hypertable  | Real-time stock quotes with prices |
| `news_items`           | Hypertable  | Financial news articles (deduplicated) |
| `sentiment_analysis`   | Hypertable  | BERT sentiment scores per article |
| `chart_data`           | Hypertable  | Historical OHLCV chart data |
| `company_profiles`     | Regular     | Company info cache (lookup table) |
| `aggregate_sentiment`  | Regular     | Rolled-up sentiment by symbol/period |

**Views & Aggregates:**
- `recent_sentiment_with_news` — joins sentiment with news articles
- `daily_sentiment_summary` — continuous aggregate (TimescaleDB), refreshed every 30 min

**Functions:**
- `get_sentiment_trend(symbol, days)` — daily sentiment trend using `time_bucket`

### TimescaleDB

The schema uses TimescaleDB features:

- **Hypertables**: Automatic time-based partitioning for all time-series tables.
- **Continuous Aggregates**: `daily_sentiment_summary` is a materialised view refreshed by TimescaleDB every 30 minutes.
- **Retention Policies**: `api_requests` chunks older than 30 days are automatically dropped.
- **`time_bucket()`**: Used in `get_sentiment_trend()` for efficient grouped time queries.

Conventional `PRIMARY KEY` constraints are replaced by composite keys `(id, time_column)` on hypertables. Foreign keys referencing hypertables are not enforced (TimescaleDB limitation).

**Useful queries:**
```sql
-- Sentiment trend over 30 days
SELECT * FROM get_sentiment_trend('AAPL', 30);

-- Daily summary from continuous aggregate
SELECT * FROM daily_sentiment_summary WHERE symbol = 'AAPL' ORDER BY bucket DESC LIMIT 7;

-- Recent API logs
SELECT * FROM api_requests ORDER BY timestamp DESC LIMIT 20;

-- Database & table sizes
SELECT pg_size_pretty(pg_database_size('dogonomics'));
```

---

## API Endpoints

Base URL: `http://localhost:{PORT}` (default 8080). Swagger UI at `/swagger/index.html`.

### Stock & Market Data

| Method | Path | Description |
|--------|------|-------------|
| GET | `/ticker/:symbol` | Polygon.io ticker details |
| GET | `/quote/:symbol` | Real-time stock quote (Finnhub) |
| GET | `/stock/:symbol` | Aggregated detail (quote + profile + chart + news) |
| GET | `/profile/:symbol` | Company profile |
| GET | `/chart/:symbol` | Historical OHLCV chart data |

### News

| Method | Path | Description |
|--------|------|-------------|
| GET | `/finnews/:symbol` | Company news (Finnhub) |
| GET | `/news/general` | General finance news |
| GET | `/news/symbol/:symbol` | Multi-source news by symbol |
| GET | `/news/search?q=keyword` | Search news by keyword |

### Sentiment Analysis

| Method | Path | Description |
|--------|------|-------------|
| GET | `/finnewsBert/:symbol` | News + BERT sentiment per article |
| GET | `/sentiment/:symbol` | Aggregate sentiment only |
| GET | `/news/general/sentiment` | General news with BERT sentiment |
| POST | `/finbert/inference` | Analyse custom text (see below) |

### Treasury

All treasury endpoints use the **US Treasury Fiscal Data API** (free, no key needed).

| Method | Path | Description |
|--------|------|-------------|
| GET | `/treasury/yield-curve` | Latest yield rates across maturities |
| GET | `/treasury/rates?days=N` | Historical daily rates (default 30, max 365) |
| GET | `/treasury/debt?days=N` | Public debt to the penny (default 90, max 365) |

### Commodities

Requires `ALPHA_VANTAGE_API_KEY` (free tier: 25 calls/day).

| Method | Path | Params | Description |
|--------|------|--------|-------------|
| GET | `/commodities/oil` | `type=wti\|brent` | Crude oil prices |
| GET | `/commodities/gas` | — | Natural gas prices |
| GET | `/commodities/metals` | `metal=copper\|aluminum` | Industrial metals |
| GET | `/commodities/agriculture` | `commodity=wheat\|corn\|cotton\|sugar\|coffee` | Agriculture prices |

### Infrastructure

| Method | Path | Description |
|--------|------|-------------|
| GET | `/health` | Service health + database status |
| GET | `/metrics` | Prometheus metrics |
| GET | `/swagger/*` | Swagger UI & JSON spec |

---

## FinBERT Inference

### POST /finbert/inference

Analyse arbitrary text with the DoggoFinBERT model (ONNX-optimised FinancialBERT).

**Request:**
```json
{ "text": "Apple reported strong quarterly earnings, beating analyst expectations." }
```

**Response:**
```json
{
  "label": "positive",
  "confidence": 0.9234,
  "score": { "positive": 0.9234, "negative": 0.0512, "neutral": 0.0254 }
}
```

- `label`: `positive`, `negative`, or `neutral`
- `confidence`: 0.0–1.0 for the predicted label
- `score`: per-class probabilities

**Tips:** 50–200 words works best. The model is trained on financial text. Inference takes ~200ms typical, up to several seconds on slow hardware — use a 60s client timeout.

### ONNX Runtime Integration

The ML pipeline: **Python PyTorch → ONNX export → Go ONNX Runtime**.

- Model: `sentAnalysis/DoggoFinBERT.onnx` (~438 MB)
- Tokeniser: WordPiece algorithm with FinBERT vocabulary (`sentAnalysis/finbert/vocab.txt`)
- Go binding: `github.com/yalue/onnxruntime_go`
- Build tag: `//go:build onnx` — the standard build uses a no-op stub

Tokenisation produces three tensors (`input_ids`, `attention_mask`, `token_type_ids`) that are fed to the ONNX session. The output logits are softmaxed to produce per-class probabilities.

---

## Docker Deployment

### Standard Build

```bash
docker build -t dogonomics:latest .
docker run --env-file .env -p 8080:8080 dogonomics:latest
```

The standard image is CGO-disabled (~15 MB binary). BERT endpoints return a "disabled" stub.

### ONNX-Enabled Build

```bash
docker build -f Dockerfile.onnx -t dogonomics:onnx .
docker run --env-file .env -p 8080:8080 dogonomics:onnx
```

Includes ONNX Runtime 1.17.1 with CGO enabled. Full BERT inference available. (~25 MB binary + shared libs).

### Full Stack

```bash
# Standard API + TimescaleDB + Redis + monitoring
docker compose up --build

# Include ONNX variant on port 8081
docker compose --profile onnx up --build
```

| Service | Port | Description |
|---------|------|-------------|
| `dogonomics` | `${PORT:-8080}` | Standard API |
| `dogonomics-onnx` | `${ONNX_PORT:-8081}` | ONNX-enabled API (profile: onnx) |
| `timescaledb` | 5432 | TimescaleDB (PostgreSQL 14) |
| `redis` | 6379 | Redis 7 cache |
| `prometheus` | 9090 | Metrics |
| `grafana` | 3000 | Dashboards (admin/admin) |

**Local ONNX development (Windows):**
```powershell
$env:CGO_ENABLED="1"
$env:CGO_CFLAGS="-IC:\onnxruntime\include"
$env:CGO_LDFLAGS="-LC:\onnxruntime\lib -lonnxruntime"
$env:Path="$env:Path;C:\onnxruntime\lib"
go run -tags onnx .\dogonomics.go
```

Or use the batch scripts: `runtimesetup.bat`, `build.bat`, `run.bat`.

---

## Redis Caching

The API caches GET responses in Redis with per-endpoint TTLs. If Redis is unavailable, requests pass through uncached (graceful degradation).

**TTL schedule:**

| Endpoint pattern | TTL |
|------------------|-----|
| `/quote/` | 2 min |
| `/ticker/`, `/stock/`, `/news/search` | 5 min |
| `/finnews/`, `/news/general`, `/news/symbol/` | 10 min |
| `/finnewsBert/`, `/sentiment/`, `/news/general/sentiment` | 15 min |
| `/chart/`, `/commodities/` | 30 min |
| `/profile/`, `/treasury/` | 1 hour |

Skipped: `/health`, `/metrics`, `/swagger/*`, POST requests.

Responses include `X-Cache: HIT` or `X-Cache: MISS` header.

**Configuration (`.env`):**
```env
REDIS_HOST=localhost   # default
REDIS_PORT=6379        # default
REDIS_PASSWORD=        # default empty
REDIS_DB=0             # default
```

---

## Monitoring

### Prometheus

Metrics at `/metrics` include:
- `http_requests_total` (counter) — labelled by service, method, handler, status class
- `http_request_duration_seconds` (histogram) — labelled by service, method, handler

Prometheus config: `monitoring/prometheus.yml`

### Grafana

Available at `http://localhost:3000` (admin/admin). Provisioning files in `monitoring/grafana/provisioning/`.

### Health Check

```bash
curl http://localhost:8080/health
```

Returns database connectivity, TimescaleDB version (when available), and feature status.

---

## ROI with Sentiment Analysis

Sentiment analysis can supplement investment research but is **not financial advice**.

**Approach:**
1. **Aggregate scores** — collect sentiment over time via `/finnewsBert/:symbol` or `/sentiment/:symbol`.
2. **Correlate with price** — compare historical sentiment with stock price movements.
3. **Build signals** — strong positive sentiment may indicate upward momentum; strong negative may indicate downward pressure.
4. **Backtest** — validate on historical data before acting.

**Caveats:** correlation ≠ causation; markets are volatile; data quality matters; always consult a qualified financial advisor.

---

## Troubleshooting

### Database

| Symptom | Fix |
|---------|-----|
| `WARNING: Database connection failed` | Check PostgreSQL is running, verify `.env` vars |
| `relation "api_requests" does not exist` | Run schema.sql: `psql -U dogonomics -d dogonomics -f internal/database/schema.sql` |
| Port 5432 in use | Stop other PostgreSQL instances or change `DB_PORT` |
| Pool connections busy | Increase `MaxConns` in `connection.go` (default 10) |

### Redis

| Symptom | Fix |
|---------|-----|
| `WARNING: Redis connection failed` | Check Redis is running, verify `REDIS_HOST`/`REDIS_PORT` |
| Stale cache data | Restart Redis or wait for TTL expiry |

### BERT / ONNX

| Symptom | Fix |
|---------|-----|
| `ONNX runtime disabled` | Build with `-tags onnx` and ONNX Runtime installed |
| `cannot find -lonnxruntime` | Check `CGO_CFLAGS`/`CGO_LDFLAGS` point to ONNX lib |
| `error while loading shared libraries` | Set `LD_LIBRARY_PATH` or copy libs to `/usr/local/lib` |
| BERT disabled in Docker | Use `Dockerfile.onnx`, check model + vocab files are copied |

### PostgreSQL Local Setup

| Symptom | Fix |
|---------|-----|
| `psql: command not found` | Add `C:\Program Files\PostgreSQL\16\bin` to PATH |
| Password auth failed | Check postgres password; edit `pg_hba.conf` to use `md5` or `trust` temporarily |
| Database already exists | Safe to ignore — schema will be updated |

### Maintenance

```bash
# Backup
docker exec dogonomics-timescaledb pg_dump -U dogonomics dogonomics > backup.sql

# Restore
docker exec -i dogonomics-timescaledb psql -U dogonomics dogonomics < backup.sql

# Reset (WARNING: deletes data)
docker compose down
docker volume rm dogonomics_go_backened_postgres_data
docker compose up -d
```
