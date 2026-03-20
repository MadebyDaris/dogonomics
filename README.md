# Dogonomics

A Go backend for real-time stock data, financial news aggregation, and FinBERT-powered sentiment analysis. Built with Gin, TimescaleDB, Redis, Prometheus, and ONNX Runtime.

## Project Structure

```
dogonomics.go                  # Entry point — routing, middleware, signal handling
controller/                    # HTTP handlers (Swagger-annotated)
internal/
  DogonomicsFetching/          # Finnhub API client (quotes, profiles, financials)
  DogonomicsProcessing/        # Shared data models (StockDetailData, ChartDataPoint, etc.)
  mcpgateway/                  # MCP server over SSE (resources, tools, prompts)
  PolygonClient/               # Polygon.io client (tickers, historical OHLCV)
  NewsClient/                  # Multi-source news aggregation (Finnhub, EODHD, Alpha Vantage)
  TreasuryClient/              # US Treasury Fiscal Data API client
  CommoditiesClient/           # Alpha Vantage commodities client
  database/                    # TimescaleDB connection pool, queries, schema
  cache/                       # Redis caching layer
  ws/                          # WebSocket hub, client, ticker (real-time streaming)
  events/                      # Kafka producer (event publishing)
  workerpool/                  # Bounded concurrent task execution
sentAnalysis/                  # EODHD news fetching + FinBERT sentiment pipeline
BertInference/                 # ONNX Runtime FinBERT model loading & inference
middleware/                    # Gin middleware (database logger, response cache)
monitoring/                    # Prometheus & Grafana config
docs/                          # Swagger generated docs
```

## Quick Start

### 🚀 **Start Here:** [GETTING_STARTED.md](GETTING_STARTED.md)
A complete step-by-step checklist to get the backend running (15-30 minutes).

### Option 1: Docker (Recommended)
```bash
# 1. Make sure you have Docker installed
# 2. Copy .env template and add your API keys
cp .env.example .env

# 3. Start the full stack
docker compose up --build

# 4. Open Swagger UI
# http://localhost:8080/swagger/index.html
```

### Option 2: Local PostgreSQL (Automated)
```bash
# 1. Make sure you have PostgreSQL installed
# 2. Run automated setup (detects your PostgreSQL superuser)
.\setup-local-postgres-automated.ps1

# 3. Copy .env and add API keys
cp .env.example .env

# 4. Run the backend
go run dogonomics.go

# 5. Open Swagger UI
# http://localhost:8080/swagger/index.html
```

### Option 3: Local Everything
See [SETUP_GUIDE.md](SETUP_GUIDE.md) for detailed instructions.

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
| `KAFKA_BROKER`         | No       | Kafka broker address (enables event publishing) |
| `API_KEY_REQUIRED`     | No       | Require API key auth (recommended: true in production) |
| `API_ALLOWED_KEYS`     | No       | Comma-separated API key allowlist |
| `API_KEY`              | No       | Single API key alias (legacy/convenience) |
| `RATE_LIMIT_RPM`       | No       | Fallback global requests/minute limit |
| `RATE_LIMIT_RPM_IP`    | No       | Per-IP requests/minute limit |
| `RATE_LIMIT_RPM_KEY`   | No       | Per-API-key requests/minute limit |
| `RATE_LIMIT_RPM_USER`  | No       | Per-authenticated-user requests/minute limit |
| `BERT_MAX_CONCURRENCY` | No       | Max concurrent FinBERT inferences (recommended: 1) |
| `BERT_QUEUE_TIMEOUT_SECONDS` | No | Queue wait timeout before FinBERT request fails |
| `MCP_ENABLED`          | No       | Enable MCP SSE server (default: true) |
| `MCP_ADDR`             | No       | MCP listen address (default: :8081) |
| `MCP_BASE_URL`         | No       | Public MCP base URL (default: http://localhost:8081) |

## MCP Server

The backend now includes an MCP gateway exposed over SSE on a separate port.

- Default SSE endpoint: `http://localhost:8081/mcp/sse`
- Default message endpoint: `http://localhost:8081/mcp/message`
- Transport: SSE

Initial MCP surface area:

- Resources: health, OHLCV history, stored sentiment trend
- Tools: latest quote, latest symbol news, live sentiment analysis, company profile
- Prompts: sentiment-shift explanation, symbol-state summary

This first pass is additive. Existing REST and WebSocket endpoints remain unchanged.

## Docker

```bash
# Full stack (API + TimescaleDB + Redis + Prometheus + Grafana)
docker compose up --build

# Include ONNX variant with BERT on port 8081
docker compose --profile onnx up --build

# Include Kafka + Zookeeper for event publishing
docker compose --profile kafka up --build

# Everything (ONNX + Kafka)
docker compose --profile onnx --profile kafka up --build
```

Services: API (`:${PORT:-8080}`), TimescaleDB (:5432), Redis (:6379), Prometheus (:9090), Grafana (:3000), Kafka (:9092, opt-in).

## Architecture

- **TimescaleDB** for time-series storage — hypertables, continuous aggregates, automatic retention.
- **Redis** caching with per-endpoint TTLs (2 min – 1 hr). Graceful degradation if unavailable.
- **WebSockets** (gorilla/websocket) — server-push real-time quotes and news at `/ws/quotes/:symbol` and `/ws/news`.
- **Kafka** (segmentio/kafka-go) — event publishing to topics on every data fetch. Opt-in via Docker profile.
- **Full data persistence** — every handler that fetches external API data persists it to TimescaleDB asynchronously.
- **Database query endpoints** — `/db/*` routes expose stored sentiment history, trends, and request analytics.
- **Goroutines + WaitGroup**: API clients fetch data concurrently.
- **Worker Pool**: `internal/workerpool` for bounded batch BERT inference.
- **Context Cancellation**: All API calls accept `context.Context` for graceful shutdown.

## Documentation

See [DOCS.md](DOCS.md) for full reference: database setup, API endpoints, FinBERT inference, Docker deployment, caching, monitoring, and troubleshooting.

## License

See [LICENCE](LICENCE).
