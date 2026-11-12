# SpecialRoundDirector — the special-enemy layer of a match (DEVELOPMENT_PLAN Step 12B):
#  * special-round atmosphere on every peer: during the last `special_warning` seconds of the
#    intermission before a special round the storm thickens (fog density / colour), map lights
#    flicker green, an energy pulse rolls out from each player and the warning + music play; the
#    green tint holds through the special round and clears at its end (from the replicated
#    RoundDirector state, so a late joiner mid-round gets it too);
#  * Galvanic death burst (host): players within `burst_radius` take `burst_damage` (falloff) and
#    the nearest barricade within `burst_plank_radius` loses a plank;
#  * the last special enemy of a special round drops Max Ammo (host, RoundDirector signal);
#  * the Warden's armor / phase replication (`_warden` [net_id, plates_left, phase], join snapshot);
#  * the rare late-round Warden (GAME_DESIGN §5.4): from round 25, at most once per 10 rounds, a
#    small chance per round — only while MapRules.warden_late_rounds_enabled() (off until Step 14
#    balances it); its death drops a Free Upgrade.
# Authority: HOST decides bursts, drops and Warden spawns; every peer presents the atmosphere.
class_name SpecialRoundDirector
extends Node

signal warning_started(enemy: StringName)

const WARDEN_FROM_ROUND: int = 25
const WARDEN_EVERY: int = 10
const WARDEN_CHANCE: float = 0.15
const FOG_DENSITY_SCALE: float = 1.8
const STORM_COLOR: Color = Color(0.35, 0.75, 0.5)
const MAX_FLICKER_LIGHTS: int = 64

var match_node: Match = null
var warning_active: bool = false
var atmosphere: float = 0.0  # 0 normal .. 1 full special-round storm (presentation)
var warnings: int = 0
var bursts: int = 0
var planks_disabled: int = 0
var max_ammo_drops: int = 0
var late_wardens: Array[int] = []  # host: net ids of wardens spawned by the late-round rule
var last_warden_round: int = -100

var _lights: Array = []  # [Light3D, base colour, base energy]
var _env: Environment = null
var _env_base: Array = []  # [fog density, fog colour]
var _t: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


static func is_authority() -> bool:
	return Net.is_host() or not Net.is_active()


func _ready() -> void:
	name = "SpecialRounds"
	_rng.randomize()
	WonderAudio.ensure()
	Net.register_message(&"_warden", _on_msg_warden)
	Net.peer_joined.connect(_on_peer_joined)
	if match_node == null:
		return
	_collect_presentation()
	if is_authority() and match_node.zombies != null:
		match_node.zombies.zombie_died.connect(_on_zombie_died)
	if is_authority() and match_node.rounds != null:
		match_node.rounds.special_last_killed.connect(_on_last_special)
		match_node.rounds.round_started.connect(_on_round_started)


func _exit_tree() -> void:
	Net.unregister_message(&"_warden")
	_apply_atmosphere(0.0)


func _collect_presentation() -> void:
	var root: Node = match_node.map_root
	if root == null:
		return
	for n: Node in root.find_children("*", "WorldEnvironment", true, false):
		_env = (n as WorldEnvironment).environment
		if _env != null:
			_env_base = [_env.fog_density, _env.fog_light_color]
			break
	for n: Node in root.find_children("*", "Light3D", true, false):
		if n is DirectionalLight3D or _lights.size() >= MAX_FLICKER_LIGHTS:
			continue
		var l: Light3D = n as Light3D
		_lights.append([l, l.light_color, l.light_energy])


# --- atmosphere (every peer) ------------------------------------------------------------------


func _process(delta: float) -> void:
	if match_node == null or match_node.rounds == null:
		return
	_t += delta
	var rd: RoundDirector = match_node.rounds
	var warn: bool = (
		rd.phase == RoundDirector.Phase.INTERMISSION
		and rd.next_special != &""
		and rd.time_left <= rd.curve.special_warning
	)
	if warn and not warning_active:
		_start_warning(rd.next_special)
	warning_active = warn
	var want: float = 1.0 if warn or (rd.phase == RoundDirector.Phase.ACTIVE and rd.special_id != &"") else 0.0
	atmosphere = move_toward(atmosphere, want, delta / 2.0)
	_apply_atmosphere(atmosphere)


func _start_warning(enemy: StringName) -> void:
	warnings += 1
	warning_started.emit(enemy)
	Audio.play_event(&"special_warning")
	Audio.play_event(&"special_music")
	var me: PlayerCharacter = match_node.players.local_avatar() if match_node.players != null else null
	if me != null:
		var fx: WonderFx = WonderFx.of(self)
		if fx != null:
			fx.present(WonderFx.Kind.RING, PackedVector3Array([me.global_position]), 30.0, WonderFx.Variant.GREEN)
	Log.info(&"special", "Special round warning (%s)" % enemy)


func _apply_atmosphere(u: float) -> void:
	if _env != null and not _env_base.is_empty():
		_env.fog_density = lerpf(float(_env_base[0]), float(_env_base[0]) * FOG_DENSITY_SCALE, u)
		_env.fog_light_color = (_env_base[1] as Color).lerp(STORM_COLOR, u * 0.6)
	for e: Array in _lights:
		var l: Light3D = e[0] as Light3D
		if not is_instance_valid(l):
			continue
		var flicker: float = 1.0
		if warning_active:
			flicker = 0.35 if sin(_t * 23.0 + float(l.get_instance_id() % 97)) > 0.55 else 1.0
		l.light_color = (e[1] as Color).lerp(Color(0.4, 1.0, 0.5), u * 0.7)
		l.light_energy = float(e[2]) * lerpf(1.0, flicker, u)


# --- host: deaths, drops, the late Warden ---------------------------------------------------------


func _on_zombie_died(a: ZombieActor, _source: int) -> void:
	var arch: ZombieArchetype = a.archetype
	if arch != null and arch.burst_radius > 0.0:
		_burst(a, arch)
	if late_wardens.has(a.net_id):
		late_wardens.erase(a.net_id)
		if match_node.powerups != null:
			match_node.powerups.host_spawn(&"free_upgrade", match_node.powerups.drop_position(a.global_position))


func _burst(a: ZombieActor, arch: ZombieArchetype) -> void:
	bursts += 1
	var at: Vector3 = a.global_position + Vector3.UP * 0.9
	var pl: PlayerSync = match_node.players
	if pl != null:
		for id: int in pl.avatars:
			var p: PlayerCharacter = pl.avatars[id]
			var d: float = p.global_position.distance_to(a.global_position)
			if d <= arch.burst_radius and not p.health.is_downed:
				var dmg: float = DamageModel.splash_damage(
					arch.burst_damage, arch.burst_damage * 0.5, arch.burst_radius, d
				)
				pl.damage_player(id, dmg, at, HealthComponent.DamageType.EXPLOSIVE)
	if arch.burst_plank_radius > 0.0 and match_node.map_root != null:
		var best: Barricade = null
		var best_d: float = arch.burst_plank_radius
		for n: Node in match_node.map_root.find_children("*", "Barricade", true, false):
			var b: Barricade = n as Barricade
			var d: float = b.global_position.distance_to(a.global_position)
			if d <= best_d and b.planks > 0:
				best_d = d
				best = b
		if best != null and best.host_tear():
			planks_disabled += 1


func _on_last_special(a: ZombieActor) -> void:
	if match_node.powerups == null:
		return
	max_ammo_drops += 1
	match_node.powerups.host_spawn(&"max_ammo", match_node.powerups.drop_position(a.global_position))
	Log.info(&"special", "Last special enemy of round %d: Max Ammo" % match_node.rounds.current_round)


func _on_round_started(r: int) -> void:
	if match_node.rules == null or not match_node.rules.warden_late_rounds_enabled():
		return
	if r < WARDEN_FROM_ROUND or r - last_warden_round < WARDEN_EVERY or match_node.rounds.is_special_round():
		return
	if _rng.randf() >= WARDEN_CHANCE:
		return
	host_spawn_late_warden(r)


func host_spawn_late_warden(r: int) -> ZombieActor:
	var zs: ZombieSync = match_node.zombies
	var sp: ZombieSpawner = zs.pick_spawner(true)
	if sp == null:
		return null
	var w: ZombieActor = WardenBehavior.host_spawn(
		zs, sp.global_position, sp.global_rotation.y, r, match_node.rounds.player_count()
	)
	if w != null:
		last_warden_round = r
		late_wardens.append(w.net_id)
		Log.info(&"special", "The Warden walks (round %d)" % r)
	return w


# --- Warden replication ---------------------------------------------------------------------------


func _on_msg_warden(sender: int, p: Array) -> void:
	if sender != 1 or Net.is_host() or p.size() < 3 or match_node == null or match_node.zombies == null:
		return
	var a: ZombieActor = match_node.zombies.actors.get(int(p[0]), null)
	if a != null:
		a.set_meta(&"warden_plates", int(p[1]))
		a.set_meta(&"warden_phase", int(p[2]))


func _on_peer_joined(peer_id: int, _info: Dictionary) -> void:
	if not Net.is_host() or peer_id == Net.local_id() or match_node == null or match_node.zombies == null:
		return
	for a: ZombieActor in match_node.zombies.actors.values():
		if a.has_meta(&"warden_plates"):
			Net.send_reliable(
				peer_id, &"_warden", [a.net_id, int(a.get_meta(&"warden_plates")), int(a.get_meta(&"warden_phase", 0))]
			)
