class_name MapV2Course
extends Resource

const PRIMITIVE_SCRIPT := preload("res://scripts/maps/v2/map_v2_primitive.gd")

@export var course_id: String = ""
@export var primitives: Array[Resource] = []
@export var spawn_position: Vector3 = Vector3.ZERO
@export var finish_position: Vector3 = Vector3(0.0, 0.0, 20.0)
@export var oob_margin: float = 2.0


func validate() -> PackedStringArray:
	var failures := PackedStringArray()
	if course_id.strip_edges().is_empty():
		failures.append("course_id is empty")
	if primitives.is_empty():
		failures.append("%s has no primitives" % course_id)
	var seen_ids: Dictionary = {}
	for primitive in primitives:
		if primitive == null:
			failures.append("%s contains a null primitive" % course_id)
			continue
		failures.append_array(primitive.validate())
		if seen_ids.has(primitive.primitive_id):
			failures.append("duplicate primitive_id: %s" % primitive.primitive_id)
		seen_ids[primitive.primitive_id] = true
	if oob_margin < 0.0:
		failures.append("%s oob_margin cannot be negative" % course_id)
	if not has_surface_at(spawn_position.x, spawn_position.z):
		failures.append("%s spawn_position is not on a playable surface" % course_id)
	if not has_surface_at(finish_position.x, finish_position.z):
		failures.append("%s finish_position is not on a playable surface" % course_id)
	var route: PackedVector3Array = get_route_points()
	if route.size() < 2:
		failures.append("%s cannot derive a usable route" % course_id)
	elif not is_route_surface_continuous(route):
		failures.append("%s route crosses a non-playable surface" % course_id)
	return failures


func has_surface_at(x: float, z: float) -> bool:
	return surface_height_at(x, z, -INF) > -INF


func surface_height_at(x: float, z: float, fallback: float = 0.0) -> float:
	var resolved_height: float = -INF
	for primitive in primitives:
		if primitive == null or primitive.kind not in [
			PRIMITIVE_SCRIPT.Kind.DECK,
			PRIMITIVE_SCRIPT.Kind.RAMP,
		]:
			continue
		if not _contains_xz(primitive, x, z):
			continue
		var top_y: float = primitive.origin.y
		if primitive.kind == PRIMITIVE_SCRIPT.Kind.RAMP:
			var progress: float = clampf((z - primitive.origin.z) / primitive.length, 0.0, 1.0)
			top_y += primitive.height_delta * progress
		resolved_height = maxf(resolved_height, top_y)
	return resolved_height if resolved_height > -INF else fallback


func sample_surface_position(
	rng: RandomNumberGenerator,
	edge_inset: float = 0.5,
	height_offset: float = 0.0
) -> Vector3:
	if rng == null or edge_inset < 0.0:
		return Vector3(INF, INF, INF)
	var candidates: Array[Resource] = []
	var cumulative_areas: Array[float] = []
	var total_area: float = 0.0
	for primitive in primitives:
		if primitive == null or primitive.kind not in [
			PRIMITIVE_SCRIPT.Kind.DECK,
			PRIMITIVE_SCRIPT.Kind.RAMP,
		]:
			continue
		var usable_width: float = primitive.width - edge_inset * 2.0
		var usable_length: float = primitive.length - edge_inset * 2.0
		if usable_width <= 0.0 or usable_length <= 0.0:
			continue
		total_area += usable_width * usable_length
		candidates.append(primitive)
		cumulative_areas.append(total_area)
	if candidates.is_empty():
		return Vector3(INF, INF, INF)

	var selected_index: int = 0
	var area_roll: float = rng.randf_range(0.0, total_area)
	while selected_index < cumulative_areas.size() - 1:
		if area_roll <= cumulative_areas[selected_index]:
			break
		selected_index += 1
	var selected: Resource = candidates[selected_index]
	var half_usable_width: float = selected.width * 0.5 - edge_inset
	var x: float = rng.randf_range(
		selected.origin.x - half_usable_width,
		selected.origin.x + half_usable_width
	)
	var z: float = rng.randf_range(
		selected.origin.z + edge_inset,
		selected.origin.z + selected.length - edge_inset
	)
	return Vector3(x, surface_height_at(x, z) + height_offset, z)


func get_route_points(height_offset: float = 0.05) -> PackedVector3Array:
	var route := PackedVector3Array()
	for primitive in primitives:
		if primitive == null or primitive.kind not in [
			PRIMITIVE_SCRIPT.Kind.DECK,
			PRIMITIVE_SCRIPT.Kind.RAMP,
		]:
			continue
		var start := Vector3(
			primitive.origin.x,
			surface_height_at(primitive.origin.x, primitive.origin.z) + height_offset,
			primitive.origin.z
		)
		var end := Vector3(
			primitive.origin.x,
			surface_height_at(
				primitive.origin.x,
				primitive.origin.z + primitive.length
			) + height_offset,
			primitive.origin.z + primitive.length
		)
		_append_unique_route_point(route, start)
		_append_unique_route_point(route, end)
	return route


func is_route_surface_continuous(
	route: PackedVector3Array = get_route_points(),
	sample_spacing: float = 0.5
) -> bool:
	if route.size() < 2 or sample_spacing <= 0.0:
		return false
	for route_index in range(1, route.size()):
		var start: Vector3 = route[route_index - 1]
		var end: Vector3 = route[route_index]
		var sample_count: int = maxi(1, ceili(start.distance_to(end) / sample_spacing))
		for sample_index in range(sample_count + 1):
			var progress: float = float(sample_index) / float(sample_count)
			var sample: Vector3 = start.lerp(end, progress)
			if not has_surface_at(sample.x, sample.z):
				return false
	return true


func get_playable_bounds() -> AABB:
	var minimum := Vector3(INF, INF, INF)
	var maximum := Vector3(-INF, -INF, -INF)
	for primitive in primitives:
		if primitive == null or primitive.kind not in [
			PRIMITIVE_SCRIPT.Kind.DECK,
			PRIMITIVE_SCRIPT.Kind.RAMP,
		]:
			continue
		var half_width: float = primitive.width * 0.5
		var start_y: float = primitive.origin.y
		var end_y: float = start_y + (
			primitive.height_delta if primitive.kind == PRIMITIVE_SCRIPT.Kind.RAMP else 0.0
		)
		minimum.x = minf(minimum.x, primitive.origin.x - half_width)
		maximum.x = maxf(maximum.x, primitive.origin.x + half_width)
		minimum.y = minf(minimum.y, minf(start_y, end_y))
		maximum.y = maxf(maximum.y, maxf(start_y, end_y))
		minimum.z = minf(minimum.z, primitive.origin.z)
		maximum.z = maxf(maximum.z, primitive.origin.z + primitive.length)
	if minimum.x == INF:
		return AABB()
	return AABB(minimum, maximum - minimum)


func get_oob_bounds() -> AABB:
	var playable: AABB = get_playable_bounds()
	if playable.size == Vector3.ZERO:
		return playable
	return AABB(
		playable.position - Vector3(oob_margin, 0.0, oob_margin),
		playable.size + Vector3(oob_margin * 2.0, 0.0, oob_margin * 2.0)
	)


func _contains_xz(primitive: Resource, x: float, z: float) -> bool:
	var half_width: float = primitive.width * 0.5
	return (
		x >= primitive.origin.x - half_width
		and x <= primitive.origin.x + half_width
		and z >= primitive.origin.z
		and z <= primitive.origin.z + primitive.length
	)


func _append_unique_route_point(route: PackedVector3Array, point: Vector3) -> void:
	if route.is_empty() or not route[-1].is_equal_approx(point):
		route.append(point)
