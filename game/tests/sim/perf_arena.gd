# perf_arena (AC-5.5, ARCHITECTURE §12): solo session on the nav torture map with 4 bot players
# (the local avatar circling the atrium + 3 bots looping routes on F1 / F2 / F3) and 32 zombies
# (`--map=vesper_peak`: every door open, bots looping the Courtyard fountain, the Lobby and the
# Reactor Lower Ring, the avatar circling the Arrival Station — the Step 8 full-map baseline)
# (mixed tiers) kept alive and pursuing. Records host AI + navigation time per physics frame
# (CrowdDirector accounting), path queries and frame time to a CSV; passes if the AI average is
# <= 1.5 ms and p99 <= 3 ms. Players are invulnerable so the pursuit never ends.
extends "res://tests/net/autotest_base.gd"

const ZOMBIES: int = 32
const WARMUP: float = 5.0
const AVG_LIMIT_MS: float = 1.5
const P99_LIMIT_MS: float = 3.0
const LOOPS: Array = [
	[Vector3(-12, 0, -13), Vector3(-3, 0, -13), Vector3(-3, 0, -2), Vector3(-12, 0, -2)],
	[Vector3(-12, 4, -2), Vector3(8, 4, -2), Vector3(8, 4, 2), Vector3(-12, 4, 2)],
	[Vector3(-13, 8, -14), Vector3(-3, 8, -14), Vector3(-3, 8, -6), Vector3(-13, 8, -6)],
]

const VESPER_LOOPS: Array = [
	[Vector3(18, -8, -40), Vector3(38, -8, -40), Vector3(38, -8, -58), Vector3(18, -8, -58)],
	[Vector3(44, -8, -10), Vector3(60, -8, -10), Vector3(60, -8, -2), Vector3(44, -8, -2)],
	[Vector3(6, -48, -50), Vector3(28, -48, -72), Vector3(50, -48, -50), Vector3(28, -48, -28)],
]

var duration: float = 60.0
var _loops: Array = LOOPS
var _bots: Array[Node3D] = []
var _u: Array[float] = [0.0, 0.0, 0.0]
var _started: float = -1.0
var _rows: PackedStringArray = ["t,ai_us,path_queries,alive,frame_ms"]
var _ai: PackedFloat64Array = []
var _errors: int = 0
var _tiers: Array[int] = [
	ZombieArchetype.Tier.WALK, ZombieArchetype.Tier.JOG, ZombieArchetype.Tier.RUN, ZombieArchetype.Tier.SPRINT
]


func _ready() -> void:
	duration = CommandLine.get_value("duration", "60").to_float()
	timeout = duration + WARMUP + 30.0
	Log.entry_added.connect(func(e: Dictionary) -> void: _errors += 1 if int(e["level"]) >= Log.Level.ERROR else 0)


func _zs() -> ZombieSync:
	return Match.current.zombies if Match.current != null else null


func _physics_process(delta: float) -> void:
	var s: PlayerSync = sync()
	var zs: ZombieSync = _zs()
	if s == null or s.local_avatar() == null or zs == null or not zs.crowd.is_ready():
		return
	if _started < 0.0:
		_setup(s, zs)
		return
	_move_bots(delta)
	var n: int = 0
	while zs.alive_count() < ZOMBIES and n < 4:
		zs.host_spawn_at_spawner(zs.archetype(&"zombie"), _tiers[zs.spawned_total % _tiers.size()])
		n += 1
	var t: float = elapsed() - _started
	if t < WARMUP:
		zs.crowd.reset_timing()
		return
	var c: CrowdDirector = zs.crowd
	var us: int = c.frame_usec[(c._timing_index - 1) % CrowdDirector.TIMING_WINDOW]
	_ai.append(us / 1000.0)
	_rows.append(
		(
			"%.3f,%d,%d,%d,%.3f"
			% [
				t,
				us,
				c.queries_this_frame,
				zs.alive_count(),
				Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
			]
		)
	)
	if t >= WARMUP + duration:
		set_physics_process(false)
		_report(zs)


func _setup(s: PlayerSync, zs: ZombieSync) -> void:
	_started = elapsed()
	var me: PlayerCharacter = s.local_avatar()
	me.bot_driver = circle_driver(0.0, false)
	me.health.invulnerable = true
	if Match.current.definition.id == &"vesper_peak":
		_loops = VESPER_LOOPS
		SurvivalCommands._cmd_open_all([])
		for n: Node in Match.current.map_root.find_children("*", "NavDoor", true, false):
			(n as NavDoor).host_set_open(true)
		if Match.current.rounds != null:
			Match.current.rounds.enabled = false
	for i: int in _loops.size():
		var b: Node3D = Node3D.new()
		b.name = "Bot%d" % (i + 1)
		Match.current.map_root.add_child(b)
		b.global_position = _loops[i][0]
		zs.crowd.extra_targets.append(b)
		_bots.append(b)


func _move_bots(delta: float) -> void:
	for i: int in _bots.size():
		var loop: Array = _loops[i]
		var seg: int = int(_u[i]) % loop.size()
		var a: Vector3 = loop[seg]
		var b: Vector3 = loop[(seg + 1) % loop.size()]
		_u[i] += 2.5 * delta / maxf(a.distance_to(b), 0.01)
		_bots[i].global_position = a.lerp(b, fposmod(_u[i], 1.0))


func _report(zs: ZombieSync) -> void:
	var sorted: Array = Array(_ai)
	sorted.sort()
	var total: float = 0.0
	for v: float in sorted:
		total += v
	var n: int = sorted.size()
	var avg: float = total / maxi(n, 1)
	var p99: float = sorted[mini(n - 1, int(n * 0.99))] if n > 0 else 0.0
	result["frames"] = n
	result["ai_avg_ms"] = snappedf(avg, 0.001)
	result["ai_p99_ms"] = snappedf(p99, 0.001)
	result["ai_max_ms"] = snappedf(sorted[-1] if n > 0 else 0.0, 0.001)
	result["path_queries"] = zs.crowd.queries_total
	result["max_queries_frame"] = zs.crowd.max_queries_in_frame
	result["requeues"] = zs.crowd.requeues
	result["zombie_damage_dealt"] = zs.crowd.damage_dealt
	var csv: String = CommandLine.get_value("csv", "")
	if csv != "":
		var f: FileAccess = FileAccess.open(csv, FileAccess.WRITE)
		if f != null:
			f.store_string("\n".join(_rows) + "\n")
			f.close()
	check("ai_avg_le_1_5ms", avg <= AVG_LIMIT_MS, "%.3f ms" % avg)
	check("ai_p99_le_3ms", p99 <= P99_LIMIT_MS, "%.3f ms" % p99)
	check("zombies_kept_alive", zs.alive_count() >= ZOMBIES, zs.alive_count())  # re-queues may top up +1
	check("zombies_attacked", zs.crowd.damage_dealt > 0.0, zs.crowd.damage_dealt)
	check("path_budget", zs.crowd.max_queries_in_frame <= zs.crowd.path_budget, zs.crowd.max_queries_in_frame)
	check("no_logged_errors", _errors == 0, _errors)
	finish(true)
