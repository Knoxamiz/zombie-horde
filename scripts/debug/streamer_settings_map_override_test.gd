extends SceneTree

const MAIN_GAME_SCENE := "res://scenes/main/main_game.tscn"
const MAP_ID := "broken_bridge_pass"
const PASS := 0
const FAIL := 1

var _failures: PackedStringArray = PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Streamer settings map override test ===")
	var main_game: Node = await _boot_main_game()
	if main_game == null:
		_finish()
		return

	var map_controller: RaceMapController = main_game.get_node_or_null(
		"Systems/RaceMapController"
	) as RaceMapController
	if map_controller == null:
		_fail("RaceMapController missing")
		main_game.queue_free()
		_finish()
		return

	var profile: StreamerSettingsProfile = StreamerSettingsProfile.new()
	profile.set_selected_settings_map_index(MapCatalog.resolve_settings_index(MAP_ID, -1))
	profile.premium_mine_count = 26
	profile.premium_obstacle_count = 22
	profile.premium_boost_pad_count = 32
	profile.premium_sewer_hole_count = 4
	profile.premium_defender_count = 12
	profile.premium_vehicle_weight = 75
	profile.premium_cone_weight = 64
	profile.premium_barrier_weight = 72

	if not map_controller.apply_profile(profile):
		_fail("apply_profile failed for Broken Bridge")
	else:
		await create_timer(0.2).timeout
		_verify_map_selection(map_controller)
		_verify_profile_values(map_controller)

	main_game.queue_free()
	_finish()


func _boot_main_game() -> Node:
	var packed: PackedScene = load(MAIN_GAME_SCENE)
	if packed == null:
		_fail("Could not load main game scene")
		return null
	var main_game: Node = packed.instantiate()
	root.add_child(main_game)
	await create_timer(0.5).timeout
	return main_game


func _verify_map_selection(map_controller: RaceMapController) -> void:
	if map_controller.active_map_id != MAP_ID:
		_fail("Expected active map %s, got %s" % [MAP_ID, map_controller.active_map_id])


func _verify_profile_values(map_controller: RaceMapController) -> void:
	if map_controller.hazard_config == null:
		_fail("HazardConfig missing")
	else:
		_expect_int("mine_count", map_controller.hazard_config.mine_count, 26)
		_expect_int("obstacle_count", map_controller.hazard_config.obstacle_count, 22)
		_expect_int("sewer_hole_count", map_controller.hazard_config.sewer_hole_count, 4)
		_expect_int("vehicle_obstacle_weight", map_controller.hazard_config.vehicle_obstacle_weight, 75)
		_expect_int("cone_obstacle_weight", map_controller.hazard_config.cone_obstacle_weight, 64)
		_expect_int("barrier_obstacle_weight", map_controller.hazard_config.barrier_obstacle_weight, 72)

	if map_controller.powerup_config == null:
		_fail("PowerupConfig missing")
	else:
		_expect_int("boost_pad_count", map_controller.powerup_config.boost_pad_count, 32)

	if map_controller.human_defender_config == null:
		_fail("HumanDefenderConfig missing")
	else:
		_expect_int("defender_count", map_controller.human_defender_config.defender_count, 12)


func _expect_int(label: String, actual: int, expected: int) -> void:
	if actual != expected:
		_fail("%s expected %d, got %d" % [label, expected, actual])


func _fail(message: String) -> void:
	_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("StreamerSettingsMapOverrideTest: PASSED")
		quit(PASS)
		return
	print("StreamerSettingsMapOverrideTest: FAILED")
	for failure in _failures:
		push_error(failure)
	quit(FAIL)
