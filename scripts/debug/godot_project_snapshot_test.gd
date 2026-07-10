extends SceneTree

## Validates godot_project_snapshot.gd output.
##
## Usage:
##   godot --headless --path . -s res://scripts/debug/godot_project_snapshot_test.gd

const PASS := 0
const FAIL := 1
const SNAPSHOT_SCRIPT := preload("res://scripts/debug/godot_project_snapshot.gd")

var _failures: PackedStringArray = PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Godot project snapshot test ===")
	var snapshot: Dictionary = SNAPSHOT_SCRIPT.build_full_snapshot()
	if not SNAPSHOT_SCRIPT._write_snapshot(snapshot):
		_fail("could not write snapshot")
		_finish()
		return

	var read_file := FileAccess.open("res://artifacts/godot_project_snapshot.json", FileAccess.READ)
	if read_file == null:
		_fail("snapshot json missing")
		_finish()
		return

	var parsed: Variant = JSON.parse_string(read_file.get_as_text())
	read_file.close()
	if parsed is not Dictionary:
		_fail("snapshot json did not parse")
		_finish()
		return

	var report: Dictionary = parsed as Dictionary
	if str(report.get("kind", "")) != "godot_project_snapshot":
		_fail("snapshot kind wrong")
	var maps: Variant = report.get("playable_maps", [])
	if maps is not Array or (maps as Array).is_empty():
		_fail("playable_maps missing")
	var scenes: Variant = report.get("scene_index", [])
	if scenes is not Array or (scenes as Array).is_empty():
		_fail("scene_index missing")
	var physics_layers: Variant = report.get("physics_layers", {})
	if physics_layers is not Dictionary or (physics_layers as Dictionary).is_empty():
		_fail("physics_layers missing")

	_finish()


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
