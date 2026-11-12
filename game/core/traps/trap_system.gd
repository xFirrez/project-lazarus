# TrapSystem — map traps (GAME_DESIGN §12, VESPER_PEAK §5 T1-T3; DEVELOPMENT_PLAN Step 11B
# scope 4). Each trap is a pair of MapMarkers of kind &"trap": "<Tn>_Console" (the activation lever,
# a Trap interactable created here BEFORE the interaction scan) and "<Tn>_<Name>" (the area origin),
# with its TrapDefinition `<tn>` from the Content registry (map data). Generic rules: 1000 points,
# power, ACTIVE for `active_time`, then COOLING for `cooldown`, then READY. While active, the HOST
# kills every zombie inside the area (TRAP damage: no power-ups; 50 points per kill to the activator
# only), freezes them instead for &"freeze" traps (they shatter: StatusEffects), takes trap-resistant
# enemies down by 50 % max HP per second, and damages standing players `player_dps`.
# Shared state = MatchSession flags "trap.<Tn>.until" / ".ready" (host times) / ".by" (activator).
# Authority: HOST activates and applies damage; every peer derives the phase from the flags.
class_name TrapSystem
extends Node

signal trap_activated(trap: Trap, peer_id: int)

enum Phase { READY, ACTIVE, COOLING }

const TICK: float = 0.1

var match_node: Match = null
var traps: Array[Trap] = []
var kills: Dictionary = {}  # host: trap id -> zombies killed (tests)
var player_damage: Dictionary = {}  # host: peer -> trap damage taken (tests)

var _tick: float = 0.0


static func is_authority() -> bool:
	return Net.is_host() or not Net.is_active()


func setup(map_root: Node) -> void:
	name = "Traps"
	ProgressionAudio.ensure()
	var by_id: Dictionary = {}  # Tn -> {console, area}
	for n: Node in map_root.find_children("*", "MapMarker", true, false):
		var mk: MapMarker = n as MapMarker
		if mk.kind != &"trap":
			continue
		var tid: String = String(mk.marker_id).get_slice("_", 0)
		var e: Dictionary = by_id.get(tid, {})
		e["console" if String(mk.marker_id).ends_with("_Console") else "area"] = mk
		by_id[tid] = e
	var ids: Array = by_id.keys()
	ids.sort()
	for tid: String in ids:
		var e: Dictionary = by_id[tid]
		var def: TrapDefinition = Content.get_def(&"TrapDefinition", StringName(tid.to_lower())) as TrapDefinition
		if def == null or not e.has("console") or not e.has("area"):
			continue
		var console: MapMarker = e["console"]
		var area: MapMarker = e["area"]
		console.show_visual = false
		area.show_visual = false
		var t: Trap = Trap.new()
		t.name = "Trap"
		t.trap_id = StringName(tid)
		t.def = def
		t.system = self
		t.area_marker = area
		console.add_child(t)
		traps.append(t)


func session() -> MatchSession:
	return match_node.session if match_node != null else null


func now() -> float:
	return Net.host_time()


func by_id(trap_id: StringName) -> Trap:
	for t: Trap in traps:
		if String(t.trap_id).to_lower() == String(trap_id).to_lower():
			return t
	return null


# --- replicated queries --------------------------------------------------------------------------


func _f(t: Trap, suffix: String, default: Variant) -> Variant:
	var s: MatchSession = session()
	return s.flag("trap.%s.%s" % [t.trap_id, suffix], default) if s != null else default


func phase(t: Trap) -> Phase:
	var n: float = now()
	if n < float(_f(t, "until", -1.0)):
		return Phase.ACTIVE
	if n < float(_f(t, "ready", -1.0)):
		return Phase.COOLING
	return Phase.READY


func time_left(t: Trap) -> float:
	match phase(t):
		Phase.ACTIVE:
			return float(_f(t, "until", 0.0)) - now()
		Phase.COOLING:
			return float(_f(t, "ready", 0.0)) - now()
	return 0.0


func activator(t: Trap) -> int:
	return int(_f(t, "by", 0))


# --- host ----------------------------------------------------------------------------------------


func host_check(t: Trap) -> String:
	match phase(t):
		Phase.ACTIVE:
			return "Trap active"
		Phase.COOLING:
			return "Trap cooling down"
	return ""


func host_activate(t: Trap, peer_id: int) -> bool:
	if not is_authority() or phase(t) != Phase.READY:
		return false
	var s: MatchSession = session()
	var start: float = now()
	s.host_set_flag("trap.%s.by" % t.trap_id, peer_id)
	s.host_set_flag("trap.%s.until" % t.trap_id, start + t.def.active_time)
	s.host_set_flag("trap.%s.ready" % t.trap_id, start + t.def.active_time + t.def.cooldown)
	trap_activated.emit(t, peer_id)
	Log.info(&"traps", "%s activated by %d" % [t.trap_id, peer_id])
	return true


# Debug: end the cooldown (`trap <id>` re-arms first).
func host_reset(t: Trap) -> void:
	if is_authority():
		session().host_set_flag("trap.%s.until" % t.trap_id, -1.0)
		session().host_set_flag("trap.%s.ready" % t.trap_id, -1.0)


func _physics_process(delta: float) -> void:
	if not is_authority():
		return
	_tick += delta
	if _tick < TICK:
		return
	var dt: float = _tick
	_tick = 0.0
	for t: Trap in traps:
		if phase(t) == Phase.ACTIVE:
			_host_apply(t, dt)


func _host_apply(t: Trap, dt: float) -> void:
	var area: Transform3D = t.area_marker.global_transform
	var peer: int = activator(t)
	var m: Match = match_node
	if m.zombies != null and m.targets != null:
		for a: ZombieActor in m.zombies.actors.values():
			if not is_instance_valid(a) or not a.alive or not t.def.contains(area, a.global_position):
				continue
			var resist: bool = a.archetype != null and (a.archetype.trap_resistant or a.archetype.is_boss)
			var amount: float = a.max_health * t.def.special_fraction_per_s * dt if resist else a.health + 1.0
			if t.def.effect == &"freeze" and not resist:
				if m.status != null:
					m.status.host_freeze(a, t.def.freeze_time, peer)
				continue
			var info: DamageInfo = DamageInfo.make(
				amount, WeaponDefinition.Hitzone.TORSO, DamageInfo.Kind.TRAP, StringName(t.trap_id), peer
			)
			m.targets.host_damage(a, info)
			if not a.alive:
				kills[t.trap_id] = int(kills.get(t.trap_id, 0)) + 1
	if m.players != null:
		for id: int in m.players.avatars:
			var p: PlayerCharacter = m.players.avatars[id]
			if p.health.is_downed or p.spectating or not t.def.contains(area, p.global_position):
				continue
			var applied: float = m.players.damage_player(
				id, t.def.player_dps * dt, area.origin, HealthComponent.DamageType.GENERIC
			)
			player_damage[id] = float(player_damage.get(id, 0.0)) + applied
