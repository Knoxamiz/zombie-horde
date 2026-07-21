class_name RaceNavigationWorld
extends Node

## Runtime navigation authority for a loaded race map.
##
## Walkable map pieces opt in through MapSurfacePiece.NAVIGATION_GROUP. This
## keeps navigation geometry aligned with collision: maps declare surfaces,
## this service turns those surfaces into Godot NavigationRegions, and runners
## use NavigationAgent3D for local avoidance. The authored RaceCoursePath is
## the global course authority, so a stacked map can never route a runner
## toward a different deck simply because it is spatially closer.

const MapSurfacePieceScript := preload("res://scripts/maps/map_surface_piece.gd")

signal navigation_ready

var _map_root: Node3D
var _definition: RaceMapDefinition
var _regions: Array[NavigationRegion3D] = []
var _links: Array[NavigationLink3D] = []
var _race_course_path: Path3D
var _surface_descriptors: Array[Dictionary] = []
var _surface_count: int = 0
var _ready_for_agents: bool = false


func configure(map_root: Node3D, definition: RaceMapDefinition) -> void:
	_map_root = map_root
	_definition = definition
	_build_race_course_path()
	call_deferred("rebuild")


func _build_race_course_path() -> void:
	if _map_root == null or not is_instance_valid(_map_root) or _definition == null:
		return

	_race_course_path = _map_root.get_node_or_null("RaceCoursePath") as Path3D
	if _race_course_path == null:
		_race_course_path = Path3D.new()
		_race_course_path.name = "RaceCoursePath"
		_map_root.add_child(_race_course_path)

	var authored_points: PackedVector3Array = _definition.get_effective_race_path()

	var curve := Curve3D.new()
	curve.bake_interval = 0.5
	for world_point in authored_points:
		curve.add_point(_map_root.to_local(world_point))
	_race_course_path.curve = curve


func rebuild() -> void:
	_clear_regions()
	_ready_for_agents = false
	if _map_root == null or not is_instance_valid(_map_root):
		return

	var surfaces: Array[StaticBody3D] = []
	_collect_navigation_surfaces(_map_root, surfaces)
	for surface in surfaces:
		var descriptor: Dictionary = _build_region_for_surface(surface)
		if descriptor.is_empty():
			continue
		_regions.append(descriptor["region"] as NavigationRegion3D)
		_surface_descriptors.append(descriptor)
	_build_surface_links()

	_surface_count = _regions.size()
	if _regions.is_empty():
		push_warning("RaceNavigationWorld found no navigable walk surfaces for %s" % _map_root.name)
		return

	# Adjacent authored pieces often overlap slightly at corners. The margin joins
	# those seams without linking the deliberately separated stacked decks.
	var navigation_map: RID = _regions[0].get_navigation_map()
	if navigation_map.is_valid():
		NavigationServer3D.map_set_edge_connection_margin(navigation_map, 3.0)
	for _frame in range(16):
		await get_tree().physics_frame
		if NavigationServer3D.map_get_iteration_id(navigation_map) > 0:
			_ready_for_agents = true
			break
	if _ready_for_agents:
		navigation_ready.emit()


func is_ready_for_agents() -> bool:
	return _ready_for_agents


func get_surface_count() -> int:
	return _surface_count


func get_link_count() -> int:
	return _links.size()


func _collect_navigation_surfaces(node: Node, result: Array[StaticBody3D]) -> void:
	if node is StaticBody3D and _is_navigation_surface(node):
		result.append(node as StaticBody3D)
	for child in node.get_children():
		_collect_navigation_surfaces(child, result)


func _is_navigation_surface(node: Node) -> bool:
	if node.is_in_group(MapSurfacePieceScript.NAVIGATION_GROUP):
		return true
	# Scene-authored groups are available immediately after instancing, while
	# runtime group registration occurs in _ready. Support both without naming
	# a specific map or road node.
	for group_name in node.get_groups():
		if str(group_name) == MapSurfacePieceScript.NAVIGATION_GROUP:
			return true
	return false


func _build_region_for_surface(surface: StaticBody3D) -> Dictionary:
	var collision: CollisionShape3D = _find_box_collision(surface)
	if collision == null or not collision.shape is BoxShape3D:
		return {}

	var box: BoxShape3D = collision.shape as BoxShape3D
	var size: Vector3 = box.size
	if size.x <= 0.1 or size.z <= 0.1:
		return {}

	var mesh := NavigationMesh.new()
	mesh.agent_radius = 0.32
	mesh.agent_height = 1.25
	mesh.agent_max_climb = 0.8
	mesh.agent_max_slope = 52.0
	var top_y: float = size.y * 0.5
	mesh.vertices = PackedVector3Array([
		Vector3(-size.x * 0.5, top_y, -size.z * 0.5),
		Vector3(size.x * 0.5, top_y, -size.z * 0.5),
		Vector3(size.x * 0.5, top_y, size.z * 0.5),
		Vector3(-size.x * 0.5, top_y, size.z * 0.5),
	])
	mesh.add_polygon(PackedInt32Array([0, 1, 2, 3]))

	var region := NavigationRegion3D.new()
	region.name = "RaceNavigationRegion"
	region.navigation_mesh = mesh
	region.use_edge_connections = true
	region.transform = collision.transform
	surface.add_child(region)
	var world_transform: Transform3D = surface.global_transform * collision.transform
	var local_corners: Array[Vector3] = [
		Vector3(-size.x * 0.5, top_y, -size.z * 0.5),
		Vector3(size.x * 0.5, top_y, -size.z * 0.5),
		Vector3(size.x * 0.5, top_y, size.z * 0.5),
		Vector3(-size.x * 0.5, top_y, size.z * 0.5),
	]
	var min_x: float = INF
	var max_x: float = -INF
	var min_y: float = INF
	var max_y: float = -INF
	var min_z: float = INF
	var max_z: float = -INF
	for local_corner in local_corners:
		var corner: Vector3 = world_transform * local_corner
		min_x = minf(min_x, corner.x)
		max_x = maxf(max_x, corner.x)
		min_y = minf(min_y, corner.y)
		max_y = maxf(max_y, corner.y)
		min_z = minf(min_z, corner.z)
		max_z = maxf(max_z, corner.z)
	return {
		"region": region,
		"top_center": world_transform * Vector3(0.0, top_y, 0.0),
		"min_x": min_x,
		"max_x": max_x,
		"min_y": min_y,
		"max_y": max_y,
		"min_z": min_z,
		"max_z": max_z,
	}


func _build_surface_links() -> void:
	for first_index in range(_surface_descriptors.size()):
		for second_index in range(first_index + 1, _surface_descriptors.size()):
			var first: Dictionary = _surface_descriptors[first_index]
			var second: Dictionary = _surface_descriptors[second_index]
			if not _surfaces_touch(first, second):
				continue
			var link := NavigationLink3D.new()
			link.name = "RaceNavigationSurfaceLink"
			link.start_position = _map_root.to_local(first["top_center"] as Vector3)
			link.end_position = _map_root.to_local(second["top_center"] as Vector3)
			link.bidirectional = true
			_map_root.add_child(link)
			_links.append(link)


func _surfaces_touch(first: Dictionary, second: Dictionary) -> bool:
	var horizontal_gap_x: float = maxf(
		maxf(float(first["min_x"]) - float(second["max_x"]), 0.0),
		maxf(float(second["min_x"]) - float(first["max_x"]), 0.0)
	)
	var horizontal_gap_z: float = maxf(
		maxf(float(first["min_z"]) - float(second["max_z"]), 0.0),
		maxf(float(second["min_z"]) - float(first["max_z"]), 0.0)
	)
	if Vector2(horizontal_gap_x, horizontal_gap_z).length() > 0.25:
		return false
	var first_min_y: float = float(first["min_y"])
	var first_max_y: float = float(first["max_y"])
	var second_min_y: float = float(second["min_y"])
	var second_max_y: float = float(second["max_y"])
	return first_max_y + 0.45 >= second_min_y and second_max_y + 0.45 >= first_min_y


func _find_box_collision(surface: StaticBody3D) -> CollisionShape3D:
	for child in surface.get_children():
		if child is CollisionShape3D and (child as CollisionShape3D).shape is BoxShape3D:
			return child as CollisionShape3D
	return null


func _clear_regions() -> void:
	for region in _regions:
		if is_instance_valid(region):
			region.queue_free()
	_regions.clear()
	for link in _links:
		if is_instance_valid(link):
			link.queue_free()
	_links.clear()
	_surface_descriptors.clear()
	_surface_count = 0
