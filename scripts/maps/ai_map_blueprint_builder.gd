class_name AIMapBlueprintBuilder
extends RefCounted

const MapAssetLibraryScript := preload("res://scripts/maps/map_asset_library.gd")
const MapSegmentDefinitionScript := preload("res://scripts/maps/map_segment_definition.gd")
const AIMapBlueprintValidatorScript := preload("res://scripts/maps/ai_map_blueprint_validator.gd")

const ZOMBIE_SPAWN_CLEARANCE: float = 0.8
const FLOOR_THICKNESS: float = 0.12
const SPAWN_BACK_OFFSET: float = 4.0

var _blueprint
var _map_root: Node3D
var _visual_layer: Node3D
var _gameplay_layer: Node3D
var _route_cursor_z: float = 0.0
var _route_deck_y: float = 0.8
var _spawn_z: float = 0.0
var _goal_z: float = 0.0
var _built_length: float = 0.0


func build_prototype(parent: Node3D, blueprint) -> Node3D:
	clear_existing(parent)
	if blueprint == null:
		push_error("AIMapBlueprintBuilder: blueprint is null")
		return null

	var validation: Dictionary = AIMapBlueprintValidatorScript.validate_blueprint(blueprint)
	if not bool(validation.get("ok", false)):
		push_error("AIMapBlueprintBuilder: refusing invalid blueprint '%s'" % blueprint.map_id)
		AIMapBlueprintValidatorScript.print_validation_report(validation)
		return null

	_blueprint = blueprint
	_route_deck_y = blueprint.deck_y
	_route_cursor_z = 0.0
	_built_length = 0.0

	_map_root = Node3D.new()
	_map_root.name = "MapRoot"
	parent.add_child(_map_root)

	_visual_layer = _make_child("VisualLayer", _map_root)
	_gameplay_layer = _make_child("GameplayLayer", _map_root)

	var road_bucket := _make_child("RoadTiles", _visual_layer)
	var rails_bucket := _make_child("Rails", _visual_layer)
	var props_bucket := _make_child("Props", _visual_layer)
	var water_bucket := _make_child("Water", _visual_layer)
	var safe_floor := _make_child("SafeFloor", _gameplay_layer)
	var spawn_zone := _make_child("SpawnZone", _gameplay_layer)
	var goal_zone := _make_child("GoalZone", _gameplay_layer)

	if blueprint.water_enabled:
		_place_water_void(water_bucket)

	for segment_id in blueprint.segment_sequence:
		var segment: Dictionary = MapSegmentDefinitionScript.get_segment(segment_id)
		_assemble_segment(
			segment,
			road_bucket,
			rails_bucket,
			props_bucket,
			water_bucket,
			safe_floor,
			spawn_zone,
			goal_zone
		)

	_spawn_z = _route_cursor_z - _built_length - SPAWN_BACK_OFFSET
	_goal_z = _route_cursor_z - float(
		MapSegmentDefinitionScript.get_segment(blueprint.segment_sequence.back()).get("length", 8.0)
	) * 0.5

	var scene_validation: Dictionary = AIMapBlueprintValidatorScript.validate_generated_scene(
		_map_root, blueprint, build_race_map_definition(blueprint)
	)
	if not bool(scene_validation.get("ok", false)):
		push_warning(
			"AIMapBlueprintBuilder: generated scene validation warnings/errors for '%s'"
			% blueprint.map_id
		)
		AIMapBlueprintValidatorScript.print_validation_report(scene_validation)

	return _map_root


func clear_existing(parent: Node3D) -> void:
	if parent == null:
		return
	var existing: Node = parent.get_node_or_null("MapRoot")
	if existing != null:
		existing.queue_free()


func build_race_map_definition(blueprint) -> RaceMapDefinition:
	if blueprint == null:
		return RaceMapDefinition.new()
	return blueprint.to_race_map_definition()


func _assemble_segment(
	segment: Dictionary,
	road_bucket: Node3D,
	rails_bucket: Node3D,
	props_bucket: Node3D,
	water_bucket: Node3D,
	safe_floor: Node3D,
	spawn_zone: Node3D,
	goal_zone: Node3D
) -> void:
	if segment.is_empty():
		return

	var segment_length: float = float(segment.get("length", 8.0))
	var segment_width: float = float(segment.get("width", 10.0))
	var segment_type: String = str(segment.get("type", ""))
	var center_z: float = _route_cursor_z + segment_length * 0.5
	var height_delta: float = float(segment.get("height_delta", 0.0))
	var deck_y_at_segment: float = _route_deck_y

	_place_required_assets(segment, road_bucket, rails_bucket, props_bucket, center_z, deck_y_at_segment)
	_place_safe_floor_for_segment(
		segment_type,
		segment_width,
		segment_length,
		center_z,
		deck_y_at_segment,
		safe_floor
	)

	match segment_type:
		MapSegmentDefinitionScript.TYPE_START:
			_place_marker(spawn_zone, "SpawnMarker", segment_width, segment_length, center_z, deck_y_at_segment, true)
		MapSegmentDefinitionScript.TYPE_FINISH:
			_place_marker(goal_zone, "GoalMarker", segment_width, segment_length, center_z, deck_y_at_segment, false)
		MapSegmentDefinitionScript.TYPE_GAP, MapSegmentDefinitionScript.TYPE_DROP, MapSegmentDefinitionScript.TYPE_SIDE_DROP:
			if _blueprint.water_enabled:
				_place_segment_water(water_bucket, segment_width + 8.0, segment_length + 2.0, center_z)

	_route_deck_y += height_delta
	_route_cursor_z += segment_length
	_built_length += segment_length


func _place_required_assets(
	segment: Dictionary,
	road_bucket: Node3D,
	rails_bucket: Node3D,
	props_bucket: Node3D,
	center_z: float,
	deck_y: float
) -> void:
	var required_assets: Array = segment.get("required_assets", [])
	for asset_id_value in required_assets:
		var asset_id: String = str(asset_id_value)
		if asset_id == "safe_floor_plate" or asset_id == "phase1_safe_floor_plate":
			continue
		var asset: Dictionary = MapAssetLibraryScript.get_asset(asset_id)
		if asset.is_empty():
			continue
		var category: int = int(asset.get("category", MapAssetLibraryScript.Category.UNKNOWN))
		var parent_bucket: Node3D = road_bucket
		if category in [MapAssetLibraryScript.Category.RAIL, MapAssetLibraryScript.Category.BARRIER]:
			parent_bucket = rails_bucket
		elif category in [
			MapAssetLibraryScript.Category.DECORATION,
			MapAssetLibraryScript.Category.MOVING_OBSTACLE,
			MapAssetLibraryScript.Category.SUPPORT,
		]:
			parent_bucket = props_bucket

		var instance: Node3D = MapAssetLibraryScript.instantiate_visual(asset_id)
		if instance == null:
			continue
		instance.position = Vector3(0.0, deck_y + float(asset.get("deck_y_offset", 0.0)), center_z)
		parent_bucket.add_child(instance)


func _place_safe_floor_for_segment(
	segment_type: String,
	segment_width: float,
	segment_length: float,
	center_z: float,
	deck_y: float,
	safe_floor: Node3D
) -> void:
	var floor_width: float = segment_width
	if segment_type in [
		MapSegmentDefinitionScript.TYPE_GAP,
		MapSegmentDefinitionScript.TYPE_NARROW_BRIDGE,
		MapSegmentDefinitionScript.TYPE_SIDE_DROP,
	]:
		floor_width = min(segment_width, _blueprint.route_half_width * 2.0 - 2.0)
	_add_safe_floor_plate(
		safe_floor,
		Vector3(0.0, deck_y - FLOOR_THICKNESS * 0.5, center_z),
		Vector3(floor_width, FLOOR_THICKNESS, segment_length)
	)


func _place_marker(
	parent: Node3D,
	marker_name: String,
	width: float,
	length: float,
	center_z: float,
	deck_y: float,
	is_spawn: bool
) -> void:
	var marker := MeshInstance3D.new()
	marker.name = marker_name
	var mesh := BoxMesh.new()
	mesh.size = Vector3(width, 0.06, min(length, 8.0))
	marker.mesh = mesh
	marker.position = Vector3(0.0, deck_y + 0.12, center_z)
	var mat_path: String = (
		"res://assets/materials/spawn_zone.tres"
		if is_spawn
		else "res://assets/materials/goal_zone.tres"
	)
	var mat: Material = load(mat_path)
	if mat != null:
		marker.material_override = mat
	parent.add_child(marker)


func _place_water_void(parent: Node3D) -> void:
	var instance: Node3D = MapAssetLibraryScript.instantiate_visual("water_void_plane")
	if instance == null:
		return
	instance.position = Vector3(0.0, _blueprint.deck_y - 4.0, _blueprint.get_total_route_length() * 0.5)
	parent.add_child(instance)


func _place_segment_water(parent: Node3D, width: float, length: float, center_z: float) -> void:
	var water := MeshInstance3D.new()
	water.name = "SegmentWater"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(width, 0.08, length)
	water.mesh = mesh
	water.position = Vector3(0.0, _blueprint.deck_y - 3.5, center_z)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.02, 0.06, 0.1, 0.95)
	water.material_override = mat
	parent.add_child(water)


func _add_safe_floor_plate(parent: Node3D, position: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "SafeFloorPlate"
	body.position = position
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var half_x: float = size.x * 0.5
	var half_z: float = size.z * 0.5
	var top_y: float = maxf(size.y, 0.08) * 0.5
	var concave := ConcavePolygonShape3D.new()
	concave.set_faces(
		PackedVector3Array(
			[
				Vector3(-half_x, top_y, -half_z),
				Vector3(half_x, top_y, -half_z),
				Vector3(half_x, top_y, half_z),
				Vector3(-half_x, top_y, -half_z),
				Vector3(half_x, top_y, half_z),
				Vector3(-half_x, top_y, half_z),
			]
		)
	)
	shape.shape = concave
	body.add_child(shape)
	parent.add_child(body)
	return body


func _make_child(child_name: String, parent: Node3D) -> Node3D:
	var node := Node3D.new()
	node.name = child_name
	parent.add_child(node)
	return node
