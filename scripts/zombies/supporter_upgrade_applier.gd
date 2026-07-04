class_name SupporterUpgradeApplier
extends RefCounted

const UPGRADE_ROOT_NAME := "SupporterUpgrades"
const HEAD_ATTACH_OFFSET := Vector3(0.0, 1.38, 0.05)
const ICON_PIXEL_SIZE := 0.0028
const GIFT_ICON_OFFSET := Vector3(0.0, 0.22, 0.12)
const BITS_ICON_OFFSET := Vector3(0.0, 0.28, 0.1)


static func clear_upgrades(attach_root: Node3D) -> void:
	if attach_root == null:
		return

	var existing: Node = attach_root.get_node_or_null(UPGRADE_ROOT_NAME)
	if existing != null:
		attach_root.remove_child(existing)
		existing.free()


static func apply_upgrades(attach_root: Node3D, join_info: ParticipantJoinInfo) -> SupporterUpgradeState:
	var state: SupporterUpgradeState = SupporterUpgradeState.new()
	clear_upgrades(attach_root)
	if attach_root == null or join_info == null:
		return state

	state.tier = join_info.get_supporter_tier()
	if state.tier == ParticipantJoinInfo.SupporterTier.NONE:
		return state
	if state.tier == ParticipantJoinInfo.SupporterTier.SUBSCRIBER:
		return state

	var upgrade_root: Node3D = Node3D.new()
	upgrade_root.name = UPGRADE_ROOT_NAME
	attach_root.add_child(upgrade_root)
	state.upgrade_root = upgrade_root

	var head_attach: Node3D = Node3D.new()
	head_attach.name = "HeadAttach"
	head_attach.position = HEAD_ATTACH_OFFSET
	upgrade_root.add_child(head_attach)

	match state.tier:
		ParticipantJoinInfo.SupporterTier.GIFT_RECIPIENT:
			_add_twitch_icon(head_attach, ZombieTierVisuals.TWITCH_GIFT_ICON, GIFT_ICON_OFFSET, 1.0)
		ParticipantJoinInfo.SupporterTier.BITS_DONOR:
			_add_twitch_icon(head_attach, ZombieTierVisuals.TWITCH_BITS_ICON, BITS_ICON_OFFSET, 1.08)
			_add_bits_sparkles(head_attach)

	return state


static func update_pulse(state: SupporterUpgradeState, delta: float) -> void:
	if state == null or state.pulse_materials.is_empty():
		return

	state.pulse_time += delta
	var pulse: float = 0.58 + 0.42 * sin(state.pulse_time * 4.8)
	for material in state.pulse_materials:
		if material == null:
			continue
		material.emission_energy_multiplier = 1.85 * pulse


static func _add_twitch_icon(
	parent: Node3D,
	texture: Texture2D,
	local_position: Vector3,
	scale_multiplier: float
) -> void:
	var sprite: Sprite3D = Sprite3D.new()
	sprite.texture = texture
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.pixel_size = ICON_PIXEL_SIZE * scale_multiplier
	sprite.position = local_position
	sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
	parent.add_child(sprite)


static func _add_bits_sparkles(head_attach: Node3D) -> void:
	var sparkles: CPUParticles3D = CPUParticles3D.new()
	sparkles.name = "BitsSparkles"
	sparkles.amount = 36
	sparkles.lifetime = 0.85
	sparkles.explosiveness = 0.22
	sparkles.randomness = 0.45
	sparkles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	sparkles.emission_sphere_radius = 0.2
	sparkles.direction = Vector3(0.0, 1.0, 0.0)
	sparkles.spread = 42.0
	sparkles.gravity = Vector3(0.0, -0.35, 0.0)
	sparkles.initial_velocity_min = 0.45
	sparkles.initial_velocity_max = 1.1
	sparkles.scale_amount_min = 0.05
	sparkles.scale_amount_max = 0.12
	sparkles.color = ZombieCharacterVisuals.GLOW_BITS_PULSE
	head_attach.add_child(sparkles)
	sparkles.emitting = true
