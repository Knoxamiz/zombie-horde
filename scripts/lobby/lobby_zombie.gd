class_name LobbyZombie
extends RigidBody3D

@export var display_name: String = "Zombie"
@export var impulse_strength: float = 4.0
@export var upward_impulse: float = 1.25
@export var spin_strength: float = 5.0

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _motion_timer: float = 0.0
var _animation_player: AnimationPlayer

@onready var _name_label: Label3D = get_node_or_null("NameLabel") as Label3D

func _ready() -> void:
	_rng.randomize()
	can_sleep = false
	_refresh_name_label()
	_animation_player = _find_animation_player(self)
	_play_idle_animation()
	call_deferred("_kick")

func configure_lobby_zombie(new_display_name: String, random_seed: int) -> void:
	display_name = new_display_name
	_rng.seed = random_seed
	_refresh_name_label()
	call_deferred("_kick")

func _physics_process(delta: float) -> void:
	_motion_timer -= delta
	if _motion_timer > 0.0:
		return

	_motion_timer = _rng.randf_range(0.55, 1.35)
	if linear_velocity.length_squared() < 1.4:
		apply_central_impulse(_get_random_impulse(impulse_strength * 0.55))
		angular_velocity += _get_random_spin(spin_strength * 0.5)

func _kick() -> void:
	if not is_inside_tree():
		return

	linear_velocity = _get_random_impulse(impulse_strength)
	angular_velocity = _get_random_spin(spin_strength)

func _get_random_impulse(strength: float) -> Vector3:
	var direction: Vector3 = Vector3(
		_rng.randf_range(-1.0, 1.0),
		0.0,
		_rng.randf_range(-1.0, 1.0)
	)
	if direction.length_squared() <= 0.001:
		direction = Vector3.FORWARD
	direction = direction.normalized()
	return direction * strength + Vector3.UP * upward_impulse

func _get_random_spin(strength: float) -> Vector3:
	return Vector3(
		_rng.randf_range(-strength, strength),
		_rng.randf_range(-strength, strength),
		_rng.randf_range(-strength, strength)
	)

func _refresh_name_label() -> void:
	if _name_label != null:
		_name_label.text = display_name

func _play_idle_animation() -> void:
	if _animation_player == null:
		return

	if _animation_player.has_animation("Idle"):
		_set_animation_loop("Idle", true)
		_animation_player.play("Idle")

func _find_animation_player(root: Node) -> AnimationPlayer:
	var animation_player: AnimationPlayer = root as AnimationPlayer
	if animation_player != null:
		return animation_player

	for child in root.get_children():
		var result: AnimationPlayer = _find_animation_player(child)
		if result != null:
			return result
	return null

func _set_animation_loop(animation_name: String, should_loop: bool) -> void:
	if _animation_player == null or not _animation_player.has_animation(animation_name):
		return

	var animation: Animation = _animation_player.get_animation(animation_name)
	if animation != null:
		animation.loop_mode = Animation.LOOP_LINEAR if should_loop else Animation.LOOP_NONE
