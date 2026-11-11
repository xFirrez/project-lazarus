#!/usr/bin/env bash
# Headless gameplay simulations. Usage: tools/run_sim.sh <scenario> [--map=id] [--duration=s]
# Scenarios:
#   smoke       solo session, bot movement, no errors
#   perf_arena  32 zombies pursuing 4 bots on nav_torture; host AI+nav ms/frame -> CSV (AC-5.5)
#   soak        continuous spawning/killing on nav_torture, default 600 simulated s (AC-5.7)
# perf_arena and soak run with --fixed-fps 60 (simulated time, deterministic frames; per-frame
# AI cost is measured in wall-clock microseconds either way). More come later (nav_validate, quest).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/tools/_common.sh"
SCENARIO="${1:?usage: run_sim.sh <scenario> [args]}"; shift
MAP=""; DURATION=""
for arg in "$@"; do
  case "$arg" in
    --map=*) MAP="${arg#--map=}" ;;
    --duration=*) DURATION="${arg#--duration=}" ;;
    *) echo "unknown arg $arg" >&2; exit 2 ;;
  esac
done
OUT="$ROOT/.test-results/sim"; mkdir -p "$OUT"
case "$SCENARIO" in
  smoke)
    LOG="$OUT/smoke.log"; JSON="$OUT/smoke.json"; rm -f "$JSON"
    set +e
    "$GODOT" --headless --path "$GAME_DIR" -- --solo --map="${MAP:-sandbox}" --profile=sim \
      --autotest=res://tests/sim/smoke.gd --autotest-out="$JSON" --duration="${DURATION:-5}" >"$LOG" 2>&1
    code=$?
    set -e
    if [[ $code -ne 0 ]] || godot_log_has_errors "$LOG"; then
      echo "[sim:smoke] FAIL (exit $code)" >&2; tail -30 "$LOG" >&2; exit 1
    fi
    echo "[sim:smoke] PASS (${MAP:-sandbox}, ${DURATION:-5}s)"
    ;;
  perf_arena|soak)
    LOG="$OUT/$SCENARIO.log"; JSON="$OUT/$SCENARIO.json"; CSV="$OUT/$SCENARIO.csv"; rm -f "$JSON"
    [[ "$SCENARIO" == perf_arena ]] && DEF=60 || DEF=600
    set +e
    "$GODOT" --headless --fixed-fps 60 --path "$GAME_DIR" -- --solo --map="${MAP:-nav_torture}" --profile=sim \
      --autotest="res://tests/sim/$SCENARIO.gd" --autotest-out="$JSON" --duration="${DURATION:-$DEF}" \
      --csv="$CSV" >"$LOG" 2>&1
    code=$?
    set -e
    if [[ $code -ne 0 ]] || godot_log_has_errors "$LOG"; then
      echo "[sim:$SCENARIO] FAIL (exit $code)" >&2; [[ -f "$JSON" ]] && cat "$JSON" >&2; tail -30 "$LOG" >&2; exit 1
    fi
    echo "[sim:$SCENARIO] PASS $(python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print({k:v for k,v in d.items() if k not in ("checks","notes","pass")})' "$JSON")"
    ;;
  *) echo "unknown scenario '$SCENARIO'" >&2; exit 2 ;;
esac
