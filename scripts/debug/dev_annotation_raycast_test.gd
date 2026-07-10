extends SceneTree

## Headless unit tests for dev annotation spray placement helpers.
##
## Usage:
##   godot --headless --path . -s res://scripts/debug/dev_annotation_raycast_test.gd

const PASS := 0
const FAIL := 1
const PainterScript := preload("res://scripts/debug/dev_annotation_painter.gd")

var _failures: PackedStringArray = PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Dev annotation raycast test ===")
	_test_plane_intersection_hits()
	_test_plane_intersection_rejects_behind_camera()
	_test_plane_intersection_rejects_parallel()
	_test_unique_heights()
	_finish()


func _test_plane_intersection_hits() -> void:
	var origin := Vector3(0.0, 5.0, 0.0)
	var direction := Vector3(0.0, -1.0, 0.0).normalized()
	var hit: Variant = PainterScript.intersect_ray_with_plane_y(origin, direction, 0.8)
	if hit is not Vector3:
		_fail("expected plane hit")
		return
	var position: Vector3 = hit as Vector3
	if not is_equal_approx(position.y, 0.8):
		_fail("plane hit y wrong: %s" % position.y)


func _test_plane_intersection_rejects_behind_camera() -> void:
	var origin := Vector3(0.0, 1.0, 0.0)
	var direction := Vector3(0.0, 1.0, 0.0).normalized()
	var hit: Variant = PainterScript.intersect_ray_with_plane_y(origin, direction, 0.8)
	if hit != null:
		_fail("plane hit should reject rays pointing away from plane")


func _test_plane_intersection_rejects_parallel() -> void:
	var origin := Vector3(0.0, 2.0, 0.0)
	var direction := Vector3(1.0, 0.0, 0.0).normalized()
	var hit: Variant = PainterScript.intersect_ray_with_plane_y(origin, direction, 0.8)
	if hit != null:
		_fail("parallel ray should not hit horizontal plane")


func _test_unique_heights() -> void:
	var heights: Array[float] = []
	PainterScript._add_unique_height(heights, 0.8)
	PainterScript._add_unique_height(heights, 0.8)
	PainterScript._add_unique_height(heights, 1.0)
	if heights.size() != 2:
		_fail("unique height helper kept duplicates")


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("SUITE RESULT: PASSED")
		quit(PASS)
	else:
		print("SUITE RESULT: FAILED")
		for failure in _failures:
			print("FAIL: %s" % failure)
		quit(FAIL)
