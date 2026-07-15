class_name SurfaceSpawnResolver
extends RefCounted

## Shared z-aware placement helper for hazards, pickups, and other street-level spawns.


static func random_z(
	rng: RandomNumberGenerator,
	zones: Array[Dictionary],
	min_z: float,
	max_z: float
) -> float:
	if rng == null or zones.is_empty():
		return randf_range(min_z, max_z)

	var ranges: Array[Dictionary] = []
	var total_length: float = 0.0
	for zone in zones:
		var z0: float = maxf(float(zone.get("z0", 0.0)), min_z)
		var z1: float = minf(float(zone.get("z1", z0)), max_z)
		if z1 <= z0:
			continue
		total_length += z1 - z0
		ranges.append({"z0": z0, "z1": z1, "end_weight": total_length})

	if ranges.is_empty() or total_length <= 0.0:
		return rng.randf_range(min_z, max_z)

	var pick: float = rng.randf_range(0.0, total_length)
	for range_spec in ranges:
		if pick <= float(range_spec.get("end_weight", 0.0)):
			return rng.randf_range(
				float(range_spec.get("z0", min_z)),
				float(range_spec.get("z1", max_z))
			)
	var final_range: Dictionary = ranges[ranges.size() - 1]
	return rng.randf_range(
		float(final_range.get("z0", min_z)),
		float(final_range.get("z1", max_z))
	)


static func y_at_z(zones: Array[Dictionary], z: float, fallback: float) -> float:
	for zone in zones:
		var z0: float = float(zone.get("z0", 0.0))
		var z1: float = float(zone.get("z1", z0))
		if z < z0 - 0.05 or z > z1 + 0.05:
			continue
		if bool(zone.get("is_ramp", false)):
			var start_y: float = float(zone.get("start_y", fallback))
			var end_y: float = float(zone.get("end_y", start_y))
			var t: float = 0.0 if z1 <= z0 else clampf((z - z0) / (z1 - z0), 0.0, 1.0)
			return lerpf(start_y, end_y, t)
		return float(zone.get("y", fallback))
	return fallback


static func has_overlap(zones: Array[Dictionary], min_z: float, max_z: float) -> bool:
	if zones.is_empty():
		return true
	for zone in zones:
		var z0: float = maxf(float(zone.get("z0", 0.0)), min_z)
		var z1: float = minf(float(zone.get("z1", z0)), max_z)
		if z1 > z0:
			return true
	return false


static func has_path(path_points: PackedVector3Array) -> bool:
	return path_points.size() >= 2


static func path_length(path_points: PackedVector3Array) -> float:
	var total: float = 0.0
	for index in range(path_points.size() - 1):
		total += path_points[index].distance_to(path_points[index + 1])
	return total


static func random_path_position(
	rng: RandomNumberGenerator,
	path_points: PackedVector3Array,
	lateral_half_width: float,
	y_offset: float,
	end_padding: float = 6.0
) -> Vector3:
	var total: float = path_length(path_points)
	if rng == null or path_points.size() < 2 or total <= 0.001:
		return Vector3.ZERO
	var min_distance: float = minf(end_padding, total * 0.25)
	var max_distance: float = maxf(total - min_distance, min_distance)
	var distance: float = rng.randf_range(min_distance, max_distance)
	var lateral_offset: float = rng.randf_range(-lateral_half_width, lateral_half_width)
	return point_at_path_distance(path_points, distance, lateral_offset, y_offset)


static func point_at_path_distance(
	path_points: PackedVector3Array,
	distance: float,
	lateral_offset: float = 0.0,
	y_offset: float = 0.0
) -> Vector3:
	if path_points.size() <= 0:
		return Vector3.ZERO
	if path_points.size() == 1:
		return path_points[0] + Vector3.UP * y_offset

	var remaining: float = maxf(distance, 0.0)
	for index in range(path_points.size() - 1):
		var a: Vector3 = path_points[index]
		var b: Vector3 = path_points[index + 1]
		var segment: Vector3 = b - a
		var length: float = segment.length()
		if length <= 0.001:
			continue
		if remaining <= length or index == path_points.size() - 2:
			var t: float = clampf(remaining / length, 0.0, 1.0)
			var center: Vector3 = a.lerp(b, t)
			var horizontal_forward := Vector3(segment.x, 0.0, segment.z)
			if horizontal_forward.length_squared() <= 0.001:
				horizontal_forward = Vector3.FORWARD
			horizontal_forward = horizontal_forward.normalized()
			var side := Vector3(horizontal_forward.z, 0.0, -horizontal_forward.x).normalized()
			return center + side * lateral_offset + Vector3.UP * y_offset
		remaining -= length

	return path_points[path_points.size() - 1] + Vector3.UP * y_offset


static func direction_at_path_distance(path_points: PackedVector3Array, distance: float) -> Vector3:
	if path_points.size() < 2:
		return Vector3.FORWARD
	var remaining: float = maxf(distance, 0.0)
	for index in range(path_points.size() - 1):
		var segment: Vector3 = path_points[index + 1] - path_points[index]
		var length: float = segment.length()
		if length <= 0.001:
			continue
		if remaining <= length or index == path_points.size() - 2:
			var horizontal_forward := Vector3(segment.x, 0.0, segment.z)
			if horizontal_forward.length_squared() <= 0.001:
				return Vector3.FORWARD
			return horizontal_forward.normalized()
		remaining -= length
	return Vector3.FORWARD


static func closest_path_distance(path_points: PackedVector3Array, world_position: Vector3) -> float:
	if path_points.size() < 2:
		return 0.0
	var best_distance: float = 0.0
	var best_distance_squared: float = INF
	var walked: float = 0.0
	for index in range(path_points.size() - 1):
		var a: Vector3 = path_points[index]
		var b: Vector3 = path_points[index + 1]
		var segment: Vector3 = b - a
		var flat_segment := Vector3(segment.x, 0.0, segment.z)
		var length_squared: float = flat_segment.length_squared()
		var length: float = sqrt(length_squared)
		if length_squared <= 0.001:
			continue
		var flat_to_point := Vector3(world_position.x - a.x, 0.0, world_position.z - a.z)
		var t: float = clampf(flat_to_point.dot(flat_segment) / length_squared, 0.0, 1.0)
		var projected: Vector3 = a + segment * t
		var distance_squared: float = Vector3(
			world_position.x - projected.x,
			0.0,
			world_position.z - projected.z
		).length_squared()
		if distance_squared < best_distance_squared:
			best_distance_squared = distance_squared
			best_distance = walked + length * t
		walked += length
	return best_distance
