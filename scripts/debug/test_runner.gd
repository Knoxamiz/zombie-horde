extends SceneTree

## Unified headless test runner for Cursor/Codex pre/post change checks.
## Usage:
##   godot --headless --path . -s res://scripts/debug/test_runner.gd -- --tier=smoke
##   godot --headless --path . -s res://scripts/debug/test_runner.gd -- --tier=core
##   godot --headless --path . -s res://scripts/debug/test_runner.gd -- --tier=map
##   godot --headless --path . -s res://scripts/debug/test_runner.gd -- --tier=certification

const PASS := 0
const FAIL := 1
const SCRIPT_DIR := "res://scripts/debug/"

const SMOKE_TESTS: Array[Dictionary] = [
	{"name": "race_quick_smoke_test", "script": "race_quick_smoke_test.gd", "args": []},
	{"name": "map_selection_test", "script": "map_selection_test.gd", "args": []},
]

const CORE_TESTS: Array[Dictionary] = [
	{"name": "race_lifecycle_smoke_test", "script": "race_lifecycle_smoke_test.gd", "args": []},
	{"name": "race_finish_contract_test", "script": "race_finish_contract_test.gd", "args": []},
	{"name": "void_oob_authority_test", "script": "void_oob_authority_test.gd", "args": []},
	{"name": "map_selection_test", "script": "map_selection_test.gd", "args": []},
]

const MAP_TESTS: Array[Dictionary] = [
	{"name": "map_selection_test", "script": "map_selection_test.gd", "args": []},
	{"name": "ai_map_pipeline_test", "script": "ai_map_pipeline_test.gd", "args": []},
	{"name": "moving_obstacle_reset_test", "script": "moving_obstacle_reset_test.gd", "args": []},
	{
		"name": "ai_generated_map_collision_audit_test",
		"script": "ai_generated_map_collision_audit_test.gd",
		"args": [],
	},
	{
		"name": "broken_bridge_real_gameplay_test",
		"script": "broken_bridge_real_gameplay_test.gd",
		"args": ["--zombies=5", "--skip-stress"],
	},
]

const CERTIFICATION_TESTS: Array[Dictionary] = [
	{"name": "map_selection_test", "script": "map_selection_test.gd", "args": []},
	{"name": "map_certification_test", "script": "map_certification_test.gd", "args": []},
	{
		"name": "ai_generated_map_certification_test",
		"script": "ai_generated_map_certification_test.gd",
		"args": [],
	},
]

const ALL_EXTRA_TESTS: Array[Dictionary] = [
	{
		"name": "broken_bridge_real_gameplay_test",
		"script": "broken_bridge_real_gameplay_test.gd",
		"args": ["--zombies=5", "--skip-stress"],
	},
	{"name": "race_finish_window_test", "script": "race_finish_window_test.gd", "args": []},
	{"name": "podium_results_test", "script": "podium_results_test.gd", "args": []},
	{"name": "supporter_upgrade_test", "script": "supporter_upgrade_test.gd", "args": []},
	{"name": "zombie_color_variant_test", "script": "zombie_color_variant_test.gd", "args": []},
	{"name": "streaming_bootstrap_test", "script": "streaming_bootstrap_test.gd", "args": []},
	{"name": "lobby_empty_boot_test", "script": "lobby_empty_boot_test.gd", "args": []},
	{"name": "prototype_map_load_test", "script": "prototype_map_load_test.gd", "args": []},
]

var _tier: String = "smoke"
var _started_msec: int = 0


func _initialize() -> void:
	call_deferred("_run_all")


func _run_all() -> void:
	_tier = _parse_tier()
	_started_msec = Time.get_ticks_msec()

	if not _tier in ["smoke", "core", "map", "certification", "all"]:
		push_error("Unknown tier '%s'. Use smoke, core, map, certification, or all." % _tier)
		_print_summary([], [], [], 0.0)
		quit(FAIL)
		return

	var tests: Array[Dictionary] = _tests_for_tier(_tier)
	if tests.is_empty():
		push_error("No tests configured for tier '%s'" % _tier)
		_print_summary([], [], [], 0.0)
		quit(FAIL)
		return

	print("=== Test Runner (%s tier, %d tests) ===" % [_tier, tests.size()])

	var passed: Array[String] = []
	var failed: Array[String] = []
	var skipped: Array[String] = []

	for test in tests:
		var script_path: String = SCRIPT_DIR + str(test.get("script", ""))
		if not ResourceLoader.exists(script_path):
			push_warning("Skipping missing test script: %s" % script_path)
			skipped.append(str(test.get("name", script_path)))
			continue

		var result: Dictionary = _run_child_test(test)
		if bool(result.get("passed", false)):
			passed.append(str(result.get("name", "")))
		else:
			failed.append(str(result.get("name", "")))

	var total_sec: float = float(Time.get_ticks_msec() - _started_msec) / 1000.0
	_print_summary(passed, failed, skipped, total_sec)
	quit(FAIL if not failed.is_empty() else PASS)


func _tests_for_tier(tier: String) -> Array[Dictionary]:
	match tier:
		"smoke":
			return SMOKE_TESTS.duplicate(true)
		"core":
			return CORE_TESTS.duplicate(true)
		"map":
			return MAP_TESTS.duplicate(true)
		"certification":
			return CERTIFICATION_TESTS.duplicate(true)
		"all":
			return _build_all_tests()
		_:
			return []


func _build_all_tests() -> Array[Dictionary]:
	var merged: Array[Dictionary] = []
	var seen: Dictionary = {}
	for test in CORE_TESTS + MAP_TESTS + ALL_EXTRA_TESTS:
		var test_name: String = str(test.get("name", ""))
		if test_name.is_empty() or seen.has(test_name):
			continue
		seen[test_name] = true
		merged.append(test.duplicate(true))
	return merged


func _parse_tier() -> String:
	for arg in OS.get_cmdline_user_args():
		var trimmed: String = arg.strip_edges()
		if trimmed.begins_with("--tier="):
			return trimmed.substr("--tier=".length()).strip_edges().to_lower()
		if trimmed == "--tier" or trimmed.begins_with("--tier "):
			continue
		if trimmed in ["smoke", "core", "map", "certification", "all"]:
			return trimmed

	for index in range(OS.get_cmdline_user_args().size()):
		var arg: String = str(OS.get_cmdline_user_args()[index]).strip_edges()
		if arg == "--tier" and index + 1 < OS.get_cmdline_user_args().size():
			return str(OS.get_cmdline_user_args()[index + 1]).strip_edges().to_lower()

	return "smoke"


func _run_child_test(test: Dictionary) -> Dictionary:
	var test_name: String = str(test.get("name", "unknown"))
	var script_path: String = SCRIPT_DIR + str(test.get("script", ""))
	var godot_path: String = OS.get_executable_path()
	var project_path: String = _get_project_path()
	var args: PackedStringArray = PackedStringArray([
		"--headless",
		"--path",
		project_path,
		"-s",
		script_path,
	])

	var user_args: Array = test.get("args", [])
	if not user_args.is_empty():
		args.append("--")
		for user_arg in user_args:
			args.append(str(user_arg))

	print("")
	print(">>> Running %s" % test_name)
	var started_msec: int = Time.get_ticks_msec()
	var output: Array = []
	var exit_code: int = OS.execute(godot_path, args, output, true, false)
	var elapsed_sec: float = float(Time.get_ticks_msec() - started_msec) / 1000.0

	for line in output:
		var text: String = str(line)
		if (
			"FAIL" in text
			or "SUITE RESULT" in text
			or "PASSED" in text
			or "ERROR" in text
			or "MapSelectionTest" in text
			or "QUICK SMOKE RUNTIME" in text
			or "MAP CERTIFICATION" in text
			or "MAP LOAD FAILED" in text
		):
			print(text)

	var passed: bool = exit_code == 0
	print(
		"<<< %s %s (exit=%d, %.1fs)"
		% [test_name, "PASSED" if passed else "FAILED", exit_code, elapsed_sec]
	)
	return {
		"name": test_name,
		"passed": passed,
		"exit_code": exit_code,
		"elapsed_sec": elapsed_sec,
	}


func _get_project_path() -> String:
	var project_path: String = ProjectSettings.globalize_path("res://")
	while project_path.ends_with("/"):
		project_path = project_path.substr(0, project_path.length() - 1)
	return project_path


func _print_summary(
	passed: Array[String],
	failed: Array[String],
	skipped: Array[String],
	total_sec: float
) -> void:
	var tests_run: int = passed.size() + failed.size()
	print("")
	print("TEST RUNNER RESULT")
	print("- tier: %s" % _tier)
	print("- tests run: %d" % tests_run)
	print("- passed: %d" % passed.size())
	print("- failed: %d" % failed.size())
	print("- skipped: %d" % skipped.size())
	print("- total time: %.1fs" % total_sec)
	if _tier == "smoke":
		print("- smoke target: 60.0s")
		if total_sec <= 60.0:
			print("- smoke status: WITHIN TARGET")
		else:
			print("- smoke status: SLOW (over 60s target)")
	if _tier == "certification":
		print("- certification runtime: %.1fs" % total_sec)
	if failed.is_empty():
		print("- failed test names:")
	else:
		print("- failed test names: %s" % ", ".join(failed))
	if not skipped.is_empty():
		print("- skipped test names: %s" % ", ".join(skipped))
