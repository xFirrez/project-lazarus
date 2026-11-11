# WeaponFx — pooled shot feedback (Step 3 scope 6): muzzle flashes (mesh + light, ~2 frames),
# shell casings (rigid bodies with a lifetime cap), moving tracers, per-surface impact particles
# (ImpactLibrary), bullet-hole decals (ring of 128, oldest reused) and grenade explosions.
# Every pool is an FxRing with a fixed cap, so sustained fire keeps node counts and memory flat.
# One instance per match (Match.fx); `WeaponFx.of(node)` finds or creates it (tests).
# Authority: local presentation on every peer.
class_name WeaponFx
extends Node3D

const DECAL_CAP: int = 128
const IMPACT_CAP: int = 32
const SHELL_CAP: int = 40
const TRACER_CAP: int = 32
const FLASH_CAP: int = 12
const EXPLOSION_CAP: int = 4
const SHELL_LIFETIME: float = 1.6
const FLASH_TIME: float = 0.035
const TRACER_SPEED: float = 350.0
const TRACER_LENGTH: float = 4.0
const VIEWMODEL_LAYER: int = 1 << 1  # 3d_render/layer_2 "viewmodel"

var decals: FxRing = null
var impacts: FxRing = null
var shells: FxRing = null
var tracers: FxRing = null
var flashes: FxRing = null
var explosions: FxRing = null
var shots_shown: int = 0

var _decal_texture: ImageTexture = null
var _timed: Dictionary = {}  # Node -> seconds left (hidden when it reaches 0)
var _tracer_state: Dictionary = {}  # MeshInstance3D -> [from, to, travelled]
var _flash_material: StandardMaterial3D = null
var _tracer_material: StandardMaterial3D = null
var _particle_material: StandardMaterial3D = null
var _shell_material: StandardMaterial3D = null


static func of(node: Node) -> WeaponFx:
	if Match.current != null and Match.current.fx != null:
		return Match.current.fx
	var tree: SceneTree = node.get_tree()
	var existing: Node = tree.get_first_node_in_group(&"weapon_fx")
	if existing != null:
		return existing as WeaponFx
	var fx: WeaponFx = WeaponFx.new()
	tree.root.add_child(fx)
	return fx


func _ready() -> void:
	name = "WeaponFx"
	add_to_group(&"weapon_fx")
	top_level = true
	_decal_texture = _make_decal_texture()
	_flash_material = _unshaded(Color(1.0, 0.75, 0.35), true)
	_tracer_material = _unshaded(Color(1.0, 0.85, 0.55), true)
	_particle_material = _unshaded(Color.WHITE, false)
	_particle_material.vertex_color_use_as_albedo = true
	_shell_material = StandardMaterial3D.new()
	_shell_material.albedo_color = Color(0.8, 0.62, 0.25)
	_shell_material.metallic = 0.8
	decals = FxRing.new(self, DECAL_CAP, _new_decal)
	impacts = FxRing.new(self, IMPACT_CAP, _new_particles)
	shells = FxRing.new(self, SHELL_CAP, _new_shell)
	tracers = FxRing.new(self, TRACER_CAP, _new_tracer)
	flashes = FxRing.new(self, FLASH_CAP, _new_flash)
	explosions = FxRing.new(self, EXPLOSION_CAP, _new_explosion)


func counts() -> Dictionary:
	return {
		"decals": decals.size(),
		"impacts": impacts.size(),
		"shells": shells.size(),
		"tracers": tracers.size(),
		"flashes": flashes.size(),
		"explosions": explosions.size(),
		"timed": _timed.size(),
	}


# --- effects ----------------------------------------------------------------------------------


func muzzle_flash(xform: Transform3D, scale_factor: float, viewmodel: bool) -> void:
	var f: Node3D = flashes.next() as Node3D
	f.global_transform = xform
	f.scale = Vector3.ONE * scale_factor
	f.rotation.z = randf() * TAU
	var mesh: MeshInstance3D = f.get_child(0) as MeshInstance3D
	mesh.layers = VIEWMODEL_LAYER if viewmodel else 1
	f.visible = true
	_timed[f] = FLASH_TIME


func tracer(from: Vector3, to: Vector3) -> void:
	if from.distance_to(to) < 1.0:
		return
	var t: MeshInstance3D = tracers.next() as MeshInstance3D
	_tracer_state[t] = [from, to, 0.0]
	t.visible = true
	_place_tracer(t)


func impact(imp: Ballistics.Impact, play_sound: bool = true) -> void:
	var p: Array = ImpactLibrary.params(imp.surface)
	var parts: CPUParticles3D = impacts.next() as CPUParticles3D
	parts.global_position = imp.position + imp.normal * 0.02
	parts.direction = imp.normal
	parts.color = p[0]
	parts.initial_velocity_min = float(p[2]) * 0.5
	parts.initial_velocity_max = float(p[2])
	parts.gravity = Vector3(0, -9.8 * float(p[3]), 0)
	parts.scale_amount_min = float(p[4]) * 0.6
	parts.scale_amount_max = float(p[4])
	parts.lifetime = float(p[5])
	parts.visible = true
	parts.restart()
	parts.emitting = true
	_timed[parts] = float(p[5]) + 0.1
	if ImpactLibrary.takes_decal(imp.surface):
		_decal(imp, p[6])
	if play_sound:
		Audio.play_event_3d(WeaponAudio.impact_event(imp.surface), imp.position)


func shell(pos: Vector3, velocity: Vector3, size: float) -> void:
	var body: RigidBody3D = shells.next() as RigidBody3D
	body.freeze = false
	body.visible = true
	body.scale = Vector3.ONE
	(body.get_child(0) as MeshInstance3D).scale = Vector3(size, size * 3.0, size) / 0.01
	body.global_position = pos
	body.linear_velocity = velocity
	body.angular_velocity = Vector3(randf_range(-20, 20), randf_range(-20, 20), randf_range(-20, 20))
	_timed[body] = SHELL_LIFETIME


func explosion(pos: Vector3, radius: float) -> void:
	var e: CPUParticles3D = explosions.next() as CPUParticles3D
	e.global_position = pos
	e.initial_velocity_max = radius * 2.5
	e.initial_velocity_min = radius
	e.visible = true
	e.restart()
	e.emitting = true
	(e.get_child(0) as OmniLight3D).visible = true
	_timed[e] = 1.0
	Audio.play_event_3d(&"frag_explode", pos)


func _decal(imp: Ballistics.Impact, tint: Color) -> void:
	var d: Decal = decals.next() as Decal
	var n: Vector3 = imp.normal.normalized()
	var ref: Vector3 = Vector3.FORWARD if absf(n.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT
	var x: Vector3 = ref.cross(n).normalized()
	var z: Vector3 = x.cross(n).normalized()
	var basis: Basis = Basis(x, n, z).rotated(n, randf() * TAU)
	d.global_transform = Transform3D(basis, imp.position)
	d.modulate = tint
	d.visible = true


# --- per-frame --------------------------------------------------------------------------------


func _process(delta: float) -> void:
	var done: Array[Node] = []
	for n: Node in _timed:
		var left: float = float(_timed[n]) - delta
		_timed[n] = left
		if left <= 0.0:
			done.append(n)
	for n: Node in done:
		_timed.erase(n)
		if n is RigidBody3D:
			(n as RigidBody3D).freeze = true
		elif n is CPUParticles3D:
			(n as CPUParticles3D).emitting = false
			if n.get_child_count() > 0:
				(n.get_child(0) as Node3D).visible = false
		(n as Node3D).visible = false
	for e: Node in explosions.nodes:
		var light: OmniLight3D = e.get_child(0) as OmniLight3D
		if light.visible:
			light.light_energy = maxf(light.light_energy - delta * 40.0, 0.0)
			if light.light_energy <= 0.0:
				light.visible = false
				light.light_energy = 8.0
	var finished: Array[MeshInstance3D] = []
	for t: MeshInstance3D in _tracer_state:
		var st: Array = _tracer_state[t]
		st[2] = float(st[2]) + TRACER_SPEED * delta
		if float(st[2]) - TRACER_LENGTH > (st[0] as Vector3).distance_to(st[1]):
			finished.append(t)
		else:
			_place_tracer(t)
	for t: MeshInstance3D in finished:
		_tracer_state.erase(t)
		t.visible = false


func _place_tracer(t: MeshInstance3D) -> void:
	var st: Array = _tracer_state[t]
	var from: Vector3 = st[0]
	var to: Vector3 = st[1]
	var total: float = from.distance_to(to)
	var head: float = minf(float(st[2]) + 1.0, total)
	var tail: float = clampf(head - TRACER_LENGTH, 0.0, total)
	var dir: Vector3 = (to - from) / maxf(total, 0.001)
	var a: Vector3 = from + dir * tail
	var b: Vector3 = from + dir * head
	var length: float = maxf(a.distance_to(b), 0.01)
	var up: Vector3 = Vector3.UP if absf(dir.y) < 0.99 else Vector3.RIGHT
	var basis: Basis = Basis.looking_at(dir, up) * Basis(Vector3.RIGHT, PI * 0.5)
	t.global_transform = Transform3D(basis.scaled_local(Vector3(1.0, length, 1.0)), (a + b) * 0.5)


# --- factories --------------------------------------------------------------------------------


func _new_decal() -> Node:
	var d: Decal = Decal.new()
	d.size = Vector3(0.07, 0.12, 0.07)
	d.texture_albedo = _decal_texture
	d.cull_mask = 1
	d.upper_fade = 0.2
	d.lower_fade = 0.2
	return d


func _new_particles() -> Node:
	var p: CPUParticles3D = CPUParticles3D.new()
	p.amount = 16
	p.one_shot = true
	p.explosiveness = 1.0
	p.emitting = false
	p.spread = 35.0
	var bm: BoxMesh = BoxMesh.new()
	bm.size = Vector3.ONE
	bm.material = _particle_material
	p.mesh = bm
	p.visible = false
	return p


func _new_shell() -> Node:
	var body: RigidBody3D = RigidBody3D.new()
	body.collision_layer = 0
	body.collision_mask = 1
	body.mass = 0.01
	body.freeze = true
	body.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	body.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var mi: MeshInstance3D = MeshInstance3D.new()
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = 0.005
	cm.bottom_radius = 0.005
	cm.height = 0.01
	cm.radial_segments = 6
	cm.rings = 1
	cm.material = _shell_material
	mi.mesh = cm
	body.add_child(mi)
	var cs: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(0.012, 0.03, 0.012)
	cs.shape = box
	body.add_child(cs)
	body.visible = false
	return body


func _new_tracer() -> Node:
	var t: MeshInstance3D = MeshInstance3D.new()
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = 0.008
	cm.bottom_radius = 0.008
	cm.height = 1.0
	cm.radial_segments = 4
	cm.rings = 1
	cm.material = _tracer_material
	t.mesh = cm
	t.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	t.visible = false
	return t


func _new_flash() -> Node:
	var root: Node3D = Node3D.new()
	var mi: MeshInstance3D = MeshInstance3D.new()
	var sm: SphereMesh = SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 8
	sm.rings = 4
	sm.material = _flash_material
	mi.mesh = sm
	mi.scale = Vector3(0.07, 0.07, 0.2)
	mi.position = Vector3(0, 0, -0.08)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	var light: OmniLight3D = OmniLight3D.new()
	light.light_color = Color(1.0, 0.75, 0.4)
	light.light_energy = 2.5
	light.omni_range = 4.0
	root.add_child(light)
	root.visible = false
	return root


func _new_explosion() -> Node:
	var p: CPUParticles3D = CPUParticles3D.new()
	p.amount = 48
	p.one_shot = true
	p.explosiveness = 1.0
	p.lifetime = 0.8
	p.emitting = false
	p.spread = 180.0
	p.gravity = Vector3(0, -3, 0)
	p.color = Color(1.0, 0.55, 0.15)
	p.scale_amount_min = 0.15
	p.scale_amount_max = 0.4
	var bm: BoxMesh = BoxMesh.new()
	bm.size = Vector3.ONE
	bm.material = _particle_material
	p.mesh = bm
	var light: OmniLight3D = OmniLight3D.new()
	light.light_color = Color(1.0, 0.6, 0.3)
	light.light_energy = 8.0
	light.omni_range = 10.0
	light.visible = false
	p.add_child(light)
	p.visible = false
	return p


static func _unshaded(color: Color, additive: bool) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


static func _make_decal_texture() -> ImageTexture:
	var size: int = 32
	var img: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c: float = (size - 1) * 0.5
	for y: int in size:
		for x: int in size:
			var r: float = Vector2(x - c, y - c).length() / c
			var a: float = clampf(1.0 - smoothstep(0.25, 1.0, r), 0.0, 1.0)
			var core: float = 1.0 - smoothstep(0.0, 0.3, r)
			img.set_pixel(x, y, Color(core * 0.2, core * 0.2, core * 0.2, a))
	return ImageTexture.create_from_image(img)
