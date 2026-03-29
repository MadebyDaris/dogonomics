#!/bin/bash
# DogoHub Linux Launcher
# Runs the DogoHub TUI from the root directory

set -euo pipefail

cd "$(dirname "$0")/../../.." || exit 1
if [ ! -t 1 ]; then
	echo "DogoHub requires an interactive terminal (TTY)."
	echo "Run from a terminal with: bash tools/scripts/linux/dogohub.sh"
	exit 1
fi

if [ "${TERM:-}" = "dumb" ] || [ -z "${TERM:-}" ]; then
	echo "Your terminal type is not TUI-friendly (TERM='${TERM:-unset}')."
	echo "Try running this from a full terminal emulator (e.g. GNOME Terminal, Konsole, or VS Code integrated terminal)."
	exit 1
fi

BIN_PATH="./.dogonomics-hub"

echo "Building DogoHub binary (shows progress)..."
go build -v -o "$BIN_PATH" dogonomics.go

echo "Launching DogoHub TUI Mode..."
"$BIN_PATH" --hub
