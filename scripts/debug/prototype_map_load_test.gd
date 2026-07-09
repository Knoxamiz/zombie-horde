extends SceneTree

const MAIN_GAME_SCENE := "res://scenes/main/main_game.tscn"
const CANDIDATE_MAP_ID := "broken_bridge_candidate"
const _BRIDGE_LAYOUT := preload("res://scripts/maps/blueprints/broken_bridge_test_layout.gd")
const PASS := 0
const FAIL := 1

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	print("=== Prototype map load test ===")

	if not MapCatalog.is_entry_playable(MapCatalog.get_entry_by_id(MAP_ID)):
		_fail("Prototype map '%s' must remain non-playable" % MAP_ID)

	var profile_before: StreamerSettingsProfile = StreamerSettingsProfile.load_from_disk()
	var saved_map_index: int = profile_before.selected_map_index if profile_before != null else 0

	var packed: PackedScene = load(MAIN_GAME_SCENE)
	if packed == null:
		_fail("Could not load main game scene")
		_finish(FAIL)
		return

	var main_game: Node = packed.instantiate()
	root.add_child(main_game)
	await create_timer(0.8).timeout

	var map_controller: RaceMapController = main_game.get_node_or_null(
		"Systems/RaceMapController"
	) as RaceMapController
	var zombie_manager: ZombieManager = main_game.get_node_or_null(
		"Systems/ZombieManager"
	) as ZombieManager

	_assert_not_null(map_controller, "RaceMapController")
	_assert_not_null(zombie_manager, "ZombieManager")

	if not _failures.is_empty():
		_finish(FAIL)
		return

	var definition: RaceMapDefinition = MapCatalog.load_definition_by_id(CANDIDATE_MAP_ID)
	_assert_not_null(definition, "broken_bridge_candidate definition")

	if not map_controller.load_prototype_map_for_test(CANDIDATE_MAP_ID):
		_fail("load_prototype_map_for_test returned false for %s" % CANDIDATE_MAP_ID)

	if not map_controller.is_prototype_test_load_active():
		_fail("Prototype test load flag was not set")

	var road_arena: Node3D = main_game.get_node_or_null("World/RoadArena") as Node3D
	_assert_not_null(road_arena, "World/RoadArena")
	if road_arena != null:
		_assert_not_null(road_arena.get_node_or_null("CoreRoad/MapRoot"), "CoreRoad/MapRoot")

	if definition != null:
		_assert_close(zombie_manager.spawn_origin, definition.spawn_origin, "spawn_origin")
		_assert_close(zombie_manager.goal_position, definition.goal_position, "goal_position")
		_assert_vec2_close(zombie_manager.spawn_area_size, definition.spawn_area_size, "spawn_area_size")
		_assert_float_close(
			map_controller.zombie_config.lane_half_width,
			definition.lane_half_width,
			"lane_half_width"
		)
		_assert_float_close(
			map_controller.zombie_config.out_of_bounds_half_width,
			definition.out_of_bounds_half_width,
			"out_of_bounds_half_width"
		)
		_assert_float_close(
			map_controller.zombie_config.out_of_bounds_min_z,
			definition.out_of_bounds_min_z,
			"out_of_bounds_min_z"
		)
		_assert_float_close(
			map_controller.zombie_config.out_of_bounds_max_z,
			definition.out_of_bounds_max_z,
			"out_of_bounds_max_z"
		)
		_assert_float_close(
			map_controller.zombie_config.out_of_bounds_min_y,
			definition.out_of_bounds_min_y,
			"out_of_bounds_min_y"
		)
		_assert_float_close(definition.deck_y, _BRIDGE_LAYOUT.BRIDGE_DECK_Y, "deck_y")
		_assert_close(definition.spawn_origin, _BRIDGE_LAYOUT.get_spawn_origin(), "layout_spawn_origin")
		_assert_close(definition.goal_position, _BRIDGE_LAYOUT.get_goal_position(), "layout_goal_position")
		_assert_close(definition.base_position, _BRIDGE_LAYOUT.get_base_position(), "layout_base_position")
		_assert_close(definition.minigun_position, _BRIDGE_LAYOUT.get_minigun_position(), "layout_minigun_position")
		_assert_float_close(
			map_controller.hazard_config.placement_surface_y,
			_BRIDGE_LAYOUT.BRIDGE_DECK_Y,
			"hazard_placement_surface_y"
		)
		_assert_float_close(
			map_controller.hazard_config.placement_half_width,
			definition.hazard_placement_half_width,
			"hazard_placement_half_width"
		)
		_assert_float_close(
			map_controller.hazard_config.placement_min_z,
			definition.hazard_placement_min_z,
			"hazard_placement_min_z"
		)
		_assert_float_close(
			map_controller.hazard_config.placement_max_z,
			definition.hazard_placement_max_z,
			"hazard_placement_max_z"
		)

	var spectator: SpectatorCameraController = main_game.get_node_or_null(
		"SpectatorCamera"
	) as SpectatorCameraController
	if spectator != null and definition != null:
		var view: Dictionary = RaceMapController.compute_race_camera_view_for_definition(definition)
		var raw_position: Vector3 = view.get("position", Vector3.ZERO)
		_assert_not_close(raw_position, Vector3.ZERO, "computed camera view")
		map_controller.frame_spectator_camera_for_definition(spectator, definition, false)
		var expected_position: Vector3 = _clamp_spectator_position(spectator, raw_position)
		_assert_close(spectator.global_position, expected_position, "camera position")

	if map_controller.load_prototype_map_for_test("missing_map_id"):
		_fail("Expected missing map id prototype load to return false")
	if OS.is_debug_build() or DisplayServer.get_name() == "headless":
		if map_controller.get_last_load_failure_reason().is_empty():
			_fail("Expected loud failure reason for missing prototype map id")
		if not map_controller.is_prototype_test_load_active():
			_fail("Prototype test load should remain active after refused fallback")
	else:
		if map_controller.is_prototype_test_load_active():
			_fail("Prototype flag should clear after release fallback")

	var profile_after: StreamerSettingsProfile = StreamerSettingsProfile.load_from_disk()
	if profile_after != null and profile_after.selected_map_index != saved_map_index:
		_fail(
			"Saved map index changed during prototype test (%d -> %d)"
			% [saved_map_index, profile_after.selected_map_index]
		)

	if MapCatalog.get_playable_count() != 8:
		_fail("Playable map count changed after prototype test (expected 8)")

	if _failures.is_empty():
		print("PASS: prototype map load test for %s" % CANDIDATE_MAP_ID)
		_finish(PASS)
	else:
		_finish(FAIL)


func _assert_not_null(value: Variant, label: String) -> void:
	if value == null:
		_fail("%s was null" % label)


func _assert_close(actual: Vector3, expected: Vector3, label: String) -> void:
	if actual.distance_to(expected) > 0.01:
		_fail("%s expected %s got %s" % [label, expected, actual])


func _assert_vec2_close(actual: Vector2, expected: Vector2, label: String) -> void:
	if actual.distance_to(expected) > 0.01:
		_fail("%s expected %s got %s" % [label, expected, actual])


func _assert_not_close(actual: Vector3, forbidden: Vector3, label: String) -> void:
	if actual.distance_to(forbidden) <= 0.01:
		_fail("%s should not be %s" % [label, forbidden])


func _clamp_spectator_position(
	spectator: SpectatorCameraController,
	target_position: Vector3
) -> Vector3:
	if spectator == null or not spectator.position_limits_enabled:
		return target_position

	var min_x: float = min(spectator.camera_bounds_min.x, spectator.camera_bounds_max.x)
	var max_x: float = max(spectator.camera_bounds_min.x, spectator.camera_bounds_max.x)
	var min_y: float = min(spectator.camera_bounds_min.y, spectator.camera_bounds_max.y)
	var max_y: float = max(spectator.camera_bounds_min.y, spectator.camera_bounds_max.y)
	var min_z: float = min(spectator.camera_bounds_min.z, spectator.camera_bounds_max.z)
	var max_z: float = max(spectator.camera_bounds_min.z, spectator.camera_bounds_max.z)
	return Vector3(
		clampf(target_position.x, min_x, max_x),
		clampf(target_position.y, min_y, max_y),
		clampf(target_position.z, min_z, max_z)
	)


func _assert_float_close(actual: float, expected: float, label: String) -> void:
	if abs(actual - expected) > 0.01:
		_fail("%s expected %.2f got %.2f" % [label, expected, actual])


func _fail(message: String) -> void:
	push_error(message)
	_failures.append(message)


func _finish(exit_code: int) -> void:
	if not _failures.is_empty():
		for message in _failures:
			print("FAIL: %s" % message)
	quit(exit_code)
