extends SceneTree

const Builder := preload("res://scripts/maps/ai_map_blueprint_builder.gd")
const Registry := preload("res://scripts/maps/ai_map_blueprint_registry.gd")
const Audit := preload("res://scripts/maps/ai_map_collision_audit.gd")
const Validator := preload("res://scripts/maps/ai_map_blueprint_validator.gd")

const PASS := 0
const FAIL := 1

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run_all")


func _run_all() -> void:
	print("=== AI generated map collision audit test ===")
	for map_id in Audit.FOCUS_MAP_IDS:
		_test_focus_map(map_id)
	_finish()


func _test_focus_map(map_id: String) -> void:
	print("-- %s --" % map_id)
	var blueprint = Registry.resolve_blueprint_for_generated_map(map_id)
	if blueprint == null:
		_fail("missing blueprint for '%s'" % map_id)
		return

	var host := Node3D.new()
	root.add_child(host)
	var builder = Builder.new()
	var map_root: Node3D = builder.build_prototype(host, blueprint)
	if map_root == null:
		_fail("build_prototype failed for '%s'" % map_id)
		host.queue_free()
		return

	Audit.print_collision_audit(map_root, map_id)

	var definition: RaceMapDefinition = builder.build_race_map_definition(blueprint)
	var scene_validation: Dictionary = Validator.validate_generated_scene(map_root, blueprint, definition)
	if not bool(scene_validation.get("ok", false)):
		_fail("scene validation failed for '%s': %s" % [map_id, str(scene_validation.get("errors", []))])

	var collision_errors: Array[String] = Audit.validate_generated_collision(map_root, blueprint, definition)
	for error in collision_errors:
		_fail("[%s] %s" % [map_id, error])

	if map_id == Audit.SIGNATURE_DROP_BRIDGE_MAP_ID:
		for error in Audit.probe_signature_drop_bridge(map_root, blueprint, definition):
			_fail("[%s] probe: %s" % [map_id, error])

	var visual_layer: Node = map_root.get_node_or_null("VisualLayer")
	if visual_layer != null:
		for entry in Audit.collect_collision_entries(visual_layer as Node3D):
			if not bool(entry.get("disabled", true)) and int(entry.get("collision_layer", 0)) != 0:
				_fail("[%s] active VisualLayer collision: %s" % [map_id, entry.get("path", "")])

	var surfaces: Node = map_root.get_node_or_null("GameplayLayer/Surfaces")
	if surfaces != null:
		for piece in surfaces.get_children():
			if not (piece is StaticBody3D):
				continue
			var shape_found: bool = false
			for child in piece.get_children():
				if child is CollisionShape3D and not (child as CollisionShape3D).disabled:
					shape_found = true
					if not ((child as CollisionShape3D).shape is BoxShape3D):
						_fail("[%s] Surfaces should use BoxShape3D collision" % map_id)
			if not shape_found:
				_fail("[%s] surface piece missing enabled collision shape" % map_id)
	elif map_root.get_node_or_null("GameplayLayer/SafeFloor") == null:
		_fail("[%s] GameplayLayer/Surfaces missing" % map_id)

	print("%s collision audit passed" % map_id)
	host.queue_free()


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
