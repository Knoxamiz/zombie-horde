class_name MapKitBuilder
extends RefCounted

const CELL_VOID := MapBlueprint.CELL_VOID
const CELL_SAFE_ROAD := MapBlueprint.CELL_SAFE_ROAD
const CELL_ROAD := MapBlueprint.CELL_ROAD
const CELL_CRACK_ROAD := MapBlueprint.CELL_CRACK_ROAD
const CELL_BROKEN_EDGE := MapBlueprint.CELL_BROKEN_EDGE
const CELL_GAP_VISUAL := MapBlueprint.CELL_GAP_VISUAL
const CELL_LEFT_RAIL := MapBlueprint.CELL_LEFT_RAIL
const CELL_RIGHT_RAIL := MapBlueprint.CELL_RIGHT_RAIL
const CELL_CONE := MapBlueprint.CELL_CONE
const CELL_BARRIER := MapBlueprint.CELL_BARRIER
const CELL_DEBRIS := MapBlueprint.CELL_DEBRIS
const CELL_LIGHT := MapBlueprint.CELL_LIGHT
const CELL_CONTAINER := MapBlueprint.CELL_CONTAINER
const CELL_HAZARD := MapBlueprint.CELL_HAZARD
const CELL_SPAWN := MapBlueprint.CELL_SPAWN
const CELL_GOAL := MapBlueprint.CELL_GOAL

const MAT_SPAWN := preload("res://assets/materials/spawn_zone.tres")
const MAT_GOAL := preload("res://assets/materials/goal_zone.tres")
const MAT_DEBUG_FLOOR := preload("res://assets/materials/road_asphalt.tres")
const MAT_DEBUG_HAZARD := preload("res://assets/materials/obstacle_warning.tres")
const SCRIPT_VOID_KILL := preload("res://scripts/maps/bridge_void_kill_zone.gd")

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _map_root: Node3D
var _visual_layer: Node3D
var _gameplay_layer: Node3D
var _debug_layer: Node3D
var _debug_visible: bool = false
var _show_safe_floor: bool = false
var _show_hazards: bool = false


func build_from_blueprint(blueprint: MapBlueprint, parent: Node3D) -> Node3D:
	clear_existing_generated_map(parent)
	if blueprint == null:
		return null

	_rng.seed = blueprint.seed
	_map_root = Node3D.new()
	_map_root.name = "MapRoot"
	parent.add_child(_map_root)

	_visual_layer = _make_child("VisualLayer", _map_root)
	_gameplay_layer = _make_child("GameplayLayer", _map_root)
	_debug_layer = _make_child("DebugLayer", _map_root)
	_debug_layer.visible = _debug_visible

	build_visual_layer(_visual_layer, blueprint)
	build_gameplay_layer(_gameplay_layer, blueprint)
	build_debug_layer(_debug_layer, blueprint)
	return _map_root


func clear_existing_generated_map(parent: Node3D) -> void:
	if parent == null:
		return
	var existing: Node = parent.get_node_or_null("MapRoot")
	if existing != null:
		existing.queue_free()


func build_visual_layer(root: Node3D, blueprint: MapBlueprint) -> void:
	if root == null or blueprint == null:
		return

	var road_tiles := _make_child("RoadTiles", root)
	var damage_tiles := _make_child("DamageTiles", root)
	var barriers := _make_child("Barriers", root)
	var cones := _make_child("Cones", root)
	var rails := _make_child("Rails", root)
	var lights := _make_child("Lights", root)
	var debris := _make_child("Debris", root)
	var containers := _make_child("Containers", root)
	var background := _make_child("Background", root)

	_build_water_void(background, blueprint)

	for row_index in range(blueprint.get_row_count()):
		for column_index in range(blueprint.visual_width_tiles):
			var cell: Dictionary = blueprint.get_cell(row_index, column_index)
			var cell_type: String = str(cell.get("type", CELL_VOID))
			if cell_type == CELL_VOID:
				continue

			var position: Vector3 = Vector3(
				blueprint.column_to_x(column_index) + float(cell.get("offset_x", 0.0)),
				float(cell.get("offset_y", 0.0)),
				blueprint.row_to_z(row_index) + float(cell.get("offset_z", 0.0))
			)
			var rotation: float = float(cell.get("rotation", 0.0))
			var scale_value: float = float(cell.get("scale", 1.0))
			var asset_id: String = str(cell.get("asset_id", ""))
			if asset_id.is_empty():
				asset_id = _default_asset_for_cell(cell_type)

			var parent_bucket: Node3D = road_tiles
			match cell_type:
				CELL_CRACK_ROAD, CELL_BROKEN_EDGE:
					parent_bucket = damage_tiles
				CELL_BARRIER:
					parent_bucket = barriers
				CELL_CONE:
					parent_bucket = cones
				CELL_LEFT_RAIL, CELL_RIGHT_RAIL:
					parent_bucket = rails
				CELL_LIGHT:
					parent_bucket = lights
				CELL_DEBRIS:
					parent_bucket = debris
				CELL_CONTAINER:
					parent_bucket = containers
				CELL_GAP_VISUAL:
					continue
				_:
					parent_bucket = road_tiles

			var instance: Node3D = add_visual_asset(asset_id, position, rotation, scale_value, parent_bucket)
			if instance != null and bool(cell.get("no_collision", true)):
				sanitize_visual_instance(instance)


func build_gameplay_layer(root: Node3D, blueprint: MapBlueprint) -> void:
	if root == null or blueprint == null:
		return

	var safe_floor := _make_child("SafeFloor", root)
	var hazard_zones := _make_child("HazardZones", root)
	var oob_zones := _make_child("OOBZones", root)
	var spawn_zone := _make_child("SpawnZone", root)
	var goal_zone := _make_child("GoalZone", root)

	for plate in blueprint.gameplay_plates:
		var size: Vector3 = plate.get("size", Vector3(8, 0.12, 8))
		var position: Vector3 = plate.get("position", Vector3.ZERO)
		add_safe_floor_plate(position, size, safe_floor)

	if blueprint.gameplay_plates.is_empty():
		_build_default_safe_floor(safe_floor, blueprint)

	for hazard in blueprint.hazard_zones:
		var size: Vector3 = hazard.get("size", Vector3(8, 4, 8))
		var position: Vector3 = hazard.get("position", Vector3.ZERO)
		add_hazard_zone(position, size, hazard_zones)

	_add_marker_box(
		spawn_zone,
		"SpawnMarker",
		Vector3(blueprint.safe_path_width_meters, 0.06, blueprint.tile_size),
		Vector3(0.0, 0.12, blueprint.spawn_z),
		MAT_SPAWN
	)
	_add_marker_box(
		goal_zone,
		"GoalMarker",
		Vector3(blueprint.safe_path_width_meters, 0.06, blueprint.tile_size),
		Vector3(0.0, 0.13, blueprint.goal_z),
		MAT_GOAL
	)

	var oob_half_width: float = max(blueprint.safe_path_width_meters * 0.75, blueprint.gameplay_lane_half_width + 4.0)
	add_oob_zone(
		Vector3(oob_half_width * 2.0, 6.0, abs(blueprint.goal_z - blueprint.spawn_z) + blueprint.tile_size * 2.0),
		Vector3(0.0, -2.0, (blueprint.spawn_z + blueprint.goal_z) * 0.5),
		oob_zones
	)


func build_debug_layer(root: Node3D, blueprint: MapBlueprint) -> void:
	if root == null or blueprint == null:
		return
	var path_preview := _make_child("PathPreview", root)
	var bounds_preview := _make_child("BoundsPreview", root)
	var hazard_preview := _make_child("HazardPreview", root)

	for row_index in range(blueprint.get_row_count()):
		for column_index in range(blueprint.visual_width_tiles):
			if not blueprint.is_safe_path_cell(row_index, column_index):
				continue
			_add_marker_box(
				path_preview,
				"SafePathCell",
				Vector3(blueprint.tile_size * 0.85, 0.04, blueprint.tile_size * 0.85),
				Vector3(blueprint.column_to_x(column_index), 0.2, blueprint.row_to_z(row_index)),
				MAT_DEBUG_FLOOR,
				0.35
			)

	for hazard in blueprint.hazard_zones:
		var size: Vector3 = hazard.get("size", Vector3(8, 0.1, 8))
		var position: Vector3 = hazard.get("position", Vector3.ZERO)
		_add_marker_box(hazard_preview, "HazardPreview", size, position, MAT_DEBUG_HAZARD, 0.45)

	_add_marker_box(
		bounds_preview,
		"BoundsPreview",
		Vector3(blueprint.safe_path_width_meters, 0.03, abs(blueprint.goal_z - blueprint.spawn_z) + blueprint.tile_size),
		Vector3(0.0, 0.05, (blueprint.spawn_z + blueprint.goal_z) * 0.5),
		MAT_DEBUG_FLOOR,
		0.2
	)


func add_visual_asset(
	asset_id: String,
	position: Vector3,
	rotation_degrees: float,
	scale_value: float,
	parent: Node3D
) -> Node3D:
	if parent == null:
		return null
	var instance: Node3D = MapAssetRegistry.instantiate_visual_asset(asset_id)
	if instance == null:
		return null
	instance.position = position
	instance.rotation_degrees = Vector3(0.0, rotation_degrees, 0.0)
	instance.scale = Vector3.ONE * scale_value
	parent.add_child(instance)
	return instance


func add_safe_floor_plate(position: Vector3, size: Vector3, parent: Node3D) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "SafeFloorPlate"
	body.position = position
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	if _show_safe_floor:
		var debug_mesh := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = size
		debug_mesh.mesh = mesh
		var mat := MAT_DEBUG_FLOOR.duplicate() as StandardMaterial3D
		if mat != null:
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_color.a = 0.25
			debug_mesh.material_override = mat
		body.add_child(debug_mesh)
	parent.add_child(body)
	return body


func add_hazard_zone(position: Vector3, size: Vector3, parent: Node3D) -> Area3D:
	var area := Area3D.new()
	area.name = "HazardZone"
	area.position = position
	area.set_script(SCRIPT_VOID_KILL)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	area.add_child(shape)
	if _show_hazards:
		var debug_mesh := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = size
		debug_mesh.mesh = mesh
		var mat := MAT_DEBUG_HAZARD.duplicate() as StandardMaterial3D
		if mat != null:
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_color.a = 0.3
			debug_mesh.material_override = mat
		area.add_child(debug_mesh)
	parent.add_child(area)
	return area


func add_oob_zone(size: Vector3, position: Vector3, parent: Node3D) -> Area3D:
	return add_hazard_zone(position, size, parent)


func sanitize_visual_instance(node: Node) -> void:
	if node == null:
		return
	_sanitize_node(node)


func set_debug_visible(enabled: bool) -> void:
	_debug_visible = enabled
	if _debug_layer != null:
		_debug_layer.visible = enabled


func set_show_safe_floor(enabled: bool) -> void:
	_show_safe_floor = enabled


func set_show_hazards(enabled: bool) -> void:
	_show_hazards = enabled


func _build_default_safe_floor(safe_floor: Node3D, blueprint: MapBlueprint) -> void:
	var length: float = abs(blueprint.goal_z - blueprint.spawn_z) + blueprint.tile_size
	var center_z: float = (blueprint.spawn_z + blueprint.goal_z) * 0.5
	add_safe_floor_plate(
		Vector3(0.0, 0.0, center_z),
		Vector3(blueprint.safe_path_width_meters, 0.12, length),
		safe_floor
	)


func _build_water_void(background: Node3D, blueprint: MapBlueprint) -> void:
	var water := MeshInstance3D.new()
	water.name = "WaterVoid"
	var mesh := BoxMesh.new()
	var length: float = abs(blueprint.goal_z - blueprint.spawn_z) + blueprint.tile_size * 3.0
	mesh.size = Vector3(blueprint.tile_size * float(blueprint.visual_width_tiles + 4), 0.06, length)
	water.mesh = mesh
	water.position = Vector3(0.0, -6.0, (blueprint.spawn_z + blueprint.goal_z) * 0.5)
	var water_mat := StandardMaterial3D.new()
	water_mat.albedo_color = Color(0.02, 0.06, 0.1, 0.95)
	water_mat.emission_enabled = true
	water_mat.emission = Color(0.02, 0.07, 0.12)
	water_mat.emission_energy_multiplier = 0.28
	water.material_override = water_mat
	background.add_child(water)


func _default_asset_for_cell(cell_type: String) -> String:
	match cell_type:
		CELL_SAFE_ROAD, CELL_ROAD, CELL_SPAWN, CELL_GOAL:
			return "street_straight"
		CELL_CRACK_ROAD:
			return "street_crack1"
		CELL_BROKEN_EDGE:
			return "street_crack2"
		CELL_BARRIER:
			return "plastic_barrier"
		CELL_CONE:
			return "traffic_cone_1"
		CELL_LEFT_RAIL, CELL_RIGHT_RAIL:
			return "traffic_barrier_1"
		CELL_LIGHT:
			return "street_light"
		CELL_DEBRIS:
			return "pallet_broken"
		CELL_CONTAINER:
			return "container_red"
		_:
			return ""


func _add_marker_box(
	parent: Node3D,
	box_name: String,
	size: Vector3,
	position: Vector3,
	material: Material,
	alpha: float = 1.0
) -> void:
	var marker := MeshInstance3D.new()
	marker.name = box_name
	var mesh := BoxMesh.new()
	mesh.size = size
	marker.mesh = mesh
	marker.position = position
	if alpha < 1.0 and material is StandardMaterial3D:
		var mat := material.duplicate() as StandardMaterial3D
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color.a = alpha
		marker.material_override = mat
	else:
		marker.material_override = material
	parent.add_child(marker)


func _sanitize_node(node: Node) -> void:
	if node is CollisionObject3D:
		var collision_object: CollisionObject3D = node as CollisionObject3D
		if not (collision_object is Area3D):
			collision_object.collision_layer = 0
			collision_object.collision_mask = 0
	if node is CollisionShape3D:
		var collision_shape: CollisionShape3D = node as CollisionShape3D
		collision_shape.disabled = true
	for child in node.get_children():
		_sanitize_node(child)


func _make_child(child_name: String, parent: Node3D) -> Node3D:
	var node := Node3D.new()
	node.name = child_name
	parent.add_child(node)
	return node
