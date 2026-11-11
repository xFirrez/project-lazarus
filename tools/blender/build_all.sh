#!/usr/bin/env bash
# Regenerates every scripted asset (kit, props, characters, weapons). Deterministic: re-running
# without script changes reproduces the same geometry.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$DIR/check_install.sh"
"$DIR/build_kit.sh"
"$DIR/build_props.sh"
"$DIR/build_characters.sh"
"$DIR/build_weapons.sh"
