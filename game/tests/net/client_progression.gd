# Client side of the Step 11 progression net test (see host_progression.gd): late-join relay / trap
# flags, its own relay start, pause replication, relays_done + bridge + reactor + Forge on this peer,
# its own Forge job and upgrade, its trap activation and kill points, FROZEN on its zombie copy, an
# impact splash shown, a fuel drum's death and respawn.
extends "res://tests/net/autotest_base.gd"


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


func _on_use(_sender: int, p: Array) -> void:
	var m: Match = _m()
	m.interaction.request(m.players.local_avatar(), m.interaction.get_by_id(int(p[0])))


func _ack(name: String) -> void:
	Net.send_reliable(1, &"_t_ack", [name])


func _on_step(_sender: int, p: Array) -> void:
	var m: Match = _m()
	var me: PlayerCharacter = m.players.local_avatar()
	match String(p[0]):
		"late_join":
			check("late_power_on", Power.is_on())
			check("late_r1_done", m.relays.state(0) == RelaySystem.State.DONE)
			check("late_r2_idle", m.relays.state(1) == RelaySystem.State.IDLE)
			check("late_t1_active", m.traps.phase(m.traps.by_id(&"T1")) == TrapSystem.Phase.ACTIVE)
			check("late_forge_dormant", not m.forge.is_unlocked())
		"paused":
			var ok: bool = await _until(func() -> bool: return m.relays.is_paused(1), 3.0)
			check("pause_replicated", ok and m.relays.progress_of(1) >= 1.0, m.relays.progress_of(1))
		"relays_done":
			var ok: bool = await _until(func() -> bool: return m.relays.all_done(), 3.0)
			check("relays_done_replicated", ok and m.relays.done_count() == 3)
			check("forge_unlocked_client", m.forge.is_unlocked())
			var open: bool = await _until(func() -> bool: return _bridge_open(m), 3.0)
			check("bridge_extended_client", open)
			var rs: Array[Node] = m.map_root.find_children("*", "ReactorState", true, false)
			await get_tree().process_frame
			check(
				"reactor_stabilized_client",
				rs.size() == 1 and (rs[0] as ReactorState).stage == ReactorState.Stage.STABILIZED
			)
		"forging":
			var ok: bool = await _until(func() -> bool: return m.forge.phase(0) == ForgeSystem.Phase.FORGING, 3.0)
			check("forge_job_replicated", ok and int(m.forge.job_of(0)[0]) == me.peer_id)
			check("m14_gone_locally", me.weapons.inventory.slot_of(&"m14") < 0)
		"took_upgrade":
			var ok: bool = await _until(func() -> bool: return me.weapons.inventory.slot_of(&"m14_up") >= 0, 5.0)
			check("m14_up_in_inventory", ok)
			check("forge_idle_client", m.forge.phase(0) == ForgeSystem.Phase.IDLE)
		"t2":
			check("t2_active_client", m.traps.phase(m.traps.by_id(&"T2")) == TrapSystem.Phase.ACTIVE)
			check("t2_points_client", m.points.get_points(me.peer_id) == 1150, m.points.get_points(me.peer_id))
		"frozen":
			var nid: int = int(p[1])
			var ok: bool = await _until(
				func() -> bool:
					return (
						m.zombies.actors.has(nid)
						and (m.zombies.actors[nid] as ZombieActor).flags & ZombieActor.Flag.FROZEN != 0
					),
				3.0
			)
			check("frozen_flag_client", ok)
		"splash":
			var ok: bool = await _until(func() -> bool: return m.weapons.splashes_shown >= 1, 3.0)
			check("splash_shown_client", ok)
		"drum_dead":
			var t: HitTarget = m.targets.get_target(int(p[1]))
			var ok: bool = await _until(func() -> bool: return t != null and not t.alive, 3.0)
			check("drum_dead_client", ok)
		"drum_back":
			var t: HitTarget = m.targets.get_target(int(p[1]))
			var ok: bool = await _until(func() -> bool: return t != null and t.alive, 3.0)
			check("drum_back_client", ok)
			_ack(String(p[0]))
			await get_tree().create_timer(0.5).timeout
			finish(true)
			return
	_ack(String(p[0]))


func _bridge_open(m: Match) -> bool:
	for d: Node in m.map_root.find_children("*", "NavDoor", true, false):
		if (d as NavDoor).solid_when_open:
			return (d as NavDoor).is_open
	return false
