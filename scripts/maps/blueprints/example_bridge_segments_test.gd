class_name ExampleBridgeSegmentsTestBlueprint
extends RefCounted

const AIMapBlueprintScript := preload("res://scripts/maps/ai_map_blueprint.gd")

## Minimal non-playable prototype blueprint:
## start → straight → gap → straight → finish
## Not registered in MapCatalog / settings dropdown.


static func create():
	var blueprint = AIMapBlueprintScript.new()
	blueprint.map_id = "example_bridge_segments_test"
	blueprint.display_name = "Example Bridge Segments TEST"
	blueprint.theme = "bridge_prototype"
	blueprint.visual_theme = "kit_bridge"
	blueprint.deck_y = 4.0
	blueprint.target_length = 40.0
	blueprint.difficulty = 2
	blueprint.route_half_width = 5.0
	blueprint.lane_half_width = 4.5
	blueprint.water_enabled = true
	blueprint.fall_enabled = true
	blueprint.moving_obstacles_enabled = false
	blueprint.authoring_status = "test"
	blueprint.notes = (
		"Pipeline proof only. Not playable. Uses segment grammar and asset library; "
		+ "finish authority remains World/StreamerBase."
	)
	blueprint.segment_sequence = [
		"seg_start_8",
		"seg_straight_8",
		"seg_gap_8",
		"seg_straight_8",
		"seg_finish_8",
	]
	return blueprint


static func resolve_blueprint(blueprint_id: String) -> Resource:
	if blueprint_id == "example_bridge_segments_test":
		return create()
	return null
