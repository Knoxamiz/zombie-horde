extends SceneTree

const ProfilerScript: Script = preload("res://scripts/debug/performance_stress_profiler.gd")
const PASS := 0
const FAIL := 1

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run_all")


func _run_all() -> void:
	print("=== Performance stress profiler test ===")
	_test_profiler_sampling_and_report()

	if _failures.is_empty():
		print("SUITE RESULT: PASSED")
		_finish(PASS)
	else:
		for failure in _failures:
			push_error(failure)
		print("SUITE RESULT: FAILED")
		_finish(FAIL)


func _test_profiler_sampling_and_report() -> void:
	var profiler: Node = ProfilerScript.new()
	root.add_child(profiler)

	if bool(profiler.call("is_stress_active")):
		_fail("profiler should start idle")
		profiler.queue_free()
		return

	profiler.call("start_sampling")
	if not bool(profiler.call("is_sampling")):
		_fail("profiler failed to start sampling")

	profiler.call("record_frame_sample", 0.016)
	profiler.call("record_frame_sample", 0.020)
	profiler.call("record_frame_sample", 0.025)
	profiler.call("stop_sampling")

	if bool(profiler.call("is_sampling")):
		_fail("profiler failed to stop sampling")

	profiler.call(
		"finalize_manual_profile",
		"profiler_test_map",
		0,
		0,
		"synthetic fps samples"
	)
	var report: String = str(profiler.call("get_last_report_text"))
	if report.is_empty():
		_fail("performance report was not generated")

	var required_lines: Array[String] = [
		"PERFORMANCE STRESS REPORT",
		"map_id:",
		"requested_zombies:",
		"spawned_zombies:",
		"analyzer_enabled:",
		"markers_enabled:",
		"avg_fps:",
		"min_fps:",
		"max_frame_ms:",
		"avg_frame_ms:",
		"race_time_sampled:",
		"alive:",
		"finished:",
		"fell:",
		"killed:",
		"stuck:",
		"unresolved:",
		"notes:",
	]
	for line in required_lines:
		if not report.contains(line):
			_fail("report missing '%s'" % line)

	if not report.contains("map_id: profiler_test_map"):
		_fail("report map id mismatch:\n%s" % report)
	if float(report.split("avg_fps: ")[1].split("\n")[0]) <= 0.0:
		_fail("expected positive avg_fps in report:\n%s" % report)

	profiler.call("print_performance_report")
	print("profiler sampling/report passed")
	profiler.queue_free()


func _fail(message: String) -> void:
	_failures.append(message)
	print("FAIL: %s" % message)


func _finish(exit_code: int) -> void:
	await create_timer(0.05).timeout
	quit(exit_code)
