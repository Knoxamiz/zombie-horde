class_name Phase2DropGapTestBlueprint
extends RefCounted

const AIMapBlueprintScript := preload("res://scripts/maps/ai_map_blueprint.gd")

## Phase 2 prototype blueprint (non-playable, not in MapCatalog):
## start → straight → elevated → left_side_drop → broken_bridge_gap
## → recovery → double_side_drop → finish


static func create():
	var blueprint = AIMapBlueprintScript.new()
	blueprint.map_id = "phase2_drop_gap_test"
	blueprint.display_name = "Phase 2 Drop Gap TEST"
	blueprint.theme = "phase2_drop_gap"
	blueprint.visual_theme = "phase2_kit"
	blueprint.deck_y = 2.0
	blueprint.target_length = 72.0
	blueprint.difficulty = 3
	blueprint.route_half_width = 5.0
	blueprint.lane_half_width = 4.0
	blueprint.water_enabled = true
	blueprint.fall_enabled = true
	blueprint.moving_obstacles_enabled = false
	blueprint.authoring_status = "test"
	blueprint.notes = (
		"Phase 2 drop/fall/gap proof route. Prototype/test only — not playable, not in map dropdown. "
		+ "Finish authority: World/StreamerBase. Falls: Zombie._check_out_of_bounds. "
		+ "No authoritative void kill zones."
	)
	blueprint.segment_sequence = [
		"start_straight",
		"straight_road_medium",
		"elevated_straight",
		"left_side_drop",
		"broken_bridge_gap",
		"recovery_straight_after_gap",
		"double_side_drop",
		"finish_straight",
	]
	return blueprint


static func resolve_blueprint(blueprint_id: String):
	if blueprint_id == "phase2_drop_gap_test":
		return create()
	return null
