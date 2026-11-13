# ZombieCommands — console commands for zombies (Step 5): spawn by tier, freeze, debug drawing of
# paths / targets / states, kill all, AI timing, barricade and door toggles.
# Authority: spawning / killing / freezing / world toggles act on the host only (clients are told
# to run them on the host); `zombie_debug` and `ai_stats` read host state.
class_name ZombieCommands
extends RefCounted


static func register(reg: CommandRegistry) -> void:
	reg.register(
		"spawn_zombie",
		_cmd_spawn,
		[["tier", TYPE_STRING, "walk"], ["count", TYPE_INT, 1], ["where", TYPE_STRING, "spawner"]],
		"Host: spawn zombies (tier shamble|walk|jog|run|sprint, where spawner|front|<spawner name>)"
	)
	reg.register("zombie_freeze", _cmd_freeze, [["on", TYPE_BOOL]], "Host: freeze / unfreeze all zombie AI")
	reg.register("zombie_debug", _cmd_debug, [["on", TYPE_BOOL]], "Host: draw zombie paths, targets and states")
	reg.register("kill_all", _cmd_kill_all, [], "Host: kill every zombie")
	reg.register("zombies", _cmd_list, [], "List zombies (id, tier, state, health)")
	reg.register("ai_stats", _cmd_stats, [], "Host: AI time per frame, path queries, re-queues, ragdolls")
	reg.register("zombie_crawler", _cmd_crawler, [["id", TYPE_INT, 0]], "Host: turn a zombie (0 = all) into a crawler")
	reg.register("barricade", _cmd_barricade, [["planks", TYPE_INT, 6]], "Host: set every barricade's plank count")
	reg.register(
		"door", _cmd_door, [["name", TYPE_STRING, ""], ["open", TYPE_BOOL, true]], "Host: open/close a NavDoor"
	)


static func _zs() -> ZombieSync:
	return Match.current.zombies if Match.current != null else null


static func _host_only() -> String:
	if _zs() == null:
		return "no match"
	if not ZombieSync.is_authority():
		return "host only"
	return ""


static func _cmd_spawn(args: Array) -> String:
	var err: String = _host_only()
	if err != "":
		return err
	var zs: ZombieSync = _zs()
	var tier: int = ZombieArchetype.tier_from_name(String(args[0]))
	if tier < 0:
		return "unknown tier '%s'" % args[0]
	var n: int = clampi(int(args[1]), 1, 64)
	var where: String = String(args[2])
	var arch: ZombieArchetype = zs.archetype(&"zombie")
	var made: int = 0
	for i: int in n:
		var a: ZombieActor = null
		if where == "front":
			var me: PlayerCharacter = Match.current.players.local_avatar()
			if me == null:
				return "no local player"
			var fwd: Vector3 = -me.camera.global_transform.basis.z
			fwd.y = 0.0
			var p: Vector3 = me.global_position + fwd.normalized() * (6.0 + i * 0.8)
			a = zs.host_spawn(arch, tier, p, atan2(-fwd.x, -fwd.z), ZombieSpawner.Kind.WINDOW)
		elif where == "spawner":
			a = zs.host_spawn_at_spawner(arch, tier)
		else:
			var sp: ZombieSpawner = Match.current.map_root.find_child(where, true, false) as ZombieSpawner
			if sp == null:
				return "no spawner '%s'" % where
			a = zs.host_spawn_at_spawner(arch, tier, sp)
		if a != null:
			made += 1
	return "spawned %d %s zombie(s); %d alive" % [made, ZombieArchetype.TIER_NAMES[tier], zs.alive_count()]


static func _cmd_freeze(args: Array) -> String:
	var err: String = _host_only()
	if err != "":
		return err
	_zs().crowd.frozen = bool(args[0])
	return "zombie AI %s" % ("frozen" if bool(args[0]) else "running")


static func _cmd_debug(args: Array) -> String:
	var err: String = _host_only()
	if err != "":
		return err
	_zs().crowd.set_debug_draw(bool(args[0]))
	return "zombie debug %s" % ("on" if bool(args[0]) else "off")


static func _cmd_kill_all(_args: Array) -> String:
	var err: String = _host_only()
	if err != "":
		return err
	return "killed %d zombies" % _zs().host_kill_all()


static func _cmd_list(_args: Array) -> String:
	var zs: ZombieSync = _zs()
	if zs == null:
		return "no match"
	var lines: PackedStringArray = ["%d alive" % zs.alive_count()]
	for a: ZombieActor in zs.actors.values():
		lines.append(
			(
				"#%d %s %s hp %.0f/%.0f %s%s"
				% [
					a.net_id,
					ZombieArchetype.TIER_NAMES[a.tier],
					a.sim.state_name() if a.sim != null else "client",
					a.health,
					a.max_health,
					"crawler " if a.is_crawler() else "",
					str(a.global_position.snapped(Vector3.ONE * 0.1))
				]
			)
		)
	return "\n".join(lines)


static func _cmd_stats(_args: Array) -> String:
	var err: String = _host_only()
	if err != "":
		return err
	var zs: ZombieSync = _zs()
	var c: CrowdDirector = zs.crowd
	return (
		(
			"%s\nqueries total %d  requeues %d  crawlers %d  spawned %d  deaths %d\n"
			+ "ragdolls %d (frozen %d, peak %d)  gibs %d  voices %d/%d active, denied %d\nsnapshot out %d B total"
		)
		% [
			c.overlay_text(),
			c.queries_total,
			c.requeues,
			c.crawlers_created,
			zs.spawned_total,
			zs.deaths_total,
			zs.fx.ragdolls_started,
			zs.fx.ragdolls_frozen,
			zs.fx.peak_ragdolls,
			zs.fx.gibs_spawned,
			ZombieAudio.active_voices(),
			ZombieAudio.MAX_VOICES,
			ZombieAudio.voices_denied,
			zs.snapshot_bytes_out
		]
	)


static func _cmd_crawler(args: Array) -> String:
	var err: String = _host_only()
	if err != "":
		return err
	var n: int = 0
	for a: ZombieActor in _zs().actors.values():
		if int(args[0]) == 0 or a.net_id == int(args[0]):
			a.set_flag(ZombieActor.Flag.CRAWLER, true)
			n += 1
	return "%d crawler(s)" % n


static func _cmd_barricade(args: Array) -> String:
	if Match.current == null or Match.current.world == null:
		return "no match"
	if not WorldSync.is_authority():
		return "host only"
	for b: Barricade in Match.current.world.barricades:
		WorldSync.host_set_barricade(b, int(args[0]))
	return "%d barricade(s) set to %d planks" % [Match.current.world.barricades.size(), int(args[0])]


static func _cmd_door(args: Array) -> String:
	if Match.current == null or Match.current.world == null:
		return "no match"
	if not WorldSync.is_authority():
		return "host only"
	var n: int = 0
	for d: NavDoor in Match.current.world.doors:
		if String(args[0]) == "" or String(d.name).begins_with(String(args[0])):
			d.host_set_open(bool(args[1]))
			n += 1
	return "%d door(s) %s" % [n, "opened" if bool(args[1]) else "closed"]
