# Power — map power circuits (GAME_DESIGN power, VESPER_PEAK §3 Z09): a circuit is a MatchSession
# flag `power.<circuit>` (true = on), so it rides the late-join snapshot and the state hash for free.
# Listeners (PoweredLight, markers, machines) use `MatchSession.flag_changed` / `Power.is_on`.
# Authority: HOST switches circuits on (`host_set`); every peer reads the mirrored flag.
class_name Power
extends RefCounted

const MAIN: StringName = &"main"


static func key(circuit: StringName) -> String:
	return "power.%s" % circuit


static func is_on(circuit: StringName = MAIN) -> bool:
	var m: Match = Match.current
	if m == null or m.session == null:
		return false
	return bool(m.session.flags.get(key(circuit), false))


static func host_set(circuit: StringName, on: bool) -> void:
	var m: Match = Match.current
	if m == null or m.session == null or not MatchSession.is_authority():
		return
	if is_on(circuit) == on:
		return
	m.session.host_set_flag(key(circuit), on)
	Log.info(&"power", "Circuit %s %s" % [circuit, "ON" if on else "off"])


# Parses a flag key back to its circuit (&"" when the key isn't a power flag).
static func circuit_of(flag_key: String) -> StringName:
	return StringName(flag_key.substr(6)) if flag_key.begins_with("power.") else &""
