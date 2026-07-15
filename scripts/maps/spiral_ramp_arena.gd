@tool
class_name SpiralRampArena
extends Node3D

const MAT_ROAD_ASPHALT := preload("res://assets/materials/road_asphalt.tres")
const MAT_CONCRETE := preload("res://assets/materials/base_concrete.tres")
const MAT_CITY_MID := preload("res://assets/materials/city_building_mid.tres")
const MAT_SPAWN := preload("res://assets/materials/spawn_zone.tres")
const MAT_GOAL := preload("res://assets/materials/goal_zone.tres")

const ROAD_WIDTH: float = 8.0
const ROAD_THICKNESS: float = 0.42
const HALF_EXTENT: float = 54.0
const TOP_Y: float = 42.0
const BOTTOM_Y: float = 0.0
const LAYER_COUNT: int = 4
const EDGE_BARRIER_HEIGHT: float = 0.86
const EDGE_BARRIER_THICKNESS: float = 0.34
const SEGMENT_END_INSET: float = 3.8

var _visual_root: Node3D
var _collision_root: Node3D


func _ready() -> void:
	_build()


static func build_path_points() -> PackedVector3Array:
	var points := PackedVector3Array()
	var layer_step: float = (TOP_Y - BOTTOM_Y) / float(LAYER_COUNT)
	points.append(Vector3(-HALF_EXTENT, TOP_Y, -HALF_EXTENT))
	for layer_index in range(LAYER_COUNT):
		var y: float = TOP_Y - layer_step * float(layer_index)
		var next_y: float = maxf(BOTTOM_Y, y - layer_step)
		points.append(Vector3(HALF_EXTENT, y, -HALF_EXTENT))
		points.append(Vector3(HALF_EXTENT, y, HALF_EXTENT))
		points.append(Vector3(-HALF_EXTENT, y, HALF_EXTENT))
		points.append(Vector3(-HALF_EXTENT, next_y, -HALF_EXTENT))
	points.append(Vector3(HALF_EXTENT, BOTTOM_Y, -HALF_EXTENT))
	return points


func _build() -> void:
	_clear_generated_roots()
	_collision_root = _make_child("KitSurfaces", self)
	_visual_root = _make_child("VisualKit", self)
	var points: PackedVector3Array = build_path_points()
	_build_center_column()
	_build_road_segments(points)
	_build_corner_decks(points)
	_build_safety_rails(points)
	_build_corner_barrier_posts(points)
	_build_markers(points)
	_build_level_labels(points)


func _clear_generated_roots() -> void:
	for child_name in ["KitSurfaces", "VisualKit"]:
		var child: Node = get_node_or_null(child_name)
		if child != null:
			remove_child(child)
			child.free()


func _build_center_column() -> void:
	_add_visual_box(
		"SpiralCoreColumn",
		Vector3(3.2, TOP_Y - BOTTOM_Y + 4.0, 3.2),
		Vector3(0.0, (TOP_Y + BOTTOM_Y) * 0.5 + 1.3, 0.0),
		0.0,
		0.0,
		MAT_CITY_MID
	)


func _build_road_segments(points: PackedVector3Array) -> void:
	for index in range(points.size() - 1):
		var a: Vector3 = points[index]
		var b: Vector3 = points[index + 1]
		var delta: Vector3 = b - a
		var horizontal_length: float = Vector2(delta.x, delta.z).length()
		var raw_length: float = maxf(delta.length(), 0.5)
		var direction: Vector3 = delta.normalized()
		var inset: float = minf(SEGMENT_END_INSET, raw_length * 0.22)
		var adjusted_a: Vector3 = a + direction * inset
		var adjusted_b: Vector3 = b - direction * inset
		var center: Vector3 = (adjusted_a + adjusted_b) * 0.5
		var length: float = maxf(adjusted_a.distance_to(adjusted_b), 0.5)
		var yaw: float = atan2(delta.x, delta.z)
		var pitch: float = -atan2(delta.y, horizontal_length)
		_add_collision_box(
			"SpiralRampSurface",
			Vector3(ROAD_WIDTH, ROAD_THICKNESS, length + 0.22),
			center,
			yaw,
			pitch
		)
		_add_visual_box(
			"SpiralRoadDeck",
			Vector3(ROAD_WIDTH, ROAD_THICKNESS * 0.72, length + 0.32),
			center + Vector3.UP * 0.02,
			yaw,
			pitch,
			MAT_ROAD_ASPHALT
		)


func _build_corner_decks(points: PackedVector3Array) -> void:
	for point: Vector3 in points:
		_add_collision_box(
			"SpiralCornerDeck",
			Vector3(ROAD_WIDTH, ROAD_THICKNESS, ROAD_WIDTH),
			point,
			0.0,
			0.0
		)
		_add_visual_box(
			"SpiralCornerDeckVisual",
			Vector3(ROAD_WIDTH, ROAD_THICKNESS * 0.72, ROAD_WIDTH),
			point + Vector3.UP * 0.03,
			0.0,
			0.0,
			MAT_ROAD_ASPHALT
		)


func _build_safety_rails(points: PackedVector3Array) -> void:
	for index in range(points.size() - 1):
		var a: Vector3 = points[index]
		var b: Vector3 = points[index + 1]
		var delta: Vector3 = b - a
		var horizontal_forward := Vector3(delta.x, 0.0, delta.z).normalized()
		var side := Vector3(horizontal_forward.z, 0.0, -horizontal_forward.x).normalized()
		var horizontal_length: float = Vector2(delta.x, delta.z).length()
		var raw_length: float = maxf(delta.length(), 0.5)
		var direction: Vector3 = delta.normalized()
		var inset: float = minf(SEGMENT_END_INSET, raw_length * 0.22)
		var adjusted_a: Vector3 = a + direction * inset
		var adjusted_b: Vector3 = b - direction * inset
		var center: Vector3 = (adjusted_a + adjusted_b) * 0.5
		var length: float = maxf(adjusted_a.distance_to(adjusted_b), 0.5)
		var yaw: float = atan2(delta.x, delta.z)
		var pitch: float = -atan2(delta.y, horizontal_length)
		for rail_side in [-1.0, 1.0]:
			var rail_position: Vector3 = (
				center
				+ side * rail_side * (ROAD_WIDTH * 0.5 + EDGE_BARRIER_THICKNESS * 0.5)
				+ Vector3.UP * (EDGE_BARRIER_HEIGHT * 0.5 + 0.16)
			)
			_add_collision_box(
				"SpiralEdgeBarrier",
				Vector3(EDGE_BARRIER_THICKNESS, EDGE_BARRIER_HEIGHT, length + 0.1),
				rail_position,
				yaw,
				pitch
			)
			_add_visual_box(
				"SpiralEdgeBarrierVisual",
				Vector3(EDGE_BARRIER_THICKNESS, EDGE_BARRIER_HEIGHT, length + 0.1),
				rail_position,
				yaw,
				pitch,
				MAT_CONCRETE
			)


func _build_corner_barrier_posts(points: PackedVector3Array) -> void:
	var post_offset: float = ROAD_WIDTH * 0.5 + EDGE_BARRIER_THICKNESS * 0.5
	for point: Vector3 in points:
		for x_side in [-1.0, 1.0]:
			for z_side in [-1.0, 1.0]:
				var post_position := Vector3(
					point.x + post_offset * x_side,
					point.y + EDGE_BARRIER_HEIGHT * 0.5 + 0.16,
					point.z + post_offset * z_side
				)
				_add_collision_box(
					"SpiralCornerBarrierPost",
					Vector3(EDGE_BARRIER_THICKNESS, EDGE_BARRIER_HEIGHT, EDGE_BARRIER_THICKNESS),
					post_position,
					0.0,
					0.0
				)
				_add_visual_box(
					"SpiralCornerBarrierPostVisual",
					Vector3(EDGE_BARRIER_THICKNESS, EDGE_BARRIER_HEIGHT, EDGE_BARRIER_THICKNESS),
					post_position,
					0.0,
					0.0,
					MAT_CONCRETE
				)


func _build_markers(points: PackedVector3Array) -> void:
	var start: Vector3 = points[0]
	var finish: Vector3 = points[points.size() - 1]
	_add_visual_box("SpawnZone", Vector3(ROAD_WIDTH, 0.08, 4.0), start + Vector3.UP * 0.16, 0.0, 0.0, MAT_SPAWN)
	_add_visual_box("GoalGuide", Vector3(ROAD_WIDTH, 0.08, 4.0), finish + Vector3.UP * 0.16, 0.0, 0.0, MAT_GOAL)


func _build_level_labels(points: PackedVector3Array) -> void:
	for index in range(LAYER_COUNT):
		var point_index: int = min(index * 4, points.size() - 1)
		var point: Vector3 = points[point_index]
		var label := Label3D.new()
		label.name = "SpiralLevelLabel"
		label.text = "LEVEL %d" % (LAYER_COUNT - index)
		label.font_size = 32
		label.outline_size = 8
		label.modulate = Color(0.78, 1.0, 0.2, 1.0)
		label.position = point + Vector3.UP * 1.3
		_visual_root.add_child(label)


func _add_collision_box(
	box_name: String,
	size: Vector3,
	position: Vector3,
	yaw: float,
	pitch: float
) -> void:
	var body := StaticBody3D.new()
	body.name = box_name
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = position
	body.rotation = Vector3(pitch, yaw, 0.0)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	_collision_root.add_child(body)


func _add_visual_box(
	box_name: String,
	size: Vector3,
	position: Vector3,
	yaw: float,
	pitch: float,
	material: Material
) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = box_name
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.position = position
	mesh_instance.rotation = Vector3(pitch, yaw, 0.0)
	mesh_instance.material_override = material
	_visual_root.add_child(mesh_instance)


func _make_child(child_name: String, parent: Node3D) -> Node3D:
	var node := Node3D.new()
	node.name = child_name
	parent.add_child(node)
	return node
