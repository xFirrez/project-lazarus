# DamageHud — local player's hit feedback (GAME_DESIGN §3.2): red vignette scaling with missing
# HP plus a hit flash, directional damage indicators around the crosshair, a low-health heartbeat
# and audio muffling (Audio.set_muffle) below 50% HP. Driven by the local HealthComponent.
# Authority: local presentation.
class_name DamageHud
extends Control

const INDICATOR_TIME: float = 1.6
const INDICATOR_RADIUS: float = 150.0
const HEARTBEAT_INTERVAL: float = 0.85
const VIGNETTE_SHADER: String = "res://content/shaders/damage_vignette.gdshader"

var player: PlayerCharacter = null
var indicators: Array[Dictionary] = []  # {source: Vector3, age: float}
var show_crosshair: bool = true  # off once the WeaponHud draws the weapon crosshair

var _vignette: ColorRect = null
var _material: ShaderMaterial = null
var _flash: float = 0.0
var _heartbeat_timer: float = 0.0
var _crosshair_color: Color = Color(1, 1, 1, 0.7)


func _ready() -> void:
	name = "DamageHud"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette = ColorRect.new()
	_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_material = ShaderMaterial.new()
	_material.shader = load(VIGNETTE_SHADER) as Shader
	_vignette.material = _material
	add_child(_vignette)
	player.health.damaged.connect(_on_damaged)


func vignette_intensity() -> float:
	return 1.0 - player.health.fraction()


func _on_damaged(_amount: float, source_position: Vector3, _type: int) -> void:
	_flash = 1.0
	if source_position != Vector3.INF:
		indicators.append({"source": source_position, "age": 0.0})
	Audio.play_event(&"player_hurt")


# Angle of a world-space source relative to the view: 0 = ahead, +PI/2 = left, -PI/2 = right.
static func relative_angle(player_pos: Vector3, view_yaw: float, source: Vector3) -> float:
	var d: Vector3 = source - player_pos
	var world: float = atan2(-d.x, -d.z)
	return wrapf(world - view_yaw, -PI, PI)


func _process(delta: float) -> void:
	_flash = maxf(_flash - delta * 2.5, 0.0)
	_material.set_shader_parameter(&"intensity", vignette_intensity())
	_material.set_shader_parameter(&"flash", _flash)
	for ind: Dictionary in indicators:
		ind["age"] = float(ind["age"]) + delta
	indicators = indicators.filter(func(i: Dictionary) -> bool: return float(i["age"]) < INDICATOR_TIME)
	var low: bool = player.health.is_low() and not player.health.is_downed
	var t: PlayerTuning = player.tuning
	Audio.set_muffle(clampf(1.0 - player.health.fraction() / t.low_health_fraction, 0.0, 1.0) if low else 0.0)
	if low:
		_heartbeat_timer -= delta
		if _heartbeat_timer <= 0.0:
			_heartbeat_timer = HEARTBEAT_INTERVAL
			Audio.play_event(&"player_heartbeat")
	else:
		_heartbeat_timer = 0.0
	queue_redraw()


func _exit_tree() -> void:
	Audio.set_muffle(0.0)


func _draw() -> void:
	var center: Vector2 = size * 0.5
	if show_crosshair:  # fallback crosshair when no weapon HUD exists
		draw_line(center + Vector2(-8, 0), center + Vector2(-3, 0), _crosshair_color, 2.0)
		draw_line(center + Vector2(3, 0), center + Vector2(8, 0), _crosshair_color, 2.0)
		draw_line(center + Vector2(0, -8), center + Vector2(0, -3), _crosshair_color, 2.0)
		draw_line(center + Vector2(0, 3), center + Vector2(0, 8), _crosshair_color, 2.0)
	for ind: Dictionary in indicators:
		var rel: float = relative_angle(player.global_position, player.camera_rig.yaw, ind["source"])
		var alpha: float = 1.0 - float(ind["age"]) / INDICATOR_TIME
		_draw_wedge(center, rel, Color(0.9, 0.08, 0.05, 0.85 * alpha))


func _draw_wedge(center: Vector2, rel: float, color: Color) -> void:
	# Screen angle: up = ahead; positive rel = left of the view.
	var pts: PackedVector2Array = []
	var half: float = deg_to_rad(16.0)
	var steps: int = 10
	for i: int in steps + 1:
		var a: float = rel - half + 2.0 * half * i / steps
		pts.append(center + Vector2(-sin(a), -cos(a)) * (INDICATOR_RADIUS + 26.0))
	for i: int in range(steps, -1, -1):
		var a: float = rel - half + 2.0 * half * i / steps
		pts.append(center + Vector2(-sin(a), -cos(a)) * INDICATOR_RADIUS)
	draw_colored_polygon(pts, color)
