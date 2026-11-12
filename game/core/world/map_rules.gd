# MapRules — the map module's script hooks (ARCHITECTURE §9). A map subclasses this in
# maps/<id>/scripts/ and names it in MapDefinition.rules_script; core calls the hooks and never
# references the map. Default implementations do nothing.
# Authority: hooks run on the HOST only (they may change shared state through host APIs).
class_name MapRules
extends RefCounted

var match_node: Match = null


func on_match_start() -> void:
	pass


func on_round_start(_round: int) -> void:
	pass


func on_round_end(_round: int) -> void:
	pass


func on_zone_unlocked(_zone: StringName) -> void:
	pass


func on_door_opened(_door_id: StringName, _peer_id: int) -> void:
	pass


# Every Resonance Relay (RelaySystem) is done: unlock what the map gates behind them.
func on_relays_complete() -> void:
	pass


# Special-round enemy for round r (Step 12); &"" = a normal round.
func get_special_round_enemy(_round: int) -> StringName:
	return &""
