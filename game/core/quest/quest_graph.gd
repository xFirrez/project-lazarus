# QuestGraph — an ordered / parallel set of QuestSteps (ARCHITECTURE §10): Easter eggs and side
# quests. Maps list their graphs in MapDefinition.quests; QuestSystem runs them on the host.
# `badge` (non-empty) is the persistent Journal badge awarded on every peer when the graph's
# completing step is done; `journal_unlocks` are Journal entries unlocked at the same moment.
# Authority: static data.
class_name QuestGraph
extends Resource

@export var id: StringName = &""
@export var title: String = ""
@export var steps: Array[QuestStep] = []
@export var badge: StringName = &""
# Journal entries unlocked on every peer when the graph completes (Vesper Peak: R09 + "requiem").
@export var journal_unlocks: Array[StringName] = []


func step(step_id: StringName) -> QuestStep:
	for s: QuestStep in steps:
		if s.id == step_id:
			return s
	return null


# Prerequisites of `step_id`, transitively, in an order where each comes after its own (debug jump).
func ancestors(step_id: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	_collect(step_id, out)
	out.erase(step_id)
	return out


func _collect(step_id: StringName, out: Array[StringName]) -> void:
	var s: QuestStep = step(step_id)
	if s == null or out.has(step_id):
		return
	for p: StringName in s.prerequisites:
		_collect(p, out)
	out.append(step_id)


# Every prerequisite names a step of this graph and there are no cycles (unit test / load check).
func validate() -> PackedStringArray:
	var errors: PackedStringArray = []
	var ids: Dictionary = {}
	for s: QuestStep in steps:
		if ids.has(s.id):
			errors.append("duplicate step %s" % s.id)
		ids[s.id] = true
	for s: QuestStep in steps:
		for p: StringName in s.prerequisites:
			if not ids.has(p):
				errors.append("%s: unknown prerequisite %s" % [s.id, p])
		if s.objective == null:
			errors.append("%s: no objective script" % s.id)
	for s: QuestStep in steps:
		var seen: Dictionary = {}
		var stack: Array[StringName] = [s.id]
		while not stack.is_empty():
			var cur: StringName = stack.pop_back()
			var cs: QuestStep = step(cur)
			if cs == null:
				continue
			for p: StringName in cs.prerequisites:
				if p == s.id:
					errors.append("cycle through %s" % s.id)
					stack.clear()
					break
				if not seen.has(p):
					seen[p] = true
					stack.append(p)
	return errors
