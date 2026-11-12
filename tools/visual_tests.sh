#!/usr/bin/env bash
# Rendered (xvfb) visual checks that need real frames:
#   damage_direction  damage HUD direction + vignette (AC-2.4), 1280x720
#   viewmodel_ads     ADS sight alignment within 1 px at 1920x1080 + viewmodel over walls (AC-3.5)
#   lookdev_perf      look-dev shots: draw calls / shadow-light budget per preset + reference PNGs (AC-4.3/4.4)
#   zombie_showcase   zombie poses (walk, attack, crawler, head look, gib, ragdoll), surround, window (Step 5)
#   survivor_showcase the four survivors: weapon-class holds, full-body states, tinted first-person arms (Step 7)
#   lobby_ui          lobby (characters, chat, ready), main menu v1, map select (Step 7)
# Same renderer selection as screenshot.sh: Vulkan if an ICD exists, otherwise opengl3 (D-013).
# Usage: tools/visual_tests.sh [out_dir] [test...]   (frames go to docs/screenshots by default)
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/tools/_common.sh"
OUT="${1:-$ROOT/docs/screenshots}"
shift || true
mkdir -p "$OUT" "$ROOT/.test-results"
OUT="$(cd "$OUT" && pwd)"
DRIVER=()
if ! ls /usr/share/vulkan/icd.d/*.json >/dev/null 2>&1; then DRIVER=(--rendering-driver opengl3); fi

run_visual() { # name map resolution [session args...]
  local name="$1" map="$2" res="$3"; shift 3
  local session=("$@"); [[ ${#session[@]} -eq 0 ]] && session=(--solo)
  local w="${res%x*}" h="${res#*x}"
  local runner=()
  if [[ -z "${DISPLAY:-}" ]]; then runner=(xvfb-run -a -s "-screen 0 ${w}x${h}x24"); fi
  local log="$ROOT/.test-results/visual_${name}.log" json="$ROOT/.test-results/visual_${name}.json"
  rm -f "$json"
  set +e
  timeout 280 "${runner[@]}" "$GODOT" --path "$GAME_DIR" --audio-driver Dummy "${DRIVER[@]}" --resolution "$res" \
    -- "${session[@]}" --map="$map" --profile=visual --autotest="res://tests/visual/${name}.gd" \
    --autotest-out="$json" --autotest-shots="$OUT" >"$log" 2>&1
  set -e
  if [[ -f "$json" ]] && python3 -c 'import json,sys; sys.exit(0 if json.load(open(sys.argv[1]))["pass"] else 1)' "$json" \
    && ! godot_log_has_errors "$log"; then
    echo "[visual:$name] PASS $(grep -E 'autotest: (PASS|FAIL)' "$log" | sed 's/.*autotest: //' | tr '\n' ';')"
  else
    echo "[visual:$name] FAIL; log: $log" >&2
    grep -E "autotest|ERROR" "$log" | tail -20 >&2
    return 1
  fi
}

TESTS=("$@")
[[ ${#TESTS[@]} -eq 0 ]] && TESTS=(damage_direction viewmodel_ads lookdev_perf zombie_showcase survivor_showcase lobby_ui)
fail=0
for t in "${TESTS[@]}"; do
  case "$t" in
    damage_direction) run_visual damage_direction movement_course 1280x720 || fail=1 ;;
    viewmodel_ads) run_visual viewmodel_ads gun_range 1920x1080 || fail=1 ;;
    lookdev_perf) run_visual lookdev_perf lookdev 1280x720 || fail=1 ;;
    zombie_showcase) run_visual zombie_showcase nav_torture 1280x720 || fail=1 ;;
    survivor_showcase) run_visual survivor_showcase vesper_peak 1280x720 || fail=1 ;;
    lobby_ui) run_visual lobby_ui vesper_peak 1280x720 --host=24599 --lobby || fail=1 ;;
    *) echo "unknown visual test $t" >&2; fail=1 ;;
  esac
done
exit $fail
