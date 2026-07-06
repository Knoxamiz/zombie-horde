class_name SettingsModal
extends Control

signal close_pressed()
signal done_pressed()
signal reset_pressed()

var _title_label: Label
var _groups_columns: HBoxContainer
var _left_column: VBoxContainer
var _right_column: VBoxContainer
var _done_button: Button
var _reset_button: Button
var _layout_shell: MarginContainer
var _panel: PanelContainer
var _content_box: VBoxContainer
var _scroll: ScrollContainer
var _expanded_layout: bool = false
var _two_column_layout: bool = false

func _ready() -> void:
	_build()
	visible = false
	resized.connect(_on_resized)

func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
	mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.color = Color(0.0, 0.0, 0.0, 0.56)
	add_child(dim)

	_layout_shell = MarginContainer.new()
	_layout_shell.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layout_shell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layout_shell.add_theme_constant_override("margin_left", 120)
	_layout_shell.add_theme_constant_override("margin_top", 48)
	_layout_shell.add_theme_constant_override("margin_right", 120)
	_layout_shell.add_theme_constant_override("margin_bottom", 48)
	add_child(_layout_shell)

	_panel = PanelContainer.new()
	_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_panel.custom_minimum_size = Vector2(820, 680)
	_panel.add_theme_stylebox_override(
		"panel",
		ControlRoomTheme.panel_style(ControlRoomTheme.COLOR_ORANGE, Color(0.018, 0.024, 0.02, 0.98), 3)
	)
	_layout_shell.add_child(_panel)

	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 26)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_right", 26)
	margin.add_theme_constant_override("margin_bottom", 22)
	_panel.add_child(margin)

	_content_box = VBoxContainer.new()
	_content_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content_box.add_theme_constant_override("separation", 10)
	margin.add_child(_content_box)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	_content_box.add_child(header)

	_title_label = Label.new()
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.text = "SETTINGS"
	ControlRoomTheme.apply_label(_title_label, 32, ControlRoomTheme.COLOR_GREEN)
	header.add_child(_title_label)

	var close_button := Button.new()
	close_button.custom_minimum_size = Vector2(92, 42)
	close_button.text = "CLOSE"
	ControlRoomTheme.apply_button(
		close_button,
		Color(0.1, 0.08, 0.06, 1.0),
		Color(0.2, 0.12, 0.06, 1.0),
		ControlRoomTheme.COLOR_ORANGE,
		17
	)
	close_button.pressed.connect(close_pressed.emit)
	header.add_child(close_button)

	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(0, 520)
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = 0
	_content_box.add_child(_scroll)

	_groups_columns = HBoxContainer.new()
	_groups_columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_groups_columns.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_groups_columns.add_theme_constant_override("separation", 18)
	_scroll.add_child(_groups_columns)

	_left_column = VBoxContainer.new()
	_left_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_left_column.size_flags_stretch_ratio = 1.0
	_left_column.add_theme_constant_override("separation", 12)
	_groups_columns.add_child(_left_column)

	_right_column = VBoxContainer.new()
	_right_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_right_column.size_flags_stretch_ratio = 1.0
	_right_column.add_theme_constant_override("separation", 12)
	_groups_columns.add_child(_right_column)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	_content_box.add_child(footer)

	_reset_button = Button.new()
	_reset_button.custom_minimum_size = Vector2(180, 46)
	_reset_button.text = "DEFAULTS"
	ControlRoomTheme.apply_button(
		_reset_button,
		Color(0.1, 0.08, 0.06, 1.0),
		Color(0.2, 0.12, 0.06, 1.0),
		ControlRoomTheme.COLOR_ORANGE,
		18
	)
	_reset_button.pressed.connect(reset_pressed.emit)
	footer.add_child(_reset_button)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(spacer)

	_done_button = Button.new()
	_done_button.custom_minimum_size = Vector2(180, 46)
	_done_button.text = "DONE"
	ControlRoomTheme.apply_button(
		_done_button,
		Color(0.36, 0.55, 0.12, 1.0),
		Color(0.52, 0.75, 0.16, 1.0),
		ControlRoomTheme.COLOR_GREEN,
		20
	)
	_done_button.pressed.connect(done_pressed.emit)
	footer.add_child(_done_button)

func set_title(title: String) -> void:
	if _title_label != null:
		_title_label.text = title.to_upper()

func clear_groups() -> void:
	_clear_column(_left_column)
	_clear_column(_right_column)

func _clear_column(column: VBoxContainer) -> void:
	if column == null:
		return
	for child in column.get_children():
		child.queue_free()

func set_two_column_layout(enabled: bool) -> void:
	_two_column_layout = enabled
	if _right_column != null:
		_right_column.visible = enabled

func add_group(title: String, column: int = 0) -> VBoxContainer:
	var target_column: VBoxContainer = _right_column if column > 0 else _left_column

	var group_panel := PanelContainer.new()
	group_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	group_panel.add_theme_stylebox_override(
		"panel",
		ControlRoomTheme.panel_style(ControlRoomTheme.COLOR_BLUE, Color(0.01, 0.014, 0.012, 0.78), 1)
	)
	target_column.add_child(group_panel)

	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 10)
	group_panel.add_child(margin)

	var group_box := VBoxContainer.new()
	group_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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

func set_streamer_layout() -> void:
	set_expanded_layout(true)
	set_two_column_layout(true)

func _apply_layout_mode() -> void:
	if _panel == null or _scroll == null or _layout_shell == null:
		return

	if _expanded_layout:
		_layout_shell.add_theme_constant_override("margin_left", 24)
		_layout_shell.add_theme_constant_override("margin_top", 20)
		_layout_shell.add_theme_constant_override("margin_right", 24)
		_layout_shell.add_theme_constant_override("margin_bottom", 20)
		_panel.custom_minimum_size = Vector2(0, 0)
	else:
		_layout_shell.add_theme_constant_override("margin_left", 120)
		_layout_shell.add_theme_constant_override("margin_top", 48)
		_layout_shell.add_theme_constant_override("margin_right", 120)
		_layout_shell.add_theme_constant_override("margin_bottom", 48)
		_panel.custom_minimum_size = Vector2(820, 680)
		_scroll.custom_minimum_size = Vector2(0, 520)

	_refresh_scroll_height()

func _refresh_scroll_height() -> void:
	if _scroll == null:
		return

	if not _expanded_layout:
		_scroll.custom_minimum_size = Vector2(0, 520)
		return

	var viewport_height: float = max(size.y, get_viewport_rect().size.y)
	var shell_margins: float = 40.0
	var panel_padding: float = 44.0
	var chrome_height: float = 118.0
	var scroll_height: float = viewport_height - shell_margins - panel_padding - chrome_height
	_scroll.custom_minimum_size = Vector2(0, max(scroll_height, 420.0))

func show_modal() -> void:
	_apply_layout_mode()
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	call_deferred("_refresh_scroll_height")

func hide_modal() -> void:
	visible = false

func _on_resized() -> void:
	if visible and _expanded_layout:
		_refresh_scroll_height()
