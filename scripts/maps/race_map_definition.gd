class_name RaceMapDefinition
extends Resource

@export var display_name: String = "Race Map"
@export var scene: PackedScene
@export var premium_only: bool = true
@export var road_core_scale: Vector3 = Vector3.ONE
@export var spawn_origin: Vector3 = Vector3(0.0, 0.8, -42.0)
@export var spawn_area_size: Vector2 = Vector2(10.0, 4.0)
@export var goal_position: Vector3 = Vector3(0.0, 0.8, 42.0)
@export var base_position: Vector3 = Vector3(0.0, 0.0, 42.0)
@export var minigun_position: Vector3 = Vector3(0.0, 0.0, 38.5)
@export var lane_half_width: float = 6.1
@export var out_of_bounds_half_width: float = 10.2
@export var out_of_bounds_min_z: float = -48.0
@export var out_of_bounds_max_z: float = 48.0
@export var out_of_bounds_min_y: float = -3.0
@export var deck_y: float = 0.0
## Optional presentation layer for maps with visible water below a fall hazard.
## Zombie remains the single OOB authority and turns this into a normal "fell"
## death after the configured float window.
@export var water_fall_enabled: bool = false
@export var water_surface_y: float = 0.0
@export_range(0.0, 10.0, 0.05) var water_float_duration: float = 0.0
@export_range(0.0, 2.0, 0.01) var water_float_height: float = 0.42
@export_range(0.0, 1.0, 0.01) var water_float_bob_amplitude: float = 0.08
@export var race_environment_override: Environment
@export var hazard_placement_half_width: float = 6.2
@export var hazard_placement_min_z: float = -30.0
@export var hazard_placement_max_z: float = 26.0
@export var obstacle_half_width: float = 5.8
@export var obstacle_min_z: float = -32.0
@export var obstacle_max_z: float = 31.0
@export_range(1, 6, 1) var obstacle_lane_count: int = 3
@export var obstacle_segment_length: float = 4.4
@export var powerup_placement_half_width: float = 5.6
@export var powerup_placement_min_z: float = -24.0
@export var powerup_placement_max_z: float = 32.0
@export var defender_placement_half_width: float = 5.25
@export var defender_placement_min_z: float = -24.0
@export var defender_placement_max_z: float = 28.0
@export var race_path_points: PackedVector3Array = PackedVector3Array()

## NPC navigation uses Godot NavigationAgent3D for path selection while these
## points preserve checkpoint order on stacked or multi-turn maps.
@export_category("NPC Navigation")
@export var navigation_profile: NpcNavigationProfile
## Zero keeps runners within the race lane. Wider playable maps can opt in to
## preserve a runner's lateral position across sidewalks or other walkable space.
@export_range(0.0, 128.0, 0.1) var npc_navigation_half_width: float = 0.0


func resolve_npc_navigation_half_width() -> float:
	return npc_navigation_half_width if npc_navigation_half_width > 0.0 else lane_half_width

## Spectator-camera space is map data, not gameplay collision. Each AABB is a
## safe free-flight volume; together they can describe a long route, a bridge,
## or an exterior frame around a multi-level map without trapping the camera
## inside visible geometry.
@export_category("Spectator Camera")
@export var free_camera_safe_regions: Array[AABB] = []

@export var uses_map_hazard_profile: bool = false
@export_range(0, 96, 1) var map_mine_count: int = 6
@export_range(0, 96, 1) var map_obstacle_count: int = 12
@export_range(0, 32, 1) var map_sewer_hole_count: int = 2
@export_range(0, 100, 1) var map_barrier_obstacle_weight: int = 42
@export_range(0, 100, 1) var map_cone_obstacle_weight: int = 40
@export_range(0, 100, 1) var map_vehicle_obstacle_weight: int = 18
@export_range(0, 32, 1) var map_boost_pad_count: int = 3
@export_range(0, 12, 1) var map_defender_count: int = 2
@export var map_mechanic_hook: String = ""
@export var use_hazard_surface_y: bool = false
@export var hazard_surface_y: float = 0.0
@export_range(0.0, 4.0, 0.05) var map_boost_multiplier: float = 0.0
@export_range(0.0, 6.0, 0.05) var map_boost_duration: float = 0.0
@export_range(0.0, 8.0, 0.05) var map_mine_blast_radius: float = 0.0
@export_range(0.0, 32.0, 0.5) var map_mine_launch_strength: float = 0.0
@export_range(0.0, 2.0, 0.05) var map_stun_duration: float = 0.0
@export_range(-1, 4, 1) var map_defender_gun_type: int = -1
@export_range(0.0, 3.0, 0.05) var map_defender_seconds_between_shots: float = 0.0
@export_range(-1.0, 1.0, 0.01) var map_crawler_chance: float = -1.0
@export_range(-1.0, 1.0, 0.01) var map_damage_chance: float = -1.0
@export_range(0, 6, 1) var map_profile_obstacle_lane_count: int = 0
@export_range(0, 6, 1) var map_max_obstacles_per_segment: int = 0
@export_range(0, 6, 1) var map_guaranteed_open_lanes: int = 0


func resolve_hazard_surface_y() -> float:
	if use_hazard_surface_y:
		return hazard_surface_y
	if deck_y > 0.0:
		return deck_y
	return 0.0


func has_free_camera_safe_regions() -> bool:
	return not free_camera_safe_regions.is_empty()


func apply_hazard_profile_to(
	hazard_config: HazardConfig,
	powerup_config: PowerupConfig,
	human_defender_config: HumanDefenderConfig
) -> void:
	if not uses_map_hazard_profile:
		return
	if hazard_config != null:
		hazard_config.mine_count = map_mine_count
		hazard_config.obstacle_count = map_obstacle_count
		hazard_config.sewer_hole_count = map_sewer_hole_count
		hazard_config.barrier_obstacle_weight = map_barrier_obstacle_weight
		hazard_config.cone_obstacle_weight = map_cone_obstacle_weight
		hazard_config.vehicle_obstacle_weight = map_vehicle_obstacle_weight
		hazard_config.placement_surface_y = resolve_hazard_surface_y()
		if map_mine_blast_radius > 0.0:
			hazard_config.mine_blast_radius = map_mine_blast_radius
		if map_mine_launch_strength > 0.0:
			hazard_config.mine_launch_strength = map_mine_launch_strength
		if map_stun_duration > 0.0:
			hazard_config.stun_duration = map_stun_duration
		if map_crawler_chance >= 0.0:
			hazard_config.crawler_chance = map_crawler_chance
		if map_damage_chance >= 0.0:
			hazard_config.damage_chance = map_damage_chance
		if map_profile_obstacle_lane_count > 0:
			hazard_config.obstacle_lane_count = map_profile_obstacle_lane_count
		if map_max_obstacles_per_segment > 0:
			hazard_config.max_obstacles_per_segment = map_max_obstacles_per_segment
		if map_guaranteed_open_lanes > 0:
			hazard_config.guaranteed_open_lanes_per_segment = map_guaranteed_open_lanes
	if powerup_config != null:
		powerup_config.boost_pad_count = map_boost_pad_count
		powerup_config.placement_surface_y = resolve_hazard_surface_y()
		if map_boost_multiplier > 0.0:
			powerup_config.boost_multiplier = map_boost_multiplier
		if map_boost_duration > 0.0:
			powerup_config.boost_duration = map_boost_duration
	if human_defender_config != null:
		human_defender_config.defender_count = map_defender_count
		human_defender_config.placement_surface_y = resolve_hazard_surface_y()
		if map_defender_gun_type >= 0:
			human_defender_config.gun_type = map_defender_gun_type
		if map_defender_seconds_between_shots > 0.0:
			human_defender_config.seconds_between_shots = map_defender_seconds_between_shots
