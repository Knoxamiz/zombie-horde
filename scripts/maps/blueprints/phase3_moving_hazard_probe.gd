class_name Phase3MovingHazardProbeBlueprint
extends RefCounted

const AIMapBlueprintScript := preload("res://scripts/maps/ai_map_blueprint.gd")

## Phase 3 moving hazard export probe (non-playable, not in MapCatalog dropdown):
## start → straight → moving_block_lane → hazard_recovery_straight
## → timed_gate_straight → finish


static func create():
	var blueprint = AIMapBlueprintScript.new()
	blueprint.map_id = "phase3_moving_hazard_probe"
	blueprint.display_name = "Phase 3 Moving Hazard PROBE"
	blueprint.theme = "phase3_moving"
	blueprint.visual_theme = "phase3_kit"
	blueprint.deck_y = 0.8
	blueprint.target_length = 56.0
	blueprint.difficulty = 3
	blueprint.route_half_width = 5.0
	blueprint.lane_half_width = 4.0
	blueprint.water_enabled = false
	blueprint.fall_enabled = false
	blueprint.moving_obstacles_enabled = true
	blueprint.obstacle_cycle_time = 4.0
	blueprint.authoring_status = "prototype"
	blueprint.notes = (
		"Phase 3 drop-and-play moving hazard export probe. Prototype/test only — not playable, "
		+ "not in map dropdown. Obstacles use MapMovingObstacle kinematic collision only. "
		+ "Finish authority: World/StreamerBase. No direct kill logic or authoritative void kill zones."
	)
	blueprint.segment_sequence = [
		"start_straight",
		"straight_road_medium",
		"moving_block_lane",
		"hazard_recovery_straight",
		"timed_gate_straight",
		"finish_straight",
	]
	return blueprint


static func resolve_blueprint(blueprint_id: String):
	if blueprint_id == "phase3_moving_hazard_probe":
		return create()
	return null
