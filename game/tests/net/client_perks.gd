# Client side of the Vigor Tonic / power-up net test (see host_perks.gd): buys Quickdraw (drink
# played, reload halved locally), revives the host with Second Wind, picks power-ups up, reports
# its host-clock estimate and checks the replicated timer flag, the Max Ammo refill and perk loss.
extends "res://tests/net/autotest_base.gd"

var _picked: Array = []
var _drained: Array = []  # [weapon id]


func _ready() -> void:
	timeout = 150.0
	Net.register_message(&"_t_use", _on_use)
	Net.register_message(&"_t_check_perks", _on_check_perks)
	Net.register_message(&"_t_revive", _on_revive)
	Net.register_message(&"_t_drain", _on_drain)
	Net.register_message(&"_t_pu_check", _on_pu_check)
	Net.register_message(&"_t_lost", _on_lost)
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
	m.powerups.picked.connect(func(_id: int, type: StringName, _peer: int) -> void: _picked.append(type))
	check("seven_machines", m.perks.machines.size() == 7)


func _on_use(_sender: int, p: Array) -> void:
	var m: Match = _m()
	m.interaction.request(m.players.local_avatar(), m.interaction.get_by_id(int(p[0])))


func _on_check_perks(_sender: int, p: Array) -> void:
	var me: PlayerCharacter = _m().players.local_avatar()
	check("perks_replicated", PerkSystem._strings(me.perk_holder.ids) == (p[0] as Array), me.perk_holder.ids)
	check("drink_played", me.weapons.drinks >= 1, me.weapons.drinks)
	var rt: WeaponRuntime = me.weapons.held()
	var base: WeaponRuntime = WeaponRuntime.new(rt.def)
	base.mag = rt.mag
	base.reserve = rt.reserve
	check("reload_halved_locally", absf(rt.total_reload_time() - base.total_reload_time() * 0.5) < 0.01)


func _on_revive(_sender: int, p: Array) -> void:
	var m: Match = _m()
	var me: PlayerCharacter = m.players.local_avatar()
	if bool(p[1]):
		check("revive_time_2s_client", is_equal_approx(m.downed.revive_time_for(me.peer_id), 2.0))
	m.downed._send_revive(me.peer_id, int(p[0]), bool(p[1]))


# Empty the held weapon's reserve (host mirror follows through the reload report).
func _on_drain(_sender: int, _p: Array) -> void:
	var me: PlayerCharacter = _m().players.local_avatar()
	var rt: WeaponRuntime = me.weapons.held()
	rt.reserve = 0
	WeaponSync.submit_reload(me.weapons, rt.def, rt.mag, 0)
	_drained = [rt.def.id, rt.mag]


func _on_pu_check(_sender: int, p: Array) -> void:
	var m: Match = _m()
	var me: PlayerCharacter = m.players.local_avatar()
	check("saw_pickups", _picked.has(&"max_ammo") and _picked.has(&"insta_kill"), _picked)
	check("drops_removed", m.powerups.drops.is_empty(), m.powerups.drops.size())
	if not _drained.is_empty():
		var rt: WeaponRuntime = me.weapons.inventory.slots[me.weapons.inventory.slot_of(_drained[0])]
		check(
			"max_ammo_reserve_refilled",
			rt.reserve == rt.def.reserve_max and rt.mag == int(_drained[1]),
			[rt.mag, rt.reserve]
		)
	var until: float = float(m.session.flag(PowerUpSystem.flag_key(&"insta_kill"), -2.0))
	check("timer_flag_identical", is_equal_approx(until, float(p[0])), [until, p[0]])
	check("timer_running", m.powerups.time_left(&"insta_kill") > 25.0, m.powerups.time_left(&"insta_kill"))
	for i: int in 12:
		Net.send_reliable(1, &"_t_clock_r", [Net.host_time(), Net.rtt_ms() / 1000.0])
		await get_tree().create_timer(0.1).timeout


func _on_lost(_sender: int, _p: Array) -> void:
	var me: PlayerCharacter = _m().players.local_avatar()
	check("perks_lost_client", me.perk_holder.ids.is_empty() and _m().perks.ids_of(me.peer_id).is_empty())
	Net.send_reliable(1, &"_t_cdone", [])
	await get_tree().create_timer(0.5).timeout
	finish(true)
