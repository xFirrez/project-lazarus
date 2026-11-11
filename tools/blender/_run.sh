#!/usr/bin/env bash
# Runs a bpy generator script with whatever Blender is available:
#   1. $BLENDER or `blender` on PATH (headless: blender -b --python <script> -- args)
#   2. the `bpy` Python module (pip install bpy; same Blender, no UI) via python3.
# Usage: tools/blender/_run.sh <script.py> [args...]
set -euo pipefail
SCRIPT="$1"; shift
# Fixed string-hash seed: the glTF exporter iterates sets of names, so output order (and bytes)
# would otherwise change between runs.
export PYTHONHASHSEED=0
BLENDER_BIN="${BLENDER:-$(command -v blender || true)}"
if [[ -n "$BLENDER_BIN" ]]; then
  exec "$BLENDER_BIN" -b --factory-startup --python-exit-code 1 --python "$SCRIPT" -- "$@"
elif python3 -c 'import bpy' >/dev/null 2>&1; then
  exec python3 "$SCRIPT" -- "$@"
else
  echo "No Blender found: install Blender 4.2+ (set \$BLENDER) or 'pip install bpy' (see tools/blender/check_install.sh)" >&2
  exit 2
fi
