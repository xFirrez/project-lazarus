#!/usr/bin/env bash
# Headless Blender install check: prints the Blender version the generators will use and
# verifies the glTF exporter is available. Exit 0 = ready.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMP="$(mktemp -d)"
cat >"$TMP/check.py" <<'PY'
import bpy, sys
print("[blender] version", bpy.app.version_string)
assert hasattr(bpy.ops.export_scene, "gltf"), "glTF exporter add-on missing"
print("[blender] glTF exporter ok")
PY
"$DIR/_run.sh" "$TMP/check.py" 2>&1 | grep '^\[blender\]'
rm -rf "$TMP"
