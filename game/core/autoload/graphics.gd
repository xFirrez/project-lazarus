# Graphics — applies the video quality preset (QualityPreset, content/quality/*.tres) at runtime
# and keeps it applied to everything that enters the tree: viewport scaling / AA / LOD, shadow
# atlas sizes and filter quality, per-WorldEnvironment SSAO / glow / volumetric fog (on top of
# what the environment preset authored), the shadow-casting light budget (lights in group
# `shadow_light`, highest `shadow_priority` meta first) and particle density (GPUParticles3D in
# group `density_scaled`). Switching presets never needs a restart; only the renderer does.
# Authority: local presentation.
extends Node

signal preset_applied(preset: QualityPreset)

const SHADOW_GROUP: StringName = &"shadow_light"
const DENSITY_GROUP: StringName = &"density_scaled"
const FALLBACK: StringName = &"high"
# Settings that cannot change at runtime (shown with a "requires restart" note in the UI).
const RESTART_ONLY: PackedStringArray = ["rendering_method"]

var preset: QualityPreset = null
var applied_count: int = 0


func _ready() -> void:
	Config.setting_changed.connect(_on_setting_changed)
	get_tree().node_added.connect(_on_node_added)
	apply_preset(StringName(str(Config.get_value(&"video", &"quality_preset", FALLBACK))))


func presets() -> Array[QualityPreset]:
	var out: Array[QualityPreset] = []
	for r: Resource in Content.get_all(&"QualityPreset"):
		out.append(r as QualityPreset)
	out.sort_custom(func(a: QualityPreset, b: QualityPreset) -> bool: return a.order < b.order)
	return out


func preset_ids() -> PackedStringArray:
	var ids: PackedStringArray = []
	for p: QualityPreset in presets():
		ids.append(String(p.id))
	return ids


func apply_preset(preset_id: StringName) -> bool:
	var p: QualityPreset = Content.get_def(&"QualityPreset", preset_id) as QualityPreset
	if p == null:
		Log.warn(&"graphics", "Unknown quality preset '%s'" % preset_id)
		if preset == null and preset_id != FALLBACK:
			return apply_preset(FALLBACK)
		return false
	preset = p
	_apply_global()
	for env: Node in get_tree().root.find_children("*", "WorldEnvironment", true, false):
		apply_environment(env as WorldEnvironment)
	for cam: Node in get_tree().root.find_children("*", "Camera3D", true, false):
		apply_camera(cam as Camera3D)
	refresh_shadow_budget()
	for n: Node in get_tree().get_nodes_in_group(DENSITY_GROUP):
		apply_particles(n as GPUParticles3D)
	applied_count += 1
	Log.info(&"graphics", "Quality preset %s applied" % p.display_name)
	preset_applied.emit(p)
	return true


# Environment features are the authored preset AND the quality level (never turned on if the
# environment resource left them off).
func apply_environment(we: WorldEnvironment) -> void:
	if we == null or we.environment == null or preset == null:
		return
	var env: Environment = we.environment
	if not env.has_meta(&"lz_base"):
		env.set_meta(&"lz_base", [env.ssao_enabled, env.glow_enabled, env.volumetric_fog_enabled])
	var base: Array = env.get_meta(&"lz_base")
	env.ssao_enabled = bool(base[0]) and preset.ssao
	env.glow_enabled = bool(base[1]) and preset.glow
	env.volumetric_fog_enabled = bool(base[2]) and preset.volumetric_fog


func apply_camera(cam: Camera3D) -> void:
	if cam == null or preset == null:
		return
	if not cam.has_meta(&"lz_far"):
		cam.set_meta(&"lz_far", cam.far)
	cam.far = minf(float(cam.get_meta(&"lz_far")), preset.view_distance)


func apply_particles(p: GPUParticles3D) -> void:
	if p != null and preset != null:
		p.amount_ratio = preset.particle_density


# Enables shadows on the `max_shadow_lights` highest-priority omni/spot lights, disables the rest.
# Directional lights are not counted (one moon/sun per area, ARCHITECTURE §12).
func refresh_shadow_budget() -> void:
	if preset == null:
		return
	var lights: Array[Light3D] = []
	for n: Node in get_tree().get_nodes_in_group(SHADOW_GROUP):
		if n is Light3D and not n is DirectionalLight3D:
			lights.append(n as Light3D)
	lights.sort_custom(
		func(a: Light3D, b: Light3D) -> bool:
			return float(a.get_meta(&"shadow_priority", 0.0)) > float(b.get_meta(&"shadow_priority", 0.0))
	)
	for i: int in lights.size():
		lights[i].shadow_enabled = i < preset.max_shadow_lights


func shadow_casting_lights() -> int:
	var count: int = 0
	for n: Node in get_tree().root.find_children("*", "Light3D", true, false):
		var l: Light3D = n as Light3D
		if l.shadow_enabled and l.visible and l.is_visible_in_tree() and not l is DirectionalLight3D:
			count += 1
	return count


func describe() -> String:
	if preset == null:
		return "no preset"
	var vp: Viewport = get_tree().root
	return (
		(
			"%s: scale %.2f (%s) msaa %d fxaa %s | shadows dir %d pos %d soft %d max %d lights"
			+ " | ssao %s glow %s vfog %s %dx%d | particles %.2f lod %.1f far %.0f"
		)
		% [
			preset.display_name,
			vp.scaling_3d_scale,
			QualityPreset.Scaling.keys()[preset.scaling],
			vp.msaa_3d,
			vp.screen_space_aa == Viewport.SCREEN_SPACE_AA_FXAA,
			preset.directional_shadow_size,
			vp.positional_shadow_atlas_size,
			preset.soft_shadow_quality,
			preset.max_shadow_lights,
			preset.ssao,
			preset.glow,
			preset.volumetric_fog,
			preset.volumetric_fog_size,
			preset.volumetric_fog_depth,
			preset.particle_density,
			vp.mesh_lod_threshold,
			preset.view_distance,
		]
	)


func _apply_global() -> void:
	var vp: Viewport = get_tree().root
	vp.scaling_3d_scale = preset.render_scale
	match preset.scaling:
		QualityPreset.Scaling.FSR1:
			vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
		QualityPreset.Scaling.FSR2:
			vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR2
		_:
			vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	vp.msaa_3d = preset.msaa
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if preset.fxaa else Viewport.SCREEN_SPACE_AA_DISABLED
	vp.use_taa = preset.taa
	vp.mesh_lod_threshold = preset.mesh_lod_threshold
	vp.positional_shadow_atlas_size = preset.positional_shadow_atlas
	RenderingServer.directional_shadow_atlas_set_size(preset.directional_shadow_size, true)
	RenderingServer.directional_soft_shadow_filter_set_quality(preset.soft_shadow_quality)
	RenderingServer.positional_soft_shadow_filter_set_quality(preset.soft_shadow_quality)
	RenderingServer.environment_set_ssao_quality(preset.ssao_quality, true, 0.5, 2, 50.0, 300.0)
	RenderingServer.environment_set_volumetric_fog_volume_size(preset.volumetric_fog_size, preset.volumetric_fog_depth)


func _deferred_apply(node: Variant) -> void:
	if not is_instance_valid(node):
		return
	if node is WorldEnvironment:
		apply_environment(node as WorldEnvironment)
	elif node is Camera3D:
		apply_camera(node as Camera3D)


func _on_node_added(node: Node) -> void:
	if preset == null:
		return
	# Deferred through a lambda that re-checks validity: a node freed in the same frame (e.g. a map
	# torn down right after it was added) must not reach the typed apply_* call.
	if node is WorldEnvironment:
		_deferred_apply.call_deferred(node)
	elif node is Camera3D:
		_deferred_apply.call_deferred(node)
	elif node is GPUParticles3D and node.is_in_group(DENSITY_GROUP):
		apply_particles(node as GPUParticles3D)
	elif node is Light3D and node.is_in_group(SHADOW_GROUP):
		refresh_shadow_budget.call_deferred()


func _on_setting_changed(section: StringName, key: StringName, value: Variant) -> void:
	if section == &"video" and key == &"quality_preset":
		apply_preset(StringName(str(value)))
