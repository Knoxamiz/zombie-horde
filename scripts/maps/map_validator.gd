class_name MapValidator
extends RefCounted

const CELL_VOID := MapBlueprint.CELL_VOID
const CELL_SAFE_ROAD := MapBlueprint.CELL_SAFE_ROAD
const CELL_SPAWN := MapBlueprint.CELL_SPAWN
const CELL_GOAL := MapBlueprint.CELL_GOAL
const CELL_HAZARD := MapBlueprint.CELL_HAZARD


static func validate_blueprint(blueprint: MapBlueprint) -> Dictionary:
	var result: Dictionary = _empty_result()
	if blueprint == null:
		_add_error(result, "Blueprint is null.")
		return _finalize_result(result)

	if blueprint.id.strip_edges().is_empty():
		_add_error(result, "Blueprint id is required.")
	if blueprint.display_name.strip_edges().is_empty():
		_add_error(result, "Blueprint display_name is required.")
	if blueprint.tile_size <= 0.0:
		_add_error(result, "tile_size must be > 0.")
	if blueprint.spawn_z >= blueprint.goal_z:
		_add_error(result, "spawn_z must be less than goal_z.")
	if blueprint.safe_path_width_meters <= 0.0:
		_add_error(result, "safe_path_width_meters must be > 0.")
	if blueprint.visual_length_tiles <= 0:
		_add_error(result, "visual_length_tiles must be > 0.")
	if blueprint.visual_width_tiles <= 0:
		_add_error(result, "visual_width_tiles must be > 0.")
	if blueprint.rows.is_empty():
		_add_error(result, "Blueprint must contain at least one row.")

	if blueprint.enabled_for_selection and blueprint.authoring_status != MapBlueprint.STATUS_PLAYABLE:
		_add_error(
			result,
			"enabled_for_selection requires authoring_status=playable (got %s)."
			% blueprint.authoring_status
		)

	_validate_assets(blueprint, result)
	_validate_safe_route(blueprint, result)
	_validate_hazards(blueprint, result)
	_validate_hazard_zone_overlap(blueprint, result)

	return _finalize_result(result)


static func validate_generated_scene(root: Node3D, blueprint: MapBlueprint) -> Dictionary:
	var result: Dictionary = validate_blueprint(blueprint)
	if root == null:
		_add_error(result, "Generated scene root is null.")
		return _finalize_result(result)

	var visual_layer: Node = root.get_node_or_null("VisualLayer")
	var gameplay_layer: Node = root.get_node_or_null("GameplayLayer")
	var debug_layer: Node = root.get_node_or_null("DebugLayer")
	if visual_layer == null:
		_add_error(result, "VisualLayer is missing on generated map root.")
	if gameplay_layer == null:
		_add_error(result, "GameplayLayer is missing on generated map root.")
	if debug_layer == null:
		_add_warning(result, "DebugLayer is missing on generated map root.")
	if gameplay_layer != null:
		if gameplay_layer.get_node_or_null("SafeFloor") == null:
			_add_error(result, "GameplayLayer/SafeFloor is missing.")
		if blueprint.rows.size() > 0 and gameplay_layer.get_node_or_null("SpawnZone") == null:
			_add_warning(result, "SpawnZone was not generated.")
		if blueprint.rows.size() > 0 and gameplay_layer.get_node_or_null("GoalZone") == null:
			_add_warning(result, "GoalZone was not generated.")
		if not blueprint.hazard_zones.is_empty() and gameplay_layer.get_node_or_null("HazardZones") == null:
			_add_warning(result, "HazardZones container is missing.")

	return _finalize_result(result)


static func print_validation_report(result: Dictionary) -> void:
	print("=== Map Validation Report ===")
	if bool(result.get("ok", false)):
		print("RESULT: validation PASSED")
	else:
		print("RESULT: validation FAILED")

	print(result.get("summary", "No summary"))

	var details: Dictionary = result.get("details", {})
	if not details.is_empty():
		if details.has("safe_path_break"):
			var break_info: Dictionary = details["safe_path_break"]
			print(
				"Safe path break at row %d col %d (%s)."
				% [
					int(break_info.get("row", -1)),
					int(break_info.get("column", -1)),
					str(break_info.get("reason", "")),
				]
			)
		for overlap in details.get("hazard_overlaps", []):
			print("Hazard overlap: %s" % overlap)
		for missing in details.get("missing_assets", []):
			print("Missing asset: %s" % missing)

	for warning in result.get("warnings", []):
		print("WARNING: %s" % warning)
	for error in result.get("errors", []):
		print("ERROR: %s" % error)


static func _validate_assets(blueprint: MapBlueprint, result: Dictionary) -> void:
	var missing_assets: Array[String] = []
	for row_index in range(blueprint.get_row_count()):
		var cells: Array = blueprint.get_cells_for_row(row_index)
		for column_index in range(cells.size()):
			var cell: Dictionary = blueprint.get_cell(row_index, column_index)
			var asset_id: String = str(cell.get("asset_id", ""))
			if asset_id.is_empty():
				asset_id = _default_asset_for_cell(str(cell.get("type", CELL_VOID)))
			if asset_id.is_empty():
				continue
			if not MapAssetRegistry.has_asset(asset_id):
				var message := "Missing asset '%s' at row %d col %d." % [asset_id, row_index, column_index]
				missing_assets.append(message)
				_add_error(result, message)

	if not missing_assets.is_empty():
		result["details"]["missing_assets"] = missing_assets


static func _validate_safe_route(blueprint: MapBlueprint, result: Dictionary) -> void:
	if blueprint.get_row_count() <= 0:
		return

	var safe_cells: int = 0
	for row_index in range(blueprint.get_row_count()):
		for column_index in range(blueprint.visual_width_tiles):
			if blueprint.is_safe_path_cell(row_index, column_index):
				safe_cells += 1
	if safe_cells <= 0:
		_add_error(result, "No safe-path cells exist.")
		return

	var center_col: int = blueprint.get_center_column_index()
	var spawn_row: int = -1
	var goal_row: int = -1
	for row_index in range(blueprint.get_row_count()):
		var cell_type: String = blueprint.get_cell_type(row_index, center_col)
		if cell_type == CELL_SPAWN:
			spawn_row = row_index
		if cell_type == CELL_GOAL:
			goal_row = row_index

	if spawn_row < 0:
		for row_index in range(blueprint.get_row_count()):
			if blueprint.is_safe_path_cell(row_index, center_col):
				spawn_row = row_index
				break
	if goal_row < 0:
		for row_index in range(blueprint.get_row_count() - 1, -1, -1):
			if blueprint.is_safe_path_cell(row_index, center_col):
				goal_row = row_index
				break

	if spawn_row < 0:
		_add_error(result, "No safe-path start row found.")
		return
	if goal_row < 0:
		_add_error(result, "No safe-path goal row found.")
		return

	for row_index in range(spawn_row, goal_row + 1):
		if not blueprint.is_safe_path_cell(row_index, center_col):
			var reason := "center safe route missing cell"
			_add_error(
				result,
				"Safe route breaks at row %d col %d (%s)." % [row_index, center_col, reason]
			)
			result["details"]["safe_path_break"] = {
				"row": row_index,
				"column": center_col,
				"reason": reason,
			}
			return

	var visited: Dictionary = {}
	var queue: Array[Vector2i] = []
	for column_index in range(blueprint.visual_width_tiles):
		if not blueprint.is_safe_path_cell(spawn_row, column_index):
			continue
		var key := Vector2i(spawn_row, column_index)
		visited[key] = true
		queue.append(key)

	var directions: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var reached_goal: bool = false
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		if current.x == goal_row:
			reached_goal = true
			break
		for direction in directions:
			var next := current + direction
			if next.x < 0 or next.x >= blueprint.get_row_count():
				continue
			if next.y < 0 or next.y >= blueprint.visual_width_tiles:
				continue
			if not blueprint.is_safe_path_cell(next.x, next.y):
				continue
			var next_key := Vector2i(next.x, next.y)
			if visited.has(next_key):
				continue
			visited[next_key] = true
			queue.append(next_key)

	if not reached_goal:
		_add_error(result, "Safe route does not connect spawn row to goal row.")
		for row_index in range(blueprint.get_row_count()):
			for column_index in range(blueprint.visual_width_tiles):
				if not blueprint.is_safe_path_cell(row_index, column_index):
					continue
				var key := Vector2i(row_index, column_index)
				if visited.has(key):
					continue
				result["details"]["safe_path_break"] = {
					"row": row_index,
					"column": column_index,
					"reason": "unreachable safe cell",
				}
				_add_error(
					result,
					"Safe route breaks at row %d col %d (unreachable safe cell)."
					% [row_index, column_index]
				)
				return


static func _validate_hazards(blueprint: MapBlueprint, result: Dictionary) -> void:
	for row_index in range(blueprint.get_row_count()):
		for column_index in range(blueprint.visual_width_tiles):
			if not blueprint.is_safe_path_cell(row_index, column_index):
				continue
			var cell: Dictionary = blueprint.get_cell(row_index, column_index)
			var cell_type: String = str(cell.get("type", CELL_VOID))
			if bool(cell.get("hazard", false)) or cell_type == CELL_HAZARD:
				_add_error(result, "Hazard cell blocks safe route at row %d col %d." % [row_index, column_index])


static func _validate_hazard_zone_overlap(blueprint: MapBlueprint, result: Dictionary) -> void:
	var overlaps: Array[String] = []
	var safe_half_width: float = blueprint.safe_path_width_meters * 0.5

	for hazard_index in range(blueprint.hazard_zones.size()):
		var hazard: Dictionary = blueprint.hazard_zones[hazard_index]
		var position: Vector3 = hazard.get("position", Vector3.ZERO)
		var size: Vector3 = hazard.get("size", Vector3(8, 4, 8))
		var min_x: float = position.x - size.x * 0.5
		var max_x: float = position.x + size.x * 0.5

		if min_x >= safe_half_width or max_x <= -safe_half_width:
			continue

		var blocks_full_route: bool = min_x <= -safe_half_width * 0.85 and max_x >= safe_half_width * 0.85
		if blocks_full_route:
			var message := (
				"Hazard zone %d at (%.1f, %.1f, %.1f) overlaps the full safe route width."
				% [hazard_index, position.x, position.y, position.z]
			)
			overlaps.append(message)
			_add_error(result, message)

	if not overlaps.is_empty():
		result["details"]["hazard_overlaps"] = overlaps


static func _default_asset_for_cell(cell_type: String) -> String:
	match cell_type:
		MapBlueprint.CELL_SAFE_ROAD, MapBlueprint.CELL_ROAD, MapBlueprint.CELL_SPAWN, MapBlueprint.CELL_GOAL:
			return "street_straight"
		MapBlueprint.CELL_CRACK_ROAD:
			return "street_crack1"
		MapBlueprint.CELL_BROKEN_EDGE:
			return "street_crack2"
		MapBlueprint.CELL_BARRIER:
			return "plastic_barrier"
		MapBlueprint.CELL_CONE:
			return "traffic_cone_1"
		MapBlueprint.CELL_LEFT_RAIL, MapBlueprint.CELL_RIGHT_RAIL:
			return "traffic_barrier_1"
		MapBlueprint.CELL_LIGHT:
			return "street_light"
		MapBlueprint.CELL_DEBRIS:
			return "pallet_broken"
		MapBlueprint.CELL_CONTAINER:
			return "container_red"
		_:
			return ""


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
