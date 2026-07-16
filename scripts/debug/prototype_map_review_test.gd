extends SceneTree

const MAIN_GAME_SCENE := "res://scenes/main/main_game.tscn"
const PASS := 0
const FAIL := 1

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run_all")


func _run_all() -> void:
	print("=== Disabled authored-map audit ===")
	var expected_ids: Array[String] = AIMapBlueprintRegistry.get_all_generated_map_ids()
	if expected_ids.is_empty():
		print("No disabled authored maps registered; skipping audit")
		_finish()
		return

	_test_catalog_lists_disabled_authored_maps(expected_ids)
	_finish()


func _test_catalog_lists_disabled_authored_maps(expected_ids: Array[String]) -> void:
	print("-- disabled authored maps --")
	for map_id in expected_ids:
		var entry: Dictionary = MapCatalog.get_entry_by_id(map_id)
		if entry.is_empty():
			_fail("expected authored map missing from catalog: %s" % map_id)
			continue
		if MapCatalog.is_entry_playable(entry):
			_fail("authored map '%s' must be disabled until release-ready" % map_id)
		if str(entry.get("status", "")) != MapCatalog.STATUS_DISABLED:
			_fail("authored map '%s' must use disabled status" % map_id)


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
