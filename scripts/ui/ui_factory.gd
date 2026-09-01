class_name UIFactory
extends RefCounted

const INK := Color("#080b17")
const PANEL := Color("#11182b")
const PANEL_LIGHT := Color("#1b2843")
const TEXT := Color("#edf3ff")
const MUTED := Color("#93a5c8")
const CRIMSON := Color("#eb3f67")
const VIOLET := Color("#9b5cff")
const GOLD := Color("#ffc857")
const CYAN := Color("#52d8ff")

static func game_theme() -> Theme:
	var theme := Theme.new()
	theme.default_base_scale = float(Game.settings.get("ui_scale", 1.0))
	var regular := SystemFont.new()
	regular.font_names = PackedStringArray(["Avenir Next", "Bahnschrift", "Trebuchet MS", "Arial"])
	regular.font_weight = 600
	var heading := SystemFont.new()
	heading.font_names = PackedStringArray(["Avenir Next Condensed", "Bahnschrift Condensed", "Trebuchet MS"])
	heading.font_weight = 800
	theme.default_font = regular
	theme.default_font_size = 22
	theme.set_font("font", "Button", heading)
	theme.set_font_size("font_size", "Button", 24)
	theme.set_color("font_color", "Label", TEXT)
	theme.set_color("font_color", "Button", TEXT)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_pressed_color", "Button", Color.WHITE)
	theme.set_color("font_disabled_color", "Button", Color("#52617d"))
	theme.set_color("font_color", "OptionButton", TEXT)
	theme.set_color("font_color", "CheckButton", TEXT)
	theme.set_stylebox("normal", "Button", panel_style(PANEL, Color("#31405f"), 2, 8))
	theme.set_stylebox("hover", "Button", panel_style(Color("#26385c"), VIOLET, 2, 8))
	theme.set_stylebox("pressed", "Button", panel_style(Color("#3a1f4f"), CRIMSON, 2, 8))
	theme.set_stylebox("disabled", "Button", panel_style(Color("#111727"), Color("#202a40"), 1, 8))
	theme.set_stylebox("normal", "PanelContainer", panel_style(Color(0.045, 0.065, 0.12, 0.94), Color("#35466d"), 2, 10))
	theme.set_stylebox("panel", "Panel", panel_style(Color(0.035, 0.05, 0.09, 0.92), Color("#293958"), 1, 8))
	theme.set_stylebox("normal", "LineEdit", panel_style(INK, Color("#35466d"), 2, 6))
	return theme

static func panel_style(fill: Color, border: Color, width := 1, radius := 6) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	return style

static func label(text: String, size := 22, color := TEXT, alignment := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var control := Label.new()
	control.text = text
	control.add_theme_font_size_override("font_size", size)
	control.add_theme_color_override("font_color", color)
	control.horizontal_alignment = alignment
	control.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return control

static func heading(text: String, size := 40, color := TEXT) -> Label:
	var control := label(text, size, color, HORIZONTAL_ALIGNMENT_CENTER)
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Avenir Next Condensed", "Bahnschrift Condensed", "Trebuchet MS"])
	font.font_weight = 900
	control.add_theme_font_override("font", font)
	control.add_theme_constant_override("outline_size", maxi(2, int(size / 14.0)))
	control.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.05, 0.9))
	return control

static func button(text: String, min_size := Vector2(330, 58)) -> Button:
	var control := Button.new()
	control.text = text
	control.custom_minimum_size = min_size
	control.focus_mode = Control.FOCUS_ALL
	control.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	control.mouse_entered.connect(func(): AudioManager.play_sfx("ui", 1.25, -8.0))
	return control

static func spacer(height: float) -> Control:
	var control := Control.new()
	control.custom_minimum_size.y = height
	return control

static func margin(child: Control, amount := 32) -> MarginContainer:
	var container := MarginContainer.new()
	container.add_theme_constant_override("margin_left", amount)
	container.add_theme_constant_override("margin_right", amount)
	container.add_theme_constant_override("margin_top", amount)
	container.add_theme_constant_override("margin_bottom", amount)
	container.add_child(child)
	return container
