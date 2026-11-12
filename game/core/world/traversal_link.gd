# TraversalLink — a NavigationLink3D that zombies cross with an action instead of walking:
# windows (tear the barricade, then climb), drop-downs, vents (crawl), jumps and lift rides. The brain finds
# the link through the path metadata (owner id) and runs the matching traversal (ZombieSim).
# Authority: static map data, read by the host's zombie brains.
class_name TraversalLink
extends NavigationLink3D

enum Action { WINDOW, DROP, VENT, JUMP, LIFT }

const NAV_LAYER_LINKS: int = 1

@export var action: Action = Action.DROP
@export var barricade_path: NodePath = ^""
@export var duration: float = 0.0  # 0 = derived from the action and the link length
@export var cost: float = 1.0

var barricade: Barricade = null
# LIFT links: the machine carrying zombies and the station this link boards at (TraversalMachine
# enables the link only while docked there).
var machine: TraversalMachine = null
var station: int = 0


func _ready() -> void:
	add_to_group(&"traversal_link")
	navigation_layers = NAV_LAYER_LINKS
	enter_cost = cost
	if barricade_path != ^"":
		barricade = get_node_or_null(barricade_path) as Barricade


func global_start() -> Vector3:
	return global_transform * start_position


func global_end() -> Vector3:
	return global_transform * end_position


func length() -> float:
	return global_start().distance_to(global_end())


func traverse_time(crawl_speed: float) -> float:
	if duration > 0.0:
		return duration
	match action:
		Action.DROP:
			return clampf(sqrt(2.0 * maxf(global_start().y - global_end().y, 0.5) / 9.8) + 0.25, 0.4, 1.4)
		Action.VENT:
			return length() / maxf(crawl_speed, 0.3)
		Action.JUMP:
			return 0.7
	return 1.2


static func create(
	p_action: Action, from: Vector3, to: Vector3, p_barricade: Barricade = null, bidirectional_link: bool = false
) -> TraversalLink:
	var l: TraversalLink = TraversalLink.new()
	l.action = p_action
	l.start_position = from
	l.end_position = to
	l.bidirectional = bidirectional_link
	l.barricade = p_barricade
	return l
