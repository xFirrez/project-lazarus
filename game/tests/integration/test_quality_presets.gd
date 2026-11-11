# AC-4.6: quality presets switch at runtime without a restart: viewport scaling / AA / LOD,
# per-environment SSAO / glow / volumetric fog, the shadow-casting light budget, particle density
# and the camera far plane all follow the selected preset (Graphics autoload).
extends GutTest

var _env: WorldEnvironment = null
var _lights: Array[OmniLight3D] = []
var _cam: Camera3D = null
var _snow: GPUParticles3D = null


func before_each() -> void:
	var root: Node3D = Node3D.new()
	add_child_autofree(root)
	_env = WorldEnvironment.new()
	_env.environment = (load("res://content/environments/exterior_storm.tres") as Environment).duplicate()
	root.add_child(_env)
	_lights.clear()
	for i: int in 6:
		var l: OmniLight3D = OmniLight3D.new()
		l.shadow_enabled = true
		l.set_meta(&"shadow_priority", float(i))
		l.add_to_group(&"shadow_light")
		root.add_child(l)
		_lights.append(l)
	_cam = Camera3D.new()
	_cam.far = 4000.0
	root.add_child(_cam)
	_snow = GPUParticles3D.new()
	_snow.add_to_group(&"density_scaled")
	root.add_child(_snow)
	await get_tree().process_frame


func after_each() -> void:
	Config.set_value(&"video", &"quality_preset", "high")


func _shadowed() -> Array[float]:
	var out: Array[float] = []
	for l: OmniLight3D in _lights:
		if l.shadow_enabled:
			out.append(float(l.get_meta(&"shadow_priority")))
	out.sort()
	return out


func test_four_presets_in_order() -> void:
	assert_eq(Graphics.preset_ids(), PackedStringArray(["low", "medium", "high", "ultra"]))
	assert_eq(Graphics.RESTART_ONLY, PackedStringArray(["rendering_method"]))


func test_switching_applies_everything_at_runtime() -> void:
	var vp: Viewport = get_tree().root
	Config.set_value(&"video", &"quality_preset", "low")
	await get_tree().process_frame
	assert_eq(Graphics.preset.id, &"low")
	assert_almost_eq(vp.scaling_3d_scale, 0.75, 0.001)
	assert_eq(vp.scaling_3d_mode, Viewport.SCALING_3D_MODE_FSR)
	assert_eq(vp.screen_space_aa, Viewport.SCREEN_SPACE_AA_FXAA)
	assert_false(_env.environment.ssao_enabled, "low: no SSAO")
	assert_false(_env.environment.volumetric_fog_enabled, "low: no volumetric fog")
	assert_true(_env.environment.glow_enabled)
	assert_eq(_shadowed(), [4.0, 5.0] as Array[float], "low: 2 highest-priority shadow lights")
	assert_almost_eq(_snow.amount_ratio, 0.35, 0.001)
	assert_almost_eq(_cam.far, 120.0, 0.01)
	Config.set_value(&"video", &"quality_preset", "medium")
	await get_tree().process_frame
	assert_eq(_shadowed().size(), 4)
	assert_true(_env.environment.ssao_enabled and _env.environment.volumetric_fog_enabled)
	assert_almost_eq(vp.scaling_3d_scale, 1.0, 0.001)
	Config.set_value(&"video", &"quality_preset", "ultra")
	await get_tree().process_frame
	assert_eq(vp.msaa_3d, Viewport.MSAA_4X)
	assert_eq(_shadowed().size(), 6, "ultra budget (12) covers all 6")
	assert_almost_eq(_snow.amount_ratio, 1.0, 0.001)
	assert_almost_eq(_cam.far, 400.0, 0.01)
	Config.set_value(&"video", &"quality_preset", "high")
	await get_tree().process_frame
	assert_eq(vp.msaa_3d, Viewport.MSAA_2X)
	assert_eq(vp.screen_space_aa, Viewport.SCREEN_SPACE_AA_DISABLED)


func test_environment_keeps_authored_off_features_off() -> void:
	_env.environment.ssao_enabled = false
	_env.environment.remove_meta(&"lz_base")
	Graphics.apply_environment(_env)
	Config.set_value(&"video", &"quality_preset", "ultra")
	await get_tree().process_frame
	assert_false(_env.environment.ssao_enabled, "a preset never enables what the environment left off")


func test_unknown_preset_is_rejected() -> void:
	assert_false(Graphics.apply_preset(&"potato"))
	assert_eq(Graphics.preset.id, &"high")
