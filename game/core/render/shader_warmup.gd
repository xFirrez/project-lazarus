# ShaderWarmup — shader / pipeline compile-stutter mitigation at load (Step 16, AC-16.3).
# Godot 4.7 compiles pipelines in the background with ubershaders, but the first draw of a new
# material + vertex-format + pass combination can still cost a specialization or a draw-time
# compile. After the map is loaded and a camera exists, this node puts one tiny quad per unique
# material (map meshes, survivors, zombie variants, weapons, extra scenes) and one copy of every
# particle system right in front of the camera for a few frames, under an opaque "preparing"
# card, so those pipelines compile during loading instead of in the first fight.
# Skipped in headless runs (no renderer). `finished` fires either way.
# Authority: local presentation.
class_name ShaderWarmup
extends Node

signal finished(materials: int, particles: int, msec: int)

const FRAMES: int = 4
const MAX_MATERIALS: int = 1500
const MAX_PARTICLES: int = 96
const CAMERA_WAIT_S: float = 15.0

var roots: Array[Node] = []
var extra_scenes: Array[PackedScene] = []
var done: bool = false
var material_count: int = 0
var particle_count: int = 0

var _cover: CanvasLayer = null
var _rig: Node3D = null
var _temp: Array[Node] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if DisplayServer.get_name() == "headless" or CommandLine.has_flag("no-warmup"):
		_finish.call_deferred(0)
		return
	_cover = CanvasLayer.new()
	_cover.layer = 90
	add_child(_cover)
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.06)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cover.add_child(bg)
	var label: Label = UiTheme.type_label("PREPARING THE MOUNTAIN…", 22, UiTheme.TEXT_LIGHT)
	label.set_anchors_preset(Control.PRESET_CENTER)
	_cover.add_child(label)
	_run.call_deferred()


func _run() -> void:
	var started: int = Time.get_ticks_msec()
	var waited: float = 0.0
	while get_viewport().get_camera_3d() == null and waited < CAMERA_WAIT_S:
		await get_tree().process_frame
		waited += get_process_delta_time()
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		_finish(started)
		return
	var materials: Array[Material] = []
	var seen: Dictionary = {}
	var particles: Array[Node3D] = []
	var particle_keys: Dictionary = {}
	for scene: PackedScene in extra_scenes:
		if scene != null:
			var inst: Node = scene.instantiate()
			_temp.append(inst)
			add_child(inst)
			if inst is Node3D:
				(inst as Node3D).visible = false
			roots.append(inst)
	for root: Node in roots:
		if is_instance_valid(root):
			_collect(root, materials, seen, particles, particle_keys)
	_rig = Node3D.new()
	_rig.name = "ShaderWarmupRig"
	cam.add_child(_rig)
	_rig.position = Vector3(0, 0, -1.5)
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(0.02, 0.02)
	var cols: int = 40
	for i: int in materials.size():
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.mesh = quad
		mi.material_override = materials[i]
		mi.position = Vector3((i % cols - cols / 2.0) * 0.021, (i / cols - 10) * 0.021, 0.0)
		_rig.add_child(mi)
	for p: Node3D in particles:
		var copy: Node3D = p.duplicate(0) as Node3D  # no scripts / signals / groups
		copy.position = Vector3.ZERO
		copy.visible = true
		_rig.add_child(copy)
		if copy is GPUParticles3D:
			(copy as GPUParticles3D).emitting = true
		elif copy is CPUParticles3D:
			(copy as CPUParticles3D).emitting = true
	material_count = materials.size()
	particle_count = particles.size()
	for f: int in FRAMES:
		await get_tree().process_frame
	_finish(started)


func _collect(
	node: Node, materials: Array[Material], seen: Dictionary, particles: Array[Node3D], particle_keys: Dictionary
) -> void:
	if node is GPUParticles3D or node is CPUParticles3D:
		var key: Variant = (node as GPUParticles3D).process_material if node is GPUParticles3D else node.get_class()
		if key != null and not particle_keys.has(key) and particles.size() < MAX_PARTICLES:
			particle_keys[key] = true
			particles.append(node as Node3D)
	if node is GeometryInstance3D:
		var gi: GeometryInstance3D = node
		_add(gi.material_override, materials, seen)
		_add(gi.material_overlay, materials, seen)
		if node is MeshInstance3D:
			var mi: MeshInstance3D = node
			if mi.mesh != null:
				for s: int in mi.mesh.get_surface_count():
					_add(mi.get_surface_override_material(s), materials, seen)
					_add(mi.mesh.surface_get_material(s), materials, seen)
		elif node is GPUParticles3D:
			var gp: GPUParticles3D = node
			for d: int in gp.draw_passes:
				var m: Mesh = gp.get_draw_pass_mesh(d)
				if m != null:
					for s: int in m.get_surface_count():
						_add(m.surface_get_material(s), materials, seen)
	for c: Node in node.get_children():
		_collect(c, materials, seen, particles, particle_keys)


func _add(m: Material, materials: Array[Material], seen: Dictionary) -> void:
	if m == null or seen.has(m) or materials.size() >= MAX_MATERIALS:
		return
	seen[m] = true
	materials.append(m)
	var next: Material = m.next_pass
	if next != null:
		_add(next, materials, seen)


func _finish(started: int) -> void:
	var ms: int = Time.get_ticks_msec() - started if started > 0 else 0
	if _rig != null:
		_rig.queue_free()
	for n: Node in _temp:
		if is_instance_valid(n):
			n.queue_free()
	_temp.clear()
	if _cover != null:
		_cover.queue_free()
		_cover = null
	done = true
	if material_count > 0:
		Log.info(
			&"render",
			"shader warm-up: %d materials, %d particle systems in %d ms" % [material_count, particle_count, ms]
		)
	finished.emit(material_count, particle_count, ms)
