class_name BroadcastHudStyle
extends RefCounted

static func apply_header(label: Label, face_color: Color) -> void:
	label.add_theme_font_size_override("font_size", 30)
	label.add_theme_color_override("font_color", face_color)
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.02, 1))
	label.add_theme_constant_override("outline_size", 10)
	label.add_theme_color_override("font_shadow_color", face_color.darkened(0.62))
	label.add_theme_constant_override("shadow_offset_x", 3)
	label.add_theme_constant_override("shadow_offset_y", 4)

static func apply_body(label: Label, color: Color = Color(0.94, 0.96, 0.88, 1)) -> void:
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.92))
	label.add_theme_constant_override("outline_size", 5)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.45))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 2)

static func apply_command(label: Label) -> void:
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color(1, 0.78, 0.28, 1))
	label.add_theme_color_override("font_outline_color", Color(0.04, 0.02, 0.01, 1))
	label.add_theme_constant_override("outline_size", 8)
	label.add_theme_color_override("font_shadow_color", Color(1, 0.55, 0.08, 0.35))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 3)

static func apply_countdown(label: Label) -> void:
	label.add_theme_font_size_override("font_size", 118)
	label.add_theme_color_override("font_color", Color(1, 0.78, 0.12, 1))
	label.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.01, 1))
	label.add_theme_constant_override("outline_size", 14)
	label.add_theme_color_override("font_shadow_color", Color(1, 0.45, 0.05, 0.4))
	label.add_theme_constant_override("shadow_offset_x", 4)
	label.add_theme_constant_override("shadow_offset_y", 5)
