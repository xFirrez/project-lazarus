# AC-3.2: reload state machine edge cases — cancel before / after the ammo-in point, reload with an
# empty reserve, swap during reload, sprint during reload, melee interrupt, per-shell reloads.
extends GutTest

const DT: float = 1.0 / 60.0


func _rt(wid: StringName) -> WeaponRuntime:
	var rt: WeaponRuntime = WeaponRuntime.new(WeaponCatalog.get_def(wid))
	rt.make_ready()
	return rt


func _run(rt: WeaponRuntime, seconds: float, trigger: bool = false, sprint: bool = false) -> void:
	for i: int in roundi(seconds / DT):
		rt.update(DT, trigger, false, sprint)


func test_partial_reload_timing() -> void:
	var rt: WeaponRuntime = _rt(&"mp40")
	rt.mag = 10
	assert_true(rt.start_reload())
	_run(rt, rt.def.ammo_in_partial - 0.05)
	assert_eq(rt.mag, 10, "no ammo before the ammo-in point")
	_run(rt, 0.1)
	assert_eq(rt.mag, 32, "mag refilled at ammo-in")
	assert_eq(rt.reserve, 192 - 22)
	assert_eq(rt.state, WeaponRuntime.State.RELOADING, "still finishing the animation")
	_run(rt, rt.def.reload_partial_time - rt.def.ammo_in_partial)
	assert_eq(rt.state, WeaponRuntime.State.IDLE)


func test_empty_reload_is_longer() -> void:
	var rt: WeaponRuntime = _rt(&"m1911")
	rt.mag = 0
	rt.start_reload()
	assert_true(rt.reload_empty)
	_run(rt, rt.def.ammo_in_partial + 0.02)
	assert_eq(rt.mag, 0, "empty reload's ammo-in is later than the partial one")
	_run(rt, rt.def.ammo_in_empty - rt.def.ammo_in_partial)
	assert_eq(rt.mag, 8)
	_run(rt, rt.def.reload_empty_time - rt.def.ammo_in_empty + 0.02)
	assert_eq(rt.state, WeaponRuntime.State.IDLE)


func test_cancel_before_ammo_in_keeps_nothing() -> void:
	var rt: WeaponRuntime = _rt(&"mp40")
	rt.mag = 5
	rt.start_reload()
	_run(rt, 0.5)
	assert_false(rt.cancel_reload(), "cancel reports no ammo kept")
	assert_eq(rt.mag, 5)
	assert_eq(rt.reserve, 192)
	assert_eq(rt.state, WeaponRuntime.State.IDLE)


func test_cancel_after_ammo_in_keeps_ammo() -> void:
	var rt: WeaponRuntime = _rt(&"mp40")
	rt.mag = 5
	rt.start_reload()
	_run(rt, rt.def.ammo_in_partial + 0.05)
	assert_true(rt.cancel_reload())
	assert_eq(rt.mag, 32)
	assert_eq(rt.reserve, 192 - 27)


func test_reload_with_empty_reserve_does_not_start() -> void:
	var rt: WeaponRuntime = _rt(&"m1911")
	rt.mag = 3
	rt.reserve = 0
	assert_false(rt.start_reload())
	assert_eq(rt.state, WeaponRuntime.State.IDLE)


func test_reload_with_full_mag_does_not_start() -> void:
	assert_false(_rt(&"m1911").start_reload())


func test_partial_reserve_fills_what_it_can() -> void:
	var rt: WeaponRuntime = _rt(&"mp40")
	rt.mag = 2
	rt.reserve = 7
	rt.start_reload()
	_run(rt, rt.def.reload_partial_time + 0.05)
	assert_eq(rt.mag, 9)
	assert_eq(rt.reserve, 0)


func test_swap_during_reload_before_ammo_in() -> void:
	var inv: WeaponInventory = WeaponInventory.new()
	inv.set_loadout([&"m1911", &"mp40"], WeaponCatalog.get_def, &"mp40")
	var mp40: WeaponRuntime = inv.held()
	mp40.make_ready()
	mp40.mag = 4
	mp40.start_reload()
	for i: int in 20:
		mp40.update(DT, false, false, false)
	assert_true(inv.switch_to(0))
	assert_eq(mp40.state, WeaponRuntime.State.LOWERING, "swap cancels the reload and lowers")
	assert_eq(mp40.mag, 4, "cancelled before ammo-in: nothing added")
	for i: int in 60:
		inv.held().update(DT, false, false, false)
		inv.update()
	assert_eq(inv.held().def.id, &"m1911")
	assert_eq(inv.held().state, WeaponRuntime.State.IDLE, "raised after the M1911 raise time")


func test_swap_during_reload_after_ammo_in() -> void:
	var inv: WeaponInventory = WeaponInventory.new()
	inv.set_loadout([&"m1911", &"mp40"], WeaponCatalog.get_def, &"mp40")
	var mp40: WeaponRuntime = inv.held()
	mp40.make_ready()
	mp40.mag = 4
	mp40.start_reload()
	for i: int in roundi((mp40.def.ammo_in_partial + 0.05) / DT):
		mp40.update(DT, false, false, false)
	inv.switch_to(0)
	assert_eq(mp40.mag, 32, "ammo-in passed: the swap keeps the full magazine")


func test_sprint_during_reload_continues() -> void:
	var rt: WeaponRuntime = _rt(&"mp40")
	rt.mag = 0
	rt.start_reload()
	_run(rt, 0.4, false, true)
	assert_eq(rt.state, WeaponRuntime.State.RELOADING, "sprinting does not cancel the reload")
	_run(rt, rt.def.reload_empty_time, false, true)
	assert_eq(rt.mag, 32, "reload completed while sprinting")
	assert_eq(rt.state, WeaponRuntime.State.SPRINT, "then the sprint pose")
	assert_eq(rt.update(DT, true, false, true), 0, "sprinting blocks fire")
	rt.update(DT, true, false, false)
	assert_eq(rt.state, WeaponRuntime.State.IDLE)
	var shots: int = 0
	var frames: int = 0
	while shots == 0 and frames < 60:
		shots += rt.update(DT, true, false, false)
		frames += 1
	assert_almost_eq(frames * DT, rt.def.sprint_out_time, DT * 1.5, "sprint-out delay before the first shot")


func test_melee_interrupts_reload() -> void:
	var rt: WeaponRuntime = _rt(&"mp40")
	rt.mag = 3
	rt.start_reload()
	_run(rt, 0.3)
	assert_true(rt.start_melee(0.45))
	assert_eq(rt.mag, 3, "melee before ammo-in: no ammo")
	assert_eq(rt.state, WeaponRuntime.State.MELEE)
	assert_eq(rt.update(DT, true, false, false), 0, "no fire during melee")
	_run(rt, 0.5)
	assert_eq(rt.state, WeaponRuntime.State.IDLE, "back to idle; reload must be restarted")


func test_fire_blocked_while_raising() -> void:
	var rt: WeaponRuntime = WeaponRuntime.new(WeaponCatalog.get_def(&"mp40"))
	rt.raise()
	assert_eq(rt.update(DT, true, false, false), 0)
	_run(rt, rt.def.raise_time + 0.02, true)
	assert_eq(rt.state, WeaponRuntime.State.IDLE)


func test_ads_blend_time() -> void:
	var rt: WeaponRuntime = _rt(&"kar98k")
	var frames: int = 0
	while rt.ads < 1.0 and frames < 120:
		rt.update(DT, false, true, false)
		frames += 1
	assert_almost_eq(frames * DT, rt.def.ads_time, DT * 1.5)
	rt.update(DT, false, true, true)
	assert_true(rt.ads < 1.0, "sprint drops ADS")


func test_shell_reload_inserts_one_at_a_time() -> void:
	var rt: WeaponRuntime = _rt(&"model37")
	rt.mag = 2
	rt.start_reload()
	var d: WeaponDefinition = rt.def
	_run(rt, d.reload_start_time + d.shell_insert_time + 0.02)
	assert_eq(rt.mag, 3, "first shell after start + insert time")
	_run(rt, d.shell_insert_time)
	assert_eq(rt.mag, 4)
	_run(rt, d.shell_insert_time * 2.0 + d.reload_end_time + 0.05)
	assert_eq(rt.mag, 6)
	assert_eq(rt.reserve, 50)
	assert_eq(rt.state, WeaponRuntime.State.IDLE)
	assert_almost_eq(d.reload_start_time + 4 * d.shell_insert_time + d.reload_end_time, 2.85, 0.001)


func test_shell_reload_stops_on_trigger() -> void:
	var rt: WeaponRuntime = _rt(&"model37")
	rt.mag = 1
	rt.start_reload()
	var d: WeaponDefinition = rt.def
	_run(rt, d.reload_start_time + d.shell_insert_time * 1.5)
	assert_eq(rt.mag, 2)
	rt.update(DT, true, false, false)  # pull the trigger mid-insert
	_run(rt, d.reload_end_time + 0.05)
	assert_eq(rt.mag, 2, "the shell in hand is dropped")
	assert_eq(rt.state, WeaponRuntime.State.IDLE)
	var shots: int = 0
	for i: int in 10:
		shots += rt.update(DT, i % 2 == 0, false, false)
	assert_eq(shots, 1, "can fire right after")


func test_cancel_shell_reload_keeps_inserted_shells() -> void:
	var rt: WeaponRuntime = _rt(&"model37")
	rt.mag = 0
	rt.start_reload()
	_run(rt, rt.def.reload_start_time + rt.def.shell_insert_time * 2.0 + 0.05)
	assert_true(rt.cancel_reload())
	assert_eq(rt.mag, 2)
