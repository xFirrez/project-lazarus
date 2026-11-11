# ZombieFx — pooled death presentation shared by all zombies of a match: the ragdoll budget
# (max RAGDOLL_LIMIT simulating at once; the oldest is frozen — bodies stopped and put to sleep —
# when a new one needs a slot, then corpses fade) and a ring of gib chunks (rigid bodies, capped).
# Authority: local presentation on every peer (each peer decides ragdoll vs. animation itself).
class_name ZombieFx
extends Node3D

const RAGDOLL_LIMIT: int = 6
const GIB_POOL: int = 16
const GIB_LIFETIME: float = 4.0

var ragdolls: Array[ZombieVisual] = []  # simulating, oldest first
var ragdolls_started: int = 0
var ragdolls_frozen: int = 0
var gibs_spawned: int = 0
var peak_ragdolls: int = 0

var _gibs: Array[RigidBody3D] = []
var _gib_age: Dictionary = {}
var _next_gib: int = 0
var _flesh: StandardMaterial3D = null


func _ready() -> void:
	name = "ZombieFx"
	_flesh = StandardMaterial3D.new()
	_flesh.albedo_color = Color(0.42, 0.12, 0.1)
	_flesh.roughness = 0.6
	for i: int in GIB_POOL:
		var b: RigidBody3D = RigidBody3D.new()
		b.name = "Gib%d" % i
		b.collision_layer = 0
		b.collision_mask = 1
		b.mass = 0.8
		b.freeze = true
		b.visible = false
		var cs: CollisionShape3D = CollisionShape3D.new()
		var sph: SphereShape3D = SphereShape3D.new()
		sph.radius = 0.08
		cs.shape = sph
		b.add_child(cs)
		var mi: MeshInstance3D = MeshInstance3D.new()
		var sm: SphereMesh = SphereMesh.new()
		sm.radius = 0.09
		sm.height = 0.14
		sm.radial_segments = 8
		sm.rings = 4
		mi.mesh = sm
		mi.material_override = _flesh
		b.add_child(mi)
		b.top_level = true
		add_child(b)
		_gibs.append(b)


# Returns true if `v` may ragdoll now (freezing the oldest simulating ragdoll if needed).
func acquire_ragdoll(v: ZombieVisual) -> bool:
	if ragdolls.size() >= RAGDOLL_LIMIT:
		var oldest: ZombieVisual = ragdolls.pop_front()
		if is_instance_valid(oldest):
			oldest.freeze_ragdoll()
			ragdolls_frozen += 1
	ragdolls.append(v)
	ragdolls_started += 1
	peak_ragdolls = maxi(peak_ragdolls, ragdolls.size())
	return true


func release_ragdoll(v: ZombieVisual) -> void:
	ragdolls.erase(v)


func spawn_gibs(at: Vector3, dir: Vector3, count: int) -> void:
	Audio.play_event_3d(&"zombie_gib", at)
	for i: int in count:
		var b: RigidBody3D = _gibs[_next_gib]
		_next_gib = (_next_gib + 1) % _gibs.size()
		b.freeze = true
		b.global_position = at + Vector3(randf_range(-0.1, 0.1), randf_range(-0.05, 0.1), randf_range(-0.1, 0.1))
		b.visible = true
		b.freeze = false
		b.linear_velocity = (
			dir * randf_range(1.5, 3.5) + Vector3(randf_range(-1, 1), randf_range(1.5, 3.5), randf_range(-1, 1))
		)
		b.angular_velocity = Vector3(randf_range(-8, 8), randf_range(-8, 8), randf_range(-8, 8))
		_gib_age[b] = GIB_LIFETIME
		gibs_spawned += 1


func _process(delta: float) -> void:
	for b: RigidBody3D in _gib_age.keys():
		var t: float = float(_gib_age[b]) - delta
		if t <= 0.0:
			_gib_age.erase(b)
			b.freeze = true
			b.visible = false
		else:
			_gib_age[b] = t
