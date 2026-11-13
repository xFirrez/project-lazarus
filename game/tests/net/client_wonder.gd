# Client side of the Step 12 net test (see host_wonder.gd): picks up a part by its own request and
# sees the shared flag, fires the Conduit and the Ray Pistol with real input, sees arcs /
# ELECTROCUTED copies / the plasma burst / the disintegration, the special round state and rifts,
# and the Warden's plate count.
extends "res://tests/net/autotest_base.gd"

var _fire: bool = false
var _saw_electrocuted: bool = false


func _ready() -> void:
	timeout = 150.0
	Net.register_message(&"_t_use", _on_use)
	Net.register_message(&"_t_step", _on_step)
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
	var me: PlayerCharacter = _m().players.local_avatar()
	me.bot_driver = func(_p: PlayerCharacter, _d: float) -> PlayerInputFrame:
		var f: PlayerInputFrame = PlayerInputFrame.new()
		f.fire = _fire
		return f
	me.weapons.recoil_enabled = false
	me.weapons.perfect_accuracy = true


func _physics_process(_delta: float) -> void:
	if _saw_electrocuted or _m() == null or _m().zombies == null:
		return
	for a: ZombieActor in _m().zombies.actors.values():
		if a.flags & ZombieActor.Flag.ELECTROCUTED != 0:
			_saw_electrocuted = true


func _on_use(_sender: int, p: Array) -> void:
	var m: Match = _m()
	m.interaction.request(m.players.local_avatar(), m.interaction.get_by_id(int(p[0])))


func _ack(name: String) -> void:
	Net.send_reliable(1, &"_t_ack", [name])


func _fire_at(at: Vector3) -> void:
	var me: PlayerCharacter = _m().players.local_avatar()
	await _until(func() -> bool: return me.weapons.held() != null and me.weapons.held().is_ready(), 5.0)
	var eye: Vector3 = me.weapons.eye_position()
	var d: Vector3 = (at - eye).normalized()
	me.set_view(atan2(-d.x, -d.z), asin(d.y))
	var before: int = me.weapons.shots_total
	for i: int in 120:
		_fire = i % 2 == 0
		await get_tree().physics_frame
		if me.weapons.shots_total > before:
			break
	_fire = false
	check("fired_%s" % me.weapons.held_def().id, me.weapons.shots_total > before)


func _on_step(_sender: int, p: Array) -> void:
	var m: Match = _m()
	match String(p[0]):
		"part":
			var ok: bool = await _until(func() -> bool: return m.buildables.has_part(&"conduit", &"coil"), 3.0)
			check("part_shared_client", ok)
			check("hud_parts_line", not m.buildables.hud_lines().is_empty())
		"fire":
			await _until(func() -> bool: return m.players.local_avatar().weapons.held_def() != null, 3.0)
			await get_tree().create_timer(0.8).timeout
			await _fire_at(p[1])
		"chain_seen":
			var fx: WonderFx = m.wonder_fx
			var arcs: bool = await _until(func() -> bool: return int(fx.shown.get(WonderFx.Kind.ARC, 0)) > 0, 3.0)
			check("arcs_shown_client", arcs)
			var fl: Array = []
			for a: ZombieActor in m.zombies.actors.values():
				fl.append([a.net_id, a.flags, a.action])
			var seen: bool = await _until(func() -> bool: return _saw_electrocuted, 2.0)
			check("electrocuted_copy", seen, fl)
		"ray_seen":
			var fx: WonderFx = m.wonder_fx
			var burst: bool = await _until(func() -> bool: return int(fx.shown.get(WonderFx.Kind.BURST, 0)) > 0, 3.0)
			check("plasma_burst_client", burst)
		"special":
			var ok: bool = await _until(func() -> bool: return m.rounds.special_id == &"galvanic", 3.0)
			check("special_round_client", ok)
			var rift: bool = await _until(
				func() -> bool: return int(m.wonder_fx.shown.get(WonderFx.Kind.RIFT, 0)) > 0, 4.0
			)
			check("rift_client", rift)
			check("atmosphere_client", await _until(func() -> bool: return m.specials.atmosphere > 0.2, 4.0))
		"warden":
			var ok: bool = await _until(
				func() -> bool:
					var a: ZombieActor = m.zombies.actors.get(int(p[1]), null)
					return a != null and int(a.get_meta(&"warden_plates", 3)) == 2,
				4.0
			)
			check("warden_plates_client", ok)
		"done":
			_ack("done")
			finish(true)
			return
	_ack(String(p[0]))
