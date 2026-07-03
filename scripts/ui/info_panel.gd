class_name InfoPanel
extends PanelContainer

var _title_label: Label
var _body_label: Label

func _ready() -> void:
	if _title_label == null:
		build_panel()

func build_panel() -> void:
	add_theme_stylebox_override("panel", ControlRoomTheme.panel_style(ControlRoomTheme.COLOR_ORANGE, ControlRoomTheme.COLOR_PANEL_DEEP, 2))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", ControlRoomTheme.PANEL_PADDING)
	margin.add_theme_constant_override("margin_top", ControlRoomTheme.PANEL_PADDING)
	margin.add_theme_constant_override("margin_right", ControlRoomTheme.PANEL_PADDING)
	margin.add_theme_constant_override("margin_bottom", ControlRoomTheme.PANEL_PADDING)
	add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", ControlRoomTheme.GAP_MEDIUM)
	margin.add_child(box)

	_title_label = Label.new()
	_title_label.text = "PANEL"
	_title_label.text = _title_label.text.to_upper()
	ControlRoomTheme.apply_label(_title_label, 30, ControlRoomTheme.COLOR_GREEN)
	box.add_child(_title_label)

	_body_label = Label.new()
	_body_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.clip_text = true
	_body_label.max_lines_visible = 18
	ControlRoomTheme.apply_label(_body_label, 22, ControlRoomTheme.COLOR_TEXT)
	box.add_child(_body_label)

func set_panel_text(title: String, body: String) -> void:
	if _title_label == null:
		build_panel()
	_title_label.text = title.to_upper()
	_body_label.text = body

func set_body_font_size(font_size: int) -> void:
	if _body_label != null:
		ControlRoomTheme.apply_label(_body_label, font_size, ControlRoomTheme.COLOR_TEXT)
