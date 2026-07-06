class_name SettingsModal
extends Control

signal close_pressed()
signal done_pressed()
signal reset_pressed()

var _title_label: Label
var _groups_box: VBoxContainer
var _done_button: Button
var _reset_button: Button
var _layout_shell: MarginContainer
var _panel: PanelContainer
var _scroll: ScrollContainer
var _expanded_layout: bool = false

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

	_layout_shell = MarginContainer.new()
	_layout_shell.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layout_shell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layout_shell.add_theme_constant_override("margin_left", 36)
	_layout_shell.add_theme_constant_override("margin_top", 28)
	_layout_shell.add_theme_constant_override("margin_right", 36)
	_layout_shell.add_theme_constant_override("margin_bottom", 28)
	add_child(_layout_shell)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(820, 680)
	_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_panel.add_theme_stylebox_override("panel", ControlRoomTheme.panel_style(ControlRoomTheme.COLOR_ORANGE, Color(0.018, 0.024, 0.02, 0.98), 3))
	_layout_shell.add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 26)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_right", 26)
	margin.add_theme_constant_override("margin_bottom", 22)
	_panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
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
	scroll.custom_minimum_size = Vector2(0, 520)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	_scroll = scroll

	_groups_box = VBoxContainer.new()
	_groups_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_groups_box.add_theme_constant_override("separation", 12)
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
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 10)
	group_panel.add_child(margin)

	var group_box := VBoxContainer.new()
	group_box.add_theme_constant_override("separation", 6)
	margin.add_child(group_box)

	var heading := Label.new()
	heading.text = title.to_upper()
	ControlRoomTheme.apply_label(heading, 20, ControlRoomTheme.COLOR_GREEN)
	group_box.add_child(heading)
	return group_box

func add_row(group_box: VBoxContainer, label_text: String, control: Control = null) -> SettingRow:
	var row := SettingRow.new()
	row.build(label_text)
	if control != null:
		row.set_control(control)
	group_box.add_child(row)
	return row

func set_expanded_layout(enabled: bool) -> void:
	_expanded_layout = enabled
	_apply_layout_mode()

func _apply_layout_mode() -> void:
	if _panel == null or _scroll == null or _layout_shell == null:
		return

	if _expanded_layout:
		_layout_shell.add_theme_constant_override("margin_left", 28)
		_layout_shell.add_theme_constant_override("margin_top", 24)
		_layout_shell.add_theme_constant_override("margin_right", 28)
		_layout_shell.add_theme_constant_override("margin_bottom", 24)
		_panel.custom_minimum_size = Vector2(0, 0)
		_scroll.custom_minimum_size = Vector2(0, 0)
		return

	_layout_shell.add_theme_constant_override("margin_left", 120)
	_layout_shell.add_theme_constant_override("margin_top", 48)
	_layout_shell.add_theme_constant_override("margin_right", 120)
	_layout_shell.add_theme_constant_override("margin_bottom", 48)
	_panel.custom_minimum_size = Vector2(820, 680)
	_scroll.custom_minimum_size = Vector2(0, 520)

func show_modal() -> void:
	if _expanded_layout:
		_apply_layout_mode()
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func hide_modal() -> void:
	visible = false
