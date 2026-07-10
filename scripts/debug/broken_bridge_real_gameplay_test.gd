extends SceneTree

const MAIN_GAME_SCENE := "res://scenes/main/main_game.tscn"
const MAP_ID := "broken_bridge_candidate"
const _BRIDGE_LAYOUT := preload("res://scripts/maps/blueprints/broken_bridge_test_layout.gd")
const PASS := 0
const FAIL := 1

const DEFAULT_COUNTS: Array[int] = [5, 20, 100]
const STUCK_SECONDS := 8.0
const OFF_BRIDGE_MARGIN := 0.75

const META_COLLISION_LAYER := "_zh_saved_collision_layer"
const META_COLLISION_MASK := "_zh_saved_collision_mask"
const META_COLLISION_SHAPE_DISABLED := "_zh_saved_collision_shape_disabled"
const META_AREA_MONITORING := "_zh_saved_area_monitoring"
const META_AREA_MONITORABLE := "_zh_saved_area_monitorable"
const META_PROCESS_MODE := "_zh_saved_process_mode"

var _failures: Array[String] = []
var _runtime_errors: Array[String] = []
var _saved_map_index: int = 0
var _overall_passed: bool = true


func _initialize() -> void:
	call_deferred("_run_all")


func _run_all() -> void:
	print("=== Broken Bridge real gameplay test suite ===")

	if not MapCatalog.is_entry_playable(MapCatalog.get_entry_by_id(MAP_ID)):
		_fail("Prototype map '%s' must remain non-playable" % MAP_ID)

	var profile_before: StreamerSettingsProfile = StreamerSettingsProfile.load_from_disk()
	_saved_map_index = profile_before.selected_map_index if profile_before != null else 0

	var counts: Array[int] = _parse_zombie_counts()
	for zombie_count in counts:
		await _run_single_scenario(zombie_count)

	await _run_oob_probe()
	await _run_void_hazard_probe()

	var main_game: Node = await _boot_main_game()
	if main_game != null:
		await _verify_hud_and_camera(main_game)
		await _restore_city_highway(main_game)

	_verify_saved_settings_unchanged()
	_verify_catalog_unchanged()

	if _overall_passed and _failures.is_empty():
		print("SUITE RESULT: PASSED")
		_finish(PASS)
	else:
		print("SUITE RESULT: FAILED")
		_finish(FAIL)


func _run_single_scenario(zombie_count: int) -> void:
	var metrics := {
		"requested": zombie_count,
		"spawned": 0,
		"reached_goal": 0,
		"killed_oob": 0,
		"killed_fell": 0,
		"killed_lateral_oob": 0,
		"killed_sewer": 0,
		"killed_other": 0,
		"stuck": 0,
		"off_bridge": 0,
		"max_progress": 0.0,
		"passed": true,
	}

	var main_game: Node = await _boot_main_game()
	if main_game == null:
		metrics.passed = false
		_print_scenario_report(metrics, "main game boot failed")
		return

	var map_controller: RaceMapController = _node(main_game, "Systems/RaceMapController") as RaceMapController
	var round_manager: RoundManager = _node(main_game, "Systems/RoundManager") as RoundManager
	var zombie_manager: ZombieManager = _node(main_game, "Systems/ZombieManager") as ZombieManager
	var debug_join: DebugJoinSource = _node(main_game, "Systems/DebugJoinSource") as DebugJoinSource
	var definition: RaceMapDefinition = MapCatalog.load_definition_by_id(MAP_ID)

	if map_controller == null or round_manager == null or zombie_manager == null or debug_join == null:
		metrics.passed = false
		_print_scenario_report(metrics, "missing core systems")
		main_game.queue_free()
		return

	if not map_controller.load_prototype_map_for_test(MAP_ID):
		metrics.passed = false
		_print_scenario_report(metrics, "prototype map load failed")
		main_game.queue_free()
		return

	_configure_test_round(round_manager, map_controller, main_game)
	await _ensure_race_systems_active(main_game)

	for _index in range(zombie_count):
		debug_join.request_random_join()
	await create_timer(0.2).timeout

	if round_manager.get_pending_count() < zombie_count:
		metrics.passed = false
		_print_scenario_report(
			metrics,
			"only %d participants queued before start (expected %d)"
			% [round_manager.get_pending_count(), zombie_count]
		)
		main_game.queue_free()
		return

	var monitor := _ZombieRunMonitor.new()
	round_manager.start_round()
	if not await _wait_for_round_state(round_manager, RoundManager.RoundState.RUNNING, 12.0):
		metrics.passed = false
		_print_scenario_report(metrics, "round never entered RUNNING")
		main_game.queue_free()
		return

	await create_timer(0.25).timeout
	monitor.begin(zombie_manager, definition, STUCK_SECONDS, OFF_BRIDGE_MARGIN)

	await _ensure_race_systems_active(main_game)
	_disable_combat_for_map_test(main_game)

	metrics.spawned = zombie_manager.get_total_count()
	if metrics.spawned != zombie_count:
		_fail_scenario(
			metrics,
			"expected %d spawned zombies, got %d" % [zombie_count, metrics.spawned]
		)

	var timeout: float = _timeout_for_count(zombie_count)
	var elapsed: float = 0.0
	var min_race_seconds: float = 12.0
	while elapsed < timeout:
		await create_timer(0.25).timeout
		elapsed += 0.25
		monitor.tick(0.25, round_manager.state == RoundManager.RoundState.RUNNING)
		if round_manager.state == RoundManager.RoundState.ENDED:
			break
		if elapsed >= min_race_seconds and _all_zombies_resolved(zombie_manager):
			break

	monitor.finish(zombie_manager)
	metrics.reached_goal = monitor.reached_goal
	metrics.killed_oob = monitor.killed_oob
	metrics.killed_fell = monitor.killed_fell
	metrics.killed_lateral_oob = monitor.killed_lateral_oob
	metrics.killed_sewer = monitor.killed_sewer
	metrics.killed_other = monitor.killed_other
	metrics.stuck = monitor.stuck
	metrics.off_bridge = monitor.off_bridge_violations
	metrics.max_progress = monitor.max_progress

	_evaluate_scenario(metrics, zombie_count)
	_print_scenario_report(metrics, "", monitor.get_stuck_diagnostics())
	main_game.queue_free()


func _run_oob_probe() -> void:
	var main_game: Node = await _boot_main_game()
	if main_game == null:
		_fail("OOB probe: could not boot main game")
		return

	var map_controller: RaceMapController = _node(main_game, "Systems/RaceMapController") as RaceMapController
	var round_manager: RoundManager = _node(main_game, "Systems/RoundManager") as RoundManager
	var zombie_manager: ZombieManager = _node(main_game, "Systems/ZombieManager") as ZombieManager
	var debug_join: DebugJoinSource = _node(main_game, "Systems/DebugJoinSource") as DebugJoinSource
	if map_controller == null or round_manager == null or zombie_manager == null or debug_join == null:
		_fail("OOB probe: missing systems")
		main_game.queue_free()
		return

	if not map_controller.load_prototype_map_for_test(MAP_ID):
		_fail("OOB probe: prototype load failed")
		main_game.queue_free()
		return

	_configure_test_round(round_manager, map_controller, main_game)
	await _ensure_race_systems_active(main_game)
	debug_join.request_random_join()
	await create_timer(0.25).timeout
	if round_manager.get_pending_count() < 1:
		_fail("OOB probe: participant was not queued")
		main_game.queue_free()
		return

	round_manager.start_round()
	if not await _wait_for_round_state(round_manager, RoundManager.RoundState.RUNNING, 12.0):
		_fail("OOB probe: round did not enter RUNNING")
		main_game.queue_free()
		return
	await create_timer(0.25).timeout

	var probe: Zombie = _get_first_tracked_zombie(zombie_manager)
	if probe == null:
		_fail("OOB probe: no zombie spawned")
		main_game.queue_free()
		return

	if not await _wait_for_round_state(round_manager, RoundManager.RoundState.RUNNING, 12.0):
		_fail("OOB probe: round did not start")
		main_game.queue_free()
		return

	await _ensure_race_systems_active(main_game)
	_disable_combat_for_map_test(main_game)

	var death_cause: String = ""
	probe.died.connect(func(_zombie: Zombie, cause: String) -> void:
		death_cause = cause
	)
	await create_timer(0.1).timeout
	probe.global_position = Vector3(20.0, _BRIDGE_LAYOUT.ZOMBIE_SPAWN_Y, 0.0)
	for _step in range(20):
		await create_timer(0.1).timeout
		if not probe.is_alive():
			break

	if probe.is_alive():
		_fail(
			"OOB probe: zombie survived outside config bounds at %s"
			% probe.global_position
		)
	else:
		print("OOB probe: config bounds kill verified")

	main_game.queue_free()


func _run_void_hazard_probe() -> void:
	var main_game: Node = await _boot_main_game()
	if main_game == null:
		_fail("Void hazard probe: could not boot main game")
		return

	var map_controller: RaceMapController = _node(main_game, "Systems/RaceMapController") as RaceMapController
	var round_manager: RoundManager = _node(main_game, "Systems/RoundManager") as RoundManager
	var zombie_manager: ZombieManager = _node(main_game, "Systems/ZombieManager") as ZombieManager
	var debug_join: DebugJoinSource = _node(main_game, "Systems/DebugJoinSource") as DebugJoinSource
	if map_controller == null or round_manager == null or zombie_manager == null or debug_join == null:
		_fail("Void hazard probe: missing systems")
		main_game.queue_free()
		return

	if not map_controller.load_prototype_map_for_test(MAP_ID):
		_fail("Void hazard probe: prototype load failed")
		main_game.queue_free()
		return

	_configure_test_round(round_manager, map_controller, main_game)
	await _ensure_race_systems_active(main_game)
	debug_join.request_random_join()
	await create_timer(0.25).timeout
	if round_manager.get_pending_count() < 1:
		_fail("Void hazard probe: participant was not queued")
		main_game.queue_free()
		return

	round_manager.start_round()
	if not await _wait_for_round_state(round_manager, RoundManager.RoundState.RUNNING, 12.0):
		_fail("Void hazard probe: round did not enter RUNNING")
		main_game.queue_free()
		return
	await create_timer(0.25).timeout

	var probe: Zombie = _get_first_tracked_zombie(zombie_manager)
	if probe == null:
		_fail("Void hazard probe: no zombie spawned")
		main_game.queue_free()
		return

	if not await _wait_for_round_state(round_manager, RoundManager.RoundState.RUNNING, 12.0):
		_fail("Void hazard probe: round did not start")
		main_game.queue_free()
		return

	await _ensure_race_systems_active(main_game)
	_disable_combat_for_map_test(main_game)

	var death_cause: String = ""
	probe.died.connect(func(_zombie: Zombie, cause: String) -> void:
		death_cause = cause
	)
	await create_timer(0.1).timeout
	probe.global_position = Vector3(9.0, 0.0, 0.0)
	for _step in range(20):
		await create_timer(0.1).timeout
		if not probe.is_alive():
			break

	if probe.is_alive():
		_fail(
			"Void hazard probe: zombie survived side void entry at %s"
			% probe.global_position
		)
	else:
		print("Void hazard probe: bridge void kill zone verified")

	main_game.queue_free()


func _verify_hud_and_camera(main_game: Node) -> void:
	var map_controller: RaceMapController = _node(main_game, "Systems/RaceMapController") as RaceMapController
	var hud: Node = _node(main_game, "HUD")
	var definition: RaceMapDefinition = MapCatalog.load_definition_by_id(MAP_ID)

	if hud == null:
		_fail("HUD missing during verification")
		return
	if hud.get_script() == null:
		_fail("HUD script failed to compile")

	if map_controller != null and not map_controller.load_prototype_map_for_test(MAP_ID):
		_fail("HUD verification could not load prototype map")

	hud.visible = true
	if hud.has_method("refresh_display"):
		hud.refresh_display()

	var status_board: Node = main_game.get_node_or_null(
		"SpectatorCamera/Camera3D/WorldMenus3D/RaceBoards/RaceStatusBoard"
	)
	if status_board == null:
		_fail("RaceStatusBoard missing during HUD verification")

	var spectator: SpectatorCameraController = _node(main_game, "SpectatorCamera") as SpectatorCameraController
	if spectator != null and definition != null and map_controller != null:
		var view: Dictionary = RaceMapController.compute_race_camera_view_for_definition(definition)
		map_controller.frame_spectator_camera_for_definition(spectator, definition, false)
		var expected_position: Vector3 = _clamp_spectator_position(
			spectator,
			view.get("position", Vector3.ZERO)
		)
		if spectator.global_position.distance_to(expected_position) > 0.05:
			_fail("Camera framing mismatch during HUD verification")


func _restore_city_highway(main_game: Node) -> void:
	var map_controller: RaceMapController = _node(main_game, "Systems/RaceMapController") as RaceMapController
	if map_controller == null:
		_fail("Could not restore City Highway: RaceMapController missing")
		return
	map_controller.clear_prototype_test_load(true)
	if map_controller.is_prototype_test_load_active():
		_fail("Prototype test flag still active after restore")


func _configure_test_round(
	round_manager: RoundManager,
	map_controller: RaceMapController,
	main_game: Node
) -> void:
	round_manager.configure_immediate_launch_for_tests()
	if map_controller.human_defender_config != null:
		map_controller.human_defender_config.defender_count = 0
	if map_controller.hazard_config != null:
		map_controller.hazard_config.mine_count = 0
		map_controller.hazard_config.sewer_hole_count = 0
		map_controller.hazard_config.obstacle_count = 0

	var zombie_manager: ZombieManager = _node(main_game, "Systems/ZombieManager") as ZombieManager
	if zombie_manager != null:
		zombie_manager.set_spawn_rng_seed(8802)


func _ensure_race_systems_active(main_game: Node) -> void:
	var flow: GameFlowController = _node(main_game, "Systems/GameFlowController") as GameFlowController
	if flow != null:
		flow.show_race()

	await create_timer(0.35).timeout

	var world: Node3D = _node(main_game, "World") as Node3D
	if world != null:
		_set_world_active_for_test(world, true)

	for manager_path in [
		"Systems/ZombieManager",
		"Systems/HazardManager",
		"Systems/PowerupManager",
		"Systems/HumanDefenderManager",
	]:
		var manager: Node = _node(main_game, manager_path)
		if manager != null:
			_set_world_active_for_test(manager, true)


func _set_world_active_for_test(node: Node, active: bool) -> void:
	if node == null:
		return

	var node_3d: Node3D = node as Node3D
	if node_3d != null:
		node_3d.visible = active

	_set_process_enabled_for_test(node, active)
	_set_collision_tree_enabled_for_test(node, active)


func _set_process_enabled_for_test(node: Node, enabled: bool) -> void:
	if enabled:
		if node.has_meta(META_PROCESS_MODE):
			node.process_mode = int(node.get_meta(META_PROCESS_MODE))
		return

	if not node.has_meta(META_PROCESS_MODE):
		node.set_meta(META_PROCESS_MODE, node.process_mode)
	node.process_mode = Node.PROCESS_MODE_DISABLED


func _set_collision_tree_enabled_for_test(node: Node, enabled: bool) -> void:
	_set_collision_node_enabled_for_test(node, enabled)
	for child in node.get_children():
		_set_collision_tree_enabled_for_test(child, enabled)


func _set_collision_node_enabled_for_test(node: Node, enabled: bool) -> void:
	var collision_object: CollisionObject3D = node as CollisionObject3D
	if collision_object != null:
		if enabled:
			if node.has_meta(META_COLLISION_LAYER):
				collision_object.collision_layer = int(node.get_meta(META_COLLISION_LAYER))
			if node.has_meta(META_COLLISION_MASK):
				collision_object.collision_mask = int(node.get_meta(META_COLLISION_MASK))
		else:
			if not node.has_meta(META_COLLISION_LAYER):
				node.set_meta(META_COLLISION_LAYER, collision_object.collision_layer)
			if not node.has_meta(META_COLLISION_MASK):
				node.set_meta(META_COLLISION_MASK, collision_object.collision_mask)
			collision_object.collision_layer = 0
			collision_object.collision_mask = 0

	var area: Area3D = node as Area3D
	if area != null:
		if enabled:
			if node.has_meta(META_AREA_MONITORING):
				area.monitoring = bool(node.get_meta(META_AREA_MONITORING))
			if node.has_meta(META_AREA_MONITORABLE):
				area.monitorable = bool(node.get_meta(META_AREA_MONITORABLE))
		else:
			if not node.has_meta(META_AREA_MONITORING):
				node.set_meta(META_AREA_MONITORING, area.monitoring)
			if not node.has_meta(META_AREA_MONITORABLE):
				node.set_meta(META_AREA_MONITORABLE, area.monitorable)
			area.monitoring = false
			area.monitorable = false

	var collision_shape: CollisionShape3D = node as CollisionShape3D
	if collision_shape != null:
		if enabled:
			if node.has_meta(META_COLLISION_SHAPE_DISABLED):
				collision_shape.disabled = bool(node.get_meta(META_COLLISION_SHAPE_DISABLED))
		else:
			if not node.has_meta(META_COLLISION_SHAPE_DISABLED):
				node.set_meta(META_COLLISION_SHAPE_DISABLED, collision_shape.disabled)
			collision_shape.disabled = true


func _get_first_tracked_zombie(zombie_manager: ZombieManager) -> Zombie:
	var living: Array[Zombie] = zombie_manager.get_living_zombies()
	if not living.is_empty():
		return living[0]

	var ranked: Array[Dictionary] = zombie_manager.get_ranked_results(1)
	if ranked.is_empty():
		return null

	var display_name: String = str(ranked[0].get("display_name", ""))
	if display_name.is_empty():
		return null

	for child in zombie_manager.get_children():
		var zombie: Zombie = child as Zombie
		if zombie != null and zombie.display_name == display_name:
			return zombie
	return null


func _all_zombies_resolved(zombie_manager: ZombieManager) -> bool:
	if zombie_manager.get_total_count() <= 0:
		return false
	return zombie_manager.get_racing_count() == 0


func _disable_combat_for_map_test(main_game: Node) -> void:
	var minigun: BaseMinigun = _node(main_game, "World/BaseMinigun") as BaseMinigun
	if minigun != null:
		minigun.set_round_active(false)


func _evaluate_scenario(metrics: Dictionary, zombie_count: int) -> void:
	if metrics.spawned <= 0:
		_fail_scenario(metrics, "no zombies spawned")
		return

	if metrics.spawned != zombie_count:
		_fail_scenario(
			metrics,
			"expected %d spawned zombies, got %d" % [zombie_count, metrics.spawned]
		)

	if _is_stress_report_only(zombie_count):
		_print_stress_report_only(metrics)
		return

	var resolved_count: int = (
		metrics.reached_goal + metrics.killed_oob + metrics.killed_other
	)
	var resolve_ratio: float = float(resolved_count) / float(metrics.spawned)
	var min_goal: int = _minimum_goal_count(zombie_count)
	var passed_goal: bool = metrics.reached_goal >= min_goal
	var passed_resolve: bool = resolve_ratio >= 0.80

	if not passed_goal and not passed_resolve:
		_fail_scenario(
			metrics,
			"need at least %d goal or 80%% clean resolve; got goal=%d resolve=%.0f%%"
			% [min_goal, metrics.reached_goal, resolve_ratio * 100.0]
		)

	if metrics.max_progress < 0.35:
		_fail_scenario(
			metrics,
			"max progress %.2f below required 0.35" % metrics.max_progress
		)

	var max_stuck: int = _maximum_stuck_count(metrics.spawned)
	if metrics.stuck > max_stuck:
		_fail_scenario(
			metrics,
			"%d zombies were stuck on the bridge (max allowed %d)" % [metrics.stuck, max_stuck]
		)

	if metrics.off_bridge > 0:
		_fail_scenario(
			metrics,
			"%d zombies ran on invisible floor outside the visible deck" % metrics.off_bridge
		)


func _is_stress_report_only(zombie_count: int) -> bool:
	return zombie_count > 20


func _minimum_goal_count(zombie_count: int) -> int:
	if zombie_count <= 5:
		return 1
	if zombie_count <= 20:
		return 3
	return 0


func _maximum_stuck_count(spawned: int) -> int:
	return int(floor(float(spawned) * 0.20))


func _print_stress_report_only(metrics: Dictionary) -> void:
	print(
		"[%d zombies] stress scenario is report-only (spawned=%d goal=%d oob=%d stuck=%d max_progress=%.2f)"
		% [
			metrics.requested,
			metrics.spawned,
			metrics.reached_goal,
			metrics.killed_oob,
			metrics.stuck,
			metrics.max_progress,
		]
	)
	if metrics.reached_goal <= 0 and metrics.max_progress < 0.25:
		_fail_scenario(
			metrics,
			"catastrophic stress failure: no goal reachers and max progress %.2f"
			% metrics.max_progress
		)


func _timeout_for_count(zombie_count: int) -> float:
	if zombie_count <= 5:
		return 140.0
	if zombie_count <= 20:
		return 200.0
	return 220.0


func _print_scenario_report(
	metrics: Dictionary,
	extra_reason: String = "",
	stuck_diagnostics: Array = []
) -> void:
	if not extra_reason.is_empty() and metrics.passed:
		metrics.passed = false
		_fail("[%d zombies] %s" % [metrics.requested, extra_reason])

	var result_text: String = "PASSED" if metrics.passed else "FAILED"
	if not metrics.passed:
		_overall_passed = false

	print("")
	print("BROKEN BRIDGE REAL GAMEPLAY TEST")
	print("- map loaded: %s" % MAP_ID)
	print("- zombies spawned: %d" % metrics.spawned)
	print("- zombies reached goal: %d" % metrics.reached_goal)
	print("- zombies killed/OOB: %d" % metrics.killed_oob)
	print("- zombies killed/fell: %d" % metrics.killed_fell)
	print("- zombies killed/lateral_oob: %d" % metrics.killed_lateral_oob)
	print("- zombies killed/sewer: %d" % metrics.killed_sewer)
	print("- zombies killed/other: %d" % metrics.killed_other)
	print("- zombies stuck: %d" % metrics.stuck)
	print("- off-bridge violations: %d" % metrics.off_bridge)
	print("- max progress: %.2f" % metrics.max_progress)
	print("- runtime errors: %s" % (_format_runtime_errors()))
	print("- result: %s" % result_text)
	if not stuck_diagnostics.is_empty():
		print("- stuck diagnostics:")
		for entry in stuck_diagnostics:
			print("  - %s" % str(entry))


func _boot_main_game() -> Node:
	var packed: PackedScene = load(MAIN_GAME_SCENE)
	if packed == null:
		_fail("Could not load main game scene")
		return null

	var main_game: Node = packed.instantiate()
	root.add_child(main_game)
	await create_timer(0.8).timeout
	return main_game


func _wait_for_round_state(round_manager: RoundManager, target_state: int, timeout: float) -> bool:
	var elapsed: float = 0.0
	while elapsed < timeout:
		if round_manager.state == target_state:
			return true
		await create_timer(0.1).timeout
		elapsed += 0.1
	return round_manager.state == target_state


func _verify_saved_settings_unchanged() -> void:
	var profile_after: StreamerSettingsProfile = StreamerSettingsProfile.load_from_disk()
	if profile_after != null and profile_after.selected_map_index != _saved_map_index:
		_fail(
			"Saved map index changed (%d -> %d)"
			% [_saved_map_index, profile_after.selected_map_index]
		)


func _verify_catalog_unchanged() -> void:
	if MapCatalog.get_playable_count() != 8:
		_fail("Playable map count changed after gameplay tests (expected 8)")
	var entry: Dictionary = MapCatalog.get_entry_by_id(MAP_ID)
	if bool(entry.get("enabled", true)):
		_fail("broken_bridge_candidate became enabled")
	if str(entry.get("status", "")) != MapCatalog.STATUS_PROTOTYPE:
		_fail("broken_bridge_candidate status changed")


func _parse_zombie_counts() -> Array[int]:
	var counts: Array[int] = []
	var user_args: PackedStringArray = OS.get_cmdline_user_args()
	for arg in user_args:
		if arg == "--skip-stress":
			continue
		if arg.begins_with("--zombies="):
			counts.clear()
			for token in arg.substr("--zombies=".length()).split(","):
				var value: int = int(token.strip_edges())
				if value > 0:
					counts.append(value)

	if counts.is_empty():
		counts = DEFAULT_COUNTS.duplicate()
		if "--skip-stress" in user_args:
			counts.erase(100)
	return counts


func _clamp_spectator_position(
	spectator: SpectatorCameraController,
	target_position: Vector3
) -> Vector3:
	if spectator == null or not spectator.position_limits_enabled:
		return target_position

	var min_x: float = min(spectator.camera_bounds_min.x, spectator.camera_bounds_max.x)
	var max_x: float = max(spectator.camera_bounds_min.x, spectator.camera_bounds_max.x)
	var min_y: float = min(spectator.camera_bounds_min.y, spectator.camera_bounds_max.y)
	var max_y: float = max(spectator.camera_bounds_min.y, spectator.camera_bounds_max.y)
	var min_z: float = min(spectator.camera_bounds_min.z, spectator.camera_bounds_max.z)
	var max_z: float = max(spectator.camera_bounds_min.z, spectator.camera_bounds_max.z)
	return Vector3(
		clampf(target_position.x, min_x, max_x),
		clampf(target_position.y, min_y, max_y),
		clampf(target_position.z, min_z, max_z)
	)


func _node(main_game: Node, path: String) -> Node:
	return main_game.get_node_or_null(path)


func _fail_scenario(metrics: Dictionary, message: String) -> void:
	metrics.passed = false
	_fail("[%d zombies] %s" % [metrics.requested, message])


func _fail(message: String) -> void:
	push_error(message)
	_failures.append(message)
	_runtime_errors.append(message)
	_overall_passed = false


func _format_runtime_errors() -> String:
	if _runtime_errors.is_empty():
		return "none"
	return str(_runtime_errors.size())


func _finish(exit_code: int) -> void:
	if not _failures.is_empty():
		for message in _failures:
			print("FAIL: %s" % message)
	quit(exit_code)


class _ZombieRunMonitor:
	const _BRIDGE_TILE_SIZE: float = 8.0
	const _BRIDGE_SPAWN_Z: float = -44.0
	const _BRIDGE_SAFE_HALF_WIDTH: float = 4.5
	const _BRIDGE_VOID_INNER_HALF: float = 4.5
	const _BRIDGE_VOID_OUTER_HALF: float = 14.0
	const _CROWD_CONTACT_RADIUS: float = 0.82
	const _ROW_CELL_TYPES: Array[String] = [
		"SPAWN/BROKEN_EDGE",
		"SAFE_ROAD/RAIL",
		"BROKEN_EDGE/SAFE",
		"GAP_VISUAL/CRACK",
		"SAFE_ROAD/RAIL",
		"CONE/SAFE",
		"GAP_VISUAL/CRACK",
		"DEBRIS/SAFE",
		"SAFE_ROAD/RAIL",
		"GAP_VISUAL/CRACK",
		"BROKEN_EDGE/SAFE",
		"GOAL/RAIL",
	]

	var reached_goal: int = 0
	var killed_oob: int = 0
	var killed_fell: int = 0
	var killed_lateral_oob: int = 0
	var killed_sewer: int = 0
	var killed_other: int = 0
	var stuck: int = 0
	var off_bridge_violations: int = 0
	var max_progress: float = 0.0

	var _deck_half_width: float = 4.5
	var _deck_y: float = _BRIDGE_LAYOUT.BRIDGE_DECK_Y
	var _stuck_seconds: float = 5.0
	var _off_bridge_margin: float = 0.75
	var _progress_by_name: Dictionary = {}
	var _stuck_timers: Dictionary = {}
	var _marked_stuck: Dictionary = {}
	var _off_bridge_marked: Dictionary = {}
	var _stuck_diagnostics: Array[Dictionary] = []

	func begin(
		zombie_manager: ZombieManager,
		definition: RaceMapDefinition,
		stuck_seconds: float,
		off_bridge_margin: float
	) -> void:
		_deck_half_width = 4.5 if definition == null else definition.lane_half_width
		_deck_y = _BRIDGE_LAYOUT.BRIDGE_DECK_Y if definition == null else (
			definition.deck_y if definition.deck_y > 0.0 else _BRIDGE_LAYOUT.BRIDGE_DECK_Y
		)
		_stuck_seconds = stuck_seconds
		_off_bridge_margin = off_bridge_margin
		_progress_by_name.clear()
		_stuck_timers.clear()
		_marked_stuck.clear()
		_off_bridge_marked.clear()
		reached_goal = 0
		killed_oob = 0
		killed_fell = 0
		killed_lateral_oob = 0
		killed_sewer = 0
		killed_other = 0
		stuck = 0
		off_bridge_violations = 0
		max_progress = 0.0
		_stuck_diagnostics.clear()

		for zombie in zombie_manager.get_living_zombies():
			_track_zombie(zombie)

	func tick(delta: float, round_running: bool) -> void:
		if not round_running:
			return

		for name_key in _progress_by_name.keys():
			if str(name_key).ends_with("_cause"):
				continue
			var zombie: Zombie = _progress_by_name[name_key] as Zombie
			if zombie == null or not is_instance_valid(zombie):
				continue
			if not zombie.is_alive():
				continue
			if zombie.has_finished_race():
				continue

			var progress: float = zombie.get_progress()
			max_progress = max(max_progress, progress)

			if not _is_on_bridge_deck(zombie):
				_stuck_timers[name_key] = 0.0
				_stuck_timers[name_key + "_progress"] = progress
				if _marked_stuck.has(name_key):
					_marked_stuck.erase(name_key)
				continue

			var last_progress: float = float(_stuck_timers.get(name_key + "_progress", progress))
			if abs(progress - last_progress) < 0.005:
				_stuck_timers[name_key] = float(_stuck_timers.get(name_key, 0.0)) + delta
			else:
				_stuck_timers[name_key] = 0.0
				_stuck_timers[name_key + "_progress"] = progress
				if _marked_stuck.has(name_key):
					_marked_stuck.erase(name_key)

			if (
				float(_stuck_timers.get(name_key, 0.0)) >= _stuck_seconds
				and not _marked_stuck.has(name_key)
			):
				_marked_stuck[name_key] = true

			if _is_invisible_floor_violation(zombie):
				if not _off_bridge_marked.has(name_key):
					_off_bridge_marked[name_key] = true
					off_bridge_violations += 1

	func _is_on_bridge_deck(zombie: Zombie) -> bool:
		var position: Vector3 = zombie.global_position
		return (
			abs(position.x) <= _deck_half_width + 1.0
			and position.y >= _deck_y - 0.5
			and position.y <= _deck_y + 2.5
		)

	func _is_invisible_floor_violation(zombie: Zombie) -> bool:
		var position: Vector3 = zombie.global_position
		if position.y < _deck_y - 0.5 or position.y > _deck_y + 3.0:
			return false
		return abs(position.x) > _deck_half_width + _off_bridge_margin

	func finish(zombie_manager: ZombieManager) -> void:
		for zombie in zombie_manager.get_living_zombies():
			_track_zombie(zombie)

		stuck = 0
		for name_key in _progress_by_name.keys():
			if str(name_key).ends_with("_cause"):
				continue
			var zombie: Zombie = _progress_by_name[name_key] as Zombie
			if zombie == null or not is_instance_valid(zombie):
				continue
			max_progress = max(max_progress, zombie.get_progress())
			if zombie.has_finished_race():
				reached_goal += 1
			elif not zombie.is_alive():
				var cause: String = str(_progress_by_name.get(name_key + "_cause", "unknown"))
				match cause:
					"fell":
						killed_fell += 1
						killed_oob += 1
					"out_of_bounds":
						killed_lateral_oob += 1
						killed_oob += 1
					"sewer":
						killed_sewer += 1
						killed_oob += 1
					_:
						killed_other += 1
			elif _marked_stuck.has(name_key) and _is_on_bridge_deck(zombie):
				stuck += 1
				_stuck_diagnostics.append(_build_stuck_diagnostic(zombie, zombie_manager))

	func get_stuck_diagnostics() -> Array[Dictionary]:
		return _stuck_diagnostics.duplicate()

	func _build_stuck_diagnostic(zombie: Zombie, zombie_manager: ZombieManager) -> Dictionary:
		var position: Vector3 = zombie.global_position
		var progress: float = zombie.get_progress()
		var lateral_distance: float = abs(position.x)
		var row_index: int = _nearest_bridge_row_index(position.z)
		var row_label: String = _ROW_CELL_TYPES[row_index] if row_index >= 0 and row_index < _ROW_CELL_TYPES.size() else "unknown"
		var crowd_hit: Dictionary = _nearest_crowd_contact(zombie, zombie_manager)
		return {
			"name": zombie.display_name,
			"position": "(%.2f, %.2f, %.2f)" % [position.x, position.y, position.z],
			"progress": "%.3f" % progress,
			"lateral_from_center": "%.2f" % lateral_distance,
			"lane_half_width": "%.2f" % _deck_half_width,
			"nearest_row": "R%d (%s)" % [row_index, row_label],
			"near_void_edge": lateral_distance >= _BRIDGE_VOID_INNER_HALF - 1.0,
			"inside_void_band": lateral_distance >= _BRIDGE_VOID_INNER_HALF and lateral_distance <= _BRIDGE_VOID_OUTER_HALF,
			"below_safe_floor_edge": lateral_distance > _BRIDGE_SAFE_HALF_WIDTH,
			"near_goal_line": position.z >= 36.0,
			"crowd_contact": crowd_hit,
		}

	func _nearest_bridge_row_index(z: float) -> int:
		var first_row_z: float = _BRIDGE_SPAWN_Z + _BRIDGE_TILE_SIZE * 0.5
		return clampi(int(round((z - first_row_z) / _BRIDGE_TILE_SIZE)), 0, _ROW_CELL_TYPES.size() - 1)

	func _nearest_crowd_contact(zombie: Zombie, zombie_manager: ZombieManager) -> Dictionary:
		var closest_name: String = ""
		var closest_distance: float = _CROWD_CONTACT_RADIUS
		for other in zombie_manager.get_living_zombies():
			if other == zombie or not other.is_alive():
				continue
			var distance: float = zombie.global_position.distance_to(other.global_position)
			if distance < closest_distance:
				closest_distance = distance
				closest_name = other.display_name
		if closest_name.is_empty():
			return {"blocked_by_zombie": false}
		return {
			"blocked_by_zombie": true,
			"nearest_zombie": closest_name,
			"distance": "%.2f" % closest_distance,
			"other_finished": _is_zombie_finished(zombie_manager, closest_name),
		}

	func _is_zombie_finished(zombie_manager: ZombieManager, display_name: String) -> bool:
		for living in zombie_manager.get_living_zombies():
			if living.display_name == display_name:
				return living.has_finished_race()
		return false

	func _track_zombie(zombie: Zombie) -> void:
		if zombie == null:
			return
		var name_key: String = zombie.display_name
		if not _progress_by_name.has(name_key):
			_progress_by_name[name_key] = zombie
			zombie.died.connect(_on_zombie_died.bind(name_key))

	func _on_zombie_died(_zombie: Zombie, cause: String, name_key: String) -> void:
		_progress_by_name[name_key + "_cause"] = cause
