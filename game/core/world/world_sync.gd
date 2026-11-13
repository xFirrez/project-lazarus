# WorldSync — ids and replication for world objects that change during a match (barricades and
# nav doors now; traps, power and the box join in later steps). Ids come from a tree-order scan of
# the map on every peer (like TargetRegistry, D-023), so no id messages are needed.
#   host -> all : `_barricade` [id, planks]     `_door` [id, open]
#   host -> peer: `_world_full` [[barricade planks...], [door open...]]  on join (late join)
# Without a Match / session (integration scenes) the calls apply locally (authority).
# Authority: HOST decides; every peer applies.
class_name WorldSync
extends Node

var barricades: Array[Barricade] = []
var doors: Array[NavDoor] = []


static func instance() -> WorldSync:
	return Match.current.world if Match.current != null else null


static func is_authority() -> bool:
	return Net.is_host() or not Net.is_active()


static func host_set_barricade(b: Barricade, planks: int) -> void:
	if not is_authority():
		return
	b.apply_planks(planks)
	var ws: WorldSync = instance()
	if ws != null and b.world_id >= 0:
		Net.send_reliable(0, &"_barricade", [b.world_id, b.planks])


static func host_set_door(d: NavDoor, open: bool) -> void:
	if not is_authority():
		return
	d.apply_open(open)
	var ws: WorldSync = instance()
	if ws != null and d.world_id >= 0:
		Net.send_reliable(0, &"_door", [d.world_id, open])


func _ready() -> void:
	name = "World"
	Net.register_message(&"_barricade", _on_msg_barricade)
	Net.register_message(&"_door", _on_msg_door)
	Net.register_message(&"_world_full", _on_msg_full)
	Net.peer_joined.connect(_on_peer_joined)


func _exit_tree() -> void:
	for m: StringName in [&"_barricade", &"_door", &"_world_full"]:
		Net.unregister_message(m)


func scan(root: Node) -> void:
	for node: Node in root.find_children("*", "", true, false):
		if node is Barricade:
			(node as Barricade).world_id = barricades.size()
			barricades.append(node as Barricade)
		elif node is NavDoor:
			(node as NavDoor).world_id = doors.size()
			doors.append(node as NavDoor)


# Door states and barricade planks as digest lines (MatchSession state hash).
func digest() -> PackedStringArray:
	var bp: PackedStringArray = []
	for b: Barricade in barricades:
		bp.append(str(b.planks))
	var dp: PackedStringArray = []
	for d: NavDoor in doors:
		dp.append("1" if d.is_open else "0")
	return PackedStringArray(["barricades=" + ",".join(bp), "doors=" + "".join(dp)])


func _on_msg_barricade(sender: int, p: Array) -> void:
	if sender != 1 or Net.is_host():
		return
	var i: int = int(p[0])
	if i >= 0 and i < barricades.size():
		barricades[i].apply_planks(int(p[1]))


func _on_msg_door(sender: int, p: Array) -> void:
	if sender != 1 or Net.is_host():
		return
	var i: int = int(p[0])
	if i >= 0 and i < doors.size():
		doors[i].apply_open(bool(p[1]))


func _on_msg_full(sender: int, p: Array) -> void:
	if sender != 1 or Net.is_host():
		return
	var bp: Array = p[0]
	for i: int in mini(bp.size(), barricades.size()):
		barricades[i].apply_planks(int(bp[i]), false)
	var dp: Array = p[1]
	for i: int in mini(dp.size(), doors.size()):
		doors[i].apply_open(bool(dp[i]), false)


func _on_peer_joined(peer_id: int, _info: Dictionary) -> void:
	if not Net.is_host() or peer_id == Net.local_id():
		return
	var bp: Array = []
	for b: Barricade in barricades:
		bp.append(b.planks)
	var dp: Array = []
	for d: NavDoor in doors:
		dp.append(d.is_open)
	Net.send_reliable(peer_id, &"_world_full", [bp, dp])
