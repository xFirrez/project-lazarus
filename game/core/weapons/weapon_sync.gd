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
#   host  -> all  : `_wexplode` [peer, seq, x, y, z, weapon_id]
#   host  -> all  : `_wproj`   [peer, weapon_id, seq, ox,oy,oz, dx,dy,dz]  projectile launched (Step 9)
#   host  -> all  : `_wpexplode` [key, weapon_id, x, y, z]  projectile / tripmine detonated
#   owner -> host : `_wtac`    [seq, origin xyz, velocity xyz]  throw a Drummer Decoy
#   owner -> host : `_wmine`   [seq, x, y, z, yaw] ; host -> all: `_wmine_r` [peer, seq, x, y, z, yaw]
#   host  -> joiner: `_wmines_full` [[peer, seq, x, y, z, yaw]...]
#   host  -> all  : `_wsplash` [x, y, z, radius]  impact splash / cluster blast (Step 11 upgrades)
# Wonder weapons (Step 12): Ray Pistol bolts are `projectile` (kind plasma); the Lazarus Conduit's
# chain (behavior `chain`) and pulse (behavior `pulse`) are resolved here on the host from the shot
# claim (ChainLightning) and presented on every peer through WonderFx (`_wfx`).
# `_wloadout` also carries equipment: [peer, ids, current, lethal, melee, tactical, tac_n, placeable, place_n].
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
var projectiles: Dictionary = {}  # key -> Projectile (local copies)
var mines: Dictionary = {}  # key -> Tripmine (every peer)
var attraction: Callable = Callable()  # host: func(decoy: Node3D, def) -> registers a zombie attractor
var explosions: int = 0  # host: explosions applied (tests)
var status: StatusEffects = null  # host: slow / burn on hit (Forge upgrades)
var impact_splashes: int = 0  # host: upgraded-weapon impact splashes + cluster blasts (tests)
var splashes_shown: int = 0  # every peer: splashes presented (net test)
var last_chain: Array = []  # host: [[zombie, damage, stunned]...] of the latest Conduit arc (tests)
var last_pulse: Array[ZombieActor] = []  # host: zombies stunned by the latest pulse (tests)
var chains: int = 0
var pulses: int = 0

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
	WonderAudio.ensure()
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
	Net.register_message(&"_wproj", _on_msg_proj)
	Net.register_message(&"_wpexplode", _on_msg_pexplode)
	Net.register_message(&"_wtac", _on_msg_tac)
	Net.register_message(&"_wmine", _on_msg_mine)
	Net.register_message(&"_wmine_r", _on_msg_mine_relay)
	Net.register_message(&"_wmines_full", _on_msg_mines_full)
	Net.register_message(&"_wsplash", _on_msg_splash)
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
		&"_wcheat",
		&"_wproj",
		&"_wpexplode",
		&"_wtac",
		&"_wmine",
		&"_wmine_r",
		&"_wmines_full",
		&"_wsplash"
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
		if def.behavior == &"projectile":
			ws._spawn_projectile(def, c.player.peer_id, seq, ctx.origin, ws.projectile_dir(ctx), false)
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


# Owner: throw a tactical (Drummer Decoy) — same flow as frags, counted against `tac_n`.
static func submit_tactical(
	c: WeaponController, def: WeaponDefinition, seq: int, origin: Vector3, vel: Vector3
) -> void:
	var ws: WeaponSync = instance(c)
	if ws == null:
		return
	var peer: int = c.player.peer_id
	if is_authority():
		ws._host_throw(peer, def, seq, origin, vel, def.fuse_time)
	else:
		ws._spawn_grenade(def, peer, seq, origin, vel, def.fuse_time, false)
		Net.send_reliable(1, &"_wtac", [seq, origin.x, origin.y, origin.z, vel.x, vel.y, vel.z])


# Owner: place a tripmine at `pos` (on the floor in front of the player).
static func submit_mine(c: WeaponController, seq: int, pos: Vector3, yaw: float) -> void:
	var ws: WeaponSync = instance(c)
	if ws == null:
		return
	if is_authority():
		ws._host_place_mine(c.player.peer_id, seq, pos, yaw)
	else:
		Net.send_reliable(1, &"_wmine", [seq, pos.x, pos.y, pos.z, yaw])


# Deterministic flight direction of a projectile shot (spread from the shot seed).
func projectile_dir(ctx: WeaponBehavior.ShotContext) -> Vector3:
	return Ballistics.spread_direction(ctx.forward, ctx.spread_deg, Ballistics.make_rng(ctx.seed))


# Any peer: ask the host for a weapon (debug `give`; purchases use the same host path in Step 6).
func request_give(weapon_id: StringName) -> void:
	if is_authority():
		host_give(Net.local_id() if Net.is_active() else 1, weapon_id)
	else:
		Net.send_reliable(1, &"_wgive", [String(weapon_id)])


# --- host -------------------------------------------------------------------------------------


func host_give(peer_id: int, weapon_id: StringName) -> bool:
	var def: WeaponDefinition = WeaponCatalog.get_def(weapon_id)
	if def == null or def.weapon_class == WeaponDefinition.WeaponClass.LETHAL or weapon_id == WeaponController.KNIFE_ID:
		return false
	var lo: Dictionary = _loadout(peer_id)
	if bool(lo.get("last_stand", false)):
		return false
	if def.is_equipment():
		return _host_give_equipment(peer_id, lo, def)
	var ids: Array = lo["ids"]
	if not ids.has(weapon_id):
		if ids.size() >= slots_for(peer_id):
			var idx: int = maxi(ids.find(lo["current"]), 0)
			validator.take(peer_id, StringName(ids[idx]))
			ids[idx] = weapon_id
		else:
			ids.append(weapon_id)
	validator.give(peer_id, def)
	var alt: WeaponDefinition = WeaponCatalog.get_def(def.alt_fire_id)
	if alt != null:
		validator.give(peer_id, alt)  # the underbarrel's own magazine (Skullcrusher)
	var pulse: WeaponDefinition = WeaponCatalog.get_def(def.pulse_id)
	if pulse != null:
		validator.give(peer_id, pulse)  # the Conduit's pulse (draws from the Conduit's magazine)
	lo["current"] = weapon_id
	_broadcast_loadout(peer_id)
	return true


# HOST: removes a primary weapon from a player's loadout (Lazarus Forge: the weapon goes in).
func host_take_weapon(peer_id: int, weapon_id: StringName) -> bool:
	var lo: Dictionary = _loadout(peer_id)
	var ids: Array = lo["ids"]
	if not ids.has(weapon_id) or bool(lo.get("last_stand", false)):
		return false
	ids.erase(weapon_id)
	validator.take(peer_id, weapon_id)
	var def: WeaponDefinition = WeaponCatalog.get_def(weapon_id)
	if def != null and def.alt_fire_id != &"":
		validator.take(peer_id, def.alt_fire_id)
	if def != null and def.pulse_id != &"":
		validator.take(peer_id, def.pulse_id)
	if StringName(lo["current"]) == weapon_id:
		lo["current"] = StringName(ids[0]) if not ids.is_empty() else &""
	_broadcast_loadout(peer_id)
	return true


# Weapon ids whose ammo a refill covers: the primaries plus their alt-fire attachments.
func _ammo_ids(lo: Dictionary) -> Array[StringName]:
	var out: Array[StringName] = []
	for wid: Variant in lo["ids"]:
		var def: WeaponDefinition = WeaponCatalog.get_def(StringName(wid))
		if def == null:
			continue
		out.append(def.id)
		if def.alt_fire_id != &"" and WeaponCatalog.get_def(def.alt_fire_id) != null:
			out.append(def.alt_fire_id)
	return out


# Melee upgrade / tactical / placeable (GAME_DESIGN §3.4): equipment slots, not primaries.
func _host_give_equipment(peer_id: int, lo: Dictionary, def: WeaponDefinition) -> bool:
	match def.weapon_class:
		WeaponDefinition.WeaponClass.MELEE:
			lo["melee"] = def.id
			validator.give(peer_id, def)
		WeaponDefinition.WeaponClass.TACTICAL:
			lo["tactical"] = def.id
			lo["tac_n"] = def.carry_max
		WeaponDefinition.WeaponClass.PLACEABLE:
			lo["placeable"] = def.id
			lo["place_n"] = def.carry_start
		_:
			return false
	_broadcast_loadout(peer_id)
	return true


# Host: does the player hold this weapon or equipment (box eligibility, wall-buy ownership)?
func host_owns(peer_id: int, weapon_id: StringName) -> bool:
	var lo: Dictionary = _loadout(peer_id)
	if (lo["ids"] as Array).has(weapon_id):
		return true
	if bool(lo.get("carry", false)) and (lo.get("carry_ids", []) as Array).has(weapon_id):
		return true
	var up: WeaponDefinition = WeaponCatalog.upgrade_of(weapon_id)
	if up != null and (lo["ids"] as Array).has(up.id):
		return true  # holding the Forge version counts (box eligibility, GAME_DESIGN §10.1)
	if StringName(lo.get("melee", &"")) == weapon_id:
		return true
	if StringName(lo.get("placeable", &"")) == weapon_id:
		return true
	var def: WeaponDefinition = WeaponCatalog.get_def(weapon_id)
	return StringName(lo.get("tactical", &"")) == weapon_id and def != null and int(lo.get("tac_n", 0)) >= def.carry_max


# Primary weapon slots of a player: 2, +1 with Pack Mule Cream Soda (PlayerStats.WEAPON_SLOTS).
func slots_for(peer_id: int) -> int:
	var st: PlayerStats = stats_of(peer_id)
	return PRIMARY_SLOTS + (int(st.value(PlayerStats.WEAPON_SLOTS, 0.0)) if st != null else 0)


func stats_of(peer_id: int) -> PlayerStats:
	if players == null or not players.avatars.has(peer_id):
		return null
	return (players.avatars[peer_id] as PlayerCharacter).stats()


# Pack Mule lost (downed, GAME_DESIGN §8): weapons beyond the slot count — the third one — go.
# The weapon in last stand (the pistol) is kept if possible.
func host_trim_to_slots(peer_id: int) -> void:
	if not loadouts.has(peer_id):
		return
	var lo: Dictionary = loadouts[peer_id]
	var ids: Array = lo["ids"]
	var keep: int = slots_for(peer_id)
	var changed: bool = false
	while ids.size() > keep:
		var drop: StringName = StringName(ids[ids.size() - 1])
		ids.remove_at(ids.size() - 1)
		validator.take(peer_id, drop)
		changed = true
		if StringName(lo["current"]) == drop:
			lo["current"] = StringName(ids[0]) if not ids.is_empty() else &""
		if StringName(lo.get("pre_down", &"")) == drop:
			lo["pre_down"] = StringName(ids[0]) if not ids.is_empty() else &""
	if changed:
		_broadcast_loadout(peer_id)


# Max Ammo power-up (GAME_DESIGN §11): every weapon's reserve to max (magazines untouched) and
# lethals to the carry max, for downed players too. The owner keeps its magazine (mag -1).
func host_max_ammo(peer_id: int) -> void:
	if not loadouts.has(peer_id):
		_loadout(peer_id)
	var lo: Dictionary = loadouts[peer_id]
	for wid: StringName in _ammo_ids(lo):
		var def: WeaponDefinition = WeaponCatalog.get_def(wid)
		var a: Array = validator.ammo(peer_id, def.id)
		validator.give(peer_id, def, int(a[0]), def.reserve_max)
		_send_to(peer_id, &"_wammo", [String(def.id), -1, def.reserve_max])
	var frag: WeaponDefinition = WeaponCatalog.get_def(WeaponController.FRAG_ID)
	if frag != null:
		lo["lethal"] = frag.carry_max
	var tac: WeaponDefinition = WeaponCatalog.get_def(StringName(lo.get("tactical", &"")))
	if tac != null:
		lo["tac_n"] = tac.carry_max
	var mine: WeaponDefinition = WeaponCatalog.get_def(StringName(lo.get("placeable", &"")))
	if mine != null:
		lo["place_n"] = mine.carry_max
	_broadcast_loadout(peer_id)


func host_refill(peer_id: int) -> void:
	var lo: Dictionary = _loadout(peer_id)
	for wid: StringName in _ammo_ids(lo):
		var def: WeaponDefinition = WeaponCatalog.get_def(wid)
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
	var alt: WeaponDefinition = WeaponCatalog.get_def(def.alt_fire_id)
	if alt != null:
		validator.give(peer_id, alt)
		_send_to(peer_id, &"_wammo", [String(alt.id), alt.mag_size, alt.reserve_max])


# Round start: +amount lethals up to the carry max (GAME_DESIGN §3.4).
func host_add_lethal(peer_id: int, amount: int) -> void:
	var frag: WeaponDefinition = WeaponCatalog.get_def(WeaponController.FRAG_ID)
	if frag == null or not loadouts.has(peer_id):
		return
	var lo: Dictionary = loadouts[peer_id]
	var next: int = mini(int(lo["lethal"]) + amount, frag.carry_max)
	var changed: bool = next != int(lo["lethal"])
	lo["lethal"] = next
	# Tripmines refill to 2 per round (GAME_DESIGN §4.3).
	var mine_def: WeaponDefinition = WeaponCatalog.get_def(StringName(lo.get("placeable", &"")))
	if mine_def != null and int(lo.get("place_n", 0)) < mine_def.carry_max:
		lo["place_n"] = mine_def.carry_max
		changed = true
	if changed:
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


# Carrying a quest item (CarryItem, Step 14 scope 5): only a pistol in hand (CarryLoadout).
func host_set_carry(peer_id: int, on: bool) -> void:
	if CarryLoadout.apply(self, _loadout(peer_id), peer_id, on):
		_broadcast_loadout(peer_id)


func is_carrying(peer_id: int) -> bool:
	return loadouts.has(peer_id) and bool((loadouts[peer_id] as Dictionary).get("carry", false))


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
	if bool(lo.get("carry", false)):
		ids = _id_strings(lo.get("carry_ids", lo["ids"]))
		current = String(lo.get("pre_carry", current))
	if bool(lo.get("last_stand", false)):
		ids.erase(String(lo.get("last_stand_added", "")))
		current = String(lo.get("pre_down", current))
	var ammo: Dictionary = {}
	for wid: String in ids:
		ammo[wid] = (validator.ammo(peer_id, StringName(wid)) as Array).duplicate()
	return {
		"ids": ids,
		"current": current,
		"lethal": int(lo["lethal"]),
		"ammo": ammo,
		"melee": String(lo.get("melee", WeaponController.KNIFE_ID)),
		"tactical": String(lo.get("tactical", "")),
		"tac_n": int(lo.get("tac_n", 0)),
		"placeable": String(lo.get("placeable", "")),
		"place_n": int(lo.get("place_n", 0))
	}


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
		if def == null or ids.size() >= slots_for(peer_id):
			continue
		ids.append(def.id)
		var a: Array = (data.get("ammo", {}) as Dictionary).get(String(wid), [def.mag_size, def.reserve_max])
		validator.give(peer_id, def, int(a[0]), int(a[1]))
		_send_to(peer_id, &"_wammo", [String(def.id), int(a[0]), int(a[1])])
	var knife: WeaponDefinition = WeaponCatalog.get_def(WeaponController.KNIFE_ID)
	if knife != null:
		validator.give(peer_id, knife)
	var cur: StringName = StringName(String(data.get("current", "")))
	var melee: StringName = StringName(String(data.get("melee", String(WeaponController.KNIFE_ID))))
	if WeaponCatalog.get_def(melee) != null:
		validator.give(peer_id, WeaponCatalog.get_def(melee))
	loadouts[peer_id] = {
		"ids": ids,
		"current": cur if ids.has(cur) else (ids[0] if not ids.is_empty() else &""),
		"lethal": int(data.get("lethal", 0)),
		"melee": melee,
		"tactical": StringName(String(data.get("tactical", ""))),
		"tac_n": int(data.get("tac_n", 0)),
		"placeable": StringName(String(data.get("placeable", ""))),
		"place_n": int(data.get("place_n", 0))
	}
	_broadcast_loadout(peer_id)


# Sorted weapon ids + lethal count of a player as one string (MatchSession state hash).
func digest_of(peer_id: int) -> String:
	if not loadouts.has(peer_id):
		return "-"
	var lo: Dictionary = loadouts[peer_id]
	var ids: Array = _id_strings(lo["ids"])
	ids.sort()
	return "%s/%d/%s" % [",".join(PackedStringArray(ids)), int(lo["lethal"]), String(lo.get("melee", "knife"))]


# Same format as digest_of, from the replicated loadout mirror (clients).
func mirror_digest_of(peer_id: int) -> String:
	if not mirrored.has(peer_id):
		return "-"
	var m: Array = mirrored[peer_id]
	var ids: Array = _id_strings(m[0])
	ids.sort()
	return "%s/%d/%s" % [",".join(PackedStringArray(ids)), int(m[2]), String(m[3]) if m.size() > 3 else "knife"]


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
			"lethal": frag.carry_start if frag != null else 0,
			"melee": WeaponController.KNIFE_ID,
			"tactical": &"",
			"tac_n": 0,
			"placeable": &"",
			"place_n": 0
		}
	return loadouts[peer_id]


func _broadcast_loadout(peer_id: int) -> void:
	var payload: Array = _loadout_payload(peer_id)
	Net.send_reliable(0, &"_wloadout", payload)
	_apply_loadout(payload)


func _loadout_payload(peer_id: int) -> Array:
	var lo: Dictionary = _loadout(peer_id)
	return [
		peer_id,
		_id_strings(lo["ids"]),
		String(lo["current"]),
		int(lo["lethal"]),
		String(lo.get("melee", WeaponController.KNIFE_ID)),
		String(lo.get("tactical", "")),
		int(lo.get("tac_n", 0)),
		String(lo.get("placeable", "")),
		int(lo.get("place_n", 0))
	]


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
	if def.behavior == &"pulse" and _pulse_parent(peer_id, def) != &"" and not validator.owns(peer_id, def.id):
		validator.give(peer_id, def)  # restored loadouts (reconnect) carry the Conduit, not its pulse
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
	if def.behavior != &"pulse":  # the pulse ring arrives through WonderFx; keep the held gun's model
		_relay_fire(peer_id, def, int(claim[10]), origin, forward, float(claim[9]))
	if def.behavior == &"projectile":
		var ctx: WeaponBehavior.ShotContext = WeaponBehavior.ShotContext.new()
		ctx.forward = forward
		ctx.spread_deg = float(claim[9])
		ctx.seed = int(claim[10])
		_host_launch(peer_id, def, int(claim[1]), _shooter_eye(peer_id, origin), projectile_dir(ctx))
		return
	if def.behavior == &"chain":
		host_chain(peer_id, def, _shooter_eye(peer_id, origin), forward)
		return
	if def.behavior == &"pulse":
		host_pulse(peer_id, def, _shooter_eye(peer_id, origin))
		return
	var eye: Vector3 = _shooter_eye(peer_id, origin)
	var space: PhysicsDirectSpaceState3D = get_viewport().get_world_3d().direct_space_state
	var killed: Array[HitTarget] = []
	var splashed: bool = false
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
		amount *= perk_damage_factor(peer_id, def, zone)
		var info: DamageInfo = DamageInfo.make(amount, zone, kind, def.id, peer_id)
		info.distance = dist
		info.target_index = int(hit[3])
		targets.host_damage(t, info)
		if not t.alive:
			killed.append(t)
		if def.is_upgraded() and t is ZombieActor:
			splashed = _host_upgrade_on_hit(peer_id, def, t as ZombieActor, zone, not t.alive, splashed)


# HOST: Forge behavior changes on a bullet hit (GAME_DESIGN §9.3): impact splash (Two Graves once
# per shot; Avalanche every headshot; Black Widow a headshot kill), slow (Glacier Breaker) and burn
# (Grease Fire). Returns whether this shot already splashed.
func _host_upgrade_on_hit(
	peer_id: int, def: WeaponDefinition, z: ZombieActor, zone: int, killed: bool, splashed: bool
) -> bool:
	if status != null and z.alive:
		if def.slow_factor > 0.0:
			status.host_slow(z, def.slow_factor, def.slow_time)
		if def.burn_dps > 0.0:
			status.host_burn(z, def.burn_dps, def.burn_time, peer_id, def.id)
	var head: bool = zone == WeaponDefinition.Hitzone.HEAD
	var go: bool = false
	match def.impact_splash:
		&"hit":
			go = not splashed
		&"headshot":
			go = head
		&"headshot_kill":
			go = head and killed
	if not go:
		return splashed
	var pos: Vector3 = z.zone_position(zone)
	host_splash(
		pos, def.impact_splash_radius, def.impact_splash_damage, def.impact_splash_damage * 0.25, def.id, peer_id
	)
	return true


# HOST: an explosion that is not a weapon's own blast (impact splash, cluster bomblets, hazards):
# damage with linear falloff to every live zombie / target in line of sight, no self damage, and
# `_wsplash` so every peer shows it.
func host_splash(
	pos: Vector3,
	radius: float,
	centre: float,
	edge: float,
	weapon_id: StringName,
	peer_id: int,
	kind: DamageInfo.Kind = DamageInfo.Kind.EXPLOSIVE
) -> int:
	impact_splashes += 1
	var hit: int = 0
	var space: PhysicsDirectSpaceState3D = get_viewport().get_world_3d().direct_space_state
	if targets != null:
		for id: int in targets.targets.keys():
			var t: HitTarget = targets.get_target(id)
			if t == null or not t.alive:
				continue
			var tp: Vector3 = t.zone_position(WeaponDefinition.Hitzone.TORSO)
			var d: float = pos.distance_to(tp)
			if d > radius or not HitValidator.has_line_of_sight(space, pos + Vector3.UP * 0.1, tp):
				continue
			var info: DamageInfo = DamageInfo.make(
				DamageModel.splash_damage(centre, edge, radius, d),
				WeaponDefinition.Hitzone.TORSO,
				kind,
				weapon_id,
				peer_id
			)
			info.distance = d
			info.position = pos
			targets.host_damage(t, info)
			hit += 1
	Net.send_reliable(0, &"_wsplash", [pos.x, pos.y, pos.z, radius])
	if not Net.is_active() or Net.is_host():
		_show_splash(pos, radius)
	return hit


func _show_splash(pos: Vector3, radius: float) -> void:
	splashes_shown += 1
	if not is_inside_tree():
		return
	WeaponFx.of(self).explosion(pos, radius)
	Audio.play_event_3d(&"frag_explode", pos)


func _on_msg_splash(sender: int, p: Array) -> void:
	if sender != 1 or Net.is_host() or p.size() < 4:
		return
	_show_splash(Vector3(float(p[0]), float(p[1]), float(p[2])), float(p[3]))


# HOST: the Lazarus Conduit's arc (GAME_DESIGN §7.2): the first zombie inside the aim cone, then
# up to `chain_jumps` more within `chain_jump_range` (line of sight between links), falloff per
# jump, each survivor electrocuted for `stun_time`; Requiem kills arc to `chain_kill_arcs` more.
func host_chain(peer_id: int, def: WeaponDefinition, eye: Vector3, forward: Vector3) -> int:
	chains += 1
	last_chain = []
	var zs: Array[ZombieActor] = _live_zombies()
	var pts: Array[Vector3] = []
	for z: ZombieActor in zs:
		pts.append(z.zone_position(WeaponDefinition.Hitzone.TORSO))
	var space: PhysicsDirectSpaceState3D = get_viewport().get_world_3d().direct_space_state
	var vis: Callable = func(a: Vector3, b: Vector3) -> bool: return HitValidator.has_line_of_sight(space, a, b)
	var muzzle: Vector3 = eye + forward.normalized() * 0.6 + Vector3.DOWN * 0.1
	var first: int = ChainLightning.pick_first(eye, forward, pts, def.max_range, def.chain_cone_deg, vis)
	if first < 0:
		var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			eye, eye + forward.normalized() * def.max_range, Ballistics.WORLD_MASK
		)
		var hit: Dictionary = space.intersect_ray(q)
		var end: Vector3 = hit["position"] if not hit.is_empty() else eye + forward.normalized() * def.max_range
		WonderFx.play(self, WonderFx.Kind.ARC, PackedVector3Array([muzzle, end]), 0.0, def.fx_variant)
		return 0
	var order: PackedInt32Array = ChainLightning.chain(first, pts, def.chain_jumps, def.chain_jump_range, vis)
	var arc: PackedVector3Array = PackedVector3Array([muzzle])
	var struck: Array = []
	for i: int in order:
		struck.append(i)
	for j: int in order.size():
		var z: ZombieActor = zs[order[j]]
		arc.append(pts[order[j]])
		var dmg: float = ChainLightning.damage_for(def, j)
		_chain_hit(peer_id, def, z, dmg, eye)
		if not z.alive and def.chain_kill_arcs > 0:
			var extra: PackedInt32Array = ChainLightning.nearest(
				order[j], pts, def.chain_kill_arcs, def.chain_jump_range, vis, struck
			)
			for k: int in extra.size():
				struck.append(extra[k])
				_chain_hit(peer_id, def, zs[extra[k]], dmg * def.chain_kill_arc_factor, eye)
				WonderFx.play(
					self, WonderFx.Kind.ARC, PackedVector3Array([pts[order[j]], pts[extra[k]]]), 0.0, def.fx_variant
				)
	WonderFx.play(self, WonderFx.Kind.ARC, arc, 0.0, def.fx_variant)
	Audio.play_event_3d(&"conduit_arc", eye)
	return struck.size()


func _chain_hit(peer_id: int, def: WeaponDefinition, z: ZombieActor, dmg: float, eye: Vector3) -> void:
	if not z.alive:
		return
	var info: DamageInfo = DamageInfo.make(dmg, WeaponDefinition.Hitzone.TORSO, DamageInfo.Kind.BULLET, def.id, peer_id)
	info.position = eye
	info.distance = eye.distance_to(z.global_position)
	targets.host_damage(z, info)
	var stunned: bool = false
	if z.alive and z.sim != null:
		stunned = z.sim.host_electrocute(def.stun_time)
	last_chain.append([z, dmg, stunned])


# HOST: the Conduit pulse (hold fire 1 s, 3 rounds): stuns every zombie within `splash_radius` of
# the shooter for `stun_time`, no damage — the escape tool.
func host_pulse(peer_id: int, def: WeaponDefinition, eye: Vector3) -> int:
	pulses += 1
	last_pulse = []
	var parent: WeaponDefinition = WeaponCatalog.get_def(_pulse_parent(peer_id, def))
	if parent != null:
		var a: Array = validator.ammo(peer_id, parent.id)
		a[0] = maxi(int(a[0]) - parent.pulse_ammo, 0)
	var at: Vector3 = eye + Vector3.DOWN * 1.5
	if players != null and players.avatars.has(peer_id):
		at = (players.avatars[peer_id] as Node3D).global_position
	for z: ZombieActor in _live_zombies():
		if z.global_position.distance_to(at) <= def.splash_radius and z.sim != null:
			if z.sim.host_electrocute(def.stun_time):
				last_pulse.append(z)
	WonderFx.play(self, WonderFx.Kind.RING, PackedVector3Array([at]), def.splash_radius, def.fx_variant)
	Audio.play_event_3d(&"conduit_pulse", at)
	return last_pulse.size()


# The Conduit (or its Requiem upgrade) a pulse draws from, "" when the peer owns neither.
func _pulse_parent(peer_id: int, pulse: WeaponDefinition) -> StringName:
	for wid: StringName in [StringName(String(pulse.attachment_of) + "_up"), pulse.attachment_of]:
		if validator.owns(peer_id, wid):
			return wid
	return &""


func _live_zombies() -> Array[ZombieActor]:
	var out: Array[ZombieActor] = []
	if targets == null:
		return out
	for id: int in targets.targets.keys():
		var t: HitTarget = targets.get_target(id)
		if t is ZombieActor and t.alive:
			out.append(t as ZombieActor)
	return out


# Perk damage (host): Twin-Fire fires every hitscan bullet twice (×2, ammo once; projectile /
# melee weapons get the fire rate only); Bullseye adds +25 % to headshots (GAME_DESIGN §8).
func perk_damage_factor(peer_id: int, def: WeaponDefinition, zone: int) -> float:
	var st: PlayerStats = stats_of(peer_id)
	if st == null or def.is_melee():
		return 1.0
	var f: float = 1.0
	if def.behavior in [&"hitscan", &"pellet"] and st.flag(PlayerStats.DOUBLE_TAP):
		f *= 2.0
	if zone == WeaponDefinition.Hitzone.HEAD:
		f *= st.value(PlayerStats.HEADSHOT_BONUS, 1.0)
	return f


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
	var tactical: bool = def.weapon_class == WeaponDefinition.WeaponClass.TACTICAL
	var count_key: String = "tac_n" if tactical else "lethal"
	if int(lo.get(count_key, 0)) <= 0 or tactical and StringName(lo.get("tactical", &"")) != def.id:
		validator._reject(HitValidator.Result.NO_AMMO, "peer %d has no %s" % [peer_id, def.id])
		return
	lo[count_key] = int(lo[count_key]) - 1
	var fuse_clamped: float = clampf(fuse, 0.0, def.fuse_time)
	var g: Grenade = _spawn_grenade(def, peer_id, seq, origin, vel, fuse_clamped, true)
	g.exploded.connect(_on_grenade_exploded)
	if tactical:
		_broadcast_loadout(peer_id)
		if attraction.is_valid():
			attraction.call(g, def)
	Net.send_reliable(
		0, &"_wthrow_r", [peer_id, seq, origin.x, origin.y, origin.z, vel.x, vel.y, vel.z, fuse_clamped, String(def.id)]
	)


func _on_grenade_exploded(g: Grenade, pos: Vector3) -> void:
	grenades.erase(g.key)
	host_explode(g.def, g.peer_id, pos)
	Net.send_reliable(
		0, &"_wexplode", [g.peer_id, g.key.get_slice(":", 1).to_int(), pos.x, pos.y, pos.z, String(g.def.id)]
	)


# HOST: splash damage of an explosive (GAME_DESIGN §4.3): `splash_damage_centre` falling linearly
# to `splash_damage_edge` at `splash_radius` (line of sight from the blast), to every live target;
# the owner takes up to `self_damage_max` with the same falloff (§3.2; friendly fire is off).
func host_explode(def: WeaponDefinition, peer_id: int, pos: Vector3) -> void:
	explosions += 1
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
				amount, WeaponDefinition.Hitzone.TORSO, DamageInfo.Kind.EXPLOSIVE, def.id, peer_id
			)
			info.distance = d
			info.position = pos
			targets.host_damage(t, info)
	if players != null and players.avatars.has(peer_id):
		var owner_avatar: PlayerCharacter = players.avatars[peer_id]
		var pd: float = pos.distance_to(owner_avatar.global_position + Vector3.UP * 0.9)
		var dmg: float = DamageModel.self_damage(def, pd)
		if dmg > 0.0:
			players.damage_player(peer_id, dmg, pos, HealthComponent.DamageType.EXPLOSIVE)
	if def.projectile_kind == &"plasma":
		WonderFx.play(self, WonderFx.Kind.BURST, PackedVector3Array([pos]), def.splash_radius, def.fx_variant)
		Audio.play_event_3d(&"ray_splash", pos)
	else:
		WeaponFx.of(self).explosion(pos, def.splash_radius)
		Audio.play_event_3d(&"frag_explode", pos)
	if def.cluster_count > 0:
		_host_cluster(def, peer_id, pos)


# L.A.W. of Averages (GAME_DESIGN §9.3): micro-cluster bomblets scatter around the rocket's blast
# (a fixed ring, so the result is deterministic) and burst 0.2 s apart.
func _host_cluster(def: WeaponDefinition, peer_id: int, pos: Vector3) -> void:
	for i: int in def.cluster_count:
		var a: float = TAU * float(i) / float(def.cluster_count)
		var at: Vector3 = pos + Vector3(cos(a), 0.2, sin(a)) * def.splash_radius * 0.6
		var delay: float = 0.2 * float(i + 1)
		get_tree().create_timer(delay, false, true).timeout.connect(
			func() -> void:
				if is_inside_tree():
					host_splash(
						at,
						def.cluster_radius,
						def.splash_damage_centre * 0.5,
						def.splash_damage_edge * 0.5,
						def.id,
						peer_id
					)
		)


# HOST: launches the authoritative projectile of an accepted shot and relays it.
func _host_launch(peer_id: int, def: WeaponDefinition, seq: int, eye: Vector3, dir: Vector3) -> void:
	var p: Projectile = _spawn_projectile(def, peer_id, seq, eye, dir, true)
	p.struck.connect(_on_projectile_struck)
	p.detonated.connect(_on_projectile_detonated)
	if def.attract_radius > 0.0 and attraction.is_valid():
		p.stuck_to.connect(func(stuck: Projectile) -> void: attraction.call(stuck, stuck.def))  # Lure of the Lantern
	Net.send_reliable(0, &"_wproj", [peer_id, String(def.id), seq, eye.x, eye.y, eye.z, dir.x, dir.y, dir.z])


func _spawn_projectile(
	def: WeaponDefinition, peer_id: int, seq: int, eye: Vector3, dir: Vector3, auth: bool
) -> Projectile:
	var key: String = "p%d:%d" % [peer_id, seq]
	if projectiles.has(key) and is_instance_valid(projectiles[key]):
		var existing: Projectile = projectiles[key]
		if auth and not existing.authoritative:
			existing.queue_free()  # host-local predicted copy (never happens for host shooters)
		else:
			return existing
	var p: Projectile = Projectile.create(def, key, peer_id, ProjectileBehavior.launch_velocity(def, dir), auth)
	if players != null and players.avatars.has(peer_id):
		p.exclude = []  # player capsules are not on the world layer; nothing to exclude
	var parent: Node = Match.current if Match.current != null else get_parent()
	parent.add_child(p)
	p.global_position = ProjectileBehavior.launch_origin(eye, dir)
	projectiles[key] = p
	p.tree_exiting.connect(func() -> void: projectiles.erase(key))
	return p


func _on_projectile_struck(p: Projectile, t: HitTarget, zone: int, pos: Vector3) -> void:
	if targets == null or t == null or not t.alive or t.target_id <= 0:
		return
	var info: DamageInfo = DamageInfo.make(p.def.damage, zone, DamageInfo.Kind.EXPLOSIVE, p.def.id, p.peer_id)
	info.position = pos
	info.distance = p.traveled
	targets.host_damage(t, info)


func _on_projectile_detonated(p: Projectile, pos: Vector3) -> void:
	projectiles.erase(p.key)
	host_explode(p.def, p.peer_id, pos)
	Net.send_reliable(0, &"_wpexplode", [p.key, String(p.def.id), pos.x, pos.y, pos.z])


# HOST: tripmines (GAME_DESIGN §4.3): `place_limit` placed per player, counted against `place_n`.
func _host_place_mine(peer_id: int, seq: int, pos: Vector3, yaw: float) -> void:
	var lo: Dictionary = _loadout(peer_id)
	var def: WeaponDefinition = WeaponCatalog.get_def(StringName(lo.get("placeable", &"")))
	if def == null or int(lo.get("place_n", 0)) <= 0:
		return
	if players != null and players.avatars.has(peer_id):
		var a: PlayerCharacter = players.avatars[peer_id]
		if a.global_position.distance_to(pos) > 4.0:
			return
	var placed: int = 0
	for m: Tripmine in mines.values():
		if m.peer_id == peer_id:
			placed += 1
	if placed >= def.place_limit:
		return
	lo["place_n"] = int(lo["place_n"]) - 1
	_broadcast_loadout(peer_id)
	_spawn_mine(def, peer_id, seq, pos, yaw)
	Net.send_reliable(0, &"_wmine_r", [peer_id, seq, pos.x, pos.y, pos.z, yaw])


func _spawn_mine(def: WeaponDefinition, peer_id: int, seq: int, pos: Vector3, yaw: float) -> Tripmine:
	var key: String = "m%d:%d" % [peer_id, seq]
	if mines.has(key):
		return mines[key]
	var m: Tripmine = Tripmine.create(def, key, peer_id)
	var parent: Node = Match.current if Match.current != null else get_parent()
	parent.add_child(m)
	m.global_position = pos
	m.rotation.y = yaw
	mines[key] = m
	m.tree_exiting.connect(func() -> void: mines.erase(key))
	if is_authority():
		m.triggered.connect(_on_mine_triggered)
	return m


func _on_mine_triggered(m: Tripmine) -> void:
	var pos: Vector3 = m.global_position + Vector3.UP * 0.1
	mines.erase(m.key)
	m.queue_free()
	host_explode(m.def, m.peer_id, pos)
	Net.send_reliable(0, &"_wpexplode", [m.key, String(m.def.id), pos.x, pos.y, pos.z])


# HOST: removes a player's placed tripmines (bled out / left).
func host_clear_mines(peer_id: int) -> void:
	for key: String in mines.keys():
		var m: Tripmine = mines[key]
		if m.peer_id == peer_id:
			mines.erase(key)
			m.queue_free()


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
	var melee: String = String(p[4]) if p.size() > 4 else String(WeaponController.KNIFE_ID)
	mirrored[int(p[0])] = [(p[1] as Array).duplicate(), String(p[2]), int(p[3]), melee]
	if players == null:
		return
	var peer: int = int(p[0])
	if not players.avatars.has(peer):
		return
	var avatar: PlayerCharacter = players.avatars[peer]
	if avatar.is_local:
		avatar.weapons.apply_loadout(p[1], StringName(p[2]), int(p[3]))
		if p.size() > 8:
			avatar.weapons.apply_equipment(StringName(p[4]), StringName(p[5]), int(p[6]), StringName(p[7]), int(p[8]))
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
	var def: WeaponDefinition = WeaponCatalog.get_def(StringName(p[9]) if p.size() > 9 else WeaponController.FRAG_ID)
	if def == null:
		return
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
	var def: WeaponDefinition = WeaponCatalog.get_def(StringName(p[5]) if p.size() > 5 else WeaponController.FRAG_ID)
	var pos: Vector3 = Vector3(float(p[2]), float(p[3]), float(p[4]))
	WeaponFx.of(self).explosion(pos, def.splash_radius if def != null else 4.0)
	Audio.play_event_3d(&"frag_explode", pos)


func _on_msg_proj(sender: int, p: Array) -> void:
	if sender != 1 or Net.is_host() or int(p[0]) == Net.local_id():
		return
	var def: WeaponDefinition = WeaponCatalog.get_def(StringName(p[1]))
	if def != null:
		_spawn_projectile(
			def,
			int(p[0]),
			int(p[2]),
			Vector3(float(p[3]), float(p[4]), float(p[5])),
			Vector3(float(p[6]), float(p[7]), float(p[8])),
			false
		)


func _on_msg_pexplode(sender: int, p: Array) -> void:
	if sender != 1 or Net.is_host():
		return
	var key: String = String(p[0])
	if projectiles.has(key) and is_instance_valid(projectiles[key]):
		(projectiles[key] as Projectile).queue_free()
	projectiles.erase(key)
	if mines.has(key) and is_instance_valid(mines[key]):
		(mines[key] as Tripmine).queue_free()
	mines.erase(key)
	var def: WeaponDefinition = WeaponCatalog.get_def(StringName(p[1]))
	var pos: Vector3 = Vector3(float(p[2]), float(p[3]), float(p[4]))
	if def != null and def.projectile_kind == &"plasma":
		Audio.play_event_3d(&"ray_splash", pos)  # the burst itself comes through WonderFx `_wfx`
		return
	WeaponFx.of(self).explosion(pos, def.splash_radius if def != null else 4.0)
	Audio.play_event_3d(&"frag_explode", pos)


func _on_msg_tac(sender: int, p: Array) -> void:
	if not Net.is_host():
		return
	var lo: Dictionary = _loadout(sender)
	var def: WeaponDefinition = WeaponCatalog.get_def(StringName(lo.get("tactical", &"")))
	if def == null:
		return
	var origin: Vector3 = Vector3(float(p[1]), float(p[2]), float(p[3]))
	var known: Vector3 = _shooter_eye(sender, origin)
	if known.distance_to(origin) > ORIGIN_SLACK:
		origin = known
	_host_throw(sender, def, int(p[0]), origin, Vector3(float(p[4]), float(p[5]), float(p[6])), def.fuse_time)


func _on_msg_mine(sender: int, p: Array) -> void:
	if Net.is_host():
		_host_place_mine(sender, int(p[0]), Vector3(float(p[1]), float(p[2]), float(p[3])), float(p[4]))


func _on_msg_mine_relay(sender: int, p: Array) -> void:
	if sender != 1 or Net.is_host():
		return
	var lo_def: WeaponDefinition = WeaponCatalog.get_def(&"tripmines")
	if lo_def != null:
		_spawn_mine(lo_def, int(p[0]), int(p[1]), Vector3(float(p[2]), float(p[3]), float(p[4])), float(p[5]))


func _on_msg_mines_full(sender: int, p: Array) -> void:
	if sender != 1 or Net.is_host():
		return
	for e: Variant in p:
		_on_msg_mine_relay(1, e as Array)


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
			Net.send_reliable(peer_id, &"_wloadout", _loadout_payload(id))
	var full: Array = []
	for m: Tripmine in mines.values():
		var mp: Vector3 = m.global_position
		full.append([m.peer_id, m.key.get_slice(":", 1).to_int(), mp.x, mp.y, mp.z, m.rotation.y])
	if not full.is_empty():
		Net.send_reliable(peer_id, &"_wmines_full", full)


func _on_peer_left(peer_id: int) -> void:
	if is_authority():
		host_clear_mines(peer_id)
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
