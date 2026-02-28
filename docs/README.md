# Dogonomics API Docs

This folder documents how to explore and test the Dogonomics API.

## Quick Links

| Service          | URL                                              |
|------------------|--------------------------------------------------|
| Swagger UI       | <http://localhost:8080/swagger/index.html>       |
| OpenAPI JSON     | <http://localhost:8080/swagger/doc.json>         |
| Prometheus       | <http://localhost:8080/metrics>                  |
| Grafana (Docker) | <http://localhost:3000> (admin / admin)          |

## Endpoints

All endpoints are documented in Swagger with parameters and example responses.

### Stock & Market Data

| Method | Path                 | Description                  |
|--------|----------------------|------------------------------|
| GET    | `/ticker/:symbol`    | Aggregated ticker data       |
| GET    | `/quote/:symbol`     | Current quote (Finnhub)      |
| GET    | `/profile/:symbol`   | Company profile              |
| GET    | `/stock/:symbol`     | Comprehensive stock detail   |
| GET    | `/chart/:symbol`     | Historical price data        |

### News & Sentiment

| Method | Path                        | Description                              |
|--------|-----------------------------|------------------------------------------|
| GET    | `/finnews/:symbol`          | Company news (EODHD)                     |
| GET    | `/finnewsBert/:symbol`      | News with FinBERT sentiment + aggregate  |
| GET    | `/sentiment/:symbol`        | Aggregate sentiment only                 |
| POST   | `/finbert/inference`        | Run FinBERT on custom text               |
| GET    | `/news/general`             | General market news (multi-source)       |
| GET    | `/news/general/sentiment`   | General news with FinBERT analysis       |
| GET    | `/news/symbol/:symbol`      | Multi-source symbol news                 |
| GET    | `/news/search?q=keyword`    | Search news by keyword                   |

### Treasury & Bonds

| Method | Path                    | Description                    |
|--------|-------------------------|--------------------------------|
| GET    | `/treasury/yield-curve` | Latest yield curve             |
| GET    | `/treasury/rates`       | Historical rates (query: days) |
| GET    | `/treasury/debt`        | Public debt data (query: days) |

### Commodities

| Method | Path                        | Description                      |
|--------|-----------------------------|----------------------------------|
| GET    | `/commodities/oil`          | Oil prices (query: type=wti/brent)|
| GET    | `/commodities/gas`          | Natural gas prices               |
| GET    | `/commodities/metals`       | Metals (query: metal=copper/aluminum) |
| GET    | `/commodities/agriculture`  | Agriculture (query: commodity=wheat/corn/...) |

### System

| Method | Path       | Description        |
|--------|------------|--------------------|
| GET    | `/health`  | Health check       |
| GET    | `/metrics` | Prometheus metrics |

## Environment Variables

Create a `.env` file in the repository root:

| Variable              | Required | Description                       |
|-----------------------|----------|-----------------------------------|
| `FINNHUB_API_KEY`     | Yes      | Finnhub quotes, profiles          |
| `EODHD_API_KEY`       | No       | EODHD news                        |
| `ALPHA_VANTAGE_API_KEY`| No      | Commodities, Alpha Vantage news   |
| `POLYGON_API_KEY`     | No       | Polygon ticker & chart data       |
| `DB_HOST`             | No       | PostgreSQL host (default: localhost) |
| `DB_PORT`             | No       | PostgreSQL port (default: 5432)   |
| `DB_USER`             | No       | Database user (default: dogonomics)|
| `DB_PASSWORD`         | No       | Database password                 |
| `DB_NAME`             | No       | Database name (default: dogonomics)|

## Run Locally

```bash
go run dogonomics.go
```

Open Swagger at <http://localhost:8080/swagger/index.html>.

## Run with Docker

```bash
docker compose up --build
```

- API: <http://localhost:8080>
- Prometheus: <http://localhost:9090>
- Grafana: <http://localhost:3000>

## FinBERT / ONNX Notes

- Default Docker build excludes ONNX via build tags and uses a stub.
- To enable ONNX in Docker, provide a base image with ONNX Runtime and build with `-tags=onnx`.
- Locally, ensure ONNX Runtime is installed (see `runtimesetup.bat`).

## Further Reading

- [ONNX & FinBERT Devlog](ortinference.md)
- [ROI with Sentiment Analysis](ROI_with_Sentiment_Analysis.md)
- [Treasury & Commodities API Guide](TREASURY_COMMODITIES.md)
