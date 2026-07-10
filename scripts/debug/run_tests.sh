#!/usr/bin/env bash
# Wrapper for headless Godot tests (local shell, cloud agents, CI).
set -euo pipefail
TIER="${1:-smoke}"
exec bash "$(dirname "$0")/run_godot.sh" test "${TIER}"
