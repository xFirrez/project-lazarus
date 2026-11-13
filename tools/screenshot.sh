#!/usr/bin/env bash
# Captures a map's named shot cameras (group "screenshot_shot") to docs/screenshots/.
# Usage: tools/screenshot.sh <shot_set=map_id> [out_dir]
# Uses xvfb. Tries Vulkan (Forward+, e.g. lavapipe) first; if no Vulkan ICD is available it
# falls back to --rendering-driver opengl3 (Compatibility) — approximate, for composition and
# regression checks only (DEVELOPMENT_PLAN Step 1 risks; AGENT_GUIDE §8).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/tools/_common.sh"
SET="${1:?usage: screenshot.sh <shot_set> [out_dir]}"
OUT="${2:-$ROOT/docs/screenshots}"
mkdir -p "$OUT"
OUT="$(cd "$OUT" && pwd)"
LOG="$(mktemp)"
DRIVER=()
if ! ls /usr/share/vulkan/icd.d/*.json >/dev/null 2>&1; then
  DRIVER=(--rendering-driver opengl3)
  echo "[screenshot] no Vulkan ICD found; using opengl3 fallback"
fi
RUNNER=()
if [[ -z "${DISPLAY:-}" ]]; then RUNNER=(xvfb-run -a -s "-screen 0 1280x720x24"); fi
set +e
timeout 120 "${RUNNER[@]}" "$GODOT" --path "$GAME_DIR" --audio-driver Dummy "${DRIVER[@]}" \
  --resolution 1280x720 -- --screenshot="$SET" --screenshot-out="$OUT" --overlay --profile=screenshot >"$LOG" 2>&1
code=$?
set -e
grep -E "screenshot|ERROR" "$LOG" | grep -v -E "audio|V-Sync" || true
if [[ $code -ne 0 ]] || ! ls "$OUT/${SET}"_*.png >/dev/null 2>&1; then
  echo "[screenshot] FAILED (exit $code); log: $LOG" >&2
  tail -30 "$LOG" >&2
  exit 1
fi
rm -f "$LOG"
echo "[screenshot] ok: $(ls "$OUT/${SET}"_*.png | tr '\n' ' ')"
