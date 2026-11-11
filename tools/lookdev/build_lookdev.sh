#!/usr/bin/env bash
# Regenerates game/maps/_test/lookdev.tscn from tools/lookdev/build_lookdev.gd (kit + props must
# be imported first). Runs with a real rendering driver (xvfb): the headless dummy renderer does not
# keep MultiMesh instance buffers, so floors would be saved empty.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/tools/_common.sh"
"$GODOT" --headless --path "$GAME_DIR" --import >/dev/null 2>&1 || true
DRIVER=()
if ! ls /usr/share/vulkan/icd.d/*.json >/dev/null 2>&1; then DRIVER=(--rendering-driver opengl3); fi
RUNNER=()
if [[ -z "${DISPLAY:-}" ]]; then RUNNER=(xvfb-run -a -s "-screen 0 640x480x24"); fi
"${RUNNER[@]}" "$GODOT" --path "$GAME_DIR" --audio-driver Dummy "${DRIVER[@]}" -s "$ROOT/tools/lookdev/build_lookdev.gd" 2>&1 \
  | grep -E "lookdev|ERROR|SCRIPT" | grep -v "audio" || true
grep -q "buffer = PackedFloat32Array" "$GAME_DIR/maps/_test/lookdev.tscn" || { echo "MultiMesh buffers missing" >&2; exit 1; }
