# perks (Step 10: AC-10.1 in the real game, AC-10.2, solo part of AC-10.4) — solo vesper_peak:
#  1. Machines: 7 PerkMachines on the perk markers; without power Quickdraw is refused ("Requires
#     power") while Second Wind sells for 500; the drink lowers the weapon for 3 s and the perk is
#     granted at the end; owned perks are refused.
#  2. Power on, buy Ironhide / Quickdraw / Pack Mule (4 perks with Second Wind); a 5th (Marathon)
#     is refused by the cap. Effects on the live player: max HP 250, held weapon reload time ×0.5,
#     three weapons carried; HUD order = acquisition order.
#  3. Down #1 (solo + Second Wind): every perk lost, Pack Mule's third weapon dropped, no game over,
#     self-revive after 5 s. Second Wind bought and used twice more; after the 3rd self-revive the
#     machine disappears (unavailable / hidden) and the price was 500 each time.
#  4. Power-ups (each spawned and walked onto): Max Ammo (reserve refilled, magazine kept),
#     Insta-Kill (one-hit kills, 30 s host-time timer), Double Points (hit = 20), Nuke (all zombies
#     dead within 2.5 s, +400, no new drops), Carpenter (every barricade rebuilt, +200), Fire Sale
#     (all box locations); natural drops from bullet kills at reachable spots, none from trap kills;
#     a drop expires after its lifetime.
#  5. Down #4 without Second Wind = game over.
extends "res://tests/net/autotest_base.gd"

var _game_over: bool = false


func _ready() -> void:
	timeout = 200.0
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


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _machine(perk: StringName) -> PerkMachine:
	for pm: PerkMachine in _m().perks.machines:
		if pm.perk_id == perk:
			return pm
	return null


func _stand_at(me: PlayerCharacter, it: Interactable) -> void:
	me.motor.teleport(it.global_position + it.global_transform.basis.z * 1.1 + Vector3.UP * 0.05)
	await _wait(0.3)


# Buys through the real interaction path (validate → pay → execute). Returns the result reason.
func _buy(me: PlayerCharacter, perk: StringName) -> bool:
	var pm: PerkMachine = _machine(perk)
	await _stand_at(me, pm)
	return _m().interaction.host_handle(me.peer_id, pm.interact_id)


func _drink_done(me: PlayerCharacter) -> void:
	await _until(func() -> bool: return not _m().perks.is_drinking(me.peer_id), 5.0)
	await _wait(0.2)


func _run() -> void:
	await _until(func() -> bool: return _m() != null and _m().players.local_avatar() != null, 20.0)
	var m: Match = _m()
	m.downed.show_screen = false
	m.downed.game_over.connect(func(_r: int, _rows: Array) -> void: _game_over = true)
	var me: PlayerCharacter = m.players.local_avatar()
	var id: int = me.peer_id
	me.notarget = true
	await _until(func() -> bool: return m.zombies.crowd.is_ready(), 20.0)
	m.rounds.enabled = false
	m.zombies.host_kill_all()
	await _wait(0.5)
	var ps: PerkSystem = m.perks
	check("seven_machines", ps.machines.size() == 7, ps.machines.size())
	var on_markers: bool = true
	for pm: PerkMachine in ps.machines:
		on_markers = on_markers and pm.get_parent() is MapMarker and (pm.get_parent() as MapMarker).kind == &"perk"
	check("machines_on_perk_markers", on_markers)
	check("solo", ps.is_solo())
	m.points.host_set(id, 30000)
	# 1. Power off.
	check("power_off_visual", not _machine(&"quickdraw").powered_visual and _machine(&"second_wind").powered_visual)
	var pts: int = m.points.get_points(id)
	var ok: bool = await _buy(me, &"quickdraw")
	check("quickdraw_needs_power", not ok and m.interaction.last_denied == "Requires power", m.interaction.last_denied)
	check("refused_no_charge", m.points.get_points(id) == pts)
	ok = await _buy(me, &"second_wind")
	check("second_wind_without_power", ok and m.points.get_points(id) == pts - 500, m.points.get_points(id))
	check("drinking_started", ps.is_drinking(id) and me.weapons.is_drinking())
	check("weapon_lowered", me.weapons.held().state != WeaponRuntime.State.IDLE, me.weapons.held().state)
	var t0: float = Net.host_time()
	await _until(func() -> bool: return ps.has_perk(id, &"second_wind"), 5.0)
	var drink_s: float = Net.host_time() - t0
	check("drink_takes_3s", drink_s > 2.6 and drink_s < 3.6, drink_s)
	await _wait(0.6)
	check("weapon_back_up", not me.weapons.is_drinking() and me.weapons.held().state == WeaponRuntime.State.IDLE)
	ok = await _buy(me, &"second_wind")
	check("owned_refused", not ok and m.interaction.last_denied == "Already owned", m.interaction.last_denied)
	# 2. Power on, cap 4, effects.
	Power.host_set(Power.MAIN, true)
	await _wait(0.3)
	check("power_on_visual", _machine(&"quickdraw").powered_visual)
	var base_reload: float = me.weapons.held().total_reload_time()
	for perk: StringName in [&"ironhide", &"quickdraw", &"pack_mule"]:
		ok = await _buy(me, perk)
		check("bought_%s" % perk, ok, m.interaction.last_denied)
		await _drink_done(me)
	check("four_perks", ps.ids_of(id).size() == 4, ps.digest_of(id))
	check(
		"hud_order",
		PerkSystem._strings(me.perk_holder.ids) == ["second_wind", "ironhide", "quickdraw", "pack_mule"],
		me.perk_holder.ids
	)
	ok = await _buy(me, &"marathon")
	check("cap_4", not ok and m.interaction.last_denied == "Perk limit reached", m.interaction.last_denied)
	check("max_hp_250", is_equal_approx(me.health.max_health, 250.0), me.health.max_health)
	await _wait(0.2)
	var quick_reload: float = me.weapons.held().total_reload_time()
	check("reload_halved", absf(quick_reload - base_reload * 0.5) < 0.01, [base_reload, quick_reload])
	m.weapons.host_give(id, &"mp40")
	m.weapons.host_give(id, &"m14")
	await _wait(0.5)
	check("three_weapons", (m.weapons.loadouts[id]["ids"] as Array).size() == 3, m.weapons.loadouts[id]["ids"])
	check("owner_three_slots", me.weapons.inventory.slots.size() == 3, me.weapons.inventory.ids())
	# 3. Downs with Second Wind.
	m.downed.host_force_down(id)
	await _wait(0.3)
	check("down1_no_game_over", not _game_over and m.downed.is_self_reviving(id))
	check("down1_perks_lost", ps.ids_of(id).is_empty() and me.perk_holder.ids.is_empty())
	check("down1_max_hp_back", is_equal_approx(me.health.max_health, 100.0), me.health.max_health)
	var lo_ids: Array = m.weapons.loadouts[id]["ids"]
	check("third_weapon_lost", not lo_ids.has(&"m14") and lo_ids.has(&"mp40"), lo_ids)
	var revived: bool = await _until(func() -> bool: return m.downed.state_of(id) == DownedSystem.State.ALIVE, 7.0)
	check("self_revived", revived and not me.health.is_downed)
	check("uses_1", ps.second_wind_uses() == 1, ps.second_wind_uses())
	for use: int in [2, 3]:
		pts = m.points.get_points(id)
		ok = await _buy(me, &"second_wind")
		check("sw_rebuy_%d" % use, ok and m.points.get_points(id) == pts - 500)
		await _drink_done(me)
		m.downed.host_force_down(id)
		await _wait(0.3)
		check("down%d_self_revive" % use, not _game_over and m.downed.is_self_reviving(id))
		await _until(func() -> bool: return m.downed.state_of(id) == DownedSystem.State.ALIVE, 7.0)
	check("uses_3", ps.second_wind_uses() == 3)
	await _wait(0.3)
	var sw: PerkMachine = _machine(&"second_wind")
	check("machine_vanished", not sw.visible and not sw.is_available(me))
	# 4. Power-ups.
	await _powerups(m, me)
	# 5. No Second Wind left: the next down is game over.
	me.notarget = true
	m.downed.host_force_down(id)
	await _until(func() -> bool: return _game_over, 4.0)
	check("down4_game_over", _game_over)
	finish(true)


func _spawn_zombies(m: Match, near: Vector3, n: int) -> Array[ZombieActor]:
	var out: Array[ZombieActor] = []
	var arch: ZombieArchetype = m.zombies.archetype(&"zombie")
	for i: int in n:
		var a: ZombieActor = m.zombies.host_spawn(arch, 0, near + Vector3(4.0 + i * 0.8, 0, 2.0), 0.0)
		if a != null:
			out.append(a)
	return out


func _pick(m: Match, me: PlayerCharacter, type: StringName, spot: Vector3) -> bool:
	var before: int = m.powerups.picked_total
	var id: int = m.powerups.host_spawn(type, spot)
	await _wait(0.3)
	me.motor.teleport(spot + Vector3.UP * 0.05)
	var ok: bool = await _until(func() -> bool: return m.powerups.picked_total > before, 3.0)
	return ok and not m.powerups.drops.has(id)


func _powerups(m: Match, me: PlayerCharacter) -> void:
	var pu: PowerUpSystem = m.powerups
	var id: int = me.peer_id
	m.zombies.crowd.frozen = true
	var spot: Vector3 = m.players.spawn_point_for(id)
	me.motor.teleport(spot)
	await _wait(0.5)
	var drop_spot: Vector3 = spot + Vector3(0, 0, -2.0)
	# Max Ammo: reserve refilled, magazine kept.
	var rt: WeaponRuntime = me.weapons.held()
	rt.mag = 2
	rt.reserve = 0
	m.weapons.validator.give(id, rt.def, 2, 0)
	check("pick_max_ammo", await _pick(m, me, &"max_ammo", drop_spot))
	await _wait(0.4)
	check("max_ammo_reserve", rt.reserve == rt.def.reserve_max and rt.mag == 2, [rt.mag, rt.reserve])
	# Insta-Kill.
	check("pick_insta_kill", await _pick(m, me, &"insta_kill", drop_spot))
	check("insta_timer_30", absf(pu.time_left(&"insta_kill") - 30.0) < 0.6, pu.time_left(&"insta_kill"))
	var zs: Array[ZombieActor] = _spawn_zombies(m, spot, 1)
	await _wait(0.3)
	if not zs.is_empty():
		var hp: float = zs[0].health
		m.targets.host_damage(
			zs[0], DamageInfo.make(5.0, WeaponDefinition.Hitzone.LIMB, DamageInfo.Kind.BULLET, &"m1911", id)
		)
		check("insta_one_hit", not zs[0].alive, hp)
	# Double Points: a hit pays 20.
	check("pick_double_points", await _pick(m, me, &"double_points", drop_spot))
	await _wait(0.1)
	zs = _spawn_zombies(m, spot, 1)
	await _wait(0.3)
	m.session.host_set_flag(PowerUpSystem.flag_key(&"insta_kill"), 0.0)  # end Insta-Kill early
	await _wait(0.1)
	if not zs.is_empty():
		var p0: int = m.points.get_points(id)
		m.targets.host_damage(
			zs[0], DamageInfo.make(5.0, WeaponDefinition.Hitzone.LIMB, DamageInfo.Kind.BULLET, &"m1911", id)
		)
		check("double_hit_20", m.points.get_points(id) - p0 == 20, m.points.get_points(id) - p0)
		m.zombies.host_kill(zs[0])
	m.session.host_set_flag(PowerUpSystem.flag_key(&"double_points"), 0.0)
	await _wait(0.1)
	# Nuke: everything dies over ~2 s, +400, no drops from it.
	pu.dropper.rate = 1000.0
	zs = _spawn_zombies(m, spot, 5)
	await _wait(0.3)
	var drops_before: int = pu.spawned_total
	var pts: int = m.points.get_points(id)
	check("pick_nuke", await _pick(m, me, &"nuke", drop_spot))
	var t0: float = Net.host_time()
	var dead: bool = await _until(func() -> bool: return m.zombies.alive_count() == 0, 4.0)
	check("nuke_kills_all", dead, m.zombies.alive_count())
	check("nuke_staggered", Net.host_time() - t0 > 1.2 and Net.host_time() - t0 < 2.8, Net.host_time() - t0)
	check("nuke_points_400", m.points.get_points(id) - pts == 400, m.points.get_points(id) - pts)
	await _wait(0.3)
	check("nuke_no_drops", pu.spawned_total == drops_before + 1, pu.spawned_total - drops_before)
	# Carpenter.
	for b: Barricade in m.world.barricades:
		WorldSync.host_set_barricade(b, 0)
	pts = m.points.get_points(id)
	check("pick_carpenter", await _pick(m, me, &"carpenter", drop_spot))
	await _wait(0.2)
	var all_up: bool = true
	for b: Barricade in m.world.barricades:
		all_up = all_up and b.planks == b.max_planks
	check("carpenter_rebuilt", all_up and m.world.barricades.size() > 0, m.world.barricades.size())
	check("carpenter_points_200", m.points.get_points(id) - pts == 200, m.points.get_points(id) - pts)
	# Fire Sale.
	check("pick_fire_sale", await _pick(m, me, &"fire_sale", drop_spot))
	check("fire_sale_box", m.box.fire_sale_active() and absf(pu.time_left(&"fire_sale") - 30.0) < 0.6)
	m.session.host_set_flag(RelicBoxSystem.FLAG_FIRE_SALE, 0.0)
	# Natural drops: a bullet kill drops at a reachable spot; a trap kill never does.
	zs = _spawn_zombies(m, spot, 2)
	await _wait(0.3)
	if zs.size() == 2:
		var n0: int = pu.spawned_total
		pu.dropper.counter = pu.dropper.threshold() + 1.0
		var trap: DamageInfo = DamageInfo.make(9999.0, WeaponDefinition.Hitzone.TORSO, DamageInfo.Kind.TRAP, &"", id)
		m.targets.host_damage(zs[0], trap)
		await _wait(0.1)
		check("trap_kill_no_drop", pu.spawned_total == n0)
		var shot: DamageInfo = DamageInfo.make(
			9999.0, WeaponDefinition.Hitzone.HEAD, DamageInfo.Kind.BULLET, &"m1911", id
		)
		m.targets.host_damage(zs[1], shot)
		await _wait(0.1)
		check("bullet_kill_drops", pu.spawned_total == n0 + 1, pu.log_spawns)
	pu.dropper.rate = 1.0
	# Lifetime: a drop vanishes after `lifetime` (shortened for the test).
	var rules: PowerUpRules = pu.rules.duplicate() as PowerUpRules
	rules.lifetime = 2.0
	rules.blink_time = 1.0
	pu.rules = rules
	for d: Variant in pu.drops.values():
		(d as PowerUpDrop).rules = rules
	me.motor.teleport(spot + Vector3(6, 0, 0))
	var far: int = pu.host_spawn(&"max_ammo", spot + Vector3(-3, 0, 3))
	await _wait(2.5)
	check("drop_expires", not pu.drops.has(far) and pu.expired_total > 0)
	m.zombies.crowd.frozen = false
