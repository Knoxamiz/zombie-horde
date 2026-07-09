class_name MapSegmentDefinition
extends RefCounted

const TYPE_START := "start"
const TYPE_STRAIGHT := "straight"
const TYPE_RAMP_UP := "ramp_up"
const TYPE_RAMP_DOWN := "ramp_down"
const TYPE_BRIDGE := "bridge"
const TYPE_NARROW_BRIDGE := "narrow_bridge"
const TYPE_GAP := "gap"
const TYPE_DROP := "drop"
const TYPE_SPLIT_LANE := "split_lane"
const TYPE_MERGE_LANE := "merge_lane"
const TYPE_SPLIT_TWO_LANE := "split_two_lane"
const TYPE_MERGE_TWO_LANE := "merge_two_lane"
const TYPE_RISK_REWARD_SPLIT := "risk_reward_split"
const TYPE_NARROW_SHORTCUT := "narrow_shortcut"
const TYPE_WIDE_SAFE_ROUTE := "wide_safe_route"
const TYPE_HIGH_LOW_SPLIT := "high_low_split"
const TYPE_SIDE_BRIDGE_ROUTE := "side_bridge_route"
const TYPE_OBSTACLE_ROUTE_CHOICE := "obstacle_route_choice"
const TYPE_SPLIT_GAP_CHOICE := "split_gap_choice"
const TYPE_MERGE_RECOVERY := "merge_recovery"
const TYPE_SIDE_DROP := "side_drop"
const TYPE_SMALL_CENTER_GAP := "small_center_gap"
const TYPE_LEFT_SIDE_DROP := "left_side_drop"
const TYPE_RIGHT_SIDE_DROP := "right_side_drop"
const TYPE_DOUBLE_SIDE_DROP := "double_side_drop"
const TYPE_NARROW_NO_RAILS_BRIDGE := "narrow_no_rails_bridge"
const TYPE_BROKEN_BRIDGE_GAP := "broken_bridge_gap"
const TYPE_ELEVATED := "elevated"
const TYPE_ELEVATED_RAMP_DROP := "elevated_ramp_drop"
const TYPE_CRACKED_EDGE_LANE := "cracked_edge_lane"
const TYPE_WATER_UNDERPASS := "water_underpass"
const TYPE_RECOVERY := "recovery"
const TYPE_SIDE_PUSHER_LANE := "side_pusher_lane"
const TYPE_CRUSHER_CORRIDOR := "crusher_corridor"
const TYPE_ROTATING_ARM_BRIDGE := "rotating_arm_bridge"
const TYPE_TIMED_GATE_STRAIGHT := "timed_gate_straight"
const TYPE_SLIDING_WALL_LANE := "sliding_wall_lane"
const TYPE_MOVING_PLATFORM_GAP := "moving_platform_gap"
const TYPE_OBSTACLE_SLALOM := "obstacle_slalom"
const TYPE_HAZARD_RECOVERY := "hazard_recovery"
const TYPE_MOVING_BLOCK_LANE := "moving_block_lane"
const TYPE_HAZARD_LANE := "hazard_lane"
const TYPE_FINISH := "finish"

const ALL_TYPES: Array[String] = [
	TYPE_START,
	TYPE_STRAIGHT,
	TYPE_RAMP_UP,
	TYPE_RAMP_DOWN,
	TYPE_BRIDGE,
	TYPE_NARROW_BRIDGE,
	TYPE_GAP,
	TYPE_DROP,
	TYPE_SIDE_DROP,
	TYPE_SMALL_CENTER_GAP,
	TYPE_LEFT_SIDE_DROP,
	TYPE_RIGHT_SIDE_DROP,
	TYPE_DOUBLE_SIDE_DROP,
	TYPE_NARROW_NO_RAILS_BRIDGE,
	TYPE_BROKEN_BRIDGE_GAP,
	TYPE_ELEVATED,
	TYPE_ELEVATED_RAMP_DROP,
	TYPE_CRACKED_EDGE_LANE,
	TYPE_WATER_UNDERPASS,
	TYPE_RECOVERY,
	TYPE_SIDE_PUSHER_LANE,
	TYPE_CRUSHER_CORRIDOR,
	TYPE_ROTATING_ARM_BRIDGE,
	TYPE_TIMED_GATE_STRAIGHT,
	TYPE_SLIDING_WALL_LANE,
	TYPE_MOVING_PLATFORM_GAP,
	TYPE_OBSTACLE_SLALOM,
	TYPE_HAZARD_RECOVERY,
	TYPE_SPLIT_LANE,
	TYPE_MERGE_LANE,
	TYPE_SPLIT_TWO_LANE,
	TYPE_MERGE_TWO_LANE,
	TYPE_RISK_REWARD_SPLIT,
	TYPE_NARROW_SHORTCUT,
	TYPE_WIDE_SAFE_ROUTE,
	TYPE_HIGH_LOW_SPLIT,
	TYPE_SIDE_BRIDGE_ROUTE,
	TYPE_OBSTACLE_ROUTE_CHOICE,
	TYPE_SPLIT_GAP_CHOICE,
	TYPE_MERGE_RECOVERY,
	TYPE_MOVING_BLOCK_LANE,
	TYPE_HAZARD_LANE,
	TYPE_FINISH,
]

const PHASE4_SEGMENT_IDS: Array[String] = [
	"split_two_lane",
	"merge_two_lane",
	"risk_reward_split",
	"narrow_shortcut",
	"wide_safe_route",
	"high_low_split",
	"side_bridge_route",
	"obstacle_route_choice",
	"split_gap_choice",
	"merge_recovery_straight",
]

const PHASE3_SEGMENT_IDS: Array[String] = [
	"moving_block_lane",
	"side_pusher_lane",
	"crusher_corridor",
	"rotating_arm_bridge",
	"timed_gate_straight",
	"sliding_wall_lane",
	"moving_platform_gap",
	"obstacle_slalom",
	"hazard_recovery_straight",
]

const PHASE2_SEGMENT_IDS: Array[String] = [
	"small_center_gap",
	"left_side_drop",
	"right_side_drop",
	"double_side_drop",
	"narrow_no_rails_bridge",
	"broken_bridge_gap",
	"elevated_straight",
	"elevated_ramp_drop",
	"cracked_edge_lane",
	"water_underpass",
	"recovery_straight_after_gap",
]

const PHASE1_SEGMENT_IDS: Array[String] = [
	"start_straight",
	"straight_road_short",
	"straight_road_medium",
	"straight_road_long",
	"bridge_straight",
	"narrow_bridge",
	"ramp_up",
	"ramp_down",
	"small_gap",
	"side_drop_edges",
	"finish_straight",
]

static var _segments_cache: Array[Dictionary] = []


static func get_phase1_segment_ids() -> Array[String]:
	return PHASE1_SEGMENT_IDS.duplicate()


static func is_phase1_segment(segment_id: String) -> bool:
	return segment_id in PHASE1_SEGMENT_IDS


static func validate_phase1_segments() -> Dictionary:
	var result: Dictionary = {"ok": true, "missing": []}
	for segment_id in PHASE1_SEGMENT_IDS:
		if not has_segment(segment_id):
			result["ok"] = false
			result["missing"].append(segment_id)
	return result


static func get_phase2_segment_ids() -> Array[String]:
	return PHASE2_SEGMENT_IDS.duplicate()


static func is_phase2_segment(segment_id: String) -> bool:
	return segment_id in PHASE2_SEGMENT_IDS


static func validate_phase2_segments() -> Dictionary:
	var result: Dictionary = {"ok": true, "missing": []}
	for segment_id in PHASE2_SEGMENT_IDS:
		if not has_segment(segment_id):
			result["ok"] = false
			result["missing"].append(segment_id)
	return result


static func get_phase3_segment_ids() -> Array[String]:
	return PHASE3_SEGMENT_IDS.duplicate()


static func is_phase3_segment(segment_id: String) -> bool:
	return segment_id in PHASE3_SEGMENT_IDS


static func validate_phase3_segments() -> Dictionary:
	var result: Dictionary = {"ok": true, "missing": []}
	for segment_id in PHASE3_SEGMENT_IDS:
		if not has_segment(segment_id):
			result["ok"] = false
			result["missing"].append(segment_id)
	return result


static func is_moving_obstacle_segment_type(segment_type: String) -> bool:
	return segment_type in [
		TYPE_MOVING_BLOCK_LANE,
		TYPE_SIDE_PUSHER_LANE,
		TYPE_CRUSHER_CORRIDOR,
		TYPE_ROTATING_ARM_BRIDGE,
		TYPE_TIMED_GATE_STRAIGHT,
		TYPE_SLIDING_WALL_LANE,
		TYPE_MOVING_PLATFORM_GAP,
		TYPE_OBSTACLE_SLALOM,
	]


static func is_platform_gap_segment_type(segment_type: String) -> bool:
	return segment_type == TYPE_MOVING_PLATFORM_GAP


static func get_phase4_segment_ids() -> Array[String]:
	return PHASE4_SEGMENT_IDS.duplicate()


static func is_phase4_segment(segment_id: String) -> bool:
	return segment_id in PHASE4_SEGMENT_IDS


static func validate_phase4_segments() -> Dictionary:
	var result: Dictionary = {"ok": true, "missing": []}
	for segment_id in PHASE4_SEGMENT_IDS:
		if not has_segment(segment_id):
			result["ok"] = false
			result["missing"].append(segment_id)
	return result


static func is_split_segment_type(segment_type: String) -> bool:
	return segment_type in [
		TYPE_SPLIT_LANE,
		TYPE_SPLIT_TWO_LANE,
		TYPE_RISK_REWARD_SPLIT,
		TYPE_HIGH_LOW_SPLIT,
		TYPE_SPLIT_GAP_CHOICE,
		TYPE_OBSTACLE_ROUTE_CHOICE,
	]


static func is_merge_segment_type(segment_type: String) -> bool:
	return segment_type in [
		TYPE_MERGE_LANE,
		TYPE_MERGE_TWO_LANE,
		TYPE_MERGE_RECOVERY,
	]


static func is_branch_route_segment_type(segment_type: String) -> bool:
	return segment_type in [
		TYPE_NARROW_SHORTCUT,
		TYPE_WIDE_SAFE_ROUTE,
		TYPE_SIDE_BRIDGE_ROUTE,
		TYPE_HIGH_LOW_SPLIT,
	]


static func is_route_shape_segment_type(segment_type: String) -> bool:
	return (
		is_split_segment_type(segment_type)
		or is_merge_segment_type(segment_type)
		or is_branch_route_segment_type(segment_type)
	)


static func get_segment_route_half_width(segment: Dictionary) -> float:
	var total_width: float = float(segment.get("total_width", segment.get("width", 10.0)))
	return total_width * 0.5


static func is_fall_risk_segment_type(segment_type: String) -> bool:
	return segment_type in [
		TYPE_GAP,
		TYPE_DROP,
		TYPE_SIDE_DROP,
		TYPE_SMALL_CENTER_GAP,
		TYPE_LEFT_SIDE_DROP,
		TYPE_RIGHT_SIDE_DROP,
		TYPE_DOUBLE_SIDE_DROP,
		TYPE_BROKEN_BRIDGE_GAP,
		TYPE_ELEVATED_RAMP_DROP,
		TYPE_CRACKED_EDGE_LANE,
		TYPE_SPLIT_GAP_CHOICE,
	]


static func is_gap_segment_type(segment_type: String) -> bool:
	return segment_type in [
		TYPE_GAP,
		TYPE_SMALL_CENTER_GAP,
		TYPE_BROKEN_BRIDGE_GAP,
	]


static func is_recovery_segment_type(segment_type: String) -> bool:
	return segment_type == TYPE_RECOVERY


static func is_elevated_segment_type(segment_type: String) -> bool:
	return segment_type in [
		TYPE_ELEVATED,
		TYPE_ELEVATED_RAMP_DROP,
		TYPE_BRIDGE,
		TYPE_NARROW_BRIDGE,
		TYPE_NARROW_NO_RAILS_BRIDGE,
		TYPE_BROKEN_BRIDGE_GAP,
		TYPE_WATER_UNDERPASS,
	]


static func has_segment(segment_id: String) -> bool:
	return not get_segment(segment_id).is_empty()


static func get_segment(segment_id: String) -> Dictionary:
	for entry in _segments():
		if str(entry.get("segment_id", "")) == segment_id:
			return entry.duplicate(true)
	return {}


static func get_segments_by_type(segment_type: String) -> Array[Dictionary]:
	var matches: Array[Dictionary] = []
	for entry in _segments():
		if str(entry.get("type", "")) == segment_type:
			matches.append(entry.duplicate(true))
	return matches


static func get_all_segment_ids() -> Array[String]:
	var ids: Array[String] = []
	for entry in _segments():
		ids.append(str(entry.get("segment_id", "")))
	return ids


static func _segments() -> Array[Dictionary]:
	if _segments_cache.is_empty():
		_segments_cache = _build_segments()
	return _segments_cache


static func _build_segments() -> Array[Dictionary]:
	return [
		_segment(
			"seg_start_8", TYPE_START, 8.0, 10.0, 0.0, 1,
			["spawn_marker", "street_straight", "safe_floor_plate"],
			["traffic_cone_1"],
			10.0, 10.0, false, false, 0, 1,
			"Spawn pad and first road tile."
		),
		_segment(
			"seg_straight_8", TYPE_STRAIGHT, 8.0, 10.0, 0.0, 1,
			["street_straight", "safe_floor_plate"],
			["street_light", "plastic_barrier"],
			10.0, 10.0, false, false, 0, 1,
			"Flat straight lane."
		),
		_segment(
			"seg_straight_16", TYPE_STRAIGHT, 16.0, 10.0, 0.0, 2,
			["street_straight", "safe_floor_plate"],
			["street_light"],
			10.0, 10.0, false, false, 0, 1,
			"Longer straight for highway-style sections."
		),
		_segment(
			"seg_ramp_up_8", TYPE_RAMP_UP, 8.0, 10.0, 0.8, 2,
			["ramp_box", "safe_floor_plate"],
			["support_pillar"],
			10.0, 10.0, false, false, 0, 1,
			"Raises deck by height_delta over segment length."
		),
		_segment(
			"seg_ramp_down_8", TYPE_RAMP_DOWN, 8.0, 10.0, -0.8, 2,
			["ramp_box", "safe_floor_plate"],
			[],
			10.0, 10.0, false, false, 0, 1,
			"Lowers deck over segment length."
		),
		_segment(
			"seg_bridge_8", TYPE_BRIDGE, 8.0, 10.0, 0.0, 2,
			["bridge_deck_plate", "safe_floor_plate", "traffic_barrier_1"],
			["support_pillar", "water_void_plane"],
			10.0, 10.0, true, false, 0, 1,
			"Elevated bridge deck with rails."
		),
		_segment(
			"seg_narrow_bridge_8", TYPE_NARROW_BRIDGE, 8.0, 6.0, 0.0, 3,
			["bridge_deck_plate", "safe_floor_plate", "traffic_barrier_1"],
			["support_pillar"],
			6.0, 6.0, true, false, 0, 1,
			"Narrow bridge segment for skill checks."
		),
		_segment(
			"seg_gap_8", TYPE_GAP, 8.0, 10.0, 0.0, 3,
			["gap_void_visual", "drop_lip", "street_crack2"],
			["water_void_plane"],
			10.0, 10.0, true, false, 1, 1,
			"Visual gap with narrow safe plate; fall via OOB min-Y.",
			1, -5.5, 1.0, 0.6,
		),
		_segment(
			"seg_drop_8", TYPE_DROP, 8.0, 10.0, -0.8, 3,
			["drop_lip", "gap_void_visual", "safe_floor_plate"],
			[],
			10.0, 10.0, true, false, 1, 1,
			"Step down segment; requires aligned deck_y in blueprint."
		),
		_segment(
			"seg_split_lane_8", TYPE_SPLIT_LANE, 8.0, 12.0, 0.0, 2,
			["street_straight", "safe_floor_plate", "plastic_barrier"],
			[],
			12.0, 12.0, false, false, 0, 2,
			"Fork visual; safe lane count 2."
		),
		_segment(
			"seg_merge_lane_8", TYPE_MERGE_LANE, 8.0, 12.0, 0.0, 2,
			["street_straight", "safe_floor_plate"],
			["plastic_barrier"],
			12.0, 10.0, false, false, 0, 1,
			"Merge back to single safe lane."
		),
		_segment(
			"seg_moving_block_8", TYPE_MOVING_BLOCK_LANE, 8.0, 10.0, 0.0, 3,
			["street_straight", "safe_floor_plate", "moving_block_slot"],
			[],
			10.0, 10.0, false, true, 0, 1,
			"Reserved slot for MapLab movers; prototype only."
		),
		_segment(
			"seg_hazard_lane_8", TYPE_HAZARD_LANE, 8.0, 10.0, 0.0, 2,
			["street_crack1", "safe_floor_plate", "hazard_warning_plane"],
			["traffic_cone_1"],
			10.0, 10.0, false, false, 2, 1,
			"Hazard dressing without authoritative kill zones."
		),
		_segment(
			"seg_finish_8", TYPE_FINISH, 8.0, 10.0, 0.0, 1,
			["finish_marker", "street_straight", "safe_floor_plate"],
			[],
			10.0, 10.0, false, false, 0, 1,
			"Goal visual band only; finish trigger is StreamerBase."
		),
		_segment(
			"seg_test_bad_asset", TYPE_STRAIGHT, 8.0, 10.0, 0.0, 1,
			["not_a_real_asset_id"],
			[],
			10.0, 10.0, false, false, 0, 1,
			"TEST ONLY — invalid asset id for validator tests."
		),
		_segment(
			"seg_test_oversized_gap", TYPE_BROKEN_BRIDGE_GAP, 8.0, 10.0, 0.0, 4,
			["phase2_broken_bridge_gap", "phase2_safe_floor_plate"],
			[],
			10.0, 10.0, true, false, 2, 1,
			"TEST ONLY — oversized safe floor ratio for validator tests.",
			3, -6.5, 3.0, 1.5,
		),
		# --- Phase 1 canonical segment templates ---
		_segment(
			"start_straight", TYPE_START, 8.0, 10.0, 0.0, 1,
			["phase1_spawn_marker", "phase1_road_straight_8", "phase1_safe_floor_plate"],
			["phase1_deco_cone"],
			10.0, 10.0, false, false, 0, 1,
			"Phase 1 spawn straight."
		),
		_segment(
			"straight_road_short", TYPE_STRAIGHT, 8.0, 10.0, 0.0, 1,
			["phase1_road_straight_8", "phase1_safe_floor_plate"],
			["phase1_deco_light", "phase1_barrier_plastic"],
			10.0, 10.0, false, false, 0, 1,
			"Short 8m straight road."
		),
		_segment(
			"straight_road_medium", TYPE_STRAIGHT, 16.0, 10.0, 0.0, 2,
			["phase1_road_straight_8", "phase1_safe_floor_plate"],
			["phase1_deco_light"],
			10.0, 10.0, false, false, 0, 1,
			"Medium 16m straight; safe floor spans full length."
		),
		_segment(
			"straight_road_long", TYPE_STRAIGHT, 24.0, 10.0, 0.0, 2,
			["phase1_road_straight_8", "phase1_safe_floor_plate"],
			["phase1_deco_light", "phase1_deco_pipes"],
			10.0, 10.0, false, false, 0, 1,
			"Long 24m straight; safe floor spans full length."
		),
		_segment(
			"bridge_straight", TYPE_BRIDGE, 8.0, 10.0, 0.0, 2,
			["phase1_bridge_deck_8", "phase1_safe_floor_plate", "phase1_rail_traffic_a"],
			["phase1_support_pillar", "phase1_water_segment"],
			10.0, 10.0, true, false, 0, 1,
			"Elevated bridge deck with rails and supports."
		),
		_segment(
			"narrow_bridge", TYPE_NARROW_BRIDGE, 8.0, 6.0, 0.0, 3,
			["phase1_bridge_deck_8", "phase1_safe_floor_plate", "phase1_rail_traffic_b"],
			["phase1_support_pillar"],
			6.0, 6.0, true, false, 0, 1,
			"Narrow bridge skill-check segment."
		),
		_segment(
			"ramp_up", TYPE_RAMP_UP, 8.0, 10.0, 0.8, 2,
			["phase1_ramp_surface_8", "phase1_safe_floor_plate"],
			["phase1_support_pillar"],
			10.0, 10.0, false, false, 0, 1,
			"Raises route deck by 0.8m over 8m."
		),
		_segment(
			"ramp_down", TYPE_RAMP_DOWN, 8.0, 10.0, -0.8, 2,
			["phase1_ramp_surface_8", "phase1_safe_floor_plate"],
			[],
			10.0, 10.0, false, false, 0, 1,
			"Lowers route deck by 0.8m over 8m."
		),
		_segment(
			"small_gap", TYPE_GAP, 8.0, 10.0, 0.0, 3,
			["phase1_gap_void", "phase1_drop_lip", "phase1_road_cracked_heavy", "phase1_safe_floor_plate"],
			["phase1_water_segment"],
			10.0, 10.0, true, false, 1, 1,
			"Small gap with narrow safe plate; requires fall_enabled.",
			1, -5.5, 1.0, 0.6,
		),
		_segment(
			"side_drop_edges", TYPE_SIDE_DROP, 8.0, 10.0, 0.0, 3,
			[
				"phase1_broken_edge_light",
				"phase1_broken_edge_heavy",
				"phase1_gap_void",
				"phase1_safe_floor_plate",
			],
			["phase1_water_segment", "phase1_deco_pallet"],
			10.0, 10.0, true, false, 1, 1,
			"Fall edges on sides; center safe lane remains."
		),
		_segment(
			"finish_straight", TYPE_FINISH, 8.0, 10.0, 0.0, 1,
			["phase1_finish_marker", "phase1_road_straight_8", "phase1_safe_floor_plate"],
			[],
			10.0, 10.0, false, false, 0, 1,
			"Phase 1 finish straight; goal visual only.",
			0, -999.0, 0.0, 1.0,
		),
		# --- Phase 2 drop/fall/gap segment templates ---
		_segment(
			"small_center_gap", TYPE_SMALL_CENTER_GAP, 8.0, 10.0, 0.0, 3,
			[
				"phase2_broken_bridge_gap",
				"phase2_gap_edge_left",
				"phase2_gap_edge_right",
				"phase2_warning_stripes",
				"phase2_safe_floor_plate",
			],
			["phase2_void_floor_visual", "phase2_edge_cone"],
			10.0, 10.0, true, false, 1, 1,
			"Center gap with narrow safe plate; requires recovery segment after.",
			2, -5.5, 2.0, 0.6,
		),
		_segment(
			"left_side_drop", TYPE_LEFT_SIDE_DROP, 8.0, 10.0, 0.0, 3,
			[
				"phase2_side_fall_opening",
				"phase2_cracked_road_edge",
				"phase2_safe_floor_plate",
			],
			["phase2_void_floor_visual", "phase2_broken_guardrail", "phase2_edge_cone"],
			10.0, 6.0, true, false, 1, 1,
			"Left side fall opening; right lane remains safe.",
			2, -5.5, 1.5, 0.55,
		),
		_segment(
			"right_side_drop", TYPE_RIGHT_SIDE_DROP, 8.0, 10.0, 0.0, 3,
			[
				"phase2_side_fall_opening",
				"phase2_cracked_road_edge",
				"phase2_safe_floor_plate",
			],
			["phase2_void_floor_visual", "phase2_broken_guardrail", "phase2_edge_cone"],
			6.0, 10.0, true, false, 1, 1,
			"Right side fall opening; left lane remains safe.",
			2, -5.5, 1.5, 0.55,
		),
		_segment(
			"double_side_drop", TYPE_DOUBLE_SIDE_DROP, 8.0, 10.0, 0.0, 4,
			[
				"phase2_side_fall_opening",
				"phase2_cracked_road_edge",
				"phase2_warning_stripes",
				"phase2_safe_floor_plate",
			],
			["phase2_void_floor_visual", "phase2_missing_rail_section", "phase2_edge_light"],
			6.0, 6.0, true, false, 2, 1,
			"Both sides open; narrow center safe lane only.",
			3, -6.0, 2.5, 0.45,
		),
		_segment(
			"narrow_no_rails_bridge", TYPE_NARROW_NO_RAILS_BRIDGE, 8.0, 6.0, 0.0, 3,
			[
				"phase2_elevated_bridge_deck",
				"phase2_safe_floor_plate",
				"phase2_missing_rail_section",
			],
			["phase2_support_pillar", "phase2_void_floor_visual"],
			6.0, 6.0, true, false, 0, 1,
			"Narrow elevated bridge without guardrails.",
			2, -5.5, 2.0, 0.7,
		),
		_segment(
			"broken_bridge_gap", TYPE_BROKEN_BRIDGE_GAP, 8.0, 10.0, 0.0, 4,
			[
				"phase2_broken_bridge_gap",
				"phase2_broken_guardrail",
				"phase2_warning_stripes",
				"phase2_safe_floor_plate",
			],
			["phase2_void_floor_visual", "phase2_lower_river_catch", "phase2_deco_debris"],
			10.0, 10.0, true, false, 2, 1,
			"Broken bridge center gap; very narrow safe plate; recovery required after.",
			3, -6.5, 3.0, 0.4,
		),
		_segment(
			"elevated_straight", TYPE_ELEVATED, 8.0, 10.0, 0.0, 2,
			[
				"phase2_elevated_bridge_deck",
				"phase2_safe_floor_plate",
				"phase2_broken_guardrail",
			],
			["phase2_support_pillar", "phase2_water_river_plane"],
			10.0, 10.0, true, false, 0, 1,
			"Elevated straight deck above water/void.",
			1, -5.0, 2.0, 1.0,
		),
		_segment(
			"elevated_ramp_drop", TYPE_ELEVATED_RAMP_DROP, 8.0, 10.0, -0.8, 3,
			[
				"phase2_drop_off_section",
				"phase2_elevated_bridge_deck",
				"phase2_safe_floor_plate",
			],
			["phase2_warning_stripes", "phase2_lower_river_catch"],
			10.0, 10.0, true, false, 1, 1,
			"Ramp down from elevated deck; fall via OOB min-Y.",
			2, -6.0, 2.5, 0.85,
		),
		_segment(
			"cracked_edge_lane", TYPE_CRACKED_EDGE_LANE, 8.0, 10.0, 0.0, 2,
			[
				"phase2_cracked_road_edge",
				"phase2_warning_stripes",
				"phase2_safe_floor_plate",
			],
			["phase2_edge_cone", "phase2_deco_debris"],
			10.0, 8.0, true, false, 1, 1,
			"Cracked edge lane with warning paint; side fall risk.",
			1, -5.0, 1.0, 0.75,
		),
		_segment(
			"water_underpass", TYPE_WATER_UNDERPASS, 8.0, 10.0, 0.0, 2,
			[
				"phase2_elevated_bridge_deck",
				"phase2_safe_floor_plate",
				"phase2_water_river_plane",
			],
			["phase2_support_pillar", "phase2_lower_river_catch"],
			10.0, 10.0, true, false, 0, 1,
			"Elevated deck over river visual; deck_y must exceed void_y.",
			1, -5.0, 2.0, 1.0,
		),
		_segment(
			"recovery_straight_after_gap", TYPE_RECOVERY, 8.0, 10.0, 0.0, 1,
			[
				"phase1_road_straight_8",
				"phase2_safe_floor_plate",
			],
			["phase2_warning_stripes", "phase2_edge_cone"],
			10.0, 10.0, false, false, 0, 1,
			"Full-width safe floor after a gap/drop segment.",
			0, -999.0, 0.0, 1.0,
		),
		# --- Phase 3 moving obstacle segment templates ---
		_moving_segment(
			"moving_block_lane", TYPE_MOVING_BLOCK_LANE, 8.0, 10.0, 0.0, 3,
			[
				"phase1_road_straight_8",
				"phase2_safe_floor_plate",
				"phase3_moving_block_crate",
				"phase3_warning_stripes",
			],
			["phase3_safe_lane_marker", "phase3_warning_light"],
			10.0, 10.0, false, true, 1, 1,
			"Center lane moving block; safe edges remain.",
			0, -999.0, 0.0, 1.0,
			1, "x", 4.0, 3.5, true, 2.5,
		),
		_moving_segment(
			"side_pusher_lane", TYPE_SIDE_PUSHER_LANE, 8.0, 10.0, 0.0, 3,
			[
				"phase1_road_straight_8",
				"phase2_safe_floor_plate",
				"phase3_side_pusher",
				"phase3_pusher_plate",
				"phase3_warning_stripes",
			],
			["phase3_safe_lane_marker"],
			10.0, 8.0, false, true, 1, 1,
			"Side pusher with center safe lane.",
			0, -999.0, 0.0, 1.0,
			1, "x", 3.5, 3.5, true, 2.5,
		),
		_moving_segment(
			"crusher_corridor", TYPE_CRUSHER_CORRIDOR, 8.0, 10.0, 0.0, 4,
			[
				"phase1_road_straight_8",
				"phase2_safe_floor_plate",
				"phase3_crusher_plate",
				"phase3_crusher_frame",
				"phase3_warning_stripes",
			],
			["phase3_warning_light"],
			10.0, 10.0, false, true, 1, 1,
			"Overhead crusher with timed safe windows.",
			0, -999.0, 0.0, 1.0,
			1, "y", 4.5, 4.5, true, 2.5,
		),
		_moving_segment(
			"rotating_arm_bridge", TYPE_ROTATING_ARM_BRIDGE, 8.0, 10.0, 0.0, 4,
			[
				"phase2_elevated_bridge_deck",
				"phase2_safe_floor_plate",
				"phase3_rotating_arm",
				"phase3_warning_stripes",
			],
			["phase2_support_pillar", "phase3_safe_lane_marker"],
			10.0, 10.0, false, true, 1, 1,
			"Rotating arm over bridge deck; center safe timing.",
			0, -999.0, 0.0, 1.0,
			1, "y", 5.0, 5.0, true, 2.5,
		),
		_moving_segment(
			"timed_gate_straight", TYPE_TIMED_GATE_STRAIGHT, 8.0, 10.0, 0.0, 3,
			[
				"phase1_road_straight_8",
				"phase2_safe_floor_plate",
				"phase3_timed_gate",
				"phase3_gate_barrier",
				"phase3_warning_stripes",
			],
			["phase3_safe_lane_marker", "phase3_warning_light"],
			10.0, 10.0, false, true, 1, 1,
			"Timed gate opening/closing; always leaves pass window.",
			0, -999.0, 0.0, 1.0,
			1, "x", 6.0, 6.0, true, 2.5,
		),
		_moving_segment(
			"sliding_wall_lane", TYPE_SLIDING_WALL_LANE, 8.0, 10.0, 0.0, 3,
			[
				"phase1_road_straight_8",
				"phase2_safe_floor_plate",
				"phase3_sliding_wall",
				"phase3_warning_stripes",
			],
			["phase3_deco_sparks"],
			10.0, 8.0, false, true, 1, 1,
			"Sliding wall along Z with side safe lane.",
			0, -999.0, 0.0, 1.0,
			1, "z", 4.0, 4.0, true, 2.5,
		),
		_moving_segment(
			"moving_platform_gap", TYPE_MOVING_PLATFORM_GAP, 8.0, 10.0, 0.0, 4,
			[
				"phase2_broken_bridge_gap",
				"phase3_moving_platform",
				"phase3_platform_deck",
				"phase3_warning_stripes",
				"phase2_safe_floor_plate",
			],
			["phase2_void_floor_visual", "phase3_safe_lane_marker"],
			10.0, 10.0, true, true, 1, 1,
			"Moving platform over gap; recovery required after.",
			2, -5.5, 1.5, 0.55,
			1, "y", 5.0, 5.0, true, 2.0,
		),
		_moving_segment(
			"obstacle_slalom", TYPE_OBSTACLE_SLALOM, 8.0, 10.0, 0.0, 3,
			[
				"phase1_road_straight_8",
				"phase2_safe_floor_plate",
				"phase3_moving_block_wide",
				"phase3_lane_blocker",
				"phase3_warning_stripes",
			],
			["phase3_deco_sparks", "phase3_safe_lane_marker"],
			10.0, 10.0, false, true, 2, 1,
			"Two obstacle slots with slalom safe lane.",
			0, -999.0, 0.0, 1.0,
			2, "x", 4.0, 3.0, true, 2.5,
		),
		_moving_segment(
			"seg_test_blocks_all_lanes", TYPE_MOVING_BLOCK_LANE, 8.0, 10.0, 0.0, 4,
			["phase1_road_straight_8", "phase2_safe_floor_plate", "phase3_moving_block_crate"],
			[],
			10.0, 10.0, false, true, 1, 1,
			"TEST ONLY — obstacle blocks all lanes.",
			0, -999.0, 0.0, 1.0,
			1, "x", 4.0, 3.5, false, 0.5,
		),
		_moving_segment(
			"hazard_recovery_straight", TYPE_HAZARD_RECOVERY, 8.0, 10.0, 0.0, 1,
			[
				"phase1_road_straight_8",
				"phase2_safe_floor_plate",
				"phase3_safe_lane_marker",
			],
			["phase3_warning_stripes"],
			10.0, 10.0, false, false, 0, 1,
			"Full-width safe straight after obstacle section.",
			0, -999.0, 0.0, 1.0,
			0, "x", 0.0, 0.0, true, 3.0,
		),
		# --- Phase 4 split/merge route segment templates ---
		_route_segment(
			"split_two_lane", TYPE_SPLIT_TWO_LANE, 8.0, 14.0, 0.0, 2,
			[
				"phase4_fork_road_left",
				"phase4_fork_road_right",
				"phase4_split_bridge",
				"phase4_divider_barrier",
				"phase4_safe_floor_plate",
			],
			["phase4_route_sign_arrow", "phase4_split_guardrail"],
			14.0, 14.0, false, false, 0, 2,
			"Two-lane fork; forward-compatible lane offsets only.",
			0, -999.0, 2.0, 1.0,
			2, [4.0, 4.0], [-2.5, 2.5], Vector3.ZERO, 0, true,
		),
		_route_segment(
			"merge_two_lane", TYPE_MERGE_TWO_LANE, 8.0, 14.0, 0.0, 2,
			[
				"phase4_merge_road",
				"phase4_lane_merge_marking",
				"phase4_safe_floor_plate",
			],
			["phase4_split_guardrail", "phase4_divider_barrier"],
			14.0, 10.0, false, false, 0, 1,
			"Merge two offset branches back to center lane.",
			0, -999.0, 1.5, 1.0,
			2, [4.0, 4.0], [-2.5, 2.5], Vector3.ZERO, 0, true,
		),
		_route_segment(
			"risk_reward_split", TYPE_RISK_REWARD_SPLIT, 8.0, 16.0, 0.0, 3,
			[
				"phase4_fork_road_left",
				"phase4_fork_road_right",
				"phase4_split_bridge",
				"phase4_route_sign_arrow",
				"phase4_safe_floor_plate",
			],
			["phase4_divider_barrier", "phase4_split_guardrail"],
			16.0, 16.0, false, true, 0, 2,
			"Risk/reward fork; requires route sign and one low-risk branch.",
			0, -999.0, 3.0, 1.0,
			2, [3.5, 6.0], [-3.0, 3.0], Vector3.ZERO, 1, true,
		),
		_route_segment(
			"narrow_shortcut", TYPE_NARROW_SHORTCUT, 8.0, 5.0, 0.0, 3,
			[
				"phase4_narrow_shortcut_bridge",
				"phase4_safe_floor_plate",
				"phase4_route_sign_arrow",
			],
			["phase3_warning_stripes"],
			5.0, 5.0, false, true, 1, 1,
			"High-risk narrow shortcut branch (shorter visual lane).",
			0, -999.0, 1.0, 0.7,
			1, [3.5], [-2.5], Vector3.ZERO, 2, true,
		),
		_route_segment(
			"wide_safe_route", TYPE_WIDE_SAFE_ROUTE, 8.0, 9.0, 0.0, 1,
			[
				"phase4_wide_safe_bridge",
				"phase4_safe_floor_plate",
			],
			["phase4_route_sign_arrow", "phase4_side_support_pillar"],
			9.0, 9.0, false, false, 0, 1,
			"Low-risk wide safe branch (longer path).",
			0, -999.0, 1.0, 1.0,
			1, [6.0], [2.5], Vector3.ZERO, 0, true,
		),
		_route_segment(
			"high_low_split", TYPE_HIGH_LOW_SPLIT, 8.0, 14.0, 0.0, 3,
			[
				"phase4_high_path_ramp",
				"phase4_low_path_ramp",
				"phase4_split_bridge",
				"phase4_safe_floor_plate",
			],
			["phase4_route_sign_arrow", "phase4_divider_barrier"],
			14.0, 14.0, false, false, 0, 2,
			"High/low path split with ramp visuals.",
			0, -999.0, 2.5, 1.0,
			2, [4.0, 4.0], [-2.5, 2.5], Vector3.ZERO, 1, true,
		),
		_route_segment(
			"side_bridge_route", TYPE_SIDE_BRIDGE_ROUTE, 8.0, 8.0, 0.0, 2,
			[
				"phase4_side_bridge",
				"phase4_safe_floor_plate",
				"phase4_split_guardrail",
			],
			["phase4_side_support_pillar"],
			8.0, 8.0, false, false, 0, 1,
			"Side bridge alternate route offset from center.",
			0, -999.0, 2.0, 1.0,
			1, [5.0], [3.5], Vector3.ZERO, 0, true,
		),
		_route_segment(
			"obstacle_route_choice", TYPE_OBSTACLE_ROUTE_CHOICE, 8.0, 14.0, 0.0, 3,
			[
				"phase4_split_bridge",
				"phase4_safe_floor_plate",
				"phase3_warning_stripes",
				"phase4_route_sign_arrow",
			],
			["phase3_moving_block_crate", "phase4_divider_barrier"],
			14.0, 14.0, false, true, 1, 2,
			"Fork with obstacle on one branch visual only.",
			0, -999.0, 2.0, 1.0,
			2, [4.0, 4.0], [-2.5, 2.5], Vector3.ZERO, 1, true,
		),
		_route_segment(
			"split_gap_choice", TYPE_SPLIT_GAP_CHOICE, 8.0, 14.0, 0.0, 4,
			[
				"phase4_fork_road_left",
				"phase4_fork_road_right",
				"phase2_broken_bridge_gap",
				"phase4_safe_floor_plate",
				"phase4_route_sign_arrow",
			],
			["phase2_warning_stripes", "phase4_split_guardrail"],
			14.0, 14.0, true, false, 1, 2,
			"Split with gap on risky branch; requires fall_enabled.",
			2, -5.5, 2.5, 0.65,
			2, [3.5, 5.0], [-3.0, 3.0], Vector3.ZERO, 2, true,
		),
		_route_segment(
			"merge_recovery_straight", TYPE_MERGE_RECOVERY, 8.0, 10.0, 0.0, 1,
			[
				"phase1_road_straight_8",
				"phase4_safe_floor_plate",
				"phase4_lane_merge_marking",
			],
			["phase4_route_sign_arrow"],
			10.0, 10.0, false, false, 0, 1,
			"Recovery straight after merge section.",
			0, -999.0, 0.0, 1.0,
			1, [8.0], [0.0], Vector3.ZERO, 0, true,
		),
		_route_segment(
			"seg_test_branch_no_floor", TYPE_NARROW_SHORTCUT, 8.0, 5.0, 0.0, 3,
			["phase4_narrow_shortcut_bridge"],
			[],
			5.0, 5.0, false, false, 0, 1,
			"TEST ONLY — branch without safe floor plate.",
			0, -999.0, 0.0, 0.7,
			1, [], [], Vector3.ZERO, 2, false,
		),
		_route_segment(
			"seg_test_oversized_route", TYPE_SPLIT_TWO_LANE, 8.0, 30.0, 0.0, 2,
			["phase4_split_bridge", "phase4_safe_floor_plate"],
			[],
			30.0, 30.0, false, false, 0, 2,
			"TEST ONLY — route wider than typical OOB bounds.",
			0, -999.0, 4.0, 1.0,
			2, [12.0, 12.0], [-6.0, 6.0], Vector3.ZERO, 0, true,
		),
	]


static func _segment(
	segment_id: String,
	segment_type: String,
	length: float,
	width: float,
	height_delta: float,
	difficulty: int,
	required_assets: Array,
	optional_assets: Array,
	entry_width: float,
	exit_width: float,
	allows_fall_edges: bool,
	allows_moving_obstacles: bool,
	hazard_slots: int,
	safe_lane_count: int,
	notes: String = "",
	fall_risk_level: int = 0,
	recommended_oob_min_y: float = -999.0,
	recommended_camera_padding: float = 0.0,
	safe_floor_width_ratio: float = 1.0,
) -> Dictionary:
	return {
		"segment_id": segment_id,
		"type": segment_type,
		"length": length,
		"width": width,
		"height_delta": height_delta,
		"difficulty": difficulty,
		"required_assets": required_assets,
		"optional_assets": optional_assets,
		"entry_width": entry_width,
		"exit_width": exit_width,
		"allows_fall_edges": allows_fall_edges,
		"allows_moving_obstacles": allows_moving_obstacles,
		"hazard_slots": hazard_slots,
		"safe_lane_count": safe_lane_count,
		"fall_risk_level": fall_risk_level,
		"recommended_oob_min_y": recommended_oob_min_y,
		"recommended_camera_padding": recommended_camera_padding,
		"safe_floor_width_ratio": safe_floor_width_ratio,
		"notes": notes,
	}


static func _moving_segment(
	segment_id: String,
	segment_type: String,
	length: float,
	width: float,
	height_delta: float,
	difficulty: int,
	required_assets: Array,
	optional_assets: Array,
	entry_width: float,
	exit_width: float,
	allows_fall_edges: bool,
	allows_moving_obstacles: bool,
	hazard_slots: int,
	safe_lane_count: int,
	notes: String = "",
	fall_risk_level: int = 0,
	recommended_oob_min_y: float = -999.0,
	recommended_camera_padding: float = 0.0,
	safe_floor_width_ratio: float = 1.0,
	obstacle_slots: int = 1,
	movement_axis: String = "x",
	recommended_cycle_time: float = 4.0,
	recommended_spacing: float = 3.0,
	fallback_safe_lane: bool = true,
	fallback_safe_lane_width: float = 2.5,
) -> Dictionary:
	var segment: Dictionary = _segment(
		segment_id,
		segment_type,
		length,
		width,
		height_delta,
		difficulty,
		required_assets,
		optional_assets,
		entry_width,
		exit_width,
		allows_fall_edges,
		allows_moving_obstacles,
		hazard_slots,
		safe_lane_count,
		notes,
		fall_risk_level,
		recommended_oob_min_y,
		recommended_camera_padding,
		safe_floor_width_ratio,
	)
	segment["obstacle_slots"] = obstacle_slots
	segment["movement_axis"] = movement_axis
	segment["recommended_cycle_time"] = recommended_cycle_time
	segment["recommended_spacing"] = recommended_spacing
	segment["fallback_safe_lane"] = fallback_safe_lane
	segment["fallback_safe_lane_width"] = fallback_safe_lane_width
	return segment


static func _route_segment(
	segment_id: String,
	segment_type: String,
	length: float,
	total_width: float,
	height_delta: float,
	difficulty: int,
	required_assets: Array,
	optional_assets: Array,
	entry_width: float,
	exit_width: float,
	allows_fall_edges: bool,
	allows_moving_obstacles: bool,
	hazard_slots: int,
	safe_lane_count: int,
	notes: String = "",
	fall_risk_level: int = 0,
	recommended_oob_min_y: float = -999.0,
	recommended_camera_padding: float = 0.0,
	safe_floor_width_ratio: float = 1.0,
	branch_count: int = 1,
	branch_widths: Array = [],
	branch_offsets: Array = [],
	merge_offset: Vector3 = Vector3.ZERO,
	route_risk_level: int = 0,
	low_risk_branch_required: bool = true,
	min_recovery_after_merge: float = 8.0,
) -> Dictionary:
	var segment: Dictionary = _segment(
		segment_id,
		segment_type,
		length,
		total_width,
		height_delta,
		difficulty,
		required_assets,
		optional_assets,
		entry_width,
		exit_width,
		allows_fall_edges,
		allows_moving_obstacles,
		hazard_slots,
		safe_lane_count,
		notes,
		fall_risk_level,
		recommended_oob_min_y,
		recommended_camera_padding,
		safe_floor_width_ratio,
	)
	segment["total_width"] = total_width
	segment["branch_count"] = branch_count
	segment["branch_widths"] = branch_widths
	segment["branch_offsets"] = branch_offsets
	segment["merge_offset"] = merge_offset
	segment["route_risk_level"] = route_risk_level
	segment["low_risk_branch_required"] = low_risk_branch_required
	segment["min_recovery_after_merge"] = min_recovery_after_merge
	return segment
