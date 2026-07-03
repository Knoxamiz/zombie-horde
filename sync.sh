#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
echo "Syncing zombie-horde from GitHub..."
git fetch origin
git reset --hard origin/main
echo ""
echo "Done. Open Godot and press F5."
