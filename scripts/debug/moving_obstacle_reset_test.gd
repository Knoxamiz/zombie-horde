extends SceneTree

const MAIN_GAME_SCENE := "res://scenes/main/main_game.tscn"
const MapAssetLibrary := preload("res://scripts/maps/map_asset_library.gd")
const MapCatalog := preload("res://scripts/maps/map_catalog.gd")
const MapMovingObstacleScript := preload("res://scripts/maps/obstacles/map_moving_obstacle.gd")
const PROBE_MAP_ID := "ai_generated_phase3_moving_hazard_probe"
const PASS := 0
const FAIL := 1

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run_all")


func _run_all() -> void:
	print("=== Moving obstacle reset test ===")
	_test_drop_and_play_assets_registered()
	_test_obstacle_scene_instantiates_and_resets()
	_test_round_reset_signal_resets_obstacle()
	await _test_probe_prototype_load()
	_finish()


func _test_drop_and_play_assets_registered() -> void:
	print("-- drop-and-play assets --")
	var ids: Array[String] = MapAssetLibrary.get_drop_and_play_obstacle_asset_ids()
	if ids.size() < 5:
		_fail("expected at least 5 drop-and-play obstacle assets, got %d" % ids.size())
	for asset_id in ids:
		var asset: Dictionary = MapAssetLibrary.get_asset(asset_id)
		if asset.is_empty():
			_fail("missing drop-and-play asset '%s'" % asset_id)
			continue
		var scene_path: String = str(asset.get("scene_path", ""))
		if not scene_path.ends_with(".tscn") or not ResourceLoader.exists(scene_path):
			_fail("drop-and-play asset '%s' missing scene at %s" % [asset_id, scene_path])
		if not bool(asset.get("reset_safe", false)):
			_fail("drop-and-play asset '%s' must set reset_safe=true" % asset_id)
		var obstacle: Node3D = MapAssetLibrary.instantiate_moving_obstacle(asset_id)
		if obstacle == null:
			_fail("failed to instantiate drop-and-play asset '%s'" % asset_id)
		elif obstacle.get_script() != MapMovingObstacleScript:
			_fail("drop-and-play asset '%s' must instantiate MapMovingObstacle" % asset_id)
		else:
			obstacle.queue_free()


func _test_obstacle_scene_instantiates_and_resets() -> void:
	print("-- obstacle movement + reset --")
	var obstacle: Node3D = MapAssetLibrary.instantiate_moving_obstacle(
		"dp_moving_block_side_to_side"
	)
	if obstacle == null or obstacle.get_script() != MapMovingObstacleScript:
		_fail("could not instantiate dp_moving_block_side_to_side")
		return

	var host := Node3D.new()
	root.add_child(host)
	host.add_child(obstacle)
	obstacle.set("auto_start", true)
	await create_timer(0.15).timeout

	var origin: Vector3 = obstacle.call("get_origin_position")
	if obstacle.position.distance_to(origin) < 0.01:
		_fail("obstacle should move from origin after physics ticks")

	obstacle.call("reset_to_start")
	if obstacle.position.distance_to(origin) > 0.05:
		_fail(
			"reset_to_start did not restore origin (got %s expected %s)"
			% [obstacle.position, origin]
		)

	host.queue_free()


func _test_round_reset_signal_resets_obstacle() -> void:
	print("-- round reset signal --")
	var obstacle: Node3D = MapAssetLibrary.instantiate_moving_obstacle(
		"dp_timed_gate"
	)
	if obstacle == null or obstacle.get_script() != MapMovingObstacleScript:
		_fail("could not instantiate dp_timed_gate")
		return

	var host := Node3D.new()
	root.add_child(host)
	host.add_child(obstacle)
	await create_timer(0.2).timeout
	var origin: Vector3 = obstacle.call("get_origin_position")
	var events: Node = get_root().get_node_or_null("GameEvents")
	if events == null:
		_fail("GameEvents autoload missing for round reset test")
		host.queue_free()
		return
	events.round_reset.emit()
	await create_timer(0.05).timeout
	if obstacle.position.distance_to(origin) > 0.05:
		_fail("GameEvents.round_reset did not reset obstacle transform")
	host.queue_free()


func _test_probe_prototype_load() -> void:
	print("-- phase3 moving hazard probe load --")
	var entry: Dictionary = MapCatalog.get_entry_by_id(PROBE_MAP_ID)
	if entry.is_empty():
		print("Skipping probe load: '%s' is not in MapCatalog" % PROBE_MAP_ID)
		return
	if not MapCatalog.is_prototype_testable(entry):
		print("Skipping probe load: '%s' is not prototype-testable" % PROBE_MAP_ID)
		return

	var packed: PackedScene = load(MAIN_GAME_SCENE)
	if packed == null:
		_fail("Could not load main game scene")
		return

	var main_game: Node = packed.instantiate()
	root.add_child(main_game)
	await create_timer(0.8).timeout

	var map_controller: RaceMapController = main_game.get_node_or_null(
		"Systems/RaceMapController"
	) as RaceMapController
	if map_controller == null:
		_fail("RaceMapController missing")
		main_game.queue_free()
		return

	if not map_controller.load_prototype_map_for_test(PROBE_MAP_ID):
		_fail(
			"load_prototype_map_for_test failed: %s"
			% map_controller.get_last_load_failure_reason()
		)
		main_game.queue_free()
		return
	if map_controller.did_last_load_use_fallback():
		_fail("probe load used City Highway fallback")

	var road_arena: Node3D = main_game.get_node_or_null("World/RoadArena") as Node3D
	var obstacles: Node = (
		road_arena.get_node_or_null("CoreRoad/MapRoot/GameplayLayer/MovingObstacles")
		if road_arena != null
		else null
	)
	if obstacles == null or obstacles.get_child_count() <= 0:
		_fail("probe map should spawn moving obstacles in GameplayLayer/MovingObstacles")

	print("%s probe load passed with %d obstacle(s)" % [PROBE_MAP_ID, obstacles.get_child_count()])
	main_game.queue_free()


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("SUITE RESULT: PASSED")
		quit(PASS)
	else:
		print("SUITE RESULT: FAILED (%d)" % _failures.size())
		quit(FAIL)
