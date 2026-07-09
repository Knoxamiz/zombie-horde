class_name AIMapBlueprintValidator
extends RefCounted

const MapAssetLibraryScript := preload("res://scripts/maps/map_asset_library.gd")
const MapSegmentDefinitionScript := preload("res://scripts/maps/map_segment_definition.gd")

const VOID_KILL_SCRIPT_PATH := "res://scripts/maps/bridge_void_kill_zone.gd"


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
	_validate_rail_barrier_match(blueprint, result)
	_validate_route_length(blueprint, result)
	_validate_definition_preview(blueprint, result)

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

	if definition != null:
		_validate_definition_values(definition, blueprint, result)
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
