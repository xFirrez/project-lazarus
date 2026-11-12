# ZombieSync — the zombie entity registry and replication (ARCHITECTURE §5.2, §7):
#   host -> all : `_zspawn`   [id, archetype, variant, tier, x, y, z, yaw, max_hp, flags, spawn_kind]
#   host -> all : `_zdie`     [id, gib_mask, dx, dy, dz, zone, kind]   (after `_target_health`)
#   host -> all : `_zdespawn` [id]                        re-queue / cleanup (no corpse)
#   host -> peer: `_zfull`    [[spawn tuple..., health]...] on join (late join)
#   host -> all : STREAM_ZOMBIES (20 Hz, unreliable) ZombieSnapshot packets
# Zombies get host-assigned NetIds (u16) and TargetRegistry ids TARGET_ID_BASE + NetId, so client
# hit claims address them like any HitTarget. Re-queued zombies (stuck / far / unreachable) are
# despawned without counting as kills and respawned at a spawner away from the players
# (`auto_respawn`; on survival maps the SpawnDirector turns it off and re-queues them itself).
# Without a session (integration scenes) this node is the authority.
# Authority: host spawns, simulates (CrowdDirector) and decides deaths; clients present.
class_name ZombieSync
extends Node3D

signal zombie_spawned(actor: ZombieActor)
signal zombie_died(actor: ZombieActor, source_peer: int)
signal zombie_requeued(archetype: ZombieArchetype, tier: int, reason: String, net_id: int)

enum Gib { HEAD = 1, ARM_L = 2, ARM_R = 4, LEG_L = 8, LEG_R = 16 }

const STREAM_ZOMBIES: int = 19
const SNAPSHOT_RATE: float = 20.0
const TARGET_ID_BASE: int = 10000
const SPAWN_MIN_PLAYER_DISTANCE: float = 8.0

var crowd: CrowdDirector = null
var targets: TargetRegistry = null
var players: PlayerSync = null
var actors: Dictionary = {}  # net id -> ZombieActor (alive)
var archetypes: Array[ZombieArchetype] = []
var spawners: Array[ZombieSpawner] = []
var auto_respawn: bool = true
var fx: ZombieFx = null

# Statistics.
var spawned_total: int = 0
var deaths_total: int = 0
var snapshot_bytes_out: int = 0
var snapshot_bytes_in: int = 0
var snapshots_in: int = 0

var _next_id: int = 1
var _snapshot_timer: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


static func instance(node: Node = null) -> ZombieSync:
	if Match.current != null and Match.current.zombies != null:
		return Match.current.zombies
	if node == null or not node.is_inside_tree():
		return null
	return node.get_tree().get_first_node_in_group(&"zombie_sync") as ZombieSync


static func is_authority() -> bool:
	return Net.is_host() or not Net.is_active()


func _ready() -> void:
	name = "Zombies"
	add_to_group(&"zombie_sync")
	process_physics_priority = 60
	_rng.randomize()
	for r: Resource in Content.get_all(&"ZombieArchetype"):
		archetypes.append(r as ZombieArchetype)
	archetypes.sort_custom(func(a: ZombieArchetype, b: ZombieArchetype) -> bool: return a.id < b.id)
	fx = ZombieFx.new()
	add_child(fx)
	if is_authority():
		if crowd == null:
			crowd = CrowdDirector.new()
			add_child(crowd)
		crowd.players = players
		crowd.requeue_requested.connect(_on_requeue)
	Net.register_message(&"_zspawn", _on_msg_spawn)
	Net.register_message(&"_zdie", _on_msg_die)
	Net.register_message(&"_zdespawn", _on_msg_despawn)
	Net.register_message(&"_zfull", _on_msg_full)
	Net.register_stream(STREAM_ZOMBIES, _on_snapshot)
	Net.peer_joined.connect(_on_peer_joined)
	ZombieAudio.ensure_events()


func _exit_tree() -> void:
	for m: StringName in [&"_zspawn", &"_zdie", &"_zdespawn", &"_zfull"]:
		Net.unregister_message(m)
	Net.unregister_stream(STREAM_ZOMBIES)


func scan_spawners(root: Node) -> void:
	for n: Node in root.find_children("*", "ZombieSpawner", true, false):
		spawners.append(n as ZombieSpawner)


func archetype(id: StringName) -> ZombieArchetype:
	for a: ZombieArchetype in archetypes:
		if a.id == id:
			return a
	return archetypes[0] if not archetypes.is_empty() else null


func alive_count() -> int:
	return actors.size()


# --- host API ---------------------------------------------------------------------------------


func host_spawn(
	arch: ZombieArchetype,
	tier: int,
	pos: Vector3,
	yaw: float = 0.0,
	kind: int = ZombieSpawner.Kind.RISER,
	variant: int = -1,
	health_value: float = -1.0
) -> ZombieActor:
	if not is_authority() or arch == null:
		return null
	var id: int = _alloc_id()
	if variant < 0:
		variant = _rng.randi_range(0, maxi(arch.variants.size() - 1, 0))
	var hp: float = health_value if health_value > 0.0 else arch.health_for_round(1)
	var p: Vector3 = crowd.snap(pos, pos) if crowd.is_ready() else pos
	var a: ZombieActor = _create([id, archetypes.find(arch), variant, tier, p.x, p.y, p.z, yaw, hp, 0, kind])
	var sim: ZombieSim = ZombieSim.new(a, crowd, _rng.randi())
	a.sim = sim
	crowd.add(sim)
	spawned_total += 1
	Net.send_reliable(0, &"_zspawn", _spawn_tuple(a))
	return a


# Spawns at a random spawner that is not within SPAWN_MIN_PLAYER_DISTANCE of a player.
func host_spawn_at_spawner(
	arch: ZombieArchetype, tier: int, spawner: ZombieSpawner = null, prefer_near: bool = false
) -> ZombieActor:
	if spawner == null:
		spawner = pick_spawner(prefer_near)
	if spawner == null:
		return null
	var jitter: Vector3 = Vector3(_rng.randf_range(-0.6, 0.6), 0, _rng.randf_range(-0.6, 0.6))
	return host_spawn(arch, tier, spawner.global_position + jitter, spawner.global_rotation.y, spawner.kind)


# Random spawner at least SPAWN_MIN_PLAYER_DISTANCE from every player (in the active zones when
# the map has a zone graph); `prefer_near` picks among
# the 3 closest such spawners (re-queued zombies come back near the action).
func pick_spawner(prefer_near: bool = false) -> ZombieSpawner:
	if spawners.is_empty():
		return null
	var ok: Array = []
	var targets_now: Array[Node3D] = crowd.live_targets() if crowd != null else []
	for s: ZombieSpawner in spawners:
		var nearest: float = INF
		for t: Node3D in targets_now:
			nearest = minf(nearest, s.global_position.distance_to(t.global_position))
		if nearest >= SPAWN_MIN_PLAYER_DISTANCE:
			ok.append([nearest, s])
	if ok.is_empty():
		for s: ZombieSpawner in spawners:
			ok.append([0.0, s])
	# Zoned maps: only spawners of the active zones (on Vesper Peak a map-wide pick lands most
	# zombies hundreds of metres away, where they're re-queued as "far").
	var zm: ZoneManager = Match.current.zones if Match.current != null else null
	if zm != null:
		var active: Array[StringName] = zm.active_zones()
		var in_zone: Array = ok.filter(func(e: Array) -> bool: return active.has((e[1] as ZombieSpawner).zone))
		if not in_zone.is_empty():
			ok = in_zone
	if prefer_near and crowd != null and crowd.is_ready() and not targets_now.is_empty():
		# Rank by path distance (a spawner on the floor above is close in a straight line only).
		for e: Array in ok:
			var best: float = INF
			for t: Node3D in targets_now:
				best = minf(best, crowd.path_length_now((e[1] as ZombieSpawner).global_position, t.global_position))
			e[0] = best
		ok.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
		ok = ok.slice(0, 3)
	return ok[_rng.randi_range(0, ok.size() - 1)][1]


func host_kill(a: ZombieActor, source_peer: int = 0) -> void:
	if not is_authority() or not a.alive:
		return
	var info: DamageInfo = DamageInfo.make(
		a.health + 1.0, WeaponDefinition.Hitzone.TORSO, DamageInfo.Kind.DEBUG, &"", source_peer
	)
	if targets != null:
		targets.host_damage(a, info)
	else:
		a.host_apply(info)


func host_kill_all() -> int:
	var n: int = 0
	for a: ZombieActor in actors.values():
		host_kill(a)
		n += 1
	return n


# Removes a zombie without a death (re-queue, cleanup). Does not count as a kill.
func host_despawn(a: ZombieActor) -> void:
	if not is_authority():
		return
	Net.send_reliable(0, &"_zdespawn", [a.net_id])
	_remove(a, true)


func _on_requeue(sim: ZombieSim, reason: String) -> void:
	var a: ZombieActor = sim.actor
	if not is_instance_valid(a) or not a.alive:
		return
	var arch: ZombieArchetype = a.archetype
	var tier: int = a.tier
	var id: int = a.net_id
	host_despawn(a)
	zombie_requeued.emit(arch, tier, reason, id)
	if auto_respawn:
		host_spawn_at_spawner(arch, tier, null, true)


# --- shared -----------------------------------------------------------------------------------


func _alloc_id() -> int:
	for i: int in 65535:
		var id: int = _next_id
		_next_id = _next_id % 65535 + 1
		if not actors.has(id):
			return id
	return 0


func _create(spawn: Array) -> ZombieActor:
	var id: int = int(spawn[0])
	var ai: int = int(spawn[1])
	var arch: ZombieArchetype = archetypes[ai] if ai >= 0 and ai < archetypes.size() else archetypes[0]
	var a: ZombieActor = ZombieActor.new()
	a.name = "Zombie_%d" % id
	a.net_id = id
	a.setup(arch, int(spawn[2]), int(spawn[3]), float(spawn[8]))
	a.position = Vector3(float(spawn[4]), float(spawn[5]), float(spawn[6]))
	a.rotation.y = float(spawn[7])
	a.flags = int(spawn[9])
	a.spawn_kind = int(spawn[10])
	if not is_authority():
		a.buffer = InterpolationBuffer.new()
	add_child(a)
	actors[id] = a
	if targets != null:
		targets.register(a, TARGET_ID_BASE + id)
	a.died.connect(_on_actor_died.bind(a))
	a.tree_exiting.connect(_on_actor_exiting.bind(a))
	zombie_spawned.emit(a)
	return a


# Safety net: an actor leaving the tree by any path never stays registered or simulated.
func _on_actor_exiting(a: ZombieActor) -> void:
	if actors.get(a.net_id, null) == a:
		_remove(a, false)


func _remove(a: ZombieActor, free_now: bool) -> void:
	actors.erase(a.net_id)
	if targets != null:
		targets.unregister(a)
	if a.sim != null:
		crowd.remove(a.sim)
		a.sim.state = ZombieSim.State.DEAD
	if free_now:
		a.queue_free()


func _on_actor_died(source_peer: int, a: ZombieActor) -> void:
	deaths_total += 1
	if not is_authority():
		return  # clients wait for `_zdie` (gibs + impulse) before presenting the death
	var info: DamageInfo = a.last_hit
	var gib: int = 0
	var zone: int = WeaponDefinition.Hitzone.TORSO
	var kind: int = DamageInfo.Kind.DEBUG
	var dir: Vector3 = Vector3(sin(a.rotation.y), 0, cos(a.rotation.y)) * -1.0
	if info != null:
		zone = info.zone
		kind = info.kind
		gib = _roll_gibs(a, info)
		var src: Vector3 = _source_position(info)
		if src != Vector3.INF:
			dir = (a.global_position - src)
			dir.y = 0.0
			dir = dir.normalized() if dir.length() > 0.01 else dir
	Net.send_reliable(0, &"_zdie", [a.net_id, gib, dir.x, dir.y, dir.z, zone, kind])
	_remove(a, false)
	a.visual.die(gib, dir, zone, kind)
	zombie_died.emit(a, source_peer)


func _roll_gibs(a: ZombieActor, info: DamageInfo) -> int:
	var arch: ZombieArchetype = a.archetype
	var gib: int = 0
	if info.zone == WeaponDefinition.Hitzone.HEAD and info.kind != DamageInfo.Kind.DEBUG:
		if _rng.randf() < arch.head_gib_chance:
			gib |= Gib.HEAD
	if info.kind == DamageInfo.Kind.EXPLOSIVE or info.amount >= a.max_health * 2.0:
		for g: int in [Gib.ARM_L, Gib.ARM_R, Gib.LEG_L, Gib.LEG_R]:
			if _rng.randf() < arch.limb_gib_chance:
				gib |= g
	return gib


func _source_position(info: DamageInfo) -> Vector3:
	if info.position != Vector3.ZERO and info.kind == DamageInfo.Kind.EXPLOSIVE:
		return info.position
	if players != null and players.avatars.has(info.source_peer):
		return (players.avatars[info.source_peer] as PlayerCharacter).global_position
	return Vector3.INF


func _spawn_tuple(a: ZombieActor) -> Array:
	var p: Vector3 = a.global_position
	return [
		a.net_id,
		archetypes.find(a.archetype),
		a.variant,
		a.tier,
		p.x,
		p.y,
		p.z,
		a.rotation.y,
		a.max_health,
		a.flags,
		a.spawn_kind
	]


# --- snapshots --------------------------------------------------------------------------------


func _physics_process(delta: float) -> void:
	if is_authority():
		_snapshot_timer -= delta
		if _snapshot_timer <= 0.0:
			_snapshot_timer += 1.0 / SNAPSHOT_RATE
			_send_snapshots()
	else:
		var now: float = Net.now()
		for a: ZombieActor in actors.values():
			a.client_tick(now, delta)


func _send_snapshots() -> void:
	if actors.is_empty() or not Net.is_active():
		return
	var stamp: float = Net.host_time()
	var batch: Array[ZombieSnapshot.Entry] = []
	for a: ZombieActor in actors.values():
		var e: ZombieSnapshot.Entry = ZombieSnapshot.Entry.new()
		e.id = a.net_id
		e.position = a.global_position
		e.yaw = a.rotation.y
		e.tier = a.tier
		e.action = a.action
		e.action_time = a.action_time
		e.health_bucket = a.health_bucket()
		e.flags = a.flags
		batch.append(e)
		if batch.size() >= ZombieSnapshot.MAX_PER_PACKET:
			_send_batch(stamp, batch)
			batch = []
	if not batch.is_empty():
		_send_batch(stamp, batch)


func _send_batch(stamp: float, batch: Array[ZombieSnapshot.Entry]) -> void:
	var bytes: PackedByteArray = ZombieSnapshot.encode(stamp, batch)
	snapshot_bytes_out += bytes.size() + 1
	Net.send_unreliable(0, STREAM_ZOMBIES, bytes)


func _on_snapshot(sender: int, bytes: PackedByteArray) -> void:
	if sender != 1 or is_authority():
		return
	snapshot_bytes_in += bytes.size() + 1
	snapshots_in += 1
	var decoded: Array = ZombieSnapshot.decode(bytes)
	var stamp: float = decoded[0]
	var now: float = Net.now()
	for e: ZombieSnapshot.Entry in decoded[1]:
		var a: ZombieActor = actors.get(e.id, null)
		if a == null or not a.alive:
			continue
		a.buffer.push(stamp, e.position, e.yaw, now)
		a.tier = e.tier
		a.flags = e.flags
		if e.action != a.action or absf(e.action_time - a.action_time) > 0.02:
			a.action = e.action
			a.action_time = e.action_time


# --- messages ---------------------------------------------------------------------------------


func _on_msg_spawn(sender: int, p: Array) -> void:
	if sender != 1 or is_authority():
		return
	_client_create(p, -1.0)


func _client_create(p: Array, health_value: float) -> void:
	if actors.has(int(p[0])):
		return
	var a: ZombieActor = _create(p)
	a.buffer.push(Net.host_time() - 0.2, a.position, a.rotation.y, Net.now() - 0.2)
	if health_value > 0.0:
		a.health = health_value
	spawned_total += 1


func _on_msg_die(sender: int, p: Array) -> void:
	if sender != 1 or is_authority():
		return
	var a: ZombieActor = actors.get(int(p[0]), null)
	if a == null:
		return
	if a.alive:
		a.apply_remote(0.0, 0.0, int(p[5]), int(p[6]), 0, false)
	_remove(a, false)
	a.visual.die(int(p[1]), Vector3(float(p[2]), float(p[3]), float(p[4])), int(p[5]), int(p[6]))


func _on_msg_despawn(sender: int, p: Array) -> void:
	if sender != 1 or is_authority():
		return
	var a: ZombieActor = actors.get(int(p[0]), null)
	if a != null:
		_remove(a, true)


func _on_msg_full(sender: int, p: Array) -> void:
	if sender != 1 or is_authority():
		return
	for entry: Variant in p[0]:
		var e: Array = entry
		_client_create(e, float(e[11]))


func _on_peer_joined(peer_id: int, _info: Dictionary) -> void:
	if not is_authority() or peer_id == Net.local_id():
		return
	var list: Array = []
	for a: ZombieActor in actors.values():
		var t: Array = _spawn_tuple(a)
		t.append(a.health)
		list.append(t)
	Net.send_reliable(peer_id, &"_zfull", [list])
