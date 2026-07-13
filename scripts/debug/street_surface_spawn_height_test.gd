extends SceneTree

const MAIN_GAME_SCENE := "res://scenes/main/main_game.tscn"
const MAP_ID := "broken_bridge_pass"
const PASS := 0
const FAIL := 1
const PRESETS := preload("res://scripts/maps/map_kit_layout_presets.gd")
const SURFACE_BUILDER := preload("res://scripts/maps/kit_map_surface_builder.gd")

var _failures: PackedStringArray = PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Street surface spawn height test ===")
	var main_game: Node = await _boot_main_game()
	if main_game == null:
		_finish()
		return

	var map_controller: Node = main_game.get_node_or_null(
		"Systems/RaceMapController"
	)
	var hazard_manager: Node = main_game.get_node_or_null(
		"Systems/HazardManager"
	)
	var powerup_manager: Node = main_game.get_node_or_null(
		"Systems/PowerupManager"
	)
	var defender_manager: Node = main_game.get_node_or_null(
		"Systems/HumanDefenderManager"
	)
	if (
		map_controller == null
		or hazard_manager == null
		or powerup_manager == null
		or defender_manager == null
	):
		_fail("Main game is missing one or more spawn managers")
		main_game.queue_free()
		_finish()
		return

	if not bool(map_controller.call("set_active_map_by_id", MAP_ID)):
		_fail("Could not activate Broken Bridge")
		main_game.queue_free()
		_finish()
		return
	await create_timer(0.5).timeout

	_verify_surface_zones(map_controller)
	_configure_spawn_counts(map_controller)

	hazard_manager.call("setup_round", 31)
	var reserved_positions: Array[Vector3] = hazard_manager.call("get_reserved_positions")
	powerup_manager.call("setup_round", 31, reserved_positions)
	for raw_position in powerup_manager.call("get_reserved_positions"):
		var position: Vector3 = raw_position
		reserved_positions.append(position)
	defender_manager.call("setup_round", 31, reserved_positions)

	var layout: Dictionary = PRESETS.get_preset(MAP_ID)
	var surface_pieces: Array = SURFACE_BUILDER.resolve_layout_surface_pieces(layout)
	_verify_spawn_group(hazard_manager, "Mine_", surface_pieces, 0.18)
	_verify_spawn_group(hazard_manager, "SewerHole_", surface_pieces, 0.08)
	_verify_spawn_group(hazard_manager, "RoadObstacle_", surface_pieces, 0.45)
	_verify_spawn_group(powerup_manager, "BoostPad_", surface_pieces, 0.12)
	_verify_spawn_group(defender_manager, "HumanDefender_", surface_pieces, 0.12)

	main_game.queue_free()
	_finish()


func _boot_main_game() -> Node:
	var packed: PackedScene = load(MAIN_GAME_SCENE)
	if packed == null:
		_fail("Could not load main game scene")
		return null

	var main_game: Node = packed.instantiate()
	root.add_child(main_game)
	await create_timer(0.5).timeout
	return main_game


func _verify_surface_zones(map_controller: Node) -> void:
	var hazard_config: Resource = map_controller.get("hazard_config") as Resource
	if hazard_config == null:
		_fail("HazardConfig missing")
		return
	var zones: Array = hazard_config.get("placement_surface_zones")
	if zones.is_empty():
		_fail("Broken Bridge did not apply placement surface zones")
	var surface_y: float = float(hazard_config.get("placement_surface_y"))
	if surface_y < 6.0:
		_fail(
			"Broken Bridge fallback placement surface is below bridge deck: %.2f"
			% surface_y
		)


func _configure_spawn_counts(map_controller: Node) -> void:
	var hazard_config: Resource = map_controller.get("hazard_config") as Resource
	if hazard_config != null:
		hazard_config.set("mine_count", 8)
		hazard_config.set("sewer_hole_count", 3)
		hazard_config.set("obstacle_count", 8)
		hazard_config.set("obstacle_lane_count", 1)
		hazard_config.set("max_obstacles_per_segment", 1)
		hazard_config.set("guaranteed_open_lanes_per_segment", 0)
	var powerup_config: Resource = map_controller.get("powerup_config") as Resource
	if powerup_config != null:
		powerup_config.set("boost_pad_count", 6)
	var human_defender_config: Resource = map_controller.get("human_defender_config") as Resource
	if human_defender_config != null:
		human_defender_config.set("defender_count", 2)


func _verify_spawn_group(
	parent: Node,
	name_prefix: String,
	surface_pieces: Array,
	expected_offset: float
) -> void:
	var checked_count: int = 0
	for child in parent.get_children():
		if not str(child.name).begins_with(name_prefix):
			continue
		var node_3d: Node3D = child as Node3D
		if node_3d == null:
			continue
		checked_count += 1
		var position: Vector3 = node_3d.global_position
		if not _has_surface_at_z(surface_pieces, position.z):
			_fail("%s spawned in a bridge gap at z=%.2f" % [child.name, position.z])
			continue
		var expected_y: float = (
			SURFACE_BUILDER.get_top_y_at_z(surface_pieces, position.z, -9999.0)
			+ expected_offset
		)
		if absf(position.y - expected_y) > 0.08:
			_fail(
				"%s y %.2f should match street y %.2f at z=%.2f"
				% [child.name, position.y, expected_y, position.z]
			)

	if checked_count == 0:
		_fail("Expected at least one %s spawn" % name_prefix)


func _has_surface_at_z(surface_pieces: Array, z: float) -> bool:
	for raw_spec in surface_pieces:
		if raw_spec is not Dictionary:
			continue
		var spec: Dictionary = raw_spec
		var z0: float = float(spec.get("z0", 0.0))
		var z1: float = float(spec.get("z1", z0))
		if z >= z0 - 0.05 and z <= z1 + 0.05:
			return true
	return false


func _fail(message: String) -> void:
	_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("StreetSurfaceSpawnHeightTest: PASSED")
		quit(PASS)
		return
	print("StreetSurfaceSpawnHeightTest: FAILED")
	for failure in _failures:
		push_error(failure)
	quit(FAIL)
