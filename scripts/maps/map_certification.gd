class_name MapCertification
extends RefCounted

const FINISH_POSITION_TOLERANCE := RaceMapController.FINISH_POSITION_TOLERANCE

const DEFAULT_CERTIFIED_MAP_IDS: Array[String] = [
	MapCatalog.DEFAULT_MAP_ID,
]


static func get_default_certified_map_ids() -> Array[String]:
	return DEFAULT_CERTIFIED_MAP_IDS.duplicate()


static func certify_catalog_entry(map_id: String) -> Array[String]:
	var failures: Array[String] = []
	var trimmed_id: String = map_id.strip_edges()
	if trimmed_id.is_empty():
		failures.append("map id is empty")
		return failures

	var entry: Dictionary = MapCatalog.get_entry_by_id(trimmed_id)
	if entry.is_empty():
		failures.append("map id '%s' not found in MapCatalog" % trimmed_id)
		return failures

	if not MapCatalog.is_entry_selectable(entry):
		failures.append(
			"map '%s' is not selectable (enabled playable or enabled_for_testing prototype required)"
			% trimmed_id
		)

	var resource_path: String = str(entry.get("resource_path", ""))
	var scene_path: String = str(entry.get("scene_path", ""))
	if resource_path.is_empty() or not ResourceLoader.exists(resource_path):
		failures.append("missing RaceMapDefinition resource for '%s' at '%s'" % [trimmed_id, resource_path])
	if scene_path.is_empty() or not ResourceLoader.exists(scene_path):
		failures.append("missing map scene for '%s' at '%s'" % [trimmed_id, scene_path])

	return failures


static func certify_definition(definition: RaceMapDefinition, map_id: String) -> Array[String]:
	var failures: Array[String] = []
	if definition == null:
		failures.append("[%s] RaceMapDefinition is null" % map_id)
		return failures
	if definition.scene == null:
		failures.append("[%s] RaceMapDefinition.scene is null" % map_id)

	if definition.spawn_origin.z >= definition.goal_position.z:
		failures.append(
			"[%s] spawn_origin.z (%.2f) must be less than goal_position.z (%.2f)"
			% [map_id, definition.spawn_origin.z, definition.goal_position.z]
		)
	if definition.lane_half_width <= 0.0:
		failures.append("[%s] lane_half_width must be > 0" % map_id)
	if definition.out_of_bounds_half_width < definition.lane_half_width:
		failures.append(
			"[%s] out_of_bounds_half_width (%.2f) must be >= lane_half_width (%.2f)"
			% [map_id, definition.out_of_bounds_half_width, definition.lane_half_width]
		)
	if definition.out_of_bounds_min_z >= definition.out_of_bounds_max_z:
		failures.append("[%s] out_of_bounds_min_z must be < out_of_bounds_max_z" % map_id)
	if definition.out_of_bounds_min_y >= definition.spawn_origin.y - 0.25:
		failures.append(
			"[%s] out_of_bounds_min_y (%.2f) must be below spawn height (%.2f)"
			% [map_id, definition.out_of_bounds_min_y, definition.spawn_origin.y]
		)
	if abs(definition.base_position.z - definition.goal_position.z) > FINISH_POSITION_TOLERANCE:
		failures.append(
			"[%s] base_position.z (%.2f) must align with goal_position.z (%.2f)"
			% [map_id, definition.base_position.z, definition.goal_position.z]
		)

	var camera_view: Dictionary = RaceMapController.compute_race_camera_view_for_definition(definition)
	var camera_position: Vector3 = camera_view.get("position", Vector3.ZERO)
	if camera_position == Vector3.ZERO:
		failures.append("[%s] camera framing position is invalid" % map_id)

	return failures


static func certify_scene_contract(map: Node3D, map_id: String) -> Array[String]:
	var failures: Array[String] = []
	if map == null:
		failures.append("[%s] loaded map scene is null" % map_id)
		return failures
	if map.name != "RoadArena":
		failures.append("[%s] loaded map root must be named RoadArena (got '%s')" % [map_id, map.name])
		return failures

	var core_road: Node = map.get_node_or_null("CoreRoad")
	if core_road == null:
		failures.append("[%s] required node CoreRoad is missing" % map_id)
		return failures

	if _is_generated_map_arena(core_road):
		var map_root: Node = core_road.get_node_or_null("MapRoot")
		if map_root == null:
			failures.append("[%s] blueprint map missing MapRoot" % map_id)
			return failures
		var visual_layer: Node = map_root.get_node_or_null("VisualLayer")
		var gameplay_layer: Node = map_root.get_node_or_null("GameplayLayer")
		if visual_layer == null:
			failures.append("[%s] blueprint map missing VisualLayer" % map_id)
		if gameplay_layer == null:
			failures.append("[%s] blueprint map missing GameplayLayer" % map_id)
		if visual_layer != null and visual_layer.get_child_count() <= 0:
			failures.append("[%s] blueprint VisualLayer has no children" % map_id)
		var surfaces: Node = null
		if gameplay_layer != null:
			surfaces = gameplay_layer.get_node_or_null("Surfaces")
			if surfaces == null:
				surfaces = gameplay_layer.get_node_or_null("SafeFloor")
		if surfaces == null:
			failures.append("[%s] blueprint map missing GameplayLayer/Surfaces" % map_id)
		elif surfaces.get_child_count() <= 0:
			failures.append("[%s] blueprint Surfaces has no walk collision pieces" % map_id)

	return failures


static func _is_generated_map_arena(core_road: Node) -> bool:
	if core_road is BlueprintMapArena:
		return true
	if core_road == null or core_road.get_script() == null:
		return false
	var script_path: String = str(core_road.get_script().resource_path)
	return script_path in [
		"res://scripts/maps/ai_generated_map_arena.gd",
		"res://scripts/maps/fallthrough_lower_deck_arena.gd",
	]


static func certify_finish_authority(
	base_goal: Node3D,
	definition: RaceMapDefinition,
	map_id: String
) -> Array[String]:
	var failures: Array[String] = []
	if definition == null:
		failures.append("[%s] finish authority check missing definition" % map_id)
		return failures
	if base_goal == null:
		failures.append("[%s] World/StreamerBase finish authority is missing" % map_id)
		return failures
	if not (base_goal is StreamerBaseGoal):
		failures.append("[%s] World/StreamerBase must use StreamerBaseGoal" % map_id)
		return failures

	var expected_base: Vector3 = definition.base_position
	var actual_base: Vector3 = base_goal.global_position
	if actual_base.distance_to(expected_base) > FINISH_POSITION_TOLERANCE:
		failures.append(
			"[%s] StreamerBase at %s does not match definition.base_position %s"
			% [map_id, actual_base, expected_base]
		)

	return failures


static func certify_oob_applied(
	definition: RaceMapDefinition,
	zombie_config: ZombieConfig,
	map_id: String
) -> Array[String]:
	var failures: Array[String] = []
	if definition == null or zombie_config == null:
		failures.append("[%s] OOB check missing definition or zombie config" % map_id)
		return failures

	if not is_equal_approx(zombie_config.out_of_bounds_half_width, definition.out_of_bounds_half_width):
		failures.append("[%s] zombie_config.out_of_bounds_half_width was not applied" % map_id)
	if not is_equal_approx(zombie_config.out_of_bounds_min_y, definition.out_of_bounds_min_y):
		failures.append("[%s] zombie_config.out_of_bounds_min_y was not applied" % map_id)
	if not is_equal_approx(zombie_config.out_of_bounds_min_z, definition.out_of_bounds_min_z):
		failures.append("[%s] zombie_config.out_of_bounds_min_z was not applied" % map_id)
	if not is_equal_approx(zombie_config.out_of_bounds_max_z, definition.out_of_bounds_max_z):
		failures.append("[%s] zombie_config.out_of_bounds_max_z was not applied" % map_id)

	return failures


static func format_failures(map_id: String, failures: Array[String]) -> String:
	if failures.is_empty():
		return ""
	var lines: PackedStringArray = PackedStringArray()
	lines.append("MAP CERTIFICATION FAILED: %s" % map_id)
	for failure in failures:
		lines.append("- %s" % failure)
	return "\n".join(lines)
