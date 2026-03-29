#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/../../.." || exit 1

echo "Starting Dogonomics stack with AI sidecars (Ollama + MCP client)..."
docker compose --profile ai up --build -d

echo "Done. Check status with: docker compose ps"
