# AmbienceEmitter — a looping ambience bed (AmbienceLibrary event) on the Ambience bus. Global
# beds (`spatial = false`) play everywhere; spatial ones (room tone, machinery) fade with
# distance via a dedicated AudioStreamPlayer3D so the shared one-shot pools are never held.
# Authority: local presentation.
class_name AmbienceEmitter
extends Node3D

@export var event: StringName = &"amb_storm_wind"
@export var volume_db: float = -8.0
@export var spatial: bool = false
@export var unit_size: float = 6.0

var player: Node = null


func _ready() -> void:
	AmbienceLibrary.ensure_registered()
	var stream: AudioStream = AmbienceLibrary.stream(event)
	if spatial:
		var p3: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
		p3.stream = stream
		p3.bus = &"Ambience"
		p3.volume_db = volume_db
		p3.unit_size = unit_size
		p3.autoplay = true
		player = p3
	else:
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		p.stream = stream
		p.bus = &"Ambience"
		p.volume_db = volume_db
		p.autoplay = true
		player = p
	add_child(player)
