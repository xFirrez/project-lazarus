# QuestCommands — Step 14 debug commands (ARCHITECTURE §10: "debug console can jump to any step"):
#   quest                  every quest graph and the state of each step
#   ee_stage <step>        jump to a step: debug-completes every prerequisite, then activates it (host)
#   ee_skip [step]         finish a step as if the players did it (default: the first active one) (host)
#   ee_event <name> [id]   send a host quest event (e.g. `ee_event interact radio_tx`) (host)
#   journal [clear|all]    Journal unlocks / badges; `clear` wipes them, `all` unlocks every entry
#   lore <id>              open a document (or play a reel / VO entry) locally
#   vo <id>                play a VO entry for everyone (host)
#   carry [drop]           carry items and their carriers; `drop` drops what the local player holds
# Authority: host-only mutations (clients get "host only").
class_name QuestCommands
extends RefCounted


static func register(reg: CommandRegistry) -> void:
	reg.register("quest", _cmd_quest, [], "Quest graphs and step states")
	reg.register("ee_stage", _cmd_stage, [["step", TYPE_STRING, ""]], "Host: jump to a quest step")
	reg.register("ee_skip", _cmd_skip, [["step", TYPE_STRING, ""]], "Host: complete a quest step")
	reg.register(
		"ee_event", _cmd_event, [["name", TYPE_STRING, ""], ["id", TYPE_STRING, ""]], "Host: send a quest event"
	)
	reg.register("journal", _cmd_journal, [["what", TYPE_STRING, ""]], "Journal unlocks / badges")
	reg.register("lore", _cmd_lore, [["id", TYPE_STRING, ""]], "Open a document / play a reel locally")
	reg.register("vo", _cmd_vo, [["id", TYPE_STRING, ""]], "Host: play a VO entry for everyone")
	reg.register("carry", _cmd_carry, [["what", TYPE_STRING, ""]], "Carry items; `drop`")


static func _q() -> QuestSystem:
	return Match.current.quest if Match.current != null else null


static func _host() -> bool:
	return _q() != null and QuestSystem.is_authority()


static func _cmd_quest(_args: Array) -> String:
	if _q() == null:
		return "No match"
	var out: String = _q().describe()
	return out if out != "" else "No quests on this map"


static func _cmd_stage(args: Array) -> String:
	if not _host():
		return "host only (needs a match)"
	var id: StringName = StringName(args[0])
	if _q().step(id) == null:
		return "Unknown step '%s' (see `quest`)" % id
	return "Jumped to %s" % id if _q().host_jump(id) else "Could not jump to %s" % id


static func _cmd_skip(args: Array) -> String:
	if not _host():
		return "host only (needs a match)"
	var id: StringName = StringName(args[0])
	if id == &"":
		var act: Array[StringName] = _q().active_steps()
		if act.is_empty():
			return "No active step"
		id = act[0]
	return "Skipped %s" % id if _q().host_skip(id) else "Could not skip %s" % id


static func _cmd_event(args: Array) -> String:
	if not _host():
		return "host only (needs a match)"
	_q().host_event(StringName(args[0]), {"id": StringName(args[1]), "peer": Net.local_id()})
	return "Event %s sent" % args[0]


static func _cmd_journal(args: Array) -> String:
	match String(args[0]):
		"clear":
			Journal.clear()
			return "Journal cleared"
		"all":
			var n: int = 0
			for res: Resource in Content.get_all(&"MapDefinition"):
				var lib: LoreLibrary = LoreLibrary.for_map(res as MapDefinition)
				for id: StringName in lib.journal_ids():
					n += int(Journal.unlock(id))
			return "Unlocked %d entries" % n
	var map_id: StringName = Match.current.definition.id if Match.current != null else &"vesper_peak"
	return (
		"%d unlocked: %s | badges %s"
		% [Journal.unlocked_ids().size(), ", ".join(Journal.unlocked_ids()), str(Journal.badges(map_id))]
	)


static func _cmd_lore(args: Array) -> String:
	if _q() == null:
		return "No match"
	var id: StringName = StringName(args[0])
	var lib: LoreLibrary = _q().vo.lore
	if lib.entry(id).is_empty():
		return "Unknown entry (%s)" % ", ".join(PackedStringArray(lib.order))
	if lib.kind_of(id) in ["reel", "vo"]:
		_q().vo.play_local(id)
	else:
		DocumentReader.open(_q(), lib.entry(id), _q().annotation(id))
	Journal.unlock(id)
	return "Opened %s" % id


static func _cmd_vo(args: Array) -> String:
	if not _host():
		return "host only (needs a match)"
	_q().vo.host_play(StringName(args[0]))
	return "Playing %s" % args[0]


static func _cmd_carry(args: Array) -> String:
	if _q() == null:
		return "No match"
	if String(args[0]) == "drop":
		for item: CarryItem in _q().carry_items.values():
			if item.carrier() == Net.local_id():
				_q().request_drop(item.item_id)
				return "Dropping %s" % item.item_id
		return "Not carrying anything"
	var parts: PackedStringArray = []
	for item: CarryItem in _q().carry_items.values():
		parts.append("%s present=%s carrier=%d" % [item.item_id, item.is_present(), item.carrier()])
	return "\n".join(parts) if not parts.is_empty() else "No carry items"
