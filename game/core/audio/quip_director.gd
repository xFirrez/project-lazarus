# QuipDirector — the survivors' character quips (GAME_DESIGN §14 / §16, DEVELOPMENT_PLAN Step 15
# scope 6): box results (wonder / good / doll), Vigor Tonics, low ammo, downed, revived, reviving a
# teammate, multi-kills and power-ups, with per-player per-category cooldowns, a global gap and
# priorities (a downed call-out interrupts a box comment, never the reverse). Lines are original
# (`content/characters/quips.json`); each plays the character's recorded take when one is delivered
# (`content/audio/vo/quip_<character>_<category>_<n>.ogg|wav`), otherwise the synthesized voice
# pitched per character, at the speaker (3D), always with a subtitle (Captions).
# Replicated events (box, perks, downed, revive, power-ups) fire on every peer for any survivor;
# local events (low ammo, multi-kills) only for the local survivor.
# Authority: local presentation.
class_name QuipDirector
extends Node

const DATA_PATH: String = "res://content/characters/quips.json"
const GLOBAL_GAP: float = 3.0
const BOX_REVEAL_DELAY: float = 4.6  # the box reveal lands ~4.5 s after the spin starts
const MULTI_KILL_WINDOW: float = 3.0
const MULTI_KILL_COUNT: int = 5
const LOW_AMMO_FRACTION: float = 0.2

var match_node: Match = null
var data: Dictionary = {}
var played: Array = []  # [peer, category, text] (tests)
var enabled: bool = true

var _cooldowns: Dictionary = {}  # "peer:category" -> Net.now() when allowed again
var _busy_until: float = 0.0
var _busy_priority: int = 0
var _last_line: Dictionary = {}  # "char:category" -> index
var _kill_times: Array[float] = []
var _low_ammo_armed: bool = true
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


static func load_data() -> Dictionary:
	var f: FileAccess = FileAccess.open(DATA_PATH, FileAccess.READ)
	if f == null:
		return {}
	var d: Variant = JSON.parse_string(f.get_as_text())
	return d if d is Dictionary else {}


func _ready() -> void:
	name = "Quips"
	data = load_data()
	_rng.randomize()
	QuestAudio.ensure()
	if match_node == null:
		return
	if match_node.box != null:
		match_node.box.spin_started.connect(_on_spin)
	if match_node.perks != null:
		match_node.perks.drink_started.connect(func(peer: int, _p: StringName) -> void: trigger(peer, &"perk", 0.6))
	if match_node.downed != null:
		match_node.downed.player_downed.connect(func(peer: int) -> void: trigger(peer, &"downed"))
		match_node.downed.player_revived.connect(_on_revived)
	if match_node.powerups != null:
		match_node.powerups.picked.connect(
			func(_id: int, _t: StringName, peer: int) -> void:
				if _rng.randf() < 0.45:
					trigger(peer, &"powerup", 1.8)
		)
	if match_node.players != null:
		match_node.players.avatar_spawned.connect(_on_avatar)
		for id: int in match_node.players.avatars:
			_on_avatar(id, match_node.players.avatars[id])


func _on_avatar(_peer: int, a: PlayerCharacter) -> void:
	if a != null and a.is_local and a.weapons != null and not a.weapons.hit_confirmed.is_connected(_on_hit):
		a.weapons.hit_confirmed.connect(_on_hit)


func _on_spin(_loc: int, spinner: int, result: StringName) -> void:
	var cat: StringName = &"box_good"
	if result == RelicBoxRoller.DOLL:
		cat = &"box_bad"
	elif match_node.box.pool != null and match_node.box.pool.wonder_ids.has(result):
		cat = &"box_wonder"
	elif _rng.randf() > 0.5:
		return
	trigger(spinner, cat, BOX_REVEAL_DELAY)


func _on_revived(target: int, reviver: int) -> void:
	trigger(target, &"revived", 0.4)
	if reviver > 0 and reviver != target:
		trigger(reviver, &"revive_given", 2.2)


func _on_hit(_t: HitTarget, _dmg: float, _zone: int, kill: bool) -> void:
	if not kill:
		return
	var now: float = Net.now()
	_kill_times.append(now)
	_kill_times = _kill_times.filter(func(t: float) -> bool: return now - t <= MULTI_KILL_WINDOW)
	if _kill_times.size() >= MULTI_KILL_COUNT:
		_kill_times.clear()
		trigger(_local_peer(), &"multi_kill")


func _local_peer() -> int:
	return Net.local_id() if Net.is_active() else 1


func _process(_delta: float) -> void:
	# Low ammo (local): total ammo under 20 % of a magazine with nothing in reserve, once per dip.
	var me: PlayerCharacter = (
		match_node.players.local_avatar() if match_node != null and match_node.players != null else null
	)
	if me == null or me.weapons == null:
		return
	var rt: WeaponRuntime = me.weapons.held()
	if rt == null or rt.def == null or rt.def.mag_size <= 1:
		return
	var low: bool = rt.reserve == 0 and float(rt.mag) <= float(rt.def.mag_size) * LOW_AMMO_FRACTION
	if low and _low_ammo_armed:
		_low_ammo_armed = false
		trigger(me.peer_id, &"low_ammo")
	elif not low:
		_low_ammo_armed = true


# Requests a quip for `peer`'s survivor in `category` (after `delay` s). Returns false if gated.
func trigger(peer: int, category: StringName, delay: float = 0.0) -> bool:
	if not enabled or data.is_empty():
		return false
	var cats: Dictionary = data.get("categories", {})
	if not cats.has(String(category)):
		return false
	var key: String = "%d:%s" % [peer, category]
	var now: float = Net.now()
	if now < float(_cooldowns.get(key, 0.0)):
		return false
	_cooldowns[key] = now + float((cats[String(category)] as Dictionary).get("cooldown", 30))
	if delay > 0.0:
		get_tree().create_timer(delay).timeout.connect(_speak.bind(peer, category))
	else:
		_speak(peer, category)
	return true


func _speak(peer: int, category: StringName) -> void:
	if not is_inside_tree() or match_node == null or match_node.players == null:
		return
	var p: PlayerCharacter = match_node.players.avatars.get(peer, null)
	if p == null or p.character == null:
		return
	var prio: int = int((data["categories"][String(category)] as Dictionary).get("priority", 1))
	var now: float = Net.now()
	if now < _busy_until and prio <= _busy_priority:
		return
	var cid: String = String(p.character.id)
	var pool: Array = (data.get("lines", {}).get(cid, {}) as Dictionary).get(String(category), [])
	if pool.is_empty():
		return
	var key: String = "%s:%s" % [cid, category]
	var idx: int = _rng.randi() % pool.size()
	if pool.size() > 1 and idx == int(_last_line.get(key, -1)):
		idx = (idx + 1) % pool.size()
	_last_line[key] = idx
	var text: String = String(pool[idx])
	var seconds: float = clampf(0.9 + text.length() * 0.055, 1.4, 4.5)
	_busy_until = now + maxf(seconds, GLOBAL_GAP)
	_busy_priority = prio
	var pitch: float = float((data.get("pitch", {}) as Dictionary).get(cid, 1.0))
	var rec: AudioStream = _recorded(cid, category, idx)
	if rec != null:
		var ev: StringName = StringName("quip_%s_%s_%d" % [cid, category, idx])
		Audio.register_event(ev, rec, &"VO", 0.0)
		Audio.play_event_3d(ev, p.global_position + Vector3.UP * 1.6)
	else:
		Audio.play_event_3d(&"vo_voice", p.global_position + Vector3.UP * 1.6, pitch)
	if match_node.captions != null:
		match_node.captions.push(p.character.display_name, text, p.character.color, seconds)
	played.append([peer, category, text])


static func _recorded(cid: String, category: StringName, idx: int) -> AudioStream:
	for ext: String in ["ogg", "wav"]:
		var path: String = "res://content/audio/vo/quip_%s_%s_%d.%s" % [cid, category, idx, ext]
		if ResourceLoader.exists(path):
			return load(path) as AudioStream
	return null
