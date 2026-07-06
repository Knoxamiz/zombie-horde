class_name MapAssetRegistry
extends RefCounted

enum Category {
	ROAD,
	CRACKED_ROAD,
	BARRIER,
	CONE,
	RAIL,
	LIGHT,
	DEBRIS,
	CONTAINER,
	VEHICLE,
	GROUND,
	WATER_VOID,
	MARKER,
	BLOCKER,
	UNKNOWN,
}

enum CollisionPolicy {
	VISUAL_ONLY,
	VISUAL_WITH_SANITIZED_COLLISION,
	GAMEPLAY_COLLISION_NEVER,
	GAMEPLAY_COLLISION_OPTIONAL,
	GAMEPLAY_COLLISION_REQUIRED,
	INVISIBLE_GAMEPLAY_ONLY,
}

const DEFAULT_TILE_SIZE: float = 8.0

static var _assets_cache: Array = []


static func _assets() -> Array:
	if _assets_cache.is_empty():
		_assets_cache = _build_assets()
	return _assets_cache


static func has_asset(asset_id: String) -> bool:
	return not get_asset(asset_id).is_empty()


static func get_asset(asset_id: String) -> Dictionary:
	for entry in _assets():
		if str(entry.get("id", "")) == asset_id:
			return entry.duplicate(true)
	return {}


static func get_assets_by_category(category: int) -> Array[Dictionary]:
	var matches: Array[Dictionary] = []
	for entry in _assets():
		if int(entry.get("category", Category.UNKNOWN)) == category:
			matches.append(entry.duplicate(true))
	return matches


static func get_assets_by_tag(tag: String) -> Array[Dictionary]:
	var matches: Array[Dictionary] = []
	for entry in _assets():
		var tags: Array = entry.get("tags", [])
		if tag in tags:
			matches.append(entry.duplicate(true))
	return matches


static func instantiate_visual_asset(asset_id: String) -> Node3D:
	var entry: Dictionary = get_asset(asset_id)
	if entry.is_empty():
		push_warning("MapAssetRegistry: missing asset id=%s" % asset_id)
		return null

	var scene_path: String = str(entry.get("scene_path", ""))
	if scene_path.is_empty() or not scene_path.ends_with(".gltf"):
		push_warning("MapAssetRegistry: missing visual scene id=%s path=%s" % [asset_id, scene_path])
		return null
	if not ResourceLoader.exists(scene_path):
		push_warning("MapAssetRegistry: missing asset id=%s path=%s" % [asset_id, scene_path])
		return null

	var packed: PackedScene = load(scene_path) as PackedScene
	if packed == null:
		push_warning("MapAssetRegistry: failed to load id=%s path=%s" % [asset_id, scene_path])
		return null

	var instance: Node3D = packed.instantiate() as Node3D
	if instance == null:
		push_warning("MapAssetRegistry: scene root is not Node3D for id=%s" % asset_id)
		return null

	var default_scale: float = float(entry.get("default_scale", 1.0))
	instance.scale = Vector3.ONE * default_scale
	var default_rotation: Vector3 = entry.get("default_rotation", Vector3.ZERO)
	instance.rotation_degrees = default_rotation
	return instance


static func print_asset_report() -> void:
	print("=== MapAssetRegistry Report ===")
	var category_names: Dictionary = {
		Category.ROAD: "road",
		Category.CRACKED_ROAD: "cracked_road",
		Category.BARRIER: "barrier",
		Category.CONE: "cone",
		Category.RAIL: "rail",
		Category.LIGHT: "light",
		Category.DEBRIS: "debris",
		Category.CONTAINER: "container",
		Category.VEHICLE: "vehicle",
		Category.GROUND: "ground",
		Category.WATER_VOID: "water_void",
		Category.MARKER: "marker",
		Category.BLOCKER: "blocker",
		Category.UNKNOWN: "unknown",
	}
	for entry in _assets():
		var category: int = int(entry.get("category", Category.UNKNOWN))
		var exists: bool = ResourceLoader.exists(str(entry.get("scene_path", "")))
		print(
			"- %s [%s] policy=%s exists=%s path=%s"
			% [
				entry.get("id", ""),
				category_names.get(category, "unknown"),
				int(entry.get("collision_policy", CollisionPolicy.VISUAL_ONLY)),
				exists,
				entry.get("scene_path", ""),
			]
		)
	print("Total assets: %d" % _assets().size())


static func _build_assets() -> Array:
	return [
		_asset("street_straight", "Street Straight", "res://assets/third_party/zombie_apocalypse_kit/imported/Environment/Street_Straight.gltf", Category.ROAD, Vector3(8, 0.2, 8), CollisionPolicy.VISUAL_ONLY, ["road", "tile"]),
		_asset("street_crack1", "Street Crack 1", "res://assets/third_party/zombie_apocalypse_kit/imported/Environment/Street_Straight_Crack1.gltf", Category.CRACKED_ROAD, Vector3(8, 0.2, 8), CollisionPolicy.VISUAL_ONLY, ["road", "crack", "damage"]),
		_asset("street_crack2", "Street Crack 2", "res://assets/third_party/zombie_apocalypse_kit/imported/Environment/Street_Straight_Crack2.gltf", Category.CRACKED_ROAD, Vector3(8, 0.2, 8), CollisionPolicy.VISUAL_ONLY, ["road", "crack", "damage"]),
		_asset("street_t", "Street T", "res://assets/third_party/zombie_apocalypse_kit/imported/Environment/Street_T.gltf", Category.ROAD, Vector3(8, 0.2, 8), CollisionPolicy.VISUAL_ONLY, ["road", "junction"]),
		_asset("street_turn", "Street Turn", "res://assets/third_party/zombie_apocalypse_kit/imported/Environment/Street_Turn.gltf", Category.ROAD, Vector3(8, 0.2, 8), CollisionPolicy.VISUAL_ONLY, ["road", "junction"]),
		_asset("street_4way", "Street 4-Way", "res://assets/third_party/zombie_apocalypse_kit/imported/Environment/Street_4Way.gltf", Category.ROAD, Vector3(8, 0.2, 8), CollisionPolicy.VISUAL_ONLY, ["road", "junction"]),
		_asset("plastic_barrier", "Plastic Barrier", "res://assets/third_party/zombie_apocalypse_kit/imported/Environment/PlasticBarrier.gltf", Category.BARRIER, Vector3(2.0, 1.2, 0.5), CollisionPolicy.VISUAL_WITH_SANITIZED_COLLISION, ["barrier", "edge"]),
		_asset("traffic_barrier_1", "Traffic Barrier 1", "res://assets/third_party/zombie_apocalypse_kit/imported/Environment/TrafficBarrier_1.gltf", Category.RAIL, Vector3(2.5, 1.0, 0.4), CollisionPolicy.VISUAL_WITH_SANITIZED_COLLISION, ["barrier", "rail"]),
		_asset("traffic_barrier_2", "Traffic Barrier 2", "res://assets/third_party/zombie_apocalypse_kit/imported/Environment/TrafficBarrier_2.gltf", Category.RAIL, Vector3(2.5, 1.0, 0.4), CollisionPolicy.VISUAL_WITH_SANITIZED_COLLISION, ["barrier", "rail"]),
		_asset("traffic_cone_1", "Traffic Cone 1", "res://assets/third_party/zombie_apocalypse_kit/imported/Environment/TrafficCone_1.gltf", Category.CONE, Vector3(0.6, 0.8, 0.6), CollisionPolicy.VISUAL_ONLY, ["cone", "guide"]),
		_asset("traffic_cone_2", "Traffic Cone 2", "res://assets/third_party/zombie_apocalypse_kit/imported/Environment/TrafficCone_2.gltf", Category.CONE, Vector3(0.6, 0.8, 0.6), CollisionPolicy.VISUAL_ONLY, ["cone", "guide"]),
		_asset("street_light", "Street Light", "res://assets/third_party/zombie_apocalypse_kit/imported/Environment/StreetLights.gltf", Category.LIGHT, Vector3(1.0, 4.5, 1.0), CollisionPolicy.VISUAL_WITH_SANITIZED_COLLISION, ["light"]),
		_asset("pallet_broken", "Broken Pallet", "res://assets/third_party/zombie_apocalypse_kit/imported/Environment/Pallet_Broken.gltf", Category.DEBRIS, Vector3(1.6, 0.4, 1.2), CollisionPolicy.VISUAL_ONLY, ["debris"]),
		_asset("pipes", "Pipes", "res://assets/third_party/zombie_apocalypse_kit/imported/Environment/Pipes.gltf", Category.DEBRIS, Vector3(2.5, 0.8, 2.5), CollisionPolicy.VISUAL_ONLY, ["debris"]),
		_asset("cinder_block", "Cinder Block", "res://assets/third_party/zombie_apocalypse_kit/imported/Environment/CinderBlock.gltf", Category.DEBRIS, Vector3(0.8, 0.5, 1.2), CollisionPolicy.VISUAL_ONLY, ["debris", "support"]),
		_asset("container_red", "Container Red", "res://assets/third_party/zombie_apocalypse_kit/imported/Environment/Container_Red.gltf", Category.CONTAINER, Vector3(3.0, 2.6, 6.0), CollisionPolicy.VISUAL_WITH_SANITIZED_COLLISION, ["container", "void"]),
		_asset("container_green", "Container Green", "res://assets/third_party/zombie_apocalypse_kit/imported/Environment/Container_Green.gltf", Category.CONTAINER, Vector3(3.0, 2.6, 6.0), CollisionPolicy.VISUAL_WITH_SANITIZED_COLLISION, ["container", "void"]),
		_asset("barrel", "Barrel", "res://assets/third_party/zombie_apocalypse_kit/imported/Environment/Barrel.gltf", Category.DEBRIS, Vector3(0.7, 1.0, 0.7), CollisionPolicy.VISUAL_ONLY, ["debris"]),
		_asset("mat_spawn_zone", "Spawn Zone Material", "res://assets/materials/spawn_zone.tres", Category.MARKER, Vector3(1, 1, 1), CollisionPolicy.INVISIBLE_GAMEPLAY_ONLY, ["marker", "material"]),
		_asset("mat_goal_zone", "Goal Zone Material", "res://assets/materials/goal_zone.tres", Category.MARKER, Vector3(1, 1, 1), CollisionPolicy.INVISIBLE_GAMEPLAY_ONLY, ["marker", "material"]),
		_asset("mat_road_asphalt", "Road Asphalt Material", "res://assets/materials/road_asphalt.tres", Category.GROUND, Vector3(1, 1, 1), CollisionPolicy.INVISIBLE_GAMEPLAY_ONLY, ["material", "ground"]),
		_asset("mat_arena_ground", "Arena Ground Material", "res://assets/materials/arena_ground.tres", Category.GROUND, Vector3(1, 1, 1), CollisionPolicy.INVISIBLE_GAMEPLAY_ONLY, ["material", "ground"]),
		_asset("mat_base_concrete", "Base Concrete Material", "res://assets/materials/base_concrete.tres", Category.MARKER, Vector3(1, 1, 1), CollisionPolicy.INVISIBLE_GAMEPLAY_ONLY, ["marker", "material"]),
	]


static func _asset(
	asset_id: String,
	display_name: String,
	scene_path: String,
	category: int,
	footprint: Vector3,
	collision_policy: int,
	tags: Array
) -> Dictionary:
	return {
		"id": asset_id,
		"display_name": display_name,
		"scene_path": scene_path,
		"category": category,
		"footprint": footprint,
		"default_rotation": Vector3.ZERO,
		"default_scale": 1.0,
		"visual_use": true,
		"collision_policy": collision_policy,
		"allow_random_rotation": false,
		"allow_random_scale": false,
		"snap_size": DEFAULT_TILE_SIZE,
		"tags": tags,
		"notes": "",
	}
