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
	create_timer(0.8).timeout.connect(_continue_runtime_load, CONNECT_ONE_SHOT)


func _continue_runtime_load() -> void:
	_failures.append_array(_test_runtime_load_verify())
	_finish()


func _test_catalog_resolution() -> PackedStringArray:
	var failures: PackedStringArray = PackedStringArray()
	var settings_entries: Array[Dictionary] = MapCatalog.get_selectable_entries_for_settings()

	if settings_entries.size() != 2:
		failures.append(
			"Expected 2 settings maps, got %d" % settings_entries.size()
		)
		return failures

	if str(settings_entries[0].get("id", "")) != "quarantine_boulevard":
		failures.append(
			"Settings index 0 should be quarantine_boulevard, got %s"
			% settings_entries[0].get("id", "")
		)
	if str(settings_entries[1].get("id", "")) != "broken_bridge_candidate":
		failures.append(
			"Settings index 1 should be broken_bridge_candidate, got %s"
			% settings_entries[1].get("id", "")
		)

	if MapCatalog.get_settings_map_id(0) != "quarantine_boulevard":
		failures.append("Settings map id 0 mismatch")
	if MapCatalog.get_settings_map_id(1) != "broken_bridge_candidate":
		failures.append("Settings map id 1 mismatch")

	if MapCatalog.resolve_settings_index("", 7) != 1:
		failures.append("Legacy index 7 should migrate to settings index 1")

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
	if profile.get_selected_settings_map_index() != 1:
		failures.append(
			"Profile migration should use settings index 1, got %d"
			% profile.get_selected_settings_map_index()
		)

	profile.set_selected_settings_map_index(1)
	if profile.selected_map_id != "broken_bridge_candidate":
		failures.append("set_selected_settings_map_index(1) should sync map id")

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
	profile.set_selected_settings_map_index(1)
	var loaded: bool = map_controller.apply_profile(profile)
	if not loaded:
		failures.append("apply_profile returned false for settings index 1")

	if map_controller.active_map_id != "broken_bridge_candidate":
		failures.append(
			"Expected active_map_id broken_bridge_candidate, got %s"
			% map_controller.active_map_id
		)
	if map_controller.active_settings_map_index != 1:
		failures.append(
			"Expected active_settings_map_index 1, got %d"
			% map_controller.active_settings_map_index
		)

	var road_arena: Node = _main_game.get_node_or_null("World/RoadArena")
	if road_arena == null:
		failures.append("RoadArena missing after loading broken_bridge_candidate")

	profile.set_selected_settings_map_index(0)
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
