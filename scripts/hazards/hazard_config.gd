class_name HazardConfig
extends Resource

@export_range(0, 96, 1) var mine_count: int = 6
@export_range(0, 96, 1) var obstacle_count: int = 12
@export var placement_half_width: float = 6.2
@export var placement_min_z: float = -30.0
@export var placement_max_z: float = 26.0
@export var placement_surface_y: float = 0.0
@export var placement_surface_zones: Array[Dictionary] = []
@export var obstacle_half_width: float = 5.8
@export var obstacle_min_z: float = -32.0
@export var obstacle_max_z: float = 31.0
@export var obstacle_min_spacing: float = 2.1
@export_range(1, 6, 1) var obstacle_lane_count: int = 3
@export var obstacle_lane_jitter: float = 0.45
@export var obstacle_segment_length: float = 4.4
@export_range(1, 6, 1) var max_obstacles_per_segment: int = 2
@export_range(1, 6, 1) var guaranteed_open_lanes_per_segment: int = 1
@export_range(1, 6, 1) var max_large_obstacles_per_segment: int = 1
@export var mine_hazard_clearance: float = 2.4
@export var mine_min_spacing: float = 2.6
@export_range(0, 32, 1) var sewer_hole_count: int = 2
@export var sewer_hole_radius: float = 1.05
@export var sewer_hole_clearance: float = 3.0
@export var sewer_hole_min_spacing: float = 4.4
@export var obstacle_rotation_degrees: float = 32.0
@export_range(0, 100, 1) var barrier_obstacle_weight: int = 42
@export_range(0, 100, 1) var cone_obstacle_weight: int = 40
@export_range(0, 100, 1) var vehicle_obstacle_weight: int = 18
@export var mine_activation_radius: float = 1.35
@export var mine_blast_radius: float = 4.25
@export var mine_launch_strength: float = 18.0
@export var mine_vertical_launch_multiplier: float = 1.05
@export var mine_damage: float = 36.0
@export var stun_duration: float = 0.7
@export_range(0.0, 1.0, 0.01) var crawler_chance: float = 0.35
@export_range(0.0, 1.0, 0.01) var damage_chance: float = 0.55
