class_name ActiveConfigInspector
extends RefCounted

## Read-only runtime config inspector for dev builds.


static func build_display_text(
	round_manager: RoundManager,
	race_map_controller: RaceMapController,
	zombie_manager: ZombieManager
) -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append_array(_build_map_lines(race_map_controller))
	lines.append("")
	lines.append_array(_build_round_lines(round_manager))
	lines.append("")
	lines.append_array(_build_zombie_lines(race_map_controller, zombie_manager))
	lines.append("")
	lines.append_array(_build_hazard_lines(race_map_controller))
	lines.append("")
	lines.append_array(_build_defender_lines(race_map_controller))
	lines.append("")
	lines.append_array(_build_powerup_lines(race_map_controller))
	return "\n".join(lines)


static func build_snapshot_text(
	round_manager: RoundManager,
	race_map_controller: RaceMapController,
	zombie_manager: ZombieManager
) -> String:
	var map_id: String = _resolve_map_id(race_map_controller)
	var entry: Dictionary = MapCatalog.get_entry_by_id(map_id)
	var definition: RaceMapDefinition = _resolve_definition(race_map_controller)
	var zombie_config: ZombieConfig = race_map_controller.zombie_config if race_map_controller != null else null
	var hazard_config: HazardConfig = race_map_controller.hazard_config if race_map_controller != null else null
	var defender_config: HumanDefenderConfig = (
		race_map_controller.human_defender_config if race_map_controller != null else null
	)
	var powerup_config: PowerupConfig = race_map_controller.powerup_config if race_map_controller != null else null
	var round_config: RoundConfig = round_manager.round_config if round_manager != null else null

	var deck_y: float = 0.0
	var spawn: Vector3 = Vector3.ZERO
	var goal: Vector3 = Vector3.ZERO
	var base_pos: Vector3 = Vector3.ZERO
	var minigun: Vector3 = Vector3.ZERO
	var lane_half_width: float = 0.0
	var oob_half_width: float = 0.0
	var oob_min_y: float = 0.0

	if definition != null:
		deck_y = definition.deck_y if definition.deck_y > 0.0 else definition.spawn_origin.y
		spawn = definition.spawn_origin
		goal = definition.goal_position
		base_pos = definition.base_position
		minigun = definition.minigun_position
		lane_half_width = definition.lane_half_width
		oob_half_width = definition.out_of_bounds_half_width
		oob_min_y = definition.out_of_bounds_min_y
	elif zombie_manager != null:
		spawn = zombie_manager.spawn_origin
		goal = zombie_manager.goal_position

	if zombie_config != null:
		if lane_half_width <= 0.0:
			lane_half_width = zombie_config.lane_half_width
		if oob_half_width <= 0.0:
			oob_half_width = zombie_config.out_of_bounds_half_width
		if oob_min_y == 0.0 and zombie_config.out_of_bounds_min_y != 0.0:
			oob_min_y = zombie_config.out_of_bounds_min_y

	var round_max_duration: float = round_config.max_race_duration_seconds if round_config != null else 0.0
	var auto_reset: float = round_config.post_round_auto_reset_seconds if round_config != null else 0.0
	var zombie_speed: float = zombie_config.runner_speed if zombie_config != null else 0.0

	var hazard_summary: String = _format_hazard_summary(hazard_config)
	var defender_summary: String = str(defender_config.defender_count) if defender_config != null else "n/a"
	var powerup_summary: String = _format_powerup_summary(powerup_config)

	var lines: PackedStringArray = PackedStringArray()
	lines.append("ACTIVE CONFIG SNAPSHOT")
	lines.append("map_id: %s" % map_id)
	lines.append("display_name: %s" % _resolve_display_name(race_map_controller, map_id))
	lines.append("scene_path: %s" % str(entry.get("scene_path", "n/a")))
	lines.append("deck_y: %.2f" % deck_y)
	lines.append("spawn: %s" % spawn)
	lines.append("goal: %s" % goal)
	lines.append("base: %s" % base_pos)
	lines.append("minigun: %s" % minigun)
	lines.append("lane_half_width: %.2f" % lane_half_width)
	lines.append("oob_half_width: %.2f" % oob_half_width)
	lines.append("oob_min_y: %.2f" % oob_min_y)
	lines.append("round_max_duration: %.1f" % round_max_duration)
	lines.append("auto_reset: %.1f" % auto_reset)
	lines.append("zombie_speed: %.2f" % zombie_speed)
	lines.append("hazards: %s" % hazard_summary)
	lines.append("defenders: %s" % defender_summary)
	lines.append("powerups: %s" % powerup_summary)
	return "\n".join(lines)


static func _build_map_lines(race_map_controller: RaceMapController) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray(["[Map]"])
	if race_map_controller == null:
		lines.append("RaceMapController missing")
		return lines

	var map_id: String = _resolve_map_id(race_map_controller)
	var entry: Dictionary = MapCatalog.get_entry_by_id(map_id)
	var definition: RaceMapDefinition = _resolve_definition(race_map_controller)

	lines.append("id: %s" % map_id)
	lines.append("name: %s" % _resolve_display_name(race_map_controller, map_id))
	lines.append("scene: %s" % str(entry.get("scene_path", "n/a")))

	if definition == null:
		lines.append("definition: missing")
		return lines

	var deck_y: float = definition.deck_y if definition.deck_y > 0.0 else definition.spawn_origin.y
	lines.append("deck_y: %.2f" % deck_y)
	lines.append("lane_half_width: %.2f" % definition.lane_half_width)
	lines.append("spawn_origin: %s" % definition.spawn_origin)
	lines.append("goal_position: %s" % definition.goal_position)
	lines.append("base_position: %s" % definition.base_position)
	lines.append("minigun_position: %s" % definition.minigun_position)
	lines.append("oob_half_width: %.2f" % definition.out_of_bounds_half_width)
	lines.append("oob_min_y: %.2f" % definition.out_of_bounds_min_y)
	lines.append("oob_min_z: %.1f" % definition.out_of_bounds_min_z)
	lines.append("oob_max_z: %.1f" % definition.out_of_bounds_max_z)

	var camera_view: Dictionary = RaceMapController.compute_race_camera_view_for_definition(definition)
	var camera_position: Vector3 = camera_view.get("position", Vector3.ZERO)
	var camera_rotation: Vector3 = camera_view.get("rotation_degrees", Vector3.ZERO)
	lines.append("camera_pos: %s" % camera_position)
	lines.append("camera_rot: %s" % camera_rotation)
	return lines


static func _build_round_lines(round_manager: RoundManager) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray(["[Round]"])
	if round_manager == null or round_manager.round_config == null:
		lines.append("RoundConfig missing")
		return lines

	var config: RoundConfig = round_manager.round_config
	lines.append("countdown_seconds: %d" % config.countdown_seconds)
	lines.append("require_manual_launch: %s" % config.require_manual_launch)
	lines.append("max_race_duration_seconds: %.1f" % config.max_race_duration_seconds)
	lines.append("post_round_auto_reset_seconds: %.1f" % config.post_round_auto_reset_seconds)
	lines.append("min_participants_to_start: %d" % config.min_participants_to_start)
	lines.append("max_pending_participants: %d" % config.max_pending_participants)
	return lines


static func _build_zombie_lines(
	race_map_controller: RaceMapController,
	zombie_manager: ZombieManager
) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray(["[Zombie]"])
	var config: ZombieConfig = race_map_controller.zombie_config if race_map_controller != null else null
	if config == null:
		lines.append("ZombieConfig missing")
		return lines

	lines.append("runner_speed: %.2f" % config.runner_speed)
	lines.append("max_health: %.1f" % config.max_health)
	lines.append("lane_half_width: %.2f" % config.lane_half_width)
	lines.append("oob_half_width: %.2f" % config.out_of_bounds_half_width)
	lines.append("oob_min_y: %.2f" % config.out_of_bounds_min_y)
	lines.append("oob_min_z: %.1f" % config.out_of_bounds_min_z)
	lines.append("oob_max_z: %.1f" % config.out_of_bounds_max_z)
	lines.append("crowd_separation_radius: %.2f" % config.crowd_separation_radius)
	lines.append("crowd_separation_strength: %.2f" % config.crowd_separation_strength)
	lines.append("crowd_bump_radius: %.2f" % config.crowd_bump_radius)
	lines.append("crowd_bump_strength: %.2f" % config.crowd_bump_strength)

	if zombie_manager != null:
		lines.append("runtime_spawn_origin: %s" % zombie_manager.spawn_origin)
		lines.append("runtime_goal_position: %s" % zombie_manager.goal_position)
		lines.append("runtime_spawn_area: %s" % zombie_manager.spawn_area_size)
	return lines


static func _build_hazard_lines(race_map_controller: RaceMapController) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray(["[Hazards]"])
	var config: HazardConfig = race_map_controller.hazard_config if race_map_controller != null else null
	if config == null:
		lines.append("HazardConfig missing")
		return lines

	lines.append("mine_count: %d" % config.mine_count)
	lines.append("sewer_hole_count: %d" % config.sewer_hole_count)
	lines.append("obstacle_count: %d" % config.obstacle_count)
	lines.append("placement_half_width: %.2f" % config.placement_half_width)
	lines.append("placement_z: %.1f to %.1f" % [config.placement_min_z, config.placement_max_z])
	lines.append("placement_surface_y: %.2f" % config.placement_surface_y)
	lines.append("obstacle_lane_count: %d" % config.obstacle_lane_count)
	return lines


static func _build_defender_lines(race_map_controller: RaceMapController) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray(["[Defenders]"])
	var config: HumanDefenderConfig = race_map_controller.human_defender_config if race_map_controller != null else null
	if config == null:
		lines.append("HumanDefenderConfig missing")
		return lines

	lines.append("defender_count: %d" % config.defender_count)
	lines.append("gun_type: %s" % config.get_gun_name(config.gun_type))
	lines.append("placement_z: %.1f to %.1f" % [config.placement_min_z, config.placement_max_z])
	lines.append("range: %.1f" % config.range)
	lines.append("seconds_between_shots: %.2f" % config.seconds_between_shots)
	return lines


static func _build_powerup_lines(race_map_controller: RaceMapController) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray(["[Powerups]"])
	var config: PowerupConfig = race_map_controller.powerup_config if race_map_controller != null else null
	if config == null:
		lines.append("PowerupConfig missing")
		return lines

	lines.append("boost_pad_count: %d" % config.boost_pad_count)
	lines.append("placement_z: %.1f to %.1f" % [config.placement_min_z, config.placement_max_z])
	lines.append("boost_multiplier: %.2f" % config.boost_multiplier)
	lines.append("boost_duration: %.2f" % config.boost_duration)
	return lines


static func _resolve_map_id(race_map_controller: RaceMapController) -> String:
	if race_map_controller == null:
		return ""
	var map_id: String = race_map_controller.get_resolved_map_id()
	if map_id.is_empty():
		map_id = race_map_controller.active_map_id
	return map_id


static func _resolve_display_name(race_map_controller: RaceMapController, map_id: String) -> String:
	if race_map_controller != null:
		return race_map_controller.get_active_map_name()
	if map_id.is_empty():
		return "n/a"
	return MapCatalog.get_entry_by_id(map_id).get("display_name", map_id)


static func _resolve_definition(race_map_controller: RaceMapController) -> RaceMapDefinition:
	if race_map_controller == null:
		return null
	return race_map_controller.get_active_map_definition()


static func _format_hazard_summary(config: HazardConfig) -> String:
	if config == null:
		return "n/a"
	return "mines=%d sewers=%d obstacles=%d" % [
		config.mine_count,
		config.sewer_hole_count,
		config.obstacle_count,
	]


static func _format_powerup_summary(config: PowerupConfig) -> String:
	if config == null:
		return "n/a"
	return "boost_pads=%d mult=%.2f dur=%.2fs" % [
		config.boost_pad_count,
		config.boost_multiplier,
		config.boost_duration,
	]
