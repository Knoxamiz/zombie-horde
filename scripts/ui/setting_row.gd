class_name SettingRow
extends HBoxContainer

var _label: Label
var _control_holder: Control

func _ready() -> void:
	if _label == null:
		build("")

func build(label_text: String) -> void:
	custom_minimum_size = Vector2(0, 34)
	add_theme_constant_override("separation", 14)
	_label = Label.new()
	_label.custom_minimum_size = Vector2(148, 0)
	_label.size_flags_horizontal = Control.SIZE_FILL
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.text = label_text
	ControlRoomTheme.apply_label(_label, 19, ControlRoomTheme.COLOR_TEXT)
	add_child(_label)

	_control_holder = HBoxContainer.new()
	_control_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_control_holder.add_theme_constant_override("separation", 10)
	add_child(_control_holder)

func set_label(label_text: String) -> void:
	if _label == null:
		build(label_text)
	else:
		_label.text = label_text

func set_control(control: Control) -> void:
	if _control_holder == null:
		build("")
	for child in _control_holder.get_children():
		child.queue_free()
	if control != null:
		control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_control_holder.add_child(control)

func add_control(control: Control) -> void:
	if _control_holder == null:
		build("")
	if control != null:
		_control_holder.add_child(control)
