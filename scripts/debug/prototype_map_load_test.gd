extends SceneTree

## Verifies playable Broken Bridge loads with kit surfaces and runtime contracts.
##
## Usage:
##   godot --headless --path . -s res://scripts/debug/prototype_map_load_test.gd

const MAIN_GAME_SCENE := "res://scenes/main/main_game.tscn"
const MAP_ID := "broken_bridge_pass"
const PASS := 0
const FAIL := 1

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	print("=== Playable Broken Bridge load test ===")

	if not MapCatalog.is_entry_playable(MapCatalog.get_entry_by_id(MAP_ID)):
		_fail("Playable map '%s' must be enabled" % MAP_ID)

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

	var definition: RaceMapDefinition = MapCatalog.load_definition_by_id(MAP_ID)
	_assert_not_null(definition, "%s definition" % MAP_ID)

	if not map_controller.set_active_map_by_id(MAP_ID):
		_fail("Failed to activate %s: %s" % [MAP_ID, map_controller.get_last_load_failure_reason()])
	elif map_controller.active_map_id != MAP_ID:
		_fail("Active map id mismatch for %s" % MAP_ID)

	var road_arena: Node3D = main_game.get_node_or_null("World/RoadArena") as Node3D
	_assert_not_null(road_arena, "World/RoadArena")
	if road_arena != null:
		var surfaces: Node = road_arena.get_node_or_null("CoreRoad/KitSurfaces")
		if surfaces == null:
			_fail("KitSurfaces missing on %s" % MAP_ID)
		elif surfaces.get_child_count() < 3:
			_fail("Expected multiple KitSurfaces on %s" % MAP_ID)

	if map_controller.zombie_config != null and map_controller.zombie_config.gap_void_zones.is_empty():
		_fail("%s should configure gap_void_zones" % MAP_ID)

	if map_controller.set_active_map_by_id("missing_map_id"):
		_fail("Expected missing map id load to return false")
	if map_controller.get_last_load_failure_reason().is_empty():
		_fail("Expected loud failure reason for missing map id")

	var profile_after: StreamerSettingsProfile = StreamerSettingsProfile.load_from_disk()
	if profile_after != null and profile_after.selected_map_index != saved_map_index:
		_fail(
			"Saved map index changed during load test (%d -> %d)"
			% [saved_map_index, profile_after.selected_map_index]
		)

	if MapCatalog.get_playable_count() != 4:
		_fail("Playable map count changed after load test (expected 4)")

	if _failures.is_empty():
		print("PASS: playable map load test for %s" % MAP_ID)
		_finish(PASS)
	else:
		_finish(FAIL)


func _assert_not_null(value: Variant, label: String) -> void:
	if value == null:
		_fail("%s was null" % label)


func _fail(message: String) -> void:
	push_error(message)
	_failures.append(message)


func _finish(exit_code: int) -> void:
	if not _failures.is_empty():
		for message in _failures:
			print("FAIL: %s" % message)
	quit(exit_code)
