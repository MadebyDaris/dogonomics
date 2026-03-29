#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/../../.." || exit 1

COMPOSE_FILES=(-f docker-compose.yml)
if [[ -f docker-compose.droplet.yml ]]; then
	COMPOSE_FILES+=(-f docker-compose.droplet.yml)
fi

ENV_ARGS=()
if [[ -f .env ]]; then
	ENV_ARGS=(--env-file .env)
fi

if docker compose version >/dev/null 2>&1; then
	COMPOSE_CMD=(docker compose)
	PS_CMD="docker compose ps"
elif command -v docker-compose >/dev/null 2>&1; then
	COMPOSE_CMD=(docker-compose)
	PS_CMD="docker-compose ps"
else
	echo "ERROR: Docker Compose not found. Install Docker Compose v2 or docker-compose."
	exit 1
fi

echo "Starting Dogonomics stack with AI sidecars (Ollama + MCP client)..."
COMPOSE_PROFILES=ai "${COMPOSE_CMD[@]}" "${ENV_ARGS[@]}" "${COMPOSE_FILES[@]}" up --build -d

echo "Done. Check status with: ${PS_CMD}"
