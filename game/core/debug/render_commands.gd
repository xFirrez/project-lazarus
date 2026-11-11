# RenderCommands — console commands for look development (Step 4): quality presets, renderer
# statistics against the budgets, environment preset swaps, snow intensity and zombie clip
# preview. Authority: local presentation only (nothing here touches shared game state).
class_name RenderCommands
extends RefCounted

const ENV_DIR: String = "res://content/environments/"


static func register(reg: CommandRegistry) -> void:
	reg.register(
		"quality", _cmd_quality, [["preset", TYPE_STRING, ""]], "Show or set the video quality preset (runtime)"
	)
	reg.register("quality_info", _cmd_quality_info, [], "Applied quality settings in detail")
	reg.register("render_stats", _cmd_render_stats, [], "Draw calls / objects / primitives / shadow lights this frame")
	reg.register("env", _cmd_env, [["preset", TYPE_STRING, ""]], "Swap the active WorldEnvironment preset (look-dev)")
	reg.register("snow", _cmd_snow, [["intensity", TYPE_FLOAT]], "Camera snow intensity (0 = off, 1 = storm)")
	reg.register(
		"zombie_anim", _cmd_zombie_anim, [["clip", TYPE_STRING, ""]], "Play a clip on every ZombieModel (list if empty)"
	)


static func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


static func _cmd_quality(args: Array) -> String:
	var id: String = String(args[0])
	if id == "":
		return "quality: %s (available: %s)" % [Graphics.preset.id, ", ".join(Graphics.preset_ids())]
	if not Graphics.preset_ids().has(id):
		return "Unknown preset '%s' (available: %s)" % [id, ", ".join(Graphics.preset_ids())]
	Config.set_value(&"video", &"quality_preset", id)
	return "quality -> %s (applied at runtime; renderer changes need a restart)" % Graphics.preset.display_name


static func _cmd_quality_info(_args: Array) -> String:
	return Graphics.describe()


static func _cmd_render_stats(_args: Array) -> String:
	var budget: int = Graphics.preset.max_shadow_lights if Graphics.preset != null else 0
	return (
		"draw calls %d (budget 1500) | objects %d | primitives %d | shadow lights %d (budget %d) | video mem %.0f MiB"
		% [
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
			Graphics.shadow_casting_lights(),
			budget,
			Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
		]
	)


static func _cmd_env(args: Array) -> String:
	var names: PackedStringArray = []
	for f: String in DirAccess.get_files_at(ENV_DIR):
		if f.ends_with(".tres"):
			names.append(f.get_basename())
	var id: String = String(args[0])
	if id == "" or not names.has(id):
		return "env presets: %s" % ", ".join(names)
	var envs: Array[Node] = _tree().root.find_children("*", "WorldEnvironment", true, false)
	if envs.is_empty():
		return "No WorldEnvironment in the scene"
	var we: WorldEnvironment = envs[0] as WorldEnvironment
	we.environment = load(ENV_DIR + id + ".tres") as Environment
	Graphics.apply_environment(we)
	return "environment -> %s" % id


static func _cmd_snow(args: Array) -> String:
	var n: int = 0
	for node: Node in _tree().root.find_children("*", "GPUParticles3D", true, false):
		if node is CameraSnow:
			(node as CameraSnow).intensity = float(args[0])
			n += 1
	return "snow intensity %.2f on %d emitter(s)" % [float(args[0]), n]


static func _cmd_zombie_anim(args: Array) -> String:
	var models: Array[Node] = _tree().root.find_children("*", "Node3D", true, false).filter(
		func(n: Node) -> bool: return n is ZombieModel
	)
	if models.is_empty():
		return "No ZombieModel in the scene"
	var first: ZombieModel = models[0] as ZombieModel
	var clip: StringName = StringName(String(args[0]))
	if clip == &"" or not first.has_clip(clip):
		return "clips: %s" % ", ".join(first.clips())
	for m: Node in models:
		(m as ZombieModel).play(clip)
	return "playing %s on %d zombie(s)" % [clip, models.size()]
