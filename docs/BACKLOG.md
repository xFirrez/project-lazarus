# Project Lazarus — Post-1.0 backlog

> Written at the end of Step 16 (release candidate 1.0.0-rc1). Everything here is **out of scope for Vesper Peak 1.0** (DEVELOPMENT_PLAN §19) or a known gap that was accepted for 1.0 with a reason in `docs/PROGRESS.md` (*Deferrals*, *Unresolved issues*). Rough priority within each group: top first.

## 1. Content

| Item | Notes |
|---|---|
| Authored art pass for procedural ("greybox+") assets | Perk machines, Relic Box, Forge / relays / traps, 22 non-M1911 weapons + arms, Ray Pistol / Conduit, Galvanic / Warden, buildable parts. Pipeline exists (ART_PIPELINE, `bpy` generators, drop-in scenes); I-033 |
| Recorded VO, quips and announcer | Drop-in by file name (`content/audio/vo/…`), no code changes; currently a synthesized voice + subtitles |
| Recorded weapon / zombie audio | Synthesized events are final-accepted in `audio_manifest.json`; replace per event |
| Zombie model variety | 6 base models × variants (GAME_DESIGN §5.1); one orderly model with 3 material variants ships (I-007) |
| Additional maps | `MapDefinition` + `MapRules` + `maps/<id>/` (ARCHITECTURE §9); the core never references a map |
| Additional zombie animation clips | Lunge, rise, vent drop, electrocuted, Warden slam / charge (currently reused clips) |

## 2. Features

| Item | Notes |
|---|---|
| Easter-egg hint mode | Optional in-world hints / journal nudges per stage |
| Built-in voice chat | Stretch: Steam voice via GodotSteam |
| Steam release pipeline | Needs a Steamworks App ID: depots for `build/linux` + `build/windows`, `steam_appid.txt`, GodotSteam GDExtension vendored per its license; `SteamTransport` exists (D-045) |
| Host migration / dedicated servers | Listen server only in 1.0 (ARCHITECTURE §5) |
| Matchmaking with strangers, online leaderboards | — |
| Motion blur setting | Godot 4.7 has no built-in motion blur; would need a custom compositor effect. Not exposed rather than shipping a dead option |
| Aim assist beyond the light slowdown | 1.0 ships the gamepad aim slowdown only (Settings → Gamepad) |
| Split-screen, mod support, console ports, other modes (Grief) | DEVELOPMENT_PLAN §19 |
| Code signing (Windows SmartScreen), macOS build | Needs certificates / notarization accounts |

## 3. Technical

| Item | Notes |
|---|---|
| Hierarchical zone routing / path cache | I-016 / I-020: full-map AI p99 ≈ budget in the container; long detour paths re-queue |
| Predicted Conduit arcs on the shooter | I-029 |
| Frag / decoy as deterministic projectiles | I-005 |
| Interpolation under frame hitches | I-012 / I-023 (container-only test flakes) |
| Bake perk machine footprints into the navmesh | I-024 |
| LightmapGI for interiors | Needs the desktop editor + GPU |
| Release-template "nonexistent connection … tree_exited" log line | I-036, engine-side, harmless |

## 4. Balance follow-ups (after human runs)

- AC-16.5: five human solo runs vs GAME_DESIGN §6.3; `tools/run_sim.sh balance` is the model to recalibrate (headshot ratio, planks, purchase order) against those runs.
- Wall-buys below the median tier (Model 37 per-shell reload, M14 / Coachgun as round 1–8 weapons) — revisit after the AC-3.7 / AC-9.7 feel reviews.
- Warden late-round health (25 × hp × players) at r50+ is very high with 4 players (≈ 4.7 M at r50): judge in AC-16.4's human run.
