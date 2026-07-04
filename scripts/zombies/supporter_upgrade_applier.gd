class_name SupporterUpgradeApplier
extends RefCounted

const UPGRADE_ROOT_NAME := "SupporterUpgrades"
const HEAD_ATTACH_OFFSET := Vector3(0.0, 1.38, 0.05)


static func clear_upgrades(attach_root: Node3D) -> void:
	if attach_root == null:
		return

	var existing: Node = attach_root.get_node_or_null(UPGRADE_ROOT_NAME)
	if existing != null:
		existing.queue_free()


static func apply_upgrades(attach_root: Node3D, join_info: ParticipantJoinInfo) -> SupporterUpgradeState:
	var state: SupporterUpgradeState = SupporterUpgradeState.new()
	clear_upgrades(attach_root)
	if attach_root == null or join_info == null:
		return state

	state.tier = join_info.get_supporter_tier()
	if state.tier == ParticipantJoinInfo.SupporterTier.NONE:
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
		ParticipantJoinInfo.SupporterTier.SUBSCRIBER:
			_add_sub_horns(head_attach, state)
		ParticipantJoinInfo.SupporterTier.GIFT_RECIPIENT:
			_add_gift_bandana(head_attach, state)
		ParticipantJoinInfo.SupporterTier.BITS_DONOR:
			_add_bits_crown(head_attach, join_info.bits_amount, state)

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


static func _add_sub_horns(head_attach: Node3D, state: SupporterUpgradeState) -> void:
	var horn_material: StandardMaterial3D = _make_emissive_material(
		ZombieCharacterVisuals.COLOR_SUBSCRIBER,
		0.85
	)
	_add_horn(head_attach, horn_material, Vector3(-0.11, 0.04, 0.0), 18.0)
	_add_horn(head_attach, horn_material, Vector3(0.11, 0.04, 0.0), -18.0)
	state.pulse_materials.append(horn_material)


static func _add_horn(
	parent: Node3D,
	material: StandardMaterial3D,
	local_position: Vector3,
	tilt_degrees: float
) -> void:
	var horn_mesh: CylinderMesh = CylinderMesh.new()
	horn_mesh.top_radius = 0.015
	horn_mesh.bottom_radius = 0.055
	horn_mesh.height = 0.2

	var horn: MeshInstance3D = MeshInstance3D.new()
	horn.mesh = horn_mesh
	horn.material_override = material
	horn.position = local_position + Vector3(0.0, 0.08, 0.0)
	horn.rotation_degrees = Vector3(0.0, 0.0, tilt_degrees)
	parent.add_child(horn)


static func _add_gift_bandana(head_attach: Node3D, state: SupporterUpgradeState) -> void:
	var bandana_material: StandardMaterial3D = _make_emissive_material(
		ZombieCharacterVisuals.COLOR_SUBSCRIBER.darkened(0.08),
		0.95
	)
	var bandana_mesh: BoxMesh = BoxMesh.new()
	bandana_mesh.size = Vector3(0.4, 0.07, 0.24)

	var bandana: MeshInstance3D = MeshInstance3D.new()
	bandana.mesh = bandana_mesh
	bandana.material_override = bandana_material
	bandana.position = Vector3(0.0, 0.1, 0.08)
	bandana.rotation_degrees = Vector3(-8.0, 0.0, 0.0)
	head_attach.add_child(bandana)

	var knot_mesh: BoxMesh = BoxMesh.new()
	knot_mesh.size = Vector3(0.1, 0.08, 0.08)
	var knot: MeshInstance3D = MeshInstance3D.new()
	knot.mesh = knot_mesh
	knot.material_override = bandana_material
	knot.position = Vector3(0.16, 0.04, -0.02)
	knot.rotation_degrees = Vector3(0.0, 0.0, 24.0)
	head_attach.add_child(knot)
	state.pulse_materials.append(bandana_material)


static func _add_bits_crown(head_attach: Node3D, bits_amount: int, state: SupporterUpgradeState) -> void:
	var crown_material: StandardMaterial3D = _make_emissive_material(
		ZombieCharacterVisuals.COLOR_BITS_CHEER,
		1.65
	)
	var spike_count: int = 5
	if bits_amount >= 500:
		spike_count = 7
	elif bits_amount >= 100:
		spike_count = 6

	var arc_radius: float = 0.16
	for spike_index in range(spike_count):
		var angle: float = PI + (float(spike_index) / float(spike_count - 1)) * PI
		var spike_mesh: BoxMesh = BoxMesh.new()
		spike_mesh.size = Vector3(0.05, 0.12, 0.05)

		var spike: MeshInstance3D = MeshInstance3D.new()
		spike.mesh = spike_mesh
		spike.material_override = crown_material
		spike.position = Vector3(cos(angle) * arc_radius, 0.12, sin(angle) * arc_radius * 0.55)
		spike.rotation_degrees = Vector3(0.0, rad_to_deg(angle) + 90.0, 0.0)
		head_attach.add_child(spike)

	var band_mesh: BoxMesh = BoxMesh.new()
	band_mesh.size = Vector3(0.34, 0.05, 0.34)
	var band: MeshInstance3D = MeshInstance3D.new()
	band.mesh = band_mesh
	band.material_override = crown_material
	band.position = Vector3(0.0, 0.04, 0.0)
	head_attach.add_child(band)
	state.pulse_materials.append(crown_material)

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


static func _make_emissive_material(base_color: Color, emission_energy: float) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.resource_local_to_scene = true
	material.albedo_color = base_color
	material.emission_enabled = true
	material.emission = base_color.lerp(Color.WHITE, 0.28)
	material.emission_energy_multiplier = emission_energy
	material.metallic = 0.42
	material.roughness = 0.3
	return material
