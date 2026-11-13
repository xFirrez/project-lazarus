# high_rounds (AC-16.4, Step 16 scope 5): time-accelerated high-round stability soak on vesper_peak.
# The local player + 3 host bots, god mode, all holding Forge-upgraded weapons (MG42 / M60 / RPD /
# AK upgrades). Rounds 1-3 play naturally, then the host jumps to rounds 10, 20, 30, 40, 50 and
# plays 55..60 back to back (every round is played to its last kill). Bot damage is scaled per
# round so each zombie takes ~4 hits (the acceleration: the soak tests spawning, AI, pools, nav,
# numerics and memory at high round sizes, not whether bots can out-shoot round 60).
# At round 60 the Warden is spawned too. Asserts: zero logged errors, every round started and
# ended, spawned zombie health == hp(r) and finite, points finite, alive cap never exceeded,
# memory within +-10 % and orphan nodes flat between the round-10 start and the end.
extends "res://tests/net/autotest_base.gd"

const PLAN: Array[int] = [1, 2, 3, 10, 20, 30, 40, 50, 55, 56, 57, 58, 59, 60]
const WEAPONS: Array[StringName] = [&"mg42_up", &"m60_up", &"rpd_up", &"ak47_up"]

var _started: bool = false
var _bots: Array[SurvivalBot] = []
var _errors: int = 0
var _error_lines: Array[String] = []
var _rounds_started: Array[int] = []
var _rounds_ended: Array[int] = []
var _bad_health: Array[String] = []
var _max_alive: int = 0
var _spawned: int = 0
var _mem: Dictionary = {}
var _orphans: Dictionary = {}
var _round_seconds: Dictionary = {}
var _round_t0: float = 0.0
var _warden_hp: float = 0.0
var _warden_killed: bool = false
var _done: bool = false


func _ready() -> void:
	timeout = 14400.0
	Log.entry_added.connect(_on_log)


func _on_log(e: Dictionary) -> void:
	if int(e["level"]) >= Log.Level.ERROR:
		_errors += 1
		if _error_lines.size() < 8:
			_error_lines.append(String(e.get("message", "")))


func _physics_process(_delta: float) -> void:
	var m: Match = Match.current
	if m == null or m.players == null or m.players.local_avatar() == null or not m.zombies.crowd.is_ready():
		return
	if not _started:
		_started = true
		m.downed.show_screen = false
		m.rounds.round_started.connect(_on_round_started)
		m.rounds.round_ended.connect(_on_round_ended)
		m.zombies.zombie_spawned.connect(_on_spawned)
		m.zombies.zombie_died.connect(_on_died)
		for i: int in 3:
			m.players.add_bot()
		var n: int = 0
		for id: int in m.players.player_ids():
			var p: PlayerCharacter = m.players.avatars[id]
			m.weapons.host_give(id, WEAPONS[n % WEAPONS.size()])
			var b: SurvivalBot = SurvivalBot.attach(p, m, 2000 + n)
			p.health.invulnerable = true
			_bots.append(b)
			n += 1
		note("high-round soak: %d players, plan %s" % [m.players.avatars.size(), str(PLAN)])
		return
	_max_alive = maxi(_max_alive, m.zombies.alive_count())
	if _done:
		set_physics_process(false)
		_report(m)


func _on_round_started(r: int) -> void:
	var m: Match = Match.current
	_rounds_started.append(r)
	_round_t0 = elapsed()
	_mem[r] = Performance.get_monitor(Performance.MEMORY_STATIC)
	_orphans[r] = Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	var hp: float = _base_hp(r)
	for b: SurvivalBot in _bots:
		var held: WeaponDefinition = (
			WeaponCatalog.get_def(StringName(m.weapons.loadouts.get(b.player.peer_id, {}).get("current", &"m1911")))
			if b.player != null
			else null
		)
		var dmg: float = held.damage * 1.6 if held != null else 80.0
		b.damage_scale = maxf(1.0, hp / (4.0 * dmg))
	Log.info(
		&"autotest",
		(
			"round %d start: total %d hp %.0f mem %.1f MB orphans %d"
			% [r, m.rounds.total, hp, float(_mem[r]) / 1048576.0, int(_orphans[r])]
		)
	)
	if r == 60:
		Debug.run("spawn_warden 60")


func _on_round_ended(r: int) -> void:
	_rounds_ended.append(r)
	_round_seconds[r] = snappedf(elapsed() - _round_t0, 1.0)
	var i: int = PLAN.find(r)
	if i < 0 or i == PLAN.size() - 1:
		_done = true
		return
	var nxt: int = PLAN[i + 1]
	if nxt != r + 1:
		(func() -> void: Match.current.rounds.host_start_round(nxt)).call_deferred()


func _base_hp(r: int) -> float:
	var a: ZombieArchetype = Match.current.zombies.archetype(&"zombie")
	return a.health_for_round(r) if a != null else 0.0


func _on_spawned(actor: ZombieActor) -> void:
	_spawned += 1
	var hp: float = actor.max_health
	if not is_finite(hp) or hp <= 0.0:
		_bad_health.append("%s r%d hp %s" % [actor.archetype.id, Match.current.rounds.current_round, str(hp)])
	elif actor.archetype.id == &"zombie" and absf(hp - _base_hp(Match.current.rounds.current_round)) > 1.0:
		if _bad_health.size() < 8:
			_bad_health.append(
				(
					"zombie r%d hp %.0f expected %.0f"
					% [Match.current.rounds.current_round, hp, _base_hp(Match.current.rounds.current_round)]
				)
			)
	if actor.behavior is WardenBehavior:
		_warden_hp = hp


func _on_died(actor: ZombieActor, _peer: int) -> void:
	if actor.behavior is WardenBehavior:
		_warden_killed = true


func _report(m: Match) -> void:
	result["rounds_started"] = _rounds_started
	result["rounds_ended"] = _rounds_ended
	result["round_seconds"] = _round_seconds
	result["spawned"] = _spawned
	result["kills"] = m.zombies.deaths_total
	result["max_alive"] = _max_alive
	result["requeues"] = m.zombies.crowd.requeues
	result["warden_hp_r60"] = _warden_hp
	result["points"] = m.points.summary()
	result["sim_seconds"] = snappedf(elapsed(), 1.0)
	result["hitches"] = m.hitches.stats() if m.hitches != null else {}
	check("no_logged_errors", _errors == 0, _error_lines)
	check("all_planned_rounds_played", _rounds_ended == PLAN, _rounds_ended)
	check("zombie_health_matches_curve", _bad_health.is_empty(), _bad_health)
	check("alive_cap_respected", _max_alive <= m.rounds.curve.alive_cap(4) + 2 + 1, _max_alive)
	check("warden_spawned_r60", _warden_hp > 0.0 and is_finite(_warden_hp), _warden_hp)
	var pts_ok: bool = true
	for id: int in m.points.points:
		var v: int = int(m.points.points[id])
		pts_ok = pts_ok and v >= 0 and v < 1000000000
	check("points_finite", pts_ok, m.points.points)
	if _mem.has(10) and _mem.has(60):
		var drift: float = (float(_mem[60]) - float(_mem[10])) / maxf(float(_mem[10]), 1.0)
		result["memory_drift"] = snappedf(drift, 0.001)
		result["orphans"] = [int(_orphans[10]), int(_orphans[60])]
		check("memory_within_10pct", absf(drift) <= 0.10, [_mem[10], _mem[60]])
		check("orphans_flat", int(_orphans[60]) <= int(_orphans[10]) + 2, [_orphans[10], _orphans[60]])
	finish(true)
