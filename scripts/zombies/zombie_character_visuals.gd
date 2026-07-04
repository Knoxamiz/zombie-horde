class_name ZombieCharacterVisuals
extends RefCounted

const BODY_TINT_SHADER: Shader = preload("res://assets/shaders/zombie_body_tint.gdshader")

const COLOR_NON_SUB: Color = Color(0.42, 1.0, 0.28, 1.0)
const COLOR_SUBSCRIBER: Color = Color(1.0, 0.18, 0.12, 1.0)
const COLOR_BITS_CHEER: Color = Color(1.0, 0.82, 0.08, 1.0)
const GLOW_BITS_PULSE: Color = Color(0.78, 0.22, 1.0, 1.0)
const BITS_NAME_SCALE: float = 1.34
const TINT_STRENGTH_VIEWER: float = 0.58
const TINT_STRENGTH_SUBSCRIBER: float = 0.72
const TINT_STRENGTH_BITS: float = 0.68
const TINT_EMISSION_SUBSCRIBER: float = 0.22
const GLOW_PULSE_BASE_ENERGY: float = 1.35

const SKIP_TINT_ROOT_NAME: String = "SupporterUpgrades"


static func get_body_color_for_join_info(join_info: ParticipantJoinInfo, crawler: bool = false) -> Color:
	var tier: ParticipantJoinInfo.SupporterTier = ParticipantJoinInfo.SupporterTier.NONE
	if join_info != null:
		tier = join_info.get_supporter_tier()

	var body_color: Color = COLOR_NON_SUB
	match tier:
		ParticipantJoinInfo.SupporterTier.BITS_DONOR:
			body_color = COLOR_BITS_CHEER
		ParticipantJoinInfo.SupporterTier.GIFT_RECIPIENT, ParticipantJoinInfo.SupporterTier.SUBSCRIBER:
			body_color = COLOR_SUBSCRIBER

	if crawler:
		body_color = body_color.lerp(Color(0.72, 0.52, 0.18, 1.0), 0.28)
	return body_color


static func apply_color_tint(root: Node, tint_color: Color, tier: ParticipantJoinInfo.SupporterTier = ParticipantJoinInfo.SupporterTier.NONE) -> void:
	if root == null:
		return

	for mesh_instance in find_mesh_instances(root):
		_apply_body_tint_shader(mesh_instance, tint_color, tier)


static func apply_color_tint_for_join_info(root: Node, join_info: ParticipantJoinInfo, crawler: bool = false) -> void:
	var tier: ParticipantJoinInfo.SupporterTier = ParticipantJoinInfo.SupporterTier.NONE
	if join_info != null:
		tier = join_info.get_supporter_tier()
	apply_color_tint(root, get_body_color_for_join_info(join_info, crawler), tier)


static func find_mesh_instances(root: Node) -> Array[MeshInstance3D]:
	var results: Array[MeshInstance3D] = []
	_collect_mesh_instances(root, results)
	return results


static func apply_supporter_glow(root: Node, tier: ParticipantJoinInfo.SupporterTier) -> Array[ShaderMaterial]:
	var glow_materials: Array[ShaderMaterial] = []
	if tier != ParticipantJoinInfo.SupporterTier.BITS_DONOR:
		return glow_materials

	for mesh_instance in find_mesh_instances(root):
		if not _should_tint_mesh(mesh_instance):
			continue

		var mesh: Mesh = mesh_instance.mesh
		if mesh == null:
			continue

		for surface_index in range(mesh.get_surface_count()):
			var shader_material: ShaderMaterial = (
				mesh_instance.get_surface_override_material(surface_index) as ShaderMaterial
			)
			if shader_material == null:
				continue

			shader_material.set_shader_parameter("bits_glow_energy", GLOW_PULSE_BASE_ENERGY)
			shader_material.set_shader_parameter("bits_glow_color", GLOW_BITS_PULSE)
			glow_materials.append(shader_material)

	return glow_materials


static func update_supporter_glow_pulse(
	glow_materials: Array[ShaderMaterial],
	pulse_time: float,
	tier: ParticipantJoinInfo.SupporterTier
) -> void:
	if tier != ParticipantJoinInfo.SupporterTier.BITS_DONOR:
		return

	var pulse: float = 0.68 + 0.32 * sin(pulse_time * 5.0)
	var energy: float = GLOW_PULSE_BASE_ENERGY * pulse
	for material in glow_materials:
		if material == null:
			continue
		material.set_shader_parameter("bits_glow_energy", energy)


static func apply_name_label_style(label: Label3D, join_info: ParticipantJoinInfo, base_font_size: int) -> void:
	if label == null:
		return

	var tier: ParticipantJoinInfo.SupporterTier = ParticipantJoinInfo.SupporterTier.NONE
	if join_info != null:
		tier = join_info.get_supporter_tier()

	label.font_size = base_font_size
	match tier:
		ParticipantJoinInfo.SupporterTier.BITS_DONOR:
			label.font_size = maxi(int(round(float(base_font_size) * BITS_NAME_SCALE)), base_font_size + 6)
			label.modulate = GLOW_BITS_PULSE.lerp(Color.WHITE, 0.08)
		ParticipantJoinInfo.SupporterTier.GIFT_RECIPIENT, ParticipantJoinInfo.SupporterTier.SUBSCRIBER:
			label.modulate = COLOR_SUBSCRIBER.lerp(Color.WHITE, 0.12)
		_:
			label.modulate = COLOR_NON_SUB.lerp(Color.WHITE, 0.1)


static func get_label_color_for_tier(tier: ParticipantJoinInfo.SupporterTier) -> Color:
	match tier:
		ParticipantJoinInfo.SupporterTier.BITS_DONOR:
			return GLOW_BITS_PULSE.lerp(Color.WHITE, 0.08)
		ParticipantJoinInfo.SupporterTier.GIFT_RECIPIENT, ParticipantJoinInfo.SupporterTier.SUBSCRIBER:
			return COLOR_SUBSCRIBER.lerp(Color.WHITE, 0.12)
	return COLOR_NON_SUB.lerp(Color.WHITE, 0.1)


static func _apply_body_tint_shader(
	mesh_instance: MeshInstance3D,
	tint_color: Color,
	tier: ParticipantJoinInfo.SupporterTier
) -> void:
	if not _should_tint_mesh(mesh_instance):
		return

	var mesh: Mesh = mesh_instance.mesh
	if mesh == null:
		return

	for surface_index in range(mesh.get_surface_count()):
		var source_material: Material = mesh_instance.get_active_material(surface_index)
		var shader_material: ShaderMaterial = _create_body_tint_material(
			source_material,
			tint_color,
			tier
		)
		mesh_instance.set_surface_override_material(surface_index, shader_material)


static func _create_body_tint_material(
	source_material: Material,
	tint_color: Color,
	tier: ParticipantJoinInfo.SupporterTier
) -> ShaderMaterial:
	var shader_material: ShaderMaterial = ShaderMaterial.new()
	shader_material.resource_local_to_scene = true
	shader_material.shader = BODY_TINT_SHADER

	var source_standard: StandardMaterial3D = source_material as StandardMaterial3D
	if source_standard != null and source_standard.albedo_texture != null:
		shader_material.set_shader_parameter("albedo_tex", source_standard.albedo_texture)

	shader_material.set_shader_parameter("body_tint", tint_color)
	shader_material.set_shader_parameter("tint_strength", _get_tint_strength(tier))
	shader_material.set_shader_parameter("bits_glow_color", GLOW_BITS_PULSE)
	shader_material.set_shader_parameter("bits_glow_energy", 0.0)

	if (
		tier == ParticipantJoinInfo.SupporterTier.SUBSCRIBER
		or tier == ParticipantJoinInfo.SupporterTier.GIFT_RECIPIENT
	):
		shader_material.set_shader_parameter("supporter_emission", tint_color)
		shader_material.set_shader_parameter("supporter_emission_energy", TINT_EMISSION_SUBSCRIBER)
	else:
		shader_material.set_shader_parameter("supporter_emission_energy", 0.0)

	return shader_material


static func _get_tint_strength(tier: ParticipantJoinInfo.SupporterTier) -> float:
	match tier:
		ParticipantJoinInfo.SupporterTier.BITS_DONOR:
			return TINT_STRENGTH_BITS
		ParticipantJoinInfo.SupporterTier.GIFT_RECIPIENT, ParticipantJoinInfo.SupporterTier.SUBSCRIBER:
			return TINT_STRENGTH_SUBSCRIBER
	return TINT_STRENGTH_VIEWER


static func _should_tint_mesh(mesh_instance: MeshInstance3D) -> bool:
	var node: Node = mesh_instance
	while node != null:
		if node.name == SKIP_TINT_ROOT_NAME:
			return false
		node = node.get_parent()
	return true


static func _collect_mesh_instances(node: Node, results: Array[MeshInstance3D]) -> void:
	var mesh_instance: MeshInstance3D = node as MeshInstance3D
	if mesh_instance != null and mesh_instance.mesh != null:
		results.append(mesh_instance)

	for child in node.get_children():
		_collect_mesh_instances(child, results)
