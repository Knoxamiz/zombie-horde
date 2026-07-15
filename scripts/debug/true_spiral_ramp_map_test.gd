extends SceneTree

const MAP_ID := "true_spiral_ramp"

var _failures: PackedStringArray = PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_catalog_entry()
	await _test_scene_builds()
	_finish()


func _test_catalog_entry() -> void:
	var entry: Dictionary = MapCatalog.get_entry_by_id(MAP_ID)
	if entry.is_empty():
		_fail("True Spiral Ramp missing from MapCatalog")
		return
	if MapCatalog.is_entry_playable(entry):
		_fail("True Spiral Ramp must remain prototype status until certified")
	if not MapCatalog.is_prototype_testable(entry):
		_fail("True Spiral Ramp must be prototype-testable")

	var definition: RaceMapDefinition = MapCatalog.load_definition_by_id(MAP_ID)
	if definition == null:
		_fail("True Spiral Ramp definition failed to load")
		return
	if definition.race_path_points.size() != 18:
		_fail("True Spiral Ramp should use the authored square-staircase route")
	if definition.spawn_origin.y < 40.0:
		_fail("True Spiral Ramp should have expanded vertical level spacing")
	if absf(definition.race_path_points[0].x) < 50.0:
		_fail("True Spiral Ramp should have expanded horizontal footprint")
	if definition.spawn_origin.y <= definition.goal_position.y:
		_fail("True Spiral Ramp should spawn at the top and finish at the bottom")
	if not definition.uses_map_hazard_profile:
		_fail("True Spiral Ramp should use a map hazard profile")


func _test_scene_builds() -> void:
	var definition: RaceMapDefinition = MapCatalog.load_definition_by_id(MAP_ID)
	if definition == null or definition.scene == null:
		_fail("True Spiral Ramp scene is not referenced")
		return

	var scene_root: Node = definition.scene.instantiate()
	if scene_root == null:
		_fail("True Spiral Ramp scene failed to instantiate")
		return
	root.add_child(scene_root)
	await create_timer(0.2).timeout

	var surfaces: Node = scene_root.get_node_or_null("KitSurfaces")
	if surfaces == null:
		_fail("True Spiral Ramp did not build KitSurfaces")
	elif surfaces.get_child_count() < 17:
		_fail("True Spiral Ramp should build square-staircase collision segments")
	elif surfaces.find_child("SpiralEdgeBarrier", true, false) == null:
		_fail("True Spiral Ramp should build physical edge barriers")

	var visual_kit: Node = scene_root.get_node_or_null("VisualKit")
	if visual_kit == null:
		_fail("True Spiral Ramp did not build VisualKit")
	elif visual_kit.find_child("SpiralRoadDeck", true, false) == null:
		_fail("True Spiral Ramp dressing did not build road deck visuals")

	scene_root.queue_free()


func _fail(message: String) -> void:
	push_error(message)
	_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: True Spiral Ramp prototype map contract")
		quit(0)
		return
	for failure in _failures:
		print("FAIL: %s" % failure)
	quit(1)
