#!/usr/bin/env bash
# Regenerates the survivor animation library and the four playable character models (Step 7).
# Usage: tools/blender/build_survivors.sh [anims] [calloway|orlov|brandt|ashcombe]...
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$DIR/_run.sh" "$DIR/characters/build_survivors.py" "$@" 2>&1 | grep -E '^\[blender\]|Error|Traceback|line [0-9]'
