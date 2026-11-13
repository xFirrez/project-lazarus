# BarricadeRepair — the inside "rebuild" interaction of a Barricade (GAME_DESIGN §12): hold to put
# one plank back every 0.5 s; 10 points per plank up to the per-round cap (PointsLedger). Created
# by the Barricade itself, so every barricade on every map gets one.
# Authority: HOST executes; prompts are local.
class_name BarricadeRepair
extends Interactable

var barricade: Barricade = null


func _ready() -> void:
	super()
	prompt = "rebuild barricade"
	continuous = true
	hold_time = 0.5
	repeat_interval = 0.5
	use_radius = 2.2


func is_available(_player: PlayerCharacter) -> bool:
	return barricade != null and barricade.planks < barricade.max_planks


func get_prompt(_player: PlayerCharacter) -> String:
	return "Hold [F] to rebuild barricade"


func host_execute(peer_id: int, _player: PlayerCharacter) -> bool:
	if not barricade.host_repair_one():
		return false
	var m: Match = Match.current
	if m != null and m.points != null:
		m.points.host_repair_reward(peer_id)
	return true
