# Step 10 (AC-10.1, data side of AC-10.2): the StatModifier stack (SET → MUL → ADD, per-source
# add / remove), every Vigor Tonic's data against GAME_DESIGN §8, and each perk's effect measured
# on the real components it drives: Quickdraw halves reload / raise time, Twin-Fire raises the
# fire rate ×1.33 (runtime cadence + host validator) and doubles hitscan damage, Ironhide max HP
# 250, Marathon move +7 % / sprint 10 s / faster recharge, Bullseye hip spread −40 % and headshots
# +25 %, Second Wind revive time 2 s, Pack Mule a third slot.
extends GutTest


func _stats(ids: Array) -> PlayerStats:
	var h: PerkHolder = PerkHolder.new()
	h.set_ids(ids)
	return h.stats


func test_stat_fold_order_and_sources() -> void:
	var st: PlayerStats = PlayerStats.new()
	assert_eq(st.value(&"x", 5.0), 5.0, "no modifiers = base")
	st.set_source(&"a", [StatModifier.make(&"x", StatModifier.Op.MUL, 2.0)])
	st.set_source(&"b", [StatModifier.make(&"x", StatModifier.Op.ADD, 1.0)])
	st.set_source(&"c", [StatModifier.make(&"x", StatModifier.Op.SET, 10.0)])
	assert_eq(st.value(&"x", 5.0), 21.0, "SET 10, ×2, +1")
	st.clear_source(&"c")
	assert_eq(st.value(&"x", 5.0), 11.0)
	assert_false(st.flag(&"y"))
	st.clear()
	assert_eq(st.value(&"x", 5.0), 5.0)


func test_perk_data_matches_design() -> void:
	# id: [cost, coop cost, requires power, marker]
	var table: Dictionary = {
		&"ironhide": [2500, 2500, true, &"Perk_Ironhide"],
		&"quickdraw": [3000, 3000, true, &"Perk_Quickdraw"],
		&"twin_fire": [2000, 2000, true, &"Perk_TwinFire"],
		&"marathon": [2000, 2000, true, &"Perk_MarathonMalt"],
		&"second_wind": [500, 1500, false, &"Perk_SecondWind"],
		&"bullseye": [1500, 1500, true, &"Perk_Bullseye"],
		&"pack_mule": [4000, 4000, true, &"Perk_PackMule"],
	}
	assert_eq(PerkCatalog.all().size(), 7, "7 Vigor Tonics")
	for id: StringName in table:
		var d: PerkDefinition = PerkCatalog.get_def(id)
		assert_not_null(d, String(id))
		if d == null:
			continue
		var row: Array = table[id]
		assert_eq(d.price(false), int(row[0]), "%s solo price" % id)
		assert_eq(d.price(true), int(row[1]), "%s co-op price" % id)
		assert_eq(d.requires_power, bool(row[2]), "%s power" % id)
		assert_eq(d.marker_id, row[3], "%s marker" % id)
		assert_eq(PerkCatalog.by_marker(d.marker_id), d)
		assert_gt(d.jingle_notes.size(), 3, "%s has a jingle" % id)
	var colors: Array = []
	for d: PerkDefinition in PerkCatalog.all():
		assert_false(colors.has(d.color), "%s neon colour is unique" % d.id)
		colors.append(d.color)


func test_ironhide_max_health() -> void:
	var tuning: PlayerTuning = load(PlayerCharacter.DEFAULT_TUNING) as PlayerTuning
	assert_eq(_stats([&"ironhide"]).value(PlayerStats.MAX_HEALTH, tuning.max_health), 250.0)
	assert_eq(_stats([]).value(PlayerStats.MAX_HEALTH, tuning.max_health), 100.0)


func test_quickdraw_halves_reload_and_raise() -> void:
	var def: WeaponDefinition = WeaponCatalog.get_def(&"m14")
	var base: WeaponRuntime = WeaponRuntime.new(def)
	base.mag = 0
	var quick: WeaponRuntime = WeaponRuntime.new(def)
	quick.mag = 0
	quick.speed_multiplier = _stats([&"quickdraw"]).value(PlayerStats.RELOAD_SPEED, 1.0)
	assert_almost_eq(quick.total_reload_time(), base.total_reload_time() * 0.5, 0.0001, "reload ×0.5")
	# Simulate an empty reload to completion in 1/60 s steps: the real timer halves too.
	assert_almost_eq(_reload_seconds(quick), _reload_seconds(base) * 0.5, 0.034)
	# Raise (weapon swap) also takes half the time.
	assert_almost_eq(_raise_seconds(quick), _raise_seconds(base) * 0.5, 0.034)


func _reload_seconds(rt: WeaponRuntime) -> float:
	rt.mag = 0
	rt.reserve = rt.def.reserve_max
	rt.make_ready()
	assert_true(rt.start_reload())
	var t: float = 0.0
	while rt.is_reloading() and t < 20.0:
		rt.update(1.0 / 60.0, false, false, false)
		t += 1.0 / 60.0
	return t


func _raise_seconds(rt: WeaponRuntime) -> float:
	rt.raise()
	var t: float = 0.0
	while rt.state == WeaponRuntime.State.RAISING and t < 10.0:
		rt.update(1.0 / 60.0, false, false, false)
		t += 1.0 / 60.0
	return t


func test_twin_fire_rate_and_validator() -> void:
	var def: WeaponDefinition = WeaponCatalog.get_def(&"mp40")
	var st: PlayerStats = _stats([&"twin_fire"])
	var rate: float = st.value(PlayerStats.FIRE_RATE, 1.0)
	assert_almost_eq(rate, 1.33, 0.0001)
	var base_shots: int = _shots_in(def, 1.0, 3.0)
	var fast_shots: int = _shots_in(def, rate, 3.0)
	assert_almost_eq(float(fast_shots) / float(base_shots), 1.33, 0.05, "×1.33 shots over 3 s")
	# Host validator: the faster cadence is rejected without the perk and accepted with it.
	var v: HitValidator = HitValidator.new()
	v.give(7, def)
	v.state_for(7).infinite_ammo = true
	var interval: float = def.fire_interval() / rate
	var rejected: int = 0
	for i: int in 20:
		if v.check_shot(7, def, i, i * interval, i * interval) != HitValidator.Result.OK:
			rejected += 1
	assert_gt(rejected, 0, "×1.33 cadence without the perk is rejected")
	var v2: HitValidator = HitValidator.new()
	v2.give(7, def)
	v2.state_for(7).infinite_ammo = true
	v2.set_rate_multiplier(7, rate, 0.0)
	for i: int in 20:
		assert_eq(v2.check_shot(7, def, i, i * interval, i * interval), HitValidator.Result.OK, "shot %d" % i)
	# Losing the perk keeps the old rate for the grace second.
	v2.set_rate_multiplier(7, 1.0, 20.0 * interval)
	assert_almost_eq(HitValidator.effective_rate(v2.state_for(7), 20.0 * interval + 0.5), rate, 0.001)
	assert_almost_eq(HitValidator.effective_rate(v2.state_for(7), 20.0 * interval + 1.5), 1.0, 0.001)


func _shots_in(def: WeaponDefinition, rate: float, seconds: float) -> int:
	var rt: WeaponRuntime = WeaponRuntime.new(def)
	rt.infinite_ammo = true
	rt.rate_multiplier = rate
	rt.make_ready()
	var n: int = 0
	var t: float = 0.0
	while t < seconds:
		n += rt.update(1.0 / 60.0, true, false, false)
		t += 1.0 / 60.0
	return n


func test_twin_fire_double_damage_and_bullseye_headshots() -> void:
	var ws: WeaponSync = WeaponSync.new()
	var ps: PlayerSync = PlayerSync.new()
	ws.players = ps
	var p: PlayerCharacter = (load("res://core/player/player_character.tscn") as PackedScene).instantiate()
	ps.avatars[3] = p
	var m14: WeaponDefinition = WeaponCatalog.get_def(&"m14")
	var law: WeaponDefinition = WeaponCatalog.get_def(&"law")
	var knife: WeaponDefinition = WeaponCatalog.get_def(&"knife")
	assert_eq(ws.perk_damage_factor(3, m14, WeaponDefinition.Hitzone.TORSO), 1.0)
	p.perk_holder.set_ids([&"twin_fire"])
	assert_eq(ws.perk_damage_factor(3, m14, WeaponDefinition.Hitzone.TORSO), 2.0, "hitscan bullets hit twice")
	assert_eq(ws.perk_damage_factor(3, law, WeaponDefinition.Hitzone.TORSO), 1.0, "projectiles: rate only")
	assert_eq(ws.perk_damage_factor(3, knife, WeaponDefinition.Hitzone.HEAD), 1.0, "melee unaffected")
	p.perk_holder.set_ids([&"bullseye"])
	assert_almost_eq(ws.perk_damage_factor(3, m14, WeaponDefinition.Hitzone.HEAD), 1.25, 0.0001)
	assert_eq(ws.perk_damage_factor(3, m14, WeaponDefinition.Hitzone.TORSO), 1.0)
	p.free()
	ps.free()
	ws.free()


func test_bullseye_hip_spread() -> void:
	var def: WeaponDefinition = WeaponCatalog.get_def(&"mp40")
	var rt: WeaponRuntime = WeaponRuntime.new(def)
	var hip: float = rt.spread_deg(0.0)
	rt.hip_multiplier = _stats([&"bullseye"]).value(PlayerStats.HIP_SPREAD, 1.0)
	assert_almost_eq(rt.spread_deg(0.0), hip * 0.6, 0.0001, "hip spread −40 %")
	assert_almost_eq(_stats([&"bullseye"]).value(PlayerStats.AIM_SNAP, 0.0), 0.15, 0.0001)


func test_marathon_and_second_wind_and_pack_mule() -> void:
	var tuning: PlayerTuning = load(PlayerCharacter.DEFAULT_TUNING) as PlayerTuning
	var st: PlayerStats = _stats([&"marathon"])
	assert_almost_eq(st.value(PlayerStats.MOVE_SPEED, 1.0), 1.07, 0.0001)
	assert_eq(st.value(PlayerStats.SPRINT_DURATION, tuning.sprint_duration), 10.0)
	assert_gt(st.value(PlayerStats.SPRINT_RECHARGE, 1.0), 1.0)
	var sw: PlayerStats = _stats([&"second_wind"])
	assert_eq(sw.value(PlayerStats.REVIVE_TIME, tuning.revive_time), 2.0, "co-op revive 2 s")
	assert_eq(_stats([]).value(PlayerStats.REVIVE_TIME, tuning.revive_time), 4.0)
	assert_true(sw.flag(PlayerStats.SELF_REVIVE))
	assert_eq(int(_stats([&"pack_mule"]).value(PlayerStats.WEAPON_SLOTS, 0.0)) + WeaponSync.PRIMARY_SLOTS, 3)


func test_holder_order_and_removal() -> void:
	var h: PerkHolder = PerkHolder.new()
	h.set_ids([&"quickdraw", &"ironhide", &"bogus", &"quickdraw"])
	assert_eq(h.ids, [&"quickdraw", &"ironhide"] as Array[StringName], "acquisition order, unknown / dupes dropped")
	assert_eq(h.stats.value(PlayerStats.MAX_HEALTH, 100.0), 250.0)
	h.set_ids([&"quickdraw"])
	assert_eq(h.stats.value(PlayerStats.MAX_HEALTH, 100.0), 100.0, "Ironhide removed")
	h.clear()
	assert_eq(h.count(), 0)
