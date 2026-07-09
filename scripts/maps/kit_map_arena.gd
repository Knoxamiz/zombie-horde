class_name KitMapArena
extends Node3D

## Hand-authored hazard-kit arena: unique path preset + RaceMapKit visuals/collision.

const KIT_SCRIPT := preload("res://scripts/maps/race_map_kit.gd")
const PRESETS := preload("res://scripts/maps/map_kit_layout_presets.gd")

@export var layout_preset_id: String = "broken_bridge"

var _kit: RaceMapKit


func _ready() -> void:
	_build_from_preset(layout_preset_id)


func _build_from_preset(preset_id: String) -> void:
	var layout: Dictionary = PRESETS.get_preset(preset_id)
	var style: RaceMapKit.MapStyle = layout.get("style", RaceMapKit.MapStyle.LONG_ROAD)
	var segments: Array[Dictionary] = _to_segment_array(layout.get("segments", []))
	var gaps: Array[Dictionary] = _to_segment_array(layout.get("gaps", []))
	var path_half_width: float = float(layout.get("path_half_width", 6.0))
	var visual_width: float = float(layout.get("visual_width", 12.0))
	var void_width: float = float(layout.get("void_width", 64.0))
	var track_length: float = float(layout.get("track_length", 192.0))
	var spawn_z: float = float(layout.get("spawn_z", -84.0))
	var goal_z: float = float(layout.get("goal_z", 84.0))
	var start_gate_z: float = float(layout.get("start_gate_z", spawn_z + 8.0))
	var finish_gate_z: float = float(layout.get("finish_gate_z", goal_z - 8.0))
	var seed: int = int(layout.get("seed", 8802))

	_kit = KIT_SCRIPT.new()
	_kit.attach(self, style, seed)
	_kit.build_environment()
	_kit.build_water(void_width, track_length)

	match style:
		RaceMapKit.MapStyle.BROKEN_BRIDGE:
			_kit.build_broken_bridge_play_surface(segments, gaps, path_half_width)
			_kit.build_bridge_fall_zones(segments, gaps, path_half_width, void_width)
		_:
			_kit.build_continuous_play_surface(path_half_width * 2.0, spawn_z, goal_z)

	_kit.compose_map(segments, gaps)
	_kit.build_markers(visual_width, spawn_z, goal_z, start_gate_z, finish_gate_z)
	print("KitMapArena: built preset '%s' (%d segments, %d gaps)" % [preset_id, segments.size(), gaps.size()])


func _to_segment_array(raw_segments: Variant) -> Array[Dictionary]:
	var segments: Array[Dictionary] = []
	if raw_segments is Array:
		for entry in raw_segments:
			if entry is Dictionary:
				segments.append(entry)
	return segments
