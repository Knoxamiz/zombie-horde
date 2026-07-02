class_name RaceCollisionAudit
extends Node

@export var enabled: bool = true
@export var scan_interval: float = 1.0
@export var race_world_path: NodePath
@export var hazard_manager_path: NodePath
@export var lane_half_width: float = 8.4
@export var min_race_z: float = -44.0
@export var max_race_z: float = 44.0

var _scan_timer: float = 0.0
var _reported_paths: Dictionary = {}

func _ready() -> void:
	call_deferred("_scan")

func _process(delta: float) -> void:
	if not enabled:
		return

	_scan_timer -= delta
	if _scan_timer > 0.0:
		return

	_scan_timer = max(scan_interval, 0.1)
	_scan()

func _scan() -> void:
	if not enabled:
		return

	_scan_root(race_world_path)
	_scan_root(hazard_manager_path)

func _scan_root(root_path: NodePath) -> void:
	if root_path.is_empty():
		return

	var root: Node = get_node_or_null(root_path)
	if root == null:
		return

	_scan_node(root)

func _scan_node(node: Node) -> void:
	var collision_object: CollisionObject3D = node as CollisionObject3D
	if collision_object != null:
		_audit_collision_object(collision_object)

	for child in node.get_children():
		_scan_node(child)

func _audit_collision_object(collision_object: CollisionObject3D) -> void:
	if collision_object is Area3D:
		return
	if (collision_object.collision_layer & 1) == 0:
		return
	if _is_expected_race_solid(collision_object):
		return

	var object_3d: Node3D = collision_object as Node3D
	if object_3d == null or not _is_inside_race_lane(object_3d.global_position):
		return

	var object_path: String = str(collision_object.get_path())
	if _reported_paths.has(object_path):
		return

	_reported_paths[object_path] = true
	var message: String = "Unexpected solid race collider: %s at %s" % [object_path, object_3d.global_position]
	push_warning(message)
	GameEvents.world_feedback_requested.emit(
		object_3d.global_position + Vector3.UP * 1.4,
		"SOLID?",
		Color(1.0, 0.14, 0.08, 1.0)
	)

func _is_inside_race_lane(world_position: Vector3) -> bool:
	return (
		abs(world_position.x) <= lane_half_width
		and world_position.z >= min_race_z
		and world_position.z <= max_race_z
	)

func _is_expected_race_solid(collision_object: CollisionObject3D) -> bool:
	var object_path: String = str(collision_object.get_path())
	if not object_path.contains("/RoadArena/"):
		return false

	return (
		object_path.ends_with("/Ground")
		or object_path.ends_with("/Road")
		or object_path.ends_with("/LeftRail")
		or object_path.ends_with("/RightRail")
	)
