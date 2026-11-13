# Stage 5 "Calibration": with the Heart socketed, four vesperite nodes emerge one at a time on the
# containment rings; each must be shot with a Forge-upgraded weapon (immune otherwise). Zombie
# waves continue between nodes (normal rounds). Complete: the reactor is calibrated.
# Authority: HOST.
extends RequiemObjective

var nodes: RequiemNodes = null


func on_activate() -> void:
	nodes = RequiemNodes.new(self)
	if int(get_flag("ee.nodes_broken", 0)) == 0:
		nodes.start()
	else:
		nodes._next_at = now() + 1.0  # host rebuilt mid-stage


func on_tick(_delta: float) -> void:
	nodes.tick()


func on_event(event: StringName, data: Dictionary) -> void:
	if event == &"damaged" and nodes.on_damaged(data):
		_calibrated()


func _calibrated() -> void:
	vo(&"vo_calibrated", marker_pos(&"EE_CoreSocket") + Vector3.UP)
	complete()


func on_debug_complete() -> void:
	nodes.debug_break_all()
	_calibrated()
