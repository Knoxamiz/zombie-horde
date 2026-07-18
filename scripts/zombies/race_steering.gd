class_name RaceSteering
extends RefCounted

## Shared steering for every race map. The authored route supplies forward
## progress, while lane recovery remains gradual so hits feel physical instead
## of snapping a runner back to the centerline.

const LANE_MARGIN: float = 0.65
const MAX_LATERAL_STEERING: float = 0.85


static func calculate_desired_velocity(
	position: Vector3,
	route_center: Vector3,
	route_forward: Vector3,
	lookahead_point: Vector3,
	lane_offset: float,
	lane_half_width: float,
	drift_direction: float,
	drift_strength: float,
	edge_recovery_strength: float,
	crowd_separation: Vector3,
	speed: float
) -> Vector3:
	var forward := Vector3(route_forward.x, 0.0, route_forward.z).normalized()
	if forward.length_squared() <= 0.001 or speed <= 0.0:
		return Vector3.ZERO
	var side := Vector3(forward.z, 0.0, -forward.x)
	var usable_half_width: float = maxf(lane_half_width - LANE_MARGIN, 0.5)
	var desired_lane: float = clampf(lane_offset, -usable_half_width, usable_half_width)
	var current_lane: float = (position - route_center).dot(side)

	# A lane offset is personality, not an error. Correct toward it slowly so a
	# runner that has been launched continues its arc while still progressing.
	var lane_error: float = desired_lane - current_lane
	var soft_recovery: float = clampf(
		lane_error / maxf(usable_half_width * 3.0, 2.0),
		-0.35,
		0.35
	)
	var edge_recovery: float = 0.0
	var edge_overage: float = absf(current_lane) - usable_half_width
	if edge_overage > 0.0:
		var edge_ratio: float = clampf(edge_overage / maxf(lane_half_width * 0.35, 1.0), 0.0, 1.0)
		edge_recovery = -signf(current_lane) * edge_ratio * maxf(edge_recovery_strength, 0.0)

	var lookahead_offset := lookahead_point - position
	lookahead_offset.y = 0.0
	var lookahead_heading: Vector3 = forward
	if lookahead_offset.length_squared() > 0.001:
		lookahead_heading = lookahead_offset.normalized()
	# Preserve route heading as the primary direction. The lookahead blend makes
	# authored corners smooth without allowing a large lateral hit to hijack it.
	var course_heading: Vector3 = (forward * 0.7 + lookahead_heading * 0.3).normalized()
	var crowd_lateral: float = clampf(crowd_separation.dot(side), -0.25, 0.25)
	var lateral_steering: float = clampf(
		drift_direction * drift_strength + soft_recovery + edge_recovery + crowd_lateral,
		-MAX_LATERAL_STEERING,
		MAX_LATERAL_STEERING
	)
	return (course_heading + side * lateral_steering).normalized() * speed


static func preserve_forward_avoidance(desired_velocity: Vector3, safe_velocity: Vector3) -> Vector3:
	var desired := Vector3(desired_velocity.x, 0.0, desired_velocity.z)
	var safe := Vector3(safe_velocity.x, 0.0, safe_velocity.z)
	if desired.length_squared() <= 0.001 or safe.length_squared() <= 0.001:
		return desired_velocity
	var desired_heading := desired.normalized()
	var safe_forward_speed: float = safe.dot(desired_heading)
	if safe_forward_speed <= desired.length() * 0.18:
		return desired_velocity
	return desired_velocity.lerp(safe_velocity, 0.6)


static func visual_yaw_for_velocity(velocity: Vector3) -> float:
	# The imported zombie variants face local +Z. Keep presentation aligned with
	# their actual steering direction without rotating gameplay coordinates.
	return atan2(velocity.x, velocity.z)
