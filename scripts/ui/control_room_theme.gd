class_name ControlRoomTheme
extends RefCounted

const GAP_SMALL: int = 8
const GAP_MEDIUM: int = 14
const GAP_LARGE: int = 24
const PANEL_PADDING: int = 22
const BUTTON_HEIGHT: int = 68
const BUTTON_WIDTH: int = 318

const COLOR_BG := Color(0.015, 0.018, 0.016, 0.9)
const COLOR_PANEL := Color(0.025, 0.034, 0.028, 0.94)
const COLOR_PANEL_DEEP := Color(0.006, 0.01, 0.008, 0.96)
const COLOR_TEXT := Color(0.96, 0.95, 0.86, 1.0)
const COLOR_MUTED := Color(0.72, 0.75, 0.64, 1.0)
const COLOR_GREEN := Color(0.72, 0.95, 0.2, 1.0)
const COLOR_BLUE := Color(0.28, 0.78, 1.0, 1.0)
const COLOR_ORANGE := Color(1.0, 0.48, 0.08, 1.0)
const COLOR_PURPLE := Color(0.72, 0.38, 1.0, 1.0)
const COLOR_RED := Color(1.0, 0.25, 0.18, 1.0)
const COLOR_METAL := Color(0.09, 0.105, 0.095, 1.0)
const COLOR_METAL_HIGHLIGHT := Color(0.16, 0.18, 0.16, 1.0)

static func apply_panel(panel: PanelContainer, accent: Color = COLOR_ORANGE, fill_color: Color = COLOR_PANEL) -> void:
	if panel == null:
		return
	panel.add_theme_stylebox_override("panel", panel_style(accent, fill_color, 2))

static func apply_option(option: OptionButton, accent: Color = COLOR_BLUE, font_size: int = 18) -> void:
	if option == null:
		return
	apply_button(option, COLOR_METAL, COLOR_METAL_HIGHLIGHT, accent, font_size)

static func apply_slider(slider: Range, accent: Color = COLOR_GREEN) -> void:
	if slider == null:
		return
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.035, 0.045, 0.038, 1.0)
	track.border_color = Color(0.22, 0.28, 0.23, 1.0)
	track.border_width_top = 1
	track.border_width_bottom = 1
	track.corner_radius_top_left = 3
	track.corner_radius_top_right = 3
	track.corner_radius_bottom_left = 3
	track.corner_radius_bottom_right = 3
	var fill := StyleBoxFlat.new()
	fill.bg_color = accent.darkened(0.18)
	fill.corner_radius_top_left = 3
	fill.corner_radius_top_right = 3
	fill.corner_radius_bottom_left = 3
	fill.corner_radius_bottom_right = 3
	slider.add_theme_stylebox_override("slider", track)
	slider.add_theme_stylebox_override("grabber_area", fill)

static func apply_section_header(label: Label, accent: Color = COLOR_GREEN) -> void:
	if label == null:
		return
	apply_label(label, 24, accent)
	label.add_theme_constant_override("outline_size", 1)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))

static func panel_style(border_color: Color = COLOR_ORANGE, fill_color: Color = COLOR_PANEL, border_width: int = 2) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill_color
	style.border_color = border_color
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.62)
	style.shadow_size = 12
	style.shadow_offset = Vector2(0, 6)
	style.content_margin_left = 4
	style.content_margin_top = 4
	style.content_margin_right = 4
	style.content_margin_bottom = 4
	return style

static func button_style(base_color: Color, border_color: Color, pressed: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = base_color
	style.border_color = border_color
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 5 if not pressed else 2
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_right = 4
	style.corner_radius_bottom_left = 4
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.48)
	style.shadow_size = 8 if not pressed else 3
	style.shadow_offset = Vector2(0, 5 if not pressed else 1)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style

static func apply_button(button: BaseButton, base_color: Color, hover_color: Color, border_color: Color, font_size: int = 25) -> void:
	button.add_theme_stylebox_override("normal", button_style(base_color, border_color))
	button.add_theme_stylebox_override("hover", button_style(hover_color, border_color))
	button.add_theme_stylebox_override("pressed", button_style(base_color.darkened(0.15), border_color, true))
	button.add_theme_stylebox_override("disabled", button_style(Color(0.08, 0.08, 0.07, 0.74), Color(0.25, 0.25, 0.22, 1.0)))
	button.add_theme_color_override("font_color", COLOR_TEXT)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color(0.52, 0.52, 0.46, 1.0))
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_constant_override("outline_size", 1)
	button.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.focus_mode = Control.FOCUS_ALL

static func apply_label(label: Label, font_size: int, color: Color = COLOR_TEXT) -> void:
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
