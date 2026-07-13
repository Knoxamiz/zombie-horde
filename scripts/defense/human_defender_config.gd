class_name HumanDefenderConfig
extends Resource

enum GunType {
	RANDOM,
	PISTOL,
	SMG,
	RIFLE,
	SHOTGUN
}

@export_range(0, 12, 1) var defender_count: int = 2
@export_enum("Random", "Pistol", "SMG", "Rifle", "Shotgun") var gun_type: int = GunType.RANDOM
@export var show_weapon_visuals: bool = true
@export var left_spawn_x: float = -6.25
@export var right_spawn_x: float = 6.25
@export var placement_half_width: float = 5.25
@export var placement_min_z: float = -24.0
@export var placement_max_z: float = 28.0
@export var placement_surface_y: float = 0.0
@export var placement_surface_zones: Array[Dictionary] = []
@export var position_jitter: float = 0.65
@export var defender_min_spacing: float = 6.0
@export var reserved_position_clearance: float = 3.0
@export var range: float = 13.5
@export var seconds_between_shots: float = 1.05
@export var damage_per_hit: float = 26.0
@export_range(0.0, 1.0, 0.01) var hit_chance: float = 0.78
@export var turn_speed: float = 8.0
@export var tracer_lifetime: float = 0.07

func resolve_gun_type(random: RandomNumberGenerator) -> int:
	if gun_type != GunType.RANDOM:
		return gun_type
	return random.randi_range(GunType.PISTOL, GunType.SHOTGUN)

func get_gun_name(active_gun_type: int) -> String:
	match active_gun_type:
		GunType.PISTOL:
			return "Pistol"
		GunType.SMG:
			return "SMG"
		GunType.RIFLE:
			return "Rifle"
		GunType.SHOTGUN:
			return "Shotgun"
	return "SMG"

func get_effective_range(active_gun_type: int) -> float:
	match active_gun_type:
		GunType.PISTOL:
			return range * 0.8
		GunType.SMG:
			return range * 0.72
		GunType.RIFLE:
			return range * 1.55
		GunType.SHOTGUN:
			return range * 0.48
	return range

func get_effective_damage_per_hit(active_gun_type: int) -> float:
	match active_gun_type:
		GunType.PISTOL:
			return damage_per_hit * 0.85
		GunType.SMG:
			return damage_per_hit * 0.62
		GunType.RIFLE:
			return damage_per_hit * 1.45
		GunType.SHOTGUN:
			return damage_per_hit * 0.72
	return damage_per_hit

func get_effective_seconds_between_shots(active_gun_type: int) -> float:
	match active_gun_type:
		GunType.PISTOL:
			return seconds_between_shots * 1.05
		GunType.SMG:
			return seconds_between_shots * 0.5
		GunType.RIFLE:
			return seconds_between_shots * 1.7
		GunType.SHOTGUN:
			return seconds_between_shots * 1.65
	return seconds_between_shots

func get_effective_hit_chance(active_gun_type: int) -> float:
	match active_gun_type:
		GunType.PISTOL:
			return clamp(hit_chance + 0.04, 0.0, 1.0)
		GunType.SMG:
			return clamp(hit_chance - 0.16, 0.0, 1.0)
		GunType.RIFLE:
			return clamp(hit_chance + 0.12, 0.0, 1.0)
		GunType.SHOTGUN:
			return clamp(hit_chance - 0.08, 0.0, 1.0)
	return hit_chance

func get_projectile_count(active_gun_type: int) -> int:
	if active_gun_type == GunType.SHOTGUN:
		return 5
	return 1
