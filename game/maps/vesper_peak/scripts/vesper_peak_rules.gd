# VesperPeakRules — Vesper Peak's MapRules (VESPER_PEAK §9). Step 8: the traversal machines unlock
# the zone they arrive in (riding the gondola to the Comms Array or the freight lift / laundry
# chute down to Specimen Storage before buying the doors there still activates that zone's
# spawners). Step 11: all three Resonance Relays -> the Reactor Bridge extends to the Forge platform
# and the Lazarus Forge wakes (ReactorState plays the beat on every peer). Special rounds
# (Galvanics) and the quest: Steps 12-14.
# Authority: host only (hooks are called by core on the host).
extends MapRules

const ARRIVAL_ZONES: Dictionary = {&"gondola": [&"Z01", &"Z07"], &"freight_lift": [&"Z06", &"Z12"]}
const SPECIAL_ENEMY: StringName = &"galvanic"
const SEED_FLAG: String = "special_seed"

var _schedule: PackedInt32Array = PackedInt32Array()
var _schedule_seed: int = -1


func on_match_start() -> void:
	# Step 14B: the rare late-round Warden (GAME_DESIGN §5.4) is enabled with the Easter egg.
	warden_late_rounds = true
	Log.info(&"vesper_peak", "Arrival Station: hold the windows, buy D01 / D02 to expand.")
	if match_node.session.flag(SEED_FLAG, null) == null:
		match_node.session.host_set_flag(SEED_FLAG, randi() % 1000000)
	var root: Node = match_node.map_root
	for n: Node in root.find_children("*", "TraversalMachine", true, false):
		var tm: TraversalMachine = n as TraversalMachine
		if ARRIVAL_ZONES.has(tm.machine_id):
			tm.arrived.connect(func(station: int) -> void: _unlock(ARRIVAL_ZONES[tm.machine_id][station]))
	for n: Node in root.find_children("*", "Chute", true, false):
		(n as Chute).grate.toggled.connect(func(_open: bool) -> void: _unlock(&"Z12"))


func _unlock(zone: StringName) -> void:
	if match_node != null and match_node.zones != null:
		match_node.zones.host_unlock(zone)


func on_zone_unlocked(zone: StringName) -> void:
	Log.info(&"vesper_peak", "Zone %s open" % zone)


func on_relays_complete() -> void:
	Log.info(&"vesper_peak", "All relays resonating: the Reactor Bridge extends.")
	for d: Node in match_node.map_root.find_children("*", "NavDoor", true, false):
		if (d as NavDoor).solid_when_open:
			(d as NavDoor).host_set_open(true)
	match_node.session.host_set_flag(ForgeSystem.FLAG_UNLOCKED, true)


func special_schedule() -> PackedInt32Array:
	var seed_value: int = int(match_node.session.flag(SEED_FLAG, 0)) if match_node != null else 0
	if seed_value != _schedule_seed:
		_schedule_seed = seed_value
		var curve: RoundCurve = (
			match_node.definition.round_curve if match_node.definition.round_curve != null else RoundCurve.new()
		)
		_schedule = curve.special_schedule(seed_value)
	return _schedule


func get_special_round_enemy(r: int) -> StringName:
	return SPECIAL_ENEMY if special_schedule().has(r) else &""


func get_mixed_enemy(r: int) -> StringName:
	return SPECIAL_ENEMY if r >= 20 else &""
