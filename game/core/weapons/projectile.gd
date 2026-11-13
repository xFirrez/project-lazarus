# Projectile — launcher rockets, China Lake grenades and crossbow bolts (GAME_DESIGN §4.3,
# DEVELOPMENT_PLAN Step 9A). Deterministic kinematic flight (no rigid body): every peer integrates
# its own copy from the same (origin, velocity) with a swept ray per physics tick against the world
# (layer 1) and hurtboxes (layer 3). Kinds (WeaponDefinition.projectile_kind):
#   rocket  — explodes on the first contact (zombie or world); `damage` to the zombie struck.
#   grenade — bounces off the world (restitution `projectile_bounce`), explodes on a zombie
#             (direct `damage`) or when `fuse_time` runs out.
#   bolt    — sticks to the first zombie (direct `damage` at impact, follows the hurtbox) or wall,
#             explodes `fuse_time` later.
#   plasma  — Ray Pistol bolt (Step 12): glowing, no gravity; explodes on a zombie, bounces off the
#             world `projectile_bounces` times (Nova Mk.II: once) and explodes at the next contact.
# Only the HOST's copy is authoritative: it emits `struck` (direct hit) and `detonated` (splash) and
# WeaponSync applies the damage and broadcasts `_wpexplode`. Cosmetic copies stop at their own
# detonation point and wait (COSMETIC_GRACE) for the host's explosion message.
# Authority: host decides hits and explosions; physics is simulated locally everywhere.
class_name Projectile
extends Node3D

signal struck(projectile: Projectile, target: HitTarget, zone: int, position: Vector3)
signal detonated(projectile: Projectile, position: Vector3)
signal stuck_to(projectile: Projectile)  # a bolt stuck (Lure of the Lantern attracts zombies)

const LIFETIME: float = 8.0
const COSMETIC_GRACE: float = 1.5
const REST_SPEED: float = 1.2
const PLASMA_LIGHT_CAP: int = 6  # plasma bolts with their own light at once (AC-12.6 light cap)

static var plasma_lights: int = 0

var key: String = ""
var peer_id: int = 0
var def: WeaponDefinition = null
var authoritative: bool = false
var velocity: Vector3 = Vector3.ZERO
var fuse_left: float = 0.0
var age: float = 0.0
var traveled: float = 0.0
var bounces: int = 0
var stuck: bool = false
var stuck_target: HitTarget = null
var exclude: Array[RID] = []

var _done: bool = false
var _resting: bool = false
var _stuck_node: Node3D = null
var _stuck_local: Transform3D = Transform3D.IDENTITY
var _light: OmniLight3D = null


static func create(p_def: WeaponDefinition, p_key: String, p_peer: int, vel: Vector3, auth: bool) -> Projectile:
	var p: Projectile = Projectile.new()
	p.def = p_def
	p.key = p_key
	p.peer_id = p_peer
	p.velocity = vel
	p.authoritative = auth
	p.fuse_left = p_def.fuse_time
	p.name = "Projectile_%s" % p_key.replace(":", "_")
	return p


func _ready() -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	match def.projectile_kind:
		&"bolt":
			var bm: BoxMesh = BoxMesh.new()
			bm.size = Vector3(0.015, 0.015, 0.4)
			mi.mesh = bm
			mat.albedo_color = Color(0.75, 0.2, 0.12)
			mat.emission_enabled = true
			mat.emission = Color(0.9, 0.25, 0.1)
		&"plasma":
			_build_plasma(mi, mat)
		&"grenade":
			var sm: SphereMesh = SphereMesh.new()
			sm.radius = def.projectile_radius
			sm.height = def.projectile_radius * 2.0
			mi.mesh = sm
			mat.albedo_color = Color(0.35, 0.38, 0.25)
		_:
			var cm: CylinderMesh = CylinderMesh.new()
			cm.top_radius = def.projectile_radius * 0.6
			cm.bottom_radius = def.projectile_radius
			cm.height = 0.5
			mi.mesh = cm
			mi.rotation.x = -PI * 0.5
			mat.albedo_color = Color(0.3, 0.33, 0.2)
			mat.emission_enabled = true
			mat.emission = Color(1.0, 0.55, 0.2)  # motor glow
	mi.material_override = mat
	add_child(mi)
	_face_velocity()


func _build_plasma(mi: MeshInstance3D, mat: StandardMaterial3D) -> void:
	var sm: SphereMesh = SphereMesh.new()
	sm.radius = maxf(def.projectile_radius, 0.06)
	sm.height = sm.radius * 2.0
	mi.mesh = sm
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = def.projectile_color
	mat.emission_enabled = true
	mat.emission = def.projectile_color
	var trail: MeshInstance3D = MeshInstance3D.new()
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = sm.radius * 0.7
	cm.bottom_radius = 0.0
	cm.height = 0.7
	trail.mesh = cm
	trail.rotation.x = -PI * 0.5
	trail.position = Vector3(0, 0, 0.38)  # behind: the node looks along -Z
	var tm: StandardMaterial3D = WeaponFx._unshaded(Color(def.projectile_color, 0.45), true)
	trail.material_override = tm
	add_child(trail)
	if plasma_lights < PLASMA_LIGHT_CAP:
		plasma_lights += 1
		_light = OmniLight3D.new()
		_light.light_color = def.projectile_color
		_light.light_energy = 2.5
		_light.omni_range = 4.0
		add_child(_light)


func _exit_tree() -> void:
	if _light != null:
		plasma_lights = maxi(plasma_lights - 1, 0)
		_light = null


func is_done() -> bool:
	return _done


func _physics_process(delta: float) -> void:
	age += delta
	if _done:
		if age > COSMETIC_GRACE:
			queue_free()
		return
	if stuck:
		_follow_stuck()
		_tick_fuse(delta)
		return
	if def.projectile_kind == &"grenade":
		_tick_fuse(delta)
		if _done:
			return
	if age >= LIFETIME:
		_detonate()
		return
	if _resting:
		return
	velocity += Vector3.DOWN * def.projectile_gravity * delta
	step(delta)


# One swept integration step (tests call it directly).
func step(delta: float) -> void:
	var from: Vector3 = global_position
	var to: Vector3 = from + velocity * delta
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		from, to, Ballistics.WORLD_MASK | Hurtbox.LAYER
	)
	q.collide_with_areas = true
	q.exclude = exclude
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		traveled += from.distance_to(to)
		global_position = to
		_face_velocity()
		return
	var pos: Vector3 = hit["position"]
	var normal: Vector3 = hit["normal"]
	traveled += from.distance_to(pos)
	var hb: Hurtbox = hit["collider"] as Hurtbox
	if hb != null:
		if hb.target == null or not hb.target.alive:
			exclude.append(hit["rid"] as RID)  # corpse: fly through
			global_position = pos
			return
		global_position = pos
		_on_target_hit(hb, pos)
		return
	_on_world_hit(hit["collider"] as Node3D, pos, normal)


func _on_target_hit(hb: Hurtbox, pos: Vector3) -> void:
	if authoritative:
		struck.emit(self, hb.target, hb.zone, pos)
	match def.projectile_kind:
		&"bolt":
			_stick(hb, hb.target)
		_:
			_detonate()


func _on_world_hit(collider: Node3D, pos: Vector3, normal: Vector3) -> void:
	match def.projectile_kind:
		&"grenade":
			bounces += 1
			velocity = velocity.bounce(normal) * def.projectile_bounce
			global_position = pos + normal * (def.projectile_radius + 0.005)
			if bounces > 0 and velocity.length() < REST_SPEED and normal.y > 0.6:
				_resting = true
				velocity = Vector3.ZERO
			Audio.play_event_3d(&"frag_bounce", pos)
		&"bolt":
			global_position = pos - velocity.normalized() * 0.15
			_stick(collider, null)
		&"plasma":
			if bounces < def.projectile_bounces:
				bounces += 1
				velocity = velocity.bounce(normal)
				global_position = pos + normal * (def.projectile_radius + 0.02)
				Audio.play_event_3d(&"ray_bounce", pos)
				return
			global_position = pos + normal * 0.05
			_detonate()
		_:
			global_position = pos + normal * 0.05
			_detonate()


func _stick(node: Node3D, target: HitTarget) -> void:
	stuck = true
	stuck_target = target
	_stuck_node = node
	if node != null:
		_stuck_local = node.global_transform.affine_inverse() * global_transform
	velocity = Vector3.ZERO
	Audio.play_event_3d(&"bolt_stick", global_position)
	stuck_to.emit(self)


func _follow_stuck() -> void:
	if _stuck_node != null and is_instance_valid(_stuck_node) and _stuck_node.is_inside_tree():
		global_transform = _stuck_node.global_transform * _stuck_local
	else:
		_stuck_node = null


func _tick_fuse(delta: float) -> void:
	fuse_left -= delta
	if fuse_left <= 0.0:
		_detonate()


func _detonate() -> void:
	if _done:
		return
	_done = true
	age = 0.0
	visible = authoritative
	if authoritative:
		detonated.emit(self, global_position)
		queue_free()


func _face_velocity() -> void:
	if velocity.length_squared() > 0.01:
		var dir: Vector3 = velocity.normalized()
		var up: Vector3 = Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.98 else Vector3.RIGHT
		look_at(global_position + dir, up)
