#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../../.." && pwd)"

cd "$REPO_ROOT"

command -v go >/dev/null 2>&1 || {
  echo "ERROR: Go is not installed or not in PATH"
  exit 1
}

if [[ ! -f /usr/local/lib/libonnxruntime.so && ! -f /usr/lib/libonnxruntime.so ]]; then
  echo "WARNING: ONNX Runtime shared library was not found in /usr/local/lib or /usr/lib"
  echo "Set CGO_CFLAGS/CGO_LDFLAGS if your installation path is custom."
fi

CGO_ENABLED=1 go build -tags onnx -o dogonomics-onnx -ldflags="-s -w" .
echo "Build complete: ./dogonomics-onnx"
