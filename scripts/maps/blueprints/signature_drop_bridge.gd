class_name SignatureDropBridgeBlueprint
extends RefCounted

const AIMapBlueprintScript := preload("res://scripts/maps/ai_map_blueprint.gd")

## Signature Map Prototype #1 — The Drop Bridge (non-playable, not in MapCatalog dropdown):
## start → straight → elevated → left_side_drop → narrow_no_rails_bridge
## → broken_bridge_gap → recovery → double_side_drop → finish
##
## Prototype ride: elevated bridge with obvious side falls, center gap, and streamer finish.
## Finish authority: World/StreamerBase. Falls: Zombie._check_out_of_bounds.
## No GoalCatch, void kill zones, scene cameras, moving obstacles, or split lanes.


static func create():
	var blueprint = AIMapBlueprintScript.new()
	blueprint.map_id = "signature_drop_bridge"
	blueprint.display_name = "The Drop Bridge"
	blueprint.theme = "signature_drop_bridge"
	blueprint.visual_theme = "phase2_kit"
	blueprint.deck_y = 3.0
	blueprint.target_length = 80.0
	blueprint.difficulty = 3
	blueprint.route_half_width = 6.0
	blueprint.lane_half_width = 5.0
	blueprint.water_enabled = true
	blueprint.fall_enabled = true
	blueprint.moving_obstacles_enabled = false
	blueprint.authoring_status = "prototype"
	blueprint.notes = (
		"Signature Map Prototype #1 — The Drop Bridge. Prototype/test only — not playable, "
		+ "not in production map dropdown. Readable elevated bridge with side drops, narrow "
		+ "no-rails section, broken center gap, and recovery floor. Mostly flat/elevated deck "
		+ "(no ramp physics dependency). Finish: World/StreamerBase. Falls: Zombie._check_out_of_bounds. "
		+ "No GoalCatch, authoritative void kill zones, scene cameras, moving obstacles, or splits."
	)
	blueprint.segment_sequence = [
		"start_straight",
		"straight_road_medium",
		"elevated_straight",
		"left_side_drop",
		"narrow_no_rails_bridge",
		"broken_bridge_gap",
		"recovery_straight_after_gap",
		"double_side_drop",
		"finish_straight",
	]
	return blueprint


static func resolve_blueprint(blueprint_id: String):
	if blueprint_id == "signature_drop_bridge":
		return create()
	return null
