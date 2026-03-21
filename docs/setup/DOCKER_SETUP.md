# Docker Setup

## Start Default Stack

```powershell
docker compose up --build
```

## Start with Profiles

```powershell
docker compose --profile onnx up --build
docker compose --profile kafka up --build
docker compose --profile onnx --profile kafka up --build
```

## New Script Entry Points

```powershell
./scripts/docker/docker-compose-up.ps1
./scripts/docker/docker-compose-up.ps1 -Profiles onnx
./scripts/docker/docker-compose-down.ps1
```

## Services

- API: 8080
- MCP SSE: 8081
- TimescaleDB: 5432
- Redis: 6379
- Prometheus: 9090
- Grafana: 3000
