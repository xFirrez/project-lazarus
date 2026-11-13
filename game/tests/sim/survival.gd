# survival (AC-6.3, AC-6.7): solo session on vesper_peak with the local player + 3 host bots, all
# driven by SurvivalBot (shoot, kite, repair, buy doors / a wall weapon, revive).
#   --rounds=N   stop after surviving N rounds (default 20)
#   --god=1      players can't be hurt (fairness soak: spawning, not combat); 0 = die naturally
#   --bot_damage=F  bot damage multiplier (default 1; the god soak uses 3 to keep it short)
# Asserts: 0 unfair spawns (within 8 m / in line of sight) across the run, zero logged errors,
# memory within +-5 % and orphan nodes flat between comparable points (round starts), and that
# the run reached N rounds or ended in a natural game over.
extends "res://tests/net/autotest_base.gd"

var rounds_target: int = 20
var god: bool = false
var bot_damage: float = 1.0
var _started: bool = false
var _errors: int = 0
var _error_lines: Array[String] = []
var _bots: Array[SurvivalBot] = []
var _mem: Dictionary = {}  # round -> static memory at round start
var _orphans: Dictionary = {}
var _game_over_round: int = -1
var _round_times: Dictionary = {}


func _ready() -> void:
	rounds_target = CommandLine.get_value("rounds", "20").to_int()
	god = CommandLine.get_value("god", "0") == "1"
	bot_damage = CommandLine.get_value("bot_damage", "3" if god else "1").to_float()
	timeout = 7200.0
	Log.entry_added.connect(_on_log)


func _on_log(e: Dictionary) -> void:
	if int(e["level"]) >= Log.Level.ERROR:
		_errors += 1
		if _error_lines.size() < 5:
			_error_lines.append(String(e.get("message", "")))


func _physics_process(_delta: float) -> void:
	var m: Match = Match.current
	if m == null or m.players == null or m.players.local_avatar() == null or not m.zombies.crowd.is_ready():
		return
	if not _started:
		_started = true
		m.downed.show_screen = false
		m.downed.game_over.connect(func(r: int, _rows: Array) -> void: _game_over_round = r)
		m.rounds.round_started.connect(_on_round_started)
		for i: int in 3:
			m.players.add_bot()
		var n: int = 0
		for id: int in m.players.player_ids():
			var p: PlayerCharacter = m.players.avatars[id]
			var b: SurvivalBot = SurvivalBot.attach(p, m, 1000 + n)
			b.damage_scale = bot_damage
			p.health.invulnerable = god
			_bots.append(b)
			n += 1
		note("survival soak: %d players, god %s, target %d rounds" % [m.players.avatars.size(), god, rounds_target])
		return
	var rd: RoundDirector = m.rounds
	var done: bool = _game_over_round > 0 or (rd.current_round > rounds_target)
	if done:
		set_physics_process(false)
		_report(m)


func _on_round_started(r: int) -> void:
	var m: Match = Match.current
	_mem[r] = Performance.get_monitor(Performance.MEMORY_STATIC)
	_orphans[r] = Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	_round_times[r] = elapsed()
	Log.info(
		&"autotest",
		(
			"round %d start t=%.0f alive players %d points %s spawns %d violations %d stalls %d mem %.1f MB orphans %d"
			% [
				r,
				elapsed(),
				m.downed.alive_count(),
				str(m.points.points.values()),
				m.spawns.spawns,
				m.spawns.violations,
				m.spawns.stalls,
				float(_mem[r]) / 1048576.0,
				int(_orphans[r])
			]
		)
	)


func _report(m: Match) -> void:
	var rd: RoundDirector = m.rounds
	var reached: int = rd.current_round - 1 if _game_over_round < 0 else _game_over_round
	result["rounds_survived"] = reached
	result["game_over_round"] = _game_over_round
	result["spawns"] = m.spawns.spawns
	result["unfair_spawns"] = m.spawns.violations
	result["spawn_stalls"] = m.spawns.stalls
	result["min_spawn_distance"] = snappedf(m.spawns.min_distance_seen, 0.01)
	result["requeues"] = m.zombies.crowd.requeues
	result["kills"] = m.zombies.deaths_total
	result["downs"] = m.downed.revives_total + m.downed.bleedouts_total
	result["revives"] = m.downed.revives_total
	result["bleedouts"] = m.downed.bleedouts_total
	result["points"] = m.points.summary()
	result["sim_seconds"] = snappedf(elapsed(), 1.0)
	check("no_unfair_spawns", m.spawns.violations == 0, m.spawns.violations)
	check("no_logged_errors", _errors == 0, _error_lines)
	check("reached_target_or_natural_end", reached >= rounds_target or (_game_over_round > 0 and not god), reached)
	# Memory / orphans between comparable points: the start of round 3 vs the last round start.
	var rounds_seen: Array = _mem.keys()
	rounds_seen.sort()
	if rounds_seen.size() >= 4:
		var a: int = 3
		var b: int = int(rounds_seen[rounds_seen.size() - 1])
		var drift: float = (float(_mem[b]) - float(_mem[a])) / maxf(float(_mem[a]), 1.0)
		result["memory_drift"] = snappedf(drift, 0.001)
		result["orphans"] = [int(_orphans[a]), int(_orphans[b])]
		check("memory_stable", absf(drift) <= 0.05, [_mem[a], _mem[b]])
		check("orphans_flat", int(_orphans[b]) <= int(_orphans[a]), [_orphans[a], _orphans[b]])
	finish(true)
