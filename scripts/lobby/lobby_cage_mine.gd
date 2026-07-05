class_name LobbyCageMine
extends Area3D

@export var activation_radius: float = 0.72
@export var launch_strength: float = 9.5
@export var vertical_launch_multiplier: float = 1.35
@export var rearm_delay: float = 4.0
@export var armed_material: Material
@export var spent_material: Material
@export var explosion_scene: PackedScene
@export var explosion_scale: float = 0.42

var _armed: bool = true
var _rearm_timer: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

@onready var _collision_shape: CollisionShape3D = get_node("CollisionShape3D") as CollisionShape3D
@onready var _visual: MeshInstance3D = get_node("Visual") as MeshInstance3D


func _ready() -> void:
	_rng.randomize()
	body_entered.connect(_on_body_entered)
	_apply_radius()
	_apply_visual()


func rearm() -> void:
	_armed = true
	monitoring = true
	_rearm_timer = 0.0
	_apply_visual()


func _physics_process(delta: float) -> void:
	if _armed:
		return

	_rearm_timer += delta
	if _rearm_timer >= rearm_delay:
		rearm()


func _on_body_entered(body: Node3D) -> void:
	if not _armed:
		return

	var lobby_zombie: LobbyZombie = body as LobbyZombie
	if lobby_zombie == null:
		return

	_trigger(lobby_zombie)


func _trigger(lobby_zombie: LobbyZombie) -> void:
	_armed = false
	monitoring = false
	_apply_visual()
	_spawn_explosion()
	GameEvents.camera_shake_requested.emit(0.28, 0.18)
	GameEvents.mine_triggered.emit(lobby_zombie.display_name, global_position)
	GameEvents.world_feedback_requested.emit(
		global_position + Vector3.UP * 0.8,
		"MINE!",
		Color(1.0, 0.22, 0.12, 1.0)
	)
	_launch_lobby_zombie(lobby_zombie)


func _launch_lobby_zombie(lobby_zombie: LobbyZombie) -> void:
	var away: Vector3 = lobby_zombie.global_position - global_position
	away.y = 0.0
	if away.length_squared() <= 0.001:
		away = Vector3(_rng.randf_range(-1.0, 1.0), 0.0, _rng.randf_range(-1.0, 1.0))
	away = away.normalized()

	var impulse: Vector3 = away * launch_strength
	impulse.y = launch_strength * vertical_launch_multiplier
	lobby_zombie.apply_central_impulse(impulse)
	lobby_zombie.angular_velocity += Vector3(
		_rng.randf_range(-5.0, 5.0),
		_rng.randf_range(-5.0, 5.0),
		_rng.randf_range(-5.0, 5.0)
	)


func _apply_radius() -> void:
	if _collision_shape == null:
		return

	var sphere_shape: SphereShape3D = _collision_shape.shape as SphereShape3D
	if sphere_shape != null:
		sphere_shape.radius = activation_radius


func _apply_visual() -> void:
	if _visual == null:
		return

	if _armed:
		_visual.material_override = armed_material
	else:
		_visual.material_override = spent_material


func _spawn_explosion() -> void:
	if explosion_scene == null:
		return

	var effect: Node3D = explosion_scene.instantiate() as Node3D
	if effect == null:
		return

	get_tree().current_scene.add_child(effect)
	effect.global_position = global_position
	effect.scale = Vector3.ONE * explosion_scale
