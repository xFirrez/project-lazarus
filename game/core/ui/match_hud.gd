# MatchHud — HUD v1 for the survival loop (GAME_DESIGN §15; final art in Step 15): round counter
# (red tally strokes for rounds 1-5, then numerals; pulses on round change), round banner, own and
# teammates' points with floating gains / deductions, interaction prompts with hold progress,
# refusal feedback, downed / bleedout / revive progress, spectating notice and teammate downed
# markers (screen-space, clamped to the edges when off-screen). Ammo, lethals, hit markers and the
# damage vignette are the WeaponHud / DamageHud.
# Authority: local presentation, reading replicated state from the Match systems.
class_name MatchHud
extends Control

const RED: Color = Color(0.78, 0.1, 0.08)
const POPUP_TIME: float = 1.2
const BANNER_TIME: float = 3.0

var match_node: Match = null
var popups: Array = []  # [text, color, age]
var popups_shown: int = 0
var banner: String = ""
var banner_age: float = 100.0
var round_pulse: float = 100.0

var _font: Font = null


func _ready() -> void:
	name = "MatchHud"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font
	if match_node == null:
		return
	match_node.points.points_changed.connect(_on_points_changed)
	match_node.rounds.round_started.connect(_on_round_started)
	match_node.rounds.round_ended.connect(func(_r: int) -> void: _show_banner("ROUND COMPLETE"))


func _on_points_changed(peer_id: int, _total: int, delta: int) -> void:
	if delta == 0 or peer_id != _local_id():
		return
	var col: Color = Color(1.0, 0.9, 0.45) if delta > 0 else Color(0.95, 0.2, 0.15)
	popups.append(["%+d" % delta, col, 0.0])
	popups_shown += 1
	if popups.size() > 8:
		popups.pop_front()


func _on_round_started(r: int) -> void:
	round_pulse = 0.0
	_show_banner("ROUND %d" % r)


func _show_banner(text: String) -> void:
	banner = text
	banner_age = 0.0


func _local_id() -> int:
	return Net.local_id() if Net.is_active() else 1


func _process(delta: float) -> void:
	banner_age += delta
	round_pulse += delta
	for p: Variant in popups:
		(p as Array)[2] = float((p as Array)[2]) + delta
	popups = popups.filter(func(p: Array) -> bool: return float(p[2]) < POPUP_TIME)
	queue_redraw()


func _draw() -> void:
	if match_node == null or match_node.players == null:
		return
	var me: PlayerCharacter = match_node.players.local_avatar()
	_draw_round()
	_draw_points()
	_draw_banner()
	if me == null:
		return
	_draw_prompt(me)
	_draw_downed(me)
	_draw_teammate_markers(me)


func _text(pos: Vector2, text: String, font_size: int, col: Color, align_right: bool = false) -> void:
	var x: float = pos.x
	if align_right:
		x -= _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(_font, Vector2(x, pos.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, col)


func _text_centered(y: float, text: String, font_size: int, col: Color) -> void:
	var w: float = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(_font, Vector2(size.x * 0.5 - w * 0.5, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, col)


func _draw_round() -> void:
	var rd: RoundDirector = match_node.rounds
	if rd == null or not rd.enabled and rd.current_round == 0:
		return
	var r: int = rd.current_round
	var base: Vector2 = Vector2(40, size.y - 40)
	var t: float = clampf(round_pulse / 2.0, 0.0, 1.0)
	var col: Color = Color.WHITE.lerp(RED, t) if round_pulse < 2.0 else RED
	if r <= 0:
		if rd.phase == RoundDirector.Phase.INTRO:
			_text_centered(size.y * 0.3, "VESPER PEAK", 54, Color(0.85, 0.85, 0.9, 0.9))
		return
	if r <= 5:
		for i: int in mini(r, 4):
			var x: float = base.x + i * 18.0
			draw_line(Vector2(x, base.y), Vector2(x + 3, base.y - 70), col, 7.0)
		if r == 5:
			draw_line(Vector2(base.x - 8, base.y - 12), Vector2(base.x + 66, base.y - 58), col, 7.0)
	else:
		_text(base, str(r), 84, col)
	if rd.phase == RoundDirector.Phase.INTERMISSION:
		_text(Vector2(base.x, base.y - 96), "next round %.0f" % ceilf(rd.time_left), 18, Color(0.8, 0.8, 0.8))


func _draw_points() -> void:
	var ledger: PointsLedger = match_node.points
	var right: float = size.x - 40.0
	var y: float = size.y - 170.0
	var me_id: int = _local_id()
	_text(Vector2(right, y), str(ledger.get_points(me_id)), 36, _player_color(me_id), true)
	for p: Variant in popups:
		var pa: Array = p
		var age: float = float(pa[2])
		var c: Color = pa[1]
		c.a = 1.0 - age / POPUP_TIME
		_text(Vector2(right - 130.0, y - 10.0 - age * 40.0), String(pa[0]), 24, c, true)
	var ty: float = y - 42.0
	for id: int in match_node.players.player_ids():
		if id == me_id:
			continue
		var pc: PlayerCharacter = match_node.players.avatars[id]
		_text(Vector2(right, ty), "%s  %d" % [pc.display_name, ledger.get_points(id)], 20, _player_color(id), true)
		ty -= 26.0


func _player_color(peer_id: int) -> Color:
	var p: PlayerCharacter = match_node.players.avatars.get(peer_id, null)
	return PlayerCharacter.COLORS[p.slot % PlayerCharacter.COLORS.size()] if p != null else Color.WHITE


func _draw_banner() -> void:
	if banner_age >= BANNER_TIME or banner == "":
		return
	var a: float = clampf(minf(banner_age * 3.0, (BANNER_TIME - banner_age) * 1.5), 0.0, 1.0)
	_text_centered(size.y * 0.28, banner, 46, Color(RED.r, RED.g, RED.b, a))


func _draw_prompt(me: PlayerCharacter) -> void:
	var ia: InteractionSystem = match_node.interaction
	var ds: DownedSystem = match_node.downed
	var y: float = size.y * 0.5 + 110.0
	var text: String = ""
	var progress: float = 0.0
	if ds != null and ds.revive_candidate != null and not me.health.is_downed:
		var target: int = ds.revive_candidate.peer_id
		text = "Hold [F] to revive %s" % ds.revive_candidate.display_name
		if me.reviving:
			progress = ds.progress_of(target) / maxf(ds.revive_time_for(me.peer_id), 0.01)
			text = "Reviving %s" % ds.revive_candidate.display_name
	elif ia != null and ia.focus_text != "":
		text = ia.focus_text
		progress = ia.hold_progress if ia.focus != null and ia.focus.hold_time > 0.3 else 0.0
	if text != "":
		_text_centered(y, text, 22, Color(1, 1, 1, 0.95))
	if progress > 0.0:
		_bar(Vector2(size.x * 0.5, y + 14.0), clampf(progress, 0.0, 1.0), Color(0.9, 0.9, 0.9))
	if ia != null and Time.get_ticks_msec() / 1000.0 - ia.last_denied_time < 1.5:
		_text_centered(y + 44.0, ia.last_denied, 22, Color(0.95, 0.25, 0.2))


func _bar(center: Vector2, frac: float, col: Color) -> void:
	var w: float = 220.0
	var r: Rect2 = Rect2(center.x - w * 0.5, center.y, w, 8.0)
	draw_rect(r, Color(0, 0, 0, 0.6))
	draw_rect(Rect2(r.position, Vector2(w * frac, 8.0)), col)


func _draw_downed(me: PlayerCharacter) -> void:
	var ds: DownedSystem = match_node.downed
	if ds == null:
		return
	var st: DownedSystem.State = ds.state_of(me.peer_id)
	if st == DownedSystem.State.DOWNED:
		var left: float = float(ds.bleed_left.get(me.peer_id, 0.0))
		_text_centered(size.y * 0.5 - 120.0, "YOU ARE DOWN", 40, RED)
		_text_centered(size.y * 0.5 - 86.0, "bleeding out %.0f" % ceilf(left), 22, Color(1, 0.8, 0.8))
		var prog: float = ds.progress_of(me.peer_id)
		if prog > 0.0:
			var r: int = int(ds.revivers.get(me.peer_id, 0))
			_text_centered(size.y * 0.5 - 60.0, "Being revived", 20, Color.WHITE)
			_bar(Vector2(size.x * 0.5, size.y * 0.5 - 50.0), prog / maxf(ds.revive_time_for(r), 0.01), Color.WHITE)
	elif st == DownedSystem.State.BLED_OUT or me.spectating:
		_text_centered(60.0, "SPECTATING — you respawn next round", 24, Color(0.9, 0.9, 0.9))


func _draw_teammate_markers(me: PlayerCharacter) -> void:
	var ds: DownedSystem = match_node.downed
	var cam: Camera3D = get_viewport().get_camera_3d()
	if ds == null or cam == null:
		return
	for id: int in match_node.players.avatars:
		if id == me.peer_id or ds.state_of(id) != DownedSystem.State.DOWNED:
			continue
		var o: PlayerCharacter = match_node.players.avatars[id]
		var wp: Vector3 = o.global_position + Vector3.UP * 0.6
		var sp: Vector2 = Vector2(size.x * 0.5, size.y - 40.0)
		var local_z: float = (cam.global_transform.affine_inverse() * wp).z
		if local_z < -0.05:
			sp = cam.unproject_position(wp)
		elif local_z > 0.05:
			sp = size - cam.unproject_position(wp)  # behind: mirror, pinned to the bottom edge
			sp.y = size.y - 40.0
		sp = sp.clamp(Vector2(30, 30), size - Vector2(30, 30))
		var left: float = float(ds.bleed_left.get(id, 0.0)) / maxf(o.tuning.bleedout_time, 1.0)
		draw_circle(sp, 13.0, Color(0.8, 0.1, 0.08, 0.85))
		draw_arc(sp, 18.0, -PI * 0.5, -PI * 0.5 + TAU * left, 24, Color(1, 1, 1, 0.9), 3.0)
		draw_line(sp + Vector2(-6, 0), sp + Vector2(6, 0), Color.WHITE, 3.0)
		draw_line(sp + Vector2(0, -6), sp + Vector2(0, 6), Color.WHITE, 3.0)
		var dist: float = o.global_position.distance_to(me.global_position)
		_text(sp + Vector2(22, 6), "%s %dm" % [o.display_name, roundi(dist)], 16, Color.WHITE)
