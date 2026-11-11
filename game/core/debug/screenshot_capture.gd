# ScreenshotCapture — once a match is running, renders every Camera3D in the
# "screenshot_shot" group to <out_dir>/<shot_set>_<camera>.png, then quits.
# Used by tools/screenshot.sh for visual verification in the cloud container.
class_name ScreenshotCapture
extends Node

const SETTLE_FRAMES: int = 20

var out_dir: String = "user://screenshots"
var shot_set: String = ""


func _ready() -> void:
	EventBus.match_started.connect(_on_match_started)


func _on_match_started(_map_id: StringName) -> void:
	_capture.call_deferred()


func _capture() -> void:
	for i: int in SETTLE_FRAMES:
		await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(out_dir)
	var cams: Array[Node] = get_tree().get_nodes_in_group(&"screenshot_shot")
	cams.sort_custom(func(a: Node, b: Node) -> bool: return String(a.name) < String(b.name))
	var written: int = 0
	for node: Node in cams:
		var cam: Camera3D = node as Camera3D
		if cam == null:
			continue
		cam.current = true
		for i: int in 4:
			await RenderingServer.frame_post_draw
		var img: Image = get_viewport().get_texture().get_image()
		var file: String = out_dir.path_join("%s_%s.png" % [shot_set, String(cam.name).to_snake_case()])
		if img != null and img.save_png(file) == OK:
			written += 1
			Log.info(&"screenshot", "Wrote %s (%dx%d)" % [file, img.get_width(), img.get_height()])
		else:
			Log.error(&"screenshot", "Failed to write %s" % file)
	if written == 0:
		Log.error(&"screenshot", "No shots captured for set '%s'" % shot_set)
	get_tree().quit(0 if written > 0 else 1)
