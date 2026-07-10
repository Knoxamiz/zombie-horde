#!/usr/bin/env bash
# Wrapper for headless Godot tests (local shell, cloud agents, CI).
set -euo pipefail

TIER="${1:-smoke}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

if command -v godot >/dev/null 2>&1; then
	GODOT_BIN="godot"
elif [[ -x "${HOME}/.local/bin/godot" ]]; then
	GODOT_BIN="${HOME}/.local/bin/godot"
else
	echo "Godot not found. Run: bash .cursor/install-godot.sh" >&2
	exit 127
fi

cd "${REPO_ROOT}"
echo "=== Godot test runner (${TIER}) ==="
echo "Binary: ${GODOT_BIN}"
"${GODOT_BIN}" --version

if [[ ! -d "${REPO_ROOT}/.godot" ]]; then
	echo "Importing project (first run)..."
	"${GODOT_BIN}" --headless --path . --import --quit
fi

exec "${GODOT_BIN}" --headless --path . -s res://scripts/debug/test_runner.gd -- --tier="${TIER}"
