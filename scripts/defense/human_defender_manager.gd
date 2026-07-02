class_name HumanDefenderManager
extends Node3D

@export var config: HumanDefenderConfig
@export var defender_scene: PackedScene
@export var zombie_manager_path: NodePath

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _zombie_manager: ZombieManager
var _defenders: Array[HumanDefender] = []
var _reserved_positions: Array[Vector3] = []

func _ready() -> void:
	_rng.randomize()
	_zombie_manager = get_node_or_null(zombie_manager_path) as ZombieManager

func setup_round(round_number: int, reserved_positions: Array[Vector3] = []) -> void:
	clear_defenders()
	if config == null or defender_scene == null:
		return

	if _zombie_manager == null:
		_zombie_manager = get_node_or_null(zombie_manager_path) as ZombieManager
	if _zombie_manager == null:
		return

	_rng.seed = int(Time.get_ticks_msec()) + round_number * 6317 + 211
	_reserved_positions.clear()
	for reserved_position in reserved_positions:
		_reserved_positions.append(reserved_position)
	var defender_total: int = max(config.defender_count, 0)
	for index in range(defender_total):
		var defender: HumanDefender = defender_scene.instantiate() as HumanDefender
		if defender == null:
			continue

		add_child(defender)
		defender.name = "HumanDefender_%02d" % (index + 1)
		defender.global_position = _get_defender_position()
		_face_road_center(defender)
		defender.configure(config, _zombie_manager, int(_rng.randi()))
		_defenders.append(defender)
		_reserved_positions.append(defender.global_position)

func clear_defenders() -> void:
	for defender in _defenders:
		if is_instance_valid(defender):
			defender.queue_free()
	_defenders.clear()
	_reserved_positions.clear()

func set_round_active(active: bool) -> void:
	for defender in _defenders:
		if is_instance_valid(defender):
			defender.set_round_active(active)

func get_living_count() -> int:
	var living_count: int = 0
	for defender in _defenders:
		if is_instance_valid(defender) and defender.is_alive():
			living_count += 1
	return living_count

func _get_defender_position() -> Vector3:
	for _attempt in range(96):
		var candidate: Vector3 = _get_random_defender_position()
		if (
			_is_position_clear(candidate, _reserved_positions, config.reserved_position_clearance)
			and _is_position_clear(candidate, _defender_positions(), config.defender_min_spacing)
		):
			return candidate

	return _get_random_defender_position()

func _get_random_defender_position() -> Vector3:
	return Vector3(
		_rng.randf_range(-config.placement_half_width, config.placement_half_width),
		0.12,
		_rng.randf_range(config.placement_min_z, config.placement_max_z)
	)

func _face_road_center(defender: HumanDefender) -> void:
	var look_target: Vector3 = Vector3(0.0, defender.global_position.y, defender.global_position.z)
	if defender.global_position.distance_squared_to(look_target) > 0.001:
		defender.look_at(look_target, Vector3.UP)

func _defender_positions() -> Array[Vector3]:
	var result: Array[Vector3] = []
	for defender in _defenders:
		if is_instance_valid(defender):
			result.append(defender.global_position)
	return result

func _is_position_clear(candidate: Vector3, used_positions: Array[Vector3], minimum_distance: float) -> bool:
	var minimum_distance_squared: float = minimum_distance * minimum_distance
	for used_position in used_positions:
		var offset: Vector3 = candidate - used_position
		offset.y = 0.0
		if offset.length_squared() < minimum_distance_squared:
			return false
	return true
