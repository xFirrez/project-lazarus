# ExplosiveDrum — H1 fuel drum (VESPER_PEAK §5): shoot it and it explodes (r 4 m, 2000 at the centre
# to zombies and other drums — chain reactions — and up to PLAYER_DAMAGE to players: "lightly").
# A HitTarget registered in tree order (TargetRegistry scan), so hits / death / revive replicate.
# HazardSystem brings destroyed drums back every RESPAWN_ROUNDS rounds.
# Authority: HOST applies the blast (WeaponSync.host_splash); every peer shows the drum's state.
class_name ExplosiveDrum
extends HitTarget

const RADIUS: float = 4.0
const DAMAGE: float = 2000.0
const EDGE_DAMAGE: float = 300.0
const PLAYER_DAMAGE: float = 40.0
const RESPAWN_ROUNDS: int = 3

var system: HazardSystem = null
var died_round: int = -1
var _mesh: MeshInstance3D = null


func _ready() -> void:
	max_health = 40.0
	respawn_time = 0.0
	super()
	var bs: BoxShape3D = BoxShape3D.new()
	bs.size = Vector3(0.62, 0.9, 0.62)
	add_hurtbox(WeaponDefinition.Hitzone.TORSO, bs, Vector3(0, 0.45, 0))
	_mesh = MeshInstance3D.new()
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = 0.3
	cm.bottom_radius = 0.3
	cm.height = 0.9
	_mesh.mesh = cm
	_mesh.position.y = 0.45
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = Color(0.62, 0.12, 0.08)
	m.metallic = 0.5
	m.roughness = 0.6
	_mesh.material_override = m
	add_child(_mesh)
	var band: MeshInstance3D = MeshInstance3D.new()
	var bm: CylinderMesh = CylinderMesh.new()
	bm.top_radius = 0.305
	bm.bottom_radius = 0.305
	bm.height = 0.08
	band.mesh = bm
	band.position.y = 0.62
	var bmat: StandardMaterial3D = StandardMaterial3D.new()
	bmat.albedo_color = Color(0.85, 0.7, 0.15)
	band.material_override = bmat
	_mesh.add_child(band)
	died.connect(_on_died)
	revived.connect(func() -> void: _mesh.visible = true)


func _on_died(source_peer: int) -> void:
	_mesh.visible = false
	if system != null:
		system.host_drum_exploded(self, source_peer)
