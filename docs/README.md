# Dogonomics API Docs

This folder documents how to explore and test the Dogonomics API using Swagger UI, monitor it with Prometheus and Grafana, and run it locally or with Docker.

## Quick links

- Swagger UI: <http://localhost:8080/swagger/index.html>
- OpenAPI JSON: <http://localhost:8080/swagger/doc.json>
- Prometheus metrics: <http://localhost:8080/metrics>
- Grafana (docker-compose): <http://localhost:3000> (user: admin, pass: admin)

## Endpoints overview

All endpoints are documented in Swagger with parameters and example responses. Highlights:

- GET /ticker/{symbol} — Aggregated ticker data for the specified date (query: date=YYYY-MM-DD)
- GET /quote/{symbol} — Current quote via Finnhub
- GET /finnews/{symbol} — Recent news from EODHD
- GET /finnewsBert/{symbol} — News with BERT sentiment + aggregate
- GET /sentiment/{symbol} — Aggregate sentiment only
- GET /stock/{symbol} — Comprehensive stock details
- GET /profile/{symbol} — Company profile
- GET /chart/{symbol} — Historical price data (query: days)
- GET /health — Service health

## Try it out in Swagger

1. Start the API (locally or via docker-compose).
2. Open Swagger UI at <http://localhost:8080/swagger/index.html>.
3. Expand an endpoint, click “Try it out”, fill required params (e.g., AAPL), and Execute.
4. Responses are returned directly in the browser.

If an endpoint relies on external APIs, make sure the corresponding environment variables are set (see below).

## Environment variables

Create a .env file in the repository root (same folder as dogonomics.go):

- FINNHUB_API_KEY: Required for quote and some profile data
- EODHD_API_KEY: Required for EODHD news

## Run locally

You can run the server directly with Go:

1. Install Go (matching the version in go.mod).
2. Set environment variables in .env.
3. Run: go run dogonomics.go
4. Open Swagger at <http://localhost:8080/swagger/index.html>

Notes:

- Sentiment (FinBERT ONNX) is optional at runtime. The default build in Docker disables ONNX to avoid CGO issues. To enable ONNX, build with the onnx tag and ensure ONNX dependencies are installed.

## Run with Docker

Build and start everything (API + Prometheus + Grafana) with docker-compose in the repo root:

- docker compose up --build

Then visit:

- API: <http://localhost:8080>
- Swagger UI: <http://localhost:8080/swagger/index.html>
- Prometheus: <http://localhost:9090>
- Grafana: <http://localhost:3000> (admin/admin)

To run just the API container:

- docker build -t dogonomics:latest .
- docker run -p 8080:8080 --env-file .env dogonomics:latest

## Observability

- Metrics: Exposed at /metrics in Prometheus format.
- Default Grafana datasource connects to Prometheus (provisioned in monitoring/grafana/provisioning/datasources).
- You can add dashboards by placing JSON files in monitoring/grafana/provisioning/dashboards/ and referencing them in a provisioner file.

## FinBERT / ONNX notes

- Default Docker build excludes ONNX via build tags and uses a stub to keep the API working.
- If you need ONNX in Docker, provide a base image with the required libraries and build with -tags=onnx, or run locally with the provided scripts ensuring ONNX Runtime is installed.
