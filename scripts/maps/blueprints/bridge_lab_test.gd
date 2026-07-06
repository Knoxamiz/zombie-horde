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
		"void_width_scale": 9.0,
		"void_depth": -7.5,
	}
	blueprint.validation_requirements = {"requires_safe_route": true}
	return blueprint


static func _build_rows() -> Array[Dictionary]:
	# Narrow 3-column deck: center lane stays clean, damage clusters at gap rows.
	var pattern: Array[Array] = [
		[MapBlueprint.CELL_BROKEN_EDGE, MapBlueprint.CELL_SPAWN, MapBlueprint.CELL_BROKEN_EDGE],
		[MapBlueprint.CELL_LEFT_RAIL, MapBlueprint.CELL_SAFE_ROAD, MapBlueprint.CELL_RIGHT_RAIL],
		[MapBlueprint.CELL_BARRIER, MapBlueprint.CELL_SAFE_ROAD, MapBlueprint.CELL_BARRIER],
		[MapBlueprint.CELL_GAP_VISUAL, MapBlueprint.CELL_CRACK_ROAD, MapBlueprint.CELL_GAP_VISUAL],
		[MapBlueprint.CELL_VOID, MapBlueprint.CELL_SAFE_ROAD, MapBlueprint.CELL_VOID],
		[MapBlueprint.CELL_CONE, MapBlueprint.CELL_SAFE_ROAD, MapBlueprint.CELL_CONE],
		[MapBlueprint.CELL_GAP_VISUAL, MapBlueprint.CELL_CRACK_ROAD, MapBlueprint.CELL_GAP_VISUAL],
		[MapBlueprint.CELL_DEBRIS, MapBlueprint.CELL_SAFE_ROAD, MapBlueprint.CELL_LIGHT],
		[MapBlueprint.CELL_LEFT_RAIL, MapBlueprint.CELL_SAFE_ROAD, MapBlueprint.CELL_RIGHT_RAIL],
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
			_apply_cell_art(cell, row_index, column_index)
			cells.append(cell)
		rows.append({"z_index": row_index, "cells": cells})
	return rows


static func _apply_cell_art(cell: Dictionary, row_index: int, column_index: int) -> void:
	var cell_type: String = str(cell.get("type", ""))
	var is_left: bool = column_index == 0
	var is_center: bool = column_index == 1
	var is_right: bool = column_index == 2
	var outward_x: float = -1.0 if is_left else 1.0 if is_right else 0.0

	match cell_type:
		MapBlueprint.CELL_SPAWN:
			cell["asset_id"] = "street_straight"
		MapBlueprint.CELL_GOAL:
			cell["asset_id"] = "street_crack1"
			cell["offset_z"] = 0.15
		MapBlueprint.CELL_SAFE_ROAD:
			cell["asset_id"] = "street_straight"
			if is_center:
				cell["scale"] = 0.98
		MapBlueprint.CELL_CRACK_ROAD:
			if is_center:
				cell["asset_id"] = "street_crack1" if row_index == 3 else "street_crack2"
				cell["offset_y"] = -0.04
				cell["safe_path"] = true
			elif is_left:
				cell["asset_id"] = "street_crack2"
				cell["offset_x"] = outward_x * 1.8
				cell["offset_y"] = -0.35
				cell["rotation"] = 18.0
				cell["scale"] = 0.82
			else:
				cell["asset_id"] = "street_crack1"
				cell["offset_x"] = outward_x * 1.8
				cell["offset_y"] = -0.35
				cell["rotation"] = -18.0
				cell["scale"] = 0.82
		MapBlueprint.CELL_BROKEN_EDGE:
			cell["asset_id"] = "street_crack2" if row_index < 6 else "street_crack1"
			cell["offset_x"] = outward_x * 2.2
			cell["offset_y"] = -0.42
			cell["offset_z"] = 0.25 if is_left else -0.2
			cell["rotation"] = 24.0 * outward_x
			cell["scale"] = 0.84
		MapBlueprint.CELL_LEFT_RAIL:
			cell["asset_id"] = "traffic_barrier_2"
			cell["offset_x"] = -0.45
			cell["offset_y"] = 0.02
			cell["rotation"] = 0.0
			cell["scale"] = 0.95
		MapBlueprint.CELL_RIGHT_RAIL:
			cell["asset_id"] = "traffic_barrier_2"
			cell["offset_x"] = 0.45
			cell["offset_y"] = 0.02
			cell["rotation"] = 180.0
			cell["scale"] = 0.95
		MapBlueprint.CELL_BARRIER:
			cell["asset_id"] = "traffic_barrier_1" if row_index < 8 else "plastic_barrier"
			cell["face_inward"] = true
			cell["offset_x"] = outward_x * 0.75
			cell["offset_z"] = 0.35 if is_left else -0.25
			cell["scale"] = 0.92
		MapBlueprint.CELL_CONE:
			cell["asset_id"] = "traffic_cone_1" if is_left else "traffic_cone_2"
			cell["face_inward"] = true
			cell["offset_x"] = outward_x * 0.95
			cell["offset_z"] = 0.4 if is_left else -0.35
			cell["scale"] = 1.05
		MapBlueprint.CELL_DEBRIS:
			cell["asset_id"] = "pallet_broken" if row_index % 2 == 0 else "pipes"
			cell["offset_x"] = -2.55
			cell["offset_y"] = -0.18
			cell["offset_z"] = 0.6
			cell["rotation"] = 38.0
			cell["scale"] = 1.1
		MapBlueprint.CELL_LIGHT:
			cell["asset_id"] = "street_light"
			cell["offset_x"] = 2.35
			cell["offset_y"] = 0.0
			cell["offset_z"] = -0.5
			cell["rotation"] = -12.0
			cell["scale"] = 0.9
		MapBlueprint.CELL_CONTAINER:
			cell["asset_id"] = "container_red"
			cell["offset_x"] = 2.7
			cell["offset_y"] = 0.0
			cell["offset_z"] = 0.35
			cell["rotation"] = 88.0
			cell["scale"] = 0.82


static func _is_safe_cell_type(cell_type: String) -> bool:
	return cell_type in [
		MapBlueprint.CELL_SAFE_ROAD,
		MapBlueprint.CELL_SPAWN,
		MapBlueprint.CELL_GOAL,
	]
