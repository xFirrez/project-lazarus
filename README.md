# Project Lazarus

[![CI](https://github.com/xFirrez/project-lazarus/actions/workflows/ci.yml/badge.svg?branch=claude/project-lazarus)](https://github.com/xFirrez/project-lazarus/actions/workflows/ci.yml)

A 3D first-person, round-based zombie survival game for solo play and 4-player online co-op, built with Godot 4. The first map is **Vesper Peak**: a 1964 Cold War research installation hidden in a snowbound mountain sanatorium.

**Status:** Step 1 of the roadmap complete — Godot 4 foundation, net layer and a co-op sandbox (see [PROGRESS.md](PROGRESS.md) and [docs/PROGRESS.md](docs/PROGRESS.md)).

## Quick start

```bash
tools/install_godot.sh          # pinned Godot 4.7.2 -> ~/.local/bin/godot
pip install gdtoolkit==4.5.0
tools/check.sh                  # import, lint, format, boundary check, unit tests
godot --path game               # run the game (Solo / Host / Join)
tools/run_coop_local.sh 2 --windowed --netsim=100,20,0.02   # host + client on localhost
```

## Documentation

| Document | Contents |
|---|---|
| [docs/DEVELOPMENT_PLAN.md](docs/DEVELOPMENT_PLAN.md) | The 16-step roadmap: scope, dependencies, deliverables, acceptance criteria, milestones, risks |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Engine and tools, project layout, networking, systems, testing, performance |
| [docs/GAME_DESIGN.md](docs/GAME_DESIGN.md) | Gameplay rules and tuning: movement, weapons, zombies, rounds, economy, perks, box, Forge, co-op |
| [docs/VESPER_PEAK.md](docs/VESPER_PEAK.md) | Map design: zones, doors, progression, landmarks, atmosphere, the Easter egg storyline |
| [docs/PROGRESS.md](docs/PROGRESS.md) | Live tracker: step status, acceptance checklists, test results, issues, human tasks |
| [docs/AGENT_GUIDE.md](docs/AGENT_GUIDE.md) | How a coding session picks up, implements, tests, documents and reports a step |
