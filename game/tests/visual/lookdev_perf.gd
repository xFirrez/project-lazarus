# Visual test (AC-4.3 automated part, AC-4.4 reference shots): renders the 5 fixed look-dev camera
# shots on the High and Medium presets and records the renderer monitors per shot (draw calls,
# objects, primitives) plus the active shadow-casting omni/spot lights. Checks draw calls <= 1500
# and shadow lights within the preset budget. Writes lookdev_<shot>.png (High, no debug overlay)
# and lookdev_perf.csv to --autotest-shots. Run: tools/visual_tests.sh <dir> lookdev_perf
extends "res://tests/net/autotest_base.gd"

const MAX_DRAW_CALLS: int = 1500
const PRESETS: Array[String] = ["high", "medium"]

var _out: String = ""


func _ready() -> void:
	timeout = 240.0
	_out = CommandLine.get_value("autotest-shots", "user://screenshots")
	DirAccess.make_dir_recursive_absolute(_out)
	EventBus.match_started.connect(func(_m: StringName) -> void: _run.call_deferred())


func _frames(n: int) -> void:
	for i: int in n:
		await RenderingServer.frame_post_draw


func _run() -> void:
	await _frames(20)
	for layer: Node in get_tree().get_nodes_in_group(&"hide_for_shots"):
		(layer as CanvasLayer).visible = false
	if Debug.overlay != null:
		Debug.overlay.visible = false
	var cams: Array[Node] = get_tree().get_nodes_in_group(&"screenshot_shot")
	cams.sort_custom(func(a: Node, b: Node) -> bool: return String(a.name) < String(b.name))
	check("five_shots", cams.size() == 5, cams.size())
	var csv: PackedStringArray = ["preset,shot,draw_calls,objects,primitives,shadow_lights,shadow_budget"]
	var worst: int = 0
	for preset: String in PRESETS:
		Config.set_value(&"video", &"quality_preset", preset)
		await _frames(4)
		var budget: int = Graphics.preset.max_shadow_lights
		var lights: int = Graphics.shadow_casting_lights()
		check("%s_shadow_lights_in_budget" % preset, lights <= budget, "%d <= %d" % [lights, budget])
		for node: Node in cams:
			var cam: Camera3D = node as Camera3D
			cam.current = true
			await _frames(6)
			var dc: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
			var obj: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
			var prim: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
			worst = maxi(worst, dc)
			csv.append("%s,%s,%d,%d,%d,%d,%d" % [preset, cam.name, dc, obj, prim, lights, budget])
			note("%s %s: draw calls %d, objects %d, primitives %d" % [preset, cam.name, dc, obj, prim])
			if preset == "high":
				var img: Image = get_viewport().get_texture().get_image()
				img.save_png(_out.path_join("lookdev_%s.png" % String(cam.name).to_snake_case()))
	# First-person reference: the M1911 hero viewmodel in the courtyard light (High).
	Config.set_value(&"video", &"quality_preset", "high")
	for layer: Node in get_tree().get_nodes_in_group(&"hide_for_shots"):
		(layer as CanvasLayer).visible = true
	var me: PlayerCharacter = sync().local_avatar()
	if me != null:
		me.camera.current = true
		me.set_view(deg_to_rad(-12.0), deg_to_rad(-4.0))
		await get_tree().create_timer(1.0).timeout
		await _frames(4)
		get_viewport().get_texture().get_image().save_png(_out.path_join("lookdev_fp_m1911.png"))
	check("draw_calls_max_%d" % MAX_DRAW_CALLS, worst > 0 and worst <= MAX_DRAW_CALLS, worst)
	var f: FileAccess = FileAccess.open(_out.path_join("lookdev_perf.csv"), FileAccess.WRITE)
	f.store_string("\n".join(csv) + "\n")
	f.close()
	Config.set_value(&"video", &"quality_preset", "high")
	finish(true)
