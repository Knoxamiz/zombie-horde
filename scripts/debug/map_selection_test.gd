extends SceneTree

const MAIN_GAME_SCENE := "res://scenes/main/main_game.tscn"

var _failures: PackedStringArray = PackedStringArray()
var _main_game: Node


func _initialize() -> void:
	_failures.append_array(_test_catalog_resolution())
	_failures.append_array(_test_profile_migration())
	call_deferred("_begin_runtime_load")


func _begin_runtime_load() -> void:
	_failures.append_array(_test_runtime_load_setup())
	if not _failures.is_empty():
		_finish()
		return
	# Allow RaceMapController._ready and scene tree setup to finish.
	create_timer(0.8).timeout.connect(_continue_runtime_load, CONNECT_ONE_SHOT)


func _continue_runtime_load() -> void:
	_failures.append_array(_test_runtime_load_verify())
	_finish()


func _test_catalog_resolution() -> PackedStringArray:
	var failures: PackedStringArray = PackedStringArray()

	if MapCatalog.get_selectable_count() != 2:
		failures.append(
			"Expected 2 selectable maps, got %d" % MapCatalog.get_selectable_count()
		)

	var city_id: String = MapCatalog.resolve_selectable_map_id("", 0)
	if city_id != "quarantine_boulevard":
		failures.append("Legacy index 0 should resolve to quarantine_boulevard, got %s" % city_id)

	var bridge_id: String = MapCatalog.resolve_selectable_map_id("", 7)
	if bridge_id != "broken_bridge_candidate":
		failures.append("Legacy index 7 should resolve to broken_bridge_candidate, got %s" % bridge_id)

	var from_id: String = MapCatalog.resolve_selectable_map_id("broken_bridge_candidate")
	if from_id != "broken_bridge_candidate":
		failures.append("Map id broken_bridge_candidate should resolve to itself, got %s" % from_id)

	if MapCatalog.get_playable_count() != 1:
		failures.append("Expected exactly one playable map, got %d" % MapCatalog.get_playable_count())

	return failures


func _test_profile_migration() -> PackedStringArray:
	var failures: PackedStringArray = PackedStringArray()
	var profile: StreamerSettingsProfile = StreamerSettingsProfile.new()
	profile.selected_map_index = 7
	profile.selected_map_id = ""
	profile.sanitize_map_selection()

	if profile.get_selected_map_id() != "broken_bridge_candidate":
		failures.append(
			"Profile migration from legacy index 7 failed: id=%s"
			% profile.get_selected_map_id()
		)
	if profile.selected_map_index != 7:
		failures.append(
			"Profile migration should keep legacy index 7, got %d" % profile.selected_map_index
		)

	profile.set_selected_map_id("broken_bridge_candidate")
	if profile.selected_map_index != 7:
		failures.append("set_selected_map_id should sync legacy index to 7")

	return failures


func _test_runtime_load_setup() -> PackedStringArray:
	var failures: PackedStringArray = PackedStringArray()
	var packed: PackedScene = load(MAIN_GAME_SCENE)
	if packed == null:
		failures.append("Failed to load main game scene")
		return failures

	_main_game = packed.instantiate()
	root.add_child(_main_game)
	return failures


func _test_runtime_load_verify() -> PackedStringArray:
	var failures: PackedStringArray = PackedStringArray()
	if _main_game == null:
		failures.append("Main game was not instantiated")
		return failures

	var map_controller: RaceMapController = _main_game.get_node_or_null(
		"Systems/RaceMapController"
	) as RaceMapController
	if map_controller == null:
		failures.append("RaceMapController missing from main game")
		_main_game.queue_free()
		return failures

	var profile: StreamerSettingsProfile = StreamerSettingsProfile.new()
	profile.set_selected_map_id("broken_bridge_candidate")
	var loaded: bool = map_controller.apply_profile(profile)
	if not loaded:
		failures.append("apply_profile returned false for broken_bridge_candidate")

	if map_controller.active_map_id != "broken_bridge_candidate":
		failures.append(
			"Expected active_map_id broken_bridge_candidate, got %s"
			% map_controller.active_map_id
		)

	var road_arena: Node = _main_game.get_node_or_null("World/RoadArena")
	if road_arena == null:
		failures.append("RoadArena missing after loading broken_bridge_candidate")

	profile.set_selected_map_id("quarantine_boulevard")
	map_controller.apply_profile(profile)
	if map_controller.active_map_id != "quarantine_boulevard":
		failures.append(
			"Expected active_map_id quarantine_boulevard, got %s" % map_controller.active_map_id
		)

	_main_game.queue_free()
	return failures


func _finish() -> void:
	_print_summary(_failures)
	quit(1 if _failures.size() > 0 else 0)


func _print_summary(failures: PackedStringArray) -> void:
	if failures.is_empty():
		print("MapSelectionTest: PASSED")
		return
	print("MapSelectionTest: FAILED")
	for failure in failures:
		push_error(failure)
