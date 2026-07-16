extends SceneTree

const MAIN_GAME_SCENE := "res://scenes/main/main_game.tscn"
const CITY_HIGHWAY_MAP_ID := MapCatalog.DEFAULT_MAP_ID
const JOIN_COUNT := 2
const PASS := 0
const FAIL := 1

var _failures: Array[String] = []
var _started_msec: int = 0


func _initialize() -> void:
	call_deferred("_run_all")


func _run_all() -> void:
	_started_msec = Time.get_ticks_msec()
	print("=== Race quick smoke test ===")
	await _run_quick_map_scenario(CITY_HIGHWAY_MAP_ID)

	var elapsed_sec: float = float(Time.get_ticks_msec() - _started_msec) / 1000.0
	if _failures.is_empty():
		print("SUITE RESULT: PASSED (%.1fs)" % elapsed_sec)
		print("QUICK SMOKE RUNTIME: %.1fs (target under 60s)" % elapsed_sec)
		_finish(PASS)
	else:
		for failure in _failures:
			push_error(failure)
		print("SUITE RESULT: FAILED (%.1fs)" % elapsed_sec)
		print("QUICK SMOKE RUNTIME: %.1fs" % elapsed_sec)
		_finish(FAIL)


func _run_quick_map_scenario(map_id: String) -> void:
	print("-- %s quick loop --" % map_id)
	var ctx: Dictionary = await _boot_scenario(map_id)
	if ctx.is_empty():
		return

	var round_manager: RoundManager = ctx.round_manager
	var debug_join: DebugJoinSource = ctx.debug_join
	var zombie_manager: ZombieManager = ctx.zombie_manager
	var main_game: Node = ctx.main_game

	for _index in range(JOIN_COUNT):
		debug_join.request_random_join()
	await create_timer(0.1).timeout

	if round_manager.get_pending_count() < JOIN_COUNT:
		_fail("%s: only %d queued" % [map_id, round_manager.get_pending_count()])
		main_game.queue_free()
		return

	round_manager.start_round()
	if not await _wait_for_round_state(round_manager, RoundManager.RoundState.RUNNING, 8.0):
		_fail("%s: never entered RUNNING" % map_id)
		main_game.queue_free()
		return

	_disable_combat_for_test(main_game)
	_set_goal_enabled(main_game, true)
	_teleport_zombies_to_goal(zombie_manager, ctx.map_controller)

	if not await _wait_for_round_state(round_manager, RoundManager.RoundState.ENDED, 12.0):
		_fail("%s: never entered ENDED after quick finish" % map_id)
		main_game.queue_free()
		return

	await _verify_reset_and_rejoin(map_id, round_manager, debug_join, main_game)


func _verify_reset_and_rejoin(
	map_id: String,
	round_manager: RoundManager,
	debug_join: DebugJoinSource,
	main_game: Node
) -> void:
	round_manager.reset_round()
	await create_timer(0.2).timeout

	if round_manager.state != RoundManager.RoundState.IDLE:
		_fail("%s: reset did not return to IDLE (state=%s)" % [map_id, round_manager.get_state_text()])
		main_game.queue_free()
		return

	debug_join.request_random_join()
	await create_timer(0.1).timeout
	if round_manager.get_pending_count() < 1:
		_fail("%s: join blocked after reset" % map_id)
		main_game.queue_free()
		return

	print("%s quick loop passed" % map_id)
	main_game.queue_free()


func _boot_scenario(map_id: String) -> Dictionary:
	var main_game: Node = await _boot_main_game()
	if main_game == null:
		_fail("%s: main game boot failed" % map_id)
		return {}

	var map_controller: RaceMapController = _node(main_game, "Systems/RaceMapController") as RaceMapController
	var round_manager: RoundManager = _node(main_game, "Systems/RoundManager") as RoundManager
	var zombie_manager: ZombieManager = _node(main_game, "Systems/ZombieManager") as ZombieManager
	var debug_join: DebugJoinSource = _node(main_game, "Systems/DebugJoinSource") as DebugJoinSource
	if map_controller == null or round_manager == null or zombie_manager == null or debug_join == null:
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

	_configure_test_round(round_manager, map_controller, main_game)
	await _ensure_race_systems_active(main_game)

	return {
		"main_game": main_game,
		"map_controller": map_controller,
		"round_manager": round_manager,
		"zombie_manager": zombie_manager,
		"debug_join": debug_join,
	}


func _boot_main_game() -> Node:
	var packed: PackedScene = load(MAIN_GAME_SCENE)
	if packed == null:
		_fail("Could not load main game scene")
		return null

	var main_game: Node = packed.instantiate()
	root.add_child(main_game)
	await create_timer(0.5).timeout
	return main_game


func _configure_test_round(
	round_manager: RoundManager,
	map_controller: RaceMapController,
	main_game: Node
) -> void:
	round_manager.configure_immediate_launch_for_tests()
	if round_manager.round_config != null:
		round_manager.round_config.max_race_duration_seconds = 60.0
		round_manager.round_config.post_round_auto_reset_seconds = 0.0
	if map_controller.human_defender_config != null:
		map_controller.human_defender_config.defender_count = 0
	if map_controller.hazard_config != null:
		map_controller.hazard_config.mine_count = 0
		map_controller.hazard_config.sewer_hole_count = 0
		map_controller.hazard_config.obstacle_count = 0

	var zombie_manager: ZombieManager = _node(main_game, "Systems/ZombieManager") as ZombieManager
	if zombie_manager != null:
		zombie_manager.set_spawn_rng_seed(5501)


func _ensure_race_systems_active(main_game: Node) -> void:
	var flow: GameFlowController = _node(main_game, "Systems/GameFlowController") as GameFlowController
	if flow != null:
		flow.show_race()
	await create_timer(0.2).timeout

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


func _teleport_zombies_to_goal(
	zombie_manager: ZombieManager,
	map_controller: RaceMapController
) -> void:
	var definition: RaceMapDefinition = map_controller.get_active_map_definition()
	var finish_position: Vector3 = Vector3(0.0, 1.5, 42.0)
	if definition != null:
		finish_position = definition.base_position + Vector3(0.0, 1.5, 0.0)

	for zombie in zombie_manager.get_living_zombies():
		if zombie == null or not is_instance_valid(zombie):
			continue
		zombie.global_position = finish_position
		zombie.velocity = Vector3.ZERO

	await create_timer(0.15).timeout


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
		await create_timer(0.05).timeout
		elapsed += 0.05
	return round_manager.state == target_state


func _node(root_node: Node, path: String) -> Node:
	return root_node.get_node_or_null(path)


func _fail(message: String) -> void:
	_failures.append(message)
	print("FAIL: %s" % message)


func _finish(exit_code: int) -> void:
	await create_timer(0.05).timeout
	quit(exit_code)
