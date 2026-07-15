class_name PowerupConfig
extends Resource

@export_range(0, 32, 1) var boost_pad_count: int = 3
@export var placement_half_width: float = 5.6
@export var placement_min_z: float = -24.0
@export var placement_max_z: float = 32.0
@export var placement_surface_y: float = 0.0
@export var placement_surface_zones: Array[Dictionary] = []
@export var placement_path_points: PackedVector3Array = PackedVector3Array()
@export var hazard_clearance_radius: float = 3.0
@export var boost_pad_min_spacing: float = 4.0
@export var activation_radius: float = 1.5
@export var boost_multiplier: float = 1.85
@export var boost_duration: float = 2.2
@export var per_zombie_cooldown: float = 1.0
