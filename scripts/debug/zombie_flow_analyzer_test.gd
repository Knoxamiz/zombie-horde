extends SceneTree

const MAIN_GAME_SCENE := "res://scenes/main/main_game.tscn"
const CITY_HIGHWAY_MAP_ID := MapCatalog.DEFAULT_MAP_ID
const VIEWER_COUNT := 5
const PASS := 0
const FAIL := 1

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run_all")


func _run_all() -> void:
	print("=== Zombie Flow Analyzer test suite ===")
	await _test_analyzer_enable_spawn_report_markers()

	if _failures.is_empty():
		print("SUITE RESULT: PASSED")
		_finish(PASS)
	else:
		for failure in _failures:
			push_error(failure)
		print("SUITE RESULT: FAILED")
		_finish(FAIL)


func _test_analyzer_enable_spawn_report_markers() -> void:
	print("-- Analyzer enable, spawn, report, markers --")
	var main_game: Node = await _boot_main_game()
	if main_game == null:
		return

	var map_controller: RaceMapController = _node(main_game, "Systems/RaceMapController") as RaceMapController
	var round_manager: RoundManager = _node(main_game, "Systems/RoundManager") as RoundManager
	var zombie_manager: ZombieManager = _node(main_game, "Systems/ZombieManager") as ZombieManager
	var debug_join: DebugJoinSource = _node(main_game, "Systems/DebugJoinSource") as DebugJoinSource
	if map_controller == null or round_manager == null or zombie_manager == null or debug_join == null:
		_fail("core systems missing")
		main_game.queue_free()
		return

	var analyzer: ZombieFlowAnalyzer = _ensure_analyzer(main_game)
	if analyzer == null:
		_fail("failed to create ZombieFlowAnalyzer")
		main_game.queue_free()
		return

	analyzer.set_force_enabled(true)
	if not analyzer.is_recording_enabled():
		_fail("analyzer did not enable in debug")
		main_game.queue_free()
		return

	map_controller.set_active_map_by_id(CITY_HIGHWAY_MAP_ID)
	if map_controller.active_map_id != CITY_HIGHWAY_MAP_ID:
		_fail("failed to activate City Highway")
		main_game.queue_free()
		return

	_configure_test_round(round_manager, map_controller, main_game)
	await _ensure_race_systems_active(main_game)

	for _index in range(VIEWER_COUNT):
		debug_join.request_random_join()
	await create_timer(0.2).timeout

	if round_manager.get_pending_count() < VIEWER_COUNT:
		_fail(
			"only %d participants queued (expected %d)"
			% [round_manager.get_pending_count(), VIEWER_COUNT]
		)
		main_game.queue_free()
		return

	round_manager.start_round()
	if not await _wait_for_round_state(round_manager, RoundManager.RoundState.RUNNING, 12.0):
		_fail("round never entered RUNNING")
		main_game.queue_free()
		return

	await create_timer(0.25).timeout
	_disable_combat_for_test(main_game)

	if analyzer.get_marker_count() < VIEWER_COUNT:
		_fail(
			"expected at least %d spawn markers, got %d"
			% [VIEWER_COUNT, analyzer.get_marker_count()]
		)

	round_manager.debug_force_end_round()
	await create_timer(0.35).timeout

	_verify_report(analyzer, CITY_HIGHWAY_MAP_ID, VIEWER_COUNT)

	var marker_count_before_clear: int = analyzer.get_marker_count()
	if marker_count_before_clear <= 0:
		_fail("expected markers before clear")
	else:
		analyzer.clear_markers()
		if analyzer.get_marker_count() != 0:
			_fail("markers were not cleared")

	analyzer.set_force_enabled(false)
	if analyzer.is_recording_enabled():
		_fail("analyzer did not disable")

	if not _scenario_failed("analyzer"):
		print("analyzer enable/spawn/report/markers passed")
	main_game.queue_free()


func _ensure_analyzer(main_game: Node) -> ZombieFlowAnalyzer:
	var systems: Node = _node(main_game, "Systems")
	if systems == null:
		return null

	var analyzer: ZombieFlowAnalyzer = systems.get_node_or_null("ZombieFlowAnalyzer") as ZombieFlowAnalyzer
	if analyzer == null:
		analyzer = ZombieFlowAnalyzer.new()
		analyzer.name = "ZombieFlowAnalyzer"
		analyzer.race_map_controller_path = NodePath("../RaceMapController")
		analyzer.zombie_manager_path = NodePath("../ZombieManager")
		analyzer.markers_root_path = NodePath("../../World/ZombieFlowMarkers")
		systems.add_child(analyzer)

	var world: Node3D = _node(main_game, "World") as Node3D
	if world != null and world.get_node_or_null("ZombieFlowMarkers") == null:
		var markers := ZombieFlowMarkers.new()
		markers.name = "ZombieFlowMarkers"
		world.add_child(markers)

	return analyzer


func _verify_report(analyzer: ZombieFlowAnalyzer, map_id: String, spawned: int) -> void:
	var report: String = analyzer.get_last_report_text()
	if report.is_empty():
		_fail("report was not printed")
		return

	var required_lines: Array[String] = [
		"ZOMBIE FLOW REPORT",
		"map_id:",
		"zombies spawned:",
		"finished:",
		"fell:",
		"lateral_oob:",
		"killed:",
		"stuck:",
		"unresolved:",
		"average progress:",
		"top death area:",
		"top stuck area:",
		"top finish area:",
	]
	for line in required_lines:
		if not report.contains(line):
			_fail("report missing '%s'" % line)

	if not report.contains("map_id: %s" % map_id):
		_fail("report map id mismatch in:\n%s" % report)
	if not report.contains("zombies spawned: %d" % spawned):
		_fail("expected %d spawned in report:\n%s" % [spawned, report])


func _scenario_failed(prefix: String) -> bool:
	for failure in _failures:
		if str(failure).begins_with(prefix):
			return true
	return false


func _boot_main_game() -> Node:
	var packed: PackedScene = load(MAIN_GAME_SCENE)
	if packed == null:
		_fail("Could not load main game scene")
		return null

	var main_game: Node = packed.instantiate()
	root.add_child(main_game)
	await create_timer(0.8).timeout
	return main_game


func _configure_test_round(
	round_manager: RoundManager,
	map_controller: RaceMapController,
	main_game: Node
) -> void:
	if round_manager.round_config != null:
		round_manager.round_config.countdown_seconds = 1
	if map_controller.human_defender_config != null:
		map_controller.human_defender_config.defender_count = 0
	if map_controller.hazard_config != null:
		map_controller.hazard_config.mine_count = 0
		map_controller.hazard_config.sewer_hole_count = 0
		map_controller.hazard_config.obstacle_count = 0

	var zombie_manager: ZombieManager = _node(main_game, "Systems/ZombieManager") as ZombieManager
	if zombie_manager != null:
		zombie_manager.set_spawn_rng_seed(9901)


func _ensure_race_systems_active(main_game: Node) -> void:
	var flow: GameFlowController = _node(main_game, "Systems/GameFlowController") as GameFlowController
	if flow != null:
		flow.show_race()
	await create_timer(0.35).timeout

	var world: Node3D = _node(main_game, "World") as Node3D
	if world != null:
		world.visible = true

	for manager_path in [
		"Systems/ZombieManager",
		"Systems/HazardManager",
		"Systems/PowerupManager",
		"Systems/HumanDefenderManager",
	]:
		var manager: Node = _node(main_game, manager_path)
		if manager != null:
			manager.visible = true


func _disable_combat_for_test(main_game: Node) -> void:
	var minigun: BaseMinigun = _node(main_game, "World/BaseMinigun") as BaseMinigun
	if minigun != null:
		minigun.set_round_active(false)


func _wait_for_round_state(round_manager: RoundManager, target_state: int, timeout: float) -> bool:
	var elapsed: float = 0.0
	while elapsed < timeout:
		if round_manager.state == target_state:
			return true
		await create_timer(0.1).timeout
		elapsed += 0.1
	return round_manager.state == target_state


func _node(root_node: Node, path: String) -> Node:
	return root_node.get_node_or_null(path)


func _fail(message: String) -> void:
	_failures.append(message)
	print("FAIL: %s" % message)


func _finish(exit_code: int) -> void:
	await create_timer(0.1).timeout
	quit(exit_code)
