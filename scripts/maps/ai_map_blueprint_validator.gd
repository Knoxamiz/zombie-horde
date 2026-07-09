class_name AIMapBlueprintValidator
extends RefCounted

const MapAssetLibraryScript := preload("res://scripts/maps/map_asset_library.gd")
const MapSegmentDefinitionScript := preload("res://scripts/maps/map_segment_definition.gd")
const AIMapRouteLayoutScript := preload("res://scripts/maps/ai_map_route_layout.gd")

const VOID_KILL_SCRIPT_PATH := "res://scripts/maps/bridge_void_kill_zone.gd"

const MIN_OBSTACLE_CYCLE_TIME: float = 1.5
const MAX_OBSTACLE_CYCLE_TIME: float = 12.0


static func validate_blueprint(blueprint) -> Dictionary:
	var result: Dictionary = _empty_result()
	if blueprint == null:
		_add_error(result, "Blueprint is null.")
		return _finalize_result(result)

	if blueprint.map_id.strip_edges().is_empty():
		_add_error(result, "map_id is required.")
	if blueprint.display_name.strip_edges().is_empty():
		_add_error(result, "display_name is required.")
	if blueprint.deck_y < -20.0 or blueprint.deck_y > 40.0:
		_add_error(result, "deck_y must be between -20 and 40.")
	if blueprint.target_length <= 0.0:
		_add_error(result, "target_length must be > 0.")
	if blueprint.route_half_width <= 0.0:
		_add_error(result, "route_half_width must be > 0.")
	if blueprint.lane_half_width <= 0.0:
		_add_error(result, "lane_half_width must be > 0.")
	if blueprint.lane_half_width > blueprint.route_half_width:
		_add_error(result, "lane_half_width must be <= route_half_width.")
	if blueprint.segment_sequence.is_empty():
		_add_error(result, "segment_sequence must not be empty.")
		return _finalize_result(result)

	_validate_segment_sequence(blueprint, result)
	_validate_segment_assets(blueprint, result)
	_validate_height_transitions(blueprint, result)
	_validate_gap_fall_settings(blueprint, result)
	_validate_phase2_fall_gap_rules(blueprint, result)
	_validate_phase3_moving_obstacle_rules(blueprint, result)
	_validate_phase4_split_merge_rules(blueprint, result)
	_validate_rail_barrier_match(blueprint, result)
	_validate_route_length(blueprint, result)
	_validate_definition_preview(blueprint, result)
	_validate_route_layout_alignment(blueprint, result)

	if blueprint.authoring_status == "playable":
		_add_error(
			result,
			"AIMapBlueprint cannot be promoted to playable directly; use MapCatalog + certification."
		)

	return _finalize_result(result)


static func validate_generated_scene(
	root: Node3D,
	blueprint,
	definition: RaceMapDefinition
) -> Dictionary:
	var result: Dictionary = validate_blueprint(blueprint)
	if root == null:
		_add_error(result, "Generated scene root is null.")
		return _finalize_result(result)

	if root.get_node_or_null("VisualLayer") == null:
		_add_error(result, "VisualLayer is missing.")
	if root.get_node_or_null("GameplayLayer") == null:
		_add_error(result, "GameplayLayer is missing.")

	var gameplay_layer: Node = root.get_node_or_null("GameplayLayer")
	if gameplay_layer != null:
		if gameplay_layer.get_node_or_null("SafeFloor") == null:
			_add_error(result, "GameplayLayer/SafeFloor is missing.")
		var safe_floor: Node = gameplay_layer.get_node_or_null("SafeFloor")
		if safe_floor != null and safe_floor.get_child_count() <= 0:
			_add_error(result, "SafeFloor has no collision plates.")

	_validate_no_goal_catch(root, result)
	_validate_no_authoritative_void_kill(root, result)
	_validate_no_scene_cameras(root, result)
	_validate_no_obstacle_finish_hijack(root, result)

	var obstacles_bucket: Node = root.get_node_or_null("GameplayLayer/MovingObstacles")
	if obstacles_bucket != null:
		_validate_moving_obstacle_scene_contract(obstacles_bucket, result)

	if definition != null:
		_validate_definition_values(definition, blueprint, result)
		_validate_route_layout_alignment(blueprint, result, definition)
		_validate_generated_geometry_alignment(root, blueprint, definition, result)
		_validate_elevated_camera_framing(definition, blueprint, result)
		var camera_view: Dictionary = RaceMapController.compute_race_camera_view_for_definition(definition)
		if camera_view.get("position", Vector3.ZERO) == Vector3.ZERO:
			_add_error(result, "Camera framing position is invalid for generated definition.")

	return _finalize_result(result)


static func print_validation_report(result: Dictionary) -> void:
	print("=== AI Map Blueprint Validation ===")
	if bool(result.get("ok", false)):
		print("RESULT: validation PASSED")
	else:
		print("RESULT: validation FAILED")
	print(result.get("summary", ""))
	for warning in result.get("warnings", []):
		print("WARNING: %s" % warning)
	for error in result.get("errors", []):
		print("ERROR: %s" % error)


static func _validate_segment_sequence(blueprint, result: Dictionary) -> void:
	var finish_count: int = 0
	var start_count: int = 0
	for index in range(blueprint.segment_sequence.size()):
		var segment_id: String = str(blueprint.segment_sequence[index])
		if not MapSegmentDefinitionScript.has_segment(segment_id):
			_add_error(result, "Unknown segment_id '%s' at index %d." % [segment_id, index])
			continue
		var segment: Dictionary = MapSegmentDefinitionScript.get_segment(segment_id)
		var segment_type: String = str(segment.get("type", ""))
		if segment_type == MapSegmentDefinitionScript.TYPE_START:
			start_count += 1
		if segment_type == MapSegmentDefinitionScript.TYPE_FINISH:
			finish_count += 1

	if start_count != 1:
		_add_error(result, "segment_sequence must contain exactly one start segment (found %d)." % start_count)
	if finish_count != 1:
		_add_error(result, "segment_sequence must contain exactly one finish segment (found %d)." % finish_count)

	var first_segment: Dictionary = MapSegmentDefinitionScript.get_segment(str(blueprint.segment_sequence[0]))
	if str(first_segment.get("type", "")) != MapSegmentDefinitionScript.TYPE_START:
		_add_error(result, "segment_sequence must begin with a start segment.")

	var last_segment: Dictionary = MapSegmentDefinitionScript.get_segment(str(blueprint.segment_sequence.back()))
	if str(last_segment.get("type", "")) != MapSegmentDefinitionScript.TYPE_FINISH:
		_add_error(result, "segment_sequence must end with a finish segment.")

	if blueprint.moving_obstacles_enabled:
		var has_moving_segment: bool = false
		for segment_id in blueprint.segment_sequence:
			var segment: Dictionary = MapSegmentDefinitionScript.get_segment(segment_id)
			if str(segment.get("type", "")) == MapSegmentDefinitionScript.TYPE_MOVING_BLOCK_LANE:
				has_moving_segment = true
				break
		if not has_moving_segment:
			_add_warning(result, "moving_obstacles_enabled but no moving_block_lane segment present.")


static func _validate_segment_assets(blueprint, result: Dictionary) -> void:
	for segment_id in blueprint.segment_sequence:
		var segment: Dictionary = MapSegmentDefinitionScript.get_segment(segment_id)
		for asset_id_value in segment.get("required_assets", []):
			var asset_id: String = str(asset_id_value)
			if not MapAssetLibraryScript.has_asset(asset_id):
				_add_error(result, "Segment '%s' requires missing asset '%s'." % [segment_id, asset_id])


static func _validate_height_transitions(blueprint, result: Dictionary) -> void:
	var route_height: float = blueprint.deck_y
	var height_adjusting_types: Array[String] = [
		MapSegmentDefinitionScript.TYPE_RAMP_UP,
		MapSegmentDefinitionScript.TYPE_RAMP_DOWN,
		MapSegmentDefinitionScript.TYPE_DROP,
		MapSegmentDefinitionScript.TYPE_SIDE_DROP,
		MapSegmentDefinitionScript.TYPE_ELEVATED_RAMP_DROP,
	]

	for index in range(blueprint.segment_sequence.size()):
		var segment_id: String = str(blueprint.segment_sequence[index])
		var segment: Dictionary = MapSegmentDefinitionScript.get_segment(segment_id)
		if segment.is_empty():
			continue

		var segment_type: String = str(segment.get("type", ""))
		var height_delta: float = float(segment.get("height_delta", 0.0))

		if absf(height_delta) > 0.001 and not segment_type in height_adjusting_types:
			_add_error(
				result,
				"Segment '%s' has height_delta %.2f but type '%s' cannot adjust elevation."
				% [segment_id, height_delta, segment_type]
			)

		if segment_type in [
			MapSegmentDefinitionScript.TYPE_RAMP_UP,
			MapSegmentDefinitionScript.TYPE_RAMP_DOWN,
		] and absf(height_delta) < 0.001:
			_add_error(result, "Ramp segment '%s' must define a non-zero height_delta." % segment_id)

		if segment_type == MapSegmentDefinitionScript.TYPE_RAMP_UP and height_delta <= 0.0:
			_add_error(result, "ramp_up segment '%s' must have positive height_delta." % segment_id)
		if segment_type == MapSegmentDefinitionScript.TYPE_RAMP_DOWN and height_delta >= 0.0:
			_add_error(result, "ramp_down segment '%s' must have negative height_delta." % segment_id)

		route_height += height_delta

	if route_height < blueprint.deck_y - 12.0 or route_height > blueprint.deck_y + 12.0:
		_add_warning(
			result,
			"Route cumulative height %.2f may be extreme relative to deck_y %.2f."
			% [route_height, blueprint.deck_y]
		)


static func _validate_gap_fall_settings(blueprint, result: Dictionary) -> void:
	var needs_fall: bool = false
	for segment_id in blueprint.segment_sequence:
		var segment: Dictionary = MapSegmentDefinitionScript.get_segment(segment_id)
		var segment_type: String = str(segment.get("type", ""))
		if segment_type in [
			MapSegmentDefinitionScript.TYPE_GAP,
			MapSegmentDefinitionScript.TYPE_DROP,
			MapSegmentDefinitionScript.TYPE_SIDE_DROP,
			MapSegmentDefinitionScript.TYPE_SMALL_CENTER_GAP,
			MapSegmentDefinitionScript.TYPE_LEFT_SIDE_DROP,
			MapSegmentDefinitionScript.TYPE_RIGHT_SIDE_DROP,
			MapSegmentDefinitionScript.TYPE_DOUBLE_SIDE_DROP,
			MapSegmentDefinitionScript.TYPE_BROKEN_BRIDGE_GAP,
			MapSegmentDefinitionScript.TYPE_ELEVATED_RAMP_DROP,
			MapSegmentDefinitionScript.TYPE_CRACKED_EDGE_LANE,
			MapSegmentDefinitionScript.TYPE_SPLIT_GAP_CHOICE,
		]:
			needs_fall = true
			break

	if needs_fall and not blueprint.fall_enabled:
		_add_error(
			result,
			"Blueprint contains gap/drop segments but fall_enabled is false; enable fall for OOB min-Y."
		)


static func _validate_rail_barrier_match(blueprint, result: Dictionary) -> void:
	for segment_id in blueprint.segment_sequence:
		var segment: Dictionary = MapSegmentDefinitionScript.get_segment(segment_id)
		var segment_type: String = str(segment.get("type", ""))
		if segment_type not in [
			MapSegmentDefinitionScript.TYPE_BRIDGE,
			MapSegmentDefinitionScript.TYPE_NARROW_BRIDGE,
		]:
			continue

		var has_edge_guard: bool = false
		for asset_id_value in segment.get("required_assets", []):
			var asset_id: String = str(asset_id_value)
			var asset: Dictionary = MapAssetLibraryScript.get_asset(asset_id)
			if asset.is_empty():
				continue
			var category: int = int(asset.get("category", MapAssetLibraryScript.Category.UNKNOWN))
			if category in [
				MapAssetLibraryScript.Category.RAIL,
				MapAssetLibraryScript.Category.BARRIER,
			]:
				has_edge_guard = true
				break

		if not has_edge_guard:
			_add_error(
				result,
				"Bridge segment '%s' must include at least one rail or barrier asset." % segment_id
			)


static func _validate_route_length(blueprint, result: Dictionary) -> void:
	var built_length: float = blueprint.get_total_route_length()
	if built_length <= 8.0:
		_add_error(result, "Route length %.1f is too short." % built_length)
	var length_delta: float = abs(built_length - blueprint.target_length)
	if length_delta > blueprint.target_length * 0.5:
		_add_warning(
			result,
			"Built route length %.1f differs from target_length %.1f."
			% [built_length, blueprint.target_length]
		)


static func _validate_definition_preview(blueprint, result: Dictionary) -> void:
	var definition: RaceMapDefinition = blueprint.to_race_map_definition()
	_validate_definition_values(definition, blueprint, result)


static func _validate_route_layout_alignment(
	blueprint,
	result: Dictionary,
	definition: RaceMapDefinition = null
) -> void:
	if definition == null:
		definition = blueprint.to_race_map_definition()
	for error in AIMapRouteLayoutScript.definition_matches_layout(definition, blueprint):
		_add_error(result, error)


static func _validate_generated_geometry_alignment(
	root: Node3D,
	blueprint,
	definition: RaceMapDefinition,
	result: Dictionary
) -> void:
	if root == null or definition == null:
		return

	var layout: Dictionary = AIMapRouteLayoutScript.compute_layout(blueprint)
	var floor_bounds: Dictionary = AIMapRouteLayoutScript.collect_safe_floor_z_bounds(root)
	if int(floor_bounds.get("count", 0)) <= 0:
		_add_error(result, "Generated safe floor has no collision plates with measurable bounds.")
		return

	var route_min_z: float = float(layout.get("route_min_z", 0.0))
	var route_max_z: float = float(layout.get("route_max_z", 0.0))
	var floor_min_z: float = float(floor_bounds.get("min_z", 0.0))
	var floor_max_z: float = float(floor_bounds.get("max_z", 0.0))
	if floor_min_z > route_min_z + 0.5:
		_add_error(
			result,
			"Safe floor min Z %.2f starts after route origin %.2f."
			% [floor_min_z, route_min_z]
		)
	if floor_max_z < route_max_z - 0.5:
		_add_error(
			result,
			"Safe floor max Z %.2f ends before route terminus %.2f."
			% [floor_max_z, route_max_z]
		)

	var spawn_marker: Node3D = _find_named_node(root, "SpawnMarker") as Node3D
	var goal_marker: Node3D = _find_named_node(root, "GoalMarker") as Node3D
	if spawn_marker == null:
		_add_error(result, "SpawnMarker is missing from generated scene.")
	if goal_marker == null:
		_add_error(result, "GoalMarker is missing from generated scene.")
	if spawn_marker != null:
		var start_length: float = _first_segment_length(blueprint)
		var expected_spawn_center_z: float = start_length * 0.5
		if absf(spawn_marker.position.z - expected_spawn_center_z) > 0.25:
			_add_error(
				result,
				"SpawnMarker Z %.2f does not align with start segment center %.2f."
				% [spawn_marker.position.z, expected_spawn_center_z]
			)
	if goal_marker != null:
		var expected_goal_center_z: float = float(layout.get("goal_z", 0.0))
		if absf(goal_marker.position.z - expected_goal_center_z) > 0.25:
			_add_error(
				result,
				"GoalMarker Z %.2f does not align with layout goal Z %.2f."
				% [goal_marker.position.z, expected_goal_center_z]
			)


static func _first_segment_length(blueprint) -> float:
	if blueprint.segment_sequence.is_empty():
		return 8.0
	var first_segment: Dictionary = MapSegmentDefinitionScript.get_segment(
		str(blueprint.segment_sequence[0])
	)
	return float(first_segment.get("length", 8.0))


static func _find_named_node(node: Node, node_name: String) -> Node:
	if node.name == node_name:
		return node
	for child in node.get_children():
		var found: Node = _find_named_node(child, node_name)
		if found != null:
			return found
	return null


static func _validate_definition_values(
	definition: RaceMapDefinition,
	blueprint,
	result: Dictionary
) -> void:
	if definition.spawn_origin.z >= definition.goal_position.z:
		_add_error(result, "spawn_origin.z must be less than goal_position.z.")
	if abs(definition.spawn_origin.y - (blueprint.deck_y + 0.8)) > 0.05:
		_add_error(
			result,
			"spawn_origin.y must align with deck_y + clearance (%.2f vs expected %.2f)."
			% [definition.spawn_origin.y, blueprint.deck_y + 0.8]
		)
	if definition.out_of_bounds_half_width < definition.lane_half_width:
		_add_error(result, "out_of_bounds_half_width must be >= lane_half_width.")
	if blueprint.has_split_merge_segments():
		var route_max_half: float = blueprint.get_route_max_half_width()
		if definition.out_of_bounds_half_width < route_max_half + 1.0:
			_add_error(
				result,
				"Split/merge route half-width %.1f exceeds OOB half-width %.1f."
				% [route_max_half, definition.out_of_bounds_half_width]
			)
	if blueprint.fall_enabled and definition.out_of_bounds_min_y >= definition.spawn_origin.y - 0.25:
		_add_error(result, "fall_enabled requires out_of_bounds_min_y below spawn height.")
	if blueprint.fall_enabled and definition.out_of_bounds_min_y >= blueprint.deck_y - 0.5:
		_add_error(
			result,
			"fall_enabled requires out_of_bounds_min_y below deck_y (%.2f vs deck %.2f)."
			% [definition.out_of_bounds_min_y, blueprint.deck_y]
		)
	if abs(definition.base_position.z - definition.goal_position.z) > RaceMapController.FINISH_POSITION_TOLERANCE:
		_add_error(result, "base_position.z must align with goal_position.z for finish contract.")


static func _validate_phase2_fall_gap_rules(blueprint, result: Dictionary) -> void:
	_validate_spawn_finish_not_in_fall_segments(blueprint, result)
	_validate_gap_recovery_floors(blueprint, result)
	_validate_safe_floor_before_gaps(blueprint, result)
	_validate_hidden_floor_width(blueprint, result)
	_validate_elevated_water_clearance(blueprint, result)
	_validate_side_drop_oob_clearance(blueprint, result)
	_validate_elevated_camera_requirement(blueprint, result)


static func _validate_phase4_split_merge_rules(blueprint, result: Dictionary) -> void:
	if not blueprint.has_split_merge_segments():
		return
	_validate_split_merge_balance(blueprint, result)
	_validate_split_merge_spawn_finish(blueprint, result)
	_validate_branch_safe_floors(blueprint, result)
	_validate_low_risk_branch_required(blueprint, result)
	_validate_merge_recovery_length(blueprint, result)
	_validate_branch_oob_bounds(blueprint, result)
	_validate_hidden_branch_floors(blueprint, result)
	_validate_split_route_camera_framing(blueprint, result)
	_validate_risk_reward_route_markers(blueprint, result)


static func _validate_split_merge_balance(blueprint, result: Dictionary) -> void:
	var open_splits: int = 0
	var saw_split: bool = false
	for segment_id in blueprint.segment_sequence:
		var segment: Dictionary = MapSegmentDefinitionScript.get_segment(segment_id)
		var segment_type: String = str(segment.get("type", ""))
		if MapSegmentDefinitionScript.is_split_segment_type(segment_type):
			open_splits += 1
			saw_split = true
		if MapSegmentDefinitionScript.is_merge_segment_type(segment_type):
			if open_splits <= 0:
				_add_error(result, "Merge segment '%s' without preceding split." % segment_id)
			else:
				open_splits -= 1
	if saw_split and open_splits > 0:
		_add_error(result, "Split segments must merge before finish (unclosed split count=%d)." % open_splits)


static func _validate_split_merge_spawn_finish(blueprint, result: Dictionary) -> void:
	if blueprint.segment_sequence.is_empty():
		return
	var first_id: String = str(blueprint.segment_sequence[0])
	var last_id: String = str(blueprint.segment_sequence.back())
	for segment_id in [first_id, last_id]:
		var segment_type: String = str(MapSegmentDefinitionScript.get_segment(segment_id).get("type", ""))
		if MapSegmentDefinitionScript.is_split_segment_type(segment_type):
			_add_error(result, "Spawn/finish cannot be split segment '%s'." % segment_id)
		if MapSegmentDefinitionScript.is_merge_segment_type(segment_type):
			_add_error(result, "Spawn/finish cannot be merge segment '%s'." % segment_id)
		if MapSegmentDefinitionScript.is_branch_route_segment_type(segment_type):
			_add_error(result, "Spawn/finish cannot be branch segment '%s'." % segment_id)


static func _validate_branch_safe_floors(blueprint, result: Dictionary) -> void:
	for segment_id in blueprint.segment_sequence:
		var segment: Dictionary = MapSegmentDefinitionScript.get_segment(segment_id)
		var branch_widths: Array = segment.get("branch_widths", [])
		if branch_widths.is_empty() and MapSegmentDefinitionScript.is_branch_route_segment_type(
			str(segment.get("type", ""))
		):
			_add_error(result, "Branch segment '%s' must define branch_widths with safe floor." % segment_id)
			continue
		if branch_widths.is_empty():
			continue
		var has_floor_asset: bool = false
		for asset_id_value in segment.get("required_assets", []):
			var asset_id: String = str(asset_id_value)
			if "safe_floor_plate" in asset_id:
				has_floor_asset = true
				break
		if not has_floor_asset:
			_add_error(result, "Route segment '%s' must include a safe_floor_plate asset." % segment_id)


static func _validate_low_risk_branch_required(blueprint, result: Dictionary) -> void:
	var in_split_section: bool = false
	var section_has_low_risk: bool = false
	for segment_id in blueprint.segment_sequence:
		var segment: Dictionary = MapSegmentDefinitionScript.get_segment(segment_id)
		var segment_type: String = str(segment.get("type", ""))
		if MapSegmentDefinitionScript.is_split_segment_type(segment_type):
			in_split_section = true
			section_has_low_risk = false
			continue
		if in_split_section:
			var risk: int = int(segment.get("route_risk_level", 0))
			if segment_type == MapSegmentDefinitionScript.TYPE_WIDE_SAFE_ROUTE or risk <= 0:
				section_has_low_risk = true
			if int(segment.get("difficulty", 1)) <= 2 and risk <= 1:
				section_has_low_risk = true
		if MapSegmentDefinitionScript.is_merge_segment_type(segment_type):
			if in_split_section and not section_has_low_risk:
				_add_error(
					result,
					"Split section ending at '%s' must include at least one low-risk branch."
					% segment_id
				)
			in_split_section = false


static func _validate_merge_recovery_length(blueprint, result: Dictionary) -> void:
	var sequence: Array = blueprint.segment_sequence
	for index in range(sequence.size()):
		var segment_id: String = str(sequence[index])
		var segment: Dictionary = MapSegmentDefinitionScript.get_segment(segment_id)
		if not MapSegmentDefinitionScript.is_merge_segment_type(str(segment.get("type", ""))):
			continue
		var min_recovery: float = float(segment.get("min_recovery_after_merge", 8.0))
		if index + 1 >= sequence.size():
			continue
		var next_segment: Dictionary = MapSegmentDefinitionScript.get_segment(str(sequence[index + 1]))
		var next_type: String = str(next_segment.get("type", ""))
		if next_type in [MapSegmentDefinitionScript.TYPE_FINISH]:
			_add_warning(
				result,
				"Merge segment '%s' is immediately followed by finish; consider recovery straight."
				% segment_id
			)
			continue
		var next_length: float = float(next_segment.get("length", 0.0))
		if next_length < min_recovery and next_type not in [
			MapSegmentDefinitionScript.TYPE_MERGE_RECOVERY,
			MapSegmentDefinitionScript.TYPE_RECOVERY,
			MapSegmentDefinitionScript.TYPE_STRAIGHT,
		]:
			_add_warning(
				result,
				"Segment after merge '%s' length %.1f < recommended recovery %.1f."
				% [segment_id, next_length, min_recovery]
			)


static func _validate_branch_oob_bounds(blueprint, result: Dictionary) -> void:
	if blueprint.fall_enabled:
		return
	for segment_id in blueprint.segment_sequence:
		var segment: Dictionary = MapSegmentDefinitionScript.get_segment(segment_id)
		var offsets: Array = segment.get("branch_offsets", [])
		var widths: Array = segment.get("branch_widths", [])
		for index in range(offsets.size()):
			var offset_x: float = float(offsets[index])
			var branch_half: float = float(widths[index] if index < widths.size() else 0.0) * 0.5
			var extent: float = abs(offset_x) + branch_half
			if extent > blueprint.get_route_max_half_width() + 0.5:
				_add_error(
					result,
					"Branch on segment '%s' extends beyond route OOB bounds (extent %.1f)."
					% [segment_id, extent]
				)


static func _validate_hidden_branch_floors(blueprint, result: Dictionary) -> void:
	for segment_id in blueprint.segment_sequence:
		var segment: Dictionary = MapSegmentDefinitionScript.get_segment(segment_id)
		var ratio: float = float(segment.get("safe_floor_width_ratio", 1.0))
		var total_width: float = float(segment.get("total_width", segment.get("width", 10.0)))
		var branch_widths: Array = segment.get("branch_widths", [])
		if branch_widths.is_empty():
			continue
		var branch_total: float = 0.0
		for branch_width_value in branch_widths:
			branch_total += float(branch_width_value)
		if branch_total * ratio > total_width * 1.15:
			_add_error(
				result,
				"Segment '%s' hidden branch floor width exceeds visible route width."
				% segment_id
			)


static func _validate_split_route_camera_framing(blueprint, result: Dictionary) -> void:
	var definition: RaceMapDefinition = blueprint.to_race_map_definition()
	var camera_view: Dictionary = RaceMapController.compute_race_camera_view_for_definition(definition)
	if camera_view.get("position", Vector3.ZERO) == Vector3.ZERO:
		_add_error(result, "Split/merge route requires valid camera framing.")
		return
	var route_max_half: float = blueprint.get_route_max_half_width()
	var camera_side: float = abs(float(camera_view.get("position", Vector3.ZERO).x))
	if camera_side < route_max_half + 4.0:
		_add_warning(
			result,
			"Camera side offset %.1f may be tight for route half-width %.1f."
			% [camera_side, route_max_half]
		)


static func _validate_risk_reward_route_markers(blueprint, result: Dictionary) -> void:
	for segment_id in blueprint.segment_sequence:
		var segment: Dictionary = MapSegmentDefinitionScript.get_segment(segment_id)
		if str(segment.get("type", "")) != MapSegmentDefinitionScript.TYPE_RISK_REWARD_SPLIT:
			continue
		var has_marker: bool = false
		for asset_id_value in segment.get("required_assets", []) + segment.get("optional_assets", []):
			var asset: Dictionary = MapAssetLibraryScript.get_asset(str(asset_id_value))
			if str(asset.get("route_category", "")) == "route_marker":
				has_marker = true
				break
		if not has_marker:
			_add_warning(result, "risk_reward_split '%s' should include route sign/marker assets." % segment_id)


static func _validate_phase3_moving_obstacle_rules(blueprint, result: Dictionary) -> void:
	var has_moving_segments: bool = blueprint.has_moving_obstacle_segments()
	if not has_moving_segments:
		return
	if not blueprint.moving_obstacles_enabled:
		_add_error(
			result,
			"Blueprint contains moving obstacle segments but moving_obstacles_enabled is false."
		)

	_validate_moving_obstacle_spawn_finish_placement(blueprint, result)
	_validate_moving_obstacle_safe_lanes(blueprint, result)
	_validate_moving_obstacle_cycle_times(blueprint, result)
	_validate_moving_obstacle_movement_bounds(blueprint, result)
	_validate_moving_platform_recovery(blueprint, result)
	_validate_drop_and_play_obstacle_assets(blueprint, result)


static func _validate_moving_obstacle_spawn_finish_placement(blueprint, result: Dictionary) -> void:
	if blueprint.segment_sequence.is_empty():
		return
	var first_id: String = str(blueprint.segment_sequence[0])
	var last_id: String = str(blueprint.segment_sequence.back())
	for segment_id in [first_id, last_id]:
		var segment_type: String = str(MapSegmentDefinitionScript.get_segment(segment_id).get("type", ""))
		if MapSegmentDefinitionScript.is_moving_obstacle_segment_type(segment_type):
			_add_error(
				result,
				"Moving obstacle segment '%s' cannot be used as spawn or finish segment." % segment_id
			)


static func _validate_moving_obstacle_safe_lanes(blueprint, result: Dictionary) -> void:
	for segment_id in blueprint.segment_sequence:
		var segment: Dictionary = MapSegmentDefinitionScript.get_segment(segment_id)
		var segment_type: String = str(segment.get("type", ""))
		if not MapSegmentDefinitionScript.is_moving_obstacle_segment_type(segment_type):
			continue
		var safe_lane_count: int = int(segment.get("safe_lane_count", 0))
		var fallback_safe_lane: bool = bool(segment.get("fallback_safe_lane", false))
		if safe_lane_count < 1:
			_add_error(
				result,
				"Moving obstacle segment '%s' must keep at least one safe_lane_count." % segment_id
			)
		if not fallback_safe_lane:
			_add_error(
				result,
				"Moving obstacle segment '%s' must set fallback_safe_lane=true." % segment_id
			)
		var safe_lane_width: float = float(segment.get("fallback_safe_lane_width", 0.0))
		if safe_lane_width < 1.5:
			_add_error(
				result,
				"Moving obstacle segment '%s' fallback_safe_lane_width too narrow." % segment_id
			)
		var max_block_distance: float = _get_segment_max_movement_distance(segment)
		var available_half: float = blueprint.route_half_width - safe_lane_width * 0.5
		if max_block_distance >= available_half * 2.0:
			_add_error(
				result,
				"Moving obstacle segment '%s' movement blocks all lanes permanently." % segment_id
			)


static func _validate_moving_obstacle_cycle_times(blueprint, result: Dictionary) -> void:
	for segment_id in blueprint.segment_sequence:
		var segment: Dictionary = MapSegmentDefinitionScript.get_segment(segment_id)
		if not MapSegmentDefinitionScript.is_moving_obstacle_segment_type(str(segment.get("type", ""))):
			continue
		var cycle_time: float = blueprint.get_effective_cycle_time(segment)
		if cycle_time < MIN_OBSTACLE_CYCLE_TIME or cycle_time > MAX_OBSTACLE_CYCLE_TIME:
			_add_error(
				result,
				"Moving obstacle segment '%s' cycle_time %.2f outside allowed range [%.1f, %.1f]."
				% [segment_id, cycle_time, MIN_OBSTACLE_CYCLE_TIME, MAX_OBSTACLE_CYCLE_TIME]
			)


static func _validate_moving_obstacle_movement_bounds(blueprint, result: Dictionary) -> void:
	for segment_id in blueprint.segment_sequence:
		var segment: Dictionary = MapSegmentDefinitionScript.get_segment(segment_id)
		if not MapSegmentDefinitionScript.is_moving_obstacle_segment_type(str(segment.get("type", ""))):
			continue
		var segment_length: float = float(segment.get("length", 8.0))
		var segment_width: float = float(segment.get("width", 10.0))
		var movement_axis: String = str(segment.get("movement_axis", "x"))
		for asset_id_value in segment.get("required_assets", []):
			var asset_id: String = str(asset_id_value)
			if not MapAssetLibraryScript.is_moving_obstacle_asset(asset_id):
				continue
			var asset: Dictionary = MapAssetLibraryScript.get_asset(asset_id)
			var distance: float = float(asset.get("movement_distance", 0.0))
			var axis: String = str(asset.get("movement_axis", movement_axis))
			if axis == "x" and distance > segment_width * 0.45:
				_add_error(
					result,
					"Asset '%s' movement_distance %.2f exceeds segment '%s' width bounds."
					% [asset_id, distance, segment_id]
				)
			if axis == "z" and distance > segment_length * 0.45:
				_add_error(
					result,
					"Asset '%s' movement_distance %.2f exceeds segment '%s' length bounds."
					% [asset_id, distance, segment_id]
				)


static func _validate_moving_platform_recovery(blueprint, result: Dictionary) -> void:
	var sequence: Array = blueprint.segment_sequence
	for index in range(sequence.size()):
		var segment_id: String = str(sequence[index])
		var segment_type: String = str(MapSegmentDefinitionScript.get_segment(segment_id).get("type", ""))
		if not MapSegmentDefinitionScript.is_platform_gap_segment_type(segment_type):
			continue
		if index + 1 >= sequence.size():
			_add_error(
				result,
				"Moving platform gap '%s' must be followed by recovery safe floor." % segment_id
			)
			continue
		var next_type: String = str(MapSegmentDefinitionScript.get_segment(str(sequence[index + 1])).get("type", ""))
		if next_type not in [
			MapSegmentDefinitionScript.TYPE_RECOVERY,
			MapSegmentDefinitionScript.TYPE_HAZARD_RECOVERY,
			MapSegmentDefinitionScript.TYPE_STRAIGHT,
		]:
			_add_error(
				result,
				"Moving platform gap '%s' must be followed by hazard_recovery_straight or safe straight (not finish)."
				% segment_id
			)


static func _validate_drop_and_play_obstacle_assets(blueprint, result: Dictionary) -> void:
	if not blueprint.has_moving_obstacle_segments():
		return
	for segment_id in blueprint.segment_sequence:
		var segment: Dictionary = MapSegmentDefinitionScript.get_segment(segment_id)
		if not MapSegmentDefinitionScript.is_moving_obstacle_segment_type(str(segment.get("type", ""))):
			continue
		for asset_id_value in segment.get("required_assets", []):
			var asset_id: String = str(asset_id_value)
			if not MapAssetLibraryScript.is_moving_obstacle_asset(asset_id):
				continue
			var asset: Dictionary = MapAssetLibraryScript.get_asset(asset_id)
			if asset.is_empty():
				_add_error(result, "Moving obstacle asset '%s' is missing from MapAssetLibrary." % asset_id)
				continue
			var scene_path: String = str(asset.get("scene_path", ""))
			if MapAssetLibraryScript.is_drop_and_play_obstacle_asset(asset_id):
				if scene_path.is_empty() or not scene_path.ends_with(".tscn"):
					_add_error(
						result,
						"Drop-and-play obstacle '%s' must define a .tscn scene_path." % asset_id
					)
				elif not ResourceLoader.exists(scene_path):
					_add_error(
						result,
						"Drop-and-play obstacle scene missing for '%s' at %s." % [asset_id, scene_path]
					)
			var cycle_time: float = blueprint.get_effective_cycle_time(segment)
			if cycle_time <= 0.0:
				_add_error(
					result,
					"Moving obstacle segment '%s' cycle_time must be > 0." % segment_id
				)
			if str(asset.get("hazard_behavior", "")) == "kill":
				_add_error(
					result,
					"Moving obstacle '%s' direct kill hazard_behavior is banned; use block/push/timing/prototype."
					% asset_id
				)


static func _validate_moving_obstacle_scene_contract(obstacles_bucket: Node, result: Dictionary) -> void:
	for child in obstacles_bucket.get_children():
		_validate_single_moving_obstacle_node(child, result)


static func _validate_single_moving_obstacle_node(node: Node, result: Dictionary) -> void:
	if node is Camera3D:
		_add_error(result, "Moving obstacle must not include Camera3D: %s" % node.get_path())
	if node is Area3D and node.name == "GoalCatch":
		_add_error(result, "Moving obstacle must not include GoalCatch: %s" % node.get_path())
	if node.get_script() != null:
		var script_path: String = str(node.get_script().resource_path)
		if script_path == VOID_KILL_SCRIPT_PATH:
			_add_error(result, "Moving obstacle must not use bridge_void_kill_zone: %s" % node.get_path())
	for child in node.get_children():
		_validate_single_moving_obstacle_node(child, result)


static func _get_segment_max_movement_distance(segment: Dictionary) -> float:
	var max_distance: float = 0.0
	for asset_id_value in segment.get("required_assets", []):
		var asset_id: String = str(asset_id_value)
		if not MapAssetLibraryScript.is_moving_obstacle_asset(asset_id):
			continue
		var asset: Dictionary = MapAssetLibraryScript.get_asset(asset_id)
		max_distance = maxf(max_distance, float(asset.get("movement_distance", 0.0)))
	return max_distance


static func _validate_no_obstacle_finish_hijack(root: Node, result: Dictionary) -> void:
	_find_goal_catch_nodes(root, result)
	_find_obstacle_camera_hijack(root, result)


static func _find_obstacle_camera_hijack(node: Node, result: Dictionary) -> void:
	if node is Camera3D:
		var camera: Camera3D = node as Camera3D
		if "obstacle" in camera.name.to_lower() and camera.current:
			_add_error(result, "Obstacle script must not hijack current camera: %s" % camera.get_path())
	for child in node.get_children():
		_find_obstacle_camera_hijack(child, result)


static func _validate_spawn_finish_not_in_fall_segments(blueprint, result: Dictionary) -> void:
	if blueprint.segment_sequence.is_empty():
		return
	var first_id: String = str(blueprint.segment_sequence[0])
	var last_id: String = str(blueprint.segment_sequence.back())
	var first_type: String = str(MapSegmentDefinitionScript.get_segment(first_id).get("type", ""))
	var last_type: String = str(MapSegmentDefinitionScript.get_segment(last_id).get("type", ""))
	if MapSegmentDefinitionScript.is_fall_risk_segment_type(first_type):
		_add_error(result, "Spawn segment '%s' cannot be a gap/drop/fall-risk segment." % first_id)
	if MapSegmentDefinitionScript.is_fall_risk_segment_type(last_type):
		_add_error(result, "Finish segment '%s' cannot be a gap/drop/fall-risk segment." % last_id)
	if MapSegmentDefinitionScript.is_gap_segment_type(first_type):
		_add_error(result, "Spawn cannot be placed inside gap segment '%s'." % first_id)
	if MapSegmentDefinitionScript.is_gap_segment_type(last_type):
		_add_error(result, "Finish cannot be placed inside gap segment '%s'." % last_id)


static func _validate_gap_recovery_floors(blueprint, result: Dictionary) -> void:
	var sequence: Array = blueprint.segment_sequence
	for index in range(sequence.size()):
		var segment_id: String = str(sequence[index])
		var segment: Dictionary = MapSegmentDefinitionScript.get_segment(segment_id)
		var segment_type: String = str(segment.get("type", ""))
		if not MapSegmentDefinitionScript.is_gap_segment_type(segment_type):
			continue
		if index + 1 >= sequence.size():
			_add_error(result, "Gap segment '%s' must be followed by recovery safe floor." % segment_id)
			continue
		var next_segment: Dictionary = MapSegmentDefinitionScript.get_segment(str(sequence[index + 1]))
		var next_type: String = str(next_segment.get("type", ""))
		if not (
			MapSegmentDefinitionScript.is_recovery_segment_type(next_type)
			or next_type in [
				MapSegmentDefinitionScript.TYPE_STRAIGHT,
				MapSegmentDefinitionScript.TYPE_BRIDGE,
				MapSegmentDefinitionScript.TYPE_ELEVATED,
				MapSegmentDefinitionScript.TYPE_FINISH,
			]
		):
			_add_error(
				result,
				"Gap segment '%s' must be followed by recovery_straight_after_gap or safe straight."
				% segment_id
			)


static func _validate_safe_floor_before_gaps(blueprint, result: Dictionary) -> void:
	var sequence: Array = blueprint.segment_sequence
	for index in range(sequence.size()):
		var segment_id: String = str(sequence[index])
		var segment: Dictionary = MapSegmentDefinitionScript.get_segment(segment_id)
		var segment_type: String = str(segment.get("type", ""))
		if not MapSegmentDefinitionScript.is_gap_segment_type(segment_type):
			continue
		if index <= 0:
			_add_error(result, "Gap segment '%s' must have safe floor segment before it." % segment_id)
			continue
		var prev_segment: Dictionary = MapSegmentDefinitionScript.get_segment(str(sequence[index - 1]))
		var prev_type: String = str(prev_segment.get("type", ""))
		if prev_type in [
			MapSegmentDefinitionScript.TYPE_GAP,
			MapSegmentDefinitionScript.TYPE_BROKEN_BRIDGE_GAP,
			MapSegmentDefinitionScript.TYPE_SMALL_CENTER_GAP,
		]:
			_add_error(
				result,
				"Gap segment '%s' must have valid safe floor before it (not another gap)." % segment_id
			)


static func _validate_hidden_floor_width(blueprint, result: Dictionary) -> void:
	for segment_id in blueprint.segment_sequence:
		var segment: Dictionary = MapSegmentDefinitionScript.get_segment(segment_id)
		var segment_type: String = str(segment.get("type", ""))
		var ratio: float = float(segment.get("safe_floor_width_ratio", 1.0))
		var segment_width: float = float(segment.get("width", 10.0))
		var visible_half: float = blueprint.route_half_width
		var floor_half: float = segment_width * ratio * 0.5
		if MapSegmentDefinitionScript.is_gap_segment_type(segment_type) and ratio > 0.75:
			_add_error(
				result,
				"Gap segment '%s' safe_floor_width_ratio %.2f is too wide; hidden floor beyond visible road."
				% [segment_id, ratio]
			)
		if floor_half > visible_half * 1.25 and segment_type not in [
			MapSegmentDefinitionScript.TYPE_RECOVERY,
			MapSegmentDefinitionScript.TYPE_STRAIGHT,
			MapSegmentDefinitionScript.TYPE_START,
			MapSegmentDefinitionScript.TYPE_FINISH,
		]:
			_add_error(
				result,
				"Segment '%s' floor width %.1f exceeds visible road half-width %.1f."
				% [segment_id, floor_half * 2.0, visible_half * 2.0]
			)


static func _validate_elevated_water_clearance(blueprint, result: Dictionary) -> void:
	if not blueprint.water_enabled:
		return
	var has_elevated: bool = false
	for segment_id in blueprint.segment_sequence:
		var segment_type: String = str(
			MapSegmentDefinitionScript.get_segment(segment_id).get("type", "")
		)
		if MapSegmentDefinitionScript.is_elevated_segment_type(segment_type):
			has_elevated = true
			break
	if not has_elevated:
		return
	var void_y: float = blueprint.get_water_void_y()
	if blueprint.deck_y <= void_y:
		_add_error(
			result,
			"Elevated map requires deck_y (%.2f) above water/void_y (%.2f)."
			% [blueprint.deck_y, void_y]
		)
	var definition: RaceMapDefinition = blueprint.to_race_map_definition()
	if definition.out_of_bounds_min_y >= void_y:
		_add_error(
			result,
			"Elevated map out_of_bounds_min_y (%.2f) must be below water/void_y (%.2f)."
			% [definition.out_of_bounds_min_y, void_y]
		)


static func _validate_side_drop_oob_clearance(blueprint, result: Dictionary) -> void:
	if not blueprint.fall_enabled:
		return
	var definition: RaceMapDefinition = blueprint.to_race_map_definition()
	for segment_id in blueprint.segment_sequence:
		var segment: Dictionary = MapSegmentDefinitionScript.get_segment(segment_id)
		var segment_type: String = str(segment.get("type", ""))
		if segment_type not in [
			MapSegmentDefinitionScript.TYPE_SIDE_DROP,
			MapSegmentDefinitionScript.TYPE_LEFT_SIDE_DROP,
			MapSegmentDefinitionScript.TYPE_RIGHT_SIDE_DROP,
			MapSegmentDefinitionScript.TYPE_DOUBLE_SIDE_DROP,
		]:
			continue
		if definition.out_of_bounds_min_y >= blueprint.deck_y - 0.25:
			_add_error(
				result,
				"Side drop segment '%s' requires out_of_bounds_min_y below deck; zombies at deck height must not die."
				% segment_id
			)


static func _validate_elevated_camera_requirement(blueprint, result: Dictionary) -> void:
	if not blueprint.has_elevated_or_drop_segments():
		return
	var definition: RaceMapDefinition = blueprint.to_race_map_definition()
	var camera_view: Dictionary = RaceMapController.compute_race_camera_view_for_definition(definition)
	if camera_view.get("position", Vector3.ZERO) == Vector3.ZERO:
		_add_error(result, "Elevated/drop map requires valid camera framing from RaceMapController.")


static func _validate_elevated_camera_framing(
	definition: RaceMapDefinition,
	blueprint,
	result: Dictionary
) -> void:
	if not blueprint.has_elevated_or_drop_segments():
		return
	var padding: float = blueprint.get_recommended_camera_padding()
	if padding > 0.0:
		var camera_view: Dictionary = RaceMapController.compute_race_camera_view_for_definition(definition)
		var cam_pos: Vector3 = camera_view.get("position", Vector3.ZERO)
		if cam_pos.y < definition.spawn_origin.y + padding * 0.5:
			_add_warning(
				result,
				"Camera height may be low for elevated/drop map (padding=%.1f)." % padding
			)


static func _validate_no_goal_catch(root: Node, result: Dictionary) -> void:
	_find_goal_catch_nodes(root, result)


static func _find_goal_catch_nodes(node: Node, result: Dictionary) -> void:
	if node is Area3D and node.name == "GoalCatch":
		_add_error(result, "Generated map must not contain GoalCatch; finish is World/StreamerBase only.")
	for child in node.get_children():
		_find_goal_catch_nodes(child, result)


static func _validate_no_authoritative_void_kill(root: Node, result: Dictionary) -> void:
	_find_void_kill_nodes(root, result)


static func _find_void_kill_nodes(node: Node, result: Dictionary) -> void:
	if node.get_script() != null:
		var script_path: String = str(node.get_script().resource_path)
		if script_path == VOID_KILL_SCRIPT_PATH:
			_add_error(result, "Generated map must not attach bridge_void_kill_zone authority.")
	if node is Area3D:
		var area: Area3D = node as Area3D
		if area.name.to_lower().contains("void") and area.name.to_lower().contains("kill"):
			if area.monitoring or not _all_collision_shapes_disabled(area):
				_add_error(result, "Void kill Area3D must not monitor collisions: %s" % area.get_path())
	for child in node.get_children():
		_find_void_kill_nodes(child, result)


static func _all_collision_shapes_disabled(node: Node) -> bool:
	for child in node.get_children():
		if child is CollisionShape3D and not (child as CollisionShape3D).disabled:
			return false
		if not _all_collision_shapes_disabled(child):
			return false
	return true


static func _validate_no_scene_cameras(root: Node, result: Dictionary) -> void:
	_find_active_cameras(root, result)


static func _find_active_cameras(node: Node, result: Dictionary) -> void:
	if node is Camera3D:
		var camera: Camera3D = node as Camera3D
		if camera.current:
			_add_error(result, "Scene camera '%s' must not hijack current camera." % camera.get_path())
	for child in node.get_children():
		_find_active_cameras(child, result)


static func _empty_result() -> Dictionary:
	return {"ok": false, "errors": [], "warnings": [], "summary": "", "details": {}}


static func _finalize_result(result: Dictionary) -> Dictionary:
	result["ok"] = result["errors"].is_empty()
	result["summary"] = (
		"Validation passed with %d warning(s)."
		if result["ok"]
		else "Validation failed with %d error(s)."
	) % (result["warnings"].size() if result["ok"] else result["errors"].size())
	return result


static func _add_error(result: Dictionary, message: String) -> void:
	result["errors"].append(message)


static func _add_warning(result: Dictionary, message: String) -> void:
	result["warnings"].append(message)
