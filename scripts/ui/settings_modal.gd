class_name SettingsModal
extends Control

signal close_pressed()
signal done_pressed()
signal reset_pressed()

var _title_label: Label
var _groups_box: VBoxContainer
var _done_button: Button
var _reset_button: Button

func _ready() -> void:
	_build()
	visible = false

func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.56)
	add_child(dim)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(940, 760)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -470
	panel.offset_top = -380
	panel.offset_right = 470
	panel.offset_bottom = 380
	panel.add_theme_stylebox_override("panel", ControlRoomTheme.panel_style(ControlRoomTheme.COLOR_ORANGE, Color(0.018, 0.024, 0.02, 0.98), 3))
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 26)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_right", 26)
	margin.add_theme_constant_override("margin_bottom", 22)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	margin.add_child(box)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	box.add_child(header)

	_title_label = Label.new()
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.text = "SETTINGS"
	ControlRoomTheme.apply_label(_title_label, 32, ControlRoomTheme.COLOR_GREEN)
	header.add_child(_title_label)

	var close_button := Button.new()
	close_button.custom_minimum_size = Vector2(92, 42)
	close_button.text = "CLOSE"
	ControlRoomTheme.apply_button(close_button, Color(0.1, 0.08, 0.06, 1.0), Color(0.2, 0.12, 0.06, 1.0), ControlRoomTheme.COLOR_ORANGE, 17)
	close_button.pressed.connect(close_pressed.emit)
	header.add_child(close_button)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 600)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)

	_groups_box = VBoxContainer.new()
	_groups_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_groups_box.add_theme_constant_override("separation", 18)
	scroll.add_child(_groups_box)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	box.add_child(footer)

	_reset_button = Button.new()
	_reset_button.custom_minimum_size = Vector2(180, 46)
	_reset_button.text = "DEFAULTS"
	ControlRoomTheme.apply_button(_reset_button, Color(0.1, 0.08, 0.06, 1.0), Color(0.2, 0.12, 0.06, 1.0), ControlRoomTheme.COLOR_ORANGE, 18)
	_reset_button.pressed.connect(reset_pressed.emit)
	footer.add_child(_reset_button)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(spacer)

	_done_button = Button.new()
	_done_button.custom_minimum_size = Vector2(180, 46)
	_done_button.text = "DONE"
	ControlRoomTheme.apply_button(_done_button, Color(0.36, 0.55, 0.12, 1.0), Color(0.52, 0.75, 0.16, 1.0), ControlRoomTheme.COLOR_GREEN, 20)
	_done_button.pressed.connect(done_pressed.emit)
	footer.add_child(_done_button)

func set_title(title: String) -> void:
	if _title_label != null:
		_title_label.text = title.to_upper()

func clear_groups() -> void:
	if _groups_box == null:
		return
	for child in _groups_box.get_children():
		child.queue_free()

func add_group(title: String) -> VBoxContainer:
	var group_panel := PanelContainer.new()
	group_panel.add_theme_stylebox_override("panel", ControlRoomTheme.panel_style(ControlRoomTheme.COLOR_BLUE, Color(0.01, 0.014, 0.012, 0.78), 1))
	_groups_box.add_child(group_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 14)
	group_panel.add_child(margin)

	var group_box := VBoxContainer.new()
	group_box.add_theme_constant_override("separation", 10)
	margin.add_child(group_box)

	var heading := Label.new()
	heading.text = title.to_upper()
	ControlRoomTheme.apply_label(heading, 23, ControlRoomTheme.COLOR_GREEN)
	group_box.add_child(heading)
	return group_box

func add_row(group_box: VBoxContainer, label_text: String, control: Control = null) -> SettingRow:
	var row := SettingRow.new()
	row.build(label_text)
	if control != null:
		row.set_control(control)
	group_box.add_child(row)
	return row

func show_modal() -> void:
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func hide_modal() -> void:
	visible = false
