# MatchHud — HUD v1 for the survival loop (GAME_DESIGN §15; final art in Step 15): round counter
# (red tally strokes for rounds 1-5, then numerals; pulses on round change), round banner, own and
# teammates' points with floating gains / deductions, interaction prompts with hold progress,
# refusal feedback, downed / bleedout / revive progress, spectating notice and teammate downed
# markers (screen-space, clamped to the edges when off-screen). Step 10: Vigor Tonic bottle caps
# in acquisition order (bottom left, above the round), the drink progress, Second Wind self-revive,
# active power-ups with circular countdowns (bottom centre), the announcer caption and the Nuke
# white flash. Ammo, lethals, hit markers and the damage vignette are the WeaponHud / DamageHud.
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
	_draw_perks(me)
	_draw_powerups()
	_draw_prompt(me)
	_draw_downed(me)
	_draw_teammate_markers(me)
	_draw_pings(me)
	_draw_session_notice()


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


# "Name (Character)" for prompts, e.g. "Hold [F] to revive Ann (Brandt)" (GAME_DESIGN §15).
static func _who(p: PlayerCharacter) -> String:
	if p.character != null and p.character.display_name != p.display_name:
		return "%s (%s)" % [p.display_name, p.character.display_name]
	return p.display_name


func _player_color(peer_id: int) -> Color:
	var p: PlayerCharacter = match_node.players.avatars.get(peer_id, null)
	return p.player_color() if p != null else Color.WHITE


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
		var who: String = _who(ds.revive_candidate)
		text = "Hold [F] to revive %s" % who
		if me.reviving:
			progress = ds.progress_of(target) / maxf(ds.revive_time_for(me.peer_id), 0.01)
			text = "Reviving %s" % who
	elif ia != null and ia.focus_text != "":
		text = ia.focus_text
		progress = ia.hold_progress if ia.focus != null and ia.focus.hold_time > 0.3 else 0.0
	if text != "":
		_text_centered(y, text, 22, Color(1, 1, 1, 0.95))
	if progress > 0.0:
		_bar(Vector2(size.x * 0.5, y + 14.0), clampf(progress, 0.0, 1.0), Color(0.9, 0.9, 0.9))
	if ia != null and Time.get_ticks_msec() / 1000.0 - ia.last_denied_time < 1.5:
		_text_centered(y + 44.0, ia.last_denied, 22, Color(0.95, 0.25, 0.2))


# Bottle caps (coloured disc, serrated rim, letter) in acquisition order, plus the drink bar.
func _draw_perks(me: PlayerCharacter) -> void:
	var ids: Array[StringName] = me.perk_holder.ids
	var base: Vector2 = Vector2(58.0, size.y - 150.0)
	for i: int in ids.size():
		var d: PerkDefinition = PerkCatalog.get_def(ids[i])
		if d == null:
			continue
		var c: Vector2 = base + Vector2(i * 46.0, 0.0)
		for k: int in 21:  # crimped rim
			var a: float = TAU * k / 21.0
			draw_circle(c + Vector2(cos(a), sin(a)) * 19.0, 3.2, d.color.darkened(0.35))
		draw_circle(c, 19.0, d.color)
		draw_arc(c, 13.0, 0.0, TAU, 24, d.color.lightened(0.4), 2.0)
		var w: float = _font.get_string_size(d.cap_letter, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		draw_string(
			_font, c + Vector2(-w * 0.5, 7.0), d.cap_letter, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.08, 0.06, 0.05)
		)
	if me.weapons != null and me.weapons.is_drinking() and me.weapons.drinking_def != null:
		var dd: PerkDefinition = me.weapons.drinking_def
		var frac: float = 1.0 - me.weapons.drink_left / PerkSystem.DRINK_TIME
		_text_centered(size.y * 0.5 + 170.0, dd.display_name, 20, dd.color)
		_bar(Vector2(size.x * 0.5, size.y * 0.5 + 180.0), clampf(frac, 0.0, 1.0), dd.color)


# Active timed power-ups (icon disc + circular countdown), the announcer caption and the flash.
func _draw_powerups() -> void:
	var pu: PowerUpSystem = match_node.powerups
	if pu == null:
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	var active: Array[StringName] = []
	for t: StringName in PowerUpSystem.TIMED:
		if pu.is_active(t):
			active.append(t)
	var x0: float = size.x * 0.5 - (active.size() - 1) * 36.0
	for i: int in active.size():
		var c: Vector2 = Vector2(x0 + i * 72.0, size.y - 110.0)
		var left: float = pu.time_left(active[i])
		var frac: float = clampf(left / pu.rules.timed_duration, 0.0, 1.0)
		var blink: bool = left < 5.0 and fmod(left * 3.0, 1.0) < 0.4
		var gold: Color = PowerUpDrop.GOLD if not blink else PowerUpDrop.GOLD * Color(1, 1, 1, 0.3)
		draw_circle(c, 26.0, Color(0, 0, 0, 0.55))
		draw_arc(c, 28.0, -PI * 0.5, -PI * 0.5 + TAU * frac, 40, PowerUpDrop.GLOW, 4.0)
		var label: String = _short(active[i])
		var w: float = _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		draw_string(_font, c + Vector2(-w * 0.5, 6.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, gold)
		var secs: String = "%d" % ceili(left)
		var sw: float = _font.get_string_size(secs, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		draw_string(_font, c + Vector2(-sw * 0.5, 44.0), secs, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.8))
	var age: float = now - pu.announce_at
	if age < 2.5 and pu.last_announce != &"":
		var a: float = clampf(minf(age * 4.0, (2.5 - age) * 2.0), 0.0, 1.0)
		var text: String = String(PowerUpSystem.NAMES.get(pu.last_announce, String(pu.last_announce)))
		_text_centered(
			size.y * 0.2, text + "!", 44, Color(PowerUpDrop.GOLD.r, PowerUpDrop.GOLD.g, PowerUpDrop.GOLD.b, a)
		)
	var fa: float = now - pu.flash_at
	if fa < PowerUpSystem.FLASH_TIME:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.85 * (1.0 - fa / PowerUpSystem.FLASH_TIME)))


static func _short(t: StringName) -> String:
	match t:
		&"insta_kill":
			return "IK"
		&"double_points":
			return "x2"
		&"fire_sale":
			return "SALE"
	return "?"


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
	if st == DownedSystem.State.DOWNED and ds.is_self_reviving(me.peer_id):
		var sl: float = float(ds.bleed_left.get(me.peer_id, 0.0))
		_text_centered(size.y * 0.5 - 120.0, "SECOND WIND", 40, Color(0.45, 0.8, 1.0))
		_text_centered(size.y * 0.5 - 86.0, "back on your feet in %.0f" % ceilf(sl), 22, Color(0.85, 0.95, 1.0))
		var f: float = 1.0 - sl / DownedSystem.SELF_REVIVE_TIME
		_bar(Vector2(size.x * 0.5, size.y * 0.5 - 70.0), clampf(f, 0.0, 1.0), Color(0.45, 0.8, 1.0))
	elif st == DownedSystem.State.DOWNED:
		var left: float = float(ds.bleed_left.get(me.peer_id, 0.0))
		_text_centered(size.y * 0.5 - 120.0, "YOU ARE DOWN", 40, RED)
		_text_centered(size.y * 0.5 - 86.0, "bleeding out %.0f" % ceilf(left), 22, Color(1, 0.8, 0.8))
		var prog: float = ds.progress_of(me.peer_id)
		if prog > 0.0:
			var r: int = int(ds.revivers.get(me.peer_id, 0))
			_text_centered(size.y * 0.5 - 60.0, "Being revived", 20, Color.WHITE)
			_bar(Vector2(size.x * 0.5, size.y * 0.5 - 50.0), prog / maxf(ds.revive_time_for(r), 0.01), Color.WHITE)
	elif st == DownedSystem.State.WAITING:
		_text_centered(60.0, "SPECTATING — you join the fight at the next round", 24, Color(0.9, 0.9, 0.9))
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
		var sp: Vector2 = _edge_point(cam, o.global_position + Vector3.UP * 0.6)
		var left: float = float(ds.bleed_left.get(id, 0.0)) / maxf(o.tuning.bleedout_time, 1.0)
		draw_circle(sp, 13.0, Color(0.8, 0.1, 0.08, 0.85))
		draw_arc(sp, 22.0, 0.0, TAU, 24, o.player_color(), 2.0)
		draw_arc(sp, 18.0, -PI * 0.5, -PI * 0.5 + TAU * left, 24, Color(1, 1, 1, 0.9), 3.0)
		draw_line(sp + Vector2(-6, 0), sp + Vector2(6, 0), Color.WHITE, 3.0)
		draw_line(sp + Vector2(0, -6), sp + Vector2(0, 6), Color.WHITE, 3.0)
		var dist: float = o.global_position.distance_to(me.global_position)
		_text(sp + Vector2(22, 6), "%s %dm" % [o.display_name, roundi(dist)], 16, Color.WHITE)


# Screen point of a world position, clamped to the screen edges (behind the camera: mirrored and
# pinned to the bottom edge) — off-screen indicators for downed teammates and pings.
func _edge_point(cam: Camera3D, wp: Vector3) -> Vector2:
	var sp: Vector2 = Vector2(size.x * 0.5, size.y - 40.0)
	var local_z: float = (cam.global_transform.affine_inverse() * wp).z
	if local_z < -0.05:
		sp = cam.unproject_position(wp)
	elif local_z > 0.05:
		sp = size - cam.unproject_position(wp)
		sp.y = size.y - 40.0
	return sp.clamp(Vector2(30, 30), size - Vector2(30, 30))


func _on_screen(cam: Camera3D, wp: Vector3) -> bool:
	if (cam.global_transform.affine_inverse() * wp).z >= -0.05:
		return false
	return Rect2(Vector2.ZERO, size).has_point(cam.unproject_position(wp))


# Off-screen pings: a coloured diamond at the edge with the label and distance.
func _draw_pings(me: PlayerCharacter) -> void:
	var ps: PingSystem = match_node.pings
	var cam: Camera3D = get_viewport().get_camera_3d()
	if ps == null or cam == null:
		return
	for peer: int in ps.active:
		var a: Dictionary = ps.active[peer]
		var wp: Vector3 = a["pos"]
		var who: PlayerCharacter = match_node.players.avatars.get(peer, null)
		var col: Color = who.player_color() if who != null else Color.WHITE
		var dist: int = roundi(wp.distance_to(me.global_position))
		if _on_screen(cam, wp):
			_text(cam.unproject_position(wp) + Vector2(14, 22), "%dm" % dist, 15, col)
			continue
		var sp: Vector2 = _edge_point(cam, wp)
		var pts: PackedVector2Array = [
			sp + Vector2(0, -10), sp + Vector2(10, 0), sp + Vector2(0, 10), sp + Vector2(-10, 0)
		]
		draw_colored_polygon(pts, col)
		_text(
			sp + Vector2(14, 6), "%s %dm" % [String(a["label"]) if String(a["label"]) != "" else "ping", dist], 15, col
		)


func _draw_session_notice() -> void:
	var ms: MatchSession = match_node.session
	var rd: RoundDirector = match_node.rounds
	if ms == null or rd == null or not rd.enabled or rd.phase != RoundDirector.Phase.WAITING:
		return
	_text_centered(size.y * 0.3, "Waiting for all players to load ...", 28, Color(0.9, 0.9, 0.9))
