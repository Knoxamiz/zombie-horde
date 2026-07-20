extends SceneTree

## Verifies the configured Broken Bridge water-fall lifecycle: a zombie falls
## through a real gap, floats at the water surface, then dies as "fell".

const MAIN_GAME_SCENE := "res://scenes/main/main_game.tscn"
const MAP_ID := "broken_bridge_pass"
const BOOT := preload("res://scripts/debug/headless_race_test_boot.gd")
const PRESETS := preload("res://scripts/maps/map_kit_layout_presets.gd")
const SURFACE_BUILDER := preload("res://scripts/maps/kit_map_surface_builder.gd")
const PASS := 0
const FAIL := 1

var _failures: PackedStringArray = PackedStringArray()
var _death_cause: String = ""


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Broken Bridge water fall test ===")
	var packed: PackedScene = BOOT.load_main_game_scene()
	if packed == null:
		_fail("Could not load main game scene")
		_finish()
		return

	var main_game: Node = packed.instantiate()
	root.add_child(main_game)
	await create_timer(0.7).timeout

	var systems: Dictionary = BOOT.get_race_systems(main_game)
	var map_controller: RaceMapController = systems.get("map_controller") as RaceMapController
	var round_manager: RoundManager = systems.get("round_manager") as RoundManager
	var zombie_manager: ZombieManager = systems.get("zombie_manager") as ZombieManager
	var debug_join: DebugJoinSource = systems.get("debug_join") as DebugJoinSource
	if map_controller == null or round_manager == null or zombie_manager == null or debug_join == null:
		_fail("Missing race systems")
		main_game.queue_free()
		_finish()
		return

	if not map_controller.set_active_map_by_id(MAP_ID):
		_fail("Failed to activate Broken Bridge: %s" % map_controller.get_last_load_failure_reason())
		main_game.queue_free()
		_finish()
		return
	await create_timer(0.25).timeout
	BOOT.activate_race_phase(main_game)
	BOOT.configure_standard_test_round(round_manager, map_controller)
	if map_controller.hazard_config != null:
		map_controller.hazard_config.mine_count = 0
		map_controller.hazard_config.sewer_hole_count = 0
		map_controller.hazard_config.obstacle_count = 0

	var definition: RaceMapDefinition = map_controller.get_active_map_definition()
	var config: ZombieConfig = map_controller.zombie_config
	if definition == null or config == null:
		_fail("Broken Bridge definition or zombie config missing")
	elif not definition.water_fall_enabled or not config.water_fall_enabled:
		_fail("Broken Bridge water-fall configuration was not applied")
	elif config.water_float_duration < 1.0:
		_fail("Broken Bridge water float duration must be long enough to read visually")
	else:
		await _run_water_probe(round_manager, zombie_manager, debug_join, definition, config)

	main_game.queue_free()
	_finish()


func _run_water_probe(
	round_manager: RoundManager,
	zombie_manager: ZombieManager,
	debug_join: DebugJoinSource,
	_definition: RaceMapDefinition,
	config: ZombieConfig
) -> void:
	var layout: Dictionary = PRESETS.get_preset(MAP_ID)
	var gaps: Array = layout.get("gaps", [])
	if gaps.is_empty():
		_fail("Broken Bridge needs at least one gap for the water-fall probe")
		return
	var gap: Dictionary = gaps[0]
	var z0: float = float(gap.get("z0", 0.0))
	var z1: float = float(gap.get("z1", z0))
	var gap_center_z: float = (z0 + z1) * 0.5
	var layout_half_width: float = float(layout.get("path_half_width", 4.5))
	var crossing_ratio: float = float(layout.get("gap_crossing_width_ratio", 0.38))
	var crossing_half: float = SURFACE_BUILDER.gap_crossing_half_width(
		layout_half_width, crossing_ratio
	)
	var surface_pieces: Array = SURFACE_BUILDER.resolve_layout_surface_pieces(layout)
	var deck_y: float = SURFACE_BUILDER.get_gap_crossing_top_y(surface_pieces, z0, z1, 0.0)

	round_manager.configure_immediate_launch_for_tests()
	debug_join.request_random_join()
	await create_timer(0.15).timeout
	round_manager.start_round()
	if round_manager.state == RoundManager.RoundState.COUNTDOWN:
		round_manager.launch_round()
	if not await _wait_for_state(round_manager, RoundManager.RoundState.RUNNING, 10.0):
		_fail("Round did not start")
		return

	var zombies: Array[Zombie] = zombie_manager.get_living_zombies()
	if zombies.is_empty():
		_fail("No zombie spawned")
		return
	var zombie: Zombie = zombies[0]
	zombie.died.connect(_on_probe_died)
	zombie.global_position = Vector3(crossing_half + 1.1, deck_y + 0.45, gap_center_z)
	zombie.velocity = Vector3.ZERO

	var entered_water: bool = false
	var elapsed: float = 0.0
	while elapsed < 4.0:
		if zombie.is_water_floating():
			entered_water = true
			var expected_y: float = config.water_surface_y + config.water_float_height
			if absf(zombie.global_position.y - expected_y) > config.water_float_bob_amplitude + 0.16:
				_fail("Water floater is not held at the configured surface")
			break
		if not zombie.is_alive():
			_fail("Zombie died before reaching the water surface")
			return
		await create_timer(0.1).timeout
		elapsed += 0.1
	if not entered_water:
		_fail("Zombie did not enter the water-float state")
		return

	await create_timer(config.water_float_duration * 0.45).timeout
	if not zombie.is_alive() or not zombie.is_water_floating():
		_fail("Zombie did not remain afloat for the configured presentation window")
		return

	elapsed = 0.0
	while elapsed < config.water_float_duration + 2.0 and zombie.is_alive():
		await create_timer(0.1).timeout
		elapsed += 0.1
	if zombie.is_alive():
		_fail("Zombie remained afloat indefinitely instead of dying")
	elif _death_cause != "fell":
		_fail("Expected water-fall death cause 'fell', got '%s'" % _death_cause)
	else:
		print("Broken Bridge water fall lifecycle passed")


func _on_probe_died(_zombie: Zombie, cause: String) -> void:
	_death_cause = cause


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
