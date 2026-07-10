extends SceneTree

const MAIN_GAME_SCENE := "res://scenes/main/main_game.tscn"
const CITY_HIGHWAY_MAP_ID := MapCatalog.DEFAULT_MAP_ID
const FINISH_ZOMBIE_COUNT := 1
const PASS := 0
const FAIL := 1

var _failures: Array[String] = []
var _finish_event_count: int = 0


func _initialize() -> void:
	call_deferred("_run_all")


func _run_all() -> void:
	print("=== Race finish contract test ===")
	await _test_finish_contract_valid_on_load(CITY_HIGHWAY_MAP_ID, false)
	await _test_map_finish_round(CITY_HIGHWAY_MAP_ID, false)
	await _test_miswired_finish_fails_validation(CITY_HIGHWAY_MAP_ID, false)

	if _failures.is_empty():
		print("SUITE RESULT: PASSED")
		_finish(PASS)
	else:
		for failure in _failures:
			push_error(failure)
		print("SUITE RESULT: FAILED")
		_finish(FAIL)


func _test_finish_contract_valid_on_load(map_id: String, use_prototype_loader: bool) -> void:
	print("-- %s finish contract validation --" % map_id)
	var ctx: Dictionary = await _boot_map(map_id, use_prototype_loader)
	if ctx.is_empty():
		return

	var map_controller: RaceMapController = ctx.map_controller
	var main_game: Node = ctx.main_game

	if not map_controller.is_finish_contract_valid():
		_fail("%s: finish contract invalid after load" % map_id)
		main_game.queue_free()
		return

	if not _assert_single_streamer_finish_authority(main_game):
		main_game.queue_free()
		return

	print("%s finish contract validation passed" % map_id)
	main_game.queue_free()


func _test_map_finish_round(map_id: String, use_prototype_loader: bool) -> void:
	print("-- %s finish round scenario --" % map_id)
	var ctx: Dictionary = await _boot_map(map_id, use_prototype_loader)
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

	_set_goal_enabled(main_game, true)
	_disable_combat_for_test(main_game)

	if not await _wait_for_round_state(round_manager, RoundManager.RoundState.ENDED, 200.0):
		_fail("%s finish: never entered ENDED" % map_id)
		main_game.queue_free()
		return

	if round_manager.is_race_timed_out():
		_fail("%s finish: ended by timeout instead of goal" % map_id)

	print("%s finish round scenario passed" % map_id)
	main_game.queue_free()


func _test_no_duplicate_finish_event(map_id: String, use_prototype_loader: bool) -> void:
	print("-- %s duplicate finish guard --" % map_id)
	_finish_event_count = 0
	var game_events: Node = _get_game_events()
	if game_events == null:
		_fail("%s duplicate guard: GameEvents autoload missing" % map_id)
		return
	if not game_events.zombie_reached_base.is_connected(_on_zombie_reached_base_counted):
		game_events.zombie_reached_base.connect(_on_zombie_reached_base_counted)

	var ctx: Dictionary = await _boot_map(map_id, use_prototype_loader)
	if ctx.is_empty():
		_disconnect_finish_counter()
		return

	var round_manager: RoundManager = ctx.round_manager
	var debug_join: DebugJoinSource = ctx.debug_join
	var main_game: Node = ctx.main_game

	debug_join.request_random_join()
	await create_timer(0.2).timeout
	round_manager.start_round()
	if not await _wait_for_round_state(round_manager, RoundManager.RoundState.RUNNING, 12.0):
		_fail("%s duplicate guard: never entered RUNNING" % map_id)
		main_game.queue_free()
		_disconnect_finish_counter()
		return

	_set_goal_enabled(main_game, true)
	_disable_combat_for_test(main_game)

	if not await _wait_for_round_state(round_manager, RoundManager.RoundState.ENDED, 200.0):
		_fail("%s duplicate guard: never entered ENDED" % map_id)
		main_game.queue_free()
		_disconnect_finish_counter()
		return

	if _finish_event_count != FINISH_ZOMBIE_COUNT:
		_fail(
			"%s duplicate guard: expected %d finish events, got %d"
			% [map_id, FINISH_ZOMBIE_COUNT, _finish_event_count]
		)
		main_game.queue_free()
		_disconnect_finish_counter()
		return

	print("%s duplicate finish guard passed" % map_id)
	main_game.queue_free()
	_disconnect_finish_counter()


func _test_miswired_finish_fails_validation(map_id: String, use_prototype_loader: bool) -> void:
	print("-- %s miswired finish validation --" % map_id)
	var ctx: Dictionary = await _boot_map(map_id, use_prototype_loader)
	if ctx.is_empty():
		return

	var map_controller: RaceMapController = ctx.map_controller
	var main_game: Node = ctx.main_game
	var streamer_goal: StreamerBaseGoal = _node(main_game, "World/StreamerBase") as StreamerBaseGoal
	if streamer_goal == null:
		_fail("%s miswired: StreamerBase missing" % map_id)
		main_game.queue_free()
		return

	streamer_goal.global_position += Vector3(0.0, 0.0, 25.0)
	if map_controller.revalidate_finish_contract():
		_fail("%s miswired: finish contract should fail after moving StreamerBase" % map_id)

	print("%s miswired finish validation passed" % map_id)
	main_game.queue_free()


func _assert_single_streamer_finish_authority(main_game: Node) -> bool:
	var streamer_goal: StreamerBaseGoal = _node(main_game, "World/StreamerBase") as StreamerBaseGoal
	if streamer_goal == null:
		_fail("StreamerBase finish authority missing")
		return false

	var map_goal: Node = main_game.get_node_or_null(
		"World/RoadArena/CoreRoad/MapRoot/GameplayLayer/GoalZone/GoalCatch"
	)
	if map_goal != null:
		if map_goal is Area3D:
			var area: Area3D = map_goal as Area3D
			if area.monitoring or area.monitorable or area.get_script() != null:
				_fail("map GoalCatch must be non-authoritative after load")
				return false
		else:
			_fail("unexpected GoalCatch node type: %s" % map_goal.get_class())
			return false

	return true


func _boot_map(map_id: String, use_prototype_loader: bool) -> Dictionary:
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

	if use_prototype_loader:
		if not map_controller.load_prototype_map_for_test(map_id):
			_fail("%s: prototype map load failed" % map_id)
			main_game.queue_free()
			return {}
	else:
		map_controller.set_active_map_by_id(map_id)
		if map_controller.active_map_id != map_id:
			_fail("%s: failed to activate map" % map_id)
			main_game.queue_free()
			return {}

	_configure_test_round(round_manager, map_controller, main_game)
	await _ensure_race_systems_active(main_game)
	_set_goal_enabled(main_game, true)

	return {
		"main_game": main_game,
		"map_controller": map_controller,
		"round_manager": round_manager,
		"debug_join": debug_join,
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
	main_game: Node
) -> void:
	round_manager.configure_immediate_launch_for_tests()
	if round_manager.round_config != null:
		round_manager.round_config.max_race_duration_seconds = 180.0
		round_manager.round_config.post_round_auto_reset_seconds = 0.0
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


func _on_zombie_reached_base_counted(_zombie_node: Node) -> void:
	_finish_event_count += 1


func _disconnect_finish_counter() -> void:
	var game_events: Node = _get_game_events()
	if game_events != null and game_events.zombie_reached_base.is_connected(_on_zombie_reached_base_counted):
		game_events.zombie_reached_base.disconnect(_on_zombie_reached_base_counted)


func _get_game_events() -> Node:
	return root.get_node_or_null("GameEvents")


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
