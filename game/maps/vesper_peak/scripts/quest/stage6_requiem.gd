# Stage 6 "Requiem" (finale), from the next round start after calibration: the round counter becomes
# a flickering "∞" (MatchHud "round_display"), normal spawns stop (RoundDirector.event_hold), the
# bridge re-extends and the Warden rises from the core pit onto the Lower Ring (finale Warden: phase
# 2 summons Galvanics; the Conduit / Requiem deals x3 to the exposed core; T3 freezes it — Step 12).
# Waves of zombies (2 + players every WAVE_TIME, up to a cap) climb from the pit and attack the three
# stabilizer pylons (PYLON_DPS per zombie within PYLON_REACH; weak lures pull them there); players
# repair a pylon by holding interact (+REPAIR per 0.5 s). All three down -> the Warden retreats, the
# Heart stays socketed and the nodes must be broken again (re-calibration), then the finale
# restarts at the following round start. Victory: every zombie dies, the Lazarus Blessing (all
# seven tonics ignoring the cap, restored on every revive; a personal Free Upgrade token), the
# reactor turns white-blue, the storm subsides for one round, VO + the ending moment, Journal
# badge + R09 + "requiem" (QuestGraph). Play continues.
# Authority: HOST.
extends RequiemObjective

enum Phase { WAITING, ACTIVE, WON, RECALIBRATE }

const WAVE_TIME: float = 10.0
const PYLON_REACH: float = 2.6
const PYLON_DPS: float = 30.0
const REPAIR: float = 60.0
const LURE_RADIUS: float = 26.0

var warden: ZombieActor = null
var failures: int = 0
var nodes: RequiemNodes = null
var finale_zombies: Array[ZombieActor] = []
var _wave_at: float = 0.0
var _lures: Array[Node3D] = []


func phase() -> int:
	return int(get_flag("ee.finale", Phase.WAITING))


func pylon_hp(i: int) -> float:
	return float(get_flag("ee.pylon.%d" % i, VesperQuestWorld.PYLON_MAX))


func on_activate() -> void:
	nodes = RequiemNodes.new(self)
	if phase() == Phase.ACTIVE:
		_fail(false)  # host rebuilt mid-finale: restart cleanly next round
	elif phase() == Phase.RECALIBRATE:
		nodes._next_at = now() + 1.0


func on_event(event: StringName, data: Dictionary) -> void:
	match event:
		&"round_started":
			if phase() == Phase.WAITING:
				begin()
		&"interact":
			var id: String = String(data.get("id", ""))
			if phase() == Phase.ACTIVE and id.begins_with("pylon_"):
				var i: int = int(id.trim_prefix("pylon_"))
				if pylon_hp(i) > 0.0:
					set_flag("ee.pylon.%d" % i, minf(pylon_hp(i) + REPAIR, VesperQuestWorld.PYLON_MAX))
					Audio.play_event_3d(&"pylon_repair", marker_pos(StringName("EE_Pylon_%d" % i)))
		&"zombie_killed":
			var a: ZombieActor = data.get("actor", null)
			if a != null and a == warden and phase() == Phase.ACTIVE:
				victory()
		&"damaged":
			if phase() == Phase.RECALIBRATE and nodes.on_damaged(data):
				set_flag("ee.finale", Phase.WAITING)
				vo(&"vo_calibrated", marker_pos(&"EE_CoreSocket") + Vector3.UP)


func begin() -> void:
	var rd: RoundDirector = m().rounds
	set_flag("ee.finale", Phase.ACTIVE)
	set_flag("round_display", "∞")
	for i: int in 3:
		set_flag("ee.pylon.%d" % (i + 1), VesperQuestWorld.PYLON_MAX)
	if rd != null:
		rd.event_hold = true
	bridge(true)
	var rise: Vector3 = marker_pos(&"EE_WardenRise")
	var p: Vector3 = m().zombies.crowd.snap(rise + Vector3(0, 6, -19.5), rise) if m().zombies.crowd != null else rise
	if not p.is_finite():
		p = rise + Vector3(0, 6, -19.5)
	var r: int = rd.current_round if rd != null else 1
	m().zombies.pending_meta = {
		"summon_archetype": &"galvanic", "summon_health": maxf(400.0, rd.special_health_value if rd != null else 400.0)
	}
	warden = WardenBehavior.host_spawn(m().zombies, p, 0.0, r, player_count())
	m().zombies.pending_meta = {}
	if warden != null:
		warden.set_meta(&"summon_archetype", &"galvanic")
		warden.set_meta(&"summon_health", maxf(400.0, rd.special_health_value if rd != null else 400.0))
		WonderFx.play(warden, WonderFx.Kind.RIFT, PackedVector3Array([p]), 3.0, WonderFx.Variant.GREEN)
		var b: WardenBehavior = warden.sim.behavior as WardenBehavior if warden.sim != null else null
		if b != null:
			b.phase_changed.connect(_on_warden_phase)
	_lure(true)
	_wave_at = now() + 3.0
	vo(&"vo_finale")
	log_info("The Requiem begins (round %d, Warden %s)" % [r, warden != null])


func _on_warden_phase(ph: int) -> void:
	if phase() != Phase.ACTIVE:
		return
	vo(&"vo_phase2" if ph == 1 else &"vo_phase3")


func _lure(on: bool) -> void:
	for l: Node3D in _lures:
		if is_instance_valid(l):
			l.queue_free()
	_lures.clear()
	var crowd: CrowdDirector = m().zombies.crowd
	if not on or crowd == null:
		return
	var w: VesperQuestWorld = world()
	for i: int in 3:
		var mk: MapMarker = w.markers.get(StringName("EE_Pylon_%d" % (i + 1)), null)
		if mk == null:
			continue
		var lure: Node3D = Node3D.new()
		lure.name = "PylonLure"
		lure.set_meta(&"attract_weak", true)
		mk.add_child(lure)
		lure.position = Vector3(0, 0.3, 0)
		crowd.add_attractor(lure, LURE_RADIUS)
		_lures.append(lure)


func on_tick(delta: float) -> void:
	match phase():
		Phase.RECALIBRATE:
			nodes.tick()
		Phase.ACTIVE:
			_tick_finale(delta)


func _tick_finale(delta: float) -> void:
	finale_zombies = finale_zombies.filter(func(z: ZombieActor) -> bool: return is_instance_valid(z) and z.alive)
	if now() >= _wave_at:
		_wave_at = now() + WAVE_TIME
		_wave()
	var alive: int = 0
	for i: int in range(1, 4):
		var hp: float = pylon_hp(i)
		if hp <= 0.0:
			continue
		var at: Vector3 = marker_pos(StringName("EE_Pylon_%d" % i))
		var n: int = 0
		for z: ZombieActor in m().zombies.actors.values():
			if z != warden and z.alive and z.global_position.distance_to(at) <= PYLON_REACH:
				n += 1
		if n > 0:
			hp -= PYLON_DPS * n * delta
			if int(hp / 100.0) != int(pylon_hp(i) / 100.0) or hp <= 0.0:
				Audio.play_event_3d(&"pylon_hit", at)
			set_flag("ee.pylon.%d" % i, maxf(roundf(hp), 0.0) if hp > 0.0 else 0.0)
			if hp <= 0.0:
				Audio.play_event_3d(&"pylon_down", at)
				vo(&"vo_pylon")
		alive += int(pylon_hp(i) > 0.0)
	if alive == 0:
		_fail(true)


func _wave() -> void:
	var cap: int = int(scaled(10.0, 4.0))
	if finale_zombies.size() >= cap:
		return
	var n: int = mini(2 + player_count(), cap - finale_zombies.size())
	var pits: Array[ZombieSpawner] = []
	for s: ZombieSpawner in m().zombies.spawners:
		if s.zone == &"Z13" and s.kind == ZombieSpawner.Kind.CLIMB:
			pits.append(s)
	for k: int in n:
		var at: Vector3 = (
			pits[randi() % pits.size()].global_position if not pits.is_empty() else marker_pos(&"EE_Pylon_1")
		)
		finale_zombies.append_array(spawn_zombies(at, 1))


# Debug / tests: pylon damage as zombies would deal it.
func host_damage_pylon(i: int, amount: float) -> void:
	set_flag("ee.pylon.%d" % i, maxf(pylon_hp(i) - amount, 0.0))


func _fail(announce: bool) -> void:
	failures += 1
	_lure(false)
	if warden != null and is_instance_valid(warden) and warden.alive:
		WonderFx.play(warden, WonderFx.Kind.RIFT, PackedVector3Array([warden.global_position]), 3.0)
		m().zombies.host_despawn(warden)
	warden = null
	if m().rounds != null:
		m().rounds.event_hold = false
		m().rounds.call(&"_check_end")
	set_flag("round_display", "")
	set_flag("ee.finale", Phase.RECALIBRATE)
	nodes.start()
	if announce:
		Audio.play_event(&"quest_fail")
		vo(&"vo_finale_fail")
	log_info("The Requiem failed (%d): re-calibrate" % failures)


func victory() -> void:
	_lure(false)
	warden = null
	set_flag("ee.finale", Phase.WON)
	set_flag("round_display", "")
	var rd: RoundDirector = m().rounds
	if rd != null:
		rd.event_hold = false
	m().zombies.host_kill_all()
	if rd != null and rd.phase == RoundDirector.Phase.ACTIVE:
		rd.host_skip_round()
	set_flag("ee.victory_at", now())
	set_flag("ee.reactor_calm", true)
	set_flag("ee.storm_calm_round", (rd.current_round if rd != null else 0) + 1)
	bridge(true)
	grant_blessing()
	vo(&"vo_victory", marker_pos(&"EE_CoreSocket") + Vector3.UP * 2.0)
	log_info("REQUIEM: the Warden falls")
	complete()


func grant_blessing() -> void:
	for id: int in m().players.avatars:
		set_flag(StageBlessing.blessed_key(id), true)
		StageBlessing.restore(m(), id)
		if m().powerups != null:
			m().powerups.host_give_token(id)


func on_debug_complete() -> void:
	if phase() != Phase.ACTIVE:
		begin()
	if warden != null and is_instance_valid(warden) and warden.alive:
		m().zombies.host_despawn(warden)
	victory()
