# ViewmodelEvents — sink for viewmodel animation method-track keys: plays the keyed weapon sound
# (`wpn_<id>_<kind>`, e.g. mag_out / mag_in / bolt / shell / pump / raise) and re-emits it.
# Authority: local presentation.
class_name ViewmodelEvents
extends Node

signal event(kind: StringName)

var weapon: WeaponDefinition = null


func ev(kind: StringName) -> void:
	if kind == &"swing":
		Audio.play_event(&"melee_swing")
	elif weapon != null:
		Audio.play_event(WeaponAudio.event(weapon, String(kind)))
	event.emit(kind)
