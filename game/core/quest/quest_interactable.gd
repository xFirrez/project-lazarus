# QuestInteractable — a generic interactable for quest objects (radio dials, drawers, the pod, the
# core socket, music boxes, mirrors ...): its prompt, availability, host check and effect come from
# Callables the map sets up (every peer builds the same nodes before the interaction scan, so ids
# match). With no `execute_fn` the host forwards an `interact` quest event {id, peer} to the active
# objectives. Presentation follows the replicated flags the callables read.
# Authority: HOST executes (InteractionSystem validates range / cost first); every peer evaluates
# prompts locally.
class_name QuestInteractable
extends Interactable

var quest_key: StringName = &""
var available_fn: Callable = Callable()  # func(player: PlayerCharacter) -> bool
var prompt_fn: Callable = Callable()  # func(player: PlayerCharacter) -> String (text after "Hold [F] to ")
var check_fn: Callable = Callable()  # HOST func(peer_id: int) -> String ("" = allowed)
var execute_fn: Callable = Callable()  # HOST func(peer_id: int) -> bool
var focus_offset: Vector3 = Vector3.ZERO


func focus_point() -> Vector3:
	return global_position + focus_offset


func is_available(player: PlayerCharacter) -> bool:
	return available_fn.call(player) if available_fn.is_valid() else true


func get_prompt(player: PlayerCharacter) -> String:
	if prompt_fn.is_valid():
		var c: int = get_cost(player)
		return "Hold [F] to %s%s" % [String(prompt_fn.call(player)), " [%d]" % c if c > 0 else ""]
	return super(player)


func host_check(peer_id: int, _player: PlayerCharacter) -> String:
	return String(check_fn.call(peer_id)) if check_fn.is_valid() else ""


func host_execute(peer_id: int, _player: PlayerCharacter) -> bool:
	if execute_fn.is_valid():
		return bool(execute_fn.call(peer_id))
	var q: QuestSystem = Match.current.quest if Match.current != null else null
	if q == null:
		return false
	q.host_event(&"interact", {"id": quest_key, "peer": peer_id})
	return true
