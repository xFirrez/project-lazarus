# MapRules — the map module's script hooks (ARCHITECTURE §9). A map subclasses this in
# maps/<id>/scripts/ and names it in MapDefinition.rules_script; core calls the hooks and never
# references the map. Default implementations do nothing.
# Authority: hooks run on the HOST only (they may change shared state through host APIs).
class_name MapRules
extends RefCounted

var match_node: Match = null
# The rare late-round Warden (GAME_DESIGN §5.4) is implemented in SpecialRoundDirector but gated
# here: off until the Easter-egg step balances it (debug `warden_late on` flips it on the host).
var warden_late_rounds: bool = false


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


# Special-round enemy for round r (Step 12); &"" = a normal round. Must be deterministic per
# round within a match (asked at round start and at the intermission before it).
func get_special_round_enemy(_round: int) -> StringName:
	return &""


# Special enemy mixed (1-2) into normal round r (RoundCurve.mixed_from_round); &"" = none.
func get_mixed_enemy(_round: int) -> StringName:
	return &""


# The late-round Warden rule is on (SpecialRoundDirector asks at every round start).
func warden_late_rounds_enabled() -> bool:
	return warden_late_rounds
