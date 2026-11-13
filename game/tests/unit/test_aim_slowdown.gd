# Gamepad aim slowdown (Step 16, GAME_DESIGN §18 "light slowdown"): the stick look rate drops to
# PlayerInputSource.AIM_SLOWDOWN while the crosshair is on an enemy, only if the setting is on.
extends GutTest

var _saved: Variant = null


func before_each() -> void:
	_saved = Config.get_value(&"input", &"aim_slowdown", true)


func after_each() -> void:
	Input.action_release(&"look_right")
	Config.set_value(&"input", &"aim_slowdown", _saved)


func _look(on_target: bool) -> float:
	var src: PlayerInputSource = PlayerInputSource.new(load("res://content/player/player_tuning.tres") as PlayerTuning)
	src.aim_probe = func() -> bool: return on_target
	Input.action_press(&"look_right", 1.0)
	return absf(src.consume_look(0.016).x)


func test_slowdown_on_target() -> void:
	Config.set_value(&"input", &"aim_slowdown", true)
	var free_rate: float = _look(false)
	var target_rate: float = _look(true)
	assert_gt(free_rate, 0.0)
	assert_almost_eq(target_rate / free_rate, PlayerInputSource.AIM_SLOWDOWN, 0.001)


func test_setting_off_disables_it() -> void:
	Config.set_value(&"input", &"aim_slowdown", false)
	assert_almost_eq(_look(true), _look(false), 0.00001)
