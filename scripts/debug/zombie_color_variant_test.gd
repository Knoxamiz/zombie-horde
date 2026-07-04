extends SceneTree

const ZOMBIE_SCENE := "res://scenes/zombies/zombie.tscn"
const ZOMBIE_CONFIG := "res://resources/config/zombie_config.tres"
const PASS := 0
const FAIL := 1


func _initialize() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	print("=== Zombie tier color test ===")
	var config: ZombieConfig = load(ZOMBIE_CONFIG) as ZombieConfig
	if config == null:
		push_error("Could not load zombie config")
		quit(FAIL)
		return

	var regular: ParticipantJoinInfo = ParticipantJoinInfo.for_name("Viewer")
	var sub: ParticipantJoinInfo = ParticipantJoinInfo.for_name("SubViewer")
	sub.is_subscriber = true
	var bits: ParticipantJoinInfo = ParticipantJoinInfo.for_name("BitsViewer")
	bits.is_bits_donor = true

	if not ZombieCharacterVisuals.get_body_color_for_join_info(regular).is_equal_approx(
		ZombieCharacterVisuals.COLOR_NON_SUB
	):
		push_error("Regular viewers should be green")
		quit(FAIL)
		return

	if not ZombieCharacterVisuals.get_body_color_for_join_info(sub).is_equal_approx(
		ZombieCharacterVisuals.COLOR_NON_SUB
	):
		push_error("Subscribers should be green")
		quit(FAIL)
		return

	if not ZombieCharacterVisuals.get_body_color_for_join_info(bits).is_equal_approx(
		ZombieCharacterVisuals.COLOR_BITS_CHEER
	):
		push_error("Cheer viewers should be gold")
		quit(FAIL)
		return

	var zombie_packed: PackedScene = load(ZOMBIE_SCENE)
	if zombie_packed == null:
		push_error("Could not load zombie scene")
		quit(FAIL)
		return

	var zombie: Zombie = zombie_packed.instantiate() as Zombie
	if zombie == null:
		push_error("Could not instantiate zombie")
		quit(FAIL)
		return

	root.add_child(zombie)
	zombie.configure_zombie("BitsViewer", config, Vector3.ZERO, Vector3.ZERO, 42, bits)
	await create_timer(0.2).timeout

	var mesh: MeshInstance3D = _find_first_mesh(zombie)
	if mesh == null:
		push_error("Missing tinted mesh")
		quit(FAIL)
		return

	var body_material: ShaderMaterial = mesh.get_surface_override_material(0) as ShaderMaterial
	if body_material == null or body_material.shader != ZombieCharacterVisuals.BODY_TINT_SHADER:
		push_error("Bits zombie should use body-only tint shader")
		quit(FAIL)
		return

	var body_tint: Color = body_material.get_shader_parameter("body_tint")
	if not body_tint.is_equal_approx(ZombieCharacterVisuals.COLOR_BITS_CHEER):
		push_error("Bits zombie body tint should be gold")
		quit(FAIL)
		return

	var albedo_texture: Texture2D = body_material.get_shader_parameter("albedo_tex")
	if albedo_texture == null:
		push_error("Body tint shader should always receive an albedo texture")
		quit(FAIL)
		return

	var glow_energy: float = float(body_material.get_shader_parameter("bits_glow_energy"))
	if glow_energy <= 0.0:
		push_error("Bits zombie should have active body glow energy")
		quit(FAIL)
		return

	var name_label: Label3D = zombie.get_node_or_null("NameLabel") as Label3D
	if name_label == null or name_label.font_size < 30:
		push_error("Bits zombie name label should be larger")
		quit(FAIL)
		return

	print("PASS: body-only tier tint shader with cheer glow")
	quit(PASS)


func _find_first_mesh(node: Node) -> MeshInstance3D:
	for mesh in ZombieCharacterVisuals.find_mesh_instances(node):
		if mesh.get_surface_override_material(0) != null:
			return mesh
	return null
