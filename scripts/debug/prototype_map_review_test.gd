extends SceneTree

const MAIN_GAME_SCENE := "res://scenes/main/main_game.tscn"
const EXPECTED_PROTOTYPE_IDS: Array[String] = [
	"ai_generated_phase1_bridge_ramp_test",
	"ai_generated_phase2_drop_gap_probe",
	"ai_generated_signature_drop_bridge",
]
const REVIEW_MAP_ID := "ai_generated_signature_drop_bridge"
const PASS := 0
const FAIL := 1

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run_all")


func _run_all() -> void:
	print("=== Prototype map review test ===")
	_test_catalog_lists_ai_generated_prototypes()
	await _test_drop_bridge_prototype_load()
	_finish()


func _test_catalog_lists_ai_generated_prototypes() -> void:
	print("-- catalog ai-generated prototypes --")
	var entries: Array[Dictionary] = MapCatalog.get_ai_generated_prototype_entries()
	if entries.is_empty():
		_fail("MapCatalog.get_ai_generated_prototype_entries returned no entries")
		return

	var found_ids: Array[String] = []
	for entry in entries:
		var map_id: String = str(entry.get("id", ""))
		found_ids.append(map_id)
		if bool(entry.get("enabled", false)):
			_fail("AI-generated prototype '%s' must remain enabled=false" % map_id)
		if str(entry.get("status", "")) != MapCatalog.STATUS_PROTOTYPE:
			_fail("AI-generated prototype '%s' must remain status=prototype" % map_id)

	for expected_id in EXPECTED_PROTOTYPE_IDS:
		if expected_id not in found_ids:
			_fail("expected AI-generated prototype missing from catalog: %s" % expected_id)


func _test_drop_bridge_prototype_load() -> void:
	print("-- drop bridge prototype load --")
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

	if not map_controller.load_prototype_map_for_test(REVIEW_MAP_ID):
		_fail(
			"load_prototype_map_for_test failed: %s"
			% map_controller.get_last_load_failure_reason()
		)
		main_game.queue_free()
		return

	if map_controller.did_last_load_use_fallback():
		_fail("prototype load used City Highway fallback")

	if map_controller.get_resolved_map_id() != REVIEW_MAP_ID:
		_fail(
			"resolved map id '%s' != '%s'"
			% [map_controller.get_resolved_map_id(), REVIEW_MAP_ID]
		)

	if not map_controller.is_prototype_test_load_active():
		_fail("prototype test load flag was not set")

	var entry: Dictionary = MapCatalog.get_entry_by_id(REVIEW_MAP_ID)
	if bool(entry.get("enabled", false)):
		_fail("catalog entry must remain enabled=false after prototype load")
	if str(entry.get("status", "")) != MapCatalog.STATUS_PROTOTYPE:
		_fail("catalog entry must remain status=prototype after prototype load")

	var road_arena: Node3D = main_game.get_node_or_null("World/RoadArena") as Node3D
	if road_arena == null:
		_fail("World/RoadArena missing after prototype load")
	elif road_arena.get_node_or_null("CoreRoad/MapRoot") == null:
		_fail("CoreRoad/MapRoot missing after prototype load")

	print("%s prototype review load passed" % REVIEW_MAP_ID)
	main_game.queue_free()


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("SUITE RESULT: PASSED")
		quit(PASS)
	else:
		print("SUITE RESULT: FAILED (%d)" % _failures.size())
		quit(FAIL)
