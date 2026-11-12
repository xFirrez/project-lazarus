# RelicBoxSystem — the Relic Box (GAME_DESIGN §10, DEVELOPMENT_PLAN Step 9 scope 6-7). One RelicBox
# per map MapMarker of kind &"box" (sorted by marker id, identical on every peer); the HOST runs the
# state machine and every peer derives the presentation from replicated data:
#   MatchSession flags (ride late join + the state hash):
#     "box_location"   marker id of the current location
#     "box_arrive_at"  host time the box (re)appears there (doll relocation: +move_time)
#     "fire_sale_until" host time a Fire Sale ends (all locations active, cost 10, no doll)
#   host -> all : `_box_spin` [loc, spinner, result_id, seed, start_host_time]
#   host -> all : `_box_end`  [loc]  (weapon taken / offer expired / doll relocation done)
#   host -> joiner: `_box_full` [[loc, spinner, result, seed, start]...]
# A spin's phase is a pure function of (host time - start): SPINNING for spin_time (seeded carousel,
# decelerating, ends on the true result on every peer), then OFFER (offer_time, only the spinner can
# take it) or, for the doll, LEAVING (refund, lid slam, box rises; move_time later it appears at a
# different random location).
# Authority: HOST rolls and validates; clients display.
class_name RelicBoxSystem
extends Node

signal spin_started(loc: int, spinner: int, result: StringName)
signal spin_ended(loc: int)
signal moved(from_loc: int, to_loc: int)

enum Phase { IDLE, SPINNING, OFFER, LEAVING }

const DEFAULT_POOL: String = "res://content/box/relic_box_pool.tres"
const FLAG_LOCATION: String = "box_location"
const FLAG_ARRIVE: String = "box_arrive_at"
const FLAG_FIRE_SALE: String = "fire_sale_until"

var match_node: Match = null
var pool: RelicBoxPool = null
var boxes: Array[RelicBox] = []
var spins: Dictionary = {}  # loc -> [spinner, result, seed, start, paid]
var spins_here: int = 0  # host: spins at the current location since it arrived
var bad_luck: Dictionary = {}  # host: peer -> wonder bonus weight
var forced: StringName = &""  # host debug: next result (box_force)
var total_spins: int = 0
var total_dolls: int = 0

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _start_index: int = 0


static func is_authority() -> bool:
	return Net.is_host() or not Net.is_active()


# Called by Match.setup BEFORE InteractionSystem.scan (the boxes are interactables).
func setup(def: MapDefinition, map_root: Node) -> void:
	name = "Box"
	pool = def.box_pool if def.box_pool != null else load(DEFAULT_POOL) as RelicBoxPool
	var markers: Array[MapMarker] = []
	for n: Node in map_root.find_children("*", "MapMarker", true, false):
		var mk: MapMarker = n as MapMarker
		if mk.kind == &"box":
			markers.append(mk)
	markers.sort_custom(func(a: MapMarker, b: MapMarker) -> bool: return String(a.marker_id) < String(b.marker_id))
	for i: int in markers.size():
		var mk: MapMarker = markers[i]
		mk.show_visual = false
		var b: RelicBox = RelicBox.new()
		b.name = "RelicBox"
		b.system = self
		b.index = i
		b.location_id = mk.marker_id
		mk.add_child(b)
		boxes.append(b)
		if mk.marker_id == def.box_start:
			_start_index = i


func _ready() -> void:
	_rng.randomize()
	Net.register_message(&"_box_spin", _on_msg_spin)
	Net.register_message(&"_box_end", _on_msg_end)
	Net.register_message(&"_box_full", _on_msg_full)
	Net.peer_joined.connect(_on_peer_joined)
	if is_authority() and not boxes.is_empty() and session() != null and session().flag(FLAG_LOCATION) == null:
		session().host_set_flag(FLAG_LOCATION, String(boxes[_start_index].location_id))
		session().host_set_flag(FLAG_ARRIVE, 0.0)


func _exit_tree() -> void:
	for msg: StringName in [&"_box_spin", &"_box_end", &"_box_full"]:
		Net.unregister_message(msg)


func session() -> MatchSession:
	return match_node.session if match_node != null else null


func now() -> float:
	return Net.host_time()


# --- replicated state queries (every peer) ------------------------------------------------------


func current_index() -> int:
	var s: MatchSession = session()
	var id: String = String(s.flag(FLAG_LOCATION, "")) if s != null else ""
	for b: RelicBox in boxes:
		if String(b.location_id) == id:
			return b.index
	return _start_index if not boxes.is_empty() else -1


func arrive_at() -> float:
	var s: MatchSession = session()
	return float(s.flag(FLAG_ARRIVE, 0.0)) if s != null else 0.0


func fire_sale_active() -> bool:
	var s: MatchSession = session()
	return s != null and float(s.flag(FLAG_FIRE_SALE, -1.0)) > now()


func cost() -> int:
	return pool.fire_sale_cost if fire_sale_active() else pool.cost


# The box at `loc` stands there and can be used (or is busy with a spin).
func is_present(loc: int) -> bool:
	if spins.has(loc):
		return true
	if fire_sale_active():
		return true
	return loc == current_index() and now() >= arrive_at()


func phase(loc: int) -> Phase:
	if not spins.has(loc):
		return Phase.IDLE
	var s: Array = spins[loc]
	var t: float = now() - float(s[3])
	if t < pool.spin_time:
		return Phase.SPINNING
	if StringName(s[1]) == RelicBoxRoller.DOLL:
		return Phase.LEAVING
	return Phase.OFFER


func spin_of(loc: int) -> Array:
	return spins.get(loc, [])


# The item shown by the carousel `t` seconds into a spin: a seeded, decelerating sequence over all
# pool items that exist (identical on every peer), landing on `result` at spin_time.
func carousel_item(loc: int, t: float) -> StringName:
	var s: Array = spin_of(loc)
	if s.is_empty():
		return &""
	if t >= pool.spin_time:
		return StringName(s[1])
	var items: Array[StringName] = display_items()
	if items.is_empty():
		return StringName(s[1])
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int(s[2])
	var at: float = 0.0
	var shown: StringName = items[rng.randi() % items.size()]
	while true:
		var u: float = at / pool.spin_time
		at += lerpf(0.06, 0.55, u * u)  # decelerating swaps
		if at > t:
			break
		shown = items[rng.randi() % items.size()]
	return shown


func display_items() -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in pool.item_ids:
		if WeaponCatalog.get_def(id) != null:
			out.append(id)
	return out


# --- host API -----------------------------------------------------------------------------------


func host_check(loc: int, peer_id: int) -> String:
	if not is_present(loc):
		return "No box here"
	match phase(loc):
		Phase.IDLE:
			return ""
		Phase.OFFER:
			return "" if int(spin_of(loc)[0]) == peer_id else "Not your weapon"
	return "Busy"


func host_use(loc: int, peer_id: int, paid: int) -> bool:
	if not is_authority():
		return false
	match phase(loc):
		Phase.IDLE:
			return host_spin(loc, peer_id, paid)
		Phase.OFFER:
			return host_take(loc, peer_id)
	return false


func host_spin(loc: int, peer_id: int, paid: int = 0) -> bool:
	if spins.has(loc) or not is_present(loc):
		return false
	var fire_sale: bool = fire_sale_active()
	var elig: Array = eligible_for(peer_id)
	var can_move: bool = not fire_sale and boxes.size() > 1 and loc == current_index()
	var result: StringName = RelicBoxRoller.roll(_rng, pool, elig, spins_here, fire_sale, can_move)
	if forced != &"":
		result = forced
		forced = &""
	if result == &"":
		return false  # nothing eligible: refund
	if loc == current_index():
		spins_here += 1
	total_spins += 1
	if result == RelicBoxRoller.DOLL:
		total_dolls += 1
	elif pool.wonder_ids.has(result):
		bad_luck[peer_id] = 0.0
	else:
		bad_luck[peer_id] = float(bad_luck.get(peer_id, 0.0)) + pool.bad_luck_step
	var payload: Array = [loc, peer_id, String(result), _rng.randi(), now()]
	spins[loc] = [peer_id, result, int(payload[3]), float(payload[4]), paid]
	Net.send_reliable(0, &"_box_spin", payload)
	spin_started.emit(loc, peer_id, result)
	return true


func host_take(loc: int, peer_id: int) -> bool:
	if phase(loc) != Phase.OFFER or int(spin_of(loc)[0]) != peer_id:
		return false
	var result: StringName = StringName(spin_of(loc)[1])
	var ws: WeaponSync = match_node.weapons if match_node != null else null
	if ws == null or not ws.host_give(peer_id, result):
		return false
	_host_end(loc)
	return true


# Eligible [ids, weights] for a player (not owned, condition met, defined), with bad-luck bonus.
func eligible_for(peer_id: int) -> Array:
	var ws: WeaponSync = match_node.weapons if match_node != null else null
	var s: MatchSession = session()
	return RelicBoxRoller.eligible(
		pool,
		func(id: StringName) -> bool: return ws != null and ws.host_owns(peer_id, id),
		func(flag: String) -> bool: return s != null and bool(s.flag(flag, false)),
		func(id: StringName) -> bool: return WeaponCatalog.get_def(id) != null,
		float(bad_luck.get(peer_id, 0.0))
	)


# Fire Sale (GAME_DESIGN §10.4; the power-up arrives in Step 10): every location active.
func activate_all_locations(duration: float) -> void:
	if is_authority() and session() != null:
		session().host_set_flag(FLAG_FIRE_SALE, now() + duration)


# Debug / relocation: move the box to `to` (index) right away (or after `delay`).
func host_move_to(to: int, delay: float = 0.0) -> void:
	if not is_authority() or to < 0 or to >= boxes.size():
		return
	var from: int = current_index()
	spins_here = 0
	session().host_set_flag(FLAG_LOCATION, String(boxes[to].location_id))
	session().host_set_flag(FLAG_ARRIVE, now() + delay)
	moved.emit(from, to)


func index_of(location_id: StringName) -> int:
	for b: RelicBox in boxes:
		if b.location_id == location_id or String(b.location_id).ends_with(String(location_id)):
			return b.index
	return -1


func _process(_delta: float) -> void:
	if not is_authority() or spins.is_empty():
		return
	for loc: int in spins.keys():
		var s: Array = spins[loc]
		var t: float = now() - float(s[3])
		if StringName(s[1]) == RelicBoxRoller.DOLL:
			if t >= pool.spin_time and s.size() < 6:
				s.append(true)  # doll resolved once: refund + relocation
				if match_node != null and match_node.points != null and int(s[4]) > 0:
					match_node.points.host_earn(int(s[0]), int(s[4]))  # a refund, not "earned"
					match_node.points.host_add_stat(int(s[0]), &"points_earned", -int(s[4]))
				var to: int = RelicBoxRoller.next_location(_rng, boxes.size(), loc)
				host_move_to(to, pool.move_time)
			if t >= pool.spin_time + pool.move_time:
				_host_end(loc)
		elif t >= pool.spin_time + pool.offer_time:
			_host_end(loc)


func _host_end(loc: int) -> void:
	spins.erase(loc)
	Net.send_reliable(0, &"_box_end", [loc])
	spin_ended.emit(loc)


# --- messages -----------------------------------------------------------------------------------


func _on_msg_spin(sender: int, p: Array) -> void:
	if sender != 1 or Net.is_host():
		return
	spins[int(p[0])] = [int(p[1]), StringName(p[2]), int(p[3]), float(p[4]), 0]
	spin_started.emit(int(p[0]), int(p[1]), StringName(p[2]))


func _on_msg_end(sender: int, p: Array) -> void:
	if sender != 1 or Net.is_host():
		return
	spins.erase(int(p[0]))
	spin_ended.emit(int(p[0]))


func _on_msg_full(sender: int, p: Array) -> void:
	if sender != 1 or Net.is_host():
		return
	for e: Variant in p:
		_on_msg_spin(1, e as Array)


func _on_peer_joined(peer_id: int, _info: Dictionary) -> void:
	if not Net.is_host() or peer_id == Net.local_id() or spins.is_empty():
		return
	var full: Array = []
	for loc: int in spins:
		var s: Array = spins[loc]
		full.append([loc, int(s[0]), String(s[1]), int(s[2]), float(s[3])])
	Net.send_reliable(peer_id, &"_box_full", full)
