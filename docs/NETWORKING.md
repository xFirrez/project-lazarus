# Project Lazarus — Playing online (co-op networking guide)

> How friends connect for co-op (Step 7, decision D-045). Architecture: listen server, host-authoritative (ARCHITECTURE §5). Up to 4 players. No host migration: if the host leaves, the match ends for everyone with a summary screen.

## 1. Quick start

| You are | Do this |
|---|---|
| **Host** | Main menu → **Host co-op** → pick the map → you are in the **lobby**. Tell friends your address (see §2). When everyone is **Ready**, press **Start** (3 s countdown). |
| **Friend** | Main menu → type the host's `ip[:port]` → **Join**. Pick a free survivor, press **Ready**. |
| **Solo** | Main menu → **Solo** → pick the map. |

Lobby: four slots, one survivor each (Calloway, Orlov, Brandt, Ashcombe — unique per lobby), ready-up, text chat, host settings (map, **late join** on/off, *starting round* in dev builds). The match starts on every machine together: round 1 waits until every peer reports its map loaded ("Waiting for all players to load ...", 30 s timeout).

**Late join** (host option, default on): a friend joining a running match spectates and spawns at the next round start with 500 + 250 × round points (max 5000) and the starting pistol. With late join off, new joins are refused with a message. **Reconnect** (always allowed): a player who drops (crash, network) keeps their points, weapons, perks (unless downed) and survivor for the rest of the match; on rejoin from the same machine/profile they spawn at the next round with all of it. A crashed client may rejoin immediately (the stale connection is replaced).

## 2. Connecting over the internet without Steam (always available)

The host listens on **UDP 24565** (`--host=<port>` to change it). One of these must be true for friends outside your LAN:

1. **UPnP (automatic, best effort).** When hosting from the menu the game tries to open UDP 24565 on your router (Settings → *Try UPnP when hosting*). The lobby shows the result: `UPnP: port 24565 open — friends join <external ip>:24565`, or why it failed (no UPnP router, carrier-grade NAT).
2. **Port forward** UDP 24565 on your router to the host PC; friends join `<your public ip>:24565`.
3. **VPN mesh (recommended when 1–2 fail): Tailscale** (or ZeroTier).
   - Everyone installs Tailscale and signs in; the host shares their tailnet node with friends (Tailscale admin console → *Share*), or everyone joins the same tailnet.
   - Friends join `<host's 100.x.y.z Tailscale IP>:24565`. No router changes; works behind CGNAT.
4. **LAN:** join the host's local IP.

Firewalls: allow the Godot/Project Lazarus executable (UDP in) on the host.

## 3. Steam (optional)

Steam lobbies + invites use the **GodotSteam GDExtension** (not vendored in the repo; D-045).

1. Install the Steam client and log in.
2. Download the GodotSteam **GDExtension** build that matches the pinned engine (`tools/godot_version.txt`, Godot 4.7.x) from the GodotSteam project (Godot Asset Library: "GodotSteam GDExtension"), and copy its `addons/godotsteam/` folder into `game/addons/`. Log the version in `docs/ASSET_LICENSES.md` (MIT) and keep the Steamworks redistributables next to the exported game.
3. For development the game uses **App ID 480** (Valve's public test app); put `480` in `steam_appid.txt` next to the editor/executable if GodotSteam asks for it.
4. Restart the game: the main menu shows **Steam lobby (invite friends)**. The host creates a friends-only lobby (metadata: map, players, round, version) and invites through the Steam overlay; friends join via the invite or the friend list. Traffic goes over Steam's relay (no port forwarding).

The game detects GodotSteam at runtime (`SteamTransport.is_available()`); without it the Steam button is hidden and everything else works. The live Steam path is untested in the cloud CI container (no Steam client) — see the Step 7 human tasks.

## 4. What to report from a test session (AC-7.6)

Host + at least one friend over the internet, 10+ rounds: which path you used (UPnP / forward / Tailscale / Steam), time from "Join" to being in the lobby, the ping shown in the lobby (`net_status` / F3 overlay in game), and any rubber-banding, desync (`session` console command prints state-hash results), or disconnects. Add a row to `docs/PROGRESS.md` (Test results log + Network baselines).

## 5. Developer notes

- `tools/run_coop_local.sh N [--netsim=ms,jitter,loss]` runs a host + N−1 clients locally. CLI `--host` starts the match immediately (dev quick host, no lobby); `--host --lobby` uses the lobby; `--upnp` tries UPnP.
- Console: `lobby`, `ready`, `character <id>`, `say <text>`, `late_join <bool>`, `start_round <n>`, `lobby_start`, `session`, `state_hash`, `round_pause`, `match_flag`, `ping`.
- Tests: `tools/net_tests.sh lobby late_join reconnect coop4` (coop4 = 4 clients at 150 ms / 30 ms / 3 % loss, 10 rounds, state-hash convergence + bandwidth).
