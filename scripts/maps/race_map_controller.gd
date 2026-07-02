class_name RaceMapController
extends Node

signal active_map_changed(map_index: int, display_name: String)

@export var feature_config: FeatureAccessConfig
@export var race_world_path: NodePath
@export var zombie_manager_path: NodePath
@export var base_goal_path: NodePath
@export var minigun_path: NodePath
@export var hazard_config: HazardConfig
@export var zombie_config: ZombieConfig
@export var powerup_config: PowerupConfig
@export var human_defender_config: HumanDefenderConfig
@export var default_map_index: int = 0
@export var map_0_definition: RaceMapDefinition
@export var map_1_definition: RaceMapDefinition
@export var map_2_definition: RaceMapDefinition
@export var map_3_definition: RaceMapDefinition
@export var map_4_definition: RaceMapDefinition

var active_map_index: int = -1
var _race_world: Node3D
var _active_map: Node3D
var _zombie_manager: ZombieManager
var _base_goal: Node3D
var _minigun: Node3D

func _ready() -> void:
	_race_world = get_node_or_null(race_world_path) as Node3D
	_zombie_manager = get_node_or_null(zombie_manager_path) as ZombieManager
	_base_goal = get_node_or_null(base_goal_path) as Node3D
	_minigun = get_node_or_null(minigun_path) as Node3D
	var profile: StreamerSettingsProfile = StreamerSettingsProfile.load_from_disk()
	apply_profile(profile)

func apply_profile(profile: StreamerSettingsProfile) -> bool:
	var requested_index: int = default_map_index
	if profile != null:
		requested_index = profile.selected_map_index
	return set_active_map_index(requested_index)

func set_active_map_index(requested_index: int) -> bool:
	var allowed_index: int = get_allowed_map_index(requested_index)
	var definition: RaceMapDefinition = get_map_definition(allowed_index)
	if definition == null or definition.scene == null:
		allowed_index = get_allowed_map_index(default_map_index)
		definition = get_map_definition(allowed_index)
	if definition == null or definition.scene == null or _race_world == null:
		return false

	if active_map_index == allowed_index and _get_current_map() != null:
		_apply_map_geometry(definition, _get_current_map())
		_apply_gameplay_dimensions(definition)
		return false

	var old_map: Node = _race_world.get_node_or_null("RoadArena")
	if old_map != null:
		old_map.name = "RoadArena_Unloading"
		old_map.queue_free()

	var new_map: Node3D = definition.scene.instantiate() as Node3D
	if new_map == null:
		return false

	new_map.name = "RoadArena"
	_race_world.add_child(new_map)
	_race_world.move_child(new_map, 0)
	_active_map = new_map
	active_map_index = allowed_index
	_apply_map_geometry(definition, new_map)
	_apply_gameplay_dimensions(definition)
	active_map_changed.emit(active_map_index, get_map_name(active_map_index))
	return true

func get_allowed_map_index(requested_index: int) -> int:
	if not _can_select_premium_maps():
		return 0

	var clamped_index: int = _clamp_map_index(requested_index)
	if is_map_available(clamped_index):
		return clamped_index
	return _clamp_map_index(default_map_index)

func get_map_count() -> int:
	return 5

func get_map_name(index: int) -> String:
	var definition: RaceMapDefinition = get_map_definition(index)
	if definition == null:
		return "Race Map"
	return definition.display_name

func get_map_scene(index: int) -> PackedScene:
	var definition: RaceMapDefinition = get_map_definition(index)
	if definition == null:
		return null
	return definition.scene

func get_map_definition(index: int) -> RaceMapDefinition:
	match _clamp_map_index(index):
		0:
			return map_0_definition
		1:
			return map_1_definition
		2:
			return map_2_definition
		3:
			return map_3_definition
		4:
			return map_4_definition
	return map_0_definition

func is_map_available(index: int) -> bool:
	if not _is_map_premium_only(index):
		return true
	return _can_select_premium_maps()

func get_active_map_name() -> String:
	if active_map_index < 0:
		return get_map_name(get_allowed_map_index(default_map_index))
	return get_map_name(active_map_index)

func _is_map_premium_only(index: int) -> bool:
	var definition: RaceMapDefinition = get_map_definition(index)
	if definition != null:
		return definition.premium_only
	return true

func _can_select_premium_maps() -> bool:
	return feature_config != null and feature_config.can_use_map_selection()

func _clamp_map_index(index: int) -> int:
	return int(clamp(index, 0, get_map_count() - 1))

func _get_current_map() -> Node3D:
	if _active_map != null and is_instance_valid(_active_map):
		return _active_map
	if _race_world == null:
		return null
	return _race_world.get_node_or_null("RoadArena") as Node3D

func _apply_map_geometry(definition: RaceMapDefinition, map: Node3D) -> void:
	if definition == null or map == null:
		return

	var core_road: Node3D = map.get_node_or_null("CoreRoad") as Node3D
	if core_road != null:
		core_road.scale = definition.road_core_scale
	else:
		map.scale = definition.road_core_scale

func _apply_gameplay_dimensions(definition: RaceMapDefinition) -> void:
	if definition == null:
		return

	if _zombie_manager != null:
		_zombie_manager.spawn_origin = definition.spawn_origin
		_zombie_manager.spawn_area_size = definition.spawn_area_size
		_zombie_manager.goal_position = definition.goal_position

	if zombie_config != null:
		zombie_config.lane_half_width = definition.lane_half_width
		zombie_config.out_of_bounds_half_width = definition.out_of_bounds_half_width
		zombie_config.out_of_bounds_min_z = definition.out_of_bounds_min_z
		zombie_config.out_of_bounds_max_z = definition.out_of_bounds_max_z

	if hazard_config != null:
		hazard_config.placement_half_width = definition.hazard_placement_half_width
		hazard_config.placement_min_z = definition.hazard_placement_min_z
		hazard_config.placement_max_z = definition.hazard_placement_max_z
		hazard_config.obstacle_half_width = definition.obstacle_half_width
		hazard_config.obstacle_min_z = definition.obstacle_min_z
		hazard_config.obstacle_max_z = definition.obstacle_max_z
		hazard_config.obstacle_lane_count = definition.obstacle_lane_count
		hazard_config.obstacle_segment_length = definition.obstacle_segment_length

	if powerup_config != null:
		powerup_config.placement_half_width = definition.powerup_placement_half_width
		powerup_config.placement_min_z = definition.powerup_placement_min_z
		powerup_config.placement_max_z = definition.powerup_placement_max_z

	if human_defender_config != null:
		human_defender_config.placement_half_width = definition.defender_placement_half_width
		human_defender_config.placement_min_z = definition.defender_placement_min_z
		human_defender_config.placement_max_z = definition.defender_placement_max_z

	if _base_goal != null:
		_base_goal.global_position = definition.base_position
	if _minigun != null:
		_minigun.global_position = definition.minigun_position
