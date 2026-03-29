#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../../.." && pwd)"

ONNX_PROFILE=""
KAFKA_PROFILE=""
DETACH_FLAG=""
PROFILES=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --onnx)
      ONNX_PROFILE="onnx"
      shift
      ;;
    --kafka)
      KAFKA_PROFILE="kafka"
      shift
      ;;
    --detach|-d)
      DETACH_FLAG="-d"
      shift
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: $0 [--onnx] [--kafka] [--detach]"
      exit 1
      ;;
  esac
done

cd "$REPO_ROOT"

if [[ ! -f .env ]]; then
  echo "WARNING: .env file not found. Continuing without API keys."
fi

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

if [[ -n "$ONNX_PROFILE" ]]; then
  PROFILES+=("$ONNX_PROFILE")
fi
if [[ -n "$KAFKA_PROFILE" ]]; then
  PROFILES+=("$KAFKA_PROFILE")
fi

if [[ ${#PROFILES[@]} -gt 0 ]]; then
  COMPOSE_PROFILES="$(IFS=,; echo "${PROFILES[*]}")" "${COMPOSE_CMD[@]}" "${ENV_ARGS[@]}" "${COMPOSE_FILES[@]}" up --build ${DETACH_FLAG}
else
  "${COMPOSE_CMD[@]}" "${ENV_ARGS[@]}" "${COMPOSE_FILES[@]}" up --build ${DETACH_FLAG}
fi
