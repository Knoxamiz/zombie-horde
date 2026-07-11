extends SceneTree

## Agent-friendly gap crossing audit for kit maps.
## Prints structured measurements so headless runs can "see" invisible bridge floors.
##
## Usage:
##   godot --headless --path . -s res://scripts/debug/kit_map_gap_audit_test.gd
##   godot --headless --path . -s res://scripts/debug/kit_map_gap_audit_test.gd -- --write-report

const AUDIT := preload("res://scripts/maps/kit_map_gap_audit.gd")
const KIT_ARENA := preload("res://scripts/maps/kit_map_arena.gd")
const PASS := 0
const FAIL := 1

const GAP_PRESET_IDS: Array[String] = [
	"broken_bridge_pass",
	"vehicle_yard",
]

var _failures: PackedStringArray = PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Kit map gap audit test ===")
	var report: Dictionary = _audit_all_presets()
	for preset_report_variant in report.get("presets", []):
		if preset_report_variant is Dictionary:
			print(AUDIT.format_report(preset_report_variant))

	if "--write-report" in OS.get_cmdline_user_args():
		var output_path: String = "res://artifacts/kit_map_gap_audit_latest.json"
		if AUDIT.write_report_file(report, output_path):
			print("Wrote %s" % output_path)
		else:
			_fail("Could not write report to %s" % output_path)

	for issue in report.get("issues", PackedStringArray()):
		_fail(str(issue))

	if _failures.is_empty():
		print("SUITE RESULT: PASSED")
		quit(PASS)
	else:
		print("SUITE RESULT: FAILED")
		for failure in _failures:
			print("FAIL: %s" % failure)
		quit(FAIL)


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _audit_all_presets() -> Dictionary:
	var reports: Array[Dictionary] = []
	var all_issues: PackedStringArray = PackedStringArray()
	for preset_id in GAP_PRESET_IDS:
		var arena := KIT_ARENA.new()
		arena.layout_preset_id = preset_id
		root.add_child(arena)
		arena.ensure_built()
		var preset_report: Dictionary = AUDIT.audit_preset(preset_id, arena)
		reports.append(preset_report)
		for issue in preset_report.get("issues", PackedStringArray()):
			all_issues.append(str(issue))
		arena.queue_free()
	return {
		"presets": reports,
		"issues": all_issues,
		"passed": all_issues.is_empty(),
	}
