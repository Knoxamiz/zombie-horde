extends SceneTree

const ROUTE_NAVIGATOR := preload("res://scripts/maps/race_route_navigator.gd")

var _failures: PackedStringArray = PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_straight_route_fallback()
	_test_square_spiral_stays_on_its_authored_segment()
	_finish()


func _test_straight_route_fallback() -> void:
	var navigator = ROUTE_NAVIGATOR.new()
	navigator.configure(PackedVector3Array(), Vector3(0.0, 0.8, -10.0), Vector3(0.0, 0.8, 10.0))
	if not navigator.has_route():
		_fail("Maps without authored waypoints should receive a spawn-to-goal route")
		return
	var target: Vector3 = navigator.get_target_point(3.0)
	if target.z <= -9.5 or target.z >= 0.0:
		_fail("Straight-route lookahead should move forward from spawn")


func _test_square_spiral_stays_on_its_authored_segment() -> void:
	var definition: RaceMapDefinition = MapCatalog.load_definition_by_id("true_spiral_ramp")
	if definition == null:
		_fail("Square Spiral Ramp definition failed to load")
		return
	var navigator = ROUTE_NAVIGATOR.new()
	navigator.configure(definition.race_path_points, definition.spawn_origin, definition.goal_position)
	if not navigator.has_route():
		_fail("Square Spiral Ramp should have an authored race route")
		return

	# A point directly below the starting deck must not cause a route jump to a
	# lower, nearby layer. The active segment remains the top eastbound run.
	navigator.advance(Vector3(-54.0, 0.8, -54.0), definition.lane_half_width + 1.0)
	var initial_target: Vector3 = navigator.get_target_point(8.0)
	if initial_target.y < 40.0 or initial_target.x <= -50.0:
		_fail("Stacked-route navigation should stay on the top segment before its first corner")

	# After reaching the first corner, the next target must turn south along the
	# authored route instead of aiming through the map toward the final goal.
	navigator.advance(Vector3(54.0, 42.0, -54.0), definition.lane_half_width + 1.0)
	var corner_target: Vector3 = navigator.get_target_point(8.0)
	if navigator.get_current_segment_index() != 1:
		_fail("Route navigator should advance exactly one segment at the first corner")
	elif corner_target.z <= -50.0 or absf(corner_target.x - 54.0) > 0.5:
		_fail("Route navigator should follow the authored turn after the first corner")


func _fail(message: String) -> void:
	push_error(message)
	_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: Race route navigation contract")
		quit(0)
		return
	for failure in _failures:
		print("FAIL: %s" % failure)
	quit(1)
