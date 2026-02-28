# Dogonomics

A Go backend for real-time stock data, financial news aggregation, and FinBERT-powered sentiment analysis. Built with Gin, TimescaleDB, Redis, Prometheus, and ONNX Runtime.

## Project Structure

```
dogonomics.go                  # Entry point — routing, middleware, signal handling
controller/                    # HTTP handlers (Swagger-annotated)
internal/
  DogonomicsFetching/          # Finnhub API client (quotes, profiles, financials)
  DogonomicsProcessing/        # Shared data models (StockDetailData, ChartDataPoint, etc.)
  PolygonClient/               # Polygon.io client (tickers, historical OHLCV)
  NewsClient/                  # Multi-source news aggregation (Finnhub, EODHD, Alpha Vantage)
  TreasuryClient/              # US Treasury Fiscal Data API client
  CommoditiesClient/           # Alpha Vantage commodities client
  database/                    # TimescaleDB connection pool, queries, schema
  cache/                       # Redis caching layer
  workerpool/                  # Bounded concurrent task execution
sentAnalysis/                  # EODHD news fetching + FinBERT sentiment pipeline
BertInference/                 # ONNX Runtime FinBERT model loading & inference
middleware/                    # Gin middleware (database logger, response cache)
monitoring/                    # Prometheus & Grafana config
docs/                          # Swagger generated docs
```

## Quick Start

```bash
# 1. Set environment variables
cp .env.example .env   # then fill in your API keys

# 2. Run with Docker (recommended)
docker compose up --build

# 3. Or run locally
go run dogonomics.go

# 4. Open Swagger UI
# http://localhost:8080/swagger/index.html
```

## Environment Variables

| Variable               | Required | Description                          |
|------------------------|----------|--------------------------------------|
| `FINNHUB_API_KEY`      | Yes      | Stock quotes, company profiles       |
| `EODHD_API_KEY`        | No       | EODHD news feed                      |
| `ALPHA_VANTAGE_API_KEY`| No       | Commodities & Alpha Vantage news     |
| `POLYGON_API_KEY`      | No       | Polygon.io ticker & chart data       |
| `PORT`                 | No       | Server port (default: 8080)          |
| `DB_HOST`              | No       | TimescaleDB host (default: localhost) |
| `DB_PORT`              | No       | TimescaleDB port (default: 5432)     |
| `DB_USER`              | No       | Database user (default: dogonomics)  |
| `DB_PASSWORD`          | No       | Database password                    |
| `DB_NAME`              | No       | Database name (default: dogonomics)  |
| `REDIS_HOST`           | No       | Redis host (default: localhost)      |
| `REDIS_PORT`           | No       | Redis port (default: 6379)           |

## Docker

```bash
# Full stack (API + TimescaleDB + Redis + Prometheus + Grafana)
docker compose up --build

# Include ONNX variant with BERT on port 8081
docker compose --profile onnx up --build
```

Services: API (`:${PORT:-8080}`), TimescaleDB (:5432), Redis (:6379), Prometheus (:9090), Grafana (:3000).

## Architecture

- **TimescaleDB** for time-series storage — hypertables, continuous aggregates, automatic retention.
- **Redis** caching with per-endpoint TTLs (2 min – 1 hr). Graceful degradation if unavailable.
- **Goroutines + WaitGroup**: API clients fetch data concurrently.
- **Worker Pool**: `internal/workerpool` for bounded batch BERT inference.
- **Context Cancellation**: All API calls accept `context.Context` for graceful shutdown.

## Documentation

See [DOCS.md](DOCS.md) for full reference: database setup, API endpoints, FinBERT inference, Docker deployment, caching, monitoring, and troubleshooting.

## License

See [LICENCE](LICENCE).
