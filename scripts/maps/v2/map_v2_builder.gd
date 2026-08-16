class_name MapV2Builder
extends Node3D

const SURFACE_SCRIPT := preload("res://scripts/maps/map_surface_piece.gd")
const COURSE_SCRIPT := preload("res://scripts/maps/v2/map_v2_course.gd")
const PRIMITIVE_SCRIPT := preload("res://scripts/maps/v2/map_v2_primitive.gd")

@export var course: Resource
@export var build_on_ready: bool = true

var _built: bool = false


func _ready() -> void:
	if build_on_ready:
		build_course()


func build_course() -> bool:
	if _built:
		return true
	if course == null:
		push_error("MapV2Builder requires a MapV2Course")
		return false
	var failures: PackedStringArray = course.validate()
	if not failures.is_empty():
		for failure in failures:
			push_error("MapV2Builder: %s" % failure)
		return false

	var gameplay_layer := Node3D.new()
	gameplay_layer.name = "GameplayLayer"
	add_child(gameplay_layer)
	var surfaces := Node3D.new()
	surfaces.name = "Surfaces"
	gameplay_layer.add_child(surfaces)
	var boundaries := Node3D.new()
	boundaries.name = "Boundaries"
	gameplay_layer.add_child(boundaries)
	var navigation := Node3D.new()
	navigation.name = "Navigation"
	gameplay_layer.add_child(navigation)

	var visual_layer := Node3D.new()
	visual_layer.name = "VisualLayer"
	add_child(visual_layer)
	var playable_visuals := Node3D.new()
	playable_visuals.name = "PlayableSurfaceVisuals"
	visual_layer.add_child(playable_visuals)
	var dressing := Node3D.new()
	dressing.name = "Dressing"
	visual_layer.add_child(dressing)
	var markers := Node3D.new()
	markers.name = "Markers"
	add_child(markers)
	_build_course_markers(markers)

	for primitive in course.primitives:
		match primitive.kind:
			PRIMITIVE_SCRIPT.Kind.DECK, PRIMITIVE_SCRIPT.Kind.RAMP:
				_build_walk_primitive(primitive, surfaces, playable_visuals)
			PRIMITIVE_SCRIPT.Kind.BOUNDARY:
				_build_boundary_primitive(primitive, boundaries, playable_visuals)
			PRIMITIVE_SCRIPT.Kind.GAP:
				pass
	_build_route_path(navigation)

	_built = true
	return true


func get_surface_height_at(x: float, z: float, fallback: float = 0.0) -> float:
	if course == null:
		return fallback
	return course.surface_height_at(x, z, fallback)


func get_playable_bounds() -> AABB:
	return course.get_playable_bounds() if course != null else AABB()


func get_oob_bounds() -> AABB:
	return course.get_oob_bounds() if course != null else AABB()


func _build_route_path(navigation: Node3D) -> void:
	var route := Path3D.new()
	route.name = "SurfaceRoute"
	var curve := Curve3D.new()
	for route_point: Vector3 in course.get_route_points():
		curve.add_point(route_point)
	route.curve = curve
	navigation.add_child(route)


func _build_course_markers(markers: Node3D) -> void:
	var spawn := Marker3D.new()
	spawn.name = "Spawn"
	spawn.position = course.spawn_position
	spawn.set_meta("map_v2_role", "spawn")
	markers.add_child(spawn)
	var finish := Marker3D.new()
	finish.name = "Finish"
	finish.position = course.finish_position
	finish.set_meta("map_v2_role", "finish_marker_only")
	markers.add_child(finish)


func _build_walk_primitive(
	primitive: Resource,
	surfaces: Node3D,
	playable_visuals: Node3D
) -> void:
	var piece: StaticBody3D
	if primitive.kind == PRIMITIVE_SCRIPT.Kind.RAMP:
		piece = SURFACE_SCRIPT.create_ramp(
			primitive.width,
			primitive.length,
			primitive.height_delta,
			primitive.origin.y
		)
	else:
		piece = SURFACE_SCRIPT.create_deck(
			Vector3(primitive.width, primitive.thickness, primitive.length),
			primitive.origin.y
		)
	piece.name = primitive.primitive_id
	piece.position.x += primitive.origin.x
	piece.position.z += primitive.origin.z + primitive.length * 0.5
	piece.segment_id = primitive.primitive_id
	piece.set_meta("map_v2_primitive_id", primitive.primitive_id)
	surfaces.add_child(piece)
	_build_matching_visual(primitive, piece, playable_visuals)


func _build_boundary_primitive(
	primitive: Resource,
	boundaries: Node3D,
	playable_visuals: Node3D
) -> void:
	var body := StaticBody3D.new()
	body.name = primitive.primitive_id
	body.collision_layer = SURFACE_SCRIPT.WALK_COLLISION_LAYER
	body.collision_mask = 0
	body.position = primitive.origin
	body.set_meta("map_v2_primitive_id", primitive.primitive_id)
	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	var box := BoxShape3D.new()
	box.size = Vector3(primitive.width, primitive.thickness, primitive.length)
	collision.shape = box
	body.add_child(collision)
	boundaries.add_child(body)
	_build_matching_visual(primitive, body, playable_visuals)


func _build_matching_visual(
	primitive: Resource,
	body: StaticBody3D,
	playable_visuals: Node3D
) -> void:
	var collision: CollisionShape3D = body.get_node_or_null("Collision") as CollisionShape3D
	var collision_box: BoxShape3D = collision.shape as BoxShape3D if collision != null else null
	if collision_box == null:
		push_error("MapV2Builder: %s has no box collision" % primitive.primitive_id)
		return
	var visual := MeshInstance3D.new()
	visual.name = primitive.primitive_id
	visual.transform = body.transform
	visual.set_meta("map_v2_primitive_id", primitive.primitive_id)
	var mesh := BoxMesh.new()
	mesh.size = collision_box.size
	visual.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = primitive.visual_color
	material.roughness = 0.92
	visual.material_override = material
	playable_visuals.add_child(visual)
