class_name MapMovingObstacle
extends AnimatableBody3D

## Reusable kinematic moving obstacle for AI map prototypes.
## Uses physics collision only — does not kill zombies or edit zombie movement.
## Hazard damage must use existing approved paths (e.g. BounceObstacle + GameEvents).

const MOVEMENT_LINEAR := "linear"
const MOVEMENT_PING_PONG := "ping_pong"
const MOVEMENT_ROTATION := "rotation"
const MOVEMENT_GATE := "gate"

const AXIS_X := "x"
const AXIS_Y := "y"
const AXIS_Z := "z"

@export var movement_type: String = MOVEMENT_PING_PONG
@export var movement_axis: String = AXIS_X
@export var movement_distance: float = 2.0
@export var cycle_time: float = 4.0
@export var phase_offset: float = 0.0
@export var pause_at_ends_sec: float = 0.2
@export var pause_at_start_sec: float = -1.0
@export var pause_at_end_sec: float = -1.0
@export var gate_open_ratio: float = 0.65
@export var hazard_behavior: String = "block"
@export var obstacle_display_name: String = ""
@export var auto_start: bool = true

var asset_id: String = ""
var _origin_position: Vector3 = Vector3.ZERO
var _origin_rotation: Vector3 = Vector3.ZERO
var _elapsed: float = 0.0
var _paused: bool = false
var _round_reset_connected: bool = false


func _ready() -> void:
	_capture_origin()
	sync_to_physics = true
	collision_layer = 1
	collision_mask = 0
	_elapsed = phase_offset
	_connect_round_reset()


func configure_from_asset(entry: Dictionary, cycle_override: float = 0.0) -> void:
	asset_id = str(entry.get("asset_id", ""))
	movement_type = str(entry.get("movement_type", MOVEMENT_PING_PONG))
	movement_axis = str(entry.get("movement_axis", AXIS_X))
	movement_distance = float(entry.get("movement_distance", 2.0))
	cycle_time = cycle_override if cycle_override > 0.0 else float(entry.get("cycle_time", 4.0))
	phase_offset = float(entry.get("phase_offset", 0.0))
	pause_at_ends_sec = float(entry.get("pause_at_ends_sec", 0.2))
	pause_at_start_sec = float(entry.get("pause_at_start_sec", -1.0))
	pause_at_end_sec = float(entry.get("pause_at_end_sec", -1.0))
	gate_open_ratio = float(entry.get("gate_open_ratio", 0.65))
	hazard_behavior = str(entry.get("hazard_behavior", "block"))
	obstacle_display_name = str(entry.get("display_name", asset_id))
	if obstacle_display_name.is_empty():
		obstacle_display_name = asset_id
	name = "MapMovingObstacle_%s" % asset_id if not asset_id.is_empty() else name
	_elapsed = phase_offset
	if is_inside_tree():
		_capture_origin()
	_apply_pose(0.0)


func reset_obstacle() -> void:
	_paused = false
	_elapsed = phase_offset
	position = _origin_position
	rotation_degrees = _origin_rotation
	_apply_pose(0.0)


func reset_to_start() -> void:
	reset_obstacle()


func pause_obstacle() -> void:
	_paused = true


func resume_obstacle() -> void:
	_paused = false


func is_paused() -> bool:
	return _paused


func get_origin_position() -> Vector3:
	return _origin_position


static func reset_all_in_node(root: Node) -> int:
	var count: int = 0
	if root == null:
		return count
	if root is MapMovingObstacle:
		(root as MapMovingObstacle).reset_obstacle()
		count += 1
	for child in root.get_children():
		count += reset_all_in_node(child)
	return count


func _physics_process(delta: float) -> void:
	if _paused or not auto_start or cycle_time <= 0.001:
		return
	_elapsed += delta
	_apply_pose(_elapsed)


func _apply_pose(time_sec: float) -> void:
	position = _origin_position
	rotation_degrees = _origin_rotation

	match movement_type:
		MOVEMENT_LINEAR:
			_apply_linear(time_sec, false)
		MOVEMENT_PING_PONG:
			_apply_linear(time_sec, true)
		MOVEMENT_GATE:
			_apply_gate(time_sec)
		MOVEMENT_ROTATION:
			_apply_rotation(time_sec)
		_:
			_apply_linear(time_sec, true)


func _apply_linear(time_sec: float, ping_pong: bool) -> void:
	var pause_start: float = _resolve_pause_at_start()
	var pause_end: float = _resolve_pause_at_end()
	var travel_time: float = max(cycle_time - pause_start - pause_end, 0.1)
	var loop_time: float = travel_time + pause_start + pause_end
	var local_t: float = fmod(time_sec, loop_time)
	var moving: bool = true
	var progress: float = 0.0

	if local_t < pause_start:
		progress = 0.0 if not ping_pong or int(time_sec / loop_time) % 2 == 0 else 1.0
		moving = false
	elif local_t > pause_start + travel_time:
		progress = 1.0 if not ping_pong or int(time_sec / loop_time) % 2 == 0 else 0.0
		moving = false
	else:
		progress = (local_t - pause_start) / travel_time

	if not moving:
		pass
	elif ping_pong and int(time_sec / loop_time) % 2 == 1:
		progress = 1.0 - progress

	var offset: float = movement_distance * progress
	_apply_axis_offset(offset)


func _apply_gate(time_sec: float) -> void:
	var loop_time: float = max(cycle_time, 0.1)
	var local_t: float = fmod(time_sec + phase_offset, loop_time) / loop_time
	var open_ratio: float = clampf(gate_open_ratio, 0.35, 0.9)
	var progress: float = 0.0
	if local_t > open_ratio:
		progress = (local_t - open_ratio) / max(1.0 - open_ratio, 0.05)
	_apply_axis_offset(movement_distance * progress)


func _apply_rotation(time_sec: float) -> void:
	var angle_deg: float = fmod(time_sec / max(cycle_time, 0.1), 1.0) * 360.0
	match movement_axis:
		AXIS_X:
			rotation_degrees.x = _origin_rotation.x + angle_deg
		AXIS_Y:
			rotation_degrees.y = _origin_rotation.y + angle_deg
		AXIS_Z:
			rotation_degrees.z = _origin_rotation.z + angle_deg


func _apply_axis_offset(offset: float) -> void:
	match movement_axis:
		AXIS_X:
			position.x = _origin_position.x + offset
		AXIS_Y:
			position.y = _origin_position.y + offset
		AXIS_Z:
			position.z = _origin_position.z + offset


func _resolve_pause_at_start() -> float:
	if pause_at_start_sec >= 0.0:
		return pause_at_start_sec
	return pause_at_ends_sec


func _resolve_pause_at_end() -> float:
	if pause_at_end_sec >= 0.0:
		return pause_at_end_sec
	return pause_at_ends_sec


func _capture_origin() -> void:
	_origin_position = position
	_origin_rotation = rotation_degrees


func _connect_round_reset() -> void:
	if _round_reset_connected:
		return
	var events: Node = _resolve_game_events()
	if events == null:
		return
	if not events.round_reset.is_connected(_on_round_reset):
		events.round_reset.connect(_on_round_reset)
	_round_reset_connected = true


func _on_round_reset() -> void:
	reset_obstacle()


func _exit_tree() -> void:
	var events: Node = _resolve_game_events()
	if _round_reset_connected and events != null and events.round_reset.is_connected(_on_round_reset):
		events.round_reset.disconnect(_on_round_reset)
	_round_reset_connected = false


func _resolve_game_events() -> Node:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	return tree.root.get_node_or_null("GameEvents")


static func attach_visual(obstacle: MapMovingObstacle, visual: Node3D, collision_size: Vector3) -> void:
	if obstacle == null:
		return
	if obstacle.get_node_or_null("Collision") != null:
		if visual != null and obstacle.get_node_or_null("Visual") == null:
			visual.name = "Visual"
			obstacle.add_child(visual)
		return
	if visual != null:
		visual.name = "Visual"
		obstacle.add_child(visual)
	var shape := CollisionShape3D.new()
	shape.name = "Collision"
	var box := BoxShape3D.new()
	box.size = collision_size
	shape.shape = box
	shape.position = Vector3(0.0, collision_size.y * 0.5, 0.0)
	obstacle.add_child(shape)
