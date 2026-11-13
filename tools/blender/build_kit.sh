#!/usr/bin/env bash
# Regenerates the Vesper modular kit (game/content/kits/vesper/*.glb + kit_manifest.json) from
# script (AC-4.1). Usage: tools/blender/build_kit.sh [piece...]
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$DIR/_run.sh" "$DIR/kits/build_kit.py" "$@" 2>&1 | grep -E '^\[blender\]|Error|Traceback|line [0-9]' || true
test -f "$DIR/../../game/content/kits/vesper/kit_manifest.json"
