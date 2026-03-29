#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../../.." && pwd)"

cd "$REPO_ROOT"

if [[ ! -x ./dogonomics-onnx ]]; then
  echo "ERROR: ./dogonomics-onnx not found. Run tools/scripts/linux/build-onnx.sh first."
  exit 1
fi

exec ./dogonomics-onnx
