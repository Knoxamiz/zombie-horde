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
	if not MapCatalog.is_entry_playable(entry):
		_fail("True Spiral Ramp must be a normal playable map")

	var definition: RaceMapDefinition = MapCatalog.load_definition_by_id(MAP_ID)
	if definition == null:
		_fail("True Spiral Ramp definition failed to load")
		return
	if definition.race_path_points.size() != 18:
		_fail("True Spiral Ramp should use the authored square-staircase route")
		return
	var generated_points: PackedVector3Array = SpiralRampArena.build_path_points()
	if not _points_match(definition.race_path_points, generated_points):
		_fail("True Spiral Ramp resource route should match generated scene route")
	if definition.spawn_origin.y < 40.0:
		_fail("True Spiral Ramp should have expanded vertical level spacing")
	if definition.spawn_origin.distance_to(definition.race_path_points[0] + Vector3.UP * 0.8) > 0.1:
		_fail("True Spiral Ramp spawn should sit on the top route point")
	if definition.goal_position.distance_to(definition.race_path_points[definition.race_path_points.size() - 1] + Vector3.UP * 0.8) > 0.1:
		_fail("True Spiral Ramp goal should sit on the bottom finish point")
	if absf(definition.race_path_points[0].x) < 50.0:
		_fail("True Spiral Ramp should have expanded horizontal footprint")
	if definition.spawn_origin.y <= definition.goal_position.y:
		_fail("True Spiral Ramp should spawn at the top and finish at the bottom")
	if definition.out_of_bounds_half_width < 70.0:
		_fail("True Spiral Ramp OOB width should cover the expanded footprint")
	if definition.out_of_bounds_min_z > -70.0 or definition.out_of_bounds_max_z < 60.0:
		_fail("True Spiral Ramp OOB depth should cover the expanded footprint")
	if definition.out_of_bounds_min_y > -5.0:
		_fail("True Spiral Ramp fall plane should sit below the bottom layer")
	if not definition.uses_map_hazard_profile:
		_fail("True Spiral Ramp should use a map hazard profile")
	if definition.map_mine_count <= 0 or definition.map_obstacle_count <= 0 or definition.map_boost_pad_count <= 0:
		_fail("True Spiral Ramp should ship with a populated hazard profile")


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

	var core_road: Node = scene_root.get_node_or_null("CoreRoad")
	if core_road == null:
		_fail("True Spiral Ramp scene should expose RoadArena/CoreRoad like other selectable maps")
		scene_root.queue_free()
		return
	var core_script: Script = core_road.get_script() as Script
	var core_script_path: String = core_script.resource_path if core_script != null else ""
	if not core_script_path.ends_with("spiral_ramp_arena.gd"):
		_fail("True Spiral Ramp CoreRoad should use spiral_ramp_arena.gd")
	# Dynamic map scenes are built by RaceMapController after instantiation. Mirror
	# that release path before asserting the generated collision and visual nodes.
	if core_road.has_method("ensure_built"):
		core_road.call("ensure_built")

	var surfaces: Node = core_road.get_node_or_null("KitSurfaces")
	var expected_path_points: int = SpiralRampArena.build_path_points().size()
	var expected_segments: int = expected_path_points - 1
	if surfaces == null:
		_fail("True Spiral Ramp did not build KitSurfaces")
	elif _count_named_descendants(surfaces, "SpiralRampSurface") != expected_segments:
		_fail(
			"True Spiral Ramp collision segments: expected %d, got %d (KitSurfaces children=%d)"
			% [
				expected_segments,
				_count_named_descendants(surfaces, "SpiralRampSurface"),
				surfaces.get_child_count(),
			]
		)
	elif _count_named_descendants(surfaces, "SpiralCornerDeck") != expected_path_points:
		_fail("True Spiral Ramp should build a corner deck for every route joint")
	elif _count_named_descendants(surfaces, "SpiralEdgeBarrier") < expected_segments * 2:
		_fail("True Spiral Ramp should build physical edge barriers")
	elif _count_named_descendants(surfaces, "SpiralCornerDeck") <= 0:
		_fail("True Spiral Ramp should build clean corner deck joints")
	elif _count_named_descendants(surfaces, "SpiralCornerBarrierWall") < 30:
		_fail("True Spiral Ramp should wall exposed corner deck edges")
	elif _count_named_descendants(surfaces, "SpiralCornerBarrierPost") < 60:
		_fail("True Spiral Ramp should reinforce corner walls with pylons")

	var visual_kit: Node = core_road.get_node_or_null("VisualKit")
	if visual_kit == null:
		_fail("True Spiral Ramp did not build VisualKit")
	elif _count_named_descendants(visual_kit, "SpiralRoadDeck") < expected_segments:
		_fail("True Spiral Ramp dressing did not build road deck visuals")
	elif _count_named_descendants(visual_kit, "SpiralRoadCenterLine") < expected_segments:
		_fail(
			"True Spiral Ramp road markings: expected at least %d, got %d (VisualKit children=%d)"
			% [
				expected_segments,
				_count_named_descendants(visual_kit, "SpiralRoadCenterLine"),
				visual_kit.get_child_count(),
			]
		)
	elif _count_named_descendants(visual_kit, "SpiralCornerBarrierWallVisual") < 30:
		_fail("True Spiral Ramp should show visible corner barrier walls")
	elif _count_named_descendants(visual_kit, "SpiralGroundPillar") < 4:
		_fail("True Spiral Ramp should have ground-level structural pillars")
	elif _count_named_descendants(visual_kit, "SpiralRouteSupportPillar") < 24:
		_fail("True Spiral Ramp should have route support pillars")
	elif _count_named_descendants(visual_kit, "SpiralSightBlocker") < 8:
		_fail("True Spiral Ramp should have neighboring sight blockers")
	elif _count_named_descendants(visual_kit, "SpiralAtmosphereBand") < 4:
		_fail("True Spiral Ramp should have surrounding atmosphere bands")

	scene_root.queue_free()


func _points_match(actual: PackedVector3Array, expected: PackedVector3Array) -> bool:
	if actual.size() != expected.size():
		return false
	for index in range(actual.size()):
		if actual[index].distance_to(expected[index]) > 0.01:
			return false
	return true


func _count_named_descendants(node: Node, node_name: String) -> int:
	var count: int = 0
	for child: Node in node.get_children():
		# Godot keeps sibling names unique by adding a numeric suffix. The builder
		# intentionally creates repeated segment families, so count that family.
		if str(child.name).begins_with(node_name):
			count += 1
		count += _count_named_descendants(child, node_name)
	return count


func _fail(message: String) -> void:
	push_error(message)
	_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: True Spiral Ramp playable map contract")
		quit(0)
		return
	for failure in _failures:
		print("FAIL: %s" % failure)
	quit(1)
