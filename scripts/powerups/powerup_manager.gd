class_name PowerupManager
extends Node3D

const SURFACE_SPAWN_RESOLVER := preload("res://scripts/maps/surface_spawn_resolver.gd")

@export var powerup_config: PowerupConfig
@export var boost_pad_scene: PackedScene

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _spawned_powerups: Array[BoostPad] = []

func _ready() -> void:
	_rng.randomize()

func setup_round(round_number: int, reserved_positions: Array[Vector3] = []) -> void:
	clear_powerups()
	if powerup_config == null or boost_pad_scene == null:
		return

	_rng.seed = int(Time.get_ticks_msec()) + round_number * 2113
	var hazard_positions: Array[Vector3] = []
	for reserved_position in reserved_positions:
		hazard_positions.append(reserved_position)
	var boost_positions: Array[Vector3] = []

	for index in range(powerup_config.boost_pad_count):
		var pad: BoostPad = boost_pad_scene.instantiate() as BoostPad
		if pad == null:
			continue

		add_child(pad)
		pad.name = "BoostPad_%02d" % (index + 1)
		pad.global_position = _get_pad_position(hazard_positions, boost_positions)
		pad.configure(powerup_config)
		_spawned_powerups.append(pad)
		boost_positions.append(pad.global_position)

func clear_powerups() -> void:
	for pad in _spawned_powerups:
		if is_instance_valid(pad):
			pad.queue_free()
	_spawned_powerups.clear()

func get_reserved_positions() -> Array[Vector3]:
	var result: Array[Vector3] = []
	for pad in _spawned_powerups:
		if is_instance_valid(pad):
			result.append(pad.global_position)
	return result

func _get_pad_position(hazard_positions: Array[Vector3], boost_positions: Array[Vector3]) -> Vector3:
	for _attempt in range(64):
		var candidate: Vector3 = _get_random_pad_position()
		if (
			_is_position_clear(candidate, hazard_positions, powerup_config.hazard_clearance_radius)
			and _is_position_clear(candidate, boost_positions, powerup_config.boost_pad_min_spacing)
		):
			return candidate

	return _get_random_pad_position()

func _get_random_pad_position() -> Vector3:
	var z: float = _get_random_surface_z(
		powerup_config.placement_min_z,
		powerup_config.placement_max_z
	)
	return Vector3(
		_rng.randf_range(-powerup_config.placement_half_width, powerup_config.placement_half_width),
		_surface_y_at_z(z, 0.12),
		z
	)

func _is_position_clear(candidate: Vector3, used_positions: Array[Vector3], minimum_distance: float) -> bool:
	var minimum_distance_squared: float = minimum_distance * minimum_distance
	for used_position in used_positions:
		var offset: Vector3 = candidate - used_position
		offset.y = 0.0
		if offset.length_squared() < minimum_distance_squared:
			return false
	return true

func _get_random_surface_z(min_z: float, max_z: float) -> float:
	var active_config: PowerupConfig = powerup_config
	if active_config == null or active_config.placement_surface_zones.is_empty():
		return _rng.randf_range(min_z, max_z)
	return SURFACE_SPAWN_RESOLVER.random_z(
		_rng,
		active_config.placement_surface_zones,
		min_z,
		max_z
	)

func _surface_y_at_z(z: float, offset: float) -> float:
	var base_y: float = powerup_config.placement_surface_y if powerup_config != null else 0.0
	if powerup_config != null:
		base_y = SURFACE_SPAWN_RESOLVER.y_at_z(powerup_config.placement_surface_zones, z, base_y)
	return base_y + offset
