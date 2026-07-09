class_name Phase1BridgeRampTestBlueprint
extends RefCounted

const AIMapBlueprintScript := preload("res://scripts/maps/ai_map_blueprint.gd")

## Phase 1 prototype blueprint (non-playable, not in MapCatalog):
## start → straight → ramp_up → bridge → small_gap → straight → ramp_down → finish


static func create():
	var blueprint = AIMapBlueprintScript.new()
	blueprint.map_id = "phase1_bridge_ramp_test"
	blueprint.display_name = "Phase 1 Bridge Ramp TEST"
	blueprint.theme = "phase1_bridge"
	blueprint.visual_theme = "phase1_kit"
	blueprint.deck_y = 0.8
	blueprint.target_length = 72.0
	blueprint.difficulty = 2
	blueprint.route_half_width = 5.0
	blueprint.lane_half_width = 4.5
	blueprint.water_enabled = true
	blueprint.fall_enabled = true
	blueprint.moving_obstacles_enabled = false
	blueprint.authoring_status = "test"
	blueprint.notes = (
		"Phase 1 asset pack proof route. Prototype/test only — not playable, not in map dropdown. "
		+ "Finish authority: World/StreamerBase. Falls: Zombie._check_out_of_bounds."
	)
	blueprint.segment_sequence = [
		"start_straight",
		"straight_road_medium",
		"ramp_up",
		"bridge_straight",
		"small_gap",
		"straight_road_short",
		"ramp_down",
		"finish_straight",
	]
	return blueprint


static func resolve_blueprint(blueprint_id: String):
	if blueprint_id == "phase1_bridge_ramp_test":
		return create()
	return null
