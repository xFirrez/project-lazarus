# Stage 2b "The Chained Drawer" (Morgue): four luminous symbols I-IV (visible only while the lab
# breaker H3 is on) give the order of the four glyph drawers ("ee.drawer_order", host-seeded). Each
# pull: a corpse falls out and may rise (RISE_CHANCE). The right order opens the chained drawer
# (shard inside); a wrong pull bursts 4 drawer-zombies and resets the sequence.
# Authority: HOST.
extends RequiemObjective

const RISE_CHANCE: float = 0.3
const WRONG_ZOMBIES: int = 4

var wrong_count: int = 0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


static func order_for(seed_value: int) -> Array:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value * 104729 + 7
	var o: Array = [0, 1, 2, 3]
	for i: int in range(3, 0, -1):
		var j: int = rng.randi_range(0, i)
		var t: Variant = o[i]
		o[i] = o[j]
		o[j] = t
	return o


func on_activate() -> void:
	_rng.randomize()
	if get_flag("ee.drawer_order", null) == null:
		set_flag("ee.drawer_order", order_for(int(get_flag("special_seed", 0))))
	if get_flag("ee.drawer_step", null) == null:
		set_flag("ee.drawer_step", 0)


func on_event(event: StringName, data: Dictionary) -> void:
	if event != &"interact":
		return
	var id: String = String(data.get("id", ""))
	if id.begins_with("drawer_") and not bool(get_flag("ee.chain_open", false)):
		pull(int(id.trim_prefix("drawer_")))
	elif id == "shard_b" and int(get_flag("ee.shard.b", 0)) == 1:
		collect_shard("b")
		complete()


func pull(glyph: int) -> bool:
	var order: Array = get_flag("ee.drawer_order", [0, 1, 2, 3])
	var step_i: int = int(get_flag("ee.drawer_step", 0))
	var at: Vector3 = marker_pos(&"EE_MorgueDrawers") + Vector3(-1.5 + glyph, -1.3, 1.2)
	if int(order[step_i]) != glyph:
		wrong_count += 1
		set_flag("ee.drawer_step", 0)
		spawn_zombies(at, WRONG_ZOMBIES)
		vo(&"vo_drawers_wrong", at)
		log_info("Wrong drawer (%d)" % wrong_count)
		return false
	if _rng.randf() < RISE_CHANCE:
		spawn_zombies(at, 1)
	step_i += 1
	set_flag("ee.drawer_step", step_i)
	if step_i >= 4:
		_open()
	return true


func _open() -> void:
	set_flag("ee.chain_open", true)
	set_flag("ee.shard.b", 1)
	log_info("The chained drawer opens")


func on_debug_complete() -> void:
	_open()
	collect_shard("b")
	complete()
