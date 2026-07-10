extends SceneTree

## Verifies post-race restart keeps the streamer on the race map with the same roster.
##
## Usage:
##   godot --headless --path . -s res://scripts/debug/race_restart_flow_test.gd

const MAIN_GAME_SCENE := "res://scenes/main/main_game.tscn"
const PASS := 0
const FAIL := 1

var _failures: PackedStringArray = PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Race restart flow test ===")
	var packed: PackedScene = load(MAIN_GAME_SCENE)
	if packed == null:
		_fail("Could not load main game scene")
		_finish()
		return

	var main_game: Node = packed.instantiate()
	root.add_child(main_game)
	await create_timer(0.6).timeout

	var round_manager: RoundManager = main_game.get_node_or_null("Systems/RoundManager") as RoundManager
	var game_flow: GameFlowController = main_game.get_node_or_null("Systems/GameFlowController") as GameFlowController
	var zombie_manager: ZombieManager = main_game.get_node_or_null("Systems/ZombieManager") as ZombieManager
	var debug_join: DebugJoinSource = main_game.get_node_or_null("Systems/DebugJoinSource") as DebugJoinSource
	if round_manager == null or game_flow == null or zombie_manager == null or debug_join == null:
		_fail("Missing core race systems on main game scene")
		main_game.queue_free()
		_finish()
		return

	if game_flow != null:
		game_flow.show_race()
	round_manager.configure_immediate_launch_for_tests()
	if round_manager.round_config != null:
		round_manager.round_config.post_round_auto_reset_seconds = 0.0

	for _i in range(8):
		debug_join.request_random_join()
	await create_timer(0.15).timeout

	round_manager.start_round()
	if not await _wait_for_state(round_manager, RoundManager.RoundState.RUNNING, 12.0):
		_fail("Round did not reach RUNNING")
		main_game.queue_free()
		_finish()
		return

	var roster_before: int = zombie_manager.get_total_count()
	if roster_before <= 0:
		_fail("Expected racers on track before forced end")
		main_game.queue_free()
		_finish()
		return

	round_manager.debug_force_end_round()
	if not await _wait_for_state(round_manager, RoundManager.RoundState.ENDED, 8.0):
		_fail("Round did not reach ENDED after timeout")
		main_game.queue_free()
		_finish()
		return

	if not round_manager.can_restart_same_race():
		_fail("can_restart_same_race() should be true after a finished race")

	if not round_manager.restart_same_race():
		_fail("restart_same_race() returned false")

	await create_timer(0.5).timeout

	if game_flow.get_current_phase() != "race":
		_fail("Restart should stay in race phase, got '%s'" % game_flow.get_current_phase())

	if not await _wait_for_state(round_manager, RoundManager.RoundState.RUNNING, 12.0):
		_fail("Restart did not return to RUNNING (state=%s)" % round_manager.get_state_text())
		main_game.queue_free()
		_finish()
		return

	if zombie_manager.get_total_count() != roster_before:
		_fail(
			"Roster size changed after restart (%d -> %d)"
			% [roster_before, zombie_manager.get_total_count()]
		)

	main_game.queue_free()
	_finish()


func _wait_for_state(round_manager: RoundManager, target_state: int, timeout: float) -> bool:
	var elapsed: float = 0.0
	while elapsed < timeout:
		if round_manager.state == target_state:
			return true
		await create_timer(0.1).timeout
		elapsed += 0.1
	return round_manager.state == target_state


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("SUITE RESULT: PASSED")
		quit(PASS)
	else:
		print("SUITE RESULT: FAILED")
		for failure in _failures:
			print("FAIL: %s" % failure)
		quit(FAIL)
