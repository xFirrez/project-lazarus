# Stage 0 "The Mountain Stirs" (VESPER_PEAK §7): power on + all three Resonance Relays; on the next
# round start the Comms Array radio begins broadcasting (map-wide faint VO) and becomes usable. The
# three frequency documents (random 3 of L04 / L06 / L08 / L09 / L10 / L12, host-seeded) now carry a
# red annotation: dial number + two digits ("ee.freq", "lore.note.<doc>").
# Authority: HOST.
extends RequiemObjective

const POOL: Array[StringName] = [&"L04", &"L06", &"L08", &"L09", &"L10", &"L12"]

var _armed: bool = false


func on_activate() -> void:
	_armed = bool(get_flag(RelaySystem.FLAG_DONE, false))


func on_event(event: StringName, data: Dictionary) -> void:
	if event == &"flag" and String(data.get("key", "")) == RelaySystem.FLAG_DONE and bool(data.get("value", false)):
		_armed = true
	elif event == &"round_started" and _armed and Power.is_on():
		_begin()


func on_debug_complete() -> void:
	_begin()


func _begin() -> void:
	if is_active():
		choose_frequency(quest, int(get_flag("special_seed", 0)))
		set_flag("ee.radio_live", true)
		vo(&"vo_broadcast")
		log_info("The radio wakes")
		complete()


# Host: picks the three documents and digits for a seed (deterministic; unit-tested).
static func pick(seed_value: int) -> Array:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value * 7919 + 13
	var pool: Array[StringName] = POOL.duplicate()
	var docs: Array = []
	var digits: Array = []
	for i: int in 3:
		var k: int = rng.randi_range(0, pool.size() - 1)
		docs.append(String(pool[k]))
		pool.remove_at(k)
		digits.append(rng.randi_range(10, 99))
	return [docs, digits]


static func choose_frequency(q: QuestSystem, seed_value: int) -> void:
	var p: Array = pick(seed_value)
	q.host_set("ee.freq_docs", p[0])
	q.host_set("ee.freq", p[1])
	for i: int in 3:
		q.host_set("lore.note.%s" % p[0][i], "%s — %02d" % [VesperQuestWorld.ROMAN[i], int(p[1][i])])
