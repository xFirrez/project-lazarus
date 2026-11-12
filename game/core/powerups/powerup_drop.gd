# PowerUpDrop — one power-up on the ground (GAME_DESIGN §11 presentation): an ORIGINAL gold icon
# per type (ammo crate, scythe, ×2 coin, round bomb, claw hammer, price tag, anvil) with a green
# glow shell, rotating and bobbing 0.3 m above a ground light, sparkle particles, blinking during
# the last `blink_time` seconds of its life. The host's PowerUpSystem decides pickup / expiry.
# Authority: local presentation of replicated state (spawned_at is host time).
class_name PowerUpDrop
extends Node3D

const GOLD: Color = Color(1.0, 0.78, 0.25)
const GLOW: Color = Color(0.35, 1.0, 0.45)

var drop_id: int = 0
var type: StringName = &"max_ammo"
var spawned_at: float = 0.0
var rules: PowerUpRules = null

var _icon: Node3D = null
var _light: OmniLight3D = null
var _gold: StandardMaterial3D = null


func _ready() -> void:
	name = "PowerUp_%d" % drop_id
	add_to_group(&"powerup_drop")
	_gold = StandardMaterial3D.new()
	_gold.albedo_color = GOLD
	_gold.metallic = 0.9
	_gold.roughness = 0.25
	_gold.emission_enabled = true
	_gold.emission = GOLD * 0.6
	_icon = Node3D.new()
	_icon.position = Vector3(0, 1.0, 0)
	add_child(_icon)
	_build_icon()
	var shell: MeshInstance3D = MeshInstance3D.new()
	var sm: SphereMesh = SphereMesh.new()
	sm.radius = 0.42
	sm.height = 0.84
	shell.mesh = sm
	var glow: StandardMaterial3D = StandardMaterial3D.new()
	glow.albedo_color = Color(GLOW.r, GLOW.g, GLOW.b, 0.16)
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.cull_mode = BaseMaterial3D.CULL_DISABLED
	shell.material_override = glow
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_icon.add_child(shell)
	_light = OmniLight3D.new()
	_light.light_color = GLOW
	_light.light_energy = 1.6
	_light.omni_range = 3.0
	_light.position = Vector3(0, 0.3, 0)
	add_child(_light)
	var ring: MeshInstance3D = MeshInstance3D.new()  # ground glow disc
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = 0.6
	cm.bottom_radius = 0.6
	cm.height = 0.01
	ring.mesh = cm
	ring.position = Vector3(0, 0.02, 0)
	ring.material_override = glow
	add_child(ring)
	var sparks: CPUParticles3D = CPUParticles3D.new()
	sparks.amount = 16
	sparks.lifetime = 1.2
	sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	sparks.emission_sphere_radius = 0.45
	sparks.gravity = Vector3(0, 0.6, 0)
	sparks.initial_velocity_min = 0.05
	sparks.initial_velocity_max = 0.2
	sparks.scale_amount_min = 0.02
	sparks.scale_amount_max = 0.04
	var qm: QuadMesh = QuadMesh.new()
	qm.size = Vector2(1, 1)
	var pm: StandardMaterial3D = StandardMaterial3D.new()
	pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	pm.albedo_color = Color(1.0, 0.95, 0.6)
	qm.material = pm
	sparks.mesh = qm
	sparks.position = Vector3(0, 1.0, 0)
	sparks.add_to_group(&"density_scaled")
	add_child(sparks)


func age() -> float:
	return Net.host_time() - spawned_at


func _process(_delta: float) -> void:
	var t: float = age()
	_icon.rotation.y = t * 2.0
	var bob: float = rules.bob_height if rules != null else 0.3
	_icon.position.y = 0.85 + (sin(t * 2.6) * 0.5 + 0.5) * bob
	var life: float = rules.lifetime if rules != null else 26.0
	var blink: float = rules.blink_time if rules != null else 6.0
	var left: float = life - t
	if left < blink:
		var hz: float = 3.0 if left > blink * 0.5 else 6.0  # blinks faster near the end
		_icon.visible = fmod(left * hz, 1.0) > 0.35
	else:
		_icon.visible = true
	_light.light_energy = 1.6 if _icon.visible else 0.4


func _build_icon() -> void:
	match type:
		&"max_ammo":  # ammo crate with three cartridges
			_box(Vector3(0, -0.08, 0), Vector3(0.42, 0.22, 0.26))
			for i: int in 3:
				_cyl(Vector3(-0.12 + i * 0.12, 0.13, 0), 0.035, 0.24, 0.0)
		&"insta_kill":  # scythe: long snath + curved blade
			_box(Vector3(0, -0.05, 0), Vector3(0.04, 0.62, 0.04))
			for k: int in 4:
				var seg: MeshInstance3D = _box(
					Vector3(0.06 + k * 0.07, 0.26 - k * k * 0.015, 0), Vector3(0.1, 0.035, 0.02)
				)
				seg.rotation.z = -0.15 * k
		&"double_points":  # coin with ×2
			var coin: MeshInstance3D = _cyl(Vector3.ZERO, 0.24, 0.05, PI * 0.5)
			coin.rotation.x = PI * 0.5
			for side: float in [1.0, -1.0]:
				var l: Label3D = Label3D.new()
				l.text = "x2"
				l.font_size = 64
				l.pixel_size = 0.004
				l.modulate = Color(0.25, 0.12, 0.0)
				l.position = Vector3(0, 0, 0.03 * side)
				l.rotation.y = 0.0 if side > 0 else PI
				l.double_sided = false
				_icon.add_child(l)
		&"nuke":  # round bomb with a fuse
			var s: MeshInstance3D = MeshInstance3D.new()
			var sm: SphereMesh = SphereMesh.new()
			sm.radius = 0.2
			sm.height = 0.4
			s.mesh = sm
			s.material_override = _gold
			_icon.add_child(s)
			_cyl(Vector3(0, 0.22, 0), 0.06, 0.08, 0.0)
			var fuse: MeshInstance3D = _box(Vector3(0.05, 0.3, 0), Vector3(0.02, 0.12, 0.02))
			fuse.rotation.z = -0.5
		&"carpenter":  # claw hammer
			_box(Vector3(0, -0.06, 0), Vector3(0.05, 0.5, 0.05))
			_box(Vector3(0.03, 0.22, 0), Vector3(0.3, 0.09, 0.08))
			var claw: MeshInstance3D = _box(Vector3(-0.16, 0.26, 0), Vector3(0.1, 0.04, 0.06))
			claw.rotation.z = 0.5
		&"fire_sale":  # price tag with a hole
			var tag: MeshInstance3D = _box(Vector3(0.03, 0, 0), Vector3(0.36, 0.24, 0.03))
			tag.rotation.z = 0.15
			var tip: MeshInstance3D = _box(Vector3(-0.17, 0.03, 0), Vector3(0.13, 0.13, 0.03))
			tip.rotation.z = PI * 0.25
			var l2: Label3D = Label3D.new()
			l2.text = "SALE"
			l2.font_size = 40
			l2.pixel_size = 0.004
			l2.modulate = Color(0.6, 0.05, 0.0)
			l2.position = Vector3(0.04, 0, 0.02)
			_icon.add_child(l2)
		_:  # free_upgrade: anvil
			_box(Vector3(0, -0.12, 0), Vector3(0.2, 0.1, 0.16))
			_box(Vector3(0, -0.03, 0), Vector3(0.1, 0.1, 0.1))
			_box(Vector3(0.02, 0.06, 0), Vector3(0.42, 0.1, 0.16))
			var horn: MeshInstance3D = _box(Vector3(-0.24, 0.07, 0), Vector3(0.12, 0.06, 0.1))
			horn.rotation.z = -0.3


func _box(pos: Vector3, size: Vector3) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = _gold
	_icon.add_child(mi)
	return mi


func _cyl(pos: Vector3, radius: float, height: float, _roll: float) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	cm.radial_segments = 16
	mi.mesh = cm
	mi.position = pos
	mi.material_override = _gold
	_icon.add_child(mi)
	return mi
