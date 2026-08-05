class_name MainMenuControlRig
extends Control

signal action_pressed(action_id: StringName)

const CONSOLE_FRAME: Texture2D = preload("res://assets/ui/main_menu/industrial_command_console.png")
const ACTIONS: Array[Dictionary] = [
	{"id": &"start", "label": "START"},
	{"id": &"streamer", "label": "STREAMER SETTINGS"},
	{"id": &"settings", "label": "GAME SETTINGS"},
	{"id": &"quit", "label": "QUIT"},
]

# These normalized rectangles match the four steel plate bays in the console frame.
# The artwork stays static; only this input/text layer is interactive.
const BAY_RECTS: Array[Rect2] = [
	Rect2(0.105, 0.120, 0.790, 0.175),
	Rect2(0.105, 0.322, 0.790, 0.175),
	Rect2(0.105, 0.525, 0.790, 0.175),
	Rect2(0.105, 0.728, 0.790, 0.175),
]

var _menu_font: Font
var _hovered_action: StringName = &""
var _pressed_action: StringName = &""
var _interactable: bool = true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = ""
	queue_redraw()


func set_interactable(enabled: bool) -> void:
	_interactable = enabled
	if not enabled:
		_hovered_action = &""
		_pressed_action = &""
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if not _interactable:
		return
	if event is InputEventMouseMotion:
		var next_hover: StringName = _action_at(event.position)
		if next_hover != _hovered_action:
			_hovered_action = next_hover
			queue_redraw()
		return

	var mouse_event := event as InputEventMouseButton
	if mouse_event == null or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	var action_id: StringName = _action_at(mouse_event.position)
	if mouse_event.pressed:
		_pressed_action = action_id
		queue_redraw()
		accept_event()
		return

	var released_action: StringName = action_id
	var was_pressed: StringName = _pressed_action
	_pressed_action = &""
	queue_redraw()
	if was_pressed != &"" and was_pressed == released_action:
		action_pressed.emit(released_action)
	accept_event()


func _get_cursor_shape(position: Vector2) -> CursorShape:
	return Control.CURSOR_POINTING_HAND if _interactable and _action_at(position) != &"" else Control.CURSOR_ARROW


func _draw() -> void:
	if size.x < 20.0 or size.y < 20.0:
		return
	draw_texture_rect(CONSOLE_FRAME, Rect2(Vector2.ZERO, size), false)
	for index in ACTIONS.size():
		_draw_action_label(_bay_rect(index), ACTIONS[index])


func _draw_action_label(rect: Rect2, action: Dictionary) -> void:
	var action_id: StringName = action.id
	var hovered: bool = action_id == _hovered_action
	var pressed: bool = action_id == _pressed_action
	if hovered or pressed:
		var overlay_color := Color(0.52, 0.95, 0.34, 0.08) if hovered else Color(0.0, 0.0, 0.0, 0.20)
		draw_rect(rect.grow(-7.0), overlay_color, true)

	var label: String = action.label
	var font_size: int = int(clampf(rect.size.y * 0.40, 24.0, 52.0))
	if label.length() > 11:
		font_size = int(float(font_size) * 0.72)
	var font: Font = _get_menu_font()
	var text_size: Vector2 = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var text_position := Vector2(
		rect.get_center().x - text_size.x * 0.5,
		rect.get_center().y + (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5,
	)
	var press_offset := Vector2(1.0, 2.0) if pressed else Vector2.ZERO
	draw_string(font, text_position + press_offset + Vector2(3.0, 4.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(0.0, 0.0, 0.0, 0.88))
	draw_string(font, text_position + press_offset, label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color("f4f1df"))


func _bay_rect(index: int) -> Rect2:
	var normalized: Rect2 = BAY_RECTS[index]
	return Rect2(normalized.position * size, normalized.size * size)


func _action_at(point: Vector2) -> StringName:
	for index in ACTIONS.size():
		if _bay_rect(index).has_point(point):
			return ACTIONS[index].id
	return &""


func _get_menu_font() -> Font:
	if _menu_font != null:
		return _menu_font
	if ResourceLoader.exists("res://assets/fonts/bangers.ttf"):
		_menu_font = load("res://assets/fonts/bangers.ttf") as Font
	if _menu_font == null:
		_menu_font = ThemeDB.fallback_font
	return _menu_font
