# ShootableGrate — a HitTarget that opens a NavDoor when shot (the laundry chute grate,
# VESPER_PEAK §5 CHT: "shoot the grate once"). Its id comes from the map's TargetRegistry scan, so
# hits replicate like any target; the door's open state replicates through WorldSync.
# Authority: HOST opens the door when the grate dies.
class_name ShootableGrate
extends HitTarget

@export var door_path: NodePath = ^""
@export var hit_size: Vector3 = Vector3(1.4, 1.4, 0.2)

var door: NavDoor = null


func _ready() -> void:
	max_health = 1.0
	super()
	door = get_node_or_null(door_path) as NavDoor
	var bs: BoxShape3D = BoxShape3D.new()
	bs.size = hit_size
	add_hurtbox(WeaponDefinition.Hitzone.TORSO, bs, Vector3.ZERO)
	died.connect(_on_died)


func _on_died(_source_peer: int) -> void:
	if door != null and WorldSync.is_authority():
		door.host_set_open(true)
