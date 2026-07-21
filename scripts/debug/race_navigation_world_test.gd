extends SceneTree

## Contract test for the runtime navigation build. It validates the same
## surface data used for walk collision becomes a queryable navigation world.

const RaceNavigationWorldScript := preload("res://scripts/maps/race_navigation_world.gd")

var _failures: PackedStringArray = PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for map_id in ["quarantine_boulevard", "broken_bridge_pass", "spiral_descent"]:
		await _test_map_navigation_surface_coverage(map_id)
	await _test_square_spiral_route()
	_finish()


func _test_map_navigation_surface_coverage(map_id: String) -> void:
	var definition: RaceMapDefinition = MapCatalog.load_definition_by_id(map_id)
	if definition == null or definition.scene == null:
		_fail("%s definition must load for navigation coverage" % map_id)
		return
	if definition.navigation_profile == null:
		_fail("%s must reference an editable NPC navigation profile" % map_id)
		return
	var arena: Node3D = definition.scene.instantiate() as Node3D
	if arena == null:
		_fail("%s scene did not instantiate" % map_id)
		return
	root.add_child(arena)
	var navigation_world: Node = RaceNavigationWorldScript.new()
	arena.add_child(navigation_world)
	navigation_world.call("configure", arena, definition)
	for _frame in range(20):
		await physics_frame
	if int(navigation_world.call("get_surface_count")) <= 0:
		_fail("%s did not expose navigable walk surfaces" % map_id)
	if not bool(navigation_world.call("is_ready_for_agents")):
		_fail("%s navigation world did not synchronize" % map_id)
	_assert_authored_course_path(arena, definition, map_id)
	print(
		"Navigation coverage %s: surfaces=%d links=%d"
		% [map_id, int(navigation_world.call("get_surface_count")), int(navigation_world.call("get_link_count"))]
	)
	var agent_anchor := Node3D.new()
	arena.add_child(agent_anchor)
	agent_anchor.global_position = definition.spawn_origin
	var agent := NavigationAgent3D.new()
	agent.path_desired_distance = 0.4
	agent.target_desired_distance = 0.8
	agent_anchor.add_child(agent)
	await physics_frame
	agent.target_position = definition.goal_position
	for _frame in range(3):
		await physics_frame
	var direct_path: PackedVector3Array = NavigationServer3D.map_get_path(
		agent.get_navigation_map(), agent_anchor.global_position, definition.goal_position, true
	)
	if (
		direct_path.size() < 2
		or direct_path[direct_path.size() - 1].distance_to(definition.goal_position) > 1.0
	):
		_fail("%s start and finish must be connected through the navigation world" % map_id)
	arena.queue_free()
	await process_frame


func _test_square_spiral_route() -> void:
	var definition: RaceMapDefinition = MapCatalog.load_definition_by_id("true_spiral_ramp")
	if definition == null or definition.scene == null:
		_fail("Square Spiral Ramp definition must load for navigation coverage")
		return
	if definition.navigation_profile == null:
		_fail("Square Spiral Ramp must reference an editable NPC navigation profile")
		return

	var arena: Node3D = definition.scene.instantiate() as Node3D
	if arena == null:
		_fail("Square Spiral Ramp scene did not instantiate")
		return
	root.add_child(arena)

	var navigation_world: Node = RaceNavigationWorldScript.new()
	navigation_world.name = "RaceNavigationWorld"
	arena.add_child(navigation_world)
	navigation_world.call("configure", arena, definition)

	for _frame in range(20):
		await physics_frame

	if int(navigation_world.call("get_surface_count")) < 12:
		_fail("Navigation world should register the spiral's authored road surfaces")
	if not bool(navigation_world.call("is_ready_for_agents")):
		_fail("Navigation world did not synchronize with NavigationServer3D")
	_assert_authored_course_path(arena, definition, "Square Spiral Ramp")

	var agent_anchor := Node3D.new()
	arena.add_child(agent_anchor)
	var agent := NavigationAgent3D.new()
	agent.path_desired_distance = 0.4
	agent.target_desired_distance = 0.8
	agent_anchor.add_child(agent)
	for segment_index in range(definition.race_path_points.size() - 1):
		agent_anchor.global_position = definition.race_path_points[segment_index] + Vector3.UP * 0.8
		agent.target_position = definition.race_path_points[segment_index + 1]
		for _frame in range(2):
			await physics_frame
		var next_position: Vector3 = agent.get_next_path_position()
		if next_position.distance_squared_to(agent_anchor.global_position) <= 0.01:
			_fail("NavigationAgent3D could not route through spiral segment %d" % segment_index)

	arena.queue_free()


func _assert_authored_course_path(arena: Node3D, definition: RaceMapDefinition, map_name: String) -> void:
	var course_path := arena.get_node_or_null("RaceCoursePath") as Path3D
	if course_path == null or course_path.curve == null:
		_fail("%s did not build its RaceCoursePath" % map_name)
		return

	var expected_points: PackedVector3Array = definition.race_path_points
	if expected_points.size() < 2:
		expected_points = PackedVector3Array([definition.spawn_origin, definition.goal_position])
	if course_path.curve.point_count != expected_points.size():
		_fail("%s RaceCoursePath point count does not match its map definition" % map_name)
		return
	var first_point: Vector3 = course_path.to_global(course_path.curve.get_point_position(0))
	var last_point: Vector3 = course_path.to_global(
		course_path.curve.get_point_position(course_path.curve.point_count - 1)
	)
	if first_point.distance_to(expected_points[0]) > 0.05:
		_fail("%s RaceCoursePath does not begin at the authored spawn" % map_name)
	if last_point.distance_to(expected_points[expected_points.size() - 1]) > 0.05:
		_fail("%s RaceCoursePath does not end at the authored finish" % map_name)


func _fail(message: String) -> void:
	push_error(message)
	_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: Race navigation world contract")
		quit(0)
		return
	for failure in _failures:
		print("FAIL: %s" % failure)
	quit(1)
