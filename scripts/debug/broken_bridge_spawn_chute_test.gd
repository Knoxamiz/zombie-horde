extends SceneTree

## Verifies spawn bowling bumpers contain a crowded lobby on Broken Bridge.
## Usage:
##   godot --headless --path . -s res://scripts/debug/broken_bridge_spawn_chute_test.gd

const MAIN_GAME_SCENE := "res://scenes/main/main_game.tscn"
const MAP_ID := "broken_bridge_pass"
const PRESETS := preload("res://scripts/maps/map_kit_layout_presets.gd")
const ZOMBIE_COUNT := 48
const PASS := 0
const FAIL := 1

var _failures: PackedStringArray = PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Broken Bridge spawn chute test ===")
	var layout: Dictionary = PRESETS.get_preset("broken_bridge_pass")
	var chute_half_width: float = float(layout.get("spawn_chute_half_width", 5.0))

	var packed: PackedScene = load(MAIN_GAME_SCENE)
	if packed == null:
		_fail("Could not load main game scene")
		_finish()
		return

	var main_game: Node = packed.instantiate()
	root.add_child(main_game)
	await create_timer(0.6).timeout

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
		_fail("Missing core systems")
		main_game.queue_free()
		_finish()
		return

	var boundaries: Node = null

	map_controller.set_active_map_by_id(MAP_ID)
	await create_timer(0.15).timeout
	boundaries = main_game.get_node_or_null("World/RoadArena/CoreRoad/GameplayBoundaries")
	if boundaries == null or boundaries.get_child_count() < 2:
		_fail("GameplayBoundaries spawn bumpers missing after map load")
	var flow: GameFlowController = main_game.get_node_or_null(
		"Systems/GameFlowController"
	) as GameFlowController
	if flow != null:
		flow.show_race()
	round_manager.configure_immediate_launch_for_tests()
	if map_controller.human_defender_config != null:
		map_controller.human_defender_config.defender_count = 0

	for _i in range(ZOMBIE_COUNT):
		debug_join.request_random_join()
	await create_timer(0.15).timeout

	round_manager.start_round()
	if round_manager.state == RoundManager.RoundState.COUNTDOWN:
		round_manager.launch_round()
	if not await _wait_for_state(round_manager, RoundManager.RoundState.RUNNING, 12.0):
		_fail("Round never entered RUNNING")
		main_game.queue_free()
		_finish()
		return

	var minigun: BaseMinigun = main_game.get_node_or_null("World/BaseMinigun") as BaseMinigun
	if minigun != null:
		minigun.set_round_active(false)

	await create_timer(0.35).timeout

	var outside_chute: int = 0
	var max_lateral: float = 0.0
	for zombie in zombie_manager.get_living_zombies():
		if zombie == null:
			continue
		var lateral: float = abs(zombie.global_position.x)
		max_lateral = maxf(max_lateral, lateral)
		if lateral > chute_half_width + 0.35:
			outside_chute += 1

	print(
		"zombies=%d outside_chute=%d max_lateral=%.2f chute_half=%.2f"
		% [zombie_manager.get_total_count(), outside_chute, max_lateral, chute_half_width]
	)

	if outside_chute > int(ceil(float(ZOMBIE_COUNT) * 0.08)):
		_fail(
			"%d/%d zombies escaped spawn chute (max lateral %.2f > %.2f)"
			% [outside_chute, ZOMBIE_COUNT, max_lateral, chute_half_width + 0.35]
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
