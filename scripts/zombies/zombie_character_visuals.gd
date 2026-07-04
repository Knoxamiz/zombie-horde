class_name ZombieCharacterVisuals
extends RefCounted

const COLOR_PALETTE: Array[Color] = [
	Color(0.62, 1.0, 0.48, 1.0),
	Color(1.0, 0.92, 0.34, 1.0),
	Color(0.82, 0.52, 1.0, 1.0),
	Color(1.0, 0.42, 0.38, 1.0),
	Color(0.48, 0.82, 1.0, 1.0),
	Color(1.0, 0.62, 0.22, 1.0),
	Color(1.0, 0.52, 0.78, 1.0),
	Color(0.72, 0.78, 0.66, 1.0),
	Color(0.42, 1.0, 0.82, 1.0),
	Color(0.95, 0.48, 0.95, 1.0),
	Color(0.88, 1.0, 0.42, 1.0),
	Color(0.58, 0.62, 1.0, 1.0),
]


static func get_color_for_identity(identity: String) -> Color:
	var trimmed: String = identity.strip_edges()
	if trimmed.is_empty():
		return COLOR_PALETTE[0]

	var hash_value: int = abs(trimmed.hash())
	var palette_index: int = hash_value % COLOR_PALETTE.size()
	return COLOR_PALETTE[palette_index]


static func apply_color_tint(root: Node, tint_color: Color, crawler: bool = false) -> void:
	if root == null:
		return

	var final_tint: Color = tint_color
	if crawler:
		final_tint = tint_color.lerp(Color(0.72, 0.52, 0.18, 1.0), 0.28)

	for mesh_instance in find_mesh_instances(root):
		_tint_mesh_instance(mesh_instance, final_tint)


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
	if tier == ParticipantJoinInfo.SupporterTier.NONE:
		return glow_materials

	var glow_color: Color = _get_glow_color(tier)
	var base_energy: float = _get_glow_energy(tier)

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
			glow_material.rim = 0.35
			glow_material.rim_tint = 0.65
			mesh_instance.set_surface_override_material(surface_index, glow_material)
			glow_materials.append(glow_material)

	return glow_materials


static func update_supporter_glow_pulse(
	glow_materials: Array[StandardMaterial3D],
	pulse_time: float,
	tier: ParticipantJoinInfo.SupporterTier
) -> void:
	var pulse: float = 0.78 + 0.22 * sin(pulse_time * 4.2)
	var base_energy: float = _get_glow_energy(tier)
	for material in glow_materials:
		if material == null:
			continue
		material.emission_energy_multiplier = base_energy * pulse


static func _get_glow_color(tier: ParticipantJoinInfo.SupporterTier) -> Color:
	match tier:
		ParticipantJoinInfo.SupporterTier.BITS_DONOR:
			return Color(1.0, 0.82, 0.18, 1.0)
		ParticipantJoinInfo.SupporterTier.GIFT_RECIPIENT:
			return Color(1.0, 0.42, 0.92, 1.0)
		ParticipantJoinInfo.SupporterTier.SUBSCRIBER:
			return Color(0.62, 0.32, 1.0, 1.0)
	return Color.WHITE


static func _get_glow_energy(tier: ParticipantJoinInfo.SupporterTier) -> float:
	match tier:
		ParticipantJoinInfo.SupporterTier.BITS_DONOR:
			return 1.35
		ParticipantJoinInfo.SupporterTier.GIFT_RECIPIENT:
			return 1.15
		ParticipantJoinInfo.SupporterTier.SUBSCRIBER:
			return 0.95
	return 0.0


static func get_label_glow_color(tier: ParticipantJoinInfo.SupporterTier) -> Color:
	return _get_glow_color(tier).lerp(Color.WHITE, 0.35)


static func _collect_mesh_instances(node: Node, results: Array[MeshInstance3D]) -> void:
	var mesh_instance: MeshInstance3D = node as MeshInstance3D
	if mesh_instance != null and mesh_instance.mesh != null:
		results.append(mesh_instance)

	for child in node.get_children():
		_collect_mesh_instances(child, results)
