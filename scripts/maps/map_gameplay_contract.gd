class_name MapGameplayContract
extends RefCounted

## Validates the gameplay hand-off from map data to runtime systems.
##
## Every shipped map has one course definition. RaceRouteNavigator sequences
## it, RaceNavigationWorld builds its navigation path from it, and every
## route-aware spawner receives the same points through RaceMapController.
## This contract catches bad authoring before a map can be promoted.

const MIN_HORIZONTAL_SEGMENT_LENGTH := 0.5


static func validate_definition(definition: RaceMapDefinition, map_id: String) -> Array[String]:
	var failures: Array[String] = []
	if definition == null:
		failures.append("[%s] gameplay contract is missing a map definition" % map_id)
		return failures

	var route: PackedVector3Array = definition.get_effective_race_path()
	if route.size() < 2:
		failures.append("[%s] effective race route must have at least two points" % map_id)
		return failures

	if definition.navigation_profile == null:
		failures.append("[%s] navigation_profile is required for shipped maps" % map_id)
	else:
		_validate_navigation_profile(definition, route, map_id, failures)

	_validate_route_shape(definition, route, map_id, failures)
	_validate_hazard_capacity(definition, map_id, failures)
	return failures


static func _validate_route_shape(
	definition: RaceMapDefinition,
	route: PackedVector3Array,
	map_id: String,
	failures: Array[String]
) -> void:
	var horizontal_start_to_goal := Vector2(
		definition.goal_position.x - definition.spawn_origin.x,
		definition.goal_position.z - definition.spawn_origin.z
	).length()
	# A course that changes horizontal direction must be authored as checkpoints.
	# Direct spawn-to-goal remains valid for intentionally straight maps, even
	# when that straight road changes elevation.
	if definition.race_path_points.size() < 2 and absf(definition.goal_position.x - definition.spawn_origin.x) > 0.5:
		failures.append("[%s] turning course requires authored race_path_points" % map_id)
	if horizontal_start_to_goal <= MIN_HORIZONTAL_SEGMENT_LENGTH and definition.race_path_points.size() < 2:
		failures.append("[%s] straight fallback route has no horizontal travel" % map_id)

	for index in range(route.size() - 1):
		var start: Vector3 = route[index]
		var end: Vector3 = route[index + 1]
		var horizontal_length := Vector2(end.x - start.x, end.z - start.z).length()
		if horizontal_length < MIN_HORIZONTAL_SEGMENT_LENGTH:
			failures.append("[%s] route segment %d is vertical or too short for NPC movement" % [map_id, index])


static func _validate_navigation_profile(
	definition: RaceMapDefinition,
	route: PackedVector3Array,
	map_id: String,
	failures: Array[String]
) -> void:
	var profile: NpcNavigationProfile = definition.navigation_profile
	if profile.agent_radius <= 0.0:
		failures.append("[%s] navigation agent_radius must be positive" % map_id)
	if definition.resolve_npc_navigation_half_width() < profile.agent_radius:
		failures.append("[%s] navigation width is narrower than the agent radius" % map_id)
	var shortest_segment: float = INF
	for index in range(route.size() - 1):
		var start: Vector3 = route[index]
		var end: Vector3 = route[index + 1]
		var horizontal_length := Vector2(end.x - start.x, end.z - start.z).length()
		if horizontal_length >= MIN_HORIZONTAL_SEGMENT_LENGTH:
			shortest_segment = minf(shortest_segment, horizontal_length)
	if shortest_segment < INF and profile.route_lookahead_distance >= shortest_segment:
		failures.append("[%s] route_lookahead_distance must be shorter than every authored segment" % map_id)


static func _validate_hazard_capacity(
	definition: RaceMapDefinition,
	map_id: String,
	failures: Array[String]
) -> void:
	var lane_count: int = definition.map_profile_obstacle_lane_count
	if lane_count <= 0:
		lane_count = definition.obstacle_lane_count
	var guaranteed_open_lanes: int = definition.map_guaranteed_open_lanes
	if guaranteed_open_lanes <= 0:
		guaranteed_open_lanes = 1
	var max_obstacles: int = definition.map_max_obstacles_per_segment
	if max_obstacles <= 0:
		max_obstacles = 2

	if lane_count < 1:
		failures.append("[%s] obstacle lane count must be at least one" % map_id)
		return
	if guaranteed_open_lanes > lane_count:
		failures.append("[%s] guaranteed open lanes exceed obstacle lane count" % map_id)
		return
	if max_obstacles > lane_count - guaranteed_open_lanes:
		failures.append("[%s] obstacle budget can seal every route lane" % map_id)
