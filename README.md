# Project Lazarus

[![CI](https://github.com/xFirrez/project-lazarus/actions/workflows/ci.yml/badge.svg?branch=claude/project-lazarus)](https://github.com/xFirrez/project-lazarus/actions/workflows/ci.yml)

A 3D first-person, round-based zombie survival game for solo play and 4-player online co-op, built with Godot 4. The first map is **Vesper Peak**: a 1964 Cold War research installation hidden in a snowbound mountain sanatorium.

**Status:** all 16 roadmap steps implemented — **Vesper Peak 1.0 release candidate (1.0.0-rc1)**. Automated acceptance criteria are met; the remaining human checks (GPU performance, feel, clean-machine builds, human balance runs) are listed in [docs/PROGRESS.md](docs/PROGRESS.md).

## Playing

**Players:** download a build (or make one, below) and read **[docs/HOW_TO_PLAY.md](docs/HOW_TO_PLAY.md)** — controls, the basics, and **how to play with friends** (host / join, UPnP, port forwarding, Tailscale).

## Release builds

```bash
tools/install_templates.sh               # pinned Godot export templates (Linux + Windows x86_64)
tools/export.sh all --channel=release    # build/ProjectLazarus-<version>-linux-x86_64.tar.gz + -windows-x86_64.zip
```

`export.sh` stamps the version + commit into the build, exports both presets, smoke-tests the exported Linux binary (a 4-player bot match and two exported binaries connecting) and packs the archives. Crash logs land in the user folder (`logs/crash_<date>.log`, see HOW_TO_PLAY §6).

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
| [docs/HOW_TO_PLAY.md](docs/HOW_TO_PLAY.md) | Player guide: install, controls, basics, playing with friends, troubleshooting |
| [docs/NETWORKING.md](docs/NETWORKING.md) | Co-op networking details (UPnP, VPN, Steam) |
| [docs/QA_TEST_PLAN.md](docs/QA_TEST_PLAN.md) | 1.0 QA plan, executed results, triaged bug list |
| [docs/BACKLOG.md](docs/BACKLOG.md) | Post-1.0 backlog |
