extends CanvasLayer

signal finished(save_changes: bool)

const HUD_LAYOUT_PROFILE := preload("res://scripts/ui/hud_layout_profile.gd")
const PANEL_IDS: Array[String] = ["top", "roster", "leaderboard", "command", "countdown"]
const RESIZE_CORNERS: Array[String] = ["tl", "tr", "bl", "br"]
const MIN_PANEL_SIZE := Vector2(180.0, 96.0)
const HANDLE_SIZE := Vector2(14.0, 14.0)

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
var _resize_corner: String = ""
var _drag_start_mouse: Vector2 = Vector2.ZERO
var _drag_start_rect: Rect2 = Rect2()
var _resize_handles: Dictionary = {}
var _outline_nodes: Dictionary = {}
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
	_end_drag()
	visible = false
	_clear_edit_chrome()

func _build_toolbar() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_toolbar = PanelContainer.new()
	_toolbar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_toolbar.offset_left = -300.0
	_toolbar.offset_top = -54.0
	_toolbar.offset_right = 300.0
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
	hint.text = "Drag header to move · drag corners to resize"
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
		var panel: Control = _get_panel(panel_id)
		if panel == null or not panel.visible:
			continue
		_add_panel_chrome(panel_id, panel)

func _add_panel_chrome(panel_id: String, panel: Control) -> void:
	HUD_LAYOUT_PROFILE.flatten_panel_to_absolute(panel)
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.z_index = 10

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

	header.gui_input.connect(_on_move_press.bind(panel_id))

	_resize_handles[panel_id] = {}
	for corner in RESIZE_CORNERS:
		var handle := ColorRect.new()
		handle.name = "ResizeHandle_%s" % corner
		handle.color = Color(1.0, 0.72, 0.16, 0.95)
		handle.custom_minimum_size = HANDLE_SIZE
		handle.size = HANDLE_SIZE
		handle.mouse_filter = Control.MOUSE_FILTER_STOP
		handle.mouse_default_cursor_shape = _corner_cursor(corner)
		handle.tooltip_text = "Resize"
		handle.gui_input.connect(_on_resize_press.bind(panel_id, corner))
		panel.add_child(handle)
		_resize_handles[panel_id][corner] = handle

	_position_resize_handles(panel_id)
	panel.move_child(header, panel.get_child_count() - 1)
	for corner in RESIZE_CORNERS:
		var handle_node: ColorRect = _resize_handles[panel_id][corner] as ColorRect
		panel.move_child(handle_node, panel.get_child_count() - 1)

func _corner_cursor(corner: String) -> Control.CursorShape:
	match corner:
		"tl", "br":
			return Control.CURSOR_FDIAGSIZE
		"tr", "bl":
			return Control.CURSOR_BDIAGSIZE
	return Control.CURSOR_FDIAGSIZE

func _position_resize_handles(panel_id: String) -> void:
	var panel: Control = _get_panel(panel_id)
	var handles: Dictionary = _resize_handles.get(panel_id, {})
	if panel == null or handles.is_empty():
		return
	var panel_size: Vector2 = panel.size
	var inset: float = 2.0
	if handles.has("tl"):
		(handles["tl"] as Control).position = Vector2(inset, HEADER_HEIGHT + inset)
	if handles.has("tr"):
		(handles["tr"] as Control).position = Vector2(panel_size.x - HANDLE_SIZE.x - inset, HEADER_HEIGHT + inset)
	if handles.has("bl"):
		(handles["bl"] as Control).position = Vector2(inset, panel_size.y - HANDLE_SIZE.y - inset)
	if handles.has("br"):
		(handles["br"] as Control).position = Vector2(panel_size.x - HANDLE_SIZE.x - inset, panel_size.y - HANDLE_SIZE.y - inset)

func _clear_edit_chrome() -> void:
	if _hud_controller == null:
		return
	for panel_id in PANEL_IDS:
		_remove_panel_chrome(panel_id)

func _on_panel_hide_pressed(panel_id: String) -> void:
	var panel: Control = _get_panel(panel_id)
	if panel != null:
		panel.visible = false
	_remove_panel_chrome(panel_id)

func _remove_panel_chrome(panel_id: String) -> void:
	var panel: Control = _get_panel(panel_id)
	if panel != null:
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.z_index = 0
	var header: PanelContainer = _header_bars.get(panel_id) as PanelContainer
	if header != null and is_instance_valid(header):
		header.queue_free()
	_header_bars.erase(panel_id)
	var handles: Dictionary = _resize_handles.get(panel_id, {})
	for corner in handles.keys():
		var handle: ColorRect = handles[corner] as ColorRect
		if handle != null and is_instance_valid(handle):
			handle.queue_free()
	_resize_handles.erase(panel_id)
	var outline: Panel = _outline_nodes.get(panel_id) as Panel
	if outline != null and is_instance_valid(outline):
		outline.queue_free()
	_outline_nodes.erase(panel_id)

func _get_panel(panel_id: String) -> Control:
	if _hud_controller == null:
		return null
	return _hud_controller.call("get_layout_panel", panel_id) as Control

func _get_panel_parent(panel: Control) -> Control:
	return panel.get_parent() as Control

func _global_to_parent_local(parent: Control, global_pos: Vector2) -> Vector2:
	return parent.get_global_transform_with_canvas().affine_inverse() * global_pos

func _get_panel_rect(panel: Control) -> Rect2:
	return Rect2(panel.offset_left, panel.offset_top, panel.size.x, panel.size.y)

func _set_panel_rect(panel: Control, rect: Rect2) -> void:
	HUD_LAYOUT_PROFILE.set_absolute_rect(panel, rect)
	panel.custom_minimum_size = Vector2(max(rect.size.x, MIN_PANEL_SIZE.x), max(rect.size.y, MIN_PANEL_SIZE.y))

func _on_move_press(event: InputEvent, panel_id: String) -> void:
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed):
		return
	var panel: Control = _get_panel(panel_id)
	if panel == null:
		return
	_active_panel_id = panel_id
	_drag_mode = "move"
	_resize_corner = ""
	_drag_start_mouse = event.global_position
	_drag_start_rect = _get_panel_rect(panel)
	_highlight_panel(panel_id, true)
	get_viewport().set_input_as_handled()

func _on_resize_press(event: InputEvent, panel_id: String, corner: String) -> void:
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed):
		return
	var panel: Control = _get_panel(panel_id)
	if panel == null:
		return
	_active_panel_id = panel_id
	_drag_mode = "resize"
	_resize_corner = corner
	_drag_start_mouse = event.global_position
	_drag_start_rect = _get_panel_rect(panel)
	_highlight_panel(panel_id, true)
	get_viewport().set_input_as_handled()

func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		finished.emit(false)
		get_viewport().set_input_as_handled()
		return

	if _drag_mode.is_empty():
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if not event.pressed:
			_end_drag()
		return

	if event is InputEventMouseMotion:
		_apply_drag(event.global_position)
		get_viewport().set_input_as_handled()

func _apply_drag(global_mouse: Vector2) -> void:
	var panel: Control = _get_panel(_active_panel_id)
	if panel == null:
		return
	var parent: Control = _get_panel_parent(panel)
	if parent == null:
		return

	var start_local: Vector2 = _global_to_parent_local(parent, _drag_start_mouse)
	var current_local: Vector2 = _global_to_parent_local(parent, global_mouse)
	var delta: Vector2 = current_local - start_local
	var rect: Rect2 = _drag_start_rect

	if _drag_mode == "move":
		rect.position = _drag_start_rect.position + delta
	elif _drag_mode == "resize":
		rect = _resize_rect(_drag_start_rect, delta, _resize_corner)

	_set_panel_rect(panel, rect)
	_position_resize_handles(_active_panel_id)

func _resize_rect(start_rect: Rect2, delta: Vector2, corner: String) -> Rect2:
	var left: float = start_rect.position.x
	var top: float = start_rect.position.y
	var right: float = start_rect.position.x + start_rect.size.x
	var bottom: float = start_rect.position.y + start_rect.size.y

	match corner:
		"br":
			right += delta.x
			bottom += delta.y
		"bl":
			left += delta.x
			bottom += delta.y
		"tr":
			right += delta.x
			top += delta.y
		"tl":
			left += delta.x
			top += delta.y

	if right - left < MIN_PANEL_SIZE.x:
		if corner in ["bl", "tl"]:
			left = right - MIN_PANEL_SIZE.x
		else:
			right = left + MIN_PANEL_SIZE.x
	if bottom - top < MIN_PANEL_SIZE.y:
		if corner in ["tl", "tr"]:
			top = bottom - MIN_PANEL_SIZE.y
		else:
			bottom = top + MIN_PANEL_SIZE.y

	return Rect2(Vector2(left, top), Vector2(right - left, bottom - top))

func _end_drag() -> void:
	if not _active_panel_id.is_empty():
		_highlight_panel(_active_panel_id, false)
	_active_panel_id = ""
	_drag_mode = ""
	_resize_corner = ""

func _highlight_panel(panel_id: String, enabled: bool) -> void:
	var outline: Panel = _outline_nodes.get(panel_id) as Panel
	if outline == null:
		return
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.set_border_width_all(4 if enabled else 3)
	style.border_color = Color(0.5, 1.0, 0.35, 1.0) if enabled else Color(0.28, 0.95, 0.24, 0.95)
	outline.add_theme_stylebox_override("panel", style)

func _on_reset_pressed() -> void:
	if _hud_controller != null:
		_hud_controller.reset_layout_to_defaults()
		if _hud_controller.has_method("_ensure_layout_panels_visible_for_edit"):
			_hud_controller.call("_ensure_layout_panels_visible_for_edit")
	_end_drag()
	_rebuild_edit_chrome()

func _on_cancel_pressed() -> void:
	finished.emit(false)

func _on_save_pressed() -> void:
	finished.emit(true)
