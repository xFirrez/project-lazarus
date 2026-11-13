#!/usr/bin/env bash
# Headless gameplay simulations. Usage: tools/run_sim.sh <scenario> [--map=id] [--duration=s]
# Scenarios:
#   smoke       solo session on vesper_peak, bot movement, round 1 starts and spawns fairly, no errors
#   perf_arena  32 zombies pursuing 4 bots on nav_torture; host AI+nav ms/frame -> CSV (AC-5.5)
#   soak        continuous spawning/killing on nav_torture, default 600 simulated s (AC-5.7)
#   round_flow  vesper_peak rounds / economy / doors / solo game over (AC-6.2, 6.4, 6.5)
#   survival    4 survival bots on vesper_peak (AC-6.3 fairness, AC-6.7 soak); --rounds=N --god=0|1
#   nav_validate  vesper_peak navigation: tiles, islands, standable coverage, spawner reach (AC-8.2)
#   flow        vesper_peak flow: door order, sprint travel times, perk spacing, bot loop (AC-8.3)
#   perks       vesper_peak solo: perk machines, cap, drink, effects, Second Wind x3, power-ups (AC-10.1/2/4)
#   progression vesper_peak solo: relays + pause rules, bridge, Forge, upgraded behaviors, traps,
#               hazards (AC-11.1..11.5)
#   specials    vesper_peak solo: Conduit buildable, Galvanic special round (rifts, burst, Max Ammo),
#               warning build-up, 50-round schedule, Warden rules (AC-12.3, AC-12.4, AC-12.5)
#   balance     BalanceModel over the shipped data: weapon tiers, zombie curve r1..100, economy
#               milestones solo / co-op vs GAME_DESIGN §6.3, specials, Warden, traps -> balance.md
#   high_rounds 4 god-mode upgraded bots on vesper_peak, round jumps to 60 (AC-16.4 stability)
# perf_arena and soak run with --fixed-fps 60 (simulated time, deterministic frames; per-frame
# AI cost is measured in wall-clock microseconds either way).
#   quest       vesper_peak solo: every Easter-egg stage + failure rules, rewards, lore, secrets,
#               4-player scaling (AC-14.1, 14.2, 14.4, 14.5)
#   presentation  vesper_peak solo: audio audit vs. the manifest, 32-zombie Ray Pistol mix peak meter,
#               dynamic music, quips / announcer captions, solo pause clock, HUD scale / palettes
#               (AC-15.3, AC-15.4)
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/tools/_common.sh"
SCENARIO="${1:?usage: run_sim.sh <scenario> [args]}"; shift
MAP=""; DURATION=""; EXTRA=()
for arg in "$@"; do
  case "$arg" in
    --map=*) MAP="${arg#--map=}" ;;
    --duration=*) DURATION="${arg#--duration=}" ;;
    --rounds=*|--god=*|--bot_damage=*|--quick=*) EXTRA+=("$arg") ;;
    *) echo "unknown arg $arg" >&2; exit 2 ;;
  esac
done
OUT="$ROOT/.test-results/sim"; mkdir -p "$OUT"
case "$SCENARIO" in
  smoke)
    LOG="$OUT/smoke.log"; JSON="$OUT/smoke.json"; rm -f "$JSON"
    set +e
    "$GODOT" --headless --path "$GAME_DIR" -- --solo --map="${MAP:-vesper_peak}" --profile=sim \
      --autotest=res://tests/sim/smoke.gd --autotest-out="$JSON" --duration="${DURATION:-12}" >"$LOG" 2>&1
    code=$?
    set -e
    if [[ $code -ne 0 ]] || godot_log_has_errors "$LOG"; then
      echo "[sim:smoke] FAIL (exit $code)" >&2; tail -30 "$LOG" >&2; exit 1
    fi
    echo "[sim:smoke] PASS (${MAP:-vesper_peak}, ${DURATION:-12}s)"
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
  nav_validate|flow)
    LOG="$OUT/$SCENARIO.log"; JSON="$OUT/$SCENARIO.json"; rm -f "$JSON"
    set +e
    "$GODOT" --headless --fixed-fps 60 --path "$GAME_DIR" -- --solo --map="${MAP:-vesper_peak}" --profile=sim \
      --autotest="res://tests/sim/$SCENARIO.gd" --autotest-out="$JSON" "${EXTRA[@]}" >"$LOG" 2>&1
    code=$?
    set -e
    if [[ $code -ne 0 ]] || godot_log_has_errors "$LOG"; then
      echo "[sim:$SCENARIO] FAIL (exit $code)" >&2; [[ -f "$JSON" ]] && python3 -m json.tool "$JSON" >&2; tail -30 "$LOG" >&2; exit 1
    fi
    echo "[sim:$SCENARIO] PASS $(python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print({k:v for k,v in d.items() if k not in ("checks","notes","pass")})' "$JSON")"
    ;;
  perks)
    LOG="$OUT/perks.log"; JSON="$OUT/perks.json"; rm -f "$JSON"
    set +e
    "$GODOT" --headless --path "$GAME_DIR" -- --solo --map="${MAP:-vesper_peak}" --profile=sim \
      --autotest=res://tests/sim/perks.gd --autotest-out="$JSON" >"$LOG" 2>&1
    code=$?
    set -e
    if [[ $code -ne 0 ]] || godot_log_has_errors "$LOG"; then
      echo "[sim:perks] FAIL (exit $code)" >&2; [[ -f "$JSON" ]] && cat "$JSON" >&2; tail -30 "$LOG" >&2; exit 1
    fi
    echo "[sim:perks] PASS"
    ;;
  progression|specials|quest|presentation)
    LOG="$OUT/$SCENARIO.log"; JSON="$OUT/$SCENARIO.json"; rm -f "$JSON"
    set +e
    "$GODOT" --headless --path "$GAME_DIR" -- --solo --map="${MAP:-vesper_peak}" --profile=sim \
      --autotest=res://tests/sim/$SCENARIO.gd --autotest-out="$JSON" >"$LOG" 2>&1
    code=$?
    set -e
    if [[ $code -ne 0 ]] || godot_log_has_errors "$LOG"; then
      echo "[sim:$SCENARIO] FAIL (exit $code)" >&2; [[ -f "$JSON" ]] && cat "$JSON" >&2; tail -30 "$LOG" >&2; exit 1
    fi
    echo "[sim:$SCENARIO] PASS"
    ;;
  round_flow|survival)
    LOG="$OUT/$SCENARIO.log"; JSON="$OUT/$SCENARIO.json"; rm -f "$JSON"
    set +e
    "$GODOT" --headless --fixed-fps 60 --path "$GAME_DIR" -- --solo --map="${MAP:-vesper_peak}" --profile=sim \
      --autotest="res://tests/sim/$SCENARIO.gd" --autotest-out="$JSON" "${EXTRA[@]}" >"$LOG" 2>&1
    code=$?
    set -e
    if [[ $code -ne 0 ]] || godot_log_has_errors "$LOG"; then
      echo "[sim:$SCENARIO] FAIL (exit $code)" >&2; [[ -f "$JSON" ]] && cat "$JSON" >&2; tail -30 "$LOG" >&2; exit 1
    fi
    echo "[sim:$SCENARIO] PASS $(python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print({k:v for k,v in d.items() if k not in ("checks","notes","pass")})' "$JSON")"
    ;;
  balance)
    LOG="$OUT/balance.log"; MD="$OUT/balance.md"; rm -f "$MD"
    set +e
    "$GODOT" --headless --path "$GAME_DIR" -- --profile=sim --autotest=res://tests/balance/balance_report.gd \
      --out="$MD" >"$LOG" 2>&1
    code=$?
    set -e
    if [[ $code -ne 0 ]] || godot_log_has_errors "$LOG"; then
      echo "[sim:balance] FAIL (exit $code)" >&2; grep -E "WARN balance|ERROR" "$LOG" >&2; exit 1
    fi
    echo "[sim:balance] PASS (report: $MD)"
    ;;
  *) echo "unknown scenario '$SCENARIO'" >&2; exit 2 ;;
esac
