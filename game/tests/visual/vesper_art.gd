# Visual test (Step 13: AC-13.3 automated part, AC-13.5, AC-13.6 review material): renders the
# Vesper Peak art viewpoints — one or more per zone, the landmark sightlines and the five heaviest
# combat viewpoints with 32 zombies and 4 players — on the High and Medium presets. Per viewpoint
# it records draw calls / objects / primitives and the lights that can affect the frame (omni /
# spot lights in range of the camera; shadow-casting ones counted separately) and checks draw
# calls ≤ 1500 (≤ 2000 on the crowd viewpoints: + 32 skinned zombies and 4 players, D-079) and
# shadow lights ≤ the preset budget (8 on High). Frames (High, power on) go to
# --autotest-shots as vesper_<shot>.png plus vesper_art_perf.csv. `--shots=Z01,Z06` limits the set.
# Run: tools/visual_tests.sh docs/screenshots/step13 vesper_art
extends "res://tests/net/autotest_base.gd"

const MAX_DRAW_CALLS: int = 1500
const MAX_DRAW_CALLS_CROWD: int = 2000  # perf viewpoints: + 32 skinned zombies and 4 players
const MAX_SHADOW_LIGHTS: int = 8
# [name, zone, from, look-at, perf viewpoint (32 zombies + 4 players), power on]
const SHOTS: Array = [
	["Z01_Hall", &"Z01", Vector3(-11.5, 4.6, -6.8), Vector3(3, 1, 4), true, true],
	["Z01_Dock", &"Z01", Vector3(-1.2, 1.7, -8.6), Vector3(-5.5, 0.4, -12.4), false, false],
	["Z01_Radar", &"Z01", Vector3(-11.8, 3.6, 5.5), Vector3(-12, 52, -126), false, true],
	["Z03_Lobby", &"Z03", Vector3(40, -5.2, -12.5), Vector3(58, -6.5, 4), true, true],
	["Z03_Mezzanine", &"Z03", Vector3(62, -2.4, 7.2), Vector3(44, -6, -6), false, true],
	["Z04_Corridor", &"Z04", Vector3(75, 0.0, -10), Vector3(75, -1.0, -50), false, true],
	["Z04_Room3", &"Z04", Vector3(78, -0.3, -16.6), Vector3(81.8, -0.6, -18.8), false, true],
	["Z05_Theater", &"Z05", Vector3(66.5, 8.4, -80.5), Vector3(74, 4.5, -88), false, true],
	["Z05_Dome", &"Z05", Vector3(74, 5.4, -86), Vector3(-12, 52, -126), false, true],
	["Z06_Courtyard", &"Z06", Vector3(12, -4.8, -27), Vector3(30, -7, -52), true, true],
	["Z06_MotorPool", &"Z06", Vector3(14, -6.2, -40), Vector3(-4, -7.0, -52), false, true],
	["Z06_Radar", &"Z06", Vector3(28, -6.3, -38), Vector3(-12, 50, -126), false, true],
	["Z07_Plaza", &"Z07", Vector3(3, 19.4, -103), Vector3(-12, 27, -126), true, true],
	["Z07_Operator", &"Z07", Vector3(17.5, 18.9, -107.6), Vector3(12.5, 17.8, -102), false, true],
	["Z08_Boiler", &"Z08", Vector3(-24, -10.4, -12), Vector3(-38, -12, -22), false, true],
	["Z09_Generators", &"Z09", Vector3(-8, -14.5, -43), Vector3(-28, -17, -56), true, true],
	["Z09_PowerOff", &"Z09", Vector3(-8, -14.5, -43), Vector3(-28, -17, -56), false, false],
	["Z10_Morgue", &"Z10", Vector3(20.5, -14.4, -11.5), Vector3(8, -15.5, -20), false, true],
	["Z10_Tunnel", &"Z10", Vector3(24, -14.6, -27), Vector3(40, -15.5, -27), false, true],
	["Z11_Labs", &"Z11", Vector3(58.5, -25.6, -50), Vector3(76, -27, -62), false, true],
	["Z12_Storage", &"Z12", Vector3(89, -25.8, -31), Vector3(68, -27, -44), false, true],
	["Z12_ReactorGlimpse", &"Z12", Vector3(70, -26.4, -42), Vector3(28, -40, -50), false, true],
	["Z13_Reactor", &"Z13", Vector3(6, -45.5, -40), Vector3(28, -44, -50), true, true],
	["Z13_Forge", &"Z13", Vector3(40, -32.0, -36), Vector3(28, -40, -50), false, true],
	["Overview", &"Z06", Vector3(-40, 70, 40), Vector3(28, -10, -60), false, true],
]

var _out: String = ""
var _cam: Camera3D = null
var _only: PackedStringArray = PackedStringArray()


func _ready() -> void:
	timeout = 420.0
	_out = CommandLine.get_value("autotest-shots", "user://screenshots")
	var only: String = CommandLine.get_value("shots", "")
	if only != "":
		_only = only.split(",")
	DirAccess.make_dir_recursive_absolute(_out)
	EventBus.match_started.connect(func(_m: StringName) -> void: _run.call_deferred())


func _frames(n: int) -> void:
	for i: int in n:
		await RenderingServer.frame_post_draw


func _wanted(shot: Array) -> bool:
	if _only.is_empty():
		return true
	for o: String in _only:
		if String(shot[0]).begins_with(o):
			return true
	return false


# Lights that can contribute to this frame: in range of the camera and not behind it.
func _lights_affecting(cam: Camera3D) -> Vector2i:
	var n: int = 0
	var shadowed: int = 0
	for node: Node in get_tree().root.find_children("*", "Light3D", true, false):
		var l: Light3D = node as Light3D
		if l is DirectionalLight3D or not l.is_visible_in_tree() or l.light_energy <= 0.001:
			continue
		var rng: float = (l as OmniLight3D).omni_range if l is OmniLight3D else (l as SpotLight3D).spot_range
		var d: float = cam.global_position.distance_to(l.global_position)
		if l.distance_fade_enabled and d > l.distance_fade_begin + l.distance_fade_length:
			continue
		if d > rng + 60.0:
			continue
		var to: Vector3 = l.global_position - cam.global_position
		if d > rng and to.dot(-cam.global_basis.z) < 0.0:
			continue
		n += 1
		if l.shadow_enabled:
			shadowed += 1
	return Vector2i(n, shadowed)


func _run() -> void:
	await _frames(10)
	var m: Match = Match.current
	var me: PlayerCharacter = sync().local_avatar()
	me.health.invulnerable = true
	me.notarget = true
	m.rounds.enabled = false
	m.zombies.host_kill_all()
	for n: Node in get_tree().get_nodes_in_group(&"hide_for_shots"):
		n.set(&"visible", false)
	if is_instance_valid(Debug.overlay):
		Debug.overlay.visible = false
	var map: Node = m.map_root
	var art: VesperArt = map.get(&"art") as VesperArt
	check("art_layer_present", art != null)
	_cam = Camera3D.new()
	_cam.far = 900.0
	_cam.fov = 70.0
	get_tree().root.add_child(_cam)
	_cam.current = true
	Graphics.apply_camera(_cam)  # the preset's view distance, like the player camera
	var csv: PackedStringArray = ["preset,shot,zone,draw_calls,objects,primitives,lights,shadow_lights,shadow_budget"]
	var worst_dc: int = 0
	var worst_shadow: int = 0
	var bots: Array[PlayerCharacter] = []
	for preset: String in ["high", "medium"]:
		Config.set_value(&"video", &"quality_preset", preset)
		await _frames(4)
		Graphics.apply_camera(_cam)
		var budget: int = Graphics.preset.max_shadow_lights
		var power: bool = false
		Power.host_set(Power.MAIN, false)
		for shot: Array in SHOTS:
			if not _wanted(shot):
				continue
			if bool(shot[5]) != power:
				power = bool(shot[5])
				Power.host_set(Power.MAIN, power)
				await get_tree().create_timer(9.5 if power else 0.5).timeout  # light cascade
			var zombies: Array[ZombieActor] = []
			if bool(shot[4]):
				zombies = _crowd(m, shot[3] as Vector3)
				bots = _bots(m, shot[3] as Vector3, bots)
			_cam.global_position = shot[2]
			_cam.look_at(shot[3], Vector3.UP)
			art.atmosphere.forced_zone = shot[1]
			art.atmosphere.snap_to(shot[1])
			art.shadows.refresh()
			await _frames(8)
			var dc: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
			var obj: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
			var prim: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
			var lights: Vector2i = _lights_affecting(_cam)
			var shadow_active: int = mini(lights.y, budget)
			if not bool(shot[4]):
				worst_dc = maxi(worst_dc, dc)
			worst_shadow = maxi(worst_shadow, Graphics.shadow_casting_lights())
			csv.append(
				(
					"%s,%s,%s,%d,%d,%d,%d,%d,%d"
					% [preset, shot[0], shot[1], dc, obj, prim, lights.x, shadow_active, budget]
				)
			)
			note(
				"%s %s: dc %d obj %d prim %d lights %d shadow %d" % [preset, shot[0], dc, obj, prim, lights.x, lights.y]
			)
			var dc_budget: int = MAX_DRAW_CALLS_CROWD if bool(shot[4]) else MAX_DRAW_CALLS
			check("%s_%s_draw_calls" % [preset, shot[0]], dc > 0 and dc <= dc_budget, "%d <= %d" % [dc, dc_budget])
			if preset == "high" and dc > dc_budget * 0.8:
				note("  in view: %s" % _breakdown(_cam))
			if preset == "high":
				var img: Image = get_viewport().get_texture().get_image()
				img.save_png(_out.path_join("vesper_%s.png" % String(shot[0]).to_lower()))
				check("%s_renders" % shot[0], _variance(img) > 0.0002, _variance(img))
			for z: ZombieActor in zombies:
				if is_instance_valid(z):
					m.zombies.host_despawn(z)
		var sl: int = Graphics.shadow_casting_lights()
		check("%s_shadow_lights_in_budget" % preset, sl <= mini(budget, MAX_SHADOW_LIGHTS), "%d <= %d" % [sl, budget])
	check("draw_calls_max_%d" % MAX_DRAW_CALLS, worst_dc > 0 and worst_dc <= MAX_DRAW_CALLS, worst_dc)
	var f: FileAccess = FileAccess.open(_out.path_join("vesper_art_perf.csv"), FileAccess.WRITE)
	f.store_string("\n".join(csv) + "\n")
	f.close()
	Config.set_value(&"video", &"quality_preset", "high")
	finish(true)


# 32 zombies around the look-at point (frozen in place: render cost, not AI).
func _crowd(m: Match, at: Vector3) -> Array[ZombieActor]:
	var out: Array[ZombieActor] = []
	var arch: ZombieArchetype = Content.get_def(&"ZombieArchetype", &"zombie") as ZombieArchetype
	m.zombies.crowd.frozen = true
	for i: int in 32:
		var a: float = TAU * float(i) / 32.0
		var r: float = 2.0 + float(i % 4) * 1.4
		var z: ZombieActor = m.zombies.host_spawn(arch, 1, at + Vector3(cos(a) * r, 0.0, sin(a) * r), a)
		if z != null:
			out.append(z)
	return out


func _bots(m: Match, at: Vector3, have: Array[PlayerCharacter]) -> Array[PlayerCharacter]:
	while have.size() < 3:
		var b: PlayerCharacter = m.players.add_bot()
		if b == null:
			break
		have.append(b)
	for i: int in have.size():
		have[i].global_position = at + Vector3(-1.5 + i * 1.5, 0.2, 1.0)
	return have


# Visible geometry instances in the camera frustum, grouped by owner (diagnostics for budgets).
func _breakdown(cam: Camera3D) -> String:
	var planes: Array[Plane] = cam.get_frustum()
	var groups: Dictionary = {}
	for n: Node in get_tree().root.find_children("*", "GeometryInstance3D", true, false):
		var g: GeometryInstance3D = n as GeometryInstance3D
		if not g.is_visible_in_tree():
			continue
		var bb: AABB = g.global_transform * g.get_aabb()
		var inside: bool = true
		for pl: Plane in planes:
			var c: Vector3 = bb.get_center()
			var r: float = bb.size.length() * 0.5
			if pl.distance_to(c) > r:
				inside = false
				break
		if not inside:
			continue
		var key: String = g.get_class()
		var p: Node = g.get_parent()
		for i: int in 3:
			if p == null:
				break
			key = "%s/%s" % [String(p.name).get_slice("_", 0), key]
			p = p.get_parent()
		groups[key] = int(groups.get(key, 0)) + 1
	var keys: Array = groups.keys()
	keys.sort_custom(func(a: String, b: String) -> bool: return int(groups[a]) > int(groups[b]))
	var out: PackedStringArray = PackedStringArray()
	for k: String in keys.slice(0, 14):
		out.append("%s=%d" % [k, groups[k]])
	return ", ".join(out)


static func _variance(img: Image) -> float:
	var sum: float = 0.0
	var sq: float = 0.0
	var n: int = 0
	for y: int in range(0, img.get_height(), 8):
		for x: int in range(0, img.get_width(), 8):
			var l: float = img.get_pixel(x, y).get_luminance()
			sum += l
			sq += l * l
			n += 1
	var mean: float = sum / n
	return sq / n - mean * mean
