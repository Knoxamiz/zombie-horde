extends SceneTree

## Headless check: can zombies naturally reach goal on playable Broken Bridge?
## Minigun is disabled after launch so this validates route/hazards, not streamer DPS.
## Usage:
##   godot --headless --path . -s res://scripts/debug/broken_bridge_pass_completion_test.gd

const MAIN_GAME_SCENE := "res://scenes/main/main_game.tscn"
const MAP_ID := "broken_bridge_pass"
const GAP_AUDIT := preload("res://scripts/maps/kit_map_gap_audit.gd")
const ZOMBIE_COUNT := 8
const PASS := 0
const FAIL := 1

var _failures: PackedStringArray = PackedStringArray()
var _death_log: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _on_zombie_died_direct(zombie: Zombie, cause: String) -> void:
	_death_log.append(
		"%s cause=%s pos=%s on_floor=%s"
		% [zombie.display_name, cause, zombie.global_position, zombie.is_on_floor()]
	)


func _run() -> void:
	print("=== Broken Bridge Pass completion test ===")
	var ctx: Dictionary = await _boot()
	if ctx.is_empty():
		_finish()
		return

	var round_manager: RoundManager = ctx.round_manager
	var zombie_manager: ZombieManager = ctx.zombie_manager
	var definition: RaceMapDefinition = ctx.definition
	var main_game: Node = ctx.main_game
	var map_controller: RaceMapController = ctx.map_controller

	var road: Node = main_game.get_node_or_null("World/RoadArena/CoreRoad")
	if road != null:
		var surfaces: Node = road.get_node_or_null("KitSurfaces")
		if surfaces == null:
			_fail("KitSurfaces missing on Broken Bridge")
		else:
			var walk_layers: int = 0
			for child in surfaces.get_children():
				if child is StaticBody3D and child.collision_layer != 0:
					walk_layers += 1
			print("KitSurfaces pieces=%d with_walk_collision=%d" % [surfaces.get_child_count(), walk_layers])
			if walk_layers == 0:
				_fail("No KitSurfaces pieces retain walk collision")

	var zombie_config: ZombieConfig = map_controller.zombie_config
	if zombie_config != null:
		print(
			"oob bounds x=±%.1f z=[%.1f,%.1f] y_min=%.1f"
			% [
				zombie_config.out_of_bounds_half_width,
				zombie_config.out_of_bounds_min_z,
				zombie_config.out_of_bounds_max_z,
				zombie_config.out_of_bounds_min_y,
			]
		)

	round_manager.start_round()
	if not await _wait_for_state(round_manager, RoundManager.RoundState.RUNNING, 12.0):
		_fail("Round never entered RUNNING")
		main_game.queue_free()
		_finish()
		return

	var minigun: BaseMinigun = main_game.get_node_or_null("World/BaseMinigun") as BaseMinigun
	if minigun != null:
		minigun.set_round_active(false)

	for zombie in zombie_manager.get_children():
		if zombie is Zombie and not (zombie as Zombie).died.is_connected(_on_zombie_died_direct):
			(zombie as Zombie).died.connect(_on_zombie_died_direct)

	await create_timer(0.15).timeout
	for zombie in zombie_manager.get_children():
		if zombie is Zombie:
			var z: Zombie = zombie as Zombie
			print(
				"spawned@%s pos=%s on_floor=%s progress=%.3f"
				% [z.display_name, z.global_position, z.is_on_floor(), z.get_progress()]
			)

	await create_timer(0.2).timeout
	var spawned: int = zombie_manager.get_total_count()
	if spawned < ZOMBIE_COUNT:
		_fail("Expected %d zombies, spawned %d" % [ZOMBIE_COUNT, spawned])

	var reached_goal: int = 0
	var killed_other: int = 0
	var max_progress: float = 0.0
	var spawn_z: float = definition.spawn_origin.z
	var goal_z: float = definition.goal_position.z
	var span: float = maxf(goal_z - spawn_z, 1.0)

	var elapsed: float = 0.0
	var timeout: float = 180.0
	while elapsed < timeout:
		await create_timer(0.25).timeout
		elapsed += 0.25

		for zombie in zombie_manager.get_living_zombies():
			if zombie == null or not is_instance_valid(zombie):
				continue
			var progress: float = clampf((zombie.global_position.z - spawn_z) / span, 0.0, 1.0)
			max_progress = maxf(max_progress, progress)

		if round_manager.state == RoundManager.RoundState.ENDED:
			break
		if zombie_manager.get_racing_count() == 0 and elapsed > 20.0:
			break

	for zombie in zombie_manager.get_children():
		if zombie is Zombie:
			var z: Zombie = zombie as Zombie
			if z.has_finished_race():
				reached_goal += 1
			elif not z.is_alive():
				killed_other += 1

	var ranked: Array = zombie_manager.get_ranked_results(spawned)
	print("spawned=%d reached_goal=%d killed_other=%d max_progress=%.2f"
		% [spawned, reached_goal, killed_other, max_progress])
	print("kill_causes=%s" % str(round_manager._stats.kill_causes))
	for entry in _death_log:
		print("  death: %s" % entry)

	for entry in ranked:
		print(
			"  %s progress=%.2f alive=%s place=%s"
			% [
				entry.get("display_name", "?"),
				float(entry.get("progress", 0.0)),
				str(entry.get("alive", false)),
				str(entry.get("finish_place", 0)),
			]
		)

	if reached_goal < 1:
		_fail("No zombies reached goal (max_progress=%.2f)" % max_progress)
	if max_progress < 0.85 and reached_goal < 1:
		_fail("Max progress %.2f too low — route may be blocked" % max_progress)

	if not _failures.is_empty():
		var gap_report: Dictionary = GAP_AUDIT.audit_preset("broken_bridge")
		print(GAP_AUDIT.format_report(gap_report))

	main_game.queue_free()
	_finish()


func _boot() -> Dictionary:
	var packed: PackedScene = load(MAIN_GAME_SCENE)
	if packed == null:
		_fail("Could not load main game scene")
		return {}

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
		return {}

	map_controller.set_active_map_by_id(MAP_ID)
	if map_controller.active_map_id != MAP_ID:
		_fail("Failed to activate %s (got %s)" % [MAP_ID, map_controller.active_map_id])
		main_game.queue_free()
		return {}

	var definition: RaceMapDefinition = map_controller.get_active_map_definition()
	if definition == null:
		_fail("Missing map definition")
		main_game.queue_free()
		return {}

	if round_manager.round_config != null:
		round_manager.round_config.countdown_seconds = 0
		round_manager.round_config.max_race_duration_seconds = 240.0
	if map_controller.human_defender_config != null:
		map_controller.human_defender_config.defender_count = 0

	var flow: GameFlowController = main_game.get_node_or_null(
		"Systems/GameFlowController"
	) as GameFlowController
	if flow != null:
		flow.show_race()
	await create_timer(0.2).timeout

	for _i in range(ZOMBIE_COUNT):
		debug_join.request_random_join()
	await create_timer(0.15).timeout

	return {
		"main_game": main_game,
		"map_controller": map_controller,
		"round_manager": round_manager,
		"zombie_manager": zombie_manager,
		"definition": definition,
	}


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
