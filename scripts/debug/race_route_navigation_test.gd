extends SceneTree

const ROUTE_NAVIGATOR := preload("res://scripts/maps/race_route_navigator.gd")

var _failures: PackedStringArray = PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_straight_route_fallback()
	_test_course_meter_uses_cumulative_route_distance()
	_test_square_spiral_stays_on_its_authored_segment()
	_test_stacked_course_progress_uses_route_order()
	_test_outer_lane_clears_every_spiral_checkpoint()
	_test_runner_past_turn_plane_is_never_pulled_backward()
	_test_wide_runner_crossing_turn_plane_keeps_progress()
	_test_lower_deck_does_not_advance_upper_route()
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


func _test_course_meter_uses_cumulative_route_distance() -> void:
	var navigator = ROUTE_NAVIGATOR.new()
	var route := PackedVector3Array([
		Vector3(0.0, 0.0, 0.0),
		Vector3(0.0, 0.0, 10.0),
		Vector3(30.0, 0.0, 10.0),
	])
	navigator.configure(route, route[0], route[2])
	navigator.advance(Vector3(0.0, 0.8, 5.0), 1.0, 4.0)
	if not is_equal_approx(navigator.get_course_distance(), 5.0):
		_fail("Course meter must measure distance along the active authored segment")
		return
	navigator.advance(route[1] + Vector3.UP * 0.8, 1.0, 4.0)
	navigator.advance(Vector3(15.0, 0.8, 10.0), 1.0, 4.0)
	if not is_equal_approx(navigator.get_course_distance(), 25.0):
		_fail("Course meter must retain prior segments instead of measuring goal proximity")
	if not is_equal_approx(navigator.get_progress_ratio(), 0.625):
		_fail("Course meter percentage must derive from cumulative route distance")


func _test_square_spiral_stays_on_its_authored_segment() -> void:
	var definition: RaceMapDefinition = MapCatalog.load_definition_by_id("true_spiral_ramp")
	if definition == null:
		_fail("Square Spiral Ramp definition failed to load")
		return
	var navigator = ROUTE_NAVIGATOR.new()
	navigator.configure(definition.race_path_points, definition.spawn_origin, definition.goal_position)
	var route: PackedVector3Array = definition.race_path_points
	if not navigator.has_route():
		_fail("Square Spiral Ramp should have an authored race route")
		return

	# A point directly below the starting deck must not cause a route jump to a
	# lower, nearby layer. The active segment remains the top eastbound run.
	navigator.advance(
		Vector3(route[0].x, 0.8, route[0].z),
		definition.lane_half_width + 1.0
	)
	var initial_target: Vector3 = navigator.get_target_point(8.0)
	if initial_target.y < route[0].y - 2.0 or initial_target.x <= route[0].x + 1.0:
		_fail("Stacked-route navigation should stay on the top segment before its first corner")

	# After reaching the first corner, the next target must turn south along the
	# authored route instead of aiming through the map toward the final goal.
	navigator.advance(route[1] + Vector3.UP * 0.8, definition.lane_half_width + 1.0)
	var corner_target: Vector3 = navigator.get_target_point(8.0)
	if navigator.get_current_segment_index() != 1:
		_fail("Route navigator should advance exactly one segment at the first corner")
	elif corner_target.z <= route[1].z + 1.0 or absf(corner_target.x - route[1].x) > 0.5:
		_fail("Route navigator should follow the authored turn after the first corner")


func _test_stacked_course_progress_uses_route_order() -> void:
	var definition: RaceMapDefinition = MapCatalog.load_definition_by_id("true_spiral_ramp")
	if definition == null:
		_fail("Square Spiral Ramp definition failed to load for route-progress coverage")
		return
	var navigator = ROUTE_NAVIGATOR.new()
	navigator.configure(definition.race_path_points, definition.spawn_origin, definition.goal_position)
	var route: PackedVector3Array = definition.race_path_points

	# The first top-deck turn shares horizontal space with lower levels. Progress
	# must only account for the first authored segment, never jump toward the
	# finish because an upper deck sits near or above it in world space.
	navigator.advance(route[1] + Vector3.UP * 0.8, definition.lane_half_width + 1.0)
	if navigator.get_current_segment_index() != 1:
		_fail("Stacked-route progress must remain on the next authored segment")
		return
	if navigator.get_progress_ratio() >= 0.5:
		_fail("Stacked-route progress must not promote an upper deck near the finish")


func _test_outer_lane_clears_every_spiral_checkpoint() -> void:
	var definition: RaceMapDefinition = MapCatalog.load_definition_by_id("true_spiral_ramp")
	if definition == null:
		_fail("Square Spiral Ramp definition failed to load for lane transition test")
		return
	var navigator = ROUTE_NAVIGATOR.new()
	navigator.configure(definition.race_path_points, definition.spawn_origin, definition.goal_position)
	var corridor_half_width: float = definition.lane_half_width
	var route: PackedVector3Array = definition.race_path_points
	for segment_index in range(route.size() - 1):
		var start: Vector3 = route[segment_index]
		var finish: Vector3 = route[segment_index + 1]
		var horizontal: Vector3 = Vector3(finish.x - start.x, 0.0, finish.z - start.z)
		if horizontal.length_squared() <= 0.001:
			continue
		var side: Vector3 = Vector3(horizontal.z, 0.0, -horizontal.x).normalized()
		# This is deliberately outside the profile's small checkpoint radius but
		# inside the map's playable lane. It must still advance the course.
		# A live CharacterBody's origin rides above the collision surface. The
		# checkpoint math must still clear a downhill corner from either lane.
		var outer_lane_position: Vector3 = (
			finish
			+ side * (corridor_half_width - 0.05)
			+ Vector3.UP * 0.8
		)
		navigator.advance(outer_lane_position, 2.4, corridor_half_width)
		if navigator.get_current_segment_index() != segment_index + 1:
			_fail(
				"Outer lane runner failed to clear Square Spiral Ramp checkpoint %d"
				% segment_index
			)
			return


func _test_runner_past_turn_plane_is_never_pulled_backward() -> void:
	var navigator = ROUTE_NAVIGATOR.new()
	var route := PackedVector3Array([
		Vector3(0.0, 0.0, 0.0),
		Vector3(0.0, 0.0, 20.0),
		Vector3(20.0, 0.0, 20.0),
	])
	navigator.configure(route, route[0], route[2])
	# This runner has crossed the first turn plane but sits outside the nominal
	# lane after a knockback. It should recover forward onto the next segment,
	# never be retargeted behind itself toward the old center checkpoint.
	navigator.advance(Vector3(4.8, 0.8, 20.4), 2.4, 3.3)
	if navigator.get_current_segment_index() != 1:
		_fail("A runner past a turn plane must advance instead of being pulled backward")
		return
	var recovery_target: Vector3 = navigator.get_target_point(6.0)
	if recovery_target.x <= 0.5:
		_fail("Recovered runner must target forward along the next route segment")


func _test_wide_runner_crossing_turn_plane_keeps_progress() -> void:
	var navigator = ROUTE_NAVIGATOR.new()
	var route := PackedVector3Array([
		Vector3(0.0, 0.0, 0.0),
		Vector3(0.0, 0.0, 20.0),
		Vector3(20.0, 0.0, 20.0),
	])
	navigator.configure(route, route[0], route[2])
	# This runner is far outside the nominal race lane after a launch, but has
	# crossed the first turn plane on the same deck. Its course meter must not
	# remain on the old segment or the leaderboard will under-report it.
	navigator.advance(Vector3(14.0, 0.8, 20.4), 2.4, 3.3, 3.0)
	if navigator.get_current_segment_index() != 1:
		_fail("Wide runner past a turn plane must advance its authored course")
		return
	navigator.advance(Vector3(10.0, 0.8, 20.0), 2.4, 3.3, 3.0)
	if navigator.get_course_distance() < 29.5:
		_fail("Wide runner route meter must continue from the cleared checkpoint")


func _test_lower_deck_does_not_advance_upper_route() -> void:
	var navigator = ROUTE_NAVIGATOR.new()
	var route := PackedVector3Array([
		Vector3(0.0, 10.0, 0.0),
		Vector3(20.0, 10.0, 0.0),
		Vector3(20.0, 0.0, 20.0),
	])
	navigator.configure(route, route[0], route[2])
	# The X/Z position crosses the upper endpoint, but this runner is directly
	# below it on a different deck and must not receive upper-route credit.
	navigator.advance(Vector3(20.2, 0.8, 0.0), 2.4, 3.3, 3.0)
	if navigator.get_current_segment_index() != 0:
		_fail("Lower deck runner must not advance a route checkpoint above it")
	if navigator.get_course_distance() > 0.01:
		_fail("Lower deck runner must not receive upper-route progress")


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
