# Visual check (Step 15, AC-15.2): the final HUD in a live solo match on Vesper Peak at 1280x720,
# 1920x1080, 2560x1440 and 3840x2160, each at HUD scale 75 / 100 / 150 % (frames downscaled to
# 1280 px wide for review: hud_<w>x<h>_<scale>.png), with round numerals, points + popups, perks,
# an active power-up, the weapon / ammo block, a prompt-like caption and a subtitle on screen.
# Then the in-match screens at 1280x720: the pause menu with the facility map (ui_pause.png) and
# the game-over dossier after the slow-motion fade (ui_game_over.png).
# Checks: the HUD's logical canvas matches viewport / factor at every size.
extends "res://tests/net/autotest_base.gd"

const SIZES: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(3840, 2160)]
const SCALES: Array[float] = [0.75, 1.0, 1.5]

var _out: String = ""


func _ready() -> void:
	timeout = 420.0
	_out = CommandLine.get_value("autotest-shots", "user://screenshots")
	DirAccess.make_dir_recursive_absolute(_out)
	_run()


func _frames(n: int) -> void:
	for i: int in n:
		await RenderingServer.frame_post_draw


func _shot(file: String) -> void:
	await _frames(3)
	var img: Image = get_viewport().get_texture().get_image()
	if img.get_width() > 1280:
		img.resize(1280, int(1280.0 * img.get_height() / img.get_width()), Image.INTERPOLATE_LANCZOS)
	img.save_png(_out.path_join(file))


func _run() -> void:
	while Match.current == null or Match.current.players == null or Match.current.players.local_avatar() == null:
		await get_tree().process_frame
	var m: Match = Match.current
	if is_instance_valid(Debug.overlay):
		Debug.overlay.visible = false
	m.downed.show_screen = true
	var me: PlayerCharacter = m.players.local_avatar()
	me.notarget = true
	me.health.invulnerable = true
	me.motor.teleport(Vector3(-2, 0.1, -3))
	await _frames(30)
	m.rounds.paused = true
	m.zombies.host_kill_all()
	m.rounds.current_round = 14
	m.rounds.round_started.emit(14)
	for p: StringName in [&"ironhide", &"quickdraw", &"twin_fire"]:
		m.perks.host_grant(me.peer_id, p, true)
	m.powerups.host_apply(&"double_points")
	m.points.host_earn(me.peer_id, 2340)
	m.captions.push("Brandt", "The mountain takes you back.", Color(0.95, 0.6, 0.3), 60.0)
	for sz: Vector2i in SIZES:
		get_window().size = sz
		await _frames(6)
		for sc: float in SCALES:
			Config.set_value(&"gameplay", &"hud_scale", sc)
			m.hud.round_pulse = 10.0
			await _frames(3)
			var vp: Vector2 = get_viewport().get_visible_rect().size
			var f: float = UiTheme.hud_factor(vp, sc)
			check(
				"hud_fit_%dx%d_%d" % [sz.x, sz.y, roundi(sc * 100)],
				m.hud.size.is_equal_approx(vp / f) and is_equal_approx(m.hud.scale.x, f),
				[vp, m.hud.size, f]
			)
			await _shot("hud_%dx%d_%d.png" % [sz.x, sz.y, roundi(sc * 100)])
	Config.set_value(&"gameplay", &"hud_scale", 1.0)
	get_window().size = Vector2i(1280, 720)
	await _frames(6)
	m.pause_menu.visited[&"Z01"] = true
	m.pause_menu.visited[&"Z03"] = true
	m.pause_menu.visited[&"Z06"] = true
	m.pause_menu.open()
	await _frames(8)
	check("pause_open", m.pause_menu.is_open)
	await _shot("ui_pause.png")
	m.pause_menu.close()
	await _frames(4)
	me.health.invulnerable = false
	m.players.damage_player(me.peer_id, 10000.0, me.global_position + Vector3.FORWARD, 0)
	var t0: int = Time.get_ticks_msec()
	while not (Game._screen is GameOverScreen) and Time.get_ticks_msec() - t0 < 60000:
		await get_tree().process_frame
	check("game_over_screen", Game._screen is GameOverScreen)
	await _frames(30)
	await _shot("ui_game_over.png")
	finish(true)
