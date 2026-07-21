extends SceneTree

## End-to-end movement contract. A route can be valid on paper while a runner
## remains stationary because of startup, avoidance, or collision integration.
## This test boots the live City Highway scene and proves a runner advances.

const MAIN_GAME_SCENE := "res://scenes/main/main_game.tscn"
const MAP_IDS := PackedStringArray([
	"quarantine_boulevard",
	"broken_bridge_pass",
	"spiral_descent",
	"true_spiral_ramp",
])
const RUNNER_COUNT := 24

var _failures: PackedStringArray = PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed: PackedScene = load(MAIN_GAME_SCENE) as PackedScene
	if packed == null:
		_fail("Could not load the main game scene")
		_finish()
		return
	var game: Node = packed.instantiate()
	root.add_child(game)
	await create_timer(0.6).timeout

	var map_controller: RaceMapController = game.get_node_or_null("Systems/RaceMapController") as RaceMapController
	var round_manager: RoundManager = game.get_node_or_null("Systems/RoundManager") as RoundManager
	var zombie_manager: ZombieManager = game.get_node_or_null("Systems/ZombieManager") as ZombieManager
	var debug_join: DebugJoinSource = game.get_node_or_null("Systems/DebugJoinSource") as DebugJoinSource
	if map_controller == null or round_manager == null or zombie_manager == null or debug_join == null:
		_fail("Live movement test could not locate race systems")
		_cleanup(game)
		return

	round_manager.configure_immediate_launch_for_tests()
	for map_id in MAP_IDS:
		if not await _verify_map_motion(map_controller, round_manager, zombie_manager, debug_join, map_id):
			break
	_cleanup(game)


func _wait_for_running(round_manager: RoundManager) -> bool:
	var elapsed := 0.0
	while elapsed < 8.0:
		if round_manager.state == RoundManager.RoundState.RUNNING:
			return true
		await create_timer(0.05).timeout
		elapsed += 0.05
	return false


func _verify_map_motion(
	map_controller: RaceMapController,
	round_manager: RoundManager,
	zombie_manager: ZombieManager,
	debug_join: DebugJoinSource,
	map_id: String
) -> bool:
	if not map_controller.set_active_map_by_id(map_id):
		_fail("Live movement test could not load %s" % map_id)
		return false
	if map_controller.hazard_config != null:
		map_controller.hazard_config.mine_count = 0
		map_controller.hazard_config.sewer_hole_count = 0
		map_controller.hazard_config.obstacle_count = 0
	if map_controller.human_defender_config != null:
		map_controller.human_defender_config.defender_count = 0
	for _index in range(RUNNER_COUNT):
		debug_join.request_random_join()
	await create_timer(0.15).timeout
	round_manager.start_round()
	if not await _wait_for_running(round_manager):
		_fail("%s never entered RUNNING" % map_id)
		return false

	var zombies: Array[Zombie] = zombie_manager.get_living_zombies()
	if zombies.size() < RUNNER_COUNT:
		_fail("%s expected %d live runners, got %d" % [map_id, RUNNER_COUNT, zombies.size()])
		return false
	# Start the entire test crowd in one valid location. This reproduces the
	# worst-case pile created by a shared explosion or vehicle launch and proves
	# that course steering plus local avoidance can fan the horde back out.
	var active_definition: RaceMapDefinition = map_controller.get_active_map_definition()
	if active_definition == null:
		_fail("%s movement test could not resolve its active map definition" % map_id)
		return false
	var shared_start: Vector3 = active_definition.spawn_origin
	for runner in zombies:
		runner.global_position = shared_start
		runner.velocity = Vector3.ZERO
	await create_timer(0.05).timeout

	var start_positions: Dictionary = {}
	var goals: Dictionary = {}
	for runner in zombies:
		start_positions[runner] = runner.global_position
		goals[runner] = runner.goal_position
	# A shipped map must move a real crowd, not merely prove a single runner can
	# receive a direction. Hazards and defenders are disabled above so this is a
	# route/crowd integration contract.
	await create_timer(2.5).timeout
	var advancing_count := 0
	for runner in zombies:
		if not is_instance_valid(runner):
			continue
		var start_position: Vector3 = start_positions.get(runner, runner.global_position) as Vector3
		var goal_position: Vector3 = goals.get(runner, runner.goal_position) as Vector3
		var displaced: bool = runner.global_position.distance_to(start_position) >= 0.75
		var route_advanced: bool = runner.get_progress() >= 0.002
		var goal_advanced: bool = runner.global_position.distance_to(goal_position) <= start_position.distance_to(goal_position) - 0.55
		if route_advanced and (displaced or goal_advanced):
			advancing_count += 1
	if advancing_count < 18:
		_fail(
			"%s crowd navigation stalled: only %d/%d runners advanced along the authored course"
			% [map_id, advancing_count, RUNNER_COUNT]
		)
		return false
	round_manager.reset_round(false)
	await create_timer(0.1).timeout
	return true


func _cleanup(game: Node) -> void:
	if game != null and is_instance_valid(game):
		game.queue_free()
	await create_timer(0.05).timeout
	_finish()


func _fail(message: String) -> void:
	push_error(message)
	_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: Zombie navigation moves a live runner toward the goal")
		quit(0)
		return
	for failure in _failures:
		print("FAIL: %s" % failure)
	quit(1)
