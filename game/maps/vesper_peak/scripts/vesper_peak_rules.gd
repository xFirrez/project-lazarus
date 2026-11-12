# VesperPeakRules — Vesper Peak's MapRules (VESPER_PEAK §9). Step 8: the traversal machines unlock
# the zone they arrive in (riding the gondola to the Comms Array or the freight lift / laundry
# chute down to Specimen Storage before buying the doors there still activates that zone's
# spawners). Step 11: all three Resonance Relays -> the Reactor Bridge extends to the Forge platform
# and the Lazarus Forge wakes (ReactorState plays the beat on every peer). Special rounds
# (Galvanics) and the quest: Steps 12-14.
# Authority: host only (hooks are called by core on the host).
extends MapRules

const ARRIVAL_ZONES: Dictionary = {&"gondola": [&"Z01", &"Z07"], &"freight_lift": [&"Z06", &"Z12"]}


func on_match_start() -> void:
	Log.info(&"vesper_peak", "Arrival Station: hold the windows, buy D01 / D02 to expand.")
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
