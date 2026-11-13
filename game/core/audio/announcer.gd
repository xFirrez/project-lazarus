# Announcer — the "Voice of the Mountain" (GAME_DESIGN §16, DEVELOPMENT_PLAN Step 15 scope 6): an
# original layered, whispery announcer for power-up callouts (PowerUpSystem: `pu_vo_<type>`), the
# round-1 intro and special-round warnings, always subtitled (Captions). The voice is synthesized
# (ScoreAudio.announcer); recorded takes replace the `ann_*` / `pu_vo_*` events when delivered.
# Authority: local presentation (called from replicated round / power-up presentation).
class_name Announcer
extends RefCounted

const SPEAKER: String = "Voice of the Mountain"
const COLOR: Color = Color(0.62, 0.85, 1.0)
const LINES: Dictionary = {
	&"ann_round_one": "The mountain wakes. Hold the station... if you can.",
	&"ann_special": "Hear it? The storm is breaking.",
}


static func say(event: StringName, seconds: float = 3.5) -> void:
	Audio.play_event(event)
	var m: Match = Match.current
	if m != null and m.captions != null:
		m.captions.push(SPEAKER, String(LINES.get(event, "")), COLOR, seconds)
