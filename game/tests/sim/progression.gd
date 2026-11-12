# progression (Step 11: AC-11.1 solo, AC-11.2 live, AC-11.3 live behaviors, AC-11.4, AC-11.5) —
# solo vesper_peak, through the real interaction path where a player would act:
#  1. Relays: 3 relays on the R1-R3 markers (zones Z07 / Z05 / Z11); refused without power; hold
#     starts R1 (charging, a weak zombie lure); progress pauses when the player leaves the zone and
#     resumes on return; R1 completes after 20 s defended; R2 / R3 started, then finished; all done
#     -> "relays_done", the Reactor Bridge extends, the Forge wakes, the reactor stage = STABILIZED.
#  2. Forge: dormant before; 5000 (Fire Sale doesn't change it); the weapon leaves the loadout, 5 s
#     forging ("In use"), the owner takes the upgrade (damage x2, table magazine); an untaken offer
#     is lost after 15 s; a Free Upgrade token makes it free and is consumed; upgraded weapons are
#     refused.
#  3. Upgraded behaviors on live zombies: slow (Glacier Breaker), burn (Grease Fire), Two Graves'
#     once-per-shot splash, Avalanche headshot splash, L.A.W. cluster bomblets, Lure bolts attract,
#     Skullcrusher alt-fire launcher, Gemini dual-wield viewmodel + camo; upgraded wall ammo 4500;
#     the base weapon counts as owned for the box.
#  4. Traps: T2 kills zombies in its tunnel, 50 points each to the activator, refuses while active,
#     damages a player standing in it (~110 HP/s), cools down then re-arms; T3 freezes, a shot
#     shatters, an untouched frozen zombie shatters when the freeze runs out.
#  5. Hazards: a shot drum blows (chain) and kills a zombie, respawns 3 rounds later; icicles kill a
#     zombie below and regrow after 2 rounds; the breaker stuns + damages a zombie in a puddle and
#     refuses while recharging.
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


func _use(me: PlayerCharacter, it: Interactable, offset: Vector3 = Vector3(1.2, 0.0, 0.0)) -> bool:
	me.motor.teleport(it.global_position + offset + Vector3.UP * 0.05)
	await _wait(0.25)
	return _m().interaction.host_handle(me.peer_id, it.interact_id)


func _zombie(pos: Vector3) -> ZombieActor:
	var m: Match = _m()
	var a: ZombieActor = m.zombies.host_spawn(m.zombies.archetype(&"zombie"), 0, pos, 0.0, ZombieSpawner.Kind.VENT)
	return a


func _run() -> void:
	await _until(func() -> bool: return _m() != null and _m().players.local_avatar() != null, 20.0)
	var m: Match = _m()
	m.downed.show_screen = false
	var me: PlayerCharacter = m.players.local_avatar()
	_id = me.peer_id
	me.notarget = true
	me.health.invulnerable = true
	await _until(func() -> bool: return m.zombies.crowd.is_ready(), 20.0)
	m.rounds.enabled = false
	m.zombies.auto_respawn = false
	m.zombies.host_kill_all()
	m.points.host_set(_id, 60000)
	await _wait(0.5)
	await _relays(m, me)
	await _forge(m, me)
	await _behaviors(m, me)
	await _traps(m, me)
	await _hazards(m, me)
	finish(true)


# --- 1. relays -------------------------------------------------------------------------------------


func _relays(m: Match, me: PlayerCharacter) -> void:
	var rs: RelaySystem = m.relays
	check("three_relays", rs.relays.size() == 3, rs.relays.size())
	var ids: Array = rs.relays.map(func(r: ResonanceRelay) -> String: return "%s:%s" % [r.relay_id, r.zone])
	check("relay_ids_zones", ids == ["R1:Z07", "R2:Z05", "R3:Z11"], ids)
	check("forge_dormant", m.forge.host_check(0, _id, &"m1911") == "The Forge is dormant")
	var r1: ResonanceRelay = rs.relays[0]
	var ok: bool = await _use(me, r1)
	check("relay_needs_power", not ok and m.interaction.last_denied == "Requires power", m.interaction.last_denied)
	Power.host_set(Power.MAIN, true)
	await _wait(0.3)
	check("r1_zone_is_z07", m.zones.zone_at(me.global_position) == &"Z07", m.zones.zone_at(me.global_position))
	ok = await _use(me, r1)
	check("r1_started", ok and rs.state(0) == RelaySystem.State.CHARGING, m.interaction.last_denied)
	var lure: bool = false
	for a: Node3D in m.zombies.crowd.live_attractors():
		lure = lure or (a.get_parent() == r1 and bool(a.get_meta(&"attract_weak", false)))
	check("r1_weak_lure", lure)
	await _wait(4.0)
	var p1: float = rs.progress_of(0)
	check("r1_progress", p1 > 3.0 and p1 < 5.5, p1)
	me.motor.teleport(Vector3(0, 0.1, 2))  # Arrival Station (Z01)
	await _wait(0.5)
	check("r1_paused", rs.is_paused(0), rs.progress_of(0))
	var p_paused: float = rs.progress_of(0)
	await _wait(2.0)
	check("r1_progress_frozen", absf(rs.progress_of(0) - p_paused) < 0.05, [p_paused, rs.progress_of(0)])
	check(
		"r1_lure_off_paused",
		m.zombies.crowd.live_attractors().filter(func(a: Node3D) -> bool: return a.get_parent() == r1).is_empty()
	)
	me.motor.teleport(r1.global_position + Vector3(1.2, 0.05, 0))
	await _wait(0.5)
	check("r1_resumed", not rs.is_paused(0))
	var done: bool = await _until(func() -> bool: return rs.state(0) == RelaySystem.State.DONE, 20.0)
	check("r1_done_after_20s_defended", done, rs.progress_of(0))
	check("not_all_done_yet", not rs.all_done() and not m.forge.is_unlocked())
	for i: int in [1, 2]:
		ok = await _use(me, rs.relays[i])
		check("r%d_started" % (i + 1), ok and rs.state(i) == RelaySystem.State.CHARGING, m.interaction.last_denied)
		check(
			"r%d_zone" % (i + 1),
			m.zones.zone_at(me.global_position) == rs.relays[i].zone,
			m.zones.zone_at(me.global_position)
		)
		await _wait(1.0)
		check("r%d_progress" % (i + 1), rs.progress_of(i) > 0.4, rs.progress_of(i))
		rs.host_complete(i)
	await _wait(0.5)
	check("relays_done_flag", rs.all_done() and bool(m.session.flag(RelaySystem.FLAG_DONE, false)))
	check("forge_unlocked", m.forge.is_unlocked())
	var bridge_open: bool = false
	for d: Node in m.map_root.find_children("*", "NavDoor", true, false):
		if (d as NavDoor).solid_when_open:
			bridge_open = (d as NavDoor).is_open
	check("bridge_extended", bridge_open)
	var rstate: Array[Node] = m.map_root.find_children("*", "ReactorState", true, false)
	check(
		"reactor_stabilized", rstate.size() == 1 and (rstate[0] as ReactorState).stage == ReactorState.Stage.STABILIZED
	)


# --- 2. forge --------------------------------------------------------------------------------------


func _forge(m: Match, me: PlayerCharacter) -> void:
	var fs: ForgeSystem = m.forge
	check("one_forge", fs.forges.size() == 1)
	var forge: LazarusForge = fs.forges[0]
	m.weapons.host_give(_id, &"m14")
	m.box.activate_all_locations(30.0)
	await _wait(0.5)
	var spot: Vector3 = Vector3(0, 0, 2.0)
	me.motor.teleport(forge.global_position + spot)
	await _wait(0.3)
	check("forge_cost_5000_fire_sale", forge.get_cost(me) == 5000 and m.box.fire_sale_active(), forge.get_cost(me))
	var pts: int = m.points.get_points(_id)
	var ok: bool = await _use(me, forge, spot)
	check("forge_insert", ok and fs.phase(0) == ForgeSystem.Phase.FORGING, m.interaction.last_denied)
	check("forge_charged_5000", m.points.get_points(_id) == pts - 5000, m.points.get_points(_id))
	check("weapon_left_loadout", not (m.weapons.loadouts[_id]["ids"] as Array).has(&"m14"))
	m.weapons.host_give(_id, &"mp40")
	ok = await _use(me, forge, spot)
	check("forge_in_use", not ok and m.interaction.last_denied == "In use", m.interaction.last_denied)
	var offer: bool = await _until(func() -> bool: return fs.phase(0) == ForgeSystem.Phase.OFFER, 6.0)
	check("forge_5s_sequence", offer and fs.job_time(0) >= 5.0 and fs.job_time(0) < 5.6, fs.job_time(0))
	pts = m.points.get_points(_id)
	ok = await _use(me, forge, spot)
	var ids: Array = m.weapons.loadouts[_id]["ids"]
	check("took_m14_up", ok and ids.has(&"m14_up") and fs.phase(0) == ForgeSystem.Phase.IDLE, ids)
	check("take_is_free", m.points.get_points(_id) == pts)
	var up: WeaponDefinition = WeaponCatalog.get_def(&"m14_up")
	check("m14_up_stats", up.damage == 210.0 and int(m.weapons.validator.ammo(_id, &"m14_up")[0]) == 20)
	# Lost offer: mp40 in, never taken.
	m.weapons.host_give(_id, &"mp40")
	await _wait(0.2)
	ok = await _use(me, forge, spot)
	check("forge_insert_mp40", ok)
	var lost: bool = await _until(func() -> bool: return fs.phase(0) == ForgeSystem.Phase.IDLE, 22.0)
	ids = m.weapons.loadouts[_id]["ids"]
	check(
		"offer_expired_lost", lost and fs.upgrades_lost == 1 and not ids.has(&"mp40") and not ids.has(&"mp40_up"), ids
	)
	# Free Upgrade token.
	m.weapons.host_give(_id, &"mp40")
	m.session.host_set_flag(PowerUpSystem.FLAG_FREE_UPGRADE, true)
	await _wait(0.3)
	check("free_upgrade_cost_0", forge.get_cost(me) == 0, forge.get_cost(me))
	pts = m.points.get_points(_id)
	ok = await _use(me, forge, spot)
	check("free_upgrade_used", ok and m.points.get_points(_id) == pts and not m.powerups.free_upgrade_pending())
	await _until(func() -> bool: return fs.phase(0) == ForgeSystem.Phase.OFFER, 6.0)
	await _use(me, forge, spot)
	check("took_mp40_up", (m.weapons.loadouts[_id]["ids"] as Array).has(&"mp40_up"))
	await _wait(0.3)
	check("upgraded_refused", m.forge.host_check(0, _id, &"mp40_up") == "This weapon cannot be upgraded")


# --- 3. upgraded behaviors -------------------------------------------------------------------------


func _behaviors(m: Match, me: PlayerCharacter) -> void:
	me.motor.teleport(Vector3(28, -7.9, -36))  # Courtyard
	await _wait(0.4)
	var ws: WeaponSync = m.weapons
	var z: ZombieActor = _zombie(Vector3(28, -8, -40))
	await _wait(0.3)
	ws._host_upgrade_on_hit(_id, WeaponCatalog.get_def(&"g3_up"), z, WeaponDefinition.Hitzone.TORSO, false, false)
	check("glacier_slow", m.status.is_slowed(z) and is_equal_approx(z.sim.speed_scale, 0.8), z.sim.speed_scale)
	await _wait(1.3)
	check("glacier_slow_1s", not m.status.is_slowed(z) and is_equal_approx(z.sim.speed_scale, 1.0), z.sim.speed_scale)
	var hp: float = z.health
	ws._host_upgrade_on_hit(
		_id, WeaponCatalog.get_def(&"grease_gun_up"), z, WeaponDefinition.Hitzone.TORSO, false, false
	)
	check("grease_burning_flag", z.flags & ZombieActor.Flag.BURNING != 0)
	await _wait(1.1)
	check("grease_burn_damage", z.health < hp - 30.0, [hp, z.health])
	var n0: int = ws.impact_splashes
	var tg: WeaponDefinition = WeaponCatalog.get_def(&"coachgun_up")
	var s1: bool = ws._host_upgrade_on_hit(_id, tg, z, WeaponDefinition.Hitzone.TORSO, false, false)
	ws._host_upgrade_on_hit(_id, tg, z, WeaponDefinition.Hitzone.TORSO, false, s1)
	check("two_graves_once_per_shot", ws.impact_splashes == n0 + 1, ws.impact_splashes - n0)
	var z2: ZombieActor = _zombie(Vector3(24, -8, -40))
	await _wait(0.3)
	var av: WeaponDefinition = WeaponCatalog.get_def(&"kar98k_up")
	n0 = ws.impact_splashes
	ws._host_upgrade_on_hit(_id, av, z2, WeaponDefinition.Hitzone.TORSO, false, false)
	check("avalanche_body_no_splash", ws.impact_splashes == n0)
	ws._host_upgrade_on_hit(_id, av, z2, WeaponDefinition.Hitzone.HEAD, false, false)
	check("avalanche_headshot_splash", ws.impact_splashes == n0 + 1 and not z2.alive)
	n0 = ws.impact_splashes
	ws.host_explode(WeaponCatalog.get_def(&"law_up"), _id, Vector3(28, -7.5, -44))
	await _wait(1.2)
	check("law_cluster_bomblets", ws.impact_splashes == n0 + 4, ws.impact_splashes - n0)
	# Lure of the Lantern: a bolt stuck in the ground becomes a zombie attractor.
	var eye: Vector3 = me.global_position + Vector3.UP * 1.6
	ws._host_launch(_id, WeaponCatalog.get_def(&"crossbow_up"), 9001, eye, Vector3(0, -0.8, -0.6).normalized())
	var lured: bool = await _until(
		func() -> bool: return m.zombies.crowd.live_attractors().any(func(a: Node3D) -> bool: return a is Projectile),
		2.0
	)
	check("lure_bolt_attracts", lured)
	await _wait(4.5)
	# Skullcrusher alt-fire + Gemini dual wield (local controller, real input).
	m.zombies.host_kill_all()
	ws.host_give(_id, &"m16_up")
	await _wait(1.2)
	var alt: WeaponRuntime = me.weapons.alt_runtime()
	check("skullcrusher_alt_runtime", alt != null and alt.def.id == &"m16_up_gl", me.weapons.held_def().id)
	check("alt_owned_on_host", ws.validator.owns(_id, &"m16_up_gl"))
	var proj0: int = ws.explosions
	me.camera_rig.pitch = -0.7  # at the snow, a few metres ahead
	Input.action_press(&"alt_fire")
	await _wait(0.4)
	Input.action_release(&"alt_fire")
	check("alt_fire_shot", me.weapons.alt_shots >= 1, me.weapons.alt_shots)
	await _until(func() -> bool: return ws.explosions > proj0, 3.0)
	check("alt_grenade_exploded", ws.explosions > proj0)
	ws.host_give(_id, &"m1911_up")
	await _wait(1.0)
	var vm: Viewmodel = me.weapons.viewmodel
	var gun: Node3D = vm._guns.get(&"m1911_up", null) if vm != null else null
	check("gemini_left_gun", gun != null and gun.get_node_or_null(^"LeftGun") != null)
	var camo: bool = false
	if gun != null:
		for g: Node in gun.find_children("*", "GeometryInstance3D", true, false):
			camo = camo or (g as GeometryInstance3D).material_overlay != null
	check("vesperite_camo_applied", camo)
	# Wall-buy upgraded ammo + box ownership.
	ws.host_give(_id, &"m14_up")
	await _wait(0.3)
	check("box_counts_base_owned", ws.host_owns(_id, &"m14") and (ws.loadouts[_id]["ids"] as Array).has(&"m14_up"))
	var wb: WallBuy = m.interaction.find_by_name("WallBuy_M14") as WallBuy
	ws.validator.give(_id, WeaponCatalog.get_def(&"m14_up"), 3, 10)
	me.motor.teleport(wb.global_position + wb.global_transform.basis.z * 1.0 + Vector3.DOWN * 1.4)
	await _wait(0.3)
	check("upgraded_ammo_4500", wb.get_cost(me) == 4500, wb.get_prompt(me))
	var pts: int = m.points.get_points(_id)
	var ok: bool = m.interaction.host_handle(_id, wb.interact_id)
	var a: Array = ws.validator.ammo(_id, &"m14_up")
	check(
		"upgraded_ammo_refilled",
		ok and int(a[0]) == 20 and int(a[1]) == 184 and m.points.get_points(_id) == pts - 4500,
		[ok, a, m.interaction.last_denied]
	)


# --- 4. traps --------------------------------------------------------------------------------------


func _traps(m: Match, me: PlayerCharacter) -> void:
	var ts: TrapSystem = m.traps
	check("three_traps", ts.traps.size() == 3, ts.traps.size())
	var t2: Trap = ts.by_id(&"T2")
	var area: Transform3D = t2.area_marker.global_transform
	var pts_in: PackedVector3Array = t2.def.sample_points(area, 2.5)
	var zs: Array[ZombieActor] = []
	for i: int in 3:
		zs.append(_zombie(pts_in[i * 2]))
	await _wait(0.4)
	var inside: int = zs.filter(func(z: ZombieActor) -> bool: return t2.def.contains(area, z.global_position)).size()
	check("t2_zombies_inside", inside == 3, inside)
	var pts: int = m.points.get_points(_id)
	var ok: bool = await _use(me, t2, Vector3(0, -1.15, -1.0))
	check("t2_activated", ok and ts.phase(t2) == TrapSystem.Phase.ACTIVE, m.interaction.last_denied)
	check("t2_cost_1000", m.points.get_points(_id) == pts - 1000, m.points.get_points(_id))
	await _wait(0.6)
	check("t2_killed_all", zs.all(func(z: ZombieActor) -> bool: return not is_instance_valid(z) or not z.alive))
	check("t2_kill_points", m.points.get_points(_id) == pts - 1000 + 150, m.points.get_points(_id) - pts)
	ok = await _use(me, t2, Vector3(0, -1.15, -1.0))
	check("t2_refused_active", not ok and m.interaction.last_denied == "Trap active", m.interaction.last_denied)
	me.health.invulnerable = false
	me.health.restore_full()
	var hp0: float = me.health.health
	me.motor.teleport(pts_in[2] + Vector3.UP * 0.05)
	await _wait(0.5)
	var lost: float = hp0 - me.health.health
	me.motor.teleport(t2.global_position + Vector3(0, -1.15, -1.0))
	me.health.invulnerable = true
	check("t2_player_damage", lost > 35.0 and lost < 80.0 and not me.health.is_downed, lost)
	m.session.host_set_flag("trap.T2.until", Net.host_time() - 0.1)
	await _wait(0.2)
	check("t2_cooling", ts.phase(t2) == TrapSystem.Phase.COOLING)
	ok = await _use(me, t2, Vector3(0, -1.15, -1.0))
	check("t2_refused_cooling", not ok and m.interaction.last_denied == "Trap cooling down", m.interaction.last_denied)
	m.session.host_set_flag("trap.T2.ready", Net.host_time() - 0.1)
	await _wait(0.2)
	check("t2_ready_again", ts.phase(t2) == TrapSystem.Phase.READY)
	# T3 freeze + shatter.
	var t3: Trap = ts.by_id(&"T3")
	var ring: PackedVector3Array = t3.def.sample_points(t3.area_marker.global_transform, 2.5)
	var za: ZombieActor = _zombie(ring[ring.size() / 2])
	var zb: ZombieActor = _zombie(ring[ring.size() / 2 + 3])
	me.motor.teleport(
		t3.global_position + Vector3(0, 0.05, 0) + (t3.global_position - t3.def.ring_centre).normalized() * -0.8
	)
	await _wait(0.4)
	ts.host_activate(t3, _id)
	var frozen: bool = await _until(func() -> bool: return m.status.is_frozen(za) and m.status.is_frozen(zb), 1.0)
	check("t3_frozen", frozen and za.flags & ZombieActor.Flag.FROZEN != 0 and za.sim.frozen)
	var pos_a: Vector3 = za.global_position
	await _wait(0.8)
	check("t3_frozen_still", za.alive and za.global_position.distance_to(pos_a) < 0.05)
	m.targets.host_damage(
		za, DamageInfo.make(5.0, WeaponDefinition.Hitzone.TORSO, DamageInfo.Kind.BULLET, &"m1911", _id)
	)
	check("t3_shot_shatters", not za.alive and m.status.shatters >= 1)
	var gone: bool = await _until(func() -> bool: return not zb.alive, 3.5)
	check("t3_shatters_at_expiry", gone)
	ts.host_reset(t3)


# --- 5. hazards ------------------------------------------------------------------------------------


func _hazards(m: Match, me: PlayerCharacter) -> void:
	var hs: HazardSystem = m.hazards
	check("hazard_counts", hs.drums.size() == 6 and hs.icicles.size() == 2 and hs.breaker != null)
	var d: ExplosiveDrum = hs.drums[0]
	me.motor.teleport(d.global_position + Vector3(6, 0.1, 0))
	var z: ZombieActor = _zombie(d.global_position + Vector3(1.6, 0, 1.0))
	await _wait(0.4)
	m.targets.host_damage(
		d, DamageInfo.make(60.0, WeaponDefinition.Hitzone.TORSO, DamageInfo.Kind.BULLET, &"m1911", _id)
	)
	await _wait(0.2)
	check("drum_exploded", not d.alive and hs.drum_blasts >= 1)
	check("drum_chain", hs.drum_blasts >= 3, hs.drum_blasts)
	check("drum_killed_zombie", not z.alive)
	var r: int = m.rounds.current_round
	hs._on_round_started(r + 2)
	check("drum_not_back_after_2", not d.alive)
	hs._on_round_started(r + 3)
	check("drum_respawned_after_3", d.alive)
	var ic: IcicleCluster = hs.icicles[0]
	var below: Vector3 = Vector3(ic.global_position.x, ic.ground_y, ic.global_position.z)
	check("icicle_ground_found", ic.global_position.y - ic.ground_y > 3.0, ic.global_position.y - ic.ground_y)
	var zi: ZombieActor = _zombie(below + Vector3(0.5, 0, 0))
	await _wait(0.4)
	m.targets.host_damage(
		ic, DamageInfo.make(10.0, WeaponDefinition.Hitzone.TORSO, DamageInfo.Kind.BULLET, &"m1911", _id)
	)
	await _wait(0.8)
	check("icicles_dropped", not ic.alive)
	check("icicles_killed_below", not zi.alive and hs.icicle_kills >= 1, zi.global_position.distance_to(below))
	hs._on_round_started(r + 2)
	check("icicles_regrew_after_2", ic.alive)
	var br: LabBreaker = hs.breaker
	var zp: ZombieActor = _zombie(br.puddles[0])
	await _wait(0.5)
	var hp: float = zp.health
	var ok: bool = await _use(me, br, br.global_transform.basis.z * 1.0 + Vector3.DOWN * 1.25)
	check("breaker_flipped", ok and hs.breaker_active(), m.interaction.last_denied)
	await _wait(0.6)
	check("puddle_stun", zp.sim.state == ZombieSim.State.STAGGER, zp.sim.state_name())
	check("puddle_damage", zp.health < hp, [hp, zp.health])
	ok = m.interaction.host_handle(_id, br.interact_id)
	check("breaker_refused_active", not ok)
	m.session.host_set_flag(HazardSystem.FLAG_H3 + ".until", Net.host_time() - 0.1)
	await _wait(0.2)
	check("breaker_recharging", hs.breaker_cooling() and not m.interaction.host_handle(_id, br.interact_id))
