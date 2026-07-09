class_name FallthroughLowerDeckArena
extends Node3D

## Hand-authored fallthrough test map: one connected upper route, center hole, lower landing deck.
## Collision uses MapSurfacePiece only where walkable geometry exists (no AI segment kit stacking).

const MapSurfacePieceScript := preload("res://scripts/maps/map_surface_piece.gd")
const VisualCollisionSanitizerScript := preload("res://scripts/core/visual_collision_sanitizer.gd")
const AIMapCollisionAuditScript := preload("res://scripts/maps/ai_map_collision_audit.gd")

const DECK_Y: float = 2.0
const LOWER_DECK_Y: float = -1.5
const ROUTE_WIDTH: float = 10.0
const ROUTE_HALF: float = ROUTE_WIDTH * 0.5
const WING_WIDTH_RATIO: float = 0.32
const WING_OFFSET_RATIO: float = 0.34
const SPAWN_Z: float = -4.0
const GOAL_Z: float = 44.0
const START_GATE_Z: float = -2.0
const FINISH_GATE_Z: float = 42.0

const MAT_ROAD := preload("res://assets/materials/road_asphalt.tres")
const MAT_SPAWN := preload("res://assets/materials/spawn_zone.tres")
const MAT_GOAL := preload("res://assets/materials/goal_zone.tres")
const MAT_CONCRETE := preload("res://assets/materials/base_concrete.tres")

var _map_root: Node3D


func _ready() -> void:
	build_map()


func build_map() -> Node3D:
	_clear_existing()
	_map_root = _build_map_root()
	_sanitize_visual_collision()
	AIMapCollisionAuditScript.ensure_gameplay_collision_enabled(_map_root)
	print("FallthroughLowerDeckArena: built hand-authored fallthrough lower deck test")
	return _map_root


func get_map_root() -> Node3D:
	return _map_root


func _clear_existing() -> void:
	var existing: Node = get_node_or_null("MapRoot")
	if existing != null:
		existing.queue_free()
	_map_root = null


func _build_map_root() -> Node3D:
	var map_root := Node3D.new()
	map_root.name = "MapRoot"
	add_child(map_root)

	var visual_layer := _make_child("VisualLayer", map_root)
	var gameplay_layer := _make_child("GameplayLayer", map_root)
	var surfaces := _make_child("Surfaces", gameplay_layer)
	var spawn_zone := _make_child("SpawnZone", gameplay_layer)
	var goal_zone := _make_child("GoalZone", gameplay_layer)

	_build_environment(map_root)
	_build_upper_track_visuals(visual_layer)
	_build_lower_track_visuals(visual_layer)
	_build_labels(visual_layer)
	_build_surface_collision(surfaces)
	_build_markers(spawn_zone, goal_zone)
	return map_root


func _build_environment(root: Node3D) -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-42.0, 28.0, 0.0)
	sun.light_color = Color(0.64, 0.7, 0.82, 1.0)
	sun.light_energy = 0.48
	sun.shadow_enabled = true
	root.add_child(sun)

	_add_omni(root, "StartPoolLight", Vector3(0.0, 5.2, 4.0), Color(0.52, 1.0, 0.35, 1.0), 2.25, 28.0)
	_add_omni(root, "HoleLight", Vector3(0.0, 4.8, 28.0), Color(1.0, 0.72, 0.2, 1.0), 1.8, 20.0)
	_add_omni(root, "LowerDeckLight", Vector3(0.0, 3.6, 38.0), Color(0.35, 1.0, 0.55, 1.0), 2.0, 22.0)
	_add_omni(root, "FinishPoolLight", Vector3(0.0, 4.2, GOAL_Z), Color(1.0, 0.32, 0.12, 1.0), 1.8, 24.0)


func _build_upper_track_visuals(parent: Node3D) -> void:
	var track := _make_child("UpperTrack", parent)
	var slab_thickness: float = 0.14

	_add_road_slab(
		track,
		"SpawnApproach",
		Vector3(ROUTE_WIDTH, slab_thickness, 4.0),
		Vector3(0.0, DECK_Y, -2.0),
		MAT_ROAD
	)
	_add_road_slab(
		track,
		"StartStraight",
		Vector3(ROUTE_WIDTH, slab_thickness, 8.0),
		Vector3(0.0, DECK_Y, 4.0),
		MAT_ROAD
	)
	_add_road_slab(
		track,
		"ApproachToHole",
		Vector3(ROUTE_WIDTH, slab_thickness, 16.0),
		Vector3(0.0, DECK_Y, 16.0),
		MAT_ROAD
	)

	var wing_width: float = ROUTE_WIDTH * WING_WIDTH_RATIO
	var wing_offset: float = ROUTE_WIDTH * WING_OFFSET_RATIO
	var wing_color := Color(0.92, 0.58, 0.18, 1.0)
	for side_sign in [-1.0, 1.0]:
		_add_road_slab(
			track,
			"UpperWing",
			Vector3(wing_width, slab_thickness, 8.0),
			Vector3(side_sign * wing_offset, DECK_Y, 28.0),
			null,
			wing_color
		)

	_add_edge_rails(track, 24.0, 32.0, DECK_Y + 0.08)
	_add_center_lane_line(track, 0.0, 24.0, DECK_Y + 0.09)

	var pit := _make_child("CenterPitVisual", track)
	_add_road_slab(
		pit,
		"PitFloor",
		Vector3(ROUTE_WIDTH * 0.34, 0.04, 7.2),
		Vector3(0.0, LOWER_DECK_Y - 0.08, 28.0),
		null,
		Color(0.03, 0.05, 0.08, 1.0)
	)


func _build_lower_track_visuals(parent: Node3D) -> void:
	var track := _make_child("LowerTrack", parent)
	var slab_thickness: float = 0.16
	var landing_color := Color(0.22, 0.82, 0.42, 1.0)

	_add_road_slab(
		track,
		"LowerLandingDeck",
		Vector3(ROUTE_WIDTH, slab_thickness, 16.0),
		Vector3(0.0, LOWER_DECK_Y, 40.0),
		null,
		landing_color
	)
	_add_edge_rails(track, 32.0, 48.0, LOWER_DECK_Y + 0.08)
	_add_center_lane_line(track, 32.0, 48.0, LOWER_DECK_Y + 0.09)


func _build_labels(parent: Node3D) -> void:
	var labels := _make_child("Labels", parent)
	_add_label(labels, "UPPER DECK — CENTER HOLE AHEAD", Vector3(0.0, DECK_Y + 1.8, 20.0), Color(1.0, 0.82, 0.2, 1.0))
	_add_label(labels, "FALL THROUGH CENTER", Vector3(0.0, DECK_Y + 1.4, 28.0), Color(1.0, 0.55, 0.2, 1.0))
	_add_label(labels, "LOWER LANDING DECK", Vector3(0.0, LOWER_DECK_Y + 1.5, 36.0), Color(0.55, 1.0, 0.65, 1.0))


func _build_surface_collision(surfaces: Node3D) -> void:
	_add_surface_deck(surfaces, "SpawnApproach", ROUTE_WIDTH, 4.0, -2.0, DECK_Y, 0, "spawn_approach")
	_add_surface_deck(surfaces, "StartStraight", ROUTE_WIDTH, 8.0, 4.0, DECK_Y, 0, "start_straight")
	_add_surface_deck(surfaces, "ApproachToHole", ROUTE_WIDTH, 16.0, 16.0, DECK_Y, 0, "straight_road_medium")

	var wing_width: float = ROUTE_WIDTH * WING_WIDTH_RATIO
	var wing_offset: float = ROUTE_WIDTH * WING_OFFSET_RATIO
	for side_index in range(2):
		var side_sign: float = -1.0 if side_index == 0 else 1.0
		_add_surface_deck(
			surfaces,
			"UpperWing_%d" % side_index,
			wing_width,
			8.0,
			28.0,
			DECK_Y,
			0,
			"upper_fallthrough_deck",
			side_sign * wing_offset,
		)

	_add_surface_deck(
		surfaces,
		"LowerRecoveryDeck",
		ROUTE_WIDTH,
		16.0,
		40.0,
		LOWER_DECK_Y,
		1,
		"lower_recovery_deck",
	)


func _build_markers(spawn_zone: Node3D, goal_zone: Node3D) -> void:
	_add_marker_box(spawn_zone, "SpawnMarker", Vector3(ROUTE_WIDTH, 0.06, 4.0), Vector3(0.0, DECK_Y + 0.12, SPAWN_Z), MAT_SPAWN)
	_add_marker_box(goal_zone, "GoalMarker", Vector3(ROUTE_WIDTH, 0.06, 4.0), Vector3(0.0, LOWER_DECK_Y + 0.12, GOAL_Z), MAT_GOAL)
	_add_marker_box(spawn_zone, "StartLine", Vector3(ROUTE_WIDTH, 0.07, 0.45), Vector3(0.0, DECK_Y + 0.12, START_GATE_Z), MAT_SPAWN)
	_add_marker_box(goal_zone, "FinishLine", Vector3(ROUTE_WIDTH, 0.07, 0.45), Vector3(0.0, LOWER_DECK_Y + 0.12, FINISH_GATE_Z), MAT_GOAL)
	var gate_half: float = ROUTE_HALF - 1.0
	_add_gate(
		spawn_zone,
		Vector3(-gate_half, DECK_Y + 1.6, START_GATE_Z),
		Vector3(gate_half, DECK_Y + 1.6, START_GATE_Z),
		MAT_SPAWN,
	)
	_add_gate(
		goal_zone,
		Vector3(-gate_half, LOWER_DECK_Y + 1.2, FINISH_GATE_Z),
		Vector3(gate_half, LOWER_DECK_Y + 1.2, FINISH_GATE_Z),
		MAT_GOAL,
	)


func _add_surface_deck(
	parent: Node3D,
	piece_name: String,
	width: float,
	length: float,
	center_z: float,
	top_y: float,
	layer_index: int,
	segment_id: String,
	x_offset: float = 0.0,
) -> void:
	var piece: StaticBody3D = MapSurfacePieceScript.create_deck(
		Vector3(width, MapSurfacePieceScript.MIN_THICKNESS, length),
		top_y,
		layer_index,
		"recovery" if layer_index > 0 else "walk",
	)
	piece.name = piece_name
	piece.position.x = x_offset
	piece.position.z = center_z
	piece.segment_id = segment_id
	parent.add_child(piece)


func _add_road_slab(
	parent: Node3D,
	slab_name: String,
	size: Vector3,
	position: Vector3,
	material: Material = null,
	color: Color = Color.WHITE,
) -> void:
	var slab := MeshInstance3D.new()
	slab.name = slab_name
	var mesh := BoxMesh.new()
	mesh.size = size
	slab.mesh = mesh
	slab.position = position
	if material != null:
		slab.material_override = material
	else:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = 0.82
		slab.material_override = mat
	parent.add_child(slab)


func _add_edge_rails(parent: Node3D, z_start: float, z_end: float, y: float) -> void:
	var length: float = z_end - z_start
	var center_z: float = (z_start + z_end) * 0.5
	for side_sign in [-1.0, 1.0]:
		_add_road_slab(
			parent,
			"EdgeRail",
			Vector3(0.35, 0.55, length),
			Vector3(side_sign * (ROUTE_HALF + 0.35), y, center_z),
			MAT_CONCRETE
		)


func _add_center_lane_line(parent: Node3D, z_start: float, z_end: float, y: float) -> void:
	var length: float = z_end - z_start
	var center_z: float = (z_start + z_end) * 0.5
	_add_road_slab(
		parent,
		"CenterLine",
		Vector3(0.16, 0.03, length - 1.0),
		Vector3(0.0, y, center_z),
		null,
		Color(0.95, 0.9, 0.2, 1.0)
	)


func _add_marker_box(parent: Node3D, box_name: String, size: Vector3, position: Vector3, material: Material) -> void:
	var marker := MeshInstance3D.new()
	marker.name = box_name
	var mesh := BoxMesh.new()
	mesh.size = size
	marker.mesh = mesh
	marker.position = position
	marker.material_override = material
	parent.add_child(marker)


func _add_gate(parent: Node3D, left_pos: Vector3, right_pos: Vector3, accent: Material) -> void:
	_add_marker_box(parent, "GatePost", Vector3(0.28, 3.2, 0.28), left_pos, MAT_CONCRETE)
	_add_marker_box(parent, "GatePost", Vector3(0.28, 3.2, 0.28), right_pos, MAT_CONCRETE)
	var center := (left_pos + right_pos) * 0.5
	center.y = max(left_pos.y, right_pos.y) + 1.55
	var header_width: float = abs(right_pos.x - left_pos.x) + 0.8
	_add_marker_box(parent, "GateHeader", Vector3(header_width, 0.42, 0.42), center, accent)


func _add_label(parent: Node3D, text: String, position: Vector3, color: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 28
	label.outline_size = 8
	label.modulate = color
	label.position = position
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	parent.add_child(label)


func _add_omni(
	root: Node3D,
	light_name: String,
	position: Vector3,
	color: Color,
	energy: float,
	range_value: float,
) -> void:
	var light := OmniLight3D.new()
	light.name = light_name
	light.position = position
	light.light_color = color
	light.light_energy = energy
	light.omni_range = range_value
	root.add_child(light)


func _make_child(child_name: String, parent: Node3D) -> Node3D:
	var node := Node3D.new()
	node.name = child_name
	parent.add_child(node)
	return node


func _sanitize_visual_collision() -> void:
	if _map_root == null:
		return
	var visual_layer: Node = _map_root.get_node_or_null("VisualLayer")
	if visual_layer != null:
		VisualCollisionSanitizerScript.sanitize_subtree(visual_layer)
