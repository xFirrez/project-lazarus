# CreditsScreen — the credits dossier (DEVELOPMENT_PLAN Step 15 scope 8, AC-15.5): the game credits
# and every third-party asset with author, license and source, read from
# `content/ui/credits.json` (generated from docs/ASSET_LICENSES.md by tools/gen_credits.py).
# Authority: local presentation.
class_name CreditsScreen
extends UiScreen

const CREDITS_PATH: String = "res://content/ui/credits.json"

var entries_shown: int = 0


static func load_credits() -> Dictionary:
	var f: FileAccess = FileAccess.open(CREDITS_PATH, FileAccess.READ)
	if f == null:
		return {}
	var d: Variant = JSON.parse_string(f.get_as_text())
	return d if d is Dictionary else {}


func _init() -> void:
	screen_title = "CREDITS"
	content_width = 900.0


func _build(c: VBoxContainer) -> void:
	var data: Dictionary = load_credits()
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(900, 520)
	c.add_child(panel)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.focus_mode = Control.FOCUS_ALL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var col: VBoxContainer = VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override(&"separation", 6)
	scroll.add_child(col)
	for pair: Variant in data.get("game", []):
		var p: Array = pair
		col.add_child(_ink(String(p[0]), 22 if String(p[1]) == "" else 18, true))
		if String(p[1]) != "":
			col.add_child(_ink(String(p[1]), 18, false))
	col.add_child(_ink("", 10, false))
	col.add_child(_ink("THIRD-PARTY ASSETS & TOOLS", 22, true))
	for e: Variant in data.get("third_party", []):
		var d: Dictionary = e
		col.add_child(_ink(String(d.get("what", "")), 18, true))
		col.add_child(_ink("%s — %s\n%s" % [d.get("author", ""), d.get("license", ""), d.get("source", "")], 15, false))
		entries_shown += 1
	col.add_child(_ink("", 10, false))
	col.add_child(_ink(String(data.get("in_house", "")), 15, false))
	var back_b: Button = UiTheme.button("Back", back)
	back_b.name = "BackButton"
	c.add_child(back_b)
	# Gamepad: scroll with up / down while the scroll box has focus.
	scroll.gui_input.connect(
		func(ev: InputEvent) -> void:
			var bar: VScrollBar = scroll.get_v_scroll_bar()
			if ev.is_action_pressed(&"ui_down") and bar.value < bar.max_value - bar.page:
				scroll.scroll_vertical += 60
				scroll.accept_event()
			elif ev.is_action_pressed(&"ui_up") and bar.value > 0.0:
				scroll.scroll_vertical -= 60
				scroll.accept_event()
	)


func _ink(text: String, font_size: int, strong: bool) -> Label:
	var l: Label = UiTheme.type_label(text, font_size, UiTheme.RED_INK if strong else UiTheme.INK)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(820, 0)
	return l
