# Pools — generic node pools (VFX, decals, projectiles, gibs, audio players) keyed by StringName.
# Authority: local presentation objects; pooled nodes are never networked directly.
extends Node

var _free: Dictionary = {}  # StringName -> Array[Node]
var _factories: Dictionary = {}  # StringName -> Callable
var _caps: Dictionary = {}  # StringName -> int
var _live: Dictionary = {}  # StringName -> int


func register(key: StringName, factory: Callable, cap: int = 64) -> void:
	_factories[key] = factory
	_caps[key] = cap
	if not _free.has(key):
		_free[key] = []
		_live[key] = 0


func acquire(key: StringName) -> Node:
	if not _factories.has(key):
		Log.error(&"pools", "Unknown pool '%s'" % key)
		return null
	var list: Array = _free[key]
	var node: Node = null
	if list.is_empty():
		if int(_live[key]) >= int(_caps[key]):
			return null
		var factory: Callable = _factories[key]
		node = factory.call()
		node.set_meta(&"pool_key", key)
		_live[key] = int(_live[key]) + 1
	else:
		node = list.pop_back()
	return node


func release(node: Node) -> void:
	if node == null or not node.has_meta(&"pool_key"):
		return
	var key: StringName = node.get_meta(&"pool_key")
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	(_free[key] as Array).append(node)


func live_count(key: StringName) -> int:
	return int(_live.get(key, 0))


func free_count(key: StringName) -> int:
	return (_free.get(key, []) as Array).size()


func _exit_tree() -> void:
	for key: StringName in _free:
		for node: Node in _free[key]:
			node.free()
	_free.clear()
