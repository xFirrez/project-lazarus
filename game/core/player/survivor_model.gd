# SurvivorModel — third-person player character model (placeholder until the survivor rigs land).
# Driven every frame from the PlayerCharacter's replicated state by `update_from`.
# Authority: local presentation.
class_name SurvivorModel
extends Node3D

var character: CharacterDefinition = null


func update_from(_player: PlayerCharacter, _delta: float) -> void:
	pass
