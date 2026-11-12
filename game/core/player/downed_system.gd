# DownedSystem — last stand, revive, bleedout, spectate, respawn and game over (GAME_DESIGN §3.3,
# §13). At 0 HP a player is downed: crawl, last-stand pistol (WeaponSync), -5 % points; teammates
# revive by holding interact for `revive_time` (the bleedout timer pauses meanwhile; the reviver
# can't shoot); after `bleedout_time` the player bleeds out: -10 % points, weapons lost, spectates
# a teammate and respawns at the next round start next to the nearest living teammate with the
# starting loadout. Everyone downed or bled out = game over on all peers (solo down = game over
# until Second Wind exists).
#   host -> all : `_downed` [peer, bleed_left]   `_revived` [peer, reviver]   `_bledout` [peer]
#                 `_respawned` [peer]   `_revive_state` [target, reviver, progress, revive_time]
#                 `_game_over` [round, summary rows]
#   owner -> host: `_revive_req` [target, holding]
#   host -> peer: `_downed_full` [[peer, state, bleed_left]...] on join
# Authority: HOST decides every transition; clients present (HUD, spectate camera, audio).
class_name DownedSystem
extends Node

signal player_downed(peer_id: int)
signal player_revived(peer_id: int, reviver_id: int)
signal player_bled_out(peer_id: int)
signal player_respawned(peer_id: int)
signal game_over(round_reached: int, summary: Array)

enum State { ALIVE, DOWNED, BLED_OUT }

const GAME_OVER_SCREEN_DELAY: float = 3.0
const REVIVE_RANGE_SLACK: float = 0.75

var players: PlayerSync = null
var ledger: PointsLedger = null
var weapons: WeaponSync = null
var interaction: InteractionSystem = null
var states: Dictionary = {}  # peer -> State
var bleed_left: Dictionary = {}  # host: peer -> seconds; clients: extrapolated
var revivers: Dictionary = {}  # target peer -> reviver peer
var revive_progress: Dictionary = {}  # target peer -> seconds held
var is_game_over: bool = false
var show_screen: bool = true  # tests can keep the match running after game over
var revive_candidate: PlayerCharacter = null  # local: downed teammate in revive range
var revives_total: int = 0
var bleedouts_total: int = 0

var _revive_target_sent: int = 0  # local: target peer of the revive request in flight
var _revive_stamp: Dictionary = {}  # clients: target -> [progress at stamp, local time, active]


static func is_authority() -> bool:
	return Net.is_host() or not Net.is_active()


func _ready() -> void:
	name = "Downed"
	process_priority = 200  # after PlayerCharacter so the spectate camera wins
	for m: StringName in [
		&"_downed", &"_revived", &"_bledout", &"_respawned", &"_revive_state", &"_game_over", &"_revive_req"
	]:
		Net.register_message(m, Callable(self, "_on_msg" + String(m)))
	Net.register_message(&"_downed_full", _on_msg_full)
	Net.peer_joined.connect(_on_peer_joined)
	Net.peer_left.connect(_on_peer_left)
	if players != null:
		players.player_downed.connect(_host_on_downed)
		players.avatar_spawned.connect(func(id: int, _a: PlayerCharacter) -> void: states[id] = State.ALIVE)
		for id: int in players.avatars:
			states[id] = State.ALIVE
	SurvivalAudio.ensure_events()


func _exit_tree() -> void:
	for m: StringName in [
		&"_downed",
		&"_revived",
		&"_bledout",
		&"_respawned",
		&"_revive_state",
		&"_game_over",
		&"_revive_req",
		&"_downed_full"
	]:
		Net.unregister_message(m)


func state_of(peer_id: int) -> State:
	return states.get(peer_id, State.ALIVE)


func tuning_of(peer_id: int) -> PlayerTuning:
	var p: PlayerCharacter = players.avatars.get(peer_id, null) if players != null else null
	return p.tuning if p != null else (load(PlayerCharacter.DEFAULT_TUNING) as PlayerTuning)


func alive_count() -> int:
	var n: int = 0
	for id: int in players.avatars:
		if state_of(id) == State.ALIVE:
			n += 1
	return n


# Seconds of revive held on `target` (0 when nobody revives), any peer.
func progress_of(target: int) -> float:
	if is_authority():
		return float(revive_progress.get(target, 0.0))
	var st: Array = _revive_stamp.get(target, [0.0, 0.0, false])
	if not bool(st[2]):
		return 0.0
	return float(st[0]) + (Time.get_ticks_msec() / 1000.0 - float(st[1]))


func revive_time_for(reviver: int) -> float:
	return tuning_of(reviver).revive_time


# --- host -----------------------------------------------------------------------------------------


func _host_on_downed(peer_id: int) -> void:
	if not is_authority() or is_game_over or state_of(peer_id) != State.ALIVE:
		return
	states[peer_id] = State.DOWNED
	bleed_left[peer_id] = tuning_of(peer_id).bleedout_time
	if ledger != null:
		ledger.host_lose_fraction(peer_id, PointsRules.DOWN_PENALTY)
		ledger.host_add_stat(peer_id, &"downs")
	if weapons != null:
		weapons.host_enter_last_stand(peer_id)
	Net.send_reliable(0, &"_downed", [peer_id, bleed_left[peer_id]])
	_present_downed(peer_id, float(bleed_left[peer_id]))
	player_downed.emit(peer_id)
	_host_check_game_over()


# HOST: reviver starts / stops holding interact on target (requests and host bots).
func host_set_reviving(reviver: int, target: int, holding: bool) -> void:
	if not is_authority():
		return
	if not holding:
		if int(revivers.get(target, 0)) == reviver:
			revivers.erase(target)
			revive_progress[target] = 0.0
			_broadcast_revive_state(target)
		return
	if state_of(target) != State.DOWNED or state_of(reviver) != State.ALIVE or reviver == target:
		return
	if revivers.has(target) and int(revivers[target]) != reviver:
		return  # someone else is already reviving
	if not _in_revive_range(reviver, target):
		return
	if not revivers.has(target):
		revivers[target] = reviver
		revive_progress[target] = 0.0
		_broadcast_revive_state(target)


func host_revive(target: int, reviver: int = 0) -> void:
	if not is_authority() or state_of(target) != State.DOWNED:
		return
	var p: PlayerCharacter = players.avatars.get(target, null)
	if p == null:
		return
	states[target] = State.ALIVE
	revivers.erase(target)
	revive_progress.erase(target)
	bleed_left.erase(target)
	p.health.revive(p.tuning.revive_health_fraction)
	players.broadcast_health(target)
	if weapons != null:
		weapons.host_exit_last_stand(target)
	if ledger != null and reviver != 0:
		ledger.host_add_stat(reviver, &"revives")
	revives_total += 1
	Net.send_reliable(0, &"_revived", [target, reviver])
	_present_revived(target, reviver)
	player_revived.emit(target, reviver)


func host_bleed_out(target: int) -> void:
	if not is_authority() or state_of(target) != State.DOWNED:
		return
	states[target] = State.BLED_OUT
	revivers.erase(target)
	revive_progress.erase(target)
	bleed_left.erase(target)
	bleedouts_total += 1
	if ledger != null:
		ledger.host_lose_fraction(target, PointsRules.BLEEDOUT_PENALTY)
	if weapons != null:
		weapons.host_reset_loadout(target)
	Net.send_reliable(0, &"_bledout", [target])
	_present_bled_out(target)
	player_bled_out.emit(target)
	_host_check_game_over()


# HOST: round start — bled-out players come back next to the nearest living teammate.
func host_respawn_bled_out() -> void:
	if not is_authority() or is_game_over:
		return
	for id: int in players.player_ids():
		if state_of(id) != State.BLED_OUT:
			continue
		var p: PlayerCharacter = players.avatars[id]
		var pos: Vector3 = players.spawn_point_for(id)
		var best: float = INF
		for other: int in players.avatars:
			if other != id and state_of(other) == State.ALIVE:
				var o: PlayerCharacter = players.avatars[other]
				var d: float = o.global_position.distance_to(p.global_position)
				if d < best:
					best = d
					pos = o.global_position + Vector3.UP * 0.05
		states[id] = State.ALIVE
		p.health.restore_full()
		players.broadcast_health(id)
		players.host_teleport(id, pos)
		Net.send_reliable(0, &"_respawned", [id])
		_present_respawned(id)
		player_respawned.emit(id)


# HOST (debug `down_me` / tests): forces a player down through the normal damage path.
func host_force_down(peer_id: int) -> void:
	var p: PlayerCharacter = players.avatars.get(peer_id, null)
	if p == null or not is_authority():
		return
	var was_god: bool = p.health.invulnerable
	p.health.invulnerable = false
	players.damage_player(peer_id, p.health.health + 1.0, Vector3.INF, HealthComponent.DamageType.GENERIC)
	p.health.invulnerable = was_god


func _host_check_game_over() -> void:
	if is_game_over or players == null or players.avatars.is_empty():
		return
	if alive_count() > 0:
		return
	is_game_over = true
	var round_reached: int = 1
	var m: Match = Match.current
	if m != null and m.rounds != null:
		round_reached = maxi(m.rounds.current_round, 1)
		m.rounds.host_game_over()
	var rows: Array = ledger.summary() if ledger != null else []
	Log.info(&"downed", "GAME OVER at round %d" % round_reached)
	Net.send_reliable(0, &"_game_over", [round_reached, rows])
	_present_game_over(round_reached, rows)


func _in_revive_range(reviver: int, target: int) -> bool:
	var a: PlayerCharacter = players.avatars.get(reviver, null)
	var b: PlayerCharacter = players.avatars.get(target, null)
	if a == null or b == null:
		return false
	return a.global_position.distance_to(b.global_position) <= a.tuning.revive_radius + REVIVE_RANGE_SLACK


func _broadcast_revive_state(target: int) -> void:
	var r: int = int(revivers.get(target, 0))
	var prog: float = float(revive_progress.get(target, 0.0))
	Net.send_reliable(0, &"_revive_state", [target, r, prog, revive_time_for(r) if r != 0 else 0.0])
	_on_msg_revive_state(1, [target, r, prog, revive_time_for(r) if r != 0 else 0.0])


func _physics_process(delta: float) -> void:
	if players == null:
		return
	_local_revive_input()
	if not is_authority() or is_game_over:
		if not is_authority():
			for id: int in bleed_left:
				if not revivers.has(id):
					bleed_left[id] = maxf(float(bleed_left[id]) - delta, 0.0)
		return
	for id: int in states.keys():
		if state_of(id) != State.DOWNED:
			continue
		if revivers.has(id):
			var r: int = int(revivers[id])
			if state_of(r) != State.ALIVE or not _in_revive_range(r, id):
				revivers.erase(id)
				revive_progress[id] = 0.0
				_broadcast_revive_state(id)
			else:
				revive_progress[id] = float(revive_progress.get(id, 0.0)) + delta
				if float(revive_progress[id]) >= revive_time_for(r):
					host_revive(id, r)
				continue
		bleed_left[id] = float(bleed_left.get(id, 0.0)) - delta
		if float(bleed_left[id]) <= 0.0:
			host_bleed_out(id)


# --- local (owner) --------------------------------------------------------------------------------


func _local_revive_input() -> void:
	var me: PlayerCharacter = players.local_avatar()
	if me == null:
		return
	revive_candidate = null
	if state_of(me.peer_id) == State.ALIVE and not me.health.is_downed:
		var best: float = me.tuning.revive_radius
		for id: int in players.avatars:
			if id != me.peer_id and state_of(id) == State.DOWNED:
				var o: PlayerCharacter = players.avatars[id]
				var d: float = o.global_position.distance_to(me.global_position)
				if d <= best:
					best = d
					revive_candidate = o
	var want: int = revive_candidate.peer_id if revive_candidate != null and me.last_frame.interact else 0
	if want != _revive_target_sent:
		if _revive_target_sent != 0:
			_send_revive(me.peer_id, _revive_target_sent, false)
		if want != 0:
			_send_revive(me.peer_id, want, true)
		_revive_target_sent = want
	me.reviving = want != 0
	if interaction != null:
		interaction.blocked = revive_candidate != null


func _send_revive(me_id: int, target: int, holding: bool) -> void:
	if is_authority():
		host_set_reviving(me_id, target, holding)
	else:
		Net.send_reliable(1, &"_revive_req", [target, holding])


func _process(_delta: float) -> void:
	var me: PlayerCharacter = players.local_avatar() if players != null else null
	if me == null or not me.spectating:
		return
	# Spectate: look through the first living teammate's eyes.
	for id: int in players.player_ids():
		if id != me.peer_id and state_of(id) == State.ALIVE:
			var o: PlayerCharacter = players.avatars[id]
			var eye: Vector3 = o.global_position + Vector3.UP * o.tuning.eye_height_stand
			me.camera.global_transform = Transform3D(Basis.from_euler(Vector3(o.get_pitch(), o.rotation.y, 0.0)), eye)
			return


# --- presentation (every peer) --------------------------------------------------------------------


func _present_downed(peer_id: int, left: float) -> void:
	states[peer_id] = State.DOWNED
	bleed_left[peer_id] = left
	# `_downed` is sent from inside the host's damage call, before the `_player_health` event.
	var p: PlayerCharacter = players.avatars.get(peer_id, null)
	if p != null and not is_authority():
		p.health.health = 0.0
		p.health.is_downed = true
	_play(peer_id, &"player_downed")


func _present_revived(peer_id: int, _reviver: int) -> void:
	states[peer_id] = State.ALIVE
	bleed_left.erase(peer_id)
	revivers.erase(peer_id)
	_revive_stamp.erase(peer_id)
	_play(peer_id, &"player_revived")


func _present_bled_out(peer_id: int) -> void:
	states[peer_id] = State.BLED_OUT
	bleed_left.erase(peer_id)
	revivers.erase(peer_id)
	_revive_stamp.erase(peer_id)
	var p: PlayerCharacter = players.avatars.get(peer_id, null)
	if p != null:
		p.spectating = true
	_play(peer_id, &"player_bledout")


func _present_respawned(peer_id: int) -> void:
	states[peer_id] = State.ALIVE
	var p: PlayerCharacter = players.avatars.get(peer_id, null)
	if p != null:
		p.spectating = false
		if p.is_local:
			p.camera_rig.yaw = p.rotation.y
	_play(peer_id, &"player_respawned")


func _present_game_over(round_reached: int, rows: Array) -> void:
	is_game_over = true
	Audio.play_event(&"game_over")
	game_over.emit(round_reached, rows)
	if not show_screen:
		return
	await get_tree().create_timer(GAME_OVER_SCREEN_DELAY).timeout
	if is_inside_tree() and show_screen:
		Game.show_match_summary(round_reached, rows)


func _play(peer_id: int, event: StringName) -> void:
	var p: PlayerCharacter = players.avatars.get(peer_id, null) if players != null else null
	if p != null and not p.is_local:
		Audio.play_event_3d(event, p.global_position)
	else:
		Audio.play_event(event)


# --- messages -------------------------------------------------------------------------------------


func _on_msg_downed(sender: int, p: Array) -> void:
	if sender == 1 and not Net.is_host():
		_present_downed(int(p[0]), float(p[1]))


func _on_msg_revived(sender: int, p: Array) -> void:
	if sender == 1 and not Net.is_host():
		_present_revived(int(p[0]), int(p[1]))


func _on_msg_bledout(sender: int, p: Array) -> void:
	if sender == 1 and not Net.is_host():
		_present_bled_out(int(p[0]))


func _on_msg_respawned(sender: int, p: Array) -> void:
	if sender == 1 and not Net.is_host():
		_present_respawned(int(p[0]))


func _on_msg_revive_state(sender: int, p: Array) -> void:
	if sender != 1:
		return
	var target: int = int(p[0])
	var r: int = int(p[1])
	if not is_authority():
		if r != 0:
			revivers[target] = r
		else:
			revivers.erase(target)
	_revive_stamp[target] = [float(p[2]), Time.get_ticks_msec() / 1000.0, r != 0]
	if r != 0:
		_play(target, &"revive_start")


func _on_msg_game_over(sender: int, p: Array) -> void:
	if sender == 1 and not Net.is_host():
		_present_game_over(int(p[0]), p[1] as Array)


func _on_msg_revive_req(sender: int, p: Array) -> void:
	if Net.is_host():
		host_set_reviving(sender, int(p[0]), bool(p[1]))


func _on_msg_full(sender: int, p: Array) -> void:
	if sender != 1 or Net.is_host():
		return
	for e: Variant in p[0]:
		var row: Array = e
		var id: int = int(row[0])
		var st: int = int(row[1])
		if st == State.DOWNED:
			_present_downed(id, float(row[2]))
		elif st == State.BLED_OUT:
			_present_bled_out(id)


func _on_peer_joined(peer_id: int, _info: Dictionary) -> void:
	if not Net.is_host() or peer_id == Net.local_id():
		return
	var list: Array = []
	for id: int in states:
		if state_of(id) != State.ALIVE:
			list.append([id, int(state_of(id)), float(bleed_left.get(id, 0.0))])
	Net.send_reliable(peer_id, &"_downed_full", [list])


func _on_peer_left(peer_id: int) -> void:
	states.erase(peer_id)
	bleed_left.erase(peer_id)
	revivers.erase(peer_id)
	for t: int in revivers.keys():
		if int(revivers[t]) == peer_id:
			revivers.erase(t)
			revive_progress[t] = 0.0
	if is_authority():
		_host_check_game_over.call_deferred()
