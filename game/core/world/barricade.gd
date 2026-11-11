# Barricade — a boarded window (GAME_DESIGN §12): `max_planks` planks that zombies tear one at a
# time and players rebuild (Step 6 adds the rebuild interaction). One zombie works a window at a
# time (`occupant`); the rest wait outside. A TraversalLink (action WINDOW) crosses the opening.
# Authority: plank count is host-authoritative; WorldSync replicates `_barricade` events and the
# full state on join. Visual planks are local presentation on every peer.
class_name Barricade
extends Node3D

signal planks_changed(planks: int, delta: int)

static var _wood: StandardMaterial3D = null

@export var max_planks: int = 6
@export var width: float = 1.4
@export var height: float = 1.2

var world_id: int = -1
var planks: int = 6
var occupant: int = 0  # host: net id of the zombie working this window (0 = free)
var tears: int = 0  # host statistics
var _plank_nodes: Array[MeshInstance3D] = []
var _plank_rest: Array[Transform3D] = []


func _ready() -> void:
	add_to_group(&"barricade")
	planks = max_planks
	_build_planks()


func is_open() -> bool:
	return planks <= 0


# Point zombies stand on while tearing (outside, +Z of the barricade's local frame).
func outside_point() -> Vector3:
	return global_transform * Vector3(0, -height * 0.5 - 0.9, 0.75)


# HOST: removes one plank. Returns true if a plank came off.
func host_tear() -> bool:
	if planks <= 0:
		return false
	tears += 1
	WorldSync.host_set_barricade(self, planks - 1)
	return true


func host_repair_all() -> void:
	WorldSync.host_set_barricade(self, max_planks)


# Every peer: applies a plank count (from the host's event or the join snapshot).
func apply_planks(count: int, animate: bool = true) -> void:
	var old: int = planks
	planks = clampi(count, 0, max_planks)
	if planks == old:
		return
	for i: int in _plank_nodes.size():
		var on: bool = i < planks
		var p: MeshInstance3D = _plank_nodes[i]
		if on:
			p.transform = _plank_rest[i]
			p.visible = true
		elif p.visible:
			if animate and is_inside_tree():
				_fling(p)
			else:
				p.visible = false
	if animate:
		Audio.play_event_3d(&"barricade_tear" if planks < old else &"barricade_repair", global_position)
	planks_changed.emit(planks, planks - old)


func _fling(p: MeshInstance3D) -> void:
	var tw: Tween = create_tween()
	var out: Transform3D = p.transform.translated(Vector3(randf_range(-0.3, 0.3), -0.6, 0.9))
	out.basis = out.basis.rotated(Vector3.UP, randf_range(-0.8, 0.8))
	tw.tween_property(p, "transform", out, 0.35).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void: p.visible = false)


func _build_planks() -> void:
	if _wood == null:
		_wood = StandardMaterial3D.new()
		_wood.albedo_color = Color(0.5, 0.36, 0.22)
		_wood.roughness = 0.9
	var bm: BoxMesh = BoxMesh.new()
	bm.size = Vector3(width + 0.25, 0.14, 0.04)
	for i: int in max_planks:
		var p: MeshInstance3D = MeshInstance3D.new()
		p.name = "Plank%d" % i
		p.mesh = bm
		p.material_override = _wood
		var y: float = -height * 0.5 + (i + 0.5) * height / max_planks
		var t: Transform3D = Transform3D(Basis(Vector3.BACK, 0.18 if i % 2 == 0 else -0.14), Vector3(0, y, 0.05))
		p.transform = t
		add_child(p)
		_plank_nodes.append(p)
		_plank_rest.append(t)
