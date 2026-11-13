#!/usr/bin/env bash
# Installs the pinned Godot headless-capable Linux binary to $GODOT_HOME (default ~/.local/godot)
# and symlinks it as `godot` in ~/.local/bin. Idempotent.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="$(tr -d '[:space:]' < "$ROOT/tools/godot_version.txt")"
GODOT_HOME="${GODOT_HOME:-$HOME/.local/godot}"
BIN_DIR="${BIN_DIR:-$HOME/.local/bin}"
NAME="Godot_v${VERSION}_linux.x86_64"
TARGET="$GODOT_HOME/$NAME"
mkdir -p "$GODOT_HOME" "$BIN_DIR"
if [[ ! -x "$TARGET" ]]; then
  URL="https://github.com/godotengine/godot/releases/download/${VERSION}/${NAME}.zip"
  echo "Downloading $URL"
  TMP="$(mktemp -d)"
  curl -fsSL --retry 4 -o "$TMP/godot.zip" "$URL"
  unzip -q -o "$TMP/godot.zip" -d "$TMP"
  mv "$TMP/$NAME" "$TARGET"
  chmod +x "$TARGET"
  rm -rf "$TMP"
fi
ln -sf "$TARGET" "$BIN_DIR/godot"
echo "Godot $VERSION installed: $BIN_DIR/godot"
"$BIN_DIR/godot" --version
