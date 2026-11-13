# specials (Step 12: AC-12.3 buildables, AC-12.4 special rounds, the Warden rules) — solo vesper_peak,
# through the real interaction path where a player would act:
#  1. Buildables: exactly one spawn option of each Conduit part is live (host-chosen flags); parts
#     go into the shared inventory; the Lab Workbench refuses with parts missing, then without
#     power; with power it builds (hold), sets "conduit_built" (the Relic Box pool gains the
#     Conduit), the first claim gives the Lazarus Conduit, the bench is then spent.
#  2. Special round: the scheduled round spawns only Galvanics (6 solo, 400 HP) through rifts that
#     crackle 1.5 s first, at most 12 alive, 8 m+ from the player; Galvanic deaths burst (players
#     within 3 m take damage, a nearby plank is torn); the last kill drops Max Ammo; the round ends.
#  3. Warning: a forced special round after an intermission plays the 8 s build-up (atmosphere on,
#     warning counted) and the HUD state reaches the client-visible RoundDirector fields.
#  4. Schedule: 50 rounds driven through the RoundDirector — the special rounds are exactly the
#     seeded schedule (first 5-7, gaps 4-6), counts grow +2 per special round; mixed Galvanics from 20.
#  5. Warden: `spawn_warden` health; the late-round rule (on since Step 14B; `warden_late` toggles it); when
#     enabled, a late Warden's death drops a Free Upgrade.
extends "res://tests/net/autotest_base.gd"

var _id: int = 1


func _ready() -> void:
	timeout = 240.0
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


func _use(me: PlayerCharacter, it: Interactable, offset: Vector3 = Vector3(1.0, 0.0, 0.0)) -> bool:
	me.motor.teleport(it.global_position + offset + Vector3.UP * 0.05)
	await _wait(0.25)
	return _m().interaction.host_handle(me.peer_id, it.interact_id)


func _run() -> void:
	await _until(func() -> bool: return _m() != null and _m().players.local_avatar() != null, 20.0)
	var m: Match = _m()
	m.downed.show_screen = false
	var me: PlayerCharacter = m.players.local_avatar()
	_id = me.peer_id
	me.notarget = true
	me.health.invulnerable = true
	await _until(func() -> bool: return m.zombies.crowd.is_ready(), 20.0)
	m.rounds.paused = true
	await _wait(0.5)
	m.zombies.host_kill_all()
	await _buildables(m, me)
	await _special_round(m, me)
	await _warning(m)
	await _schedule(m)
	await _warden(m, me)
	finish(true)


# --- 1. buildables ---------------------------------------------------------------------------------


func _buildables(m: Match, me: PlayerCharacter) -> void:
	var bs: BuildableSystem = m.buildables
	check("one_buildable", bs.defs.size() == 1 and bs.defs[0].id == &"conduit", bs.defs.size())
	check("six_part_options", bs.parts.size() == 6, bs.parts.size())
	var live: Array[BuildablePart] = []
	for bp: BuildablePart in bs.parts:
		if bp.is_here():
			live.append(bp)
	check("one_live_option_per_part", live.size() == 3, live.size())
	check(
		"workbench_in_z11",
		bs.benches.has(&"conduit") and m.zones.zone_at((bs.benches[&"conduit"] as Node3D).global_position) == &"Z11"
	)
	var wb: Workbench = bs.benches[&"conduit"]
	var ok: bool = await _use(me, wb, Vector3(0, 0, 1.2))
	check("bench_needs_parts", not ok and m.interaction.last_denied == "Missing parts", m.interaction.last_denied)
	for bp: BuildablePart in live:
		ok = await _use(me, bp)
		check("pickup_%s" % bp.part, ok and bs.has_part(&"conduit", bp.part), m.interaction.last_denied)
		check("part_gone_%s" % bp.part, not bp.is_here())
	check("shared_inventory_full", bs.all_parts(&"conduit"))
	check("hud_line", bs.hud_lines().is_empty() == false or bs.all_parts(&"conduit"))
	Power.host_set(Power.MAIN, false)
	ok = await _use(me, wb, Vector3(0, 0, 1.2))
	check("bench_needs_power", not ok and m.interaction.last_denied == "Requires power", m.interaction.last_denied)
	check("box_no_conduit_before", not (m.box.eligible_for(_id)[0] as Array).has(&"lazarus_conduit"))
	Power.host_set(Power.MAIN, true)
	await _wait(0.2)
	ok = await _use(me, wb, Vector3(0, 0, 1.2))
	check("built", ok and bs.state(&"conduit") == BuildableSystem.State.BUILT, m.interaction.last_denied)
	check("conduit_built_flag", bool(m.session.flag("conduit_built", false)))
	check("box_pool_has_conduit", (m.box.eligible_for(_id)[0] as Array).has(&"lazarus_conduit"))
	ok = await _use(me, wb, Vector3(0, 0, 1.2))
	check("claimed", ok and m.weapons.host_owns(_id, &"lazarus_conduit"), m.interaction.last_denied)
	check("bench_spent", bs.state(&"conduit") == BuildableSystem.State.CLAIMED)
	check("box_one_per_player", not (m.box.eligible_for(_id)[0] as Array).has(&"lazarus_conduit"))


# --- 2. special round ------------------------------------------------------------------------------


func _special_round(m: Match, me: PlayerCharacter) -> void:
	var rd: RoundDirector = m.rounds
	var sched: PackedInt32Array = m.rules.call(&"special_schedule")
	var first: int = sched[0]
	check("first_special_5_to_7", first >= 5 and first <= 7, first)
	me.motor.teleport(Vector3(0, 0.1, 2))
	await _wait(0.3)
	rd.paused = false
	rd.host_start_round(first)
	check("special_id", rd.special_id == &"galvanic" and rd.is_special_round(), rd.special_id)
	check("special_count_solo_6", rd.total == 6 and rd.special_left == 6, [rd.total, rd.special_left])
	check("special_health_400", rd.special_health_value == 400.0, rd.special_health_value)
	check("no_normal_queue", rd.queue.is_empty())
	var fx: WonderFx = m.wonder_fx
	var rifts0: int = int(fx.shown.get(WonderFx.Kind.RIFT, 0))
	var t_rift: float = -1.0
	var t_spawn: float = -1.0
	var max_alive: int = 0
	var killed: int = 0
	var last_drops: int = m.powerups.log_spawns.size()
	var t0: float = elapsed()
	var arch_ok: bool = true
	var hp_ok: bool = true
	var bursts0: int = m.specials.bursts
	while elapsed() - t0 < 60.0 and rd.phase == RoundDirector.Phase.ACTIVE:
		await get_tree().physics_frame
		if t_rift < 0.0 and int(fx.shown.get(WonderFx.Kind.RIFT, 0)) > rifts0:
			t_rift = elapsed()
		max_alive = maxi(max_alive, rd.special_ids.size() + m.spawns.rifts.size())
		for id: Variant in rd.special_ids.keys():
			var a: ZombieActor = m.zombies.actors.get(id, null)
			if a == null:
				continue
			if t_spawn < 0.0:
				t_spawn = elapsed()
			arch_ok = arch_ok and a.archetype.id == &"galvanic"
			hp_ok = hp_ok and a.max_health == 400.0
			if killed == 0:
				# First one dies next to the player: the electric burst hits in 3 m.
				me.health.invulnerable = false
				var hp_before: float = me.health.health
				me.motor.teleport(a.global_position + Vector3(1.5, 0.05, 0))
				await _wait(0.1)
				m.zombies.host_kill(a)
				await _wait(0.1)
				check("burst_hurts_player", me.health.health < hp_before, [hp_before, me.health.health])
				me.health.invulnerable = true
				me.health.health = me.health.max_health
				me.motor.teleport(Vector3(0, 0.1, 2))
			elif a.alive:
				m.zombies.host_kill(a)
			killed += 1
	check("rift_telegraph_1_5s", t_rift > 0.0 and t_spawn - t_rift >= 1.4, [t_rift, t_spawn])
	check("only_galvanics", arch_ok)
	check("galvanic_hp_400", hp_ok)
	check("alive_cap_12", max_alive <= 12, max_alive)
	check("rift_8m_from_players", m.spawns.rift_min_distance_seen >= 7.5, m.spawns.rift_min_distance_seen)
	check("bursts_counted", m.specials.bursts > bursts0, m.specials.bursts)
	check("special_round_ended", rd.phase == RoundDirector.Phase.INTERMISSION, rd.phase_name())
	var new_drops: Array = m.powerups.log_spawns.slice(last_drops)
	check("max_ammo_on_last_kill", m.specials.max_ammo_drops == 1, [m.specials.max_ammo_drops, new_drops])
	var finite: bool = true
	for d: PowerUpDrop in m.powerups.drops.values():
		finite = finite and d.global_position.is_finite()
	check("drops_on_finite_positions", finite)
	check("special_log", rd.special_log.has(first), rd.special_log)


# --- 3. warning -------------------------------------------------------------------------------------


func _warning(m: Match) -> void:
	var rd: RoundDirector = m.rounds
	var w0: int = m.specials.warnings
	rd.host_force_special(&"galvanic")
	check("next_special_set", rd.next_special == &"galvanic")
	check("intermission_cut_to_warning", rd.time_left <= rd.curve.special_warning + 0.6, rd.time_left)
	var warned: bool = await _until(func() -> bool: return m.specials.warnings > w0, 3.0)
	check("warning_buildup", warned, m.specials.warnings)
	await _wait(1.5)
	check("atmosphere_on", m.specials.atmosphere > 0.3, m.specials.atmosphere)
	var started: bool = await _until(func() -> bool: return rd.phase == RoundDirector.Phase.ACTIVE, 12.0)
	check("forced_special_started", started and rd.special_id == &"galvanic", rd.special_id)
	check("second_special_count_8", rd.total == 8, rd.total)
	var want_hp: float = rd.curve.special_health(1, rd.zombie_health())
	check("second_special_hp_x1_35_soft_cap", rd.special_health_value == want_hp, [rd.special_health_value, want_hp])
	rd.host_skip_round()
	await _wait(0.3)


# --- 4. 50-round schedule ---------------------------------------------------------------------------


func _schedule(m: Match) -> void:
	var rd: RoundDirector = m.rounds
	rd.paused = true
	rd.special_log.clear()
	rd.special_rounds_played = 0
	var sched: PackedInt32Array = m.rules.call(&"special_schedule")
	var mixed_ok: bool = true
	var counts: Array[int] = []
	for r: int in range(1, 51):
		rd.host_start_round(r)
		if rd.is_special_round():
			counts.append(rd.total)
		elif r >= 20:
			mixed_ok = mixed_ok and rd.special_left >= 1 and rd.special_left <= 2
		elif r < 20:
			mixed_ok = mixed_ok and rd.special_left == 0
		rd.host_skip_round()
		await get_tree().physics_frame
	var want: Array = Array(sched).filter(func(x: int) -> bool: return x <= 50)
	check("specials_match_schedule_50", Array(rd.special_log) == want, [rd.special_log, want])
	var grows: bool = true
	for i: int in counts.size():
		grows = grows and counts[i] == mini(6 + 2 * i, 24)
	check("special_counts_grow", grows, counts)
	check("mixed_from_20", mixed_ok)
	m.zombies.host_kill_all()


# --- 5. Warden ---------------------------------------------------------------------------------------


func _warden(m: Match, me: PlayerCharacter) -> void:
	me.motor.teleport(Vector3(0, 0.1, 2))
	await _wait(0.3)
	var out: String = Debug.commands.execute("spawn_warden 20")
	var w: ZombieActor = null
	for a: ZombieActor in m.zombies.actors.values():
		if a.archetype.id == &"warden":
			w = a
	var base: ZombieArchetype = m.zombies.archetype(&"zombie")
	check("warden_spawned", w != null, out)
	if w != null:
		check("warden_health", w.max_health == 25.0 * base.health_for_round(20), w.max_health)
		m.zombies.host_kill(w)
	check("late_rule_on_with_ee", m.rules.warden_late_rounds_enabled())  # Step 14B enables it
	Debug.commands.execute("warden_late off")
	check("late_rule_off_cmd", not m.rules.warden_late_rounds_enabled())
	Debug.commands.execute("warden_late on")
	check("late_rule_enabled", m.rules.warden_late_rounds_enabled())
	var drops0: int = m.powerups.log_spawns.size()
	var lw: ZombieActor = m.specials.host_spawn_late_warden(25)
	check("late_warden", lw != null)
	if lw != null:
		m.zombies.host_kill(lw)
		await _wait(0.2)
		var new_drops: Array = m.powerups.log_spawns.slice(drops0)
		check("free_upgrade_drop", new_drops.any(func(e: Array) -> bool: return e[1] == "free_upgrade"), new_drops)
	Debug.commands.execute("warden_late off")
