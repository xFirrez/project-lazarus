# Tripmine — placeable claymore-style charge (GAME_DESIGN §4.3, Step 9 scope 5): sits on the floor
# with a red laser fan; a zombie inside `trigger_radius` in front of it sets it off after a short
# `fuse_time` beep (2000 splash, r = 4 m). Players never trigger it. Replicated by WeaponSync
# (`_wmine_r`, `_wmines_full` for late joiners, `_wpexplode`).
# Authority: HOST checks triggers (`triggered`); every peer shows the mine.
class_name Tripmine
extends Node3D

signal triggered(mine: Tripmine)

const CHECK_INTERVAL: float = 0.1
const ARM_TIME: float = 1.0
const FRONT_CONE: float = -0.2  # dot(forward, to zombie) above this counts as "in front"

var key: String = ""
var peer_id: int = 0
var def: WeaponDefinition = null
var armed_in: float = ARM_TIME
var fuse: float = -1.0

var _check: float = 0.0


static func create(p_def: WeaponDefinition, p_key: String, p_peer: int) -> Tripmine:
	var m: Tripmine = Tripmine.new()
	m.def = p_def
	m.key = p_key
	m.peer_id = p_peer
	m.name = "Tripmine_%s" % p_key.replace(":", "_")
	return m


func _ready() -> void:
	add_to_group(&"tripmine")
	var body: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = Vector3(0.22, 0.14, 0.05)
	body.mesh = bm
	body.position = Vector3(0, 0.1, 0)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = def.viewmodel_color if def != null else Color(0.25, 0.3, 0.22)
	body.material_override = mat
	add_child(body)
	for i: int in 2:
		var leg: MeshInstance3D = MeshInstance3D.new()
		var lm: BoxMesh = BoxMesh.new()
		lm.size = Vector3(0.012, 0.06, 0.012)
		leg.mesh = lm
		leg.position = Vector3(-0.08 + i * 0.16, 0.02, 0)
		leg.material_override = mat
		add_child(leg)
	var laser: MeshInstance3D = MeshInstance3D.new()
	var lb: BoxMesh = BoxMesh.new()
	lb.size = Vector3(0.004, 0.004, 1.6)
	laser.mesh = lb
	laser.position = Vector3(0, 0.12, 0.8)  # +Z is the mine's front
	var lmat: StandardMaterial3D = StandardMaterial3D.new()
	lmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lmat.albedo_color = Color(1.0, 0.1, 0.05)
	lmat.emission_enabled = true
	lmat.emission = Color(1.0, 0.1, 0.05)
	laser.material_override = lmat
	laser.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(laser)
	Audio.play_event_3d(&"mine_place", global_position)


func _physics_process(delta: float) -> void:
	if not WeaponSync.is_authority():
		return
	if armed_in > 0.0:
		armed_in -= delta
		return
	if fuse >= 0.0:
		fuse -= delta
		if fuse <= 0.0:
			triggered.emit(self)
		return
	_check -= delta
	if _check > 0.0:
		return
	_check = CHECK_INTERVAL
	if _zombie_in_range():
		fuse = def.fuse_time
		Audio.play_event_3d(&"mine_beep", global_position)


func _zombie_in_range() -> bool:
	var fwd: Vector3 = global_transform.basis.z
	var r2: float = def.trigger_radius * def.trigger_radius
	for n: Node in get_tree().get_nodes_in_group(&"zombie"):
		var z: Node3D = n as Node3D
		var ht: HitTarget = n as HitTarget
		if z == null or ht == null or not ht.alive:
			continue
		var to: Vector3 = z.global_position - global_position
		if absf(to.y) > 2.0 or to.length_squared() > r2:
			continue
		to.y = 0.0
		if to.length() < 0.6 or to.normalized().dot(fwd) > FRONT_CONE:
			return true
	return false
