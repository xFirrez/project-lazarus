# soak (AC-5.7): solo session on the nav torture map with continuous respawning for --duration
# simulated seconds (default 600): zombies are kept at 24-32 alive, a zombie is killed every
# ~1.5 s with a random damage kind / zone (headshots, explosives, bullets -> gibs, crawlers,
# ragdolls), barricades are rebuilt every 40 s and the F1 / F2 doors toggle every 60 s. Fails on
# any logged error or warning from the spawn / path / animation systems, leaked actors or a
# runaway alive count.
extends "res://tests/net/autotest_base.gd"

var duration: float = 600.0
var _started: float = -1.0
var _kill_timer: float = 0.0
var _rebuild_timer: float = 40.0
var _door_timer: float = 60.0
var _errors: int = 0
var _warnings: Array[String] = []
var _kills: int = 0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _max_alive: int = 0
var _last_report: float = 0.0


func _ready() -> void:
	duration = CommandLine.get_value("duration", "600").to_float()
	timeout = duration + 60.0
	_rng.seed = 1234
	Log.entry_added.connect(_on_log)


func _on_log(e: Dictionary) -> void:
	var lvl: int = int(e["level"])
	if lvl >= Log.Level.ERROR:
		_errors += 1
	elif lvl == Log.Level.WARN and String(e.get("category", "")) in ["ai", "enemies", "map", "net"]:
		_warnings.append(String(e.get("message", "")))


func _zs() -> ZombieSync:
	return Match.current.zombies if Match.current != null else null


func _physics_process(delta: float) -> void:
	var s: PlayerSync = sync()
	var zs: ZombieSync = _zs()
	if s == null or s.local_avatar() == null or zs == null or not zs.crowd.is_ready():
		return
	var me: PlayerCharacter = s.local_avatar()
	if _started < 0.0:
		_started = elapsed()
		me.bot_driver = circle_driver(0.0, false)
		me.health.invulnerable = true
		return
	var t: float = elapsed() - _started
	var want: int = 24 + int(8.0 * (0.5 + 0.5 * sin(t * 0.05)))
	if zs.alive_count() < want:
		zs.host_spawn_at_spawner(zs.archetype(&"zombie"), _rng.randi_range(0, 4))
	_max_alive = maxi(_max_alive, zs.alive_count())
	_kill_timer -= delta
	if _kill_timer <= 0.0 and zs.alive_count() > 0:
		_kill_timer = 1.5
		_kill_one(zs)
	_rebuild_timer -= delta
	if _rebuild_timer <= 0.0:
		_rebuild_timer = 40.0
		Debug.run("barricade 6")
	_door_timer -= delta
	if _door_timer <= 0.0:
		_door_timer = 60.0
		for d: NavDoor in Match.current.world.doors:
			d.host_set_open(not d.is_open)
	if t - _last_report >= 60.0:
		_last_report = t
		Log.info(
			&"autotest", "soak t=%.0f s alive %d kills %d %s" % [t, zs.alive_count(), _kills, zs.crowd.overlay_text()]
		)
	if t >= duration:
		set_physics_process(false)
		_report(zs)


func _kill_one(zs: ZombieSync) -> void:
	var list: Array = zs.actors.values()
	var a: ZombieActor = list[_rng.randi_range(0, list.size() - 1)]
	var zone: int = [WeaponDefinition.Hitzone.HEAD, WeaponDefinition.Hitzone.TORSO, WeaponDefinition.Hitzone.LIMB][
		_rng.randi_range(0, 2)
	]
	var kind: DamageInfo.Kind = DamageInfo.Kind.EXPLOSIVE if _rng.randf() < 0.25 else DamageInfo.Kind.BULLET
	var amount: float = a.health + 1.0 if _rng.randf() < 0.8 else a.max_health * 0.4
	var info: DamageInfo = DamageInfo.make(amount, zone, kind, &"m1911", 1)
	info.position = a.global_position + Vector3.UP * 0.2
	Match.current.targets.host_damage(a, info)
	if not a.alive:
		_kills += 1


func _report(zs: ZombieSync) -> void:
	var st: Dictionary = zs.crowd.timing_stats()
	result["sim_seconds"] = duration
	result["kills"] = _kills
	result["spawned"] = zs.spawned_total
	result["requeues"] = zs.crowd.requeues
	result["crawlers"] = zs.crowd.crawlers_created
	result["ragdolls"] = zs.fx.ragdolls_started
	result["ragdolls_frozen"] = zs.fx.ragdolls_frozen
	result["gibs"] = zs.fx.gibs_spawned
	result["max_alive"] = _max_alive
	result["ai_last_window"] = st
	var corpses: int = (
		Match.current.zombies.get_children().filter(func(n: Node) -> bool: return n is ZombieActor).size()
	)
	result["actor_nodes"] = corpses
	check("no_logged_errors", _errors == 0, _errors)
	check("no_ai_warnings", _warnings.is_empty(), _warnings.slice(0, 5))
	check("kept_spawning", zs.spawned_total > _kills, [zs.spawned_total, _kills])
	check("alive_bounded", _max_alive <= 32, _max_alive)
	check("no_leaked_actors", corpses <= zs.alive_count() + ZombieFx.RAGDOLL_LIMIT + 8, [corpses, zs.alive_count()])
	check("ragdoll_pool_respected", zs.fx.peak_ragdolls <= ZombieFx.RAGDOLL_LIMIT, zs.fx.peak_ragdolls)
	finish(true)
