extends SceneTree

const GAMEPLAY_CONTRACT := preload("res://scripts/maps/map_gameplay_contract.gd")

const MAP_IDS := PackedStringArray([
	"quarantine_boulevard",
	"broken_bridge_pass",
	"spiral_descent",
	"true_spiral_ramp",
])

var _failures: PackedStringArray = PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for map_id in MAP_IDS:
		var definition: RaceMapDefinition = MapCatalog.load_definition_by_id(map_id)
		if definition == null:
			_fail("%s definition could not load" % map_id)
			continue
		var failures: Array[String] = GAMEPLAY_CONTRACT.validate_definition(definition, map_id)
		for failure in failures:
			_fail(failure)
		_assert_shared_course_resolver(definition, map_id)
	_test_turning_map_requires_authored_route()
	_finish()


func _assert_shared_course_resolver(definition: RaceMapDefinition, map_id: String) -> void:
	var route: PackedVector3Array = definition.get_effective_race_path()
	if route.size() < 2:
		_fail("%s effective route is missing" % map_id)
		return
	if definition.race_path_points.size() >= 2 and route != definition.race_path_points:
		_fail("%s effective route must preserve authored checkpoint order" % map_id)
	if definition.race_path_points.size() < 2:
		if route[0] != definition.spawn_origin or route[1] != definition.goal_position:
			_fail("%s straight route must resolve from spawn to goal" % map_id)


func _test_turning_map_requires_authored_route() -> void:
	var definition := RaceMapDefinition.new()
	definition.spawn_origin = Vector3(-10.0, 0.8, -10.0)
	definition.goal_position = Vector3(10.0, 0.8, 10.0)
	definition.lane_half_width = 4.0
	definition.navigation_profile = NpcNavigationProfile.new()
	var failures: Array[String] = GAMEPLAY_CONTRACT.validate_definition(definition, "contract_turning_stub")
	var rejected: bool = false
	for failure in failures:
		if "turning course requires authored race_path_points" in failure:
			rejected = true
	if not rejected:
		_fail("gameplay contract must reject a turning map without authored checkpoints")


func _fail(message: String) -> void:
	push_error(message)
	_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: Map gameplay contract")
		quit(0)
		return
	for failure in _failures:
		print("FAIL: %s" % failure)
	quit(1)
