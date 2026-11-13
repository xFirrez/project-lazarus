#!/usr/bin/env bash
# Installs the export templates for the pinned Godot version (≈ 1.3 GB download) into
# ~/.local/share/godot/export_templates/<version>/. Only the Linux + Windows x86_64 templates are
# kept (release + debug), so the install stays ≈ 250 MB. Idempotent.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="$(tr -d '[:space:]' < "$ROOT/tools/godot_version.txt")"
DEST="$HOME/.local/share/godot/export_templates/${VERSION/-/.}"
if [[ -f "$DEST/linux_release.x86_64" && -f "$DEST/windows_release_x86_64.exe" ]]; then
  echo "templates present: $DEST"; exit 0
fi
TPZ="${TEMPLATES_TPZ:-}"
TMP="$(mktemp -d)"
if [[ -z "$TPZ" ]]; then
  TPZ="$TMP/templates.tpz"
  curl -fsSL --retry 4 -o "$TPZ" "https://github.com/godotengine/godot/releases/download/${VERSION}/Godot_v${VERSION}_export_templates.tpz"
fi
mkdir -p "$DEST"
unzip -q -o -j "$TPZ" "templates/version.txt" "templates/linux_*x86_64" "templates/windows_*x86_64*.exe" -d "$DEST"
rm -rf "$TMP"
ls -la "$DEST"
