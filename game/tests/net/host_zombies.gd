# Host side of the zombie net test (AC-5.3 replication, AC-5.6): 8 zombies exist before the client
# joins (late-join `_zfull`), 24 more once it is in. The host player circles the atrium, both
# players are invulnerable, zombies have high health so they keep moving. The client shoots
# moving zombies with scripted aim; the host reports how many of its hit claims were accepted,
# the barricade state and the zombie count, and checks no claim was rejected.
extends "res://tests/net/autotest_base.gd"

const HP: float = 1_000_000.0

var _client_id: int = 0
var _pre_spawned: bool = false
var _spawned: bool = false


func _ready() -> void:
	timeout = 70.0
	Net.register_message(&"_autotest_phase", _on_phase)
	Net.register_message(&"_autotest_report", func(_s: int, _p: Array) -> void: pass)


func _zs() -> ZombieSync:
	return Match.current.zombies if Match.current != null else null


func _spawn(n: int) -> void:
	var zs: ZombieSync = _zs()
	var arch: ZombieArchetype = zs.archetype(&"zombie")
	for i: int in n:
		var sp: ZombieSpawner = zs.spawners[i % zs.spawners.size()]
		var a: ZombieActor = zs.host_spawn(arch, ZombieArchetype.Tier.JOG, sp.global_position, 0.0, sp.kind, -1, HP)
		a.health = HP


func _physics_process(_delta: float) -> void:
	var s: PlayerSync = sync()
	if s == null or _zs() == null or not _zs().crowd.is_ready():
		return
	var me: PlayerCharacter = s.local_avatar()
	if me == null:
		return
	if not me.bot_driver.is_valid():
		me.bot_driver = circle_driver(0.0, false)
	me.health.invulnerable = true
	if not _pre_spawned and elapsed() > 0.3:
		_pre_spawned = true
		# Re-queued zombies respawn through ZombieSync: give them the test health too.
		_zs().zombie_spawned.connect(
			func(a: ZombieActor) -> void:
				a.max_health = HP
				a.health = HP
		)
		_spawn(8)
		note("pre-join zombies: %d" % _zs().alive_count())
	if _client_id == 0:
		for id: int in s.avatars:
			if id != Net.local_id():
				_client_id = id
				(s.avatars[id] as PlayerCharacter).health.invulnerable = true
				Debug.run("infinite_ammo true %d" % id)
				Log.info(&"autotest", "AUTOTEST READY host")
		return
	if s.avatars.has(_client_id):
		(s.avatars[_client_id] as PlayerCharacter).health.invulnerable = true
	if not _spawned and elapsed() > 2.0:
		_spawned = true
		_spawn(24)
		Net.send_reliable(_client_id, &"_autotest_phase", ["spawned", _zs().alive_count()])


func _on_phase(sender: int, p: Array) -> void:
	if String(p[0]) != "done":
		return
	var v: HitValidator = Match.current.weapons.validator
	var claimed: int = int(p[1])
	var zs: ZombieSync = _zs()
	var w: Array = []
	for b: Barricade in Match.current.world.barricades:
		w.append(b.planks)
	result["claimed_hits"] = claimed
	result["accepted_hits"] = v.accepted_hits
	result["rejections"] = v.rejections
	result["alive"] = zs.alive_count()
	result["ai"] = zs.crowd.timing_stats()
	result["snapshot_bytes_out"] = zs.snapshot_bytes_out
	var ratio: float = float(v.accepted_hits) / maxf(claimed, 1.0)
	check("enough_claims", claimed >= 40, claimed)
	check(
		"hit_claims_accepted_98pct", ratio >= 0.98, "%.3f (%d/%d, %s)" % [ratio, v.accepted_hits, claimed, v.rejections]
	)
	check("windows_torn", w.min() < 6, w)
	var alive: int = zs.alive_count()
	zs.host_kill_all()  # deaths replicate before the report (same ordered reliable channel)
	check("all_killed", zs.alive_count() == 0, zs.alive_count())
	Net.send_reliable(sender, &"_autotest_report", [alive, w, v.accepted_hits])
	await get_tree().create_timer(1.0).timeout
	finish(true)
