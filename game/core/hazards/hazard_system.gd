# HazardSystem — environmental hazards (VESPER_PEAK §5 H1-H3; DEVELOPMENT_PLAN Step 11B scope 5),
# built from MapMarkers of kind &"hazard" by name prefix, BEFORE the target and interaction scans
# (tree-order ids on every peer):
#   H1_*  fuel drums (3 ExplosiveDrums per marker): shoot -> blast; destroyed drums respawn every
#         3 rounds.
#   H2_*  icicle clusters (IcicleCluster): shoot -> fall, kills zombies below; regrow after 2 rounds.
#   H3_Breaker + H3_Puddles: LabBreaker (free, power) electrifies the puddles 10 s (stun + damage),
#         recharge 90 s. Flags "hazard.H3.until" / ".ready".
# Authority: HOST applies effects and respawns; drums / icicles replicate through TargetRegistry.
class_name HazardSystem
extends Node

const DRUM_OFFSETS: Array[Vector3] = [Vector3(0, 0, 0), Vector3(0.75, 0, 0.2), Vector3(0.3, 0, -0.7)]
const PUDDLE_OFFSETS: Array[Vector3] = [
	Vector3(-2.2, 0, -1.6), Vector3(2.0, 0, -1.9), Vector3(-1.6, 0, 2.1), Vector3(2.4, 0, 1.8)
]
const PUDDLE_ZOMBIE_DPS_FRACTION: float = 0.25  # of max health per second, plus the stun
const PUDDLE_PLAYER_DPS: float = 15.0
const STUN_TIME: float = 1.2
const TICK: float = 0.2
const FLAG_H3: String = "hazard.H3"

var match_node: Match = null
var drums: Array[ExplosiveDrum] = []
var icicles: Array[IcicleCluster] = []
var breaker: LabBreaker = null
var drum_blasts: int = 0
var icicle_kills: int = 0
var puddle_hits: int = 0

var _tick: float = 0.0


static func is_authority() -> bool:
	return Net.is_host() or not Net.is_active()


func setup(map_root: Node) -> void:
	name = "Hazards"
	ProgressionAudio.ensure()
	var markers: Array[MapMarker] = []
	for n: Node in map_root.find_children("*", "MapMarker", true, false):
		if (n as MapMarker).kind == &"hazard":
			markers.append(n as MapMarker)
	markers.sort_custom(func(a: MapMarker, b: MapMarker) -> bool: return String(a.marker_id) < String(b.marker_id))
	var puddle_marker: MapMarker = null
	for mk: MapMarker in markers:
		var id: String = String(mk.marker_id)
		if id.begins_with("H1_"):
			mk.show_visual = false
			for i: int in DRUM_OFFSETS.size():
				var d: ExplosiveDrum = ExplosiveDrum.new()
				d.name = "Drum%d" % i
				d.system = self
				d.position = DRUM_OFFSETS[i]
				mk.add_child(d)
				drums.append(d)
		elif id.begins_with("H2_"):
			mk.show_visual = false
			var ic: IcicleCluster = IcicleCluster.new()
			ic.name = "Icicles"
			ic.system = self
			ic.ground_y = _ground_below(mk)
			mk.add_child(ic)
			icicles.append(ic)
		elif id == "H3_Puddles":
			puddle_marker = mk
	for mk: MapMarker in markers:
		if String(mk.marker_id) == "H3_Breaker":
			mk.show_visual = false
			breaker = LabBreaker.new()
			breaker.name = "LabBreaker"
			breaker.system = self
			if puddle_marker != null:
				puddle_marker.show_visual = false
				for o: Vector3 in PUDDLE_OFFSETS:
					breaker.puddles.append(
						(
							puddle_marker.global_transform * o
							if puddle_marker.is_inside_tree()
							else puddle_marker.position + o
						)
					)
			mk.add_child(breaker)


# Markers sit in the map before it is in the tree: estimate the ground from the zone datum below
# (icicles hang ~6.5 m over the Courtyard floor at y -8; refined at runtime by a ray).
func _ground_below(mk: MapMarker) -> float:
	return mk.position.y - 6.5


func _ready() -> void:
	if match_node != null and match_node.rounds != null:
		match_node.rounds.round_started.connect(_on_round_started)
	for ic: IcicleCluster in icicles:
		_refine_ground.call_deferred(ic)


func _refine_ground(ic: IcicleCluster) -> void:
	if not ic.is_inside_tree():
		return
	var space: PhysicsDirectSpaceState3D = ic.get_world_3d().direct_space_state
	var from: Vector3 = ic.global_position + Vector3.DOWN * 1.0
	var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 30.0, 1))
	if not hit.is_empty():
		ic.ground_y = (hit["position"] as Vector3).y


func session() -> MatchSession:
	return match_node.session if match_node != null else null


func current_round() -> int:
	return match_node.rounds.current_round if match_node != null and match_node.rounds != null else 0


# --- H1 / H2 (host) ------------------------------------------------------------------------------


func host_drum_exploded(d: ExplosiveDrum, source_peer: int) -> void:
	if not is_authority():
		return
	d.died_round = current_round()
	drum_blasts += 1
	var pos: Vector3 = d.global_position + Vector3.UP * 0.5
	var ws: WeaponSync = match_node.weapons
	if ws != null:
		ws.host_splash(
			pos, ExplosiveDrum.RADIUS, ExplosiveDrum.DAMAGE, ExplosiveDrum.EDGE_DAMAGE, &"fuel_drum", source_peer
		)
	if match_node.players != null:
		for id: int in match_node.players.avatars:
			var p: PlayerCharacter = match_node.players.avatars[id]
			var dist: float = pos.distance_to(p.global_position + Vector3.UP * 0.9)
			if dist < ExplosiveDrum.RADIUS and not p.health.is_downed:
				var dmg: float = ExplosiveDrum.PLAYER_DAMAGE * (1.0 - dist / ExplosiveDrum.RADIUS)
				match_node.players.damage_player(id, dmg, pos, HealthComponent.DamageType.EXPLOSIVE)


func host_icicles_dropped(ic: IcicleCluster, source_peer: int) -> void:
	if not is_authority():
		return
	ic.died_round = current_round()
	get_tree().create_timer(IcicleCluster.FALL_TIME, false, true).timeout.connect(_icicle_impact.bind(ic, source_peer))


func _icicle_impact(ic: IcicleCluster, source_peer: int) -> void:
	if not is_instance_valid(ic) or match_node == null or match_node.zombies == null:
		return
	var at: Vector3 = Vector3(ic.global_position.x, ic.ground_y, ic.global_position.z)
	for a: ZombieActor in match_node.zombies.actors.values():
		if not is_instance_valid(a) or not a.alive:
			continue
		var flat: float = Vector2(a.global_position.x - at.x, a.global_position.z - at.z).length()
		if flat <= IcicleCluster.KILL_RADIUS and absf(a.global_position.y - at.y) < 2.5:
			var info: DamageInfo = DamageInfo.make(
				a.health + 1.0, WeaponDefinition.Hitzone.HEAD, DamageInfo.Kind.EXPLOSIVE, &"icicles", source_peer
			)
			info.position = at + Vector3.UP * 2.0
			match_node.targets.host_damage(a, info)
			icicle_kills += 1


func _on_round_started(r: int) -> void:
	if not is_authority() or match_node.targets == null:
		return
	for d: ExplosiveDrum in drums:
		if not d.alive and r >= d.died_round + ExplosiveDrum.RESPAWN_ROUNDS:
			match_node.targets.host_revive_target(d)
	for ic: IcicleCluster in icicles:
		if not ic.alive and r >= ic.died_round + IcicleCluster.REGROW_ROUNDS:
			match_node.targets.host_revive_target(ic)


# --- H3 ------------------------------------------------------------------------------------------


func breaker_until() -> float:
	var s: MatchSession = session()
	return float(s.flag(FLAG_H3 + ".until", -1.0)) if s != null else -1.0


func breaker_ready_at() -> float:
	var s: MatchSession = session()
	return float(s.flag(FLAG_H3 + ".ready", -1.0)) if s != null else -1.0


func breaker_active() -> bool:
	return Net.host_time() < breaker_until()


func breaker_cooling() -> bool:
	return not breaker_active() and Net.host_time() < breaker_ready_at()


func host_flip_breaker(peer_id: int) -> bool:
	if not is_authority() or breaker_active() or breaker_cooling():
		return false
	var now: float = Net.host_time()
	session().host_set_flag(FLAG_H3 + ".by", peer_id)
	session().host_set_flag(FLAG_H3 + ".until", now + LabBreaker.ACTIVE_TIME)
	session().host_set_flag(FLAG_H3 + ".ready", now + LabBreaker.ACTIVE_TIME + LabBreaker.RECHARGE)
	return true


func in_puddle(p: Vector3) -> bool:
	if breaker == null:
		return false
	for c: Vector3 in breaker.puddles:
		if Vector2(p.x - c.x, p.z - c.z).length() <= LabBreaker.PUDDLE_RADIUS and absf(p.y - c.y) < 1.0:
			return true
	return false


func _physics_process(delta: float) -> void:
	if not is_authority() or breaker == null or not breaker_active():
		return
	_tick += delta
	if _tick < TICK:
		return
	var dt: float = _tick
	_tick = 0.0
	var peer: int = int(session().flag(FLAG_H3 + ".by", 0))
	for a: ZombieActor in match_node.zombies.actors.values():
		if not is_instance_valid(a) or not a.alive or not in_puddle(a.global_position):
			continue
		puddle_hits += 1
		if a.sim != null:
			a.sim.host_stun(STUN_TIME)
		var info: DamageInfo = DamageInfo.make(
			a.max_health * PUDDLE_ZOMBIE_DPS_FRACTION * dt,
			WeaponDefinition.Hitzone.TORSO,
			DamageInfo.Kind.TRAP,
			&"breaker",
			peer
		)
		match_node.targets.host_damage(a, info)
	for id: int in match_node.players.avatars:
		var p: PlayerCharacter = match_node.players.avatars[id]
		if not p.health.is_downed and in_puddle(p.global_position):
			match_node.players.damage_player(
				id, PUDDLE_PLAYER_DPS * dt, p.global_position, HealthComponent.DamageType.GENERIC
			)
