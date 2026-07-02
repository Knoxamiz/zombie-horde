class_name HumanDefender
extends Area3D

signal defender_died(defender: HumanDefender)

@export var config: HumanDefenderConfig
@export var tracer_material: Material
@export var pivot_path: NodePath = ^"Pivot"
@export var variant_root_path: NodePath = ^"Pivot/VariantModels"
@export var muzzle_path: NodePath = ^"Pivot/Muzzle"
@export var muzzle_flash_path: NodePath = ^"Pivot/MuzzleFlash"
@export var randomize_visual_variant: bool = true
@export var snap_aim_before_shot: bool = true

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _zombie_manager: ZombieManager
var _round_active: bool = false
var _alive: bool = true
var _shot_cooldown: float = 0.0
var _muzzle_flash_timer: float = 0.0
var _selected_visual_variant: Node3D
var _active_animation_player: AnimationPlayer
var _active_animation_name: String = ""
var _active_gun_type: int = HumanDefenderConfig.GunType.SMG

@onready var _pivot: Node3D = get_node_or_null(pivot_path) as Node3D
@onready var _variant_root: Node3D = get_node_or_null(variant_root_path) as Node3D
@onready var _muzzle: Marker3D = get_node_or_null(muzzle_path) as Marker3D
@onready var _muzzle_flash: MeshInstance3D = get_node_or_null(muzzle_flash_path) as MeshInstance3D

func _ready() -> void:
	_rng.randomize()
	body_entered.connect(_on_body_entered)
	_select_visual_variant()
	_select_weapon()
	_disable_visual_colliders(_variant_root)
	if _muzzle_flash != null:
		_muzzle_flash.visible = false
	_shot_cooldown = _get_initial_cooldown()
	_play_animation_by_candidates(["Idle"], true, true)

func configure(new_config: HumanDefenderConfig, zombie_manager: ZombieManager, random_seed: int) -> void:
	config = new_config
	_zombie_manager = zombie_manager
	_rng.seed = random_seed
	_alive = true
	_round_active = false
	monitoring = true
	monitorable = true
	_active_gun_type = _get_config().resolve_gun_type(_rng)
	_shot_cooldown = _get_initial_cooldown()
	_select_visual_variant()
	_select_weapon()
	_disable_visual_colliders(_variant_root)
	_play_animation_by_candidates(["Idle"], true, true)
	if _muzzle_flash != null:
		_muzzle_flash.visible = false

func set_round_active(active: bool) -> void:
	_round_active = active and _alive
	if _round_active:
		_shot_cooldown = min(_shot_cooldown, _get_initial_cooldown())

func is_alive() -> bool:
	return _alive

func _process(delta: float) -> void:
	_select_weapon()
	_update_muzzle_flash(delta)
	if not _round_active or not _alive or _zombie_manager == null:
		return

	var target: Zombie = _pick_target()
	if target == null:
		_play_animation_by_candidates(["Idle"], false, true)
		return

	_track_target(target, delta)
	_shot_cooldown -= delta
	if _shot_cooldown <= 0.0:
		_fire_at(target)
		_shot_cooldown = _get_config().get_effective_seconds_between_shots(_active_gun_type) * _rng.randf_range(0.82, 1.22)

func _pick_target() -> Zombie:
	var candidates: Array[Zombie] = _zombie_manager.get_living_zombies_in_range(global_position, _get_config().get_effective_range(_active_gun_type))
	if candidates.is_empty():
		return null

	var nearest: Zombie = candidates[0]
	var nearest_distance_squared: float = nearest.global_position.distance_squared_to(global_position)
	for candidate in candidates:
		var distance_squared: float = candidate.global_position.distance_squared_to(global_position)
		if distance_squared < nearest_distance_squared:
			nearest = candidate
			nearest_distance_squared = distance_squared
	return nearest

func _track_target(target: Zombie, delta: float) -> void:
	if _pivot == null:
		return

	var target_position: Vector3 = target.global_position + Vector3.UP * 0.65
	_aim_at_position(target_position, delta, false)

func _fire_at(target: Zombie) -> void:
	if target == null or not target.is_alive():
		return

	var active_config: HumanDefenderConfig = _get_config()
	var target_position: Vector3 = target.global_position + Vector3.UP * 0.65
	if snap_aim_before_shot:
		_aim_at_position(target_position, 0.0, true)
	var hit: bool = false
	var total_damage: float = 0.0
	for _projectile_index in range(active_config.get_projectile_count(_active_gun_type)):
		if _rng.randf() <= active_config.get_effective_hit_chance(_active_gun_type):
			hit = true
			total_damage += active_config.get_effective_damage_per_hit(_active_gun_type)

	_show_muzzle_flash()
	_spawn_tracer(target_position)
	_play_animation_by_candidates(["Shoot", "Fire", "Attack"], true, false)

	if hit:
		target.take_damage(total_damage, "defender")
		GameEvents.impact_mark_requested.emit(target.global_position, "blood")
		GameEvents.world_feedback_requested.emit(target.global_position + Vector3.UP * 1.2, active_config.get_gun_name(_active_gun_type).to_upper(), Color(0.95, 0.72, 0.24, 1.0))

	GameEvents.human_defender_fired.emit(str(name), target.display_name, hit)

func _aim_at_position(target_position: Vector3, delta: float, immediate: bool) -> void:
	if _pivot == null:
		return

	var flat_target_position: Vector3 = target_position
	flat_target_position.y = _pivot.global_position.y
	if _pivot.global_position.distance_squared_to(flat_target_position) <= 0.01:
		return

	var current_basis: Basis = _pivot.global_transform.basis
	_pivot.look_at(flat_target_position, Vector3.UP)
	if immediate:
		return

	var target_transform: Transform3D = _pivot.global_transform
	target_transform.basis = current_basis.slerp(target_transform.basis, clamp(delta * _get_config().turn_speed, 0.0, 1.0))
	_pivot.global_transform = target_transform

func _spawn_tracer(target_position: Vector3) -> void:
	if _muzzle == null:
		return

	var start_position: Vector3 = _muzzle.global_position
	var distance: float = start_position.distance_to(target_position)
	if distance <= 0.01:
		return

	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(0.035, 0.035, distance)

	var tracer: MeshInstance3D = MeshInstance3D.new()
	tracer.mesh = mesh
	tracer.material_override = tracer_material
	get_tree().current_scene.add_child(tracer)
	tracer.global_position = start_position.lerp(target_position, 0.5)
	tracer.look_at(target_position, Vector3.UP)

	var cleanup_timer: SceneTreeTimer = get_tree().create_timer(_get_config().tracer_lifetime)
	cleanup_timer.timeout.connect(Callable(tracer, "queue_free"))

func _on_body_entered(body: Node3D) -> void:
	if not _alive:
		return

	var zombie: Zombie = body as Zombie
	if zombie == null or not zombie.is_alive():
		return

	_die(zombie.display_name)

func _die(_zombie_name: String) -> void:
	_alive = false
	_round_active = false
	monitoring = false
	monitorable = false
	var played_death_animation: bool = _play_animation_by_candidates(["Death", "Die"], true, false)
	if not played_death_animation and _pivot != null:
		_pivot.rotation_degrees.x = -82.0
		_pivot.position.y = 0.12
	if _muzzle_flash != null:
		_muzzle_flash.visible = false
	GameEvents.world_feedback_requested.emit(global_position + Vector3.UP * 1.6, "HUMAN DOWN", Color(0.98, 0.18, 0.12, 1.0))
	GameEvents.human_defender_died.emit(str(name))
	defender_died.emit(self)

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
		_selected_visual_variant = null
		_active_animation_player = null
		return

	var selected_index: int = 0
	if randomize_visual_variant:
		selected_index = _rng.randi_range(0, variants.size() - 1)
	_selected_visual_variant = variants[selected_index]
	_selected_visual_variant.visible = true
	_active_animation_player = _find_animation_player(_selected_visual_variant)
	_active_animation_name = ""

func _select_weapon() -> void:
	KitCharacterVisuals.set_weapon_nodes_visible(
		_selected_visual_variant,
		_get_weapon_node_name(),
		_get_config().show_weapon_visuals
	)
	_configure_weapon_muzzle()

func _configure_weapon_muzzle() -> void:
	var muzzle_z: float = -1.1
	match _active_gun_type:
		HumanDefenderConfig.GunType.PISTOL:
			muzzle_z = -0.86
		HumanDefenderConfig.GunType.SMG:
			muzzle_z = -1.02
		HumanDefenderConfig.GunType.RIFLE:
			muzzle_z = -1.36
		HumanDefenderConfig.GunType.SHOTGUN:
			muzzle_z = -1.18

	if _muzzle != null:
		_muzzle.position.z = muzzle_z
	if _muzzle_flash != null:
		_muzzle_flash.position.z = muzzle_z - 0.08

func _get_weapon_node_name() -> String:
	match _active_gun_type:
		HumanDefenderConfig.GunType.PISTOL:
			return "Pistol"
		HumanDefenderConfig.GunType.SMG:
			return "SMG"
		HumanDefenderConfig.GunType.RIFLE:
			return "Rifle"
		HumanDefenderConfig.GunType.SHOTGUN:
			return "Shotgun"
	return "SMG"

func _find_animation_player(root: Node) -> AnimationPlayer:
	var animation_player: AnimationPlayer = root as AnimationPlayer
	if animation_player != null:
		return animation_player

	for child in root.get_children():
		var result: AnimationPlayer = _find_animation_player(child)
		if result != null:
			return result
	return null

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

func _set_animation_loop(animation_name: String, should_loop: bool) -> void:
	if _active_animation_player == null:
		return

	var animation: Animation = _active_animation_player.get_animation(animation_name)
	if animation != null:
		animation.loop_mode = Animation.LOOP_LINEAR if should_loop else Animation.LOOP_NONE

func _show_muzzle_flash() -> void:
	if _muzzle_flash == null:
		return

	_muzzle_flash.visible = true
	_muzzle_flash_timer = 0.055

func _update_muzzle_flash(delta: float) -> void:
	if _muzzle_flash == null or not _muzzle_flash.visible:
		return

	_muzzle_flash_timer -= delta
	if _muzzle_flash_timer <= 0.0:
		_muzzle_flash.visible = false

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

func _get_initial_cooldown() -> float:
	return _get_config().get_effective_seconds_between_shots(_active_gun_type) * _rng.randf_range(0.25, 0.95)

func _get_config() -> HumanDefenderConfig:
	if config != null:
		return config
	return HumanDefenderConfig.new()
