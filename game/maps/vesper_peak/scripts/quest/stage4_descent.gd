# Stage 4 "The Descent" (escort): carry the Heart (CarryItem: walk speed, no sprint, pistol only,
# glows, zombies prioritise the carrier; drop / pass with X; auto-dropped when downed) from the Labs
# to the core socket on the Reactor Lower Ring within ESCORT_TIME, through the Maintenance Network:
# the Reactor Bridge locks for the escort ("the Choir is watching the bridge"), spawns run x1.5 and
# every spawner in Z09 / Z10 / Z13 is active. The timer starts at the first pick-up.
# Failure (timer expires): the Heart returns to the pod (souls kept) and can be taken again from the
# next round start.
# Authority: HOST.
extends RequiemObjective

const ESCORT_TIME: float = 240.0
const SPAWN_SCALE: float = 1.5
const ZONES: Array[StringName] = [&"Z09", &"Z10", &"Z13"]

var failures: int = 0
var _shown: int = -1


func heart() -> CarryItem:
	return world().heart


func running() -> bool:
	return float(get_flag("ee.escort_until", 0.0)) > 0.0


func on_activate() -> void:
	if not heart().is_present() and not running():
		heart().host_set_present(true)
	if running():
		_apply(true)  # host rebuilt mid-escort


func on_event(event: StringName, data: Dictionary) -> void:
	match event:
		&"carry":
			if data.get("item", &"") == &"heart" and data.get("event", &"") == &"picked" and not running():
				_start()
		&"interact":
			if data.get("id", &"") == &"socket" and heart().carrier() == int(data.get("peer", -1)):
				_socket()
		&"round_started":
			if not heart().is_present() and not running():
				heart().host_reset()
				heart().host_set_present(true)


func _start() -> void:
	set_flag("ee.escort_until", now() + ESCORT_TIME)
	_apply(true)
	vo(&"vo_escort_start")
	log_info("Escort started (%d s)" % int(ESCORT_TIME))


func _apply(on: bool) -> void:
	var sd: SpawnDirector = m().spawns
	if sd != null:
		sd.rate_scale = SPAWN_SCALE if on else 1.0
		sd.extra_zones = ZONES.duplicate() if on else ([] as Array[StringName])
	bridge(not on and bool(get_flag(RelaySystem.FLAG_DONE, false)))
	if not on:
		set_flag("qhud.escort", "")


func on_tick(_delta: float) -> void:
	if not running():
		return
	var left: float = float(get_flag("ee.escort_until", 0.0)) - now()
	var secs: int = maxi(int(ceil(left)), 0)
	if secs != _shown:
		_shown = secs
		set_flag("qhud.escort", "The Heart  %d:%02d" % [secs / 60, secs % 60])
	if left <= 0.0:
		fail()


func fail() -> void:
	failures += 1
	set_flag("ee.escort_until", 0.0)
	_apply(false)
	heart().host_set_present(false)  # back in the pod; available again next round
	heart().host_reset()
	Audio.play_event(&"quest_fail")
	vo(&"vo_escort_fail")
	log_info("Escort failed (%d)" % failures)


func _socket() -> void:
	set_flag("ee.escort_until", 0.0)
	_apply(false)
	heart().host_set_present(false)
	set_flag("ee.heart_socketed", true)
	vo(&"vo_socket", marker_pos(&"EE_CoreSocket") + Vector3.UP)
	complete()


func on_debug_complete() -> void:
	_socket()
