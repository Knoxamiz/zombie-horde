class_name MapAssetLibrary
extends RefCounted

## Approved reusable map parts for AI segment assembly.
## Visual GLTF assets are sanitized at build time; gameplay collision comes from safe-floor plates only.

enum Category {
	ROAD,
	BRIDGE,
	RAMP,
	GAP,
	DROP,
	RAIL,
	BARRIER,
	SUPPORT,
	WATER,
	HAZARD,
	MOVING_OBSTACLE,
	DECORATION,
	SPAWN,
	FINISH,
	UNKNOWN,
}

const CATEGORY_NAMES: Dictionary = {
	Category.ROAD: "road",
	Category.BRIDGE: "bridge",
	Category.RAMP: "ramp",
	Category.GAP: "gap",
	Category.DROP: "drop",
	Category.RAIL: "rail",
	Category.BARRIER: "barrier",
	Category.SUPPORT: "support",
	Category.WATER: "water",
	Category.HAZARD: "hazard",
	Category.MOVING_OBSTACLE: "moving_obstacle",
	Category.DECORATION: "decoration",
	Category.SPAWN: "spawn",
	Category.FINISH: "finish",
	Category.UNKNOWN: "unknown",
}

const KIT_ENV := "res://assets/third_party/zombie_apocalypse_kit/imported/Environment"

const PHASE4_ASSET_IDS: Array[String] = [
	"phase4_fork_road_left",
	"phase4_fork_road_right",
	"phase4_merge_road",
	"phase4_split_bridge",
	"phase4_side_bridge",
	"phase4_narrow_shortcut_bridge",
	"phase4_wide_safe_bridge",
	"phase4_high_path_ramp",
	"phase4_low_path_ramp",
	"phase4_divider_barrier",
	"phase4_route_sign_arrow",
	"phase4_lane_merge_marking",
	"phase4_split_guardrail",
	"phase4_side_support_pillar",
	"phase4_safe_floor_plate",
]

const PHASE3_ASSET_IDS: Array[String] = [
	"phase3_moving_block_crate",
	"phase3_moving_block_wide",
	"phase3_side_pusher",
	"phase3_pusher_plate",
	"phase3_crusher_plate",
	"phase3_crusher_frame",
	"phase3_rotating_arm",
	"phase3_sliding_wall",
	"phase3_timed_gate",
	"phase3_gate_barrier",
	"phase3_moving_platform",
	"phase3_platform_deck",
	"phase3_lane_blocker",
	"phase3_blocker_barrier",
	"phase3_warning_stripes",
	"phase3_warning_light",
	"phase3_deco_sparks",
	"phase3_safe_lane_marker",
]

const DROP_AND_PLAY_OBSTACLE_ASSET_IDS: Array[String] = [
	"dp_moving_block_side_to_side",
	"dp_side_pusher_wall",
	"dp_timed_gate",
	"dp_crusher_block",
	"dp_rotating_arm",
]

const PHASE2_ASSET_IDS: Array[String] = [
	"phase2_gap_edge_left",
	"phase2_gap_edge_right",
	"phase2_broken_bridge_gap",
	"phase2_cracked_road_edge",
	"phase2_drop_off_section",
	"phase2_elevated_bridge_deck",
	"phase2_water_river_plane",
	"phase2_void_floor_visual",
	"phase2_warning_stripes",
	"phase2_broken_guardrail",
	"phase2_missing_rail_section",
	"phase2_side_fall_opening",
	"phase2_support_pillar",
	"phase2_lower_river_catch",
	"phase2_deco_debris",
	"phase2_edge_cone",
	"phase2_edge_light",
	"phase2_safe_floor_plate",
]

const PHASE1_ASSET_IDS: Array[String] = [
	"phase1_road_straight_8",
	"phase1_road_cracked_light",
	"phase1_road_cracked_heavy",
	"phase1_bridge_deck_8",
	"phase1_safe_floor_plate",
	"phase1_ramp_surface_8",
	"phase1_rail_traffic_a",
	"phase1_rail_traffic_b",
	"phase1_barrier_plastic",
	"phase1_support_pillar",
	"phase1_support_cinder",
	"phase1_water_river",
	"phase1_water_segment",
	"phase1_gap_void",
	"phase1_drop_lip",
	"phase1_broken_edge_light",
	"phase1_broken_edge_heavy",
	"phase1_deco_cone",
	"phase1_deco_light",
	"phase1_deco_barrel",
	"phase1_deco_pipes",
	"phase1_deco_pallet",
	"phase1_spawn_marker",
	"phase1_finish_marker",
]

static var _assets_cache: Array[Dictionary] = []


static func has_asset(asset_id: String) -> bool:
	return not get_asset(asset_id).is_empty()


static func get_asset(asset_id: String) -> Dictionary:
	for entry in _assets():
		if str(entry.get("asset_id", "")) == asset_id:
			return entry.duplicate(true)
	return {}


static func get_assets_by_category(category: int) -> Array[Dictionary]:
	var matches: Array[Dictionary] = []
	for entry in _assets():
		if int(entry.get("category", Category.UNKNOWN)) == category:
			matches.append(entry.duplicate(true))
	return matches


static func get_phase1_asset_ids() -> Array[String]:
	return PHASE1_ASSET_IDS.duplicate()


static func is_phase1_asset(asset_id: String) -> bool:
	return asset_id in PHASE1_ASSET_IDS


static func validate_phase1_assets() -> Dictionary:
	var result: Dictionary = {"ok": true, "missing": []}
	for asset_id in PHASE1_ASSET_IDS:
		if not has_asset(asset_id):
			result["ok"] = false
			result["missing"].append(asset_id)
	return result


static func get_phase2_asset_ids() -> Array[String]:
	return PHASE2_ASSET_IDS.duplicate()


static func is_phase2_asset(asset_id: String) -> bool:
	return asset_id in PHASE2_ASSET_IDS


static func validate_phase2_assets() -> Dictionary:
	var result: Dictionary = {"ok": true, "missing": []}
	for asset_id in PHASE2_ASSET_IDS:
		if not has_asset(asset_id):
			result["ok"] = false
			result["missing"].append(asset_id)
	return result


static func get_phase3_asset_ids() -> Array[String]:
	return PHASE3_ASSET_IDS.duplicate()


static func get_drop_and_play_obstacle_asset_ids() -> Array[String]:
	return DROP_AND_PLAY_OBSTACLE_ASSET_IDS.duplicate()


static func is_drop_and_play_obstacle_asset(asset_id: String) -> bool:
	return asset_id in DROP_AND_PLAY_OBSTACLE_ASSET_IDS


static func is_phase3_asset(asset_id: String) -> bool:
	return asset_id in PHASE3_ASSET_IDS


static func validate_phase3_assets() -> Dictionary:
	var result: Dictionary = {"ok": true, "missing": []}
	for asset_id in PHASE3_ASSET_IDS:
		if not has_asset(asset_id):
			result["ok"] = false
			result["missing"].append(asset_id)
	return result


static func get_phase4_asset_ids() -> Array[String]:
	return PHASE4_ASSET_IDS.duplicate()


static func is_phase4_asset(asset_id: String) -> bool:
	return asset_id in PHASE4_ASSET_IDS


static func validate_phase4_assets() -> Dictionary:
	var result: Dictionary = {"ok": true, "missing": []}
	for asset_id in PHASE4_ASSET_IDS:
		if not has_asset(asset_id):
			result["ok"] = false
			result["missing"].append(asset_id)
	return result


static func is_moving_obstacle_asset(asset_id: String) -> bool:
	var entry: Dictionary = get_asset(asset_id)
	return bool(entry.get("supports_moving", false)) or not str(entry.get("movement_category", "")).is_empty()


static func instantiate_moving_obstacle(asset_id: String, cycle_override: float = 0.0) -> Node3D:
	const MapMovingObstacleScript := preload("res://scripts/maps/obstacles/map_moving_obstacle.gd")
	var entry: Dictionary = get_asset(asset_id)
	if entry.is_empty():
		push_warning("MapAssetLibrary: missing moving asset_id=%s" % asset_id)
		return null

	var scene_path: String = str(entry.get("scene_path", ""))
	if scene_path.ends_with(".tscn") and ResourceLoader.exists(scene_path):
		var packed: PackedScene = load(scene_path) as PackedScene
		if packed != null:
			var scene_instance: Node = packed.instantiate()
			if scene_instance.has_method("configure_from_asset"):
				scene_instance.configure_from_asset(entry, cycle_override)
				return scene_instance as Node3D
			if scene_instance != null:
				scene_instance.queue_free()
			push_warning(
				"MapAssetLibrary: obstacle scene '%s' must root MapMovingObstacle (asset=%s)"
				% [scene_path, asset_id]
			)

	var obstacle = MapMovingObstacleScript.new()
	obstacle.configure_from_asset(entry, cycle_override)
	var visual: Node3D = instantiate_visual(asset_id)
	var collision_size := Vector3(
		float(entry.get("approximate_width", 2.0)),
		float(entry.get("approximate_height", 2.0)),
		float(entry.get("approximate_length", 2.0)),
	)
	MapMovingObstacleScript.attach_visual(obstacle, visual, collision_size)
	return obstacle


static func get_all_asset_ids() -> Array[String]:
	var ids: Array[String] = []
	for entry in _assets():
		ids.append(str(entry.get("asset_id", "")))
	return ids


static func instantiate_visual(asset_id: String) -> Node3D:
	var entry: Dictionary = get_asset(asset_id)
	if entry.is_empty():
		push_warning("MapAssetLibrary: missing asset_id=%s" % asset_id)
		return null
	if bool(entry.get("is_visual_only", true)) and not bool(entry.get("has_collision", false)):
		var scene_path: String = str(entry.get("scene_path", ""))
		if scene_path.is_empty() or not ResourceLoader.exists(scene_path):
			return _instantiate_procedural(entry)
		if not scene_path.ends_with(".gltf"):
			return _instantiate_procedural(entry)
		var packed: PackedScene = load(scene_path) as PackedScene
		if packed == null:
			return null
		var instance: Node3D = packed.instantiate() as Node3D
		if instance == null:
			return null
		var default_scale: float = float(entry.get("default_scale", 1.0))
		instance.scale = Vector3.ONE * default_scale
		instance.rotation_degrees = entry.get("default_rotation", Vector3.ZERO)
		_sanitize_visual_collision(instance)
		return instance
	return _instantiate_procedural(entry)


static func get_audit_report() -> Dictionary:
	var report: Dictionary = {
		"total_assets": _assets().size(),
		"by_category": {},
		"existing": [],
		"missing_paths": [],
		"missing_categories": [],
		"notes": [],
	}
	for category in CATEGORY_NAMES.keys():
		report["by_category"][CATEGORY_NAMES[category]] = 0

	for entry in _assets():
		var category_name: String = CATEGORY_NAMES.get(int(entry.get("category", Category.UNKNOWN)), "unknown")
		report["by_category"][category_name] = int(report["by_category"].get(category_name, 0)) + 1
		var scene_path: String = str(entry.get("scene_path", ""))
		var path_exists: bool = scene_path.is_empty() or ResourceLoader.exists(scene_path)
		var row: Dictionary = {
			"asset_id": entry.get("asset_id", ""),
			"category": category_name,
			"path_exists": path_exists,
			"scene_path": scene_path,
		}
		report["existing"].append(row)
		if not path_exists:
			report["missing_paths"].append(row)

	var required_categories: Array[String] = [
		"road", "bridge", "ramp", "gap", "drop", "rail", "barrier", "support",
		"water", "hazard", "moving_obstacle", "decoration", "spawn", "finish",
	]
	for category_name in required_categories:
		if int(report["by_category"].get(category_name, 0)) <= 0:
			report["missing_categories"].append(category_name)

	report["notes"] = [
		"Phase 4 pack: %d canonical split/merge route assets (phase4_* ids)." % PHASE4_ASSET_IDS.size(),
		"Phase 3 pack: %d canonical moving obstacle assets (phase3_* ids)." % PHASE3_ASSET_IDS.size(),
		"Phase 2 pack: %d canonical assets (phase2_* ids)." % PHASE2_ASSET_IDS.size(),
		"Phase 1 pack: %d canonical assets (phase1_* ids)." % PHASE1_ASSET_IDS.size(),
		"Road/bridge deck collision is procedural (safe_floor_plate / phase1_safe_floor_plate).",
		"Dedicated ramp GLTF meshes are missing; phase1_ramp_surface_8 is procedural.",
		"No certified moving-obstacle prefabs in Phase 1 (deferred to later packs).",
		"Finish authority remains World/StreamerBase; markers are visual-only.",
		"Water visuals are procedural; void death is Zombie._check_out_of_bounds only.",
		"Missing for rich maps: curved road GLTF, dedicated bridge parapet meshes, art themes.",
	]
	return report


static func print_audit_report() -> void:
	var report: Dictionary = get_audit_report()
	print("=== Map Asset Library Audit ===")
	print("Total approved assets: %d" % int(report.get("total_assets", 0)))
	print("By category: %s" % str(report.get("by_category", {})))
	for row in report.get("missing_paths", []):
		print("MISSING PATH: %s -> %s" % [row.get("asset_id", ""), row.get("scene_path", "")])
	if not report.get("missing_categories", []).is_empty():
		print("Sparse categories (procedural placeholders used): %s" % str(report.get("missing_categories", [])))
	for note in report.get("notes", []):
		print("NOTE: %s" % note)


static func _assets() -> Array[Dictionary]:
	if _assets_cache.is_empty():
		_assets_cache = _build_assets()
	return _assets_cache


static func _build_assets() -> Array[Dictionary]:
	return [
		_entry(
			"street_straight", "Street Straight", Category.ROAD,
			"%s/Street_Straight.gltf" % KIT_ENV,
			8.0, 8.0, 0.2, Vector3(0, 0, -4), Vector3(0, 0, 4), 0.0,
			false, true, false, false,
			"Primary straight road tile from zombie kit."
		),
		_entry(
			"street_crack1", "Street Crack 1", Category.ROAD,
			"%s/Street_Straight_Crack1.gltf" % KIT_ENV,
			8.0, 8.0, 0.2, Vector3(0, 0, -4), Vector3(0, 0, 4), 0.0,
			false, true, false, false,
			"Damaged road surface for bridge lips and hazard lanes."
		),
		_entry(
			"street_crack2", "Street Crack 2", Category.ROAD,
			"%s/Street_Straight_Crack2.gltf" % KIT_ENV,
			8.0, 8.0, 0.2, Vector3(0, 0, -4), Vector3(0, 0, 4), 0.0,
			false, true, false, false,
			"Heavier crack variant for gap edges."
		),
		_entry(
			"street_turn", "Street Turn", Category.ROAD,
			"%s/Street_Turn.gltf" % KIT_ENV,
			8.0, 8.0, 0.2, Vector3(0, 0, -4), Vector3(0, 0, 4), 0.0,
			false, true, false, false,
			"Turn piece; use only when segment grammar allows bends."
		),
		_entry(
			"bridge_deck_plate", "Bridge Deck Plate", Category.BRIDGE,
			"",
			8.0, 10.0, 0.16, Vector3(0, 0, -4), Vector3(0, 0, 4), 0.0,
			true, true, true, false,
			"Procedural deck plate; gameplay collision via safe_floor_plate in builder."
		),
		_entry(
			"ramp_box", "Ramp Box", Category.RAMP,
			"",
			8.0, 10.0, 1.0, Vector3(0, 0, -4), Vector3(0, 0.8, 4), 0.0,
			true, true, false, false,
			"Procedural ramp visual until dedicated ramp GLTF exists."
		),
		_entry(
			"gap_void_visual", "Gap Void Visual", Category.GAP,
			"",
			8.0, 10.0, 0.1, Vector3(0, 0, -4), Vector3(0, 0, 4), -0.5,
			false, true, true, false,
			"Visual drop slot; fall authority is zombie min-Y only."
		),
		_entry(
			"drop_lip", "Drop Lip", Category.DROP,
			"%s/Street_Straight_Crack2.gltf" % KIT_ENV,
			8.0, 8.0, 0.2, Vector3(0, 0, -4), Vector3(0, -0.4, 4), 0.0,
			false, true, true, false,
			"Broken edge lip before a drop segment."
		),
		_entry(
			"traffic_barrier_1", "Traffic Barrier 1", Category.RAIL,
			"%s/TrafficBarrier_1.gltf" % KIT_ENV,
			2.5, 0.4, 1.0, Vector3(0, 0, -1.25), Vector3(0, 0, 1.25), 0.0,
			false, true, false, false,
			"Parapet / edge rail candidate."
		),
		_entry(
			"traffic_barrier_2", "Traffic Barrier 2", Category.RAIL,
			"%s/TrafficBarrier_2.gltf" % KIT_ENV,
			2.5, 0.4, 1.0, Vector3(0, 0, -1.25), Vector3(0, 0, 1.25), 0.0,
			false, true, false, false,
			"Alternate rail mesh."
		),
		_entry(
			"plastic_barrier", "Plastic Barrier", Category.BARRIER,
			"%s/PlasticBarrier.gltf" % KIT_ENV,
			2.0, 0.5, 1.2, Vector3(0, 0, -1), Vector3(0, 0, 1), 0.0,
			false, true, false, false,
			"Lane divider / soft barrier."
		),
		_entry(
			"support_pillar", "Support Pillar", Category.SUPPORT,
			"%s/CinderBlock.gltf" % KIT_ENV,
			1.05, 1.05, 4.0, Vector3.ZERO, Vector3.ZERO, -2.0,
			false, true, false, false,
			"Placeholder pillar until dedicated bridge support GLTF is authored."
		),
		_entry(
			"water_void_plane", "Water Void Plane", Category.WATER,
			"",
			40.0, 0.08, 80.0, Vector3.ZERO, Vector3.ZERO, -4.0,
			false, true, true, false,
			"Procedural void water visual; never authoritative kill volume."
		),
		_entry(
			"hazard_warning_plane", "Hazard Warning Plane", Category.HAZARD,
			"res://assets/materials/obstacle_warning.tres",
			8.0, 8.0, 0.05, Vector3.ZERO, Vector3.ZERO, 0.02,
			false, true, false, false,
			"Debug/hazard marker material only."
		),
		_entry(
			"moving_block_slot", "Moving Block Slot", Category.MOVING_OBSTACLE,
			"%s/Container_Red.gltf" % KIT_ENV,
			3.0, 6.0, 2.6, Vector3(0, 0, -3), Vector3(0, 0, 3), 0.0,
			false, true, false, true,
			"Placeholder for future MapLab sim mover; not wired to gameplay yet."
		),
		_entry(
			"traffic_cone_1", "Traffic Cone 1", Category.DECORATION,
			"%s/TrafficCone_1.gltf" % KIT_ENV,
			0.6, 0.6, 0.8, Vector3.ZERO, Vector3.ZERO, 0.0,
			false, true, false, false,
			"Lane guide decoration."
		),
		_entry(
			"street_light", "Street Light", Category.DECORATION,
			"%s/StreetLights.gltf" % KIT_ENV,
			1.0, 1.0, 4.5, Vector3.ZERO, Vector3.ZERO, 0.0,
			false, true, false, false,
			"Roadside light prop."
		),
		_entry(
			"container_red", "Container Red", Category.DECORATION,
			"%s/Container_Red.gltf" % KIT_ENV,
			6.0, 3.0, 2.6, Vector3.ZERO, Vector3.ZERO, 0.0,
			false, true, false, false,
			"Large void-side prop."
		),
		_entry(
			"pallet_broken", "Broken Pallet", Category.DECORATION,
			"%s/Pallet_Broken.gltf" % KIT_ENV,
			1.2, 1.6, 0.4, Vector3.ZERO, Vector3.ZERO, 0.0,
			false, true, false, false,
			"Small debris dressing."
		),
		_entry(
			"spawn_marker", "Spawn Marker", Category.SPAWN,
			"res://assets/materials/spawn_zone.tres",
			10.0, 4.0, 0.06, Vector3(0, 0, -2), Vector3(0, 0, 2), 0.12,
			false, true, false, false,
			"Visual spawn band only; spawn_origin comes from RaceMapDefinition."
		),
		_entry(
			"finish_marker", "Finish Marker", Category.FINISH,
			"res://assets/materials/goal_zone.tres",
			10.0, 4.0, 0.06, Vector3(0, 0, -2), Vector3(0, 0, 2), 0.13,
			false, true, false, false,
			"Visual goal band only; finish authority is World/StreamerBase."
		),
		_entry(
			"safe_floor_plate", "Safe Floor Plate", Category.BRIDGE,
			"",
			8.0, 10.0, 0.12, Vector3(0, 0, -4), Vector3(0, 0, 4), -0.06,
			true, false, true, false,
			"Authoritative walk collision; builder-owned procedural mesh."
		),
		# --- Phase 1 canonical asset pack ---
		_entry(
			"phase1_road_straight_8", "P1 Road Straight 8m", Category.ROAD,
			"%s/Street_Straight.gltf" % KIT_ENV,
			8.0, 8.0, 0.2, Vector3(0, 0, -4), Vector3(0, 0, 4), 0.0,
			false, true, false, false,
			"Phase 1 primary straight road tile."
		),
		_entry(
			"phase1_road_cracked_light", "P1 Road Cracked Light", Category.ROAD,
			"%s/Street_Straight_Crack1.gltf" % KIT_ENV,
			8.0, 8.0, 0.2, Vector3(0, 0, -4), Vector3(0, 0, 4), 0.0,
			false, true, false, false,
			"Light damage road surface."
		),
		_entry(
			"phase1_road_cracked_heavy", "P1 Road Cracked Heavy", Category.ROAD,
			"%s/Street_Straight_Crack2.gltf" % KIT_ENV,
			8.0, 8.0, 0.2, Vector3(0, 0, -4), Vector3(0, 0, 4), 0.0,
			false, true, false, false,
			"Heavy crack road for gap lips and broken edges."
		),
		_entry(
			"phase1_bridge_deck_8", "P1 Bridge Deck 8m", Category.BRIDGE,
			"",
			8.0, 10.0, 0.16, Vector3(0, 0, -4), Vector3(0, 0, 4), 0.0,
			false, true, true, false,
			"Procedural bridge deck visual; collision via safe floor plate."
		),
		_entry(
			"phase1_safe_floor_plate", "P1 Safe Floor Plate", Category.BRIDGE,
			"",
			8.0, 10.0, 0.12, Vector3(0, 0, -4), Vector3(0, 0, 4), -0.06,
			true, false, true, false,
			"Phase 1 authoritative walk collision plate."
		),
		_entry(
			"phase1_ramp_surface_8", "P1 Ramp Surface 8m", Category.RAMP,
			"",
			8.0, 10.0, 0.8, Vector3(0, 0, -4), Vector3(0, 0.8, 4), 0.0,
			false, true, false, false,
			"Procedural ramp visual; height_delta comes from segment."
		),
		_entry(
			"phase1_rail_traffic_a", "P1 Rail Traffic A", Category.RAIL,
			"%s/TrafficBarrier_1.gltf" % KIT_ENV,
			2.5, 0.4, 1.0, Vector3(0, 0, -1.25), Vector3(0, 0, 1.25), 0.0,
			false, true, false, false,
			"Bridge parapet / guardrail visual."
		),
		_entry(
			"phase1_rail_traffic_b", "P1 Rail Traffic B", Category.RAIL,
			"%s/TrafficBarrier_2.gltf" % KIT_ENV,
			2.5, 0.4, 1.0, Vector3(0, 0, -1.25), Vector3(0, 0, 1.25), 0.0,
			false, true, false, false,
			"Alternate bridge rail visual."
		),
		_entry(
			"phase1_barrier_plastic", "P1 Barrier Plastic", Category.BARRIER,
			"%s/PlasticBarrier.gltf" % KIT_ENV,
			2.0, 0.5, 1.2, Vector3(0, 0, -1), Vector3(0, 0, 1), 0.0,
			false, true, false, false,
			"Lane-edge soft barrier visual."
		),
		_entry(
			"phase1_support_pillar", "P1 Support Pillar", Category.SUPPORT,
			"",
			1.05, 1.05, 4.0, Vector3.ZERO, Vector3.ZERO, -2.0,
			false, true, false, false,
			"Procedural bridge support column."
		),
		_entry(
			"phase1_support_cinder", "P1 Support Cinder Block", Category.SUPPORT,
			"%s/CinderBlock.gltf" % KIT_ENV,
			1.2, 0.8, 0.5, Vector3.ZERO, Vector3.ZERO, -0.25,
			false, true, false, false,
			"Kit cinder block support prop."
		),
		_entry(
			"phase1_water_river", "P1 Water River", Category.WATER,
			"",
			40.0, 0.08, 80.0, Vector3.ZERO, Vector3.ZERO, -4.0,
			false, true, true, false,
			"Route-wide void water visual; never authoritative kill."
		),
		_entry(
			"phase1_water_segment", "P1 Water Segment", Category.WATER,
			"",
			12.0, 0.08, 10.0, Vector3.ZERO, Vector3.ZERO, -3.5,
			false, true, true, false,
			"Per-segment void water under gaps/bridge."
		),
		_entry(
			"phase1_gap_void", "P1 Gap Void", Category.GAP,
			"",
			8.0, 10.0, 0.1, Vector3(0, 0, -4), Vector3(0, 0, 4), -0.5,
			false, true, true, false,
			"Visual void slot for small_gap segments."
		),
		_entry(
			"phase1_drop_lip", "P1 Drop Lip", Category.DROP,
			"%s/Street_Straight_Crack2.gltf" % KIT_ENV,
			8.0, 8.0, 0.2, Vector3(0, 0, -4), Vector3(0, -0.4, 4), 0.0,
			false, true, true, false,
			"Broken lip before a height drop."
		),
		_entry(
			"phase1_broken_edge_light", "P1 Broken Edge Light", Category.DROP,
			"%s/Street_Straight_Crack1.gltf" % KIT_ENV,
			8.0, 8.0, 0.2, Vector3(0, 0, -4), Vector3(0, -0.2, 4), 0.0,
			false, true, true, false,
			"Side fall-edge lip visual (light crack)."
		),
		_entry(
			"phase1_broken_edge_heavy", "P1 Broken Edge Heavy", Category.DROP,
			"%s/Street_Straight_Crack2.gltf" % KIT_ENV,
			8.0, 8.0, 0.2, Vector3(0, 0, -4), Vector3(0, -0.4, 4), 0.0,
			false, true, true, false,
			"Side fall-edge lip visual (heavy crack)."
		),
		_entry(
			"phase1_deco_cone", "P1 Deco Cone", Category.DECORATION,
			"%s/TrafficCone_1.gltf" % KIT_ENV,
			0.6, 0.6, 0.8, Vector3.ZERO, Vector3.ZERO, 0.0,
			false, true, false, false,
			"Lane guide cone."
		),
		_entry(
			"phase1_deco_light", "P1 Deco Street Light", Category.DECORATION,
			"%s/StreetLights.gltf" % KIT_ENV,
			1.0, 1.0, 4.5, Vector3.ZERO, Vector3.ZERO, 0.0,
			false, true, false, false,
			"Roadside light prop."
		),
		_entry(
			"phase1_deco_barrel", "P1 Deco Barrel", Category.DECORATION,
			"%s/Barrel.gltf" % KIT_ENV,
			0.7, 0.7, 1.0, Vector3.ZERO, Vector3.ZERO, 0.0,
			false, true, false, false,
			"Void-side barrel prop."
		),
		_entry(
			"phase1_deco_pipes", "P1 Deco Pipes", Category.DECORATION,
			"%s/Pipes.gltf" % KIT_ENV,
			2.5, 2.5, 0.8, Vector3.ZERO, Vector3.ZERO, 0.0,
			false, true, false, false,
			"Industrial pipe debris."
		),
		_entry(
			"phase1_deco_pallet", "P1 Deco Pallet", Category.DECORATION,
			"%s/Pallet_Broken.gltf" % KIT_ENV,
			1.2, 1.6, 0.4, Vector3.ZERO, Vector3.ZERO, 0.0,
			false, true, false, false,
			"Broken pallet debris."
		),
		_entry(
			"phase1_spawn_marker", "P1 Spawn Marker", Category.SPAWN,
			"res://assets/materials/spawn_zone.tres",
			10.0, 4.0, 0.06, Vector3(0, 0, -2), Vector3(0, 0, 2), 0.12,
			false, true, false, false,
			"Phase 1 spawn band visual only."
		),
		_entry(
			"phase1_finish_marker", "P1 Finish Marker", Category.FINISH,
			"res://assets/materials/goal_zone.tres",
			10.0, 4.0, 0.06, Vector3(0, 0, -2), Vector3(0, 0, 2), 0.13,
			false, true, false, false,
			"Phase 1 goal band visual only; finish is StreamerBase."
		),
		# --- Phase 2 drop/fall/gap asset pack ---
		_entry(
			"phase2_gap_edge_left", "P2 Gap Edge Left", Category.GAP,
			"%s/Street_Straight_Crack2.gltf" % KIT_ENV,
			8.0, 2.0, 0.2, Vector3(-3, 0, -4), Vector3(-3, 0, 4), 0.0,
			false, true, true, false,
			"Left lip before a center gap; visual only."
		),
		_entry(
			"phase2_gap_edge_right", "P2 Gap Edge Right", Category.GAP,
			"%s/Street_Straight_Crack2.gltf" % KIT_ENV,
			8.0, 2.0, 0.2, Vector3(3, 0, -4), Vector3(3, 0, 4), 0.0,
			false, true, true, false,
			"Right lip before a center gap; visual only."
		),
		_entry(
			"phase2_broken_bridge_gap", "P2 Broken Bridge Gap", Category.GAP,
			"",
			8.0, 10.0, 0.1, Vector3(0, 0, -4), Vector3(0, 0, 4), -0.5,
			false, true, true, false,
			"Broken bridge void slot; fall via OOB min-Y only."
		),
		_entry(
			"phase2_cracked_road_edge", "P2 Cracked Road Edge", Category.ROAD,
			"%s/Street_Straight_Crack1.gltf" % KIT_ENV,
			8.0, 3.0, 0.2, Vector3(0, 0, -4), Vector3(0, 0, 4), 0.0,
			false, true, true, false,
			"Cracked pavement edge lane; visual hazard cue."
		),
		_entry(
			"phase2_drop_off_section", "P2 Drop Off Section", Category.DROP,
			"%s/Street_Straight_Crack2.gltf" % KIT_ENV,
			8.0, 8.0, 0.2, Vector3(0, 0, -4), Vector3(0, -0.4, 4), 0.0,
			false, true, true, false,
			"Deck lip before a height drop segment."
		),
		_entry(
			"phase2_elevated_bridge_deck", "P2 Elevated Bridge Deck", Category.BRIDGE,
			"",
			8.0, 10.0, 0.16, Vector3(0, 0, -4), Vector3(0, 0, 4), 0.0,
			false, true, true, false,
			"Elevated bridge deck visual; collision via safe floor plate."
		),
		_entry(
			"phase2_water_river_plane", "P2 Water River Plane", Category.WATER,
			"",
			40.0, 0.08, 80.0, Vector3.ZERO, Vector3.ZERO, -4.0,
			false, true, true, false,
			"Route-wide river visual below elevated deck; never authoritative kill."
		),
		_entry(
			"phase2_void_floor_visual", "P2 Void Floor Visual", Category.WATER,
			"",
			12.0, 0.08, 10.0, Vector3.ZERO, Vector3.ZERO, -3.5,
			false, true, true, false,
			"Per-segment void floor under gaps/drops; visual only."
		),
		_entry(
			"phase2_warning_stripes", "P2 Warning Stripes", Category.HAZARD,
			"res://assets/materials/obstacle_warning.tres",
			8.0, 8.0, 0.05, Vector3.ZERO, Vector3.ZERO, 0.02,
			false, true, false, false,
			"Warning paint before gaps; visual readability helper."
		),
		_entry(
			"phase2_broken_guardrail", "P2 Broken Guardrail", Category.RAIL,
			"%s/TrafficBarrier_1.gltf" % KIT_ENV,
			2.5, 0.4, 0.6, Vector3(0, 0, -1.25), Vector3(0, 0, 1.25), 0.0,
			false, true, true, false,
			"Broken parapet section; collision sanitized."
		),
		_entry(
			"phase2_missing_rail_section", "P2 Missing Rail Section", Category.RAIL,
			"",
			2.5, 0.4, 0.1, Vector3.ZERO, Vector3.ZERO, 0.0,
			false, true, true, false,
			"Empty rail slot marker; signals missing guardrail."
		),
		_entry(
			"phase2_side_fall_opening", "P2 Side Fall Opening", Category.DROP,
			"%s/Street_Straight_Crack2.gltf" % KIT_ENV,
			8.0, 3.0, 0.2, Vector3(0, 0, -4), Vector3(0, -0.3, 4), 0.0,
			false, true, true, false,
			"Side fall opening lip; center lane remains safe."
		),
		_entry(
			"phase2_support_pillar", "P2 Support Pillar", Category.SUPPORT,
			"%s/CinderBlock.gltf" % KIT_ENV,
			1.05, 1.05, 4.0, Vector3.ZERO, Vector3.ZERO, -2.0,
			false, true, false, false,
			"Bridge/elevated support column prop."
		),
		_entry(
			"phase2_lower_river_catch", "P2 Lower River Catch", Category.WATER,
			"",
			16.0, 0.12, 12.0, Vector3.ZERO, Vector3.ZERO, -5.0,
			false, true, true, false,
			"Lower catch basin visual below drops; never authoritative kill."
		),
		_entry(
			"phase2_deco_debris", "P2 Deco Debris", Category.DECORATION,
			"%s/Pallet_Broken.gltf" % KIT_ENV,
			1.2, 1.6, 0.4, Vector3.ZERO, Vector3.ZERO, 0.0,
			false, true, false, false,
			"Void-side decorative debris."
		),
		_entry(
			"phase2_edge_cone", "P2 Edge Cone", Category.DECORATION,
			"%s/TrafficCone_1.gltf" % KIT_ENV,
			0.6, 0.6, 0.8, Vector3.ZERO, Vector3.ZERO, 0.0,
			false, true, false, false,
			"Edge cone for gap/drop readability."
		),
		_entry(
			"phase2_edge_light", "P2 Edge Light", Category.DECORATION,
			"%s/StreetLights.gltf" % KIT_ENV,
			1.0, 1.0, 4.5, Vector3.ZERO, Vector3.ZERO, 0.0,
			false, true, false, false,
			"Edge light prop before dangerous sections."
		),
		_entry(
			"phase2_safe_floor_plate", "P2 Safe Floor Plate", Category.BRIDGE,
			"",
			8.0, 10.0, 0.12, Vector3(0, 0, -4), Vector3(0, 0, 4), -0.06,
			true, false, false, false,
			"Phase 2 authoritative walk collision plate."
		),
		# --- Phase 3 moving obstacle asset pack ---
		_moving_entry(
			"phase3_moving_block_crate", "P3 Moving Block Crate", "moving_obstacle", Category.MOVING_OBSTACLE,
			"res://scenes/maps/obstacles/moving_block_side_to_side.tscn",
			3.0, 2.4, 2.6, Vector3(0, 0, -1.5), Vector3(0, 0, 1.5), 0.0,
			true, false,
			"ping_pong", "x", 2.8, 4.0, 0.0,
			"kinematic_block", "block",
			"Lane-moving crate; leaves center safe lane open.",
			true, true
		),
		_moving_entry(
			"phase3_moving_block_wide", "P3 Moving Block Wide", "moving_obstacle", Category.MOVING_OBSTACLE,
			"%s/Container_Green.gltf" % KIT_ENV,
			4.0, 3.0, 2.6, Vector3(0, 0, -2), Vector3(0, 0, 2), 0.0,
			true, false,
			"ping_pong", "x", 2.2, 5.0, 0.25,
			"kinematic_block", "block",
			"Wide moving block for slalom lanes."
		),
		_moving_entry(
			"phase3_side_pusher", "P3 Side Pusher", "pusher", Category.MOVING_OBSTACLE,
			"res://scenes/maps/obstacles/side_pusher_wall.tscn",
			2.0, 0.6, 1.2, Vector3(0, 0, -1), Vector3(0, 0, 1), 0.0,
			true, false,
			"ping_pong", "x", 2.0, 3.5, 0.0,
			"kinematic_push", "push",
			"Side lane pusher; physics push only, no direct kill.",
			true, true
		),
		_moving_entry(
			"phase3_pusher_plate", "P3 Pusher Plate", "pusher", Category.MOVING_OBSTACLE,
			"",
			2.5, 0.4, 1.4, Vector3.ZERO, Vector3.ZERO, 0.0,
			true, false,
			"linear", "x", 1.8, 3.0, 0.5,
			"kinematic_push", "push",
			"Procedural pusher plate for side_pusher_lane segments."
		),
		_moving_entry(
			"phase3_crusher_plate", "P3 Crusher Plate", "crusher", Category.MOVING_OBSTACLE,
			"res://scenes/maps/obstacles/crusher_block.tscn",
			3.0, 3.0, 0.5, Vector3.ZERO, Vector3.ZERO, 1.2,
			true, false,
			"ping_pong", "y", 1.0, 4.5, 0.0,
			"kinematic_crush", "prototype",
			"Overhead crusher plate; blocks lane briefly, no authoritative kill.",
			true, true
		),
		_moving_entry(
			"phase3_crusher_frame", "P3 Crusher Frame", "crusher", Category.DECORATION,
			"%s/Pipes.gltf" % KIT_ENV,
			2.5, 2.5, 2.5, Vector3.ZERO, Vector3.ZERO, 1.5,
			false, true,
			"rotation", "z", 0.0, 6.0, 0.0,
			"visual_only", "none",
			"Crusher frame visual; collision sanitized."
		),
		_moving_entry(
			"phase3_rotating_arm", "P3 Rotating Arm", "rotating_arm", Category.MOVING_OBSTACLE,
			"res://scenes/maps/obstacles/rotating_arm.tscn",
			4.0, 0.5, 0.5, Vector3.ZERO, Vector3.ZERO, 1.2,
			true, false,
			"rotation", "y", 3.5, 5.0, 0.0,
			"kinematic_sweep", "block",
			"Rotating sweep arm over bridge segment.",
			true, true
		),
		_moving_entry(
			"phase3_sliding_wall", "P3 Sliding Wall", "sliding_wall", Category.MOVING_OBSTACLE,
			"%s/Container_Red.gltf" % KIT_ENV,
			1.5, 6.0, 2.6, Vector3(0, 0, -3), Vector3(0, 0, 3), 0.0,
			true, false,
			"ping_pong", "z", 2.5, 4.0, 0.0,
			"kinematic_block", "block",
			"Wall sliding along segment length."
		),
		_moving_entry(
			"phase3_timed_gate", "P3 Timed Gate", "timed_gate", Category.MOVING_OBSTACLE,
			"res://scenes/maps/obstacles/timed_gate.tscn",
			2.5, 0.4, 1.0, Vector3(0, 0, -1.25), Vector3(0, 0, 1.25), 0.0,
			true, false,
			"gate", "x", 3.2, 6.0, 0.0,
			"kinematic_gate", "timing",
			"Timed gate that opens/closes lane; always leaves safe window.",
			true, true
		),
		_moving_entry(
			"phase3_gate_barrier", "P3 Gate Barrier", "timed_gate", Category.BARRIER,
			"%s/TrafficBarrier_2.gltf" % KIT_ENV,
			2.5, 0.4, 1.0, Vector3.ZERO, Vector3.ZERO, 0.0,
			false, true,
			"ping_pong", "x", 2.5, 6.0, 0.5,
			"visual_only", "gate",
			"Gate barrier visual companion."
		),
		_moving_entry(
			"phase3_moving_platform", "P3 Moving Platform", "moving_platform", Category.MOVING_OBSTACLE,
			"%s/Pallet.gltf" % KIT_ENV,
			2.0, 2.0, 0.4, Vector3.ZERO, Vector3.ZERO, 0.0,
			true, false,
			"ping_pong", "y", 0.6, 5.0, 0.0,
			"kinematic_platform", "platform",
			"Vertical moving platform over gap slots."
		),
		_moving_entry(
			"phase3_platform_deck", "P3 Platform Deck", "moving_platform", Category.MOVING_OBSTACLE,
			"",
			3.0, 2.5, 0.2, Vector3.ZERO, Vector3.ZERO, 0.0,
			true, false,
			"ping_pong", "y", 0.8, 4.5, 0.25,
			"kinematic_platform", "platform",
			"Procedural platform deck for moving_platform_gap."
		),
		_moving_entry(
			"phase3_lane_blocker", "P3 Lane Blocker", "blocker", Category.MOVING_OBSTACLE,
			"%s/CinderBlock.gltf" % KIT_ENV,
			1.2, 0.8, 0.8, Vector3.ZERO, Vector3.ZERO, 0.0,
			true, false,
			"ping_pong", "x", 1.5, 3.5, 0.0,
			"kinematic_block", "block",
			"Small timed lane blocker."
		),
		_moving_entry(
			"phase3_blocker_barrier", "P3 Blocker Barrier", "blocker", Category.BARRIER,
			"%s/PlasticBarrier.gltf" % KIT_ENV,
			2.0, 0.5, 1.2, Vector3.ZERO, Vector3.ZERO, 0.0,
			false, true,
			"ping_pong", "x", 1.2, 4.0, 0.0,
			"visual_only", "block",
			"Blocker visual; collision sanitized."
		),
		_moving_entry(
			"phase3_warning_stripes", "P3 Warning Stripes", "warning_visual", Category.HAZARD,
			"res://assets/materials/obstacle_warning.tres",
			8.0, 8.0, 0.05, Vector3.ZERO, Vector3.ZERO, 0.02,
			false, true,
			"linear", "x", 0.0, 0.0, 0.0,
			"visual_only", "none",
			"Warning paint before moving obstacle sections."
		),
		_moving_entry(
			"phase3_warning_light", "P3 Warning Light", "warning_visual", Category.DECORATION,
			"%s/StreetLights.gltf" % KIT_ENV,
			1.0, 1.0, 4.5, Vector3.ZERO, Vector3.ZERO, 0.0,
			false, true,
			"linear", "x", 0.0, 0.0, 0.0,
			"visual_only", "none",
			"Edge light before obstacle lanes."
		),
		_moving_entry(
			"phase3_deco_sparks", "P3 Deco Sparks", "decoration", Category.DECORATION,
			"",
			0.5, 0.5, 0.5, Vector3.ZERO, Vector3.ZERO, 0.5,
			false, true,
			"linear", "x", 0.0, 0.0, 0.0,
			"visual_only", "none",
			"Obstacle section dressing sparks."
		),
		_moving_entry(
			"phase3_safe_lane_marker", "P3 Safe Lane Marker", "warning_visual", Category.HAZARD,
			"res://assets/materials/spawn_zone.tres",
			2.0, 2.0, 0.04, Vector3.ZERO, Vector3.ZERO, 0.03,
			false, true,
			"linear", "x", 0.0, 0.0, 0.0,
			"visual_only", "none",
			"Marks persistent safe lane through obstacle segment."
		),
		# --- Drop-and-Play Moving Hazard Kit v1 ---
		_moving_entry(
			"dp_moving_block_side_to_side", "DP Moving Block Side To Side", "moving_obstacle",
			Category.MOVING_OBSTACLE,
			"res://scenes/maps/obstacles/moving_block_side_to_side.tscn",
			2.4, 2.2, 2.4, Vector3.ZERO, Vector3.ZERO, 0.0,
			true, false,
			"ping_pong", "x", 2.8, 4.0, 0.0,
			"kinematic_block", "block",
			"Drop-and-play side-to-side lane block; reset-safe prototype hazard.",
			true, true
		),
		_moving_entry(
			"dp_side_pusher_wall", "DP Side Pusher Wall", "pusher", Category.MOVING_OBSTACLE,
			"res://scenes/maps/obstacles/side_pusher_wall.tscn",
			2.0, 1.4, 0.5, Vector3.ZERO, Vector3.ZERO, 0.0,
			true, false,
			"ping_pong", "x", 2.0, 3.5, 0.0,
			"kinematic_push", "push",
			"Drop-and-play side pusher; push only, no direct kill.",
			true, true
		),
		_moving_entry(
			"dp_timed_gate", "DP Timed Gate", "timed_gate", Category.MOVING_OBSTACLE,
			"res://scenes/maps/obstacles/timed_gate.tscn",
			2.2, 0.35, 1.0, Vector3.ZERO, Vector3.ZERO, 0.0,
			true, false,
			"gate", "x", 3.0, 6.0, 0.0,
			"kinematic_gate", "timing",
			"Drop-and-play timed gate; never permanently blocks all lanes.",
			true, true
		),
		_moving_entry(
			"dp_crusher_block", "DP Crusher Block", "crusher", Category.MOVING_OBSTACLE,
			"res://scenes/maps/obstacles/crusher_block.tscn",
			2.8, 0.6, 2.8, Vector3.ZERO, Vector3.ZERO, 1.2,
			true, false,
			"ping_pong", "y", 1.0, 4.5, 0.0,
			"kinematic_crush", "prototype",
			"Drop-and-play crusher block; prototype-safe, no authoritative kill.",
			true, true
		),
		_moving_entry(
			"dp_rotating_arm", "DP Rotating Arm", "rotating_arm", Category.MOVING_OBSTACLE,
			"res://scenes/maps/obstacles/rotating_arm.tscn",
			3.5, 0.35, 0.35, Vector3.ZERO, Vector3.ZERO, 1.2,
			true, false,
			"rotation", "y", 3.5, 5.0, 0.0,
			"kinematic_sweep", "block",
			"Drop-and-play rotating arm; push/block only.",
			true, true
		),
		# --- Phase 4 split/merge route asset pack ---
		_route_entry(
			"phase4_fork_road_left", "P4 Fork Road Left", "split_lane", Category.ROAD,
			"%s/Street_Turn.gltf" % KIT_ENV,
			8.0, 6.0, 0.2, Vector3(-2, 0, -4), Vector3(-2, 0, 4), 0.0,
			false, true,
			[Vector3(-2.5, 0, 0)], Vector3.ZERO,
			"visual_only",
			"Left fork road visual for split segments."
		),
		_route_entry(
			"phase4_fork_road_right", "P4 Fork Road Right", "split_lane", Category.ROAD,
			"%s/Street_Turn.gltf" % KIT_ENV,
			8.0, 6.0, 0.2, Vector3(2, 0, -4), Vector3(2, 0, 4), 0.0,
			false, true,
			[Vector3(2.5, 0, 0)], Vector3.ZERO,
			"visual_only",
			"Right fork road visual for split segments."
		),
		_route_entry(
			"phase4_merge_road", "P4 Merge Road", "merge_lane", Category.ROAD,
			"%s/Street_Straight.gltf" % KIT_ENV,
			8.0, 10.0, 0.2, Vector3(0, 0, -4), Vector3(0, 0, 4), 0.0,
			false, true,
			[], Vector3.ZERO,
			"visual_only",
			"Merge lane road visual."
		),
		_route_entry(
			"phase4_split_bridge", "P4 Split Bridge", "alternate_route", Category.BRIDGE,
			"",
			8.0, 12.0, 0.16, Vector3(0, 0, -4), Vector3(0, 0, 4), 0.0,
			false, true,
			[Vector3(-3, 0, 0), Vector3(3, 0, 0)], Vector3.ZERO,
			"visual_only",
			"Split bridge deck visual; collision via safe floor plates."
		),
		_route_entry(
			"phase4_side_bridge", "P4 Side Bridge", "alternate_route", Category.BRIDGE,
			"%s/Street_Straight.gltf" % KIT_ENV,
			8.0, 5.0, 0.16, Vector3(3.5, 0, -4), Vector3(3.5, 0, 4), 0.0,
			false, true,
			[Vector3(3.5, 0, 0)], Vector3.ZERO,
			"visual_only",
			"Side bridge path offset from center route."
		),
		_route_entry(
			"phase4_narrow_shortcut_bridge", "P4 Narrow Shortcut Bridge", "shortcut", Category.BRIDGE,
			"",
			8.0, 4.0, 0.14, Vector3(-2.5, 0, -4), Vector3(-2.5, 0, 4), 0.0,
			false, true,
			[Vector3(-2.5, 0, 0)], Vector3.ZERO,
			"visual_only",
			"Narrow high-risk shortcut branch visual."
		),
		_route_entry(
			"phase4_wide_safe_bridge", "P4 Wide Safe Bridge", "safe_route", Category.BRIDGE,
			"",
			8.0, 8.0, 0.14, Vector3(2.5, 0, -4), Vector3(2.5, 0, 4), 0.0,
			false, true,
			[Vector3(2.5, 0, 0)], Vector3.ZERO,
			"visual_only",
			"Wide low-risk safe branch visual."
		),
		_route_entry(
			"phase4_high_path_ramp", "P4 High Path Ramp", "ramp", Category.RAMP,
			"",
			8.0, 5.0, 0.6, Vector3(-2, 0, -4), Vector3(-2, 0.6, 4), 0.0,
			false, true,
			[Vector3(-2, 0.3, 0)], Vector3.ZERO,
			"visual_only",
			"High path ramp for high/low split segments."
		),
		_route_entry(
			"phase4_low_path_ramp", "P4 Low Path Ramp", "ramp", Category.RAMP,
			"",
			8.0, 5.0, 0.4, Vector3(2, 0, -4), Vector3(2, -0.2, 4), 0.0,
			false, true,
			[Vector3(2, -0.1, 0)], Vector3.ZERO,
			"visual_only",
			"Low path ramp for high/low split segments."
		),
		_route_entry(
			"phase4_divider_barrier", "P4 Divider Barrier", "divider", Category.BARRIER,
			"%s/PlasticBarrier.gltf" % KIT_ENV,
			2.0, 0.5, 1.2, Vector3.ZERO, Vector3.ZERO, 0.0,
			false, true,
			[], Vector3.ZERO,
			"visual_only",
			"Lane divider between split branches; collision sanitized."
		),
		_route_entry(
			"phase4_route_sign_arrow", "P4 Route Sign Arrow", "route_marker", Category.DECORATION,
			"%s/TownSign.gltf" % KIT_ENV,
			1.5, 0.3, 2.0, Vector3.ZERO, Vector3.ZERO, 0.0,
			false, true,
			[], Vector3.ZERO,
			"visual_only",
			"Route arrow sign for risk/reward splits."
		),
		_route_entry(
			"phase4_lane_merge_marking", "P4 Lane Merge Marking", "route_marker", Category.HAZARD,
			"res://assets/materials/obstacle_warning.tres",
			8.0, 8.0, 0.05, Vector3.ZERO, Vector3.ZERO, 0.02,
			false, true,
			[], Vector3.ZERO,
			"visual_only",
			"Merge lane warning markings."
		),
		_route_entry(
			"phase4_split_guardrail", "P4 Split Guardrail", "rail", Category.RAIL,
			"%s/TrafficBarrier_1.gltf" % KIT_ENV,
			2.5, 0.4, 1.0, Vector3.ZERO, Vector3.ZERO, 0.0,
			false, true,
			[], Vector3.ZERO,
			"visual_only",
			"Guardrail for split path edges."
		),
		_route_entry(
			"phase4_side_support_pillar", "P4 Side Support Pillar", "decoration", Category.SUPPORT,
			"%s/CinderBlock.gltf" % KIT_ENV,
			1.05, 1.05, 4.0, Vector3.ZERO, Vector3.ZERO, -2.0,
			false, true,
			[], Vector3.ZERO,
			"visual_only",
			"Support pillar for side bridge paths."
		),
		_route_entry(
			"phase4_safe_floor_plate", "P4 Safe Floor Plate", "safe_route", Category.BRIDGE,
			"",
			8.0, 10.0, 0.12, Vector3(0, 0, -4), Vector3(0, 0, 4), -0.06,
			true, false,
			[], Vector3.ZERO,
			"gameplay_collision",
			"Phase 4 authoritative walk collision for branch lanes."
		),
	]


static func _entry(
	asset_id: String,
	display_name: String,
	category: int,
	scene_path: String,
	length: float,
	width: float,
	height: float,
	entry_offset: Vector3,
	exit_offset: Vector3,
	deck_y_offset: float,
	has_collision: bool,
	is_visual_only: bool,
	supports_falling: bool,
	supports_moving: bool,
	notes: String
) -> Dictionary:
	var collision_mode: String = "gameplay_collision" if has_collision else "visual_only"
	return {
		"asset_id": asset_id,
		"display_name": display_name,
		"category": category,
		"scene_path": scene_path,
		"approximate_length": length,
		"approximate_width": width,
		"approximate_height": height,
		"entry_offset": entry_offset,
		"exit_offset": exit_offset,
		"deck_y_offset": deck_y_offset,
		"has_collision": has_collision,
		"is_visual_only": is_visual_only,
		"collision_mode": collision_mode,
		"supports_falling": supports_falling,
		"fall_enabled": supports_falling,
		"supports_moving": supports_moving,
		"default_scale": 1.0,
		"default_rotation": Vector3.ZERO,
		"notes": notes,
	}


static func _moving_entry(
	asset_id: String,
	display_name: String,
	movement_category: String,
	category: int,
	scene_path: String,
	length: float,
	width: float,
	height: float,
	entry_offset: Vector3,
	exit_offset: Vector3,
	deck_y_offset: float,
	has_collision: bool,
	is_visual_only: bool,
	movement_type: String,
	movement_axis: String,
	movement_distance: float,
	cycle_time: float,
	phase_offset: float,
	collision_expectation: String,
	hazard_behavior: String,
	notes: String,
	reset_safe: bool = false,
	drop_and_play: bool = false
) -> Dictionary:
	var entry: Dictionary = _entry(
		asset_id,
		display_name,
		category,
		scene_path,
		length,
		width,
		height,
		entry_offset,
		exit_offset,
		deck_y_offset,
		has_collision,
		is_visual_only,
		false,
		true,
		notes,
	)
	entry["movement_category"] = movement_category
	entry["movement_type"] = movement_type
	entry["movement_axis"] = movement_axis
	entry["movement_distance"] = movement_distance
	entry["cycle_time"] = cycle_time
	entry["phase_offset"] = phase_offset
	entry["pause_at_ends_sec"] = 0.2
	entry["pause_at_start_sec"] = -1.0
	entry["pause_at_end_sec"] = -1.0
	entry["gate_open_ratio"] = 0.65
	entry["collision_expectation"] = collision_expectation
	entry["hazard_behavior"] = hazard_behavior
	entry["gameplay_collision"] = has_collision and not is_visual_only
	entry["reset_safe"] = reset_safe
	entry["drop_and_play"] = drop_and_play
	return entry


static func _route_entry(
	asset_id: String,
	display_name: String,
	route_category: String,
	category: int,
	scene_path: String,
	length: float,
	width: float,
	height: float,
	entry_offset: Vector3,
	exit_offset: Vector3,
	deck_y_offset: float,
	has_collision: bool,
	is_visual_only: bool,
	branch_offsets: Array,
	merge_offset: Vector3,
	collision_expectation: String,
	notes: String
) -> Dictionary:
	var entry: Dictionary = _entry(
		asset_id,
		display_name,
		category,
		scene_path,
		length,
		width,
		height,
		entry_offset,
		exit_offset,
		deck_y_offset,
		has_collision,
		is_visual_only,
		false,
		false,
		notes,
	)
	entry["route_category"] = route_category
	entry["branch_offsets"] = branch_offsets
	entry["merge_offset"] = merge_offset
	entry["collision_expectation"] = collision_expectation
	return entry


static func _instantiate_procedural(entry: Dictionary) -> Node3D:
	var asset_id: String = str(entry.get("asset_id", ""))
	var node := MeshInstance3D.new()
	node.name = asset_id
	var mesh := BoxMesh.new()
	mesh.size = Vector3(
		float(entry.get("approximate_width", 8.0)),
		float(entry.get("approximate_height", 0.12)),
		float(entry.get("approximate_length", 8.0)),
	)
	node.mesh = mesh
	var mat := StandardMaterial3D.new()
	match asset_id:
		"spawn_marker":
			var spawn_mat: Material = load("res://assets/materials/spawn_zone.tres")
			if spawn_mat != null:
				node.material_override = spawn_mat
		"finish_marker":
			var goal_mat: Material = load("res://assets/materials/goal_zone.tres")
			if goal_mat != null:
				node.material_override = goal_mat
		"water_void_plane":
			mat.albedo_color = Color(0.02, 0.06, 0.1, 0.95)
			mat.emission_enabled = true
			mat.emission = Color(0.02, 0.07, 0.12)
			mat.emission_energy_multiplier = 0.25
			node.material_override = mat
		"hazard_warning_plane":
			var hazard_mat: Material = load("res://assets/materials/obstacle_warning.tres")
			if hazard_mat != null:
				node.material_override = hazard_mat
		"gap_void_visual":
			mat.albedo_color = Color(0.01, 0.02, 0.05, 0.9)
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			node.material_override = mat
		"phase1_gap_void":
			mat.albedo_color = Color(0.01, 0.02, 0.05, 0.9)
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			node.material_override = mat
		"phase1_water_river", "phase1_water_segment":
			mat.albedo_color = Color(0.02, 0.06, 0.1, 0.95)
			mat.emission_enabled = true
			mat.emission = Color(0.02, 0.07, 0.12)
			mat.emission_energy_multiplier = 0.25
			node.material_override = mat
		"phase1_support_pillar":
			mat.albedo_color = Color(0.2, 0.21, 0.23, 1.0)
			mat.roughness = 0.92
			node.material_override = mat
		"phase1_bridge_deck_8", "phase1_ramp_surface_8", "phase1_safe_floor_plate":
			mat.albedo_color = Color(0.24, 0.25, 0.27, 1.0)
			mat.roughness = 0.9
			node.material_override = mat
		"phase1_spawn_marker":
			var spawn_mat: Material = load("res://assets/materials/spawn_zone.tres")
			if spawn_mat != null:
				node.material_override = spawn_mat
		"phase1_finish_marker":
			var goal_mat: Material = load("res://assets/materials/goal_zone.tres")
			if goal_mat != null:
				node.material_override = goal_mat
		"phase2_broken_bridge_gap", "phase2_void_floor_visual":
			mat.albedo_color = Color(0.01, 0.02, 0.05, 0.9)
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			node.material_override = mat
		"phase2_water_river_plane", "phase2_lower_river_catch":
			mat.albedo_color = Color(0.02, 0.06, 0.1, 0.95)
			mat.emission_enabled = true
			mat.emission = Color(0.02, 0.07, 0.12)
			mat.emission_energy_multiplier = 0.25
			node.material_override = mat
		"phase2_warning_stripes":
			var warn_mat: Material = load("res://assets/materials/obstacle_warning.tres")
			if warn_mat != null:
				node.material_override = warn_mat
		"phase2_elevated_bridge_deck", "phase2_safe_floor_plate":
			mat.albedo_color = Color(0.24, 0.25, 0.27, 1.0)
			mat.roughness = 0.9
			node.material_override = mat
		"phase2_missing_rail_section":
			mat.albedo_color = Color(0.35, 0.1, 0.1, 0.6)
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			node.material_override = mat
		"phase3_pusher_plate", "phase3_crusher_plate", "phase3_platform_deck":
			mat.albedo_color = Color(0.55, 0.35, 0.15, 1.0)
			mat.metallic = 0.2
			mat.roughness = 0.85
			node.material_override = mat
		"phase3_deco_sparks":
			mat.albedo_color = Color(1.0, 0.7, 0.2, 1.0)
			mat.emission_enabled = true
			mat.emission = Color(1.0, 0.5, 0.1)
			mat.emission_energy_multiplier = 0.4
			node.material_override = mat
		"phase3_warning_stripes":
			var warn_mat: Material = load("res://assets/materials/obstacle_warning.tres")
			if warn_mat != null:
				node.material_override = warn_mat
		"phase3_safe_lane_marker":
			var lane_mat: Material = load("res://assets/materials/spawn_zone.tres")
			if lane_mat != null:
				node.material_override = lane_mat
		"phase4_split_bridge", "phase4_narrow_shortcut_bridge", "phase4_wide_safe_bridge", "phase4_safe_floor_plate":
			mat.albedo_color = Color(0.24, 0.25, 0.27, 1.0)
			mat.roughness = 0.9
			node.material_override = mat
		"phase4_high_path_ramp", "phase4_low_path_ramp":
			mat.albedo_color = Color(0.28, 0.27, 0.25, 1.0)
			mat.roughness = 0.88
			node.material_override = mat
		"phase4_lane_merge_marking":
			var merge_mat: Material = load("res://assets/materials/obstacle_warning.tres")
			if merge_mat != null:
				node.material_override = merge_mat
		_:
			mat.albedo_color = Color(0.22, 0.23, 0.25, 1.0)
			mat.roughness = 0.9
			node.material_override = mat
	return node


static func _sanitize_visual_collision(node: Node) -> void:
	if node is CollisionObject3D and not (node is Area3D):
		var collision_object: CollisionObject3D = node as CollisionObject3D
		collision_object.collision_layer = 0
		collision_object.collision_mask = 0
	if node is CollisionShape3D:
		var collision_shape: CollisionShape3D = node as CollisionShape3D
		collision_shape.disabled = true
	for child in node.get_children():
		_sanitize_visual_collision(child)
