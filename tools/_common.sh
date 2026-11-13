# Shared helpers for tools/*.sh (sourced, not executed).
ROOT="${ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
GAME_DIR="$ROOT/game"
GODOT="${GODOT:-}"
if [[ -z "$GODOT" ]]; then
  if command -v godot >/dev/null 2>&1; then
    GODOT="$(command -v godot)"
  elif [[ -x "$HOME/.local/bin/godot" ]]; then
    GODOT="$HOME/.local/bin/godot"
  else
    echo "godot not found: run tools/install_godot.sh" >&2
    exit 1
  fi
fi
export GODOT GAME_DIR ROOT

# Fails (returns 1) if a Godot log contains script/engine errors.
# Known-benign lines from a display-less container are filtered out.
godot_log_has_errors() {
  local log="$1"
  grep -E "SCRIPT ERROR|Parse Error|^ERROR:|^USER ERROR|Failed to load script|Compile Error" "$log" \
    | grep -v -E "audio_driver_alsa|All audio drivers failed|init_output_device|Texture with GL ID of [0-9]+: leaked" >/dev/null
  # (GL exit message: menu screens' default-font glyph atlases under opengl3 / xvfb, I-013)
}

godot_import() {
  # Imports resources / builds the class cache. Required on a fresh checkout.
  local log
  log="$(mktemp)"
  "$GODOT" --headless --path "$GAME_DIR" --import >"$log" 2>&1 || true
  if godot_log_has_errors "$log"; then
    grep -E "SCRIPT ERROR|Parse Error|ERROR" -A2 "$log" | head -60 >&2
    rm -f "$log"
    return 1
  fi
  rm -f "$log"
}
