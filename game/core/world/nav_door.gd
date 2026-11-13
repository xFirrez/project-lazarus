# NavDoor — a door that blocks players and zombie navigation while closed. Opening it disables its
# collider and asks the owning NavigationRegion3D to re-bake (threaded), which connects the areas
# on both sides. Purchasable doors (PurchasableDoor) open it; the test maps toggle it by console.
# Authority: open state is host-authoritative (WorldSync `_door` events + join snapshot); only the
# host re-bakes navigation (clients don't run zombie AI).
class_name NavDoor
extends StaticBody3D

signal toggled(open: bool)

@export var size: Vector3 = Vector3(1.6, 2.4, 0.2)
@export var start_open: bool = false
@export var nav_region_path: NodePath = ^""
# Inverted doors are solid while "open" (the extendable Reactor Bridge, a lowered gate).
@export var solid_when_open: bool = false

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
	if solid_when_open:
		_apply_solid(false)
	if start_open:
		apply_open(true, false)


func _apply_solid(on: bool) -> void:
	collision_layer = 1 if on else 0
	_shape.disabled = not on


func host_set_open(on: bool) -> void:
	WorldSync.host_set_door(self, on)


func apply_open(on: bool, animate: bool = true) -> void:
	if on == is_open:
		return
	is_open = on
	_apply_solid(on == solid_when_open)
	if solid_when_open:
		# Extends into place (bridge) / retracts.
		_mesh.visible = true
		if animate and is_inside_tree():
			_mesh.scale = Vector3(1, 1, 0.05) if on else Vector3.ONE
			var tw2: Tween = create_tween()
			tw2.tween_property(_mesh, "scale", Vector3.ONE if on else Vector3(1, 1, 0.05), 1.5)
			if not on:
				tw2.tween_callback(func() -> void: _mesh.visible = false)
		else:
			_mesh.scale = Vector3.ONE
			_mesh.visible = on
	elif animate and on and is_inside_tree():
		# Debris collapses / door drops away, then hides.
		var tw: Tween = create_tween()
		tw.tween_property(_mesh, "position", Vector3(0, -size.y, 0), 0.7).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(_mesh, "rotation", Vector3(0.25, 0.0, 0.15), 0.7)
		tw.tween_callback(func() -> void: _mesh.visible = false)
	else:
		_mesh.position = Vector3.ZERO
		_mesh.rotation = Vector3.ZERO
		_mesh.visible = not on
	if animate:
		Audio.play_event_3d(&"door_open" if on else &"door_close", global_position)
	if WorldSync.is_authority():
		_rebake()
	toggled.emit(on)


func global_box() -> AABB:
	var t: Transform3D = global_transform
	return t * AABB(-size * 0.5, size)


func _rebake() -> void:
	var tiles: NavTiles = NavTiles.find(self)
	if tiles != null:
		tiles.rebake_around(global_box())
		return
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
