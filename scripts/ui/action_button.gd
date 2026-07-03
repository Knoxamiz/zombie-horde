class_name ActionButton
extends Button

@export var action_id: StringName = &""
@export var icon_text: String = ">"
@export var label_text: String = "ACTION"
@export var primary: bool = false

func _ready() -> void:
	_apply_action_style()

func configure(new_action_id: StringName, new_icon: String, new_label: String, is_primary: bool = false, enabled: bool = true) -> void:
	action_id = new_action_id
	icon_text = new_icon
	label_text = new_label
	primary = is_primary
	disabled = not enabled
	_apply_action_style()

func set_action_label(new_label: String) -> void:
	label_text = new_label
	_apply_action_style()

func _apply_action_style() -> void:
	custom_minimum_size = Vector2(ControlRoomTheme.BUTTON_WIDTH, ControlRoomTheme.BUTTON_HEIGHT + (12 if primary else 0))
	text = "%s   %s" % [icon_text, label_text.to_upper()]
	var base: Color = ControlRoomTheme.COLOR_GREEN if primary else Color(0.075, 0.09, 0.078, 0.98)
	var hover: Color = Color(0.52, 0.74, 0.16, 1.0) if primary else Color(0.13, 0.16, 0.13, 1.0)
	var border: Color = ControlRoomTheme.COLOR_GREEN if primary else ControlRoomTheme.COLOR_ORANGE
	ControlRoomTheme.apply_button(self, base, hover, border, 27 if primary else 23)
