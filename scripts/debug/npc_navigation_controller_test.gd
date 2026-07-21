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
	_test_navigation_fallback_reports_its_state()
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
	controller.configure(null, profile, route, route[0], route[2], 42)

	var first_direction: Vector3 = controller.update(route[0], 5.0, 0.1)
	if first_direction.x <= 0.8 or absf(first_direction.z) > 0.4:
		_fail("Initial navigation direction should follow the first authored segment")

	var turned_direction: Vector3 = controller.update(route[1], 5.0, 0.1)
	if turned_direction.z <= 0.8 or absf(turned_direction.x) > 0.4:
		_fail("Checkpoint sequencing should advance to the authored turn")


func _test_navigation_fallback_reports_its_state() -> void:
	var controller = NPC_NAVIGATION_CONTROLLER.new()
	controller.configure(
		null,
		NAVIGATION_PROFILE.new(),
		PackedVector3Array([Vector3.ZERO, Vector3(0.0, 0.0, 10.0)]),
		Vector3.ZERO,
		Vector3(0.0, 0.0, 10.0),
		7
	)
	controller.update(Vector3.ZERO, 5.0, 0.1)
	var diagnostics: Dictionary = controller.get_diagnostics()
	if not bool(diagnostics.get("fallback_active", false)):
		_fail("Navigation diagnostics should expose fallback state before a map is ready")


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
