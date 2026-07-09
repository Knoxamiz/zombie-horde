class_name MapMovingObstacle
extends AnimatableBody3D

## Reusable kinematic moving obstacle for AI map prototypes.
## Uses physics collision only — does not kill zombies or edit zombie movement.
## Hazard damage must use existing approved paths (e.g. BounceObstacle + GameEvents).

const MOVEMENT_LINEAR := "linear"
const MOVEMENT_PING_PONG := "ping_pong"
const MOVEMENT_ROTATION := "rotation"

const AXIS_X := "x"
const AXIS_Y := "y"
const AXIS_Z := "z"

@export var movement_type: String = MOVEMENT_PING_PONG
@export var movement_axis: String = AXIS_X
@export var movement_distance: float = 2.0
@export var cycle_time: float = 4.0
@export var phase_offset: float = 0.0
@export var pause_at_ends_sec: float = 0.2
@export var hazard_behavior: String = "block"
@export var auto_start: bool = true

var asset_id: String = ""
var _origin_position: Vector3 = Vector3.ZERO
var _origin_rotation: Vector3 = Vector3.ZERO
var _elapsed: float = 0.0
var _paused: bool = false


func _ready() -> void:
	_origin_position = position
	_origin_rotation = rotation_degrees
	sync_to_physics = true
	collision_layer = 1
	collision_mask = 0
	_elapsed = phase_offset


func configure_from_asset(entry: Dictionary, cycle_override: float = 0.0) -> void:
	asset_id = str(entry.get("asset_id", ""))
	movement_type = str(entry.get("movement_type", MOVEMENT_PING_PONG))
	movement_axis = str(entry.get("movement_axis", AXIS_X))
	movement_distance = float(entry.get("movement_distance", 2.0))
	cycle_time = cycle_override if cycle_override > 0.0 else float(entry.get("cycle_time", 4.0))
	phase_offset = float(entry.get("phase_offset", 0.0))
	pause_at_ends_sec = float(entry.get("pause_at_ends_sec", 0.2))
	hazard_behavior = str(entry.get("hazard_behavior", "block"))
	name = "MapMovingObstacle_%s" % asset_id if not asset_id.is_empty() else "MapMovingObstacle"
	_elapsed = phase_offset
	_apply_pose(0.0)


func reset_obstacle() -> void:
	_paused = false
	_elapsed = phase_offset
	position = _origin_position
	rotation_degrees = _origin_rotation
	_apply_pose(0.0)


func pause_obstacle() -> void:
	_paused = true


func resume_obstacle() -> void:
	_paused = false


func is_paused() -> bool:
	return _paused


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
		MOVEMENT_ROTATION:
			_apply_rotation(time_sec)
		_:
			_apply_linear(time_sec, true)


func _apply_linear(time_sec: float, ping_pong: bool) -> void:
	var travel_time: float = max(cycle_time - pause_at_ends_sec * 2.0, 0.1)
	var loop_time: float = travel_time + pause_at_ends_sec * 2.0
	var local_t: float = fmod(time_sec, loop_time)
	var moving: bool = true
	var progress: float = 0.0

	if local_t < pause_at_ends_sec:
		progress = 0.0 if not ping_pong or int(time_sec / loop_time) % 2 == 0 else 1.0
		moving = false
	elif local_t > pause_at_ends_sec + travel_time:
		progress = 1.0 if not ping_pong or int(time_sec / loop_time) % 2 == 0 else 0.0
		moving = false
	else:
		progress = (local_t - pause_at_ends_sec) / travel_time

	if not moving:
		pass
	elif ping_pong and int(time_sec / loop_time) % 2 == 1:
		progress = 1.0 - progress

	var offset: float = movement_distance * progress
	_apply_axis_offset(offset)


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


static func attach_visual(obstacle: MapMovingObstacle, visual: Node3D, collision_size: Vector3) -> void:
	if visual == null:
		return
	visual.name = "Visual"
	obstacle.add_child(visual)
	var shape := CollisionShape3D.new()
	shape.name = "Collision"
	var box := BoxShape3D.new()
	box.size = collision_size
	shape.shape = box
	shape.position = Vector3(0.0, collision_size.y * 0.5, 0.0)
	obstacle.add_child(shape)
