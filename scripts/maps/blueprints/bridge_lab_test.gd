class_name BridgeLabTestBlueprint
extends RefCounted

static func create() -> MapBlueprint:
	var blueprint := MapBlueprint.new()
	blueprint.id = "bridge_lab_test"
	blueprint.display_name = "Bridge Lab Test"
	blueprint.authoring_status = MapBlueprint.STATUS_LAB_ONLY
	blueprint.enabled_for_selection = false
	blueprint.tile_size = 8.0
	blueprint.visual_width_tiles = 3
	blueprint.visual_length_tiles = 12
	blueprint.safe_path_width_meters = 8.0
	blueprint.gameplay_lane_half_width = 4.0
	blueprint.spawn_z = -44.0
	blueprint.goal_z = 44.0
	blueprint.theme = "broken_bridge"
	blueprint.seed = 8802
	blueprint.rows = _build_rows()
	blueprint.gameplay_plates = [
		{"position": Vector3(0.0, 0.0, -32.0), "size": Vector3(8.0, 0.12, 14.0)},
		{"position": Vector3(0.0, 0.0, -10.0), "size": Vector3(8.0, 0.12, 14.0)},
		{"position": Vector3(0.0, 0.0, 12.0), "size": Vector3(8.0, 0.12, 14.0)},
		{"position": Vector3(0.0, 0.0, 34.0), "size": Vector3(8.0, 0.12, 14.0)},
	]
	blueprint.hazard_zones = [
		{"position": Vector3(-8.0, -1.0, -21.0), "size": Vector3(5.0, 4.0, 7.0)},
		{"position": Vector3(8.0, -1.0, -21.0), "size": Vector3(5.0, 4.0, 7.0)},
		{"position": Vector3(-8.0, -1.0, 1.0), "size": Vector3(5.0, 4.0, 7.0)},
		{"position": Vector3(8.0, -1.0, 1.0), "size": Vector3(5.0, 4.0, 7.0)},
		{"position": Vector3(-8.0, -1.0, 23.0), "size": Vector3(5.0, 4.0, 7.0)},
		{"position": Vector3(8.0, -1.0, 23.0), "size": Vector3(5.0, 4.0, 7.0)},
	]
	blueprint.dressing_rules = {
		"void_water": true,
		"center_guides": true,
		"narrow_bridge": true,
	}
	blueprint.validation_requirements = {"requires_safe_route": true}
	return blueprint


static func _build_rows() -> Array[Dictionary]:
	var pattern: Array[Array] = [
		[MapBlueprint.CELL_BROKEN_EDGE, MapBlueprint.CELL_SPAWN, MapBlueprint.CELL_BROKEN_EDGE],
		[MapBlueprint.CELL_BARRIER, MapBlueprint.CELL_SAFE_ROAD, MapBlueprint.CELL_BARRIER],
		[MapBlueprint.CELL_CRACK_ROAD, MapBlueprint.CELL_SAFE_ROAD, MapBlueprint.CELL_CRACK_ROAD],
		[MapBlueprint.CELL_GAP_VISUAL, MapBlueprint.CELL_CRACK_ROAD, MapBlueprint.CELL_GAP_VISUAL],
		[MapBlueprint.CELL_VOID, MapBlueprint.CELL_SAFE_ROAD, MapBlueprint.CELL_VOID],
		[MapBlueprint.CELL_CONE, MapBlueprint.CELL_SAFE_ROAD, MapBlueprint.CELL_CONE],
		[MapBlueprint.CELL_GAP_VISUAL, MapBlueprint.CELL_CRACK_ROAD, MapBlueprint.CELL_GAP_VISUAL],
		[MapBlueprint.CELL_DEBRIS, MapBlueprint.CELL_SAFE_ROAD, MapBlueprint.CELL_CONTAINER],
		[MapBlueprint.CELL_BARRIER, MapBlueprint.CELL_SAFE_ROAD, MapBlueprint.CELL_BARRIER],
		[MapBlueprint.CELL_GAP_VISUAL, MapBlueprint.CELL_CRACK_ROAD, MapBlueprint.CELL_GAP_VISUAL],
		[MapBlueprint.CELL_BROKEN_EDGE, MapBlueprint.CELL_SAFE_ROAD, MapBlueprint.CELL_BROKEN_EDGE],
		[MapBlueprint.CELL_BARRIER, MapBlueprint.CELL_GOAL, MapBlueprint.CELL_BARRIER],
	]

	var rows: Array[Dictionary] = []
	for row_index in range(pattern.size()):
		var cells: Array = []
		for column_index in range(pattern[row_index].size()):
			var cell_type: String = str(pattern[row_index][column_index])
			var cell := {
				"type": cell_type,
				"safe_path": _is_safe_cell_type(cell_type),
				"no_collision": true,
			}
			if cell_type == MapBlueprint.CELL_CRACK_ROAD and column_index == 1:
				cell["safe_path"] = true
			if cell_type in [MapBlueprint.CELL_DEBRIS, MapBlueprint.CELL_CONTAINER]:
				cell["offset_x"] = 0.8 if column_index == 0 else -0.8
			if cell_type == MapBlueprint.CELL_GOAL:
				cell["asset_id"] = "street_crack1"
			cells.append(cell)
		rows.append({"z_index": row_index, "cells": cells})
	return rows


static func _is_safe_cell_type(cell_type: String) -> bool:
	return cell_type in [
		MapBlueprint.CELL_SAFE_ROAD,
		MapBlueprint.CELL_SPAWN,
		MapBlueprint.CELL_GOAL,
	]
