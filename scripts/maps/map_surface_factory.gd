class_name MapSurfaceFactory
extends RefCounted

const MapSegmentDefinitionScript := preload("res://scripts/maps/map_segment_definition.gd")
const MapSurfacePieceScript := preload("res://scripts/maps/map_surface_piece.gd")

const MIN_THICKNESS: float = 0.12


static func build_specs_for_segment(
	segment: Dictionary,
	segment_type: String,
	segment_width: float,
	segment_length: float,
	route_half_width: float
) -> Array[Dictionary]:
	var explicit: Array = segment.get("surface_pieces", [])
	if not explicit.is_empty():
		return _normalize_specs(explicit)

	return _derive_specs_from_segment(
		segment,
		segment_type,
		segment_width,
		segment_length,
		route_half_width,
	)


static func build_piece(
	spec: Dictionary,
	segment_width: float,
	segment_length: float,
	deck_top_y: float,
	center_z: float,
	segment_id: String = ""
) -> StaticBody3D:
	var shape: String = str(spec.get("shape", "deck"))
	var layer_index: int = int(spec.get("layer_index", 0))
	var deck_y_offset: float = float(spec.get("deck_y_offset", 0.0))
	var top_y: float = deck_top_y + deck_y_offset
	var length: float = segment_length * float(spec.get("length_ratio", 1.0))
	var width: float = _resolve_width(spec, segment_width)
	var x_offset: float = _resolve_x_offset(spec, segment_width)
	var z_offset: float = float(spec.get("z_offset", 0.0))

	var piece: StaticBody3D
	if shape == "ramp":
		var height_delta: float = float(spec.get("height_delta", 0.0))
		piece = MapSurfacePieceScript.create_ramp(width, length, height_delta, top_y, layer_index)
	else:
		piece = MapSurfacePieceScript.create_deck(
			Vector3(width, MIN_THICKNESS, length),
			top_y,
			layer_index,
			str(spec.get("role", "walk")),
		)

	piece.position.x += x_offset
	piece.position.z += center_z + z_offset
	piece.segment_id = segment_id
	piece.allows_edge_fall = bool(spec.get("allows_edge_fall", true))
	return piece


static func get_lowest_top_y(pieces: Array) -> float:
	var lowest: float = INF
	for piece in pieces:
		if piece == null:
			continue
		var top_y: float = MapSurfacePieceScript.get_collision_top_y(piece)
		lowest = minf(lowest, top_y)
	return lowest if lowest < INF else 0.0


static func _normalize_specs(raw_specs: Array) -> Array[Dictionary]:
	var normalized: Array[Dictionary] = []
	for raw_spec in raw_specs:
		if raw_spec is Dictionary:
			normalized.append((raw_spec as Dictionary).duplicate(true))
	return normalized


static func _derive_specs_from_segment(
	segment: Dictionary,
	segment_type: String,
	segment_width: float,
	segment_length: float,
	route_half_width: float
) -> Array[Dictionary]:
	var branch_widths: Array = segment.get("branch_widths", [])
	var branch_offsets: Array = segment.get("branch_offsets", [])
	var ratio: float = float(segment.get("safe_floor_width_ratio", 1.0))

	if not branch_widths.is_empty():
		var specs: Array[Dictionary] = []
		for index in range(branch_widths.size()):
			specs.append(
				{
					"shape": "deck",
					"width": float(branch_widths[index]) * ratio,
					"x_offset": (
						float(branch_offsets[index]) if index < branch_offsets.size() else 0.0
					),
				}
			)
		return specs

	if segment_type == MapSegmentDefinitionScript.TYPE_UPPER_DECK_GAP:
		return [
			{"shape": "deck", "width_ratio": 0.32, "x_offset_ratio": -0.34, "layer_index": 0},
			{"shape": "deck", "width_ratio": 0.32, "x_offset_ratio": 0.34, "layer_index": 0},
		]

	if segment_type == MapSegmentDefinitionScript.TYPE_LOWER_RECOVERY_DECK:
		return [
			{
				"shape": "deck",
				"width_ratio": 1.0,
				"layer_index": 1,
				"deck_y_offset": float(segment.get("lower_deck_y_offset", -3.5)),
				"role": "recovery",
			},
		]

	if segment_type in [MapSegmentDefinitionScript.TYPE_RAMP_UP, MapSegmentDefinitionScript.TYPE_RAMP_DOWN]:
		var height_delta: float = float(segment.get("height_delta", 0.0))
		return [
			{
				"shape": "ramp",
				"width_ratio": 1.0,
				"height_delta": height_delta,
				"layer_index": 0,
			},
		]

	var floor_width: float = segment_width * ratio
	if segment_type in [
		MapSegmentDefinitionScript.TYPE_GAP,
		MapSegmentDefinitionScript.TYPE_SMALL_CENTER_GAP,
		MapSegmentDefinitionScript.TYPE_BROKEN_BRIDGE_GAP,
		MapSegmentDefinitionScript.TYPE_NARROW_BRIDGE,
		MapSegmentDefinitionScript.TYPE_NARROW_NO_RAILS_BRIDGE,
		MapSegmentDefinitionScript.TYPE_SIDE_DROP,
		MapSegmentDefinitionScript.TYPE_LEFT_SIDE_DROP,
		MapSegmentDefinitionScript.TYPE_RIGHT_SIDE_DROP,
		MapSegmentDefinitionScript.TYPE_DOUBLE_SIDE_DROP,
		MapSegmentDefinitionScript.TYPE_CRACKED_EDGE_LANE,
		MapSegmentDefinitionScript.TYPE_MOVING_PLATFORM_GAP,
	]:
		floor_width = minf(floor_width, route_half_width * 2.0 - 2.0)

	var x_offset: float = 0.0
	if segment_type == MapSegmentDefinitionScript.TYPE_LEFT_SIDE_DROP:
		x_offset = segment_width * 0.15
	elif segment_type == MapSegmentDefinitionScript.TYPE_RIGHT_SIDE_DROP:
		x_offset = -segment_width * 0.15

	return [
		{
			"shape": "deck",
			"width": floor_width,
			"x_offset": x_offset,
			"layer_index": 0,
		},
	]


static func _resolve_width(spec: Dictionary, segment_width: float) -> float:
	if spec.has("width"):
		return maxf(float(spec.get("width", segment_width)), 0.5)
	if spec.has("width_ratio"):
		return maxf(segment_width * float(spec.get("width_ratio", 1.0)), 0.5)
	return maxf(segment_width, 0.5)


static func _resolve_x_offset(spec: Dictionary, segment_width: float) -> float:
	if spec.has("x_offset"):
		return float(spec.get("x_offset", 0.0))
	if spec.has("x_offset_ratio"):
		return segment_width * float(spec.get("x_offset_ratio", 0.0))
	return 0.0
