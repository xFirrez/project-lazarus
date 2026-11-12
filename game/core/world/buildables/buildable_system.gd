# BuildableSystem — generic buildables (DEVELOPMENT_PLAN Step 12A scope 3, GAME_DESIGN §7.2): parts
# spawn at one of their marker options (chosen per match by the host, `choose_locations`, seedable),
# any player picks a part up into the SHARED team inventory, and the workbench builds the item once
# every part is in (hold `build_time`, power when `requires_power`). The first build sets
# `unlock_flag` (Vesper Peak: "conduit_built" -> the Relic Box pool gains the Lazarus Conduit); the
# built item then sits on the bench and the first player to interact takes it (one per player).
# Shared state = MatchSession flags (late join, reconnect and the state hash for free):
#   "build.<id>.loc.<part>" chosen option index; "build.<id>.part.<part>" collected (bool)
#   "build.<id>.state" 0 collecting / 1 built, waiting on the bench / 2 claimed
#   "build.<id>.by.<part>" peer id that found the part (HUD credit)
# One BuildablePart under EVERY option marker and one Workbench per buildable are created by `setup`
# BEFORE the interaction scan on every peer (tree-order interactable ids); only the chosen option
# shows / can be used, from the replicated flags.
# Authority: HOST picks locations and executes pickups / builds / claims; every peer presents.
class_name BuildableSystem
extends Node

signal changed(buildable_id: StringName)

enum State { COLLECTING, BUILT, CLAIMED }

var match_node: Match = null
var defs: Array[BuildableDef] = []
var parts: Array[BuildablePart] = []
var benches: Dictionary = {}  # buildable id -> Workbench
var seed_override: int = -1  # tests / debug: fixed location seed


static func is_authority() -> bool:
	return Net.is_host() or not Net.is_active()


static func flag_loc(id: StringName, part: StringName) -> String:
	return "build.%s.loc.%s" % [id, part]


static func flag_part(id: StringName, part: StringName) -> String:
	return "build.%s.part.%s" % [id, part]


static func flag_state(id: StringName) -> String:
	return "build.%s.state" % id


# Option index per part for a seed (deterministic: the seeded test of AC-12.3).
static func choose_locations(def: BuildableDef, seed_value: int) -> Dictionary:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var out: Dictionary = {}
	for p: StringName in def.parts:
		out[p] = rng.randi_range(0, maxi(def.options_of(p).size() - 1, 0))
	return out


func setup(def_list: Array[BuildableDef], map_root: Node) -> void:
	name = "Buildables"
	defs = def_list
	var markers: Dictionary = {}
	for n: Node in map_root.find_children("*", "MapMarker", true, false):
		markers[(n as MapMarker).marker_id] = n
	for def: BuildableDef in defs:
		for p: StringName in def.parts:
			var opts: Array[StringName] = def.options_of(p)
			for i: int in opts.size():
				var mk: MapMarker = markers.get(opts[i], null)
				if mk == null:
					Log.warn(&"buildables", "%s: part marker %s missing" % [def.id, opts[i]])
					continue
				mk.show_visual = false
				var bp: BuildablePart = BuildablePart.new()
				bp.name = "BuildablePart"
				bp.system = self
				bp.def = def
				bp.part = p
				bp.option = i
				mk.add_child(bp)
				parts.append(bp)
		var wm: MapMarker = markers.get(def.workbench_marker, null)
		if wm == null:
			Log.warn(&"buildables", "%s: workbench marker %s missing" % [def.id, def.workbench_marker])
			continue
		wm.show_visual = false
		var wb: Workbench = Workbench.new()
		wb.name = "Workbench"
		wb.system = self
		wb.def = def
		wm.add_child(wb)
		benches[def.id] = wb


func _ready() -> void:
	WonderAudio.ensure()
	if session() != null:
		session().flag_changed.connect(_on_flag_changed)
	if is_authority():
		host_choose_locations(seed_override if seed_override >= 0 else randi())


func session() -> MatchSession:
	return match_node.session if match_node != null else null


func def_of(id: StringName) -> BuildableDef:
	for d: BuildableDef in defs:
		if d.id == id:
			return d
	return null


# --- replicated queries ---------------------------------------------------------------------------


func location(id: StringName, part: StringName) -> int:
	var s: MatchSession = session()
	return int(s.flag(flag_loc(id, part), -1)) if s != null else -1


func has_part(id: StringName, part: StringName) -> bool:
	var s: MatchSession = session()
	return s != null and bool(s.flag(flag_part(id, part), false))


func parts_collected(id: StringName) -> int:
	var def: BuildableDef = def_of(id)
	var n: int = 0
	if def != null:
		for p: StringName in def.parts:
			if has_part(id, p):
				n += 1
	return n


func all_parts(id: StringName) -> bool:
	var def: BuildableDef = def_of(id)
	return def != null and parts_collected(id) == def.parts.size()


func state(id: StringName) -> int:
	var s: MatchSession = session()
	return int(s.flag(flag_state(id), State.COLLECTING)) if s != null else State.COLLECTING


# HUD: one line per buildable while it is being assembled.
func hud_lines() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for def: BuildableDef in defs:
		if state(def.id) != State.COLLECTING or parts_collected(def.id) == 0:
			continue
		var bits: PackedStringArray = PackedStringArray()
		for p: StringName in def.parts:
			bits.append("%s %s" % [def.part_name(p), "✓" if has_part(def.id, p) else "·"])
		out.append("%s parts: %s" % [def.display_name, "  ".join(bits)])
	return out


# --- host ---------------------------------------------------------------------------------------


func host_choose_locations(seed_value: int) -> void:
	if not is_authority() or session() == null:
		return
	for def: BuildableDef in defs:
		var locs: Dictionary = choose_locations(def, seed_value + hash(def.id))
		for p: StringName in locs:
			if location(def.id, p) < 0:
				session().host_set_flag(flag_loc(def.id, p), int(locs[p]))
	Log.info(&"buildables", "Part locations chosen (seed %d)" % seed_value)


func host_pickup(peer_id: int, def: BuildableDef, part: StringName) -> bool:
	if not is_authority() or has_part(def.id, part) or state(def.id) != State.COLLECTING:
		return false
	session().host_set_flag(flag_part(def.id, part), true)
	session().host_set_flag("build.%s.by.%s" % [def.id, part], peer_id)
	Log.info(&"buildables", "Peer %d found the %s %s" % [peer_id, def.display_name, part])
	return true


# Debug `parts`: every part of a buildable collected.
func host_give_all_parts(id: StringName) -> void:
	var def: BuildableDef = def_of(id)
	if def == null:
		return
	for p: StringName in def.parts:
		host_pickup(1, def, p)


func host_build(peer_id: int, def: BuildableDef) -> bool:
	if not is_authority() or state(def.id) != State.COLLECTING or not all_parts(def.id):
		return false
	session().host_set_flag(flag_state(def.id), State.BUILT)
	if def.unlock_flag != "":
		session().host_set_flag(def.unlock_flag, true)
	Log.info(&"buildables", "Peer %d built the %s" % [peer_id, def.display_name])
	return true


# The first player to take the built item gets it (one per player).
func host_claim(peer_id: int, def: BuildableDef) -> bool:
	if not is_authority() or state(def.id) != State.BUILT or match_node.weapons == null:
		return false
	if match_node.weapons.host_owns(peer_id, def.reward_weapon):
		return false
	if not match_node.weapons.host_give(peer_id, def.reward_weapon):
		return false
	session().host_set_flag(flag_state(def.id), State.CLAIMED)
	return true


func _on_flag_changed(key: String, _value: Variant) -> void:
	if not key.begins_with("build."):
		return
	var id: StringName = StringName(key.get_slice(".", 1))
	for bp: BuildablePart in parts:
		if bp.def.id == id:
			bp.refresh()
	if benches.has(id):
		(benches[id] as Workbench).refresh()
	changed.emit(id)
	if key.contains(".part.") and bool(session().flag(key, false)):
		Audio.play_event(&"part_pickup")
	elif key == flag_state(id) and int(session().flag(key, 0)) == State.BUILT:
		Audio.play_event(&"build_done")
