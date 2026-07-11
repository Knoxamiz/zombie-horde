extends SceneTree

## Verifies Broken Bridge gaps: center crossing is walkable, side void kills quickly.
##
## Usage:
##   godot --headless --path . -s res://scripts/debug/broken_bridge_gap_walk_test.gd

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
	print("=== Broken Bridge gap walk test ===")
	var layout: Dictionary = PRESETS.get_preset("broken_bridge")
	var gaps: Array = layout.get("gaps", [])
	if gaps.is_empty():
		_fail("broken_bridge preset should define gaps")
		_finish()
		return

	var gap: Dictionary = gaps[0]
	var gap_center_z: float = (float(gap["z0"]) + float(gap["z1"])) * 0.5
	var path_half_width: float = float(layout.get("path_half_width", 4.5))
	var crossing_half: float = SURFACE_BUILDER.gap_crossing_half_width(
		path_half_width,
		float(layout.get("gap_crossing_width_ratio", 0.55))
	)

	var packed: PackedScene = BOOT.load_main_game_scene()
	if packed == null:
		_fail("Could not load main game scene")
		_finish()
		return

	var main_game: Node = packed.instantiate()
	root.add_child(main_game)
	await create_timer(0.6).timeout

	var systems: Dictionary = BOOT.get_race_systems(main_game)
	var map_controller: RaceMapController = systems.get("map_controller")
	var round_manager: RoundManager = systems.get("round_manager")
	var zombie_manager: ZombieManager = systems.get("zombie_manager")
	var zombie_config: ZombieConfig = map_controller.zombie_config if map_controller != null else null
	var debug_join: DebugJoinSource = systems.get("debug_join")
	if map_controller == null or round_manager == null or zombie_manager == null or zombie_config == null or debug_join == null:
		_fail("Missing race systems")
		main_game.queue_free()
		_finish()
		return

	map_controller.set_active_map_by_id(MAP_ID)
	await create_timer(0.2).timeout
	BOOT.activate_race_phase(main_game)
	BOOT.configure_standard_test_round(round_manager, map_controller)

	if zombie_config.gap_void_zones.is_empty():
		_fail("Broken Bridge should configure gap_void_zones on zombie_config")
		main_game.queue_free()
		_finish()
		return

	var surface_pieces: Array = SURFACE_BUILDER.resolve_layout_surface_pieces(layout)
	var water_y: float = float(layout.get("water_y", 0.0))
	var deck_y: float = SURFACE_BUILDER.get_gap_crossing_top_y(
		surface_pieces, float(gap["z0"]), float(gap["z1"]), 0.0
	)
	var clearance: float = deck_y - water_y
	if clearance < 6.0:
		_fail("deck clearance %.2fm is below 20ft minimum (water_y=%.2f deck_y=%.2f)" % [clearance, water_y, deck_y])

	var flow: GameFlowController = systems.get("game_flow")
	if flow != null:
		flow.show_race()
	round_manager.configure_immediate_launch_for_tests()
	await _probe_gap_position(
		round_manager,
		zombie_manager,
		debug_join,
		Vector3(0.0, deck_y + 0.45, gap_center_z),
		false,
		"center crossing"
	)
	await _probe_gap_position(
		round_manager,
		zombie_manager,
		debug_join,
		Vector3(crossing_half + 1.1, deck_y + 0.45, gap_center_z),
		true,
		"gap side void"
	)

	main_game.queue_free()
	_finish()


func _probe_gap_position(
	round_manager: RoundManager,
	zombie_manager: ZombieManager,
	debug_join: DebugJoinSource,
	probe_position: Vector3,
	should_die: bool,
	label: String
) -> void:
	_death_cause = ""
	round_manager.reset_round(false)
	zombie_manager.clear_all_zombies()
	debug_join.request_random_join()
	await create_timer(0.15).timeout
	round_manager.start_round()
	if round_manager.state == RoundManager.RoundState.COUNTDOWN:
		round_manager.launch_round()
	if not await _wait_for_state(round_manager, RoundManager.RoundState.RUNNING, 10.0):
		_fail("%s: round did not start" % label)
		return

	var zombies: Array[Zombie] = zombie_manager.get_living_zombies()
	if zombies.is_empty():
		_fail("%s: no zombie spawned" % label)
		return
	var zombie: Zombie = zombies[0]
	if not zombie.died.is_connected(_on_probe_died):
		zombie.died.connect(_on_probe_died)

	zombie.global_position = probe_position
	zombie.velocity = Vector3.ZERO

	var elapsed: float = 0.0
	while elapsed < 4.0:
		if should_die and not zombie.is_alive():
			if _death_cause != "fell":
				_fail("%s: expected fell, got '%s'" % [label, _death_cause])
			else:
				print("%s: passed" % label)
			return
		if not should_die and zombie.is_alive() and zombie.is_on_floor():
			print("%s: passed" % label)
			return
		await create_timer(0.1).timeout
		elapsed += 0.1

	if should_die:
		_fail("%s: zombie survived in gap void" % label)
	else:
		_fail("%s: center crossing not walkable" % label)


func _on_probe_died(_zombie: Node, cause: String) -> void:
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
