extends SceneTree

const PROTOTYPE := preload("res://scenes/maps/v2_graybox_prototype.tscn")
const COURSE := preload("res://resources/maps/v2_graybox_course.tres")
const PRIMITIVE_SCRIPT := preload("res://scripts/maps/v2/map_v2_primitive.gd")
const SURFACE_SCRIPT := preload("res://scripts/maps/map_surface_piece.gd")

var _failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var prototype: Node3D = PROTOTYPE.instantiate() as Node3D
	root.add_child(prototype)
	await physics_frame

	var surfaces: Node = prototype.get_node_or_null("GameplayLayer/Surfaces")
	var visuals: Node = prototype.get_node_or_null("VisualLayer/PlayableSurfaceVisuals")
	if surfaces == null or visuals == null:
		_fail("V2 prototype is missing its surface or visual container")
		prototype.queue_free()
		_finish()
		return

	var expected_walk_count: int = 0
	for primitive: Resource in COURSE.primitives:
		if primitive.kind == PRIMITIVE_SCRIPT.Kind.GAP:
			if surfaces.get_node_or_null(primitive.primitive_id) != null:
				_fail("Gap %s unexpectedly created collision" % primitive.primitive_id)
			if visuals.get_node_or_null(primitive.primitive_id) != null:
				_fail("Gap %s unexpectedly created a playable visual" % primitive.primitive_id)
			_verify_gap_has_no_surface(prototype, primitive)
			continue
		if primitive.kind == PRIMITIVE_SCRIPT.Kind.BOUNDARY:
			continue
		expected_walk_count += 1
		_verify_pair(primitive, surfaces, visuals)
		_verify_surface_height(prototype, primitive)

	if surfaces.get_child_count() != expected_walk_count:
		_fail(
			"Expected %d V2 walk surfaces, got %d"
			% [expected_walk_count, surfaces.get_child_count()]
		)
	if visuals.get_child_count() != expected_walk_count:
		_fail(
			"Expected %d V2 playable visuals, got %d"
			% [expected_walk_count, visuals.get_child_count()]
		)

	_verify_course_queries(prototype)

	prototype.queue_free()
	_finish()


func _verify_pair(primitive: Resource, surfaces: Node, visuals: Node) -> void:
	var surface: StaticBody3D = surfaces.get_node_or_null(primitive.primitive_id) as StaticBody3D
	var visual: MeshInstance3D = visuals.get_node_or_null(primitive.primitive_id) as MeshInstance3D
	if surface == null or visual == null:
		_fail("Primitive %s is missing matching visual/collision output" % primitive.primitive_id)
		return
	if surface.collision_layer != SURFACE_SCRIPT.WALK_COLLISION_LAYER:
		_fail("Primitive %s is not on walk collision layer 1" % primitive.primitive_id)
	if not surface.is_in_group(SURFACE_SCRIPT.NAVIGATION_GROUP):
		_fail("Primitive %s is missing navigation surface membership" % primitive.primitive_id)
	if not surface.transform.is_equal_approx(visual.transform):
		_fail("Primitive %s visual and collision transforms differ" % primitive.primitive_id)

	var collision: CollisionShape3D = surface.get_node_or_null("Collision") as CollisionShape3D
	var collision_box: BoxShape3D = collision.shape as BoxShape3D if collision != null else null
	var visual_box: BoxMesh = visual.mesh as BoxMesh
	if collision_box == null or visual_box == null:
		_fail("Primitive %s does not use matching box geometry" % primitive.primitive_id)
		return
	if not collision_box.size.is_equal_approx(visual_box.size):
		_fail("Primitive %s visual and collision sizes differ" % primitive.primitive_id)


func _verify_surface_height(prototype: Node3D, primitive: Resource) -> void:
	var sample_x: float = primitive.origin.x
	var sample_z: float = primitive.origin.z + primitive.length * 0.5
	var expected_y: float = primitive.origin.y
	if primitive.kind == PRIMITIVE_SCRIPT.Kind.RAMP:
		expected_y += primitive.height_delta * 0.5
	var hit: Dictionary = _raycast_surface(prototype, sample_x, sample_z)
	if hit.is_empty():
		_fail("Primitive %s has no collision at its visual center" % primitive.primitive_id)
		return
	var hit_position: Vector3 = hit.get("position", Vector3.ZERO)
	if absf(hit_position.y - expected_y) > 0.03:
		_fail(
			"Primitive %s collision height %.3f differs from authored visual height %.3f"
			% [primitive.primitive_id, hit_position.y, expected_y]
		)


func _verify_gap_has_no_surface(prototype: Node3D, primitive: Resource) -> void:
	var sample_x: float = primitive.origin.x
	var sample_z: float = primitive.origin.z + primitive.length * 0.5
	if not _raycast_surface(prototype, sample_x, sample_z).is_empty():
		_fail("Gap %s has an invisible collision surface" % primitive.primitive_id)


func _raycast_surface(prototype: Node3D, x: float, z: float) -> Dictionary:
	var world: World3D = prototype.get_world_3d()
	if world == null:
		return {}
	var query := PhysicsRayQueryParameters3D.create(
		Vector3(x, 24.0, z),
		Vector3(x, -12.0, z),
		SURFACE_SCRIPT.WALK_COLLISION_LAYER
	)
	query.collide_with_areas = false
	return world.direct_space_state.intersect_ray(query)


func _verify_course_queries(prototype: Node3D) -> void:
	if not COURSE.has_surface_at(COURSE.spawn_position.x, COURSE.spawn_position.z):
		_fail("V2 spawn is not on an authoritative course surface")
	if not COURSE.has_surface_at(COURSE.finish_position.x, COURSE.finish_position.z):
		_fail("V2 finish is not on an authoritative course surface")
	var ramp_mid_y: float = COURSE.surface_height_at(0.0, -9.0, -999.0)
	if absf(ramp_mid_y - 1.0) > 0.01:
		_fail("V2 ramp midpoint query returned %.3f instead of 1.0" % ramp_mid_y)
	if COURSE.has_surface_at(0.0, 16.0):
		_fail("V2 surface query reports solid ground inside the authored gap")

	var builder = prototype
	var playable_bounds: AABB = builder.get_playable_bounds()
	var oob_bounds: AABB = builder.get_oob_bounds()
	var expected_playable := AABB(Vector3(-6.0, 0.0, -30.0), Vector3(12.0, 2.0, 64.0))
	if not playable_bounds.is_equal_approx(expected_playable):
		_fail("V2 playable bounds %s differ from expected %s" % [playable_bounds, expected_playable])
	if absf(oob_bounds.position.x + 8.0) > 0.01 or absf(oob_bounds.end.x - 8.0) > 0.01:
		_fail("V2 OOB width was not derived from playable bounds plus margin")
	if absf(oob_bounds.position.z + 32.0) > 0.01 or absf(oob_bounds.end.z - 36.0) > 0.01:
		_fail("V2 OOB length was not derived from playable bounds plus margin")


func _fail(message: String) -> void:
	_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("MapV2SurfaceParityTest: PASSED")
		quit(0)
		return
	print("MapV2SurfaceParityTest: FAILED")
	for failure in _failures:
		push_error(failure)
	quit(1)
