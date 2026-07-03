class_name BottomStatusBar
extends PanelContainer

var _items_box: HBoxContainer

func _ready() -> void:
	_build()

func _build() -> void:
	custom_minimum_size = Vector2(0, 62)
	add_theme_stylebox_override("panel", ControlRoomTheme.panel_style(ControlRoomTheme.COLOR_BLUE, Color(0.018, 0.026, 0.026, 0.92), 1))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)

	_items_box = HBoxContainer.new()
	_items_box.add_theme_constant_override("separation", 12)
	margin.add_child(_items_box)

func set_items(items: Array[Dictionary]) -> void:
	if _items_box == null:
		_build()
	for child in _items_box.get_children():
		child.queue_free()
	for item in items:
		var label := Label.new()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.text = "%s  %s" % [str(item.get("label", "")).to_upper(), str(item.get("value", "-"))]
		label.clip_text = true
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		ControlRoomTheme.apply_label(label, 16, ControlRoomTheme.COLOR_TEXT)
		_items_box.add_child(label)
