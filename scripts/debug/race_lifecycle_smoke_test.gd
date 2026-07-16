extends SceneTree

const MAIN_GAME_SCENE := "res://scenes/main/main_game.tscn"
const CITY_HIGHWAY_MAP_ID := MapCatalog.DEFAULT_MAP_ID
const ZOMBIE_COUNT := 3
const FINISH_ZOMBIE_COUNT := 1
const PASS := 0
const FAIL := 1

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run_all")


func _run_all() -> void:
	print("=== Race lifecycle smoke test ===")
	await _run_map_finish_scenario(CITY_HIGHWAY_MAP_ID)
	await _run_map_timeout_scenario(CITY_HIGHWAY_MAP_ID)

	if _failures.is_empty():
		print("SUITE RESULT: PASSED")
		_finish(PASS)
	else:
		for failure in _failures:
			push_error(failure)
		print("SUITE RESULT: FAILED")
		_finish(FAIL)


func _run_map_finish_scenario(map_id: String) -> void:
	print("-- %s finish scenario --" % map_id)
	var ctx: Dictionary = await _boot_scenario(map_id, 180.0, 0.0, true)
	if ctx.is_empty():
		return

	var round_manager: RoundManager = ctx.round_manager
	var debug_join: DebugJoinSource = ctx.debug_join
	var main_game: Node = ctx.main_game

	for _index in range(FINISH_ZOMBIE_COUNT):
		debug_join.request_random_join()
	await create_timer(0.2).timeout

	if round_manager.get_pending_count() < FINISH_ZOMBIE_COUNT:
		_fail("%s finish: only %d queued" % [map_id, round_manager.get_pending_count()])
		main_game.queue_free()
		return

	round_manager.start_round()
	if not await _wait_for_round_state(round_manager, RoundManager.RoundState.RUNNING, 12.0):
		_fail("%s finish: never entered RUNNING" % map_id)
		main_game.queue_free()
		return

	_disable_combat_for_test(main_game)
	_set_goal_enabled(main_game, true)

	if not await _wait_for_round_state(
		round_manager,
		RoundManager.RoundState.ENDED,
		max(ctx.max_race_seconds, 90.0) + 20.0
	):
		_fail("%s finish: never entered ENDED" % map_id)
		main_game.queue_free()
		return

	if round_manager.is_race_timed_out():
		_fail("%s finish: ended by timeout instead of normal resolution" % map_id)

	await _verify_reset_and_rejoin(map_id, round_manager, debug_join, main_game)


func _run_map_timeout_scenario(map_id: String) -> void:
	print("-- %s timeout scenario --" % map_id)
	var ctx: Dictionary = await _boot_scenario(map_id, 8.0, 0.0, false)
	if ctx.is_empty():
		return

	var round_manager: RoundManager = ctx.round_manager
	var debug_join: DebugJoinSource = ctx.debug_join
	var main_game: Node = ctx.main_game

	for _index in range(ZOMBIE_COUNT):
		debug_join.request_random_join()
	await create_timer(0.2).timeout

	round_manager.start_round()
	if not await _wait_for_round_state(round_manager, RoundManager.RoundState.RUNNING, 12.0):
		_fail("%s timeout: never entered RUNNING" % map_id)
		main_game.queue_free()
		return

	_set_goal_enabled(main_game, false)
	_disable_combat_for_test(main_game)

	if not await _wait_for_round_state(round_manager, RoundManager.RoundState.ENDED, 20.0):
		_fail("%s timeout: never entered ENDED" % map_id)
		main_game.queue_free()
		return

	if not round_manager.is_race_timed_out():
		_fail("%s timeout: race ended without timeout flag" % map_id)

	await _verify_reset_and_rejoin(map_id, round_manager, debug_join, main_game)


func _verify_reset_and_rejoin(
	map_id: String,
	round_manager: RoundManager,
	debug_join: DebugJoinSource,
	main_game: Node
) -> void:
	round_manager.reset_round()
	await create_timer(0.35).timeout

	if round_manager.state != RoundManager.RoundState.IDLE:
		_fail("%s: reset did not return to IDLE (state=%s)" % [map_id, round_manager.get_state_text()])
		main_game.queue_free()
		return

	debug_join.request_random_join()
	await create_timer(0.15).timeout
	if round_manager.get_pending_count() < 1:
		_fail("%s: join blocked after reset" % map_id)
		main_game.queue_free()
		return

	print("%s lifecycle scenario passed" % map_id)
	main_game.queue_free()


func _boot_scenario(
	map_id: String,
	max_race_seconds: float,
	auto_reset_seconds: float,
	enable_goal: bool
) -> Dictionary:
	var main_game: Node = await _boot_main_game()
	if main_game == null:
		_fail("%s: main game boot failed" % map_id)
		return {}

	var map_controller: RaceMapController = _node(main_game, "Systems/RaceMapController") as RaceMapController
	var round_manager: RoundManager = _node(main_game, "Systems/RoundManager") as RoundManager
	var debug_join: DebugJoinSource = _node(main_game, "Systems/DebugJoinSource") as DebugJoinSource
	if map_controller == null or round_manager == null or debug_join == null:
		_fail("%s: missing core systems" % map_id)
		main_game.queue_free()
		return {}

	if not map_controller.set_active_map_by_id(map_id):
		_fail("%s: failed to activate map: %s" % [map_id, map_controller.get_last_load_failure_reason()])
		main_game.queue_free()
		return {}
	if map_controller.active_map_id != map_id:
		_fail("%s: active map id mismatch" % map_id)
		main_game.queue_free()
		return {}

	_configure_test_round(round_manager, map_controller, main_game, max_race_seconds, auto_reset_seconds)
	await _ensure_race_systems_active(main_game)
	_set_goal_enabled(main_game, enable_goal)
	_disable_combat_for_test(main_game)

	return {
		"main_game": main_game,
		"round_manager": round_manager,
		"debug_join": debug_join,
		"max_race_seconds": max_race_seconds,
	}


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
	main_game: Node,
	max_race_seconds: float,
	auto_reset_seconds: float
) -> void:
	round_manager.configure_immediate_launch_for_tests()
	if round_manager.round_config != null:
		round_manager.round_config.max_race_duration_seconds = max_race_seconds
		round_manager.round_config.post_round_auto_reset_seconds = auto_reset_seconds
	if map_controller.human_defender_config != null:
		map_controller.human_defender_config.defender_count = 0
	if map_controller.hazard_config != null:
		map_controller.hazard_config.mine_count = 0
		map_controller.hazard_config.sewer_hole_count = 0
		map_controller.hazard_config.obstacle_count = 0

	var zombie_manager: ZombieManager = _node(main_game, "Systems/ZombieManager") as ZombieManager
	if zombie_manager != null:
		zombie_manager.set_spawn_rng_seed(4401)


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


func _set_goal_enabled(main_game: Node, enabled: bool) -> void:
	var streamer_goal: StreamerBaseGoal = _node(main_game, "World/StreamerBase") as StreamerBaseGoal
	if streamer_goal != null:
		streamer_goal.set_goal_enabled(enabled)


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
