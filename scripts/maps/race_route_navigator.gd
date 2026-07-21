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
	_total_length = _calculate_total_length()


func has_route() -> bool:
	return _points.size() >= 2 and _total_length > 0.001


func advance(world_position: Vector3, corridor_radius: float) -> void:
	if not has_route():
		return

	var safe_radius: float = maxf(corridor_radius, 0.5)
	while _segment_index < _points.size() - 1:
		var segment_start: Vector3 = _points[_segment_index]
		var segment_end: Vector3 = _points[_segment_index + 1]
		var segment: Vector3 = segment_end - segment_start
		var segment_length: float = segment.length()
		if segment_length <= 0.001:
			_segment_index += 1
			continue

		var local_t: float = clampf(
			(world_position - segment_start).dot(segment) / segment.length_squared(),
			0.0,
			1.0
		)
		var projected: Vector3 = segment_start + segment * local_t
		var corridor_offset: Vector3 = world_position - projected
		var horizontal_offset := Vector3(corridor_offset.x, 0.0, corridor_offset.z)
		var reached_endpoint: bool = world_position.distance_to(segment_end) <= safe_radius
		var passed_endpoint: bool = (
			local_t >= 0.985
			and horizontal_offset.length() <= safe_radius
		)

		if not reached_endpoint and not passed_endpoint:
			_distance_along_route = maxf(
				_distance_along_route,
				_distance_before_segment(_segment_index) + segment_length * local_t
			)
			return

		_distance_along_route = _distance_before_segment(_segment_index) + segment_length
		_segment_index += 1


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
	return clampf(_distance_along_route / _total_length, 0.0, 1.0)


func get_current_segment_index() -> int:
	return _segment_index


## The finish can share horizontal coordinates with an earlier deck on a
## stacked map. Consumers must use route order, not world-space proximity, to
## decide when it is valid to hand movement off to the final goal.
func is_on_final_segment() -> bool:
	return has_route() and _segment_index >= _points.size() - 2


func _calculate_total_length() -> float:
	var total: float = 0.0
	for index in range(_points.size() - 1):
		total += _points[index].distance_to(_points[index + 1])
	return total


func _distance_before_segment(segment_index: int) -> float:
	var distance: float = 0.0
	for index in range(mini(segment_index, _points.size() - 1)):
		distance += _points[index].distance_to(_points[index + 1])
	return distance


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
