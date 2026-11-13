# WonderCommands — Step 12 debug commands (DEVELOPMENT_PLAN Step 12 scope 6; `give raygun` /
# `give conduit` are aliases of `give` in WeaponCommands):
#   special_round [enemy]   the next round is a special round (Galvanics), now if one is active (host)
#   specials                special-round schedule of this match, current / next special, counts
#   spawn_galvanic [n]      n Galvanics through rifts near the local player (host)
#   spawn_warden [round]    a Warden at round-r health near the local player (host)
#   warden <attack|info>    force slam / charge / summon on the live Warden, or print its state (host)
#   warden_late <on|off>    the gated late-round Warden rule (MapRules) (host)
#   parts [part|all]        collect a Conduit part (or all) into the team inventory (host)
#   build                   build the Lazarus Conduit now (parts + power ignored) (host)
# Authority: host-only mutations (clients get "host only").
class_name WonderCommands
extends RefCounted


static func register(reg: CommandRegistry) -> void:
	reg.register("special_round", _cmd_special, [["enemy", TYPE_STRING, "galvanic"]], "Host: next round is special")
	reg.register("specials", _cmd_specials, [], "Special-round schedule and state")
	reg.register("spawn_galvanic", _cmd_galvanic, [["count", TYPE_INT, 1]], "Host: Galvanics through rifts")
	reg.register("spawn_warden", _cmd_warden_spawn, [["round", TYPE_INT, 0]], "Host: spawn the Warden nearby")
	reg.register("warden", _cmd_warden, [["what", TYPE_STRING, "info"]], "Host: slam|charge|summon|info")
	reg.register("warden_late", _cmd_warden_late, [["on", TYPE_STRING, "on"]], "Host: late-round Warden rule")
	reg.register("parts", _cmd_parts, [["part", TYPE_STRING, "all"]], "Host: collect Conduit parts")
	reg.register("build", _cmd_build, [], "Host: build the Lazarus Conduit now")


static func _m() -> Match:
	return Match.current


static func _host() -> bool:
	return _m() != null and (Net.is_host() or not Net.is_active())


static func _me() -> PlayerCharacter:
	return _m().players.local_avatar() if _m() != null and _m().players != null else null


static func _cmd_special(args: Array) -> String:
	if not _host() or _m().rounds == null:
		return "host only (needs a match)"
	_m().rounds.host_force_special(StringName(args[0]))
	return "Next round: special (%s)" % args[0]


static func _cmd_specials(_args: Array) -> String:
	var m: Match = _m()
	if m == null or m.rounds == null:
		return "No match"
	var sched: Array = []
	if m.rules != null and m.rules.has_method(&"special_schedule"):
		sched = Array(m.rules.call(&"special_schedule")).slice(0, 10)
	var rd: RoundDirector = m.rounds
	return (
		"schedule %s | round %d special '%s' next '%s' | left %d alive %d | played %s"
		% [
			str(sched),
			rd.current_round,
			rd.special_id,
			rd.next_special,
			rd.special_left,
			rd.special_ids.size(),
			str(rd.special_log)
		]
	)


static func _cmd_galvanic(args: Array) -> String:
	if not _host() or _me() == null:
		return "host only (needs a player)"
	var zs: ZombieSync = _m().zombies
	var arch: ZombieArchetype = zs.archetype(&"galvanic")
	var n: int = 0
	for i: int in maxi(int(args[0]), 1):
		var a: float = TAU * float(i) / maxf(float(args[0]), 1.0)
		var p: Vector3 = _me().global_position + Vector3(cos(a), 0, sin(a)) * 10.0
		p = zs.crowd.snap(p, _me().global_position)
		WonderFx.play(_me(), WonderFx.Kind.RIFT, PackedVector3Array([p]), 1.0, WonderFx.Variant.ELECTRIC)
		var hp: float = _m().rounds.curve.special_health(0, _m().rounds.zombie_health())
		if zs.host_spawn(arch, ZombieArchetype.Tier.SPRINT, p, a, ZombieSpawner.Kind.SPECIAL, -1, hp) != null:
			n += 1
	return "%d Galvanic(s) spawned" % n


static func _cmd_warden_spawn(args: Array) -> String:
	if not _host() or _me() == null:
		return "host only (needs a player)"
	var r: int = int(args[0]) if int(args[0]) > 0 else maxi(_m().rounds.current_round, 1)
	var me: PlayerCharacter = _me()
	var p: Vector3 = _m().zombies.crowd.snap(me.global_position - me.global_basis.z * 12.0, me.global_position)
	var w: ZombieActor = WardenBehavior.host_spawn(_m().zombies, p, me.rotation.y + PI, r, _m().rounds.player_count())
	return "Warden spawned (round %d, %.0f HP)" % [r, w.max_health] if w != null else "no warden archetype"


static func _warden_actor() -> ZombieActor:
	if _m() == null or _m().zombies == null:
		return null
	for a: ZombieActor in _m().zombies.actors.values():
		if a.behavior is WardenBehavior:
			return a
	return null


static func _cmd_warden(args: Array) -> String:
	if not _host():
		return "host only"
	var a: ZombieActor = _warden_actor()
	if a == null:
		return "No Warden alive (spawn_warden)"
	var wb: WardenBehavior = a.behavior as WardenBehavior
	var what: String = String(args[0])
	if what in ["slam", "charge", "summon"]:
		wb.force_attack(StringName(what))
		return "Warden: %s" % what
	return (
		"Warden %.0f / %.0f HP, plates %d, phase %d, attack %s, stats %s"
		% [
			a.health,
			a.max_health,
			wb.plates_left(),
			wb.phase + 1,
			WardenBehavior.ATTACK_NAMES[wb.attack],
			str(wb.stats)
		]
	)


static func _cmd_warden_late(args: Array) -> String:
	if not _host() or _m().rules == null:
		return "host only"
	_m().rules.warden_late_rounds = String(args[0]) in ["on", "1", "true"]
	return "Late-round Warden rule: %s" % ("on" if _m().rules.warden_late_rounds else "off")


static func _cmd_parts(args: Array) -> String:
	if not _host() or _m().buildables == null or _m().buildables.defs.is_empty():
		return "host only (needs a map with buildables)"
	var bs: BuildableSystem = _m().buildables
	var def: BuildableDef = bs.defs[0]
	if String(args[0]) == "all":
		bs.host_give_all_parts(def.id)
	elif not bs.host_pickup(1, def, StringName(args[0])):
		return "Cannot collect '%s' (parts: %s)" % [args[0], str(def.parts)]
	return "%s parts %d / %d" % [def.display_name, bs.parts_collected(def.id), def.parts.size()]


static func _cmd_build(_args: Array) -> String:
	if not _host() or _m().buildables == null or _m().buildables.defs.is_empty():
		return "host only (needs a map with buildables)"
	var bs: BuildableSystem = _m().buildables
	var def: BuildableDef = bs.defs[0]
	bs.host_give_all_parts(def.id)
	bs.host_build(1, def)
	return (
		"%s built (state %d, %s=%s)"
		% [def.display_name, bs.state(def.id), def.unlock_flag, _m().session.flag(def.unlock_flag)]
	)
