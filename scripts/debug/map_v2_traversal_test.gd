extends SceneTree

## Isolated real-runner traversal proof for the disabled Map V2 graybox. The catalog is
## mutated only in this test process so the prototype remains unavailable in
## normal play.

const MAIN_GAME_SCENE := "res://scenes/main/main_game.tscn"
const MAP_ID := "v2_graybox_prototype"
const ZOMBIE_COUNT := 6
const TIMEOUT_SECONDS := 45.0

var _failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Map V2 real zombie traversal test ===")
	_enable_prototype_for_this_process()
	var packed: PackedScene = load(MAIN_GAME_SCENE) as PackedScene
	if packed == null:
		_fail("Could not load the main game scene")
		_finish()
		return

	var main_game: Node = packed.instantiate()
	root.add_child(main_game)
	await create_timer(0.8).timeout
	var map_controller: RaceMapController = main_game.get_node_or_null(
		"Systems/RaceMapController"
	) as RaceMapController
	var round_manager: RoundManager = main_game.get_node_or_null(
		"Systems/RoundManager"
	) as RoundManager
	var zombie_manager: ZombieManager = main_game.get_node_or_null(
		"Systems/ZombieManager"
	) as ZombieManager
	var debug_join: DebugJoinSource = main_game.get_node_or_null(
		"Systems/DebugJoinSource"
	) as DebugJoinSource
	if map_controller == null or round_manager == null or zombie_manager == null or debug_join == null:
		_fail("Main game is missing a required race system")
		main_game.queue_free()
		_finish()
		return

	if not map_controller.set_active_map_by_id(MAP_ID):
		_fail("RaceMapController refused the isolated V2 prototype")
		main_game.queue_free()
		_finish()
		return
	await create_timer(0.8).timeout
	if map_controller.active_map_id != MAP_ID:
		_fail("V2 prototype did not become the active isolated test map")

	var navigation_world: RaceNavigationWorld = main_game.get_node_or_null(
		"World/RoadArena/RaceNavigationWorld"
	) as RaceNavigationWorld
	if navigation_world == null:
		_fail("V2 prototype did not create RaceNavigationWorld")
	else:
		var navigation_wait: float = 0.0
		while not navigation_world.is_ready_for_agents() and navigation_wait < 8.0:
			await create_timer(0.1).timeout
			navigation_wait += 0.1
		if not navigation_world.is_ready_for_agents():
			_fail("V2 navigation did not become ready")

	round_manager.configure_immediate_launch_for_tests()
	if round_manager.round_config != null:
		round_manager.round_config.max_race_duration_seconds = TIMEOUT_SECONDS + 15.0
	if map_controller.human_defender_config != null:
		map_controller.human_defender_config.defender_count = 0
	var flow: GameFlowController = main_game.get_node_or_null(
		"Systems/GameFlowController"
	) as GameFlowController
	if flow != null:
		flow.show_race()
	for _join_index in ZOMBIE_COUNT:
		debug_join.request_random_join()
	await create_timer(0.2).timeout

	round_manager.start_round()
	if not await _wait_for_running(round_manager, 12.0):
		_fail("V2 round never entered RUNNING")
		main_game.queue_free()
		_finish()
		return
	var minigun: BaseMinigun = main_game.get_node_or_null("World/BaseMinigun") as BaseMinigun
	if minigun != null:
		minigun.set_round_active(false)

	var elapsed: float = 0.0
	var best_progress: float = 0.0
	var reached_finish: int = 0
	while elapsed < TIMEOUT_SECONDS:
		await create_timer(0.25).timeout
		elapsed += 0.25
		for zombie in zombie_manager.get_children():
			if not zombie is Zombie:
				continue
			var runner := zombie as Zombie
			best_progress = maxf(best_progress, runner.get_progress())
			if runner.has_finished_race():
				reached_finish += 1
		if reached_finish > 0 or best_progress >= 0.999:
			break
		reached_finish = 0

	print(
		"Map V2 completion: spawned=%d finished=%d best_progress=%.3f elapsed=%.1fs"
		% [zombie_manager.get_total_count(), reached_finish, best_progress, elapsed]
	)
	var streamer_goal: StreamerBaseGoal = main_game.get_node_or_null(
		"World/StreamerBase"
	) as StreamerBaseGoal
	if streamer_goal != null:
		print(
			"V2 goal: pos=%s enabled=%s monitoring=%s mask=%d"
			% [
				streamer_goal.global_position,
				streamer_goal.goal_enabled,
				streamer_goal.monitoring,
				streamer_goal.collision_mask,
			]
		)
	for zombie in zombie_manager.get_children():
		if zombie is Zombie:
			var runner := zombie as Zombie
			print(
				"V2 runner: pos=%s alive=%s finished=%s progress=%.3f layer=%d"
				% [
					runner.global_position,
					runner.is_alive(),
					runner.has_finished_race(),
					runner.get_progress(),
					runner.collision_layer,
				]
			)
	if zombie_manager.get_total_count() < ZOMBIE_COUNT:
		_fail("V2 completion test did not spawn all requested zombies")
	if best_progress < 0.999:
		_fail("No real zombie traversed the complete V2 route")

	main_game.queue_free()
	_finish()


func _enable_prototype_for_this_process() -> void:
	if not MapCatalog.set_isolated_test_playable(MAP_ID, true):
		_fail("V2 prototype could not receive its isolated test override")


func _wait_for_running(round_manager: RoundManager, timeout: float) -> bool:
	var elapsed: float = 0.0
	while elapsed < timeout:
		if round_manager.state == RoundManager.RoundState.RUNNING:
			return true
		await create_timer(0.05).timeout
		elapsed += 0.05
	return false


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("MAP_V2_TRAVERSAL_TEST: PASSED")
		quit(0)
		return
	for failure in _failures:
		print("FAIL: %s" % failure)
	print("MAP_V2_TRAVERSAL_TEST: FAILED")
	quit(1)
