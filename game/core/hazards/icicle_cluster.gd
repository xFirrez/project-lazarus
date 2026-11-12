# IcicleCluster — H2 icicles (VESPER_PEAK §5): shoot the cluster and it drops; anything below within
# KILL_RADIUS (horizontal) is killed when it lands (zombies; players are only bruised). Regrows
# REGROW_ROUNDS rounds later. A HitTarget (tree-order id) so the break replicates.
# Authority: HOST applies the impact (HazardSystem); every peer animates the fall.
class_name IcicleCluster
extends HitTarget

const KILL_RADIUS: float = 1.5
const FALL_TIME: float = 0.45
const REGROW_ROUNDS: int = 2

var system: HazardSystem = null
var died_round: int = -1
var ground_y: float = 0.0
var _spikes: Node3D = null


func _ready() -> void:
	max_health = 1.0
	respawn_time = 0.0
	super()
	var bs: BoxShape3D = BoxShape3D.new()
	bs.size = Vector3(1.6, 0.9, 0.5)
	add_hurtbox(WeaponDefinition.Hitzone.TORSO, bs, Vector3(0, -0.4, 0))
	_spikes = Node3D.new()
	add_child(_spikes)
	var ice: StandardMaterial3D = StandardMaterial3D.new()
	ice.albedo_color = Color(0.8, 0.92, 1.0, 0.85)
	ice.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ice.roughness = 0.05
	ice.metallic_specular = 1.0
	for i: int in 7:
		var mi: MeshInstance3D = MeshInstance3D.new()
		var cm: CylinderMesh = CylinderMesh.new()
		cm.top_radius = 0.07 + 0.02 * (i % 3)
		cm.bottom_radius = 0.0
		cm.height = 0.5 + 0.12 * ((i * 5) % 4)
		mi.mesh = cm
		mi.position = Vector3(-0.7 + i * 0.23, -cm.height * 0.5, 0.05 * (i % 2))
		mi.material_override = ice
		_spikes.add_child(mi)
	died.connect(_on_died)
	revived.connect(_on_revived)


func _on_died(_source_peer: int) -> void:
	Audio.play_event_3d(&"icicle_crack", global_position)
	var drop: float = maxf(global_position.y - ground_y, 0.5)
	var tw: Tween = create_tween()
	tw.tween_property(_spikes, "position:y", -drop, FALL_TIME).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(func() -> void: Audio.play_event_3d(&"shatter", global_position + Vector3.DOWN * drop))
	tw.tween_interval(0.4)
	tw.tween_callback(func() -> void: _spikes.visible = false)
	if system != null:
		system.host_icicles_dropped(self, _source_peer)


func _on_revived() -> void:
	_spikes.position = Vector3.ZERO
	_spikes.visible = true
