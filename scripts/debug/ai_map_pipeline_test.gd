extends SceneTree

const MapAssetLibrary := preload("res://scripts/maps/map_asset_library.gd")
const MapSegmentDefinition := preload("res://scripts/maps/map_segment_definition.gd")
const AIMapBlueprintValidator := preload("res://scripts/maps/ai_map_blueprint_validator.gd")
const AIMapBlueprintBuilder := preload("res://scripts/maps/ai_map_blueprint_builder.gd")
const ExampleBridgeSegmentsTestBlueprint := preload(
	"res://scripts/maps/blueprints/example_bridge_segments_test.gd"
)

const PASS := 0
const FAIL := 1

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run_all")


func _run_all() -> void:
	print("=== AI Map Pipeline Test ===")
	_test_asset_registry_loads()
	_test_example_blueprint_validates()
	_test_invalid_segment_fails()
	_test_invalid_asset_id_fails()
	_test_invalid_segment_order_fails()
	_test_generated_prototype_contract()
	MapAssetLibrary.print_audit_report()

	if _failures.is_empty():
		print("SUITE RESULT: PASSED")
		_finish(PASS)
	else:
		for failure in _failures:
			push_error(failure)
		print("SUITE RESULT: FAILED (%d)" % _failures.size())
		_finish(FAIL)


func _test_asset_registry_loads() -> void:
	print("-- asset registry --")
	var ids: Array = MapAssetLibrary.get_all_asset_ids()
	if ids.is_empty():
		_fail("MapAssetLibrary returned no assets")
		return
	if not MapAssetLibrary.has_asset("street_straight"):
		_fail("street_straight missing from library")
	if not MapAssetLibrary.has_asset("safe_floor_plate"):
		_fail("safe_floor_plate missing from library")
	var segments: Array = MapSegmentDefinition.get_all_segment_ids()
	if segments.is_empty():
		_fail("MapSegmentDefinition returned no segments")
	print("assets=%d segments=%d" % [ids.size(), segments.size()])


func _test_example_blueprint_validates() -> void:
	print("-- example blueprint --")
	var blueprint = ExampleBridgeSegmentsTestBlueprint.create()
	var result: Dictionary = AIMapBlueprintValidator.validate_blueprint(blueprint)
	AIMapBlueprintValidator.print_validation_report(result)
	if not bool(result.get("ok", false)):
		_fail("example_bridge_segments_test blueprint should validate")


func _test_invalid_segment_fails() -> void:
	print("-- invalid segment id --")
	var blueprint = ExampleBridgeSegmentsTestBlueprint.create()
	blueprint.segment_sequence = ["seg_start_8", "seg_not_real", "seg_finish_8"]
	var result: Dictionary = AIMapBlueprintValidator.validate_blueprint(blueprint)
	if bool(result.get("ok", false)):
		_fail("invalid segment_id should fail validation")


func _test_invalid_asset_id_fails() -> void:
	print("-- invalid asset id --")
	var blueprint = ExampleBridgeSegmentsTestBlueprint.create()
	blueprint.segment_sequence = ["seg_start_8", "seg_test_bad_asset", "seg_finish_8"]
	var result: Dictionary = AIMapBlueprintValidator.validate_blueprint(blueprint)
	if bool(result.get("ok", false)):
		_fail("invalid asset_id in segment should fail validation")


func _test_invalid_segment_order_fails() -> void:
	print("-- invalid segment order --")
	var blueprint = ExampleBridgeSegmentsTestBlueprint.create()
	blueprint.segment_sequence = ["seg_straight_8", "seg_finish_8", "seg_start_8"]
	var result: Dictionary = AIMapBlueprintValidator.validate_blueprint(blueprint)
	if bool(result.get("ok", false)):
		_fail("segment order without start/finish ends should fail")


func _test_generated_prototype_contract() -> void:
	print("-- generated prototype contract --")
	var blueprint = ExampleBridgeSegmentsTestBlueprint.create()
	var host := Node3D.new()
	root.add_child(host)

	var builder = AIMapBlueprintBuilder.new()
	var map_root: Node3D = builder.build_prototype(host, blueprint)
	if map_root == null:
		_fail("build_prototype returned null for valid example blueprint")
		host.queue_free()
		return

	var definition: RaceMapDefinition = builder.build_race_map_definition(blueprint)
	var scene_result: Dictionary = AIMapBlueprintValidator.validate_generated_scene(
		map_root, blueprint, definition
	)
	AIMapBlueprintValidator.print_validation_report(scene_result)
	if not bool(scene_result.get("ok", false)):
		_fail("generated example scene failed validation")

	if _find_node_named(map_root, "GoalCatch") != null:
		_fail("generated prototype must not create GoalCatch")

	if _find_void_kill_authority(map_root):
		_fail("generated prototype must not create authoritative void kill zones")

	host.queue_free()


func _find_node_named(node: Node, node_name: String) -> Node:
	if node.name == node_name:
		return node
	for child in node.get_children():
		var found: Node = _find_node_named(child, node_name)
		if found != null:
			return found
	return null


func _find_void_kill_authority(node: Node) -> bool:
	if node.get_script() != null:
		if str(node.get_script().resource_path) == AIMapBlueprintValidator.VOID_KILL_SCRIPT_PATH:
			return true
	if node is Area3D:
		var area: Area3D = node as Area3D
		if area.name.to_lower().contains("void") and area.name.to_lower().contains("kill"):
			if area.monitoring:
				return true
	for child in node.get_children():
		if _find_void_kill_authority(child):
			return true
	return false


func _fail(message: String) -> void:
	_failures.append(message)
	print("FAIL: %s" % message)


func _finish(exit_code: int) -> void:
	quit(exit_code)
