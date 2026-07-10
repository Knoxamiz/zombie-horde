class_name SpectatorCameraController
extends Node3D

@export var move_speed: float = 16.0
@export var boost_multiplier: float = 2.4
@export var mouse_sensitivity: float = 0.08
@export var min_pitch_degrees: float = -82.0
@export var max_pitch_degrees: float = 74.0
@export var capture_mouse_on_start: bool = true
@export var recapture_on_click: bool = true
@export var zombie_manager_path: NodePath
@export var auto_director_on_round_start: bool = true
@export var director_follow_distance: float = 16.0
@export var director_follow_height: float = 9.0
@export var director_side_offset: float = 3.5
@export var director_look_ahead_distance: float = 7.5
@export var director_focus_height: float = 1.4
@export var director_position_smoothing: float = 4.8
@export var director_rotation_smoothing: float = 7.0
@export var overview_position: Vector3 = Vector3(0.0, 23.0, -46.0)
@export var overview_rotation_degrees: Vector3 = Vector3(-31.0, 180.0, 0.0)
@export var position_limits_enabled: bool = true
@export var camera_bounds_min: Vector3 = Vector3(-18.0, 2.2, -52.0)
@export var camera_bounds_max: Vector3 = Vector3(18.0, 38.0, 52.0)

var _look_enabled: bool = false
var _yaw_degrees: float = 0.0
var _pitch_degrees: float = -24.0
var _shake_timer: float = 0.0
var _shake_duration: float = 0.0
var _shake_strength: float = 0.0
var _camera_rest_position: Vector3 = Vector3.ZERO
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _director_enabled: bool = false
var _annotation_paint_active: bool = false
var _zombie_manager: ZombieManager

@onready var _camera: Camera3D = get_node("Camera3D") as Camera3D

func _ready() -> void:
	_rng.randomize()
	_zombie_manager = get_node_or_null(zombie_manager_path) as ZombieManager
	global_position = _clamp_to_bounds(global_position)
	_yaw_degrees = rotation_degrees.y
	_pitch_degrees = rotation_degrees.x
	_apply_rotation()
	if _camera != null:
		_camera.current = true
		_camera_rest_position = _camera.position
	GameEvents.camera_shake_requested.connect(_on_camera_shake_requested)
	GameEvents.round_started.connect(_on_round_started)
	GameEvents.round_ended.connect(_on_round_ended)
	GameEvents.round_reset.connect(_on_round_reset)
	if capture_mouse_on_start:
		call_deferred("_capture_mouse_after_start")

func _input(event: InputEvent) -> void:
	if _annotation_paint_active:
		_handle_annotation_paint_input(event)
		return

	var key_event: InputEventKey = event as InputEventKey
	if key_event != null and key_event.pressed and not key_event.echo and key_event.physical_keycode == KEY_ESCAPE:
		_set_look_enabled(false)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("camera_director"):
		_set_director_enabled(not _director_enabled)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("camera_overview"):
		_set_director_enabled(false)
		_snap_to_overview()
		get_viewport().set_input_as_handled()
		return

	var mouse_button: InputEventMouseButton = event as InputEventMouseButton
	if mouse_button != null and mouse_button.pressed and recapture_on_click and not _look_enabled:
		if get_viewport().gui_get_hovered_control() != null:
			return
		_set_director_enabled(false)
		_set_look_enabled(true)
		get_viewport().set_input_as_handled()
		return

	var mouse_motion: InputEventMouseMotion = event as InputEventMouseMotion
	if mouse_motion != null and _look_enabled:
		_set_director_enabled(false)
		_yaw_degrees -= mouse_motion.relative.x * mouse_sensitivity
		_pitch_degrees -= mouse_motion.relative.y * mouse_sensitivity
		_pitch_degrees = clamp(_pitch_degrees, min_pitch_degrees, max_pitch_degrees)
		_apply_rotation()
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	var input_direction: Vector3 = Vector3.ZERO
	if Input.is_action_pressed("camera_forward"):
		input_direction.z -= 1.0
	if Input.is_action_pressed("camera_back"):
		input_direction.z += 1.0
	if Input.is_action_pressed("camera_left"):
		input_direction.x -= 1.0
	if Input.is_action_pressed("camera_right"):
		input_direction.x += 1.0
	if Input.is_action_pressed("camera_up"):
		input_direction.y += 1.0
	if Input.is_action_pressed("camera_down"):
		input_direction.y -= 1.0

	if input_direction != Vector3.ZERO:
		_set_director_enabled(false)
		var speed: float = move_speed
		if Input.is_action_pressed("camera_boost"):
			speed *= boost_multiplier

		global_position += global_transform.basis * input_direction.normalized() * speed * delta
		global_position = _clamp_to_bounds(global_position)
	elif _director_enabled:
		_update_director_camera(delta)

	_update_camera_shake(delta)

func _apply_rotation() -> void:
	rotation_degrees = Vector3(_pitch_degrees, _yaw_degrees, 0.0)

func _set_look_enabled(enabled: bool) -> void:
	_look_enabled = enabled
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED if _look_enabled else Input.MOUSE_MODE_VISIBLE)

func _capture_mouse_after_start() -> void:
	await get_tree().process_frame
	_set_look_enabled(true)

func _snap_to_overview() -> void:
	global_position = _clamp_to_bounds(overview_position)
	_pitch_degrees = overview_rotation_degrees.x
	_yaw_degrees = overview_rotation_degrees.y
	_apply_rotation()

func set_view(new_global_position: Vector3, new_rotation_degrees: Vector3, enable_mouse_look: bool) -> void:
	_set_director_enabled(false)
	global_position = _clamp_to_bounds(new_global_position)
	_pitch_degrees = clamp(new_rotation_degrees.x, min_pitch_degrees, max_pitch_degrees)
	_yaw_degrees = new_rotation_degrees.y
	_apply_rotation()
	_set_look_enabled(enable_mouse_look)
	if _camera != null:
		_camera.current = true


func update_bounds_for_map_definition(definition: RaceMapDefinition) -> void:
	if definition == null:
		return
	var side_extent: float = max(definition.lane_half_width + 8.0, 14.0)
	var min_z: float = min(definition.spawn_origin.z, definition.goal_position.z) - 12.0
	var max_z: float = max(definition.spawn_origin.z, definition.goal_position.z) + 12.0
	camera_bounds_min = Vector3(-side_extent, 2.2, min_z)
	camera_bounds_max = Vector3(side_extent, 38.0, max_z)

func set_mouse_capture_allowed(allowed: bool) -> void:
	recapture_on_click = allowed
	if not allowed:
		_set_director_enabled(false)
		_set_look_enabled(false)


func set_annotation_paint_active(active: bool) -> void:
	_annotation_paint_active = active
	if active:
		_set_director_enabled(false)
		_set_look_enabled(false)
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	elif recapture_on_click:
		_set_look_enabled(true)


func is_annotation_paint_active() -> bool:
	return _annotation_paint_active


func _handle_annotation_paint_input(event: InputEvent) -> void:
	var key_event: InputEventKey = event as InputEventKey
	if key_event != null and key_event.pressed and not key_event.echo and key_event.physical_keycode == KEY_ESCAPE:
		for node in get_tree().get_nodes_in_group(DevAnnotationPainter.GROUP_NAME):
			var painter: DevAnnotationPainter = node as DevAnnotationPainter
			if painter != null:
				painter.set_paint_mode_enabled(false)
		get_viewport().set_input_as_handled()
		return

	var mouse_button: InputEventMouseButton = event as InputEventMouseButton
	if mouse_button != null and mouse_button.button_index == MOUSE_BUTTON_RIGHT:
		if mouse_button.pressed:
			_set_director_enabled(false)
			_set_look_enabled(true)
		else:
			_set_look_enabled(false)
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		get_viewport().set_input_as_handled()
		return

	var mouse_motion: InputEventMouseMotion = event as InputEventMouseMotion
	if mouse_motion != null and _look_enabled:
		_yaw_degrees -= mouse_motion.relative.x * mouse_sensitivity
		_pitch_degrees -= mouse_motion.relative.y * mouse_sensitivity
		_pitch_degrees = clamp(_pitch_degrees, min_pitch_degrees, max_pitch_degrees)
		_apply_rotation()
		get_viewport().set_input_as_handled()

func set_director_enabled(enabled: bool) -> void:
	_set_director_enabled(enabled)

func _clamp_to_bounds(target_position: Vector3) -> Vector3:
	if not position_limits_enabled:
		return target_position

	var min_x: float = min(camera_bounds_min.x, camera_bounds_max.x)
	var max_x: float = max(camera_bounds_min.x, camera_bounds_max.x)
	var min_y: float = min(camera_bounds_min.y, camera_bounds_max.y)
	var max_y: float = max(camera_bounds_min.y, camera_bounds_max.y)
	var min_z: float = min(camera_bounds_min.z, camera_bounds_max.z)
	var max_z: float = max(camera_bounds_min.z, camera_bounds_max.z)

	return Vector3(
		clamp(target_position.x, min_x, max_x),
		clamp(target_position.y, min_y, max_y),
		clamp(target_position.z, min_z, max_z)
	)

func _on_camera_shake_requested(strength: float, duration: float) -> void:
	_shake_strength = max(_shake_strength, strength)
	_shake_duration = max(_shake_duration, duration)
	_shake_timer = max(_shake_timer, duration)

func _on_round_started(_round_number: int) -> void:
	if auto_director_on_round_start:
		_set_director_enabled(true)

func _on_round_ended(_winner_name: String, _base_won: bool) -> void:
	_set_director_enabled(false)

func _on_round_reset() -> void:
	_set_director_enabled(false)

func _update_camera_shake(delta: float) -> void:
	if _camera == null:
		return

	if _shake_timer <= 0.0:
		_camera.position = _camera_rest_position
		return

	_shake_timer = max(0.0, _shake_timer - delta)
	var progress: float = 1.0
	if _shake_duration > 0.001:
		progress = _shake_timer / _shake_duration
	var amount: float = _shake_strength * progress
	_camera.position = _camera_rest_position + Vector3(
		_rng.randf_range(-amount, amount),
		_rng.randf_range(-amount, amount),
		0.0
	)

	if _shake_timer <= 0.0:
		_camera.position = _camera_rest_position
		_shake_strength = 0.0
		_shake_duration = 0.0

func _set_director_enabled(enabled: bool) -> void:
	_director_enabled = enabled and recapture_on_click and _zombie_manager != null

func _update_director_camera(delta: float) -> void:
	if _zombie_manager == null:
		_set_director_enabled(false)
		return

	var leader: Zombie = _zombie_manager.get_leader_zombie()
	if leader == null or not leader.is_alive():
		return

	var target_position: Vector3 = leader.global_position
	var focus_position: Vector3 = target_position + Vector3(0.0, director_focus_height, director_look_ahead_distance)
	var desired_position: Vector3 = target_position + Vector3(director_side_offset, director_follow_height, -director_follow_distance)
	desired_position = _clamp_to_bounds(desired_position)

	var position_weight: float = 1.0 - exp(-max(director_position_smoothing, 0.01) * delta)
	global_position = global_position.lerp(desired_position, position_weight)

	var direction: Vector3 = focus_position - global_position
	if direction.length_squared() < 0.001:
		return

	direction = direction.normalized()
	var desired_pitch: float = rad_to_deg(asin(clamp(direction.y, -1.0, 1.0)))
	var desired_yaw: float = rad_to_deg(atan2(-direction.x, -direction.z))
	var rotation_weight: float = 1.0 - exp(-max(director_rotation_smoothing, 0.01) * delta)
	_pitch_degrees = rad_to_deg(lerp_angle(deg_to_rad(_pitch_degrees), deg_to_rad(desired_pitch), rotation_weight))
	_yaw_degrees = rad_to_deg(lerp_angle(deg_to_rad(_yaw_degrees), deg_to_rad(desired_yaw), rotation_weight))
	_pitch_degrees = clamp(_pitch_degrees, min_pitch_degrees, max_pitch_degrees)
	_apply_rotation()
