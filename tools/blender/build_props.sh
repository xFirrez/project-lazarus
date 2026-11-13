#!/usr/bin/env bash
# Regenerates the look-dev props (game/content/props/<id>/<id>.glb).
# Usage: tools/blender/build_props.sh [prop...]
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$DIR/_run.sh" "$DIR/props/build_props.py" "$@" 2>&1 | grep -E '^\[blender\]|Error|Traceback|line [0-9]'
