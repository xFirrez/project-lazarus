# Visual test (AC-2.4): renders the local player's view, applies damage from the left and then
# from the right, and checks in the captured frames that the directional indicator appears on the
# matching side and that the red vignette strengthens at the screen edges. Writes the frames to
# --autotest-shots (docs/screenshots) for review. Run by tools/visual_tests.sh (xvfb + opengl3).
extends "res://tests/net/autotest_base.gd"

var _out: String = ""


func _ready() -> void:
	timeout = 40.0
	_out = CommandLine.get_value("autotest-shots", "user://screenshots")
	DirAccess.make_dir_recursive_absolute(_out)
	EventBus.match_started.connect(func(_m: StringName) -> void: _run.call_deferred())


func _frames(n: int) -> void:
	for i: int in n:
		await RenderingServer.frame_post_draw


func _capture(shot: String) -> Image:
	await _frames(3)
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(_out.path_join("damage_hud_%s.png" % shot))
	return img


# Mean "redness" (r - (g + b) / 2) over a rectangle given in fractions of the image size.
static func redness(img: Image, rect: Rect2) -> float:
	var w: int = img.get_width()
	var h: int = img.get_height()
	var x0: int = int(rect.position.x * w)
	var y0: int = int(rect.position.y * h)
	var x1: int = int(rect.end.x * w)
	var y1: int = int(rect.end.y * h)
	var total: float = 0.0
	var count: int = 0
	for y: int in range(y0, y1, 2):
		for x: int in range(x0, x1, 2):
			var c: Color = img.get_pixel(x, y)
			total += c.r - (c.g + c.b) * 0.5
			count += 1
	return total / maxf(count, 1)


func _indicator_rect(left: bool, img: Image) -> Rect2:
	# Indicator wedge sits 150-176 px from the centre, at the side of the source.
	var w: float = img.get_width()
	var h: float = img.get_height()
	var cx: float = 0.5 + (-163.0 if left else 163.0) / w
	return Rect2(cx - 12.0 / w, 0.5 - 40.0 / h, 24.0 / w, 80.0 / h)


func _run() -> void:
	await _frames(30)
	var me: PlayerCharacter = sync().local_avatar()
	me.set_view(0.0, deg_to_rad(-8.0))
	await _frames(10)
	var base: Image = await _capture("0_none")
	var edge: Rect2 = Rect2(0.0, 0.88, 0.1, 0.12)  # bottom-left corner: vignette is strongest there
	var base_edge: float = redness(base, edge)
	var base_l: float = redness(base, _indicator_rect(true, base))
	var base_r: float = redness(base, _indicator_rect(false, base))
	Debug.run("damage 45 90")
	var left: Image = await _capture("1_from_left")
	var l_l: float = redness(left, _indicator_rect(true, left)) - base_l
	var l_r: float = redness(left, _indicator_rect(false, left)) - base_r
	check("left_hit_indicator_on_left", l_l > 0.2 and l_l > l_r + 0.15, "left %.2f right %.2f" % [l_l, l_r])
	var edge_hit: float = redness(left, edge)
	check("vignette_reddens_edges", edge_hit > base_edge + 0.05, "edge %.3f -> %.3f" % [base_edge, edge_hit])
	result["edge_redness"] = [base_edge, edge_hit]
	# Let the left indicator fade, then hit from the right.
	await get_tree().create_timer(DamageHud.INDICATOR_TIME + 0.2).timeout
	Debug.run("damage 25 -90")
	var right: Image = await _capture("2_from_right")
	var r_l: float = redness(right, _indicator_rect(true, right)) - base_l
	var r_r: float = redness(right, _indicator_rect(false, right)) - base_r
	check("right_hit_indicator_on_right", r_r > 0.2 and r_r > r_l + 0.15, "left %.2f right %.2f" % [r_l, r_r])
	check("vignette_scales_with_missing_hp", redness(right, edge) > edge_hit, "70%% missing > 45%% missing")
	finish(true)
