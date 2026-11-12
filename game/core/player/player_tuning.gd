# PlayerTuning — every movement / camera / health number for the player in one resource
# (GAME_DESIGN §3.1, §3.2). Live-editable with the console `tune <param> <value>` command.
# Authority: data, identical on every peer. The host's copy drives movement validation.
class_name PlayerTuning
extends Resource

@export var id: StringName = &"default"

@export_group("Ground")
@export var walk_speed: float = 4.6
@export var sprint_speed: float = 6.6
@export var crouch_speed: float = 2.4
@export var ground_accel: float = 45.0
@export var friction: float = 9.0
@export var stop_speed: float = 1.5

@export_group("Sprint")
@export var sprint_duration: float = 4.0
@export var sprint_recharge_time: float = 3.0
@export var sprint_recharge_delay: float = 0.8
@export var sprint_min_forward: float = 0.5
@export var sprint_restart_fraction: float = 0.1

@export_group("Crouch / slide")
@export var stand_height: float = 1.8
@export var crouch_height: float = 1.1
@export var capsule_radius: float = 0.35
@export var crouch_transition: float = 0.15
@export var slide_duration: float = 0.7
@export var slide_start_speed: float = 7.5
@export var slide_end_speed: float = 3.0
@export var slide_cooldown: float = 1.0
@export var slide_steer: float = 2.0

@export_group("Air")
@export var gravity: float = 20.0
@export var jump_apex: float = 1.0
@export var air_accel: float = 8.0
@export var coyote_time: float = 0.1
@export var jump_buffer: float = 0.12

@export_group("Traversal")
@export var step_height: float = 0.35
@export var floor_max_angle_deg: float = 46.0
@export var mantle_max_height: float = 1.2
@export var mantle_min_height: float = 0.36
@export var mantle_reach: float = 0.7
@export var mantle_duration: float = 0.32

@export_group("Camera")
@export var eye_height_stand: float = 1.62
@export var eye_height_crouch: float = 0.95
@export var eye_height_slide: float = 0.8
@export var sprint_fov_kick: float = 5.0
@export var fov_lerp_speed: float = 10.0
@export var bob_frequency: float = 1.8
@export var bob_amplitude: float = 0.045
@export var strafe_tilt_deg: float = 1.2
@export var landing_dip_per_mps: float = 0.012
@export var landing_dip_max: float = 0.14
@export var step_smooth_speed: float = 14.0
@export var pitch_limit_deg: float = 89.0
@export var shake_decay: float = 1.6
@export var shake_max_angle_deg: float = 3.0
@export var mouse_scale: float = 0.0022
@export var gamepad_look_speed_deg: float = 220.0
@export var gamepad_deadzone: float = 0.15
@export var gamepad_curve: float = 2.0

@export_group("Health")
@export var max_health: float = 100.0
@export var regen_delay: float = 3.0
@export var regen_rate: float = 100.0
@export var low_health_fraction: float = 0.5
@export var fall_damage_min_height: float = 5.0
@export var fall_damage_max_height: float = 10.0
@export var fall_damage_max: float = 50.0

@export_group("Downed (GAME_DESIGN §3.3)")
@export var downed_crawl_speed: float = 1.2
@export var eye_height_downed: float = 0.55
@export var bleedout_time: float = 45.0
@export var revive_time: float = 4.0
@export var revive_radius: float = 2.0
@export var revive_health_fraction: float = 0.5

@export_group("Net validation (host)")
@export var validation_max_horizontal_speed: float = 10.5
@export var validation_max_vertical_up_speed: float = 12.0
@export var validation_teleport_distance: float = 4.0
@export var validation_slack: float = 1.5


func jump_velocity() -> float:
	return sqrt(2.0 * gravity * jump_apex)


func fall_damage(height: float) -> float:
	if height <= fall_damage_min_height:
		return 0.0
	var t: float = clampf(
		(height - fall_damage_min_height) / maxf(fall_damage_max_height - fall_damage_min_height, 0.01), 0.0, 1.0
	)
	return roundf(t * fall_damage_max)


# Names of tunable float properties (for `tune` autocomplete and listing).
func tunable_names() -> PackedStringArray:
	var out: PackedStringArray = []
	for prop: Dictionary in get_property_list():
		if int(prop["type"]) == TYPE_FLOAT and (int(prop["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE) != 0:
			out.append(String(prop["name"]))
	return out
