class_name KitMapArena
extends Node3D

## Hand-authored hazard-kit arena: unique path preset + RaceMapKit visuals/collision.

const KIT_SCRIPT := preload("res://scripts/maps/race_map_kit.gd")
const PRESETS := preload("res://scripts/maps/map_kit_layout_presets.gd")
const SURFACE_BUILDER := preload("res://scripts/maps/kit_map_surface_builder.gd")
const VisualCollisionSanitizerScript := preload("res://scripts/core/visual_collision_sanitizer.gd")

@export var layout_preset_id: String = "broken_bridge"

var _kit: RaceMapKit
var _built: bool = false


func _ready() -> void:
	ensure_built()


func ensure_built() -> void:
	if _built:
		return
	_build_from_preset(layout_preset_id)
	_built = true


func _build_from_preset(preset_id: String) -> void:
	var layout: Dictionary = PRESETS.get_preset(preset_id)
	var style: RaceMapKit.MapStyle = layout.get("style", RaceMapKit.MapStyle.LONG_ROAD)
	var segments: Array[Dictionary] = _to_segment_array(layout.get("segments", []))
	var gaps: Array[Dictionary] = _to_segment_array(layout.get("gaps", []))
	var surface_pieces: Array = layout.get("surface_pieces", [])
	var path_half_width: float = float(layout.get("path_half_width", 6.0))
	var visual_width: float = float(layout.get("visual_width", 12.0))
	var void_width: float = float(layout.get("void_width", 64.0))
	var track_length: float = float(layout.get("track_length", 192.0))
	var spawn_z: float = float(layout.get("spawn_z", -84.0))
	var goal_z: float = float(layout.get("goal_z", 84.0))
	var start_gate_z: float = float(layout.get("start_gate_z", spawn_z + 8.0))
	var finish_gate_z: float = float(layout.get("finish_gate_z", goal_z - 8.0))
	var seed: int = int(layout.get("seed", 8802))
	var road_width: float = path_half_width * 2.0
	var uses_surface_pieces: bool = not surface_pieces.is_empty()
	var gap_crossing_width_ratio: float = float(
		layout.get("gap_crossing_width_ratio", SURFACE_BUILDER.DEFAULT_GAP_CROSSING_WIDTH_RATIO)
	)

	_kit = KIT_SCRIPT.new()
	_kit.attach(self, style, seed)
	_kit.set_path_half_width(path_half_width)
	_kit.set_gap_crossing_width_ratio(gap_crossing_width_ratio)
	_kit.build_environment()
	_kit.build_water(void_width, track_length)

	if uses_surface_pieces:
		var surfaces: Node3D = SURFACE_BUILDER.build_surfaces(self, surface_pieces, road_width)
		if style == RaceMapKit.MapStyle.BROKEN_BRIDGE and not gaps.is_empty():
			SURFACE_BUILDER.build_gap_crossings(
				surfaces, gaps, path_half_width, surface_pieces, gap_crossing_width_ratio
			)
		_kit.set_elevation_zones(SURFACE_BUILDER.build_elevation_zones_from_pieces(surface_pieces))
	else:
		match style:
			RaceMapKit.MapStyle.BROKEN_BRIDGE:
				_kit.build_broken_bridge_play_surface(segments, gaps, path_half_width)
				_kit.build_bridge_fall_zones(segments, gaps, path_half_width, void_width)
			_:
				_kit.build_continuous_play_surface(road_width, spawn_z, goal_z)

	if uses_surface_pieces:
		_kit.build_ramp_visuals(SURFACE_BUILDER.collect_ramp_visual_specs(surface_pieces), road_width)
	_kit.compose_map(segments, gaps)
	_kit.build_route_context(
		spawn_z,
		goal_z,
		start_gate_z,
		path_half_width,
		segments,
		gaps,
		void_width,
		track_length,
		surface_pieces if uses_surface_pieces else [],
		gap_crossing_width_ratio,
		float(layout.get("spawn_chute_half_width", path_half_width + 0.85))
	)
	_kit.build_markers(visual_width, spawn_z, goal_z, start_gate_z, finish_gate_z)
	var visual_kit: Node = get_node_or_null("VisualKit")
	if visual_kit != null:
		VisualCollisionSanitizerScript.sanitize_subtree(visual_kit)
	print(
		"KitMapArena: built preset '%s' (%d segments, %d gaps, elevation=%s)"
		% [preset_id, segments.size(), gaps.size(), uses_surface_pieces]
	)


func _to_segment_array(raw_segments: Variant) -> Array[Dictionary]:
	var segments: Array[Dictionary] = []
	if raw_segments is Array:
		for entry in raw_segments:
			if entry is Dictionary:
				segments.append(entry)
	return segments
