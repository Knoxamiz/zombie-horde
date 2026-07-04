class_name HudLayoutPanel
extends Control

signal edit_hide_requested(panel_id: String)

const MOVE_BAR_HEIGHT: float = 52.0
const RESIZE_HANDLE_SIZE: float = 18.0
const MIN_PANEL_SIZE: Vector2 = Vector2(120.0, 48.0)

@export var panel_id: String = ""

var edit_active: bool = false

var _edit_root: Control
var _outline: Panel
var _move_bar: PanelContainer
var _move_label: Label
var _hide_button: Button
var _resize_handle: ColorRect
var _interaction_mode: String = ""
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
			_refresh_move_label()
	mouse_filter = Control.MOUSE_FILTER_PASS if active else Control.MOUSE_FILTER_IGNORE
	z_index = 10 if active else 0
	set_process_input(active)
	if not active:
		_end_interaction()
	call_deferred("_update_edit_chrome_layout")


func get_layout_rect() -> Rect2:
	return HudLayoutProfile.get_absolute_rect(self)


func set_layout_rect(rect: Rect2) -> void:
	HudLayoutProfile.set_absolute_rect(self, rect)
	call_deferred("_update_edit_chrome_layout")


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

	_outline = Panel.new()
	_outline.name = "Outline"
	_outline.set_anchors_preset(Control.PRESET_FULL_RECT)
	_outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_outline_style(false)
	_edit_root.add_child(_outline)

	var move_style := StyleBoxFlat.new()
	move_style.bg_color = Color(0.95, 0.5, 0.08, 0.96)
	move_style.corner_radius_top_left = 6
	move_style.corner_radius_top_right = 6
	move_style.corner_radius_bottom_left = 4
	move_style.corner_radius_bottom_right = 4
	move_style.content_margin_left = 14.0
	move_style.content_margin_top = 10.0
	move_style.content_margin_right = 14.0
	move_style.content_margin_bottom = 10.0
	move_style.shadow_color = Color(1.0, 0.6, 0.12, 0.35)
	move_style.shadow_size = 8

	_move_bar = PanelContainer.new()
	_move_bar.name = "MoveBar"
	_move_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	_move_bar.mouse_default_cursor_shape = Control.CURSOR_MOVE
	_move_bar.add_theme_stylebox_override("panel", move_style)
	_move_bar.gui_input.connect(_on_move_bar_gui_input)
	_edit_root.add_child(_move_bar)

	_move_label = Label.new()
	_move_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_move_label.add_theme_color_override("font_color", Color(0.06, 0.04, 0.02, 1.0))
	_move_label.add_theme_font_size_override("font_size", 18)
	_move_bar.add_child(_move_label)

	_resize_handle = ColorRect.new()
	_resize_handle.name = "ResizeHandleBR"
	_resize_handle.color = Color(0.28, 0.95, 0.24, 0.95)
	_resize_handle.custom_minimum_size = Vector2(RESIZE_HANDLE_SIZE, RESIZE_HANDLE_SIZE)
	_resize_handle.mouse_filter = Control.MOUSE_FILTER_STOP
	_resize_handle.mouse_default_cursor_shape = Control.CURSOR_FDIAGSIZE
	_resize_handle.tooltip_text = "Resize"
	_resize_handle.gui_input.connect(_on_resize_handle_gui_input)
	_edit_root.add_child(_resize_handle)

	_hide_button = Button.new()
	_hide_button.name = "HideButton"
	_hide_button.text = "Hide"
	_hide_button.custom_minimum_size = Vector2(52.0, 30.0)
	_hide_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_hide_button.pressed.connect(_on_hide_pressed)
	_edit_root.add_child(_hide_button)

	call_deferred("_update_edit_chrome_layout")


func _refresh_move_label() -> void:
	if _move_label == null:
		return
	var title: String = _get_panel_title()
	_move_label.text = ":::  %s  —  DRAG TO MOVE  :::" % title


func _get_panel_title() -> String:
	var header_label: Label = find_child("HeaderLabel", true, false) as Label
	if header_label != null and not header_label.text.is_empty():
		return header_label.text
	return panel_id.to_upper()


func _on_move_bar_gui_input(event: InputEvent) -> void:
	if not edit_active:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_begin_move(event.global_position)
		get_viewport().set_input_as_handled()


func _on_resize_handle_gui_input(event: InputEvent) -> void:
	if not edit_active:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_begin_resize(event.global_position)
		get_viewport().set_input_as_handled()


func _begin_move(global_mouse: Vector2) -> void:
	_raise_for_edit()
	_interaction_mode = "move"
	_drag_start_mouse_global = global_mouse
	_drag_start_rect = get_layout_rect()
	set_highlight(true)


func _begin_resize(global_mouse: Vector2) -> void:
	_raise_for_edit()
	_interaction_mode = "resize"
	_drag_start_mouse_global = global_mouse
	_drag_start_rect = get_layout_rect()
	set_highlight(true)


func _raise_for_edit() -> void:
	var parent_node: Node = get_parent()
	if parent_node != null:
		parent_node.move_child(self, parent_node.get_child_count() - 1)
	if _edit_root != null:
		_edit_root.move_to_front()


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
		rect.size = Vector2(
			maxf(_drag_start_rect.size.x + delta.x, MIN_PANEL_SIZE.x),
			maxf(_drag_start_rect.size.y + delta.y, MIN_PANEL_SIZE.y)
		)

	set_layout_rect(rect)


func _end_interaction() -> void:
	set_highlight(false)
	_interaction_mode = ""


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


func _on_resized() -> void:
	_update_edit_chrome_layout()


func _update_edit_chrome_layout() -> void:
	if _edit_root == null:
		return

	var panel_size: Vector2 = get_layout_rect().size
	var inset: float = 2.0

	if _move_bar != null:
		_move_bar.position = Vector2(inset, inset)
		_move_bar.size = Vector2(maxf(panel_size.x - inset * 2.0, MOVE_BAR_HEIGHT), MOVE_BAR_HEIGHT)

	if _hide_button != null:
		_hide_button.position = Vector2(maxf(panel_size.x - 58.0, inset), inset + 8.0)
		_hide_button.size = Vector2(52.0, 30.0)

	if _resize_handle != null:
		_resize_handle.position = Vector2(
			panel_size.x - RESIZE_HANDLE_SIZE - inset,
			panel_size.y - RESIZE_HANDLE_SIZE - inset
		)
		_resize_handle.size = Vector2(RESIZE_HANDLE_SIZE, RESIZE_HANDLE_SIZE)
