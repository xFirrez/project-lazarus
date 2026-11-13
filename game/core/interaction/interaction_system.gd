# InteractionSystem — per-match interaction flow (ARCHITECTURE §8): request -> validate -> execute.
# LOCAL: each physics tick, finds the best Interactable for the local player (in range, roughly in
# view, available), exposes `focus` / `focus_text` to the HUD and runs the hold; a completed hold
# sends `_interact` to the host (continuous ones repeat while held).
# HOST: validates (player alive and standing, distance, conditions, cost via PointsLedger), pays,
# executes and answers the requester with `_interact_r` [id, ok, reason] (UI + audio feedback).
# Requests are processed one at a time on the host, so simultaneous purchases can't double-spend.
# Authority: host decides; owners only request.
class_name InteractionSystem
extends Node

signal result_received(id: int, ok: bool, reason: String)

const RANGE_SLACK: float = 1.0  # host tolerance for latency

var interactables: Array[Interactable] = []
var players: PlayerSync = null
var ledger: PointsLedger = null
var focus: Interactable = null
var focus_text: String = ""
var hold_progress: float = 0.0  # 0..1 of the current hold
var last_denied: String = ""
var last_denied_time: float = -100.0
var requests_ok: int = 0
var requests_denied: int = 0
var blocked: bool = false  # set by DownedSystem while the local player revives someone

var _holds: Dictionary = {}  # peer -> Hold (local avatar and host bots)


class Hold:
	var time: float = 0.0
	var repeat: float = 0.0
	var sent: bool = false
	var target: Interactable = null


static func is_authority() -> bool:
	return Net.is_host() or not Net.is_active()


func _ready() -> void:
	name = "Interaction"
	process_physics_priority = 90
	Net.register_message(&"_interact", _on_msg_interact)
	Net.register_message(&"_interact_r", _on_msg_result)
	SurvivalAudio.ensure_events()


func _exit_tree() -> void:
	Net.unregister_message(&"_interact")
	Net.unregister_message(&"_interact_r")


func scan(root: Node) -> void:
	for n: Node in root.find_children("*", "", true, false):
		if n is Interactable:
			(n as Interactable).interact_id = interactables.size()
			interactables.append(n as Interactable)


func get_by_id(id: int) -> Interactable:
	return interactables[id] if id >= 0 and id < interactables.size() else null


func find_by_name(node_name: String) -> Interactable:
	for i: Interactable in interactables:
		if i.name == node_name:
			return i
	return null


# Best candidate for a player: in range, available, most centred in view.
func best_for(player: PlayerCharacter, ignore_view: bool = false) -> Interactable:
	var eye: Vector3 = player.global_position + Vector3.UP * player.camera_rig.eye_height
	var fwd: Vector3 = -player.camera_rig.view_basis().z
	var best: Interactable = null
	var best_score: float = -INF
	for i: Interactable in interactables:
		if not i.is_inside_tree() or not i.in_range(player) or not i.is_available(player):
			continue
		var to: Vector3 = i.focus_point() - eye
		var d: float = to.length()
		var dot: float = fwd.dot(to / d) if d > 0.01 else 1.0
		if ignore_view:
			dot = 1.0
		elif dot < 0.2 and d > 1.0:
			continue
		var score: float = dot * 2.0 - d * 0.3
		if score > best_score:
			best_score = score
			best = i
	return best


# --- local flow -----------------------------------------------------------------------------------


func _physics_process(delta: float) -> void:
	var me: PlayerCharacter = players.local_avatar() if players != null else null
	if me == null or me.has_meta(&"survival_bot"):
		return  # a SurvivalBot driving the local avatar runs its own interaction
	tick_player(me, me.last_frame.interact, delta)


# Runs the probe + hold for a locally simulated player (the local avatar or a host bot).
func tick_player(me: PlayerCharacter, holding: bool, delta: float, forced: Interactable = null) -> void:
	var can: bool = not me.health.is_downed and not me.spectating and not (blocked and me.is_local)
	var target: Interactable = (forced if forced != null else best_for(me)) if can else null
	if me.is_local:
		focus = target
		focus_text = target.get_prompt(me) if target != null else ""
	if not _holds.has(me.peer_id):
		_holds[me.peer_id] = Hold.new()
	var h: Hold = _holds[me.peer_id]
	if target == null or not holding or target != h.target:
		h.time = 0.0
		h.sent = false
		h.target = target if holding else null
		if me.is_local:
			hold_progress = 0.0
		if target == null or not holding:
			return
	h.time += delta
	if me.is_local:
		hold_progress = clampf(h.time / maxf(target.hold_time, 0.01), 0.0, 1.0)
	if h.time < target.hold_time:
		return
	if not h.sent:
		h.sent = true
		h.repeat = target.repeat_interval
		request(me, target)
	elif target.continuous:
		h.repeat -= delta
		if h.repeat <= 0.0:
			h.repeat += target.repeat_interval
			request(me, target)


func request(me: PlayerCharacter, target: Interactable) -> void:
	if is_authority():
		host_handle(me.peer_id, target.interact_id)
	else:
		Net.send_reliable(1, &"_interact", [target.interact_id])


# --- host -----------------------------------------------------------------------------------------


func host_handle(peer_id: int, id: int) -> bool:
	var reason: String = _host_validate_and_run(peer_id, id)
	var ok: bool = reason == ""
	if ok:
		requests_ok += 1
	else:
		requests_denied += 1
		Log.info(&"interact", "Peer %d denied on %d: %s" % [peer_id, id, reason])
	if players != null and peer_id == Net.local_id() or not Net.is_active():
		_on_msg_result(1, [id, ok, reason])
	elif players != null and players.avatars.has(peer_id) and (players.avatars[peer_id] as PlayerCharacter).is_bot:
		pass  # host bots have no UI
	else:
		Net.send_reliable(peer_id, &"_interact_r", [id, ok, reason])
	return ok


func _host_validate_and_run(peer_id: int, id: int) -> String:
	var it: Interactable = get_by_id(id)
	if it == null or players == null or not players.avatars.has(peer_id):
		return "invalid"
	var p: PlayerCharacter = players.avatars[peer_id]
	if p.health.is_downed or p.spectating:
		return "unavailable"
	if not it.is_available(p):
		return "unavailable"
	if not it.in_range(p, RANGE_SLACK):
		return "too far"
	var why: String = "Requires power" if it.requires_power and not Power.is_on() else it.host_check(peer_id, p)
	if why != "":
		return why
	var c: int = it.get_cost(p)
	if ledger != null and not ledger.host_try_spend(peer_id, c):
		return "Not enough points"
	if not it.host_execute(peer_id, p):
		if ledger != null and c > 0:
			ledger.host_earn(peer_id, c)  # refund (does not count as earned: corrected below)
			ledger.host_add_stat(peer_id, &"points_earned", -c)
		return "failed"
	return ""


# --- messages -------------------------------------------------------------------------------------


func _on_msg_interact(sender: int, p: Array) -> void:
	if Net.is_host():
		host_handle(sender, int(p[0]))


func _on_msg_result(sender: int, p: Array) -> void:
	if sender != 1:
		return
	var ok: bool = bool(p[1])
	var reason: String = String(p[2])
	var it: Interactable = get_by_id(int(p[0]))
	if ok:
		Audio.play_event(&"purchase" if it != null and it.cost > 0 else &"interact_ok")
	else:
		last_denied = reason
		last_denied_time = Time.get_ticks_msec() / 1000.0
		Audio.play_event(&"purchase_denied")
	result_received.emit(int(p[0]), ok, reason)
