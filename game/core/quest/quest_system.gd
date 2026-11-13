# QuestSystem — the quest engine (ARCHITECTURE §10, DEVELOPMENT_PLAN Step 14 scope 1): runs the map's
# QuestGraphs (MapDefinition.quests) on the HOST. A step is LOCKED until every prerequisite is DONE,
# then ACTIVE: its QuestObjective receives host events (kills with position + weapon, damage,
# interacts, rounds, flags, downs / revives, carry events) and ticks until it completes. There is no
# quest HUD: objectives show progress through the world (diegetic cues); the only generic UI is a
# subtle "quest step complete" sound and optional `qhud.*` lines (the shard indicator).
# Shared state = MatchSession flags (late join, reconnect and the state hash for free):
#   "q.<step>" State; "q.<step>.<key>" objective data; "quest.<graph>.done" graph complete;
#   "qhud.<key>" HUD line text; "lore.note.<entry>" document annotations; "round_display" HUD
#   round override (the finale's "∞").
# Also hosts the generic quest services: CarryItem requests (`_carry_drop`), lore documents / reels
# (LoreItem: `_lore_open`, `_reel`) and the VoDirector (`vo`).
# Debug: `ee_stage <id>` (jump: debug-completes every prerequisite), `ee_skip [id]`, `quest`.
# Authority: HOST decides; every peer presents from the flags.
class_name QuestSystem
extends Node

signal step_changed(step_id: StringName, state: int)  # every peer (from the flags)
signal graph_completed(graph_id: StringName)  # every peer
signal host_event_sent(event: StringName, data: Dictionary)  # host (tests)

enum State { LOCKED, ACTIVE, DONE }

const STATE_NAMES: PackedStringArray = ["locked", "active", "done"]
const STEP_SOUND: StringName = &"quest_step"

var match_node: Match = null
var graphs: Array[QuestGraph] = []
var objectives: Dictionary = {}  # host: step id -> QuestObjective
var carry_items: Dictionary = {}  # item id -> CarryItem (every peer)
var vo: VoDirector = null
var events_sent: int = 0
var completed_log: Array[StringName] = []  # host: steps in completion order (tests)
var started: bool = false

var _graph_of: Dictionary = {}  # step id -> QuestGraph
var _dispatching: int = 0


static func is_authority() -> bool:
	return Net.is_host() or not Net.is_active()


static func state_key(step_id: StringName) -> String:
	return "q.%s" % step_id


func setup(def: MapDefinition) -> void:
	name = "Quest"
	for g: QuestGraph in def.quests:
		if g == null:
			continue
		var errors: PackedStringArray = g.validate()
		if not errors.is_empty():
			Log.error(&"quest", "Quest %s invalid: %s" % [g.id, "; ".join(errors)])
			continue
		graphs.append(g)
		for s: QuestStep in g.steps:
			_graph_of[s.id] = g
	vo = VoDirector.new()
	vo.quest = self
	vo.lore = LoreLibrary.for_map(def)
	add_child(vo)


func _ready() -> void:
	QuestAudio.ensure()
	Net.register_message(&"_carry_drop", _on_msg_carry_drop)
	Net.register_message(&"_lore_open", _on_msg_lore_open)
	Net.register_message(&"_reel", _on_msg_reel)
	if match_node != null and match_node.session != null:
		match_node.session.flag_changed.connect(_on_flag_changed)


func _exit_tree() -> void:
	for o: QuestObjective in objectives.values():
		o.release()
	objectives.clear()
	for t: StringName in [&"_carry_drop", &"_lore_open", &"_reel"]:
		Net.unregister_message(t)


func session() -> MatchSession:
	return match_node.session if match_node != null else null


func flag(k: String, default: Variant = null) -> Variant:
	var s: MatchSession = session()
	return s.flag(k, default) if s != null else default


func host_set(k: String, value: Variant) -> void:
	var s: MatchSession = session()
	if s != null and is_authority():
		s.host_set_flag(k, value)


func now() -> float:
	return Net.host_time()


func player_count() -> int:
	if match_node == null or match_node.players == null:
		return 1
	return maxi(match_node.players.avatars.size(), 1)


# --- queries (every peer) ---------------------------------------------------------------------


func state(step_id: StringName) -> State:
	return int(flag(state_key(step_id), State.LOCKED)) as State


func is_done(step_id: StringName) -> bool:
	return state(step_id) == State.DONE


func is_active(step_id: StringName) -> bool:
	return state(step_id) == State.ACTIVE


func graph_of(step_id: StringName) -> QuestGraph:
	return _graph_of.get(step_id, null)


func step(step_id: StringName) -> QuestStep:
	var g: QuestGraph = graph_of(step_id)
	return g.step(step_id) if g != null else null


func graph(graph_id: StringName) -> QuestGraph:
	for g: QuestGraph in graphs:
		if g.id == graph_id:
			return g
	return null


func graph_done(graph_id: StringName) -> bool:
	return bool(flag("quest.%s.done" % graph_id, false))


# Game-over line (Step 15): "Requiem 4/9 steps" per graph with a badge (main quests only).
func progress_text() -> String:
	var parts: PackedStringArray = []
	for g: QuestGraph in graphs:
		if g.badge == &"" or g.steps.is_empty():
			continue
		var done: int = 0
		for s: QuestStep in g.steps:
			if is_done(s.id):
				done += 1
		parts.append(
			(
				"%s %d/%d%s"
				% [g.title if g.title != "" else String(g.id), done, g.steps.size(), " ★" if graph_done(g.id) else ""]
			)
		)
	return ", ".join(parts)


func active_steps() -> Array[StringName]:
	var out: Array[StringName] = []
	for g: QuestGraph in graphs:
		for s: QuestStep in g.steps:
			if state(s.id) == State.ACTIVE:
				out.append(s.id)
	return out


func objective(step_id: StringName) -> QuestObjective:
	return objectives.get(step_id, null)


# `qhud.*` flags as HUD lines (sorted by key).
func hud_lines() -> PackedStringArray:
	var out: PackedStringArray = []
	var s: MatchSession = session()
	if s == null:
		return out
	var keys: Array = []
	for k: Variant in s.flags.keys():
		if String(k).begins_with("qhud.") and String(s.flags[k]) != "":
			keys.append(k)
	keys.sort()
	for k: Variant in keys:
		out.append(String(s.flags[k]))
	return out


func annotation(entry_id: StringName) -> String:
	return String(flag("lore.note.%s" % entry_id, ""))


func round_display() -> String:
	return String(flag("round_display", ""))


# One line per graph: each step's state (console `quest`).
func describe() -> String:
	var lines: PackedStringArray = []
	for g: QuestGraph in graphs:
		var parts: PackedStringArray = []
		for s: QuestStep in g.steps:
			parts.append("%s:%s" % [s.id, STATE_NAMES[state(s.id)]])
		lines.append("%s%s  %s" % [g.id, " (done)" if graph_done(g.id) else "", " ".join(parts)])
	return "\n".join(lines)


# --- host ---------------------------------------------------------------------------------------


# Called by Match.setup on the host once every system exists: hook up the event sources, then
# activate the steps whose prerequisites are met (a reconnecting host rebuilds from the flags).
func host_start() -> void:
	if not is_authority() or started:
		return
	started = true
	var mn: Match = match_node
	if mn.zombies != null:
		mn.zombies.zombie_died.connect(_on_zombie_died)
		mn.zombies.zombie_spawned.connect(func(a: ZombieActor) -> void: host_event(&"zombie_spawned", {"actor": a}))
	if mn.rounds != null:
		mn.rounds.round_started.connect(func(r: int) -> void: host_event(&"round_started", {"round": r}))
		mn.rounds.round_ended.connect(func(r: int) -> void: host_event(&"round_ended", {"round": r}))
	Net.peer_left.connect(_on_peer_left)
	if mn.downed != null:
		mn.downed.player_downed.connect(_on_player_downed)
		mn.downed.player_revived.connect(
			func(p: int, r: int) -> void: host_event(&"player_revived", {"peer": p, "reviver": r})
		)
	for g: QuestGraph in graphs:
		for s: QuestStep in g.steps:
			if state(s.id) == State.ACTIVE:
				_make_objective(s)
	_unlock_ready()


func host_event(event: StringName, data: Dictionary = {}) -> void:
	if not is_authority():
		return
	events_sent += 1
	_dispatching += 1
	for id: StringName in objectives.keys():
		var o: QuestObjective = objectives.get(id, null)
		if o != null and state(id) == State.ACTIVE:
			o.on_event(event, data)
	_dispatching -= 1
	host_event_sent.emit(event, data)


func host_complete(step_id: StringName) -> void:
	if not is_authority() or state(step_id) == State.DONE:
		return
	var o: QuestObjective = objectives.get(step_id, null)
	objectives.erase(step_id)
	host_set(state_key(step_id), State.DONE)
	completed_log.append(step_id)
	Log.info(&"quest", "Step %s complete" % step_id)
	if o != null:
		o.on_done()
		o.release.call_deferred()  # after the caller finishes (code may follow complete())
	var g: QuestGraph = graph_of(step_id)
	var s: QuestStep = step(step_id)
	if g != null and s != null and s.completes_graph and not graph_done(g.id):
		host_set("quest.%s.done" % g.id, true)
	_unlock_ready()


# Debug: debug-complete every prerequisite of `step_id` (in dependency order), then make it active.
func host_jump(step_id: StringName) -> bool:
	var g: QuestGraph = graph_of(step_id)
	if g == null or not is_authority():
		return false
	for id: StringName in g.ancestors(step_id):
		host_skip(id)
	if state(step_id) == State.LOCKED:
		_activate(g.step(step_id))
	return state(step_id) == State.ACTIVE


# Debug: finish an ACTIVE step as if the players did it (activating it first if needed).
func host_skip(step_id: StringName) -> bool:
	if not is_authority() or state(step_id) == State.DONE:
		return false
	var s: QuestStep = step(step_id)
	if s == null:
		return false
	if state(step_id) == State.LOCKED:
		var g: QuestGraph = graph_of(step_id)
		for id: StringName in g.ancestors(step_id):
			host_skip(id)
		if state(step_id) == State.LOCKED:
			_activate(s)
	var o: QuestObjective = objectives.get(step_id, null)
	if o != null:
		o.on_debug_complete()
	if state(step_id) != State.DONE:
		host_complete(step_id)
	return true


func _unlock_ready() -> void:
	var changed: bool = true
	while changed:
		changed = false
		for g: QuestGraph in graphs:
			for s: QuestStep in g.steps:
				if state(s.id) != State.LOCKED:
					continue
				var ok: bool = true
				for p: StringName in s.prerequisites:
					if state(p) != State.DONE:
						ok = false
						break
				if ok:
					_activate(s)
					changed = true


func _activate(s: QuestStep) -> void:
	host_set(state_key(s.id), State.ACTIVE)
	Log.info(&"quest", "Step %s active" % s.id)
	_make_objective(s)


func _make_objective(s: QuestStep) -> void:
	if objectives.has(s.id) or s.objective == null:
		return
	var o: QuestObjective = s.objective.new() as QuestObjective
	if o == null:
		Log.error(&"quest", "%s: objective script is not a QuestObjective" % s.id)
		return
	o.quest = self
	o.step = s
	o.graph = graph_of(s.id)
	objectives[s.id] = o
	o.on_activate()


func _physics_process(delta: float) -> void:
	if not is_authority() or not started:
		return
	for id: StringName in objectives.keys():
		var o: QuestObjective = objectives.get(id, null)
		if o != null and state(id) == State.ACTIVE:
			o.on_tick(delta)


# --- host event sources -------------------------------------------------------------------------


func _on_zombie_died(a: ZombieActor, source_peer: int) -> void:
	var info: DamageInfo = a.last_hit
	host_event(
		&"zombie_killed",
		{
			"actor": a,
			"position": a.global_position,
			"peer": source_peer,
			"weapon": info.weapon_id if info != null else &"",
			"kind": int(info.kind) if info != null else -1,
		}
	)


func _on_player_downed(peer_id: int) -> void:
	for item: CarryItem in carry_items.values():
		if item.carrier() == peer_id:
			item.host_drop(peer_id)
	host_event(&"player_downed", {"peer": peer_id})


func _on_peer_left(peer_id: int) -> void:
	for item: CarryItem in carry_items.values():
		if item.carrier() == peer_id:
			item.host_drop(peer_id)


# --- presentation (every peer) ------------------------------------------------------------------


func _on_flag_changed(key: String, value: Variant) -> void:
	if key.begins_with("q.") and key.count(".") == 1:
		var id: StringName = StringName(key.substr(2))
		step_changed.emit(id, int(value))
		if int(value) == State.DONE and started_presentation():
			Audio.play_event(STEP_SOUND)
	elif key.begins_with("quest.") and key.ends_with(".done") and bool(value):
		var gid: StringName = StringName(key.trim_prefix("quest.").trim_suffix(".done"))
		var g: QuestGraph = graph(gid)
		if g != null and g.badge != &"" and match_node != null:
			Journal.award_badge(match_node.definition.id, g.badge, player_count())
		if g != null:
			for e: StringName in g.journal_unlocks:
				Journal.unlock(e)
		graph_completed.emit(gid)
	if is_authority() and _dispatching == 0 and not key.begins_with("q.") and not key.begins_with("qhud."):
		host_event(&"flag", {"key": key, "value": value})


# The join snapshot replays every flag: only sound for live changes.
func started_presentation() -> bool:
	return match_node != null and match_node.session != null and match_node.session.gate_open()


# --- carry items --------------------------------------------------------------------------------


func register_carry(item: CarryItem) -> void:
	carry_items[item.item_id] = item


func request_drop(item_id: StringName) -> void:
	if is_authority():
		_on_msg_carry_drop(Net.local_id() if Net.is_active() else 1, [String(item_id)])
	else:
		Net.send_reliable(1, &"_carry_drop", [String(item_id)])


func _on_msg_carry_drop(sender: int, p: Array) -> void:
	if not is_authority() or p.is_empty():
		return
	var item: CarryItem = carry_items.get(StringName(p[0]), null)
	if item != null and item.carrier() == sender:
		item.host_drop(sender)


# --- lore -----------------------------------------------------------------------------------------


func host_open_document(peer_id: int, entry_id: StringName) -> void:
	if not is_authority():
		return
	if peer_id == Net.local_id() or not Net.is_active():
		_on_msg_lore_open(1, [String(entry_id)])
	else:
		Net.send_reliable(peer_id, &"_lore_open", [String(entry_id)])


func host_play_reel(entry_id: StringName, at: Vector3) -> void:
	if not is_authority():
		return
	Net.send_reliable(0, &"_reel", [String(entry_id), at])
	_on_msg_reel(1, [String(entry_id), at])


func _on_msg_lore_open(sender: int, p: Array) -> void:
	if sender != 1 or p.is_empty():
		return
	var id: StringName = StringName(p[0])
	Journal.unlock(id)
	DocumentReader.open(self, vo.lore.entry(id), annotation(id))


func _on_msg_reel(sender: int, p: Array) -> void:
	if sender != 1 or p.size() < 2:
		return
	var id: StringName = StringName(p[0])
	var at: Vector3 = p[1]
	var me: PlayerCharacter = match_node.players.local_avatar() if match_node.players != null else null
	if me == null or me.global_position.distance_to(at) <= LoreItem.REEL_HEAR_RADIUS:
		Journal.unlock(id)
	vo.play_local(id, at)
