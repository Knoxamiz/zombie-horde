class_name FreeCameraFlightLimits
extends RefCounted

## Map-owned free-camera boundaries. Multiple safe regions form one allowed
## flight space, which keeps cameras out of stacked decks without imposing a
## single rectangular box on every course.

var _safe_regions: Array[AABB] = []
var _fallback_bounds_min: Vector3 = Vector3(-18.0, 2.2, -52.0)
var _fallback_bounds_max: Vector3 = Vector3(18.0, 38.0, 52.0)


func configure_for_map_definition(definition: Resource) -> void:
	if definition == null:
		return

	_safe_regions.clear()
	var raw_regions: Variant = definition.get("free_camera_safe_regions")
	if raw_regions is Array:
		for raw_region in raw_regions:
			if raw_region is AABB:
				_safe_regions.append(raw_region)
	if not _safe_regions.is_empty():
		_update_fallback_bounds_from_safe_regions()
		return

	# Authoring-only resources without camera data keep the legacy envelope.
	# Playable maps define their own regions in RaceMapDefinition resources.
	var lane_half_width: float = float(definition.get("lane_half_width"))
	var spawn_origin: Vector3 = definition.get("spawn_origin") as Vector3
	var goal_position: Vector3 = definition.get("goal_position") as Vector3
	var side_extent: float = maxf(lane_half_width + 8.0, 14.0)
	var min_z: float = minf(spawn_origin.z, goal_position.z) - 12.0
	var max_z: float = maxf(spawn_origin.z, goal_position.z) + 12.0
	_fallback_bounds_min = Vector3(-side_extent, 2.2, min_z)
	_fallback_bounds_max = Vector3(side_extent, 38.0, max_z)


func get_safe_region_count() -> int:
	return _safe_regions.size()


func get_enclosing_bounds_min() -> Vector3:
	return _fallback_bounds_min


func get_enclosing_bounds_max() -> Vector3:
	return _fallback_bounds_max


func is_position_inside_active_limits(target_position: Vector3) -> bool:
	if _safe_regions.is_empty():
		return _is_point_inside_box(target_position, _fallback_bounds_min, _fallback_bounds_max)
	for region in _safe_regions:
		if _is_point_inside_region(target_position, region):
			return true
	return false


func clamp_position(target_position: Vector3) -> Vector3:
	if _safe_regions.is_empty():
		return _clamp_point_to_box(target_position, _fallback_bounds_min, _fallback_bounds_max)

	var closest_position: Vector3 = target_position
	var closest_distance_squared: float = INF
	for region in _safe_regions:
		if _is_point_inside_region(target_position, region):
			return target_position
		var clamped_position: Vector3 = _clamp_point_to_box(
			target_position,
			region.position,
			region.end
		)
		var distance_squared: float = target_position.distance_squared_to(clamped_position)
		if distance_squared < closest_distance_squared:
			closest_distance_squared = distance_squared
			closest_position = clamped_position
	return closest_position


func _update_fallback_bounds_from_safe_regions() -> void:
	if _safe_regions.is_empty():
		return
	var min_corner: Vector3 = _region_min_corner(_safe_regions[0])
	var max_corner: Vector3 = _region_max_corner(_safe_regions[0])
	for region in _safe_regions:
		var region_min: Vector3 = _region_min_corner(region)
		var region_max: Vector3 = _region_max_corner(region)
		min_corner = Vector3(
			minf(min_corner.x, region_min.x),
			minf(min_corner.y, region_min.y),
			minf(min_corner.z, region_min.z)
		)
		max_corner = Vector3(
			maxf(max_corner.x, region_max.x),
			maxf(max_corner.y, region_max.y),
			maxf(max_corner.z, region_max.z)
		)
	_fallback_bounds_min = min_corner
	_fallback_bounds_max = max_corner


func _is_point_inside_region(point: Vector3, region: AABB) -> bool:
	return _is_point_inside_box(point, _region_min_corner(region), _region_max_corner(region))


func _is_point_inside_box(point: Vector3, corner_a: Vector3, corner_b: Vector3) -> bool:
	var min_corner := Vector3(
		minf(corner_a.x, corner_b.x),
		minf(corner_a.y, corner_b.y),
		minf(corner_a.z, corner_b.z)
	)
	var max_corner := Vector3(
		maxf(corner_a.x, corner_b.x),
		maxf(corner_a.y, corner_b.y),
		maxf(corner_a.z, corner_b.z)
	)
	return (
		point.x >= min_corner.x and point.x <= max_corner.x
		and point.y >= min_corner.y and point.y <= max_corner.y
		and point.z >= min_corner.z and point.z <= max_corner.z
	)


func _clamp_point_to_box(point: Vector3, corner_a: Vector3, corner_b: Vector3) -> Vector3:
	var min_corner := Vector3(
		minf(corner_a.x, corner_b.x),
		minf(corner_a.y, corner_b.y),
		minf(corner_a.z, corner_b.z)
	)
	var max_corner := Vector3(
		maxf(corner_a.x, corner_b.x),
		maxf(corner_a.y, corner_b.y),
		maxf(corner_a.z, corner_b.z)
	)
	return Vector3(
		clampf(point.x, min_corner.x, max_corner.x),
		clampf(point.y, min_corner.y, max_corner.y),
		clampf(point.z, min_corner.z, max_corner.z)
	)


func _region_min_corner(region: AABB) -> Vector3:
	return Vector3(
		minf(region.position.x, region.end.x),
		minf(region.position.y, region.end.y),
		minf(region.position.z, region.end.z)
	)


func _region_max_corner(region: AABB) -> Vector3:
	return Vector3(
		maxf(region.position.x, region.end.x),
		maxf(region.position.y, region.end.y),
		maxf(region.position.z, region.end.z)
	)
