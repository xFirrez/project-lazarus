# PlayerInputSource — turns raw device input into one PlayerInputFrame per physics frame.
# Mouse look: raw relative motion × sensitivity (× ADS multiplier while aiming), no acceleration.
# Gamepad look: radial deadzone + power curve. Sprint/crouch hold-vs-toggle from Config.
# Authority: local (only the owning peer's PlayerCharacter has one).
class_name PlayerInputSource
extends RefCounted

# Menus over a running match (the co-op pause menu, Step 15) block gameplay input: gather() returns
# an idle frame and look input is dropped.
static var ui_blocked: bool = false

var tuning: PlayerTuning = null
var mouse_captured_required: bool = true

var _mouse_accum: Vector2 = Vector2.ZERO
var _ads_toggled: bool = false
var _sprint_toggled: bool = false
var _crouch_toggled: bool = false
var _aiming: bool = false
var _switch_delta: int = 0


func _init(t: PlayerTuning) -> void:
	tuning = t


func handle_event(event: InputEvent) -> void:
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null and (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or not mouse_captured_required):
		_mouse_accum += motion.screen_relative
	elif event.is_action_pressed(&"weapon_next"):
		_switch_delta += 1
	elif event.is_action_pressed(&"weapon_prev"):
		_switch_delta -= 1


# Clears toggles (e.g. when the motor cancels sprint because stamina ran out or the player stopped).
func cancel_sprint_toggle() -> void:
	_sprint_toggled = false


func set_crouch_toggle(on: bool) -> void:
	_crouch_toggled = on


func gather() -> PlayerInputFrame:
	var f: PlayerInputFrame = PlayerInputFrame.new()
	if ui_blocked:
		_switch_delta = 0
		return f
	f.move = Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	f.aim = Input.is_action_pressed(&"aim")
	f.fire = Input.is_action_pressed(&"fire")
	f.jump_pressed = Input.is_action_just_pressed(&"jump")
	f.jump_held = Input.is_action_pressed(&"jump")
	f.crouch_pressed = Input.is_action_just_pressed(&"crouch")
	f.reload_pressed = Input.is_action_just_pressed(&"reload")
	f.melee_pressed = Input.is_action_just_pressed(&"melee")
	f.interact = Input.is_action_pressed(&"interact")
	f.lethal_held = Input.is_action_pressed(&"lethal")
	f.tactical_pressed = Input.is_action_just_pressed(&"tactical")
	f.alt_fire = InputMap.has_action(&"alt_fire") and Input.is_action_pressed(&"alt_fire")
	f.placeable_pressed = Input.is_action_just_pressed(&"placeable")
	for i: int in 3:
		if Input.is_action_just_pressed(StringName("weapon_slot_%d" % (i + 1))):
			f.switch_slot = i
	f.switch_delta = signi(_switch_delta)
	_switch_delta = 0
	var toggle_sprint: bool = bool(Config.get_value(&"input", &"toggle_sprint", false))
	var toggle_crouch: bool = bool(Config.get_value(&"input", &"toggle_crouch", true))
	if toggle_sprint:
		if Input.is_action_just_pressed(&"sprint"):
			_sprint_toggled = not _sprint_toggled
		if f.move.y > -0.1:
			_sprint_toggled = false
		f.sprint = _sprint_toggled
	else:
		f.sprint = Input.is_action_pressed(&"sprint")
	if toggle_crouch:
		if f.crouch_pressed:
			_crouch_toggled = not _crouch_toggled
		f.crouch = _crouch_toggled
	else:
		f.crouch = Input.is_action_pressed(&"crouch")
	if bool(Config.get_value(&"input", &"toggle_ads", false)):
		if Input.is_action_just_pressed(&"aim"):
			_ads_toggled = not _ads_toggled
		if f.reload_pressed or f.sprint:
			_ads_toggled = false
		f.aim = _ads_toggled
	_aiming = f.aim
	return f


# Look is consumed every render frame (not per physics tick) for minimum latency.
func consume_look(delta: float) -> Vector2:
	if ui_blocked:
		_mouse_accum = Vector2.ZERO
		return Vector2.ZERO
	var aiming: bool = _aiming
	var sens: float = float(Config.get_value(&"input", &"mouse_sensitivity", 1.0))
	if aiming:
		sens *= float(Config.get_value(&"input", &"ads_sensitivity_multiplier", 0.8))
	var invert: float = -1.0 if bool(Config.get_value(&"input", &"invert_y", false)) else 1.0
	var look: Vector2 = Vector2(-_mouse_accum.x, -_mouse_accum.y * invert) * tuning.mouse_scale * sens
	_mouse_accum = Vector2.ZERO
	var stick: Vector2 = Input.get_vector(&"look_left", &"look_right", &"look_up", &"look_down", 0.0)
	var shaped: Vector2 = shape_stick(stick, tuning.gamepad_deadzone, tuning.gamepad_curve)
	if shaped != Vector2.ZERO:
		var pad_sens: float = float(Config.get_value(&"input", &"gamepad_sensitivity", 1.0))
		var rate: float = deg_to_rad(tuning.gamepad_look_speed_deg) * pad_sens * delta
		look += Vector2(-shaped.x, -shaped.y * invert) * rate
	return look


# Radial deadzone rescaled to 0..1, then a power curve on the magnitude (fine aim near centre).
static func shape_stick(stick: Vector2, deadzone: float, curve: float) -> Vector2:
	var mag: float = minf(stick.length(), 1.0)
	if mag <= deadzone:
		return Vector2.ZERO
	var scaled: float = (mag - deadzone) / (1.0 - deadzone)
	return stick.normalized() * pow(scaled, curve)
