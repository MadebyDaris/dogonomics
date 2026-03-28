#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../../.." && pwd)"

cd "$REPO_ROOT"

if [[ ! -x ./dogonomics ]]; then
  echo "ERROR: ./dogonomics not found. Run tools/scripts/linux/build.sh first."
  exit 1
fi

exec ./dogonomics
