extends SceneTree

const MAIN_GAME_SCENE := "res://scenes/main/main_game.tscn"
const MapKitLayoutPresetsScript := preload("res://scripts/maps/map_kit_layout_presets.gd")
const KitMapArenaScript := preload("res://scripts/maps/kit_map_arena.gd")
const KitMapSurfaceBuilderScript := preload("res://scripts/maps/kit_map_surface_builder.gd")
const EXPECTED_MAP_IDS: Array[String] = [
	"quarantine_boulevard",
	"ai_generated_fallthrough_lower_deck_test",
	"broken_bridge_pass",
	"mine_alley",
	"cone_slalom",
	"vehicle_yard",
	"defender_gauntlet",
	"boost_rush",
]

var _failures: PackedStringArray = PackedStringArray()
var _main_game: Node


func _initialize() -> void:
	_failures.append_array(_test_catalog_resolution())
	_failures.append_array(_test_profile_migration())
	_failures.append_array(_test_layout_preset_uniqueness())
	_failures.append_array(_test_kit_elevation_presets())
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

	if settings_entries.size() != EXPECTED_MAP_IDS.size():
		failures.append(
			"Expected %d settings maps, got %d"
			% [EXPECTED_MAP_IDS.size(), settings_entries.size()]
		)
		return failures

	for index in range(EXPECTED_MAP_IDS.size()):
		var expected_id: String = EXPECTED_MAP_IDS[index]
		var actual_id: String = str(settings_entries[index].get("id", ""))
		if actual_id != expected_id:
			failures.append(
				"Settings index %d should be %s, got %s" % [index, expected_id, actual_id]
			)

	if MapCatalog.get_settings_map_id(0) != "quarantine_boulevard":
		failures.append("Settings map id 0 mismatch")

	if MapCatalog.resolve_settings_index("", 7) != 7:
		failures.append("Legacy index 7 should resolve to settings index 7 (Boost Rush)")

	if MapCatalog.get_settings_map_id(7) != "boost_rush":
		failures.append("Settings index 7 should be boost_rush")

	if MapCatalog.get_playable_count() != EXPECTED_MAP_IDS.size():
		failures.append(
			"Expected %d playable maps, got %d"
			% [EXPECTED_MAP_IDS.size(), MapCatalog.get_playable_count()]
		)

	return failures


func _test_profile_migration() -> PackedStringArray:
	var failures: PackedStringArray = PackedStringArray()

	var legacy_profile: StreamerSettingsProfile = StreamerSettingsProfile.new()
	legacy_profile.selected_map_index = 7
	legacy_profile.selected_map_id = ""
	legacy_profile.sanitize_map_selection()
	if legacy_profile.get_selected_map_id() != "boost_rush":
		failures.append(
			"Legacy index 7 should resolve to boost_rush, got id=%s"
			% legacy_profile.get_selected_map_id()
		)
	if legacy_profile.get_selected_settings_map_index() != 7:
		failures.append(
			"Legacy index 7 should use settings index 7, got %d"
			% legacy_profile.get_selected_settings_map_index()
		)

	var invalid_profile: StreamerSettingsProfile = StreamerSettingsProfile.new()
	invalid_profile.selected_map_index = 99
	invalid_profile.selected_map_id = ""
	invalid_profile.sanitize_map_selection()
	if invalid_profile.get_selected_map_id() != "quarantine_boulevard":
		failures.append(
			"Invalid legacy index should fall back to City Highway, got id=%s"
			% invalid_profile.get_selected_map_id()
		)

	legacy_profile.set_selected_settings_map_index(0)
	if legacy_profile.selected_map_id != "quarantine_boulevard":
		failures.append("set_selected_settings_map_index(0) should sync map id")

	return failures


func _test_layout_preset_uniqueness() -> PackedStringArray:
	var failures: PackedStringArray = PackedStringArray()
	var preset_ids: Array[String] = [
		"broken_bridge",
		"mine_alley",
		"cone_slalom",
		"vehicle_yard",
		"defender_gauntlet",
		"boost_rush",
	]
	var signatures: Dictionary = {}
	for preset_id in preset_ids:
		var layout: Dictionary = MapKitLayoutPresetsScript.get_preset(preset_id)
		var signature: String = "%s|%.0f|%.0f|%d|%d" % [
			str(layout.get("style", "")),
			float(layout.get("spawn_z", 0.0)),
			float(layout.get("goal_z", 0.0)),
			(layout.get("segments", []) as Array).size(),
			(layout.get("gaps", []) as Array).size(),
		]
		if signatures.has(signature):
			failures.append(
				"Layout preset '%s' duplicates path signature of '%s'"
				% [preset_id, signatures[signature]]
			)
		signatures[signature] = preset_id
	return failures


func _test_kit_elevation_presets() -> PackedStringArray:
	var failures: PackedStringArray = PackedStringArray()
	var elevated_ids: Array[String] = ["mine_alley", "cone_slalom", "vehicle_yard"]
	for preset_id in elevated_ids:
		var layout: Dictionary = MapKitLayoutPresetsScript.get_preset(preset_id)
		var pieces: Array = layout.get("surface_pieces", [])
		if pieces.is_empty():
			failures.append("Preset '%s' should define surface_pieces for elevation" % preset_id)
			continue

		var arena = KitMapArenaScript.new()
		arena.layout_preset_id = preset_id
		root.add_child(arena)

		var surfaces: Node = arena.get_node_or_null("KitSurfaces")
		if surfaces == null or surfaces.get_child_count() < 2:
			failures.append(
				"Preset '%s' should build multiple KitSurfaces pieces, got %d"
				% [preset_id, surfaces.get_child_count() if surfaces != null else 0]
			)

		var sample_z: float = (
			float(layout.get("spawn_z", 0.0)) + float(layout.get("goal_z", 0.0))
		) * 0.5
		var mid_y: float = KitMapSurfaceBuilderScript.get_top_y_at_z(pieces, sample_z, 0.0)
		if mid_y <= 0.01:
			failures.append(
				"Preset '%s' should have elevated mid-route Y, got %.2f" % [preset_id, mid_y]
			)

		arena.queue_free()
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
	profile.set_selected_settings_map_index(0)
	var loaded: bool = map_controller.apply_profile(profile)
	if not loaded:
		failures.append("apply_profile returned false for settings index 0")

	if map_controller.active_map_id != "quarantine_boulevard":
		failures.append(
			"Expected active_map_id quarantine_boulevard, got %s"
			% map_controller.active_map_id
		)
	if map_controller.active_settings_map_index != 0:
		failures.append(
			"Expected active_settings_map_index 0, got %d"
			% map_controller.active_settings_map_index
		)

	var road_arena: Node = _main_game.get_node_or_null("World/RoadArena")
	if road_arena == null:
		failures.append("RoadArena missing after loading City Highway")

	var viewport_camera: Camera3D = _main_game.get_viewport().get_camera_3d()
	if viewport_camera != null:
		var camera_path: String = str(viewport_camera.get_path())
		if "SpectatorCamera" not in camera_path:
			failures.append("Spectator camera is not active after City Highway load: %s" % camera_path)

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
