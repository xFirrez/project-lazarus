# CoopAudio — placeholder audio events for the co-op layer (lobby, pings), synthesised like
# SurvivalAudio until Step 15's final sounds: lobby countdown / chat / ready, and one short cue
# per ping kind (location, zombie, item, machine) so teammates can tell them apart by ear.
# Authority: local presentation.
class_name CoopAudio
extends RefCounted

static var _registered: bool = false


static func ensure_events() -> void:
	if _registered:
		return
	_registered = true
	Audio.register_event(&"lobby_countdown", SurvivalAudio._sting([392.0, 392.0, 587.0], 0.25), &"UI", -6.0)
	Audio.register_event(&"lobby_chat", SurvivalAudio._sting([740.0], 0.06), &"UI", -12.0)
	Audio.register_event(&"lobby_ready", SurvivalAudio._sting([523.0, 659.0], 0.08), &"UI", -8.0)
	Audio.register_event(&"ping_location", SurvivalAudio._sting([880.0, 1175.0], 0.07), &"UI", -6.0)
	Audio.register_event(&"ping_zombie", SurvivalAudio._sting([440.0, 330.0], 0.09), &"UI", -4.0)
	Audio.register_event(&"ping_item", SurvivalAudio._sting([988.0, 1319.0, 988.0], 0.06), &"UI", -6.0)
	Audio.register_event(&"ping_machine", SurvivalAudio._sting([659.0, 988.0, 1319.0], 0.07), &"UI", -6.0)
