class_name ChatActivityPanel
extends InfoPanel

func _ready() -> void:
	build_panel()
	custom_minimum_size = Vector2(340, 150)
	add_theme_stylebox_override("panel", ControlRoomTheme.panel_style(ControlRoomTheme.COLOR_RED, Color(0.02, 0.018, 0.018, 0.9), 2))
	set_panel_text("CHAT ACTIVITY", "ByteBiter: !brains\nGraveSnarl: !chaos\nNeonRot: !brains\nCrawlerQ: !slowmo")
	set_body_font_size(17)

func set_activity(lines: PackedStringArray) -> void:
	if lines.is_empty():
		set_panel_text("CHAT ACTIVITY", "Waiting for chat commands")
		return
	set_panel_text("CHAT ACTIVITY", "\n".join(lines))
