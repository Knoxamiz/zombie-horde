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
		"Road/bridge deck collision is procedural (safe_floor_plate), not GLTF collision.",
		"Dedicated ramp GLTF meshes are missing; ramp segments use procedural boxes.",
		"No certified moving-obstacle prefab yet; moving_block_lane uses placeholder slot markers.",
		"Finish authority remains World/StreamerBase; finish_marker is visual-only.",
		"Water/void visuals are procedural; void death is Zombie._check_out_of_bounds only.",
		"City Highway and Broken Bridge TEST scenes use hand-authored or grid blueprints, not AIMapBlueprint yet.",
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
		"supports_falling": supports_falling,
		"supports_moving": supports_moving,
		"default_scale": 1.0,
		"default_rotation": Vector3.ZERO,
		"notes": notes,
	}


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
