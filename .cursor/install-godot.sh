#!/usr/bin/env bash
# Idempotent Godot 4.4 install for Cursor Cloud Agents and local dev scripts.
set -euo pipefail

GODOT_VERSION="${GODOT_VERSION:-4.4-stable}"
GODOT_ARCH="${GODOT_ARCH:-linux.x86_64}"
GODOT_DIR="${HOME}/.local/share/godot"
GODOT_BIN="${GODOT_DIR}/Godot_v${GODOT_VERSION}_${GODOT_ARCH}"
GODOT_LINK="${HOME}/.local/bin/godot"

mkdir -p "${GODOT_DIR}" "${HOME}/.local/bin"

if [[ -x "${GODOT_BIN}" ]]; then
	ln -sf "${GODOT_BIN}" "${GODOT_LINK}"
	echo "Godot already installed: $("${GODOT_BIN}" --version)"
	exit 0
fi

ZIP_NAME="Godot_v${GODOT_VERSION}_${GODOT_ARCH}.zip"
DOWNLOAD_URL="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/${ZIP_NAME}"

echo "Downloading ${DOWNLOAD_URL}..."
curl -fsSL -o /tmp/godot.zip "${DOWNLOAD_URL}"
unzip -qo /tmp/godot.zip -d "${GODOT_DIR}"
chmod +x "${GODOT_BIN}"
ln -sf "${GODOT_BIN}" "${GODOT_LINK}"
rm -f /tmp/godot.zip

echo "Installed: $("${GODOT_BIN}" --version)"
echo "Binary: ${GODOT_BIN}"
echo "Symlink: ${GODOT_LINK}"
