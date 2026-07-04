class_name ZombieCharacterVisuals
extends RefCounted

const BODY_TINT_SHADER: Shader = preload("res://assets/shaders/zombie_body_tint.gdshader")
const FALLBACK_ATLAS_TEXTURE: Texture2D = preload(
	"res://assets/third_party/zombie_apocalypse_kit/imported/Characters/Zombie_Basic_Zombie_Atlas.png"
)

const COLOR_NON_SUB: Color = Color(0.42, 1.0, 0.28, 1.0)
const COLOR_SUBSCRIBER: Color = Color(1.0, 0.18, 0.12, 1.0)
const COLOR_BITS_CHEER: Color = Color(1.0, 0.82, 0.08, 1.0)
const GLOW_BITS_PULSE: Color = Color(0.78, 0.22, 1.0, 1.0)
const BITS_NAME_SCALE: float = 1.34
const TINT_STRENGTH_VIEWER: float = 0.58
const TINT_STRENGTH_SUBSCRIBER: float = 0.72
const TINT_STRENGTH_BITS: float = 0.68
const TINT_EMISSION_SUBSCRIBER: float = 0.22
const GLOW_PULSE_BASE_ENERGY: float = 2.45
const BITS_RIM_STRENGTH: float = 1.15
const BITS_AURA_BASE_ENERGY: float = 2.1
const BITS_AURA_RANGE: float = 2.8
const BITS_CHAMPION_LIGHT_NAME: String = "BitsChampionGlow"

const SKIP_TINT_ROOT_NAME: String = "SupporterUpgrades"


static func get_body_color_for_join_info(join_info: ParticipantJoinInfo, crawler: bool = false) -> Color:
	var tier: ParticipantJoinInfo.SupporterTier = ParticipantJoinInfo.SupporterTier.NONE
	if join_info != null:
		tier = join_info.get_supporter_tier()

	var body_color: Color = COLOR_NON_SUB
	match tier:
		ParticipantJoinInfo.SupporterTier.BITS_DONOR:
			body_color = COLOR_BITS_CHEER
		ParticipantJoinInfo.SupporterTier.GIFT_RECIPIENT:
			body_color = COLOR_SUBSCRIBER
		ParticipantJoinInfo.SupporterTier.SUBSCRIBER:
			body_color = COLOR_NON_SUB

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
	if not ZombieTierVisuals.should_apply_body_tint(tier):
		return
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
			shader_material.set_shader_parameter("bits_rim_strength", BITS_RIM_STRENGTH)
			glow_materials.append(shader_material)

	return glow_materials


static func attach_bits_champion_glow(parent: Node3D) -> OmniLight3D:
	clear_bits_champion_glow(parent)
	if parent == null:
		return null

	var light: OmniLight3D = OmniLight3D.new()
	light.name = BITS_CHAMPION_LIGHT_NAME
	light.light_color = GLOW_BITS_PULSE.lerp(COLOR_BITS_CHEER, 0.22)
	light.light_energy = BITS_AURA_BASE_ENERGY
	light.omni_range = BITS_AURA_RANGE
	light.position = Vector3(0.0, 0.95, 0.0)
	parent.add_child(light)
	return light


static func clear_bits_champion_glow(parent: Node3D) -> void:
	if parent == null:
		return

	var existing: Node = parent.get_node_or_null(BITS_CHAMPION_LIGHT_NAME)
	if existing != null:
		existing.queue_free()


static func update_bits_champion_glow(light: OmniLight3D, pulse_time: float) -> void:
	if light == null:
		return

	var pulse: float = 0.58 + 0.42 * sin(pulse_time * 4.4)
	light.light_energy = BITS_AURA_BASE_ENERGY * pulse + 0.55
	light.light_color = GLOW_BITS_PULSE.lerp(COLOR_BITS_CHEER, 0.18 + 0.12 * pulse)


static func update_supporter_glow_pulse(
	glow_materials: Array[ShaderMaterial],
	pulse_time: float,
	tier: ParticipantJoinInfo.SupporterTier
) -> void:
	if tier != ParticipantJoinInfo.SupporterTier.BITS_DONOR:
		return

	var pulse: float = 0.58 + 0.42 * sin(pulse_time * 4.4)
	var energy: float = GLOW_PULSE_BASE_ENERGY * pulse
	var rim_strength: float = BITS_RIM_STRENGTH * (0.82 + 0.18 * pulse)
	for material in glow_materials:
		if material == null:
			continue
		material.set_shader_parameter("bits_glow_energy", energy)
		material.set_shader_parameter("bits_rim_strength", rim_strength)


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
		ParticipantJoinInfo.SupporterTier.GIFT_RECIPIENT:
			label.modulate = COLOR_SUBSCRIBER.lerp(Color.WHITE, 0.12)
		ParticipantJoinInfo.SupporterTier.SUBSCRIBER:
			label.modulate = COLOR_NON_SUB.lerp(Color.WHITE, 0.1)
		_:
			label.modulate = COLOR_NON_SUB.lerp(Color.WHITE, 0.1)


static func get_label_color_for_tier(tier: ParticipantJoinInfo.SupporterTier) -> Color:
	match tier:
		ParticipantJoinInfo.SupporterTier.BITS_DONOR:
			return GLOW_BITS_PULSE.lerp(Color.WHITE, 0.08)
		ParticipantJoinInfo.SupporterTier.GIFT_RECIPIENT:
			return COLOR_SUBSCRIBER.lerp(Color.WHITE, 0.12)
		ParticipantJoinInfo.SupporterTier.SUBSCRIBER:
			return COLOR_NON_SUB.lerp(Color.WHITE, 0.1)
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
			mesh_instance,
			surface_index,
			source_material,
			tint_color,
			tier
		)
		mesh_instance.set_surface_override_material(surface_index, shader_material)


static func _create_body_tint_material(
	mesh_instance: MeshInstance3D,
	surface_index: int,
	source_material: Material,
	tint_color: Color,
	tier: ParticipantJoinInfo.SupporterTier
) -> ShaderMaterial:
	var shader_material: ShaderMaterial = ShaderMaterial.new()
	shader_material.resource_local_to_scene = true
	shader_material.shader = BODY_TINT_SHADER

	var source_standard: StandardMaterial3D = _resolve_standard_material(
		mesh_instance,
		surface_index,
		source_material
	)
	var albedo_texture: Texture2D = _resolve_albedo_texture(mesh_instance, surface_index, source_standard)
	shader_material.set_shader_parameter("albedo_tex", albedo_texture)
	shader_material.set_shader_parameter("body_tint", tint_color)
	shader_material.set_shader_parameter("tint_strength", _get_tint_strength(tier))
	shader_material.set_shader_parameter("bits_glow_color", GLOW_BITS_PULSE)
	shader_material.set_shader_parameter("bits_glow_energy", 0.0)
	shader_material.set_shader_parameter("bits_rim_strength", 0.0)

	var roughness: float = 1.0
	var metallic: float = 0.0
	if source_standard != null:
		roughness = source_standard.roughness
		metallic = source_standard.metallic
	shader_material.set_shader_parameter("material_roughness", roughness)
	shader_material.set_shader_parameter("material_metallic", metallic)

	if tier == ParticipantJoinInfo.SupporterTier.GIFT_RECIPIENT:
		shader_material.set_shader_parameter("supporter_emission", tint_color)
		shader_material.set_shader_parameter("supporter_emission_energy", TINT_EMISSION_SUBSCRIBER)
	else:
		shader_material.set_shader_parameter("supporter_emission_energy", 0.0)

	return shader_material


static func _resolve_standard_material(
	mesh_instance: MeshInstance3D,
	surface_index: int,
	source_material: Material
) -> StandardMaterial3D:
	var standard: StandardMaterial3D = source_material as StandardMaterial3D
	if standard != null:
		return standard

	var mesh: Mesh = mesh_instance.mesh
	if mesh == null:
		return null

	return mesh.surface_get_material(surface_index) as StandardMaterial3D


static func _resolve_albedo_texture(
	mesh_instance: MeshInstance3D,
	surface_index: int,
	source_standard: StandardMaterial3D
) -> Texture2D:
	if source_standard != null and source_standard.albedo_texture != null:
		return source_standard.albedo_texture

	var mesh: Mesh = mesh_instance.mesh
	if mesh != null:
		var surface_material: StandardMaterial3D = mesh.surface_get_material(surface_index) as StandardMaterial3D
		if surface_material != null and surface_material.albedo_texture != null:
			return surface_material.albedo_texture

	return FALLBACK_ATLAS_TEXTURE


static func _get_tint_strength(tier: ParticipantJoinInfo.SupporterTier) -> float:
	match tier:
		ParticipantJoinInfo.SupporterTier.BITS_DONOR:
			return TINT_STRENGTH_BITS
		ParticipantJoinInfo.SupporterTier.GIFT_RECIPIENT:
			return TINT_STRENGTH_SUBSCRIBER
		ParticipantJoinInfo.SupporterTier.SUBSCRIBER:
			return TINT_STRENGTH_VIEWER
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
