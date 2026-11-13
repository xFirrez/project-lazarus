# Client side of the Step 14 quest net test (see host_quest.gd). Phase a (--reconnect-phase=a):
# late join + carrying, then the shell kills it; phase b: rejoin, finale, victory.
extends "res://tests/net/autotest_base.gd"

var _phase: String = "b"


func _ready() -> void:
	timeout = 150.0
	_phase = CommandLine.get_value("reconnect-phase", "b")
	Net.register_message(&"_t_use", _on_use)
	Net.register_message(&"_t_step", _on_step)
	if _phase == "b":
		Journal.clear()
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
	_m().downed.show_screen = false


func _on_use(_sender: int, p: Array) -> void:
	var m: Match = _m()
	m.interaction.request(m.players.local_avatar(), m.interaction.get_by_id(int(p[0])))


func _ack(name: String) -> void:
	Net.send_reliable(1, &"_t_ack", [name])


func _flag(k: String, d: Variant = null) -> Variant:
	return _m().quest.flag(k, d)


func _on_step(_sender: int, p: Array) -> void:
	var m: Match = _m()
	var q: QuestSystem = m.quest
	var me: PlayerCharacter = m.players.local_avatar()
	var w: VesperQuestWorld = VesperQuestWorld.of(m)
	match String(p[0]):
		"late_join":
			var host_id: int = int(p[1])
			check("late_stage3_done", q.is_done(&"stage3") and q.is_done(&"stage2b"), q.describe())
			check("late_stage4_active", q.is_active(&"stage4"))
			check(
				"late_radio_live", bool(_flag("ee.radio_live", false)) and (_flag("ee.freq", []) as Array).size() == 3
			)
			check("late_shards", bool(_flag("ee.pod_shards", false)) and bool(_flag("ee.heart_charged", false)))
			check("late_carrier_host", w.heart.carrier() == host_id and w.heart.is_present())
			var host: PlayerCharacter = m.players.avatars.get(host_id, null)
			var ok: bool = await _until(
				func() -> bool: return host != null and host.stats().flag(PlayerStats.NO_SPRINT), 3.0
			)
			check("late_carrier_restricted", ok)
			check(
				"late_escort_hud", q.hud_lines().size() > 0 and q.hud_lines()[0].begins_with("The Heart"), q.hud_lines()
			)
			check("late_annotations", q.annotation(StringName((_flag("ee.freq_docs", ["L04"]) as Array)[0])) != "")
			check("late_shard_models_hidden", w.shard_state(&"a") == 2 and w.shard_state(&"c") == 2)
		"carrying":
			var ok: bool = await _until(func() -> bool: return me.stats().flag(PlayerStats.NO_SPRINT), 3.0)
			check("client_no_sprint", ok)
			var lo: Array = m.weapons.mirrored.get(me.peer_id, [[]])
			check("client_pistol_only", lo[0] == ["m1911"], lo)
			check("client_target_bias", me.has_meta(&"target_bias"))
			_ack("carrying")
			await get_tree().create_timer(1.0).timeout  # let the ack reach the host before the kill
			Log.info(&"autotest", "AUTOTEST READY client-a")
			return
		"rejoined":
			check("rejoin_quest_state", q.is_active(&"stage4") and q.is_done(&"stage3"))
			check("rejoin_heart_on_ground", w.heart.carrier() == 0 and w.heart.is_present())
			check("rejoin_not_restricted", not me.stats().flag(PlayerStats.NO_SPRINT))
		"finale":
			var ok: bool = await _until(func() -> bool: return q.round_display() == "∞", 3.0)
			check("finale_round_display", ok)
			check("finale_flag", int(_flag("ee.finale", 0)) == 1)
			var warden: bool = false
			for a: ZombieActor in m.zombies.actors.values():
				warden = warden or a.archetype.id == &"warden"
			check("finale_warden_replicated", warden)
			check("finale_pylons_full", is_equal_approx(float(_flag("ee.pylon.1", 0.0)), VesperQuestWorld.PYLON_MAX))
		"victory":
			var ok: bool = await _until(func() -> bool: return q.graph_done(&"requiem"), 5.0)
			check("victory_replicated", ok and int(_flag("ee.finale", 0)) == 2)
			check("client_r09_unlocked", Journal.is_unlocked(&"R09") and Journal.is_unlocked(&"requiem"))
			check("client_badge_2p", (Journal.badges(&"vesper_peak").get(&"requiem", []) as Array).has(2))
			ok = await _until(func() -> bool: return m.perks.ids_of(me.peer_id).size() == 7, 3.0)
			check("client_blessing", ok, m.perks.ids_of(me.peer_id))
			check("client_token", m.powerups.free_tokens(me.peer_id) == 1)
			check("client_reactor_calm", bool(_flag("ee.reactor_calm", false)))
			_ack("victory")
			finish(true)
			return
	_ack(String(p[0]))
