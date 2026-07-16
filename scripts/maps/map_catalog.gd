class_name MapCatalog
extends RefCounted

## Single source of truth for every map the game can load.
##
## A map is selectable only when it is `enabled` and `status` is `playable`.
## Selection always resolves by this catalog's ordered list, then loads the
## matching RaceMapDefinition resource and its scene. There are no alternate
## test, legacy-slot, or scene-export loading paths.

const MapNamingScript := preload("res://scripts/maps/map_naming.gd")

const STATUS_PLAYABLE := "playable"
const STATUS_DISABLED := "disabled"

const DEFAULT_MAP_ID := MapNamingScript.DEFAULT_MAP_ID

const ENTRIES: Array[Dictionary] = [
	{
		"id": "quarantine_boulevard",
		"display_name": "City Highway",
		"resource_path": "res://resources/maps/quarantine_boulevard.tres",
		"scene_path": "res://scenes/maps/quarantine_boulevard.tscn",
		"enabled": true,
		"status": STATUS_PLAYABLE,
	},
	{
		"id": "ai_generated_fallthrough_lower_deck_test",
		"display_name": "Fallthrough Lower Deck",
		"resource_path": "res://resources/maps/ai_generated_fallthrough_lower_deck_test.tres",
		"scene_path": "res://scenes/maps/ai_generated_fallthrough_lower_deck_test.tscn",
		"ai_generated": true,
		"enabled": false,
		"status": STATUS_DISABLED,
	},
	{
		"id": "broken_bridge_pass",
		"display_name": "Broken Bridge",
		"resource_path": "res://resources/maps/broken_bridge_pass.tres",
		"scene_path": "res://scenes/maps/broken_bridge_pass.tscn",
		"layout_preset_id": "broken_bridge_pass",
		"enabled": true,
		"status": STATUS_PLAYABLE,
	},
	{
		"id": "mine_alley",
		"display_name": "Mine Alley",
		"resource_path": "res://resources/maps/mine_alley.tres",
		"scene_path": "res://scenes/maps/mine_alley.tscn",
		"layout_preset_id": "mine_alley",
		"enabled": false,
		"status": STATUS_DISABLED,
	},
	{
		"id": "cone_slalom",
		"display_name": "Cone Slalom",
		"resource_path": "res://resources/maps/cone_slalom.tres",
		"scene_path": "res://scenes/maps/cone_slalom.tscn",
		"layout_preset_id": "cone_slalom",
		"enabled": false,
		"status": STATUS_DISABLED,
	},
	{
		"id": "vehicle_yard",
		"display_name": "Vehicle Yard",
		"resource_path": "res://resources/maps/vehicle_yard.tres",
		"scene_path": "res://scenes/maps/vehicle_yard.tscn",
		"layout_preset_id": "vehicle_yard",
		"enabled": false,
		"status": STATUS_DISABLED,
	},
	{
		"id": "defender_gauntlet",
		"display_name": "Defender Gauntlet",
		"resource_path": "res://resources/maps/defender_gauntlet.tres",
		"scene_path": "res://scenes/maps/defender_gauntlet.tscn",
		"layout_preset_id": "defender_gauntlet",
		"enabled": false,
		"status": STATUS_DISABLED,
	},
	{
		"id": "boost_rush",
		"display_name": "Boost Rush",
		"resource_path": "res://resources/maps/boost_rush.tres",
		"scene_path": "res://scenes/maps/boost_rush.tscn",
		"layout_preset_id": "boost_rush",
		"enabled": false,
		"status": STATUS_DISABLED,
	},
	{
		"id": "spiral_descent",
		"display_name": "Straight Descent",
		"resource_path": "res://resources/maps/spiral_descent.tres",
		"scene_path": "res://scenes/maps/spiral_descent.tscn",
		"layout_preset_id": "spiral_descent",
		"enabled": true,
		"status": STATUS_PLAYABLE,
	},
	{
		"id": "true_spiral_ramp",
		"display_name": "Square Spiral Ramp",
		"resource_path": "res://resources/maps/true_spiral_ramp.tres",
		"scene_path": "res://scenes/maps/true_spiral_ramp.tscn",
		"enabled": true,
		"status": STATUS_PLAYABLE,
	},
]


static func get_all_entries() -> Array[Dictionary]:
	return ENTRIES.duplicate(true)


static func get_playable_entries() -> Array[Dictionary]:
	var playable: Array[Dictionary] = []
	for entry in ENTRIES:
		if is_entry_playable(entry):
			playable.append(entry.duplicate(true))
	return playable


static func get_selectable_entries() -> Array[Dictionary]:
	return get_playable_entries()


static func get_selectable_entries_for_settings() -> Array[Dictionary]:
	var settings_entries: Array[Dictionary] = []
	var playable: Array[Dictionary] = get_playable_entries()
	for settings_index in range(playable.size()):
		var entry: Dictionary = playable[settings_index].duplicate(true)
		entry["settings_index"] = settings_index
		settings_entries.append(entry)
	return settings_entries


static func get_settings_map_count() -> int:
	return get_playable_entries().size()


static func get_settings_entry(settings_index: int) -> Dictionary:
	var playable: Array[Dictionary] = get_playable_entries()
	if playable.is_empty():
		return get_entry_by_id(DEFAULT_MAP_ID)
	var resolved_index: int = _resolve_existing_settings_index(settings_index, playable.size())
	return playable[resolved_index]


static func get_settings_map_id(settings_index: int) -> String:
	return str(get_settings_entry(settings_index).get("id", DEFAULT_MAP_ID))


static func resolve_settings_index(map_id: String = "", settings_index: int = -1) -> int:
	var playable: Array[Dictionary] = get_playable_entries()
	if playable.is_empty():
		return 0

	var trimmed_id: String = map_id.strip_edges()
	if not trimmed_id.is_empty():
		for index in range(playable.size()):
			if str(playable[index].get("id", "")) == trimmed_id:
				return index

	return _resolve_existing_settings_index(settings_index, playable.size())


static func resolve_settings_map_id(map_id: String = "", settings_index: int = -1) -> String:
	return get_settings_map_id(resolve_settings_index(map_id, settings_index))


static func get_playable_count() -> int:
	return get_playable_entries().size()


static func is_entry_playable(entry: Dictionary) -> bool:
	return not entry.is_empty() and bool(entry.get("enabled", false)) and str(entry.get("status", "")) == STATUS_PLAYABLE


static func get_entry_by_id(map_id: String) -> Dictionary:
	for entry in ENTRIES:
		if str(entry.get("id", "")) == map_id:
			return entry.duplicate(true)
	return {}


static func get_playable_display_name(settings_index: int) -> String:
	return str(get_settings_entry(settings_index).get("display_name", "Race Map"))


static func get_selectable_display_name(map_id: String) -> String:
	var entry: Dictionary = get_entry_by_id(map_id)
	if not is_entry_playable(entry):
		return get_playable_display_name(0)
	return str(entry.get("display_name", "Race Map"))


static func load_definition_for_settings_index(settings_index: int) -> RaceMapDefinition:
	return _load_definition_from_entry(get_settings_entry(settings_index))


static func load_definition_for_map_id(map_id: String) -> RaceMapDefinition:
	return _load_definition_from_entry(get_entry_by_id(map_id))


static func load_definition_by_id(map_id: String) -> RaceMapDefinition:
	return load_definition_for_map_id(map_id)


static func _resolve_existing_settings_index(settings_index: int, count: int) -> int:
	if settings_index < 0 or settings_index >= count:
		return 0
	return settings_index


static func _load_definition_from_entry(entry: Dictionary) -> RaceMapDefinition:
	if entry.is_empty():
		return null
	var resource_path: String = str(entry.get("resource_path", ""))
	if resource_path.is_empty() or not ResourceLoader.exists(resource_path):
		push_warning(
			"MapCatalog: missing definition for id=%s path=%s"
			% [entry.get("id", ""), resource_path]
		)
		return null
	return load(resource_path) as RaceMapDefinition
