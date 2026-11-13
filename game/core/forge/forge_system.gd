# ForgeSystem — the Lazarus Forge (GAME_DESIGN §9, DEVELOPMENT_PLAN Step 11A scope 2). One
# LazarusForge interactable per MapMarker of kind &"forge" (created by `setup` BEFORE the interaction
# scan, tree order). The HOST runs one job at a time per forge:
#   insert (5000, or free with a pending Free Upgrade token; Fire Sale never applies) -> the held
#   weapon leaves the loadout -> FORGING for `FORGE_TIME` (arcs, hammering, green-to-gold flash) ->
#   OFFER for `OFFER_TIME`: the upgraded weapon floats and only its owner can take it -> taken, or
#   lost when the offer runs out (classic).
# The forge is dormant until the map unlocks it (MatchSession flag "forge_unlocked"; Vesper Peak:
# all three Resonance Relays). Job phase is a pure function of (host time - start), like the box.
#   host -> all  : `_forge_start` [forge, peer, base_id, up_id, start_host_time]
#   host -> all  : `_forge_end`   [forge, taken]
#   host -> joiner: `_forge_full` [[forge, peer, base_id, up_id, start]...]
# Authority: HOST validates and transfers weapons; every peer presents from the replicated job.
class_name ForgeSystem
extends Node

signal job_started(forge: int, peer_id: int, up_id: StringName)
signal job_ended(forge: int, taken: bool)

enum Phase { IDLE, FORGING, OFFER }

const COST: int = 5000
const FORGE_TIME: float = 5.0
const OFFER_TIME: float = 15.0
const FLAG_UNLOCKED: String = "forge_unlocked"

var match_node: Match = null
var forges: Array[LazarusForge] = []
var jobs: Dictionary = {}  # forge index -> [peer, base_id, up_id, start]
var upgrades_done: int = 0  # host: weapons taken
var upgrades_lost: int = 0  # host: offers that expired
var free_used: int = 0


static func is_authority() -> bool:
	return Net.is_host() or not Net.is_active()


func setup(map_root: Node) -> void:
	name = "Forge"
	ProgressionAudio.ensure()
	var markers: Array[MapMarker] = []
	for n: Node in map_root.find_children("*", "MapMarker", true, false):
		if (n as MapMarker).kind == &"forge":
			markers.append(n as MapMarker)
	markers.sort_custom(func(a: MapMarker, b: MapMarker) -> bool: return String(a.marker_id) < String(b.marker_id))
	for mk: MapMarker in markers:
		mk.show_visual = false
		var f: LazarusForge = LazarusForge.new()
		f.name = "LazarusForge"
		f.system = self
		f.index = forges.size()
		mk.add_child(f)
		forges.append(f)


func _ready() -> void:
	for m: StringName in [&"_forge_start", &"_forge_end", &"_forge_full"]:
		Net.register_message(m, Callable(self, "_on_msg" + String(m)))
	Net.peer_joined.connect(_on_peer_joined)


func _exit_tree() -> void:
	for m: StringName in [&"_forge_start", &"_forge_end", &"_forge_full"]:
		Net.unregister_message(m)


func session() -> MatchSession:
	return match_node.session if match_node != null else null


func now() -> float:
	return Net.host_time()


# --- replicated queries (every peer) ------------------------------------------------------------


func is_unlocked() -> bool:
	var s: MatchSession = session()
	return s != null and bool(s.flag(FLAG_UNLOCKED, false))


func free_pending() -> bool:
	return match_node != null and match_node.powerups != null and match_node.powerups.free_upgrade_pending()


func cost(peer_id: int = 0) -> int:
	return 0 if free_pending() or has_token(peer_id) else COST


func has_token(peer_id: int) -> bool:
	return (
		peer_id != 0
		and match_node != null
		and match_node.powerups != null
		and match_node.powerups.free_tokens(peer_id) > 0
	)


func phase(forge: int) -> Phase:
	if not jobs.has(forge):
		return Phase.IDLE
	var t: float = now() - float((jobs[forge] as Array)[3])
	return Phase.FORGING if t < FORGE_TIME else Phase.OFFER


func job_of(forge: int) -> Array:
	return jobs.get(forge, [])


# Seconds into the current job (0 when idle).
func job_time(forge: int) -> float:
	return now() - float((jobs[forge] as Array)[3]) if jobs.has(forge) else 0.0


# --- host ----------------------------------------------------------------------------------------


func host_check(forge: int, peer_id: int, held: StringName) -> String:
	if not is_unlocked():
		return "The Forge is dormant"
	match phase(forge):
		Phase.FORGING:
			return "In use"
		Phase.OFFER:
			return "" if int(job_of(forge)[0]) == peer_id else "In use"
	if held == &"" or not WeaponCatalog.can_upgrade(held):
		return "This weapon cannot be upgraded"
	return ""


# The interactable's execute: insert the held weapon, or take the finished one.
func host_use(forge: int, peer_id: int, held: StringName) -> bool:
	if not is_authority():
		return false
	match phase(forge):
		Phase.IDLE:
			return host_insert(forge, peer_id, held)
		Phase.OFFER:
			return host_take(forge, peer_id)
	return false


func host_insert(forge: int, peer_id: int, base_id: StringName) -> bool:
	var up: WeaponDefinition = WeaponCatalog.upgrade_of(base_id)
	var ws: WeaponSync = match_node.weapons if match_node != null else null
	if jobs.has(forge) or up == null or ws == null or not ws.host_take_weapon(peer_id, base_id):
		return false
	if match_node.powerups != null and match_node.powerups.host_consume_free_upgrade():
		free_used += 1
	elif match_node.powerups != null and match_node.powerups.host_consume_token(peer_id):
		free_used += 1
	var payload: Array = [forge, peer_id, String(base_id), String(up.id), now()]
	jobs[forge] = [peer_id, base_id, up.id, float(payload[4])]
	Net.send_reliable(0, &"_forge_start", payload)
	job_started.emit(forge, peer_id, up.id)
	Log.info(&"forge", "Peer %d forging %s -> %s" % [peer_id, base_id, up.id])
	return true


func host_take(forge: int, peer_id: int) -> bool:
	if phase(forge) != Phase.OFFER or int(job_of(forge)[0]) != peer_id:
		return false
	var ws: WeaponSync = match_node.weapons if match_node != null else null
	if ws == null or not ws.host_give(peer_id, StringName(job_of(forge)[2])):
		return false
	upgrades_done += 1
	_host_end(forge, true)
	return true


# Debug (`forge <weapon_id>`): hand a player the upgraded weapon directly.
func host_grant(peer_id: int, weapon_id: StringName) -> bool:
	var up: WeaponDefinition = WeaponCatalog.upgrade_of(weapon_id)
	var ws: WeaponSync = match_node.weapons if match_node != null else null
	if up == null or ws == null:
		return false
	ws.host_take_weapon(peer_id, weapon_id)
	return ws.host_give(peer_id, up.id)


func _process(_delta: float) -> void:
	if not is_authority() or jobs.is_empty():
		return
	for forge: int in jobs.keys():
		if job_time(forge) >= FORGE_TIME + OFFER_TIME:
			upgrades_lost += 1
			_host_end(forge, false)


func _host_end(forge: int, taken: bool) -> void:
	jobs.erase(forge)
	Net.send_reliable(0, &"_forge_end", [forge, taken])
	job_ended.emit(forge, taken)


# --- messages ------------------------------------------------------------------------------------


func _on_msg_forge_start(sender: int, p: Array) -> void:
	if sender != 1 or Net.is_host():
		return
	jobs[int(p[0])] = [int(p[1]), StringName(p[2]), StringName(p[3]), float(p[4])]
	job_started.emit(int(p[0]), int(p[1]), StringName(p[3]))


func _on_msg_forge_end(sender: int, p: Array) -> void:
	if sender != 1 or Net.is_host():
		return
	jobs.erase(int(p[0]))
	job_ended.emit(int(p[0]), bool(p[1]))


func _on_msg_forge_full(sender: int, p: Array) -> void:
	if sender != 1 or Net.is_host():
		return
	for e: Variant in p:
		_on_msg_forge_start(1, e as Array)


func _on_peer_joined(peer_id: int, _info: Dictionary) -> void:
	if not Net.is_host() or peer_id == Net.local_id() or jobs.is_empty():
		return
	var full: Array = []
	for forge: int in jobs:
		var j: Array = jobs[forge]
		full.append([forge, int(j[0]), String(j[1]), String(j[2]), float(j[3])])
	Net.send_reliable(peer_id, &"_forge_full", full)
