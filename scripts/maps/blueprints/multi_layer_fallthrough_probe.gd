class_name MultiLayerFallthroughProbeBlueprint
extends RefCounted

const AIMapBlueprintScript := preload("res://scripts/maps/ai_map_blueprint.gd")

## Professional surface-collision proof map:
## upper deck wings with center hole → fall through → land on lower recovery deck.
##
## Collision is per MapSurfacePiece (shape-matched slabs). No full-segment invisible plates.


static func create():
	var blueprint = AIMapBlueprintScript.new()
	blueprint.map_id = "multi_layer_fallthrough_probe"
	blueprint.display_name = "Multi-Layer Fallthrough PROBE"
	blueprint.theme = "phase2_multi_layer"
	blueprint.visual_theme = "phase2_kit"
	blueprint.deck_y = 2.0
	blueprint.target_length = 48.0
	blueprint.difficulty = 3
	blueprint.route_half_width = 5.0
	blueprint.lane_half_width = 4.0
	blueprint.water_enabled = true
	blueprint.fall_enabled = true
	blueprint.moving_obstacles_enabled = false
	blueprint.authoring_status = "test"
	blueprint.notes = (
		"Surface-piece collision proof: upper deck hole, lower recovery deck landing. "
		+ "Prototype/test only. Falls below void still use Zombie._check_out_of_bounds()."
	)
	blueprint.segment_sequence = [
		"start_straight",
		"straight_road_medium",
		"upper_fallthrough_deck",
		"lower_recovery_deck",
		"finish_straight",
	]
	return blueprint


static func resolve_blueprint(blueprint_id: String):
	if blueprint_id == "multi_layer_fallthrough_probe":
		return create()
	return null
