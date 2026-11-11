#!/usr/bin/env bash
# Regenerates the hero weapon models (M1911 viewmodel + world model).
# Usage: tools/blender/build_weapons.sh
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$DIR/_run.sh" "$DIR/weapons/build_m1911.py" "$@" 2>&1 | grep -E '^\[blender\]|Error|Traceback|line [0-9]'
