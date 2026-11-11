# FxRing — fixed-capacity recycling pool for short-lived effect nodes (decals, shells, tracers,
# particles). Nodes are created lazily up to `cap`; once full, the oldest node is reused, so the
# live count never exceeds the cap and memory stays flat under sustained fire (AC-3.6).
# Authority: local presentation.
class_name FxRing
extends RefCounted

var cap: int = 32
var nodes: Array[Node] = []
var parent: Node = null
var created: int = 0  # total nodes ever created (== nodes.size(), kept for tests/diagnostics)

var _factory: Callable
var _next: int = 0


func _init(p_parent: Node, p_cap: int, factory: Callable) -> void:
	parent = p_parent
	cap = p_cap
	_factory = factory


func next() -> Node:
	if nodes.size() < cap:
		var n: Node = _factory.call()
		parent.add_child(n)
		nodes.append(n)
		created += 1
		return n
	var reused: Node = nodes[_next]
	_next = (_next + 1) % cap
	return reused


func size() -> int:
	return nodes.size()
