#!/usr/bin/env bash
# Renders the procedural score / presentation audio (ScoreAudio) to game/content/audio/score/*.wav
# and re-imports. Run after changing core/audio/score_audio.gd. Usage: tools/gen_audio.sh
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/tools/_common.sh"
godot_import  # class cache must know ScoreAudio
"$GODOT" --headless --path "$GAME_DIR" --audio-driver Dummy -s "$ROOT/tools/audio/render_score.gd" 2>&1 | grep -E "render_score|ERROR|SCRIPT" || true
godot_import
ls -la "$GAME_DIR/content/audio/score" | tail -n +2 | wc -l
