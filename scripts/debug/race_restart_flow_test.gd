extends SceneTree

## Verifies post-race restart keeps the streamer on the race map with the same roster.
##
## Usage:
##   godot --headless --path . -s res://scripts/debug/race_restart_flow_test.gd

const PASS := 0
const FAIL := 1
const BOOT := preload("res://scripts/debug/headless_race_test_boot.gd")

var _failures: PackedStringArray = PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Race restart flow test ===")
	var packed: PackedScene = BOOT.load_main_game_scene()
	if packed == null:
		_fail("Could not load main game scene")
		_finish()
		return

	var main_game: Node = packed.instantiate()
	root.add_child(main_game)
	await create_timer(0.6).timeout

	var systems: Dictionary = BOOT.get_race_systems(main_game)
	var round_manager: RoundManager = systems.get("round_manager")
	var game_flow: GameFlowController = systems.get("game_flow")
	var zombie_manager: ZombieManager = systems.get("zombie_manager")
	var debug_join: DebugJoinSource = systems.get("debug_join")
	var map_controller: RaceMapController = systems.get("map_controller")
	if (
		round_manager == null
		or game_flow == null
		or zombie_manager == null
		or debug_join == null
		or map_controller == null
	):
		_fail("Missing core race systems on main game scene")
		main_game.queue_free()
		_finish()
		return

	map_controller.set_active_map_by_id(MapCatalog.DEFAULT_MAP_ID)
	await create_timer(0.2).timeout
	BOOT.activate_race_phase(main_game)
	BOOT.configure_standard_test_round(round_manager, map_controller)

	for _i in range(8):
		debug_join.request_random_join()
	await create_timer(0.15).timeout

	round_manager.start_round()
	if round_manager.state == RoundManager.RoundState.COUNTDOWN:
		round_manager.launch_round()
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

	var restart_wait: float = RoundManager.RESTART_SAME_RACE_DELAY_SEC + 1.5
	await create_timer(restart_wait).timeout

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
		await create_timer(0.05).timeout
		elapsed += 0.05
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
