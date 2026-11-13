# QuestStep — one step of a QuestGraph (ARCHITECTURE §10): an id, the steps it waits for
# (`prerequisites`: every one DONE), the objective script that watches host events while the step
# is ACTIVE (a QuestObjective subclass), free-form tuning `params` and an optional hint (debug /
# a later "story mode"). Steps without prerequisites start ACTIVE when the match starts.
# Authority: static data.
class_name QuestStep
extends Resource

@export var id: StringName = &""
@export var title: String = ""
@export var prerequisites: Array[StringName] = []
@export var objective: Script = null
@export var params: Dictionary = {}
@export_multiline var hint: String = ""
# Steps that must be DONE for the whole graph to count as complete (the last step of a quest).
@export var completes_graph: bool = false
