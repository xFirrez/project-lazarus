#!/usr/bin/env bash
# Regenerates game/maps/vesper_peak/gameplay_baseline.json (AC-13.1 marker baseline). Only for an
# intentional gameplay-marker change — log it in docs/VESPER_PEAK.md §9.1.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/tools/_common.sh"
"$GODOT" --headless --path "$GAME_DIR" --audio-driver Dummy -s "$ROOT/tools/art/gen_gameplay_baseline.gd" 2>&1 \
  | grep -E "baseline|ERROR|SCRIPT" || true
