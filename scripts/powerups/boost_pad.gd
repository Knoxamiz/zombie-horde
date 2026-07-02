class_name BoostPad
extends Area3D

@export var config: PowerupConfig

var _recent_zombie_ids: Dictionary = {}

@onready var _collision_shape: CollisionShape3D = get_node("CollisionShape3D") as CollisionShape3D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_apply_radius()

func configure(new_config: PowerupConfig) -> void:
	config = new_config
	_apply_radius()

func _on_body_entered(body: Node3D) -> void:
	var zombie: Zombie = body as Zombie
	if zombie == null or not zombie.is_alive():
		return

	var zombie_id: int = zombie.get_instance_id()
	if _recent_zombie_ids.has(zombie_id):
		return

	var active_config: PowerupConfig = _get_config()
	_recent_zombie_ids[zombie_id] = true
	zombie.apply_boost(active_config.boost_multiplier, active_config.boost_duration)
	GameEvents.boost_pad_triggered.emit(zombie.display_name, global_position)
	GameEvents.world_feedback_requested.emit(zombie.global_position + Vector3.UP * 1.2, "BOOST", Color(0.25, 0.72, 1.0, 1.0))
	_release_cooldown_later(zombie_id, active_config.per_zombie_cooldown)

func _release_cooldown_later(zombie_id: int, duration: float) -> void:
	await get_tree().create_timer(duration).timeout
	_recent_zombie_ids.erase(zombie_id)

func _apply_radius() -> void:
	if _collision_shape == null:
		return

	var sphere_shape: SphereShape3D = _collision_shape.shape as SphereShape3D
	if sphere_shape != null:
		sphere_shape.radius = _get_config().activation_radius

func _get_config() -> PowerupConfig:
	if config != null:
		return config
	return PowerupConfig.new()
