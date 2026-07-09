class_name FallthroughLowerDeckTestBlueprint
extends RefCounted

const AIMapBlueprintScript := preload("res://scripts/maps/ai_map_blueprint.gd")

## Dev-only collision proof: upper deck wings with center hole → fall onto lower recovery deck.
## Uses MapSurfacePiece collision only where walkable geometry exists.


static func create():
	var blueprint = AIMapBlueprintScript.new()
	blueprint.map_id = "fallthrough_lower_deck_test"
	blueprint.display_name = "Fallthrough Lower Deck TEST"
	blueprint.theme = "fallthrough_test"
	blueprint.visual_theme = "phase2_kit"
	blueprint.deck_y = 2.0
	blueprint.target_length = 44.0
	blueprint.difficulty = 2
	blueprint.route_half_width = 5.0
	blueprint.lane_half_width = 4.0
	blueprint.water_enabled = true
	blueprint.fall_enabled = true
	blueprint.moving_obstacles_enabled = false
	blueprint.authoring_status = "test"
	blueprint.notes = (
		"Dev test map: center hole on upper deck, land on lower recovery deck. "
		+ "Not playable in streamer menu. Load via F3 dev panel only."
	)
	blueprint.segment_sequence = [
		"start_straight",
		"straight_road_medium",
		"upper_fallthrough_deck",
		"lower_recovery_deck",
		"finish_straight",
	]
	return blueprint
