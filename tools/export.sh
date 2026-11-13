#!/usr/bin/env bash
# Release builds (Step 16): tools/export.sh [linux|windows|all] [--channel=release|rc|nightly] [--no-smoke]
# Needs the pinned Godot export templates (tools/install_templates.sh). For each platform:
#   1. writes game/build_info.json (version from project.godot, git commit, UTC date, channel) —
#      BuildInfo reads it in the exported game; the file is removed again afterwards
#   2. godot --headless --export-release "<preset>" build/<platform>/...
#   3. Linux: smoke-launches the exported binary headless (--version, then 40 s of a solo match on
#      vesper_peak with 3 survival bots, quitting itself) and fails on script / engine errors
#   4. packs build/ProjectLazarus-<version>-<platform>.(tar.gz|zip) with README + HOW_TO_PLAY.txt
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/tools/_common.sh"
WHAT="all"; CHANNEL="release"; SMOKE=1
for arg in "$@"; do
  case "$arg" in
    linux|windows|all) WHAT="$arg" ;;
    --channel=*) CHANNEL="${arg#--channel=}" ;;
    --no-smoke) SMOKE=0 ;;
    *) echo "unknown arg $arg" >&2; exit 2 ;;
  esac
done
VERSION="$(sed -n 's/^config\/version="\(.*\)"/\1/p' "$GAME_DIR/project.godot")"
COMMIT="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo unknown)"
if [[ -n "$(git -C "$ROOT" status --porcelain 2>/dev/null)" ]]; then COMMIT="$COMMIT-dirty"; fi
BUILD="$ROOT/build"; mkdir -p "$BUILD"
INFO="$GAME_DIR/build_info.json"
trap 'rm -f "$INFO"' EXIT
printf '{"version": "%s", "commit": "%s", "date": "%s", "channel": "%s"}\n' \
  "$VERSION" "$COMMIT" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$CHANNEL" >"$INFO"
godot_import

export_one() {
  local preset="$1" out="$2"
  mkdir -p "$(dirname "$out")"
  local log="$BUILD/export_${preset,,}.log"
  echo "[export] $preset -> $out"
  set +e
  "$GODOT" --headless --path "$GAME_DIR" --export-release "$preset" "$out" >"$log" 2>&1
  local code=$?
  set -e
  if [[ $code -ne 0 || ! -f "$out" ]] || grep -E "SCRIPT ERROR|Parse Error|^ERROR:" "$log" | grep -v -E "audio_driver|init_output_device" >/dev/null; then
    echo "[export] $preset FAILED (exit $code), log $log" >&2; tail -30 "$log" >&2; exit 1
  fi
  cp "$ROOT/docs/HOW_TO_PLAY.md" "$(dirname "$out")/HOW_TO_PLAY.txt"
  cp "$ROOT/README.md" "$(dirname "$out")/README.md"
  echo "[export] $preset ok ($(du -sh "$(dirname "$out")" | cut -f1))"
}

# Release templates print one engine-side "Attempt to disconnect a nonexistent connection from
# 'Net' ... tree_exited" line when a session closes (not seen with the editor binary; I-036).
release_log_has_errors() {
  local f; f="$(mktemp)"
  grep -v "Attempt to disconnect a nonexistent connection from 'Net:" "$1" >"$f" || true
  if godot_log_has_errors "$f"; then rm -f "$f"; return 0; fi
  rm -f "$f"; return 1
}

smoke_linux() {
  local bin="$1" log="$BUILD/smoke_linux.log"
  "$bin" --headless -- --version >"$log" 2>&1
  grep -q "Project Lazarus v$VERSION ($COMMIT, $CHANNEL)" "$log" || { echo "[export] version smoke FAILED" >&2; cat "$log" >&2; exit 1; }
  set +e
  timeout 240 "$bin" --headless -- --solo --map=vesper_peak --exec="bots 3" --quit-after=40 >>"$log" 2>&1
  local code=$?
  set -e
  if [[ $code -ne 0 ]] || ! grep -q "Match started on 'vesper_peak'" "$log" || ! grep -q "round_start 1 " "$log" || release_log_has_errors "$log"; then
    echo "[export] linux smoke FAILED (exit $code), log $log" >&2; tail -30 "$log" >&2; exit 1
  fi
  echo "[export] linux smoke ok (exported binary loads vesper_peak headless and quits cleanly)"
}

# Two exported binaries over loopback ENet: the client joins the host's match and both quit cleanly.
smoke_linux_coop() {
  local bin="$1" hlog="$BUILD/smoke_coop_host.log" clog="$BUILD/smoke_coop_client.log" port=24611
  timeout 120 "$bin" --headless -- --host="$port" --map=vesper_peak --quit-after=45 >"$hlog" 2>&1 &
  local hpid=$!
  sleep 6
  set +e
  timeout 100 "$bin" --headless -- --join="127.0.0.1:$port" --profile=export_smoke --quit-after=25 >"$clog" 2>&1
  local ccode=$?
  wait "$hpid"
  local hcode=$?
  set -e
  if [[ $ccode -ne 0 || $hcode -ne 0 ]] || ! grep -q "Joined session as peer" "$clog" \
    || ! grep -q "Match started on 'vesper_peak'" "$clog" || ! grep -q "Peer .* joined" "$hlog" \
    || release_log_has_errors "$hlog" || release_log_has_errors "$clog"; then
    echo "[export] linux co-op smoke FAILED (host $hcode, client $ccode), logs $hlog $clog" >&2
    tail -20 "$clog" >&2; exit 1
  fi
  echo "[export] linux co-op smoke ok (two exported binaries connected over ENet loopback)"
}

if [[ "$WHAT" == linux || "$WHAT" == all ]]; then
  export_one "Linux" "$BUILD/linux/ProjectLazarus.x86_64"
  if [[ $SMOKE -eq 1 ]]; then
    smoke_linux "$BUILD/linux/ProjectLazarus.x86_64"
    smoke_linux_coop "$BUILD/linux/ProjectLazarus.x86_64"
  fi
  tar -C "$BUILD" -czf "$BUILD/ProjectLazarus-$VERSION-linux-x86_64.tar.gz" linux
fi
if [[ "$WHAT" == windows || "$WHAT" == all ]]; then
  export_one "Windows" "$BUILD/windows/ProjectLazarus.exe"
  (cd "$BUILD" && rm -f "ProjectLazarus-$VERSION-windows-x86_64.zip" && python3 -m zipfile -c "ProjectLazarus-$VERSION-windows-x86_64.zip" windows)
fi
ls -la "$BUILD"/*.tar.gz "$BUILD"/*.zip 2>/dev/null || true
