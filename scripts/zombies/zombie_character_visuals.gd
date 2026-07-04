class_name ZombieCharacterVisuals
extends RefCounted

const COLOR_NON_SUB: Color = Color(0.52, 1.0, 0.38, 1.0)
const COLOR_SUBSCRIBER: Color = Color(1.0, 0.22, 0.18, 1.0)
const COLOR_BITS_CHEER: Color = Color(1.0, 0.78, 0.12, 1.0)
const GLOW_BITS_PULSE: Color = Color(0.72, 0.22, 1.0, 1.0)
const BITS_NAME_SCALE: float = 1.28


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


static func apply_color_tint(root: Node, tint_color: Color) -> void:
	if root == null:
		return

	for mesh_instance in find_mesh_instances(root):
		_tint_mesh_instance(mesh_instance, tint_color)


static func find_mesh_instances(root: Node) -> Array[MeshInstance3D]:
	var results: Array[MeshInstance3D] = []
	_collect_mesh_instances(root, results)
	return results


static func _tint_mesh_instance(mesh_instance: MeshInstance3D, tint_color: Color) -> void:
	var mesh: Mesh = mesh_instance.mesh
	if mesh == null:
		return

	for surface_index in range(mesh.get_surface_count()):
		var source_material: Material = mesh_instance.get_active_material(surface_index)
		if source_material == null:
			continue

		var tinted_material: StandardMaterial3D = source_material.duplicate() as StandardMaterial3D
		if tinted_material == null:
			continue

		tinted_material.resource_local_to_scene = true
		tinted_material.albedo_color = tint_color
		mesh_instance.set_surface_override_material(surface_index, tinted_material)


static func apply_supporter_glow(root: Node, tier: ParticipantJoinInfo.SupporterTier) -> Array[StandardMaterial3D]:
	var glow_materials: Array[StandardMaterial3D] = []
	if tier != ParticipantJoinInfo.SupporterTier.BITS_DONOR:
		return glow_materials

	var glow_color: Color = GLOW_BITS_PULSE
	var base_energy: float = 1.25

	for mesh_instance in find_mesh_instances(root):
		var mesh: Mesh = mesh_instance.mesh
		if mesh == null:
			continue

		for surface_index in range(mesh.get_surface_count()):
			var source_material: Material = mesh_instance.get_surface_override_material(surface_index)
			if source_material == null:
				source_material = mesh_instance.get_active_material(surface_index)
			if source_material == null:
				continue

			var glow_material: StandardMaterial3D = source_material.duplicate() as StandardMaterial3D
			if glow_material == null:
				continue

			glow_material.resource_local_to_scene = true
			glow_material.emission_enabled = true
			glow_material.emission = glow_color
			glow_material.emission_energy_multiplier = base_energy
			glow_material.rim_enabled = true
			glow_material.rim = 0.42
			glow_material.rim_tint = 0.8
			mesh_instance.set_surface_override_material(surface_index, glow_material)
			glow_materials.append(glow_material)

	return glow_materials


static func update_supporter_glow_pulse(
	glow_materials: Array[StandardMaterial3D],
	pulse_time: float,
	tier: ParticipantJoinInfo.SupporterTier
) -> void:
	if tier != ParticipantJoinInfo.SupporterTier.BITS_DONOR:
		return

	var pulse: float = 0.72 + 0.28 * sin(pulse_time * 4.6)
	var base_energy: float = 1.25
	for material in glow_materials:
		if material == null:
			continue
		material.emission_energy_multiplier = base_energy * pulse


static func apply_name_label_style(label: Label3D, join_info: ParticipantJoinInfo, base_font_size: int) -> void:
	if label == null:
		return

	var tier: ParticipantJoinInfo.SupporterTier = ParticipantJoinInfo.SupporterTier.NONE
	if join_info != null:
		tier = join_info.get_supporter_tier()

	label.font_size = base_font_size
	match tier:
		ParticipantJoinInfo.SupporterTier.BITS_DONOR:
			label.font_size = maxi(int(round(float(base_font_size) * BITS_NAME_SCALE)), base_font_size + 4)
			label.modulate = GLOW_BITS_PULSE.lerp(Color.WHITE, 0.18)
		ParticipantJoinInfo.SupporterTier.GIFT_RECIPIENT, ParticipantJoinInfo.SupporterTier.SUBSCRIBER:
			label.modulate = COLOR_SUBSCRIBER.lerp(Color.WHITE, 0.28)
		_:
			label.modulate = COLOR_NON_SUB.lerp(Color.WHITE, 0.22)


static func get_label_color_for_tier(tier: ParticipantJoinInfo.SupporterTier) -> Color:
	match tier:
		ParticipantJoinInfo.SupporterTier.BITS_DONOR:
			return GLOW_BITS_PULSE.lerp(Color.WHITE, 0.18)
		ParticipantJoinInfo.SupporterTier.GIFT_RECIPIENT, ParticipantJoinInfo.SupporterTier.SUBSCRIBER:
			return COLOR_SUBSCRIBER.lerp(Color.WHITE, 0.28)
	return COLOR_NON_SUB.lerp(Color.WHITE, 0.22)


static func _collect_mesh_instances(node: Node, results: Array[MeshInstance3D]) -> void:
	var mesh_instance: MeshInstance3D = node as MeshInstance3D
	if mesh_instance != null and mesh_instance.mesh != null:
		results.append(mesh_instance)

	for child in node.get_children():
		_collect_mesh_instances(child, results)
