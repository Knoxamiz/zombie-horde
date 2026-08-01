class_name MainMenuControlRig
extends Control

signal action_pressed(action_id: StringName)

const ACTIONS: Array[Dictionary] = [
	{"id": &"start", "label": "START", "rail": Color("78d93d")},
	{"id": &"streamer", "label": "STREAMER SETTINGS", "rail": Color("b65cff")},
	{"id": &"settings", "label": "GAME SETTINGS", "rail": Color("f4a12d")},
	{"id": &"quit", "label": "QUIT", "rail": Color("e45745")},
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
	var chassis: Rect2 = Rect2(Vector2(7.0, 6.0), size - Vector2(14.0, 12.0))
	_draw_chassis(chassis)
	for index in ACTIONS.size():
		_draw_sign(_sign_rect(index), ACTIONS[index])


func _draw_chassis(chassis: Rect2) -> void:
	var shadow: Rect2 = chassis.grow(8.0)
	draw_rect(shadow, Color(0.0, 0.0, 0.0, 0.44), true)
	draw_rect(chassis, Color("171b19"), true)
	draw_rect(chassis, Color("59605b"), false, 3.0)
	draw_rect(chassis.grow(-7.0), Color("090c0b"), false, 2.0)

	var pillar_width: float = clampf(size.x * 0.045, 13.0, 20.0)
	var left_pillar := Rect2(chassis.position + Vector2(8.0, 8.0), Vector2(pillar_width, chassis.size.y - 16.0))
	var right_pillar := Rect2(Vector2(chassis.end.x - pillar_width - 8.0, chassis.position.y + 8.0), Vector2(pillar_width, chassis.size.y - 16.0))
	for pillar in [left_pillar, right_pillar]:
		draw_rect(pillar, Color("252c28"), true)
		draw_rect(pillar, Color("879087"), false, 2.0)
		draw_line(pillar.position + Vector2(4.0, 8.0), Vector2(pillar.position.x + 4.0, pillar.end.y - 8.0), Color("101310"), 3.0)


func _draw_sign(rect: Rect2, action: Dictionary) -> void:
	var action_id: StringName = action.id
	var hovered: bool = action_id == _hovered_action
	var pressed: bool = action_id == _pressed_action
	var rail: Color = action.rail
	var outer: Rect2 = rect.grow(2.0)
	var face: Rect2 = rect.grow(-8.0)
	var face_color: Color = Color("222824") if hovered else Color("151a17")
	if pressed:
		face_color = Color("0c100e")

	draw_rect(outer, Color("686f69"), true)
	draw_rect(outer, Color("050706"), false, 3.0)
	draw_rect(face, face_color, true)
	draw_rect(face, Color("303832"), false, 2.0)

	var rail_height: float = clampf(rect.size.y * 0.075, 3.0, 5.0)
	var top_rail := Rect2(rect.position + Vector2(4.0, 3.0), Vector2(rect.size.x - 8.0, rail_height))
	var bottom_rail := Rect2(Vector2(rect.position.x + 4.0, rect.end.y - rail_height - 3.0), Vector2(rect.size.x - 8.0, rail_height))
	draw_rect(top_rail, rail, true)
	draw_rect(bottom_rail, rail, true)
	draw_line(top_rail.position, Vector2(top_rail.end.x, top_rail.position.y), rail.lightened(0.3), 1.0)
	draw_line(bottom_rail.position, Vector2(bottom_rail.end.x, bottom_rail.position.y), rail.darkened(0.38), 2.0)

	var bolt_inset: float = 13.0
	for bolt_position in [
		Vector2(rect.position.x + bolt_inset, rect.position.y + bolt_inset),
		Vector2(rect.end.x - bolt_inset, rect.position.y + bolt_inset),
		Vector2(rect.position.x + bolt_inset, rect.end.y - bolt_inset),
		Vector2(rect.end.x - bolt_inset, rect.end.y - bolt_inset),
	]:
		draw_circle(bolt_position + Vector2(1.5, 1.5), 4.4, Color(0.0, 0.0, 0.0, 0.5))
		draw_circle(bolt_position, 4.4, Color("afb7af"))
		draw_circle(bolt_position - Vector2(1.0, 1.0), 1.5, Color("e7eee4"))

	var label: String = action.label
	var font_size: int = int(clampf(rect.size.y * 0.40, 20.0, 34.0))
	if label.length() > 11:
		font_size = int(float(font_size) * 0.76)
	var font: Font = _get_menu_font()
	var text_size: Vector2 = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var text_position := Vector2(
		rect.get_center().x - text_size.x * 0.5,
		rect.get_center().y + (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5,
	)
	draw_string(font, text_position + Vector2(2.0, 3.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(0.0, 0.0, 0.0, 0.86))
	draw_string(font, text_position, label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color("fbfaf0"))


func _sign_rect(index: int) -> Rect2:
	var margin_x: float = clampf(size.x * 0.095, 30.0, 52.0)
	var top_margin: float = clampf(size.y * 0.075, 18.0, 32.0)
	var bottom_margin: float = top_margin
	var gap: float = clampf(size.y * 0.027, 8.0, 13.0)
	var sign_height: float = (size.y - top_margin - bottom_margin - gap * float(ACTIONS.size() - 1)) / float(ACTIONS.size())
	return Rect2(
		Vector2(margin_x, top_margin + float(index) * (sign_height + gap)),
		Vector2(size.x - margin_x * 2.0, sign_height),
	)


func _action_at(point: Vector2) -> StringName:
	for index in ACTIONS.size():
		if _sign_rect(index).grow(3.0).has_point(point):
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
