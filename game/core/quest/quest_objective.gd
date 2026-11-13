# QuestObjective — the host-side logic of one QuestStep (ARCHITECTURE §10). QuestSystem creates
# it when the step becomes ACTIVE and forwards host events (`on_event`) and ticks (`on_tick`) to it
# until it calls `complete()`. All state that peers or late joiners must see lives in MatchSession
# flags (`set_value` -> "q.<step>.<key>"; `set_flag` for map-wide keys), so an objective holds only
# derived / transient host data and can be rebuilt from the flags.
# Events (QuestSystem.EVENTS): zombie_killed {actor, position, peer, weapon, kind}, zombie_spawned
# {actor}, round_started {round}, round_ended {round}, damaged {target, amount, kind, peer,
# weapon}, interact {id, peer, ...}, flag {key, value}, player_downed {peer}, player_revived
# {peer}, carry {item, event, peer}, custom map events.
# Authority: HOST only.
class_name QuestObjective
extends RefCounted

var quest: QuestSystem = null
var step: QuestStep = null
var graph: QuestGraph = null

# --- virtuals ---------------------------------------------------------------------------------


func on_activate() -> void:
	pass


func on_event(_event: StringName, _data: Dictionary) -> void:
	pass


func on_tick(_delta: float) -> void:
	pass


# Debug skip (`ee_skip`, `ee_stage`): leave the world as a real completion would, then complete().
func on_debug_complete() -> void:
	complete()


# The step just completed (after the DONE flag): clean-up of transient host objects.
func on_done() -> void:
	pass


# Match teardown: drop references that could form RefCounted cycles (helpers holding the objective).
func release() -> void:
	quest = null


# --- helpers ----------------------------------------------------------------------------------


func m() -> Match:
	return quest.match_node if quest != null else null


func param(key: String, default: Variant = null) -> Variant:
	return step.params.get(key, default) if step != null else default


func key(k: String) -> String:
	return "q.%s.%s" % [step.id, k]


func get_value(k: String, default: Variant = null) -> Variant:
	return quest.flag(key(k), default)


func set_value(k: String, value: Variant) -> void:
	if quest.flag(key(k), null) != value:
		quest.host_set(key(k), value)


func get_flag(k: String, default: Variant = null) -> Variant:
	return quest.flag(k, default)


func set_flag(k: String, value: Variant) -> void:
	if quest.flag(k, null) != value:
		quest.host_set(k, value)


func complete() -> void:
	quest.host_complete(step.id)


func is_active() -> bool:
	return quest.state(step.id) == QuestSystem.State.ACTIVE


func player_count() -> int:
	return quest.player_count()


# Scaling for co-op (VESPER_PEAK §7.1: counts, not mechanics): base + per_extra × (players − 1).
func scaled(base: float, per_extra: float) -> float:
	return base + per_extra * float(maxi(player_count() - 1, 0))


func now() -> float:
	return quest.now()


func log_info(text: String) -> void:
	Log.info(&"quest", "[%s] %s" % [step.id, text])
