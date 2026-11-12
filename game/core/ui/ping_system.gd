# PingSystem — contextual teammate pings (GAME_DESIGN §13 "Ping", DEVELOPMENT_PLAN Step 7 scope
# 8). The local player presses `ping` (middle mouse / Z): a ray from the camera classifies what
# is under the crosshair — a zombie (marker follows it), an interactable item (wall-buy, door) or
# machine (Interactable.ping_kind), or a location — and asks the host, which rate-limits and
# broadcasts it. Every peer shows a world marker in the pinger's character colour for
# PING_LIFETIME (one per player; a new ping replaces the old), plays a short per-kind cue and
# the MatchHud draws an edge indicator when it is off-screen.
#   owner -> host : `_ping_req` [kind, x, y, z, zombie_net_id, label]
#   host  -> all  : `_ping` [peer, kind, x, y, z, zombie_net_id, label]
# Authority: HOST validates and relays; presentation on every peer.
class_name PingSystem
extends Node

signal pinged(peer_id: int, kind: StringName, position: Vector3, label: String)

enum Kind { LOCATION, ZOMBIE, ITEM, MACHINE }

const KIND_NAMES: Array[StringName] = [&"location", &"zombie", &"item", &"machine"]
const PING_LIFETIME: float = 6.0
const RAY_LENGTH: float = 80.0
const ITEM_RADIUS: float = 2.5
const MIN_INTERVAL: float = 0.6  # host rate limit per player
const MAX_PINGER_DISTANCE: float = 90.0
const WORLD_MASK: int = 1 << 0

var match_node: Match = null
var active: Dictionary = {}  # peer -> {kind, pos, zombie, label, age, node}
var pings_sent: int = 0
var pings_shown: int = 0

var _last_ping: Dictionary = {}  # host: peer -> Net.now()


static func is_authority() -> bool:
	return Net.is_host() or not Net.is_active()


static func kind_from_name(n: StringName) -> int:
	return maxi(KIND_NAMES.find(n), 0)


func _ready() -> void:
	name = "Pings"
	CoopAudio.ensure_events()
	Net.register_message(&"_ping_req", _on_msg_req)
	Net.register_message(&"_ping", _on_msg_ping)
	Net.peer_left.connect(func(id: int) -> void: _clear(id))


func _exit_tree() -> void:
	Net.unregister_message(&"_ping_req")
	Net.unregister_message(&"_ping")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ping") and not event.is_echo():
		ping_from_view()


# Local player: classify what is under the crosshair and send the ping.
func ping_from_view() -> bool:
	var me: PlayerCharacter = match_node.players.local_avatar() if match_node.players != null else null
	if me == null or me.spectating:
		return false
	var cam: Camera3D = me.camera
	var from: Vector3 = cam.global_position
	var dir: Vector3 = -cam.global_transform.basis.z
	var info: Dictionary = classify(me, from, dir)
	request(int(info["kind"]), info["pos"] as Vector3, int(info["zombie"]), String(info["label"]))
	return true


# Ray from `from` along `dir`: zombie hurtbox -> ZOMBIE; near an interactable -> ITEM / MACHINE;
# else the world hit point (or the far point of the ray) -> LOCATION.
func classify(me: PlayerCharacter, from: Vector3, dir: Vector3) -> Dictionary:
	var space: PhysicsDirectSpaceState3D = me.get_world_3d().direct_space_state
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		from, from + dir * RAY_LENGTH, WORLD_MASK | Hurtbox.LAYER, [me.get_rid()]
	)
	q.collide_with_areas = true
	var hit: Dictionary = space.intersect_ray(q)
	var pos: Vector3 = from + dir * RAY_LENGTH
	if not hit.is_empty():
		pos = hit["position"]
		var col: Object = hit["collider"]
		if col is Hurtbox and (col as Hurtbox).target is ZombieActor:
			var z: ZombieActor = (col as Hurtbox).target as ZombieActor
			if z.alive:
				return {"kind": Kind.ZOMBIE, "pos": z.global_position, "zombie": z.net_id, "label": "Zombie"}
	var best: Interactable = null
	var best_d: float = ITEM_RADIUS
	if match_node.interaction != null:
		for ia: Interactable in match_node.interaction.interactables:
			if not ia.is_available(me):
				continue
			var d: float = _segment_distance(ia.global_position, from, pos)
			if d < best_d and ia.global_position.distance_to(pos) < ITEM_RADIUS * 2.0:
				best_d = d
				best = ia
	if best != null:
		var kind: int = Kind.MACHINE if best.ping_kind == &"machine" else Kind.ITEM
		return {"kind": kind, "pos": best.global_position, "zombie": 0, "label": label_for(best, me)}
	return {"kind": Kind.LOCATION, "pos": pos, "zombie": 0, "label": ""}


static func label_for(ia: Interactable, me: PlayerCharacter) -> String:
	if ia.ping_label != "":
		return ia.ping_label
	var t: String = ia.get_prompt(me)
	t = t.trim_prefix("Hold [F] to ").trim_prefix("Hold [F] for ")
	var bracket: int = t.find(" [")
	if bracket > 0:
		t = t.substr(0, bracket)
	return t.capitalize() if t.length() < 3 else t[0].to_upper() + t.substr(1)


static func _segment_distance(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab: Vector3 = b - a
	var t: float = clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return p.distance_to(a + ab * t)


func request(kind: int, pos: Vector3, zombie_id: int, label: String) -> void:
	pings_sent += 1
	var payload: Array = [kind, pos.x, pos.y, pos.z, zombie_id, label.substr(0, 40)]
	if is_authority():
		_host_ping(Net.local_id() if Net.is_active() else 1, payload)
	else:
		Net.send_reliable(1, &"_ping_req", payload)


func _host_ping(peer_id: int, p: Array) -> void:
	var now: float = Net.now()
	if now - float(_last_ping.get(peer_id, -100.0)) < MIN_INTERVAL:
		return
	var pinger: PlayerCharacter = match_node.players.avatars.get(peer_id, null)
	var pos: Vector3 = Vector3(float(p[1]), float(p[2]), float(p[3]))
	if pinger == null or pinger.global_position.distance_to(pos) > MAX_PINGER_DISTANCE:
		return
	_last_ping[peer_id] = now
	var kind: int = clampi(int(p[0]), 0, KIND_NAMES.size() - 1)
	var out: Array = [peer_id, kind, pos.x, pos.y, pos.z, int(p[4]), String(p[5])]
	Net.send_reliable(0, &"_ping", out)
	_show(out)


func _on_msg_req(sender: int, p: Array) -> void:
	if Net.is_host() and p.size() >= 6:
		_host_ping(sender, p)


func _on_msg_ping(sender: int, p: Array) -> void:
	if sender == 1 and not Net.is_host():
		_show(p)


func _show(p: Array) -> void:
	var peer: int = int(p[0])
	var kind: int = int(p[1])
	var pos: Vector3 = Vector3(float(p[2]), float(p[3]), float(p[4]))
	var label: String = String(p[6])
	_clear(peer)
	var who: PlayerCharacter = match_node.players.avatars.get(peer, null)
	var col: Color = who.player_color() if who != null else Color.WHITE
	var marker: Node3D = _build_marker(kind, col, label, who.display_name if who != null else "")
	add_child(marker)
	marker.global_position = pos
	active[peer] = {"kind": kind, "pos": pos, "zombie": int(p[5]), "label": label, "age": 0.0, "node": marker}
	pings_shown += 1
	Audio.play_event(StringName("ping_%s" % KIND_NAMES[kind]))
	pinged.emit(peer, KIND_NAMES[kind], pos, label)


func _clear(peer: int) -> void:
	if active.has(peer):
		var n: Node3D = (active[peer] as Dictionary)["node"]
		if is_instance_valid(n):
			n.queue_free()
		active.erase(peer)


func _build_marker(kind: int, col: Color, label: String, who: String) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "Ping"
	var l: Label3D = Label3D.new()
	l.name = "Label"
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.fixed_size = true
	l.pixel_size = 0.0012
	l.font_size = 30
	l.outline_size = 8
	l.modulate = col
	l.render_priority = 3
	var head: String = ["▼", "☠ ▼", "◆ ▼", "⚙ ▼"][kind]
	var text: String = label if label != "" else ("%s's ping" % who if who != "" else "Here")
	l.text = "%s\n%s" % [text, head]
	l.position.y = 0.5 if kind != Kind.ZOMBIE else 2.2
	root.add_child(l)
	var ring: MeshInstance3D = MeshInstance3D.new()
	ring.name = "Ring"
	var tm: TorusMesh = TorusMesh.new()
	tm.inner_radius = 0.32
	tm.outer_radius = 0.4
	ring.mesh = tm
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = col
	mat.no_depth_test = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material_override = mat
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.position.y = 0.05
	root.add_child(ring)
	return root


func _process(delta: float) -> void:
	for peer: int in active.keys():
		var a: Dictionary = active[peer]
		a["age"] = float(a["age"]) + delta
		if float(a["age"]) >= PING_LIFETIME:
			_clear(peer)
			continue
		var n: Node3D = a["node"]
		var zid: int = int(a["zombie"])
		if zid != 0 and match_node.zombies != null:
			var z: ZombieActor = match_node.zombies.actors.get(zid, null)
			if z != null and z.alive:
				n.global_position = z.global_position
				a["pos"] = z.global_position
		var fade: float = clampf((PING_LIFETIME - float(a["age"])) / 1.0, 0.0, 1.0)
		var label: Label3D = n.get_node(^"Label") as Label3D
		var c: Color = label.modulate
		c.a = fade
		label.modulate = c
		var ring: Node3D = n.get_node(^"Ring") as Node3D
		ring.scale = Vector3.ONE * (1.0 + 0.15 * sin(float(a["age"]) * 6.0))
