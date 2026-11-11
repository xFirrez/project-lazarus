# Asset & third-party licenses

Every third-party file in the repository is listed here (AGENT_GUIDE rule 8). If a license is unknown, the file is not used.

| Path | What | Source | Author | License | Added (step) |
|---|---|---|---|---|---|
| `game/addons/gut/` | GUT — Godot Unit Test addon v9.7.1 (test tooling only, not shipped in exports) | https://github.com/bitwes/Gut (tag v9.7.1) | Butch Wesley and contributors | MIT (`game/addons/gut/LICENSE.md`) | 1 |
| *(engine)* | Godot Engine 4.7.2-stable (not vendored; downloaded by `tools/install_godot.sh`) | https://godotengine.org | Godot Engine contributors | MIT | 1 |

Generated placeholders (no third-party source): placeholder UI tones are synthesized at runtime in `core/autoload/audio.gd`; sandbox geometry uses Godot primitive meshes.
