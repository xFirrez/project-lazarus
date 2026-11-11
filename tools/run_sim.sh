#!/usr/bin/env bash
# Headless gameplay simulations. Usage: tools/run_sim.sh <scenario> [--map=id] [--duration=s]
# Scenarios: smoke (solo session, bot movement, no errors). More are added by later steps
# (soak, perf_arena, nav_validate, quest ...).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/tools/_common.sh"
SCENARIO="${1:?usage: run_sim.sh <scenario> [args]}"; shift
MAP="sandbox"; DURATION=5
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
    "$GODOT" --headless --path "$GAME_DIR" -- --solo --map="$MAP" --profile=sim \
      --autotest=res://tests/sim/smoke.gd --autotest-out="$JSON" --duration="$DURATION" >"$LOG" 2>&1
    code=$?
    set -e
    if [[ $code -ne 0 ]] || godot_log_has_errors "$LOG"; then
      echo "[sim:smoke] FAIL (exit $code)" >&2; tail -30 "$LOG" >&2; exit 1
    fi
    echo "[sim:smoke] PASS ($MAP, ${DURATION}s)"
    ;;
  *) echo "unknown scenario '$SCENARIO'" >&2; exit 2 ;;
esac
