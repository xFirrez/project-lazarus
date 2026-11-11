# Audio — bus layout, named audio events and pooled one-shot players.
# Authority: local presentation. Every interaction must play a named event (placeholder at
# minimum); unknown events are logged once so silence is caught early.
extends Node

const BUSES: PackedStringArray = ["Music", "SFX", "Weapons", "Zombies", "UI", "VO", "Ambience"]
const PLAYER_POOL: int = 32
const PLAYER_POOL_3D: int = 24
const MUFFLED_BUSES: PackedStringArray = ["SFX", "Weapons", "Zombies"]
const MUFFLE_OPEN_HZ: float = 20000.0
const MUFFLE_CLOSED_HZ: float = 900.0

var muffle_amount: float = 0.0

var _events: Dictionary = {}  # StringName -> {stream, bus, volume_db}
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
		add_child(p3)
		_players_3d.append(p3)
	_setup_muffle()
	register_event(&"ui_click", make_tone(880.0, 0.05), &"UI")
	register_event(&"player_hurt", make_tone(140.0, 0.12), &"SFX", -4.0)
	register_event(&"player_heartbeat", _make_heartbeat(), &"UI", -2.0)
	register_event(&"player_downed", make_tone(110.0, 0.6), &"UI")
	register_event(&"ui_error", make_tone(220.0, 0.15), &"UI")
	register_event(&"net_peer_joined", make_tone(660.0, 0.12), &"UI")
	register_event(&"net_peer_left", make_tone(330.0, 0.12), &"UI")
	_apply_volumes()
	Config.setting_changed.connect(_on_setting_changed)


func ensure_buses() -> void:
	for bus_name: String in BUSES:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var idx: int = AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, &"Master")


func bus_names() -> PackedStringArray:
	var names: PackedStringArray = []
	for i: int in AudioServer.bus_count:
		names.append(AudioServer.get_bus_name(i))
	return names


func register_event(event: StringName, stream: AudioStream, bus: StringName, volume_db: float = 0.0) -> void:
	_events[event] = {"stream": stream, "bus": bus, "volume_db": volume_db}


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
	var player: AudioStreamPlayer3D = _players_3d[_next_player_3d]
	_next_player_3d = (_next_player_3d + 1) % _players_3d.size()
	player.stream = def["stream"]
	player.bus = def["bus"]
	player.volume_db = def["volume_db"]
	player.global_position = position
	player.pitch_scale = pitch
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
		var linear: float = float(Config.get_value(&"audio", StringName(bus_name), 1.0))
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(linear, 0.0001)))


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


# Stops all playback and ignores further events. Call before quitting in the same frame as a
# sound was started, otherwise the mixer still holds the playback and it is reported as leaked.
func shutdown() -> void:
	_shut_down = true
	for p: AudioStreamPlayer in _players:
		p.stop()
		p.stream = null
	for p3: AudioStreamPlayer3D in _players_3d:
		p3.stop()
		p3.stream = null
