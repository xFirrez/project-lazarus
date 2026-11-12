# ReactorState — the Lazarus Reactor's visual state (VESPER_PEAK §3 Z13; DEVELOPMENT_PLAN Step 11
# AC-11.1): power off = dark, still rings, a low glow; power on = the containment rings begin to
# turn and the core pulses; all three relays = the rings race, the core blazes and grows, and the
# bridge-extension beat plays (boom at the bridge, flash). Reads the replicated flags, so late
# joiners see the current state immediately.
# Authority: local presentation on every peer.
class_name ReactorState
extends Node3D

enum Stage { DORMANT, POWERED, STABILIZED }

var core: MeshInstance3D = null
var rings: Array[MeshInstance3D] = []
var light: OmniLight3D = null
var bridge_position: Vector3 = Vector3.ZERO
## Step 13: the reactor drone emitter; when it plays, the core's heartbeat follows its playback
## position (AmbienceLibrary.REACTOR_BPM) so the light thumps with the sound.
var heartbeat: AmbienceEmitter = null
var stage: Stage = Stage.DORMANT

var _match: Match = null
var _core_mat: StandardMaterial3D = null
var _t: float = 0.0
var _flash: float = 0.0
var _speed: float = 0.0


func _on_match_setup(m: Match) -> void:
	_match = m
	m.session.flag_changed.connect(_on_flag)


func _ready() -> void:
	if core != null and core.material_override is StandardMaterial3D:
		_core_mat = (core.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
		_core_mat.emission_enabled = true
		core.material_override = _core_mat
	if light == null and core != null:
		light = OmniLight3D.new()
		light.name = "StageLight"
		light.light_color = Color(0.4, 1.0, 0.55)
		light.omni_range = 40.0
		light.shadow_enabled = false
		add_child(light)
		light.global_position = core.global_position


func _on_flag(key: String, value: Variant) -> void:
	if key == RelaySystem.FLAG_DONE and bool(value) and stage != Stage.STABILIZED:
		_flash = 1.0
		Audio.play_event_3d(&"bridge_extend", bridge_position)
		Audio.play_event_3d(&"relay_done", core.global_position if core != null else bridge_position)


func _process(delta: float) -> void:
	_t += delta
	var s: MatchSession = _match.session if _match != null else null
	if s != null and bool(s.flag(RelaySystem.FLAG_DONE, false)):
		stage = Stage.STABILIZED
	elif Power.is_on():
		stage = Stage.POWERED
	else:
		stage = Stage.DORMANT
	var want: float = [0.0, 0.25, 1.4][stage]
	_speed = lerpf(_speed, want, clampf(delta * 0.6, 0.0, 1.0))
	for i: int in rings.size():
		rings[i].rotate_object_local(Vector3.UP, _speed * delta * (1.0 + 0.4 * i) * (1.0 if i % 2 == 0 else -1.0))
	_flash = maxf(_flash - delta * 0.4, 0.0)
	var beat: float = heartbeat_beat()
	var energy: float = [0.15, 0.8 + 0.5 * beat, 2.5 + 1.2 * beat][stage] + _flash * 6.0
	if _core_mat != null:
		_core_mat.emission_energy_multiplier = energy
	if core != null:
		core.scale = Vector3.ONE * ([0.9, 1.0, 1.15][stage] + _flash * 0.3)
	if light != null:
		light.light_energy = [0.0, 3.0 + 2.0 * beat, 9.0 + 3.0 * beat][stage] + _flash * 20.0


# 0..1 pulse: a double thump per beat (audio-synced when the drone is playing).
func heartbeat_beat() -> float:
	var period: float = 60.0 / AmbienceLibrary.REACTOR_BPM
	var t: float = _t
	if heartbeat != null and is_instance_valid(heartbeat.player):
		var p: AudioStreamPlayer3D = heartbeat.player as AudioStreamPlayer3D
		if p != null and p.playing:
			t = p.get_playback_position()
	var ph: float = fmod(t, period)
	return clampf(exp(-ph * 6.0) + 0.6 * exp(-maxf(ph - 0.28, 0.0) * 8.0) * float(ph > 0.28), 0.0, 1.0)
