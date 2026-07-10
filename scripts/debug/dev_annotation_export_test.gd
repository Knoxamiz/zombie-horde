extends SceneTree

## Unit test for dev annotation JSON export (no viewport required).
##
## Usage:
##   godot --headless --path . -s res://scripts/debug/dev_annotation_export_test.gd

const PASS := 0
const FAIL := 1
const PainterScript := preload("res://scripts/debug/dev_annotation_painter.gd")

var _failures: PackedStringArray = PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Dev annotation export test ===")
	var painter := PainterScript.new()
	painter.set_note("gap void looks walkable")
	painter.set_spray_color(DevAnnotationPainter.SprayColor.BUG)
	painter._strokes = [
		{
			"color": "#ff3355",
			"label": "bug",
			"points": [
				{"x": -3.2, "y": 0.8, "z": -44.0},
				{"x": -2.1, "y": 0.8, "z": -43.5},
			],
		}
	]

	var report: Dictionary = painter.build_report(painter)
	if str(report.get("kind", "")) != "dev_annotation_report":
		_fail("report kind missing or wrong")
	if str(report.get("note", "")) != "gap void looks walkable":
		_fail("note not preserved in report")
	var strokes: Variant = report.get("strokes", [])
	if not strokes is Array or strokes.size() != 1:
		_fail("stroke count wrong in report")

	var wrote: bool = PainterScript.write_json_report(report)
	if not wrote:
		_fail("could not write dev_annotation_latest.json")

	var read_file := FileAccess.open(DevAnnotationPainter.JSON_PATH, FileAccess.READ)
	if read_file == null:
		_fail("could not read written json")
	else:
		var parsed: Variant = JSON.parse_string(read_file.get_as_text())
		read_file.close()
		if parsed is not Dictionary:
			_fail("written json did not parse")
		elif int((parsed as Dictionary).get("strokes", []).size()) != 1:
			_fail("round-trip stroke count wrong")

	painter.clear_all_paint()
	if painter.get_stamp_count() != 0 or painter.get_stroke_count() != 0:
		_fail("clear_all_paint did not reset strokes")

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
