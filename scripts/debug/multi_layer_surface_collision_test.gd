extends SceneTree

const ArenaScript := preload("res://scripts/maps/fallthrough_lower_deck_arena.gd")
const Blueprint := preload("res://scripts/maps/blueprints/fallthrough_lower_deck_test.gd")
const Audit := preload("res://scripts/maps/ai_map_collision_audit.gd")
const Validator := preload("res://scripts/maps/ai_map_blueprint_validator.gd")
const MapSurfacePieceScript := preload("res://scripts/maps/map_surface_piece.gd")

const MAP_ID := "ai_generated_fallthrough_lower_deck_test"
const PASS := 0
const FAIL := 1

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run_all")


func _run_all() -> void:
	print("=== Multi-layer surface collision test ===")
	var blueprint = Blueprint.create()
	var blueprint_validation: Dictionary = Validator.validate_blueprint(blueprint)
	if not bool(blueprint_validation.get("ok", false)):
		_fail("blueprint validation failed: %s" % str(blueprint_validation.get("errors", [])))

	var host := Node3D.new()
	root.add_child(host)
	var arena = ArenaScript.new()
	host.add_child(arena)
	var map_root: Node3D = arena.build_map()
	if map_root == null:
		_fail("hand-authored arena build_map returned null")
		_finish()
		return

	var surfaces: Node = map_root.get_node_or_null("GameplayLayer/Surfaces")
	if surfaces == null:
		_fail("GameplayLayer/Surfaces missing")
	else:
		_test_surface_pieces(surfaces)

	var definition: RaceMapDefinition = MapCatalog.load_definition_by_id(MAP_ID)
	if definition == null:
		_fail("missing RaceMapDefinition for %s" % MAP_ID)

	var collision_errors: Array[String] = Audit.validate_generated_collision(
		map_root, blueprint, definition
	)
	for error in collision_errors:
		_fail(error)

	var probe_errors: Array[String] = Audit.probe_multi_layer_fallthrough(
		map_root, blueprint, definition
	)
	for error in probe_errors:
		_fail(error)

	if definition != null and definition.out_of_bounds_min_y >= blueprint.deck_y - 3.5 - 1.0:
		_fail(
			"out_of_bounds_min_y %.2f should be below lower recovery deck"
			% definition.out_of_bounds_min_y
		)

	var visual_layer: Node = map_root.get_node_or_null("VisualLayer")
	if visual_layer != null:
		for child in visual_layer.get_children():
			if str(child.name).to_lower().contains("water"):
				_fail("hand-authored arena must not place water void visuals")

	print("fallthrough_lower_deck_test surface collision passed")
	host.queue_free()
	_finish()


func _test_surface_pieces(surfaces: Node) -> void:
	var layer_counts: Dictionary = {}
	var has_map_surface_piece: bool = false
	for child in surfaces.get_children():
		if child is StaticBody3D and child.get_script() == MapSurfacePieceScript:
			has_map_surface_piece = true
			var piece: StaticBody3D = child as StaticBody3D
			var layer_index: int = int(piece.get("surface_layer_index"))
			layer_counts[layer_index] = int(layer_counts.get(layer_index, 0)) + 1
			for shape_child in piece.get_children():
				if shape_child is CollisionShape3D:
					if not ((shape_child as CollisionShape3D).shape is BoxShape3D):
						_fail("surface piece '%s' must use BoxShape3D" % piece.name)
	if not has_map_surface_piece:
		_fail("Surfaces has no MapSurfacePiece nodes")
	if int(layer_counts.get(0, 0)) < 2:
		_fail("expected at least 2 primary-layer wing surfaces")
	if int(layer_counts.get(1, 0)) < 1:
		_fail("expected at least 1 lower-layer recovery surface")


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
