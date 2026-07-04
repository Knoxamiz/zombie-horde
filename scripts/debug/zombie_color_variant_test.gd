extends SceneTree

const ZOMBIE_SCENE := "res://scenes/zombies/zombie.tscn"
const LOBBY_ZOMBIE_SCENE := "res://scenes/lobby/lobby_zombie.tscn"
const ZOMBIE_CONFIG := "res://resources/config/zombie_config.tres"
const PASS := 0
const FAIL := 1


func _initialize() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	print("=== Zombie color variant test ===")
	var config: ZombieConfig = load(ZOMBIE_CONFIG) as ZombieConfig
	if config == null:
		push_error("Could not load zombie config")
		quit(FAIL)
		return

	var color_a: Color = ZombieCharacterVisuals.get_color_for_identity("ViewerAlpha")
	var color_b: Color = ZombieCharacterVisuals.get_color_for_identity("ViewerBeta")
	if color_a.is_equal_approx(color_b):
		push_error("Different names should map to different zombie colors")
		quit(FAIL)
		return

	var same_again: Color = ZombieCharacterVisuals.get_color_for_identity("ViewerAlpha")
	if not color_a.is_equal_approx(same_again):
		push_error("Same name should keep the same zombie color")
		quit(FAIL)
		return

	var zombie_packed: PackedScene = load(ZOMBIE_SCENE)
	var lobby_packed: PackedScene = load(LOBBY_ZOMBIE_SCENE)
	if zombie_packed == null or lobby_packed == null:
		push_error("Could not load zombie scenes")
		quit(FAIL)
		return

	var zombie: Zombie = zombie_packed.instantiate() as Zombie
	var lobby_zombie: LobbyZombie = lobby_packed.instantiate() as LobbyZombie
	if zombie == null or lobby_zombie == null:
		push_error("Could not instantiate zombies")
		quit(FAIL)
		return

	root.add_child(zombie)
	root.add_child(lobby_zombie)
	zombie.configure_zombie("ViewerAlpha", config, Vector3.ZERO, Vector3.ZERO, 42)
	lobby_zombie.configure_lobby_zombie("ViewerAlpha", 42)
	await create_timer(0.2).timeout

	var race_mesh: MeshInstance3D = _find_first_mesh(zombie)
	var lobby_mesh: MeshInstance3D = _find_first_mesh(lobby_zombie)
	if race_mesh == null or lobby_mesh == null:
		push_error("Could not find tinted zombie meshes")
		quit(FAIL)
		return

	var race_material: Material = race_mesh.get_active_material(0)
	var lobby_material: Material = lobby_mesh.get_active_material(0)
	if race_material == null or lobby_material == null:
		push_error("Zombie meshes missing tinted materials")
		quit(FAIL)
		return

	var race_color: Color = (race_material as StandardMaterial3D).albedo_color
	var lobby_color: Color = (lobby_material as StandardMaterial3D).albedo_color
	if not race_color.is_equal_approx(color_a) or not lobby_color.is_equal_approx(color_a):
		push_error("Tinted materials did not match palette color")
		quit(FAIL)
		return

	print("PASS: zombies get stable per-name color tints in race and lobby")
	quit(PASS)


func _find_first_mesh(node: Node) -> MeshInstance3D:
	for mesh in ZombieCharacterVisuals.find_mesh_instances(node):
		if mesh.get_surface_override_material(0) != null:
			return mesh
	return null
