class_name MapNaming
extends RefCounted

## Canonical map naming rules and validation helpers.
##
## Map ID (catalog) == resource basename == scene basename == layout_preset_id (kit maps).
## Display names are human labels only and may differ from IDs.

const FEET_TO_METERS: float = 0.3048

## Retired IDs — must not appear in catalog, scenes, or saved configs.
const BANNED_MAP_IDS: Array[String] = [
	"broken_bridge_candidate",
	"city_highway",
	"broken_bridge_test",
]

## Kit-map catalog IDs. Each must use the same string as layout_preset_id on its scene.
const KIT_MAP_IDS: Array[String] = [
	"broken_bridge_pass",
	"mine_alley",
	"cone_slalom",
	"vehicle_yard",
	"defender_gauntlet",
	"boost_rush",
]

## Default production map (display name: City Highway).
const DEFAULT_MAP_ID: String = "quarantine_boulevard"

## Primary signature map under active development.
const SIGNATURE_MAP_ID: String = "broken_bridge_pass"


static func is_banned_map_id(map_id: String) -> bool:
	return map_id.strip_edges() in BANNED_MAP_IDS


static func is_kit_map_id(map_id: String) -> bool:
	return map_id.strip_edges() in KIT_MAP_IDS


static func expected_resource_path(map_id: String) -> String:
	return "res://resources/maps/%s.tres" % map_id.strip_edges()


static func expected_scene_path(map_id: String) -> String:
	return "res://scenes/maps/%s.tscn" % map_id.strip_edges()


static func validate_catalog_entry(entry: Dictionary) -> PackedStringArray:
	var failures: PackedStringArray = PackedStringArray()
	var map_id: String = str(entry.get("id", "")).strip_edges()
	if map_id.is_empty():
		return PackedStringArray(["catalog entry missing id"])
	if is_banned_map_id(map_id):
		failures.append("catalog entry uses banned map id '%s'" % map_id)

	var resource_path: String = str(entry.get("resource_path", ""))
	var scene_path: String = str(entry.get("scene_path", ""))
	if resource_path != expected_resource_path(map_id):
		failures.append(
			"map '%s' resource_path should be %s, got %s"
			% [map_id, expected_resource_path(map_id), resource_path]
		)
	if scene_path != expected_scene_path(map_id):
		failures.append(
			"map '%s' scene_path should be %s, got %s"
			% [map_id, expected_scene_path(map_id), scene_path]
		)
	if not ResourceLoader.exists(resource_path):
		failures.append("map '%s' missing resource file %s" % [map_id, resource_path])
	if not ResourceLoader.exists(scene_path):
		failures.append("map '%s' missing scene file %s" % [map_id, scene_path])

	if is_kit_map_id(map_id):
		var preset_id: String = str(entry.get("layout_preset_id", map_id))
		if preset_id != map_id:
			failures.append(
				"kit map '%s' layout_preset_id should equal map id, got '%s'"
				% [map_id, preset_id]
			)

	return failures


static func validate_kit_scene_preset(scene_path: String, map_id: String) -> PackedStringArray:
	var failures: PackedStringArray = PackedStringArray()
	if not is_kit_map_id(map_id):
		return failures
	if not ResourceLoader.exists(scene_path):
		failures.append("kit scene missing: %s" % scene_path)
		return failures

	var scene: PackedScene = load(scene_path) as PackedScene
	if scene == null:
		failures.append("could not load kit scene %s" % scene_path)
		return failures

	var instance: Node = scene.instantiate()
	var core_road: Node = instance.get_node_or_null("CoreRoad")
	if core_road == null:
		failures.append("kit scene %s missing CoreRoad node" % scene_path)
	else:
		var preset_id: String = str(core_road.get("layout_preset_id"))
		if preset_id != map_id:
			failures.append(
				"kit scene %s layout_preset_id should be '%s', got '%s'"
				% [scene_path, map_id, preset_id]
			)
	instance.free()
	return failures


static func validate_all_catalog_entries() -> PackedStringArray:
	var failures: PackedStringArray = PackedStringArray()
	for entry in MapCatalog.get_all_entries():
		failures.append_array(validate_catalog_entry(entry))
		var map_id: String = str(entry.get("id", ""))
		if is_kit_map_id(map_id):
			failures.append_array(
				validate_kit_scene_preset(str(entry.get("scene_path", "")), map_id)
			)
	return failures
