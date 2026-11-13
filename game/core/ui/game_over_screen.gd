# GameOverScreen — the final game-over dossier (GAME_DESIGN §15, DEVELOPMENT_PLAN Step 15 scope 5):
# "YOU SURVIVED N ROUNDS" stamped in red, the per-player table (kills, headshots, downs, revives,
# points earned, doors, perks drunk, box spins), time played and Easter-egg progress, the local best
# round for this player count (highlighted "NEW RECORD" when beaten), and "Play Again" (host:
# everyone back to the lobby; solo: a new run) / "Main menu". Rows come from the host's
# PointsLedger summary in the `_game_over` event, so every peer shows the same numbers; the slow-
# motion fade before it is DownedSystem._present_game_over.
# Authority: local presentation.
class_name GameOverScreen
extends UiScreen

signal menu_pressed
signal lobby_pressed

const COLUMNS: Array[String] = [
	"kills", "headshots", "downs", "revives", "points_earned", "doors", "perks", "box_spins"
]
const HEADERS: Array[String] = ["Survivor", "Kills", "Heads", "Downs", "Revives", "Points", "Doors", "Tonics", "Box"]

var round_reached: int = 1
var rows: Array = []
var local_peer: int = 1
var subtitle: String = ""  # e.g. "The host left the game"
var show_lobby_button: bool = false  # host of a session: "Play again" (back to the lobby)
var lobby_button_text: String = "Play again"
var info: Dictionary = {}  # Game.last_match_info: seconds, quest, map, players
var new_best: bool = false
var best_round: int = 0


static func title_for(r: int) -> String:
	return "YOU SURVIVED %d ROUND%s" % [r, "" if r == 1 else "S"]


static func time_text(seconds: float) -> String:
	var s: int = int(seconds)
	return "%d:%02d:%02d" % [s / 3600, (s / 60) % 60, s % 60] if s >= 3600 else "%d:%02d" % [s / 60, s % 60]


func _init() -> void:
	content_width = 1040.0
	backdrop_alpha = 0.9
	has_back = false


func _build(c: VBoxContainer) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var title: Label = UiTheme.title_label(title_for(round_reached), 62)
	title.name = "Title"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_child(title)
	if subtitle != "":
		var sub: Label = UiTheme.type_label(subtitle, 22, UiTheme.TEXT_LIGHT)
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		c.add_child(sub)
	var rec: Label = UiTheme.type_label(_record_line(), 22, Color(1.0, 0.82, 0.3) if new_best else UiTheme.TEXT_DIM)
	rec.name = "Record"
	rec.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_child(rec)
	if new_best:
		var tw: Tween = rec.create_tween().set_loops(4)
		tw.tween_property(rec, ^"modulate", Color(1.6, 1.4, 1.0), 0.35)
		tw.tween_property(rec, ^"modulate", Color.WHITE, 0.35)
	var paper: PanelContainer = PanelContainer.new()
	c.add_child(paper)
	var grid: GridContainer = GridContainer.new()
	grid.name = "Table"
	grid.columns = HEADERS.size()
	grid.add_theme_constant_override(&"h_separation", 26)
	grid.add_theme_constant_override(&"v_separation", 6)
	paper.add_child(grid)
	for h: String in HEADERS:
		grid.add_child(_cell(h, UiTheme.RED_INK, 18, true))
	for r: Variant in rows:
		var row: Dictionary = r
		var col: Color = UiTheme.INK
		var cdef: CharacterDefinition = CharacterDefinition.get_def(StringName(String(row.get("character", ""))))
		var who: String = String(row.get("name", "?"))
		if int(row.get("peer", 0)) == local_peer:
			who = "▶ " + who
		var name_cell: Label = _cell(who, cdef.color.darkened(0.6) if cdef != null else col, 20, true)
		grid.add_child(name_cell)
		for k: String in COLUMNS:
			grid.add_child(_cell(str(int(row.get(k, 0))), col, 20, false))
	var foot: PackedStringArray = []
	if info.has("seconds"):
		foot.append("Time played %s" % time_text(float(info["seconds"])))
	if String(info.get("quest", "")) != "":
		foot.append("Easter egg: %s" % String(info["quest"]))
	if not foot.is_empty():
		var f: Label = UiTheme.type_label("   ·   ".join(foot), 18, UiTheme.TEXT_LIGHT)
		f.name = "Footer"
		f.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		c.add_child(f)
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override(&"separation", 16)
	c.add_child(buttons)
	if show_lobby_button:
		var lb: Button = UiTheme.button(lobby_button_text, func() -> void: lobby_pressed.emit())
		lb.name = "LobbyButton"
		lb.custom_minimum_size = Vector2(240, 48)
		buttons.add_child(lb)
	var b: Button = UiTheme.button("Main menu", func() -> void: menu_pressed.emit())
	b.name = "MenuButton"
	b.custom_minimum_size = Vector2(240, 48)
	buttons.add_child(b)
	Audio.play_event(&"game_over_sting")
	# Stamp the title in: big and transparent -> normal size.
	title.pivot_offset = Vector2(content_width * 0.5, 36)
	title.scale = Vector2(1.4, 1.4)
	var st: Tween = title.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	st.tween_property(title, ^"scale", Vector2.ONE, 0.45)


func _record_line() -> String:
	var n: int = maxi(int(info.get("players", rows.size())), 1)
	if new_best:
		return "NEW RECORD — best round with %d player%s" % [n, "" if n == 1 else "s"]
	if best_round > 0:
		return "Best with %d player%s: round %d" % [n, "" if n == 1 else "s", best_round]
	return ""


func _cell(text: String, color: Color, font_size: int, strong: bool) -> Label:
	var l: Label = UiTheme.type_label(text, font_size, color)
	if strong:
		l.add_theme_font_override(&"font", UiTheme.font(&"bold"))
	return l
