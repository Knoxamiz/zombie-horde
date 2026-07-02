class_name MineExplosionEffect
extends Node3D

@export var lifetime: float = 0.58
@export var max_scale: float = 8.5
@export var max_light_energy: float = 10.0

var _elapsed: float = 0.0

@onready var _flash_light: OmniLight3D = get_node("FlashLight") as OmniLight3D

func _ready() -> void:
	scale = Vector3.ONE * 0.2
	if _flash_light != null:
		_flash_light.light_energy = max_light_energy

func _process(delta: float) -> void:
	_elapsed += delta
	var progress: float = clamp(_elapsed / lifetime, 0.0, 1.0)
	scale = Vector3.ONE * lerp(0.2, max_scale, progress)

	if _flash_light != null:
		_flash_light.light_energy = lerp(max_light_energy, 0.0, progress)

	if progress >= 1.0:
		queue_free()
