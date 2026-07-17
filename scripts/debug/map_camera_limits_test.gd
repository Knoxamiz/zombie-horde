extends SceneTree

const FreeCameraFlightLimitsScript := preload("res://scripts/camera/free_camera_flight_limits.gd")

const EXPECTED_REGION_COUNTS := {
	"quarantine_boulevard": 1,
	"broken_bridge_pass": 1,
	"spiral_descent": 1,
	"true_spiral_ramp": 5,
}

var _failures: PackedStringArray = PackedStringArray()


func _initialize() -> void:
	for map_id_variant in EXPECTED_REGION_COUNTS:
		var map_id: String = str(map_id_variant)
		_test_map_camera_limits(map_id, int(EXPECTED_REGION_COUNTS[map_id]))
	if _failures.is_empty():
		print("PASS: every playable map owns a valid free-camera flight space")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_map_camera_limits(map_id: String, expected_region_count: int) -> void:
	var definition: RaceMapDefinition = MapCatalog.load_definition_for_map_id(map_id)
	if definition == null:
		_fail("%s: definition could not load" % map_id)
		return
	if definition.free_camera_safe_regions.size() != expected_region_count:
		_fail(
			"%s: expected %d camera regions, got %d"
			% [map_id, expected_region_count, definition.free_camera_safe_regions.size()]
		)
		return

	for region_index in range(definition.free_camera_safe_regions.size()):
		var region: AABB = definition.free_camera_safe_regions[region_index]
		if region.size.x <= 0.0 or region.size.y <= 0.0 or region.size.z <= 0.0:
			_fail("%s: camera region %d must have positive volume" % [map_id, region_index])

	var limits = FreeCameraFlightLimitsScript.new()
	limits.configure_for_map_definition(definition)
	if limits.get_safe_region_count() != expected_region_count:
		_fail("%s: controller limits did not apply map camera regions" % map_id)
		return

	var outside_position := Vector3(999.0, -80.0, 999.0)
	var clamped_position: Vector3 = limits.clamp_position(outside_position)
	if not limits.is_position_inside_active_limits(clamped_position):
		_fail("%s: out-of-bounds camera position did not clamp into a safe region" % map_id)

	if map_id == "true_spiral_ramp":
		var stacked_road_interior := Vector3(0.0, 21.0, 0.0)
		if limits.is_position_inside_active_limits(stacked_road_interior):
			_fail("true_spiral_ramp: stacked-road interior must not be free-camera space")
		var spiral_clamped: Vector3 = limits.clamp_position(stacked_road_interior)
		if spiral_clamped.is_equal_approx(stacked_road_interior):
			_fail("true_spiral_ramp: interior camera position was not redirected")


func _fail(message: String) -> void:
	_failures.append(message)
	print("FAIL: %s" % message)
