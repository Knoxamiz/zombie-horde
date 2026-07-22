class_name NpcNavigationController
extends RefCounted

## Per-NPC navigation state.
##
## RaceRouteNavigator owns ordered checkpoints. NavigationAgent3D owns the
## actual walkable route to the active checkpoint. This separation prevents a
## stacked map from shortcutting between decks while letting NPCs use the full
## navigable width instead of being pulled to a centerline.

const ROUTE_NAVIGATOR := preload("res://scripts/maps/race_route_navigator.gd")

var _route = ROUTE_NAVIGATOR.new()
var _agent: NavigationAgent3D
var _profile: NpcNavigationProfile
var _lane_seed: float = 0.0
var _goal_position: Vector3 = Vector3.ZERO
var _navigation_half_width: float = 0.0
var _requested_target: Vector3 = Vector3.INF
var _target_refresh_timer: float = 0.0
var _safe_velocity: Vector3 = Vector3.ZERO
var _has_safe_velocity: bool = false
var _last_path_direction: Vector3 = Vector3.FORWARD
var _fallback_active: bool = true
var _agent_direction_accepted: bool = false


func configure(
	agent: NavigationAgent3D,
	profile: NpcNavigationProfile,
	authored_points: PackedVector3Array,
	spawn_position: Vector3,
	goal_position: Vector3,
	random_seed: int,
	navigation_half_width: float
) -> void:
	_agent = agent
	_profile = profile if profile != null else NpcNavigationProfile.new()
	_goal_position = goal_position
	_navigation_half_width = maxf(navigation_half_width, 0.5)
	_route.configure(authored_points, spawn_position, goal_position)
	_requested_target = Vector3.INF
	_target_refresh_timer = 0.0
	_safe_velocity = Vector3.ZERO
	_has_safe_velocity = false
	_last_path_direction = _route.get_forward_direction()
	_fallback_active = true
	_agent_direction_accepted = false

	var lane_rng := RandomNumberGenerator.new()
	lane_rng.seed = random_seed ^ 0x6E6176
	_lane_seed = lane_rng.randf_range(-1.0, 1.0)
	_apply_agent_profile()


func set_agent(agent: NavigationAgent3D) -> void:
	_agent = agent
	_apply_agent_profile()


func update(position: Vector3, delta: float) -> Vector3:
	if not _route.has_route():
		return _direction_to(_goal_position, position, _last_path_direction)

	_route.advance(
		position,
		_profile.checkpoint_reach_radius,
		_navigation_half_width
	)
	_target_refresh_timer = maxf(0.0, _target_refresh_timer - delta)
	# The ordered race route is the movement authority. NavigationAgent3D can
	# refine a route around nearby walkable geometry, but it must never replace
	# the course with a result that points sideways, backwards, or nowhere.
	var course_target: Vector3 = _build_active_target(position)
	var course_direction: Vector3 = _direction_to(
		course_target,
		position,
		_route.get_forward_direction()
	)
	var target: Vector3 = course_target
	_agent_direction_accepted = false
	if _can_query_navigation():
		# The authored course target is already on the active map surface. Do not
		# snap it to NavigationServer's globally nearest point: on stacked maps
		# that can select a lower deck directly below this route segment and make
		# the agent fight the prescribed turn. NavigationAgent3D still supplies
		# local path refinement and avoidance after receiving this route-owned
		# target.
		if _should_refresh_target(target):
			_requested_target = target
			_target_refresh_timer = _profile.target_refresh_interval
			_agent.target_position = target
		var next_path_point: Vector3 = _agent.get_next_path_position()
		var path_direction: Vector3 = _direction_to(next_path_point, position, course_direction)
		var points_along_course: bool = path_direction.dot(course_direction) >= 0.15
		if (
			not _agent.is_navigation_finished()
			and path_direction.length_squared() > 0.001
			and points_along_course
		):
			_last_path_direction = path_direction
			_fallback_active = false
			_agent_direction_accepted = true
			return path_direction

	_fallback_active = true
	_last_path_direction = course_direction
	return _last_path_direction


func submit_preferred_velocity(preferred_velocity: Vector3) -> void:
	if _can_query_navigation():
		_agent.velocity = Vector3(preferred_velocity.x, 0.0, preferred_velocity.z)


func resolve_avoidance(preferred_velocity: Vector3) -> Vector3:
	if not _has_safe_velocity:
		return preferred_velocity
	var desired := Vector3(preferred_velocity.x, 0.0, preferred_velocity.z)
	var safe := Vector3(_safe_velocity.x, 0.0, _safe_velocity.z)
	if desired.length_squared() <= 0.001 or safe.length_squared() <= 0.001:
		return preferred_velocity
	var desired_heading := desired.normalized()
	if safe.dot(desired_heading) <= desired.length() * 0.35:
		return preferred_velocity
	var adjusted := desired.lerp(safe, _profile.avoidance_blend)
	# RVO is a local crowd tool, not a movement authority. It must never reduce
	# a live runner below a meaningful forward speed toward the active course
	# checkpoint, otherwise a dense spawn pile can animate in place forever.
	if adjusted.dot(desired_heading) < desired.length() * 0.65:
		return preferred_velocity
	return adjusted


func accept_safe_velocity(safe_velocity: Vector3) -> void:
	_safe_velocity = Vector3(safe_velocity.x, 0.0, safe_velocity.z)
	_has_safe_velocity = true


func get_progress_ratio() -> float:
	return _route.get_progress_ratio()


func get_route_forward() -> Vector3:
	return _route.get_forward_direction()


func get_checkpoint_target() -> Vector3:
	return _route.get_current_segment_end()


func has_route() -> bool:
	return _route.has_route()


func get_diagnostics() -> Dictionary:
	return {
		"segment_index": _route.get_current_segment_index(),
		"progress": _route.get_progress_ratio(),
		"requested_target": _requested_target,
		"path_direction": _last_path_direction,
		"fallback_active": _fallback_active,
		"agent_direction_accepted": _agent_direction_accepted,
		"navigation_ready": _can_query_navigation(),
		"navigation_half_width": _navigation_half_width,
	}


func _apply_agent_profile() -> void:
	# A spawned CharacterBody can enter its ready callback before the manager
	# supplies map configuration. Apply the profile only once both dependencies
	# exist; configure() will call this again after it assigns the profile.
	if _agent == null or _profile == null:
		return
	_agent.path_desired_distance = _profile.path_desired_distance
	_agent.target_desired_distance = _profile.target_desired_distance
	_agent.avoidance_enabled = true
	_agent.radius = _profile.agent_radius
	_agent.neighbor_distance = _profile.neighbor_distance
	_agent.max_neighbors = _profile.max_neighbors
	_agent.time_horizon_agents = _profile.time_horizon_agents


func _build_active_target(position: Vector3) -> Vector3:
	var route_forward: Vector3 = _route.get_forward_direction()
	var route_side := Vector3(route_forward.z, 0.0, -route_forward.x).normalized()
	var distance_to_goal: float = Vector2(
		position.x - _goal_position.x,
		position.z - _goal_position.z
	).length()
	# A stacked course can pass directly above its finish on an earlier deck.
	# World-space proximity alone would then make a runner abandon the authored
	# turns and aim vertically through the structure. Route completion is the
	# authority; the distance check only refines the final segment's target.
	var approaching_finish: bool = (
		_route.is_on_final_segment()
		and distance_to_goal <= _profile.finish_rejoin_distance
	)
	if approaching_finish:
		var finish_offset: float = _lane_seed * _navigation_half_width * _profile.finish_lane_spread
		return _goal_position + route_side * finish_offset

	# Project the runner's lateral offset onto the active route, then carry that
	# offset ahead along the course. A stable seeded lane preference gives a
	# dense horde room to fan out, but is deliberately blended with the runner's
	# current location so a launch into a wide playable area does not rubber-band
	# it back to the centerline.
	var center: Vector3 = _route.get_center_point()
	var lateral_offset: float = clampf(
		(position - center).dot(route_side),
		-_navigation_half_width,
		_navigation_half_width
	)
	var preferred_lane: float = _lane_seed * _navigation_half_width * _profile.checkpoint_lane_spread
	var carried_offset: float = lerpf(lateral_offset, preferred_lane, 0.22)
	var lookahead: Vector3 = _route.get_target_point(_profile.route_lookahead_distance)
	return lookahead + route_side * carried_offset


func _should_refresh_target(target: Vector3) -> bool:
	return (
		_target_refresh_timer <= 0.0
		or target.distance_squared_to(_requested_target) >= _profile.target_refresh_distance * _profile.target_refresh_distance
	)


func _can_query_navigation() -> bool:
	if _agent == null:
		return false
	var navigation_map: RID = _agent.get_navigation_map()
	return navigation_map.is_valid() and NavigationServer3D.map_get_iteration_id(navigation_map) > 0


func _direction_to(target: Vector3, position: Vector3, fallback: Vector3) -> Vector3:
	var direction := target - position
	direction.y = 0.0
	if direction.length_squared() <= 0.001:
		return fallback.normalized()
	return direction.normalized()
