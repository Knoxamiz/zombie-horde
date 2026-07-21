extends SceneTree

## Regression coverage for the navigation authority split: route checkpoints
## sequence the race, while movement direction comes from the current path.

const NPC_NAVIGATION_CONTROLLER := preload("res://scripts/navigation/npc_navigation_controller.gd")
const NAVIGATION_PROFILE := preload("res://scripts/navigation/npc_navigation_profile.gd")

var _failures: PackedStringArray = PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_checkpoint_sequence_preserves_turn_order()
	_test_stacked_course_does_not_shortcut_to_finish_below()
	_test_navigation_fallback_reports_its_state()
	_test_wide_map_runner_keeps_forward_progress()
	_finish()


func _test_checkpoint_sequence_preserves_turn_order() -> void:
	var controller = NPC_NAVIGATION_CONTROLLER.new()
	var profile = NAVIGATION_PROFILE.new()
	profile.checkpoint_reach_radius = 2.0
	var route := PackedVector3Array([
		Vector3(-10.0, 0.8, -10.0),
		Vector3(10.0, 0.8, -10.0),
		Vector3(10.0, 0.8, 10.0),
	])
	controller.configure(null, profile, route, route[0], route[2], 42, 5.0)
	if not controller.has_route():
		_fail("Authored race routes must initialize their total length")
		return

	var first_direction: Vector3 = controller.update(route[0], 0.1)
	if first_direction.x <= 0.8 or absf(first_direction.z) > 0.4:
		_fail("Initial navigation direction should follow the first authored segment")

	var turned_direction: Vector3 = controller.update(route[1], 0.1)
	if turned_direction.z <= 0.8 or absf(turned_direction.x) > 0.4:
		_fail("Checkpoint sequencing should advance to the authored turn")


func _test_stacked_course_does_not_shortcut_to_finish_below() -> void:
	var definition: RaceMapDefinition = MapCatalog.load_definition_by_id("true_spiral_ramp")
	if definition == null:
		_fail("Square Spiral Ramp definition failed to load for stacked navigation coverage")
		return
	var controller = NPC_NAVIGATION_CONTROLLER.new()
	var profile = NAVIGATION_PROFILE.new()
	profile.route_lookahead_distance = 8.0
	profile.finish_rejoin_distance = 12.0
	controller.configure(
		null,
		profile,
		definition.race_path_points,
		definition.spawn_origin,
		definition.goal_position,
		91,
		definition.resolve_npc_navigation_half_width()
	)

	# This is the production failure case: same X/Z as the Square Spiral Ramp
	# finish, four stories up. The runner must turn south on the top deck, never
	# target the finish below or wait in place.
	var top_finish_overlook := Vector3(54.0, 42.0, -54.0)
	var direction: Vector3 = controller.update(top_finish_overlook, 0.1)
	if direction.z <= 0.8 or absf(direction.x) > 0.4:
		_fail("Stacked routes must follow their next checkpoint when directly above the finish")
	var diagnostics: Dictionary = controller.get_diagnostics()
	if int(diagnostics.get("segment_index", -1)) != 1:
		_fail("A stacked runner above the finish must remain on its top-deck segment")


func _test_navigation_fallback_reports_its_state() -> void:
	var controller = NPC_NAVIGATION_CONTROLLER.new()
	controller.configure(
		null,
		NAVIGATION_PROFILE.new(),
		PackedVector3Array([Vector3.ZERO, Vector3(0.0, 0.0, 10.0)]),
		Vector3.ZERO,
		Vector3(0.0, 0.0, 10.0),
		7,
		5.0
	)
	controller.update(Vector3.ZERO, 0.1)
	var diagnostics: Dictionary = controller.get_diagnostics()
	if not bool(diagnostics.get("fallback_active", false)):
		_fail("Navigation diagnostics should expose fallback state before a map is ready")


func _test_wide_map_runner_keeps_forward_progress() -> void:
	var controller = NPC_NAVIGATION_CONTROLLER.new()
	var profile = NAVIGATION_PROFILE.new()
	profile.route_lookahead_distance = 8.0
	profile.finish_rejoin_distance = 8.0
	controller.configure(
		null,
		profile,
		PackedVector3Array([Vector3(0.0, 0.0, -40.0), Vector3(0.0, 0.0, 40.0)]),
		Vector3(0.0, 0.0, -40.0),
		Vector3(0.0, 0.0, 40.0),
		12,
		30.0
	)
	var side_runner_direction: Vector3 = controller.update(Vector3(-24.0, 0.0, -12.0), 0.1)
	if side_runner_direction.z <= 0.92 or absf(side_runner_direction.x) >= 0.2:
		_fail("Wide-map runners must keep advancing toward the goal instead of snapping to the centerline")


func _fail(message: String) -> void:
	push_error(message)
	_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: NPC navigation controller contract")
		quit(0)
		return
	for failure in _failures:
		print("FAIL: %s" % failure)
	quit(1)
