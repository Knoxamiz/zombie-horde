#!/usr/bin/env bash
# Unified Godot CLI wrapper — headless flags, import, leak-check mute for CI.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export GODOT_DISABLE_LEAK_CHECKS="${GODOT_DISABLE_LEAK_CHECKS:-1}"

if command -v godot >/dev/null 2>&1; then
	GODOT_BIN="godot"
elif [[ -x "${HOME}/.local/bin/godot" ]]; then
	GODOT_BIN="${HOME}/.local/bin/godot"
else
	echo "Godot not found. Run: bash .cursor/install-godot.sh" >&2
	exit 127
fi

HEADLESS_FLAGS=(
	--headless
	--path "${REPO_ROOT}"
	--display-driver headless
	--audio-driver Dummy
	--disable-render-loop
)

cd "${REPO_ROOT}"

case "${1:-}" in
	import)
		shift
		exec "${GODOT_BIN}" "${HEADLESS_FLAGS[@]}" --import --quit "$@"
		;;
	snapshot)
		shift
		exec "${GODOT_BIN}" "${HEADLESS_FLAGS[@]}" -s res://scripts/debug/godot_project_snapshot.gd "$@"
		;;
	test)
		shift
		TIER="${1:-smoke}"
		if [[ ! -d "${REPO_ROOT}/.godot" ]]; then
			echo "Importing project (first run)..."
			"${GODOT_BIN}" "${HEADLESS_FLAGS[@]}" --import --quit
		fi
		exec "${GODOT_BIN}" "${HEADLESS_FLAGS[@]}" -s res://scripts/debug/test_runner.gd -- --tier="${TIER}"
		;;
	*)
		exec "${GODOT_BIN}" "${HEADLESS_FLAGS[@]}" "$@"
		;;
esac
