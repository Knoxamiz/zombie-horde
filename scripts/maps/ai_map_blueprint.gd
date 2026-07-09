class_name AIMapBlueprint
extends Resource

const MapSegmentDefinitionScript := preload("res://scripts/maps/map_segment_definition.gd")
const AIMapRouteLayoutScript := preload("res://scripts/maps/ai_map_route_layout.gd")

const STATUS_PROTOTYPE := "prototype"
const STATUS_TEST := "test"
const STATUS_VALIDATED := "validated"
const STATUS_PLAYABLE := "playable"

@export var map_id: String = ""
@export var display_name: String = ""
@export var theme: String = "prototype"
@export var deck_y: float = 0.8
@export var target_length: float = 64.0
@export var difficulty: int = 1
@export var segment_sequence: Array = []
@export var visual_theme: String = "kit_road"
@export var water_enabled: bool = false
@export var fall_enabled: bool = false
@export var moving_obstacles_enabled: bool = false
@export var obstacle_cycle_time: float = 0.0
@export var route_half_width: float = 5.0
@export var lane_half_width: float = 5.0
@export var authoring_status: String = STATUS_PROTOTYPE
@export var notes: String = ""


func get_total_route_length() -> float:
	var total: float = 0.0
	for segment_id in segment_sequence:
		var segment: Dictionary = MapSegmentDefinitionScript.get_segment(segment_id)
		if segment.is_empty():
			continue
		total += float(segment.get("length", 0.0))
	return total


func get_recommended_oob_min_y() -> float:
	var min_y: float = deck_y - 6.0 if fall_enabled else deck_y - 3.0
	for segment_id in segment_sequence:
		var segment: Dictionary = MapSegmentDefinitionScript.get_segment(segment_id)
		if segment.is_empty():
			continue
		var recommended: float = float(segment.get("recommended_oob_min_y", -999.0))
		if recommended > -900.0:
			min_y = minf(min_y, recommended)
	return min_y


func get_recommended_camera_padding() -> float:
	var padding: float = 0.0
	for segment_id in segment_sequence:
		var segment: Dictionary = MapSegmentDefinitionScript.get_segment(segment_id)
		if segment.is_empty():
			continue
		padding = maxf(padding, float(segment.get("recommended_camera_padding", 0.0)))
	return padding


func has_elevated_or_drop_segments() -> bool:
	for segment_id in segment_sequence:
		var segment: Dictionary = MapSegmentDefinitionScript.get_segment(segment_id)
		if segment.is_empty():
			continue
		var segment_type: String = str(segment.get("type", ""))
		if MapSegmentDefinitionScript.is_elevated_segment_type(segment_type):
			return true
		if MapSegmentDefinitionScript.is_fall_risk_segment_type(segment_type):
			return true
	return false


func get_route_max_half_width() -> float:
	var max_half: float = route_half_width
	for segment_id in segment_sequence:
		var segment: Dictionary = MapSegmentDefinitionScript.get_segment(segment_id)
		if segment.is_empty():
			continue
		max_half = maxf(max_half, MapSegmentDefinitionScript.get_segment_route_half_width(segment))
	return max_half


func has_split_merge_segments() -> bool:
	for segment_id in segment_sequence:
		var segment: Dictionary = MapSegmentDefinitionScript.get_segment(segment_id)
		if segment.is_empty():
			continue
		var segment_type: String = str(segment.get("type", ""))
		if MapSegmentDefinitionScript.is_route_shape_segment_type(segment_type):
			return true
	return false


func get_water_void_y() -> float:
	return deck_y - 4.0


func has_moving_obstacle_segments() -> bool:
	for segment_id in segment_sequence:
		var segment: Dictionary = MapSegmentDefinitionScript.get_segment(segment_id)
		if segment.is_empty():
			continue
		if MapSegmentDefinitionScript.is_moving_obstacle_segment_type(str(segment.get("type", ""))):
			return true
	return false


func get_effective_cycle_time(segment: Dictionary) -> float:
	if obstacle_cycle_time > 0.0:
		return obstacle_cycle_time
	return float(segment.get("recommended_cycle_time", 4.0))


func get_segment_types() -> Array[String]:
	var types: Array[String] = []
	for segment_id in segment_sequence:
		var segment: Dictionary = MapSegmentDefinitionScript.get_segment(segment_id)
		types.append(str(segment.get("type", "")))
	return types


func is_prototype_only() -> bool:
	return authoring_status in [STATUS_PROTOTYPE, STATUS_TEST]


func to_race_map_definition() -> RaceMapDefinition:
	var definition := RaceMapDefinition.new()
	AIMapRouteLayoutScript.apply_to_definition(definition, self)
	return definition


func get_route_layout() -> Dictionary:
	return AIMapRouteLayoutScript.compute_layout(self)
