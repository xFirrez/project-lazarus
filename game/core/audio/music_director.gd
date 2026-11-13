# MusicDirector — dynamic music by intensity (GAME_DESIGN §16, DEVELOPMENT_PLAN Step 15 scope 6):
# mostly silence / ambience during rounds (classic), with a low drone layer that swells with the
# zombie density around the local player, a heartbeat pulse layer at medium intensity and a
# tremolo-string tension layer when the player is swarmed or downed; special rounds bring in the
# storm layer. The four ScoreAudio loops play phase-locked in one AudioStreamSynchronized on the
# Music bus (so VO ducks it); only their volumes move. Scripted music (the "Snowblind" Easter-egg
# song, the game-over coda) silences the layers while it plays.
# Authority: local presentation on every peer (reads replicated zombies / rounds / downed state).
class_name MusicDirector
extends Node

const SILENT_DB: float = -60.0
const NEAR_RADIUS: float = 22.0
const SWARM_COUNT: float = 14.0  # zombies within NEAR_RADIUS for intensity 1
const SMOOTH: float = 0.6  # intensity follow rate (1/s)
const LAYER_DB: Dictionary = {
	# layer -> [intensity at which it starts, intensity where it is full, full level dB]
	&"drone": [0.0, 0.5, -8.0],
	&"pulse": [0.3, 0.7, -10.0],
	&"tension": [0.6, 1.0, -12.0],
	&"storm": [0.0, 0.0, -9.0],  # special rounds only
}
# Events that override the dynamic layers while they play: event -> seconds.
const OVERRIDES: Dictionary = {&"snowblind": 20.0, &"game_over": 9.0, &"finale_sting": 6.0}

var match_node: Match = null
var intensity: float = 0.0
var target: float = 0.0
var player: AudioStreamPlayer = null
var layer_db: Dictionary = {}  # layer -> current dB (tests / debug)

var _stream: AudioStreamSynchronized = null
var _override_left: float = 0.0
var _sample: float = 0.0


func _ready() -> void:
	name = "Music"
	ScoreAudio.ensure()
	Audio.event_played.connect(_on_event_played)
	Audio.event_registered.connect(func(_e: StringName) -> void: _try_build())
	_try_build()


func _exit_tree() -> void:
	if player != null:
		player.stop()
		player.stream = null


func _try_build() -> void:
	if player != null:
		return
	var streams: Array[AudioStream] = []
	for l: String in ScoreAudio.LAYERS:
		var e: StringName = StringName("music_" + l)
		if not Audio.has_event(e):
			return
		streams.append(Audio.event_stream(e))
	_stream = AudioStreamSynchronized.new()
	_stream.stream_count = streams.size()
	for i: int in streams.size():
		_stream.set_sync_stream(i, streams[i])
		_stream.set_sync_stream_volume(i, SILENT_DB)
	player = AudioStreamPlayer.new()
	player.name = "Layers"
	player.bus = &"Music"
	player.stream = _stream
	add_child(player)
	player.play()


func _on_event_played(e: StringName) -> void:
	if OVERRIDES.has(e):
		_override_left = maxf(_override_left, float(OVERRIDES[e]))


# Intensity 0..1 from the local situation (computed a few times a second).
func compute_target() -> float:
	if match_node == null or match_node.players == null:
		return 0.0
	var rd: RoundDirector = match_node.rounds
	if rd == null or not rd.enabled or rd.phase != RoundDirector.Phase.ACTIVE:
		return 0.0
	var me: PlayerCharacter = match_node.players.local_avatar()
	if me == null:
		return 0.2
	var near: int = 0
	if match_node.zombies != null:
		for id: int in match_node.zombies.actors:
			var z: ZombieActor = match_node.zombies.actors[id]
			if is_instance_valid(z) and z.alive and z.global_position.distance_to(me.global_position) < NEAR_RADIUS:
				near += 1
	var t: float = clampf(near / SWARM_COUNT, 0.0, 1.0)
	if me.health != null and me.health.is_downed:
		t = maxf(t, 0.85)
	elif me.health != null and me.health.max_health > 0.0 and me.health.health / me.health.max_health < 0.35:
		t = maxf(t, 0.7)
	return maxf(t, 0.12)  # an active round always carries a faint drone


func _process(delta: float) -> void:
	if player == null:
		return
	_sample -= delta
	if _sample <= 0.0:
		_sample = 0.25
		target = compute_target()
	intensity = move_toward(intensity, target, SMOOTH * delta * (2.0 if target > intensity else 1.0))
	_override_left = maxf(_override_left - delta, 0.0)
	var special: bool = (
		match_node != null
		and match_node.rounds != null
		and match_node.rounds.special_id != &""
		and match_node.rounds.phase == RoundDirector.Phase.ACTIVE
	)
	for i: int in ScoreAudio.LAYERS.size():
		var l: StringName = StringName(ScoreAudio.LAYERS[i])
		var cfg: Array = LAYER_DB[l]
		var db: float = SILENT_DB
		if l == &"storm":
			db = float(cfg[2]) if special else SILENT_DB
		else:
			var k: float = clampf(inverse_lerp(float(cfg[0]), float(cfg[1]), intensity), 0.0, 1.0)
			if k > 0.0:
				db = lerpf(-36.0, float(cfg[2]), sqrt(k))
		if _override_left > 0.0:
			db = SILENT_DB
		var cur: float = float(layer_db.get(l, SILENT_DB))
		cur = move_toward(cur, db, delta * 18.0)
		layer_db[l] = cur
		_stream.set_sync_stream_volume(i, cur)
