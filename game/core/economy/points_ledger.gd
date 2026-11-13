# PointsLedger — per-player points and match statistics (ARCHITECTURE §4, GAME_DESIGN §6). The
# host earns points from zombie damage (TargetRegistry.target_damaged: 10 per hit, counted once
# per shot per zombie; kill points by zone / kind), barricade repairs (capped per round) and
# rules; spends are validated against the balance at the moment the host processes the request,
# so concurrent requests can never double-spend.
#   host -> all : `_points` [peer, total, delta]          host -> all : `_stat` [peer, key, value]
#   host -> peer: `_points_full` [[peer, total, {stats}]...] on join
# Authority: HOST decides; every peer mirrors totals and stats (HUD, game-over screen).
class_name PointsLedger
extends Node

signal points_changed(peer_id: int, total: int, delta: int)
# HOST: base points (before Double Points) a player earned from damaging a zombie; the
# PowerUpSystem's drop counter listens (GAME_DESIGN §11).
signal zombie_points(peer_id: int, points: int, target: HitTarget, killed: bool, kind: int)

const STAT_KEYS: Array[StringName] = [
	&"kills", &"headshots", &"downs", &"revives", &"points_earned", &"doors", &"repairs", &"perks", &"box_spins"
]

var points: Dictionary = {}  # peer -> int
var stats: Dictionary = {}  # peer -> {StringName: int}
var starting_points: int = 500
var targets: TargetRegistry = null
var players: PlayerSync = null
var spends_refused: int = 0
var names: Dictionary = {}  # peer -> display name (kept after a player leaves, for the summary)
var earn_multiplier: int = 1  # host: 2 while Double Points is active (PowerUpSystem)
var _repair_round: Dictionary = {}  # peer -> points from repairs this round
var _hit_keys: Dictionary = {}  # "peer:target" -> physics frame of the last paid hit


static func is_authority() -> bool:
	return Net.is_host() or not Net.is_active()


func _ready() -> void:
	name = "Points"
	Net.register_message(&"_points", _on_msg_points)
	Net.register_message(&"_stat", _on_msg_stat)
	Net.register_message(&"_points_full", _on_msg_full)
	Net.register_message(&"_points_forget", _on_msg_forget)
	Net.peer_joined.connect(_on_peer_joined)
	if targets != null:
		targets.target_damaged.connect(_on_target_damaged)
	if players != null:
		players.avatar_spawned.connect(_on_avatar_spawned)
		for id: int in players.avatars:
			_on_avatar_spawned(id, players.avatars[id])


func _exit_tree() -> void:
	for m: StringName in [&"_points", &"_stat", &"_points_full", &"_points_forget"]:
		Net.unregister_message(m)


func _on_avatar_spawned(peer_id: int, a: PlayerCharacter) -> void:
	names[peer_id] = a.display_name
	ensure_player(peer_id)


func ensure_player(peer_id: int) -> void:
	if not points.has(peer_id):
		points[peer_id] = starting_points if is_authority() else 0
		var s: Dictionary = {}
		for k: StringName in STAT_KEYS:
			s[k] = 0
		stats[peer_id] = s
		if is_authority():
			_broadcast(peer_id, 0)


func get_points(peer_id: int) -> int:
	return int(points.get(peer_id, 0))


func stat(peer_id: int, key: StringName) -> int:
	return int((stats.get(peer_id, {}) as Dictionary).get(key, 0))


# --- host API ---------------------------------------------------------------------------------


func host_earn(peer_id: int, amount: int) -> void:
	if not is_authority() or amount == 0:
		return
	ensure_player(peer_id)
	points[peer_id] = get_points(peer_id) + amount
	if amount > 0:
		host_add_stat(peer_id, &"points_earned", amount)
	_broadcast(peer_id, amount)


# Deducts `cost` if affordable. The only way points are spent (purchases, penalties use host_lose).
func host_try_spend(peer_id: int, cost: int) -> bool:
	if not is_authority():
		return false
	ensure_player(peer_id)
	if cost < 0 or get_points(peer_id) < cost:
		spends_refused += 1
		return false
	if cost > 0:
		points[peer_id] = get_points(peer_id) - cost
		_broadcast(peer_id, -cost)
	return true


func host_lose_fraction(peer_id: int, fraction: float) -> int:
	if not is_authority():
		return 0
	var lost: int = PointsRules.penalty(get_points(peer_id), fraction)
	if lost > 0:
		points[peer_id] = get_points(peer_id) - lost
		_broadcast(peer_id, -lost)
	return lost


func host_set(peer_id: int, value: int) -> void:
	if not is_authority():
		return
	ensure_player(peer_id)
	var delta: int = value - get_points(peer_id)
	points[peer_id] = maxi(value, 0)
	_broadcast(peer_id, delta)


func host_add_stat(peer_id: int, key: StringName, amount: int = 1) -> void:
	if not is_authority():
		return
	ensure_player(peer_id)
	var s: Dictionary = stats[peer_id]
	s[key] = int(s.get(key, 0)) + amount
	if key != &"points_earned":
		Net.send_reliable(0, &"_stat", [peer_id, String(key), s[key]])


# Barricade plank repaired: 10 points while under the per-round cap.
func host_repair_reward(peer_id: int) -> int:
	var earned: int = int(_repair_round.get(peer_id, 0))
	var pts: int = PointsRules.repair_points(earned)
	_repair_round[peer_id] = earned + pts
	host_add_stat(peer_id, &"repairs")
	if pts > 0:
		host_earn(peer_id, pts * earn_multiplier)
	return pts


# HOST (reconnect): moves a retained player's points + stats from their old peer id to the new one
# and drops the old row everywhere (so the game-over table has one row per player).
func host_transfer(old_peer: int, new_peer: int, total: int, stat_values: Dictionary) -> void:
	if not is_authority():
		return
	ensure_player(new_peer)
	for k: Variant in stat_values:
		host_add_stat(new_peer, StringName(k), int(stat_values[k]) - stat(new_peer, StringName(k)))
	host_set(new_peer, total)
	if old_peer != new_peer and points.has(old_peer):
		points.erase(old_peer)
		stats.erase(old_peer)
		Net.send_reliable(0, &"_points_forget", [old_peer])


func stats_of(peer_id: int) -> Dictionary:
	return (stats.get(peer_id, {}) as Dictionary).duplicate()


func host_new_round() -> void:
	_repair_round.clear()


func summary() -> Array:
	var out: Array = []
	for id: int in points:
		var name_text: String = String(names.get(id, "Player %d" % id))
		var char_id: String = String(Session.character_of(id))
		if players != null and players.avatars.has(id):
			var pc: PlayerCharacter = players.avatars[id]
			name_text = pc.display_name
			char_id = String(pc.character_id)
		var row: Dictionary = {"peer": id, "name": name_text, "points": get_points(id), "character": char_id}
		for k: StringName in STAT_KEYS:
			row[String(k)] = stat(id, k)
		out.append(row)
	return out


# --- earning from damage ------------------------------------------------------------------------


func _on_target_damaged(t: HitTarget, _amount: float, zone: int, kind: int, source_peer: int) -> void:
	if not is_authority() or not (t is ZombieActor) or source_peer <= 0:
		return
	if players != null and not players.avatars.has(source_peer):
		return
	var killed: bool = not t.alive
	var pts: int = PointsRules.for_damage(kind, zone, killed)
	if not killed and pts > 0:
		# Multi-pellet shots pay hit points once per shot per zombie (GAME_DESIGN §6.1).
		var key: String = "%d:%d" % [source_peer, t.target_id]
		var frame: int = Engine.get_physics_frames()
		if int(_hit_keys.get(key, -1)) == frame:
			return
		_hit_keys[key] = frame
		if _hit_keys.size() > 512:
			_hit_keys.clear()
	if killed and kind != DamageInfo.Kind.DEBUG:
		host_add_stat(source_peer, &"kills")
		if zone == WeaponDefinition.Hitzone.HEAD and kind == DamageInfo.Kind.BULLET:
			host_add_stat(source_peer, &"headshots")
	if pts > 0:
		host_earn(source_peer, pts * earn_multiplier)
	zombie_points.emit(source_peer, pts, t, killed, kind)


# HOST: gameplay earnings that Double Points multiplies (Nuke / Carpenter bonuses).
func host_earn_bonus(peer_id: int, amount: int) -> void:
	host_earn(peer_id, amount * earn_multiplier)


# --- replication --------------------------------------------------------------------------------


func _broadcast(peer_id: int, delta: int) -> void:
	points_changed.emit(peer_id, get_points(peer_id), delta)
	Net.send_reliable(0, &"_points", [peer_id, get_points(peer_id), delta])


func _on_msg_points(sender: int, p: Array) -> void:
	if sender != 1 or Net.is_host():
		return
	var id: int = int(p[0])
	ensure_player(id)
	points[id] = int(p[1])
	points_changed.emit(id, int(p[1]), int(p[2]))


func _on_msg_stat(sender: int, p: Array) -> void:
	if sender != 1 or Net.is_host():
		return
	ensure_player(int(p[0]))
	(stats[int(p[0])] as Dictionary)[StringName(p[1])] = int(p[2])


func _on_msg_full(sender: int, p: Array) -> void:
	if sender != 1 or Net.is_host():
		return
	for e: Variant in p[0]:
		var row: Array = e
		var id: int = int(row[0])
		ensure_player(id)
		points[id] = int(row[1])
		var s: Dictionary = row[2]
		for k: Variant in s:
			(stats[id] as Dictionary)[StringName(k)] = int(s[k])
		points_changed.emit(id, int(row[1]), 0)


func _on_msg_forget(sender: int, p: Array) -> void:
	if sender == 1 and not Net.is_host():
		points.erase(int(p[0]))
		stats.erase(int(p[0]))


func _on_peer_joined(peer_id: int, _info: Dictionary) -> void:
	if not Net.is_host() or peer_id == Net.local_id():
		return
	var list: Array = []
	for id: int in points:
		var s: Dictionary = {}
		for k: StringName in stats[id] as Dictionary:
			s[String(k)] = stats[id][k]
		list.append([id, get_points(id), s])
	Net.send_reliable(peer_id, &"_points_full", [list])
