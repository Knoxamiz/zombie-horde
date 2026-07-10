class_name VisualCollisionSanitizer
extends Node

const MAP_WALK_SURFACES_GROUP := "map_walk_surfaces"

@export var root_path: NodePath = ^".."
@export var sanitize_on_ready: bool = true
@export var disable_area_colliders: bool = false
@export_range(0, 4, 1) var deferred_sanitize_passes: int = 2

func _ready() -> void:
	if sanitize_on_ready:
		sanitize()
		_run_deferred_sanitize_passes()

func _run_deferred_sanitize_passes() -> void:
	for _pass_index in range(deferred_sanitize_passes):
		await get_tree().process_frame
		sanitize()

func sanitize() -> void:
	var root: Node = get_node_or_null(root_path)
	if root == null:
		root = get_parent()

	if root != null:
		_sanitize_node(root, false)


static func sanitize_subtree(root: Node) -> void:
	if root == null:
		return
	var sanitizer := VisualCollisionSanitizer.new()
	sanitizer._sanitize_node(root, false)

func _sanitize_node(node: Node, under_kit_surfaces: bool = false) -> void:
	if node == self:
		return
	var next_under_kit_surfaces: bool = under_kit_surfaces or node.name == "KitSurfaces"
	if node.name == "Collision" and next_under_kit_surfaces:
		return
	if node.is_in_group(MAP_WALK_SURFACES_GROUP):
		return

	var collision_object: CollisionObject3D = node as CollisionObject3D
	if collision_object != null and (disable_area_colliders or not (collision_object is Area3D)):
		collision_object.collision_layer = 0
		collision_object.collision_mask = 0

	var collision_shape: CollisionShape3D = node as CollisionShape3D
	if collision_shape != null and not (node.name == "Collision" and next_under_kit_surfaces):
		collision_shape.disabled = true

	for child in node.get_children():
		_sanitize_node(child, next_under_kit_surfaces)
