# SurvivalBot — a simple bot player for soak tests (DEVELOPMENT_PLAN Step 6 scope 12): follows the
# map's `bot_waypoint` loop (skipping legs behind closed doors), backs away from close zombies,
# shoots the nearest visible zombie with its held weapon (accuracy roll, damage from the weapon
# definition, applied through TargetRegistry so points / kills count normally; no ammo
# bookkeeping), rebuilds barricades and buys doors / one wall weapon through the normal
# InteractionSystem path, and revives downed teammates.
# Authority: HOST only (drives a PlayerSync host bot avatar through its bot_driver).
class_name SurvivalBot
extends RefCounted

const RETARGET_INTERVAL: float = 0.25
const DANGER_RADIUS: float = 3.2
const VIEW_RANGE: float = 32.0

var player: PlayerCharacter = null
var match_node: Match = null
var route: Array[Marker3D] = []
var index: int = 0
var accuracy: float = 0.55
var head_share: float = 0.25
var damage_scale: float = 1.0  # soak runs that test spawning, not combat, speed rounds up
var shots: int = 0
var hits: int = 0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _target: ZombieActor = null
var _retarget: float = 0.0
var _fire_cd: float = 0.0
var _best_dist: float = INF
var _since_progress: float = 0.0
var _reviving: int = 0


static func attach(p: PlayerCharacter, m: Match, seed_value: int = 0) -> SurvivalBot:
	var b: SurvivalBot = SurvivalBot.new()
	b.player = p
	b.match_node = m
	b._rng.seed = seed_value if seed_value != 0 else hash(p.peer_id)
	var markers: Array[Node] = m.map_root.find_children("*", "Marker3D", true, false)
	markers.sort_custom(func(a: Node, c: Node) -> bool: return String(a.name) < String(c.name))
	for n: Node in markers:
		if n.is_in_group(&"bot_waypoint"):
			b.route.append(n as Marker3D)
	b.index = b._rng.randi_range(0, maxi(b.route.size() - 1, 0))
	p.bot_driver = b.drive
	p.set_meta(&"survival_bot", b)
	return b


func drive(p: PlayerCharacter, dt: float) -> PlayerInputFrame:
	var f: PlayerInputFrame = PlayerInputFrame.new()
	if not is_instance_valid(match_node) or p.spectating:
		return f
	var ds: DownedSystem = match_node.downed
	if p.health.is_downed:
		_stop_revive(ds)
		return f
	_fire_cd -= dt
	_retarget -= dt
	if _retarget <= 0.0:
		_retarget = RETARGET_INTERVAL
		_target = _pick_target(p)
	var closest: ZombieActor = _closest_zombie(p)
	var close_d: float = closest.global_position.distance_to(p.global_position) if closest != null else INF
	# Revive a downed teammate when it is safe enough.
	var mate: PlayerCharacter = _downed_mate(p, ds)
	var wish: Vector3 = Vector3.ZERO
	if mate != null and close_d > 2.0:
		var to_mate: Vector3 = mate.global_position - p.global_position
		to_mate.y = 0.0
		if to_mate.length() <= p.tuning.revive_radius * 0.8:
			if _reviving != mate.peer_id:
				_stop_revive(ds)
				ds.host_set_reviving(p.peer_id, mate.peer_id, true)
				_reviving = mate.peer_id
			_face(p, to_mate)
			return f
		wish = to_mate.normalized()
	else:
		_stop_revive(ds)
	if _target != null and is_instance_valid(_target) and _target.alive:
		var to_t: Vector3 = _target.global_position - p.global_position
		_face(p, to_t)
		if _fire_cd <= 0.0:
			_shoot(p, _target)
	if wish == Vector3.ZERO:
		if close_d < DANGER_RADIUS:
			wish = p.global_position - closest.global_position
			wish.y = 0.0
			wish = wish.normalized()
		else:
			wish = _route_dir(p, dt)
	_interact(p, close_d, dt)
	var local: Vector3 = Basis(Vector3.UP, p.get_yaw()).inverse() * wish
	f.move = Vector2(local.x, local.z).limit_length(1.0)
	return f


func _stop_revive(ds: DownedSystem) -> void:
	if _reviving != 0 and ds != null:
		ds.host_set_reviving(player.peer_id, _reviving, false)
	_reviving = 0


func _face(p: PlayerCharacter, dir: Vector3) -> void:
	if Vector2(dir.x, dir.z).length() < 0.01:
		return
	p.set_view(atan2(-dir.x, -dir.z), 0.0)


func _route_dir(p: PlayerCharacter, dt: float) -> Vector3:
	if route.is_empty():
		return Vector3.ZERO
	for i: int in route.size():
		var wp: Marker3D = route[index]
		if _door_open(StringName(wp.get_meta(&"requires_door", &""))):
			break
		index = (index + 1) % route.size()
	var to: Vector3 = route[index].global_position - p.global_position
	to.y = 0.0
	var d: float = to.length()
	if d < _best_dist - 0.05:
		_best_dist = d
		_since_progress = 0.0
	else:
		_since_progress += dt
	if d < 0.9 or _since_progress > 4.0:
		index = (index + 1) % route.size()
		_best_dist = INF
		_since_progress = 0.0
	return to / d if d > 0.01 else Vector3.ZERO


func _door_open(door_id: StringName) -> bool:
	if door_id == &"":
		return true
	for it: Interactable in match_node.interaction.interactables:
		if it is PurchasableDoor and (it as PurchasableDoor).door_id == door_id:
			return (it as PurchasableDoor).is_open()
	return true


func _interact(p: PlayerCharacter, close_d: float, dt: float) -> void:
	var ia: InteractionSystem = match_node.interaction
	var it: Interactable = ia.best_for(p, true)
	var want: bool = it != null and close_d > 4.0 and _wants(p, it)
	ia.tick_player(p, want, dt, it if want else null)


func _wants(p: PlayerCharacter, it: Interactable) -> bool:
	var pts: int = match_node.points.get_points(p.peer_id)
	if it is BarricadeRepair:
		return true
	if it is PurchasableDoor:
		return pts >= it.get_cost(p)
	if it is WallBuy:
		var wb: WallBuy = it as WallBuy
		var lo: Dictionary = match_node.weapons.loadouts.get(p.peer_id, {})
		return not wb.owns(p) and (lo.get("ids", []) as Array).size() < 2 and pts >= wb.get_cost(p) + 250
	return false


func _held_def(p: PlayerCharacter) -> WeaponDefinition:
	var lo: Dictionary = match_node.weapons.loadouts.get(p.peer_id, {})
	var d: WeaponDefinition = WeaponCatalog.get_def(StringName(lo.get("current", &"m1911")))
	return d if d != null else WeaponCatalog.get_def(&"m1911")


func _shoot(p: PlayerCharacter, z: ZombieActor) -> void:
	var def: WeaponDefinition = _held_def(p)
	_fire_cd = maxf(60.0 / maxf(def.rpm, 1.0), 0.2) * _rng.randf_range(1.0, 1.6)
	var dist: float = z.global_position.distance_to(p.global_position)
	shots += 1
	var acc: float = accuracy * clampf(1.0 - dist / 40.0, 0.35, 1.0)
	if _rng.randf() > acc:
		return
	hits += 1
	var zone: int = WeaponDefinition.Hitzone.HEAD if _rng.randf() < head_share else WeaponDefinition.Hitzone.TORSO
	var amount: float = DamageModel.bullet_damage(def, dist, zone, 0)
	if def.pellets > 1:
		amount *= maxf(def.pellets * clampf(1.0 - dist / 20.0, 0.1, 0.7), 1.0)
	var info: DamageInfo = DamageInfo.make(amount * damage_scale, zone, DamageInfo.Kind.BULLET, def.id, p.peer_id)
	info.distance = dist
	match_node.targets.host_damage(z, info)


func _pick_target(p: PlayerCharacter) -> ZombieActor:
	var best: ZombieActor = null
	var best_d: float = VIEW_RANGE
	var space: PhysicsDirectSpaceState3D = p.get_world_3d().direct_space_state
	var eye: Vector3 = p.global_position + Vector3.UP * 1.6
	for a: ZombieActor in match_node.zombies.actors.values():
		if not a.alive:
			continue
		var d: float = a.global_position.distance_to(p.global_position)
		if d >= best_d:
			continue
		var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			eye, a.global_position + Vector3.UP * 1.2, 1
		)
		if space.intersect_ray(q).is_empty():
			best = a
			best_d = d
	return best


func _closest_zombie(p: PlayerCharacter) -> ZombieActor:
	var best: ZombieActor = null
	var best_d: float = INF
	for a: ZombieActor in match_node.zombies.actors.values():
		if a.alive:
			var d: float = a.global_position.distance_squared_to(p.global_position)
			if d < best_d:
				best_d = d
				best = a
	return best


func _downed_mate(p: PlayerCharacter, ds: DownedSystem) -> PlayerCharacter:
	if ds == null:
		return null
	var best: PlayerCharacter = null
	var best_d: float = 25.0
	for id: int in match_node.players.avatars:
		if id != p.peer_id and ds.state_of(id) == DownedSystem.State.DOWNED:
			var o: PlayerCharacter = match_node.players.avatars[id]
			var d: float = o.global_position.distance_to(p.global_position)
			if d < best_d:
				best_d = d
				best = o
	return best
