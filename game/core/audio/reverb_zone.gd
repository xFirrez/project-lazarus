# ReverbZone — an Area3D that routes 3D sounds playing inside it through a reverb send bus
# (Step 13, DEVELOPMENT_PLAN §13 scope 4): Godot's built-in area reverb, on physics layer 10
# ("audio_zone") so gameplay queries never see it. `preset` names an Audio.REVERBS entry
# (Room / Hall / Tunnel / Industrial / Tile / Cavern / Exterior). Maps place one per acoustic space.
# Authority: local presentation.
class_name ReverbZone
extends Area3D

@export var preset: StringName = &"Reverb_Room"
@export var size: Vector3 = Vector3(10, 4, 10)
@export var amount: float = 0.8
@export var zone: StringName = &""


func _ready() -> void:
	add_to_group(&"reverb_zone")
	collision_layer = Audio.AUDIO_ZONE_LAYER
	collision_mask = 0
	monitoring = false
	monitorable = true
	var cs: CollisionShape3D = CollisionShape3D.new()
	var bs: BoxShape3D = BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	add_child(cs)
	var bus: StringName = Audio.ensure_reverb_bus(preset)
	if bus != &"":
		reverb_bus_enabled = true
		reverb_bus_name = bus
		reverb_bus_amount = amount
		reverb_bus_uniformity = 0.4
