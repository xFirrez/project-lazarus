# Client side of the Relic Box net test (see host_box.gd): late-join box location, own spin, the
# replicated carousel identical to the host's and ending on the result, taking the weapon, the doll
# relocation and the Fire Sale on this peer.
extends "res://tests/net/autotest_base.gd"


func _ready() -> void:
	timeout = 120.0
	Net.register_message(&"_t_use", _on_use)
	Net.register_message(&"_t_carousel", _on_carousel)
	Net.register_message(&"_t_loc", _on_loc)
	Net.register_message(&"_t_firesale", _on_firesale)
	_run()


func _m() -> Match:
	return Match.current


func _until(cond: Callable, limit: float) -> bool:
	var t0: float = elapsed()
	while not cond.call():
		if elapsed() - t0 > limit:
			return false
		await get_tree().physics_frame
	return true


func _run() -> void:
	await _until(func() -> bool: return _m() != null and _m().players.local_avatar() != null, 30.0)
	var m: Match = _m()
	m.downed.show_screen = false
	await _until(func() -> bool: return m.box.current_index() == m.box.index_of(&"Box_Z07"), 5.0)
	check("late_join_box_location", String(m.box.boxes[m.box.current_index()].location_id) == "Box_Z07")


func _on_use(_sender: int, p: Array) -> void:
	var m: Match = _m()
	m.interaction.request(m.players.local_avatar(), m.interaction.get_by_id(int(p[0])))


func _on_carousel(_sender: int, p: Array) -> void:
	var m: Match = _m()
	var loc: int = int(p[0])
	var ok: bool = await _until(func() -> bool: return not m.box.spin_of(loc).is_empty(), 5.0)
	check("spin_replicated", ok)
	var mine: Array = []
	for t: float in [0.2, 0.7, 1.3, 2.0, 2.8, 3.6, 4.2, 4.6]:
		mine.append(String(m.box.carousel_item(loc, t)))
	check("carousel_matches_host", mine == (p[1] as Array), [mine, p[1]])
	var result: String = String(m.box.spin_of(loc)[1])
	check("carousel_ends_on_result", mine[mine.size() - 1] == result and result == "ak47", result)
	var shown: bool = await _until(
		func() -> bool: return m.box.boxes[loc].shown_item == StringName(result), m.box.pool.spin_time + 2.0
	)
	check("box_shows_result", shown, m.box.boxes[loc].shown_item)
	var me: PlayerCharacter = m.players.local_avatar()
	var got: bool = await _until(func() -> bool: return me.weapons.inventory.slot_of(&"ak47") >= 0, 15.0)
	check("took_ak47_locally", got)


func _on_loc(_sender: int, p: Array) -> void:
	var m: Match = _m()
	var here: String = String(m.box.boxes[m.box.current_index()].location_id)
	check("doll_relocation_matches", here == String(p[0]) and here != "Box_Z07", [here, p[0]])
	check("box_present_after_move", m.box.is_present(m.box.current_index()))


func _on_firesale(_sender: int, _p: Array) -> void:
	var m: Match = _m()
	var all: bool = true
	for b: RelicBox in m.box.boxes:
		all = all and m.box.is_present(b.index)
	check("fire_sale_all_present", all)
	Net.send_reliable(1, &"_t_cdone", [])
	await get_tree().create_timer(0.5).timeout
	finish(true)
