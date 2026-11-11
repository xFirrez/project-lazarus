# Project Lazarus — instructions for coding agents

Before doing any work, read `docs/AGENT_GUIDE.md` and follow its reading order (it begins with `docs/PROGRESS.md`).

- Engine: Godot 4 (pinned in `tools/godot_version.txt`), statically typed GDScript. Godot project root: `game/`.
- Implement only the step or checkpoint you were assigned in `docs/DEVELOPMENT_PLAN.md`.
- Host-authoritative networking, one code path for solo and co-op, `core/` never references `maps/`.
- Run `tools/check.sh` before every commit. Update `docs/PROGRESS.md` and add a session report in `docs/sessions/` at the end of every session.
