class_name SliderControl
extends HSlider

func _ready() -> void:
	custom_minimum_size = Vector2(260, 38)
	min_value = 0.0
	max_value = 100.0
	step = 1.0
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
