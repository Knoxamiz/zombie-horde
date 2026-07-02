class_name MineTrap
extends Area3D

@export var config: HazardConfig
@export var armed_material: Material
@export var spent_material: Material
@export var explosion_scene: PackedScene

var _armed: bool = true
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

@onready var _collision_shape: CollisionShape3D = get_node("CollisionShape3D") as CollisionShape3D
@onready var _visual: MeshInstance3D = get_node("Visual") as MeshInstance3D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_apply_radius()
	_apply_visual()

func configure(new_config: HazardConfig, random_seed: int) -> void:
	config = new_config
	_rng.seed = random_seed
	_armed = true
	monitoring = true
	_apply_radius()
	_apply_visual()

func _on_body_entered(body: Node3D) -> void:
	if not _armed:
		return

	var zombie: Zombie = body as Zombie
	if zombie == null or not zombie.is_alive():
		return

	_trigger(zombie)

func _trigger(zombie: Zombie) -> void:
	var active_config: HazardConfig = _get_config()
	_armed = false
	monitoring = false
	_apply_visual()
	_spawn_explosion()
	GameEvents.impact_mark_requested.emit(global_position, "scorch")
	GameEvents.camera_shake_requested.emit(0.54, 0.34)
	GameEvents.mine_triggered.emit(zombie.display_name, global_position)
	GameEvents.world_feedback_requested.emit(global_position + Vector3.UP * 1.2, "MINE!", Color(1.0, 0.22, 0.12, 1.0))
	_apply_blast(active_config, zombie)

func _apply_blast(active_config: HazardConfig, trigger_zombie: Zombie) -> void:
	var blast_radius: float = max(active_config.mine_blast_radius, active_config.mine_activation_radius)
	var triggered_instance_id: int = trigger_zombie.get_instance_id() if trigger_zombie != null else 0

	for node in get_tree().get_nodes_in_group("race_zombies"):
		var zombie: Zombie = node as Zombie
		if zombie == null or not zombie.is_alive():
			continue

		var offset: Vector3 = zombie.global_position - global_position
		offset.y = 0.0
		var distance: float = offset.length()
		if distance > blast_radius:
			continue

		var away: Vector3 = offset
		if away.length_squared() <= 0.001:
			away = Vector3(_rng.randf_range(-1.0, 1.0), 0.0, _rng.randf_range(-1.0, 1.0))
		away = away.normalized()

		var falloff: float = clamp(1.0 - (distance / blast_radius), 0.0, 1.0)
		if zombie.get_instance_id() == triggered_instance_id:
			falloff = max(falloff, 0.78)
		var launch_strength: float = active_config.mine_launch_strength * lerp(0.42, 1.15, falloff)
		var impulse: Vector3 = away * launch_strength
		impulse.y = launch_strength * active_config.mine_vertical_launch_multiplier
		zombie.apply_launch(impulse, active_config.stun_duration)

		var effect_chance_scale: float = 1.0 if zombie.get_instance_id() == triggered_instance_id else falloff * 0.7
		if _rng.randf() <= active_config.crawler_chance * effect_chance_scale:
			zombie.convert_to_crawler("mine")
		if _rng.randf() <= active_config.damage_chance * effect_chance_scale:
			zombie.take_damage(active_config.mine_damage * max(effect_chance_scale, 0.35), "mine")

func _apply_radius() -> void:
	if _collision_shape == null:
		return

	var sphere_shape: SphereShape3D = _collision_shape.shape as SphereShape3D
	if sphere_shape != null:
		sphere_shape.radius = _get_config().mine_activation_radius

func _apply_visual() -> void:
	if _visual == null:
		return

	if _armed:
		_visual.material_override = armed_material
	else:
		_visual.material_override = spent_material

func _get_config() -> HazardConfig:
	if config != null:
		return config
	return HazardConfig.new()

func _spawn_explosion() -> void:
	if explosion_scene == null:
		return

	var effect: Node3D = explosion_scene.instantiate() as Node3D
	if effect == null:
		return

	get_tree().current_scene.add_child(effect)
	effect.global_position = global_position
