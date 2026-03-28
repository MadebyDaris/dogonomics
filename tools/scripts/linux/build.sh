#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../../.." && pwd)"

cd "$REPO_ROOT"

command -v go >/dev/null 2>&1 || {
  echo "ERROR: Go is not installed or not in PATH"
  exit 1
}

CGO_ENABLED=0 go build -o dogonomics -ldflags="-s -w" .
echo "Build complete: ./dogonomics"
