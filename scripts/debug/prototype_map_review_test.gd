extends SceneTree

const MAIN_GAME_SCENE := "res://scenes/main/main_game.tscn"
const PASS := 0
const FAIL := 1

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run_all")


func _run_all() -> void:
	print("=== Prototype map review test ===")
	var expected_ids: Array[String] = AIMapBlueprintRegistry.get_all_generated_map_ids()
	if expected_ids.is_empty():
		print("No AI-generated prototype maps registered; skipping load checks")
		_finish()
		return

	_test_catalog_lists_ai_generated_prototypes(expected_ids)
	for map_id in expected_ids:
		await _test_prototype_load(map_id)
	_finish()


func _test_catalog_lists_ai_generated_prototypes(expected_ids: Array[String]) -> void:
	print("-- catalog ai-generated prototypes --")
	var entries: Array[Dictionary] = MapCatalog.get_ai_generated_prototype_entries()
	var found_ids: Array[String] = []
	for entry in entries:
		var map_id: String = str(entry.get("id", ""))
		found_ids.append(map_id)
		if bool(entry.get("enabled", false)):
			_fail("AI-generated prototype '%s' must remain enabled=false" % map_id)
		if str(entry.get("status", "")) != MapCatalog.STATUS_PROTOTYPE:
			_fail("AI-generated prototype '%s' must remain status=prototype" % map_id)

	for expected_id in expected_ids:
		if expected_id not in found_ids:
			_fail("expected AI-generated prototype missing from catalog: %s" % expected_id)


func _test_prototype_load(map_id: String) -> void:
	print("-- prototype load: %s --" % map_id)
	var packed: PackedScene = load(MAIN_GAME_SCENE)
	if packed == null:
		_fail("Could not load main game scene")
		return

	var main_game: Node = packed.instantiate()
	root.add_child(main_game)
	await create_timer(0.8).timeout

	var map_controller: RaceMapController = main_game.get_node_or_null(
		"Systems/RaceMapController"
	) as RaceMapController
	if map_controller == null:
		_fail("RaceMapController missing")
		main_game.queue_free()
		return

	if not map_controller.load_prototype_map_for_test(map_id):
		_fail(
			"load_prototype_map_for_test failed for %s: %s"
			% [map_id, map_controller.get_last_load_failure_reason()]
		)
		main_game.queue_free()
		return

	if map_controller.did_last_load_use_fallback():
		_fail("prototype load used City Highway fallback for %s" % map_id)

	if map_controller.get_resolved_map_id() != map_id:
		_fail(
			"resolved map id '%s' != '%s'"
			% [map_controller.get_resolved_map_id(), map_id]
		)

	if not map_controller.is_prototype_test_load_active():
		_fail("prototype test load flag was not set for %s" % map_id)

	map_controller.clear_prototype_test_load(true)
	main_game.queue_free()


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
