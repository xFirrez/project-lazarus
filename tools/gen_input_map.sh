#!/usr/bin/env bash
# Regenerates the [input] section of game/project.godot from core/autoload/input_defaults.gd.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/tools/_common.sh"
"$GODOT" --headless --path "$ROOT/game" -s "$ROOT/tools/gen_input_map.gd"
