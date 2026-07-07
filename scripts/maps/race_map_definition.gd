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
