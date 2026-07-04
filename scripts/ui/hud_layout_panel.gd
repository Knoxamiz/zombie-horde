class_name HudLayoutPanel
extends Control

signal edit_hide_requested(panel_id: String)

const HANDLE_SIZE: float = 20.0
const MIN_PANEL_SIZE: Vector2 = Vector2(180.0, 96.0)
const RESIZE_CORNERS: Array[String] = ["tl", "tr", "bl", "br"]

@export var panel_id: String = ""

var edit_active: bool = false

var _edit_root: Control
var _drag_surface: ColorRect
var _outline: Panel
var _hide_button: Button
var _handles: Dictionary = {}
var _interaction_mode: String = ""
var _resize_corner: String = ""
var _drag_start_mouse_global: Vector2 = Vector2.ZERO
var _drag_start_rect: Rect2 = Rect2()


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_on_resized)
	_ensure_scene_children_fill()
	_build_edit_chrome()


func set_edit_active(active: bool) -> void:
	edit_active = active
	if _edit_root != null:
		_edit_root.visible = active
		if active:
			_edit_root.move_to_front()
	mouse_filter = Control.MOUSE_FILTER_PASS if active else Control.MOUSE_FILTER_IGNORE
	z_index = 10 if active else 0
	set_process_input(active)
	if not active:
		_end_interaction()
	call_deferred("_update_handle_positions")


func get_layout_rect() -> Rect2:
	return HudLayoutProfile.get_absolute_rect(self)


func set_layout_rect(rect: Rect2) -> void:
	HudLayoutProfile.set_absolute_rect(self, rect)
	call_deferred("_update_handle_positions")


func flatten_to_absolute() -> void:
	HudLayoutProfile.flatten_panel_to_absolute(self)


func _ensure_scene_children_fill() -> void:
	for child in get_children():
		if child == _edit_root or child.name == "EditChrome":
			continue
		if child is Control:
			var control := child as Control
			control.set_anchors_preset(Control.PRESET_FULL_RECT)
			control.offset_left = 0.0
			control.offset_top = 0.0
			control.offset_right = 0.0
			control.offset_bottom = 0.0
			control.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _build_edit_chrome() -> void:
	_edit_root = Control.new()
	_edit_root.name = "EditChrome"
	_edit_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_edit_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_edit_root.visible = false
	add_child(_edit_root)

	_drag_surface = ColorRect.new()
	_drag_surface.name = "DragSurface"
	_drag_surface.set_anchors_preset(Control.PRESET_FULL_RECT)
	_drag_surface.color = Color(0.0, 0.0, 0.0, 0.0)
	_drag_surface.mouse_filter = Control.MOUSE_FILTER_STOP
	_drag_surface.mouse_default_cursor_shape = Control.CURSOR_MOVE
	_drag_surface.gui_input.connect(_on_drag_surface_gui_input)
	_edit_root.add_child(_drag_surface)

	_outline = Panel.new()
	_outline.name = "Outline"
	_outline.set_anchors_preset(Control.PRESET_FULL_RECT)
	_outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_outline_style(false)
	_edit_root.add_child(_outline)

	_hide_button = Button.new()
	_hide_button.name = "HideButton"
	_hide_button.text = "Hide"
	_hide_button.custom_minimum_size = Vector2(52.0, 28.0)
	_hide_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_hide_button.pressed.connect(_on_hide_pressed)
	_edit_root.add_child(_hide_button)

	for corner in RESIZE_CORNERS:
		var handle := ColorRect.new()
		handle.name = "ResizeHandle_%s" % corner
		handle.color = Color(1.0, 0.72, 0.16, 0.95)
		handle.custom_minimum_size = Vector2(HANDLE_SIZE, HANDLE_SIZE)
		handle.mouse_filter = Control.MOUSE_FILTER_STOP
		handle.mouse_default_cursor_shape = _corner_cursor(corner)
		handle.gui_input.connect(_on_resize_handle_input.bind(corner))
		_edit_root.add_child(handle)
		_handles[corner] = handle

	call_deferred("_update_handle_positions")


func _on_drag_surface_gui_input(event: InputEvent) -> void:
	if not edit_active:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_begin_interaction("move", "", event.global_position)
		get_viewport().set_input_as_handled()


func _on_resize_handle_input(event: InputEvent, corner: String) -> void:
	if not edit_active:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_begin_interaction("resize", corner, event.global_position)
		get_viewport().set_input_as_handled()


func _begin_interaction(mode: String, corner: String, global_mouse: Vector2) -> void:
	_interaction_mode = mode
	_resize_corner = corner
	_drag_start_mouse_global = global_mouse
	_drag_start_rect = get_layout_rect()
	set_highlight(true)


func _input(event: InputEvent) -> void:
	if not edit_active or _interaction_mode.is_empty():
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if not event.pressed:
			_end_interaction()
		return

	if event is InputEventMouseMotion:
		_apply_interaction(event.global_position)
		get_viewport().set_input_as_handled()


func _apply_interaction(global_mouse: Vector2) -> void:
	var parent: Control = get_parent() as Control
	if parent == null:
		return

	var parent_inverse: Transform2D = parent.get_global_transform_with_canvas().affine_inverse()
	var start_local: Vector2 = parent_inverse * _drag_start_mouse_global
	var current_local: Vector2 = parent_inverse * global_mouse
	var delta: Vector2 = current_local - start_local
	var rect: Rect2 = _drag_start_rect

	if _interaction_mode == "move":
		rect.position = _drag_start_rect.position + delta
	elif _interaction_mode == "resize":
		rect = _resize_rect(_drag_start_rect, delta, _resize_corner)

	set_layout_rect(rect)


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


func _end_interaction() -> void:
	set_highlight(false)
	_interaction_mode = ""
	_resize_corner = ""


func _on_hide_pressed() -> void:
	edit_hide_requested.emit(panel_id)


func set_highlight(enabled: bool) -> void:
	_apply_outline_style(enabled)


func _apply_outline_style(active: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.set_border_width_all(4 if active else 3)
	style.border_color = (
		Color(0.5, 1.0, 0.35, 1.0) if active else Color(0.28, 0.95, 0.24, 0.95)
	)
	_outline.add_theme_stylebox_override("panel", style)


func _corner_cursor(corner: String) -> Control.CursorShape:
	match corner:
		"tl", "br":
			return Control.CURSOR_FDIAGSIZE
		"tr", "bl":
			return Control.CURSOR_BDIAGSIZE
	return Control.CURSOR_FDIAGSIZE


func _on_resized() -> void:
	_update_handle_positions()


func _update_handle_positions() -> void:
	if _edit_root == null:
		return

	var panel_size: Vector2 = get_layout_rect().size
	var inset: float = 1.0

	if _hide_button != null:
		_hide_button.position = Vector2(maxf(panel_size.x - 60.0, inset), inset)
		_hide_button.size = Vector2(52.0, 28.0)

	if _handles.has("tl"):
		(_handles["tl"] as Control).position = Vector2(inset, inset)
	if _handles.has("tr"):
		(_handles["tr"] as Control).position = Vector2(panel_size.x - HANDLE_SIZE - inset, inset)
	if _handles.has("bl"):
		(_handles["bl"] as Control).position = Vector2(inset, panel_size.y - HANDLE_SIZE - inset)
	if _handles.has("br"):
		(_handles["br"] as Control).position = Vector2(
			panel_size.x - HANDLE_SIZE - inset,
			panel_size.y - HANDLE_SIZE - inset
		)
