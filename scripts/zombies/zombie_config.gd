class_name ZombieConfig
extends Resource

@export var max_health: float = 100.0
@export var runner_speed: float = 3.9
@export_range(0.05, 1.0, 0.01) var crawler_speed_multiplier: float = 0.38
@export var acceleration: float = 12.0
@export var drift_strength: float = 0.55
@export var drift_change_interval: float = 0.75
@export var crowd_separation_radius: float = 1.05
@export var crowd_separation_strength: float = 0.9
@export var crowd_separation_max_neighbors: int = 10
@export var lane_half_width: float = 6.1
@export var edge_recovery_strength: float = 1.15
@export var crowd_bump_radius: float = 0.82
@export var crowd_bump_strength: float = 1.55
@export var crowd_bump_upward_strength: float = 0.28
@export var crowd_bump_forward_bias: float = 0.18
@export var crowd_bump_cooldown: float = 0.28
@export var gravity: float = 24.0
@export var launch_damping: float = 6.5
@export var body_settle_damping: float = 10.0
@export var crawler_visual_scale: Vector3 = Vector3.ONE
@export var boost_decay_buffer: float = 0.05
@export_range(0.0, 1.0, 0.01) var lethal_dismember_chance: float = 0.42
@export var dismember_survivor_health: float = 28.0
@export var dismemberment_causes: PackedStringArray = PackedStringArray(["mine", "obstacle", "minigun"])
@export var out_of_bounds_enabled: bool = true
@export var out_of_bounds_half_width: float = 10.2
@export var out_of_bounds_min_z: float = -48.0
@export var out_of_bounds_max_z: float = 48.0
@export var out_of_bounds_min_y: float = -3.0
@export_range(0, 256, 1) var name_label_full_roster_limit: int = 24
@export var color_variants_enabled: bool = true
