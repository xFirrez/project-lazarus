# Audio — bus layout, the mix, named audio events and pooled one-shot players.
# Authority: local presentation. Every interaction must play a named event; unknown events are
# logged once so silence is caught early. The status of every event (final / accepted) is audited
# against content/audio/audio_manifest.json (AC-15.3).
# Mix (Step 15, GAME_DESIGN §16 priorities): per-bus base levels (MIX_DB, added to the player's
# volume sliders), VO ducks Music and Ambience (sidechain compressors), a hard limiter on Master
# (ceiling MASTER_CEILING_DB, so the master never clips), distance attenuation per bus for the 3D
# pool (ATTENUATION) and the low-health muffle low-pass. Loudness target ≈ −16 LUFS integrated for
# gameplay capture (measured by `run_sim.sh mix`, logged in GAME_DESIGN §19).
extends Node

signal event_played(event: StringName)
signal event_registered(event: StringName)

const BUSES: PackedStringArray = ["Music", "SFX", "Weapons", "Zombies", "UI", "VO", "Ambience"]
const PLAYER_POOL: int = 32
const PLAYER_POOL_3D: int = 24
const MUFFLED_BUSES: PackedStringArray = ["SFX", "Weapons", "Zombies"]
const MUFFLE_OPEN_HZ: float = 20000.0
const MUFFLE_CLOSED_HZ: float = 900.0
const AUDIO_ZONE_LAYER: int = 1 << 9  # physics layer 10 "audio_zone" (ReverbZone areas)
# Base mix per bus in dB (own weapon > nearby zombie attacks > feedback > VO > ambience).
const MIX_DB: Dictionary = {
	"Master": -3.0,  # loudness target ≈ −16 LUFS (measured in run_sim.sh presentation)
	"Music": -7.0,
	"SFX": -3.0,
	"Weapons": -1.0,
	"Zombies": -3.0,
	"UI": -6.0,
	"VO": 0.0,
	"Ambience": -9.0,
}
const MASTER_CEILING_DB: float = -1.0
const DUCKED_BUSES: PackedStringArray = ["Music", "Ambience"]
# 3D attenuation per bus: [unit_size, max_distance, attenuation filter cutoff Hz].
const ATTENUATION: Dictionary = {
	"Weapons": [11.0, 95.0, 9000.0],
	"Zombies": [5.0, 42.0, 6500.0],
	"SFX": [6.0, 48.0, 8000.0],
	"VO": [7.0, 50.0, 9000.0],
	"Ambience": [8.0, 60.0, 7000.0],
	"Music": [9.0, 60.0, 9000.0],
	"UI": [6.0, 45.0, 9000.0],
}
# Reverb presets for ReverbZone areas: name -> [room size, damping, wet, pre-delay ms, spread].
const REVERBS: Dictionary = {
	&"Reverb_Room": [0.35, 0.6, 0.18, 15.0, 0.6],
	&"Reverb_Hall": [0.7, 0.45, 0.28, 35.0, 0.9],
	&"Reverb_Tunnel": [0.6, 0.25, 0.32, 25.0, 0.4],
	&"Reverb_Industrial": [0.65, 0.35, 0.3, 30.0, 0.8],
	&"Reverb_Tile": [0.5, 0.15, 0.3, 12.0, 0.7],
	&"Reverb_Cavern": [0.95, 0.3, 0.42, 60.0, 1.0],
	&"Reverb_Exterior": [0.25, 0.8, 0.06, 5.0, 1.0],
}

var muffle_amount: float = 0.0

var _tasks: Array[int] = []
var _events: Dictionary = {}  # StringName -> {stream, bus, volume_db}
var _final: Dictionary = {}  # events registered with register_final
var _warned: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next_player: int = 0
var _shut_down: bool = false
var _players_3d: Array[AudioStreamPlayer3D] = []
var _next_player_3d: int = 0
var _muffle_filters: Array[AudioEffectLowPassFilter] = []


func _ready() -> void:
	ensure_buses()
	for i: int in PLAYER_POOL:
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	for i: int in PLAYER_POOL_3D:
		var p3: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
		p3.unit_size = 6.0
		p3.max_distance = 45.0
		p3.area_mask = 1 | AUDIO_ZONE_LAYER
		add_child(p3)
		_players_3d.append(p3)
	_setup_muffle()
	_setup_mix()
	register_event(&"ui_click", make_tone(880.0, 0.05), &"UI")
	register_event(&"player_hurt", make_tone(140.0, 0.12), &"SFX", -4.0)
	register_event(&"player_heartbeat", _make_heartbeat(), &"UI", -2.0)
	register_event(&"player_downed", make_tone(110.0, 0.6), &"UI")
	register_event(&"ui_error", make_tone(220.0, 0.15), &"UI")
	register_event(&"net_peer_joined", make_tone(660.0, 0.12), &"UI")
	register_event(&"net_peer_left", make_tone(330.0, 0.12), &"UI")
	ScoreAudio.ensure()
	_apply_volumes()
	Config.setting_changed.connect(_on_setting_changed)


func ensure_buses() -> void:
	for bus_name: String in BUSES:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var idx: int = AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, &"Master")


# Creates (once) a reverb send bus for ReverbZone areas; returns its name ("" if unknown preset).
func ensure_reverb_bus(preset: StringName) -> StringName:
	if not REVERBS.has(preset):
		return &""
	if AudioServer.get_bus_index(preset) != -1:
		return preset
	AudioServer.add_bus()
	var idx: int = AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, preset)
	AudioServer.set_bus_send(idx, &"Master")
	var r: Array = REVERBS[preset]
	var fx: AudioEffectReverb = AudioEffectReverb.new()
	fx.room_size = float(r[0])
	fx.damping = float(r[1])
	fx.wet = float(r[2])
	fx.dry = 0.0
	fx.predelay_msec = float(r[3])
	fx.spread = float(r[4])
	AudioServer.add_bus_effect(idx, fx)
	return preset


func bus_names() -> PackedStringArray:
	var names: PackedStringArray = []
	for i: int in AudioServer.bus_count:
		names.append(AudioServer.get_bus_name(i))
	return names


# Background synthesis jobs (WorkerThreadPool task ids, e.g. PerkAudio / PowerUpAudio) are waited
# for at shutdown so no worker outlives the engine.
func track_task(task_id: int) -> void:
	_tasks.append(task_id)


func wait_for_synthesis() -> void:
	for t: int in _tasks:
		WorkerThreadPool.wait_for_task_completion(t)
	_tasks.clear()


func register_event(event: StringName, stream: AudioStream, bus: StringName, volume_db: float = 0.0) -> void:
	if _final.has(event):
		return  # the final asset (ScoreAudio etc.) wins over an earlier system's stand-in
	_events[event] = {"stream": stream, "bus": bus, "volume_db": volume_db}


# Registers the final version of an event; later plain register_event calls for it are ignored.
func register_final(event: StringName, stream: AudioStream, bus: StringName, volume_db: float = 0.0) -> void:
	_final[event] = true
	_events[event] = {"stream": stream, "bus": bus, "volume_db": volume_db}
	event_registered.emit(event)


func event_stream(event: StringName) -> AudioStream:
	return (_events[event] as Dictionary)["stream"] if _events.has(event) else null


func is_final(event: StringName) -> bool:
	return _final.has(event)


func has_event(event: StringName) -> bool:
	return _events.has(event)


func play_event(event: StringName) -> void:
	if _shut_down:
		return
	if not _events.has(event):
		if not _warned.has(event):
			_warned[event] = true
			Log.warn(&"audio", "Unregistered audio event '%s'" % event)
		return
	var def: Dictionary = _events[event]
	event_played.emit(event)
	var player: AudioStreamPlayer = _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	player.stream = def["stream"]
	player.bus = def["bus"]
	player.volume_db = def["volume_db"]
	player.play()


# Spatialized one-shot (remote players' footsteps, later zombies and weapons of others).
func play_event_3d(event: StringName, position: Vector3, pitch: float = 1.0) -> void:
	if _shut_down:
		return
	if not _events.has(event):
		play_event(event)  # logs the missing event once
		return
	var def: Dictionary = _events[event]
	event_played.emit(event)
	var player: AudioStreamPlayer3D = _players_3d[_next_player_3d]
	_next_player_3d = (_next_player_3d + 1) % _players_3d.size()
	player.stream = def["stream"]
	player.bus = def["bus"]
	player.volume_db = def["volume_db"]
	player.global_position = position
	player.pitch_scale = pitch
	var att: Array = ATTENUATION.get(String(def["bus"]), ATTENUATION["SFX"])
	player.unit_size = float(att[0])
	player.max_distance = float(att[1])
	player.attenuation_filter_cutoff_hz = float(att[2])
	player.play()


# Low-health muffling: 0 = open, 1 = fully muffled (low-pass on the SFX/Weapons/Zombies buses).
func set_muffle(amount: float) -> void:
	muffle_amount = clampf(amount, 0.0, 1.0)
	var cutoff: float = lerpf(MUFFLE_OPEN_HZ, MUFFLE_CLOSED_HZ, pow(muffle_amount, 0.5))
	for i: int in _muffle_filters.size():
		_muffle_filters[i].cutoff_hz = cutoff
		var bus: int = AudioServer.get_bus_index(MUFFLED_BUSES[i])
		if bus >= 0:
			AudioServer.set_bus_effect_enabled(bus, 0, muffle_amount > 0.001)


func _setup_muffle() -> void:
	for bus_name: String in MUFFLED_BUSES:
		var bus: int = AudioServer.get_bus_index(bus_name)
		var lpf: AudioEffectLowPassFilter = AudioEffectLowPassFilter.new()
		lpf.cutoff_hz = MUFFLE_OPEN_HZ
		AudioServer.add_bus_effect(bus, lpf, 0)
		AudioServer.set_bus_effect_enabled(bus, 0, false)
		_muffle_filters.append(lpf)


func _make_heartbeat() -> AudioStreamWAV:
	var rate: int = 22050
	var count: int = int(rate * 0.45)
	var data: PackedByteArray = PackedByteArray()
	data.resize(count * 2)
	for i: int in count:
		var t: float = float(i) / rate
		var s: float = 0.0
		for beat: float in [0.0, 0.22]:
			var bt: float = t - beat
			if bt >= 0.0:
				s += sin(TAU * 55.0 * bt) * exp(-bt * 28.0)
		data.encode_s16(i * 2, int(clampf(s * 0.8, -1.0, 1.0) * 32767.0))
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.data = data
	return wav


func _apply_volumes() -> void:
	for i: int in AudioServer.bus_count:
		var bus_name: String = AudioServer.get_bus_name(i)
		if REVERBS.has(StringName(bus_name)):
			continue
		var linear: float = float(Config.get_value(&"audio", StringName(bus_name), 1.0))
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(linear, 0.0001)) + float(MIX_DB.get(bus_name, 0.0)))


# Master limiter + VO ducking. Effects are appended after the muffle filters (index 0 there).
func _setup_mix() -> void:
	var master: int = AudioServer.get_bus_index(&"Master")
	if not _has_effect(master, "AudioEffectHardLimiter"):
		var lim: AudioEffectHardLimiter = AudioEffectHardLimiter.new()
		lim.ceiling_db = MASTER_CEILING_DB
		lim.release = 0.12
		AudioServer.add_bus_effect(master, lim)
	for bus_name: String in DUCKED_BUSES:
		var idx: int = AudioServer.get_bus_index(bus_name)
		if idx < 0 or _has_effect(idx, "AudioEffectCompressor"):
			continue
		var duck: AudioEffectCompressor = AudioEffectCompressor.new()
		duck.sidechain = &"VO"
		duck.threshold = -32.0
		duck.ratio = 6.0
		duck.attack_us = 8000.0
		duck.release_ms = 450.0
		duck.gain = 0.0
		AudioServer.add_bus_effect(idx, duck)


func _has_effect(bus: int, cls: String) -> bool:
	for i: int in AudioServer.get_bus_effect_count(bus):
		if AudioServer.get_bus_effect(bus, i).get_class() == cls:
			return true
	return false


# Current master peak (dBFS, max of both channels) — the mix test logs it every frame.
func master_peak_db() -> float:
	var m: int = AudioServer.get_bus_index(&"Master")
	return maxf(AudioServer.get_bus_peak_volume_left_db(m, 0), AudioServer.get_bus_peak_volume_right_db(m, 0))


func registered_events() -> Dictionary:
	var out: Dictionary = {}
	for e: StringName in _events:
		out[e] = String((_events[e] as Dictionary)["bus"])
	return out


func _on_setting_changed(section: StringName, _key: StringName, _value: Variant) -> void:
	if section == &"audio":
		_apply_volumes()


# Placeholder tone generator so interactions are never silent before real assets exist.
func make_tone(freq: float, seconds: float) -> AudioStreamWAV:
	var rate: int = 22050
	var count: int = int(rate * seconds)
	var data: PackedByteArray = PackedByteArray()
	data.resize(count * 2)
	for i: int in count:
		var env: float = 1.0 - float(i) / count
		var s: float = sin(TAU * freq * i / rate) * env * 0.4
		data.encode_s16(i * 2, int(s * 32767.0))
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.data = data
	return wav


func _exit_tree() -> void:
	shutdown()


# Stops every pooled one-shot (tests: no playback may outlive the run).
func stop_all() -> void:
	for p: AudioStreamPlayer in _players:
		p.stop()
	for p3: AudioStreamPlayer3D in _players_3d:
		p3.stop()


# Stops all playback and ignores further events. Call before quitting in the same frame as a
# sound was started, otherwise the mixer still holds the playback and it is reported as leaked.
func shutdown() -> void:
	_shut_down = true
	wait_for_synthesis()
	for p: AudioStreamPlayer in _players:
		p.stop()
		p.stream = null
	for p3: AudioStreamPlayer3D in _players_3d:
		p3.stop()
		p3.stream = null
	# Ambience beds (map emitters) hold the cached loops: stop them, then drop the cache.
	for e: Node in get_tree().get_nodes_in_group(&"ambience_emitter") if is_inside_tree() else []:
		var ep: Node = (e as AmbienceEmitter).player
		if ep is AudioStreamPlayer3D:
			(ep as AudioStreamPlayer3D).stop()
			(ep as AudioStreamPlayer3D).stream = null
		elif ep is AudioStreamPlayer:
			(ep as AudioStreamPlayer).stop()
			(ep as AudioStreamPlayer).stream = null
	AmbienceLibrary.clear_cache()
