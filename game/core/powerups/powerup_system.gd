# PowerUpSystem — power-up drops, pickups and global effects (GAME_DESIGN §11; DEVELOPMENT_PLAN
# Step 10 scope 6-7). HOST: the PowerUpDropper turns zombie points into drops at kill spots that
# are on the navmesh and reachable by a living player; a living player touching a drop picks it up
# for everyone; drops vanish after `lifetime` (blinking for the last `blink_time`). Effects:
#   max_ammo       reserves + lethals / equipment for every player (WeaponSync.host_max_ammo)
#   insta_kill     MatchSession flag "pu.insta_kill" = end host time; zombies die in one hit
#                  (bosses take ×10) through TargetRegistry.damage_modifier
#   double_points  flag "pu.double_points"; PointsLedger.earn_multiplier = 2
#   nuke           every alive zombie killed over `nuke_stagger` s (Kind.NUKE: they count, pay no
#                  points, never drop), +400 per player, white flash
#   carpenter      every barricade rebuilt (WorldSync), +200 per player
#   fire_sale      RelicBoxSystem.activate_all_locations(30)
#   free_upgrade   (stub, bosses / Easter egg only) flag "pu.free_upgrade" = true; Step 11's Forge
#                  consumes it
# Timers are host-time flags, so every peer's countdown derives from the synced clock (AC-10.4)
# and they ride the late-join snapshot + state hash. Picking a timed one again resets its timer.
#   host -> all  : `_pu_spawn` [id, type, x, y, z, spawned_at]   `_pu_pick` [id, type, peer]
#                  `_pu_gone` [id]   host -> joiner: `_pu_full` [[id, type, x, y, z, spawned_at]...]
# Authority: HOST decides; every peer presents (drop visuals, announcer, sting, HUD timers, flash).
class_name PowerUpSystem
extends Node

signal spawned(id: int, type: StringName, pos: Vector3)
signal picked(id: int, type: StringName, peer_id: int)
signal expired(id: int)

const RULES_PATH: String = "res://content/powerups/powerup_rules.tres"
const TYPES: Array[StringName] = [
	&"max_ammo", &"insta_kill", &"double_points", &"nuke", &"carpenter", &"fire_sale", &"free_upgrade"
]
const TIMED: Array[StringName] = [&"insta_kill", &"double_points", &"fire_sale"]
const NAMES: Dictionary = {
	&"max_ammo": "MAX AMMO",
	&"insta_kill": "INSTA-KILL",
	&"double_points": "DOUBLE POINTS",
	&"nuke": "NUKE",
	&"carpenter": "CARPENTER",
	&"fire_sale": "FIRE SALE",
	&"free_upgrade": "FREE UPGRADE",
}
const FLAG_FREE_UPGRADE: String = "pu.free_upgrade"
const FLASH_TIME: float = 1.2

var match_node: Match = null
var rules: PowerUpRules = null
var dropper: PowerUpDropper = null
var drops: Dictionary = {}  # every peer: id -> PowerUpDrop
var spawned_total: int = 0
var picked_total: int = 0
var expired_total: int = 0
var nuke_kills: int = 0
var last_announce: StringName = &""  # local presentation (HUD)
var announce_at: float = -100.0  # local seconds
var flash_at: float = -100.0  # local seconds (Nuke)
var log_spawns: Array = []  # host: [round, type] (tests)

var _next_id: int = 1
var _nuke_queue: Array = []  # host: [[ZombieActor, host time]]


static func is_authority() -> bool:
	return Net.is_host() or not Net.is_active()


static func flag_key(type: StringName) -> String:
	return "pu.%s" % type


func _ready() -> void:
	name = "PowerUps"
	rules = load(RULES_PATH) as PowerUpRules
	dropper = PowerUpDropper.new(rules)
	PowerUpAudio.ensure()
	for m: StringName in [&"_pu_spawn", &"_pu_pick", &"_pu_gone", &"_pu_full"]:
		Net.register_message(m, Callable(self, "_on_msg" + String(m)))
	Net.peer_joined.connect(_on_peer_joined)
	if match_node == null:
		return
	if match_node.points != null:
		match_node.points.zombie_points.connect(_host_on_zombie_points)
	if match_node.rounds != null:
		match_node.rounds.round_started.connect(func(r: int) -> void: dropper.new_round(r))
	if match_node.targets != null:
		match_node.targets.damage_modifier = _insta_kill_modifier


func _exit_tree() -> void:
	for m: StringName in [&"_pu_spawn", &"_pu_pick", &"_pu_gone", &"_pu_full"]:
		Net.unregister_message(m)


func session() -> MatchSession:
	return match_node.session if match_node != null else null


# --- replicated state (every peer) --------------------------------------------------------------


# Seconds left on a timed power-up (0 = inactive), from the host-time flags.
func time_left(type: StringName) -> float:
	var s: MatchSession = session()
	if s == null:
		return 0.0
	var until: float = -1.0
	if type == &"fire_sale":
		until = float(s.flag(RelicBoxSystem.FLAG_FIRE_SALE, -1.0))
	else:
		until = float(s.flag(flag_key(type), -1.0))
	return maxf(until - Net.host_time(), 0.0)


func is_active(type: StringName) -> bool:
	return time_left(type) > 0.0


func free_upgrade_pending() -> bool:
	var s: MatchSession = session()
	return s != null and bool(s.flag(FLAG_FREE_UPGRADE, false))


# --- host ---------------------------------------------------------------------------------------


func _host_on_zombie_points(_peer: int, pts: int, t: HitTarget, killed: bool, kind: int) -> void:
	if not is_authority():
		return
	dropper.add_points(pts, kind)
	if not killed or not dropper.wants_drop(kind):
		return
	var pos: Vector3 = drop_position(t.global_position)
	if pos == Vector3.INF:
		return  # not on the navmesh / unreachable: the counter stays, the next kill tries again
	var type: StringName = dropper.next_type(context())
	dropper.commit_drop()
	host_spawn(type, pos)


# Bag conditions: box moved at least once, planks missing map-wide, current round.
func context() -> Dictionary:
	var missing: int = 0
	if match_node != null and match_node.world != null:
		for b: Barricade in match_node.world.barricades:
			missing += b.max_planks - b.planks
	var r: int = match_node.rounds.current_round if match_node != null and match_node.rounds != null else 0
	var moved: bool = match_node != null and match_node.box != null and match_node.box.moves_total > 0
	return {"box_moved": moved, "planks_missing": missing, "round": r}


# A kill spot snapped onto the navmesh and path-reachable from a living player (Vector3.INF = no).
func drop_position(at: Vector3) -> Vector3:
	var crowd: CrowdDirector = match_node.zombies.crowd if match_node != null and match_node.zombies != null else null
	if crowd == null or not crowd.is_ready():
		return at
	var p: Vector3 = crowd.snap(at, at)
	if Vector2(p.x - at.x, p.z - at.z).length() > 1.5 or absf(p.y - at.y) > 1.6:
		return Vector3.INF
	var nav: RID = crowd.navigation_map()
	for pc: PlayerCharacter in match_node.players.avatars.values():
		if pc.health.is_downed or pc.spectating:
			continue
		var from: Vector3 = NavigationServer3D.map_get_closest_point(nav, pc.global_position)
		var path: PackedVector3Array = NavigationServer3D.map_get_path(nav, from, p, true)
		if not path.is_empty() and path[path.size() - 1].distance_to(p) < 1.0:
			return p
	return Vector3.INF


func host_spawn(type: StringName, pos: Vector3) -> int:
	if not is_authority() or not TYPES.has(type) or not pos.is_finite():
		return -1
	var id: int = _next_id
	_next_id += 1
	var now: float = Net.host_time()
	var r: int = match_node.rounds.current_round if match_node != null and match_node.rounds != null else 0
	log_spawns.append([r, String(type)])
	Net.send_reliable(0, &"_pu_spawn", [id, String(type), pos.x, pos.y, pos.z, now])
	_create(id, type, pos, now)
	return id


func host_pickup(id: int, peer_id: int) -> void:
	if not is_authority() or not drops.has(id):
		return
	var d: PowerUpDrop = drops[id]
	var type: StringName = d.type
	var pos: Vector3 = d.global_position
	_remove(id)
	picked_total += 1
	Net.send_reliable(0, &"_pu_pick", [id, String(type), peer_id])
	host_apply(type, pos)
	_present_pick(type, peer_id, pos)
	picked.emit(id, type, peer_id)


# The effect itself (pickups, debug, tests).
func host_apply(type: StringName, pos: Vector3 = Vector3.ZERO) -> void:
	if not is_authority() or match_node == null:
		return
	var now: float = Net.host_time()
	match type:
		&"max_ammo":
			for peer: int in match_node.players.avatars:
				match_node.weapons.host_max_ammo(peer)
		&"insta_kill", &"double_points":
			session().host_set_flag(flag_key(type), now + rules.timed_duration)
		&"fire_sale":
			if match_node.box != null:
				match_node.box.activate_all_locations(rules.timed_duration)
		&"nuke":
			var alive: Array[ZombieActor] = []
			for a: ZombieActor in match_node.zombies.actors.values():
				if a.alive:
					alive.append(a)
			alive.sort_custom(
				func(a: ZombieActor, b: ZombieActor) -> bool:
					return a.global_position.distance_squared_to(pos) < b.global_position.distance_squared_to(pos)
			)
			for i: int in alive.size():
				var at: float = now + rules.nuke_stagger * float(i + 1) / float(alive.size())
				_nuke_queue.append([alive[i], at])
			for peer: int in match_node.players.avatars:
				match_node.points.host_earn_bonus(peer, rules.nuke_points)
		&"carpenter":
			if match_node.world != null:
				for b: Barricade in match_node.world.barricades:
					if b.planks < b.max_planks:
						WorldSync.host_set_barricade(b, b.max_planks)
			for peer: int in match_node.players.avatars:
				match_node.points.host_earn_bonus(peer, rules.carpenter_points)
		&"free_upgrade":
			session().host_set_flag(FLAG_FREE_UPGRADE, true)
	_update_multiplier()


# HOST (Step 11 Forge): the free upgrade was used.
# Personal Free Upgrade tokens (the Easter-egg reward, Step 14): "pu.token.<uid8>" = count. The next
# Forge use by that player is free (after a pending team-wide Free Upgrade power-up).
static func token_key(peer_id: int) -> String:
	var info: Dictionary = Net.peers.get(peer_id, {})
	return "pu.token.%s" % String(info.get("uid", str(peer_id))).substr(0, 8)


func free_tokens(peer_id: int) -> int:
	var s: MatchSession = session()
	return int(s.flag(token_key(peer_id), 0)) if s != null else 0


func host_give_token(peer_id: int) -> void:
	if is_authority() and session() != null:
		session().host_set_flag(token_key(peer_id), free_tokens(peer_id) + 1)


func host_consume_token(peer_id: int) -> bool:
	if not is_authority() or free_tokens(peer_id) <= 0:
		return false
	session().host_set_flag(token_key(peer_id), free_tokens(peer_id) - 1)
	return true


func host_consume_free_upgrade() -> bool:
	if not is_authority() or not free_upgrade_pending():
		return false
	session().host_set_flag(FLAG_FREE_UPGRADE, false)
	return true


func _insta_kill_modifier(t: HitTarget, info: DamageInfo) -> void:
	if not (t is ZombieActor) or not is_active(&"insta_kill") or info.kind == DamageInfo.Kind.DEBUG:
		return
	var a: ZombieActor = t as ZombieActor
	if a.archetype != null and a.archetype.is_boss:
		info.amount *= rules.boss_insta_multiplier
	else:
		info.amount = maxf(info.amount, a.health + 1.0)


func _update_multiplier() -> void:
	if match_node != null and match_node.points != null:
		match_node.points.earn_multiplier = 2 if is_active(&"double_points") else 1


func _physics_process(_delta: float) -> void:
	if not is_authority() or match_node == null:
		return
	_update_multiplier()
	var now: float = Net.host_time()
	while not _nuke_queue.is_empty() and float(_nuke_queue[0][1]) <= now:
		var e: Array = _nuke_queue.pop_front()
		if not is_instance_valid(e[0]):
			continue  # despawned / re-queued before its turn
		var a: ZombieActor = e[0] as ZombieActor
		if a.alive:
			var info: DamageInfo = DamageInfo.make(
				a.health + 1.0, WeaponDefinition.Hitzone.TORSO, DamageInfo.Kind.NUKE, &"nuke", 0
			)
			match_node.targets.host_damage(a, info)
			nuke_kills += 1
	for id: int in drops.keys():
		var d: PowerUpDrop = drops[id]
		if now - d.spawned_at >= rules.lifetime:
			_remove(id)
			expired_total += 1
			Net.send_reliable(0, &"_pu_gone", [id])
			expired.emit(id)
			continue
		for pc: PlayerCharacter in match_node.players.avatars.values():
			if pc.health.is_downed or pc.spectating:
				continue
			var off: Vector3 = pc.global_position - d.global_position
			if Vector2(off.x, off.z).length() <= rules.pickup_radius and absf(off.y + 0.3) <= 1.8:
				host_pickup(id, pc.peer_id)
				break


# --- presentation (every peer) ------------------------------------------------------------------


func _create(id: int, type: StringName, pos: Vector3, spawned_at: float) -> void:
	if drops.has(id):
		return
	var d: PowerUpDrop = PowerUpDrop.new()
	d.drop_id = id
	d.type = type
	d.spawned_at = spawned_at
	d.rules = rules
	add_child(d)
	d.global_position = pos
	drops[id] = d
	spawned_total += 1
	Audio.play_event_3d(&"pu_spawn", pos)
	spawned.emit(id, type, pos)


func _remove(id: int) -> void:
	var d: PowerUpDrop = drops.get(id, null)
	drops.erase(id)
	if d != null and is_instance_valid(d):
		d.queue_free()


func _present_pick(type: StringName, _peer: int, pos: Vector3) -> void:
	last_announce = type
	announce_at = Time.get_ticks_msec() / 1000.0
	Audio.play_event_3d(&"pu_pickup", pos)
	Audio.play_event(StringName("pu_vo_%s" % type))
	if type == &"nuke":
		flash_at = announce_at
		Audio.play_event(&"pu_nuke")
	elif type == &"carpenter":
		Audio.play_event(&"pu_carpenter")


# --- messages -----------------------------------------------------------------------------------


func _on_msg_pu_spawn(sender: int, p: Array) -> void:
	if sender == 1 and not Net.is_host():
		_create(int(p[0]), StringName(String(p[1])), Vector3(float(p[2]), float(p[3]), float(p[4])), float(p[5]))


func _on_msg_pu_pick(sender: int, p: Array) -> void:
	if sender != 1 or Net.is_host():
		return
	var id: int = int(p[0])
	var pos: Vector3 = (drops[id] as PowerUpDrop).global_position if drops.has(id) else Vector3.ZERO
	_remove(id)
	picked_total += 1
	_present_pick(StringName(String(p[1])), int(p[2]), pos)
	picked.emit(id, StringName(String(p[1])), int(p[2]))


func _on_msg_pu_gone(sender: int, p: Array) -> void:
	if sender == 1 and not Net.is_host():
		_remove(int(p[0]))
		expired_total += 1
		expired.emit(int(p[0]))


func _on_msg_pu_full(sender: int, p: Array) -> void:
	if sender != 1 or Net.is_host():
		return
	for e: Variant in p:
		_on_msg_pu_spawn(1, e as Array)


func _on_peer_joined(peer_id: int, _info: Dictionary) -> void:
	if not Net.is_host() or peer_id == Net.local_id() or drops.is_empty():
		return
	var full: Array = []
	for id: int in drops:
		var d: PowerUpDrop = drops[id]
		var pos: Vector3 = d.global_position
		full.append([id, String(d.type), pos.x, pos.y, pos.z, d.spawned_at])
	Net.send_reliable(peer_id, &"_pu_full", full)
