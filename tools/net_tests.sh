#!/usr/bin/env bash
# Multi-process headless net tests over loopback (ENet + NetSim):
#   replication  host+client @ --netsim, replicated position error, connect time, clean disconnect
#   host_loss    client returns to menu with "Host disconnected" when the host is killed
#   solo         OfflineTransport runs the same sandbox path; console commands work
#   speedhack    client runs `speed_hack 3`; the host's MovementValidator corrects it (AC-2.5)
#   course       client walks the whole movement course at --netsim latency, no corrections (AC-2.1)
#   weapons      gun range at --netsim: hit markers, host damage + replication, forged claims rejected (AC-3.4)
#   zombies      nav torture at --netsim: 32 zombies, late join, bandwidth, smoothness, hit claims on
#                moving zombies accepted >= 98%, barricade replication (AC-5.3, AC-5.6)
# Usage: tools/net_tests.sh [replication|host_loss|solo|speedhack|course|weapons|zombies]...   (default: all)
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/tools/_common.sh"
OUT="${NET_TEST_OUT:-$ROOT/.test-results/net}"
NETSIM="${NETSIM:-100,20,0.02}"
mkdir -p "$OUT"
PIDS=()
cleanup() { for p in "${PIDS[@]:-}"; do kill -9 "$p" 2>/dev/null || true; done; }
trap cleanup EXIT

free_port() { python3 -c 'import socket; s=socket.socket(socket.AF_INET, socket.SOCK_DGRAM); s.bind(("127.0.0.1",0)); print(s.getsockname()[1]); s.close()'; }

wait_for_log() { # file pattern timeout_s
  local file="$1" pattern="$2" limit="$3" waited=0
  while ! grep -q "$pattern" "$file" 2>/dev/null; do
    sleep 0.1; waited=$((waited + 1))
    if (( waited > limit * 10 )); then echo "timeout waiting for '$pattern' in $file" >&2; return 1; fi
  done
}

launch() { # name log args...
  local name="$1" log="$2"; shift 2
  "$GODOT" --headless --path "$GAME_DIR" "$@" >"$log" 2>&1 &
  PIDS+=($!)
  eval "PID_$name=$!"
}

result_ok() { # json
  python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); sys.exit(0 if d.get("pass") else 1)' "$1"
}

report() { # name json log...
  local name="$1" json="$2"; shift 2
  local ok=1
  [[ -f "$json" ]] && result_ok "$json" || ok=0
  for log in "$@"; do
    if godot_log_has_errors "$log"; then echo "[$name] errors in $log:" >&2; grep -E "SCRIPT ERROR|^ERROR:" -A3 "$log" | head -30 >&2; ok=0; fi
  done
  if (( ok )); then
    echo "[net:$name] PASS $(python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print({k:v for k,v in d.items() if k not in ("checks","notes")})' "$json")"
  else
    echo "[net:$name] FAIL" >&2
    [[ -f "$json" ]] && cat "$json" >&2
    for log in "$@"; do echo "--- $log" >&2; tail -25 "$log" >&2; done
    return 1
  fi
}

test_replication() {
  local port; port="$(free_port)"
  rm -f "$OUT"/replication_*.json
  launch host "$OUT/replication_host.log" -- --host="$port" --map=sandbox --netsim="$NETSIM" \
    --autotest=res://tests/net/host_replication.gd --autotest-out="$OUT/replication_host.json" --profile=nethost
  wait_for_log "$OUT/replication_host.log" "Match started" 15
  launch client "$OUT/replication_client.log" -- --join="127.0.0.1:$port" --netsim="$NETSIM" \
    --autotest=res://tests/net/client_replication.gd --autotest-out="$OUT/replication_client.json" --profile=netclient1
  wait "$PID_client" || true
  wait "$PID_host" || true
  report replication_client "$OUT/replication_client.json" "$OUT/replication_client.log"
  report replication_host "$OUT/replication_host.json" "$OUT/replication_host.log"
}

test_host_loss() {
  local port; port="$(free_port)"
  rm -f "$OUT"/host_loss_*.json
  launch host "$OUT/host_loss_host.log" -- --host="$port" --map=sandbox \
    --autotest=res://tests/net/host_idle.gd --profile=nethost
  wait_for_log "$OUT/host_loss_host.log" "Match started" 15
  launch client "$OUT/host_loss_client.log" -- --join="127.0.0.1:$port" --netsim="$NETSIM" \
    --autotest=res://tests/net/client_host_loss.gd --autotest-out="$OUT/host_loss_client.json" --profile=netclient1
  wait_for_log "$OUT/host_loss_client.log" "AUTOTEST READY client" 15
  kill -9 "$PID_host"
  wait "$PID_client" || true
  report host_loss "$OUT/host_loss_client.json" "$OUT/host_loss_client.log"
}

test_solo() {
  rm -f "$OUT"/solo.json
  local start=$SECONDS
  launch solo "$OUT/solo.log" -- --solo --map=sandbox \
    --autotest=res://tests/net/solo_check.gd --autotest-out="$OUT/solo.json" --profile=netsolo
  wait "$PID_solo" || true
  report solo "$OUT/solo.json" "$OUT/solo.log"
  grep -q "Quitting" "$OUT/solo.log" || { echo "[net:solo] quit command did not run" >&2; return 1; }
}

pair_test() { # name map host_script client_script
  local name="$1" map="$2" host_script="$3" client_script="$4" port
  port="$(free_port)"
  rm -f "$OUT"/"$name"_*.json
  launch host "$OUT/${name}_host.log" -- --host="$port" --map="$map" --netsim="$NETSIM" \
    --autotest="res://tests/net/$host_script" --autotest-out="$OUT/${name}_host.json" --profile=nethost
  wait_for_log "$OUT/${name}_host.log" "Match started" 15
  launch client "$OUT/${name}_client.log" -- --join="127.0.0.1:$port" --netsim="$NETSIM" \
    --autotest="res://tests/net/$client_script" --autotest-out="$OUT/${name}_client.json" --profile=netclient1
  wait "$PID_client" || true
  wait "$PID_host" || true
  report "${name}_client" "$OUT/${name}_client.json" "$OUT/${name}_client.log"
  report "${name}_host" "$OUT/${name}_host.json" "$OUT/${name}_host.log"
}

test_speedhack() { pair_test speedhack sandbox host_speedhack.gd client_speedhack.gd; }
test_course() { pair_test course movement_course host_course.gd client_course.gd; }
test_weapons() { pair_test weapons gun_range host_weapons.gd client_weapons.gd; }
test_zombies() { pair_test zombies nav_torture host_zombies.gd client_zombies.gd; }

TESTS=("$@")
[[ ${#TESTS[@]} -eq 0 ]] && TESTS=(solo replication host_loss speedhack course weapons zombies)
fail=0
for t in "${TESTS[@]}"; do
  "test_$t" || fail=1
done
exit $fail
