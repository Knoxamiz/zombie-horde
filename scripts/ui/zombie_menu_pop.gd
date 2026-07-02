class_name ZombieMenuPop
extends Control

@export_range(0.0, 2.0, 0.01) var float_strength: float = 0.55
@export_range(0.0, 0.08, 0.001) var scale_strength: float = 0.018
@export_range(0.0, 0.06, 0.001) var tilt_strength: float = 0.012
@export var phase: float = 0.0

var _base_position: Vector2 = Vector2.ZERO
var _base_scale: Vector2 = Vector2.ONE
var _base_rotation: float = 0.0
var _time: float = 0.0

func _ready() -> void:
	_base_position = position
	_base_scale = scale
	_base_rotation = rotation
	resized.connect(_on_resized)
	_on_resized()

func _process(delta: float) -> void:
	if not visible:
		return

	_time += delta
	var pulse: float = sin(_time * 1.2 + phase)
	var drift: Vector2 = Vector2(sin(_time * 0.72 + phase) * 2.0, pulse * 3.0) * float_strength
	position = _base_position + drift
	rotation = _base_rotation + pulse * tilt_strength
	scale = _base_scale * (1.0 + (pulse + 1.0) * 0.5 * scale_strength)

func _on_resized() -> void:
	pivot_offset = size * 0.5
