# BotInputDriver — feeds synthetic PlayerInputFrames so tests can walk a route (Step 2 scope 10).
# Waypoints are {pos: Vector3, action: StringName, radius: float, until_y: float}; the action
# applies while heading to that waypoint: walk | sprint | slide (sprint, then crouch on arrival)
# | crouch (hold) | mantle (jump when blocked) | ride (wait on arrival until y >= until_y).
# A waypoint counts as reached within `radius` horizontally and 1.6 m vertically. If the
# distance to the current waypoint stops improving for `stuck_timeout` s the run fails.
# Also provides a deterministic random-input driver (tunneling test) and a world-direction driver.
# Authority: local (drives the owning peer's player).
class_name BotInputDriver
extends RefCounted

const TURN_RATE: float = 14.0

var waypoints: Array[Dictionary] = []
var index: int = 0
var finished: bool = false
var failed: bool = false
var fail_reason: String = ""
var reached_times: PackedFloat64Array = []
var stuck_timeout: float = 5.0
var elapsed: float = 0.0

var _best_dist: float = INF
var _since_progress: float = 0.0
var _slide_pending: bool = false
var _riding: bool = false


static func from_markers(markers: Array[Node]) -> BotInputDriver:
	var d: BotInputDriver = BotInputDriver.new()
	var sorted: Array[Node] = markers.duplicate()
	sorted.sort_custom(func(a: Node, b: Node) -> bool: return String(a.name) < String(b.name))
	for n: Node in sorted:
		var m: Node3D = n as Node3D
		(
			d
			. waypoints
			. append(
				{
					"pos": m.global_position,
					"name": String(m.name),
					"action": StringName(m.get_meta(&"action", &"walk")),
					"radius": float(m.get_meta(&"radius", 0.6)),
					"until_y": float(m.get_meta(&"until_y", 0.0)),
				}
			)
		)
	return d


func current_name() -> String:
	return String(waypoints[index]["name"]) if index < waypoints.size() else "done"


func frame(player: PlayerCharacter, delta: float) -> PlayerInputFrame:
	var f: PlayerInputFrame = PlayerInputFrame.new()
	elapsed += delta
	if finished or failed or index >= waypoints.size():
		finished = finished or index >= waypoints.size()
		return f
	var wp: Dictionary = waypoints[index]
	var target: Vector3 = wp["pos"]
	var action: StringName = wp["action"]
	var pos: Vector3 = player.global_position
	var flat: Vector3 = Vector3(target.x - pos.x, 0.0, target.z - pos.z)
	var dist: float = flat.length()
	if _riding:
		_since_progress = 0.0
		if pos.y >= float(wp["until_y"]) - 0.05:
			_riding = false
			_advance()
		return f
	if dist <= float(wp["radius"]) and absf(target.y - pos.y) < 1.6:
		if action == &"ride":
			_riding = true
			return f
		if action == &"slide":
			f.crouch_pressed = true
			f.sprint = true
			f.move = Vector2(0, -1)
		_advance()
		return f
	# Steer: turn toward the waypoint, walk forward (slower while turning hard).
	var desired: float = atan2(-flat.x, -flat.z)
	var diff: float = wrapf(desired - player.get_yaw(), -PI, PI)
	f.look_delta.x = clampf(diff, -TURN_RATE * delta, TURN_RATE * delta)
	var fwd: float = 1.0 if absf(diff) < 0.35 else clampf(cos(diff), 0.15, 0.6)
	f.move = Vector2(0.0, -fwd)
	f.sprint = action == &"sprint" or action == &"slide"
	f.crouch = action == &"crouch"
	if action == &"mantle" and (player.is_on_wall() or _since_progress > 0.4):
		f.jump_pressed = true
		f.jump_held = true
	if dist < _best_dist - 0.05:
		_best_dist = dist
		_since_progress = 0.0
	else:
		_since_progress += delta
		if _since_progress > stuck_timeout:
			failed = true
			fail_reason = (
				"stuck before %s at %s (%.2f m away)" % [wp["name"], str(pos.snapped(Vector3.ONE * 0.01)), dist]
			)
	return f


func _advance() -> void:
	reached_times.append(elapsed)
	index += 1
	_best_dist = INF
	_since_progress = 0.0
	if index >= waypoints.size():
		finished = true


func as_callable() -> Callable:
	return frame


# World-space wish direction driver (e.g. circle bots in net tests). `dir_fn` returns a Vector3.
static func direction_driver(dir_fn: Callable, sprint: bool = false) -> Callable:
	return func(player: PlayerCharacter, _delta: float) -> PlayerInputFrame:
		var f: PlayerInputFrame = PlayerInputFrame.new()
		var wish: Vector3 = dir_fn.call()
		var local: Vector3 = Basis(Vector3.UP, player.get_yaw()).inverse() * wish
		f.move = Vector2(local.x, local.z).limit_length(1.0)
		f.sprint = sprint
		return f


# Deterministic random input for the tunneling soak (AC-2.3): changes intent every few frames.
static func random_driver(seed_value: int) -> Callable:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var state: Dictionary = {"frames": 0, "frame": PlayerInputFrame.new()}
	return func(_player: PlayerCharacter, _delta: float) -> PlayerInputFrame:
		var left: int = int(state["frames"])
		var first: bool = left <= 0
		if first:
			var nf: PlayerInputFrame = PlayerInputFrame.new()
			nf.move = Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 0.4)).limit_length(1.0)
			nf.sprint = rng.randf() < 0.5
			nf.crouch = rng.randf() < 0.2
			nf.crouch_pressed = rng.randf() < 0.15
			nf.jump_pressed = rng.randf() < 0.25
			nf.jump_held = nf.jump_pressed or rng.randf() < 0.3
			nf.look_delta = Vector2(rng.randf_range(-0.12, 0.12), rng.randf_range(-0.03, 0.03))
			state["frame"] = nf
			state["frames"] = rng.randi_range(4, 40)
		else:
			state["frames"] = left - 1
		var f: PlayerInputFrame = (state["frame"] as PlayerInputFrame).duplicate_frame()
		if not first:
			f.jump_pressed = false
			f.crouch_pressed = false
		return f
