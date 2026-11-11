# Grenade — thrown frag (GAME_DESIGN §4.3: cookable, 3.5 s fuse, bounce physics, splash damage).
# Every peer simulates its own copy from the same throw (origin, velocity, remaining fuse); only
# the HOST's copy is authoritative and explodes (WeaponSync applies splash damage and broadcasts
# `_wexplode`). Cosmetic copies stop at the end of the fuse and wait for the host's explosion.
# Authority: host decides the explosion; physics is simulated locally everywhere.
class_name Grenade
extends RigidBody3D

signal exploded(grenade: Grenade, position: Vector3)

const LAYER: int = 1 << 5  # 3d_physics/layer_6 "projectile"
const COSMETIC_GRACE: float = 1.5

var key: String = ""
var peer_id: int = 0
var def: WeaponDefinition = null
var fuse_left: float = 3.5
var authoritative: bool = false

var _done: bool = false
var _bounce_cooldown: float = 0.0


static func create(p_def: WeaponDefinition, p_key: String, p_peer: int, fuse: float, auth: bool) -> Grenade:
	var g: Grenade = Grenade.new()
	g.def = p_def
	g.key = p_key
	g.peer_id = p_peer
	g.fuse_left = fuse
	g.authoritative = auth
	g.name = "Grenade_%s" % p_key.replace(":", "_")
	return g


func _ready() -> void:
	collision_layer = LAYER
	collision_mask = 1
	mass = 0.4
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = 2
	var pm: PhysicsMaterial = PhysicsMaterial.new()
	pm.bounce = 0.4
	pm.friction = 0.7
	physics_material_override = pm
	angular_damp = 2.0
	linear_damp = 0.2
	var cs: CollisionShape3D = CollisionShape3D.new()
	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = 0.05
	cs.shape = sphere
	add_child(cs)
	var mi: MeshInstance3D = MeshInstance3D.new()
	var sm: SphereMesh = SphereMesh.new()
	sm.radius = 0.05
	sm.height = 0.1
	mi.mesh = sm
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.25, 0.3, 0.2)
	mi.material_override = mat
	add_child(mi)
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	_bounce_cooldown = maxf(_bounce_cooldown - delta, 0.0)
	fuse_left -= delta
	if _done:
		if fuse_left < -COSMETIC_GRACE:
			queue_free()
		return
	if fuse_left <= 0.0:
		_done = true
		if authoritative:
			exploded.emit(self, global_position)
			queue_free()
		else:
			freeze = true


func _on_body_entered(_body: Node) -> void:
	if _bounce_cooldown <= 0.0 and linear_velocity.length() > 1.5:
		_bounce_cooldown = 0.12
		Audio.play_event_3d(&"frag_bounce", global_position)
