class_name RaceRouteNavigator
extends RefCounted

## Per-runner race sequencing over a map-authored centerline.
##
## This class owns checkpoint order and progress only. Actual pathfinding and
## avoidance are handled by NavigationAgent3D via RaceNavigationWorld. Keeping
## those responsibilities separate prevents a stacked map from changing race
## order while still allowing agents to route around hazards on each surface.

var _points: PackedVector3Array = PackedVector3Array()
var _segment_index: int = 0
var _distance_along_route: float = 0.0
var _total_length: float = 0.0
var _segment_start_distances: PackedFloat32Array = PackedFloat32Array()


func configure(
	authored_points: PackedVector3Array,
	spawn_position: Vector3,
	goal_position: Vector3
) -> void:
	_points = authored_points.duplicate()
	if _points.size() < 2:
		_points = PackedVector3Array([spawn_position, goal_position])
	# Every race starts at the first authored segment. The previous version only
	# initialized these values for the fallback two-point route, leaving valid
	# authored routes with a zero length and therefore no course to follow.
	_segment_index = 0
	_distance_along_route = 0.0
	_rebuild_course_meter()


func has_route() -> bool:
	return _points.size() >= 2 and _total_length > 0.001


func advance(
	world_position: Vector3,
	checkpoint_reach_radius: float,
	corridor_half_width: float = 0.0,
	checkpoint_vertical_tolerance: float = 3.0
) -> void:
	if not has_route():
		return

	var safe_reach_radius: float = maxf(checkpoint_reach_radius, 0.5)
	# Checkpoints sequence the route; they are not narrow centerline gates.  A
	# runner using a legitimate outer lane must be allowed to clear a turn while
	# it is still inside the map-authored corridor, otherwise it will turn back
	# toward the center point and form a permanent crowd pile at that joint.
	var safe_corridor_half_width: float = maxf(corridor_half_width, safe_reach_radius)
	var safe_vertical_tolerance: float = maxf(checkpoint_vertical_tolerance, 0.5)
	# Launches, avoidance and wide turns can carry a runner just outside its
	# nominal lane as it crosses a checkpoint plane. Give it a bounded recovery
	# margin so route progress remains monotonic instead of pulling it backward
	# to the old waypoint. This is intentionally derived from map/profile data,
	# not a map-specific coordinate or special case.
	var transition_half_width: float = safe_corridor_half_width + safe_reach_radius
	# A launch can land a runner on a later, lower deck that is already part of
	# this exact authored course. Recovering that landing by its matching route
	# segment is not a shortcut: it gives the runner the same ordered course
	# distance it would have earned by travelling there normally. The vertical
	# check is essential on stacked maps so an upper road never borrows progress
	# from a visually aligned lower road.
	_try_reacquire_forward_course_segment(
		world_position,
		safe_corridor_half_width,
		safe_vertical_tolerance
	)
	while _segment_index < _points.size() - 1:
		var segment_start: Vector3 = _points[_segment_index]
		var segment_end: Vector3 = _points[_segment_index + 1]
		var segment: Vector3 = segment_end - segment_start
		var segment_length: float = segment.length()
		if segment_length <= 0.001:
			_segment_index += 1
			continue

		# Race checkpoints live on the horizontal track plane. Character origins
		# sit above that plane, and using the vertical ramp slope in this
		# projection makes a grounded runner look short of a downhill corner.
		# Keep the route's Y value for targets, but sequence turns from horizontal
		# course progress so the same contract works for flat, ramped, and stacked
		# maps.
		var horizontal_segment := Vector3(segment.x, 0.0, segment.z)
		var horizontal_position := Vector3(
			world_position.x - segment_start.x,
			0.0,
			world_position.z - segment_start.z
		)
		var horizontal_segment_length_squared: float = horizontal_segment.length_squared()
		var local_t: float = clampf(
			horizontal_position.dot(horizontal_segment) / maxf(horizontal_segment_length_squared, 0.001),
			0.0,
			1.0
		)
		var projected: Vector3 = segment_start + segment * local_t
		var corridor_offset: Vector3 = world_position - projected
		var horizontal_offset := Vector3(corridor_offset.x, 0.0, corridor_offset.z)
		var vertical_offset: float = absf(corridor_offset.y)
		var reached_endpoint: bool = (
			world_position.distance_to(segment_end) <= safe_reach_radius
			or (
			local_t >= 0.94
			and horizontal_offset.length() <= transition_half_width
			and vertical_offset <= safe_vertical_tolerance
			)
		)
		# A route checkpoint is a forward-crossing plane, not a narrow centerline
		# gate. A launch or an open playable shoulder can put a legitimate runner
		# beyond the lane corridor; once it has crossed the endpoint plane on the
		# correct deck, preserve its route order and let the next segment recover
		# its heading. The vertical check still protects stacked maps from granting
		# credit to a runner on a lower or upper road at the same X/Z coordinate.
		var passed_endpoint: bool = (
			local_t >= 0.985
			and vertical_offset <= safe_vertical_tolerance
		)

		if not reached_endpoint and not passed_endpoint:
			if vertical_offset <= safe_vertical_tolerance:
				_distance_along_route = maxf(
					_distance_along_route,
					_distance_before_segment(_segment_index) + segment_length * local_t
				)
			return

		_distance_along_route = _distance_before_segment(_segment_index) + segment_length
		_segment_index += 1


func _try_reacquire_forward_course_segment(
	world_position: Vector3,
	corridor_half_width: float,
	vertical_tolerance: float
) -> void:
	var best_segment_index: int = _segment_index
	var best_distance: float = _distance_along_route
	for candidate_index in range(_segment_index + 1, _points.size() - 1):
		var segment_start: Vector3 = _points[candidate_index]
		var segment_end: Vector3 = _points[candidate_index + 1]
		var segment: Vector3 = segment_end - segment_start
		var segment_length: float = segment.length()
		if segment_length <= 0.001:
			continue

		# This is the course's authoritative 0-100 lookup: project the runner
		# against every later authored segment, select only a physically valid
		# deck match, then use that segment's cumulative route distance. It is
		# deliberately not a goal-distance or centerline shortcut.
		var horizontal_segment := Vector3(segment.x, 0.0, segment.z)
		var horizontal_length_squared: float = horizontal_segment.length_squared()
		if horizontal_length_squared <= 0.001:
			continue
		var horizontal_position := Vector3(
			world_position.x - segment_start.x,
			0.0,
			world_position.z - segment_start.z
		)
		var local_t: float = clampf(
			horizontal_position.dot(horizontal_segment) / horizontal_length_squared,
			0.0,
			1.0
		)
		var projected: Vector3 = segment_start + segment * local_t
		var lateral_offset := Vector2(
			world_position.x - projected.x,
			world_position.z - projected.z
		).length()
		var vertical_offset: float = absf(world_position.y - projected.y)
		if lateral_offset > corridor_half_width or vertical_offset > vertical_tolerance:
			continue

		var candidate_distance: float = (
			_distance_before_segment(candidate_index)
			+ segment_length * local_t
		)
		if candidate_distance > best_distance + 0.05:
			best_segment_index = candidate_index
			best_distance = candidate_distance

	if best_segment_index > _segment_index:
		_segment_index = best_segment_index
		_distance_along_route = best_distance


func get_target_point(lookahead_distance: float) -> Vector3:
	if not has_route():
		return Vector3.ZERO
	return _point_at_distance(
		minf(_distance_along_route + maxf(lookahead_distance, 0.0), _total_length)
	)


func get_current_segment_end() -> Vector3:
	if not has_route():
		return Vector3.ZERO
	var safe_index: int = mini(_segment_index + 1, _points.size() - 1)
	return _points[safe_index]


func get_center_point() -> Vector3:
	if not has_route():
		return Vector3.ZERO
	return _point_at_distance(_distance_along_route)


func get_forward_direction() -> Vector3:
	if not has_route():
		return Vector3.FORWARD
	var safe_index: int = mini(_segment_index, _points.size() - 2)
	var segment: Vector3 = _points[safe_index + 1] - _points[safe_index]
	var horizontal := Vector3(segment.x, 0.0, segment.z)
	if horizontal.length_squared() <= 0.001:
		return Vector3.FORWARD
	return horizontal.normalized()


func get_progress_ratio() -> float:
	if not has_route():
		return 0.0
	return clampf(get_course_distance() / get_course_length(), 0.0, 1.0)


## Authoritative race distance measured along the authored course, never by
## world-space distance to the goal. This remains meaningful when roads overlap
## vertically, such as parking garages and stacked bridge decks.
func get_course_distance() -> float:
	return clampf(_distance_along_route, 0.0, _total_length)


func get_course_length() -> float:
	return _total_length


func get_current_segment_index() -> int:
	return _segment_index


## The finish can share horizontal coordinates with an earlier deck on a
## stacked map. Consumers must use route order, not world-space proximity, to
## decide when it is valid to hand movement off to the final goal.
func is_on_final_segment() -> bool:
	return has_route() and _segment_index >= _points.size() - 2


func _rebuild_course_meter() -> void:
	_segment_start_distances = PackedFloat32Array()
	var total: float = 0.0
	for index in range(maxi(_points.size() - 1, 0)):
		_segment_start_distances.append(total)
		total += _points[index].distance_to(_points[index + 1])
	_total_length = total


func _distance_before_segment(segment_index: int) -> float:
	if _segment_start_distances.is_empty():
		return 0.0
	var safe_index: int = clampi(segment_index, 0, _segment_start_distances.size() - 1)
	return _segment_start_distances[safe_index]


func _point_at_distance(distance: float) -> Vector3:
	if _points.is_empty():
		return Vector3.ZERO
	var remaining: float = clampf(distance, 0.0, _total_length)
	for index in range(_points.size() - 1):
		var start: Vector3 = _points[index]
		var end: Vector3 = _points[index + 1]
		var segment: Vector3 = end - start
		var length: float = segment.length()
		if length <= 0.001:
			continue
		if remaining <= length or index == _points.size() - 2:
			return start.lerp(end, clampf(remaining / length, 0.0, 1.0))
		remaining -= length
	return _points[_points.size() - 1]
