# ZombieDebugDraw — `zombie_debug on`: draws every host zombie's path (cyan, links magenta), the
# line to its target (red) and a state label. Debug presentation only (host).
class_name ZombieDebugDraw
extends Node3D

var _mesh: ImmediateMesh = ImmediateMesh.new()
var _mi: MeshInstance3D = MeshInstance3D.new()
var _labels: Array[Label3D] = []


func _ready() -> void:
	name = "ZombieDebug"
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.no_depth_test = true
	_mi.mesh = _mesh
	_mi.material_override = m
	_mi.top_level = true
	add_child(_mi)


func redraw(sims: Array[ZombieSim]) -> void:
	_mesh.clear_surfaces()
	if sims.is_empty():
		return
	var has_lines: bool = false
	for sim: ZombieSim in sims:
		has_lines = has_lines or sim.path.size() > sim.path_index or sim.target != null
	if not has_lines:
		return
	_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for sim: ZombieSim in sims:
		var lift: Vector3 = Vector3.UP * 0.15
		for i: int in range(maxi(sim.path_index, 1), sim.path.size()):
			var is_link: bool = sim.director.link_for_owner(sim.path_owners[i]) != null
			_mesh.surface_set_color(Color.MAGENTA if is_link else Color.CYAN)
			_mesh.surface_add_vertex((sim.pos if i == sim.path_index else sim.path[i - 1]) + lift)
			_mesh.surface_add_vertex(sim.path[i] + lift)
		if sim.target != null and is_instance_valid(sim.target):
			_mesh.surface_set_color(Color.RED)
			_mesh.surface_add_vertex(sim.pos + Vector3.UP * 1.8)
			_mesh.surface_add_vertex(sim.target.global_position + Vector3.UP * 1.2)
	_mesh.surface_end()
	while _labels.size() < sims.size():
		var l: Label3D = Label3D.new()
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.font_size = 28
		l.top_level = true
		add_child(l)
		_labels.append(l)
	for i: int in _labels.size():
		var l: Label3D = _labels[i]
		l.visible = i < sims.size()
		if l.visible:
			var s: ZombieSim = sims[i]
			l.global_position = s.pos + Vector3.UP * 2.2
			l.text = "#%d %s L%d" % [s.actor.net_id, s.state_name(), s.lod]
