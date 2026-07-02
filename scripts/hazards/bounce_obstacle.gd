class_name BounceObstacle
extends Node3D

@export var trigger_path: NodePath = ^"Trigger"
@export var variant_root_path: NodePath = ^"ArtRoot/VariantModels"
@export var randomize_visual_variant: bool = true
@export var disable_visual_colliders: bool = true
@export var preserve_forward_progress: bool = true
@export var forward_bounce_bias: float = 0.35
@export var lateral_bounce_bias: float = 1.0
@export var launch_strength: float = 6.0
@export var upward_strength: float = 3.0
@export var stun_duration: float = 0.35
@export var damage: float = 0.0
@export_range(0.0, 1.0, 0.01) var crawler_chance: float = 0.0
@export var hit_cooldown: float = 0.55
@export var feedback_text: String = "BOUNCE!"
@export var feedback_color: Color = Color(1.0, 0.8, 0.2, 1.0)

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _last_hit_times: Dictionary = {}
var _visual_kick_timer: float = 0.0
var _visual_kick_direction: float = 1.0

@onready var _trigger: Area3D = get_node_or_null(trigger_path) as Area3D
@onready var _variant_root: Node3D = get_node_or_null(variant_root_path) as Node3D
@onready var _art_root: Node3D = get_node_or_null("ArtRoot") as Node3D

func _ready() -> void:
	_rng.randomize()
	_select_visual_variant()
	if disable_visual_colliders:
		_disable_non_trigger_collision(self)
	if _trigger != null:
		_trigger.body_entered.connect(_on_trigger_body_entered)

func _process(delta: float) -> void:
	if _art_root == null or _visual_kick_timer <= 0.0:
		return

	_visual_kick_timer = max(0.0, _visual_kick_timer - delta)
	var kick_amount: float = sin(_visual_kick_timer * 42.0) * _visual_kick_timer * _visual_kick_direction
	_art_root.rotation_degrees.z = kick_amount * 14.0
	if _visual_kick_timer <= 0.0:
		_art_root.rotation_degrees.z = 0.0

func _on_trigger_body_entered(body: Node3D) -> void:
	var zombie: Zombie = body as Zombie
	if zombie == null or not zombie.is_alive():
		return

	var instance_key: int = zombie.get_instance_id()
	var now_seconds: float = float(Time.get_ticks_msec()) / 1000.0
	var last_hit: float = float(_last_hit_times.get(instance_key, -1000.0))
	if now_seconds - last_hit < hit_cooldown:
		return

	_last_hit_times[instance_key] = now_seconds
	_launch_zombie(zombie)

func _launch_zombie(zombie: Zombie) -> void:
	var bounce_direction: Vector3 = _get_bounce_direction(zombie)
	var impulse: Vector3 = bounce_direction * launch_strength
	impulse.y = upward_strength
	zombie.apply_launch(impulse, stun_duration)

	if damage > 0.0:
		zombie.take_damage(damage, "obstacle")
		GameEvents.impact_mark_requested.emit(zombie.global_position, "blood")
		GameEvents.camera_shake_requested.emit(clamp(damage / 70.0, 0.08, 0.18), 0.14)
	else:
		GameEvents.impact_mark_requested.emit(zombie.global_position, "scuff")
	if crawler_chance > 0.0 and _rng.randf() <= crawler_chance:
		zombie.convert_to_crawler("obstacle")

	_visual_kick_timer = 0.18
	_visual_kick_direction = 1.0 if bounce_direction.x >= 0.0 else -1.0

	GameEvents.obstacle_triggered.emit(zombie.display_name, name, global_position)
	GameEvents.world_feedback_requested.emit(zombie.global_position + Vector3.UP * 1.1, feedback_text, feedback_color)

func _get_bounce_direction(zombie: Zombie) -> Vector3:
	var away: Vector3 = zombie.global_position - global_position
	away.y = 0.0
	if away.length_squared() <= 0.001:
		away = Vector3(_rng.randf_range(-1.0, 1.0), 0.0, _rng.randf_range(-1.0, 1.0))

	if not preserve_forward_progress:
		return away.normalized()

	var race_forward: Vector3 = zombie.get_race_forward_direction()
	var race_side: Vector3 = Vector3(race_forward.z, 0.0, -race_forward.x).normalized()
	var lateral_sign: float = sign(away.dot(race_side))
	if is_zero_approx(lateral_sign):
		lateral_sign = -1.0 if zombie.get_instance_id() % 2 == 0 else 1.0

	return (
		race_side * lateral_sign * lateral_bounce_bias
		+ race_forward * max(forward_bounce_bias, 0.0)
	).normalized()

func _select_visual_variant() -> void:
	if _variant_root == null:
		return

	var variants: Array[Node3D] = []
	for child in _variant_root.get_children():
		var variant: Node3D = child as Node3D
		if variant != null:
			variant.visible = false
			variants.append(variant)

	if variants.is_empty():
		return

	var selected_index: int = 0
	if randomize_visual_variant:
		selected_index = _rng.randi_range(0, variants.size() - 1)
	variants[selected_index].visible = true

func _disable_non_trigger_collision(node: Node) -> void:
	if _trigger != null and (node == _trigger or _trigger.is_ancestor_of(node)):
		return

	var collision_object: CollisionObject3D = node as CollisionObject3D
	if collision_object != null:
		collision_object.collision_layer = 0
		collision_object.collision_mask = 0

	var collision_shape: CollisionShape3D = node as CollisionShape3D
	if collision_shape != null:
		collision_shape.disabled = true

	for child in node.get_children():
		_disable_non_trigger_collision(child)
