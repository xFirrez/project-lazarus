# RequiemNodes — the calibration nodes (VESPER_PEAK §7 stage 5; re-run after a failed finale): four
# vesperite nodes emerge one at a time on the containment rings ("ee.node" = active 1..4) and break
# only under Forge-upgraded weapons ("ee.node_hp"); GAP seconds between nodes while the waves go on.
# Health per node: 500 + 250 x (players - 1).
# Authority: HOST (used by the stage 5 / stage 6 objectives).
class_name RequiemNodes
extends RefCounted

const GAP: float = 6.0
const COUNT: int = 4

var obj: RequiemObjective = null
var ignored_hits: int = 0  # host (tests): non-upgraded hits on an active node
var _next_at: float = -1.0


func _init(o: RequiemObjective) -> void:
	obj = o


func start() -> void:
	obj.set_flag("ee.nodes_broken", 0)
	obj.set_flag("ee.node", 0)
	_next_at = obj.now() + 2.0


func done() -> bool:
	return int(obj.get_flag("ee.nodes_broken", 0)) >= COUNT


func health() -> float:
	return obj.scaled(500.0, 250.0)


func tick() -> void:
	if done() or int(obj.get_flag("ee.node", 0)) != 0 or _next_at < 0.0:
		return
	if obj.now() >= _next_at:
		_next_at = -1.0
		obj.set_flag("ee.node_hp", health())
		obj.set_flag("ee.node", int(obj.get_flag("ee.nodes_broken", 0)) + 1)


# Returns true when this hit broke the last node.
func on_damaged(data: Dictionary) -> bool:
	var active: int = int(obj.get_flag("ee.node", 0))
	if active == 0 or StringName(data.get("id", &"")) != StringName("node_%d" % active):
		return false
	if not RequiemObjective.is_upgraded(StringName(data.get("weapon", &""))):
		ignored_hits += 1
		return false
	var hp: float = float(obj.get_flag("ee.node_hp", health())) - float(data.get("amount", 0.0))
	obj.set_flag("ee.node_hp", maxf(hp, 0.0))
	if hp > 0.0:
		return false
	return break_active()


func break_active() -> bool:
	var n: int = int(obj.get_flag("ee.nodes_broken", 0)) + 1
	obj.set_flag("ee.node", 0)
	obj.set_flag("ee.nodes_broken", n)
	if n >= COUNT:
		return true
	obj.vo(&"vo_node")
	_next_at = obj.now() + GAP
	return false


func debug_break_all() -> void:
	while not done():
		obj.set_flag("ee.node", int(obj.get_flag("ee.nodes_broken", 0)) + 1)
		break_active()
