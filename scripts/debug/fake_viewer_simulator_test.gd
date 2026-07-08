extends SceneTree

const MAIN_GAME_SCENE := "res://scenes/main/main_game.tscn"
const PASS := 0
const FAIL := 1

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run_all")


func _run_all() -> void:
	print("=== Fake viewer simulator test ===")
	await _test_simulator_queues_viewers()
	await _test_reset_stops_simulation()

	if _failures.is_empty():
		print("SUITE RESULT: PASSED")
		_finish(PASS)
	else:
		for failure in _failures:
			push_error(failure)
		print("SUITE RESULT: FAILED")
		_finish(FAIL)


func _test_simulator_queues_viewers() -> void:
	var main_game: Node = await _boot_main_game()
	if main_game == null:
		return

	var round_manager: RoundManager = _node(main_game, "Systems/RoundManager") as RoundManager
	var debug_join: DebugJoinSource = _node(main_game, "Systems/DebugJoinSource") as DebugJoinSource
	var zombie_manager: ZombieManager = _node(main_game, "Systems/ZombieManager") as ZombieManager
	if round_manager == null or debug_join == null:
		_fail("missing RoundManager or DebugJoinSource")
		main_game.queue_free()
		return

	var simulator := FakeViewerSimulator.new()
	main_game.add_child(simulator)
	simulator.configure(debug_join, round_manager, zombie_manager)

	var before_pending: int = round_manager.get_pending_count()
	simulator.simulate_viewers(5)
	var after_pending: int = round_manager.get_pending_count()
	if after_pending - before_pending < 5:
		_fail(
			"expected at least 5 queued joins, got %d (before=%d after=%d)"
			% [after_pending - before_pending, before_pending, after_pending]
		)
	if simulator.get_joins_sent() != 5:
		_fail("expected 5 joins sent, got %d" % simulator.get_joins_sent())
	if simulator.is_running():
		_fail("instant simulation should not remain running")

	print("queue 5 viewers passed")
	main_game.queue_free()


func _test_reset_stops_simulation() -> void:
	var main_game: Node = await _boot_main_game()
	if main_game == null:
		return

	var round_manager: RoundManager = _node(main_game, "Systems/RoundManager") as RoundManager
	var debug_join: DebugJoinSource = _node(main_game, "Systems/DebugJoinSource") as DebugJoinSource
	var zombie_manager: ZombieManager = _node(main_game, "Systems/ZombieManager") as ZombieManager
	if round_manager == null or debug_join == null:
		_fail("missing RoundManager or DebugJoinSource for reset test")
		main_game.queue_free()
		return

	var simulator := FakeViewerSimulator.new()
	main_game.add_child(simulator)
	simulator.configure(debug_join, round_manager, zombie_manager)
	simulator.start_trickle_joins(2.0, 2.0)
	if not simulator.is_running():
		_fail("trickle simulation should be running")
	if simulator.get_pending_simulated_joins() <= 0:
		_fail("trickle simulation should have pending joins")

	round_manager.reset_round()
	await create_timer(0.1).timeout
	if simulator.is_running():
		_fail("reset should stop trickle simulation")
	if simulator.get_pending_simulated_joins() != 0:
		_fail("reset should clear pending simulated joins")

	print("reset stops simulation passed")
	main_game.queue_free()


func _boot_main_game() -> Node:
	var packed: PackedScene = load(MAIN_GAME_SCENE)
	if packed == null:
		_fail("Could not load main game scene")
		return null

	var main_game: Node = packed.instantiate()
	root.add_child(main_game)
	await create_timer(0.5).timeout
	return main_game


func _node(root_node: Node, path: String) -> Node:
	return root_node.get_node_or_null(path)


func _fail(message: String) -> void:
	_failures.append(message)
	print("FAIL: %s" % message)


func _finish(exit_code: int) -> void:
	await create_timer(0.05).timeout
	quit(exit_code)
