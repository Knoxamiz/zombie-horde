extends SceneTree

const FreeCameraFlightLimitsScript := preload("res://scripts/camera/free_camera_flight_limits.gd")
const RaceMapControllerScript := preload("res://scripts/maps/race_map_controller.gd")

const EXPECTED_REGION_COUNTS := {
	"quarantine_boulevard": 1,
	"broken_bridge_pass": 1,
	"spiral_descent": 1,
	"true_spiral_ramp": 1,
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
		if not limits.is_position_inside_active_limits(stacked_road_interior):
			_fail("true_spiral_ramp: compact garage center must be free-camera space")
		var garage_race_view: Dictionary = RaceMapControllerScript.compute_race_camera_view_for_definition(definition)
		var garage_start_position: Vector3 = garage_race_view.get("position", Vector3.ZERO) as Vector3
		var garage_min: Vector3 = limits.get_enclosing_bounds_min()
		var garage_max: Vector3 = limits.get_enclosing_bounds_max()
		var garage_start_margin: float = minf(
			minf(garage_start_position.x - garage_min.x, garage_max.x - garage_start_position.x),
			minf(garage_start_position.y - garage_min.y, garage_max.y - garage_start_position.y),
			minf(garage_start_position.z - garage_min.z, garage_max.z - garage_start_position.z)
		)
		if garage_start_margin < 18.0:
			_fail("true_spiral_ramp: initial free camera needs at least 18m of flight margin")

	if map_id == "quarantine_boulevard":
		var city_start_view: Dictionary = RaceMapControllerScript.compute_race_camera_view_for_definition(definition)
		var city_start_position: Vector3 = city_start_view.get("position", Vector3.ZERO) as Vector3
		if not limits.is_position_inside_active_limits(city_start_position):
			_fail("quarantine_boulevard: initial race camera view must not clamp to the start boundary")
		var city_overview_points: Array[Vector3] = [
			Vector3(-52.0, 28.0, -96.0),
			Vector3(52.0, 28.0, 96.0),
		]
		for city_overview_point: Vector3 in city_overview_points:
			if not limits.is_position_inside_active_limits(city_overview_point):
				_fail("quarantine_boulevard: free camera must cover the full suburban neighborhood")

	if map_id == "spiral_descent":
		# The Parking Garage route descends from the upper deck to ground level.
		# The camera must remain free in the central volume, rather than clamping
		# operators to the upper deck as they follow the horde downstairs.
		var garage_inspection_points: Array[Vector3] = [
			Vector3(0.0, 1.0, 64.0),
			Vector3(0.0, 6.0, 0.0),
			Vector3(-32.0, 32.0, -96.0),
			Vector3(32.0, 48.0, 96.0),
		]
		for garage_inspection_point: Vector3 in garage_inspection_points:
			if not limits.is_position_inside_active_limits(garage_inspection_point):
				_fail("spiral_descent: garage camera cannot reach inspection point %s" % garage_inspection_point)


func _fail(message: String) -> void:
	_failures.append(message)
	print("FAIL: %s" % message)
