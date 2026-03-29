#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../../.." && pwd)"

ONNX_PROFILE=""
KAFKA_PROFILE=""
DETACH_FLAG=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --onnx)
      ONNX_PROFILE="--profile onnx"
      shift
      ;;
    --kafka)
      KAFKA_PROFILE="--profile kafka"
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

docker compose ${ONNX_PROFILE} ${KAFKA_PROFILE} up --build ${DETACH_FLAG}
