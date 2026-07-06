class_name MapCatalog
extends RefCounted

const STATUS_PLAYABLE := "playable"
const STATUS_PROTOTYPE := "prototype"
const STATUS_DISABLED := "disabled"
const STATUS_LAB_ONLY := "lab_only"
const STATUS_VALIDATED := "validated"

const DEFAULT_MAP_ID := "quarantine_boulevard"

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
		"id": "long_road",
		"display_name": "Long_Road",
		"resource_path": "res://resources/maps/long_road.tres",
		"scene_path": "res://scenes/maps/long_road.tscn",
		"enabled": false,
		"status": STATUS_PROTOTYPE,
		"legacy_index": 1,
	},
	{
		"id": "broken_bridge",
		"display_name": "Broken Bridge",
		"resource_path": "res://resources/maps/broken_bridge.tres",
		"scene_path": "res://scenes/maps/broken_bridge.tscn",
		"enabled": false,
		"status": STATUS_PROTOTYPE,
		"legacy_index": 2,
	},
	{
		"id": "industrial_yard",
		"display_name": "Industrial Yard",
		"resource_path": "res://resources/maps/industrial_yard.tres",
		"scene_path": "res://scenes/maps/industrial_yard.tscn",
		"enabled": false,
		"status": STATUS_DISABLED,
		"legacy_index": 3,
	},
	{
		"id": "suburban_evac_route",
		"display_name": "Suburban Evac Route",
		"resource_path": "res://resources/maps/suburban_evac_route.tres",
		"scene_path": "res://scenes/maps/suburban_evac_route.tscn",
		"enabled": false,
		"status": STATUS_DISABLED,
		"legacy_index": 4,
	},
	{
		"id": "tunnel_checkpoint",
		"display_name": "Tunnel Checkpoint",
		"resource_path": "res://resources/maps/tunnel_checkpoint.tres",
		"scene_path": "res://scenes/maps/tunnel_checkpoint.tscn",
		"enabled": false,
		"status": STATUS_DISABLED,
		"legacy_index": 5,
	},
	{
		"id": "rooftop_causeway",
		"display_name": "Rooftop Causeway",
		"resource_path": "res://resources/maps/rooftop_causeway.tres",
		"scene_path": "res://scenes/maps/rooftop_causeway.tscn",
		"enabled": false,
		"status": STATUS_DISABLED,
		"legacy_index": 6,
	},
	{
		"id": "broken_bridge_candidate",
		"display_name": "Broken Bridge Candidate",
		"resource_path": "res://resources/maps/broken_bridge_candidate.tres",
		"scene_path": "res://scenes/maps/broken_bridge_candidate.tscn",
		"enabled": false,
		"status": STATUS_PROTOTYPE,
		"legacy_index": 7,
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


static func get_playable_count() -> int:
	return get_playable_entries().size()


static func is_entry_playable(entry: Dictionary) -> bool:
	if entry.is_empty():
		return false
	if not bool(entry.get("enabled", false)):
		return false
	return str(entry.get("status", "")) == STATUS_PLAYABLE


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


static func resolve_playable_index(requested_index: int) -> int:
	var playable: Array[Dictionary] = get_playable_entries()
	if playable.is_empty():
		return 0

	for playable_index in range(playable.size()):
		if int(playable[playable_index].get("legacy_index", -1)) == requested_index:
			return playable_index

	push_warning(
		"MapCatalog: saved map index %d is not playable; falling back to %s"
		% [requested_index, DEFAULT_MAP_ID]
	)
	return 0


static func resolve_legacy_index(playable_index: int) -> int:
	var entry: Dictionary = get_playable_entry(playable_index)
	if entry.is_empty():
		return 0
	return int(entry.get("legacy_index", 0))


static func load_definition_for_playable_index(playable_index: int) -> RaceMapDefinition:
	var entry: Dictionary = get_playable_entry(playable_index)
	return _load_definition_from_entry(entry)


static func load_definition_for_legacy_index(legacy_index: int) -> RaceMapDefinition:
	var entry: Dictionary = get_entry_by_legacy_index(legacy_index)
	if entry.is_empty() or not is_entry_playable(entry):
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
	return is_entry_playable(entry)


static func _load_definition_from_entry(entry: Dictionary) -> RaceMapDefinition:
	if entry.is_empty():
		return null
	var resource_path: String = str(entry.get("resource_path", ""))
	if resource_path.is_empty() or not ResourceLoader.exists(resource_path):
		push_warning("MapCatalog: missing resource for id=%s path=%s" % [entry.get("id", ""), resource_path])
		return null
	return load(resource_path) as RaceMapDefinition
