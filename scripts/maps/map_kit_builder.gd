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
var _show_debug_grid: bool = true
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
			if cell_type == CELL_VOID or bool(cell.get("skip_visual", false)):
				continue

			var base_x: float = float(cell.get("placement_x", blueprint.column_to_x(column_index)))
			var position: Vector3 = Vector3(
				base_x + float(cell.get("offset_x", 0.0)),
				float(cell.get("offset_y", 0.0)),
				blueprint.row_to_z(row_index) + float(cell.get("offset_z", 0.0))
			)
			var rotation: float = _resolve_cell_rotation(cell, column_index, blueprint)
			var scale_value: float = float(cell.get("scale", 1.0))
			var scale_x: float = float(cell.get("scale_x", scale_value))
			var scale_z: float = float(cell.get("scale_z", scale_value))
			var scale_y: float = float(cell.get("scale_y", scale_value))
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

			var instance: Node3D = add_visual_asset(
				asset_id, position, rotation, Vector3(scale_x, scale_y, scale_z), parent_bucket
			)
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
	var bridge_length: float = abs(blueprint.goal_z - blueprint.spawn_z) + blueprint.tile_size * 2.0
	add_oob_zone(
		Vector3(oob_half_width * 2.0, 4.0, bridge_length),
		Vector3(0.0, -5.5, (blueprint.spawn_z + blueprint.goal_z) * 0.5),
		oob_zones
	)


func build_debug_layer(root: Node3D, blueprint: MapBlueprint) -> void:
	if root == null or blueprint == null:
		return
	var grid_overlay := _make_child("GridOverlay", root)
	var grid_labels := _make_child("GridLabels", root)
	var bounds_preview := _make_child("BoundsPreview", root)
	var hazard_preview := _make_child("HazardPreview", root)

	if _show_debug_grid:
		_build_grid_overlay(grid_overlay, grid_labels, blueprint)

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
	scale_value: Variant,
	parent: Node3D
) -> Node3D:
	if parent == null:
		return null
	var instance: Node3D = MapAssetRegistry.instantiate_visual_asset(asset_id)
	if instance == null:
		return null
	instance.position = position
	instance.rotation_degrees = Vector3(0.0, rotation_degrees, 0.0)
	if scale_value is Vector3:
		instance.scale = scale_value
	else:
		instance.scale = Vector3.ONE * float(scale_value)
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


func set_show_debug_grid(enabled: bool) -> void:
	_show_debug_grid = enabled


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


func _build_grid_overlay(grid_overlay: Node3D, grid_labels: Node3D, blueprint: MapBlueprint) -> void:
	var tile_size: float = blueprint.tile_size
	var marker_size := Vector3(tile_size * 0.82, 0.05, tile_size * 0.82)
	var center_col: int = blueprint.get_center_column_index()
	var spawn_row: int = _find_marker_row(blueprint, CELL_SPAWN)
	var goal_row: int = _find_marker_row(blueprint, CELL_GOAL)
	if spawn_row < 0:
		spawn_row = 0
	if goal_row < 0:
		goal_row = blueprint.get_row_count() - 1

	var mat_safe := _make_debug_material(Color(0.2, 0.95, 0.35, 0.42))
	var mat_hazard := _make_debug_material(Color(0.95, 0.2, 0.2, 0.5))
	var mat_void := _make_debug_material(Color(0.05, 0.08, 0.18, 0.55))
	var mat_gap := _make_debug_material(Color(0.12, 0.2, 0.45, 0.62))
	var mat_spawn_row := _make_debug_material(Color(0.2, 0.85, 1.0, 0.28))
	var mat_goal_row := _make_debug_material(Color(1.0, 0.82, 0.15, 0.28))
	var mat_center_route := _make_debug_material(Color(0.95, 0.95, 0.2, 0.22))

	_add_marker_box(
		grid_overlay,
		"CenterSafeRoute",
		Vector3(blueprint.safe_path_width_meters, 0.02, abs(blueprint.goal_z - blueprint.spawn_z) + tile_size),
		Vector3(0.0, 0.08, (blueprint.spawn_z + blueprint.goal_z) * 0.5),
		mat_center_route,
		1.0
	)

	_add_row_band_marker(grid_overlay, blueprint, spawn_row, tile_size, mat_spawn_row, "SpawnRow")
	_add_row_band_marker(grid_overlay, blueprint, goal_row, tile_size, mat_goal_row, "GoalRow")

	for row_index in range(blueprint.get_row_count()):
		for column_index in range(blueprint.visual_width_tiles):
			var cell: Dictionary = blueprint.get_cell(row_index, column_index)
			var cell_type: String = str(cell.get("type", CELL_VOID))
			var position := Vector3(
				blueprint.column_to_x(column_index),
				0.16,
				blueprint.row_to_z(row_index)
			)
			var material: StandardMaterial3D = null
			var marker_name: String = "CellMarker"

			if blueprint.is_safe_path_cell(row_index, column_index):
				material = mat_safe
				marker_name = "SafeCell"
			elif cell_type == CELL_HAZARD or bool(cell.get("hazard", false)):
				material = mat_hazard
				marker_name = "HazardCell"
			elif cell_type == CELL_GAP_VISUAL:
				material = mat_gap
				marker_name = "GapCell"
			elif cell_type == CELL_VOID:
				material = mat_void
				marker_name = "VoidCell"
			else:
				continue

			_add_marker_box(grid_overlay, marker_name, marker_size, position, material, 1.0)

	_build_grid_labels(grid_labels, blueprint, center_col, spawn_row, goal_row)


func _build_grid_labels(
	labels_root: Node3D,
	blueprint: MapBlueprint,
	center_col: int,
	spawn_row: int,
	goal_row: int
) -> void:
	var left_x: float = blueprint.column_to_x(0) - blueprint.tile_size * 1.35
	var top_z: float = blueprint.row_to_z(0) - blueprint.tile_size * 0.85
	var column_names: Array[String] = ["L", "C", "R"]
	if blueprint.visual_width_tiles == 3:
		column_names = ["LEFT", "CENTER", "RIGHT"]

	for row_index in range(blueprint.get_row_count()):
		var row_label := Label3D.new()
		row_label.name = "RowLabel_%d" % row_index
		row_label.text = "R%d" % row_index
		row_label.font_size = 22
		row_label.outline_size = 6
		row_label.modulate = Color(0.85, 0.92, 1.0, 1.0)
		row_label.position = Vector3(left_x, 1.4, blueprint.row_to_z(row_index))
		row_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		labels_root.add_child(row_label)

	for column_index in range(blueprint.visual_width_tiles):
		var column_label := Label3D.new()
		column_label.name = "ColumnLabel_%d" % column_index
		var suffix: String = ""
		if column_index == center_col:
			suffix = " (SAFE)"
		column_label.text = "%s%s" % [column_names[min(column_index, column_names.size() - 1)], suffix]
		column_label.font_size = 20
		column_label.outline_size = 6
		column_label.modulate = Color(1.0, 0.92, 0.45, 1.0) if column_index == center_col else Color(0.8, 0.85, 0.95, 1.0)
		column_label.position = Vector3(blueprint.column_to_x(column_index), 1.8, top_z)
		column_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		labels_root.add_child(column_label)

	var spawn_label := Label3D.new()
	spawn_label.name = "SpawnRowLabel"
	spawn_label.text = "SPAWN ROW %d" % spawn_row
	spawn_label.font_size = 24
	spawn_label.outline_size = 8
	spawn_label.modulate = Color(0.35, 0.9, 1.0, 1.0)
	spawn_label.position = Vector3(left_x - 2.0, 2.2, blueprint.row_to_z(spawn_row))
	spawn_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	labels_root.add_child(spawn_label)

	var goal_label := Label3D.new()
	goal_label.name = "GoalRowLabel"
	goal_label.text = "GOAL ROW %d" % goal_row
	goal_label.font_size = 24
	goal_label.outline_size = 8
	goal_label.modulate = Color(1.0, 0.82, 0.2, 1.0)
	goal_label.position = Vector3(left_x - 2.0, 2.2, blueprint.row_to_z(goal_row))
	goal_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	labels_root.add_child(goal_label)


func _add_row_band_marker(
	parent: Node3D,
	blueprint: MapBlueprint,
	row_index: int,
	tile_size: float,
	material: StandardMaterial3D,
	marker_name: String
) -> void:
	_add_marker_box(
		parent,
		marker_name,
		Vector3(tile_size * float(blueprint.visual_width_tiles + 1), 0.03, tile_size * 0.92),
		Vector3(0.0, 0.12, blueprint.row_to_z(row_index)),
		material,
		1.0
	)


func _find_marker_row(blueprint: MapBlueprint, marker_type: String) -> int:
	for row_index in range(blueprint.get_row_count()):
		for column_index in range(blueprint.visual_width_tiles):
			if blueprint.get_cell_type(row_index, column_index) == marker_type:
				return row_index
	return -1


func _make_debug_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func _build_water_void(background: Node3D, blueprint: MapBlueprint) -> void:
	var water := MeshInstance3D.new()
	water.name = "WaterVoid"
	var mesh := BoxMesh.new()
	var length_scale: float = float(blueprint.dressing_rules.get("void_length_scale", 1.0))
	var length: float = (abs(blueprint.goal_z - blueprint.spawn_z) + blueprint.tile_size * 3.0) * length_scale
	var width_scale: float = float(blueprint.dressing_rules.get("void_width_scale", 0.0))
	if width_scale <= 0.0:
		width_scale = 6.0 if bool(blueprint.dressing_rules.get("narrow_bridge", false)) else 4.0
	mesh.size = Vector3(blueprint.tile_size * float(blueprint.visual_width_tiles + width_scale), 0.06, length)
	water.mesh = mesh
	var void_depth: float = float(blueprint.dressing_rules.get("void_depth", -6.0))
	water.position = Vector3(0.0, void_depth, (blueprint.spawn_z + blueprint.goal_z) * 0.5)
	var water_mat := StandardMaterial3D.new()
	var void_darkness: float = float(blueprint.dressing_rules.get("void_darkness", 1.0))
	water_mat.albedo_color = Color(0.002 * void_darkness, 0.008 * void_darkness, 0.018, 0.995)
	water_mat.emission_enabled = true
	water_mat.emission = Color(0.004, 0.02, 0.04) * void_darkness
	water_mat.emission_energy_multiplier = 0.12
	water.material_override = water_mat
	background.add_child(water)

	if bool(blueprint.dressing_rules.get("deep_void", false)):
		var deep := MeshInstance3D.new()
		deep.name = "DeepVoid"
		var deep_mesh := BoxMesh.new()
		deep_mesh.size = Vector3(mesh.size.x * 1.08, 0.12, mesh.size.z * 1.05)
		deep.mesh = deep_mesh
		deep.position = Vector3(0.0, void_depth - 2.5, water.position.z)
		var deep_mat := StandardMaterial3D.new()
		deep_mat.albedo_color = Color(0.002, 0.008, 0.02, 1.0)
		deep_mat.emission_enabled = true
		deep_mat.emission = Color(0.004, 0.01, 0.02)
		deep_mat.emission_energy_multiplier = 0.1
		deep.material_override = deep_mat
		background.add_child(deep)


func _resolve_cell_rotation(cell: Dictionary, column_index: int, blueprint: MapBlueprint) -> float:
	if cell.has("rotation"):
		return float(cell.get("rotation", 0.0))
	if not bool(cell.get("face_inward", false)):
		return 0.0

	var center_col: int = blueprint.get_center_column_index()
	if column_index < center_col:
		return 90.0
	if column_index > center_col:
		return -90.0
	return 0.0


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
