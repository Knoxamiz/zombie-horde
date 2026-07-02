class_name Zombie
extends CharacterBody3D

signal died(zombie: Zombie, cause: String)

enum MobilityState {
	RUNNER,
	CRAWLER,
	DEAD
}

@export var config: ZombieConfig
@export var display_name: String = "Zombie"
@export var goal_position: Vector3 = Vector3.ZERO
@export var runner_material: Material
@export var crawler_material: Material
@export var dead_material: Material
@export var randomize_visual_variant: bool = true

var mobility_state: MobilityState = MobilityState.RUNNER
var health: float = 100.0

var _round_active: bool = false
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _drift_direction: float = 0.0
var _drift_timer: float = 0.0
var _stun_timer: float = 0.0
var _boost_timer: float = 0.0
var _crowd_bump_timer: float = 0.0
var _boost_multiplier: float = 1.0
var _start_position: Vector3 = Vector3.ZERO
var _active_animation_player: AnimationPlayer
var _active_animation_name: String = ""
var _reaction_animation_timer: float = 0.0
var _selected_visual_variant: Node3D
var _total_zombie_count: int = 0
var _is_current_leader: bool = false

@onready var _visual_root: Node3D = get_node("VisualRoot") as Node3D
@onready var _collision_shape: CollisionShape3D = get_node("CollisionShape3D") as CollisionShape3D
@onready var _body_mesh: MeshInstance3D = get_node("VisualRoot/BodyMesh") as MeshInstance3D
@onready var _variant_root: Node3D = get_node_or_null("VisualRoot/VariantModels") as Node3D
@onready var _name_label: Label3D = get_node("NameLabel") as Label3D

func _ready() -> void:
	_rng.randomize()
	add_to_group("race_zombies")
	if _collision_shape != null and _collision_shape.shape != null:
		_collision_shape.shape = _collision_shape.shape.duplicate()
	_disable_visual_colliders(_visual_root)
	health = _get_config().max_health
	_start_position = global_position
	_select_visual_variant()
	_refresh_name_label()
	_apply_state_visuals()
	GameEvents.leader_changed.connect(_on_leader_changed)
	GameEvents.zombie_count_changed.connect(_on_zombie_count_changed)

func configure_zombie(
	new_display_name: String,
	new_config: ZombieConfig,
	new_goal_position: Vector3,
	new_start_position: Vector3,
	random_seed: int
) -> void:
	display_name = new_display_name
	config = new_config
	goal_position = new_goal_position
	_start_position = new_start_position
	_rng.seed = random_seed
	health = _get_config().max_health
	_is_current_leader = false
	_select_visual_variant()
	_refresh_name_label()
	_apply_state_visuals()

func set_round_active(active: bool) -> void:
	_round_active = active
	_play_animation_for_state(true)

func is_alive() -> bool:
	return mobility_state != MobilityState.DEAD

func is_crawler() -> bool:
	return mobility_state == MobilityState.CRAWLER

func get_race_forward_direction() -> Vector3:
	return _get_race_forward()

func get_progress() -> float:
	var path: Vector3 = goal_position - _start_position
	path.y = 0.0
	var path_length: float = path.length()
	if path_length <= 0.001:
		return 0.0

	var traveled: Vector3 = global_position - _start_position
	traveled.y = 0.0
	return clamp(traveled.dot(path.normalized()) / path_length, 0.0, 1.0)

func apply_launch(impulse: Vector3, stun_duration: float) -> void:
	if not is_alive():
		return

	velocity.x += impulse.x
	velocity.y = max(velocity.y, impulse.y)
	velocity.z += impulse.z
	_stun_timer = max(_stun_timer, stun_duration)
	_play_reaction_animation()

func apply_boost(multiplier: float, duration: float) -> void:
	if not is_alive():
		return

	_boost_multiplier = max(_boost_multiplier, multiplier)
	_boost_timer = max(_boost_timer, duration)

func convert_to_crawler(cause: String) -> void:
	if mobility_state != MobilityState.RUNNER:
		return

	mobility_state = MobilityState.CRAWLER
	health = max(health, _get_config().dismember_survivor_health)
	_apply_state_visuals()
	GameEvents.zombie_became_crawler.emit(self, cause)
	GameEvents.impact_mark_requested.emit(global_position, "blood")

func take_damage(amount: float, cause: String) -> void:
	if not is_alive():
		return

	health -= amount
	if health <= 0.0:
		if _try_survive_as_dismembered_crawler(cause):
			return
		kill(cause)

func kill(cause: String) -> void:
	if not is_alive():
		return

	mobility_state = MobilityState.DEAD
	_round_active = false
	collision_layer = 4
	collision_mask = 1
	velocity = Vector3.ZERO
	_stop_animation()
	GameEvents.impact_mark_requested.emit(global_position, "death_blood")
	_apply_state_visuals()
	died.emit(self, cause)

func _physics_process(delta: float) -> void:
	var active_config: ZombieConfig = _get_config()
	_update_timers(delta)
	_update_animation_playback(active_config)

	if mobility_state == MobilityState.DEAD:
		_process_dead_body(delta, active_config)
		return

	var vertical_velocity: float = velocity.y
	if not is_on_floor():
		vertical_velocity -= active_config.gravity * delta
	elif vertical_velocity < 0.0:
		vertical_velocity = -0.1

	if not _round_active:
		velocity = Vector3(
			move_toward(velocity.x, 0.0, active_config.launch_damping * delta),
			vertical_velocity,
			move_toward(velocity.z, 0.0, active_config.launch_damping * delta)
		)
		_move_and_slide_with_audit()
		return

	if _stun_timer > 0.0:
		velocity = Vector3(
			move_toward(velocity.x, 0.0, active_config.launch_damping * delta),
			vertical_velocity,
			move_toward(velocity.z, 0.0, active_config.launch_damping * delta)
		)
		_move_and_slide_with_audit()
		_check_out_of_bounds(active_config)
		return

	_update_drift(delta)
	var desired_velocity: Vector3 = _get_desired_velocity(active_config)
	velocity = Vector3(
		move_toward(velocity.x, desired_velocity.x, active_config.acceleration * delta),
		vertical_velocity,
		move_toward(velocity.z, desired_velocity.z, active_config.acceleration * delta)
	)
	_apply_crowd_bump(active_config)
	_move_and_slide_with_audit()
	_check_out_of_bounds(active_config)

func _process_dead_body(delta: float, active_config: ZombieConfig) -> void:
	var vertical_velocity: float = velocity.y
	if not is_on_floor():
		vertical_velocity -= active_config.gravity * delta
	elif vertical_velocity < 0.0:
		vertical_velocity = 0.0

	velocity = Vector3(
		move_toward(velocity.x, 0.0, active_config.body_settle_damping * delta),
		vertical_velocity,
		move_toward(velocity.z, 0.0, active_config.body_settle_damping * delta)
	)
	_move_and_slide_with_audit()

func _get_desired_velocity(active_config: ZombieConfig) -> Vector3:
	var to_goal: Vector3 = goal_position - global_position
	to_goal.y = 0.0
	if to_goal.length_squared() <= 0.001:
		return Vector3.ZERO

	var forward: Vector3 = to_goal.normalized()
	var race_forward: Vector3 = _get_race_forward()
	var side: Vector3 = _get_race_side(race_forward)
	var separation: Vector3 = _get_crowd_separation(active_config, side)
	var edge_recovery: Vector3 = _get_edge_recovery(active_config, side)
	var direction: Vector3 = (
		forward
		+ side * _drift_direction * active_config.drift_strength
		+ separation * active_config.crowd_separation_strength
		+ edge_recovery * active_config.edge_recovery_strength
	).normalized()
	return direction * _get_current_speed(active_config)

func _get_race_forward() -> Vector3:
	var z_direction: float = sign(goal_position.z - _start_position.z)
	if is_zero_approx(z_direction):
		z_direction = 1.0
	return Vector3(0.0, 0.0, z_direction)

func _get_race_side(race_forward: Vector3) -> Vector3:
	return Vector3(race_forward.z, 0.0, -race_forward.x).normalized()

func _get_edge_recovery(active_config: ZombieConfig, side: Vector3) -> Vector3:
	var lane_half_width: float = max(active_config.lane_half_width, 0.1)
	var lateral_position: float = (global_position - goal_position).dot(side)
	var overage: float = abs(lateral_position) - lane_half_width
	if overage <= 0.0:
		return Vector3.ZERO

	return -side * sign(lateral_position) * clamp(overage / 2.0, 0.0, 1.0)

func _get_crowd_separation(active_config: ZombieConfig, side: Vector3) -> Vector3:
	var radius: float = max(active_config.crowd_separation_radius, 0.01)
	var radius_squared: float = radius * radius
	var checked_neighbors: int = 0
	var separation: Vector3 = Vector3.ZERO

	for node in get_tree().get_nodes_in_group("race_zombies"):
		var other_zombie: Zombie = node as Zombie
		if other_zombie == null or other_zombie == self or not other_zombie.is_alive():
			continue

		var offset: Vector3 = global_position - other_zombie.global_position
		offset.y = 0.0
		var distance_squared: float = offset.length_squared()
		if distance_squared <= 0.001 or distance_squared > radius_squared:
			continue

		var lateral_distance: float = offset.dot(side)
		var lateral_sign: float = sign(lateral_distance)
		if is_zero_approx(lateral_sign):
			lateral_sign = -1.0 if get_instance_id() < other_zombie.get_instance_id() else 1.0

		var distance: float = sqrt(distance_squared)
		var falloff: float = 1.0 - clamp(distance / radius, 0.0, 1.0)
		separation += side * lateral_sign * falloff
		checked_neighbors += 1
		if checked_neighbors >= active_config.crowd_separation_max_neighbors:
			break

	return separation

func _apply_crowd_bump(active_config: ZombieConfig) -> void:
	if _crowd_bump_timer > 0.0 or active_config.crowd_bump_strength <= 0.0:
		return

	var to_goal: Vector3 = goal_position - global_position
	to_goal.y = 0.0
	if to_goal.length_squared() <= 0.001:
		return

	var forward: Vector3 = _get_race_forward()
	var side: Vector3 = _get_race_side(forward)
	var radius: float = max(active_config.crowd_bump_radius, 0.01)
	var radius_squared: float = radius * radius
	var closest_zombie: Zombie = null
	var closest_offset: Vector3 = Vector3.ZERO
	var closest_distance_squared: float = radius_squared

	for node in get_tree().get_nodes_in_group("race_zombies"):
		var other_zombie: Zombie = node as Zombie
		if other_zombie == null or other_zombie == self or not other_zombie.is_alive():
			continue

		var offset: Vector3 = global_position - other_zombie.global_position
		offset.y = 0.0
		var distance_squared: float = offset.length_squared()
		if distance_squared <= 0.001:
			var overlap_sign: float = -1.0 if get_instance_id() < other_zombie.get_instance_id() else 1.0
			offset = side * overlap_sign * 0.05
			distance_squared = 0.0025
		if distance_squared >= closest_distance_squared:
			continue

		closest_zombie = other_zombie
		closest_offset = offset
		closest_distance_squared = distance_squared

	if closest_zombie == null:
		return

	var lateral_sign: float = sign(closest_offset.dot(side))
	if is_zero_approx(lateral_sign):
		lateral_sign = -1.0 if get_instance_id() < closest_zombie.get_instance_id() else 1.0

	var distance: float = sqrt(closest_distance_squared)
	var contact_strength: float = 1.0 - clamp(distance / radius, 0.0, 1.0)
	var jitter: float = _rng.randf_range(-0.28, 0.28)
	var bump_direction: Vector3 = (
		side * (lateral_sign + jitter)
		+ forward * active_config.crowd_bump_forward_bias
	).normalized()
	var bump_amount: float = active_config.crowd_bump_strength * contact_strength

	velocity.x += bump_direction.x * bump_amount
	velocity.z += bump_direction.z * bump_amount
	if active_config.crowd_bump_upward_strength > 0.0:
		velocity.y = max(velocity.y, active_config.crowd_bump_upward_strength * contact_strength)
	_crowd_bump_timer = active_config.crowd_bump_cooldown * _rng.randf_range(0.75, 1.25)

func _get_current_speed(active_config: ZombieConfig) -> float:
	var speed: float = active_config.runner_speed
	if mobility_state == MobilityState.CRAWLER:
		speed *= active_config.crawler_speed_multiplier
	return speed * _boost_multiplier

func _check_out_of_bounds(active_config: ZombieConfig) -> void:
	if not _round_active or not active_config.out_of_bounds_enabled or not is_alive():
		return

	var is_out_of_bounds: bool = (
		abs(global_position.x) > active_config.out_of_bounds_half_width
		or global_position.z < active_config.out_of_bounds_min_z
		or global_position.z > active_config.out_of_bounds_max_z
		or global_position.y < active_config.out_of_bounds_min_y
	)
	if not is_out_of_bounds:
		return

	GameEvents.world_feedback_requested.emit(global_position + Vector3.UP * 1.2, "OUT!", Color(0.7, 0.92, 1.0, 1.0))
	kill("out_of_bounds")

func _update_timers(delta: float) -> void:
	if _stun_timer > 0.0:
		_stun_timer = max(0.0, _stun_timer - delta)

	if _reaction_animation_timer > 0.0:
		_reaction_animation_timer = max(0.0, _reaction_animation_timer - delta)

	if _boost_timer > 0.0:
		_boost_timer = max(0.0, _boost_timer - delta)
		if _boost_timer <= _get_config().boost_decay_buffer:
			_boost_multiplier = 1.0

	if _crowd_bump_timer > 0.0:
		_crowd_bump_timer = max(0.0, _crowd_bump_timer - delta)

func _update_drift(delta: float) -> void:
	_drift_timer -= delta
	if _drift_timer > 0.0:
		return

	var active_config: ZombieConfig = _get_config()
	_drift_direction = _rng.randf_range(-1.0, 1.0)
	_drift_timer = max(0.05, active_config.drift_change_interval)

func _refresh_name_label() -> void:
	if _name_label != null:
		_name_label.text = "%s\n%s" % [display_name, _get_status_text()]

func _refresh_name_label_visibility() -> void:
	if _name_label == null:
		return

	if mobility_state == MobilityState.DEAD:
		_name_label.visible = false
		return

	var active_config: ZombieConfig = _get_config()
	_name_label.visible = (
		_is_current_leader
		or mobility_state == MobilityState.CRAWLER
		or _total_zombie_count <= active_config.name_label_full_roster_limit
	)

func _apply_state_visuals() -> void:
	if _visual_root == null:
		return

	if mobility_state == MobilityState.CRAWLER:
		_visual_root.visible = true
		_activate_visual_variant_for_state()
		_visual_root.scale = _get_config().crawler_visual_scale
		_visual_root.rotation_degrees = Vector3.ZERO
		_apply_collision_profile(true)
		_set_body_material(crawler_material)
		_set_name_label_color(Color(1.0, 0.78, 0.26, 1.0))
	elif mobility_state == MobilityState.DEAD:
		_hide_dead_visuals()
	else:
		_visual_root.visible = true
		_activate_visual_variant_for_state()
		_visual_root.scale = Vector3.ONE
		_visual_root.rotation_degrees = Vector3.ZERO
		_apply_collision_profile(false)
		_set_body_material(runner_material)
		_set_name_label_color(Color(0.9, 1.0, 0.82, 1.0))
	if mobility_state == MobilityState.DEAD:
		_stop_animation()
	else:
		_play_animation_for_state(true)
	_refresh_name_label()
	_refresh_name_label_visibility()

func _get_config() -> ZombieConfig:
	if config != null:
		return config
	return ZombieConfig.new()

func _set_body_material(material: Material) -> void:
	if _body_mesh != null and material != null:
		_body_mesh.material_override = material

func _set_name_label_color(color: Color) -> void:
	if _name_label != null:
		_name_label.modulate = color

func _set_name_label_visible(visible: bool) -> void:
	if _name_label != null:
		_name_label.visible = visible

func _select_visual_variant() -> void:
	_selected_visual_variant = _select_variant_from_root(_variant_root)
	_active_animation_name = ""
	_activate_visual_variant_for_state()

func _select_variant_from_root(root: Node3D) -> Node3D:
	if root == null:
		return null

	var variants: Array[Node3D] = []
	for child in root.get_children():
		var variant: Node3D = child as Node3D
		if variant != null:
			variant.visible = false
			variants.append(variant)

	if variants.is_empty():
		return null

	var selected_index: int = 0
	if randomize_visual_variant:
		selected_index = _rng.randi_range(0, variants.size() - 1)
	return variants[selected_index]

func _activate_visual_variant_for_state() -> void:
	_hide_variant_root(_variant_root)

	if _selected_visual_variant == null:
		_active_animation_player = null
		return

	_selected_visual_variant.visible = true
	_active_animation_player = _find_animation_player(_selected_visual_variant)
	_active_animation_name = ""
	_play_animation_for_state(true)

func _hide_variant_root(root: Node3D) -> void:
	if root == null:
		return

	for child in root.get_children():
		var variant: Node3D = child as Node3D
		if variant != null:
			variant.visible = false

func _hide_dead_visuals() -> void:
	_stop_animation()
	_hide_variant_root(_variant_root)
	_visual_root.visible = false
	_set_name_label_visible(false)
	_set_collision_enabled(false)

func _find_animation_player(root: Node) -> AnimationPlayer:
	var animation_player: AnimationPlayer = root as AnimationPlayer
	if animation_player != null:
		return animation_player

	for child in root.get_children():
		var result: AnimationPlayer = _find_animation_player(child)
		if result != null:
			return result
	return null

func _play_reaction_animation() -> void:
	_reaction_animation_timer = max(_reaction_animation_timer, 0.38)
	if not _play_animation_by_candidates(["HitReact", "Jump"], true, false):
		_play_animation_for_state(true)

func _try_survive_as_dismembered_crawler(cause: String) -> bool:
	var active_config: ZombieConfig = _get_config()
	if mobility_state != MobilityState.RUNNER:
		return false
	if not _is_dismemberment_cause(cause, active_config):
		return false
	if _rng.randf() > active_config.lethal_dismember_chance:
		return false

	health = active_config.dismember_survivor_health
	mobility_state = MobilityState.CRAWLER
	GameEvents.impact_mark_requested.emit(global_position, "blood")
	GameEvents.world_feedback_requested.emit(global_position + Vector3.UP * 1.1, "STILL CRAWLING!", Color(0.96, 0.18, 0.08, 1.0))
	_apply_state_visuals()
	GameEvents.zombie_survived_dismemberment.emit(self, cause)
	GameEvents.zombie_became_crawler.emit(self, cause)
	return true

func _is_dismemberment_cause(cause: String, active_config: ZombieConfig) -> bool:
	for eligible_cause in active_config.dismemberment_causes:
		if str(eligible_cause) == cause:
			return true
	return false

func _update_animation_playback(active_config: ZombieConfig) -> void:
	if _active_animation_player == null:
		return

	if _reaction_animation_timer <= 0.0:
		_play_animation_for_state(false)

	if mobility_state == MobilityState.DEAD:
		_active_animation_player.speed_scale = 1.0
	elif _reaction_animation_timer > 0.0 or _stun_timer > 0.0:
		_active_animation_player.speed_scale = 0.55
	elif not _round_active:
		_active_animation_player.speed_scale = 0.7
	else:
		var speed_ratio: float = _get_current_speed(active_config) / max(active_config.runner_speed, 0.01)
		if mobility_state == MobilityState.CRAWLER:
			speed_ratio = max(0.55, speed_ratio)
		_active_animation_player.speed_scale = clamp(speed_ratio, 0.55, 1.7)

func _play_animation_for_state(force: bool = false) -> void:
	match mobility_state:
		MobilityState.DEAD:
			_play_animation_by_candidates(["Death"], force, false)
		MobilityState.CRAWLER:
			_play_animation_by_candidates(["Crawl", "Walk"], force, true)
		MobilityState.RUNNER:
			if _round_active:
				_play_animation_by_candidates(["Run", "Walk"], force, true)
			else:
				_play_animation_by_candidates(["Idle", "Walk"], force, true)

func _play_animation_by_candidates(candidates: Array[String], force: bool, should_loop: bool) -> bool:
	if _active_animation_player == null:
		return false

	for candidate in candidates:
		if not _active_animation_player.has_animation(candidate):
			continue

		_set_animation_loop(candidate, should_loop)
		if force or _active_animation_name != candidate:
			_active_animation_player.play(candidate)
			_active_animation_name = candidate
		return true
	return false

func _stop_animation() -> void:
	if _active_animation_player == null:
		return

	_active_animation_player.stop()
	_active_animation_name = ""

func _apply_collision_profile(low_profile: bool) -> void:
	if _collision_shape == null:
		return
	_set_collision_enabled(true)

	var capsule_shape: CapsuleShape3D = _collision_shape.shape as CapsuleShape3D
	if capsule_shape == null:
		return

	if low_profile:
		capsule_shape.radius = 0.42
		capsule_shape.height = 0.58
		_collision_shape.position = Vector3(0.0, -0.28, 0.0)
	else:
		capsule_shape.radius = 0.36
		capsule_shape.height = 1.45
		_collision_shape.position = Vector3.ZERO

func _set_collision_enabled(enabled: bool) -> void:
	if _collision_shape != null:
		_collision_shape.disabled = not enabled

func _set_animation_loop(animation_name: String, should_loop: bool) -> void:
	if _active_animation_player == null:
		return

	var animation: Animation = _active_animation_player.get_animation(animation_name)
	if animation == null:
		return

	animation.loop_mode = Animation.LOOP_LINEAR if should_loop else Animation.LOOP_NONE

func _disable_visual_colliders(node: Node) -> void:
	if node == null:
		return

	var collision_object: CollisionObject3D = node as CollisionObject3D
	if collision_object != null:
		collision_object.collision_layer = 0
		collision_object.collision_mask = 0

	var collision_shape: CollisionShape3D = node as CollisionShape3D
	if collision_shape != null:
		collision_shape.disabled = true

	for child in node.get_children():
		_disable_visual_colliders(child)

func _move_and_slide_with_audit() -> void:
	move_and_slide()
	_report_side_collisions()

func _report_side_collisions() -> void:
	for collision_index in range(get_slide_collision_count()):
		var collision: KinematicCollision3D = get_slide_collision(collision_index)
		if collision == null:
			continue

		var normal: Vector3 = collision.get_normal()
		if abs(normal.y) > 0.65:
			continue

		var collider: Object = collision.get_collider()
		if collider != null:
			GameEvents.report_race_blocker(collider, collision.get_position())

func _get_status_text() -> String:
	match mobility_state:
		MobilityState.RUNNER:
			return "RUNNER"
		MobilityState.CRAWLER:
			return "CRAWLER"
		MobilityState.DEAD:
			return "DEAD"
	return ""

func _on_leader_changed(leader_name: String, _progress: float) -> void:
	_is_current_leader = not leader_name.is_empty() and leader_name == display_name
	_refresh_name_label_visibility()

func _on_zombie_count_changed(_living_count: int, total_count: int) -> void:
	_total_zombie_count = total_count
	_refresh_name_label_visibility()
