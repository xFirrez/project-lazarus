# Visual test (AC-3.5), rendered at 1920x1080: (1) for each of the 4 weapons in full ADS, the
# sight point (the magenta fibre dot / scope reticle centre) is centred within 1 px; (2) standing
# 0.4 m from a wall, the viewmodel is still drawn on top of it (separate camera + render layer:
# hiding the viewmodel changes the lower-right of the frame). Frames go to --autotest-shots
# (half-size copies). Run by tools/visual_tests.sh.
extends "res://tests/net/autotest_base.gd"

const WEAPONS: Array[StringName] = [&"m1911", &"mp40", &"model37", &"kar98k"]

var _out: String = ""
var _input: Dictionary = {"aim": false, "fire": false}


func _ready() -> void:
	timeout = 90.0
	_out = CommandLine.get_value("autotest-shots", "user://screenshots")
	DirAccess.make_dir_recursive_absolute(_out)
	EventBus.match_started.connect(func(_m: StringName) -> void: _run.call_deferred())


func _frames(n: int) -> void:
	for i: int in n:
		await RenderingServer.frame_post_draw


func _capture(shot: String) -> Image:
	await _frames(3)
	var img: Image = get_viewport().get_texture().get_image()
	var half: Image = img.duplicate() as Image
	half.resize(img.get_width() / 2, img.get_height() / 2, Image.INTERPOLATE_BILINEAR)
	half.save_png(_out.path_join("viewmodel_%s.png" % shot))
	return img


static func sight_centroid(img: Image) -> Vector3:
	var sx: float = 0.0
	var sy: float = 0.0
	var n: int = 0
	var cx: int = img.get_width() / 2
	var cy: int = img.get_height() / 2
	for y: int in range(cy - 120, cy + 120):
		for x: int in range(cx - 120, cx + 120):
			var c: Color = img.get_pixel(x, y)
			if c.r > 0.8 and c.b > 0.8 and c.g < 0.25:
				sx += x + 0.5
				sy += y + 0.5
				n += 1
	if n == 0:
		return Vector3(-1, -1, 0)
	return Vector3(sx / n, sy / n, n)


func _run() -> void:
	await _frames(20)
	var me: PlayerCharacter = sync().local_avatar()
	var input: Dictionary = _input
	me.bot_driver = func(_p: PlayerCharacter, _d: float) -> PlayerInputFrame:
		var f: PlayerInputFrame = PlayerInputFrame.new()
		f.aim = bool(input["aim"])
		f.fire = bool(input["fire"])
		return f
	me.weapons.recoil_enabled = false
	me.weapons.viewmodel.breath_enabled = false
	me.set_view(0.0, 0.0)
	var size: Vector2 = get_viewport().get_visible_rect().size
	result["resolution"] = [size.x, size.y]
	for wid: StringName in WEAPONS:
		Match.current.weapons.request_give(wid)
		await get_tree().create_timer(0.1).timeout
		_input["aim"] = false
		await get_tree().create_timer(me.weapons.held().def.raise_time + 0.3).timeout
		_input["aim"] = true
		await get_tree().create_timer(me.weapons.held().def.ads_time + 0.8).timeout
		var img: Image = await _capture("ads_%s" % wid)
		var c: Vector3 = sight_centroid(img)
		var centre: Vector2 = Vector2(img.get_width(), img.get_height()) * 0.5
		var err: Vector2 = Vector2(c.x, c.y) - centre
		result["ads_%s" % wid] = {"centroid": [c.x, c.y], "pixels": c.z, "error_px": [err.x, err.y]}
		check(
			"ads_%s_centred_1px" % wid,
			c.z > 4 and absf(err.x) <= 1.0 and absf(err.y) <= 1.0,
			"err %s (%d px)" % [err, c.z]
		)
	# Wall test: hip-fire pose 0.4 m from the backstop.
	_input["aim"] = false
	Match.current.players.request_teleport(Vector3(0, 0.05, -59.1))
	me.set_view(0.0, deg_to_rad(-5.0))
	await get_tree().create_timer(0.8).timeout
	var shown: Image = await _capture("wall_hip")
	me.weapons.viewmodel.container.visible = false
	var hidden: Image = await _capture("wall_hidden")
	me.weapons.viewmodel.container.visible = true
	var diff: int = 0
	var total: int = 0
	for y: int in range(shown.get_height() / 2, shown.get_height(), 4):
		for x: int in range(shown.get_width() / 2, shown.get_width(), 4):
			total += 1
			var a: Color = shown.get_pixel(x, y)
			var b: Color = hidden.get_pixel(x, y)
			if absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) > 0.1:
				diff += 1
	var frac: float = float(diff) / maxf(total, 1)
	result["wall_viewmodel_coverage"] = frac
	check("viewmodel_drawn_over_wall", frac > 0.02, "%.1f%% of the lower-right quadrant" % (frac * 100.0))
	# Feedback frame for review: MP40 sustained fire into the concrete wall (decals, sparks, tracers).
	Match.current.weapons.request_give(&"mp40")
	Match.current.weapons.host_set_infinite_ammo(Net.local_id(), true)
	Match.current.players.request_teleport(Vector3(16, 0.05, -7.5))
	me.set_view(0.0, deg_to_rad(-2.0))
	await get_tree().create_timer(0.8).timeout
	_input["fire"] = true
	await get_tree().create_timer(1.2).timeout
	await _capture("fire_mp40")
	_input["fire"] = false
	await get_tree().create_timer(0.3).timeout
	var vm: Viewmodel = me.weapons.viewmodel
	check(
		"viewmodel_at_rest_after_fire", vm.gun.visible and vm.anim_root.position.length() < 0.005, vm.anim_root.position
	)
	check("decals_spawned", Match.current.fx.decals.size() > 5, Match.current.fx.decals.size())
	finish(true)
