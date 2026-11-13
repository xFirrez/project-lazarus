#!/usr/bin/env bash
# Starts a host plus N-1 clients on localhost.
# Usage: tools/run_coop_local.sh <N> [--netsim=ms,jitter,loss] [--windowed] [--map=id] [--port=P]
#        [--duration=S]  (headless default: run S seconds (default 10), print each peer's summary, exit)
# Windowed mode opens real windows (needs a display) and runs until you close them.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/tools/_common.sh"
N="${1:-2}"; shift || true
NETSIM=""; WINDOWED=0; MAP="sandbox"; PORT=24565; DURATION=10
for arg in "$@"; do
  case "$arg" in
    --netsim=*) NETSIM="$arg" ;;
    --windowed) WINDOWED=1 ;;
    --map=*) MAP="${arg#--map=}" ;;
    --port=*) PORT="${arg#--port=}" ;;
    --duration=*) DURATION="${arg#--duration=}" ;;
    *) echo "unknown arg $arg" >&2; exit 2 ;;
  esac
done
OUT="$ROOT/.test-results/coop"
mkdir -p "$OUT"
PIDS=()
cleanup() { for p in "${PIDS[@]:-}"; do kill "$p" 2>/dev/null || true; done; }
trap cleanup EXIT INT TERM

MODE=(--headless)
(( WINDOWED )) && MODE=()
EXTRA=(--overlay)
[[ -n "$NETSIM" ]] && EXTRA+=("$NETSIM")

"$GODOT" "${MODE[@]}" --path "$GAME_DIR" -- --host="$PORT" --map="$MAP" --profile=host "${EXTRA[@]}" \
  >"$OUT/peer1_host.log" 2>&1 &
PIDS+=($!)
for _ in $(seq 1 150); do grep -q "Match started" "$OUT/peer1_host.log" 2>/dev/null && break; sleep 0.1; done
start=$(date +%s.%N)
for i in $(seq 2 "$N"); do
  "$GODOT" "${MODE[@]}" --path "$GAME_DIR" -- --join="127.0.0.1:$PORT" --profile="client$i" "${EXTRA[@]}" \
    >"$OUT/peer${i}_client.log" 2>&1 &
  PIDS+=($!)
done
echo "Started host + $((N - 1)) client(s) on port $PORT; logs in $OUT"
if (( WINDOWED )); then
  wait
  exit 0
fi
# Headless: wait for every client to see N capsules, report timing, then shut down.
ok=1
for i in $(seq 2 "$N"); do
  log="$OUT/peer${i}_client.log"
  for _ in $(seq 1 100); do
    [[ $(grep -c "Spawned avatar" "$log" 2>/dev/null || true) -ge "$N" ]] && break
    sleep 0.1
  done
  count=$(grep -c "Spawned avatar" "$log" || true)
  t=$(python3 -c "import time,sys; print(f'{time.time()-float(sys.argv[1]):.2f}')" "$start")
  if [[ "$count" -ge "$N" ]]; then echo "peer $i: joined, sees $count capsules (${t}s after launch)"; else echo "peer $i: FAILED (sees $count capsules)"; ok=0; fi
done
host_count=$(grep -c "Spawned avatar" "$OUT/peer1_host.log" || true)
echo "host: sees $host_count capsules"
[[ "$host_count" -ge "$N" ]] || ok=0
sleep "$DURATION"
for log in "$OUT"/*.log; do
  if godot_log_has_errors "$log"; then echo "errors in $log" >&2; ok=0; fi
done
(( ok )) && echo "run_coop_local: OK" || { echo "run_coop_local: FAILED" >&2; exit 1; }
