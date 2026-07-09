class_name AIMapRouteLayout
extends RefCounted

const MapSegmentDefinitionScript := preload("res://scripts/maps/map_segment_definition.gd")

## Shared spawn/goal/route geometry for AI map blueprints and builders.
## Route segments assemble forward from Z=0 to Z=total_route_length.

const SPAWN_BACK_OFFSET: float = 4.0
const OOB_Z_MARGIN: float = 8.0
const ZOMBIE_SPAWN_CLEARANCE: float = 0.8
const MINIGUN_GOAL_OFFSET: float = 4.0
const POSITION_TOLERANCE: float = 0.05


static func compute_layout(blueprint) -> Dictionary:
	if blueprint == null:
		return {}

	var total_length: float = blueprint.get_total_route_length()
	var finish_length: float = _finish_segment_length(blueprint)
	var spawn_z: float = -SPAWN_BACK_OFFSET
	var goal_z: float = total_length - finish_length * 0.5
	var route_min_z: float = 0.0
	var route_max_z: float = total_length
	var spawn_y: float = blueprint.deck_y + ZOMBIE_SPAWN_CLEARANCE
	var route_max_half: float = blueprint.get_route_max_half_width()

	return {
		"total_route_length": total_length,
		"finish_segment_length": finish_length,
		"spawn_z": spawn_z,
		"goal_z": goal_z,
		"route_min_z": route_min_z,
		"route_max_z": route_max_z,
		"spawn_y": spawn_y,
		"deck_y": blueprint.deck_y,
		"route_max_half_width": route_max_half,
		"out_of_bounds_min_z": spawn_z - OOB_Z_MARGIN,
		"out_of_bounds_max_z": goal_z + OOB_Z_MARGIN,
		"out_of_bounds_half_width": maxf(
			blueprint.lane_half_width + 6.0,
			maxf(route_max_half + 2.0, blueprint.route_half_width + 2.0)
		),
		"out_of_bounds_min_y": blueprint.get_recommended_oob_min_y(),
	}


static func apply_to_definition(definition: RaceMapDefinition, blueprint) -> void:
	if definition == null or blueprint == null:
		return

	var layout: Dictionary = compute_layout(blueprint)
	if layout.is_empty():
		return

	var spawn_z: float = float(layout.get("spawn_z", 0.0))
	var goal_z: float = float(layout.get("goal_z", 0.0))
	var spawn_y: float = float(layout.get("spawn_y", 0.0))
	var deck_y: float = float(layout.get("deck_y", 0.0))

	definition.display_name = blueprint.display_name
	definition.premium_only = true
	definition.deck_y = deck_y
	definition.spawn_origin = Vector3(0.0, spawn_y, spawn_z)
	definition.spawn_area_size = Vector2(blueprint.route_half_width * 2.0, 4.0)
	definition.goal_position = Vector3(0.0, spawn_y, goal_z)
	definition.base_position = Vector3(0.0, deck_y, goal_z)
	definition.minigun_position = Vector3(0.0, deck_y, goal_z - MINIGUN_GOAL_OFFSET)
	definition.lane_half_width = blueprint.lane_half_width
	definition.out_of_bounds_half_width = float(layout.get("out_of_bounds_half_width", blueprint.lane_half_width + 6.0))
	definition.out_of_bounds_min_z = float(layout.get("out_of_bounds_min_z", spawn_z - OOB_Z_MARGIN))
	definition.out_of_bounds_max_z = float(layout.get("out_of_bounds_max_z", goal_z + OOB_Z_MARGIN))
	definition.out_of_bounds_min_y = float(layout.get("out_of_bounds_min_y", deck_y - 3.0))
	definition.hazard_placement_half_width = blueprint.lane_half_width
	definition.hazard_placement_min_z = spawn_z + 4.0
	definition.hazard_placement_max_z = goal_z - 4.0
	definition.obstacle_half_width = blueprint.lane_half_width
	definition.obstacle_min_z = spawn_z + 4.0
	definition.obstacle_max_z = goal_z - 4.0
	definition.obstacle_lane_count = 1
	definition.powerup_placement_half_width = blueprint.lane_half_width - 0.5
	definition.powerup_placement_min_z = spawn_z + 8.0
	definition.powerup_placement_max_z = goal_z - 4.0
	definition.defender_placement_half_width = blueprint.lane_half_width - 0.5
	definition.defender_placement_min_z = spawn_z + 8.0
	definition.defender_placement_max_z = goal_z - 4.0


static func definition_matches_layout(definition: RaceMapDefinition, blueprint) -> Array[String]:
	var errors: Array[String] = []
	if definition == null or blueprint == null:
		errors.append("definition or blueprint is null")
		return errors

	var layout: Dictionary = compute_layout(blueprint)
	if layout.is_empty():
		errors.append("route layout could not be computed")
		return errors

	_compare_float(errors, "spawn_origin.z", definition.spawn_origin.z, float(layout.get("spawn_z", 0.0)))
	_compare_float(errors, "goal_position.z", definition.goal_position.z, float(layout.get("goal_z", 0.0)))
	_compare_float(errors, "spawn_origin.y", definition.spawn_origin.y, float(layout.get("spawn_y", 0.0)))
	_compare_float(errors, "deck_y", definition.deck_y, float(layout.get("deck_y", 0.0)))
	_compare_float(
		errors,
		"out_of_bounds_min_z",
		definition.out_of_bounds_min_z,
		float(layout.get("out_of_bounds_min_z", 0.0))
	)
	_compare_float(
		errors,
		"out_of_bounds_max_z",
		definition.out_of_bounds_max_z,
		float(layout.get("out_of_bounds_max_z", 0.0))
	)
	_compare_float(
		errors,
		"out_of_bounds_half_width",
		definition.out_of_bounds_half_width,
		float(layout.get("out_of_bounds_half_width", 0.0))
	)
	_compare_float(
		errors,
		"out_of_bounds_min_y",
		definition.out_of_bounds_min_y,
		float(layout.get("out_of_bounds_min_y", 0.0))
	)
	_compare_float(errors, "base_position.z", definition.base_position.z, float(layout.get("goal_z", 0.0)))
	_compare_float(
		errors,
		"minigun_position.z",
		definition.minigun_position.z,
		float(layout.get("goal_z", 0.0)) - MINIGUN_GOAL_OFFSET
	)

	var definition_span: float = definition.goal_position.z - definition.spawn_origin.z
	var expected_span: float = float(layout.get("goal_z", 0.0)) - float(layout.get("spawn_z", 0.0))
	if absf(definition_span - expected_span) > 0.25:
		errors.append(
			"definition Z span %.2f does not match route layout span %.2f."
			% [definition_span, expected_span]
		)

	if definition.out_of_bounds_min_z > float(layout.get("route_min_z", 0.0)) - 0.01:
		errors.append("out_of_bounds_min_z must cover generated route start (Z=0).")
	if definition.out_of_bounds_max_z < float(layout.get("route_max_z", 0.0)) - 0.01:
		errors.append("out_of_bounds_max_z must cover generated route end.")

	if not _camera_framing_valid(definition):
		errors.append("camera framing position is invalid for generated route.")

	return errors


static func _camera_framing_valid(definition: RaceMapDefinition) -> bool:
	if definition == null:
		return false
	if definition.spawn_origin.z >= definition.goal_position.z:
		return false
	if abs(definition.goal_position.z - definition.spawn_origin.z) <= 1.0:
		return false
	if definition.lane_half_width <= 0.0:
		return false
	return true


static func collect_safe_floor_z_bounds(root: Node3D) -> Dictionary:
	var bounds := {"min_z": INF, "max_z": -INF, "count": 0}
	if root == null:
		return bounds

	var safe_floor: Node = root.get_node_or_null("GameplayLayer/SafeFloor")
	if safe_floor == null:
		return bounds

	for child in safe_floor.get_children():
		if child is Node3D:
			_accumulate_plate_bounds(child as Node3D, bounds)
	return bounds


static func _finish_segment_length(blueprint) -> float:
	if blueprint.segment_sequence.is_empty():
		return 8.0
	var finish_segment: Dictionary = MapSegmentDefinitionScript.get_segment(
		str(blueprint.segment_sequence.back())
	)
	return float(finish_segment.get("length", 8.0))


static func _accumulate_plate_bounds(plate: Node3D, bounds: Dictionary) -> void:
	for child in plate.get_children():
		if child is CollisionShape3D:
			var shape: CollisionShape3D = child as CollisionShape3D
			if shape.shape == null:
				continue
			var local_half_z: float = _shape_half_extent_z(shape.shape)
			var map_z: float = _node_map_z(plate)
			bounds["min_z"] = minf(bounds["min_z"], map_z - local_half_z)
			bounds["max_z"] = maxf(bounds["max_z"], map_z + local_half_z)
			bounds["count"] = int(bounds["count"]) + 1


static func _node_map_z(node: Node3D) -> float:
	var map_z: float = 0.0
	var current: Node = node
	while current is Node3D:
		map_z += (current as Node3D).position.z
		current = current.get_parent()
	return map_z


static func _shape_half_extent_z(shape: Shape3D) -> float:
	if shape is BoxShape3D:
		return (shape as BoxShape3D).size.z * 0.5
	if shape is ConcavePolygonShape3D:
		return 4.0
	return 4.0


static func _compare_float(errors: Array[String], label: String, actual: float, expected: float) -> void:
	if absf(actual - expected) > POSITION_TOLERANCE:
		errors.append("%s expected %.2f but got %.2f." % [label, expected, actual])
