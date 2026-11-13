# RelaySystem — Resonance Relays (GAME_DESIGN §9.1, VESPER_PEAK §5; DEVELOPMENT_PLAN Step 11A
# scope 1): a "hold, then defend" objective. One ResonanceRelay per MapMarker of kind &"relay"
# (created by `setup` BEFORE the interaction scan; the marker's `zone` is the relay's zone).
# Per relay: hold interact HOLD_TIME (power required) -> CHARGING: progress accumulates while at
# least one standing player is in the relay's zone and pauses otherwise; zombies within
# ATTRACT_RADIUS are drawn toward it (the Drummer Decoy mechanism at a weaker strength: a zombie
# keeps chasing a player who is closer than the relay) -> DONE after DEFEND_TIME. All relays done
# -> MatchSession flag "relays_done" and MapRules.on_relays_complete() (Vesper Peak: the Reactor
# Bridge extends, the Forge wakes, the reactor blazes).
# Shared state = MatchSession flags (late join + state hash for free):
#   "relay.<id>" state 0 idle / 1 charging / 2 done; "relay.<id>.p" defended seconds (0.5 s steps);
#   "relay.<id>.paused" bool; "relays_done" bool.
# Authority: HOST runs progress and pause rules; every peer presents from the flags.
class_name RelaySystem
extends Node

signal relay_changed(index: int, state: int)
signal all_completed

enum State { IDLE, CHARGING, DONE }

const HOLD_TIME: float = 3.0
const DEFEND_TIME: float = 20.0
const ATTRACT_RADIUS: float = 14.0
const PROGRESS_STEP: float = 0.5
const FLAG_DONE: String = "relays_done"

var match_node: Match = null
var relays: Array[ResonanceRelay] = []
var progress: Dictionary = {}  # host: index -> exact defended seconds
var pause_time: Dictionary = {}  # host: index -> seconds spent paused (tests / tuning)

var _attractors: Dictionary = {}  # host: index -> Node3D lure


static func is_authority() -> bool:
	return Net.is_host() or not Net.is_active()


static func flag_state(id: StringName) -> String:
	return "relay.%s" % id


func setup(map_root: Node) -> void:
	name = "Relays"
	ProgressionAudio.ensure()
	var markers: Array[MapMarker] = []
	for n: Node in map_root.find_children("*", "MapMarker", true, false):
		if (n as MapMarker).kind == &"relay":
			markers.append(n as MapMarker)
	markers.sort_custom(func(a: MapMarker, b: MapMarker) -> bool: return String(a.marker_id) < String(b.marker_id))
	for mk: MapMarker in markers:
		mk.show_visual = false
		var r: ResonanceRelay = ResonanceRelay.new()
		r.name = "ResonanceRelay"
		r.system = self
		r.index = relays.size()
		r.relay_id = StringName(String(mk.marker_id).get_slice("_", 0))
		r.zone = mk.zone
		mk.add_child(r)
		relays.append(r)


func _ready() -> void:
	if match_node != null and match_node.session != null:
		match_node.session.flag_changed.connect(_on_flag_changed)


func session() -> MatchSession:
	return match_node.session if match_node != null else null


# --- replicated queries (every peer) ------------------------------------------------------------


func state(index: int) -> int:
	var s: MatchSession = session()
	return int(s.flag(flag_state(relays[index].relay_id), State.IDLE)) if s != null else State.IDLE


func progress_of(index: int) -> float:
	if is_authority() and progress.has(index):
		return float(progress[index])
	var s: MatchSession = session()
	return float(s.flag(flag_state(relays[index].relay_id) + ".p", 0.0)) if s != null else 0.0


func is_paused(index: int) -> bool:
	var s: MatchSession = session()
	return s != null and bool(s.flag(flag_state(relays[index].relay_id) + ".paused", false))


func done_count() -> int:
	var n: int = 0
	for i: int in relays.size():
		if state(i) == State.DONE:
			n += 1
	return n


func all_done() -> bool:
	var s: MatchSession = session()
	return s != null and bool(s.flag(FLAG_DONE, false))


func index_of(relay_id: StringName) -> int:
	for r: ResonanceRelay in relays:
		if r.relay_id == relay_id:
			return r.index
	return -1


# --- host ----------------------------------------------------------------------------------------


func host_check(index: int) -> String:
	if state(index) == State.CHARGING:
		return "Relay is charging"
	if state(index) == State.DONE:
		return "Relay is active"
	return ""


func host_activate(index: int) -> bool:
	if not is_authority() or index < 0 or index >= relays.size() or state(index) != State.IDLE:
		return false
	progress[index] = 0.0
	pause_time[index] = 0.0
	_set_flag(index, "", State.CHARGING)
	_set_flag(index, ".p", 0.0)
	_set_flag(index, ".paused", false)
	_lure(index, true)
	Log.info(&"relays", "Relay %s charging" % relays[index].relay_id)
	return true


# Debug (`relays_complete`) / tests: finish one relay (or all) at once.
func host_complete(index: int) -> void:
	if not is_authority() or state(index) == State.DONE:
		return
	progress[index] = DEFEND_TIME
	_finish(index)


func host_complete_all() -> void:
	for i: int in relays.size():
		host_complete(i)


func _physics_process(delta: float) -> void:
	if not is_authority():
		return
	for i: int in relays.size():
		if state(i) != State.CHARGING:
			continue
		var occupied: bool = zone_occupied(relays[i].zone)
		if is_paused(i) == occupied:
			_set_flag(i, ".paused", not occupied)
			_lure(i, occupied)
		if not occupied:
			pause_time[i] = float(pause_time.get(i, 0.0)) + delta
			continue
		var p: float = float(progress.get(i, 0.0)) + delta
		progress[i] = p
		var q: float = floorf(p / PROGRESS_STEP) * PROGRESS_STEP
		if not is_equal_approx(q, float(session().flag(flag_state(relays[i].relay_id) + ".p", 0.0))):
			_set_flag(i, ".p", q)
		if p >= DEFEND_TIME:
			_finish(i)


# A standing (not downed, not spectating) player is inside the zone.
func zone_occupied(zone: StringName) -> bool:
	if match_node == null or match_node.players == null or match_node.zones == null:
		return false
	for id: int in match_node.players.avatars:
		var p: PlayerCharacter = match_node.players.avatars[id]
		if p.health.is_downed or p.spectating:
			continue
		if match_node.zones.zone_at(p.global_position) == zone:
			return true
	return false


func _finish(index: int) -> void:
	_lure(index, false)
	_set_flag(index, ".p", DEFEND_TIME)
	_set_flag(index, ".paused", false)
	_set_flag(index, "", State.DONE)
	Log.info(&"relays", "Relay %s active (%d / %d)" % [relays[index].relay_id, done_count(), relays.size()])
	if done_count() == relays.size() and not all_done():
		session().host_set_flag(FLAG_DONE, true)
		all_completed.emit()
		if match_node.rules != null:
			match_node.rules.on_relays_complete()


func _set_flag(index: int, suffix: String, value: Variant) -> void:
	session().host_set_flag(flag_state(relays[index].relay_id) + suffix, value)


# Zombie lure while charging and occupied (CrowdDirector attractor, weak: see ZombieSim).
func _lure(index: int, on: bool) -> void:
	if _attractors.has(index):
		var old: Node3D = _attractors[index]
		if is_instance_valid(old):
			old.queue_free()
		_attractors.erase(index)
	var crowd: CrowdDirector = match_node.zombies.crowd if match_node.zombies != null else null
	if not on or crowd == null:
		return
	var lure: Node3D = Node3D.new()
	lure.name = "RelayLure"
	lure.set_meta(&"attract_weak", true)
	relays[index].add_child(lure)
	lure.position = Vector3(0, 0.5, 0)
	crowd.add_attractor(lure, ATTRACT_RADIUS)
	_attractors[index] = lure


func _on_flag_changed(key: String, value: Variant) -> void:
	if not key.begins_with("relay.") or key.count(".") != 1:
		return
	var id: StringName = StringName(key.substr(6))
	var i: int = index_of(id)
	if i >= 0:
		relay_changed.emit(i, int(value))
		relays[i].on_state(int(value))
