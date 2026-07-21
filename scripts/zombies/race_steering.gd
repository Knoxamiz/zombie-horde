class_name RaceSteering
extends RefCounted

## Shared local steering for every race map.
##
## NavigationAgent3D supplies a valid path direction. This layer only adds
## small individual drift and crowd separation; it never pulls a runner back
## toward a route centerline.

const MAX_LATERAL_STEERING: float = 0.48


static func calculate_desired_velocity(
	path_direction: Vector3,
	drift_direction: float,
	drift_strength: float,
	crowd_separation: Vector3,
	speed: float
) -> Vector3:
	var forward := Vector3(path_direction.x, 0.0, path_direction.z).normalized()
	if forward.length_squared() <= 0.001 or speed <= 0.0:
		return Vector3.ZERO
	var side := Vector3(forward.z, 0.0, -forward.x)
	var crowd_lateral: float = clampf(crowd_separation.dot(side), -0.25, 0.25)
	var lateral_steering: float = clampf(
		drift_direction * drift_strength + crowd_lateral,
		-MAX_LATERAL_STEERING,
		MAX_LATERAL_STEERING
	)
	return (forward + side * lateral_steering).normalized() * speed


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
