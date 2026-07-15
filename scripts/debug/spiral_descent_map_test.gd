extends SceneTree

const MAP_ID := "spiral_descent"
const MapKitLayoutPresetsScript := preload("res://scripts/maps/map_kit_layout_presets.gd")
const KitMapSurfaceBuilderScript := preload("res://scripts/maps/kit_map_surface_builder.gd")

var _failures: PackedStringArray = PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_catalog_entry()
	_test_layout_shape()
	await _test_scene_builds_surfaces()
	_finish()


func _test_catalog_entry() -> void:
	var entry: Dictionary = MapCatalog.get_entry_by_id(MAP_ID)
	if entry.is_empty():
		_fail("Spiral Descent missing from MapCatalog")
		return
	if MapCatalog.is_entry_playable(entry):
		_fail("Spiral Descent must remain prototype status until certified")
	if not MapCatalog.is_prototype_testable(entry):
		_fail("Spiral Descent must be prototype-testable")

	var definition: RaceMapDefinition = MapCatalog.load_definition_by_id(MAP_ID)
	if definition == null:
		_fail("Spiral Descent definition failed to load")
		return
	if definition.spawn_origin.y <= definition.goal_position.y:
		_fail("Spiral Descent should spawn at the top and finish at the bottom")
	if not definition.uses_map_hazard_profile:
		_fail("Spiral Descent should use a map hazard profile")


func _test_layout_shape() -> void:
	var layout: Dictionary = MapKitLayoutPresetsScript.get_preset(MAP_ID)
	var surface_pieces: Array = KitMapSurfaceBuilderScript.resolve_layout_surface_pieces(layout)
	var zones: Array[Dictionary] = KitMapSurfaceBuilderScript.build_elevation_zones_from_pieces(surface_pieces)
	var deck_heights: Array[float] = []
	var ramp_count: int = 0

	for raw_spec in surface_pieces:
		if raw_spec is not Dictionary:
			continue
		var spec: Dictionary = raw_spec
		if str(spec.get("shape", "deck")) == "ramp":
			ramp_count += 1
		else:
			deck_heights.append(float(spec.get("top_y", 0.0)))

	if deck_heights.size() != 4:
		_fail("Spiral Descent should have four deck levels, got %d" % deck_heights.size())
	if ramp_count != 3:
		_fail("Spiral Descent should have three descending ramps, got %d" % ramp_count)
	for index in range(1, deck_heights.size()):
		if deck_heights[index] >= deck_heights[index - 1]:
			_fail("Spiral Descent deck heights should descend every level: %s" % str(deck_heights))
			break
	if zones.size() != surface_pieces.size():
		_fail("Spiral Descent hazard elevation zones should match surface pieces")

	var spawn_y: float = KitMapSurfaceBuilderScript.get_top_y_at_z(surface_pieces, -92.0, -999.0)
	var finish_y: float = KitMapSurfaceBuilderScript.get_top_y_at_z(surface_pieces, 92.0, -999.0)
	if absf(spawn_y - 12.0) > 0.05:
		_fail("Spiral Descent spawn surface height should be 12.0, got %.2f" % spawn_y)
	if absf(finish_y - 0.0) > 0.05:
		_fail("Spiral Descent finish surface height should be 0.0, got %.2f" % finish_y)


func _test_scene_builds_surfaces() -> void:
	var definition: RaceMapDefinition = MapCatalog.load_definition_by_id(MAP_ID)
	if definition == null or definition.scene == null:
		_fail("Spiral Descent scene is not referenced")
		return

	var scene_root: Node = definition.scene.instantiate()
	if scene_root == null:
		_fail("Spiral Descent scene failed to instantiate")
		return
	root.add_child(scene_root)
	await create_timer(0.2).timeout

	var surfaces: Node = scene_root.get_node_or_null("CoreRoad/KitSurfaces")
	if surfaces == null:
		_fail("Spiral Descent did not build KitSurfaces")
	elif surfaces.get_child_count() < 7:
		_fail("Spiral Descent should build all deck/ramp surface pieces")

	var visual_kit: Node = scene_root.get_node_or_null("CoreRoad/VisualKit")
	if visual_kit == null:
		_fail("Spiral Descent did not build VisualKit")
	elif visual_kit.find_child("SpiralCoreColumn", true, false) == null:
		_fail("Spiral Descent dressing did not build spiral core column")

	scene_root.queue_free()


func _fail(message: String) -> void:
	push_error(message)
	_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: Spiral Descent prototype map contract")
		quit(0)
		return
	for failure in _failures:
		print("FAIL: %s" % failure)
	quit(1)
