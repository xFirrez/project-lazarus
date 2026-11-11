# TargetDummy — greybox humanoid HitTarget for the gun range: head / neck / torso / limb
# hurtboxes, a hit flash, debug-only floating damage numbers (`damage_numbers on`), a tip-over
# death with respawn (host-driven), and an optional back-and-forth track driven by the shared
# host clock so every peer sees it at the same place.
# Authority: host applies damage / respawn (TargetRegistry broadcasts); visuals on every peer.
class_name TargetDummy
extends HitTarget

const BODY_COLOR: Color = Color(0.72, 0.62, 0.45)
const HEAD_COLOR: Color = Color(0.78, 0.66, 0.5)
const FLASH_COLOR: Color = Color(1.0, 0.25, 0.15)
const NUMBER_TIME: float = 0.9

static var show_damage_numbers: bool = false

@export var track_offset: Vector3 = Vector3.ZERO  # moving dummies: travel to base + offset and back
@export var track_period: float = 0.0

var base_position: Vector3 = Vector3.ZERO

var _visual: Node3D = null
var _materials: Array[StandardMaterial3D] = []
var _flash: float = 0.0
var _numbers: Array[Label3D] = []
var _tip: float = 0.0


func _ready() -> void:
	super()
	base_position = position
	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)
	# zone, shape size (box) or radius (sphere), centre
	_part(WeaponDefinition.Hitzone.HEAD, Vector3(0.13, 0, 0), Vector3(0, 1.68, 0), true)
	_part(WeaponDefinition.Hitzone.NECK, Vector3(0.12, 0.1, 0.12), Vector3(0, 1.5, 0))
	_part(WeaponDefinition.Hitzone.TORSO, Vector3(0.44, 0.6, 0.26), Vector3(0, 1.15, 0))
	_part(WeaponDefinition.Hitzone.LIMB, Vector3(0.12, 0.6, 0.14), Vector3(-0.3, 1.13, 0))
	_part(WeaponDefinition.Hitzone.LIMB, Vector3(0.12, 0.6, 0.14), Vector3(0.3, 1.13, 0))
	_part(WeaponDefinition.Hitzone.LIMB, Vector3(0.16, 0.85, 0.18), Vector3(-0.11, 0.425, 0))
	_part(WeaponDefinition.Hitzone.LIMB, Vector3(0.16, 0.85, 0.18), Vector3(0.11, 0.425, 0))
	damaged.connect(_on_hit)


func _part(zone: int, size: Vector3, centre: Vector3, sphere: bool = false) -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var shape: Shape3D = null
	if sphere:
		var sm: SphereMesh = SphereMesh.new()
		sm.radius = size.x
		sm.height = size.x * 2.0
		mi.mesh = sm
		var ss: SphereShape3D = SphereShape3D.new()
		ss.radius = size.x
		shape = ss
	else:
		var bm: BoxMesh = BoxMesh.new()
		bm.size = size
		mi.mesh = bm
		var bs: BoxShape3D = BoxShape3D.new()
		bs.size = size
		shape = bs
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = HEAD_COLOR if zone == WeaponDefinition.Hitzone.HEAD else BODY_COLOR
	mat.set_meta(&"base", mat.albedo_color)
	mi.material_override = mat
	mi.position = centre
	_materials.append(mat)
	_visual.add_child(mi)
	add_hurtbox(zone, shape, centre, _visual)


func _physics_process(delta: float) -> void:
	if track_period > 0.0:
		var t: float = Net.host_time()
		var k: float = 0.5 - 0.5 * cos(TAU * fmod(t, track_period) / track_period)
		position = base_position + track_offset * k
	var target_tip: float = 0.0 if alive else deg_to_rad(80.0)
	_tip = move_toward(_tip, target_tip, delta * 6.0)
	_visual.rotation.x = -_tip


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(_flash - delta * 6.0, 0.0)
		for m: StandardMaterial3D in _materials:
			m.albedo_color = (m.get_meta(&"base") as Color).lerp(FLASH_COLOR, _flash)
	for label: Label3D in _numbers:
		var age: float = float(label.get_meta(&"age")) + delta
		label.set_meta(&"age", age)
		label.position.y += delta * 0.8
		label.modulate.a = 1.0 - age / NUMBER_TIME
	while not _numbers.is_empty() and float(_numbers[0].get_meta(&"age")) >= NUMBER_TIME:
		_numbers.pop_front().queue_free()


func _on_hit(amount: float, zone: int, _kind: int, _peer: int) -> void:
	_flash = 1.0
	if not show_damage_numbers or _numbers.size() > 12:
		return
	var label: Label3D = Label3D.new()
	label.text = "%d" % roundi(amount)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 56
	label.outline_size = 8
	label.modulate = Color(1.0, 0.85, 0.2) if zone == WeaponDefinition.Hitzone.HEAD else Color.WHITE
	label.position = Vector3(randf_range(-0.2, 0.2), 2.0, 0.0)
	label.set_meta(&"age", 0.0)
	add_child(label)
	_numbers.append(label)
