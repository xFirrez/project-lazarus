# round_flow (AC-6.2, AC-6.4, AC-6.5, solo part of AC-6.6): solo session on vesper_peak.
#  1. Rounds: the intro leads into round 1 with N(1,1) = 6 zombies at hp(1); a forced re-queue
#     returns the zombie to the queue (still counts); killing every alive zombie while the queue is
#     not empty does not end the round; the round ends only when all are dead; intermission ~10 s;
#     events in order; last-zombie promotion; round 2 zombies have hp(2).
#  2. Economy: hit / kill points per type; purchases deduct; insufficient funds refused; ammo full
#     refused without charge; barricade repair pays 10 per plank.
#  3. Doors: buying D01 opens the NavDoor, unlocks Z03 (its spawners become active) and connects
#     the navigation (a path from a Z03 spawner to the player exists).
#  4. Downed in solo = game over with a summary.
extends "res://tests/net/autotest_base.gd"

var _stage: int = 0
var _t0: float = 0.0
var _round_end_time: float = -1.0
var _requeued_once: bool = false
var _killed_while_queue: bool = false
var _game_over_round: int = -1
var _game_over_rows: Array = []


func _ready() -> void:
	timeout = 150.0


func _m() -> Match:
	return Match.current


func _physics_process(_delta: float) -> void:
	var m: Match = _m()
	if m == null or m.players == null or m.players.local_avatar() == null or not m.zombies.crowd.is_ready():
		return
	var me: PlayerCharacter = m.players.local_avatar()
	var rd: RoundDirector = m.rounds
	match _stage:
		0:
			me.health.invulnerable = true
			me.notarget = true
			m.downed.show_screen = false
			m.downed.game_over.connect(_on_game_over)
			check("starts_in_intro", rd.phase == RoundDirector.Phase.INTRO, rd.phase_name())
			check("starting_points", m.points.get_points(me.peer_id) == 500, m.points.get_points(me.peer_id))
			_stage = 1
		1:
			if rd.phase == RoundDirector.Phase.ACTIVE:
				check("round1_total", rd.total == 6 and rd.current_round == 1, [rd.current_round, rd.total])
				check("round1_hp", is_equal_approx(rd.zombie_health(), 150.0), rd.zombie_health())
				_stage = 2
		2:
			# Wait for two zombies, re-queue one, kill the other with a bullet headshot (+100).
			if rd.round_ids.size() >= 2:
				var ids: Array = rd.round_ids.keys()
				var a: ZombieActor = m.zombies.actors[ids[0]]
				check("spawn_hp_matches_round", is_equal_approx(a.max_health, 150.0), a.max_health)
				var before_q: int = rd.queue.size()
				m.zombies._on_requeue(a.sim, "test")
				check(
					"requeue_back_in_queue",
					rd.queue.size() == before_q + 1 and rd.requeued == 1 and rd.total == 6,
					[rd.queue.size(), before_q]
				)
				var b: ZombieActor = m.zombies.actors[ids[1]]
				var p0: int = m.points.get_points(me.peer_id)
				_hit(m, b, 40.0, WeaponDefinition.Hitzone.TORSO, DamageInfo.Kind.BULLET)
				_hit(m, b, 40.0, WeaponDefinition.Hitzone.TORSO, DamageInfo.Kind.BULLET)  # same frame: once
				check(
					"hit_points_once_per_shot",
					m.points.get_points(me.peer_id) == p0 + 10,
					m.points.get_points(me.peer_id) - p0
				)
				_stage = 3
		3:
			var p1: int = m.points.get_points(me.peer_id)
			var b2: ZombieActor = _any_round_zombie(m)
			if b2 != null:
				_hit(m, b2, 5000.0, WeaponDefinition.Hitzone.HEAD, DamageInfo.Kind.BULLET)
				check(
					"head_kill_points",
					m.points.get_points(me.peer_id) == p1 + 100,
					m.points.get_points(me.peer_id) - p1
				)
				_stage = 4
		4:
			# Kill whatever is alive (DEBUG kind: no points) until the round ends.
			for id: int in rd.round_ids.keys():
				var a: ZombieActor = m.zombies.actors.get(id, null)
				if a != null:
					m.zombies.host_kill(a)
			if rd.phase == RoundDirector.Phase.ACTIVE and rd.round_ids.is_empty() and not rd.queue.is_empty():
				_killed_while_queue = true
			if rd.phase == RoundDirector.Phase.INTERMISSION:
				check("not_ended_early", _killed_while_queue)
				check("ended_with_all_dead", rd.killed == rd.total, [rd.killed, rd.total])
				_round_end_time = elapsed()
				_stage = 5
		5:
			if rd.phase == RoundDirector.Phase.ACTIVE:
				var gap: float = elapsed() - _round_end_time
				check("intermission_10s", absf(gap - 10.0) < 0.6, gap)
				check("round2", rd.current_round == 2 and rd.total == 8, [rd.current_round, rd.total])
				check("round2_hp", is_equal_approx(rd.zombie_health(), 250.0), rd.zombie_health())
				_stage = 6
		6:
			# Leave the last two alive: they get promoted to Run.
			if rd.remaining() > 2:
				var a3: ZombieActor = _any_round_zombie(m)
				if a3 != null and rd.round_ids.size() > 0 and rd.remaining() > 2:
					m.zombies.host_kill(a3)
			elif rd.round_ids.size() == rd.remaining():
				_stage = 7
				_t0 = elapsed()
		7:
			if elapsed() - _t0 > 0.5:
				var all_run: bool = true
				for id: int in rd.round_ids:
					var a4: ZombieActor = m.zombies.actors[id]
					all_run = all_run and (a4.tier >= ZombieArchetype.Tier.RUN or a4.is_crawler())
				check("last_two_promoted", rd.promoted and all_run, rd.events.slice(-3))
				_check_order(rd.events)
				_stage = 8
		8:
			_economy_and_doors(m, me)
			_stage = 9
			_t0 = elapsed()
		9:
			# Navigation re-bake is threaded: wait, then path from a Z03 spawner to the player.
			if elapsed() - _t0 > 2.0:
				var sp: ZombieSpawner = _spawner(m, "Spawn_Z03_W1")
				var len: float = m.zombies.crowd.path_length_now(sp.global_position, me.global_position)
				check("d01_nav_connected", len > 30.0 and len < 90.0, len)
				var z03: Array[ZombieSpawner] = m.zombies.spawners.filter(
					func(s: ZombieSpawner) -> bool: return s.zone == &"Z03"
				)
				check(
					"z03_spawners_active",
					m.zones.active_zones().has(&"Z03") and z03.size() >= 2,
					m.zones.active_zones()
				)
				SurvivalCommands.host_exec(me.peer_id, "down_me", 0)
				_t0 = elapsed()
				_stage = 10
		10:
			if _game_over_round > 0 or elapsed() - _t0 > 3.0:
				check("solo_down_game_over", _game_over_round == 2 and m.downed.is_game_over, _game_over_round)
				check(
					"summary_rows",
					_game_over_rows.size() == 1 and int(_game_over_rows[0]["kills"]) >= 1,
					_game_over_rows
				)
				check("down_penalty", m.points.stat(me.peer_id, &"downs") == 1)
				check("spawn_fairness", m.spawns.violations == 0, m.spawns.violations)
				set_physics_process(false)
				finish(true)


func _on_game_over(r: int, rows: Array) -> void:
	_game_over_round = r
	_game_over_rows = rows


func _hit(m: Match, a: ZombieActor, amount: float, zone: int, kind: DamageInfo.Kind) -> void:
	var info: DamageInfo = DamageInfo.make(amount, zone, kind, &"m1911", m.players.local_avatar().peer_id)
	m.targets.host_damage(a, info)


func _any_round_zombie(m: Match) -> ZombieActor:
	for id: int in m.rounds.round_ids:
		var a: ZombieActor = m.zombies.actors.get(id, null)
		if a != null and a.alive:
			return a
	return null


func _spawner(m: Match, n: String) -> ZombieSpawner:
	for s: ZombieSpawner in m.zombies.spawners:
		if s.name == n:
			return s
	return null


func _check_order(ev: Array[String]) -> void:
	var want: Array[String] = ["round_start 1", "requeue", "round_end 1", "intermission 2", "round_start 2"]
	var i: int = 0
	for e: String in ev:
		if i < want.size() and e.begins_with(want[i]):
			i += 1
	check("event_order", i == want.size(), ev.slice(0, 8))


func _economy_and_doors(m: Match, me: PlayerCharacter) -> void:
	var ia: InteractionSystem = m.interaction
	var id: int = me.peer_id
	# Insufficient funds: D02 costs 1000.
	m.points.host_set(id, 600)
	me.motor.teleport(Vector3(6, 0.05, -6.6))
	var d02: PurchasableDoor = ia.find_by_name("D02_Buy") as PurchasableDoor
	var ok: bool = ia.host_handle(id, d02.interact_id)
	check("insufficient_refused", not ok and m.points.get_points(id) == 600 and not d02.is_open(), ia.last_denied)
	# D01 (750).
	m.points.host_set(id, 2000)
	me.motor.teleport(Vector3(11.6, 0.05, -3))
	var d01: PurchasableDoor = ia.find_by_name("D01_Buy") as PurchasableDoor
	ok = ia.host_handle(id, d01.interact_id)
	check("d01_bought", ok and d01.is_open() and m.points.get_points(id) == 1250, m.points.get_points(id))
	check("z03_unlocked", m.zones.is_unlocked(&"Z03") and m.zones.active_zones().has(&"Z03"), m.zones.active_zones())
	ok = ia.host_handle(id, d01.interact_id)
	check("d01_no_double_buy", not ok and m.points.get_points(id) == 1250)
	# Wall-buy M14 (500), then ammo while full is refused without charge.
	me.motor.teleport(Vector3(-1.5, 0.05, -7.0))
	var wb: WallBuy = ia.find_by_name("WallBuy_M14") as WallBuy
	ok = ia.host_handle(id, wb.interact_id)
	var lo: Dictionary = m.weapons.loadouts[id]
	check("m14_bought", ok and (lo["ids"] as Array).has(&"m14") and m.points.get_points(id) == 750, lo)
	ok = ia.host_handle(id, wb.interact_id)
	check("ammo_full_refused", not ok and m.points.get_points(id) == 750, ia.last_denied)
	m.weapons.validator.give(id, wb.definition(), 3, 10)
	ok = ia.host_handle(id, wb.interact_id)
	check("ammo_bought_half_price", ok and m.points.get_points(id) == 500, m.points.get_points(id))
	# Barricade repair: +10 per plank.
	var b: Barricade = m.world.barricades[0]
	me.motor.teleport(b.repair.global_position + Vector3(0, -1.4, 0))
	b.host_tear()
	b.host_tear()
	var p0: int = m.points.get_points(id)
	ia.host_handle(id, b.repair.interact_id)
	ia.host_handle(id, b.repair.interact_id)
	check(
		"repair_points",
		b.planks == b.max_planks and m.points.get_points(id) == p0 + 20,
		[b.planks, m.points.get_points(id) - p0]
	)
	me.motor.teleport(Vector3(0, 0.05, -3))
