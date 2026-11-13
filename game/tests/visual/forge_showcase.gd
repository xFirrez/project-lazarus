# Visual check (Step 11, AC-11.6 review material): the three Resonance Relays idle / charging /
# active, the reactor before and after the relays (bridge extended), the Lazarus Forge dormant,
# forging and offering an upgraded weapon, the three traps active, the breaker puddles live, and a
# row of upgraded weapons with the vesperite camo. Frames go to --autotest-shots. Run by
# tools/visual_tests.sh.
extends "res://tests/net/autotest_base.gd"

var _out: String = ""
var _cam: Camera3D = null


func _ready() -> void:
	timeout = 150.0
	_out = CommandLine.get_value("autotest-shots", "user://screenshots")
	DirAccess.make_dir_recursive_absolute(_out)
	EventBus.match_started.connect(func(_m: StringName) -> void: _run.call_deferred())


func _frames(n: int) -> void:
	for i: int in n:
		await RenderingServer.frame_post_draw


func _shot(file: String) -> void:
	await _frames(4)
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(_out.path_join(file))
	check("%s_renders" % file.get_basename(), _variance(img) > 0.0003, _variance(img))


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


func _look(from: Vector3, at: Vector3) -> void:
	_cam.global_position = from
	_cam.look_at(at, Vector3.UP)


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
	_cam = Camera3D.new()
	_cam.fov = 60.0
	add_child(_cam)
	_cam.current = true
	var core: Vector3 = Vector3(28, -44, -50)
	_look(Vector3(28, -38, -24), core)
	await _shot("reactor_dormant.png")
	Power.host_set(Power.MAIN, true)
	await _frames(30)
	# Relays: R1 idle, R2 charging, R3 done.
	m.relays.host_activate(1)
	m.relays.host_complete(2)
	for i: int in m.relays.relays.size():
		var r: ResonanceRelay = m.relays.relays[i]
		me.motor.teleport(r.global_position + Vector3(2.0, 0.05, 0))  # in the zone: R2 keeps charging
		await _frames(40)
		_look(r.global_position + Vector3(2.6, 2.0, 2.6), r.global_position + Vector3.UP * 1.3)
		await _shot("relay_%s_%s.png" % [r.relay_id, ["idle", "charging", "active"][i]])
	m.relays.host_complete_all()
	await _frames(60)
	_look(Vector3(28, -38, -24), core)
	await _shot("reactor_stabilized.png")
	_look(Vector3(38, -29, -71), Vector3(44, -31.5, -60))  # Step 13: from inside the cavern
	await _shot("reactor_bridge_extended.png")
	# Forge: forging, then the floating offer.
	var forge: LazarusForge = m.forge.forges[0]
	m.weapons.host_give(me.peer_id, &"ak47")
	await _frames(10)
	me.motor.teleport(forge.global_position + Vector3(0, 0.05, 2.5))
	m.forge.host_insert(0, me.peer_id, &"ak47")
	await get_tree().create_timer(2.4).timeout
	_look(forge.global_position + Vector3(3.2, 2.2, 3.2), forge.global_position + Vector3.UP * 1.5)
	await _shot("forge_forging.png")
	await get_tree().create_timer(3.0).timeout
	await _shot("forge_offer.png")
	# Traps active.
	for t: Trap in m.traps.traps:
		m.traps.host_reset(t)
		m.traps.host_activate(t, me.peer_id)
	await _frames(20)
	for t: Trap in m.traps.traps:
		var a: Vector3 = t.area_marker.global_position
		var side: Vector3 = t.global_position - a
		side.y = 0.0
		side = side.normalized() if side.length() > 0.1 else Vector3.RIGHT
		_look(a + side * 5.0 + Vector3.UP * 2.6, a + Vector3.UP * 0.4)
		await _shot("trap_%s_active.png" % t.trap_id)
	m.hazards.host_flip_breaker(me.peer_id)
	await _frames(10)
	var pc: Vector3 = m.hazards.breaker.puddles[0]
	_look(pc + Vector3(-4.0, 3.0, 3.0), pc)
	await _shot("hazard_breaker_puddles.png")
	# Upgraded guns with camo, in a row in the Arrival Station.
	var base: Vector3 = Vector3(-4.0, 1.2, 3.0)
	var ids: Array[StringName] = [&"m1911_up", &"mp40_up", &"m16_up", &"model37_up", &"mg42_up", &"kar98k_up"]
	for i: int in ids.size():
		var def: WeaponDefinition = WeaponCatalog.get_def(ids[i])
		var g: Node3D = def.world_scene.instantiate() as Node3D if def.world_scene != null else GreyboxGun.build(def, 1)
		g.scale = Vector3.ONE * 2.2
		add_child(g)
		g.global_position = base + Vector3(i * 1.6, 0, 0)
		g.rotation.y = PI * 0.5
		WeaponCamo.apply(g, def)
	_look(base + Vector3(4.0, 0.5, 2.6), base + Vector3(4.0, 0, 0))
	await _frames(20)
	await _shot("upgraded_camo_row.png")
	finish(true)
