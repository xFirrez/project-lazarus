# NavDoor — a door that blocks players and zombie navigation while closed. Opening it disables its
# collider and asks the owning NavigationRegion3D to re-bake (threaded), which connects the areas
# on both sides. Purchasable doors (Step 6/8) build on this; the test maps toggle it by console.
# Authority: open state is host-authoritative (WorldSync `_door` events + join snapshot); only the
# host re-bakes navigation (clients don't run zombie AI).
class_name NavDoor
extends StaticBody3D

signal toggled(open: bool)

@export var size: Vector3 = Vector3(1.6, 2.4, 0.2)
@export var start_open: bool = false
@export var nav_region_path: NodePath = ^""

var world_id: int = -1
var is_open: bool = false
var _mesh: MeshInstance3D = null
var _shape: CollisionShape3D = null


func _ready() -> void:
	add_to_group(&"nav_door")
	collision_layer = 1
	collision_mask = 0
	_shape = CollisionShape3D.new()
	var bs: BoxShape3D = BoxShape3D.new()
	bs.size = size
	_shape.shape = bs
	add_child(_shape)
	_mesh = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = size
	_mesh.mesh = bm
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = Color(0.35, 0.4, 0.46)
	m.metallic = 0.4
	_mesh.material_override = m
	add_child(_mesh)
	if start_open:
		apply_open(true, false)


func host_set_open(on: bool) -> void:
	WorldSync.host_set_door(self, on)


func apply_open(on: bool, animate: bool = true) -> void:
	if on == is_open:
		return
	is_open = on
	collision_layer = 0 if on else 1
	_shape.disabled = on
	_mesh.visible = not on
	if animate:
		Audio.play_event_3d(&"door_open" if on else &"door_close", global_position)
	if WorldSync.is_authority():
		_rebake()
	toggled.emit(on)


func _rebake() -> void:
	var region: NavigationRegion3D = get_node_or_null(nav_region_path) as NavigationRegion3D
	var p: Node = get_parent()
	while region == null and p != null:
		region = p as NavigationRegion3D
		p = p.get_parent()
	if region == null:
		return
	if region.is_baking():
		await region.bake_finished
	region.bake_navigation_mesh(true)
