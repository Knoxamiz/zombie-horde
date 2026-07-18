extends SceneTree

const RACE_STEERING := preload("res://scripts/zombies/race_steering.gd")

var _failures: PackedStringArray = PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_lane_offsets_do_not_snap_to_center()
	_test_edge_recovery_keeps_forward_progress()
	_test_avoidance_cannot_reverse_a_runner()
	_test_visual_facing_matches_forward_velocity()
	_finish()


func _test_lane_offsets_do_not_snap_to_center() -> void:
	var velocity := RACE_STEERING.calculate_desired_velocity(
		Vector3(4.0, 0.0, 0.0), Vector3.ZERO, Vector3(0.0, 0.0, 1.0), Vector3(0.0, 0.0, 4.0),
		3.0, 6.1, 0.0, 0.0, 1.15, Vector3.ZERO, 4.0
	)
	if velocity.x >= -0.05:
		_fail("A displaced runner should recover toward its own lane, not the centerline")
	if velocity.z <= 2.5:
		_fail("Lane recovery must preserve strong forward movement")


func _test_edge_recovery_keeps_forward_progress() -> void:
	var velocity := RACE_STEERING.calculate_desired_velocity(
		Vector3(10.0, 0.0, 0.0), Vector3.ZERO, Vector3(0.0, 0.0, 1.0), Vector3(0.0, 0.0, 4.0),
		0.0, 6.1, 0.0, 0.0, 1.15, Vector3.ZERO, 4.0
	)
	if velocity.x >= -0.2:
		_fail("A runner beyond the lane should steer inward")
	if velocity.z <= 2.0:
		_fail("Edge recovery must arc forward instead of rubber-banding sideways")


func _test_avoidance_cannot_reverse_a_runner() -> void:
	var resolved := RACE_STEERING.preserve_forward_avoidance(Vector3(0.0, 0.0, 4.0), Vector3(0.0, 0.0, -2.0))
	if resolved.z <= 3.5:
		_fail("Local avoidance must not reverse route progress")


func _test_visual_facing_matches_forward_velocity() -> void:
	var forward_yaw: float = RACE_STEERING.visual_yaw_for_velocity(Vector3(0.0, 0.0, 4.0))
	if absf(forward_yaw) > 0.001:
		_fail("A +Z runner must keep the imported model facing forward")


func _fail(message: String) -> void:
	push_error(message)
	_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: Race steering contract")
		quit(0)
		return
	for failure in _failures:
		print("FAIL: %s" % failure)
	quit(1)
