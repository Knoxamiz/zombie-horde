class_name MinigunConfig
extends Resource

@export var range: float = 34.0
@export var seconds_between_bursts: float = 1.6
@export_range(1, 24, 1) var shots_per_burst: int = 4
@export var shot_interval: float = 0.11
@export var damage_per_hit: float = 34.0
@export_range(0.0, 1.0, 0.01) var hit_chance: float = 0.72
@export var turn_speed: float = 8.0

