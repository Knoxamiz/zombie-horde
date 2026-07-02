class_name WorldFeedbackLabel
extends Node3D

@export var lifetime: float = 0.85
@export var rise_speed: float = 1.9

var _elapsed: float = 0.0

@onready var _label: Label3D = get_node("Label3D") as Label3D

func configure(label_text: String, accent_color: Color) -> void:
	if _label == null:
		return

	_label.text = label_text
	_label.modulate = accent_color

func _process(delta: float) -> void:
	_elapsed += delta
	global_position += Vector3.UP * rise_speed * delta

	var progress: float = clamp(_elapsed / lifetime, 0.0, 1.0)
	if _label != null:
		var label_color: Color = _label.modulate
		label_color.a = lerp(1.0, 0.0, progress)
		_label.modulate = label_color

	if progress >= 1.0:
		queue_free()

