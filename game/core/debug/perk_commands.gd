# PerkCommands — Vigor Tonic / power-up debug commands (DEVELOPMENT_PLAN Step 10 scope 8):
#   perk <id> [peer]       grant a perk now (host; ignores price, power and the cap)
#   perk_all [peer]        every perk (host; ignores the cap)
#   perk_clear [peer]      remove every perk (host)
#   perks                  every player's perks, Second Wind uses, drinks in progress
#   powerup <id>           spawn a power-up 2.5 m in front of you (host; ids: max_ammo, insta_kill,
#                          double_points, nuke, carpenter, fire_sale, free_upgrade)
#   powerup_apply <id>     apply a power-up's effect immediately (host)
#   drop_rate <multiplier> scale the drop counter (host; 1 = GAME_DESIGN §11)
#   powerups               drop counter / threshold / bag / active timers
# Authority: host-only mutations (clients get "host only").
class_name PerkCommands
extends RefCounted


static func register(reg: CommandRegistry) -> void:
	reg.register("perk", _cmd_perk, [["id", TYPE_STRING], ["peer", TYPE_INT, 0]], "Host: grant a Vigor Tonic")
	reg.register("perk_all", _cmd_perk_all, [["peer", TYPE_INT, 0]], "Host: grant every Vigor Tonic")
	reg.register("perk_clear", _cmd_perk_clear, [["peer", TYPE_INT, 0]], "Host: remove every perk")
	reg.register("perks", _cmd_perks, [], "Perks of every player")
	reg.register("powerup", _cmd_powerup, [["id", TYPE_STRING]], "Host: spawn a power-up in front of you")
	reg.register("powerup_apply", _cmd_apply, [["id", TYPE_STRING]], "Host: apply a power-up effect now")
	reg.register("drop_rate", _cmd_drop_rate, [["multiplier", TYPE_FLOAT]], "Host: power-up drop rate multiplier")
	reg.register("powerups", _cmd_powerups, [], "Power-up drop state and timers")


static func _perks() -> PerkSystem:
	return Match.current.perks if Match.current != null else null


static func _pu() -> PowerUpSystem:
	return Match.current.powerups if Match.current != null else null


static func _peer(arg: int) -> int:
	if arg != 0:
		return arg
	return Net.local_id() if Net.is_active() else 1


static func _cmd_perk(args: Array) -> String:
	var ps: PerkSystem = _perks()
	if ps == null or not PerkSystem.is_authority():
		return "Host only (needs a match)"
	var id: StringName = StringName(args[0])
	if PerkCatalog.get_def(id) == null:
		return "Unknown perk '%s' (%s)" % [id, ", ".join(PackedStringArray(PerkSystem._strings(PerkCatalog.ids())))]
	var peer: int = _peer(int(args[1]))
	if not ps.host_grant(peer, id, true):
		return "Peer %d already has %s" % [peer, id]
	return "Granted %s to %d" % [PerkCatalog.get_def(id).display_name, peer]


static func _cmd_perk_all(args: Array) -> String:
	var ps: PerkSystem = _perks()
	if ps == null or not PerkSystem.is_authority():
		return "Host only (needs a match)"
	var peer: int = _peer(int(args[0]))
	ps.host_set_perks(peer, PerkCatalog.ids())
	return "Granted every perk to %d" % peer


static func _cmd_perk_clear(args: Array) -> String:
	var ps: PerkSystem = _perks()
	if ps == null or not PerkSystem.is_authority():
		return "Host only (needs a match)"
	var peer: int = _peer(int(args[0]))
	ps.host_set_perks(peer, [])
	return "Cleared perks of %d" % peer


static func _cmd_perks(_args: Array) -> String:
	var ps: PerkSystem = _perks()
	if ps == null:
		return "No match"
	var lines: PackedStringArray = [
		(
			"cap %d, solo %s, Second Wind uses %d/%d"
			% [ps.cap(), ps.is_solo(), ps.second_wind_uses(), PerkSystem.SECOND_WIND_SOLO_USES]
		)
	]
	for id: int in Match.current.players.player_ids():
		lines.append("  %d: %s%s" % [id, ps.digest_of(id), "  (drinking)" if ps.is_drinking(id) else ""])
	return "\n".join(lines)


static func _cmd_powerup(args: Array) -> String:
	var pu: PowerUpSystem = _pu()
	if pu == null or not PowerUpSystem.is_authority():
		return "Host only (needs a match)"
	var id: StringName = StringName(args[0])
	if not PowerUpSystem.TYPES.has(id):
		return "Unknown power-up '%s'" % id
	var me: PlayerCharacter = Match.current.players.local_avatar()
	if me == null:
		return "No local player"
	var fwd: Vector3 = -me.global_transform.basis.z
	fwd.y = 0.0
	var pos: Vector3 = me.global_position + fwd.normalized() * 2.5
	pu.host_spawn(id, pos)
	return "Spawned %s" % id


static func _cmd_apply(args: Array) -> String:
	var pu: PowerUpSystem = _pu()
	if pu == null or not PowerUpSystem.is_authority():
		return "Host only (needs a match)"
	var id: StringName = StringName(args[0])
	if not PowerUpSystem.TYPES.has(id):
		return "Unknown power-up '%s'" % id
	var me: PlayerCharacter = Match.current.players.local_avatar()
	pu.host_apply(id, me.global_position if me != null else Vector3.ZERO)
	return "Applied %s" % id


static func _cmd_drop_rate(args: Array) -> String:
	var pu: PowerUpSystem = _pu()
	if pu == null or not PowerUpSystem.is_authority():
		return "Host only (needs a match)"
	pu.dropper.rate = maxf(float(args[0]), 0.0)
	return "Drop rate x%.2f" % pu.dropper.rate


static func _cmd_powerups(_args: Array) -> String:
	var pu: PowerUpSystem = _pu()
	if pu == null:
		return "No match"
	var d: PowerUpDropper = pu.dropper
	var timers: PackedStringArray = []
	for t: StringName in PowerUpSystem.TIMED:
		if pu.is_active(t):
			timers.append("%s %.1fs" % [t, pu.time_left(t)])
	return (
		"counter %.0f / %.0f, drops %d (this round %d), rate x%.2f, bag %s, on ground %d, active [%s]"
		% [
			d.counter,
			d.threshold(),
			d.drops_total,
			d.drops_round,
			d.rate,
			str(d.bag),
			pu.drops.size(),
			", ".join(timers)
		]
	)
