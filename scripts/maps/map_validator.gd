class_name MapValidator
extends RefCounted

const CELL_VOID := MapBlueprint.CELL_VOID
const CELL_SAFE_ROAD := MapBlueprint.CELL_SAFE_ROAD
const CELL_SPAWN := MapBlueprint.CELL_SPAWN
const CELL_GOAL := MapBlueprint.CELL_GOAL


static func validate_blueprint(blueprint: MapBlueprint) -> Dictionary:
	var result: Dictionary = _empty_result()
	if blueprint == null:
		_add_error(result, "Blueprint is null.")
		return result

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

	result["ok"] = result["errors"].is_empty()
	result["summary"] = (
		"Validation passed with %d warning(s)."
		if result["ok"]
		else "Validation failed with %d error(s)."
	) % (result["warnings"].size() if result["ok"] else result["errors"].size())
	return result


static func validate_generated_scene(root: Node3D, blueprint: MapBlueprint) -> Dictionary:
	var result: Dictionary = validate_blueprint(blueprint)
	if root == null:
		_add_error(result, "Generated scene root is null.")
		result["ok"] = false
		return result

	var visual_layer: Node = root.get_node_or_null("VisualLayer")
	var gameplay_layer: Node = root.get_node_or_null("GameplayLayer")
	if visual_layer == null:
		_add_error(result, "VisualLayer is missing on generated map root.")
	if gameplay_layer == null:
		_add_error(result, "GameplayLayer is missing on generated map root.")
	if gameplay_layer != null:
		if gameplay_layer.get_node_or_null("SafeFloor") == null:
			_add_error(result, "GameplayLayer/SafeFloor is missing.")
		if blueprint.rows.size() > 0 and gameplay_layer.get_node_or_null("SpawnZone") == null:
			_add_warning(result, "SpawnZone was not generated.")
		if blueprint.rows.size() > 0 and gameplay_layer.get_node_or_null("GoalZone") == null:
			_add_warning(result, "GoalZone was not generated.")
		if not blueprint.hazard_zones.is_empty() and gameplay_layer.get_node_or_null("HazardZones") == null:
			_add_warning(result, "HazardZones container is missing.")

	result["ok"] = result["errors"].is_empty()
	return result


static func print_validation_report(result: Dictionary) -> void:
	print("=== Map Validation Report ===")
	print(result.get("summary", "No summary"))
	for warning in result.get("warnings", []):
		print("WARNING: %s" % warning)
	for error in result.get("errors", []):
		print("ERROR: %s" % error)


static func _validate_assets(blueprint: MapBlueprint, result: Dictionary) -> void:
	for row_index in range(blueprint.get_row_count()):
		var cells: Array = blueprint.get_cells_for_row(row_index)
		for column_index in range(cells.size()):
			var cell: Dictionary = blueprint.get_cell(row_index, column_index)
			var asset_id: String = str(cell.get("asset_id", ""))
			if asset_id.is_empty():
				continue
			if not MapAssetRegistry.has_asset(asset_id):
				_add_warning(result, "Unknown asset_id '%s' at row %d col %d." % [asset_id, row_index, column_index])


static func _validate_safe_route(blueprint: MapBlueprint, result: Dictionary) -> void:
	if blueprint.get_row_count() <= 0:
		return

	var start_rows: Array[int] = []
	var goal_rows: Array[int] = []
	for row_index in range(blueprint.get_row_count()):
		for column_index in range(blueprint.visual_width_tiles):
			var cell_type: String = blueprint.get_cell_type(row_index, column_index)
			if blueprint.is_safe_path_cell(row_index, column_index) or cell_type in [CELL_SAFE_ROAD, CELL_SPAWN, CELL_GOAL]:
				if row_index == 0 or cell_type == CELL_SPAWN:
					start_rows.append(row_index)
				if row_index == blueprint.get_row_count() - 1 or cell_type == CELL_GOAL:
					goal_rows.append(row_index)

	if start_rows.is_empty():
		_add_error(result, "No safe-path start row found.")
		return
	if goal_rows.is_empty():
		_add_error(result, "No safe-path goal row found.")
		return

	var visited: Dictionary = {}
	var queue: Array[Vector2i] = []
	for row_index in start_rows:
		for column_index in range(blueprint.visual_width_tiles):
			if not blueprint.is_safe_path_cell(row_index, column_index):
				continue
			var key := Vector2i(row_index, column_index)
			if visited.has(key):
				continue
			visited[key] = true
			queue.append(key)

	var directions: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var reached_goal: bool = false
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		if current.x == blueprint.get_row_count() - 1:
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
		_add_error(result, "Safe route does not connect first row to last row.")


static func _validate_hazards(blueprint: MapBlueprint, result: Dictionary) -> void:
	for row_index in range(blueprint.get_row_count()):
		for column_index in range(blueprint.visual_width_tiles):
			if not blueprint.is_safe_path_cell(row_index, column_index):
				continue
			var cell: Dictionary = blueprint.get_cell(row_index, column_index)
			if bool(cell.get("hazard", false)):
				_add_error(result, "Hazard cell blocks safe route at row %d col %d." % [row_index, column_index])

	var safe_cells: int = 0
	for row_index in range(blueprint.get_row_count()):
		for column_index in range(blueprint.visual_width_tiles):
			if blueprint.is_safe_path_cell(row_index, column_index):
				safe_cells += 1
	if safe_cells <= 0:
		_add_error(result, "No safe-path cells exist.")


static func _empty_result() -> Dictionary:
	return {"ok": false, "errors": [], "warnings": [], "summary": ""}


static func _add_error(result: Dictionary, message: String) -> void:
	result["errors"].append(message)


static func _add_warning(result: Dictionary, message: String) -> void:
	result["warnings"].append(message)
