# quest (Step 14: AC-14.1 / 14.2 / 14.4 / 14.5) — the headless "quest runner" on vesper_peak, solo:
# every stage of "Requiem for Lazarus" completed through the real interaction / damage / kill paths
# (interact requests through InteractionSystem.host_handle, damage through TargetRegistry /
# WeaponSync.host_explode, kills credited to the Conduit), every failure rule forced (wrong
# frequency, wrong drawer order, the marked Galvanic escaping, a loose cable, the escort timer, all
# pylons destroyed) with the retry checked, then the rewards (all seven tonics past the cap and
# restored on revive, Free Upgrade token, badge + R09 + "requiem" in the Journal), the lore items
# (documents / reels / guestbook, Journal persistence after a reload), S1, S2, Snowblind, ravens,
# the departures board and the rare late Warden rule. Finally 3 host bots join (4 players) and the
# co-op scaling values and a debug-skip run through every stage are checked (`--bots` style).
extends "res://tests/net/autotest_base.gd"

var _id: int = 1
var _q: QuestSystem = null
var _w: VesperQuestWorld = null
var _s: VesperSecretsWorld = null


func _ready() -> void:
	timeout = 300.0
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


func _use(me: PlayerCharacter, it: Interactable) -> bool:
	var fp: Vector3 = it.focus_point()
	me.motor.teleport(fp + Vector3(0.6, -1.0, 0.6))
	me.velocity = Vector3.ZERO
	await get_tree().physics_frame
	me.motor.teleport(fp + Vector3(0.6, -1.0, 0.6))
	return _m().interaction.host_handle(me.peer_id, it.interact_id)


func _hit(t: HitTarget, amount: float, kind: DamageInfo.Kind, weapon: StringName) -> void:
	_m().targets.host_damage(t, DamageInfo.make(amount, WeaponDefinition.Hitzone.TORSO, kind, weapon, _id))


func _flag(k: String, d: Variant = null) -> Variant:
	return _q.flag(k, d)


func _zombie(at: Vector3) -> ZombieActor:
	var zs: ZombieSync = _m().zombies
	var arch: ZombieArchetype = zs.archetype(&"zombie")
	var p: Vector3 = zs.crowd.snap(at, at)
	return zs.host_spawn(
		arch, ZombieArchetype.Tier.WALK, p if p.is_finite() else at, 0.0, ZombieSpawner.Kind.RISER, -1, 50
	)


func _run() -> void:
	await _until(func() -> bool: return _m() != null and _m().players.local_avatar() != null, 20.0)
	var m: Match = _m()
	m.downed.show_screen = false
	var me: PlayerCharacter = m.players.local_avatar()
	_id = me.peer_id
	me.notarget = true
	me.health.invulnerable = true
	_q = m.quest
	_w = VesperQuestWorld.of(m)
	_s = VesperSecretsWorld.of(m)
	Journal.path_override = "user://journal_quest_sim.cfg"
	Journal.clear()
	await _until(func() -> bool: return m.zombies.crowd.is_ready(), 20.0)
	m.rounds.paused = true
	await _wait(0.5)
	m.zombies.host_kill_all()
	_structure(m)
	await _lore(m, me)
	await _s1(m, me)
	await _stage0(m)
	await _stage1(m, me)
	await _stage2a(m, me)
	await _stage2b(m, me)
	await _stage2c(m, me)
	await _stage3(m, me)
	await _stage4(m, me)
	await _stage5(m)
	await _stage6(m, me)
	await _secrets(m, me)
	await _coop_scaling(m)
	finish(true)


# --- structure -----------------------------------------------------------------------------------


func _structure(m: Match) -> void:
	check("two_graphs", _q.graphs.size() == 2, _q.graphs.size())
	check("stage0_active", _q.is_active(&"stage0"), _q.describe())
	check("secrets_active", _q.is_active(&"s1_office") and _q.is_active(&"ravens"))
	check("stage1_locked", _q.state(&"stage1") == QuestSystem.State.LOCKED)
	check("radio_not_live", not _q.is_active(&"stage1") and not bool(_flag("ee.radio_live", false)))
	check("late_warden_rule_on", m.rules.warden_late_rounds_enabled())
	check("dials_built", _w.dials.size() == 3 and _w.radio_tx != null)
	check("nodes_pylons_built", _w.nodes.size() == 4 and _w.pylons.size() == 3)
	check("drawers_built", _w.drawers.size() == 4 and _w.shard_pickups.size() == 3)
	check("heart_absent", not _w.heart.is_present())


# --- lore (AC-14.5) --------------------------------------------------------------------------------


func _lore(m: Match, me: PlayerCharacter) -> void:
	var lib: LoreLibrary = _q.vo.lore
	check("lore_valid", lib.validate().is_empty(), lib.validate())
	check("14_documents", lib.ids_of_kind("doc").size() == 14, lib.ids_of_kind("doc").size())
	check("9_reels", lib.ids_of_kind("reel").size() == 9, lib.ids_of_kind("reel"))
	var docs: int = 0
	var reels: int = 0
	for li: LoreItem in _s.lore_items:
		docs += int(li.kind == "doc")
		reels += int(li.kind == "reel")
	check("lore_items_14_docs_guestbook", docs == 15, docs)  # 14 + the guestbook clue
	check("lore_items_8_reels", reels == 8, reels)
	var l01: LoreItem = _item(&"L01")
	var ok: bool = await _use(me, l01)
	await _wait(0.1)
	check("read_doc", ok and DocumentReader.is_open() and Journal.is_unlocked(&"L01"), m.interaction.last_denied)
	check("reader_text", DocumentReader.is_open() and DocumentReader.current.text().contains("DO NOT RETURN"))
	DocumentReader.close_current()
	var r02: LoreItem = _item(&"R02")
	ok = await _use(me, r02)
	check("play_reel", ok and _q.vo.is_playing(&"R02") and Journal.is_unlocked(&"R02"))
	check("subtitle", _q.vo.current_text.begins_with("Nurse Ilse Kemper"), _q.vo.current_text)
	ok = await _use(me, r02)
	check("reel_busy_refused", not ok and m.interaction.last_denied == "Playing", m.interaction.last_denied)
	_q.vo.stop()
	Journal.forget_cache()
	check("journal_persists_reload", Journal.is_unlocked(&"L01") and Journal.is_unlocked(&"R02"))
	check("r09_locked", not Journal.is_unlocked(&"R09"))


func _item(id: StringName) -> LoreItem:
	for li: LoreItem in _s.lore_items:
		if li.entry_id == id:
			return li
	return null


# --- S1 ---------------------------------------------------------------------------------------------


func _s1(m: Match, me: PlayerCharacter) -> void:
	var uses0: int = int(_flag("ee.mirror_uses", 0))
	var ok: bool = await _use(me, _s.mirror)
	check("mirror_flash_without_clue", ok and int(_flag("ee.mirror_uses", 0)) == uses0 + 1)
	check("bookcase_closed", not _s.bookcase_door.is_open and not _q.is_done(&"s1_office"))
	check("crate_disabled", not _s.crate.is_available(me))
	ok = await _use(me, _item(&"guestbook"))
	DocumentReader.close_current()
	check("guestbook_read", ok and bool(_flag("ee.guestbook_read", false)))
	ok = await _use(me, _s.mirror)
	check("bookcase_open", ok and _s.bookcase_door.is_open and _q.is_done(&"s1_office"))
	var n0: int = m.perks.ids_of(_id).size()
	ok = await _use(me, _s.crate)
	check("crate_tonic", ok and m.perks.ids_of(_id).size() == n0 + 1, m.interaction.last_denied)
	ok = await _use(me, _s.crate)
	check("crate_once", not ok)
	m.perks.host_set_perks(_id, [])
	var ok_nav: bool = m.zones.zone_at(_s.crate.global_position) == &"Z03"
	check("office_is_z03", ok_nav, m.zones.zone_at(_s.crate.global_position))


# --- stage 0 / 1 --------------------------------------------------------------------------------


func _stage0(m: Match) -> void:
	m.rounds.host_start_round(2)
	check("no_radio_before_relays", not bool(_flag("ee.radio_live", false)))
	Power.host_set(Power.MAIN, true)
	m.relays.host_complete_all()
	await _wait(0.2)
	check("not_until_next_round", not bool(_flag("ee.radio_live", false)))
	m.rounds.host_skip_round()
	m.rounds.host_start_round(m.rounds.current_round + 1)
	await _wait(0.2)
	check("radio_live", bool(_flag("ee.radio_live", false)) and _q.is_done(&"stage0"))
	check("broadcast_vo", _q.vo.played_ids.has(&"vo_broadcast"))
	var docs: Array = _flag("ee.freq_docs", [])
	var digits: Array = _flag("ee.freq", [])
	check("three_freq_docs", docs.size() == 3 and digits.size() == 3, [docs, digits])
	var note_ok: bool = true
	for i: int in docs.size():
		note_ok = note_ok and _q.annotation(StringName(docs[i])).contains("%02d" % int(digits[i]))
	check("red_ink_annotations", note_ok)
	check("pool_only", docs.all(func(d: String) -> bool: return d in ["L04", "L06", "L08", "L09", "L10", "L12"]))
	m.rounds.host_skip_round()
	m.zombies.host_kill_all()


func _stage1(m: Match, me: PlayerCharacter) -> void:
	check("stage1_active", _q.is_active(&"stage1"))
	var ok: bool = await _use(me, _w.dials[0])
	check("dial_interact", ok and _w.dial(1) == 1, m.interaction.last_denied)
	var alive0: int = m.zombies.alive_count()
	ok = await _use(me, _w.radio_tx)
	await _wait(0.2)
	var o: QuestObjective = _q.objective(&"stage1")
	check("wrong_frequency_zombies", m.zombies.alive_count() == alive0 + 3, m.zombies.alive_count() - alive0)
	check("wrong_keeps_stage", _q.is_active(&"stage1") and _q.vo.played_ids.has(&"vo_wrong"))
	m.zombies.host_kill_all()
	var ans: Array = _flag("ee.freq", [])
	for i: int in 3:
		while _w.dial(i + 1) != int(ans[i]):
			_q.host_event(&"interact", {"id": StringName("radio_dial_%d" % (i + 1)), "peer": _id})
	o.set(&"_next_try", 0.0)
	ok = await _use(me, _w.radio_tx)
	check("contact", ok and _q.is_done(&"stage1") and _q.vo.played_ids.has(&"vo_contact"))
	check("stage2_parallel", _q.is_active(&"stage2a") and _q.is_active(&"stage2b") and _q.is_active(&"stage2c"))
	check("shard_hud", String(_flag("qhud.shards", "")).contains("0 / 3"), _flag("qhud.shards", ""))


# --- stage 2 ------------------------------------------------------------------------------------


func _stage2a(m: Match, me: PlayerCharacter) -> void:
	_hit(_w.ice, 1500.0, DamageInfo.Kind.BULLET, &"kar98k")
	check("bullet_no_break", not bool(_flag("ee.ice_broken", false)))
	await _wait(0.3)
	_hit(_w.ice, 900.0, DamageInfo.Kind.EXPLOSIVE, &"china_lake")
	check("one_blast_under_threshold", not bool(_flag("ee.ice_broken", false)))
	await _wait(0.3)
	_hit(_w.ice, 900.0, DamageInfo.Kind.EXPLOSIVE, &"china_lake")
	_hit(_w.ice, 500.0, DamageInfo.Kind.EXPLOSIVE, &"china_lake")
	check("china_lake_direct_plus_splash_breaks", bool(_flag("ee.ice_broken", false)))
	# The real frag explosion path also qualifies (1200 centre x2): verified on a fresh window below.
	var frag: WeaponDefinition = WeaponCatalog.get_def(&"frag")
	var v: float = load("res://maps/vesper_peak/scripts/quest/stage2a_frozen_heart.gd").call(
		&"hit_value", DamageInfo.Kind.EXPLOSIVE, &"frag", frag.splash_damage_centre
	)
	check("frag_qualifies", v >= 2000.0, v)
	check("shard_in_basin", _w.shard_state(&"a") == 1)
	var ok: bool = await _use(me, _w.shard_pickups["a"])
	check("shard_a", ok and _w.shard_state(&"a") == 2 and _q.is_done(&"stage2a"), m.interaction.last_denied)
	check("hud_1_of_3", String(_flag("qhud.shards", "")).contains("1 / 3"))


func _stage2b(m: Match, me: PlayerCharacter) -> void:
	var order: Array = _flag("ee.drawer_order", [])
	check("drawer_order", order.size() == 4 and order.duplicate().all(func(x: int) -> bool: return x >= 0 and x < 4))
	m.hazards.host_flip_breaker(_id)
	await _wait(0.3)
	check("symbols_visible_with_breaker", _w.get(&"_symbols")[0].visible)
	var wrong: int = (int(order[0]) + 1) % 4
	var alive0: int = m.zombies.alive_count()
	var ok: bool = await _use(me, _w.drawers[wrong])
	await _wait(0.2)
	check("wrong_drawer_zombies", m.zombies.alive_count() >= alive0 + 4, m.zombies.alive_count() - alive0)
	check("wrong_drawer_reset", int(_flag("ee.drawer_step", -1)) == 0 and not bool(_flag("ee.chain_open", false)))
	m.zombies.host_kill_all()
	for i: int in 4:
		ok = await _use(me, _w.drawers[int(order[i])])
	check("chain_open", ok and bool(_flag("ee.chain_open", false)))
	ok = await _use(me, _w.shard_pickups["b"])
	check("shard_b", ok and _q.is_done(&"stage2b"), m.interaction.last_denied)
	m.zombies.host_kill_all()


func _stage2c(m: Match, me: PlayerCharacter) -> void:
	var rd: RoundDirector = m.rounds
	for attempt: int in 2:
		rd.host_force_special(&"galvanic")
		if rd.phase != RoundDirector.Phase.ACTIVE:
			rd.host_start_round(rd.current_round + 1)
		var marked: bool = await _until(func() -> bool: return int(_flag("ee.marked", 0)) != 0, 25.0)
		check("marked_%d" % attempt, marked and rd.is_special_round(), rd.special_id)
		var a: ZombieActor = m.zombies.actors.get(int(_flag("ee.marked", 0)), null)
		check("marked_is_galvanic_%d" % attempt, a != null and a.archetype.id == &"galvanic")
		if attempt == 0:
			var aid: int = a.net_id
			_q.objective(&"stage2c").set(&"_marked_at", _q.now() - 41.0)
			await _wait(0.2)
			check("marked_escaped", int(_flag("ee.marked", 0)) == 0 and not m.zombies.actors.has(aid))
			check("escape_keeps_stage", _q.is_active(&"stage2c") and _w.shard_state(&"c") == 0)
			rd.host_skip_round()
			m.zombies.host_kill_all()
		else:
			_hit(a, 1.0e6, DamageInfo.Kind.BULLET, &"m1911")
			await _wait(0.2)
			check("shard_c_dropped", _w.shard_state(&"c") == 1, _flag("ee.shard.c.pos"))
			var ok: bool = await _use(me, _w.shard_pickups["c"])
			check("shard_c", ok and _q.is_done(&"stage2c"), m.interaction.last_denied)
	rd.host_skip_round()
	m.zombies.host_kill_all()
	check("all_shards_hud", String(_flag("qhud.shards", "")).contains("3 / 3"))
	check("stage3_active", _q.is_active(&"stage3"))


# --- stage 3 ------------------------------------------------------------------------------------


func _stage3(m: Match, me: PlayerCharacter) -> void:
	var ok: bool = await _use(me, _w.pod)
	check("shards_in_pod", ok and bool(_flag("ee.pod_shards", false)) and String(_flag("qhud.shards", "")) == "")
	var need: int = int(_flag("ee.souls_needed", 0))
	check("souls_needed_solo_30", need == 30, need)
	var pod_at: Vector3 = _w.pod.global_position
	var z: ZombieActor = _zombie(pod_at + Vector3(3, 0, 0))
	_hit(z, 1.0e6, DamageInfo.Kind.BULLET, &"m1911")
	z = _zombie(pod_at + Vector3(14, 0, 0))
	if z != null and z.global_position.distance_to(pod_at) > 10.0:
		_hit(z, 1.0e6, DamageInfo.Kind.BULLET, &"lazarus_conduit")
	await _wait(0.1)
	check("only_close_conduit_kills", int(_flag("ee.souls", 0)) == 0, _flag("ee.souls"))
	var loose_seen: bool = false
	var paused_ok: bool = false
	var guard: int = 0
	while not bool(_flag("ee.heart_charged", false)) and guard < 120:
		guard += 1
		for c: int in 2:
			if bool(_flag("ee.cable.%d" % (c + 1), false)):
				loose_seen = true
				var before: int = int(_flag("ee.souls", 0))
				z = _zombie(pod_at + Vector3(2, 0, 1))
				_hit(z, 1.0e6, DamageInfo.Kind.BULLET, &"lazarus_conduit_up")
				await _wait(0.05)
				paused_ok = int(_flag("ee.souls", 0)) == before
				ok = await _use(me, _w.cables[c])
				check("cable_%d_reseated" % (c + 1), ok and not bool(_flag("ee.cable.%d" % (c + 1), false)))
		z = _zombie(pod_at + Vector3(2, 0, -1))
		if z != null:
			_hit(z, 1.0e6, DamageInfo.Kind.BULLET, &"lazarus_conduit")
		await get_tree().physics_frame
	check("surge_cable_loose", loose_seen and bool(_flag("ee.surge.1", false)) and bool(_flag("ee.surge.2", false)))
	check("charging_paused_while_loose", paused_ok)
	check("heart_charged", _q.is_done(&"stage3") and int(_flag("ee.souls", 0)) >= 30 and _w.heart.is_present())
	m.zombies.host_kill_all()


# --- stage 4 ------------------------------------------------------------------------------------


func _stage4(m: Match, me: PlayerCharacter) -> void:
	var h: CarryItem = _w.heart
	var ok: bool = await _use(me, h)
	await _wait(0.1)
	check("heart_picked", ok and h.carrier() == _id, m.interaction.last_denied)
	check("escort_timer", float(_flag("ee.escort_until", 0.0)) > _q.now() + 230.0)
	check("carry_no_sprint", me.stats().flag(PlayerStats.NO_SPRINT))
	check(
		"carry_pistol_only",
		m.weapons.is_carrying(_id) and m.weapons.mirrored[_id][0] == ["m1911"],
		m.weapons.mirrored[_id]
	)
	check("carry_zombie_bias", me.has_meta(&"target_bias"))
	check("bridge_locked", not _bridge_open(m))
	check("spawns_x1_5", is_equal_approx(m.spawns.rate_scale, 1.5) and m.spawns.extra_zones.has(&"Z10"))
	check("hud_timer", String(_flag("qhud.escort", "")).begins_with("The Heart"))
	_q.request_drop(&"heart")
	await _wait(0.1)
	check("heart_dropped", h.carrier() == 0 and h.is_present() and not me.stats().flag(PlayerStats.NO_SPRINT))
	check("loadout_back", not m.weapons.is_carrying(_id))
	ok = await _use(me, h)
	m.perks.host_grant(_id, &"second_wind", true)  # solo: a down without it is a game over
	m.downed.host_force_down(_id)
	await _wait(0.1)
	check("auto_drop_on_down", h.carrier() == 0)
	m.downed.host_revive(_id)
	await _wait(0.2)
	# Failure: the timer expires -> back to the pod, available from the next round start.
	_q.host_set("ee.escort_until", _q.now() - 0.1)
	await _wait(0.2)
	check(
		"escort_failed", not h.is_present() and float(_flag("ee.escort_until", 0.0)) == 0.0 and _q.is_active(&"stage4")
	)
	check("bridge_restored", _bridge_open(m) and is_equal_approx(m.spawns.rate_scale, 1.0))
	m.rounds.host_skip_round()
	m.rounds.host_start_round(m.rounds.current_round + 1)
	await _wait(0.2)
	check("heart_back_next_round", h.is_present() and h.ground_position().distance_to(h.home) < 0.1)
	ok = await _use(me, h)
	check("heart_repicked", ok and h.carrier() == _id)
	ok = await _use(me, _w.socket)
	check(
		"socketed", ok and _q.is_done(&"stage4") and bool(_flag("ee.heart_socketed", false)), m.interaction.last_denied
	)
	await _wait(0.1)
	check("carry_cleared", not m.weapons.is_carrying(_id) and not me.has_meta(&"target_bias") and not h.is_present())
	m.rounds.host_skip_round()
	m.zombies.host_kill_all()


func _bridge_open(m: Match) -> bool:
	for d: Node in m.map_root.find_children("*", "NavDoor", true, false):
		if (d as NavDoor).solid_when_open:
			return (d as NavDoor).is_open
	return false


# --- stage 5 / 6 --------------------------------------------------------------------------------


func _break_nodes(_m: Match, tag: String) -> void:
	var up: StringName = WeaponCatalog.upgrade_of(&"m1911").id
	for i: int in 4:
		var on: bool = await _until(func() -> bool: return int(_flag("ee.node", 0)) == i + 1, 12.0)
		check("%s_node_%d_emerges" % [tag, i + 1], on, _flag("ee.node"))
		var n: QuestTarget = _w.nodes[i]
		var hp0: float = float(_flag("ee.node_hp", 0.0))
		_hit(n, 400.0, DamageInfo.Kind.BULLET, &"m1911")
		if i == 0:
			check("%s_node_immune_unupgraded" % tag, is_equal_approx(float(_flag("ee.node_hp", 0.0)), hp0))
			_hit(_w.nodes[1], 1.0e5, DamageInfo.Kind.BULLET, up)
			check("%s_inactive_node_ignored" % tag, int(_flag("ee.nodes_broken", 0)) == 0)
		_hit(n, 1.0e5, DamageInfo.Kind.BULLET, up)
	await _wait(0.1)


func _stage5(m: Match) -> void:
	check("stage5_active", _q.is_active(&"stage5"))
	check("node_hp_solo", is_equal_approx(_q.objective(&"stage5").get(&"nodes").call(&"health"), 500.0))
	await _break_nodes(m, "s5")
	check("calibrated", _q.is_done(&"stage5") and _q.is_active(&"stage6"))


func _stage6(m: Match, me: PlayerCharacter) -> void:
	var rd: RoundDirector = m.rounds
	check("finale_waits_for_round", int(_flag("ee.finale", 0)) == 0)
	rd.host_start_round(rd.current_round + 1)
	await _wait(0.3)
	var o: QuestObjective = _q.objective(&"stage6")
	check("finale_active", int(_flag("ee.finale", 0)) == 1 and _q.round_display() == "∞" and rd.event_hold)
	var w: ZombieActor = o.get(&"warden")
	check("warden_rose", w != null and w.archetype.id == &"warden", w)
	check("warden_on_ring", w != null and m.zones.zone_at(w.global_position) == &"Z13")
	check("warden_summons_galvanics", w != null and w.get_meta(&"summon_archetype", &"") == &"galvanic")
	check("bridge_extended", _bridge_open(m))
	await _wait(3.5)
	check("finale_waves", (o.get(&"finale_zombies") as Array).size() > 0)
	# Repair works; then every pylon falls -> fail, the Warden retreats, re-calibrate.
	o.call(&"host_damage_pylon", 1, 400.0)
	var hp1: float = float(_flag("ee.pylon.1", 0.0))
	var ok: bool = await _use(me, _w.pylons[0])
	check("pylon_repair", ok and float(_flag("ee.pylon.1", 0.0)) > hp1, m.interaction.last_denied)
	for i: int in 3:
		o.call(&"host_damage_pylon", i + 1, 5000.0)
	await _wait(0.2)
	check("finale_failed", int(_flag("ee.finale", 0)) == 3 and not rd.event_hold and _q.round_display() == "")
	check("warden_retreated", w == null or not is_instance_valid(w) or not m.zombies.actors.has(w.net_id))
	check("heart_stays", bool(_flag("ee.heart_socketed", false)) and _q.is_active(&"stage6"))
	m.zombies.host_kill_all()
	await _break_nodes(m, "s6")
	check("recalibrated", int(_flag("ee.finale", 0)) == 0)
	rd.host_skip_round()
	m.zombies.host_kill_all()
	rd.host_start_round(rd.current_round + 1)
	await _wait(0.3)
	w = o.get(&"warden")
	check("finale_retry", int(_flag("ee.finale", 0)) == 1 and w != null)
	m.perks.host_set_perks(_id, [])
	_hit(w, 1.0e9, DamageInfo.Kind.DEBUG, &"")
	await _wait(0.3)
	check("victory", _q.is_done(&"stage6") and _q.graph_done(&"requiem") and int(_flag("ee.finale", 0)) == 2)
	check("all_zombies_dead", m.zombies.alive_count() == 0, m.zombies.alive_count())
	check("all_seven_tonics", m.perks.ids_of(_id).size() == 7, m.perks.ids_of(_id))
	check("free_upgrade_token", m.powerups.free_tokens(_id) == 1 and m.forge.cost(_id) == 0)
	check("reactor_calm", bool(_flag("ee.reactor_calm", false)))
	check(
		"storm_calm",
		(
			int(_flag("ee.storm_calm_round", 0)) == rd.current_round + 1
			or int(_flag("ee.storm_calm_round", 0)) >= rd.current_round
		)
	)
	await _wait(0.2)
	var art: VesperArt = m.map_root.get(&"art") as VesperArt
	check("storm_calm_applied", art != null and art.storm.calm)
	check("ending_moment", _w.ending_active())
	check(
		"badge",
		Journal.badges(&"vesper_peak").has(&"requiem") and (Journal.badges(&"vesper_peak")[&"requiem"] as Array).has(1)
	)
	check("r09_unlocked", Journal.is_unlocked(&"R09") and Journal.is_unlocked(&"requiem"))
	check("badge_on_map_card", MapSelectScreen.badge_text(&"vesper_peak").contains("Requiem"))
	check("blessing_active", _q.is_active(&"blessing"))
	m.downed.host_force_down(_id)
	await _wait(0.2)
	check("perks_lost_on_down", m.perks.ids_of(_id).size() < 7, m.perks.ids_of(_id).size())
	m.downed.host_revive(_id)
	await _wait(0.2)
	check("blessing_restored_on_revive", m.perks.ids_of(_id).size() == 7, m.perks.ids_of(_id))
	check("round_continues", rd.phase != RoundDirector.Phase.GAME_OVER)


# --- minor secrets ---------------------------------------------------------------------------------


func _secrets(m: Match, me: PlayerCharacter) -> void:
	Power.host_set(Power.MAIN, false)
	_hit(_s.waterfall, 2000.0, DamageInfo.Kind.EXPLOSIVE, &"law")
	check("waterfall_needs_power", not bool(_flag("ee.s2_open", false)))
	Power.host_set(Power.MAIN, true)
	_hit(_s.waterfall, 500.0, DamageInfo.Kind.BULLET, &"m1911")
	check("waterfall_bullets_no", not bool(_flag("ee.s2_open", false)))
	_hit(_s.waterfall, 300.0, DamageInfo.Kind.BULLET, &"ray_pistol")
	check(
		"waterfall_ray_pistol",
		bool(_flag("ee.s2_open", false)) and _s.waterfall_door.is_open and _q.is_done(&"s2_grotto")
	)
	var ok: bool = await _use(me, _s.grotto_box)
	check("grotto_vo", ok and _q.vo.played_ids.has(&"vo_grotto"))
	check("grotto_zone", m.zones.zone_at(_s.grotto_box.global_position) == &"Z06")
	for i: int in 3:
		ok = await _use(me, _s.music_boxes[i])
		check("music_box_%d" % (i + 1), ok and bool(_flag("ee.mb.%d" % (i + 1), false)))
	check("snowblind", _q.is_done(&"snowblind") and float(_flag("ee.snowblind_at", 0.0)) > 0.0)
	ok = await _use(me, _s.music_boxes[0])
	check("music_box_once", not ok)
	var pu0: int = m.powerups.drops.size()
	for i: int in 5:
		_hit(_s.ravens[i], 50.0, DamageInfo.Kind.BULLET, &"m1911")
	await _wait(0.1)
	check("ravens_reward", _q.is_done(&"ravens") and m.powerups.drops.size() == pu0 + 2, m.powerups.drops.size() - pu0)
	check("departures_board", _s.get(&"_board") != null)


# --- 4 players (AC-14.1 scaling) ------------------------------------------------------------------


func _coop_scaling(m: Match) -> void:
	for i: int in 3:
		m.players.add_bot("Bot%d" % (i + 1))
	await _wait(0.3)
	check("four_players", _q.player_count() == 4, _q.player_count())
	var o: QuestObjective = _q.objective(&"blessing")
	check("souls_4p_60", is_equal_approx(o.scaled(30.0, 10.0), 60.0))
	check("node_hp_4p", is_equal_approx(RequiemNodes.new(o as RequiemObjective).health(), 1250.0))
	check("finale_cap_4p", is_equal_approx(o.scaled(10.0, 4.0), 22.0))
	note("quest events %d, completed %s" % [_q.events_sent, str(_q.completed_log)])
