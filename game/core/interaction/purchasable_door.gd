# PurchasableDoor — a door / debris pile bought with points (GAME_DESIGN §12, VESPER_PEAK §2.2):
# shared world progress, whoever pays. Executing opens its NavDoor(s) through WorldSync (nav
# re-bake, open animation, late-join state) and unlocks the zones it leads to (ZoneManager), which
# activates their spawners. The open state is read back from the NavDoors, so it replicates for free.
# Authority: HOST executes; prompts are evaluated locally on every peer.
class_name PurchasableDoor
extends Interactable

@export var door_id: StringName = &""
@export var unlocks: Array[StringName] = []
@export var door_paths: Array[NodePath] = []

var nav_doors: Array[NavDoor] = []


func _ready() -> void:
	super()
	hold_time = 0.35
	use_radius = maxf(use_radius, 2.5)
	for np: NodePath in door_paths:
		var d: NavDoor = get_node_or_null(np) as NavDoor
		if d != null and not nav_doors.has(d):
			nav_doors.append(d)


func is_open() -> bool:
	for d: NavDoor in nav_doors:
		if d.is_open:
			return true
	return false


func is_available(_player: PlayerCharacter) -> bool:
	return not is_open()


func get_prompt(player: PlayerCharacter) -> String:
	return "Hold [F] to open %s [%d]" % [prompt, get_cost(player)]


func host_execute(peer_id: int, _player: PlayerCharacter) -> bool:
	host_open(peer_id)
	return true


# HOST: opens without payment (also used by `open_all_doors`).
func host_open(peer_id: int = 0) -> void:
	if is_open():
		return
	for d: NavDoor in nav_doors:
		d.host_set_open(true)
	var m: Match = Match.current
	if m != null:
		if m.zones != null:
			for z: StringName in unlocks:
				m.zones.host_unlock(z)
		if m.points != null and peer_id > 0:
			m.points.host_add_stat(peer_id, &"doors")
		if m.rules != null:
			m.rules.on_door_opened(door_id, peer_id)
	Log.info(&"world", "Door %s opened by peer %d" % [door_id, peer_id])
