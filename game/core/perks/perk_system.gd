# PerkSystem — Vigor Tonics per match (GAME_DESIGN §8, §3.3; DEVELOPMENT_PLAN Step 10 scope 1-4, 7).
# Machines (PerkMachine, one per MapMarker of kind &"perk", created by `setup` BEFORE the
# interaction scan) sell perks; the HOST validates (cap 4, power, owned, Second Wind uses), takes the
# points, starts the 3 s drink and grants the perk when the drink ends. Every peer mirrors every
# player's perk list into `PlayerCharacter.perk_holder` (stats → movement, weapons, health, revive).
# Rules: all perks are lost when downed (Pack Mule also drops the third weapon); Second Wind in
# solo = an automatic self-revive (DownedSystem) at most `SECOND_WIND_SOLO_USES` times per match,
# after which its machine disappears; in co-op it makes its owner revive teammates in 2 s.
# Shared state: per-player lists (replicated + late join + state hash) and MatchSession flags
# "second_wind_uses" / "perk_cap_removed" (Easter egg reward, Step 14).
#   host -> all  : `_perks` [peer, [ids]]   `_perk_drink` [peer, perk_id, seconds]   `_perk_lost` [peer]
#   host -> joiner: `_perks_full` [[peer, [ids]]...]
# Authority: HOST decides; every peer presents (HUD caps, drink animation, stingers).
class_name PerkSystem
extends Node

signal perks_changed(peer_id: int, ids: Array[StringName])
signal drink_started(peer_id: int, perk_id: StringName)
signal perks_lost(peer_id: int)

const DRINK_TIME: float = 3.0
const PERK_CAP: int = 4
const SECOND_WIND: StringName = &"second_wind"
const PACK_MULE: StringName = &"pack_mule"
const SECOND_WIND_SOLO_USES: int = 3
const FLAG_SW_USES: String = "second_wind_uses"
const FLAG_CAP_REMOVED: String = "perk_cap_removed"

var match_node: Match = null
var machines: Array[PerkMachine] = []
var lists: Dictionary = {}  # every peer: peer -> Array[StringName] (acquisition order)
var drinking: Dictionary = {}  # host: peer -> [perk_id, ends_at (host time)]
var purchases: int = 0
var free_grants: int = 0
var self_revives: int = 0


static func is_authority() -> bool:
	return Net.is_host() or not Net.is_active()


# Called by Match.setup BEFORE InteractionSystem.scan (machines are interactables, tree order).
func setup(map_root: Node) -> void:
	name = "Perks"
	PerkAudio.ensure()
	var markers: Array[MapMarker] = []
	for n: Node in map_root.find_children("*", "MapMarker", true, false):
		var mk: MapMarker = n as MapMarker
		if mk.kind == &"perk":
			markers.append(mk)
	markers.sort_custom(func(a: MapMarker, b: MapMarker) -> bool: return String(a.marker_id) < String(b.marker_id))
	for mk: MapMarker in markers:
		var def: PerkDefinition = PerkCatalog.by_marker(mk.marker_id)
		if def == null:
			continue
		mk.show_visual = false
		var pm: PerkMachine = PerkMachine.new()
		pm.name = "PerkMachine"
		pm.perk_id = def.id
		pm.system = self
		mk.add_child(pm)
		machines.append(pm)


func _ready() -> void:
	for m: StringName in [&"_perks", &"_perk_drink", &"_perk_lost", &"_perks_full"]:
		Net.register_message(m, Callable(self, "_on_msg" + String(m)))
	Net.peer_joined.connect(_on_peer_joined)
	Net.peer_left.connect(
		func(id: int) -> void:
			lists.erase(id)
			drinking.erase(id)
	)
	var ps: PlayerSync = players()
	if ps != null:
		ps.avatar_spawned.connect(func(id: int, _a: PlayerCharacter) -> void: _apply(id))


func _exit_tree() -> void:
	for m: StringName in [&"_perks", &"_perk_drink", &"_perk_lost", &"_perks_full"]:
		Net.unregister_message(m)


func players() -> PlayerSync:
	return match_node.players if match_node != null else null


func session() -> MatchSession:
	return match_node.session if match_node != null else null


# --- queries (every peer) ---------------------------------------------------------------------


func ids_of(peer_id: int) -> Array[StringName]:
	var out: Array[StringName] = []
	for v: Variant in lists.get(peer_id, []):
		out.append(StringName(v))
	return out


func has_perk(peer_id: int, perk_id: StringName) -> bool:
	return ids_of(peer_id).has(perk_id)


func cap() -> int:
	var s: MatchSession = session()
	return 99 if s != null and bool(s.flag(FLAG_CAP_REMOVED, false)) else PERK_CAP


# Solo = one player in the match (Second Wind price and behaviour, GAME_DESIGN §8).
func is_solo() -> bool:
	var ps: PlayerSync = players()
	return ps == null or ps.avatars.size() <= 1


func second_wind_uses() -> int:
	var s: MatchSession = session()
	return int(s.flag(FLAG_SW_USES, 0)) if s != null else 0


# The Second Wind machine is gone after its third solo self-revive.
func second_wind_available() -> bool:
	return second_wind_uses() < SECOND_WIND_SOLO_USES


func price_of(def: PerkDefinition) -> int:
	return def.price(not is_solo())


func is_drinking(peer_id: int) -> bool:
	return drinking.has(peer_id)


# Digest fragment for the MatchSession state hash ("a,b,c").
func digest_of(peer_id: int) -> String:
	return ",".join(PackedStringArray(_strings(ids_of(peer_id))))


# --- host API ---------------------------------------------------------------------------------


# Refusal reason for buying `perk_id` ("" = allowed). Cost and power are checked by the caller.
func host_check(peer_id: int, perk_id: StringName) -> String:
	if has_perk(peer_id, perk_id):
		return "Already owned"
	if drinking.has(peer_id):
		return "Busy"
	if ids_of(peer_id).size() >= cap():
		return "Perk limit reached"
	if perk_id == SECOND_WIND and is_solo() and not second_wind_available():
		return "Unavailable"
	return ""


# HOST: paid purchase → drink → grant (PerkMachine.host_execute).
func host_begin_purchase(peer_id: int, perk_id: StringName) -> bool:
	if not is_authority() or host_check(peer_id, perk_id) != "":
		return false
	purchases += 1
	if Match.current != null and Match.current.points != null:
		Match.current.points.host_add_stat(peer_id, &"perks")
	drinking[peer_id] = [perk_id, Net.host_time() + DRINK_TIME]
	Net.send_reliable(0, &"_perk_drink", [peer_id, String(perk_id), DRINK_TIME])
	_present_drink(peer_id, perk_id, DRINK_TIME)
	return true


# HOST: grant right away (debug `perk`, free perk crate, reconnect). Ignores price and power.
func host_grant(peer_id: int, perk_id: StringName, ignore_cap: bool = false) -> bool:
	if not is_authority() or PerkCatalog.get_def(perk_id) == null or has_perk(peer_id, perk_id):
		return false
	if not ignore_cap and ids_of(peer_id).size() >= cap():
		return false
	var next: Array[StringName] = ids_of(peer_id)
	next.append(perk_id)
	host_set_perks(peer_id, next)
	return true


# HOST: free perk (S1 Director's Office crate, Easter egg events): a random perk the player
# doesn't hold (`perk_id` forces one). Ignores the cap. Returns the perk granted (&"" = none).
func host_grant_free(peer_id: int, perk_id: StringName = &"", rng: RandomNumberGenerator = null) -> StringName:
	if not is_authority():
		return &""
	var pick: StringName = perk_id
	if pick == &"":
		var pool: Array[StringName] = []
		for pid: StringName in PerkCatalog.ids():
			if not has_perk(peer_id, pid) and not (pid == SECOND_WIND and is_solo() and not second_wind_available()):
				pool.append(pid)
		if pool.is_empty():
			return &""
		var r: RandomNumberGenerator = rng if rng != null else RandomNumberGenerator.new()
		if rng == null:
			r.randomize()
		pick = pool[r.randi() % pool.size()]
	if not host_grant(peer_id, pick, true):
		return &""
	free_grants += 1
	Audio.play_event(PerkCatalog.get_def(pick).sting_event())
	return pick


func host_set_perks(peer_id: int, ids: Array) -> void:
	if not is_authority():
		return
	var clean: Array[StringName] = []
	for v: Variant in ids:
		var pid: StringName = StringName(String(v))
		if PerkCatalog.get_def(pid) != null and not clean.has(pid):
			clean.append(pid)
	var had_mule: bool = has_perk(peer_id, PACK_MULE)
	lists[peer_id] = clean
	Net.send_reliable(0, &"_perks", [peer_id, _strings(clean)])
	_apply(peer_id)
	# After _apply: the slot count already excludes Pack Mule's third slot.
	if had_mule and not clean.has(PACK_MULE) and match_node != null and match_node.weapons != null:
		match_node.weapons.host_trim_to_slots(peer_id)


# HOST (DownedSystem, before last stand): every perk is lost; a drink in progress is cancelled.
func host_on_downed(peer_id: int) -> void:
	if not is_authority():
		return
	drinking.erase(peer_id)
	if ids_of(peer_id).is_empty():
		return
	host_set_perks(peer_id, [])
	Net.send_reliable(0, &"_perk_lost", [peer_id])
	_present_lost(peer_id)


# HOST (DownedSystem): solo + Second Wind with uses left → the down becomes a self-revive.
# Consumes the use (MatchSession flag) and every perk.
func host_take_self_revive(peer_id: int) -> bool:
	if not is_authority() or not is_solo() or not second_wind_available():
		return false
	var p: PlayerCharacter = players().avatars.get(peer_id, null) if players() != null else null
	if p == null or not p.perk_holder.stats.flag(PlayerStats.SELF_REVIVE):
		return false
	self_revives += 1
	if session() != null:
		session().host_set_flag(FLAG_SW_USES, second_wind_uses() + 1)
	return true


func _process(_delta: float) -> void:
	if not is_authority() or drinking.is_empty():
		return
	var now: float = Net.host_time()
	for peer: int in drinking.keys():
		var d: Array = drinking[peer]
		if now >= float(d[1]):
			drinking.erase(peer)
			host_grant(peer, StringName(d[0]))
			var def: PerkDefinition = PerkCatalog.get_def(StringName(d[0]))
			if def != null:
				_play_for(peer, def.sting_event())


# --- presentation (every peer) ----------------------------------------------------------------


func _apply(peer_id: int) -> void:
	var ps: PlayerSync = players()
	var p: PlayerCharacter = ps.avatars.get(peer_id, null) if ps != null else null
	var ids: Array[StringName] = ids_of(peer_id)
	if p != null:
		p.apply_perks(ids)
		if match_node != null and match_node.weapons != null:  # host fire-rate validation (Twin-Fire)
			var rate: float = p.perk_holder.stats.value(PlayerStats.FIRE_RATE, 1.0)
			match_node.weapons.validator.set_rate_multiplier(peer_id, rate, Net.host_time())
		if is_authority():
			ps.broadcast_health(peer_id)
	perks_changed.emit(peer_id, ids)


func _present_drink(peer_id: int, perk_id: StringName, seconds: float) -> void:
	var ps: PlayerSync = players()
	var p: PlayerCharacter = ps.avatars.get(peer_id, null) if ps != null else null
	var def: PerkDefinition = PerkCatalog.get_def(perk_id)
	if p != null and def != null:
		if p.is_local and p.weapons != null:
			p.weapons.begin_drink(def, seconds)
		elif p.model != null:
			p.model.play_action(&"drink")
	_play_for(peer_id, &"perk_drink")
	drink_started.emit(peer_id, perk_id)


func _present_lost(peer_id: int) -> void:
	var ps: PlayerSync = players()
	var p: PlayerCharacter = ps.avatars.get(peer_id, null) if ps != null else null
	if p != null and p.is_local and p.weapons != null:
		p.weapons.cancel_drink()
	if p != null and p.is_local:
		Audio.play_event(&"perk_lost")
	perks_lost.emit(peer_id)


func _play_for(peer_id: int, event: StringName) -> void:
	var ps: PlayerSync = players()
	var p: PlayerCharacter = ps.avatars.get(peer_id, null) if ps != null else null
	if p != null and p.is_local:
		Audio.play_event(event)
	elif p != null:
		Audio.play_event_3d(event, p.global_position)


# --- messages ---------------------------------------------------------------------------------


func _on_msg_perks(sender: int, p: Array) -> void:
	if sender != 1 or Net.is_host():
		return
	var ids: Array[StringName] = []
	for v: Variant in p[1]:
		ids.append(StringName(String(v)))
	var peer: int = int(p[0])
	var before: int = ids_of(peer).size()
	lists[peer] = ids
	_apply(peer)
	var me: PlayerCharacter = players().local_avatar() if players() != null else null
	if me != null and me.peer_id == peer and ids.size() > before:
		var def: PerkDefinition = PerkCatalog.get_def(ids[ids.size() - 1])
		if def != null:
			Audio.play_event(def.sting_event())


func _on_msg_perk_drink(sender: int, p: Array) -> void:
	if sender == 1 and not Net.is_host():
		_present_drink(int(p[0]), StringName(String(p[1])), float(p[2]))


func _on_msg_perk_lost(sender: int, p: Array) -> void:
	if sender == 1 and not Net.is_host():
		_present_lost(int(p[0]))


func _on_msg_perks_full(sender: int, p: Array) -> void:
	if sender != 1 or Net.is_host():
		return
	for e: Variant in p:
		_on_msg_perks(1, e as Array)


func _on_peer_joined(peer_id: int, _info: Dictionary) -> void:
	if not Net.is_host() or peer_id == Net.local_id():
		return
	var full: Array = []
	for id: int in lists:
		full.append([id, _strings(ids_of(id))])
	Net.send_reliable(peer_id, &"_perks_full", full)


static func _strings(ids: Array) -> Array:
	var out: Array = []
	for v: Variant in ids:
		out.append(String(v))
	return out
