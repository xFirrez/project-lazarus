#!/usr/bin/env bash
# Rendered (xvfb) visual checks that need real frames, e.g. the damage HUD direction test (AC-2.4).
# Same renderer selection as screenshot.sh: Vulkan if an ICD exists, otherwise opengl3 (D-013).
# Usage: tools/visual_tests.sh [out_dir]   (frames go to docs/screenshots by default)
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/tools/_common.sh"
OUT="${1:-$ROOT/docs/screenshots}"
mkdir -p "$OUT" "$ROOT/.test-results"
OUT="$(cd "$OUT" && pwd)"
DRIVER=()
if ! ls /usr/share/vulkan/icd.d/*.json >/dev/null 2>&1; then DRIVER=(--rendering-driver opengl3); fi
RUNNER=()
if [[ -z "${DISPLAY:-}" ]]; then RUNNER=(xvfb-run -a -s "-screen 0 1280x720x24"); fi
LOG="$ROOT/.test-results/visual_damage.log"
JSON="$ROOT/.test-results/visual_damage.json"
rm -f "$JSON"
set +e
timeout 90 "${RUNNER[@]}" "$GODOT" --path "$GAME_DIR" --audio-driver Dummy "${DRIVER[@]}" --resolution 1280x720 \
  -- --solo --map=movement_course --profile=visual --autotest=res://tests/visual/damage_direction.gd \
  --autotest-out="$JSON" --autotest-shots="$OUT" >"$LOG" 2>&1
set -e
if [[ -f "$JSON" ]] && python3 -c 'import json,sys; sys.exit(0 if json.load(open(sys.argv[1]))["pass"] else 1)' "$JSON" \
  && ! godot_log_has_errors "$LOG"; then
  echo "[visual:damage_direction] PASS $(grep -E 'autotest: (PASS|FAIL)' "$LOG" | sed 's/.*autotest: //' | tr '\n' ';')"
else
  echo "[visual:damage_direction] FAIL; log: $LOG" >&2
  grep -E "autotest|ERROR" "$LOG" | tail -20 >&2
  exit 1
fi
