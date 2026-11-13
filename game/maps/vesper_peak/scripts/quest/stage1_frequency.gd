# Stage 1 "The Frequency": tune the three radio dials to the annotated digits and transmit. Right ->
# Dr. Varga makes contact (VO) and the stage completes; wrong -> piercing static and 3 zombies burst
# from the radio building door (retry at once; dials keep their values).
# Authority: HOST.
extends RequiemObjective

const WRONG_COOLDOWN: float = 4.0

var wrong_count: int = 0
var _next_try: float = 0.0


func on_activate() -> void:
	for i: int in 3:
		if get_flag("ee.dial.%d" % (i + 1), null) == null:
			set_flag("ee.dial.%d" % (i + 1), 0)


func on_event(event: StringName, data: Dictionary) -> void:
	if event != &"interact":
		return
	var id: String = String(data.get("id", ""))
	if id.begins_with("radio_dial_"):
		var k: String = "ee.dial.%s" % id.trim_prefix("radio_dial_")
		set_flag(k, (int(get_flag(k, 0)) + 1) % 100)
	elif id == "radio_tx":
		transmit()


func answer() -> Array:
	return get_flag("ee.freq", [0, 0, 0])


func transmit() -> bool:
	if now() < _next_try:
		return false
	var ans: Array = answer()
	var ok: bool = true
	for i: int in 3:
		ok = ok and int(get_flag("ee.dial.%d" % (i + 1), 0)) == int(ans[i])
	var at: Vector3 = marker_pos(&"EE_RadioConsole")
	if ok:
		vo(&"vo_contact", at + Vector3.UP)
		Audio.play_event_3d(&"radio_contact", at)
		set_flag("ee.contact", true)
		update_shard_hud(quest)
		complete()
		update_shard_hud(quest)
		return true
	wrong_count += 1
	_next_try = now() + WRONG_COOLDOWN
	vo(&"vo_wrong", at + Vector3.UP)
	# The radio building's door is south of the console (Z07 radio room, z -107.5 -> -104).
	spawn_zombies(at + Vector3(0, 0, 3.5), 3)
	log_info("Wrong frequency (%d)" % wrong_count)
	return false


func on_debug_complete() -> void:
	var ans: Array = answer()
	for i: int in 3:
		set_flag("ee.dial.%d" % (i + 1), int(ans[i]))
	transmit()
	if is_active():
		complete()
