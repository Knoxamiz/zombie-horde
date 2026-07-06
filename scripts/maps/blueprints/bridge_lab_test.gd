class_name BridgeLabTestBlueprint
extends RefCounted

const _DECK_SHOULDER_X: float = 3.85
const _EDGE_RAIL_X: float = 5.15
const _GUIDE_CONE_X: float = 2.25
const _VOID_PROP_X: float = 10.5
const _CRACK_ROWS: Array[int] = [3, 6, 9]


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
		"deep_void": true,
		"void_width_scale": 14.0,
		"void_length_scale": 1.15,
		"void_depth": -8.0,
	}
	blueprint.validation_requirements = {"requires_safe_route": true}
	return blueprint


static func _build_rows() -> Array[Dictionary]:
	# Center column = continuous deck. Side columns are mostly open void with authored wings/rails.
	var pattern: Array[Array] = [
		[MapBlueprint.CELL_BROKEN_EDGE, MapBlueprint.CELL_SPAWN, MapBlueprint.CELL_BROKEN_EDGE],
		[MapBlueprint.CELL_VOID, MapBlueprint.CELL_SAFE_ROAD, MapBlueprint.CELL_VOID],
		[MapBlueprint.CELL_LEFT_RAIL, MapBlueprint.CELL_SAFE_ROAD, MapBlueprint.CELL_RIGHT_RAIL],
		[MapBlueprint.CELL_GAP_VISUAL, MapBlueprint.CELL_CRACK_ROAD, MapBlueprint.CELL_GAP_VISUAL],
		[MapBlueprint.CELL_VOID, MapBlueprint.CELL_SAFE_ROAD, MapBlueprint.CELL_VOID],
		[MapBlueprint.CELL_CONE, MapBlueprint.CELL_SAFE_ROAD, MapBlueprint.CELL_CONE],
		[MapBlueprint.CELL_GAP_VISUAL, MapBlueprint.CELL_CRACK_ROAD, MapBlueprint.CELL_GAP_VISUAL],
		[MapBlueprint.CELL_DEBRIS, MapBlueprint.CELL_SAFE_ROAD, MapBlueprint.CELL_VOID],
		[MapBlueprint.CELL_BROKEN_EDGE, MapBlueprint.CELL_SAFE_ROAD, MapBlueprint.CELL_BROKEN_EDGE],
		[MapBlueprint.CELL_GAP_VISUAL, MapBlueprint.CELL_CRACK_ROAD, MapBlueprint.CELL_GAP_VISUAL],
		[MapBlueprint.CELL_LEFT_RAIL, MapBlueprint.CELL_SAFE_ROAD, MapBlueprint.CELL_RIGHT_RAIL],
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
			_apply_cell_art(cell, row_index, column_index)
			cells.append(cell)
		rows.append({"z_index": row_index, "cells": cells})
	return rows


static func _apply_cell_art(cell: Dictionary, row_index: int, column_index: int) -> void:
	var cell_type: String = str(cell.get("type", ""))
	var is_left: bool = column_index == 0
	var is_center: bool = column_index == 1
	var is_right: bool = column_index == 2
	var side_sign: float = -1.0 if is_left else 1.0 if is_right else 0.0

	match cell_type:
		MapBlueprint.CELL_SPAWN, MapBlueprint.CELL_GOAL:
			cell["asset_id"] = "street_straight" if cell_type == MapBlueprint.CELL_SPAWN else "street_crack1"
			if is_center:
				cell["scale"] = 1.03
				cell["offset_y"] = 0.0
		MapBlueprint.CELL_SAFE_ROAD:
			cell["asset_id"] = "street_straight"
			cell["scale"] = 1.03
			cell["offset_y"] = 0.0
		MapBlueprint.CELL_CRACK_ROAD:
			if not is_center:
				cell["skip_visual"] = true
				return
			cell["safe_path"] = true
			cell["asset_id"] = "street_crack1" if row_index == _CRACK_ROWS[0] else "street_crack2"
			cell["scale"] = 1.02
			cell["offset_y"] = -0.03
		MapBlueprint.CELL_BROKEN_EDGE:
			cell["placement_x"] = side_sign * _DECK_SHOULDER_X
			cell["asset_id"] = "street_crack2" if row_index < 7 else "street_crack1"
			cell["scale"] = 0.48
			cell["offset_y"] = -0.28
			cell["offset_z"] = 0.35 * side_sign
			cell["rotation"] = 26.0 * side_sign
		MapBlueprint.CELL_LEFT_RAIL:
			cell["placement_x"] = -_EDGE_RAIL_X
			cell["asset_id"] = "plastic_barrier"
			cell["scale"] = 0.78
			cell["offset_y"] = 0.04
			cell["rotation"] = 90.0
		MapBlueprint.CELL_RIGHT_RAIL:
			cell["placement_x"] = _EDGE_RAIL_X
			cell["asset_id"] = "plastic_barrier"
			cell["scale"] = 0.78
			cell["offset_y"] = 0.04
			cell["rotation"] = -90.0
		MapBlueprint.CELL_BARRIER:
			cell["placement_x"] = side_sign * (_EDGE_RAIL_X - 0.35)
			cell["asset_id"] = "plastic_barrier"
			cell["face_inward"] = true
			cell["scale"] = 0.72
			cell["offset_y"] = 0.02
			cell["offset_z"] = 0.2 * side_sign
		MapBlueprint.CELL_CONE:
			cell["placement_x"] = side_sign * _GUIDE_CONE_X
			cell["asset_id"] = "traffic_cone_1" if is_left else "traffic_cone_2"
			cell["face_inward"] = true
			cell["scale"] = 0.82
			cell["offset_y"] = 0.0
			cell["offset_z"] = 0.25 * side_sign
		MapBlueprint.CELL_DEBRIS:
			cell["placement_x"] = -_VOID_PROP_X
			cell["asset_id"] = "cinder_block" if row_index % 2 == 0 else "barrel"
			cell["scale"] = 0.72
			cell["offset_y"] = -0.35
			cell["offset_z"] = 0.8
			cell["rotation"] = 42.0
		MapBlueprint.CELL_LIGHT:
			cell["placement_x"] = _VOID_PROP_X
			cell["asset_id"] = "street_light"
			cell["scale"] = 0.75
			cell["offset_y"] = -0.2
			cell["rotation"] = -8.0


static func _is_safe_cell_type(cell_type: String) -> bool:
	return cell_type in [
		MapBlueprint.CELL_SAFE_ROAD,
		MapBlueprint.CELL_SPAWN,
		MapBlueprint.CELL_GOAL,
	]
