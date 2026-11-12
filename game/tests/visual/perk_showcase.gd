# Visual check (Step 10, AC-10.5 review material): every Vigor Tonic machine on vesper_peak from
# the front with the power off (only Second Wind lit) and on, plus the six power-up drops in a row.
# Frames go to --autotest-shots (docs/screenshots). Run by tools/visual_tests.sh.
extends "res://tests/net/autotest_base.gd"

var _out: String = ""


func _ready() -> void:
	timeout = 120.0
	_out = CommandLine.get_value("autotest-shots", "user://screenshots")
	DirAccess.make_dir_recursive_absolute(_out)
	EventBus.match_started.connect(func(_m: StringName) -> void: _run.call_deferred())


func _frames(n: int) -> void:
	for i: int in n:
		await RenderingServer.frame_post_draw


func _shot(file: String) -> Image:
	await _frames(3)
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(_out.path_join(file))
	return img


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
	var m: float = sum / n
	return sq / n - m * m


func _run() -> void:
	await _frames(10)
	var m: Match = Match.current
	var me: PlayerCharacter = sync().local_avatar()
	me.health.invulnerable = true
	me.notarget = true
	m.rounds.enabled = false
	for n: Node in get_tree().get_nodes_in_group(&"hide_for_shots"):
		n.set(&"visible", false)
	if is_instance_valid(Debug.overlay):
		Debug.overlay.visible = false
	for i: int in 10:
		await get_tree().physics_frame  # machines face their open side
	var cam: Camera3D = Camera3D.new()
	cam.fov = 60.0
	add_child(cam)
	cam.current = true
	for on: bool in [false, true]:
		Power.host_set(Power.MAIN, on)
		await _frames(4)
		for pm: PerkMachine in m.perks.machines:
			var front: Vector3 = pm.global_transform.basis.z
			cam.global_position = pm.global_position + front * 3.2 + Vector3.UP * 1.5
			cam.look_at(pm.global_position + Vector3.UP * 1.25, Vector3.UP)
			var img: Image = await _shot("perk_%s_%s.png" % [pm.perk_id, "on" if on else "off"])
			check("perk_%s_%s_renders" % [pm.perk_id, "on" if on else "off"], _variance(img) > 0.0005, _variance(img))
	var base: Vector3 = m.players.spawn_point_for(me.peer_id) + Vector3(0, 0, 4.0)
	me.motor.teleport(base + Vector3(0, 0, 12.0))
	var types: Array[StringName] = [&"max_ammo", &"insta_kill", &"double_points", &"nuke", &"carpenter", &"fire_sale"]
	for i: int in types.size():
		m.powerups.host_spawn(types[i], base + Vector3(-3.75 + i * 1.5, 0, 0))
	cam.global_position = base + Vector3(0, 1.6, 4.0)
	cam.look_at(base + Vector3(0, 1.0, 0), Vector3.UP)
	await _frames(20)
	var pimg: Image = await _shot("powerups_row.png")
	check("powerups_render", _variance(pimg) > 0.0005, _variance(pimg))
	finish(true)
