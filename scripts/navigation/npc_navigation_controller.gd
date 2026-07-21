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
var _requested_target: Vector3 = Vector3.INF
var _target_refresh_timer: float = 0.0
var _safe_velocity: Vector3 = Vector3.ZERO
var _has_safe_velocity: bool = false
var _last_path_direction: Vector3 = Vector3.FORWARD
var _fallback_active: bool = true


func configure(
	agent: NavigationAgent3D,
	profile: NpcNavigationProfile,
	authored_points: PackedVector3Array,
	spawn_position: Vector3,
	goal_position: Vector3,
	random_seed: int
) -> void:
	_agent = agent
	_profile = profile if profile != null else NpcNavigationProfile.new()
	_goal_position = goal_position
	_route.configure(authored_points, spawn_position, goal_position)
	_requested_target = Vector3.INF
	_target_refresh_timer = 0.0
	_safe_velocity = Vector3.ZERO
	_has_safe_velocity = false
	_last_path_direction = _route.get_forward_direction()
	_fallback_active = true

	var lane_rng := RandomNumberGenerator.new()
	lane_rng.seed = random_seed ^ 0x6E6176
	_lane_seed = lane_rng.randf_range(-1.0, 1.0)
	_apply_agent_profile()


func set_agent(agent: NavigationAgent3D) -> void:
	_agent = agent
	_apply_agent_profile()


func update(position: Vector3, lane_half_width: float, delta: float) -> Vector3:
	if not _route.has_route():
		return _direction_to(_goal_position, position, _last_path_direction)

	_route.advance(position, _profile.checkpoint_reach_radius)
	_target_refresh_timer = maxf(0.0, _target_refresh_timer - delta)
	var target: Vector3 = _build_active_target(lane_half_width)
	if _can_query_navigation():
		var navigation_map: RID = _agent.get_navigation_map()
		target = NavigationServer3D.map_get_closest_point(navigation_map, target)
		if _should_refresh_target(target):
			_requested_target = target
			_target_refresh_timer = _profile.target_refresh_interval
			_agent.target_position = target
		var next_path_point: Vector3 = _agent.get_next_path_position()
		var path_direction: Vector3 = _direction_to(next_path_point, position, _last_path_direction)
		if not _agent.is_navigation_finished() and path_direction.length_squared() > 0.001:
			_last_path_direction = path_direction
			_fallback_active = false
			return path_direction

	_fallback_active = true
	_last_path_direction = _direction_to(target, position, _last_path_direction)
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
	if safe.dot(desired.normalized()) <= desired.length() * 0.10:
		return preferred_velocity
	return preferred_velocity.lerp(_safe_velocity, _profile.avoidance_blend)


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
		"navigation_ready": _can_query_navigation(),
	}


func _apply_agent_profile() -> void:
	if _agent == null:
		return
	_agent.path_desired_distance = _profile.path_desired_distance
	_agent.target_desired_distance = _profile.target_desired_distance
	_agent.avoidance_enabled = true
	_agent.radius = _profile.agent_radius
	_agent.neighbor_distance = _profile.neighbor_distance
	_agent.max_neighbors = _profile.max_neighbors
	_agent.time_horizon_agents = _profile.time_horizon_agents


func _build_active_target(lane_half_width: float) -> Vector3:
	var route_forward: Vector3 = _route.get_forward_direction()
	var route_side := Vector3(route_forward.z, 0.0, -route_forward.x).normalized()
	var spread: float = _profile.finish_lane_spread if _route.get_progress_ratio() >= 0.999 else _profile.checkpoint_lane_spread
	var offset: float = _lane_seed * maxf(lane_half_width, 0.5) * spread
	var checkpoint: Vector3 = _goal_position if _route.get_progress_ratio() >= 0.999 else _route.get_current_segment_end()
	return checkpoint + route_side * offset


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
