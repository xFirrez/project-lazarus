# PlayerCommands — console commands for the player controller (Step 2): live tuning, damage,
# teleport, god/noclip, speed hack (for the validation test) and settings.
# Authority: local commands act on the local avatar; damage/heal apply on the host only
# (they go through PlayerSync, which broadcasts the authoritative result).
class_name PlayerCommands
extends RefCounted


static func register(reg: CommandRegistry) -> void:
	reg.register(
		"tune",
		_cmd_tune,
		[["param", TYPE_STRING, ""], ["value", TYPE_STRING, ""]],
		"PlayerTuning: list, show or set a value live (local player)"
	)
	reg.register("player_info", _cmd_info, [], "Local player position, velocity, stance, stamina, HP")
	reg.register(
		"damage",
		_cmd_damage,
		[["amount", TYPE_FLOAT], ["from_deg", TYPE_FLOAT, 0.0], ["peer", TYPE_INT, 0]],
		"Host: damage a player (default local) from an angle relative to their view (90 = left)"
	)
	reg.register("heal", _cmd_heal, [["peer", TYPE_INT, 0]], "Host: restore a player to full HP")
	reg.register("god", _cmd_god, [["on", TYPE_BOOL]], "Local player ignores damage")
	reg.register("noclip", _cmd_noclip, [["on", TYPE_BOOL]], "Fly through geometry (local)")
	reg.register("tp", _cmd_tp, [["x", TYPE_FLOAT], ["y", TYPE_FLOAT], ["z", TYPE_FLOAT]], "Teleport (host-authorized)")
	reg.register("respawn", _cmd_respawn, [], "Teleport the local player to their spawn point")
	reg.register(
		"speed_hack", _cmd_speed_hack, [["multiplier", TYPE_FLOAT]], "Cheat test: scale own speed (host corrects)"
	)
	reg.register(
		"setting",
		_cmd_setting,
		[["section", TYPE_STRING], ["key", TYPE_STRING], ["value", TYPE_STRING, ""]],
		"Show/set a Config value, e.g. 'setting input mouse_sensitivity 1.5'"
	)
	reg.register("settings_save", _cmd_settings_save, [], "Persist settings to the profile's settings.cfg")


static func _sync() -> PlayerSync:
	return Match.current.players if Match.current != null else null


static func _me() -> PlayerCharacter:
	var s: PlayerSync = _sync()
	return s.local_avatar() if s != null else null


static func _cmd_tune(args: Array) -> String:
	var me: PlayerCharacter = _me()
	var t: PlayerTuning = me.tuning if me != null else load(PlayerCharacter.DEFAULT_TUNING) as PlayerTuning
	var param: String = String(args[0])
	if param == "":
		var parts: PackedStringArray = []
		for n: String in t.tunable_names():
			parts.append("%s=%s" % [n, str(t.get(n))])
		return "\n".join(parts)
	if not t.tunable_names().has(param):
		return "Unknown tuning param '%s'" % param
	if String(args[1]) == "":
		return "%s = %s" % [param, str(t.get(param))]
	if me == null:
		return "No local player"
	t.set(param, String(args[1]).to_float())
	Log.info(&"tuning", "tune %s %s (record changes in the GAME_DESIGN tuning log)" % [param, args[1]])
	return "%s = %s" % [param, str(t.get(param))]


static func _cmd_info(_args: Array) -> String:
	var me: PlayerCharacter = _me()
	if me == null:
		return "No local player"
	var m: MotorComponent = me.motor
	return (
		"pos=%s vel=%s hspeed=%.2f stance=%s grounded=%s sprinting=%s stamina=%.2f hp=%.0f/%.0f"
		% [
			str(me.global_position.snapped(Vector3.ONE * 0.01)),
			str(me.velocity.snapped(Vector3.ONE * 0.01)),
			m.horizontal_speed(),
			MotorComponent.Stance.keys()[m.stance],
			m.grounded,
			m.sprinting,
			m.stamina,
			me.health.health,
			me.health.max_health
		]
	)


static func _cmd_damage(args: Array) -> String:
	var s: PlayerSync = _sync()
	if s == null or not Net.is_host():
		return "damage: host only"
	var peer: int = int(args[2]) if int(args[2]) != 0 else Net.local_id()
	if not s.avatars.has(peer):
		return "No player %d" % peer
	var p: PlayerCharacter = s.avatars[peer]
	var dir: Vector3 = Basis(Vector3.UP, p.get_yaw() + deg_to_rad(float(args[1]))) * Vector3.FORWARD
	var src: Vector3 = p.global_position + dir * 5.0 + Vector3.UP
	var applied: float = s.damage_player(peer, float(args[0]), src, HealthComponent.DamageType.GENERIC)
	return "Applied %.0f damage to %d (hp %.0f)" % [applied, peer, p.health.health]


static func _cmd_heal(args: Array) -> String:
	var s: PlayerSync = _sync()
	if s == null or not Net.is_host():
		return "heal: host only"
	var peer: int = int(args[0]) if int(args[0]) != 0 else Net.local_id()
	s.heal_player(peer)
	return "Healed %d" % peer


static func _cmd_god(args: Array) -> String:
	var me: PlayerCharacter = _me()
	if me == null:
		return "No local player"
	me.health.invulnerable = bool(args[0])
	if Net.is_active() and not Net.is_host():
		SurvivalCommands.request("god", 1 if me.health.invulnerable else 0)  # damage is applied on the host
	return "god %s" % ("on" if me.health.invulnerable else "off")


static func _cmd_noclip(args: Array) -> String:
	var me: PlayerCharacter = _me()
	if me == null:
		return "No local player"
	me.motor.noclip = bool(args[0])
	return "noclip %s" % ("on" if me.motor.noclip else "off")


static func _cmd_tp(args: Array) -> String:
	var s: PlayerSync = _sync()
	if s == null:
		return "Not in a match"
	var pos: Vector3 = Vector3(float(args[0]), float(args[1]), float(args[2]))
	s.request_teleport(pos)
	return "Teleport requested to %s" % str(pos)


static func _cmd_respawn(_args: Array) -> String:
	var s: PlayerSync = _sync()
	if s == null:
		return "Not in a match"
	s.request_teleport(s.spawn_point_for(Net.local_id()))
	return "Respawning"


static func _cmd_speed_hack(args: Array) -> String:
	var me: PlayerCharacter = _me()
	if me == null:
		return "No local player"
	me.motor.speed_multiplier = maxf(float(args[0]), 0.1)
	return "speed multiplier %.2f (the host validates and corrects)" % me.motor.speed_multiplier


static func _cmd_setting(args: Array) -> String:
	var section: StringName = StringName(args[0])
	var key: StringName = StringName(args[1])
	var current: Variant = Config.get_value(section, key, null)
	if String(args[2]) == "":
		return "%s/%s = %s" % [section, key, str(current)]
	var raw: String = String(args[2])
	var value: Variant = raw
	if current is bool or raw == "true" or raw == "false":
		value = raw == "true" or raw == "1" or raw == "on"
	elif current is float or current is int or raw.is_valid_float():
		value = raw.to_float()
	Config.set_value(section, key, value)
	return "%s/%s = %s" % [section, key, str(value)]


static func _cmd_settings_save(_args: Array) -> String:
	return "saved" if Config.save_settings() == OK else "save failed"
