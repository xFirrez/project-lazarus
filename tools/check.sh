#!/usr/bin/env bash
# Fast pre-commit gate: import, lint, format check, core->maps boundary, unit tests.
# Usage: tools/check.sh            (run before every commit; CI runs the same)
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/tools/_common.sh"
cd "$ROOT"

GD_PATHS=(game/core game/tests game/maps tools)
step() { printf '\n== %s\n' "$1"; }

step "Godot import ($("$GODOT" --version))"
godot_import
echo "import ok"

step "gdlint"
gdlint "${GD_PATHS[@]}"

step "gdformat --check"
gdformat --line-length 120 --check "${GD_PATHS[@]}"

step "core -> maps boundary"
if grep -rn --include='*.gd' --include='*.tscn' --include='*.tres' -E 'res://maps/' game/core; then
  echo "core/ must not reference maps/ (ARCHITECTURE §3). Move map-specific code to maps/<map>/scripts/." >&2
  exit 1
fi
echo "boundary ok"

step "bare print() check"
if grep -rn --include='*.gd' -E '^\s*print(err)?\(' game/core game/maps | grep -v 'core/autoload/log.gd'; then
  echo "Use Log.info/warn/error instead of print() (AGENT_GUIDE §11)." >&2
  exit 1
fi
echo "no bare prints"

step "generated data current"
python3 "$ROOT/tools/gen_credits.py" --check
echo "credits ok"

step "unit tests"
"$ROOT/tools/run_tests.sh" unit

printf '\ncheck.sh: all green\n'
