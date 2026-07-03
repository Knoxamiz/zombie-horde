class_name ToggleControl
extends CheckBox

func _ready() -> void:
	custom_minimum_size = Vector2(160, 38)
	ControlRoomTheme.apply_button(self, Color(0.08, 0.1, 0.08, 0.96), Color(0.14, 0.18, 0.12, 1.0), ControlRoomTheme.COLOR_GREEN, 18)
