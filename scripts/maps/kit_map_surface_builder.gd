class_name KitMapSurfaceBuilder
extends RefCounted

## Builds authoritative MapSurfacePiece collision for hazard-kit elevation routes.

const MapSurfacePieceScript := preload("res://scripts/maps/map_surface_piece.gd")

## Narrow plate ratio for broken-bridge gap crossings (matches phase2 safe_floor ~40-45%).
const DEFAULT_GAP_CROSSING_WIDTH_RATIO: float = 0.45


static func build_surfaces(
	parent: Node3D,
	surface_pieces: Array,
	default_width: float
) -> Node3D:
	var surfaces := Node3D.new()
	surfaces.name = "KitSurfaces"
	parent.add_child(surfaces)

	for raw_spec in surface_pieces:
		if raw_spec is not Dictionary:
			continue
		var spec: Dictionary = raw_spec
		var z0: float = float(spec.get("z0", 0.0))
		var z1: float = float(spec.get("z1", z0))
		if z1 <= z0:
			continue
		var length: float = z1 - z0
		var center_z: float = (z0 + z1) * 0.5
		var width: float = float(spec.get("width", default_width))
		var shape: String = str(spec.get("shape", "deck"))

		var piece: MapSurfacePiece
		if shape == "ramp":
			var start_y: float = float(spec.get("start_y", 0.0))
			var height_delta: float = float(spec.get("height_delta", 0.0))
			piece = MapSurfacePieceScript.create_ramp(width, length, height_delta, start_y)
		else:
			var top_y: float = float(spec.get("top_y", 0.0))
			piece = MapSurfacePieceScript.create_deck(
				Vector3(width, MapSurfacePieceScript.MIN_THICKNESS, length),
				top_y
			)

		piece.position.z = center_z
		surfaces.add_child(piece)

	return surfaces


static func get_top_y_at_z(surface_pieces: Array, z: float, fallback: float = 0.0) -> float:
	var best_y: float = fallback
	var found: bool = false
	for raw_spec in surface_pieces:
		if raw_spec is not Dictionary:
			continue
		var spec: Dictionary = raw_spec
		var z0: float = float(spec.get("z0", 0.0))
		var z1: float = float(spec.get("z1", z0))
		if z < z0 or z > z1:
			continue
		var shape: String = str(spec.get("shape", "deck"))
		if shape == "ramp":
			var start_y: float = float(spec.get("start_y", 0.0))
			var height_delta: float = float(spec.get("height_delta", 0.0))
			var t: float = 0.0 if z1 <= z0 else (z - z0) / (z1 - z0)
			best_y = start_y + height_delta * t
		else:
			best_y = float(spec.get("top_y", 0.0))
		found = true
	return best_y if found else fallback


static func get_lowest_top_y(surface_pieces: Array, fallback: float = 0.0) -> float:
	var lowest: float = INF
	for raw_spec in surface_pieces:
		if raw_spec is not Dictionary:
			continue
		var spec: Dictionary = raw_spec
		var shape: String = str(spec.get("shape", "deck"))
		if shape == "ramp":
			var start_y: float = float(spec.get("start_y", 0.0))
			var height_delta: float = float(spec.get("height_delta", 0.0))
			lowest = minf(lowest, minf(start_y, start_y + height_delta))
		else:
			lowest = minf(lowest, float(spec.get("top_y", 0.0)))
	return lowest if lowest < INF else fallback


static func get_gap_crossing_top_y(surface_pieces: Array, z0: float, z1: float, fallback: float = 0.0) -> float:
	var approach_y: float = get_top_y_at_z(surface_pieces, z0 - 0.05, fallback)
	var exit_y: float = get_top_y_at_z(surface_pieces, z1 + 0.05, fallback)
	if abs(approach_y - exit_y) > 0.02:
		return maxf(approach_y, exit_y)
	return approach_y


static func gap_crossing_half_width(path_half_width: float, width_ratio: float = DEFAULT_GAP_CROSSING_WIDTH_RATIO) -> float:
	return maxf(path_half_width * width_ratio, 1.35)


static func build_elevation_zones_from_pieces(surface_pieces: Array) -> Array[Dictionary]:
	var zones: Array[Dictionary] = []
	for raw_spec in surface_pieces:
		if raw_spec is not Dictionary:
			continue
		var spec: Dictionary = raw_spec
		var z0: float = float(spec.get("z0", 0.0))
		var z1: float = float(spec.get("z1", z0))
		if z1 <= z0:
			continue
		var shape: String = str(spec.get("shape", "deck"))
		if shape == "ramp":
			var start_y: float = float(spec.get("start_y", 0.0))
			var height_delta: float = float(spec.get("height_delta", 0.0))
			zones.append(
				{
					"z0": z0,
					"z1": z1,
					"is_ramp": true,
					"start_y": start_y,
					"end_y": start_y + height_delta,
				}
			)
		else:
			zones.append({"z0": z0, "z1": z1, "y": float(spec.get("top_y", 0.0))})
	return zones


static func collect_ramp_visual_specs(surface_pieces: Array) -> Array[Dictionary]:
	var ramps: Array[Dictionary] = []
	for raw_spec in surface_pieces:
		if raw_spec is not Dictionary:
			continue
		var spec: Dictionary = raw_spec
		if str(spec.get("shape", "deck")) == "ramp":
			ramps.append(spec.duplicate(true))
	return ramps


static func build_gap_crossings(
	surfaces: Node3D,
	gaps: Array,
	path_half_width: float,
	surface_pieces: Array,
	visual_width_ratio: float = DEFAULT_GAP_CROSSING_WIDTH_RATIO,
	collision_width_ratio: float = -1.0
) -> void:
	var resolved_collision_ratio: float = (
		visual_width_ratio if collision_width_ratio < 0.0 else collision_width_ratio
	)
	var crossing_half_width: float = gap_crossing_half_width(path_half_width, resolved_collision_ratio)
	for raw_gap in gaps:
		if raw_gap is not Dictionary:
			continue
		var gap: Dictionary = raw_gap
		var z0: float = float(gap.get("z0", 0.0))
		var z1: float = float(gap.get("z1", z0))
		if z1 <= z0:
			continue
		var length: float = z1 - z0
		var center_z: float = (z0 + z1) * 0.5
		var top_y: float = get_gap_crossing_top_y(surface_pieces, z0, z1, 0.0)
		var piece: MapSurfacePiece = MapSurfacePieceScript.create_deck(
			Vector3(crossing_half_width * 2.0, MapSurfacePieceScript.MIN_THICKNESS, length),
			top_y
		)
		piece.segment_id = "gap_crossing"
		piece.position.z = center_z
		surfaces.add_child(piece)
