class_name MapCatalog
extends RefCounted

const MapNamingScript := preload("res://scripts/maps/map_naming.gd")

const STATUS_PLAYABLE := "playable"
const STATUS_PROTOTYPE := "prototype"
const STATUS_DISABLED := "disabled"
const STATUS_LAB_ONLY := "lab_only"
const STATUS_VALIDATED := "validated"

const DEFAULT_MAP_ID := MapNamingScript.DEFAULT_MAP_ID

const ENTRIES: Array[Dictionary] = [
	{
		"id": "quarantine_boulevard",
		"display_name": "City Highway",
		"resource_path": "res://resources/maps/quarantine_boulevard.tres",
		"scene_path": "res://scenes/maps/quarantine_boulevard.tscn",
		"enabled": true,
		"status": STATUS_PLAYABLE,
		"legacy_index": 0,
	},
	{
		"id": "ai_generated_fallthrough_lower_deck_test",
		"display_name": "Fallthrough Lower Deck",
		"resource_path": "res://resources/maps/ai_generated_fallthrough_lower_deck_test.tres",
		"scene_path": "res://scenes/maps/ai_generated_fallthrough_lower_deck_test.tscn",
		"ai_generated": true,
		"enabled": false,
		"status": STATUS_DISABLED,
		"legacy_index": 1,
	},
	{
		"id": "broken_bridge_pass",
		"display_name": "Broken Bridge",
		"resource_path": "res://resources/maps/broken_bridge_pass.tres",
		"scene_path": "res://scenes/maps/broken_bridge_pass.tscn",
		"layout_preset_id": "broken_bridge_pass",
		"enabled": true,
		"status": STATUS_PLAYABLE,
		"legacy_index": 2,
	},
	{
		"id": "mine_alley",
		"display_name": "Mine Alley",
		"resource_path": "res://resources/maps/mine_alley.tres",
		"scene_path": "res://scenes/maps/mine_alley.tscn",
		"layout_preset_id": "mine_alley",
		"enabled": false,
		"status": STATUS_DISABLED,
		"legacy_index": 3,
	},
	{
		"id": "cone_slalom",
		"display_name": "Cone Slalom",
		"resource_path": "res://resources/maps/cone_slalom.tres",
		"scene_path": "res://scenes/maps/cone_slalom.tscn",
		"layout_preset_id": "cone_slalom",
		"enabled": false,
		"status": STATUS_DISABLED,
		"legacy_index": 4,
	},
	{
		"id": "vehicle_yard",
		"display_name": "Vehicle Yard",
		"resource_path": "res://resources/maps/vehicle_yard.tres",
		"scene_path": "res://scenes/maps/vehicle_yard.tscn",
		"layout_preset_id": "vehicle_yard",
		"enabled": false,
		"status": STATUS_DISABLED,
		"legacy_index": 5,
	},
	{
		"id": "defender_gauntlet",
		"display_name": "Defender Gauntlet",
		"resource_path": "res://resources/maps/defender_gauntlet.tres",
		"scene_path": "res://scenes/maps/defender_gauntlet.tscn",
		"layout_preset_id": "defender_gauntlet",
		"enabled": false,
		"status": STATUS_DISABLED,
		"legacy_index": 6,
	},
	{
		"id": "boost_rush",
		"display_name": "Boost Rush",
		"resource_path": "res://resources/maps/boost_rush.tres",
		"scene_path": "res://scenes/maps/boost_rush.tscn",
		"layout_preset_id": "boost_rush",
		"enabled": false,
		"status": STATUS_DISABLED,
		"legacy_index": 7,
	},
	{
		"id": "spiral_descent",
		"display_name": "Straight Descent Prototype",
		"resource_path": "res://resources/maps/spiral_descent.tres",
		"scene_path": "res://scenes/maps/spiral_descent.tscn",
		"layout_preset_id": "spiral_descent",
		"enabled": false,
		"enabled_for_testing": true,
		"status": STATUS_PROTOTYPE,
		"legacy_index": 8,
	},
	{
		"id": "true_spiral_ramp",
		"display_name": "Square Spiral Ramp",
		"resource_path": "res://resources/maps/true_spiral_ramp.tres",
		"scene_path": "res://scenes/maps/true_spiral_ramp.tscn",
		"enabled": false,
		"enabled_for_testing": true,
		"status": STATUS_PROTOTYPE,
		"legacy_index": 9,
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
	var selectable: Array[Dictionary] = []
	for entry in ENTRIES:
		if is_entry_selectable(entry):
			selectable.append(entry.duplicate(true))
	return selectable


static func get_selectable_entries_for_settings() -> Array[Dictionary]:
	var settings_entries: Array[Dictionary] = []
	var selectable: Array[Dictionary] = get_selectable_entries()
	for settings_index in range(selectable.size()):
		var entry: Dictionary = selectable[settings_index].duplicate(true)
		entry["settings_index"] = settings_index
		settings_entries.append(entry)
	return settings_entries


static func get_settings_map_count() -> int:
	return get_selectable_entries_for_settings().size()


static func get_settings_entry(settings_index: int) -> Dictionary:
	var settings_entries: Array[Dictionary] = get_selectable_entries_for_settings()
	if settings_entries.is_empty():
		return get_entry_by_id(DEFAULT_MAP_ID)
	var clamped: int = int(clamp(settings_index, 0, settings_entries.size() - 1))
	return settings_entries[clamped]


static func get_settings_map_id(settings_index: int) -> String:
	var entry: Dictionary = get_settings_entry(settings_index)
	return str(entry.get("id", DEFAULT_MAP_ID))


static func resolve_settings_index(map_id: String = "", legacy_or_settings_index: int = -1) -> int:
	var trimmed_id: String = map_id.strip_edges()
	if not trimmed_id.is_empty():
		var settings_entries: Array[Dictionary] = get_selectable_entries_for_settings()
		for settings_index in range(settings_entries.size()):
			if str(settings_entries[settings_index].get("id", "")) == trimmed_id:
				return settings_index

	if legacy_or_settings_index < 0:
		return 0

	if legacy_or_settings_index < get_settings_map_count():
		var settings_entry: Dictionary = get_settings_entry(legacy_or_settings_index)
		if is_entry_selectable(settings_entry):
			return legacy_or_settings_index

	var legacy_entry: Dictionary = get_entry_by_legacy_index(legacy_or_settings_index)
	if is_entry_selectable(legacy_entry):
		return resolve_settings_index(str(legacy_entry.get("id", "")), -1)

	return 0


static func resolve_settings_map_id(map_id: String = "", legacy_or_settings_index: int = -1) -> String:
	return get_settings_map_id(resolve_settings_index(map_id, legacy_or_settings_index))


static func load_definition_for_settings_index(settings_index: int) -> RaceMapDefinition:
	return _load_definition_from_entry(get_settings_entry(settings_index))


static func get_playable_count() -> int:
	return get_playable_entries().size()


static func get_selectable_count() -> int:
	return get_selectable_entries().size()


static func is_entry_playable(entry: Dictionary) -> bool:
	if entry.is_empty():
		return false
	if not bool(entry.get("enabled", false)):
		return false
	return str(entry.get("status", "")) == STATUS_PLAYABLE


static func is_entry_selectable(entry: Dictionary) -> bool:
	if entry.is_empty():
		return false
	if is_entry_playable(entry):
		return true
	if not bool(entry.get("enabled_for_testing", false)):
		return false
	return str(entry.get("status", "")) == STATUS_PROTOTYPE


static func get_entry_by_id(map_id: String) -> Dictionary:
	for entry in ENTRIES:
		if str(entry.get("id", "")) == map_id:
			return entry.duplicate(true)
	return {}


static func get_entry_by_legacy_index(legacy_index: int) -> Dictionary:
	for entry in ENTRIES:
		if int(entry.get("legacy_index", -1)) == legacy_index:
			return entry.duplicate(true)
	return {}


static func get_playable_entry(playable_index: int) -> Dictionary:
	var playable: Array[Dictionary] = get_playable_entries()
	if playable.is_empty():
		return {}
	var clamped: int = int(clamp(playable_index, 0, playable.size() - 1))
	return playable[clamped]


static func get_selectable_entry(selectable_index: int) -> Dictionary:
	var selectable: Array[Dictionary] = get_selectable_entries()
	if selectable.is_empty():
		return {}
	var clamped: int = int(clamp(selectable_index, 0, selectable.size() - 1))
	return selectable[clamped]


static func get_max_selectable_legacy_index() -> int:
	var max_index: int = 0
	for entry in get_selectable_entries():
		max_index = maxi(max_index, int(entry.get("legacy_index", 0)))
	return max_index


static func resolve_playable_index(requested_index: int) -> int:
	var selectable: Array[Dictionary] = get_selectable_entries()
	if selectable.is_empty():
		return 0

	for selectable_index in range(selectable.size()):
		if int(selectable[selectable_index].get("legacy_index", -1)) == requested_index:
			return selectable_index

	push_warning(
		"MapCatalog: saved map index %d is not selectable; falling back to %s"
		% [requested_index, DEFAULT_MAP_ID]
	)
	return 0


static func resolve_selectable_map_id(requested_map_id: String, legacy_index: int = -1) -> String:
	return resolve_settings_map_id(requested_map_id, legacy_index)


static func resolve_legacy_index_from_map_id(map_id: String) -> int:
	var entry: Dictionary = get_entry_by_id(map_id)
	if entry.is_empty():
		return 0
	return int(entry.get("legacy_index", 0))


static func resolve_legacy_index(playable_index: int) -> int:
	var entry: Dictionary = get_selectable_entry(playable_index)
	if entry.is_empty():
		return 0
	return int(entry.get("legacy_index", 0))


static func get_selectable_display_name(map_id: String) -> String:
	var entry: Dictionary = get_entry_by_id(map_id)
	if entry.is_empty() or not is_entry_selectable(entry):
		return get_settings_entry(0).get("display_name", "City Highway")
	return str(entry.get("display_name", "City Highway"))


static func load_definition_for_map_id(map_id: String) -> RaceMapDefinition:
	var entry: Dictionary = get_entry_by_id(map_id)
	return _load_definition_from_entry(entry)


static func load_definition_for_playable_index(playable_index: int) -> RaceMapDefinition:
	return load_definition_for_settings_index(playable_index)


static func load_definition_for_legacy_index(legacy_index: int) -> RaceMapDefinition:
	var entry: Dictionary = get_entry_by_legacy_index(legacy_index)
	if entry.is_empty() or not is_entry_selectable(entry):
		entry = get_entry_by_id(DEFAULT_MAP_ID)
	return _load_definition_from_entry(entry)


static func load_definition_by_id(map_id: String) -> RaceMapDefinition:
	var entry: Dictionary = get_entry_by_id(map_id)
	if entry.is_empty():
		push_warning("MapCatalog: unknown map id=%s" % map_id)
		return null
	return _load_definition_from_entry(entry)


static func get_prototype_test_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for entry in ENTRIES:
		if is_prototype_testable(entry):
			entries.append(entry.duplicate(true))
	return entries


static func get_ai_generated_prototype_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for entry in ENTRIES:
		if not bool(entry.get("ai_generated", false)):
			continue
		if not is_prototype_testable(entry):
			continue
		entries.append(entry.duplicate(true))
	return entries


static func is_prototype_testable(entry: Dictionary) -> bool:
	if entry.is_empty():
		return false
	if bool(entry.get("enabled", false)):
		return false
	return str(entry.get("status", "")) == STATUS_PROTOTYPE


static func get_playable_display_name(playable_index: int) -> String:
	var entry: Dictionary = get_playable_entry(playable_index)
	if entry.is_empty():
		return "City Highway"
	return str(entry.get("display_name", "Race Map"))


static func is_playable_legacy_index(legacy_index: int) -> bool:
	var entry: Dictionary = get_entry_by_legacy_index(legacy_index)
	return is_entry_selectable(entry)


static func _load_definition_from_entry(entry: Dictionary) -> RaceMapDefinition:
	if entry.is_empty():
		return null
	var resource_path: String = str(entry.get("resource_path", ""))
	if resource_path.is_empty() or not ResourceLoader.exists(resource_path):
		push_warning("MapCatalog: missing resource for id=%s path=%s" % [entry.get("id", ""), resource_path])
		return null
	return load(resource_path) as RaceMapDefinition
