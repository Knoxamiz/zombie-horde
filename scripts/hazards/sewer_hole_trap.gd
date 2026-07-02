class_name SewerHoleTrap
extends Area3D

@export var config: HazardConfig

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

@onready var _collision_shape: CollisionShape3D = get_node("CollisionShape3D") as CollisionShape3D
@onready var _cover: Node3D = get_node_or_null("Cover") as Node3D

func _ready() -> void:
	_rng.randomize()
	body_entered.connect(_on_body_entered)
	_apply_radius()

func configure(new_config: HazardConfig) -> void:
	config = new_config
	monitoring = true
	monitorable = true
	_apply_radius()

func _on_body_entered(body: Node3D) -> void:
	var zombie: Zombie = body as Zombie
	if zombie == null or not zombie.is_alive():
		return

	GameEvents.impact_mark_requested.emit(global_position, "scuff")
	GameEvents.world_feedback_requested.emit(global_position + Vector3.UP * 1.15, "SEWER!", Color(0.42, 0.95, 0.65, 1.0))
	zombie.kill("sewer")

	if _cover != null:
		_cover.rotation_degrees.z = _rng.randf_range(-18.0, 18.0)

func _apply_radius() -> void:
	if _collision_shape == null:
		return

	var cylinder_shape: CylinderShape3D = _collision_shape.shape as CylinderShape3D
	if cylinder_shape != null:
		cylinder_shape.radius = _get_config().sewer_hole_radius

func _get_config() -> HazardConfig:
	if config != null:
		return config
	return HazardConfig.new()
