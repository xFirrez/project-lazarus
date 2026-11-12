# WeaponCommands — console commands for the weapon framework (Step 3): give weapons, ammo,
# infinite ammo, damage numbers, live weapon tuning, recoil/spread toggles, dummy reset and the
# host's hit-validation statistics.
# Authority: `give` / `ammo` / `infinite_ammo` / `dummy_reset` go through the host (WeaponSync);
# `wtune`, `recoil`, `spread` and `damage_numbers` are local presentation/feel tools.
class_name WeaponCommands
extends RefCounted

# Short names for the debug console (DEVELOPMENT_PLAN Step 12 scope 6: `give raygun`, `give conduit`).
const ALIASES: Dictionary = {
	"raygun": "ray_pistol",
	"nova": "ray_pistol_up",
	"conduit": "lazarus_conduit",
	"requiem": "lazarus_conduit_up",
}


static func register(reg: CommandRegistry) -> void:
	reg.register("give", _cmd_give, [["weapon", TYPE_STRING]], "Give the local player a weapon (host decides)")
	reg.register("weapons", _cmd_weapons, [], "List weapon definitions")
	reg.register("weapon_info", _cmd_info, [], "Held weapon state, ammo, spread, ADS")
	reg.register("ammo", _cmd_ammo, [["peer", TYPE_INT, 0]], "Host: refill a player's ammo and lethals")
	reg.register(
		"infinite_ammo", _cmd_infinite, [["on", TYPE_BOOL], ["peer", TYPE_INT, 0]], "Host: infinite ammo (validated)"
	)
	reg.register("damage_numbers", _cmd_numbers, [["on", TYPE_BOOL]], "Show floating damage numbers on dummies")
	reg.register(
		"wtune",
		_cmd_wtune,
		[["param", TYPE_STRING, ""], ["value", TYPE_STRING, ""]],
		"Held WeaponDefinition: list, show or set a value live (local copy)"
	)
	reg.register("recoil", _cmd_recoil, [["on", TYPE_BOOL]], "Enable/disable recoil (local)")
	reg.register("spread", _cmd_spread, [["on", TYPE_BOOL]], "Enable/disable spread (local)")
	reg.register("dummy_reset", _cmd_dummy_reset, [], "Host: revive all targets and clear their damage logs")
	reg.register("hit_stats", _cmd_hit_stats, [], "Host: accepted / rejected shots and hits")


static func _me() -> PlayerCharacter:
	return Match.current.players.local_avatar() if Match.current != null and Match.current.players != null else null


static func _sync() -> WeaponSync:
	return Match.current.weapons if Match.current != null else null


static func _cmd_give(args: Array) -> String:
	var ws: WeaponSync = _sync()
	if ws == null:
		return "No match"
	var id: StringName = StringName(ALIASES.get(String(args[0]), args[0]))
	var def: WeaponDefinition = WeaponCatalog.get_def(id)
	if def == null:
		return "Unknown weapon '%s' (see `weapons`)" % id
	ws.request_give(id)
	return "Requested %s" % def.display_name


static func _cmd_weapons(_args: Array) -> String:
	var lines: PackedStringArray = []
	for wid: StringName in WeaponCatalog.all_ids():
		var d: WeaponDefinition = WeaponCatalog.get_def(wid)
		lines.append(
			(
				"%s  %s  %s %.0f dmg %.0f rpm %d/%d"
				% [
					wid,
					d.display_name,
					WeaponDefinition.WeaponClass.keys()[d.weapon_class],
					d.damage,
					d.rpm,
					d.mag_size,
					d.reserve_max
				]
			)
		)
	return "\n".join(lines)


static func _cmd_info(_args: Array) -> String:
	var me: PlayerCharacter = _me()
	if me == null or me.weapons.held() == null:
		return "No weapon"
	var h: WeaponRuntime = me.weapons.held()
	return (
		"%s state=%s mag=%d reserve=%d ads=%.2f spread=%.2f° bloom=%.2f shots=%d frags=%d slots=%s"
		% [
			h.def.id,
			WeaponRuntime.State.keys()[h.state],
			h.mag,
			h.reserve,
			h.ads,
			me.weapons.current_spread(),
			h.bloom,
			h.shots_fired,
			me.weapons.inventory.lethal_count,
			str(me.weapons.inventory.ids())
		]
	)


static func _cmd_ammo(args: Array) -> String:
	var ws: WeaponSync = _sync()
	if ws == null or not Net.is_host():
		return "ammo: host only"
	var peer: int = int(args[0]) if int(args[0]) != 0 else Net.local_id()
	ws.host_refill(peer)
	return "Refilled peer %d" % peer


static func _cmd_infinite(args: Array) -> String:
	var ws: WeaponSync = _sync()
	if ws == null or not Net.is_host():
		return "infinite_ammo: host only"
	var peer: int = int(args[1]) if int(args[1]) != 0 else Net.local_id()
	ws.host_set_infinite_ammo(peer, bool(args[0]))
	return "infinite ammo %s for peer %d" % ["on" if bool(args[0]) else "off", peer]


static func _cmd_numbers(args: Array) -> String:
	TargetDummy.show_damage_numbers = bool(args[0])
	return "damage numbers %s" % ("on" if TargetDummy.show_damage_numbers else "off")


static func _cmd_wtune(args: Array) -> String:
	var me: PlayerCharacter = _me()
	if me == null or me.weapons.held() == null:
		return "No weapon"
	var h: WeaponRuntime = me.weapons.held()
	if not h.def.has_meta(&"tuning_copy"):
		var copy: WeaponDefinition = h.def.duplicate() as WeaponDefinition
		copy.set_meta(&"tuning_copy", true)
		h.def = copy  # local copy: the host keeps validating with the shipped definition
	var param: String = String(args[0])
	var names: PackedStringArray = []
	for p: Dictionary in h.def.get_property_list():
		if int(p["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE and int(p["type"]) in [TYPE_FLOAT, TYPE_INT]:
			names.append(String(p["name"]))
	if param == "":
		var parts: PackedStringArray = []
		for n: String in names:
			parts.append("%s=%s" % [n, str(h.def.get(n))])
		return "\n".join(parts)
	if not names.has(param):
		return "Unknown weapon param '%s'" % param
	if String(args[1]) != "":
		h.def.set(param, String(args[1]).to_float())
		Log.info(
			&"tuning", "wtune %s %s %s (record changes in the GAME_DESIGN tuning log)" % [h.def.id, param, args[1]]
		)
	return "%s.%s = %s" % [h.def.id, param, str(h.def.get(param))]


static func _cmd_recoil(args: Array) -> String:
	var me: PlayerCharacter = _me()
	if me == null:
		return "No local player"
	me.weapons.recoil_enabled = bool(args[0])
	return "recoil %s" % ("on" if me.weapons.recoil_enabled else "off")


static func _cmd_spread(args: Array) -> String:
	var me: PlayerCharacter = _me()
	if me == null:
		return "No local player"
	me.weapons.perfect_accuracy = not bool(args[0])
	return "spread %s" % ("off" if me.weapons.perfect_accuracy else "on")


static func _cmd_dummy_reset(_args: Array) -> String:
	if Match.current == null or Match.current.targets == null or not Net.is_host():
		return "dummy_reset: host only"
	Match.current.targets.host_reset_all()
	return "Targets reset"


static func _cmd_hit_stats(_args: Array) -> String:
	var ws: WeaponSync = _sync()
	if ws == null or not Net.is_host():
		return "hit_stats: host only"
	var v: HitValidator = ws.validator
	return (
		"shots accepted=%d hits accepted=%d rejected=%s last=%s"
		% [v.accepted_shots, v.accepted_hits, str(v.rejections), v.last_rejection]
	)
