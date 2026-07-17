@tool
class_name SpiralRampArena
extends Node3D

const MAT_ROAD_ASPHALT := preload("res://assets/materials/road_asphalt.tres")
const MAT_ROAD_LINE := preload("res://assets/materials/road_line.tres")
const MAT_ARENA_GROUND := preload("res://assets/materials/arena_ground.tres")
const MAT_CONCRETE := preload("res://assets/materials/base_concrete.tres")
const MAT_CITY_DARK := preload("res://assets/materials/city_building_dark.tres")
const MAT_CITY_MID := preload("res://assets/materials/city_building_mid.tres")
const MAT_WINDOW_GLOW := preload("res://assets/materials/city_window_glow.tres")
const MAT_WARNING := preload("res://assets/materials/obstacle_warning.tres")
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
const RAIL_END_INSET: float = 6.4

var _visual_root: Node3D
var _collision_root: Node3D
var _atmosphere_material: StandardMaterial3D
var _generated_name_counts: Dictionary = {}


func _ready() -> void:
	ensure_built()


func ensure_built() -> void:
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
	_generated_name_counts.clear()
	_collision_root = _make_child("KitSurfaces", self)
	_visual_root = _make_child("VisualKit", self)
	var points: PackedVector3Array = build_path_points()
	_build_environment_dressing(points)
	_build_center_column()
	_build_road_segments(points)
	_build_road_markings(points)
	_build_corner_decks(points)
	_build_safety_rails(points)
	_build_corner_barrier_walls(points)
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


func _build_environment_dressing(points: PackedVector3Array) -> void:
	_build_ground_plane()
	_build_ground_level_pillars()
	_build_route_support_pillars(points)
	_build_neighboring_sight_blockers()
	_build_atmosphere_bands()


func _build_ground_plane() -> void:
	_add_visual_box(
		"SpiralGroundPad",
		Vector3(168.0, 0.5, 168.0),
		Vector3(0.0, -0.58, 0.0),
		0.0,
		0.0,
		MAT_ARENA_GROUND
	)
	_add_visual_box(
		"SpiralGroundWarningStripe",
		Vector3(150.0, 0.04, 1.2),
		Vector3(0.0, -0.28, -66.0),
		0.0,
		0.0,
		MAT_WARNING
	)
	_add_visual_box(
		"SpiralGroundWarningStripe",
		Vector3(150.0, 0.04, 1.2),
		Vector3(0.0, -0.28, 66.0),
		0.0,
		0.0,
		MAT_WARNING
	)


func _build_ground_level_pillars() -> void:
	var pillar_height: float = TOP_Y + 5.0
	var pillar_positions: Array[Vector3] = [
		Vector3(-64.0, pillar_height * 0.5 - 0.4, -64.0),
		Vector3(64.0, pillar_height * 0.5 - 0.4, -64.0),
		Vector3(64.0, pillar_height * 0.5 - 0.4, 64.0),
		Vector3(-64.0, pillar_height * 0.5 - 0.4, 64.0),
	]
	for position: Vector3 in pillar_positions:
		_add_visual_box(
			"SpiralGroundPillar",
			Vector3(2.8, pillar_height, 2.8),
			position,
			0.0,
			0.0,
			MAT_CONCRETE
		)
		_add_visual_box(
			"SpiralGroundPillarBase",
			Vector3(5.2, 0.8, 5.2),
			Vector3(position.x, -0.1, position.z),
			0.0,
			0.0,
			MAT_CITY_DARK
		)


func _build_route_support_pillars(points: PackedVector3Array) -> void:
	var support_offset: float = ROAD_WIDTH * 0.38
	for index in range(0, points.size(), 2):
		var point: Vector3 = points[index]
		if point.y <= 1.0:
			continue
		var support_height: float = maxf(point.y, 1.0)
		for x_side in [-1.0, 1.0]:
			for z_side in [-1.0, 1.0]:
				var position := Vector3(
					point.x + support_offset * x_side,
					support_height * 0.5 - 0.35,
					point.z + support_offset * z_side
				)
				_add_visual_box(
					"SpiralRouteSupportPillar",
					Vector3(0.72, support_height, 0.72),
					position,
					0.0,
					0.0,
					MAT_CONCRETE
				)


func _build_neighboring_sight_blockers() -> void:
	var blockers: Array[Dictionary] = [
		{"position": Vector3(-92.0, 19.0, -58.0), "size": Vector3(18.0, 38.0, 28.0)},
		{"position": Vector3(-92.0, 25.0, 4.0), "size": Vector3(22.0, 50.0, 34.0)},
		{"position": Vector3(-92.0, 16.0, 56.0), "size": Vector3(16.0, 32.0, 24.0)},
		{"position": Vector3(92.0, 21.0, -44.0), "size": Vector3(20.0, 42.0, 30.0)},
		{"position": Vector3(92.0, 27.0, 18.0), "size": Vector3(24.0, 54.0, 36.0)},
		{"position": Vector3(92.0, 18.0, 66.0), "size": Vector3(18.0, 36.0, 22.0)},
		{"position": Vector3(-42.0, 22.0, 92.0), "size": Vector3(32.0, 44.0, 18.0)},
		{"position": Vector3(30.0, 28.0, 92.0), "size": Vector3(38.0, 56.0, 20.0)},
		{"position": Vector3(-22.0, 24.0, -92.0), "size": Vector3(34.0, 48.0, 18.0)},
		{"position": Vector3(48.0, 17.0, -92.0), "size": Vector3(26.0, 34.0, 18.0)},
	]
	for index in range(blockers.size()):
		var blocker: Dictionary = blockers[index]
		var position: Vector3 = blocker["position"]
		var size: Vector3 = blocker["size"]
		var material: Material = MAT_CITY_DARK if index % 2 == 0 else MAT_CITY_MID
		_add_visual_box("SpiralSightBlocker", size, position, 0.0, 0.0, material)
		_add_window_strips(position, size, index)


func _add_window_strips(building_position: Vector3, building_size: Vector3, seed_index: int) -> void:
	var side_sign: float = 1.0 if building_position.x < 0.0 else -1.0
	var strip_count: int = 3
	for strip_index in range(strip_count):
		var y: float = building_position.y - building_size.y * 0.26 + float(strip_index) * building_size.y * 0.24
		var z_offset: float = -building_size.z * 0.28 + float((strip_index + seed_index) % 3) * building_size.z * 0.28
		var position := Vector3(
			building_position.x + side_sign * (building_size.x * 0.5 + 0.035),
			y,
			building_position.z + z_offset
		)
		_add_visual_box(
			"SpiralWindowGlowStrip",
			Vector3(0.08, 0.42, building_size.z * 0.24),
			position,
			0.0,
			0.0,
			MAT_WINDOW_GLOW
		)


func _build_atmosphere_bands() -> void:
	var material: StandardMaterial3D = _get_atmosphere_material()
	var bands: Array[Dictionary] = [
		{"position": Vector3(0.0, 9.0, -84.0), "size": Vector3(156.0, 14.0, 0.8)},
		{"position": Vector3(0.0, 13.0, 84.0), "size": Vector3(156.0, 18.0, 0.8)},
		{"position": Vector3(-84.0, 17.0, 0.0), "size": Vector3(0.8, 22.0, 156.0)},
		{"position": Vector3(84.0, 15.0, 0.0), "size": Vector3(0.8, 20.0, 156.0)},
	]
	for band: Dictionary in bands:
		_add_visual_box(
			"SpiralAtmosphereBand",
			band["size"],
			band["position"],
			0.0,
			0.0,
			material
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
			pitch,
			true
		)
		_add_visual_box(
			"SpiralRoadDeck",
			Vector3(ROAD_WIDTH, ROAD_THICKNESS * 0.72, length + 0.32),
			center + Vector3.UP * 0.02,
			yaw,
			pitch,
			MAT_ROAD_ASPHALT
		)


func _build_road_markings(points: PackedVector3Array) -> void:
	for index in range(points.size() - 1):
		var a: Vector3 = points[index]
		var b: Vector3 = points[index + 1]
		var delta: Vector3 = b - a
		var horizontal_length: float = Vector2(delta.x, delta.z).length()
		var raw_length: float = maxf(delta.length(), 0.5)
		var direction: Vector3 = delta.normalized()
		var inset: float = minf(SEGMENT_END_INSET + 1.8, raw_length * 0.28)
		var adjusted_a: Vector3 = a + direction * inset
		var adjusted_b: Vector3 = b - direction * inset
		var center: Vector3 = (adjusted_a + adjusted_b) * 0.5
		var length: float = maxf(adjusted_a.distance_to(adjusted_b), 0.5)
		var yaw: float = atan2(delta.x, delta.z)
		var pitch: float = -atan2(delta.y, horizontal_length)
		_add_visual_box(
			"SpiralRoadCenterLine",
			Vector3(0.18, 0.045, length),
			center + Vector3.UP * 0.28,
			yaw,
			pitch,
			MAT_ROAD_LINE
		)


func _build_corner_decks(points: PackedVector3Array) -> void:
	for point: Vector3 in points:
		_add_collision_box(
			"SpiralCornerDeck",
			Vector3(ROAD_WIDTH, ROAD_THICKNESS, ROAD_WIDTH),
			point,
			0.0,
			0.0,
			true
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
		var inset: float = minf(RAIL_END_INSET, raw_length * 0.3)
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
				Vector3(EDGE_BARRIER_THICKNESS, EDGE_BARRIER_HEIGHT, length),
				rail_position,
				yaw,
				pitch
			)
			_add_visual_box(
				"SpiralEdgeBarrierVisual",
				Vector3(EDGE_BARRIER_THICKNESS, EDGE_BARRIER_HEIGHT, length),
				rail_position,
				yaw,
				pitch,
				MAT_CONCRETE
			)


func _build_corner_barrier_walls(points: PackedVector3Array) -> void:
	var wall_offset: float = ROAD_WIDTH * 0.5 + EDGE_BARRIER_THICKNESS * 0.5
	var wall_directions: Array[Vector3] = [
		Vector3.RIGHT,
		Vector3.LEFT,
		Vector3.FORWARD,
		Vector3.BACK,
	]
	for index in range(points.size()):
		var point: Vector3 = points[index]
		var openings: Array[Vector3] = _corner_opening_directions(points, index)
		for normal: Vector3 in wall_directions:
			if _has_corner_opening(openings, normal):
				continue
			var tangent := Vector3(-normal.z, 0.0, normal.x).normalized()
			var yaw: float = atan2(tangent.x, tangent.z)
			var wall_position := Vector3(
				point.x + normal.x * wall_offset,
				point.y + EDGE_BARRIER_HEIGHT * 0.5 + 0.16,
				point.z + normal.z * wall_offset
			)
			_add_collision_box(
				"SpiralCornerBarrierWall",
				Vector3(EDGE_BARRIER_THICKNESS, EDGE_BARRIER_HEIGHT, ROAD_WIDTH),
				wall_position,
				yaw,
				0.0
			)
			_add_visual_box(
				"SpiralCornerBarrierWallVisual",
				Vector3(EDGE_BARRIER_THICKNESS, EDGE_BARRIER_HEIGHT, ROAD_WIDTH),
				wall_position,
				yaw,
				0.0,
				MAT_CONCRETE
			)


func _corner_opening_directions(points: PackedVector3Array, point_index: int) -> Array[Vector3]:
	var openings: Array[Vector3] = []
	var point: Vector3 = points[point_index]
	if point_index > 0:
		var previous_direction: Vector3 = _horizontal_cardinal_direction(points[point_index - 1] - point)
		if previous_direction != Vector3.ZERO:
			openings.append(previous_direction)
	if point_index < points.size() - 1:
		var next_direction: Vector3 = _horizontal_cardinal_direction(points[point_index + 1] - point)
		if next_direction != Vector3.ZERO:
			openings.append(next_direction)
	return openings


func _horizontal_cardinal_direction(delta: Vector3) -> Vector3:
	if absf(delta.x) >= absf(delta.z):
		if absf(delta.x) <= 0.001:
			return Vector3.ZERO
		return Vector3.RIGHT if delta.x > 0.0 else Vector3.LEFT
	if absf(delta.z) <= 0.001:
		return Vector3.ZERO
	return Vector3.BACK if delta.z > 0.0 else Vector3.FORWARD


func _has_corner_opening(openings: Array[Vector3], direction: Vector3) -> bool:
	for opening: Vector3 in openings:
		if opening.dot(direction) > 0.99:
			return true
	return false


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
		label.name = _next_generated_name("SpiralLevelLabel")
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
	pitch: float,
	is_navigation_surface: bool = false
) -> void:
	var body := StaticBody3D.new()
	body.name = _next_generated_name(box_name)
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = position
	body.rotation = Vector3(pitch, yaw, 0.0)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	if is_navigation_surface:
		body.add_to_group("race_navigation_surfaces")
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
	mesh_instance.name = _next_generated_name(box_name)
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


func _next_generated_name(family_name: String) -> String:
	# Generated siblings are named deterministically so the editor tree and
	# map validation can identify every physical piece without ambiguity.
	var next_index: int = int(_generated_name_counts.get(family_name, 0)) + 1
	_generated_name_counts[family_name] = next_index
	return "%s_%02d" % [family_name, next_index]


func _get_atmosphere_material() -> StandardMaterial3D:
	if _atmosphere_material != null:
		return _atmosphere_material
	_atmosphere_material = StandardMaterial3D.new()
	_atmosphere_material.albedo_color = Color(0.08, 0.16, 0.18, 0.32)
	_atmosphere_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_atmosphere_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return _atmosphere_material
