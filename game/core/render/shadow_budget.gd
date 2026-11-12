# ShadowBudget — keeps the shadow-casting omni / spot lights near the viewer within the quality
# preset's budget (Step 13; ARCHITECTURE §12 "≤ 8 shadow-casting lights visible anywhere"): every
# `interval` seconds it ranks the `shadow_light` group by reach (lights whose range cannot touch
# the camera's surroundings are skipped), then by `shadow_priority` and distance, and enables
# shadows on the best `Graphics.preset.max_shadow_lights`. Graphics.refresh_shadow_budget still
# runs on preset changes; this refines it per viewpoint. Directional lights are not counted.
# Authority: local presentation.
class_name ShadowBudget
extends Node

@export var interval: float = 0.5
@export var margin: float = 6.0  # metres beyond a light's range that still count as "visible"

var active: int = 0

var _t: float = 0.0


func _ready() -> void:
	if Graphics.preset_applied.is_connected(_on_preset) == false:
		Graphics.preset_applied.connect(_on_preset)


func _on_preset(_p: QualityPreset) -> void:
	refresh.call_deferred()


func _process(delta: float) -> void:
	_t -= delta
	if _t <= 0.0:
		_t = interval
		refresh()


func refresh() -> void:
	var cam: Camera3D = get_viewport().get_camera_3d() if get_viewport() != null else null
	if cam == null or Graphics.preset == null:
		return
	var budget: int = Graphics.preset.max_shadow_lights
	var at: Vector3 = cam.global_position
	var ranked: Array = []
	var off: Array[Light3D] = []
	for n: Node in get_tree().get_nodes_in_group(&"shadow_light"):
		if not n is Light3D or n is DirectionalLight3D:
			continue
		var l: Light3D = n as Light3D
		var rng: float = (l as OmniLight3D).omni_range if l is OmniLight3D else (l as SpotLight3D).spot_range
		var d: float = at.distance_to(l.global_position)
		if d > rng + margin or not l.is_visible_in_tree():
			off.append(l)
			continue
		ranked.append([float(l.get_meta(&"shadow_priority", 0.0)) - d * 0.5, l])
	ranked.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
	active = 0
	for i: int in ranked.size():
		var on: bool = i < budget
		(ranked[i][1] as Light3D).shadow_enabled = on
		if on:
			active += 1
	for l: Light3D in off:
		l.shadow_enabled = false
