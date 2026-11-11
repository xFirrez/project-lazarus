#!/usr/bin/env bash
# Regenerates the humanoid animation library and the zombie model (AC-4.2).
# Usage: tools/blender/build_characters.sh
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$DIR/_run.sh" "$DIR/characters/build_zombie.py" "$@" 2>&1 | grep -E '^\[blender\]|Error|Traceback|line [0-9]'
