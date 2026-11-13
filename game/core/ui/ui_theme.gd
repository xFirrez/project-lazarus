# UiTheme — the Cold War dossier look shared by every screen and the HUD (DEVELOPMENT_PLAN Step 15
# scope 1): a stencil display face (Black Ops One), a typewriter face (Special Elite) and a readable
# sans for body text (Barlow), paper / manila panels with a procedural grain, red-ink accents,
# consistent widget styles (buttons, sliders, tabs, check boxes, line edits, rebind rows), the
# colorblind-aware HUD palette, the HUD scale and small animated transitions.
# Authority: local presentation (pure helpers; the Theme is built once and cached).
class_name UiTheme
extends RefCounted

const FONT_DISPLAY: String = "res://content/ui/fonts/BlackOpsOne-Regular.ttf"
const FONT_TYPE: String = "res://content/ui/fonts/SpecialElite-Regular.ttf"
const FONT_BODY: String = "res://content/ui/fonts/Barlow-Regular.ttf"
const FONT_BODY_BOLD: String = "res://content/ui/fonts/Barlow-SemiBold.ttf"

const INK: Color = Color(0.11, 0.1, 0.09)  # typewriter ink on paper
const PAPER: Color = Color(0.86, 0.82, 0.71)
const MANILA: Color = Color(0.74, 0.66, 0.48)
const NIGHT: Color = Color(0.05, 0.06, 0.08)  # backdrop behind panels
const PANEL_DARK: Color = Color(0.09, 0.09, 0.1, 0.92)
const RED_INK: Color = Color(0.72, 0.09, 0.07)
const TEXT_LIGHT: Color = Color(0.9, 0.88, 0.82)
const TEXT_DIM: Color = Color(0.62, 0.6, 0.55)

const COLORBLIND_MODES: PackedStringArray = ["off", "deuteranopia", "protanopia", "tritanopia"]

# HUD semantic colours per colorblind mode. Red / green pairs move to orange / blue (deutan, protan)
# and blue / yellow pairs to red / teal (tritan) so gains vs. losses and hit vs. kill stay distinct.
const PALETTES: Dictionary = {
	"off":
	{
		&"danger": Color(0.85, 0.12, 0.09),
		&"gain": Color(1.0, 0.9, 0.45),
		&"loss": Color(0.95, 0.2, 0.15),
		&"ok": Color(0.45, 0.9, 0.5),
		&"info": Color(0.55, 0.8, 1.0),
		&"warn": Color(1.0, 0.75, 0.3),
		&"hit": Color(1, 1, 1),
		&"kill": Color(0.95, 0.15, 0.1),
		&"headshot": Color(1.0, 0.8, 0.2),
		&"ammo_low": Color(0.95, 0.2, 0.15),
		&"round": Color(0.78, 0.1, 0.08),
	},
	"deuteranopia":
	{
		&"danger": Color(0.95, 0.45, 0.0),
		&"gain": Color(0.4, 0.75, 1.0),
		&"loss": Color(0.95, 0.5, 0.0),
		&"ok": Color(0.3, 0.6, 1.0),
		&"info": Color(0.75, 0.85, 1.0),
		&"warn": Color(1.0, 0.85, 0.2),
		&"hit": Color(1, 1, 1),
		&"kill": Color(1.0, 0.55, 0.0),
		&"headshot": Color(0.3, 0.65, 1.0),
		&"ammo_low": Color(1.0, 0.55, 0.0),
		&"round": Color(0.85, 0.35, 0.0),
	},
	"protanopia":
	{
		&"danger": Color(1.0, 0.6, 0.0),
		&"gain": Color(0.35, 0.7, 1.0),
		&"loss": Color(1.0, 0.65, 0.05),
		&"ok": Color(0.25, 0.55, 1.0),
		&"info": Color(0.8, 0.85, 1.0),
		&"warn": Color(1.0, 0.9, 0.3),
		&"hit": Color(1, 1, 1),
		&"kill": Color(1.0, 0.7, 0.0),
		&"headshot": Color(0.35, 0.7, 1.0),
		&"ammo_low": Color(1.0, 0.7, 0.0),
		&"round": Color(0.9, 0.5, 0.0),
	},
	"tritanopia":
	{
		&"danger": Color(0.9, 0.1, 0.25),
		&"gain": Color(0.3, 0.9, 0.85),
		&"loss": Color(0.95, 0.15, 0.3),
		&"ok": Color(0.2, 0.85, 0.8),
		&"info": Color(0.95, 0.6, 0.75),
		&"warn": Color(1.0, 0.45, 0.55),
		&"hit": Color(1, 1, 1),
		&"kill": Color(0.95, 0.1, 0.25),
		&"headshot": Color(0.3, 0.95, 0.9),
		&"ammo_low": Color(0.95, 0.15, 0.3),
		&"round": Color(0.8, 0.08, 0.2),
	},
}

const HUD_SCALE_MIN: float = 0.75
const HUD_SCALE_MAX: float = 1.5
# The project stretches canvas items from a 1280 x 720 base (project.godot), so the viewport the HUD
# sees is in logical pixels (720 high for 16:9 at any physical resolution); the factor is relative to it.
const HUD_REFERENCE_HEIGHT: float = 720.0

static var _theme: Theme = null
static var _fonts: Dictionary = {}
static var _paper_tex: Texture2D = null


static func font(kind: StringName) -> Font:
	if _fonts.has(kind):
		return _fonts[kind]
	var path: String = FONT_BODY
	match kind:
		&"display":
			path = FONT_DISPLAY
		&"type":
			path = FONT_TYPE
		&"bold":
			path = FONT_BODY_BOLD
	var f: Font = load(path) as Font
	if f == null:
		f = ThemeDB.fallback_font
	_fonts[kind] = f
	return f


static func colorblind_mode() -> String:
	var m: String = String(Config.get_value(&"gameplay", &"colorblind_mode", "off"))
	return m if PALETTES.has(m) else "off"


static func color(key: StringName, mode: String = "") -> Color:
	var pal: Dictionary = PALETTES.get(mode if mode != "" else colorblind_mode(), PALETTES["off"])
	return pal.get(key, Color.WHITE)


static func hud_scale_setting() -> float:
	return clampf(float(Config.get_value(&"gameplay", &"hud_scale", 1.0)), HUD_SCALE_MIN, HUD_SCALE_MAX)


# Effective HUD scale: the user's HUD scale times the logical-height factor (canvas_items stretch
# already maps 720p..4K physical pixels; this keeps taller aspect ratios proportional).
static func hud_factor(viewport_size: Vector2, setting: float = -1.0) -> float:
	var s: float = setting if setting > 0.0 else hud_scale_setting()
	return s * clampf(viewport_size.y / HUD_REFERENCE_HEIGHT, 0.7, 2.0)


# Fits a full-rect HUD Control to its viewport at the effective scale (it then lays out in logical
# pixels: size = viewport / factor). Call every frame or on resize.
static func fit_hud(c: Control) -> void:
	var vp: Vector2 = c.get_viewport_rect().size
	var f: float = hud_factor(vp)
	c.set_anchors_preset(Control.PRESET_TOP_LEFT)
	c.position = Vector2.ZERO
	c.scale = Vector2(f, f)
	c.size = vp / f


static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t: Theme = Theme.new()
	t.default_font = font(&"body")
	t.default_font_size = 20
	# Buttons: typewritten labels on a dark tab, red ink when focused / hovered.
	t.set_font(&"font", &"Button", font(&"type"))
	t.set_font_size(&"font_size", &"Button", 22)
	t.set_color(&"font_color", &"Button", TEXT_LIGHT)
	t.set_color(&"font_hover_color", &"Button", Color(1, 1, 1))
	t.set_color(&"font_focus_color", &"Button", Color(1, 1, 1))
	t.set_color(&"font_pressed_color", &"Button", PAPER)
	t.set_color(&"font_disabled_color", &"Button", Color(0.45, 0.44, 0.42))
	t.set_stylebox(&"normal", &"Button", _box(Color(0.12, 0.12, 0.12, 0.88), Color(0.35, 0.33, 0.3), 1))
	t.set_stylebox(&"hover", &"Button", _box(Color(0.3, 0.06, 0.05, 0.95), RED_INK, 2))
	t.set_stylebox(&"pressed", &"Button", _box(Color(0.45, 0.08, 0.06, 1.0), RED_INK, 2))
	t.set_stylebox(&"focus", &"Button", _focus_box())
	t.set_stylebox(&"disabled", &"Button", _box(Color(0.1, 0.1, 0.1, 0.6), Color(0.25, 0.25, 0.25), 1))
	for cls: StringName in [&"Label", &"CheckBox", &"CheckButton", &"OptionButton", &"LineEdit", &"ItemList"]:
		t.set_font(&"font", cls, font(&"body"))
		t.set_color(&"font_color", cls, TEXT_LIGHT)
	t.set_font_size(&"font_size", &"Label", 20)
	t.set_color(&"font_outline_color", &"Label", Color(0, 0, 0, 0.85))
	for cls: StringName in [&"OptionButton", &"CheckBox", &"CheckButton"]:
		t.set_stylebox(&"normal", cls, _box(Color(0.12, 0.12, 0.12, 0.88), Color(0.35, 0.33, 0.3), 1))
		t.set_stylebox(&"hover", cls, _box(Color(0.22, 0.08, 0.07, 0.95), RED_INK, 1))
		t.set_stylebox(&"pressed", cls, _box(Color(0.3, 0.08, 0.06, 1.0), RED_INK, 1))
		t.set_stylebox(&"focus", cls, _focus_box())
		t.set_color(&"font_hover_color", cls, Color(1, 1, 1))
		t.set_color(&"font_focus_color", cls, Color(1, 1, 1))
		t.set_color(&"font_pressed_color", cls, PAPER)
	t.set_stylebox(&"normal", &"LineEdit", _box(Color(0.08, 0.08, 0.08, 0.9), Color(0.4, 0.38, 0.33), 1))
	t.set_stylebox(&"focus", &"LineEdit", _focus_box())
	t.set_stylebox(&"panel", &"ItemList", _box(Color(0.08, 0.08, 0.08, 0.85), Color(0.35, 0.33, 0.3), 1))
	t.set_stylebox(&"focus", &"ItemList", _focus_box())
	t.set_color(&"font_selected_color", &"ItemList", Color(1, 1, 1))
	t.set_stylebox(&"selected", &"ItemList", _box(Color(0.45, 0.08, 0.06, 0.9), RED_INK, 0))
	t.set_stylebox(&"selected_focus", &"ItemList", _box(Color(0.55, 0.1, 0.07, 1.0), RED_INK, 1))
	# Sliders: a thin inked rule with a red stamp grabber.
	var rule: StyleBoxFlat = _box(Color(0.3, 0.28, 0.25), Color(0, 0, 0, 0), 0)
	rule.content_margin_top = 3
	rule.content_margin_bottom = 3
	t.set_stylebox(&"slider", &"HSlider", rule)
	var fill: StyleBoxFlat = _box(RED_INK, Color(0, 0, 0, 0), 0)
	fill.content_margin_top = 3
	fill.content_margin_bottom = 3
	t.set_stylebox(&"grabber_area", &"HSlider", fill)
	t.set_stylebox(&"grabber_area_highlight", &"HSlider", fill)
	t.set_stylebox(&"focus", &"HSlider", _focus_box())
	# Tabs: manila folder tabs.
	t.set_font(&"font", &"TabBar", font(&"type"))
	t.set_font(&"font", &"TabContainer", font(&"type"))
	t.set_font_size(&"font_size", &"TabContainer", 20)
	t.set_color(&"font_selected_color", &"TabContainer", INK)
	t.set_color(&"font_unselected_color", &"TabContainer", TEXT_DIM)
	t.set_color(&"font_hovered_color", &"TabContainer", TEXT_LIGHT)
	t.set_stylebox(&"tab_selected", &"TabContainer", _box(MANILA, Color(0.4, 0.33, 0.2), 1, 4))
	t.set_stylebox(&"tab_unselected", &"TabContainer", _box(Color(0.16, 0.15, 0.13, 0.9), Color(0.3, 0.28, 0.24), 1, 4))
	t.set_stylebox(&"tab_hovered", &"TabContainer", _box(Color(0.3, 0.08, 0.06, 0.95), RED_INK, 1, 4))
	t.set_stylebox(&"tab_focus", &"TabContainer", _focus_box())
	t.set_stylebox(&"panel", &"TabContainer", _box(Color(0.1, 0.1, 0.1, 0.9), Color(0.4, 0.33, 0.2), 2))
	t.set_stylebox(&"panel", &"PanelContainer", paper_box())
	t.set_stylebox(&"panel", &"Panel", _box(PANEL_DARK, Color(0.3, 0.28, 0.24), 1))
	t.set_color(&"font_color", &"TooltipLabel", INK)
	t.set_stylebox(&"panel", &"TooltipPanel", _box(PAPER, INK, 1))
	_theme = t
	return t


# Applies the theme to a top-level Control (screens live under CanvasLayers, which break theme
# inheritance from the root window).
static func apply(c: Control) -> void:
	c.theme = theme()


static func _box(bg: Color, border: Color, border_w: int, radius: int = 2) -> StyleBoxFlat:
	var s: StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	return s


static func _focus_box() -> StyleBoxFlat:
	# Keyboard / gamepad focus: a red-ink frame drawn over the widget (never invisible).
	var s: StyleBoxFlat = StyleBoxFlat.new()
	s.draw_center = false
	s.border_color = Color(0.95, 0.2, 0.12)
	s.set_border_width_all(2)
	s.set_corner_radius_all(2)
	s.expand_margin_left = 3
	s.expand_margin_right = 3
	s.expand_margin_top = 2
	s.expand_margin_bottom = 2
	return s


# Dossier paper: a textured StyleBox (procedural grain + foxing) with a darker edge.
static func paper_box(tint: Color = PAPER) -> StyleBoxTexture:
	var s: StyleBoxTexture = StyleBoxTexture.new()
	s.texture = paper_texture()
	s.modulate_color = Color(tint.r / PAPER.r, tint.g / PAPER.g, tint.b / PAPER.b, tint.a)
	s.texture_margin_left = 6
	s.texture_margin_right = 6
	s.texture_margin_top = 6
	s.texture_margin_bottom = 6
	s.content_margin_left = 28
	s.content_margin_right = 28
	s.content_margin_top = 22
	s.content_margin_bottom = 22
	s.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	s.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	return s


static func paper_texture() -> Texture2D:
	if _paper_tex != null:
		return _paper_tex
	var n: int = 256
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGBA8)
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = 1957
	noise.frequency = 0.035
	var fine: FastNoiseLite = FastNoiseLite.new()
	fine.seed = 1962
	fine.frequency = 0.6
	for y: int in n:
		for x: int in n:
			var g: float = noise.get_noise_2d(x, y) * 0.06 + fine.get_noise_2d(x, y) * 0.035
			var edge: float = minf(minf(x, n - 1 - x), minf(y, n - 1 - y))
			var burn: float = clampf(1.0 - edge / 6.0, 0.0, 1.0) * 0.35
			var c: Color = PAPER * (1.0 + g - burn)
			c.a = 1.0
			img.set_pixel(x, y, c)
	_paper_tex = ImageTexture.create_from_image(img)
	return _paper_tex


# --- widgets -------------------------------------------------------------------------------------


static func title_label(text: String, font_size: int = 48, col: Color = RED_INK) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_override(&"font", font(&"display"))
	l.add_theme_font_size_override(&"font_size", font_size)
	l.add_theme_color_override(&"font_color", col)
	l.add_theme_color_override(&"font_outline_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override(&"outline_size", 4)
	return l


static func type_label(text: String, font_size: int = 18, col: Color = TEXT_DIM) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_override(&"font", font(&"type"))
	l.add_theme_font_size_override(&"font_size", font_size)
	l.add_theme_color_override(&"font_color", col)
	return l


static func button(text: String, on_press: Callable, min_height: float = 44.0) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, min_height)
	b.focus_mode = Control.FOCUS_ALL
	b.pressed.connect(func() -> void: Audio.play_event(&"ui_click"))
	b.pressed.connect(on_press)
	b.focus_entered.connect(func() -> void: Audio.play_event(&"ui_focus"))
	return b


# A full-screen backdrop: night colour, a red-ink vignette and a slow film grain.
static func backdrop(alpha: float = 1.0) -> Control:
	var bd: UiBackdrop = UiBackdrop.new()
	bd.alpha = alpha
	return bd


# Screen intro: fade + a short upward slide of `c` (the content, not the backdrop).
static func intro(c: Control, delay: float = 0.0) -> void:
	if not c.is_inside_tree():
		return
	c.modulate.a = 0.0
	var tw: Tween = c.create_tween()
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_interval(delay)
	tw.tween_property(c, ^"modulate:a", 1.0, 0.28)


# Gives keyboard / gamepad focus to the first focusable descendant (every screen calls this so the
# pad can drive the menus without a mouse).
static func focus_first(root: Node) -> Control:
	for n: Node in root.find_children("*", "Control", true, false):
		var c: Control = n as Control
		if c.focus_mode == Control.FOCUS_ALL and c.is_visible_in_tree() and not _disabled(c):
			c.grab_focus.call_deferred()
			return c
	return null


static func _disabled(c: Control) -> bool:
	return c is BaseButton and (c as BaseButton).disabled
