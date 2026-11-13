# SurvivalCommands — console commands for the survival loop (Step 6 scope 13): points, rounds,
# doors, downs, revive, notarget, host bots. On a client, commands that change shared state are
# sent to the host as `_cheat` [name, int arg] and applied to the sender (dev builds only).
# Authority: shared-state changes run on the host; read-only commands read local mirrors.
class_name SurvivalCommands
extends RefCounted


static func register(reg: CommandRegistry) -> void:
	reg.register(
		"give_points",
		_cmd_give_points,
		[["amount", TYPE_INT, 5000], ["peer", TYPE_INT, 0]],
		"Add points (default self)"
	)
	reg.register("set_round", _cmd_set_round, [["round", TYPE_INT]], "Host: start round N now")
	reg.register("round_pause", _cmd_round_pause, [["on", TYPE_BOOL, true]], "Host: freeze intro/intermission")
	reg.register("state_hash", _cmd_state_hash, [], "Co-op state digest + hash (desync checks)")
	reg.register("session", _cmd_session, [], "Late join / reconnect / hash / bandwidth status")
	reg.register(
		"match_flag", _cmd_match_flag, [["key", TYPE_STRING], ["value", TYPE_STRING]], "Host: set a match flag"
	)
	reg.register("ping", _cmd_ping, [], "Ping what is under the crosshair")
	reg.register("skip_round", _cmd_skip_round, [], "Host: kill this round's zombies and end it")
	reg.register("open_all_doors", _cmd_open_all, [], "Host: open every purchasable door (no cost)")
	reg.register("down_me", _cmd_down_me, [], "Go down (last stand) now")
	reg.register("revive", _cmd_revive, [["peer", TYPE_INT, 0]], "Host: revive a downed player (0 = all)")
	reg.register("bleedout", _cmd_bleedout, [["peer", TYPE_INT, 0]], "Host: bleed out a downed player (0 = all)")
	reg.register("notarget", _cmd_notarget, [["on", TYPE_BOOL]], "Zombies ignore you")
	reg.register("round_info", _cmd_round_info, [], "Round, phase, totals, queue, spawns, fairness")
	reg.register("points", _cmd_points, [], "Every player's points and stats")
	reg.register("bots", _cmd_bots, [["count", TYPE_INT, 1]], "Host: add survival bot players (soak tests)")
	reg.register("buy", _cmd_buy, [["name", TYPE_STRING]], "Use an interactable by node name (pays normally)")


static func _cmd_round_pause(args: Array) -> String:
	var m: Match = _m()
	if m == null or not _is_host():
		return "host only"
	m.rounds.paused = bool(args[0])
	return "rounds %s" % ("paused" if m.rounds.paused else "running")


static func _cmd_state_hash(_args: Array) -> String:
	var m: Match = _m()
	if m == null:
		return "no match"
	return "%s\nhash %d" % ["\n".join(m.session.state_digest()), m.session.state_hash()]


static func _cmd_session(_args: Array) -> String:
	var m: Match = _m()
	if m == null:
		return "no match"
	var s: MatchSession = m.session
	return (
		"gate_open=%s retained=%s hashes ok=%d bad=%d bw_avg=%.1f KB/s peak=%.1f KB/s join_snapshot=%.2f s"
		% [
			s.gate_open(),
			str(s.retained.keys()),
			s.hash_matches,
			s.hash_mismatches,
			s.bandwidth_average() / 1024.0,
			s.bandwidth_peak / 1024.0,
			s.join_snapshot_seconds
		]
	)


static func _cmd_match_flag(args: Array) -> String:
	var m: Match = _m()
	if m == null or not _is_host():
		return "host only"
	m.session.host_set_flag(String(args[0]), String(args[1]))
	return "flag %s = %s" % [args[0], args[1]]


static func _cmd_ping(_args: Array) -> String:
	var m: Match = _m()
	if m == null:
		return "no match"
	return "pinged" if m.pings.ping_from_view() else "cannot ping now"


static func _m() -> Match:
	return Match.current


static func _local_id() -> int:
	return Net.local_id() if Net.is_active() else 1


static func _is_host() -> bool:
	return Net.is_host() or not Net.is_active()


# Runs a cheat for `peer` on the host (called directly on the host, or from `_cheat`).
static func host_exec(peer: int, cmd: String, arg: int) -> String:
	var m: Match = _m()
	if m == null:
		return "no match"
	match cmd:
		"give_points":
			m.points.host_earn(peer, arg)
			return "peer %d now has %d points" % [peer, m.points.get_points(peer)]
		"down_me":
			m.downed.host_force_down(peer)
			return "peer %d downed" % peer
		"notarget":
			if m.players.avatars.has(peer):
				(m.players.avatars[peer] as PlayerCharacter).notarget = arg != 0
			return "notarget %s for %d" % ["on" if arg != 0 else "off", peer]
		"god":
			if m.players.avatars.has(peer):
				(m.players.avatars[peer] as PlayerCharacter).health.invulnerable = arg != 0
			return "god %s for %d" % ["on" if arg != 0 else "off", peer]
	return "unknown cheat %s" % cmd


static func request(cmd: String, arg: int) -> String:
	if _m() == null:
		return "no match"
	if _is_host():
		return host_exec(_local_id(), cmd, arg)
	Net.send_reliable(1, &"_cheat", [cmd, arg])
	return "requested %s from host" % cmd


static func on_msg_cheat(sender: int, p: Array) -> void:
	if Net.is_host() and p.size() >= 2:
		Log.info(&"console", host_exec(sender, String(p[0]), int(p[1])))


static func _cmd_give_points(args: Array) -> String:
	var peer: int = int(args[1])
	if peer != 0 and _is_host():
		return host_exec(peer, "give_points", int(args[0]))
	return request("give_points", int(args[0]))


static func _cmd_set_round(args: Array) -> String:
	if _m() == null or not _is_host():
		return "host only"
	_m().rounds.host_start_round(int(args[0]))
	return "round %d" % _m().rounds.current_round


static func _cmd_skip_round(_args: Array) -> String:
	if _m() == null or not _is_host():
		return "host only"
	_m().rounds.host_skip_round()
	return "skipped (now %s, round %d)" % [_m().rounds.phase_name(), _m().rounds.current_round]


static func _cmd_open_all(_args: Array) -> String:
	if _m() == null or not _is_host():
		return "host only"
	var n: int = 0
	for it: Interactable in _m().interaction.interactables:
		if it is PurchasableDoor and not (it as PurchasableDoor).is_open():
			(it as PurchasableDoor).host_open(_local_id())
			n += 1
	return "opened %d doors" % n


static func _cmd_down_me(_args: Array) -> String:
	return request("down_me", 0)


static func _cmd_revive(args: Array) -> String:
	if _m() == null or not _is_host():
		return "host only"
	var ds: DownedSystem = _m().downed
	for id: int in ds.states.keys():
		if int(args[0]) == 0 or id == int(args[0]):
			ds.host_revive(id)
	return "revived"


static func _cmd_bleedout(args: Array) -> String:
	if _m() == null or not _is_host():
		return "host only"
	var ds: DownedSystem = _m().downed
	for id: int in ds.states.keys():
		if int(args[0]) == 0 or id == int(args[0]):
			ds.host_bleed_out(id)
	return "bled out"


static func _cmd_notarget(args: Array) -> String:
	return request("notarget", 1 if bool(args[0]) else 0)


static func _cmd_round_info(_args: Array) -> String:
	var m: Match = _m()
	if m == null:
		return "no match"
	var rd: RoundDirector = m.rounds
	var text: String = (
		"round %d %s t=%.1f total %d killed %d queue %d alive %d requeued %d hp %.0f"
		% [
			rd.current_round,
			rd.phase_name(),
			rd.time_left,
			rd.total,
			rd.killed,
			rd.queue.size(),
			rd.round_ids.size(),
			rd.requeued,
			rd.zombie_health()
		]
	)
	if m.spawns != null and m.spawns.is_inside_tree():
		text += (
			"\nspawns %d violations %d stalls %d min dist %.1f active zones %s"
			% [
				m.spawns.spawns,
				m.spawns.violations,
				m.spawns.stalls,
				m.spawns.min_distance_seen,
				m.zones.active_zones()
			]
		)
	return text


static func _cmd_points(_args: Array) -> String:
	var m: Match = _m()
	if m == null:
		return "no match"
	var lines: PackedStringArray = []
	for row: Variant in m.points.summary():
		lines.append(str(row))
	return "\n".join(lines)


static func _cmd_bots(args: Array) -> String:
	var m: Match = _m()
	if m == null or not Net.is_host():
		return "host only (in a session)"
	var n: int = clampi(int(args[0]), 1, 3)
	for i: int in n:
		var b: PlayerCharacter = m.players.add_bot()
		if b != null:
			SurvivalBot.attach(b, m)
	return "%d players" % m.players.avatars.size()


static func _cmd_buy(args: Array) -> String:
	var m: Match = _m()
	if m == null:
		return "no match"
	var it: Interactable = m.interaction.find_by_name(String(args[0]))
	if it == null:
		return "no interactable '%s'" % args[0]
	var me: PlayerCharacter = m.players.local_avatar()
	if me == null:
		return "no local player"
	m.interaction.request(me, it)
	return "requested %s (%s)" % [it.name, it.get_prompt(me)]
