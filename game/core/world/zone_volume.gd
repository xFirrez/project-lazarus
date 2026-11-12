# ZoneVolume — an axis-aligned box (in its own frame) marking where a zone is; ZoneManager asks
# which volume contains each player. Pure math (no physics overlap) so the answer is identical on
# every peer and in headless tests.
# Authority: static map data.
class_name ZoneVolume
extends Node3D

@export var zone: StringName = &""
@export var size: Vector3 = Vector3(10, 4, 10)


func _ready() -> void:
	add_to_group(&"zone_volume")


func contains(p: Vector3) -> bool:
	var l: Vector3 = to_local(p)
	var h: Vector3 = size * 0.5
	return absf(l.x) <= h.x and absf(l.y) <= h.y and absf(l.z) <= h.z
