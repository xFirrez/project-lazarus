# MatchSession — per-match co-op session rules (GAME_DESIGN §13, ARCHITECTURE §5.2):
#  * scene-ready gate: after a lobby start the host's RoundDirector holds until every peer reports
#    `_scene_ready` (or SCENE_READY_TIMEOUT passes), so round 1 starts for everyone together;
#  * late join: a joiner mid-round spectates and spawns at the next round start with
#    500 + 250 x round points (max 5000) and the starting loadout;
#  * reconnect: a leaving player's state (points, stats, weapons + ammo, perks, character) is
#    retained by `player_uid` for the rest of the match and restored on rejoin (perks only if they
#    weren't downed); they respawn at the next round start;
#  * match flags: generic shared world flags (power, box location, quest flags; filled by Steps
#    9-14) replicated with the full join snapshot;
#  * convergence: `state_digest()` / `state_hash()` over round, zones, doors, barricades, flags,
#    each player's points / weapons / perks and the zombie count; clients report their hash at
#    every round end and the host counts matches / mismatches (AC-7.1, desync detection);
#  * bandwidth: clients sample their downstream rate (AC-7.4).
#   peer -> host : `_scene_ready` []                    `_hash_report` [round, hash, digest]
#   host -> all  : `_flag` [key, value]                 host -> peer: `_flags_full` [{flags}]
#   host -> peer : `_join_done` [round, waiting, late_points, restored]   (end of the join snapshot)
# Authority: HOST decides admission / restores; every peer computes its own digest.
class_name MatchSession
extends Node

signal join_completed(waiting: bool)  # client: the full join snapshot has arrived
signal hash_compared(round_number: int, peer_id: int, ok: bool)  # host
signal player_retained(uid: String, record: Dictionary)  # host
signal player_restored(peer_id: int, uid: String)  # host
signal flag_changed(key: String, value: Variant)  # every peer: host set / relayed / join snapshot

const SCENE_READY_TIMEOUT: float = 30.0
const BANDWIDTH_LOG_INTERVAL: float = 10.0

var match_node: Match = null
var flags: Dictionary = {}  # String -> Variant (power, box location, quest flags ...)
var retained: Dictionary = {}  # host: uid -> record (see _capture)
var hash_matches: int = 0
var hash_mismatches: int = 0
var hash_log: Array = []  # host: [round, peer, ok]
var bandwidth_peak: float = 0.0  # client: max downstream bytes/s over 1 s windows
var bandwidth_samples: PackedFloat32Array = []
var joined_at: float = -1.0  # client: Net.now() when the session (welcome) started
var join_snapshot_seconds: float = -1.0  # client: welcome -> `_join_done`
var waiting_ready: Dictionary = {}  # host: peer -> false until `_scene_ready`

var _gate_started: float = 0.0
var _gate_open: bool = true
var _bw_timer: float = 0.0
var _bw_log_timer: float = 0.0
var _peer_uids: Dictionary = {}  # host: peer -> uid (for the leave capture)
var _host_hashes: Dictionary = {}  # host: round -> {hash, digest}


static func is_authority() -> bool:
	return Net.is_host() or not Net.is_active()


static func late_join_points(round_number: int) -> int:
	return PointsRules.late_join_points(round_number)


func _ready() -> void:
	name = "Session"
	for m: StringName in [&"_scene_ready", &"_hash_report", &"_flag", &"_flags_full", &"_join_done"]:
		Net.register_message(m, Callable(self, "_on_msg" + String(m)))
	# Connected before PlayerSync / WeaponSync / PointsLedger (Match adds this node first), so the
	# leave capture still sees the player's points and loadout.
	Net.peer_joined.connect(_on_peer_joined)
	Net.peer_left.connect(_on_peer_left)
	Session.retained_lookup = func(uid: String) -> bool: return retained.has(uid)
	for id: int in Net.peer_ids():
		_peer_uids[id] = String((Net.peers[id] as Dictionary).get("uid", ""))


func _exit_tree() -> void:
	for m: StringName in [&"_scene_ready", &"_hash_report", &"_flag", &"_flags_full", &"_join_done"]:
		Net.unregister_message(m)
	Session.retained_lookup = Callable()


# Called by Match.setup once every system exists.
func on_match_ready(from_lobby: bool) -> void:
	var rd: RoundDirector = match_node.rounds
	if rd != null:
		rd.phase_changed.connect(_on_phase_changed)
	if Net.is_host() and from_lobby:
		for id: int in Net.peer_ids():
			if id != Net.local_id():
				waiting_ready[id] = false
		_gate_open = waiting_ready.is_empty()
		_gate_started = Net.now()
		if not _gate_open:
			Log.info(&"session", "Waiting for %d peer(s) to load" % waiting_ready.size())
	if not Net.is_host() and Net.is_active():
		Net.send_reliable(1, &"_scene_ready", [])


func gate_open() -> bool:
	return _gate_open


# --- host API -----------------------------------------------------------------------------------


func host_set_flag(key: String, value: Variant) -> void:
	if not is_authority():
		return
	flags[key] = value
	Net.send_reliable(0, &"_flag", [key, value])
	flag_changed.emit(key, value)


func flag(key: String, default: Variant = null) -> Variant:
	return flags.get(key, default)


func has_retained(uid: String) -> bool:
	return retained.has(uid)


# --- convergence --------------------------------------------------------------------------------


# Everything every peer must agree on at a round end, as sorted "key=value" lines.
func state_digest() -> PackedStringArray:
	var m: Match = match_node
	var lines: PackedStringArray = []
	if m.rounds != null:
		lines.append("round=%d" % m.rounds.current_round)
	if m.zones != null:
		var z: Array = m.zones.unlocked.keys()
		z.sort()
		lines.append("zones=%s" % ",".join(PackedStringArray(z)))
	if m.world != null:
		lines.append_array(m.world.digest())
	var keys: Array = flags.keys()
	keys.sort()
	for k: Variant in keys:
		lines.append("flag.%s=%s" % [k, str(flags[k])])
	for id: int in Net.peer_ids():
		var pts: int = m.points.get_points(id) if m.points != null else 0
		var w: String = m.weapons.mirror_digest_of(id) if m.weapons != null else "-"
		var pk: String = m.perks.digest_of(id) if m.perks != null else ""
		lines.append("player.%s=%d|%s|perks:%s" % [_uid_of(id), pts, w, pk])
	if m.zombies != null:
		lines.append("zombies=%d" % m.zombies.alive_count())
	lines.sort()
	return lines


func state_hash() -> int:
	return hash("\n".join(state_digest()))


func _uid_of(peer_id: int) -> String:
	var info: Dictionary = Net.peers.get(peer_id, {})
	return String(info.get("uid", str(peer_id))).substr(0, 8)


func _on_phase_changed(phase: int) -> void:
	if phase == RoundDirector.Phase.ACTIVE:
		Session.update_steam_metadata()
	if phase != RoundDirector.Phase.INTERMISSION or not Net.is_active():
		return
	var r: int = match_node.rounds.current_round
	if Net.is_host():
		_host_hashes[r] = {"hash": state_hash(), "digest": "\n".join(state_digest())}
		return
	Net.send_reliable(1, &"_hash_report", [r, state_hash(), "\n".join(state_digest())])


# --- host: admission / retention ----------------------------------------------------------------


func _on_peer_joined(peer_id: int, info: Dictionary) -> void:
	_peer_uids[peer_id] = String(info.get("uid", ""))
	if not Net.is_host() or peer_id == Net.local_id():
		return
	# After every other system's join snapshot / default state (they handle the same signal).
	_host_admit.call_deferred(peer_id)


func _host_admit(peer_id: int) -> void:
	var m: Match = match_node
	if not is_inside_tree() or not m.players.avatars.has(peer_id):
		return
	var uid: String = String(_peer_uids.get(peer_id, ""))
	var rd: RoundDirector = m.rounds
	var round_now: int = rd.current_round if rd != null else 0
	var restored: bool = false
	var late_pts: int = -1
	if retained.has(uid):
		_restore(peer_id, uid)
		restored = true
	elif rd != null and rd.enabled and round_now >= 1:
		late_pts = late_join_points(round_now)
		m.points.host_set(peer_id, late_pts)
	var waiting: bool = rd != null and rd.enabled and rd.phase == RoundDirector.Phase.ACTIVE
	if waiting and m.downed != null:
		m.downed.host_set_waiting(peer_id)
	Net.send_reliable(peer_id, &"_flags_full", [flags])
	Net.send_reliable(peer_id, &"_join_done", [round_now, waiting, late_pts, restored])
	Log.info(
		&"session",
		(
			"Admitted peer %d (round %d, %s%s)"
			% [peer_id, round_now, "waiting" if waiting else "playing", ", restored" if restored else ""]
		)
	)


func _on_peer_left(peer_id: int) -> void:
	if Net.is_host() and match_node != null and not (match_node.downed != null and match_node.downed.is_game_over):
		_capture(peer_id)
	waiting_ready.erase(peer_id)
	_peer_uids.erase(peer_id)


func _capture(peer_id: int) -> void:
	var m: Match = match_node
	var uid: String = String(_peer_uids.get(peer_id, ""))
	if uid == "" or not m.players.avatars.has(peer_id):
		return
	var was_downed: bool = m.downed != null and m.downed.state_of(peer_id) == DownedSystem.State.DOWNED
	var avatar: PlayerCharacter = m.players.avatars[peer_id]
	retained[uid] = {
		"peer": peer_id,
		"name": avatar.display_name,
		"character": String(avatar.character_id),
		"points": m.points.get_points(peer_id),
		"stats": m.points.stats_of(peer_id),
		"loadout": m.weapons.host_export(peer_id),
		"perks": [] if was_downed or m.perks == null else PerkSystem._strings(m.perks.ids_of(peer_id)),
		"downed": was_downed,
	}
	player_retained.emit(uid, retained[uid])
	Log.info(
		&"session",
		"Retained state of %s (uid %s): %d points" % [avatar.display_name, uid.substr(0, 8), retained[uid]["points"]]
	)


func _restore(peer_id: int, uid: String) -> void:
	var m: Match = match_node
	var rec: Dictionary = retained[uid]
	retained.erase(uid)
	m.points.host_transfer(int(rec["peer"]), peer_id, int(rec["points"]), rec["stats"] as Dictionary)
	# Perks first: Pack Mule's third slot must exist before the loadout is imported.
	if m.perks != null:
		m.perks.host_set_perks(peer_id, rec["perks"] as Array)
	m.weapons.host_import(peer_id, rec["loadout"] as Dictionary)
	Log.info(&"session", "Restored %s (uid %s) as peer %d" % [rec["name"], uid.substr(0, 8), peer_id])
	player_restored.emit(peer_id, uid)


# --- frame --------------------------------------------------------------------------------------


func _process(delta: float) -> void:
	if Net.is_host() and not _gate_open:
		var all_ready: bool = true
		for id: int in waiting_ready:
			if not bool(waiting_ready[id]):
				all_ready = false
		if all_ready or Net.now() - _gate_started > SCENE_READY_TIMEOUT:
			_open_gate(all_ready)
	if Net.is_active() and not Net.is_host():
		_bw_timer += delta
		if _bw_timer >= 1.0:
			_bw_timer = 0.0
			bandwidth_samples.append(Net.bytes_in_per_sec)
			bandwidth_peak = maxf(bandwidth_peak, Net.bytes_in_per_sec)
		_bw_log_timer += delta
		if _bw_log_timer >= BANDWIDTH_LOG_INTERVAL:
			_bw_log_timer = 0.0
			Log.info(
				&"session",
				"bandwidth down %.1f KB/s (peak %.1f)" % [Net.bytes_in_per_sec / 1024.0, bandwidth_peak / 1024.0]
			)


func bandwidth_average() -> float:
	if bandwidth_samples.is_empty():
		return 0.0
	var sum: float = 0.0
	for v: float in bandwidth_samples:
		sum += v
	return sum / bandwidth_samples.size()


func _open_gate(all_ready: bool) -> void:
	_gate_open = true
	if not all_ready:
		Log.warn(&"session", "Scene-ready timeout; starting without %s" % str(waiting_ready))
	else:
		Log.info(&"session", "All peers loaded")
	if match_node.rounds != null:
		match_node.rounds.host_release()


# --- messages -----------------------------------------------------------------------------------


func _on_msg_scene_ready(sender: int, _p: Array) -> void:
	if Net.is_host() and waiting_ready.has(sender):
		waiting_ready[sender] = true
		Log.info(&"session", "Peer %d loaded" % sender)


func _on_msg_hash_report(sender: int, p: Array) -> void:
	if not Net.is_host():
		return
	var r: int = int(p[0])
	# The host's own digest for that round end was taken when it entered the intermission.
	var mine: Dictionary = _host_hashes.get(r, {})
	var ok: bool = not mine.is_empty() and int(mine["hash"]) == int(p[1])
	if ok:
		hash_matches += 1
	else:
		hash_mismatches += 1
		Log.warn(
			&"session",
			"State hash mismatch round %d peer %d:\n host: %s\n peer: %s" % [r, sender, mine.get("digest", "?"), p[2]]
		)
	hash_log.append([r, sender, ok])
	hash_compared.emit(r, sender, ok)


func _on_msg_flag(sender: int, p: Array) -> void:
	if sender == 1 and not Net.is_host():
		flags[String(p[0])] = p[1]
		flag_changed.emit(String(p[0]), p[1])


func _on_msg_flags_full(sender: int, p: Array) -> void:
	if sender == 1 and not Net.is_host():
		flags = (p[0] as Dictionary).duplicate()
		for k: Variant in flags.keys():
			flag_changed.emit(String(k), flags[k])


func _on_msg_join_done(sender: int, p: Array) -> void:
	if sender != 1 or Net.is_host():
		return
	if joined_at > 0.0:
		join_snapshot_seconds = Net.now() - joined_at
	Log.info(
		&"session",
		(
			"Join snapshot complete in %.2f s (round %d, %s, late points %d, restored %s)"
			% [join_snapshot_seconds, int(p[0]), "waiting" if bool(p[1]) else "playing", int(p[2]), p[3]]
		)
	)
	join_completed.emit(bool(p[1]))
