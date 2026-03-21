# Backend Architecture

## Runtime Entry

- Current build target entrypoint: `cmd/dogonomics/main.go`
- Backward-compatible root entrypoint remains: `dogonomics.go`
- Router: Gin
- API docs: Swagger (`/swagger/index.html`)

## Core Modules

- `internal/handler/controller/` HTTP handlers
- `internal/middleware/` security, rate limiting, cache, logging
- `internal/database/` TimescaleDB
- `internal/cache/` Redis
- `internal/ws/` WebSocket hub and tickers
- `internal/events/` Kafka publishing
- `internal/service/sentiment/` sentiment orchestration
- `internal/service/bertinference/` ONNX-backed inference

## Security Pipeline

1. CORS
2. Rate limiting (IP + API key)
3. API key allowlist
4. Firebase auth
5. User-level rate limiting
6. Logging and cache middleware

## Data and Realtime

- External provider fetches are persisted asynchronously.
- WebSocket streams serve quotes and news.
- Sentiment workloads use serialized FinBERT queueing for overload protection.
