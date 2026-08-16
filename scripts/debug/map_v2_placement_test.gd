extends SceneTree

const COURSE := preload("res://resources/maps/v2_graybox_course.tres")

const SAMPLE_COUNT := 500
const EDGE_INSET := 0.75
const HEIGHT_OFFSET := 0.4

var _failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var first_rng := RandomNumberGenerator.new()
	var second_rng := RandomNumberGenerator.new()
	first_rng.seed = 4271
	second_rng.seed = 4271
	for sample_index in SAMPLE_COUNT:
		var position: Vector3 = COURSE.sample_surface_position(
			first_rng,
			EDGE_INSET,
			HEIGHT_OFFSET
		)
		var repeated_position: Vector3 = COURSE.sample_surface_position(
			second_rng,
			EDGE_INSET,
			HEIGHT_OFFSET
		)
		if not position.is_equal_approx(repeated_position):
			_fail("Placement sampling is not deterministic at sample %d" % sample_index)
			break
		if not position.is_finite():
			_fail("Placement sampling failed at sample %d" % sample_index)
			continue
		if not COURSE.has_surface_at(position.x, position.z):
			_fail("Placement sample %d is not on a course surface" % sample_index)
			continue
		var expected_y: float = COURSE.surface_height_at(position.x, position.z) + HEIGHT_OFFSET
		if absf(position.y - expected_y) > 0.001:
			_fail("Placement sample %d is floating above or below its surface" % sample_index)
		if position.z > 14.0 and position.z < 18.0 and absf(position.x) > 1.5:
			_fail("Placement sample %d landed inside the authored gap" % sample_index)
	_finish()


func _fail(message: String) -> void:
	_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("MAP_V2_PLACEMENT_TEST: PASSED (%d samples)" % SAMPLE_COUNT)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("MAP_V2_PLACEMENT_TEST: FAILED (%d failures)" % _failures.size())
	quit(1)
