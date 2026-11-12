# Interactable — anything a player uses with the interact key (ARCHITECTURE §8): prompt text,
# cost, hold time, use radius and conditions. The local InteractionSystem probes for the best one,
# runs the hold and sends a request; the HOST re-validates (distance, conditions, cost through the
# PointsLedger) and calls `host_execute`. `continuous` interactables repeat every
# `repeat_interval` while the key stays held (barricade repair). Subclasses override the virtuals.
# Ids come from a tree-order scan of the map on every peer (like WorldSync), so no id messages.
# Authority: HOST executes; every peer evaluates prompts locally from replicated state.
class_name Interactable
extends Node3D

@export var prompt: String = "use"
@export var cost: int = 0
@export var hold_time: float = 0.25
@export var use_radius: float = 2.0
@export var continuous: bool = false
@export var repeat_interval: float = 0.5
@export var requires_power: bool = false

var interact_id: int = -1


func _ready() -> void:
	add_to_group(&"interactable")


# --- virtuals ---------------------------------------------------------------------------------


# Shown at all (false hides the prompt, e.g. an opened door).
func is_available(_player: PlayerCharacter) -> bool:
	return true


func get_cost(_player: PlayerCharacter) -> int:
	return cost


func get_prompt(player: PlayerCharacter) -> String:
	var c: int = get_cost(player)
	return "Hold [F] to %s%s" % [prompt, " [%d]" % c if c > 0 else ""]


# HOST: "" = allowed, otherwise the refusal reason shown to the player.
func host_check(_peer_id: int, _player: PlayerCharacter) -> String:
	return ""


# HOST: performs the effect after the cost was paid. Returns false to refund.
func host_execute(_peer_id: int, _player: PlayerCharacter) -> bool:
	return true


# --- helpers ----------------------------------------------------------------------------------


func focus_point() -> Vector3:
	return global_position


func in_range(player: PlayerCharacter, slack: float = 0.0) -> bool:
	var eye: Vector3 = player.global_position + Vector3.UP * 1.0
	return eye.distance_to(focus_point()) <= use_radius + slack
