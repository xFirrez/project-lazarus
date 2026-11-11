#!/usr/bin/env bash
# Runs GUT suites headless: tools/run_tests.sh unit|integration|net|all
# unit/integration use GUT; net runs multi-process loopback scenarios (tools/net_tests.sh).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/tools/_common.sh"
SUITE="${1:-unit}"

run_gut() {
  local dir="$1"
  local extra=()
  # Integration suites step physics: --fixed-fps makes every frame exactly 1/60 s and lets
  # headless runs go as fast as the CPU allows (deterministic, faster than real time).
  if [[ "$dir" == "integration" ]]; then extra=(--fixed-fps 60); fi
  if [[ -z "$(find "$GAME_DIR/tests/$dir" -name 'test_*.gd' 2>/dev/null)" ]]; then
    echo "[run_tests] no tests in tests/$dir"
    return 0
  fi
  local log
  log="$(mktemp)"
  set +e
  "$GODOT" --headless "${extra[@]}" --path "$GAME_DIR" -s res://addons/gut/gut_cmdln.gd \
    -gdir="res://tests/$dir" -gprefix=test_ -gsuffix=.gd -ginclude_subdirs -gexit \
    -glog=1 -gdisable_colors >"$log" 2>&1
  local code=$?
  set -e
  grep -E "^(Totals|Scripts|Tests|Passing|Failing|Pending|Asserts|Time)|FAILED|\[Failed\]|---- " "$log" || true
  if godot_log_has_errors "$log"; then
    echo "[run_tests] engine/script errors in $dir run:" >&2
    grep -E "SCRIPT ERROR|Parse Error|^ERROR:" -A3 "$log" | head -60 >&2
    code=1
  fi
  if [[ $code -ne 0 ]]; then
    echo "[run_tests] $dir FAILED (exit $code); full log: $log" >&2
    tail -40 "$log" >&2
    return 1
  fi
  rm -f "$log"
  echo "[run_tests] $dir passed"
}

case "$SUITE" in
  unit) run_gut unit ;;
  integration) run_gut integration ;;
  net) "$ROOT/tools/net_tests.sh" ;;
  all)
    run_gut unit
    run_gut integration
    "$ROOT/tools/net_tests.sh"
    ;;
  *) echo "usage: $0 unit|integration|net|all" >&2; exit 2 ;;
esac
