extends SceneTree

const RACE_STEERING := preload("res://scripts/zombies/race_steering.gd")

var _failures: PackedStringArray = PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_path_direction_is_movement_authority()
	_test_local_drift_preserves_path_progress()
	_test_avoidance_cannot_reverse_a_runner()
	_test_visual_facing_matches_forward_velocity()
	_finish()


func _test_path_direction_is_movement_authority() -> void:
	var velocity := RACE_STEERING.calculate_desired_velocity(
		Vector3(1.0, 0.0, 0.0), 0.0, 0.0, Vector3.ZERO, 4.0
	)
	if velocity.x <= 3.5 or absf(velocity.z) > 0.05:
		_fail("Local steering must follow the navigation path direction")


func _test_local_drift_preserves_path_progress() -> void:
	var velocity := RACE_STEERING.calculate_desired_velocity(
		Vector3(0.0, 0.0, 1.0), 1.0, 0.55, Vector3.ZERO, 4.0
	)
	if velocity.x <= 0.2:
		_fail("Local drift should create a small natural lateral variation")
	if velocity.z <= 3.5:
		_fail("Local drift must preserve forward path progress")


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
