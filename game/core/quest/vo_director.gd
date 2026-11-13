# VoDirector — quest voice-over and reel playback with mandatory subtitles (DEVELOPMENT_PLAN Step 14
# scope 2 / 6). `host_play(entry, at)` broadcasts `_vo`; every peer queues the entry's lines
# (LoreLibrary), plays each line's recorded take when one is delivered (content/audio/vo/
# <entry>_<line>.ogg|wav), otherwise the synthesized voice (pitched per speaker, radio-filtered;
# an accepted asset, see content/audio/audio_manifest.json) at `at` (positional) or map-wide
# (`at` = INF, e.g. the radio broadcast), and shows each line as a subtitle. One entry at a time:
# a new entry replaces the current one (story beats outrank ambient reels).
# Authority: HOST triggers quest VO; reels are triggered through LoreItem (QuestSystem `_reel`).
class_name VoDirector
extends Node

const SUBTITLE_LAYER: int = 8

var quest: QuestSystem = null
var lore: LoreLibrary = null
var playing_id: StringName = &""
var lines_played: int = 0  # every peer (tests)
var played_ids: Array[StringName] = []
var current_text: String = ""  # the subtitle on screen ("" = none)
var lines_played_in_entry: int = 0

var _queue: Array = []
var _line_left: float = 0.0
var _at: Vector3 = Vector3.INF
var _label: Label = null
var _layer: CanvasLayer = null


func _ready() -> void:
	name = "Vo"
	Net.register_message(&"_vo", _on_msg_vo)
	_layer = CanvasLayer.new()
	_layer.layer = SUBTITLE_LAYER
	_layer.name = "Subtitles"
	add_child(_layer)
	_label = Label.new()
	_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.custom_minimum_size = Vector2(900, 0)
	_label.position = Vector2(-450, -170)
	_label.add_theme_font_override(&"font", UiTheme.font(&"type"))
	_label.add_theme_font_size_override(&"font_size", 22)
	_label.add_theme_color_override(&"font_outline_color", Color(0, 0, 0, 0.9))
	_label.add_theme_constant_override(&"outline_size", 6)
	_layer.add_child(_label)


func _exit_tree() -> void:
	Net.unregister_message(&"_vo")


func is_playing(id: StringName = &"") -> bool:
	return playing_id != &"" and (id == &"" or id == playing_id)


func host_play(entry_id: StringName, at: Vector3 = Vector3.INF) -> void:
	if not QuestSystem.is_authority():
		return
	Net.send_reliable(0, &"_vo", [String(entry_id), at])
	play_local(entry_id, at)


func _on_msg_vo(sender: int, p: Array) -> void:
	if sender == 1 and p.size() >= 2:
		play_local(StringName(p[0]), p[1])


func play_local(entry_id: StringName, at: Vector3 = Vector3.INF) -> void:
	if lore == null or lore.entry(entry_id).is_empty():
		Log.warn(&"vo", "Unknown VO entry %s" % entry_id)
		return
	_queue = lore.lines_of(entry_id).duplicate()
	playing_id = entry_id
	played_ids.append(entry_id)
	_at = at
	_line_left = 0.0
	lines_played_in_entry = 0
	if lore.kind_of(entry_id) == "reel" and at.is_finite():
		Audio.play_event_3d(&"reel_click", at)
	_next_line()


# A delivered recording for one line (the asset request list in docs/PROGRESS.md names them).
static func recorded_line(entry_id: StringName, index: int) -> AudioStream:
	for ext: String in ["ogg", "wav"]:
		var path: String = "res://content/audio/vo/%s_%d.%s" % [entry_id, index, ext]
		if ResourceLoader.exists(path):
			return load(path) as AudioStream
	return null


func stop() -> void:
	_queue.clear()
	playing_id = &""
	current_text = ""
	_line_left = 0.0
	if _label != null:
		_label.text = ""


func _next_line() -> void:
	if _queue.is_empty():
		stop()
		return
	var line: Array = _queue.pop_front()
	var speaker: String = String(line[0])
	_line_left = LoreLibrary.line_seconds(line)
	current_text = "%s: %s" % [lore.speaker_name(speaker), String(line[1])]
	lines_played += 1
	if _label != null:
		_label.text = current_text
		_label.visible = Captions.enabled()
		_label.modulate = Color(0.75, 1.0, 0.8) if speaker == "VARGA" else Color(1, 1, 1)
	var pitch: float = lore.speaker_pitch(speaker)
	# Recorded VO (when delivered): content/audio/vo/<entry>_<line>.ogg|wav, else the voice synth.
	var recorded: AudioStream = recorded_line(playing_id, lines_played_in_entry)
	lines_played_in_entry += 1
	if recorded != null:
		var ev: StringName = StringName("vo_rec_%s_%d" % [playing_id, lines_played_in_entry - 1])
		Audio.register_event(ev, recorded, &"VO", 0.0)
		if _at.is_finite():
			Audio.play_event_3d(ev, _at)
		else:
			Audio.play_event(ev)
	elif _at.is_finite():
		Audio.play_event_3d(&"vo_voice", _at, pitch)
	else:
		Audio.play_event(&"vo_voice_radio")


func _process(delta: float) -> void:
	if playing_id == &"":
		return
	_line_left -= delta
	if _line_left <= 0.0:
		_next_line()
