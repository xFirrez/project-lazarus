# Project Lazarus — How to play (and how to play with friends)

Project Lazarus is a round-based zombie survival shooter for 1–4 players. Survive as many rounds as you can on **Vesper Peak**, a snowbound 1960s research sanatorium. Version 1.0.

## 1. Install and run

| Platform | Do this |
|---|---|
| **Windows** (10/11, 64-bit) | Unzip `ProjectLazarus-<version>-windows-x86_64.zip` anywhere and run `ProjectLazarus.exe`. If SmartScreen warns about an unknown publisher (the build is not code-signed), choose *More info → Run anyway*. `ProjectLazarus.console.exe` starts the same game with a log window (useful for bug reports). |
| **Linux** (x86_64, glibc 2.31+) | `tar xzf ProjectLazarus-<version>-linux-x86_64.tar.gz`, then `./linux/ProjectLazarus.x86_64`. |

Needs a Vulkan 1.0 GPU (Forward+ renderer). Keep `ProjectLazarus.pck` next to the executable.

## 2. Controls (rebind in Settings → Controls)

| Action | Keyboard / mouse | Gamepad |
|---|---|---|
| Move / look | WASD / mouse | Left / right stick |
| Jump · Sprint · Crouch (slide while sprinting) | Space · Shift · C | A · L3 · B |
| Fire · Aim | Left / right mouse | RT · LT |
| Reload · Interact (buy, repair, revive) | R · F (hold) | X · X (hold) |
| Melee · Grenade · Decoy · Tripmine | V · G · Q · 4 | R3 · RB · LB · D-pad right |
| Switch weapon | Mouse wheel / 1–3 | Y |
| Alt-fire (upgraded attachments) | B | D-pad left |
| Drop carried object | X | D-pad up (12) |
| Ping | Middle mouse / Z | D-pad down (11) |
| Scoreboard · Pause | Tab · Esc | Back · Start |

## 3. The basics

- Zombies come in rounds; each round has more and faster zombies. Kill them for **points**; shooting a zombie before killing it gives extra points, headshots and knife kills give the most.
- Spend points on **doors** (open new areas), **wall weapons** (chalk outlines on the walls; buying again refills ammo), the **Relic Box** (950: a random weapon), and **Vigor Tonics** (perk machines, max 4).
- **Repair barricades** (hold Interact at a window) for 10 points per plank.
- Turn on the **power** in the Generator Hall to wake the perk machines and traps. The three **Resonance Relays** extend the Reactor Bridge to the **Lazarus Forge** (5000: upgrades the weapon in your hands).
- When your health runs out you go **down**: a teammate can revive you (hold Interact). Solo, the Second Wind tonic revives you itself, three times.
- There is a long, optional secret quest ("Requiem for Lazarus") — look for strange notes, radios and music boxes. Your **Journal** (main menu) keeps the lore you have found.

## 4. Playing with friends (online co-op, up to 4)

One player **hosts**; the others **join** the host's address. There are no dedicated servers: the host's PC runs the match, so the player with the best upload connection should host. Everyone must run **the same version** (shown in the corner of the main menu; a mismatched version is refused with "Version mismatch").

**Host:** Main menu → **Multiplayer → Host co-op** → pick the map → you are in the **lobby**. Give your friends your address (below). When everyone shows **Ready**, press **Start**.

**Friends:** Main menu → **Multiplayer** → type the host's address (`ip` or `ip:port`) → **Join** → pick a free survivor → **Ready**.

### Which address do friends use?

The host listens on **UDP port 24565**. Pick the first option that works:

1. **Same house / LAN:** the host's local IP (e.g. `192.168.1.20`). Nothing else to do.
2. **UPnP (automatic):** with *Settings → Gameplay → Try UPnP when hosting* on, the lobby shows `UPnP: port 24565 open — friends join <address>:24565`. Give friends that address.
3. **Port forward:** in your router, forward **UDP 24565** to the host PC; friends join `<your public IP>:24565` (search "what is my IP").
4. **VPN (works everywhere, also behind CGNAT / mobile internet): Tailscale** (free) or ZeroTier. Everyone installs it and joins the same network (or the host shares their machine); friends join the host's `100.x.y.z` address.

Allow the game through the host's firewall (Windows asks the first time you host: allow on private *and* public networks if your friends connect over the internet).

### Good to know

- **Late join** (host option, on by default): a friend joining mid-match watches until the next round, then spawns with bonus points.
- **Reconnect:** if a friend's game crashes or their connection drops, they can rejoin the same address and get their points, weapons and perks back.
- If the **host** quits, the match ends for everyone.
- The in-game **F3** overlay shows FPS and ping; press **`** (backquote) for the console.

## 5. Settings worth knowing

Settings → **Video**: quality presets (Low / Medium / High / Ultra), resolution scale / FSR, V-sync, FPS cap, FOV. **Audio**: per-bus volumes, subtitles. **Controls**: sensitivity, ADS multiplier, invert, gamepad aim slowdown, hold / toggle aim, rebinding. **Interface**: HUD scale, colourblind palettes, camera bob / screen shake.

## 6. Problems?

- **Logs:** every run writes `godot.log` to the user folder — Windows `%APPDATA%\Godot\app_userdata\Project Lazarus\logs\`, Linux `~/.local/share/godot/app_userdata/Project Lazarus/logs/`. If the game crashed, the next start saves a `crash_<date>.log` there and the main menu tells you; please attach it to bug reports, with the version from the main menu.
- **Can't connect:** check the version matches, the host's firewall, and try the VPN option. "Lobby is full" means 4 players are already in.
- **Stutter in the first seconds:** the game prepares shaders behind the "Preparing the mountain…" card; if a new driver is installed the first match can take longer to load.

More detail for developers: `docs/NETWORKING.md` (networking), `docs/PROGRESS.md` (project status).
