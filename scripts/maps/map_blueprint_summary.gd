class_name MapBlueprintSummary
extends RefCounted

const CELL_HAZARD := MapBlueprint.CELL_HAZARD
const CELL_GAP_VISUAL := MapBlueprint.CELL_GAP_VISUAL
const CELL_VOID := MapBlueprint.CELL_VOID


static func compute_stats(blueprint: MapBlueprint) -> Dictionary:
	if blueprint == null:
		return {}

	var safe_cells: int = 0
	var hazard_cells: int = 0
	var gap_cells: int = 0
	var void_cells: int = 0
	var visual_asset_cells: int = 0

	for row_index in range(blueprint.get_row_count()):
		for column_index in range(blueprint.visual_width_tiles):
			var cell: Dictionary = blueprint.get_cell(row_index, column_index)
			var cell_type: String = str(cell.get("type", CELL_VOID))

			if blueprint.is_safe_path_cell(row_index, column_index):
				safe_cells += 1
			if cell_type == CELL_HAZARD or bool(cell.get("hazard", false)):
				hazard_cells += 1
			if cell_type == CELL_GAP_VISUAL:
				gap_cells += 1
			if cell_type == CELL_VOID:
				void_cells += 1
			if cell_type not in [CELL_VOID, CELL_GAP_VISUAL]:
				visual_asset_cells += 1

	return {
		"id": blueprint.id,
		"display_name": blueprint.display_name,
		"authoring_status": blueprint.authoring_status,
		"enabled_for_selection": blueprint.enabled_for_selection,
		"tile_size": blueprint.tile_size,
		"visual_width_tiles": blueprint.visual_width_tiles,
		"visual_length_tiles": blueprint.visual_length_tiles,
		"safe_path_width_meters": blueprint.safe_path_width_meters,
		"row_count": blueprint.get_row_count(),
		"safe_cell_count": safe_cells,
		"hazard_cell_count": hazard_cells,
		"gap_cell_count": gap_cells,
		"void_cell_count": void_cells,
		"visual_asset_cells": visual_asset_cells,
		"gameplay_plate_count": blueprint.gameplay_plates.size(),
		"hazard_zone_count": blueprint.hazard_zones.size(),
		"spawn_z": blueprint.spawn_z,
		"goal_z": blueprint.goal_z,
		"theme": blueprint.theme,
	}


static func format_text(
	stats: Dictionary,
	visual_node_count: int = -1,
	gameplay_node_count: int = -1
) -> String:
	if stats.is_empty():
		return "No blueprint loaded."

	var lines: PackedStringArray = PackedStringArray([
		"Blueprint: %s (%s)" % [stats.get("display_name", ""), stats.get("id", "")],
		"Status: %s | selectable: %s" % [
			stats.get("authoring_status", ""),
			"yes" if bool(stats.get("enabled_for_selection", false)) else "no",
		],
		"Grid: %d rows x %d cols @ %.1fm tiles"
		% [
			stats.get("row_count", 0),
			stats.get("visual_width_tiles", 0),
			float(stats.get("tile_size", 0.0)),
		],
		"Safe path width: %.1fm | spawn_z: %.1f | goal_z: %.1f"
		% [
			float(stats.get("safe_path_width_meters", 0.0)),
			float(stats.get("spawn_z", 0.0)),
			float(stats.get("goal_z", 0.0)),
		],
		"Cells: safe=%d hazard=%d gap=%d void=%d visual_cells=%d"
		% [
			stats.get("safe_cell_count", 0),
			stats.get("hazard_cell_count", 0),
			stats.get("gap_cell_count", 0),
			stats.get("void_cell_count", 0),
			stats.get("visual_asset_cells", 0),
		],
		"Gameplay: plates=%d hazard_zones=%d"
		% [
			stats.get("gameplay_plate_count", 0),
			stats.get("hazard_zone_count", 0),
		],
	])

	if visual_node_count >= 0 or gameplay_node_count >= 0:
		lines.append(
			"Generated nodes: visual=%d gameplay=%d"
			% [max(visual_node_count, 0), max(gameplay_node_count, 0)]
		)

	return "\n".join(lines)


static func print_summary(
	blueprint: MapBlueprint,
	visual_node_count: int = -1,
	gameplay_node_count: int = -1
) -> Dictionary:
	var stats: Dictionary = compute_stats(blueprint)
	print("=== Map Blueprint Summary ===")
	print(format_text(stats, visual_node_count, gameplay_node_count))
	return stats
