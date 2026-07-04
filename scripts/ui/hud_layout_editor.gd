extends CanvasLayer

signal finished(save_changes: bool)

const HUD_LAYOUT_PROFILE := preload("res://scripts/ui/hud_layout_profile.gd")
const PANEL_IDS: Array[String] = ["top", "roster", "leaderboard", "command", "countdown"]

const PANEL_LABELS: Dictionary = {
	"top": "Race Status",
	"roster": "Live Feed",
	"leaderboard": "Top 10",
	"command": "Chat Command",
	"countdown": "Countdown",
}

var _hud_controller: Node
var _toolbar: PanelContainer
var _visibility_checks: Dictionary = {}
var _active_panel_id: String = ""
var _drag_mode: String = ""
var _drag_start_mouse: Vector2 = Vector2.ZERO
var _drag_start_rect: Rect2 = Rect2()
var _resize_handles: Dictionary = {}
var _outline_nodes: Dictionary = {}
var _panel_input_handlers: Dictionary = {}
var _resize_input_handlers: Dictionary = {}

func setup(hud_controller: Node) -> void:
	_hud_controller = hud_controller
	layer = 20
	_build_toolbar()
	visible = false

func begin() -> void:
	if _hud_controller == null:
		return
	visible = true
	_refresh_visibility_checks()
	_rebuild_edit_chrome()

func end() -> void:
	visible = false
	_clear_edit_chrome()

func _build_toolbar() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_toolbar = PanelContainer.new()
	_toolbar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_toolbar.offset_left = 24.0
	_toolbar.offset_top = 16.0
	_toolbar.offset_right = -24.0
	_toolbar.offset_bottom = 132.0
	_toolbar.mouse_filter = Control.MOUSE_FILTER_STOP
	var toolbar_style := StyleBoxFlat.new()
	toolbar_style.bg_color = Color(0.016, 0.026, 0.018, 0.96)
	toolbar_style.corner_radius_top_left = 12
	toolbar_style.corner_radius_top_right = 12
	toolbar_style.corner_radius_bottom_left = 12
	toolbar_style.corner_radius_bottom_right = 12
	toolbar_style.shadow_color = Color(0.28, 0.95, 0.24, 0.35)
	toolbar_style.shadow_size = 18
	toolbar_style.content_margin_left = 18.0
	toolbar_style.content_margin_top = 14.0
	toolbar_style.content_margin_right = 18.0
	toolbar_style.content_margin_bottom = 14.0
	_toolbar.add_theme_stylebox_override("panel", toolbar_style)
	root.add_child(_toolbar)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	_toolbar.add_child(box)

	var title := Label.new()
	title.text = "HUD Layout Editor — drag panels, resize from the corner grip"
	title.add_theme_color_override("font_color", Color(0.94, 1.0, 0.58, 1.0))
	title.add_theme_font_size_override("font_size", 20)
	box.add_child(title)

	var visibility_row := HBoxContainer.new()
	visibility_row.add_theme_constant_override("separation", 14)
	box.add_child(visibility_row)
	for panel_id in PANEL_IDS:
		var check := CheckBox.new()
		check.text = str(PANEL_LABELS.get(panel_id, panel_id))
		check.button_pressed = true
		check.toggled.connect(_on_visibility_toggled.bind(panel_id))
		_visibility_checks_assign(panel_id, check)
		visibility_row.add_child(check)

	var button_row := HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 10)
	box.add_child(button_row)

	var reset_button := _make_button("Reset Defaults", Color(1.0, 0.48, 0.08, 1.0))
	reset_button.pressed.connect(_on_reset_pressed)
	button_row.add_child(reset_button)

	var cancel_button := _make_button("Cancel", Color(0.74, 0.34, 1.0, 1.0))
	cancel_button.pressed.connect(_on_cancel_pressed)
	button_row.add_child(cancel_button)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button_row.add_child(spacer)

	var save_button := _make_button("Save & Close", Color(0.72, 0.95, 0.2, 1.0))
	save_button.pressed.connect(_on_save_pressed)
	button_row.add_child(save_button)

func _visibility_checks_assign(panel_id: String, check: CheckBox) -> void:
	_visibility_checks[panel_id] = check

func _make_button(label: String, accent: Color) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(150, 40)
	button.text = label
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.038, 0.032, 0.022, 0.94)
	normal.border_color = accent
	normal.set_border_width_all(2)
	normal.corner_radius_top_left = 4
	normal.corner_radius_top_right = 4
	normal.corner_radius_bottom_left = 4
	normal.corner_radius_bottom_right = 4
	normal.content_margin_left = 12.0
	normal.content_margin_top = 8.0
	normal.content_margin_right = 12.0
	normal.content_margin_bottom = 8.0
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_color_override("font_color", Color(0.95, 0.91, 0.76, 1.0))
	return button

func _refresh_visibility_checks() -> void:
	if _hud_controller == null:
		return
	for panel_id in PANEL_IDS:
		var panel: Control = _hud_controller.call("get_layout_panel", panel_id) as Control
		var check: CheckBox = _visibility_checks.get(panel_id) as CheckBox
		if panel != null and check != null:
			check.button_pressed = panel.visible

func _rebuild_edit_chrome() -> void:
	_clear_edit_chrome()
	if _hud_controller == null:
		return

	for panel_id in PANEL_IDS:
		var panel: Control = _hud_controller.call("get_layout_panel", panel_id) as Control
		if panel == null:
			continue
		HUD_LAYOUT_PROFILE.flatten_panel_to_absolute(panel)
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		if not _panel_input_handlers.has(panel_id):
			var panel_handler := _on_panel_gui_input.bind(panel_id)
			_panel_input_handlers[panel_id] = panel_handler
			panel.gui_input.connect(panel_handler)

		var outline := Panel.new()
		outline.name = "LayoutOutline_%s" % panel_id
		outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
		outline.set_anchors_preset(Control.PRESET_FULL_RECT)
		var outline_style := StyleBoxFlat.new()
		outline_style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
		outline_style.border_color = Color(0.28, 0.95, 0.24, 0.95)
		outline_style.set_border_width_all(2)
		outline.add_theme_stylebox_override("panel", outline_style)
		panel.add_child(outline)
		_outline_nodes[panel_id] = outline

		var tag := Label.new()
		tag.name = "LayoutTag"
		tag.text = str(PANEL_LABELS.get(panel_id, panel_id))
		tag.position = Vector2(8.0, 8.0)
		tag.add_theme_color_override("font_color", Color(0.88, 1.0, 0.34, 1.0))
		tag.add_theme_font_size_override("font_size", 14)
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		outline.add_child(tag)

		var handle := ColorRect.new()
		handle.name = "ResizeHandle"
		handle.color = Color(1.0, 0.72, 0.16, 0.95)
		handle.custom_minimum_size = Vector2(16.0, 16.0)
		handle.size = Vector2(16.0, 16.0)
		handle.mouse_filter = Control.MOUSE_FILTER_STOP
		var resize_handler := _on_resize_gui_input.bind(panel_id)
		_resize_input_handlers[panel_id] = resize_handler
		handle.gui_input.connect(resize_handler)
		panel.add_child(handle)
		_resize_handles[panel_id] = handle
		call_deferred("_position_resize_handle", panel_id)

func _position_resize_handle(panel_id: String) -> void:
	var panel: Control = _hud_controller.call("get_layout_panel", panel_id) as Control if _hud_controller != null else null
	var handle: ColorRect = _resize_handles.get(panel_id) as ColorRect
	if panel == null or handle == null:
		return
	handle.position = panel.size - handle.size

func _clear_edit_chrome() -> void:
	if _hud_controller == null:
		return
	for panel_id in PANEL_IDS:
		var panel: Control = _hud_controller.call("get_layout_panel", panel_id) as Control
		if panel == null:
			continue
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if _panel_input_handlers.has(panel_id):
			var panel_handler: Callable = _panel_input_handlers[panel_id]
			if panel.gui_input.is_connected(panel_handler):
				panel.gui_input.disconnect(panel_handler)
		var handle: ColorRect = _resize_handles.get(panel_id) as ColorRect
		if handle != null and is_instance_valid(handle):
			if _resize_input_handlers.has(panel_id):
				var resize_handler: Callable = _resize_input_handlers[panel_id]
				if handle.gui_input.is_connected(resize_handler):
					handle.gui_input.disconnect(resize_handler)
			handle.queue_free()
		var outline: Panel = _outline_nodes.get(panel_id) as Panel
		if outline != null and is_instance_valid(outline):
			outline.queue_free()
	_outline_nodes.clear()
	_resize_handles.clear()
	_panel_input_handlers.clear()
	_resize_input_handlers.clear()

func _on_visibility_toggled(enabled: bool, panel_id: String) -> void:
	if _hud_controller == null:
		return
	var panel: Control = _hud_controller.call("get_layout_panel", panel_id) as Control
	if panel != null:
		panel.visible = enabled

func _on_panel_gui_input(event: InputEvent, panel_id: String) -> void:
	var panel: Control = _hud_controller.call("get_layout_panel", panel_id) as Control if _hud_controller != null else null
	if panel == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_active_panel_id = panel_id
			_drag_mode = "move"
			_drag_start_mouse = event.global_position
			_drag_start_rect = Rect2(panel.offset_left, panel.offset_top, panel.size.x, panel.size.y)
		else:
			_active_panel_id = ""
			_drag_mode = ""
	elif event is InputEventMouseMotion and _drag_mode == "move" and _active_panel_id == panel_id:
		var delta: Vector2 = event.global_position - _drag_start_mouse
		panel.offset_left = _drag_start_rect.position.x + delta.x
		panel.offset_top = _drag_start_rect.position.y + delta.y
		panel.offset_right = panel.offset_left + _drag_start_rect.size.x
		panel.offset_bottom = panel.offset_top + _drag_start_rect.size.y
		_position_resize_handle(panel_id)

func _on_resize_gui_input(event: InputEvent, panel_id: String) -> void:
	var panel: Control = _hud_controller.call("get_layout_panel", panel_id) as Control if _hud_controller != null else null
	if panel == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_active_panel_id = panel_id
			_drag_mode = "resize"
			_drag_start_mouse = event.global_position
			_drag_start_rect = Rect2(panel.offset_left, panel.offset_top, panel.size.x, panel.size.y)
			get_viewport().set_input_as_handled()
		else:
			_active_panel_id = ""
			_drag_mode = ""
	elif event is InputEventMouseMotion and _drag_mode == "resize" and _active_panel_id == panel_id:
		var delta: Vector2 = event.global_position - _drag_start_mouse
		var new_width: float = max(_drag_start_rect.size.x + delta.x, 180.0)
		var new_height: float = max(_drag_start_rect.size.y + delta.y, 72.0)
		panel.offset_right = panel.offset_left + new_width
		panel.offset_bottom = panel.offset_top + new_height
		panel.custom_minimum_size = Vector2(new_width, 0.0)
		_position_resize_handle(panel_id)
		get_viewport().set_input_as_handled()

func _on_reset_pressed() -> void:
	if _hud_controller != null:
		_hud_controller.reset_layout_to_defaults()
	_refresh_visibility_checks()
	_rebuild_edit_chrome()

func _on_cancel_pressed() -> void:
	finished.emit(false)

func _on_save_pressed() -> void:
	finished.emit(true)

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		finished.emit(false)
		get_viewport().set_input_as_handled()
