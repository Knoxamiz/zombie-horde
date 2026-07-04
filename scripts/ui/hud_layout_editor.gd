extends CanvasLayer

signal finished(save_changes: bool)

const HUD_LAYOUT_PROFILE := preload("res://scripts/ui/hud_layout_profile.gd")
const PANEL_IDS: Array[String] = ["top", "roster", "leaderboard", "command", "countdown"]

const PANEL_LABELS: Dictionary = {
	"top": "RACE STATUS",
	"roster": "LIVE FEED",
	"leaderboard": "TOP 10 STANDINGS",
	"command": "CHAT COMMAND",
	"countdown": "COUNTDOWN",
}

const HEADER_HEIGHT: float = 40.0

var _hud_controller: Node
var _toolbar: PanelContainer
var _active_panel_id: String = ""
var _drag_mode: String = ""
var _drag_start_mouse: Vector2 = Vector2.ZERO
var _drag_start_rect: Rect2 = Rect2()
var _resize_handles: Dictionary = {}
var _outline_nodes: Dictionary = {}
var _panel_input_handlers: Dictionary = {}
var _resize_input_handlers: Dictionary = {}
var _drag_shields: Dictionary = {}
var _header_bars: Dictionary = {}

func setup(hud_controller: Node) -> void:
	_hud_controller = hud_controller
	layer = 20
	_build_toolbar()
	visible = false

func begin() -> void:
	if _hud_controller == null:
		return
	visible = true
	await _hud_controller.get_tree().process_frame
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
	_toolbar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_toolbar.offset_left = -280.0
	_toolbar.offset_top = -54.0
	_toolbar.offset_right = 280.0
	_toolbar.offset_bottom = -14.0
	_toolbar.mouse_filter = Control.MOUSE_FILTER_STOP
	var toolbar_style := StyleBoxFlat.new()
	toolbar_style.bg_color = Color(0.016, 0.026, 0.018, 0.94)
	toolbar_style.corner_radius_top_left = 10
	toolbar_style.corner_radius_top_right = 10
	toolbar_style.corner_radius_bottom_left = 10
	toolbar_style.corner_radius_bottom_right = 10
	toolbar_style.border_color = Color(0.28, 0.95, 0.24, 0.55)
	toolbar_style.set_border_width_all(1)
	toolbar_style.content_margin_left = 14.0
	toolbar_style.content_margin_top = 8.0
	toolbar_style.content_margin_right = 14.0
	toolbar_style.content_margin_bottom = 8.0
	_toolbar.add_theme_stylebox_override("panel", toolbar_style)
	root.add_child(_toolbar)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_toolbar.add_child(row)

	var hint := Label.new()
	hint.text = "Drag headers to move · orange grip = resize"
	hint.add_theme_color_override("font_color", Color(0.82, 1.0, 0.45, 0.9))
	hint.add_theme_font_size_override("font_size", 14)
	row.add_child(hint)

	row.add_child(_make_button("Reset", Color(1.0, 0.48, 0.08, 1.0), _on_reset_pressed))
	row.add_child(_make_button("Cancel", Color(0.74, 0.34, 1.0, 1.0), _on_cancel_pressed))
	row.add_child(_make_button("Save", Color(0.72, 0.95, 0.2, 1.0), _on_save_pressed))

func _make_button(label: String, accent: Color, callback: Callable) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(88, 34)
	button.text = label
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.038, 0.032, 0.022, 0.94)
	normal.border_color = accent
	normal.set_border_width_all(2)
	normal.corner_radius_top_left = 4
	normal.corner_radius_top_right = 4
	normal.corner_radius_bottom_left = 4
	normal.corner_radius_bottom_right = 4
	normal.content_margin_left = 10.0
	normal.content_margin_top = 6.0
	normal.content_margin_right = 10.0
	normal.content_margin_bottom = 6.0
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_color_override("font_color", Color(0.95, 0.91, 0.76, 1.0))
	button.add_theme_font_size_override("font_size", 15)
	button.pressed.connect(callback)
	return button

func _make_header_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.95, 0.5, 0.08, 0.98)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 0
	style.corner_radius_bottom_right = 0
	style.content_margin_left = 12.0
	style.content_margin_top = 8.0
	style.content_margin_right = 12.0
	style.content_margin_bottom = 8.0
	return style

func _rebuild_edit_chrome() -> void:
	_clear_edit_chrome()
	if _hud_controller == null:
		return

	for panel_id in PANEL_IDS:
		var panel: Control = _hud_controller.call("get_layout_panel", panel_id) as Control
		if panel == null or not panel.visible:
			continue
		_add_panel_chrome(panel_id, panel)

func _add_panel_chrome(panel_id: String, panel: Control) -> void:
	HUD_LAYOUT_PROFILE.flatten_panel_to_absolute(panel)
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.z_index = 1

	var outline := Panel.new()
	outline.name = "LayoutOutline_%s" % panel_id
	outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outline.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var outline_style := StyleBoxFlat.new()
	outline_style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	outline_style.border_color = Color(0.28, 0.95, 0.24, 0.95)
	outline_style.set_border_width_all(3)
	outline.add_theme_stylebox_override("panel", outline_style)
	panel.add_child(outline)
	_outline_nodes[panel_id] = outline
	panel.move_child(outline, 0)

	var header := PanelContainer.new()
	header.name = "LayoutHeaderBar"
	header.mouse_filter = Control.MOUSE_FILTER_STOP
	header.set_anchors_preset(Control.PRESET_TOP_WIDE)
	header.offset_bottom = HEADER_HEIGHT
	header.add_theme_stylebox_override("panel", _make_header_style())
	panel.add_child(header)
	_header_bars[panel_id] = header

	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 8)
	header.add_child(header_row)

	var title := Label.new()
	title.text = str(PANEL_LABELS.get(panel_id, panel_id))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_color_override("font_color", Color(0.06, 0.04, 0.02, 1.0))
	title.add_theme_font_size_override("font_size", 17)
	header_row.add_child(title)

	var hide_button := Button.new()
	hide_button.text = "Hide"
	hide_button.custom_minimum_size = Vector2(52, 0)
	hide_button.add_theme_font_size_override("font_size", 13)
	hide_button.pressed.connect(_on_panel_hide_pressed.bind(panel_id))
	header_row.add_child(hide_button)

	var panel_handler := _on_panel_gui_input.bind(panel_id)
	_panel_input_handlers[panel_id] = panel_handler
	header.gui_input.connect(panel_handler)

	var drag_shield := ColorRect.new()
	drag_shield.name = "LayoutDragShield"
	drag_shield.color = Color(0.04, 0.12, 0.05, 0.08)
	drag_shield.mouse_filter = Control.MOUSE_FILTER_STOP
	drag_shield.set_anchors_preset(Control.PRESET_FULL_RECT)
	drag_shield.offset_top = HEADER_HEIGHT
	drag_shield.gui_input.connect(panel_handler)
	panel.add_child(drag_shield)
	_drag_shields[panel_id] = drag_shield

	var handle := ColorRect.new()
	handle.name = "ResizeHandle"
	handle.color = Color(1.0, 0.72, 0.16, 0.95)
	handle.custom_minimum_size = Vector2(18.0, 18.0)
	handle.size = Vector2(18.0, 18.0)
	handle.mouse_filter = Control.MOUSE_FILTER_STOP
	handle.tooltip_text = "Resize"
	var resize_handler := _on_resize_gui_input.bind(panel_id)
	_resize_input_handlers[panel_id] = resize_handler
	handle.gui_input.connect(resize_handler)
	panel.add_child(handle)
	_resize_handles[panel_id] = handle
	panel.move_child(handle, panel.get_child_count() - 1)
	_position_resize_handle(panel_id)

func _position_resize_handle(panel_id: String) -> void:
	var panel: Control = _hud_controller.call("get_layout_panel", panel_id) as Control if _hud_controller != null else null
	var handle: ColorRect = _resize_handles.get(panel_id) as ColorRect
	if panel == null or handle == null:
		return
	handle.position = panel.size - handle.size - Vector2(4.0, 4.0)

func _clear_edit_chrome() -> void:
	if _hud_controller == null:
		return
	for panel_id in PANEL_IDS:
		_remove_panel_chrome(panel_id)

func _on_panel_hide_pressed(panel_id: String) -> void:
	if _hud_controller == null:
		return
	var panel: Control = _hud_controller.call("get_layout_panel", panel_id) as Control
	if panel != null:
		panel.visible = false
	_remove_panel_chrome(panel_id)

func _rebuild_single_panel_chrome(panel_id: String) -> void:
	_remove_panel_chrome(panel_id)
	if _hud_controller == null:
		return
	var panel: Control = _hud_controller.call("get_layout_panel", panel_id) as Control
	if panel == null or not panel.visible:
		return
	_add_panel_chrome(panel_id, panel)

func _remove_panel_chrome(panel_id: String) -> void:
	var panel: Control = _hud_controller.call("get_layout_panel", panel_id) as Control if _hud_controller != null else null
	if panel != null:
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.z_index = 0
	var drag_shield: ColorRect = _drag_shields.get(panel_id) as ColorRect
	if drag_shield != null and is_instance_valid(drag_shield):
		if _panel_input_handlers.has(panel_id):
			var panel_handler: Callable = _panel_input_handlers[panel_id]
			if drag_shield.gui_input.is_connected(panel_handler):
				drag_shield.gui_input.disconnect(panel_handler)
		drag_shield.queue_free()
	_drag_shields.erase(panel_id)
	var header: PanelContainer = _header_bars.get(panel_id) as PanelContainer
	if header != null and is_instance_valid(header):
		if _panel_input_handlers.has(panel_id):
			var panel_handler: Callable = _panel_input_handlers[panel_id]
			if header.gui_input.is_connected(panel_handler):
				header.gui_input.disconnect(panel_handler)
		header.queue_free()
	_header_bars.erase(panel_id)
	var handle: ColorRect = _resize_handles.get(panel_id) as ColorRect
	if handle != null and is_instance_valid(handle):
		if _resize_input_handlers.has(panel_id):
			var resize_handler: Callable = _resize_input_handlers[panel_id]
			if handle.gui_input.is_connected(resize_handler):
				handle.gui_input.disconnect(resize_handler)
		handle.queue_free()
	_resize_handles.erase(panel_id)
	var outline: Panel = _outline_nodes.get(panel_id) as Panel
	if outline != null and is_instance_valid(outline):
		outline.queue_free()
	_outline_nodes.erase(panel_id)
	_panel_input_handlers.erase(panel_id)
	_resize_input_handlers.erase(panel_id)

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
			_highlight_panel(panel_id, true)
		else:
			_highlight_panel(panel_id, false)
			_active_panel_id = ""
			_drag_mode = ""
	elif event is InputEventMouseMotion and _drag_mode == "move" and _active_panel_id == panel_id:
		var delta: Vector2 = event.global_position - _drag_start_mouse
		panel.offset_left = _drag_start_rect.position.x + delta.x
		panel.offset_top = _drag_start_rect.position.y + delta.y
		panel.offset_right = panel.offset_left + _drag_start_rect.size.x
		panel.offset_bottom = panel.offset_top + _drag_start_rect.size.y
		_position_resize_handle(panel_id)

func _highlight_panel(panel_id: String, enabled: bool) -> void:
	var outline: Panel = _outline_nodes.get(panel_id) as Panel
	if outline == null:
		return
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.set_border_width_all(4 if enabled else 3)
	style.border_color = Color(0.5, 1.0, 0.35, 1.0) if enabled else Color(0.28, 0.95, 0.24, 0.95)
	outline.add_theme_stylebox_override("panel", style)

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
		var new_height: float = max(_drag_start_rect.size.y + delta.y, 96.0)
		panel.offset_right = panel.offset_left + new_width
		panel.offset_bottom = panel.offset_top + new_height
		panel.custom_minimum_size = Vector2(new_width, 0.0)
		_position_resize_handle(panel_id)
		get_viewport().set_input_as_handled()

func _on_reset_pressed() -> void:
	if _hud_controller != null:
		_hud_controller.reset_layout_to_defaults()
		if _hud_controller.has_method("_ensure_layout_panels_visible_for_edit"):
			_hud_controller.call("_ensure_layout_panels_visible_for_edit")
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
