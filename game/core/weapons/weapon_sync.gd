# WeaponSync — weapon networking and host authority (Step 3 scope 7–8, ARCHITECTURE §5.4).
#   owner -> host : `_wshots`   (reliable, batched per physics frame)
#                   [[weapon_id, seq, time, ox,oy,oz, fx,fy,fz, spread, seed, [[tid, zone, dist, idx, props]...]]...]
#   host  -> all  : STREAM_FIRE (unreliable)  [peer, weapon index, seed, origin, forward, spread]
#                   accepted shots replayed cosmetically by observers (tracers, flash, impacts, audio)
#   owner -> host : `_wreload` [weapon_id, mag, reserve]   ammo-in reports (host mirrors ammo)
#   host  -> owner: `_wammo`   [weapon_id, mag, reserve]   ammo correction / refill
#   owner -> host : `_wrl` [] reload started ; host -> others: `_wrl_r` [peer]  (third-person anim)
#   owner -> host : `_wswitch` [weapon_id] ; host -> all: `_wswitch_r` [peer, weapon_id]
#   any   -> host : `_wgive`   [weapon_id] (debug) ; host -> all: `_wloadout` [peer, ids, current, lethal]
#   owner -> host : `_wthrow`  [seq, origin xyz, velocity xyz, fuse] ; host -> all: `_wthrow_r` [peer, ...]
#   host  -> all  : `_wexplode` [peer, seq, x, y, z]
#   host  -> owner: `_wcheat`  [infinite_ammo]
# The host validates every claim with HitValidator, recomputes damage from the definition and
# applies it through TargetRegistry. The host's own shots take the same path without the network.
# Without an active session (unit/integration scenes) this node acts as the authority.
# Authority: host decides; owners predict.
class_name WeaponSync
extends Node

signal shot_accepted(peer_id: int, def: WeaponDefinition)
signal shot_rejected(peer_id: int, reason: String)
signal hit_rejected(peer_id: int, reason: String)

const STREAM_FIRE: int = 18
const ORIGIN_SLACK: float = 2.5
const PRIMARY_SLOTS: int = 2
const LAST_STAND_PISTOL: StringName = &"m1911"

var validator: HitValidator = HitValidator.new()
var targets: TargetRegistry = null
var players: PlayerSync = null
var starting_weapons: Array[StringName] = [&"m1911"]
var loadouts: Dictionary = {}  # host: peer -> {ids: Array[StringName], current: StringName, lethal: int}
var grenades: Dictionary = {}  # key -> Grenade (local copies)
var shots_relayed: int = 0
var mirrored: Dictionary = {}  # every peer: peer -> [ids, current, lethal] from `_wloadout`

var _outbox: Array = []
var _standalone_controllers: Array[WeaponController] = []


static func instance(node: Node) -> WeaponSync:
	if Match.current != null and Match.current.weapons != null:
		return Match.current.weapons
	if node == null or not node.is_inside_tree():
		return null
	return node.get_tree().get_first_node_in_group(&"weapon_sync") as WeaponSync


static func is_authority() -> bool:
	return Net.is_host() or not Net.is_active()


func _ready() -> void:
	name = "Weapons"
	add_to_group(&"weapon_sync")
	process_physics_priority = 110
	Net.register_message(&"_wshots", _on_msg_shots)
	Net.register_message(&"_wreload", _on_msg_reload)
	Net.register_message(&"_wammo", _on_msg_ammo)
	Net.register_message(&"_wrl", _on_msg_reload_start)
	Net.register_message(&"_wrl_r", _on_msg_reload_start_relay)
	Net.register_message(&"_wswitch", _on_msg_switch)
	Net.register_message(&"_wswitch_r", _on_msg_switch_relay)
	Net.register_message(&"_wgive", _on_msg_give)
	Net.register_message(&"_wloadout", _on_msg_loadout)
	Net.register_message(&"_wthrow", _on_msg_throw)
	Net.register_message(&"_wthrow_r", _on_msg_throw_relay)
	Net.register_message(&"_wexplode", _on_msg_explode)
	Net.register_message(&"_wcheat", _on_msg_cheat)
	Net.register_stream(STREAM_FIRE, _on_fire_stream)
	Net.peer_joined.connect(_on_peer_joined)
	Net.peer_left.connect(_on_peer_left)
	if players != null:
		players.avatar_spawned.connect(_on_avatar_spawned)
		for id: int in players.avatars:
			_on_avatar_spawned(id, players.avatars[id])


func _exit_tree() -> void:
	for msg: StringName in [
		&"_wshots",
		&"_wreload",
		&"_wammo",
		&"_wrl",
		&"_wrl_r",
		&"_wswitch",
		&"_wswitch_r",
		&"_wgive",
		&"_wloadout",
		&"_wthrow",
		&"_wthrow_r",
		&"_wexplode",
		&"_wcheat"
	]:
		Net.unregister_message(msg)
	Net.unregister_stream(STREAM_FIRE)


# --- controller-facing API (static: no-op without a WeaponSync) -------------------------------


static func submit_shot(
	c: WeaponController, def: WeaponDefinition, seq: int, ctx: WeaponBehavior.ShotContext, r: Ballistics.ShotResult
) -> void:
	var ws: WeaponSync = instance(c)
	if ws == null:
		return
	var hits: Array = []
	for rec: Ballistics.HitRecord in r.hits:
		if rec.target != null and rec.target.target_id > 0:
			hits.append(
				[rec.target.target_id, rec.zone, snappedf(rec.distance, 0.01), rec.target_index, rec.props_passed]
			)
	var o: Vector3 = ctx.origin
	var fw: Vector3 = ctx.forward
	var claim: Array = [
		String(def.id), seq, Net.host_time(), o.x, o.y, o.z, fw.x, fw.y, fw.z, ctx.spread_deg, ctx.seed, hits
	]
	if is_authority():
		ws._host_process_shot(c.player.peer_id, claim)
	else:
		ws._outbox.append(claim)


static func submit_reload(c: WeaponController, def: WeaponDefinition, mag: int, reserve: int) -> void:
	var ws: WeaponSync = instance(c)
	if ws == null:
		return
	if is_authority():
		ws.validator.check_reload(c.player.peer_id, def.id, mag, reserve)
	else:
		Net.send_reliable(1, &"_wreload", [String(def.id), mag, reserve])


# Cosmetic: tells the other peers a reload started (third-person reload layer, SurvivorModel).
static func submit_reload_start(c: WeaponController) -> void:
	var ws: WeaponSync = instance(c)
	if ws == null or not Net.is_active():
		return
	if Net.is_host():
		Net.send_reliable(0, &"_wrl_r", [c.player.peer_id])
	else:
		Net.send_reliable(1, &"_wrl", [])


static func submit_switch(c: WeaponController, def: WeaponDefinition) -> void:
	var ws: WeaponSync = instance(c)
	if ws == null:
		return
	if is_authority():
		ws._host_switch(c.player.peer_id, def.id)
	else:
		Net.send_reliable(1, &"_wswitch", [String(def.id)])


static func submit_throw(
	c: WeaponController, def: WeaponDefinition, seq: int, origin: Vector3, vel: Vector3, fuse: float
) -> void:
	var ws: WeaponSync = instance(c)
	if ws == null:
		return
	var peer: int = c.player.peer_id
	if is_authority():
		ws._host_throw(peer, def, seq, origin, vel, fuse)
	else:
		ws._spawn_grenade(def, peer, seq, origin, vel, fuse, false)
		Net.send_reliable(1, &"_wthrow", [seq, origin.x, origin.y, origin.z, vel.x, vel.y, vel.z, fuse])


# Any peer: ask the host for a weapon (debug `give`; purchases use the same host path in Step 6).
func request_give(weapon_id: StringName) -> void:
	if is_authority():
		host_give(Net.local_id() if Net.is_active() else 1, weapon_id)
	else:
		Net.send_reliable(1, &"_wgive", [String(weapon_id)])


# --- host -------------------------------------------------------------------------------------


func host_give(peer_id: int, weapon_id: StringName) -> bool:
	var def: WeaponDefinition = WeaponCatalog.get_def(weapon_id)
	if def == null or def.is_melee() or def.weapon_class == WeaponDefinition.WeaponClass.LETHAL:
		return false
	var lo: Dictionary = _loadout(peer_id)
	if bool(lo.get("last_stand", false)):
		return false
	var ids: Array = lo["ids"]
	if not ids.has(weapon_id):
		if ids.size() >= PRIMARY_SLOTS:
			var idx: int = maxi(ids.find(lo["current"]), 0)
			validator.take(peer_id, StringName(ids[idx]))
			ids[idx] = weapon_id
		else:
			ids.append(weapon_id)
	validator.give(peer_id, def)
	lo["current"] = weapon_id
	_broadcast_loadout(peer_id)
	return true


func host_refill(peer_id: int) -> void:
	var lo: Dictionary = _loadout(peer_id)
	for wid: Variant in lo["ids"]:
		var def: WeaponDefinition = WeaponCatalog.get_def(StringName(wid))
		validator.give(peer_id, def)
		_send_to(peer_id, &"_wammo", [String(def.id), def.mag_size, def.reserve_max])
	var frag: WeaponDefinition = WeaponCatalog.get_def(WeaponController.FRAG_ID)
	if frag != null:
		lo["lethal"] = frag.carry_max
		_broadcast_loadout(peer_id)


# Wall-buy ammo: refills one owned weapon (mag + reserve) on host and owner.
func host_refill_weapon(peer_id: int, weapon_id: StringName) -> void:
	var def: WeaponDefinition = WeaponCatalog.get_def(weapon_id)
	if def == null:
		return
	validator.give(peer_id, def)
	_send_to(peer_id, &"_wammo", [String(def.id), def.mag_size, def.reserve_max])


# Round start: +amount lethals up to the carry max (GAME_DESIGN §3.4).
func host_add_lethal(peer_id: int, amount: int) -> void:
	var frag: WeaponDefinition = WeaponCatalog.get_def(WeaponController.FRAG_ID)
	if frag == null or not loadouts.has(peer_id):
		return
	var lo: Dictionary = loadouts[peer_id]
	var next: int = mini(int(lo["lethal"]) + amount, frag.carry_max)
	if next != int(lo["lethal"]):
		lo["lethal"] = next
		_broadcast_loadout(peer_id)


# Downed (GAME_DESIGN §3.3): switch to the best owned pistol with 2 extra mags, else a
# temporary M1911. The other weapons stay in the loadout (kept on revive).
func host_enter_last_stand(peer_id: int) -> void:
	var lo: Dictionary = _loadout(peer_id)
	if bool(lo.get("last_stand", false)):
		return
	lo["last_stand"] = true
	lo["pre_down"] = lo["current"]
	var best: WeaponDefinition = null
	for wid: Variant in lo["ids"]:
		var d: WeaponDefinition = WeaponCatalog.get_def(StringName(wid))
		if d != null and d.weapon_class == WeaponDefinition.WeaponClass.PISTOL:
			if best == null or d.damage * d.rpm > best.damage * best.rpm:
				best = d
	if best == null:
		best = WeaponCatalog.get_def(LAST_STAND_PISTOL)
		if best == null:
			return
		(lo["ids"] as Array).append(best.id)
		lo["last_stand_added"] = best.id
		validator.give(peer_id, best)
	else:
		var a: Array = validator.ammo(peer_id, best.id)
		var reserve: int = mini(int(a[1]) + best.mag_size * 2, best.reserve_max + best.mag_size * 2)
		validator.give(peer_id, best, int(a[0]), reserve)
		_send_to(peer_id, &"_wammo", [String(best.id), int(a[0]), reserve])
	lo["current"] = best.id
	_broadcast_loadout(peer_id)


func host_exit_last_stand(peer_id: int) -> void:
	if not loadouts.has(peer_id):
		return
	var lo: Dictionary = loadouts[peer_id]
	if not bool(lo.get("last_stand", false)):
		return
	lo["last_stand"] = false
	var added: StringName = StringName(lo.get("last_stand_added", &""))
	if added != &"":
		(lo["ids"] as Array).erase(added)
		validator.take(peer_id, added)
		lo.erase("last_stand_added")
	var ids: Array = lo["ids"]
	var back: StringName = StringName(lo.get("pre_down", &""))
	lo["current"] = back if ids.has(back) else (StringName(ids[0]) if not ids.is_empty() else &"")
	_broadcast_loadout(peer_id)


# Bled out (GAME_DESIGN §3.3): weapons are lost; the player respawns with the starting loadout.
func host_reset_loadout(peer_id: int) -> void:
	if loadouts.has(peer_id):
		for wid: Variant in (loadouts[peer_id] as Dictionary)["ids"]:
			validator.take(peer_id, StringName(wid))
		loadouts.erase(peer_id)
	_loadout(peer_id)
	_broadcast_loadout(peer_id)
	for wid: StringName in starting_weapons:
		var def: WeaponDefinition = WeaponCatalog.get_def(wid)
		if def != null:
			_send_to(peer_id, &"_wammo", [String(def.id), def.mag_size, def.reserve_max])


# HOST (reconnect, MatchSession): the player's weapons + host-mirrored ammo as plain data. A player
# in last stand exports the loadout from before going down (a down is not kept across rejoin).
func host_export(peer_id: int) -> Dictionary:
	if not loadouts.has(peer_id):
		return {}
	var lo: Dictionary = loadouts[peer_id]
	var ids: Array = _id_strings(lo["ids"])
	var current: String = String(lo["current"])
	if bool(lo.get("last_stand", false)):
		ids.erase(String(lo.get("last_stand_added", "")))
		current = String(lo.get("pre_down", current))
	var ammo: Dictionary = {}
	for wid: String in ids:
		ammo[wid] = (validator.ammo(peer_id, StringName(wid)) as Array).duplicate()
	return {"ids": ids, "current": current, "lethal": int(lo["lethal"]), "ammo": ammo}


# HOST: restores an exported loadout onto (a new peer id for) the same player.
func host_import(peer_id: int, data: Dictionary) -> void:
	if data.is_empty():
		return
	if loadouts.has(peer_id):
		for wid: Variant in (loadouts[peer_id] as Dictionary)["ids"]:
			validator.take(peer_id, StringName(wid))
	var ids: Array = []
	for wid: Variant in data.get("ids", []):
		var def: WeaponDefinition = WeaponCatalog.get_def(StringName(String(wid)))
		if def == null or ids.size() >= PRIMARY_SLOTS:
			continue
		ids.append(def.id)
		var a: Array = (data.get("ammo", {}) as Dictionary).get(String(wid), [def.mag_size, def.reserve_max])
		validator.give(peer_id, def, int(a[0]), int(a[1]))
		_send_to(peer_id, &"_wammo", [String(def.id), int(a[0]), int(a[1])])
	var knife: WeaponDefinition = WeaponCatalog.get_def(WeaponController.KNIFE_ID)
	if knife != null:
		validator.give(peer_id, knife)
	var cur: StringName = StringName(String(data.get("current", "")))
	loadouts[peer_id] = {
		"ids": ids,
		"current": cur if ids.has(cur) else (ids[0] if not ids.is_empty() else &""),
		"lethal": int(data.get("lethal", 0))
	}
	_broadcast_loadout(peer_id)


# Sorted weapon ids + lethal count of a player as one string (MatchSession state hash).
func digest_of(peer_id: int) -> String:
	if not loadouts.has(peer_id):
		return "-"
	var lo: Dictionary = loadouts[peer_id]
	var ids: Array = _id_strings(lo["ids"])
	ids.sort()
	return "%s/%d" % [",".join(PackedStringArray(ids)), int(lo["lethal"])]


# Same format as digest_of, from the replicated loadout mirror (clients).
func mirror_digest_of(peer_id: int) -> String:
	if not mirrored.has(peer_id):
		return "-"
	var m: Array = mirrored[peer_id]
	var ids: Array = _id_strings(m[0])
	ids.sort()
	return "%s/%d" % [",".join(PackedStringArray(ids)), int(m[2])]


func is_last_stand(peer_id: int) -> bool:
	return loadouts.has(peer_id) and bool((loadouts[peer_id] as Dictionary).get("last_stand", false))


func host_set_infinite_ammo(peer_id: int, on: bool) -> void:
	validator.state_for(peer_id).infinite_ammo = on
	_send_to(peer_id, &"_wcheat", [on])


func _loadout(peer_id: int) -> Dictionary:
	if not loadouts.has(peer_id):
		var ids: Array = []
		for wid: StringName in starting_weapons:
			if WeaponCatalog.get_def(wid) != null and ids.size() < PRIMARY_SLOTS:
				ids.append(wid)
				validator.give(peer_id, WeaponCatalog.get_def(wid))
		var knife: WeaponDefinition = WeaponCatalog.get_def(WeaponController.KNIFE_ID)
		if knife != null:
			validator.give(peer_id, knife)
		var frag: WeaponDefinition = WeaponCatalog.get_def(WeaponController.FRAG_ID)
		loadouts[peer_id] = {
			"ids": ids,
			"current": ids[0] if not ids.is_empty() else &"",
			"lethal": frag.carry_start if frag != null else 0
		}
	return loadouts[peer_id]


func _broadcast_loadout(peer_id: int) -> void:
	var lo: Dictionary = _loadout(peer_id)
	var payload: Array = [peer_id, _id_strings(lo["ids"]), String(lo["current"]), int(lo["lethal"])]
	Net.send_reliable(0, &"_wloadout", payload)
	_apply_loadout(payload)


func _host_process_shot(peer_id: int, claim: Array) -> void:
	if claim.size() < 12:
		validator._reject(HitValidator.Result.BAD_DATA, "malformed shot claim")
		return
	var def: WeaponDefinition = WeaponCatalog.get_def(StringName(claim[0]))
	if def == null:
		validator._reject(HitValidator.Result.BAD_DATA, "unknown weapon %s" % claim[0])
		return
	var now: float = Net.host_time()
	# The host's own shots are trusted (it is the authority); every client claim is validated.
	var trusted: bool = not Net.is_active() or peer_id == Net.local_id() or _is_host_bot(peer_id)
	var res: HitValidator.Result = HitValidator.Result.OK
	if trusted:
		validator.accepted_shots += 1
	else:
		res = validator.check_shot(peer_id, def, int(claim[1]), float(claim[2]), now)
	if res != HitValidator.Result.OK:
		shot_rejected.emit(peer_id, validator.last_rejection)
		Log.warn(&"weapons", "Rejected shot from %d: %s" % [peer_id, validator.last_rejection])
		return
	shot_accepted.emit(peer_id, def)
	var origin: Vector3 = Vector3(float(claim[3]), float(claim[4]), float(claim[5]))
	var forward: Vector3 = Vector3(float(claim[6]), float(claim[7]), float(claim[8]))
	_relay_fire(peer_id, def, int(claim[10]), origin, forward, float(claim[9]))
	var eye: Vector3 = _shooter_eye(peer_id, origin)
	var space: PhysicsDirectSpaceState3D = get_viewport().get_world_3d().direct_space_state
	var killed: Array[HitTarget] = []
	for h: Variant in claim[11]:
		var hit: Array = h
		if hit.size() < 5:
			continue
		var t: HitTarget = targets.get_target(int(hit[0])) if targets != null else null
		if t != null and killed.has(t):
			continue  # later pellets / penetration of a target this shot already killed
		var zone: int = int(hit[1])
		var dist: float = float(hit[2])
		var r: HitValidator.Result = HitValidator.Result.OK
		if trusted:
			r = HitValidator.Result.OK if t != null and t.alive else HitValidator.Result.DEAD_TARGET
		else:
			r = validator.check_hit(def, eye, t, zone, dist, int(hit[3]), int(hit[4]), space)
		if r != HitValidator.Result.OK and trusted:
			continue
		if r != HitValidator.Result.OK:
			hit_rejected.emit(peer_id, validator.last_rejection)
			Log.warn(&"weapons", "Rejected hit from %d: %s" % [peer_id, validator.last_rejection])
			continue
		var amount: float = DamageModel.melee_damage(def)
		var kind: DamageInfo.Kind = DamageInfo.Kind.MELEE
		if not def.is_melee():
			kind = DamageInfo.Kind.BULLET
			amount = (
				DamageModel.bullet_damage(def, dist, zone, int(hit[3]))
				* pow(Ballistics.PROP_PENETRATION_FACTOR, int(hit[4]))
			)
		var info: DamageInfo = DamageInfo.make(amount, zone, kind, def.id, peer_id)
		info.distance = dist
		info.target_index = int(hit[3])
		targets.host_damage(t, info)
		if not t.alive:
			killed.append(t)


func _is_host_bot(peer_id: int) -> bool:
	return players != null and players.avatars.has(peer_id) and (players.avatars[peer_id] as PlayerCharacter).is_bot


func _shooter_eye(peer_id: int, claimed: Vector3) -> Vector3:
	if players == null or not players.avatars.has(peer_id):
		return claimed
	var p: PlayerCharacter = players.avatars[peer_id]
	var known: Vector3 = p.global_position
	if peer_id != Net.local_id() and players.validators.has(peer_id):
		known = (players.validators[peer_id] as MovementValidator).position
	var stance_crouched: bool = p.remote_stance() != MotorComponent.Stance.STAND and peer_id != Net.local_id()
	var eye: Vector3 = (
		known + Vector3.UP * (p.tuning.eye_height_crouch if stance_crouched else p.tuning.eye_height_stand)
	)
	if peer_id == Net.local_id():
		eye = known + Vector3.UP * p.camera_rig.eye_height
	return claimed if claimed.distance_to(eye) <= ORIGIN_SLACK else eye


func _relay_fire(
	peer_id: int, def: WeaponDefinition, seed_value: int, origin: Vector3, fw: Vector3, spread: float
) -> void:
	shots_relayed += 1
	if players != null and peer_id != Net.local_id() and players.avatars.has(peer_id):
		(players.avatars[peer_id] as PlayerCharacter).weapons.replay_remote_shot(def, seed_value, origin, fw, spread)
	var buf: StreamPeerBuffer = StreamPeerBuffer.new()
	buf.put_u32(peer_id)
	buf.put_u16(maxi(WeaponCatalog.index_of(def.id), 0))
	buf.put_u32(seed_value)
	for v: float in [origin.x, origin.y, origin.z, fw.x, fw.y, fw.z, spread]:
		buf.put_float(v)
	Net.send_unreliable(0, STREAM_FIRE, buf.data_array)


func _host_switch(peer_id: int, weapon_id: StringName) -> void:
	var lo: Dictionary = _loadout(peer_id)
	if not (lo["ids"] as Array).has(weapon_id):
		return
	lo["current"] = weapon_id
	Net.send_reliable(0, &"_wswitch_r", [peer_id, String(weapon_id)])


func _host_throw(peer_id: int, def: WeaponDefinition, seq: int, origin: Vector3, vel: Vector3, fuse: float) -> void:
	var lo: Dictionary = _loadout(peer_id)
	if int(lo["lethal"]) <= 0:
		validator._reject(HitValidator.Result.NO_AMMO, "peer %d has no lethals" % peer_id)
		return
	lo["lethal"] = int(lo["lethal"]) - 1
	var fuse_clamped: float = clampf(fuse, 0.0, def.fuse_time)
	var g: Grenade = _spawn_grenade(def, peer_id, seq, origin, vel, fuse_clamped, true)
	g.exploded.connect(_on_grenade_exploded)
	Net.send_reliable(0, &"_wthrow_r", [peer_id, seq, origin.x, origin.y, origin.z, vel.x, vel.y, vel.z, fuse_clamped])


func _on_grenade_exploded(g: Grenade, pos: Vector3) -> void:
	grenades.erase(g.key)
	var def: WeaponDefinition = g.def
	var space: PhysicsDirectSpaceState3D = get_viewport().get_world_3d().direct_space_state
	if targets != null:
		for id: int in targets.targets.keys():
			var t: HitTarget = targets.get_target(id)
			if t == null or not t.alive:
				continue
			var tp: Vector3 = t.zone_position(WeaponDefinition.Hitzone.TORSO)
			var d: float = pos.distance_to(tp)
			if d > def.splash_radius or not HitValidator.has_line_of_sight(space, pos + Vector3.UP * 0.1, tp):
				continue
			var amount: float = DamageModel.splash_damage(
				def.splash_damage_centre, def.splash_damage_edge, def.splash_radius, d
			)
			var info: DamageInfo = DamageInfo.make(
				amount, WeaponDefinition.Hitzone.TORSO, DamageInfo.Kind.EXPLOSIVE, def.id, g.peer_id
			)
			info.distance = d
			info.position = pos
			targets.host_damage(t, info)
	if players != null and players.avatars.has(g.peer_id):
		var thrower: PlayerCharacter = players.avatars[g.peer_id]
		var pd: float = pos.distance_to(thrower.global_position + Vector3.UP * 0.9)
		if pd <= def.splash_radius:
			var frac: float = DamageModel.splash_damage(1.0, 0.0, def.splash_radius, pd)
			players.damage_player(g.peer_id, def.self_damage_max * frac, pos, HealthComponent.DamageType.EXPLOSIVE)
	Net.send_reliable(0, &"_wexplode", [g.peer_id, g.key.get_slice(":", 1).to_int(), pos.x, pos.y, pos.z])
	WeaponFx.of(self).explosion(pos, def.splash_radius)


func _spawn_grenade(
	def: WeaponDefinition, peer_id: int, seq: int, origin: Vector3, vel: Vector3, fuse: float, auth: bool
) -> Grenade:
	var key: String = "%d:%d" % [peer_id, seq]
	if grenades.has(key) and is_instance_valid(grenades[key]):
		var existing: Grenade = grenades[key]
		existing.authoritative = auth
		return existing
	var g: Grenade = Grenade.create(def, key, peer_id, fuse, auth)
	var parent: Node = Match.current if Match.current != null else get_parent()
	parent.add_child(g)
	g.global_position = origin
	g.linear_velocity = vel
	grenades[key] = g
	g.tree_exiting.connect(func() -> void: grenades.erase(key))
	return g


# --- tick -------------------------------------------------------------------------------------


func _physics_process(_delta: float) -> void:
	if _outbox.is_empty():
		return
	Net.send_reliable(1, &"_wshots", _outbox.duplicate())
	_outbox.clear()


# --- messages ---------------------------------------------------------------------------------


func _on_msg_shots(sender: int, p: Array) -> void:
	if not Net.is_host():
		return
	for claim: Variant in p:
		_host_process_shot(sender, claim as Array)


func _on_msg_reload(sender: int, p: Array) -> void:
	if not Net.is_host():
		return
	var wid: StringName = StringName(p[0])
	if not validator.check_reload(sender, wid, int(p[1]), int(p[2])):
		var a: Array = validator.ammo(sender, wid)
		Net.send_reliable(sender, &"_wammo", [String(wid), int(a[0]), int(a[1])])


func _on_msg_reload_start(sender: int, _p: Array) -> void:
	if not Net.is_host():
		return
	for id: int in Net.peer_ids():
		if id != sender and id != Net.local_id():
			Net.send_reliable(id, &"_wrl_r", [sender])
	_on_msg_reload_start_relay(1, [sender])


func _on_msg_reload_start_relay(sender: int, p: Array) -> void:
	if sender != 1 or players == null:
		return
	var a: PlayerCharacter = players.avatars.get(int(p[0]), null)
	if a != null and not a.is_local:
		a.weapons.remote_reloads += 1


func _on_msg_ammo(sender: int, p: Array) -> void:
	if sender != 1:
		return
	var me: PlayerCharacter = players.local_avatar() if players != null else null
	if me != null:
		me.weapons.set_ammo(StringName(p[0]), int(p[1]), int(p[2]))


func _on_msg_switch(sender: int, p: Array) -> void:
	if Net.is_host():
		_host_switch(sender, StringName(p[0]))


func _on_msg_switch_relay(sender: int, p: Array) -> void:
	if sender != 1 or players == null:
		return
	var peer: int = int(p[0])
	if peer != Net.local_id() and players.avatars.has(peer):
		(players.avatars[peer] as PlayerCharacter).weapons.set_remote_weapon(WeaponCatalog.get_def(StringName(p[1])))


func _on_msg_give(sender: int, p: Array) -> void:
	if Net.is_host():
		host_give(sender, StringName(p[0]))


func _on_msg_loadout(sender: int, p: Array) -> void:
	if sender == 1 and not Net.is_host():
		_apply_loadout(p)


func _apply_loadout(p: Array) -> void:
	mirrored[int(p[0])] = [(p[1] as Array).duplicate(), String(p[2]), int(p[3])]
	if players == null:
		return
	var peer: int = int(p[0])
	if not players.avatars.has(peer):
		return
	var avatar: PlayerCharacter = players.avatars[peer]
	if avatar.is_local:
		avatar.weapons.apply_loadout(p[1], StringName(p[2]), int(p[3]))
	else:
		avatar.weapons.set_remote_weapon(WeaponCatalog.get_def(StringName(p[2])))


func _on_msg_throw(sender: int, p: Array) -> void:
	if not Net.is_host():
		return
	var def: WeaponDefinition = WeaponCatalog.get_def(WeaponController.FRAG_ID)
	var origin: Vector3 = Vector3(float(p[1]), float(p[2]), float(p[3]))
	if players != null and players.avatars.has(sender):
		var known: Vector3 = _shooter_eye(sender, origin)
		if known.distance_to(origin) > ORIGIN_SLACK:
			origin = known
	_host_throw(sender, def, int(p[0]), origin, Vector3(float(p[4]), float(p[5]), float(p[6])), float(p[7]))


func _on_msg_throw_relay(sender: int, p: Array) -> void:
	if sender != 1 or Net.is_host() or int(p[0]) == Net.local_id():
		return
	var def: WeaponDefinition = WeaponCatalog.get_def(WeaponController.FRAG_ID)
	_spawn_grenade(
		def,
		int(p[0]),
		int(p[1]),
		Vector3(float(p[2]), float(p[3]), float(p[4])),
		Vector3(float(p[5]), float(p[6]), float(p[7])),
		float(p[8]),
		false
	)


func _on_msg_explode(sender: int, p: Array) -> void:
	if sender != 1 or Net.is_host():
		return
	var key: String = "%d:%d" % [int(p[0]), int(p[1])]
	if grenades.has(key) and is_instance_valid(grenades[key]):
		(grenades[key] as Grenade).queue_free()
	grenades.erase(key)
	var def: WeaponDefinition = WeaponCatalog.get_def(WeaponController.FRAG_ID)
	WeaponFx.of(self).explosion(
		Vector3(float(p[2]), float(p[3]), float(p[4])), def.splash_radius if def != null else 4.0
	)


func _on_msg_cheat(sender: int, p: Array) -> void:
	if sender != 1:
		return
	var me: PlayerCharacter = players.local_avatar() if players != null else null
	if me != null:
		me.weapons.set_infinite_ammo(bool(p[0]))


func _on_fire_stream(sender: int, bytes: PackedByteArray) -> void:
	if sender != 1 or Net.is_host() or players == null:
		return
	var buf: StreamPeerBuffer = StreamPeerBuffer.new()
	buf.data_array = bytes
	var peer: int = buf.get_u32()
	var def: WeaponDefinition = WeaponCatalog.def_at(buf.get_u16())
	var seed_value: int = buf.get_u32()
	var v: PackedFloat32Array = PackedFloat32Array()
	for i: int in 7:
		v.append(buf.get_float())
	if peer == Net.local_id() or not players.avatars.has(peer):
		return
	(players.avatars[peer] as PlayerCharacter).weapons.replay_remote_shot(
		def, seed_value, Vector3(v[0], v[1], v[2]), Vector3(v[3], v[4], v[5]), v[6]
	)


func _on_avatar_spawned(peer_id: int, _avatar: PlayerCharacter) -> void:
	if is_authority():
		_loadout(peer_id)
		_broadcast_loadout(peer_id)


func _on_peer_joined(peer_id: int, _info: Dictionary) -> void:
	if not Net.is_host() or peer_id == Net.local_id():
		return
	for id: int in loadouts:
		if id != peer_id:
			var lo: Dictionary = loadouts[id]
			Net.send_reliable(
				peer_id, &"_wloadout", [id, _id_strings(lo["ids"]), String(lo["current"]), int(lo["lethal"])]
			)


func _on_peer_left(peer_id: int) -> void:
	loadouts.erase(peer_id)
	mirrored.erase(peer_id)
	validator.remove_peer(peer_id)


func _send_to(peer_id: int, msg: StringName, payload: Array) -> void:
	if _is_host_bot(peer_id):
		return  # host bots shoot without ammo bookkeeping
	if Net.is_active():
		Net.send_reliable(peer_id, msg, payload)  # to self dispatches locally
	else:
		_dispatch_local(msg, payload)


func _dispatch_local(msg: StringName, payload: Array) -> void:
	match msg:
		&"_wammo":
			_on_msg_ammo(1, payload)
		&"_wcheat":
			_on_msg_cheat(1, payload)


static func _id_strings(ids: Array) -> Array:
	var out: Array = []
	for i: Variant in ids:
		out.append(String(i))
	return out
