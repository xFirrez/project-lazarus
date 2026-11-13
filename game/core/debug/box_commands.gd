# BoxCommands — Relic Box / arsenal debug commands (DEVELOPMENT_PLAN Step 9 scope 8):
#   box_force <weapon_id|doll>  next spin's result (host)
#   box_move <location>         move the box (marker id or suffix such as Z07, or index) (host)
#   firesale [seconds]          activate every location (host; Fire Sale power-up arrives in Step 10)
#   box                         box state (location, spins here, phase per location)
# Authority: host-only mutations (clients get "host only").
class_name BoxCommands
extends RefCounted


static func register(reg: CommandRegistry) -> void:
	reg.register("box_force", _cmd_force, [["result", TYPE_STRING]], "Host: force the next Relic Box result")
	reg.register("box_move", _cmd_move, [["location", TYPE_STRING]], "Host: move the Relic Box (Z07 / Box_Z07 / index)")
	reg.register("firesale", _cmd_firesale, [["seconds", TYPE_FLOAT, 30.0]], "Host: Fire Sale (all box locations)")
	reg.register("box", _cmd_box, [], "Relic Box state")


static func _box() -> RelicBoxSystem:
	return Match.current.box if Match.current != null else null


static func _cmd_force(args: Array) -> String:
	var b: RelicBoxSystem = _box()
	if b == null or not RelicBoxSystem.is_authority():
		return "Host only (needs a match with a Relic Box)"
	var id: StringName = StringName(args[0])
	if id != RelicBoxRoller.DOLL and WeaponCatalog.get_def(id) == null:
		return "Unknown item '%s'" % id
	b.forced = id
	return "Next spin: %s" % id


static func _cmd_move(args: Array) -> String:
	var b: RelicBoxSystem = _box()
	if b == null or not RelicBoxSystem.is_authority():
		return "Host only (needs a match with a Relic Box)"
	var arg: String = String(args[0])
	var i: int = int(arg) if arg.is_valid_int() else b.index_of(StringName(arg))
	if i < 0 or i >= b.boxes.size():
		return "Unknown location '%s'" % arg
	b.host_move_to(i)
	return "Relic Box -> %s" % b.boxes[i].location_id


static func _cmd_firesale(args: Array) -> String:
	var b: RelicBoxSystem = _box()
	if b == null or not RelicBoxSystem.is_authority():
		return "Host only (needs a match with a Relic Box)"
	b.activate_all_locations(float(args[0]))
	return "Fire Sale for %.0f s" % float(args[0])


static func _cmd_box(_args: Array) -> String:
	var b: RelicBoxSystem = _box()
	if b == null:
		return "No Relic Box"
	var lines: PackedStringArray = [
		(
			"location %s (spins here %d, fire sale %s, spins %d, dolls %d)"
			% [b.boxes[b.current_index()].location_id, b.spins_here, b.fire_sale_active(), b.total_spins, b.total_dolls]
		)
	]
	for bx: RelicBox in b.boxes:
		lines.append(
			"  %d %s present=%s phase=%s" % [bx.index, bx.location_id, b.is_present(bx.index), b.phase(bx.index)]
		)
	return "\n".join(lines)
