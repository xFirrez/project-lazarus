# Secret — five frozen ravens around the exterior (VESPER_PEAK §7.2): shoot all five in one match ->
# a Double Points + Max Ammo pair appears by the Courtyard fountain.
# Authority: HOST.
extends RequiemObjective

const REWARD_AT: Vector3 = Vector3(28.0, -8.0, -43.5)


func on_event(event: StringName, data: Dictionary) -> void:
	if event != &"damaged":
		return
	var id: String = String(data.get("id", ""))
	if not id.begins_with("raven_"):
		return
	set_flag("ee.raven.%s" % id.trim_prefix("raven_"), true)
	if count() == 5:
		_reward()


func count() -> int:
	var n: int = 0
	for i: int in 5:
		n += int(bool(get_flag("ee.raven.%d" % (i + 1), false)))
	return n


func _reward() -> void:
	if m().powerups != null:
		for e: Array in [[&"double_points", Vector3(-1.2, 0, 0)], [&"max_ammo", Vector3(1.2, 0, 0)]]:
			var p: Vector3 = m().powerups.drop_position(REWARD_AT + (e[1] as Vector3))
			m().powerups.host_spawn(e[0], p if p.is_finite() else REWARD_AT + (e[1] as Vector3))
	log_info("All five ravens: Double Points + Max Ammo")
	complete()


func on_debug_complete() -> void:
	for i: int in 5:
		set_flag("ee.raven.%d" % (i + 1), true)
	_reward()
