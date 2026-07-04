class_name LobbyZombie
extends RigidBody3D

@export var display_name: String = "Zombie"
@export var impulse_strength: float = 2.4
@export var upward_impulse: float = 0.15
@export var spin_strength: float = 7.5
@export var settle_velocity_threshold: float = 0.42
@export_range(0.1, 1.0, 0.01) var first_bounce_scale: float = 0.55
@export_range(1.0, 1.6, 0.01) var later_bounce_boost: float = 1.24

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _motion_timer: float = 0.0
var _animation_player: AnimationPlayer
var _was_falling: bool = true
var _landings: int = 0
var _join_info: ParticipantJoinInfo
var _supporter_glow_materials: Array[ShaderMaterial] = []
var _supporter_glow_tier: ParticipantJoinInfo.SupporterTier = ParticipantJoinInfo.SupporterTier.NONE
var _supporter_upgrade_state: SupporterUpgradeState
var _awaiting_cage_drop: bool = true
var _gift_spotlight_played: bool = false
var _base_visual_scale: Vector3 = Vector3.ONE
var _glow_pulse_time: float = 0.0
var _base_name_font_size: int = 20

@onready var _name_label: Label3D = get_node_or_null("NameLabel") as Label3D
@onready var _visual_root: Node3D = get_node_or_null("VisualRoot") as Node3D

func _ready() -> void:
	_rng.randomize()
	can_sleep = false
	_join_info = ParticipantJoinInfo.for_name(display_name)
	if _name_label != null:
		_base_name_font_size = _name_label.font_size
	if _visual_root != null:
		_base_visual_scale = _visual_root.scale
	_refresh_name_label()
	_apply_zombie_visuals()
	_animation_player = _find_animation_player(self)
	_play_idle_animation()

func configure_lobby_zombie(new_display_name: String, random_seed: int, join_info: ParticipantJoinInfo = null) -> void:
	display_name = new_display_name
	_join_info = join_info if join_info != null else ParticipantJoinInfo.for_name(new_display_name)
	_rng.seed = random_seed
	_landings = 0
	_was_falling = true
	_awaiting_cage_drop = true
	_gift_spotlight_played = false
	if _visual_root != null:
		_visual_root.scale = _base_visual_scale
	_refresh_name_label()
	_apply_zombie_visuals()
	call_deferred("_drop_into_cage")

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	var velocity: Vector3 = state.get_linear_velocity()

	if velocity.y < -0.35:
		_was_falling = true
		return

	if not _was_falling or velocity.y <= 0.05:
		return

	_was_falling = false
	_landings += 1

	if _landings == 1:
		_awaiting_cage_drop = false
		_trigger_drop_upgrade_effects()

	if _landings == 1:
		state.linear_velocity = Vector3(velocity.x, velocity.y * first_bounce_scale, velocity.z)
	else:
		state.linear_velocity = Vector3(velocity.x, velocity.y * later_bounce_boost, velocity.z)

func _physics_process(delta: float) -> void:
	_update_supporter_glow_pulse(delta)
	_update_supporter_upgrade_pulse(delta)

	_motion_timer -= delta
	if _awaiting_cage_drop:
		return

	if _motion_timer > 0.0:
		return

	_motion_timer = _rng.randf_range(0.55, 1.35)
	if linear_velocity.length_squared() < settle_velocity_threshold:
		apply_central_impulse(_get_random_impulse(impulse_strength * 0.55))
		angular_velocity += _get_random_spin(spin_strength * 0.5)

func _drop_into_cage() -> void:
	if not is_inside_tree():
		return

	sleeping = false
	linear_velocity = Vector3(
		_rng.randf_range(-0.2, 0.2),
		-0.35,
		_rng.randf_range(-0.2, 0.2)
	)
	angular_velocity = _get_random_spin(spin_strength * 0.4)
	_was_falling = true

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
	direction = direction.normalize()
	return direction * strength + Vector3.UP * upward_impulse

func _get_random_spin(strength: float) -> Vector3:
	return Vector3(
		_rng.randf_range(-strength, strength),
		_rng.randf_range(-strength, strength),
		_rng.randf_range(-strength, strength)
	)

func _refresh_name_label() -> void:
	if _name_label == null:
		return
	_name_label.text = display_name
	ZombieCharacterVisuals.apply_name_label_style(_name_label, _join_info, _base_name_font_size)

func _apply_zombie_visuals() -> void:
	if _visual_root == null:
		return

	ZombieCharacterVisuals.apply_color_tint_for_join_info(_visual_root, _join_info)
	_supporter_glow_materials.clear()
	_supporter_glow_tier = ParticipantJoinInfo.SupporterTier.NONE
	if _join_info != null and _join_info.has_supporter_glow():
		_supporter_glow_tier = _join_info.get_supporter_tier()
		_supporter_glow_materials = ZombieCharacterVisuals.apply_supporter_glow(
			_visual_root,
			_supporter_glow_tier
		)
	_apply_supporter_upgrades()

func _apply_supporter_upgrades() -> void:
	if _visual_root == null:
		_supporter_upgrade_state = null
		return

	_supporter_upgrade_state = SupporterUpgradeApplier.apply_upgrades(_visual_root, _join_info)

func _update_supporter_upgrade_pulse(delta: float) -> void:
	SupporterUpgradeApplier.update_pulse(_supporter_upgrade_state, delta)

func _trigger_drop_upgrade_effects() -> void:
	if _join_info == null:
		return

	match _join_info.get_supporter_tier():
		ParticipantJoinInfo.SupporterTier.GIFT_RECIPIENT:
			_play_gift_spotlight()
		ParticipantJoinInfo.SupporterTier.BITS_DONOR:
			_play_bits_drop_scale()

func _play_gift_spotlight() -> void:
	if _gift_spotlight_played:
		return
	_gift_spotlight_played = true

	var spotlight: OmniLight3D = OmniLight3D.new()
	spotlight.name = "GiftSpotlight"
	spotlight.light_color = ZombieCharacterVisuals.COLOR_SUBSCRIBER
	spotlight.light_energy = 4.2
	spotlight.omni_range = 3.4
	spotlight.position = Vector3(0.0, 0.45, 0.0)
	add_child(spotlight)

	var tween: Tween = create_tween()
	tween.tween_property(spotlight, "light_energy", 0.0, 0.7)
	tween.tween_callback(spotlight.queue_free)

func _play_bits_drop_scale() -> void:
	if _visual_root == null:
		return

	var boosted_scale: Vector3 = _base_visual_scale * 1.2
	var tween: Tween = create_tween()
	tween.tween_property(_visual_root, "scale", boosted_scale, 0.12)
	tween.tween_property(_visual_root, "scale", _base_visual_scale, 0.28)

func _update_supporter_glow_pulse(delta: float) -> void:
	if _supporter_glow_materials.is_empty():
		return
	_glow_pulse_time += delta
	ZombieCharacterVisuals.update_supporter_glow_pulse(
		_supporter_glow_materials,
		_glow_pulse_time,
		_supporter_glow_tier
	)

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
