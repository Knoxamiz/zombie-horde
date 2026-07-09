class_name Phase4SplitLaneTestBlueprint
extends RefCounted

const AIMapBlueprintScript := preload("res://scripts/maps/ai_map_blueprint.gd")

## Phase 4 prototype blueprint (non-playable, not in MapCatalog):
## start → straight → split → narrow_shortcut → wide_safe_route → merge
## → moving_block_lane → finish
##
## Split branches are forward-compatible lane offsets — no zombie pathfinding.


static func create():
	var blueprint = AIMapBlueprintScript.new()
	blueprint.map_id = "phase4_split_lane_test"
	blueprint.display_name = "Phase 4 Split Lane TEST"
	blueprint.theme = "phase4_split_merge"
	blueprint.visual_theme = "phase4_kit"
	blueprint.deck_y = 0.8
	blueprint.target_length = 64.0
	blueprint.difficulty = 3
	blueprint.route_half_width = 7.0
	blueprint.lane_half_width = 5.0
	blueprint.water_enabled = false
	blueprint.fall_enabled = false
	blueprint.moving_obstacles_enabled = true
	blueprint.obstacle_cycle_time = 4.0
	blueprint.authoring_status = "test"
	blueprint.notes = (
		"Phase 4 split/merge proof route. Prototype/test only — not playable, not in map dropdown. "
		+ "Branches are visual/lane-offset shapes; zombies still use forward-track movement. "
		+ "Finish authority: World/StreamerBase. No authoritative void kill zones."
	)
	blueprint.segment_sequence = [
		"start_straight",
		"straight_road_medium",
		"split_two_lane",
		"narrow_shortcut",
		"wide_safe_route",
		"merge_two_lane",
		"moving_block_lane",
		"finish_straight",
	]
	return blueprint


static func resolve_blueprint(blueprint_id: String):
	if blueprint_id == "phase4_split_lane_test":
		return create()
	return null
