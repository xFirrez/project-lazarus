# Stage 3 "Charging the Heart" (Containment Labs): place the shards in the Soul Containment Pod, then
# feed it souls — zombies killed within SOUL_RADIUS of the pod by the Lazarus Conduit (either form).
# Required: 30 + 10 x (players - 1). At 1/3 and 2/3 of the charge a vesperite surge knocks one of
# the pod's two cables loose (alarm); charging pauses until a player reseats it (hold 2 s).
# Complete: the Heart is charged and waits on the pod (CarryItem "heart").
# Authority: HOST.
extends RequiemObjective

const SOUL_RADIUS: float = 10.0

var paused_kills: int = 0  # host (tests): Conduit kills while a cable was loose


func needed() -> int:
	return int(scaled(30.0, 10.0))


func on_activate() -> void:
	set_flag("ee.souls_needed", needed())


func on_event(event: StringName, data: Dictionary) -> void:
	match event:
		&"interact":
			var id: String = String(data.get("id", ""))
			if id == "pod" and not bool(get_flag("ee.pod_shards", false)) and shard_count(quest) == 3:
				set_flag("ee.pod_shards", true)
				set_flag("ee.souls", 0)
				update_shard_hud(quest)
				vo(&"vo_pod_start", marker_pos(&"EE_SoulPod") + Vector3.UP)
			elif id.begins_with("cable_") and bool(get_flag("ee.%s" % id.replace("_", "."), false)):
				set_flag("ee.%s" % id.replace("_", "."), false)
		&"zombie_killed":
			if not bool(get_flag("ee.pod_shards", false)):
				return
			if not String(data.get("weapon", "")).begins_with(CONDUIT_PREFIX):
				return
			var p: Vector3 = data.get("position", Vector3.INF)
			if p.distance_to(marker_pos(&"EE_SoulPod")) > SOUL_RADIUS:
				return
			if cable_loose():
				paused_kills += 1
				return
			add_soul()


func cable_loose() -> bool:
	return bool(get_flag("ee.cable.1", false)) or bool(get_flag("ee.cable.2", false))


func add_soul() -> void:
	var s: int = int(get_flag("ee.souls", 0)) + 1
	var need: int = needed()
	set_flag("ee.souls", s)
	set_flag("ee.souls_needed", need)
	for k: int in 2:
		var at: int = int(ceil(need * (k + 1) / 3.0))
		if s == at and not bool(get_flag("ee.surge.%d" % (k + 1), false)):
			set_flag("ee.surge.%d" % (k + 1), true)
			set_flag("ee.cable.%d" % (k + 1), true)
			vo(&"vo_cable", marker_pos(&"EE_SoulPod") + Vector3.UP)
	if s >= need:
		_charged()


func _charged() -> void:
	set_flag("ee.heart_charged", true)
	world().heart.host_reset()
	world().heart.host_set_present(true)
	vo(&"vo_pod_done", marker_pos(&"EE_SoulPod") + Vector3.UP)
	complete()


func on_debug_complete() -> void:
	set_flag("ee.pod_shards", true)
	update_shard_hud(quest)
	set_flag("ee.cable.1", false)
	set_flag("ee.cable.2", false)
	set_flag("ee.souls", needed())
	_charged()
