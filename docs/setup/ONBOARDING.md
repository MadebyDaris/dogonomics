# Backend Onboarding

Use this guide to pick the right setup path quickly.

## Choose a Path

- Local development on Windows: see `LOCAL_SETUP_WINDOWS.md`
- Docker-first development: see `DOCKER_SETUP.md`
- ONNX/BERT local runtime setup: see `ONNX_BERT_SETUP.md`

## Prerequisites

- Go 1.24.5+
- Docker Desktop (if using Docker path)
- PostgreSQL (if local DB path)
- Redis (if local cache path)

## First Actions

1. Copy `.env.example` to `.env`.
2. Set at least `FINNHUB_API_KEY`.
3. Configure API security keys (`API_KEY_REQUIRED`, `API_ALLOWED_KEYS`).
4. Pick your setup path from the files above.
