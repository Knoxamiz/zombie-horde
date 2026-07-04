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
		ZombieCharacterVisuals.COLOR_SUBSCRIBER
	):
		push_error("Subscribers should be red")
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

	var body_material: StandardMaterial3D = mesh.get_active_material(0) as StandardMaterial3D
	if body_material == null:
		push_error("Missing body material")
		quit(FAIL)
		return

	if body_material.albedo_texture == null:
		push_error("Bits zombie should preserve albedo texture detail")
		quit(FAIL)
		return

	if body_material.albedo_color.g < body_material.albedo_color.b:
		push_error("Bits zombie body tint should lean gold, not purple")
		quit(FAIL)
		return

	if not body_material.emission_enabled:
		push_error("Bits zombie should have purple pulse emission")
		quit(FAIL)
		return

	var name_label: Label3D = zombie.get_node_or_null("NameLabel") as Label3D
	if name_label == null or name_label.font_size < 30:
		push_error("Bits zombie name label should be larger")
		quit(FAIL)
		return

	print("PASS: tier colors green/red/gold with cheer glow")
	quit(PASS)


func _find_first_mesh(node: Node) -> MeshInstance3D:
	for mesh in ZombieCharacterVisuals.find_mesh_instances(node):
		if mesh.get_surface_override_material(0) != null:
			return mesh
	return null
