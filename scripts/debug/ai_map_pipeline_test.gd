extends SceneTree

const MapAssetLibrary := preload("res://scripts/maps/map_asset_library.gd")
const MapSegmentDefinition := preload("res://scripts/maps/map_segment_definition.gd")
const AIMapBlueprintValidator := preload("res://scripts/maps/ai_map_blueprint_validator.gd")
const AIMapBlueprintBuilder := preload("res://scripts/maps/ai_map_blueprint_builder.gd")
const ExampleBridgeSegmentsTestBlueprint := preload(
	"res://scripts/maps/blueprints/example_bridge_segments_test.gd"
)
const Phase1BridgeRampTestBlueprint := preload(
	"res://scripts/maps/blueprints/phase1_bridge_ramp_test.gd"
)
const Phase2DropGapTestBlueprint := preload(
	"res://scripts/maps/blueprints/phase2_drop_gap_test.gd"
)

const PASS := 0
const FAIL := 1

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run_all")


func _run_all() -> void:
	print("=== AI Map Pipeline Test ===")
	_test_asset_registry_loads()
	_test_phase1_assets_validate()
	_test_phase1_segments_validate()
	_test_phase2_assets_validate()
	_test_phase2_segments_validate()
	_test_example_blueprint_validates()
	_test_phase1_blueprint_validates()
	_test_phase2_blueprint_validates()
	_test_invalid_segment_fails()
	_test_invalid_asset_id_fails()
	_test_invalid_segment_order_fails()
	_test_gap_without_fall_fails()
	_test_gap_without_recovery_fails()
	_test_elevated_bad_oob_min_y_fails()
	_test_spawn_inside_gap_fails()
	_test_finish_inside_gap_fails()
	_test_hidden_floor_width_fails()
	_test_generated_example_contract()
	_test_generated_phase1_contract()
	_test_generated_phase2_contract()
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
	if not MapAssetLibrary.has_asset("phase1_road_straight_8"):
		_fail("phase1_road_straight_8 missing from library")
	if not MapAssetLibrary.has_asset("phase2_warning_stripes"):
		_fail("phase2_warning_stripes missing from library")
	var segments: Array = MapSegmentDefinition.get_all_segment_ids()
	if segments.is_empty():
		_fail("MapSegmentDefinition returned no segments")
	print("assets=%d segments=%d" % [ids.size(), segments.size()])


func _test_phase1_assets_validate() -> void:
	print("-- phase1 assets --")
	var result: Dictionary = MapAssetLibrary.validate_phase1_assets()
	if not bool(result.get("ok", false)):
		_fail("Phase 1 assets missing: %s" % str(result.get("missing", [])))


func _test_phase1_segments_validate() -> void:
	print("-- phase1 segments --")
	var result: Dictionary = MapSegmentDefinition.validate_phase1_segments()
	if not bool(result.get("ok", false)):
		_fail("Phase 1 segments missing: %s" % str(result.get("missing", [])))


func _test_phase2_assets_validate() -> void:
	print("-- phase2 assets --")
	var result: Dictionary = MapAssetLibrary.validate_phase2_assets()
	if not bool(result.get("ok", false)):
		_fail("Phase 2 assets missing: %s" % str(result.get("missing", [])))


func _test_phase2_segments_validate() -> void:
	print("-- phase2 segments --")
	var result: Dictionary = MapSegmentDefinition.validate_phase2_segments()
	if not bool(result.get("ok", false)):
		_fail("Phase 2 segments missing: %s" % str(result.get("missing", [])))


func _test_example_blueprint_validates() -> void:
	print("-- example blueprint --")
	var blueprint = ExampleBridgeSegmentsTestBlueprint.create()
	var result: Dictionary = AIMapBlueprintValidator.validate_blueprint(blueprint)
	AIMapBlueprintValidator.print_validation_report(result)
	if not bool(result.get("ok", false)):
		_fail("example_bridge_segments_test blueprint should validate")


func _test_phase1_blueprint_validates() -> void:
	print("-- phase1 blueprint --")
	var blueprint = Phase1BridgeRampTestBlueprint.create()
	var result: Dictionary = AIMapBlueprintValidator.validate_blueprint(blueprint)
	AIMapBlueprintValidator.print_validation_report(result)
	if not bool(result.get("ok", false)):
		_fail("phase1_bridge_ramp_test blueprint should validate")


func _test_phase2_blueprint_validates() -> void:
	print("-- phase2 blueprint --")
	var blueprint = Phase2DropGapTestBlueprint.create()
	var result: Dictionary = AIMapBlueprintValidator.validate_blueprint(blueprint)
	AIMapBlueprintValidator.print_validation_report(result)
	if not bool(result.get("ok", false)):
		_fail("phase2_drop_gap_test blueprint should validate")


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


func _test_gap_without_fall_fails() -> void:
	print("-- gap without fall_enabled --")
	var blueprint = Phase1BridgeRampTestBlueprint.create()
	blueprint.fall_enabled = false
	var result: Dictionary = AIMapBlueprintValidator.validate_blueprint(blueprint)
	if bool(result.get("ok", false)):
		_fail("gap blueprint without fall_enabled should fail validation")


func _test_gap_without_recovery_fails() -> void:
	print("-- gap without recovery floor --")
	var blueprint = Phase2DropGapTestBlueprint.create()
	blueprint.segment_sequence = [
		"start_straight",
		"straight_road_medium",
		"broken_bridge_gap",
		"double_side_drop",
		"finish_straight",
	]
	var result: Dictionary = AIMapBlueprintValidator.validate_blueprint(blueprint)
	if bool(result.get("ok", false)):
		_fail("gap without recovery segment should fail validation")


func _test_elevated_bad_oob_min_y_fails() -> void:
	print("-- elevated bad OOB min Y --")
	var blueprint = Phase2DropGapTestBlueprint.create()
	blueprint.fall_enabled = false
	var result: Dictionary = AIMapBlueprintValidator.validate_blueprint(blueprint)
	if bool(result.get("ok", false)):
		_fail("elevated/drop blueprint with fall_enabled=false should fail validation")


func _test_spawn_inside_gap_fails() -> void:
	print("-- spawn inside gap --")
	var blueprint = Phase2DropGapTestBlueprint.create()
	blueprint.segment_sequence = [
		"broken_bridge_gap",
		"recovery_straight_after_gap",
		"finish_straight",
	]
	var result: Dictionary = AIMapBlueprintValidator.validate_blueprint(blueprint)
	if bool(result.get("ok", false)):
		_fail("spawn inside gap segment should fail validation")


func _test_finish_inside_gap_fails() -> void:
	print("-- finish inside gap --")
	var blueprint = Phase2DropGapTestBlueprint.create()
	blueprint.segment_sequence = [
		"start_straight",
		"straight_road_medium",
		"broken_bridge_gap",
	]
	var result: Dictionary = AIMapBlueprintValidator.validate_blueprint(blueprint)
	if bool(result.get("ok", false)):
		_fail("finish inside gap segment should fail validation")


func _test_hidden_floor_width_fails() -> void:
	print("-- hidden floor width --")
	var blueprint = Phase2DropGapTestBlueprint.create()
	blueprint.segment_sequence = [
		"start_straight",
		"straight_road_short",
		"seg_test_oversized_gap",
		"recovery_straight_after_gap",
		"finish_straight",
	]
	var result: Dictionary = AIMapBlueprintValidator.validate_blueprint(blueprint)
	if bool(result.get("ok", false)):
		_fail("oversized hidden floor on gap segment should fail validation")


func _test_generated_example_contract() -> void:
	print("-- generated example contract --")
	_validate_generated_prototype(ExampleBridgeSegmentsTestBlueprint.create(), "example")


func _test_generated_phase1_contract() -> void:
	print("-- generated phase1 contract --")
	_validate_generated_prototype(Phase1BridgeRampTestBlueprint.create(), "phase1")


func _test_generated_phase2_contract() -> void:
	print("-- generated phase2 contract --")
	_validate_generated_prototype(Phase2DropGapTestBlueprint.create(), "phase2")


func _validate_generated_prototype(blueprint, label: String) -> void:
	var host := Node3D.new()
	root.add_child(host)

	var builder = AIMapBlueprintBuilder.new()
	var map_root: Node3D = builder.build_prototype(host, blueprint)
	if map_root == null:
		_fail("%s build_prototype returned null" % label)
		host.queue_free()
		return

	var definition: RaceMapDefinition = builder.build_race_map_definition(blueprint)
	var scene_result: Dictionary = AIMapBlueprintValidator.validate_generated_scene(
		map_root, blueprint, definition
	)
	AIMapBlueprintValidator.print_validation_report(scene_result)
	if not bool(scene_result.get("ok", false)):
		_fail("%s generated scene failed validation" % label)

	if _find_node_named(map_root, "GoalCatch") != null:
		_fail("%s generated prototype must not create GoalCatch" % label)

	if _find_void_kill_authority(map_root):
		_fail("%s generated prototype must not create authoritative void kill zones" % label)

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
