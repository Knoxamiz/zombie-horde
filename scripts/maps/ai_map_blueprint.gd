class_name AIMapBlueprint
extends Resource

const MapSegmentDefinitionScript := preload("res://scripts/maps/map_segment_definition.gd")

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


func get_water_void_y() -> float:
	return deck_y - 4.0


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
	var total_length: float = get_total_route_length()
	var half_route: float = total_length * 0.5
	var spawn_z: float = -half_route - 4.0
	var goal_z: float = half_route
	var spawn_y: float = deck_y + 0.8

	definition.display_name = display_name
	definition.premium_only = true
	definition.deck_y = deck_y
	definition.spawn_origin = Vector3(0.0, spawn_y, spawn_z)
	definition.spawn_area_size = Vector2(route_half_width * 2.0, 4.0)
	definition.goal_position = Vector3(0.0, spawn_y, goal_z)
	definition.base_position = Vector3(0.0, deck_y, goal_z)
	definition.minigun_position = Vector3(0.0, deck_y, goal_z - 4.0)
	definition.lane_half_width = lane_half_width
	definition.out_of_bounds_half_width = max(lane_half_width + 6.0, route_half_width + 2.0)
	definition.out_of_bounds_min_z = spawn_z - 8.0
	definition.out_of_bounds_max_z = goal_z + 8.0
	definition.out_of_bounds_min_y = get_recommended_oob_min_y()
	definition.hazard_placement_half_width = lane_half_width
	definition.hazard_placement_min_z = spawn_z + 4.0
	definition.hazard_placement_max_z = goal_z - 4.0
	definition.obstacle_half_width = lane_half_width
	definition.obstacle_min_z = spawn_z + 4.0
	definition.obstacle_max_z = goal_z - 4.0
	definition.obstacle_lane_count = 1
	definition.powerup_placement_half_width = lane_half_width - 0.5
	definition.powerup_placement_min_z = spawn_z + 8.0
	definition.powerup_placement_max_z = goal_z - 4.0
	definition.defender_placement_half_width = lane_half_width - 0.5
	definition.defender_placement_min_z = spawn_z + 8.0
	definition.defender_placement_max_z = goal_z - 4.0
	return definition
