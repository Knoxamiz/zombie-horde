class_name MapLabSimMover
extends Node3D

enum State {
	MOVING,
	REACHED_GOAL,
	FELL_HAZARD,
	STUCK,
	LEFT_ROUTE,
}

const STUCK_TIME_SEC: float = 3.0
const STUCK_DISTANCE_EPS: float = 0.08

var mover_id: String = ""
var is_hazard_probe: bool = false
var move_speed: float = 12.0
var goal_z: float = 44.0
var safe_half_width: float = 4.0
var hazard_direction: Vector3 = Vector3.ZERO

var state: int = State.MOVING
var _stuck_timer: float = 0.0
var _last_position: Vector3 = Vector3.ZERO
var _mesh: MeshInstance3D


func setup(
	id: String,
	start_position: Vector3,
	is_probe: bool,
	speed: float,
	target_goal_z: float,
	lane_half_width: float,
	probe_direction: Vector3 = Vector3.ZERO
) -> void:
	mover_id = id
	is_hazard_probe = is_probe
	move_speed = speed
	goal_z = target_goal_z
	safe_half_width = lane_half_width
	hazard_direction = probe_direction.normalized() if probe_direction.length_squared() > 0.001 else Vector3.ZERO
	position = start_position
	_last_position = start_position
	name = id
	_build_visual(is_probe)
	print("MapLabSim: mover started %s at %s" % [mover_id, start_position])


func tick(delta: float, hazard_zones: Array) -> void:
	if state != State.MOVING:
		return

	var previous_position: Vector3 = global_position
	if is_hazard_probe and hazard_direction.length_squared() > 0.001:
		global_position += hazard_direction * move_speed * delta
	else:
		var forward: Vector3 = Vector3(0.0, 0.0, 1.0)
		global_position += forward * move_speed * delta
		if global_position.z >= goal_z:
			global_position.z = goal_z
			_finish(State.REACHED_GOAL, "mover reached goal")
			return

	if _check_hazard_overlap(hazard_zones):
		_finish(State.FELL_HAZARD, "mover fell / hazard hit")
		return

	if not is_hazard_probe and abs(global_position.x) > safe_half_width + 0.35:
		_finish(State.LEFT_ROUTE, "mover left route")
		return

	if global_position.distance_squared_to(_last_position) <= STUCK_DISTANCE_EPS * STUCK_DISTANCE_EPS:
		_stuck_timer += delta
	else:
		_stuck_timer = 0.0
		_last_position = global_position

	if _stuck_timer >= STUCK_TIME_SEC:
		_finish(State.STUCK, "mover stuck")


func is_finished() -> bool:
	return state != State.MOVING


func get_result_category() -> String:
	if is_hazard_probe:
		return "hazard"
	return "safe"


func get_result_outcome() -> String:
	match state:
		State.REACHED_GOAL:
			return "reached_goal"
		State.FELL_HAZARD:
			return "fell_hazard"
		State.STUCK:
			return "stuck"
		State.LEFT_ROUTE:
			return "left_route"
		_:
			return "moving"


func _finish(next_state: int, log_message: String) -> void:
	state = next_state
	_set_visual_state(next_state)
	print("MapLabSim: %s - %s" % [mover_id, log_message])


func _check_hazard_overlap(hazard_zones: Array) -> bool:
	var probe_position: Vector3 = global_position
	for hazard in hazard_zones:
		if hazard is not Dictionary:
			continue
		var zone_position: Vector3 = hazard.get("position", Vector3.ZERO)
		var zone_size: Vector3 = hazard.get("size", Vector3.ONE)
		var half: Vector3 = zone_size * 0.5
		if (
			abs(probe_position.x - zone_position.x) <= half.x
			and abs(probe_position.y - zone_position.y) <= half.y + 1.0
			and abs(probe_position.z - zone_position.z) <= half.z
		):
			return true
	return false


func _build_visual(is_probe: bool) -> void:
	_mesh = MeshInstance3D.new()
	_mesh.name = "Body"
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.32
	capsule.height = 1.1
	_mesh.mesh = capsule
	_mesh.position = Vector3(0.0, 0.75, 0.0)
	var material := StandardMaterial3D.new()
	if is_probe:
		material.albedo_color = Color(1.0, 0.35, 0.2, 1.0)
		material.emission = Color(1.0, 0.2, 0.1)
	else:
		material.albedo_color = Color(0.25, 0.95, 0.45, 1.0)
		material.emission = Color(0.1, 0.8, 0.25)
	material.emission_enabled = true
	material.emission_energy_multiplier = 0.55
	_mesh.material_override = material
	add_child(_mesh)


func _set_visual_state(next_state: int) -> void:
	if _mesh == null:
		return
	var material := _mesh.material_override as StandardMaterial3D
	if material == null:
		return
	match next_state:
		State.REACHED_GOAL:
			material.albedo_color = Color(0.3, 0.75, 1.0)
			material.emission = Color(0.2, 0.6, 1.0)
		State.FELL_HAZARD:
			material.albedo_color = Color(0.9, 0.15, 0.15)
			material.emission = Color(1.0, 0.1, 0.1)
		State.STUCK, State.LEFT_ROUTE:
			material.albedo_color = Color(0.95, 0.85, 0.2)
			material.emission = Color(1.0, 0.7, 0.1)
