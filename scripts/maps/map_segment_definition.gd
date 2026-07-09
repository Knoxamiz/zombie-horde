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
const TYPE_SIDE_DROP := "side_drop"
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
	TYPE_SPLIT_LANE,
	TYPE_MERGE_LANE,
	TYPE_MOVING_BLOCK_LANE,
	TYPE_HAZARD_LANE,
	TYPE_FINISH,
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
			"Visual gap with narrow safe plate; fall via OOB min-Y."
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
			"Small gap with narrow safe plate; requires fall_enabled."
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
			"Phase 1 finish straight; goal visual only."
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
	notes: String
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
		"notes": notes,
	}
