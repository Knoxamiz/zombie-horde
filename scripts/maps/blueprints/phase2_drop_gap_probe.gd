class_name Phase2DropGapProbeBlueprint
extends RefCounted

const AIMapBlueprintScript := preload("res://scripts/maps/ai_map_blueprint.gd")

## Minimal Phase 2 export probe (non-playable, not in MapCatalog dropdown):
## start → straight → elevated → broken_bridge_gap → recovery → finish
##
## Purpose: prove drops/gaps/water/OOB validation exports and certifies correctly
## before designing the full Drop Bridge signature map.


static func create():
	var blueprint = AIMapBlueprintScript.new()
	blueprint.map_id = "phase2_drop_gap_probe"
	blueprint.display_name = "Phase 2 Drop Gap PROBE"
	blueprint.theme = "phase2_drop_gap"
	blueprint.visual_theme = "phase2_kit"
	blueprint.deck_y = 2.0
	blueprint.target_length = 56.0
	blueprint.difficulty = 2
	blueprint.route_half_width = 5.0
	blueprint.lane_half_width = 4.0
	blueprint.water_enabled = true
	blueprint.fall_enabled = true
	blueprint.moving_obstacles_enabled = false
	blueprint.authoring_status = "test"
	blueprint.notes = (
		"Minimal Phase 2 drop/gap/water/OOB export probe. Prototype/test only — not playable, "
		+ "not in map dropdown. Finish authority: World/StreamerBase. "
		+ "Falls: Zombie._check_out_of_bounds. No authoritative void kill zones."
	)
	blueprint.segment_sequence = [
		"start_straight",
		"straight_road_medium",
		"elevated_straight",
		"broken_bridge_gap",
		"recovery_straight_after_gap",
		"finish_straight",
	]
	return blueprint


static func resolve_blueprint(blueprint_id: String):
	if blueprint_id == "phase2_drop_gap_probe":
		return create()
	return null
