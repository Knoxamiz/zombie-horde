class_name MapSurfacePiece
extends StaticBody3D

## Authoritative walk surface for AI-generated maps.
## Collision matches the physical slab/ramp shape — no invisible full-segment plates.
## Gaps and fall-through are created by omitting pieces, not boolean mesh cuts.

const WALK_COLLISION_LAYER: int = 1
const GROUP_NAME := "map_walk_surfaces"
const NAVIGATION_GROUP := "race_navigation_surfaces"
const MIN_THICKNESS: float = 0.12

@export var surface_layer_index: int = 0
@export var surface_role: String = "walk"
@export var allows_edge_fall: bool = true
@export var segment_id: String = ""
@export var shape_kind: String = "deck"


func _init() -> void:
	collision_layer = WALK_COLLISION_LAYER
	collision_mask = 0


func _ready() -> void:
	add_to_group(GROUP_NAME)
	add_to_group(NAVIGATION_GROUP)
	collision_layer = WALK_COLLISION_LAYER
	collision_mask = 0


static func create_deck(
	size: Vector3,
	top_y: float,
	layer_index: int = 0,
	role: String = "walk"
) -> MapSurfacePiece:
	var piece := MapSurfacePiece.new()
	piece.name = "SurfaceDeck_L%d" % layer_index
	piece.surface_layer_index = layer_index
	piece.surface_role = role
	piece.shape_kind = "deck"
	var thickness: float = maxf(size.y, MIN_THICKNESS)
	piece.position = Vector3(0.0, top_y - thickness * 0.5, 0.0)
	_add_box_collision(piece, Vector3(maxf(size.x, 0.5), thickness, maxf(size.z, 0.5)))
	return piece


static func create_ramp(
	width: float,
	length: float,
	height_delta: float,
	start_top_y: float,
	layer_index: int = 0
) -> MapSurfacePiece:
	var piece := MapSurfacePiece.new()
	piece.name = "SurfaceRamp_L%d" % layer_index
	piece.surface_layer_index = layer_index
	piece.surface_role = "ramp"
	piece.shape_kind = "ramp"
	piece.allows_edge_fall = true

	var thickness: float = MIN_THICKNESS
	var safe_length: float = maxf(length, 0.5)
	var safe_width: float = maxf(width, 0.5)
	var slope_angle: float = atan2(height_delta, safe_length)
	var ramp_span: float = sqrt(safe_length * safe_length + height_delta * height_delta)
	var center_y: float = start_top_y + height_delta * 0.5

	piece.position = Vector3(0.0, center_y - thickness * 0.5, 0.0)
	piece.rotation.x = -slope_angle
	_add_box_collision(
		piece,
		Vector3(safe_width, thickness, maxf(ramp_span, 0.5)),
	)
	return piece


static func get_collision_top_y(piece: MapSurfacePiece) -> float:
	if piece == null:
		return 0.0
	var shape_node: CollisionShape3D = _find_collision_shape(piece)
	if shape_node == null or shape_node.shape == null:
		return piece.position.y
	var half_height: float = _shape_half_height(shape_node.shape, piece)
	return piece.global_position.y + half_height


static func _add_box_collision(
	piece: MapSurfacePiece,
	size: Vector3,
	local_offset: Vector3 = Vector3.ZERO
) -> void:
	var shape_node := CollisionShape3D.new()
	shape_node.name = "Collision"
	shape_node.position = local_offset
	var box := BoxShape3D.new()
	box.size = size
	shape_node.shape = box
	piece.add_child(shape_node)


static func _find_collision_shape(node: Node) -> CollisionShape3D:
	for child in node.get_children():
		if child is CollisionShape3D:
			return child as CollisionShape3D
	return null


static func _shape_half_height(shape: Shape3D, owner: Node3D) -> float:
	if shape is BoxShape3D:
		var local_half: float = (shape as BoxShape3D).size.y * 0.5
		return abs(owner.global_basis.y.y) * local_half + abs(owner.global_basis.y.z) * (
			(shape as BoxShape3D).size.z * 0.5
		)
	return 0.06
