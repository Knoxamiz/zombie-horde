class_name HazardManager
extends Node3D

@export var hazard_config: HazardConfig
@export var mine_scene: PackedScene
@export var sewer_hole_scene: PackedScene
@export var obstacle_scene: PackedScene
@export var cone_obstacle_scene: PackedScene
@export var vehicle_obstacle_scene: PackedScene

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _spawned_mines: Array[MineTrap] = []
var _spawned_sewer_holes: Array[SewerHoleTrap] = []
var _spawned_obstacles: Array[Node3D] = []
var _reserved_positions: Array[Vector3] = []

func _ready() -> void:
	_rng.randomize()

func setup_preview(round_number: int) -> void:
	clear_hazards()
	if hazard_config == null:
		return

	_rng.seed = int(Time.get_ticks_msec()) + round_number * 7919 + 37
	_spawn_obstacles()

func setup_round(round_number: int) -> void:
	clear_hazards()
	if hazard_config == null:
		return

	_rng.seed = int(Time.get_ticks_msec()) + round_number * 1093
	_spawn_obstacles()
	_spawn_sewer_holes()
	_spawn_mines()

func clear_hazards() -> void:
	for mine in _spawned_mines:
		if is_instance_valid(mine):
			mine.queue_free()
	for sewer_hole in _spawned_sewer_holes:
		if is_instance_valid(sewer_hole):
			sewer_hole.queue_free()
	for obstacle in _spawned_obstacles:
		if is_instance_valid(obstacle):
			obstacle.queue_free()
	_spawned_mines.clear()
	_spawned_sewer_holes.clear()
	_spawned_obstacles.clear()
	_reserved_positions.clear()

func get_reserved_positions() -> Array[Vector3]:
	var result: Array[Vector3] = []
	for reserved_position in _reserved_positions:
		result.append(reserved_position)
	return result

func _spawn_mines() -> void:
	if hazard_config == null or mine_scene == null:
		return

	for index in range(hazard_config.mine_count):
		var mine: MineTrap = mine_scene.instantiate() as MineTrap
		if mine == null:
			continue

		add_child(mine)
		mine.name = "Mine_%02d" % (index + 1)
		mine.global_position = _get_mine_position(_reserved_positions)
		mine.configure(hazard_config, int(_rng.randi()))
		_spawned_mines.append(mine)
		_reserved_positions.append(mine.global_position)

func _spawn_sewer_holes() -> void:
	if hazard_config == null or sewer_hole_scene == null:
		return

	for index in range(hazard_config.sewer_hole_count):
		var sewer_hole: SewerHoleTrap = sewer_hole_scene.instantiate() as SewerHoleTrap
		if sewer_hole == null:
			continue

		add_child(sewer_hole)
		sewer_hole.name = "SewerHole_%02d" % (index + 1)
		sewer_hole.global_position = _get_sewer_hole_position(_reserved_positions)
		sewer_hole.configure(hazard_config)
		_spawned_sewer_holes.append(sewer_hole)
		_reserved_positions.append(sewer_hole.global_position)

func _spawn_obstacles() -> void:
	if hazard_config == null:
		return

	var segment_slots: Dictionary = {}
	var large_counts: Dictionary = {}
	for index in range(hazard_config.obstacle_count):
		var selected_scene: PackedScene = _pick_obstacle_scene()
		if selected_scene == null:
			return

		var placement: Dictionary = _get_obstacle_position(segment_slots, large_counts, selected_scene)
		if not bool(placement.get("valid", false)) and _is_large_obstacle_scene(selected_scene):
			if cone_obstacle_scene == null:
				continue
			selected_scene = cone_obstacle_scene
			placement = _get_obstacle_position(segment_slots, large_counts, selected_scene)
		if not bool(placement.get("valid", false)):
			continue
		if selected_scene == null:
			continue

		var obstacle: Node3D = selected_scene.instantiate() as Node3D
		if obstacle == null:
			continue

		add_child(obstacle)
		obstacle.name = "RoadObstacle_%02d" % (index + 1)
		var obstacle_position: Vector3 = placement.get("position", Vector3.ZERO)
		obstacle.global_position = obstacle_position
		obstacle.rotation_degrees.y = _rng.randf_range(-hazard_config.obstacle_rotation_degrees, hazard_config.obstacle_rotation_degrees)
		_spawned_obstacles.append(obstacle)
		_reserved_positions.append(obstacle_position)

func _get_mine_position(used_positions: Array[Vector3]) -> Vector3:
	for _attempt in range(64):
		var candidate: Vector3 = _get_random_mine_position()
		if (
			_is_position_clear(candidate, used_positions, hazard_config.mine_hazard_clearance)
			and _is_position_clear(candidate, _spawned_mine_positions(), hazard_config.mine_min_spacing)
		):
			return candidate

	return _get_random_mine_position()

func _get_sewer_hole_position(used_positions: Array[Vector3]) -> Vector3:
	for _attempt in range(80):
		var candidate: Vector3 = _get_random_sewer_hole_position()
		if (
			_is_position_clear(candidate, used_positions, hazard_config.sewer_hole_clearance)
			and _is_position_clear(candidate, _spawned_sewer_hole_positions(), hazard_config.sewer_hole_min_spacing)
		):
			return candidate

	return _get_random_sewer_hole_position()

func _get_random_mine_position() -> Vector3:
	return Vector3(
		_rng.randf_range(-hazard_config.placement_half_width, hazard_config.placement_half_width),
		0.18,
		_rng.randf_range(hazard_config.placement_min_z, hazard_config.placement_max_z)
	)

func _get_random_sewer_hole_position() -> Vector3:
	return Vector3(
		_rng.randf_range(-hazard_config.placement_half_width, hazard_config.placement_half_width),
		0.08,
		_rng.randf_range(hazard_config.placement_min_z, hazard_config.placement_max_z)
	)

func _get_obstacle_position(segment_slots: Dictionary, large_counts: Dictionary, selected_scene: PackedScene) -> Dictionary:
	var segment_count: int = _get_obstacle_segment_count()
	if segment_count <= 0:
		return {"valid": false}

	for _attempt in range(96):
		var segment_index: int = _rng.randi_range(0, segment_count - 1)
		var available_lanes: Array[int] = _get_available_lanes(segment_slots, large_counts, segment_index, selected_scene)
		if available_lanes.is_empty():
			continue

		var lane_index: int = available_lanes[_rng.randi_range(0, available_lanes.size() - 1)]
		var candidate: Vector3 = _get_obstacle_slot_position(segment_index, lane_index)
		if not _is_position_clear(candidate, _reserved_positions, hazard_config.obstacle_min_spacing):
			continue

		_reserve_obstacle_slot(segment_slots, large_counts, segment_index, lane_index, selected_scene)
		return {
			"valid": true,
			"position": candidate
		}

	return {"valid": false}

func _get_available_lanes(
	segment_slots: Dictionary,
	large_counts: Dictionary,
	segment_index: int,
	selected_scene: PackedScene
) -> Array[int]:
	var lane_count: int = _get_obstacle_lane_count()
	var occupied_lanes: Array = segment_slots.get(segment_index, [])
	var guaranteed_open_lanes: int = clamp(hazard_config.guaranteed_open_lanes_per_segment, 0, lane_count)
	var max_blocked_lanes: int = max(0, lane_count - guaranteed_open_lanes)
	var segment_capacity: int = min(hazard_config.max_obstacles_per_segment, max_blocked_lanes)
	if occupied_lanes.size() >= segment_capacity:
		return []

	if _is_large_obstacle_scene(selected_scene):
		var large_count: int = int(large_counts.get(segment_index, 0))
		if large_count >= hazard_config.max_large_obstacles_per_segment:
			return []

	var result: Array[int] = []
	for lane_index in range(lane_count):
		if not occupied_lanes.has(lane_index):
			result.append(lane_index)
	return result

func _reserve_obstacle_slot(
	segment_slots: Dictionary,
	large_counts: Dictionary,
	segment_index: int,
	lane_index: int,
	selected_scene: PackedScene
) -> void:
	var occupied_lanes: Array = segment_slots.get(segment_index, [])
	occupied_lanes.append(lane_index)
	segment_slots[segment_index] = occupied_lanes

	if _is_large_obstacle_scene(selected_scene):
		large_counts[segment_index] = int(large_counts.get(segment_index, 0)) + 1

func _get_obstacle_slot_position(segment_index: int, lane_index: int) -> Vector3:
	var segment_length: float = max(hazard_config.obstacle_segment_length, 0.5)
	var segment_start: float = hazard_config.obstacle_min_z + float(segment_index) * segment_length
	var segment_end: float = min(segment_start + segment_length, hazard_config.obstacle_max_z)
	var segment_center: float = (segment_start + segment_end) * 0.5
	var z_jitter: float = min(segment_length * 0.22, max((segment_end - segment_start) * 0.42, 0.0))
	var x_position: float = _get_lane_center_x(lane_index)

	return Vector3(
		clamp(x_position + _rng.randf_range(-hazard_config.obstacle_lane_jitter, hazard_config.obstacle_lane_jitter), -hazard_config.obstacle_half_width, hazard_config.obstacle_half_width),
		0.45,
		clamp(segment_center + _rng.randf_range(-z_jitter, z_jitter), hazard_config.obstacle_min_z, hazard_config.obstacle_max_z)
	)

func _get_lane_center_x(lane_index: int) -> float:
	var lane_count: int = _get_obstacle_lane_count()
	if lane_count <= 1:
		return 0.0

	var lane_spacing: float = (hazard_config.obstacle_half_width * 2.0) / float(lane_count)
	return -hazard_config.obstacle_half_width + lane_spacing * 0.5 + lane_spacing * float(lane_index)

func _get_obstacle_lane_count() -> int:
	return max(hazard_config.obstacle_lane_count, 1)

func _get_obstacle_segment_count() -> int:
	var segment_length: float = max(hazard_config.obstacle_segment_length, 0.5)
	var placement_length: float = max(hazard_config.obstacle_max_z - hazard_config.obstacle_min_z, 0.0)
	return int(ceil(placement_length / segment_length))

func _is_large_obstacle_scene(scene: PackedScene) -> bool:
	return scene == obstacle_scene or scene == vehicle_obstacle_scene

func _spawned_mine_positions() -> Array[Vector3]:
	var result: Array[Vector3] = []
	for mine in _spawned_mines:
		if is_instance_valid(mine):
			result.append(mine.global_position)
	return result

func _spawned_sewer_hole_positions() -> Array[Vector3]:
	var result: Array[Vector3] = []
	for sewer_hole in _spawned_sewer_holes:
		if is_instance_valid(sewer_hole):
			result.append(sewer_hole.global_position)
	return result

func _is_position_clear(candidate: Vector3, used_positions: Array[Vector3], minimum_distance: float) -> bool:
	var minimum_distance_squared: float = minimum_distance * minimum_distance
	for used_position in used_positions:
		var offset: Vector3 = candidate - used_position
		offset.y = 0.0
		if offset.length_squared() < minimum_distance_squared:
			return false
	return true

func _pick_obstacle_scene() -> PackedScene:
	var active_config: HazardConfig = hazard_config
	if active_config == null:
		return null

	var weighted_scenes: Array[PackedScene] = []
	_append_weighted_scene(weighted_scenes, obstacle_scene, active_config.barrier_obstacle_weight)
	_append_weighted_scene(weighted_scenes, cone_obstacle_scene, active_config.cone_obstacle_weight)
	_append_weighted_scene(weighted_scenes, vehicle_obstacle_scene, active_config.vehicle_obstacle_weight)

	if weighted_scenes.is_empty():
		return null

	return weighted_scenes[_rng.randi_range(0, weighted_scenes.size() - 1)]

func _append_weighted_scene(weighted_scenes: Array[PackedScene], scene: PackedScene, weight: int) -> void:
	if scene == null or weight <= 0:
		return

	for _weight_index in range(weight):
		weighted_scenes.append(scene)
