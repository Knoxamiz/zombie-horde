class_name BridgeLabTestBlueprint
extends RefCounted

const _INNER_WING_X: float = 2.65
const _PAD_WING_X: float = 3.15
const _GAP_LIP_X: float = 4.35
const _EDGE_RAIL_X: float = 5.75
const _GUIDE_CONE_X: float = 2.95
const _VOID_PROP_X: float = 11.5
const _CRACK_ROWS: Array[int] = [3, 6, 9]
const _PAD_ROWS: Array[int] = [0, 1, 10, 11]
const _RAIL_ROWS: Array[int] = [1, 4, 8, 11]


static func create() -> MapBlueprint:
	var blueprint := MapBlueprint.new()
	blueprint.id = "bridge_lab_test"
	blueprint.display_name = "Bridge Lab Test"
	blueprint.authoring_status = MapBlueprint.STATUS_LAB_ONLY
	blueprint.enabled_for_selection = false
	blueprint.tile_size = 8.0
	blueprint.visual_width_tiles = 3
	blueprint.visual_length_tiles = 12
	blueprint.safe_path_width_meters = 9.0
	blueprint.gameplay_lane_half_width = 4.5
	blueprint.spawn_z = -44.0
	blueprint.goal_z = 44.0
	blueprint.theme = "broken_bridge"
	blueprint.seed = 8802
	blueprint.rows = _build_rows()
	var floor_top_y: float = BrokenBridgeTestLayout.BRIDGE_DECK_Y
	var floor_thickness: float = BrokenBridgeTestLayout.FLOOR_THICKNESS
	var bridge_length: float = abs(blueprint.goal_z - blueprint.spawn_z) + blueprint.tile_size * 3.0
	blueprint.gameplay_plates = [
		{
			"position": Vector3(
				0.0,
				BrokenBridgeTestLayout.get_safe_floor_body_y(),
				(blueprint.spawn_z + blueprint.goal_z) * 0.5
			),
			"size": Vector3(
				blueprint.safe_path_width_meters,
				floor_thickness,
				bridge_length
			),
		},
	]
	blueprint.dressing_rules = {
		"void_water": true,
		"center_guides": true,
		"narrow_bridge": true,
		"deep_void": true,
		"auto_side_void_hazards": true,
		"deck_elevation": floor_top_y,
		"river_kill": true,
		"river_kill_height": 5.0,
		"void_outer_half_width": 14.0,
		"void_kill_y": -2.5,
		"void_kill_height": 7.0,
		"void_darkness": 1.35,
		"void_width_scale": 18.0,
		"void_length_scale": 1.28,
		"void_depth": BrokenBridgeTestLayout.RIVER_VOID_Y,
	}
	blueprint.validation_requirements = {"requires_safe_route": true}
	return blueprint


static func _build_rows() -> Array[Dictionary]:
	var pattern: Array[Array] = [
		[MapBlueprint.CELL_BROKEN_EDGE, MapBlueprint.CELL_SPAWN, MapBlueprint.CELL_BROKEN_EDGE],
		[MapBlueprint.CELL_LEFT_RAIL, MapBlueprint.CELL_SAFE_ROAD, MapBlueprint.CELL_RIGHT_RAIL],
		[MapBlueprint.CELL_BROKEN_EDGE, MapBlueprint.CELL_SAFE_ROAD, MapBlueprint.CELL_BROKEN_EDGE],
		[MapBlueprint.CELL_GAP_VISUAL, MapBlueprint.CELL_CRACK_ROAD, MapBlueprint.CELL_GAP_VISUAL],
		[MapBlueprint.CELL_LEFT_RAIL, MapBlueprint.CELL_SAFE_ROAD, MapBlueprint.CELL_RIGHT_RAIL],
		[MapBlueprint.CELL_CONE, MapBlueprint.CELL_SAFE_ROAD, MapBlueprint.CELL_CONE],
		[MapBlueprint.CELL_GAP_VISUAL, MapBlueprint.CELL_CRACK_ROAD, MapBlueprint.CELL_GAP_VISUAL],
		[MapBlueprint.CELL_DEBRIS, MapBlueprint.CELL_SAFE_ROAD, MapBlueprint.CELL_DEBRIS],
		[MapBlueprint.CELL_LEFT_RAIL, MapBlueprint.CELL_SAFE_ROAD, MapBlueprint.CELL_RIGHT_RAIL],
		[MapBlueprint.CELL_GAP_VISUAL, MapBlueprint.CELL_CRACK_ROAD, MapBlueprint.CELL_GAP_VISUAL],
		[MapBlueprint.CELL_BROKEN_EDGE, MapBlueprint.CELL_SAFE_ROAD, MapBlueprint.CELL_BROKEN_EDGE],
		[MapBlueprint.CELL_LEFT_RAIL, MapBlueprint.CELL_GOAL, MapBlueprint.CELL_RIGHT_RAIL],
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
	var side_sign: float = -1.0 if is_left else 1.0 if column_index == 2 else 0.0

	match cell_type:
		MapBlueprint.CELL_SPAWN, MapBlueprint.CELL_GOAL:
			if not is_center:
				return
			cell["asset_id"] = "street_straight" if cell_type == MapBlueprint.CELL_SPAWN else "street_crack1"
			cell["scale_x"] = 1.22
			cell["scale_z"] = 1.08
			cell["scale_y"] = 1.0
			cell["offset_y"] = 0.02
		MapBlueprint.CELL_SAFE_ROAD:
			cell["asset_id"] = "street_straight"
			cell["scale_x"] = 1.18 if row_index in _PAD_ROWS else 1.14
			cell["scale_z"] = 1.06
			cell["scale_y"] = 1.0
			cell["offset_y"] = 0.01 if row_index in _PAD_ROWS else 0.0
		MapBlueprint.CELL_CRACK_ROAD:
			if not is_center:
				cell["skip_visual"] = true
				return
			cell["safe_path"] = true
			cell["asset_id"] = "street_crack1" if row_index == _CRACK_ROWS[0] else "street_crack2"
			cell["scale_x"] = 1.14
			cell["scale_z"] = 1.05
			cell["offset_y"] = -0.02
		MapBlueprint.CELL_BROKEN_EDGE:
			_style_broken_edge(cell, row_index, side_sign)
		MapBlueprint.CELL_GAP_VISUAL:
			if not is_center:
				_style_gap_lip(cell, row_index, side_sign)
		MapBlueprint.CELL_LEFT_RAIL, MapBlueprint.CELL_RIGHT_RAIL:
			cell["placement_x"] = side_sign * _EDGE_RAIL_X
			cell["asset_id"] = "traffic_barrier_1" if row_index in _RAIL_ROWS else "plastic_barrier"
			cell["scale"] = 0.88
			cell["offset_y"] = 0.05
			cell["rotation"] = 90.0 * side_sign
		MapBlueprint.CELL_BARRIER:
			cell["placement_x"] = side_sign * (_EDGE_RAIL_X - 0.4)
			cell["asset_id"] = "plastic_barrier"
			cell["face_inward"] = true
			cell["scale"] = 0.76
			cell["offset_y"] = 0.03
		MapBlueprint.CELL_CONE:
			cell["placement_x"] = side_sign * _GUIDE_CONE_X
			cell["asset_id"] = "traffic_cone_1" if is_left else "traffic_cone_2"
			cell["face_inward"] = true
			cell["scale"] = 0.86
			cell["offset_z"] = 0.2 * side_sign
		MapBlueprint.CELL_DEBRIS:
			cell["placement_x"] = side_sign * _VOID_PROP_X
			cell["asset_id"] = "pallet_broken" if is_left else "cinder_block"
			cell["scale"] = 0.68
			cell["offset_y"] = -0.42
			cell["offset_z"] = 0.6 * side_sign
			cell["rotation"] = 35.0 * side_sign


static func _style_broken_edge(cell: Dictionary, row_index: int, side_sign: float) -> void:
	if row_index in [0, 1, 10, 11]:
		cell["placement_x"] = side_sign * _PAD_WING_X
		cell["asset_id"] = "street_straight"
		cell["scale_x"] = 0.86
		cell["scale_z"] = 0.82
		cell["offset_y"] = 0.0
		return

	if row_index in [2, 8, 10]:
		cell["placement_x"] = side_sign * _INNER_WING_X
		cell["asset_id"] = "street_straight"
		cell["scale_x"] = 0.76
		cell["scale_z"] = 0.74
		cell["offset_y"] = -0.02
		return

	cell["placement_x"] = side_sign * (_INNER_WING_X + 0.35)
	cell["asset_id"] = "street_crack2"
	cell["scale"] = 0.58
	cell["offset_y"] = -0.22
	cell["offset_z"] = 0.25 * side_sign
	cell["rotation"] = 18.0 * side_sign


static func _style_gap_lip(cell: Dictionary, row_index: int, side_sign: float) -> void:
	cell["type"] = MapBlueprint.CELL_BROKEN_EDGE
	cell["placement_x"] = side_sign * _GAP_LIP_X
	cell["asset_id"] = "street_crack2" if row_index == _CRACK_ROWS[1] else "street_crack1"
	cell["scale"] = 0.46
	cell["offset_y"] = -0.52
	cell["offset_z"] = 0.4 * side_sign
	cell["rotation"] = 34.0 * side_sign


static func _is_safe_cell_type(cell_type: String) -> bool:
	return cell_type in [
		MapBlueprint.CELL_SAFE_ROAD,
		MapBlueprint.CELL_SPAWN,
		MapBlueprint.CELL_GOAL,
	]
