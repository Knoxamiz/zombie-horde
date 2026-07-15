extends SceneTree

const MAIN_GAME_SCENE := "res://scenes/main/main_game.tscn"
const MapKitLayoutPresetsScript := preload("res://scripts/maps/map_kit_layout_presets.gd")
const KitMapArenaScript := preload("res://scripts/maps/kit_map_arena.gd")
const KitMapSurfaceBuilderScript := preload("res://scripts/maps/kit_map_surface_builder.gd")
const EXPECTED_MAP_IDS: Array[String] = [
	"quarantine_boulevard",
	"broken_bridge_pass",
	"spiral_descent",
	"true_spiral_ramp",
]
const EXPECTED_PLAYABLE_COUNT := 2

var _failures: PackedStringArray = PackedStringArray()
var _main_game: Node


func _initialize() -> void:
	_failures.append_array(_test_catalog_resolution())
	_failures.append_array(_test_profile_migration())
	_failures.append_array(_test_layout_preset_uniqueness())
	_failures.append_array(_test_kit_elevation_presets())
	_failures.append_array(_test_kit_route_context())
	_failures.append_array(_test_broken_bridge_gap_crossings())
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

	if MapCatalog.resolve_settings_index("", 2) != 1:
		failures.append("Legacy index 2 should resolve to settings index 1 (Broken Bridge)")

	if MapCatalog.get_settings_map_id(1) != "broken_bridge_pass":
		failures.append("Settings index 1 should be broken_bridge_pass")

	if MapCatalog.get_playable_count() != EXPECTED_PLAYABLE_COUNT:
		failures.append(
			"Expected %d playable maps, got %d"
			% [EXPECTED_PLAYABLE_COUNT, MapCatalog.get_playable_count()]
		)

	return failures


func _test_profile_migration() -> PackedStringArray:
	var failures: PackedStringArray = PackedStringArray()

	var legacy_profile: StreamerSettingsProfile = StreamerSettingsProfile.new()
	legacy_profile.selected_map_index = 7
	legacy_profile.selected_map_id = ""
	legacy_profile.sanitize_map_selection()
	if legacy_profile.get_selected_map_id() != "quarantine_boulevard":
		failures.append(
			"Disabled legacy index 7 should fall back to City Highway, got id=%s"
			% legacy_profile.get_selected_map_id()
		)
	if legacy_profile.get_selected_settings_map_index() != 0:
		failures.append(
			"Disabled legacy index 7 should use settings index 0, got %d"
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
		"broken_bridge_pass",
		"mine_alley",
		"cone_slalom",
		"vehicle_yard",
		"defender_gauntlet",
		"boost_rush",
		"spiral_descent",
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
	var elevated_ids: Array[String] = [
		"mine_alley",
		"cone_slalom",
		"vehicle_yard",
		"broken_bridge_pass",
		"defender_gauntlet",
		"boost_rush",
	]
	for preset_id in elevated_ids:
		var layout: Dictionary = MapKitLayoutPresetsScript.get_preset(preset_id)
		var pieces: Array = layout.get("surface_pieces", [])
		if pieces.is_empty():
			failures.append("Preset '%s' should define surface_pieces for elevation" % preset_id)
			continue

		var arena = KitMapArenaScript.new()
		arena.layout_preset_id = preset_id
		root.add_child(arena)
		arena.ensure_built()

		var surfaces: Node = arena.get_node_or_null("KitSurfaces")
		if surfaces == null or surfaces.get_child_count() < 2:
			failures.append(
				"Preset '%s' should build multiple KitSurfaces pieces, got %d"
				% [preset_id, surfaces.get_child_count() if surfaces != null else 0]
			)

		var has_elevation: bool = false
		for raw_spec in pieces:
			if raw_spec is not Dictionary:
				continue
			var spec: Dictionary = raw_spec
			var shape: String = str(spec.get("shape", "deck"))
			if shape == "ramp":
				if abs(float(spec.get("height_delta", 0.0))) > 0.01:
					has_elevation = true
			elif abs(float(spec.get("top_y", 0.0))) > 0.01:
				has_elevation = true
		if not has_elevation:
			failures.append("Preset '%s' should define elevated surface pieces" % preset_id)

		arena.queue_free()
	return failures


func _test_kit_route_context() -> PackedStringArray:
	var failures: PackedStringArray = PackedStringArray()
	var preset_ids: Array[String] = [
		"broken_bridge_pass",
		"mine_alley",
		"cone_slalom",
		"vehicle_yard",
		"defender_gauntlet",
		"boost_rush",
	]
	for preset_id in preset_ids:
		var arena = KitMapArenaScript.new()
		arena.layout_preset_id = preset_id
		root.add_child(arena)
		arena.ensure_built()

		var ground_bed: Node = arena.get_node_or_null("GroundBed")
		if ground_bed == null:
			failures.append("Preset '%s' should build GroundBed route context" % preset_id)

		var visual_kit: Node = arena.get_node_or_null("VisualKit")
		if visual_kit == null:
			failures.append("Preset '%s' missing VisualKit for guardrails" % preset_id)
		else:
			var barrier_count: int = 0
			for child in visual_kit.get_children():
				if child is Node3D:
					barrier_count += 1
			if barrier_count < 8:
				failures.append(
					"Preset '%s' should place route guardrail props, got %d visual children"
					% [preset_id, barrier_count]
				)

		arena.queue_free()
	return failures


func _test_broken_bridge_gap_crossings() -> PackedStringArray:
	var failures: PackedStringArray = PackedStringArray()
	var layout: Dictionary = MapKitLayoutPresetsScript.get_preset("broken_bridge_pass")
	var path_half_width: float = float(layout.get("path_half_width", 4.5))
	var ratio: float = float(
		layout.get("gap_crossing_width_ratio", KitMapSurfaceBuilderScript.DEFAULT_GAP_CROSSING_WIDTH_RATIO)
	)
	var expected_half: float = KitMapSurfaceBuilderScript.gap_crossing_half_width(path_half_width, ratio)
	var max_allowed_half: float = path_half_width * 0.65

	var arena = KitMapArenaScript.new()
	arena.layout_preset_id = "broken_bridge_pass"
	root.add_child(arena)
	arena.ensure_built()

	var surfaces: Node = arena.get_node_or_null("KitSurfaces")
	if surfaces == null:
		failures.append("Broken Bridge should build KitSurfaces")
		arena.queue_free()
		return failures

	var crossing_count: int = 0
	for child in surfaces.get_children():
		if child is MapSurfacePiece and str((child as MapSurfacePiece).segment_id) == "gap_crossing":
			crossing_count += 1
			var shape_node: CollisionShape3D = child.get_node_or_null("Collision") as CollisionShape3D
			if shape_node == null or shape_node.shape == null:
				failures.append("Gap crossing piece missing collision shape")
				continue
			var box: BoxShape3D = shape_node.shape as BoxShape3D
			if box == null:
				continue
			var actual_half: float = box.size.x * 0.5
			if abs(actual_half - expected_half) > 0.08:
				failures.append(
					"Gap crossing collision width mismatch: %.2f (expected %.2f)"
					% [actual_half, expected_half]
				)
			if actual_half > max_allowed_half:
				failures.append(
					"Gap crossing spans too much of the deck (%.2f > max %.2f) — looks like an invisible bridge"
					% [actual_half, max_allowed_half]
				)

	if crossing_count != 3:
		failures.append("Broken Bridge should have 3 gap crossings, got %d" % crossing_count)

	var visual_kit: Node = arena.get_node_or_null("VisualKit")
	if visual_kit != null:
		var plank_count: int = 0
		var route_shoulder_count: int = 0
		var gap_shoulder_count: int = 0
		var gap_z_ranges: Array = layout.get("gaps", [])
		for child in visual_kit.get_children():
			if not str(child.name).begins_with("GapCrossingPlank"):
				continue
			plank_count += 1
		for child in visual_kit.get_children():
			var child_name: String = str(child.name)
			if not (child_name.begins_with("RouteShoulder") or child_name.begins_with("GapEdgeShoulder")):
				continue
			if child_name.begins_with("RouteShoulder"):
				route_shoulder_count += 1
			var shoulder_z: float = (child as Node3D).position.z
			for raw_gap in gap_z_ranges:
				if raw_gap is Dictionary:
					var z0: float = float(raw_gap.get("z0", 0.0))
					var z1: float = float(raw_gap.get("z1", z0))
					if shoulder_z >= z0 - 0.1 and shoulder_z <= z1 + 0.1:
						gap_shoulder_count += 1
						break
		if plank_count != 3:
			failures.append("Broken Bridge should show 3 gap crossing planks, got %d" % plank_count)
		if route_shoulder_count < 40:
			failures.append(
				"Broken Bridge should build route shoulders along the track (got %d)"
				% route_shoulder_count
			)

	var boundaries: Node = arena.get_node_or_null("GameplayBoundaries")
	if boundaries == null or boundaries.get_child_count() < 3:
		failures.append("Broken Bridge should build spawn lane bumper walls")

	if surfaces != null:
		for child in surfaces.get_children():
			if child is StaticBody3D and child.collision_layer == 0:
				failures.append("Broken Bridge KitSurfaces gameplay collision was stripped")
				break

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

	var spiral_settings_index: int = MapCatalog.resolve_settings_index("true_spiral_ramp", -1)
	profile.set_selected_settings_map_index(spiral_settings_index)
	loaded = map_controller.apply_profile(profile)
	if not loaded:
		failures.append("apply_profile returned false for True Spiral Ramp")
	if not map_controller.is_prototype_test_load_active():
		failures.append("True Spiral Ramp settings selection should use prototype load mode")
	if map_controller.get_resolved_map_id() != "true_spiral_ramp":
		failures.append(
			"Expected resolved prototype map id true_spiral_ramp, got %s"
			% map_controller.get_resolved_map_id()
		)
	if map_controller.did_last_load_use_fallback():
		failures.append("True Spiral Ramp settings selection used City Highway fallback")
	var active_definition: RaceMapDefinition = map_controller.get_active_map_definition()
	if active_definition == null or active_definition.display_name != "Square Spiral Ramp":
		failures.append(
			"Expected active definition Square Spiral Ramp, got %s"
			% (active_definition.display_name if active_definition != null else "null")
		)
	if not map_controller.should_use_definition_race_camera():
		failures.append("True Spiral Ramp should use definition camera framing")
	road_arena = _main_game.get_node_or_null("World/RoadArena")
	if road_arena == null:
		failures.append("RoadArena missing after loading True Spiral Ramp")
	else:
		var arena_script: Script = road_arena.get_script() as Script
		var arena_script_path: String = arena_script.resource_path if arena_script != null else ""
		if not arena_script_path.ends_with("spiral_ramp_arena.gd"):
			failures.append(
				"True Spiral Ramp loaded the wrong arena script: %s"
				% arena_script_path
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
