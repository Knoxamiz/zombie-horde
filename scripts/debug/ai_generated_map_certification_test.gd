extends SceneTree

const AIMapBlueprintExporterScript := preload("res://scripts/maps/ai_map_blueprint_exporter.gd")
const AIMapBlueprintValidatorScript := preload("res://scripts/maps/ai_map_blueprint_validator.gd")
const AIMapBlueprintRegistryScript := preload("res://scripts/maps/ai_map_blueprint_registry.gd")

const MAIN_GAME_SCENE := "res://scenes/main/main_game.tscn"
const JOIN_COUNT := 2
const PASS := 0
const FAIL := 1

var _failures: Array[String] = []
var _started_msec: int = 0
var _target_map_ids: Array[String] = []


func _initialize() -> void:
	call_deferred("_run_all")


func _run_all() -> void:
	_started_msec = Time.get_ticks_msec()
	_target_map_ids = _resolve_target_map_ids()
	print("=== AI generated map certification test ===")
	print("targets: %s" % str(_target_map_ids))

	for generated_map_id in _target_map_ids:
		await _certify_generated_map(generated_map_id)

	var elapsed_sec: float = float(Time.get_ticks_msec() - _started_msec) / 1000.0
	if _failures.is_empty():
		print("SUITE RESULT: PASSED (%.1fs)" % elapsed_sec)
		_finish(PASS)
	else:
		for failure in _failures:
			push_error(failure)
		print("SUITE RESULT: FAILED (%.1fs, %d)" % [elapsed_sec, _failures.size()])
		_finish(FAIL)


func _resolve_target_map_ids() -> Array[String]:
	var requested_map_id: String = _read_cli_arg("--map_id=").strip_edges()
	if not requested_map_id.is_empty():
		return [requested_map_id]
	return AIMapBlueprintRegistryScript.get_all_generated_map_ids()


func _read_cli_arg(prefix: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if str(arg).begins_with(prefix):
			return str(arg).substr(prefix.length())
	return ""


func _certify_generated_map(generated_map_id: String) -> void:
	print("-- %s --" % generated_map_id)
	_test_catalog_entry(generated_map_id)
	_test_exporter_definition(generated_map_id)
	await _test_runtime_certification(generated_map_id)


func _test_catalog_entry(generated_map_id: String) -> void:
	print("  catalog entry")
	var entry: Dictionary = MapCatalog.get_entry_by_id(generated_map_id)
	if entry.is_empty():
		_fail("generated map id '%s' missing from MapCatalog" % generated_map_id)
		return
	if bool(entry.get("enabled", false)):
		_fail("generated map '%s' must not be enabled/playable" % generated_map_id)
	if str(entry.get("status", "")) != MapCatalog.STATUS_PROTOTYPE:
		_fail("generated map '%s' must remain prototype status" % generated_map_id)
	if not MapCatalog.is_prototype_testable(entry):
		_fail("generated map '%s' must be prototype-testable" % generated_map_id)
	if not ResourceLoader.exists(str(entry.get("resource_path", ""))):
		_fail("generated RaceMapDefinition resource missing for '%s'" % generated_map_id)
	if not ResourceLoader.exists(str(entry.get("scene_path", ""))):
		_fail("generated scene wrapper missing for '%s'" % generated_map_id)


func _test_exporter_definition(generated_map_id: String) -> void:
	print("  exporter definition")
	var registry_entry: Dictionary = AIMapBlueprintRegistryScript.get_entry_by_generated_map_id(
		generated_map_id
	)
	if registry_entry.is_empty():
		_fail("no registry entry for generated map '%s'" % generated_map_id)
		return

	var blueprint_id: String = str(registry_entry.get("blueprint_id", ""))
	var export_result: Dictionary = AIMapBlueprintExporterScript.export_validated_blueprint_prototype(
		blueprint_id
	)
	if not bool(export_result.get("ok", false)):
		_fail(
			"AIMapBlueprintExporter failed for '%s': %s"
			% [blueprint_id, str(export_result.get("errors", []))]
		)
		return

	var definition: RaceMapDefinition = MapCatalog.load_definition_by_id(generated_map_id)
	if definition == null:
		_fail("could not reload exported definition for '%s'" % generated_map_id)
		return
	if definition.spawn_origin.z >= definition.goal_position.z:
		_fail("exported spawn_origin.z must be less than goal_position.z for '%s'" % generated_map_id)


func _test_runtime_certification(generated_map_id: String) -> void:
	print("  runtime certification")
	var failures: Array[String] = _certify_prototype_catalog_entry(generated_map_id)
	if not failures.is_empty():
		_record_failures(generated_map_id, failures)
		return

	var definition: RaceMapDefinition = MapCatalog.load_definition_by_id(generated_map_id)
	failures.append_array(MapCertification.certify_definition(definition, generated_map_id))
	if not failures.is_empty():
		_record_failures(generated_map_id, failures)
		return

	var main_game: Node = await _boot_main_game()
	if main_game == null:
		return

	var map_controller: RaceMapController = _node(main_game, "Systems/RaceMapController") as RaceMapController
	var round_manager: RoundManager = _node(main_game, "Systems/RoundManager") as RoundManager
	var zombie_manager: ZombieManager = _node(main_game, "Systems/ZombieManager") as ZombieManager
	var debug_join: DebugJoinSource = _node(main_game, "Systems/DebugJoinSource") as DebugJoinSource
	if map_controller == null or round_manager == null or zombie_manager == null or debug_join == null:
		_fail("missing core systems for '%s'" % generated_map_id)
		main_game.queue_free()
		return

	if not map_controller.load_prototype_map_for_test(generated_map_id):
		_record_failures(
			generated_map_id,
			[
				"prototype load failed: %s"
				% map_controller.get_last_load_failure_reason()
			]
		)
		main_game.queue_free()
		return

	if map_controller.did_last_load_use_fallback():
		_record_failures(generated_map_id, ["prototype load used City Highway fallback"])
		main_game.queue_free()
		return
	if map_controller.get_resolved_map_id() != generated_map_id:
		_record_failures(
			generated_map_id,
			[
				"resolved map id '%s' != '%s'"
				% [map_controller.get_resolved_map_id(), generated_map_id]
			]
		)
		main_game.queue_free()
		return

	var loaded_map: Node3D = main_game.get_node_or_null("World/RoadArena") as Node3D
	failures.append_array(MapCertification.certify_scene_contract(loaded_map, generated_map_id))
	failures.append_array(
		MapCertification.certify_finish_authority(
			_node(main_game, "World/StreamerBase") as Node3D,
			definition,
			generated_map_id
		)
	)
	failures.append_array(
		MapCertification.certify_oob_applied(
			definition,
			map_controller.zombie_config,
			generated_map_id
		)
	)
	if not map_controller.is_finish_contract_valid():
		failures.append("finish contract invalid after generated map load")

	var map_root: Node = loaded_map.get_node_or_null("CoreRoad/MapRoot") if loaded_map != null else null
	if map_root == null:
		failures.append("CoreRoad/MapRoot missing after generated build")
	else:
		var blueprint = AIMapBlueprintRegistryScript.resolve_blueprint_for_generated_map(generated_map_id)
		if blueprint == null:
			failures.append("could not resolve blueprint for '%s'" % generated_map_id)
		else:
			var scene_validation: Dictionary = AIMapBlueprintValidatorScript.validate_generated_scene(
				map_root as Node3D, blueprint, definition
			)
			if not bool(scene_validation.get("ok", false)):
				failures.append("post-load geometry validation failed")
				failures.append_array(scene_validation.get("errors", []))

	if not failures.is_empty():
		_record_failures(generated_map_id, failures)
		main_game.queue_free()
		return

	_configure_test_round(round_manager, map_controller, main_game)
	await _ensure_race_systems_active(main_game)

	for _index in range(JOIN_COUNT):
		debug_join.request_random_join()
	await create_timer(0.1).timeout
	if round_manager.get_pending_count() < 1:
		_record_failures(generated_map_id, ["no participants queued before race start"])
		main_game.queue_free()
		return

	round_manager.start_round()
	if not await _wait_for_round_state(round_manager, RoundManager.RoundState.RUNNING, 8.0):
		_record_failures(generated_map_id, ["race never entered RUNNING"])
		main_game.queue_free()
		return

	_disable_combat_for_test(main_game)
	_set_goal_enabled(main_game, true)
	_teleport_zombies_to_goal(zombie_manager, definition)

	if not await _wait_for_round_state(round_manager, RoundManager.RoundState.ENDED, 12.0):
		_record_failures(generated_map_id, ["race never resolved to ENDED"])
		main_game.queue_free()
		return

	if not _at_least_one_zombie_resolved(zombie_manager):
		_record_failures(generated_map_id, ["no zombie resolved by finish/death"])
		main_game.queue_free()
		return

	round_manager.reset_round()
	await create_timer(0.2).timeout
	if round_manager.state != RoundManager.RoundState.IDLE:
		_record_failures(
			generated_map_id,
			["reset did not return to IDLE (state=%s)" % round_manager.get_state_text()]
		)
		main_game.queue_free()
		return

	debug_join.request_random_join()
	await create_timer(0.1).timeout
	if round_manager.get_pending_count() < 1:
		_record_failures(generated_map_id, ["join blocked after reset"])
		main_game.queue_free()
		return

	print("%s generated-map certification passed" % generated_map_id)
	main_game.queue_free()


func _certify_prototype_catalog_entry(map_id: String) -> Array[String]:
	var failures: Array[String] = []
	var entry: Dictionary = MapCatalog.get_entry_by_id(map_id)
	if entry.is_empty():
		failures.append("map id '%s' not found in MapCatalog" % map_id)
		return failures
	if bool(entry.get("enabled", false)):
		failures.append("generated map '%s' must not be enabled/playable" % map_id)
	if not MapCatalog.is_prototype_testable(entry):
		failures.append("generated map '%s' must be prototype-testable" % map_id)
	var resource_path: String = str(entry.get("resource_path", ""))
	var scene_path: String = str(entry.get("scene_path", ""))
	if resource_path.is_empty() or not ResourceLoader.exists(resource_path):
		failures.append("missing RaceMapDefinition resource for '%s'" % map_id)
	if scene_path.is_empty() or not ResourceLoader.exists(scene_path):
		failures.append("missing map scene for '%s'" % map_id)
	return failures


func _record_failures(map_id: String, failures: Array[String]) -> void:
	var message: String = MapCertification.format_failures(map_id, failures)
	print(message)
	for failure in failures:
		_fail("[%s] %s" % [map_id, failure])


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


func _ensure_race_systems_active(main_game: Node) -> void:
	var race_hud: Node = _node(main_game, "UI/RaceHUD")
	if race_hud != null and race_hud.has_method("set_visible"):
		race_hud.call("set_visible", true)


func _disable_combat_for_test(main_game: Node) -> void:
	var minigun: Node = _node(main_game, "World/StreamerBase/Minigun")
	if minigun != null and minigun.has_method("set_process"):
		minigun.set_process(false)


func _set_goal_enabled(main_game: Node, enabled: bool) -> void:
	var base_goal: Node = _node(main_game, "World/StreamerBase")
	if base_goal != null and base_goal.has_method("set_goal_enabled"):
		base_goal.call("set_goal_enabled", enabled)


func _teleport_zombies_to_goal(zombie_manager: ZombieManager, definition: RaceMapDefinition) -> void:
	if zombie_manager == null or definition == null:
		return
	for zombie in zombie_manager.get_living_zombies():
		if zombie == null:
			continue
		zombie.global_position = definition.goal_position + Vector3(0.0, 0.0, -1.0)


func _wait_for_round_state(round_manager: RoundManager, target_state: int, timeout_sec: float) -> bool:
	var elapsed: float = 0.0
	while elapsed < timeout_sec:
		if round_manager.state == target_state:
			return true
		await create_timer(0.05).timeout
		elapsed += 0.05
	return round_manager.state == target_state


func _at_least_one_zombie_resolved(zombie_manager: ZombieManager) -> bool:
	if zombie_manager.get_total_count() <= 0:
		return false
	for zombie in zombie_manager.get_living_zombies():
		if zombie != null and zombie.has_finished_race():
			return true
	return zombie_manager.get_racing_count() == 0


func _node(main_game: Node, path: String) -> Node:
	return main_game.get_node_or_null(path)


func _fail(message: String) -> void:
	_failures.append(message)


func _finish(exit_code: int) -> void:
	quit(exit_code)
