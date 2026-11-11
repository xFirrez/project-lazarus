# CameraRig — first-person view: yaw/pitch with clamps, FOV setting (horizontal) with sprint
# kick, head bob and strafe tilt (scaled by setting), landing dip, crouch/slide eye-height
# transitions, stair-step smoothing and trauma-based screen shake (shake scale setting).
# The camera is top-level and placed every render frame from the body's *interpolated* transform,
# so look input applies at render rate with no physics-tick latency.
# Authority: local presentation (only the local player's rig has a current camera).
class_name CameraRig
extends Node3D

var tuning: PlayerTuning = null
var body: CharacterBody3D = null
var motor: MotorComponent = null
var camera: Camera3D = null

var yaw: float = 0.0
var pitch: float = 0.0
var trauma: float = 0.0
var eye_height: float = 1.62

var _step_offset: float = 0.0
var _dip: float = 0.0
var _dip_vel: float = 0.0
var _bob_phase: float = 0.0
var _bob_weight: float = 0.0
var _tilt: float = 0.0
var _fov_kick: float = 0.0
var _noise: FastNoiseLite = FastNoiseLite.new()
var _noise_t: float = 0.0


func setup(p_body: CharacterBody3D, p_motor: MotorComponent, p_tuning: PlayerTuning, cam: Camera3D) -> void:
	body = p_body
	motor = p_motor
	tuning = p_tuning
	camera = cam
	camera.top_level = true
	camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	camera.keep_aspect = Camera3D.KEEP_WIDTH  # FOV setting is horizontal (GAME_DESIGN §3.1)
	camera.near = 0.05
	eye_height = tuning.eye_height_stand
	_noise.seed = 1337
	_noise.frequency = 2.0
	motor.stepped.connect(_on_stepped)
	motor.landed.connect(_on_landed)


func add_look(delta_rad: Vector2) -> void:
	yaw = wrapf(yaw + delta_rad.x, -PI, PI)
	var limit: float = deg_to_rad(tuning.pitch_limit_deg)
	pitch = clampf(pitch + delta_rad.y, -limit, limit)


func add_trauma(amount: float) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)


func _on_stepped(height: float) -> void:
	# The body popped up a stair; keep the eye where it was and ease it up.
	_step_offset -= height


func _on_landed(impact_speed: float, _fall_height: float) -> void:
	_dip_vel -= minf(impact_speed * tuning.landing_dip_per_mps * 12.0, tuning.landing_dip_max * 12.0)
	if impact_speed > 12.0:
		add_trauma(0.25)


func target_eye_height() -> float:
	match motor.stance:
		MotorComponent.Stance.CROUCH:
			return tuning.eye_height_crouch
		MotorComponent.Stance.SLIDE:
			return tuning.eye_height_slide
	return tuning.eye_height_stand


# Called every render frame by PlayerCharacter (local player only).
func update_view(delta: float) -> void:
	if camera == null:
		return
	var eye_rate: float = (tuning.eye_height_stand - tuning.eye_height_crouch) / maxf(tuning.crouch_transition, 0.01)
	eye_height = move_toward(eye_height, target_eye_height(), eye_rate * delta)
	_step_offset = lerpf(_step_offset, 0.0, clampf(tuning.step_smooth_speed * delta, 0.0, 1.0))
	# Landing dip: critically-damped spring back to 0.
	var k: float = 120.0
	var c: float = 2.0 * sqrt(k)
	_dip_vel += (-k * _dip - c * _dip_vel) * delta
	_dip = clampf(_dip + _dip_vel * delta, -tuning.landing_dip_max, tuning.landing_dip_max)
	var bob_scale: float = float(Config.get_value(&"video", &"camera_bob_scale", 1.0))
	var shake_scale: float = float(Config.get_value(&"video", &"screen_shake_scale", 1.0))
	var hspeed: float = motor.horizontal_speed()
	var moving: bool = motor.grounded and hspeed > 0.5 and motor.stance != MotorComponent.Stance.SLIDE
	_bob_weight = move_toward(
		_bob_weight, clampf(hspeed / tuning.sprint_speed, 0.0, 1.0) if moving else 0.0, delta * 4.0
	)
	_bob_phase += delta * tuning.bob_frequency * TAU * clampf(hspeed / tuning.walk_speed, 0.5, 1.6)
	var bob: Vector2 = Vector2(cos(_bob_phase * 0.5), absf(sin(_bob_phase * 0.5)) - 0.5) * tuning.bob_amplitude
	bob *= _bob_weight * bob_scale
	var local_vel: Vector3 = Basis(Vector3.UP, yaw).inverse() * body.velocity
	var tilt_target: float = -clampf(local_vel.x / tuning.walk_speed, -1.0, 1.0) * deg_to_rad(tuning.strafe_tilt_deg)
	if motor.stance == MotorComponent.Stance.SLIDE:
		tilt_target += deg_to_rad(3.0)
	_tilt = lerpf(_tilt, tilt_target * bob_scale, clampf(delta * 8.0, 0.0, 1.0))
	var kick: float = tuning.sprint_fov_kick if motor.sprinting or motor.stance == MotorComponent.Stance.SLIDE else 0.0
	_fov_kick = lerpf(_fov_kick, kick, clampf(delta * tuning.fov_lerp_speed, 0.0, 1.0))
	camera.fov = clampf(float(Config.get_value(&"video", &"fov", 90.0)), 70.0, 110.0) + _fov_kick
	# Trauma shake: angle offsets proportional to trauma², smooth noise.
	trauma = maxf(trauma - tuning.shake_decay * delta, 0.0)
	_noise_t += delta * 30.0
	var shake: float = trauma * trauma * deg_to_rad(tuning.shake_max_angle_deg) * shake_scale
	var sx: float = _noise.get_noise_2d(_noise_t, 0.0) * shake
	var sy: float = _noise.get_noise_2d(0.0, _noise_t) * shake
	var sz: float = _noise.get_noise_2d(_noise_t, _noise_t) * shake
	var origin: Vector3 = body.get_global_transform_interpolated().origin
	if motor.stance == MotorComponent.Stance.MANTLE:
		origin = body.global_position
	var basis: Basis = Basis.from_euler(Vector3(pitch + sx, yaw + sy, _tilt + sz), EULER_ORDER_YXZ)
	var head: Vector3 = origin + Vector3(0.0, eye_height + _step_offset + _dip + bob.y, 0.0)
	head += Basis(Vector3.UP, yaw) * Vector3(bob.x, 0.0, 0.0)
	camera.global_transform = Transform3D(basis, head)
	position = Vector3(0.0, eye_height, 0.0)
