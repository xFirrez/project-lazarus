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
#   survival     vesper_peak at --netsim: late-join door, purchase race without double-spend,
#                revive / bleedout / spectate / respawn / game over on both peers (AC-6.4..6.6)
#   lobby        --host --lobby + 2 clients: unique characters, chat, ready, countdown, scene-ready gate,
#                starting round, late join off refuses a 3rd client, game over -> return to lobby (Step 7)
#   late_join    a client joins mid-round 3: full state < 2 s, spectates, spawns next round with
#                500 + 250 x 3 points, correct doors / barricades; pings (AC-7.2)
#   reconnect    a client is SIGKILLed and relaunched: points, weapons, perks restored by uid (AC-7.3);
#                RECONNECT_CYCLES=N repeats the kill / relaunch N times (Step 16 reconnect stress)
#   coop4        host + 3 clients at 150 ms / 30 ms / 3 %: 32-zombie bandwidth phase, then 10 bot rounds
#                with state-hash convergence at every round end (AC-7.1, AC-7.4); COOP4_ROUNDS=N plays N
#                rounds and checks memory growth <= 10 % on every peer (Step 16 soak, AC-16.2)
# Usage: tools/net_tests.sh [replication|host_loss|solo|speedhack|course|weapons|zombies|survival|lobby|
#        late_join|reconnect|coop4|traversal|box|perks|progression|wonder|quest]... (default: all)
#   traversal    vesper_peak at --netsim: power on before join (late join), gondola + lift (with a
#                zombie) riders without corrections, chute grate + slide (AC-8.4, AC-8.5)
#   box          vesper_peak at --netsim: Relic Box late-join location, spinner-only take, identical
#                carousel on both peers, doll relocation, Fire Sale (AC-9.5)
#   perks        vesper_peak at --netsim: perk purchase replication, co-op Second Wind revive 2 s,
#                power-up pickups, timer flag + clock agreement < 100 ms, perk loss on down (AC-10.2/10.4)
#   progression  vesper_peak at --netsim: late-join relay / trap flags, client relay start + pause,
#                bridge / reactor / Forge on the client, client Forge job + upgrade, client trap kills
#                + points, FROZEN + splash replication, drum death / respawn (AC-11.1/11.2/11.4/11.5)
#   quest        vesper_peak at --netsim: quest late join at stage 4 (Heart carried), Heart passed to the
#                client, client SIGKILLed while carrying (auto-drop) + reconnect, finale + victory
#                replicated, client Journal / blessing (AC-14.3, AC-14.4)
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
test_survival() {
  # Like pair_test, but the client joins only after the host bought D01 (late-join door state).
  local port; port="$(free_port)"
  rm -f "$OUT"/survival_*.json
  launch host "$OUT/survival_host.log" -- --host="$port" --map=vesper_peak --netsim="$NETSIM" \
    --autotest=res://tests/net/host_survival.gd --autotest-out="$OUT/survival_host.json" --profile=nethost
  wait_for_log "$OUT/survival_host.log" "AUTOTEST READY host" 20
  launch client "$OUT/survival_client.log" -- --join="127.0.0.1:$port" --netsim="$NETSIM" \
    --autotest=res://tests/net/client_survival.gd --autotest-out="$OUT/survival_client.json" --profile=netclient1
  wait "$PID_client" || true
  wait "$PID_host" || true
  report survival_client "$OUT/survival_client.json" "$OUT/survival_client.log"
  report survival_host "$OUT/survival_host.json" "$OUT/survival_host.log"
}

test_traversal() {
  # The client joins after the host turned the power on (late-join power state, AC-8.5).
  local port; port="$(free_port)"
  rm -f "$OUT"/traversal_*.json
  launch host "$OUT/traversal_host.log" -- --host="$port" --map=vesper_peak --netsim="$NETSIM" \
    --autotest=res://tests/net/host_traversal.gd --autotest-out="$OUT/traversal_host.json" --profile=nethost
  wait_for_log "$OUT/traversal_host.log" "AUTOTEST READY host" 30
  launch client "$OUT/traversal_client.log" -- --join="127.0.0.1:$port" --netsim="$NETSIM" \
    --autotest=res://tests/net/client_traversal.gd --autotest-out="$OUT/traversal_client.json" --profile=netclient1
  wait "$PID_client" || true
  wait "$PID_host" || true
  report traversal_client "$OUT/traversal_client.json" "$OUT/traversal_client.log"
  report traversal_host "$OUT/traversal_host.json" "$OUT/traversal_host.log"
}

test_box() {
  local port; port="$(free_port)"
  rm -f "$OUT"/box_*.json
  launch host "$OUT/box_host.log" -- --host="$port" --map=vesper_peak --netsim="$NETSIM" \
    --autotest=res://tests/net/host_box.gd --autotest-out="$OUT/box_host.json" --profile=nethost
  wait_for_log "$OUT/box_host.log" "AUTOTEST READY host" 30
  launch client "$OUT/box_client.log" -- --join="127.0.0.1:$port" --netsim="$NETSIM" \
    --autotest=res://tests/net/client_box.gd --autotest-out="$OUT/box_client.json" --profile=netclient1
  wait "$PID_client" || true
  wait "$PID_host" || true
  report box_client "$OUT/box_client.json" "$OUT/box_client.log"
  report box_host "$OUT/box_host.json" "$OUT/box_host.log"
}

test_perks() {
  local port; port="$(free_port)"
  rm -f "$OUT"/perks_*.json
  launch host "$OUT/perks_host.log" -- --host="$port" --map=vesper_peak --netsim="$NETSIM" \
    --autotest=res://tests/net/host_perks.gd --autotest-out="$OUT/perks_host.json" --profile=nethost
  wait_for_log "$OUT/perks_host.log" "AUTOTEST READY host" 30
  launch client "$OUT/perks_client.log" -- --join="127.0.0.1:$port" --netsim="$NETSIM" \
    --autotest=res://tests/net/client_perks.gd --autotest-out="$OUT/perks_client.json" --profile=netclient1
  wait "$PID_client" || true
  wait "$PID_host" || true
  report perks_client "$OUT/perks_client.json" "$OUT/perks_client.log"
  report perks_host "$OUT/perks_host.json" "$OUT/perks_host.log"
}

test_progression() {
  local port; port="$(free_port)"
  rm -f "$OUT"/progression_*.json
  launch host "$OUT/progression_host.log" -- --host="$port" --map=vesper_peak --netsim="$NETSIM" \
    --autotest=res://tests/net/host_progression.gd --autotest-out="$OUT/progression_host.json" --profile=nethost
  wait_for_log "$OUT/progression_host.log" "AUTOTEST READY host" 30
  launch client "$OUT/progression_client.log" -- --join="127.0.0.1:$port" --netsim="$NETSIM" \
    --autotest=res://tests/net/client_progression.gd --autotest-out="$OUT/progression_client.json" --profile=netclient1
  wait "$PID_client" || true
  wait "$PID_host" || true
  report progression_client "$OUT/progression_client.json" "$OUT/progression_client.log"
  report progression_host "$OUT/progression_host.json" "$OUT/progression_host.log"
}

test_wonder() {
  local port; port="$(free_port)"
  rm -f "$OUT"/wonder_*.json
  launch host "$OUT/wonder_host.log" -- --host="$port" --map=vesper_peak --netsim="$NETSIM" \
    --autotest=res://tests/net/host_wonder.gd --autotest-out="$OUT/wonder_host.json" --profile=nethost
  wait_for_log "$OUT/wonder_host.log" "AUTOTEST READY host" 30
  launch client "$OUT/wonder_client.log" -- --join="127.0.0.1:$port" --netsim="$NETSIM" \
    --autotest=res://tests/net/client_wonder.gd --autotest-out="$OUT/wonder_client.json" --profile=netclient1
  wait "$PID_client" || true
  wait "$PID_host" || true
  report wonder_client "$OUT/wonder_client.json" "$OUT/wonder_client.log"
  report wonder_host "$OUT/wonder_host.json" "$OUT/wonder_host.log"
}

test_lobby() {
  local port; port="$(free_port)"
  rm -f "$OUT"/lobby_*.json
  launch host "$OUT/lobby_host.log" -- --host="$port" --lobby --map=vesper_peak --netsim="$NETSIM" \
    --autotest=res://tests/net/host_lobby.gd --autotest-out="$OUT/lobby_host.json" --profile=nethost
  wait_for_log "$OUT/lobby_host.log" "AUTOTEST READY host" 20
  launch c1 "$OUT/lobby_c1.log" -- --join="127.0.0.1:$port" --netsim="$NETSIM" \
    --autotest=res://tests/net/client_lobby.gd --autotest-out="$OUT/lobby_c1.json" --profile=netclient1
  wait_for_log "$OUT/lobby_host.log" "slot 1" 20
  launch c2 "$OUT/lobby_c2.log" -- --join="127.0.0.1:$port" --netsim="$NETSIM" \
    --autotest=res://tests/net/client_lobby.gd --autotest-out="$OUT/lobby_c2.json" --profile=netclient2
  wait_for_log "$OUT/lobby_host.log" "AUTOTEST READY match" 60
  launch c3 "$OUT/lobby_c3.log" -- --join="127.0.0.1:$port" --netsim="$NETSIM" \
    --autotest=res://tests/net/client_lobby.gd --autotest-out="$OUT/lobby_c3.json" --profile=netclient3
  wait "$PID_c3" || true
  wait "$PID_c1" || true
  wait "$PID_c2" || true
  wait "$PID_host" || true
  local fail=0
  report lobby_c1 "$OUT/lobby_c1.json" "$OUT/lobby_c1.log" || fail=1
  report lobby_c2 "$OUT/lobby_c2.json" "$OUT/lobby_c2.log" || fail=1
  report lobby_c3_refused "$OUT/lobby_c3.json" "$OUT/lobby_c3.log" || fail=1
  report lobby_host "$OUT/lobby_host.json" "$OUT/lobby_host.log" || fail=1
  return $fail
}

test_late_join() {
  local port; port="$(free_port)"
  rm -f "$OUT"/late_join_*.json
  launch host "$OUT/late_join_host.log" -- --host="$port" --map=vesper_peak --netsim="$NETSIM" \
    --autotest=res://tests/net/host_late_join.gd --autotest-out="$OUT/late_join_host.json" --profile=nethost
  wait_for_log "$OUT/late_join_host.log" "AUTOTEST READY host" 40
  launch client "$OUT/late_join_client.log" -- --join="127.0.0.1:$port" --netsim="$NETSIM" \
    --autotest=res://tests/net/client_late_join.gd --autotest-out="$OUT/late_join_client.json" --profile=netclient1
  wait "$PID_client" || true
  wait "$PID_host" || true
  report late_join_client "$OUT/late_join_client.json" "$OUT/late_join_client.log"
  report late_join_host "$OUT/late_join_host.json" "$OUT/late_join_host.log"
}

test_reconnect() {
  local port; port="$(free_port)"
  rm -f "$OUT"/reconnect_*.json
  launch host "$OUT/reconnect_host.log" -- --host="$port" --map=vesper_peak --netsim="$NETSIM" \
    --autotest=res://tests/net/host_reconnect.gd --autotest-out="$OUT/reconnect_host.json" --profile=nethost \
    --reconnect-cycles="${RECONNECT_CYCLES:-1}"
  wait_for_log "$OUT/reconnect_host.log" "AUTOTEST READY host" 40
  launch client "$OUT/reconnect_client_a.log" -- --join="127.0.0.1:$port" --netsim="$NETSIM" \
    --autotest=res://tests/net/client_reconnect.gd --reconnect-phase=a --profile=netclient1
  wait_for_log "$OUT/reconnect_client_a.log" "AUTOTEST READY client-a" 40
  kill -9 "$PID_client"
  wait "$PID_client" 2>/dev/null || true
  sleep "${RECONNECT_DELAY:-1}"  # 1 s: rejoin before the host's timeout; 6 s: after it
  # Step 16 reconnect stress: RECONNECT_CYCLES=N relaunches + SIGKILLs the client N-1 more times.
  local c
  for ((c = 2; c <= ${RECONNECT_CYCLES:-1}; c++)); do
    launch client "$OUT/reconnect_client_a$c.log" -- --join="127.0.0.1:$port" --netsim="$NETSIM" \
      --autotest=res://tests/net/client_reconnect.gd --reconnect-phase=a --profile=netclient1
    wait_for_log "$OUT/reconnect_client_a$c.log" "AUTOTEST READY client-a" 40
    kill -9 "$PID_client"
    wait "$PID_client" 2>/dev/null || true
    sleep "${RECONNECT_DELAY:-1}"
  done
  launch client "$OUT/reconnect_client_b.log" -- --join="127.0.0.1:$port" --netsim="$NETSIM" \
    --autotest=res://tests/net/client_reconnect.gd --reconnect-phase=b \
    --autotest-out="$OUT/reconnect_client.json" --profile=netclient1
  wait "$PID_client" || true
  wait "$PID_host" || true
  report reconnect_client "$OUT/reconnect_client.json" "$OUT/reconnect_client_b.log"
  report reconnect_host "$OUT/reconnect_host.json" "$OUT/reconnect_host.log"
}

test_quest() {
  local port; port="$(free_port)"
  rm -f "$OUT"/quest_*.json
  launch host "$OUT/quest_host.log" -- --host="$port" --map=vesper_peak --netsim="$NETSIM" \
    --autotest=res://tests/net/host_quest.gd --autotest-out="$OUT/quest_host.json" --profile=nethost
  wait_for_log "$OUT/quest_host.log" "AUTOTEST READY host" 40
  launch client "$OUT/quest_client_a.log" -- --join="127.0.0.1:$port" --netsim="$NETSIM" \
    --autotest=res://tests/net/client_quest.gd --reconnect-phase=a --profile=netclient1
  wait_for_log "$OUT/quest_client_a.log" "AUTOTEST READY client-a" 60
  kill -9 "$PID_client"
  wait "$PID_client" 2>/dev/null || true
  sleep 1
  launch client "$OUT/quest_client_b.log" -- --join="127.0.0.1:$port" --netsim="$NETSIM" \
    --autotest=res://tests/net/client_quest.gd --reconnect-phase=b \
    --autotest-out="$OUT/quest_client.json" --profile=netclient1
  wait "$PID_client" || true
  wait "$PID_host" || true
  report quest_client "$OUT/quest_client.json" "$OUT/quest_client_b.log"
  report quest_host "$OUT/quest_host.json" "$OUT/quest_host.log"
}

test_coop4() {
  local port netsim="${COOP_NETSIM:-150,30,0.03}"; port="$(free_port)"
  rm -f "$OUT"/coop4_*.json
  launch host "$OUT/coop4_host.log" -- --host="$port" --map=vesper_peak --netsim="$netsim" \
    --autotest=res://tests/net/host_coop4.gd --autotest-out="$OUT/coop4_host.json" --profile=nethost \
    --rounds="${COOP4_ROUNDS:-10}"
  wait_for_log "$OUT/coop4_host.log" "AUTOTEST READY host" 40
  local i
  for i in 1 2 3; do
    launch "c$i" "$OUT/coop4_c$i.log" -- --join="127.0.0.1:$port" --netsim="$netsim" \
      --autotest=res://tests/net/client_coop4.gd --autotest-out="$OUT/coop4_c$i.json" --profile="netclient$i" \
      --rounds="${COOP4_ROUNDS:-10}"
    wait_for_log "$OUT/coop4_host.log" "slot $i" 30
  done
  wait "$PID_c1" || true; wait "$PID_c2" || true; wait "$PID_c3" || true
  wait "$PID_host" || true
  local fail=0
  for i in 1 2 3; do report "coop4_c$i" "$OUT/coop4_c$i.json" "$OUT/coop4_c$i.log" || fail=1; done
  report coop4_host "$OUT/coop4_host.json" "$OUT/coop4_host.log" || fail=1
  return $fail
}

TESTS=("$@")
[[ ${#TESTS[@]} -eq 0 ]] && TESTS=(solo replication host_loss speedhack course weapons zombies survival lobby late_join reconnect coop4 traversal box perks progression wonder quest)
fail=0
for t in "${TESTS[@]}"; do
  "test_$t" || fail=1
done
exit $fail
