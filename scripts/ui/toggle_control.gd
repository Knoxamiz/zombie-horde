class_name ToggleControl
extends CheckBox

func _ready() -> void:
	custom_minimum_size = Vector2(160, 38)
	ControlRoomTheme.apply_button(self, ControlRoomTheme.COLOR_METAL, ControlRoomTheme.COLOR_METAL_HIGHLIGHT, ControlRoomTheme.COLOR_GREEN, 18)
