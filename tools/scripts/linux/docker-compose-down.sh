#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../../.." && pwd)"

cd "$REPO_ROOT"

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
elif command -v docker-compose >/dev/null 2>&1; then
	COMPOSE_CMD=(docker-compose)
else
	echo "ERROR: Docker Compose not found. Install Docker Compose v2 or docker-compose."
	exit 1
fi

"${COMPOSE_CMD[@]}" "${ENV_ARGS[@]}" "${COMPOSE_FILES[@]}" down "$@"
