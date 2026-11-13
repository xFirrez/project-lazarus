# RoundDirector — the round state machine (ARCHITECTURE §7.3, GAME_DESIGN §2, §5.2):
# INTRO (5 s sting) -> ACTIVE (round r: N(r, p) zombies at hp(r)) -> INTERMISSION (10 s) -> ...
# A round ends only when every zombie of it is dead. Zombies re-queued by the brain (stuck / far)
# are pushed back into the spawn queue and still count. The last zombies are promoted to Run when
# slower (unless a crawler is left). GAME_OVER stops everything.
# Special rounds (Step 12, GAME_DESIGN §5.3): MapRules.get_special_round_enemy(r) names the enemy
# (Vesper Peak: Galvanics on the seeded schedule); such a round spawns only that archetype
# (RoundCurve.special_count / special_health), through energy rifts (SpawnDirector), after a longer
# intermission with the warning build-up (SpecialRoundDirector), and its last kill drops Max Ammo.
# MapRules.get_mixed_enemy(r) mixes 1-2 of them into normal rounds (from round 20).
#   host -> all : `_round` [round, phase, time_left, total, special, next_special]
#                 (on every phase change; join snapshot)
# Authority: HOST runs the machine; clients mirror round / phase / countdown and play the stings.
class_name RoundDirector
extends Node

signal round_started(round_number: int)
signal round_ended(round_number: int)
signal intermission_started(next_round: int, seconds: float)
signal phase_changed(phase: int)
signal special_last_killed(actor: ZombieActor)  # host: the last special enemy of a special round died

enum Phase { WAITING, INTRO, ACTIVE, INTERMISSION, GAME_OVER }

const PHASE_NAMES: PackedStringArray = ["waiting", "intro", "active", "intermission", "game_over"]

var curve: RoundCurve = null
var zombies: ZombieSync = null
var players: PlayerSync = null
var archetype: ZombieArchetype = null
var enabled: bool = false
var current_round: int = 0
var phase: Phase = Phase.WAITING
var time_left: float = 0.0
var total: int = 0
var killed: int = 0
var queue: Array[int] = []  # tiers waiting to spawn this round (host)
var round_ids: Dictionary = {}  # host: net id -> true for this round's alive zombies
var requeued: int = 0
var promoted: bool = false
var events: Array[String] = []  # host: ordered event log (tests, AC-6.2)
# Host: stay in WAITING until MatchSession reports every peer's scene ready (lobby start).
var hold: bool = false
var first_round: int = 1  # dev lobby setting "starting round"
var paused: bool = false  # host debug (`round_pause`): intro / intermission timers stop
# Special enemies (replicated through `_round`): this round's / the next round's enemy id.
var special_id: StringName = &""
var next_special: StringName = &""
var special_archetype: ZombieArchetype = null  # host
var special_left: int = 0  # host: special enemies still to spawn this round
var special_pending: int = 0  # host: taken by the SpawnDirector, rift still crackling
var special_ids: Dictionary = {}  # host: alive special enemies of this round
var special_health_value: float = 400.0  # host
var special_rounds_played: int = 0  # host: k for the special count / health growth
var forced_special: StringName = &""  # host debug `special_round`: the next round is special
var special_log: Array[int] = []  # host: rounds that were special (tests, AC-12.4)
# Host: a scripted event (the Easter-egg finale) holds the active round: no normal spawns, no end.
var event_hold: bool = false

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


static func is_authority() -> bool:
	return Net.is_host() or not Net.is_active()


func _ready() -> void:
	name = "Rounds"
	_rng.randomize()
	Net.register_message(&"_round", _on_msg_round)
	Net.peer_joined.connect(_on_peer_joined)
	SurvivalAudio.ensure_events()
	if zombies != null and is_authority():
		zombies.zombie_died.connect(_on_zombie_died)
		zombies.zombie_requeued.connect(_on_zombie_requeued)
		archetype = zombies.archetype(&"zombie")
	if enabled and is_authority() and not hold:
		host_release()


# HOST: everyone is in the map -> intro, then round `first_round`.
func host_release() -> void:
	hold = false
	if not enabled or not is_authority() or phase != Phase.WAITING:
		return
	current_round = maxi(first_round, 1) - 1
	_set_phase(Phase.INTRO, curve.intro_delay)


func _exit_tree() -> void:
	Net.unregister_message(&"_round")


func phase_name() -> String:
	return PHASE_NAMES[phase]


func remaining() -> int:
	return maxi(total - killed, 0)


func player_count() -> int:
	return maxi(players.avatars.size() if players != null else 1, 1)


func zombie_health() -> float:
	return archetype.health_for_round(maxi(current_round, 1)) if archetype != null else 150.0


# --- host -------------------------------------------------------------------------------------


func host_start_round(r: int) -> void:
	if not is_authority() or phase == Phase.GAME_OVER:
		return
	_clear_round_zombies()
	current_round = maxi(r, 1)
	total = curve.zombie_count(current_round, player_count())
	killed = 0
	requeued = 0
	promoted = false
	queue.clear()
	special_ids.clear()
	special_left = 0
	special_pending = 0
	special_id = _special_for(current_round)
	forced_special = &""
	special_archetype = zombies.archetype(special_id) if special_id != &"" and zombies != null else null
	if special_archetype != null and special_archetype.id != special_id:
		special_archetype = null
	if special_archetype != null:
		total = curve.special_count(special_rounds_played, player_count())
		special_left = total
		special_health_value = curve.special_health(special_rounds_played, zombie_health())
		special_rounds_played += 1
		special_log.append(current_round)
	else:
		special_id = &""
		for i: int in total:
			queue.append(curve.pick_tier(current_round, _rng.randf()))
		_add_mixed()
	next_special = &""
	_log("round_start %d total %d%s" % [current_round, total, " special %s" % special_id if special_id != &"" else ""])
	_set_phase(Phase.ACTIVE, 0.0)
	round_started.emit(current_round)
	_on_round_started_host()


func _special_for(r: int) -> StringName:
	if forced_special != &"":
		return forced_special
	var m: Match = Match.current
	return m.rules.get_special_round_enemy(r) if m != null and m.rules != null else &""


# Normal rounds from RoundCurve.mixed_from_round: 1-2 special enemies join the queue (MapRules).
func _add_mixed() -> void:
	var m: Match = Match.current
	if m == null or m.rules == null or zombies == null:
		return
	var mid: StringName = m.rules.get_mixed_enemy(current_round)
	var arch: ZombieArchetype = zombies.archetype(mid) if mid != &"" else null
	if arch == null or arch.id != mid or current_round < curve.mixed_from_round:
		return
	special_archetype = arch
	special_left = _rng.randi_range(curve.mixed_min, curve.mixed_max)
	special_health_value = curve.special_health(maxi(special_rounds_played - 1, 0), zombie_health())
	total += special_left
	_log("mixed %s x%d" % [mid, special_left])


func is_special_round() -> bool:
	return special_id != &""


# HOST: the next special enemy to spawn (SpawnDirector), or null.
func host_take_special() -> ZombieArchetype:
	if special_left <= 0 or special_archetype == null:
		return null
	special_left -= 1
	special_pending += 1
	return special_archetype


func host_register_special(a: ZombieActor) -> void:
	special_pending = maxi(special_pending - 1, 0)
	round_ids[a.net_id] = true
	special_ids[a.net_id] = true


# A rift's spawn failed (or the round was cleared): the enemy goes back to the queue.
func host_return_special() -> void:
	special_pending = maxi(special_pending - 1, 0)
	special_left += 1


# Debug `special_round [enemy]`: the next round is a special round (starts it now when active).
func host_force_special(enemy: StringName = &"galvanic") -> void:
	if not is_authority():
		return
	forced_special = enemy
	next_special = enemy
	if phase == Phase.ACTIVE:
		host_skip_round()
	elif phase == Phase.INTERMISSION:
		time_left = minf(time_left, curve.special_warning + 0.5)
		Net.send_reliable(0, &"_round", _payload())


# Debug `skip_round`: kills this round's zombies and ends it.
func host_skip_round() -> void:
	if not is_authority():
		return
	if phase != Phase.ACTIVE:
		host_start_round(current_round + 1)
		return
	queue.clear()
	special_left = 0
	special_pending = 0
	for id: int in round_ids.keys():
		var a: ZombieActor = zombies.actors.get(id, null)
		if a != null:
			zombies.host_kill(a)
	killed = total
	round_ids.clear()
	_check_end()


# Next queued tier for the SpawnDirector (-1 = nothing to spawn).
func host_take_next() -> int:
	if queue.is_empty():
		return -1
	var t: int = queue.pop_front()
	return t


func host_register_spawn(a: ZombieActor) -> void:
	round_ids[a.net_id] = true


func host_game_over() -> void:
	if not is_authority():
		return
	queue.clear()
	_log("game_over %d" % current_round)
	_set_phase(Phase.GAME_OVER, 0.0)


func _clear_round_zombies() -> void:
	for id: int in round_ids.keys():
		var a: ZombieActor = zombies.actors.get(id, null) if zombies != null else null
		if a != null:
			zombies.host_despawn(a)
	round_ids.clear()


func _on_round_started_host() -> void:
	var m: Match = Match.current
	if m == null:
		return
	if m.points != null:
		m.points.host_new_round()
	if m.downed != null:
		m.downed.host_respawn_bled_out()
	if m.weapons != null and current_round > 1:
		for id: int in m.players.avatars:
			m.weapons.host_add_lethal(id, 2)
	if m.rules != null:
		m.rules.on_round_start(current_round)


func _on_zombie_died(a: ZombieActor, _source: int) -> void:
	if not round_ids.has(a.net_id):
		return
	round_ids.erase(a.net_id)
	killed += 1
	var last: bool = special_left == 0 and special_pending == 0
	if special_ids.erase(a.net_id) and is_special_round() and last and special_ids.is_empty():
		special_last_killed.emit(a)
	_check_end()


func _on_zombie_requeued(_arch: ZombieArchetype, tier: int, reason: String, net_id: int) -> void:
	if not round_ids.has(net_id):
		return
	round_ids.erase(net_id)
	requeued += 1
	if special_ids.erase(net_id):
		special_left += 1  # comes back through a rift
	else:
		queue.push_front(tier)
	_log("requeue %s" % reason)


func _check_end() -> void:
	if event_hold:
		return
	if phase != Phase.ACTIVE or killed < total or not queue.is_empty() or not round_ids.is_empty():
		return
	if special_left > 0 or special_pending > 0:
		return
	_log("round_end %d" % current_round)
	round_ended.emit(current_round)
	var m: Match = Match.current
	if m != null and m.rules != null:
		m.rules.on_round_end(current_round)
	next_special = _special_for(current_round + 1)
	var pause: float = curve.special_intermission if next_special != &"" else curve.intermission
	special_id = &""
	_set_phase(Phase.INTERMISSION, pause)
	_log("intermission %d%s" % [current_round + 1, " special warning" if next_special != &"" else ""])
	intermission_started.emit(current_round + 1, pause)


func _promote_last() -> void:
	if promoted or not queue.is_empty() or remaining() > curve.last_zombies_promoted or round_ids.is_empty():
		return
	promoted = true
	var list: Array[ZombieActor] = []
	for id: int in round_ids:
		var a: ZombieActor = zombies.actors.get(id, null)
		if a == null:
			continue
		if a.is_crawler():
			return  # the player left a crawler on purpose (GAME_DESIGN §5.1)
		list.append(a)
	for a: ZombieActor in list:
		if a.tier < ZombieArchetype.Tier.RUN and a.sim != null:
			a.tier = ZombieArchetype.Tier.RUN
			a.sim.move_speed = a.archetype.speed_for(ZombieArchetype.Tier.RUN)
	_log("promoted %d" % list.size())


func _physics_process(delta: float) -> void:
	if not is_authority():
		time_left = maxf(time_left - delta, 0.0)
		return
	if paused:
		return
	match phase:
		Phase.INTRO, Phase.INTERMISSION:
			time_left -= delta
			if time_left <= 0.0:
				host_start_round(current_round + 1)
		Phase.ACTIVE:
			_promote_last()


func _set_phase(p: Phase, seconds: float) -> void:
	phase = p
	time_left = seconds
	Net.send_reliable(0, &"_round", _payload())
	phase_changed.emit(int(phase))
	_play_sting(p)


func _payload() -> Array:
	return [current_round, int(phase), time_left, total, String(special_id), String(next_special)]


func _play_sting(p: Phase) -> void:
	if p == Phase.ACTIVE and special_id != &"":
		Audio.play_event(&"special_round_start")
		Announcer.say(&"ann_special")
	elif p == Phase.ACTIVE:
		Audio.play_event(&"round_start")
		if current_round == 1:
			Announcer.say(&"ann_round_one", 4.0)
	elif p == Phase.INTERMISSION:
		Audio.play_event(&"round_end")
	elif p == Phase.INTRO:
		Audio.play_event(&"match_intro")


func _log(text: String) -> void:
	events.append(text)
	Log.info(&"rounds", text)


# --- messages -------------------------------------------------------------------------------------


func _on_msg_round(sender: int, p: Array) -> void:
	if sender != 1 or Net.is_host():
		return
	var prev_round: int = current_round
	var prev_phase: Phase = phase
	current_round = int(p[0])
	phase = int(p[1]) as Phase
	time_left = float(p[2])
	total = int(p[3])
	special_id = StringName(p[4]) if p.size() > 4 else &""
	next_special = StringName(p[5]) if p.size() > 5 else &""
	if phase != prev_phase:
		phase_changed.emit(int(phase))
		_play_sting(phase)
	if phase == Phase.ACTIVE and (current_round != prev_round or prev_phase != Phase.ACTIVE):
		round_started.emit(current_round)
	elif phase == Phase.INTERMISSION and prev_phase == Phase.ACTIVE:
		round_ended.emit(current_round)
		intermission_started.emit(current_round + 1, time_left)


func _on_peer_joined(peer_id: int, _info: Dictionary) -> void:
	if not Net.is_host() or peer_id == Net.local_id():
		return
	Net.send_reliable(peer_id, &"_round", _payload())
