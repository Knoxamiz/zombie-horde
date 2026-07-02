class_name BaseMinigun
extends Node3D

@export var config: MinigunConfig
@export var zombie_manager_path: NodePath
@export var tracer_material: Material
@export_range(0, 3, 1) var streamer_avatar_index: int = 0
@export var avatar_root_path: NodePath = ^"AvatarRoot/Variants"
@export var avatar_look_root_path: NodePath = ^"AvatarRoot"
@export var streamer_name: String = "Streamer"
@export var streamer_name_label_path: NodePath = ^"StreamerNameLabel"
@export var avatar_turn_speed: float = 5.0

var _zombie_manager: ZombieManager
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _round_active: bool = false
var _burst_cooldown: float = 0.0
var _shot_cooldown: float = 0.0
var _shots_remaining: int = 0
var _current_target: Zombie
var _muzzle_flash_timer: float = 0.0
var _barrel_spin_velocity: float = 0.0
var _avatar_root: Node3D
var _avatar_look_root: Node3D
var _streamer_name_label: Label3D
var _leader_name: String = ""

@onready var _turret_yaw: Node3D = get_node("TurretYaw") as Node3D
@onready var _muzzle: Marker3D = get_node("TurretYaw/Muzzle") as Marker3D
@onready var _muzzle_flash: MeshInstance3D = get_node_or_null("TurretYaw/MuzzleFlash") as MeshInstance3D
@onready var _barrel_cluster: Node3D = get_node_or_null("TurretYaw/BarrelCluster") as Node3D

func _ready() -> void:
	_rng.randomize()
	_zombie_manager = get_node_or_null(zombie_manager_path) as ZombieManager
	_avatar_root = get_node_or_null(avatar_root_path) as Node3D
	_avatar_look_root = get_node_or_null(avatar_look_root_path) as Node3D
	_streamer_name_label = get_node_or_null(streamer_name_label_path) as Label3D
	_burst_cooldown = _get_config().seconds_between_bursts
	if _muzzle_flash != null:
		_muzzle_flash.visible = false
	_disable_visual_colliders(_avatar_root)
	set_streamer_avatar_index(streamer_avatar_index)
	KitCharacterVisuals.set_weapon_nodes_visible(_avatar_root)
	set_streamer_name(streamer_name)
	GameEvents.leader_changed.connect(_on_leader_changed)

func set_round_active(active: bool) -> void:
	_round_active = active
	_shots_remaining = 0
	_shot_cooldown = 0.0
	_burst_cooldown = _get_config().seconds_between_bursts
	_current_target = null

func _process(delta: float) -> void:
	_update_muzzle_flash(delta)
	_update_barrel_spin(delta)
	_update_avatar_tracking(delta)
	if not _round_active or _zombie_manager == null:
		return

	_track_target(delta)
	if _shots_remaining > 0:
		_shot_cooldown -= delta
		if _shot_cooldown <= 0.0:
			_fire_single_shot()
			_shots_remaining -= 1
			_shot_cooldown = _get_config().shot_interval
		return

	_burst_cooldown -= delta
	if _burst_cooldown <= 0.0:
		_current_target = _pick_target()
		if _current_target != null:
			_shots_remaining = _get_config().shots_per_burst
			_shot_cooldown = 0.0
		_burst_cooldown = _get_config().seconds_between_bursts

func _track_target(delta: float) -> void:
	if _current_target == null or not is_instance_valid(_current_target) or not _current_target.is_alive():
		_current_target = _pick_target()

	if _current_target == null or _turret_yaw == null:
		return

	var target_position: Vector3 = _current_target.global_position + Vector3.UP * 0.6
	var current_basis: Basis = _turret_yaw.global_transform.basis
	_turret_yaw.look_at(target_position, Vector3.UP)
	var target_transform: Transform3D = _turret_yaw.global_transform
	target_transform.basis = current_basis.slerp(target_transform.basis, clamp(delta * _get_config().turn_speed, 0.0, 1.0))
	_turret_yaw.global_transform = target_transform

func _pick_target() -> Zombie:
	if _zombie_manager == null:
		return null

	var candidates: Array[Zombie] = _zombie_manager.get_living_zombies_in_range(global_position, _get_config().range)
	if candidates.is_empty():
		return null

	var index: int = _rng.randi_range(0, candidates.size() - 1)
	return candidates[index]

func _fire_single_shot() -> void:
	var target: Zombie = _pick_target()
	if target == null:
		return

	_current_target = target
	var hit: bool = _rng.randf() <= _get_config().hit_chance
	_barrel_spin_velocity = 48.0
	_show_muzzle_flash()
	_spawn_tracer(target.global_position + Vector3.UP * 0.6)
	if hit:
		target.take_damage(_get_config().damage_per_hit, "minigun")
		GameEvents.impact_mark_requested.emit(target.global_position, "blood")
		GameEvents.world_feedback_requested.emit(target.global_position + Vector3.UP * 1.25, "HIT", Color(1.0, 0.86, 0.18, 1.0))

	GameEvents.minigun_fired.emit(target.display_name, hit)

func _spawn_tracer(target_position: Vector3) -> void:
	if _muzzle == null:
		return

	var start_position: Vector3 = _muzzle.global_position
	var distance: float = start_position.distance_to(target_position)
	if distance <= 0.01:
		return

	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(0.045, 0.045, distance)

	var tracer: MeshInstance3D = MeshInstance3D.new()
	tracer.mesh = mesh
	tracer.material_override = tracer_material
	get_tree().current_scene.add_child(tracer)
	tracer.global_position = start_position.lerp(target_position, 0.5)
	tracer.look_at(target_position, Vector3.UP)

	var cleanup_timer: SceneTreeTimer = get_tree().create_timer(0.08)
	cleanup_timer.timeout.connect(Callable(tracer, "queue_free"))

func _get_config() -> MinigunConfig:
	if config != null:
		return config
	return MinigunConfig.new()

func set_streamer_avatar_index(avatar_index: int) -> void:
	streamer_avatar_index = int(clamp(avatar_index, 0, 3))
	if _avatar_root == null:
		return

	var index: int = 0
	for child in _avatar_root.get_children():
		var variant: Node3D = child as Node3D
		if variant != null:
			variant.visible = index == streamer_avatar_index
			index += 1
	KitCharacterVisuals.set_weapon_nodes_visible(_avatar_root)

func set_streamer_name(display_name: String) -> void:
	streamer_name = display_name.strip_edges()
	if streamer_name.is_empty():
		streamer_name = "Streamer"
	if _streamer_name_label != null:
		_streamer_name_label.text = streamer_name.to_upper()

func _show_muzzle_flash() -> void:
	if _muzzle_flash == null:
		return

	_muzzle_flash.visible = true
	_muzzle_flash_timer = 0.05

func _update_muzzle_flash(delta: float) -> void:
	if _muzzle_flash == null or not _muzzle_flash.visible:
		return

	_muzzle_flash_timer -= delta
	if _muzzle_flash_timer <= 0.0:
		_muzzle_flash.visible = false

func _update_barrel_spin(delta: float) -> void:
	if _barrel_cluster == null:
		return

	if _barrel_spin_velocity > 0.01:
		_barrel_cluster.rotate_z(_barrel_spin_velocity * delta)
		_barrel_spin_velocity = move_toward(_barrel_spin_velocity, 0.0, 18.0 * delta)

func _on_leader_changed(leader_name: String, _progress: float) -> void:
	_leader_name = leader_name

func _update_avatar_tracking(delta: float) -> void:
	if _avatar_look_root == null:
		return

	var target_position: Vector3 = global_position + Vector3(0.0, 0.0, -10.0)
	var leader: Zombie = _get_leader_zombie()
	if leader != null:
		target_position = leader.global_position

	target_position.y = _avatar_look_root.global_position.y
	if _avatar_look_root.global_position.distance_to(target_position) <= 0.05:
		return

	var current_basis: Basis = _avatar_look_root.global_transform.basis
	_avatar_look_root.look_at(target_position, Vector3.UP)
	var target_transform: Transform3D = _avatar_look_root.global_transform
	target_transform.basis = current_basis.slerp(target_transform.basis, clamp(delta * avatar_turn_speed, 0.0, 1.0))
	_avatar_look_root.global_transform = target_transform

func _get_leader_zombie() -> Zombie:
	if _zombie_manager == null or _leader_name.is_empty():
		return null

	for zombie in _zombie_manager.get_living_zombies():
		if zombie.display_name == _leader_name:
			return zombie
	return null

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
